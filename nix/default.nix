# Shared Nix module for Brute agent deployments.
#
# Provides:
#   - Ruby + bundler for running the agent
#   - k3d + kubectl + helm for local Kubernetes
#   - Single `cluster` command: cluster {up,down,load,status,deploy,undeploy,logs}
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

  cluster = pkgs.writeShellScriptBin "cluster" ''
    K3D="${pkgs.k3d}/bin/k3d"
    KUBECTL="${pkgs.kubectl}/bin/kubectl"
    CLUSTER="${clusterName}"

    cmd_up() {
      if ! command -v docker &> /dev/null || ! docker info &> /dev/null 2>&1; then
        echo "error: Docker is not running" >&2
        exit 1
      fi

      if $K3D cluster list 2>/dev/null | grep -q "$CLUSTER"; then
        echo "Cluster '$CLUSTER' already exists"
        $KUBECTL config use-context k3d-$CLUSTER
        exit 0
      fi

      echo "Creating k3d cluster '$CLUSTER'..."
      $K3D cluster create $CLUSTER \
        --wait \
        --timeout 120s \
        --agents 1 \
        --k3s-arg "--disable=traefik@server:0" \
        --port "9292:9292@loadbalancer" \
        --port "9293:9293@loadbalancer"

      $KUBECTL wait --for=condition=Ready nodes --all --timeout=120s
      echo "Cluster '$CLUSTER' is ready"
    }

    cmd_down() {
      $K3D cluster delete $CLUSTER 2>/dev/null
      echo "Cluster '$CLUSTER' deleted"
    }

    cmd_load() {
      if [ -z "$1" ]; then
        echo "Usage: cluster load <image:tag>"
        exit 1
      fi
      $K3D image import "$1" --cluster $CLUSTER
      echo "Loaded $1 into cluster '$CLUSTER'"
    }

    cmd_status() {
      echo "=== Cluster ==="
      $K3D cluster list 2>/dev/null
      echo
      echo "=== Nodes ==="
      $KUBECTL get nodes 2>/dev/null || echo "(not running)"
      echo
      echo "=== Pods ==="
      $KUBECTL get pods -A 2>/dev/null || echo "(not running)"
    }

    cmd_deploy() {
      DEPLOYMENT=''${1:-deployment.yaml}
      if [ ! -f "$DEPLOYMENT" ]; then
        echo "error: $DEPLOYMENT not found" >&2
        echo "Usage: cluster deploy [deployment.yaml]" >&2
        exit 1
      fi

      echo "Building Docker image..."
      docker build -t brute-local:latest .

      echo "Loading image into k3d..."
      $K3D image import brute-local:latest --cluster $CLUSTER

      echo "Applying $DEPLOYMENT..."
      $KUBECTL apply -f "$DEPLOYMENT"

      echo "Waiting for rollout..."
      DEPLOY_NAME=$(grep -m1 'name:' "$DEPLOYMENT" | awk '{print $2}')
      $KUBECTL rollout status deployment/"$DEPLOY_NAME" --timeout=120s 2>/dev/null

      echo
      echo "=== Pods ==="
      $KUBECTL get pods
      echo
      echo "=== Services ==="
      $KUBECTL get svc
    }

    cmd_undeploy() {
      DEPLOYMENT=''${1:-deployment.yaml}
      if [ ! -f "$DEPLOYMENT" ]; then
        echo "error: $DEPLOYMENT not found" >&2
        exit 1
      fi
      $KUBECTL delete -f "$DEPLOYMENT"
      echo "Removed resources from $DEPLOYMENT"
    }

    cmd_logs() {
      LABEL=''${1:-app=brute-agent}
      $KUBECTL logs -l "$LABEL" -f --all-containers
    }

    cmd_help() {
      echo "Usage: cluster <command> [args]"
      echo ""
      echo "Commands:"
      echo "  up              Create local k3d cluster"
      echo "  down            Destroy local k3d cluster"
      echo "  load <image>    Import Docker image into cluster"
      echo "  status          Show cluster, nodes, and pods"
      echo "  deploy [file]   Build, load, and apply deployment.yaml"
      echo "  undeploy [file] Remove deployed resources"
      echo "  logs [label]    Tail pod logs (default: app=brute-agent)"
      echo "  help            Show this help"
    }

    COMMAND="$1"
    shift 2>/dev/null || true

    case "$COMMAND" in
      up)       cmd_up "$@" ;;
      down)     cmd_down "$@" ;;
      load)     cmd_load "$@" ;;
      status)   cmd_status "$@" ;;
      deploy)   cmd_deploy "$@" ;;
      undeploy) cmd_undeploy "$@" ;;
      logs)     cmd_logs "$@" ;;
      help|-h|--help) cmd_help ;;
      "")       cmd_help ;;
      *)        echo "Unknown command: $COMMAND"; cmd_help; exit 1 ;;
    esac
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
    cluster
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
    echo "  cluster up|down|load|status|deploy|undeploy|logs|help"
    echo ""
  '';

in
{
  inherit shellPackages shellHook cluster clusterName;
}
