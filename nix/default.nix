# Shared Nix module for Brute agent deployments.
#
# Provides:
#   - Ruby + bundler for running the agent
#   - k3d + kubectl + helm for local Kubernetes
#   - Convenience scripts: cluster-up, cluster-down, cluster-load, cluster-status,
#     cluster-deploy, cluster-undeploy, cluster-logs
#
# Usage as a flake input:
#
#   inputs.brute-nix.url = "github:general-intelligence-systems/brute_rack?dir=nix";
#
#   Then in outputs:
#     let brute = brute-nix.lib.${system}; in { ... }
#
{ pkgs }:

let
  clusterName = "brute";

  cluster-up = pkgs.writeShellScriptBin "cluster-up" ''
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

  cluster-down = pkgs.writeShellScriptBin "cluster-down" ''
    ${pkgs.k3d}/bin/k3d cluster delete ${clusterName} 2>/dev/null
    echo "Cluster '${clusterName}' deleted"
  '';

  cluster-load = pkgs.writeShellScriptBin "cluster-load" ''
    if [ -z "$1" ]; then
      echo "Usage: cluster-load <image:tag>"
      exit 1
    fi
    ${pkgs.k3d}/bin/k3d image import "$1" --cluster ${clusterName}
    echo "Loaded $1 into cluster '${clusterName}'"
  '';

  cluster-status = pkgs.writeShellScriptBin "cluster-status" ''
    echo "=== Cluster ==="
    ${pkgs.k3d}/bin/k3d cluster list 2>/dev/null
    echo
    echo "=== Nodes ==="
    ${pkgs.kubectl}/bin/kubectl get nodes 2>/dev/null || echo "(not running)"
    echo
    echo "=== Pods ==="
    ${pkgs.kubectl}/bin/kubectl get pods -A 2>/dev/null || echo "(not running)"
  '';

  cluster-deploy = pkgs.writeShellScriptBin "cluster-deploy" ''
    DEPLOYMENT=''${1:-deployment.yaml}
    if [ ! -f "$DEPLOYMENT" ]; then
      echo "error: $DEPLOYMENT not found" >&2
      echo "Usage: cluster-deploy [deployment.yaml]" >&2
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

  cluster-undeploy = pkgs.writeShellScriptBin "cluster-undeploy" ''
    DEPLOYMENT=''${1:-deployment.yaml}
    if [ ! -f "$DEPLOYMENT" ]; then
      echo "error: $DEPLOYMENT not found" >&2
      exit 1
    fi
    ${pkgs.kubectl}/bin/kubectl delete -f "$DEPLOYMENT"
    echo "Removed resources from $DEPLOYMENT"
  '';

  cluster-logs = pkgs.writeShellScriptBin "cluster-logs" ''
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
    cluster-up
    cluster-down
    cluster-load
    cluster-status
    cluster-deploy
    cluster-undeploy
    cluster-logs
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
    echo "  cluster-up        Create local k3d cluster"
    echo "  cluster-down      Destroy local k3d cluster"
    echo "  cluster-load IMG  Import Docker image into cluster"
    echo "  cluster-status    Show cluster, nodes, and pods"
    echo "  cluster-deploy    Build, load, and apply deployment.yaml"
    echo "  cluster-undeploy  Remove deployed resources"
    echo "  cluster-logs      Tail pod logs"
    echo ""
  '';

in
{
  inherit
    shellPackages
    shellHook
    cluster-up
    cluster-down
    cluster-load
    cluster-status
    cluster-deploy
    cluster-undeploy
    cluster-logs
    clusterName;
}
