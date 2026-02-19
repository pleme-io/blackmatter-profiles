# profiles/debug — Base shell debug environment
#
# The foundation profile. Everything a developer needs for debugging
# in a container: full blzsh tool suite + baseline Unix utilities + git.
# No domain-specific tools (kubectl, cargo, etc.) — compose those in other profiles.
#
# Image: ghcr.io/pleme-io/blackmatter-debug
# Usage: kubectl run debug --image=ghcr.io/pleme-io/blackmatter-debug:latest --rm -it --restart=Never
{ pkgs, lib, blzsh }:
let
  mkImage = import ../../lib/base-image.nix { inherit pkgs lib blzsh; };
in
mkImage {
  name = "ghcr.io/pleme-io/blackmatter-debug";
}
