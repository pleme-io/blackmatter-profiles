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
    self,
    nixpkgs,
    blackmatter-shell,
    blackmatter-nvim,
  }: let
    # Profiles are Linux-only — OCI containers always run on Linux
    linuxSystems = ["x86_64-linux" "aarch64-linux"];
    forLinux = f: nixpkgs.lib.genAttrs linuxSystems (system: f system nixpkgs.legacyPackages.${system});

    mkProfile = name: system: pkgs:
      import ./profiles/${name} {
        inherit pkgs;
        lib = nixpkgs.lib;
        blzsh = blackmatter-shell.packages.${system}.blzsh;
      };

    # Registry names for each profile
    profileRegistry = {
      debug = "ghcr.io/pleme-io/blackmatter-debug";
      k8s = "ghcr.io/pleme-io/blackmatter-k8s";
    };

    # Release script: skopeo copy from nix store tar → GHCR (no docker daemon needed)
    mkReleaseScript = system: pkgs: name: let
      image = mkProfile name system pkgs;
      registry = profileRegistry.${name};
    in
      pkgs.writeShellScript "release-${name}" ''
        set -euo pipefail
        SHORT_SHA=$(${pkgs.git}/bin/git rev-parse --short HEAD)
        echo "==> Releasing ${registry} (latest + $SHORT_SHA)"
        ${pkgs.skopeo}/bin/skopeo copy docker-archive:${image} docker://${registry}:latest
        ${pkgs.skopeo}/bin/skopeo copy docker-archive:${image} docker://${registry}:$SHORT_SHA
        echo "==> Done: ${registry}"
      '';
  in {
    # Each profile is exposed as packages.<system>.<name>
    # Build:  nix build .#packages.x86_64-linux.debug
    # Run:    docker load < result && docker run --rm -it ghcr.io/pleme-io/blackmatter-debug:latest
    packages = forLinux (system: pkgs: {
      default = mkProfile "debug" system pkgs;
      debug = mkProfile "debug" system pkgs;
      k8s = mkProfile "k8s" system pkgs;
    });

    # Release apps: build image + push to GHCR
    # Usage: nix run .#release          (all profiles)
    #        nix run .#release:debug    (debug only)
    #        nix run .#release:k8s      (k8s only)
    apps = forLinux (system: pkgs: {
      "release:debug" = {
        type = "app";
        program = toString (mkReleaseScript system pkgs "debug");
      };
      "release:k8s" = {
        type = "app";
        program = toString (mkReleaseScript system pkgs "k8s");
      };
      release = {
        type = "app";
        program = toString (pkgs.writeShellScript "release-all" ''
          set -euo pipefail
          ${mkReleaseScript system pkgs "debug"}
          ${mkReleaseScript system pkgs "k8s"}
        '');
      };
    });
  };
}
