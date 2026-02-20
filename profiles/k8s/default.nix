# profiles/k8s — Kubernetes debug environment
#
# The definitive K8s troubleshooting image: throw it into any pod network and
# have everything needed to diagnose issues, with first-class support for
# non-interactive use by Claude agents via kubectl exec or Kubernetes MCP.
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
#
#   # Full diagnostic (structured JSON — primary agent entry point)
#   kubectl exec <pod> -c debug -- kdiag
#
#   # Check a specific service
#   kubectl exec <pod> -c debug -- kcheck redis --json
{ pkgs, lib, blzsh }:
let
  mkImage = import ../../lib/base-image.nix { inherit pkgs lib blzsh; };
  k8sScripts = import ../../lib/k8s-scripts.nix { inherit pkgs; };
in
mkImage {
  name = "ghcr.io/pleme-io/blackmatter-k8s";
  extraContents = with pkgs; [
    # --- K8s CLI ---
    kubectl
    kubernetes-helm
    fluxcd
    k9s
    stern
    kubectl-tree
    kubectl-neat
    kubectx

    # --- Network diagnostics ---
    dnsutils        # dig, nslookup, host
    netcat-openbsd  # nc (BSD variant, more featureful)
    nmap
    tcpdump
    iproute2        # ip, ss
    iputils         # ping, tracepath
    mtr             # traceroute + ping combined
    socat           # multipurpose relay
    traceroute
    iperf3

    # --- Process debugging ---
    strace
    lsof
    htop
    util-linux      # lsns, nsenter, unshare, mount
    psmisc          # pstree, killall, fuser
    file

    # --- Database clients ---
    postgresql_16   # psql
    redis           # redis-cli

    # --- HTTP / API ---
    grpcurl
    websocat

    # --- Data processing ---
    jq
    yq-go

    # --- Diagnostic scripts ---
    k8sScripts
  ];
  extraEnv = [
    "KUBECONFIG=/root/.kube/config"
  ];
  extraCommands = ''
    mkdir -p root/.kube
    mkdir -p root/.config/shell/local.d

    # Startup banner — runs when entering an interactive shell inside k8s
    cat > root/.config/shell/local.d/k8s-motd.zsh << 'EOF'
if [[ -n "''${KUBERNETES_SERVICE_HOST:-}" && $- == *i* ]]; then
  k8s-banner 2>/dev/null || true
fi
EOF
  '';
  extraLabels = {
    "org.opencontainers.image.description" = "Blackmatter K8s debug environment — full diagnostic toolkit + agent-ready structured output";
  };
}
