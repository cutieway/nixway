{ pkgs, ... }:

let
  mudfish = pkgs.callPackage ../../../packages/mudfish { };

  mudfishPrepareState = pkgs.writeShellApplication {
    name = "mudfish-prepare-state";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
    ];
    text = ''
      state=/var/lib/mudfish
      backups=/var/lib/mudfish-backups
      marker="$state/.nixway-version"
      new_version=${mudfish.version}
      old_version=unknown

      if [ -r "$marker" ]; then
        read -r old_version <"$marker"
      fi

      if [ "$old_version" = "$new_version" ]; then
        exit 0
      fi

      state_entry="$(find "$state" -mindepth 1 ! -name .nixway-version -print -quit)"
      if [ -n "$state_entry" ]; then
        timestamp="$(date --utc +%Y%m%dT%H%M%SZ)"
        old_label="$(printf '%s' "$old_version" | tr -c 'A-Za-z0-9._-' '_')"
        new_label="$(printf '%s' "$new_version" | tr -c 'A-Za-z0-9._-' '_')"
        destination="$backups/$old_label-before-$new_label-$timestamp"

        mkdir -p "$destination"
        cp -a "$state/." "$destination/"
        echo "Backed up Mudfish state to $destination"
      fi

      printf '%s\n' "$new_version" >"$marker"
    '';
  };

  mudfishLaunch = pkgs.writeShellApplication {
    name = "mudfish-launch";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.kdePackages.kdialog
      pkgs.systemd
      pkgs.xdg-utils
    ];
    text = ''
      dashboard="http://127.0.0.1:8282"

      if ! systemctl is-active --quiet mudfish.service; then
        if ! /run/wrappers/bin/pkexec ${pkgs.systemd}/bin/systemctl start mudfish.service; then
          kdialog --error "Mudfish was not started. Administrator authentication may have been cancelled."
          exit 1
        fi
      fi

      for _ in {1..30}; do
        if curl --fail --silent --output /dev/null --connect-timeout 1 "$dashboard/"; then
          exec xdg-open "$dashboard/"
        fi

        if ! systemctl is-active --quiet mudfish.service; then
          break
        fi
        sleep 1
      done

      kdialog --error "Mudfish did not open its local dashboard. Check: sudo journalctl -u mudfish --no-pager"
      exit 1
    '';
  };

  mudfishStop = pkgs.writeShellApplication {
    name = "mudfish-stop";
    runtimeInputs = [
      pkgs.kdePackages.kdialog
      pkgs.systemd
    ];
    text = ''
      if /run/wrappers/bin/pkexec ${pkgs.systemd}/bin/systemctl stop mudfish.service; then
        kdialog --passivepopup "Mudfish stopped" 5
      else
        kdialog --error "Mudfish was not stopped. Administrator authentication may have been cancelled."
        exit 1
      fi
    '';
  };

  mudfishDesktop = pkgs.makeDesktopItem {
    name = "mudfish";
    desktopName = "Mudfish";
    genericName = "Game Network Accelerator";
    comment = "Start Mudfish and open its local dashboard";
    exec = "${mudfishLaunch}/bin/mudfish-launch";
    icon = "${mudfish.unwrapped}/opt/mudfish/${mudfish.version}/share/mudrun_logo.png";
    terminal = false;
    categories = [
      "Game"
      "Network"
    ];
    keywords = [
      "GPN"
      "VPN"
      "latency"
      "ping"
    ];
    actions.stop = {
      name = "Stop Mudfish";
      exec = "${mudfishStop}/bin/mudfish-stop";
    };
  };

  mudfishMenu = pkgs.symlinkJoin {
    name = "mudfish-menu";
    paths = [
      mudfishDesktop
      mudfishLaunch
      mudfishStop
    ];
  };
in
{
  environment.systemPackages = [ mudfishMenu ];

  systemd.services.mudfish = {
    description = "Mudfish game network accelerator";
    documentation = [ "https://docs.mudfish.net/en/docs/mudfish-cloud-vpn/" ];
    after = [ "NetworkManager.service" ];
    wants = [ "NetworkManager.service" ];
    restartIfChanged = false;

    # This service is intentionally not enabled at boot. The Plasma menu entry
    # starts it only when Mudfish is needed for a game.
    serviceConfig = {
      Type = "simple";
      ExecStartPre = "${mudfishPrepareState}/bin/mudfish-prepare-state";
      ExecStart = "${mudfish}/bin/mudfish";
      WorkingDirectory = "/var/lib/mudfish";
      StateDirectory = [
        "mudfish"
        "mudfish-backups"
      ];
      StateDirectoryMode = "0700";
      UMask = "0077";
      TimeoutStopSec = "15s";
    };
  };
}
