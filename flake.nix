{
  description = "lexi's NixOS configuration for uwu";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";

    llm-agents.url = "github:numtide/llm-agents.nix";

    # pi-coding-agent: flake = false because the repo has no flake.nix.
    # Using it as a plain source means `nix flake update pi` pulls the latest
    # tag and the package version is derived from its package.json.
    pi = {
      url = "github:earendil-works/pi";
      flake = false;
    };

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
