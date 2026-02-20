{ pkgs }:
let
  # Shared runtime dependencies for all k8s diagnostic scripts
  commonDeps = with pkgs; [
    jq
    coreutils
  ];

  networkDeps = with pkgs; [
    dnsutils       # dig, nslookup
    netcat-openbsd # nc
    curl
    iproute2       # ip
  ];

  kenv = pkgs.writeShellApplication {
    name = "kenv";
    runtimeInputs = commonDeps;
    text = builtins.readFile ./k8s-scripts/kenv;
  };

  kservices = pkgs.writeShellApplication {
    name = "kservices";
    runtimeInputs = commonDeps;
    text = builtins.readFile ./k8s-scripts/kservices;
  };

  kdiag = pkgs.writeShellApplication {
    name = "kdiag";
    runtimeInputs = commonDeps ++ networkDeps ++ [ kservices ];
    text = builtins.readFile ./k8s-scripts/kdiag;
  };

  kcheck = pkgs.writeShellApplication {
    name = "kcheck";
    runtimeInputs = commonDeps ++ networkDeps;
    text = builtins.readFile ./k8s-scripts/kcheck;
  };

  k8s-banner = pkgs.writeShellApplication {
    name = "k8s-banner";
    runtimeInputs = commonDeps ++ networkDeps;
    text = builtins.readFile ./k8s-scripts/k8s-banner;
  };
in
pkgs.symlinkJoin {
  name = "k8s-scripts";
  paths = [ kenv kservices kdiag kcheck k8s-banner ];
}
