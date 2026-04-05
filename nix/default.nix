# Shared Nix module for Brute agent deployments.
#
# Provides:
#   - Ruby + bundler for running the agent
#   - k3d + kubectl + helm for local Kubernetes
#   - Convenience scripts: k3d-up, k3d-down, k3d-load, brute-deploy, brute-undeploy
#   - Docker image building via dockerTools
#
# Usage as a flake input:
#
#   inputs.brute-nix.url = "path:../../nix";
#
#   Then in outputs:
#     let brute = brute-nix.lib.${system}; in { ... }
#
{ pkgs }:

let
  clusterName = "brute";

  k3d-up = pkgs.writeShellScriptBin "k3d-up" ''
    if ! command -v docker &> /dev/null || ! docker info &> /dev/null 2>&1; then
      echo "error: Docker is not running" >&2
      exit 1
    fi

    if ${pkgs.k3d}/bin/k3d cluster list 2>/dev/null | grep -q "${clusterName}"; then
      echo "Cluster '${clusterName}' already exists"
      ${pkgs.kubectl}/bin/kubectl config use-context k3d-${clusterName}
      exit 0
    fi

    echo "Creating k3d cluster '${clusterName}'..."
    ${pkgs.k3d}/bin/k3d cluster create ${clusterName} \
      --wait \
      --timeout 120s \
      --agents 1 \
      --k3s-arg "--disable=traefik@server:0" \
      --port "9292:9292@loadbalancer" \
      --port "9293:9293@loadbalancer"

    ${pkgs.kubectl}/bin/kubectl wait \
      --for=condition=Ready nodes --all \
      --timeout=120s

    echo "Cluster '${clusterName}' is ready"
  '';

  k3d-down = pkgs.writeShellScriptBin "k3d-down" ''
    ${pkgs.k3d}/bin/k3d cluster delete ${clusterName} 2>/dev/null
    echo "Cluster '${clusterName}' deleted"
  '';

  k3d-load = pkgs.writeShellScriptBin "k3d-load" ''
    if [ -z "$1" ]; then
      echo "Usage: k3d-load <image:tag>"
      exit 1
    fi
    ${pkgs.k3d}/bin/k3d image import "$1" --cluster ${clusterName}
    echo "Loaded $1 into cluster '${clusterName}'"
  '';

  k3d-status = pkgs.writeShellScriptBin "k3d-status" ''
    echo "=== Cluster ==="
    ${pkgs.k3d}/bin/k3d cluster list 2>/dev/null
    echo
    echo "=== Nodes ==="
    ${pkgs.kubectl}/bin/kubectl get nodes 2>/dev/null || echo "(not running)"
    echo
    echo "=== Pods ==="
    ${pkgs.kubectl}/bin/kubectl get pods -A 2>/dev/null || echo "(not running)"
  '';

  brute-deploy = pkgs.writeShellScriptBin "brute-deploy" ''
    DEPLOYMENT=''${1:-deployment.yaml}
    if [ ! -f "$DEPLOYMENT" ]; then
      echo "error: $DEPLOYMENT not found" >&2
      echo "Usage: brute-deploy [deployment.yaml]" >&2
      exit 1
    fi

    echo "Building Docker image..."
    docker build -t brute-local:latest .

    echo "Loading image into k3d..."
    ${pkgs.k3d}/bin/k3d image import brute-local:latest --cluster ${clusterName}

    echo "Applying $DEPLOYMENT..."
    ${pkgs.kubectl}/bin/kubectl apply -f "$DEPLOYMENT"

    echo "Waiting for rollout..."
    DEPLOY_NAME=$(grep -m1 'name:' "$DEPLOYMENT" | awk '{print $2}')
    ${pkgs.kubectl}/bin/kubectl rollout status deployment/"$DEPLOY_NAME" --timeout=120s 2>/dev/null

    echo
    echo "=== Pods ==="
    ${pkgs.kubectl}/bin/kubectl get pods
    echo
    echo "=== Services ==="
    ${pkgs.kubectl}/bin/kubectl get svc
  '';

  brute-undeploy = pkgs.writeShellScriptBin "brute-undeploy" ''
    DEPLOYMENT=''${1:-deployment.yaml}
    if [ ! -f "$DEPLOYMENT" ]; then
      echo "error: $DEPLOYMENT not found" >&2
      exit 1
    fi
    ${pkgs.kubectl}/bin/kubectl delete -f "$DEPLOYMENT"
    echo "Removed resources from $DEPLOYMENT"
  '';

  brute-logs = pkgs.writeShellScriptBin "brute-logs" ''
    LABEL=''${1:-app=brute-agent}
    ${pkgs.kubectl}/bin/kubectl logs -l "$LABEL" -f --all-containers
  '';

  shellPackages = [
    pkgs.ruby_3_4
    pkgs.bundler
    pkgs.openssl
    pkgs.ripgrep
    pkgs.git
    pkgs.bash
    pkgs.docker
    pkgs.k3d
    pkgs.kubectl
    pkgs.kubernetes-helm
    k3d-up
    k3d-down
    k3d-load
    k3d-status
    brute-deploy
    brute-undeploy
    brute-logs
  ];

  shellHook = ''
    export BUNDLE_PATH=vendor/bundle
    bundle install --quiet 2>/dev/null

    echo ""
    echo "Brute development environment"
    echo ""
    echo "  Ruby:    $(ruby --version | cut -d' ' -f2)"
    echo "  k3d:     $(${pkgs.k3d}/bin/k3d version | head -1 | awk '{print $3}')"
    echo "  kubectl: $(${pkgs.kubectl}/bin/kubectl version --client -o json 2>/dev/null | grep gitVersion | awk -F'"' '{print $4}')"
    echo ""
    echo "  k3d-up          Create local k3d cluster"
    echo "  k3d-down        Destroy local k3d cluster"
    echo "  k3d-load IMG    Import Docker image into cluster"
    echo "  k3d-status      Show cluster, nodes, and pods"
    echo "  brute-deploy    Build, load, and apply deployment.yaml"
    echo "  brute-undeploy  Remove deployed resources"
    echo "  brute-logs      Tail pod logs"
    echo ""
  '';

in
{
  inherit
    shellPackages
    shellHook
    k3d-up
    k3d-down
    k3d-load
    k3d-status
    brute-deploy
    brute-undeploy
    brute-logs
    clusterName;
}
