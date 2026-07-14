{ otter-shell, ... }:

{
  imports = [ otter-shell.nixosModules.default ];

  nixpkgs.overlays = [ otter-shell.overlays.default ];

  # Keep general machine services under nixway's ownership. The Otter module
  # supplies only the prerequisites that are not already configured elsewhere.
  services.otter-shell = {
    enable = true;
    installFonts = false;
    enablePipeWire = false;
    enableUPower = true;
    enableNetworkManager = false;
    enablePolkit = false;
    enableLockPam = true;

    # Granting cap_sys_admin is deliberately separate from merely installing
    # and testing otter-rec.
    enableRecorderKmsWrapper = false;
  };
}
