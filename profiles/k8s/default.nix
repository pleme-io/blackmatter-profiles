# profiles/k8s — Kubernetes debug environment
#
# Extends the debug profile with Kubernetes tooling for cluster introspection,
# GitOps debugging, and infrastructure troubleshooting from inside the cluster.
#
# Image: ghcr.io/pleme-io/blackmatter-k8s
# Usage:
#   # Interactive debug pod
#   kubectl run debug --image=ghcr.io/pleme-io/blackmatter-k8s:latest --rm -it --restart=Never
#
#   # Ephemeral container in an existing pod's namespace (shares PID/net)
#   kubectl debug -it <pod> --image=ghcr.io/pleme-io/blackmatter-k8s:latest --target=<container>
#
#   # Debug a node directly
#   kubectl debug node/<node-name> -it --image=ghcr.io/pleme-io/blackmatter-k8s:latest
{ pkgs, lib, blzsh }:
let
  mkImage = import ../../lib/base-image.nix { inherit pkgs lib blzsh; };
in
mkImage {
  name = "ghcr.io/pleme-io/blackmatter-k8s";
  extraContents = with pkgs; [
    kubectl # Kubernetes CLI
    kubernetes-helm # Helm package manager
    fluxcd # FluxCD CLI for GitOps inspection
    k9s # Terminal UI for Kubernetes
    stern # Multi-pod log tailing
  ];
  extraEnv = [
    # Default kubeconfig location — mount a secret here in K8s
    "KUBECONFIG=/root/.kube/config"
  ];
  extraCommands = ''
    # kubectl completion goes here if needed
    mkdir -p root/.kube
  '';
  extraLabels = {
    "org.opencontainers.image.description" = "Blackmatter K8s debug environment — shell + kubectl + helm + flux + k9s";
  };
}
