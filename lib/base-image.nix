# lib/base-image.nix
#
# Shared base for all shell profile container images.
# Every profile gets: blzsh (full tool closure) + baseline Unix utilities
# for broad script/tooling compatibility + proper SSL + standard dir layout.
#
# Usage:
#   let mkImage = import ../../lib/base-image.nix { inherit pkgs lib blzsh; };
#   in mkImage {
#     name = "ghcr.io/pleme-io/blackmatter-debug";
#     extraContents = [ pkgs.kubectl ];
#     extraEnv = [ "KUBECONFIG=/root/.kube/config" ];
#   }
{ pkgs, lib, blzsh }:
{
  name,
  tag ? "latest",
  extraContents ? [],
  extraEnv ? [],
  extraCommands ? "",
  extraLabels ? {},
}:
pkgs.dockerTools.buildLayeredImage {
  inherit name tag;

  # blzsh closure already includes: bat eza fd rg zoxide fzf delta dust procs
  # bottom sd tokei hyperfine tealdeer xh jaq ouch hexyl choose difftastic vivid
  # mdcat pastel grex macchina onefetch bandwhich trippy gping just watchexec
  # miniserve yazi direnv nix-direnv starship zsh blnvim (gitui on Linux)
  #
  # We add baseline POSIX utilities that scripts and tools rely on having at
  # their standard flag syntax (find -name, grep -E, etc.) — distinct from
  # the Rust replacements in blzsh which have different interfaces.
  contents =
    [ blzsh ]
    ++ (with pkgs; [
      bashInteractive # /bin/bash for fallback sessions and scripting
      coreutils # ls cp mv rm chmod chown env date etc
      findutils # find xargs (POSIX flags — not fd)
      gnugrep # grep (POSIX flags — not rg)
      gnutar # tar
      gzip # gzip/gunzip
      git # version control — essential in any debug environment
      curl # HTTP client — wider script compatibility than xh
      openssh # ssh client for remote debugging
      cacert # SSL certificates
      pkgs.dockerTools.fakeNss # /etc/passwd and /etc/group for root
    ])
    ++ extraContents;

  extraCommands = ''
    # Standard directories
    mkdir -p root tmp
    chmod 1777 tmp

    # /bin symlinks so tooling that hardcodes /bin/bash or /bin/sh works
    mkdir -p bin
    ln -s ${pkgs.bashInteractive}/bin/bash bin/bash
    ln -s ${pkgs.bashInteractive}/bin/bash bin/sh
    ln -s ${blzsh}/bin/blzsh bin/blzsh

    # /usr/bin/env is required by many shebang lines
    mkdir -p usr/bin
    ln -s ${pkgs.coreutils}/bin/env usr/bin/env

    ${extraCommands}
  '';

  config = {
    Cmd = [ "/bin/blzsh" ];
    WorkingDir = "/root";
    Env =
      [
        "HOME=/root"
        "USER=root"
        "TERM=xterm-256color"
        "COLORTERM=truecolor"
        "LANG=C.UTF-8"
        "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
        "GIT_SSL_CAINFO=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
        "CURL_CA_BUNDLE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      ]
      ++ extraEnv;
    Labels =
      {
        "org.opencontainers.image.source" = "https://github.com/pleme-io/blackmatter-profiles";
        "org.opencontainers.image.description" = "Blackmatter shell profile — ${name}";
        "org.opencontainers.image.licenses" = "MIT";
      }
      // extraLabels;
  };
}
