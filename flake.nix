{
  description = "lexi's NixOS configuration for uwu";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";

    hermes-agent.url = "github:NousResearch/hermes-agent";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  nixConfig = {
    extra-substituters = [ "https://cache.xinux.uz" ];
    extra-trusted-public-keys = [
      "cache.xinux.uz:BXCrtqejFjWzWEB9YuGB7X2MV4ttBur1N8BkwQRdH+0="
    ];
  };

  outputs = { self, nixpkgs, home-manager, nix-cachyos-kernel, hermes-agent, ... }:
    let
      system = "x86_64-linux";
    in
    {
      nixosConfigurations.uwu = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit nix-cachyos-kernel; };
        modules = [
          ./hosts/uwu/configuration.nix
          ./modules/filesystems.nix
          ./modules/sway.nix

          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit hermes-agent; };
            home-manager.users.lexi = import ./home/lexi/home.nix;
          }
        ];
      };
    };
}
