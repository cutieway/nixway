{ pkgs, ... }:

{
  home.packages = with pkgs; [
    (opencode-desktop.overrideAttrs (old: {
      preFixup = (old.preFixup or "") + ''
        gappsWrapperArgs+=(
          --add-flags "--ozone-platform-hint=auto"
        )
      '';
    }))
  ];
}
