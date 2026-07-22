{ inputs }:

{
  hostname,
  username,
  system ? "x86_64-linux",
  uid ? 1000,
  gid ? uid,
}:

let
  hostModule = ../hosts + "/${hostname}";
  homeModule = ../home + "/${username}/home.nix";
  repoPath = "/home/${username}/Projects/nixway";

  # Package set from the unstable nixpkgs channel, used for packages that need
  # a newer version than nixos-26.05 provides (e.g. zed-editor).
  pkgs-unstable = import inputs.nixpkgs-unstable {
    inherit system;
    config.allowUnfree = true;
  };
in
inputs.nixpkgs.lib.nixosSystem {
  inherit system;

  specialArgs = {
    inherit
      gid
      hostname
      inputs
      pkgs-unstable
      repoPath
      uid
      username
      ;
  };

  modules = [
    hostModule
    inputs.home-manager.nixosModules.home-manager
    {
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        extraSpecialArgs = {
          inherit
            hostname
            inputs
            pkgs-unstable
            repoPath
            username
            ;
        };
        users.${username} = import homeModule;
      };
    }
  ];
}
