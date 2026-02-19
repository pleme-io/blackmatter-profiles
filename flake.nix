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
  };

  outputs = {
    nixpkgs,
    blackmatter-shell,
    ...
  }: let
    # OCI images are always Linux; release scripts run on any system
    linuxSystems = ["x86_64-linux" "aarch64-linux"];
    allSystems = linuxSystems ++ ["x86_64-darwin" "aarch64-darwin"];
    forLinux = f: nixpkgs.lib.genAttrs linuxSystems (system: f system nixpkgs.legacyPackages.${system});
    forAll = f: nixpkgs.lib.genAttrs allSystems (system: f system nixpkgs.legacyPackages.${system});

    # Map host system → container target (darwin hosts build linux images)
    containerSystem = system:
      {
        "aarch64-darwin" = "aarch64-linux";
        "x86_64-darwin" = "x86_64-linux";
      }.${
        system
      } or system;

    mkProfile = name: system:
      import ./profiles/${name} {
        pkgs = nixpkgs.legacyPackages.${system};
        lib = nixpkgs.lib;
        blzsh = blackmatter-shell.packages.${system}.blzsh;
      };

    # Registry names for each profile
    profileRegistry = {
      debug = "ghcr.io/pleme-io/blackmatter-debug";
      k8s = "ghcr.io/pleme-io/blackmatter-k8s";
    };

    # Release script: host tools (skopeo/git) from hostPkgs, image built for linux
    mkReleaseScript = hostPkgs: targetSystem: name: let
      image = mkProfile name targetSystem;
      registry = profileRegistry.${name};
    in
      hostPkgs.writeShellScript "release-${name}" ''
        set -euo pipefail
        SHORT_SHA=$(${hostPkgs.git}/bin/git rev-parse --short HEAD)
        echo "==> Releasing ${registry} (latest + $SHORT_SHA)"
        ${hostPkgs.skopeo}/bin/skopeo copy docker-archive:${image} docker://${registry}:latest
        ${hostPkgs.skopeo}/bin/skopeo copy docker-archive:${image} docker://${registry}:$SHORT_SHA
        echo "==> Done: ${registry}"
      '';
  in {
    # Each profile is exposed as packages.<system>.<name>
    # Build:  nix build .#packages.x86_64-linux.debug
    # Run:    docker load < result && docker run --rm -it ghcr.io/pleme-io/blackmatter-debug:latest
    packages = forLinux (system: pkgs: {
      default = mkProfile "debug" system;
      debug = mkProfile "debug" system;
      k8s = mkProfile "k8s" system;
    });

    # Release apps: build image + push to GHCR
    # Runs on any system (macOS builds linux images via remote builder)
    # Usage: nix run .#release          (all profiles)
    #        nix run .#release:debug    (debug only)
    #        nix run .#release:k8s      (k8s only)
    apps = forAll (system: pkgs: let
      target = containerSystem system;
    in {
      "release:debug" = {
        type = "app";
        program = toString (mkReleaseScript pkgs target "debug");
      };
      "release:k8s" = {
        type = "app";
        program = toString (mkReleaseScript pkgs target "k8s");
      };
      release = {
        type = "app";
        program = toString (pkgs.writeShellScript "release-all" ''
          set -euo pipefail
          ${mkReleaseScript pkgs target "debug"}
          ${mkReleaseScript pkgs target "k8s"}
        '');
      };
    });
  };
}
