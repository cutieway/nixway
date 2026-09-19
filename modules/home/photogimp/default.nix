{
  lib,
  pkgs,
  ...
}:

let
  photoGimpVersion = "3.1";

  src = pkgs.fetchFromGitHub {
    owner = "Diolinux";
    repo = "PhotoGIMP";
    rev = photoGimpVersion;
    hash = "sha256-524lsDRmahWXXP9/cfk2ia+7K6xNFTdoYXO8UUsLP/o=";
  };

  # GIMP keeps user configuration in ~/.config/GIMP/<major.minor>, and
  # PhotoGIMP ships its preset for exactly that directory.
  gimpConfigVersion = lib.versions.majorMinor pkgs.gimp.version;
  gimpConfigDir = "GIMP/${gimpConfigVersion}";
  photoGimpConfig = "${src}/.config/${gimpConfigDir}";

  # One icon per hicolor size. Upstream misplaces the 256×256 file, so point it
  # at the path icon themes actually search.
  icons = {
    "16x16" = "16x16/apps/photogimp.png";
    "32x32" = "32x32/apps/photogimp.png";
    "48x48" = "48x48/apps/photogimp.png";
    "64x64" = "64x64/apps/photogimp.png";
    "128x128" = "128x128/apps/photogimp.png";
    "256x256" = "256x256/256x256.png";
    "512x512" = "512x512/apps/photogimp.png";
  };

  # PhotoGIMP's own launcher assumes Flatpak's org.gimp.GIMP desktop ID and a
  # `flatpak run` command. Rebrand the native gimp.desktop entry instead so
  # image associations keep pointing at the same ID and the native Exec and
  # StartupWMClass stay intact.
  desktopItem = pkgs.runCommand "gimp-photogimp.desktop" { } ''
    install -Dm644 ${pkgs.gimp}/share/applications/gimp.desktop \
      $out/share/applications/gimp.desktop

    # Localised Name[...] entries would win over the generic Name in those
    # locales, so remove them before rebranding.
    sed -i \
      -e '/^Name\[/d' \
      -e 's|^Name=.*|Name=PhotoGIMP|' \
      -e 's|^Icon=.*|Icon=photogimp|' \
      $out/share/applications/gimp.desktop

    grep -qx 'Name=PhotoGIMP' $out/share/applications/gimp.desktop
    grep -qx 'Icon=photogimp' $out/share/applications/gimp.desktop
    grep -q '^Exec=' $out/share/applications/gimp.desktop
  '';
in
{
  xdg.dataFile =
    lib.mapAttrs' (
      size: relative:
      lib.nameValuePair "icons/hicolor/${size}/apps/photogimp.png" {
        source = "${src}/.local/share/icons/hicolor/${relative}";
      }
    ) icons
    // {
      "applications/gimp.desktop".source = "${desktopItem}/share/applications/gimp.desktop";
    };

  # GIMP rewrites gimprc, shortcutsrc, tool-options/* and friends every time it
  # exits, so these have to stay real files in $HOME instead of read-only links
  # into the store. Copy them once per PhotoGIMP version, keeping the previous
  # configuration next to the GIMP directory.
  home.activation.photoGimp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    version=${lib.escapeShellArg photoGimpVersion}
    source=${lib.escapeShellArg photoGimpConfig}
    config_dir="$HOME/.config/${gimpConfigDir}"
    marker="$config_dir/.photogimp-version"

    if [[ -v DRY_RUN ]]; then
      echo "PhotoGIMP: would install PhotoGIMP $version into $config_dir"
    elif [ "$(cat "$marker" 2>/dev/null || true)" != "$version" ]; then
      if [ -d "$config_dir" ]; then
        backup="$config_dir.photogimp-backup-$(date +%Y%m%d%H%M%S)"
        cp -a "$config_dir" "$backup"
        echo "PhotoGIMP: previous GIMP configuration saved to $backup"
      fi

      mkdir -p "$config_dir"
      cp -r "$source/." "$config_dir/"
      # Nix store files are read-only; GIMP must be able to rewrite them.
      chmod -R u+w "$config_dir"
      printf '%s\n' "$version" > "$marker"
      echo "PhotoGIMP $version installed; restart GIMP to use the new layout."
    fi
  '';
}
