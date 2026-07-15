{
  pkgs,
  repoPath,
  ...
}:

let
  nixwaySwitch = pkgs.writeShellApplication {
    name = "nixway-switch";
    runtimeInputs = with pkgs; [
      coreutils
      git
      nh
    ];
    text = ''
      repo="''${NH_FLAKE:-${repoPath}}"
      cd "$repo"

      if ! git config --get user.email >/dev/null; then
        echo "Git needs an author email before it can create the automatic commit." >&2
        echo 'Set one with: git config --file ~/.config/git/local user.email "YOUR_GITHUB_NOREPLY_EMAIL"' >&2
        exit 1
      fi

      # Git flakes ignore untracked files, so stage the whole blueprint first.
      git add -A
      nh os switch --accept-flake-config "$@"

      if ! git diff --cached --quiet; then
        git commit -m "uwu: automatic system rebuild $(date --iso-8601=seconds)"
      fi

      git push origin HEAD
    '';
  };
in
{
  programs.home-manager.enable = true;
  home.sessionPath = [ "$HOME/.local/bin" ];

  home.packages = with pkgs; [
    _7zz
    bat
    eza
    fastfetch
    ffmpeg
    gh
    htop
    nixwaySwitch
    tree
  ];

  programs.git = {
    enable = true;
    settings = {
      init.defaultBranch = "main";
      pull.rebase = false;
    };
    includes = [ { path = "~/.config/git/local"; } ];
  };

  programs.bash = {
    enable = true;
    shellAliases = {
      ll = "eza -la --group-directories-first";
      rebuild = "nixway-switch";
      test-rebuild = "nh os test --accept-flake-config";
      update-hermes = "update_hermes";
      update-kernel = "update_kernel";
      update-system = "update_system";
    };
    initExtra = ''
      update_kernel() (
        cd "${repoPath}" || return
        nix flake update --accept-flake-config nix-cachyos-kernel
        nixway-switch
      )

      update_hermes() (
        cd "${repoPath}" || return
        nix flake update --accept-flake-config hermes-agent
        nixway-switch
      )

      update_system() (
        cd "${repoPath}" || return
        nix flake update --accept-flake-config
        nixway-switch
      )
    '';
  };

  programs.mpv.enable = true;
}
