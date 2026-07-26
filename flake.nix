{
  description = "lexi's NixOS configuration for uwu";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";

    llm-agents.url = "github:numtide/llm-agents.nix";

    openspec.url = "github:Fission-AI/OpenSpec";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ self, ... }:
    let
      mkHost = import ./lib/mk-host.nix { inherit inputs self; };
    in
    {
      nixosConfigurations.uwu = mkHost {
        hostname = "uwu";
        username = "lexi";
      };
    };
}
