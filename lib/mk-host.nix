{ inputs, self }:

{
  hostname,
  username,
  system ? "x86_64-linux",
  uid ? 1000,
  gid ? uid,
}:

let
  hostModule = ../hosts/${hostname};
  homeModule = ../home/${username}/home.nix;
  repoPath = builtins.toString self.outPath;

  # Package set from the unstable nixpkgs channel, used for packages that need
  # a newer version than nixos-26.05 provides (e.g. zed-editor).
  pkgs-unstable = inputs.nixpkgs-unstable.legacyPackages.${system};
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
          inherit inputs pkgs-unstable repoPath;
        };
        users.${username} = import homeModule;
      };
    }
  ];
}
