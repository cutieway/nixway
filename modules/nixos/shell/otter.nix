{ inputs, ... }:

{
  imports = [ inputs.otter-shell.nixosModules.default ];

  nixpkgs.overlays = [ inputs.otter-shell.overlays.default ];

  # Desktop provider selection happens in Home Manager. This layer supplies
  # only shared system prerequisites and never edits a compositor config.
  services.otter-shell = {
    enable = true;
    installFonts = false;
    enablePipeWire = false;
    enableUPower = true;
    enableNetworkManager = false;
    enablePolkit = false;
    enableLockPam = true;
    enableRecorderKmsWrapper = false;
  };
}
