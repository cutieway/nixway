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
      system = "x86_64-linux";
      pkgs = inputs.nixpkgs.legacyPackages.${system};
    in
    {
      nixosConfigurations.uwu = mkHost {
        hostname = "uwu";
        username = "lexi";
      };

      # Locally packaged AI tools, exposed so `nix build .#pi` and friends
      # work and so the update-agents/update-ai shell commands can call
      # `nix-update --flake` without hand-editing versions or hashes.
      # `nix flake check` only evaluates these; it does not build them.
      packages.${system} = {
        claude-code-router = pkgs.callPackage ./packages/claude-code-router.nix { };
        llama-cpp-prism = pkgs.callPackage ./packages/llama-cpp-prism.nix { };
        openchamber = pkgs.callPackage ./packages/openchamber { };
        pi = pkgs.callPackage ./packages/pi.nix { pi-src = inputs.pi; };
      };
    };
}
