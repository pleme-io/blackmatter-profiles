{
  description = "Blackmatter Profiles - curated shell environments as OCI container images";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/d6c71932130818840fc8fe9509cf50be8c64634f";

    blackmatter-nvim = {
      url = "github:pleme-io/blackmatter-nvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    blackmatter-shell = {
      url = "github:pleme-io/blackmatter-shell";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.blackmatter-nvim.follows = "blackmatter-nvim";
    };

    umbra = {
      url = "github:pleme-io/umbra";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    substrate = {
      url = "git+ssh://git@github.com/pleme-io/substrate.git";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    nixpkgs,
    blackmatter-shell,
    umbra,
    substrate,
    ...
  }: let
    # OCI images are always Linux; release scripts run on any system
    linuxSystems = ["x86_64-linux" "aarch64-linux"];
    allSystems = linuxSystems ++ ["x86_64-darwin" "aarch64-darwin"];
    forLinux = f: nixpkgs.lib.genAttrs linuxSystems (system: f system nixpkgs.legacyPackages.${system});
    forAll = f: nixpkgs.lib.genAttrs allSystems (system: f system);

    mkProfile = name: system:
      import ./profiles/${name} {
        pkgs = nixpkgs.legacyPackages.${system};
        lib = nixpkgs.lib;
        blzsh = blackmatter-shell.packages.${system}.blzsh;
        umbra-agent = umbra.packages.${system}.umbra-agent;
      };

    # Substrate lib for release helpers (instantiated per host system)
    mkSubstrateLib = system: import "${substrate}/lib" {
      pkgs = nixpkgs.legacyPackages.${system};
    };
  in {
    # Each profile is exposed as packages.<system>.<name>
    # Build:  nix build .#packages.x86_64-linux.debug
    # Run:    docker load < result && docker run --rm -it ghcr.io/pleme-io/blackmatter-debug:latest
    packages = forLinux (system: pkgs: {
      default = mkProfile "debug" system;
      debug = mkProfile "debug" system;
      k8s = mkProfile "k8s" system;
    });

    # Release apps: build image + push to GHCR via substrate helper
    # Runs on any system (macOS builds linux images via remote builder)
    # Usage: nix run .#release          (all profiles)
    #        nix run .#release:debug    (debug only)
    #        nix run .#release:k8s      (k8s only)
    apps = forAll (system: let
      substrateLib = mkSubstrateLib system;
    in
      substrateLib.mkImageReleaseApps {
        debug = {
          registry = "ghcr.io/pleme-io/blackmatter-debug";
          mkImage = targetSystem: mkProfile "debug" targetSystem;
        };
        k8s = {
          registry = "ghcr.io/pleme-io/blackmatter-k8s";
          mkImage = targetSystem: mkProfile "k8s" targetSystem;
        };
      }
    );
  };
}
