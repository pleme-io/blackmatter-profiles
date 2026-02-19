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
  in {
    # Each profile is exposed as packages.<system>.<name>
    # Build:  nix build .#packages.x86_64-linux.debug
    # Run:    docker load < result && docker run --rm -it ghcr.io/pleme-io/blackmatter-debug:latest
    packages = forLinux (system: pkgs: {
      default = mkProfile "debug" system pkgs;
      debug = mkProfile "debug" system pkgs;
      k8s = mkProfile "k8s" system pkgs;
    });
  };
}
