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
in
inputs.nixpkgs.lib.nixosSystem {
  inherit system;

  specialArgs = {
    inherit
      gid
      hostname
      inputs
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
            repoPath
            username
            ;
        };
        users.${username} = import homeModule;
      };
    }
  ];
}
