# Shared Nix module for Brute agent deployments.
#
# Provides:
#   - Ruby + bundler for running the agent
#   - k3d + kubectl + helm for local Kubernetes
#   - kubectl wrapper that automatically uses the k3d kubeconfig
#   - Single `cluster` command: cluster {up,down,status,redeploy,undeploy,load,logs,forward}
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
  kubeconfigPath = "/tmp/k3d-${clusterName}-kubeconfig.yaml";

  # kubectl wrapper — automatically uses the k3d kubeconfig.
  kubectl = pkgs.writeShellScriptBin "kubectl" ''
    if [ -f "${kubeconfigPath}" ]; then
      exec env KUBECONFIG="${kubeconfigPath}" ${pkgs.kubectl}/bin/kubectl "$@"
    else
      echo "No k3d kubeconfig found. Run: cluster up" >&2
      exit 1
    fi
  '';

  cluster = pkgs.writeShellScriptBin "cluster" ''
    K3D="${pkgs.k3d}/bin/k3d"
    KUBECTL="env KUBECONFIG=${kubeconfigPath} ${pkgs.kubectl}/bin/kubectl"
    CLUSTER="${clusterName}"
    KUBECONFIG_FILE="${kubeconfigPath}"

    wait_for_pods() {
      echo "Waiting for pods..."
      while [ -z "$($KUBECTL get pods -A --no-headers 2>/dev/null)" ]; do
        sleep 2
      done

      $KUBECTL get events -A --watch-only 2>/dev/null &
      EVENTS_PID=$!

      while true; do
        TOTAL=$($KUBECTL get pods -A --no-headers 2>/dev/null | wc -l)
        READY=$($KUBECTL get pods -A --no-headers 2>/dev/null | grep -c "Running\|Completed" || true)
        echo "  pods: $READY/$TOTAL ready"
        if [ "$TOTAL" -gt 0 ] && [ "$READY" -eq "$TOTAL" ]; then
          break
        fi
        sleep 3
      done

      kill $EVENTS_PID 2>/dev/null
      wait $EVENTS_PID 2>/dev/null
    }

    deploy_app() {
      DEPLOYMENT=''${1:-deployment.yaml}
      if [ ! -f "$DEPLOYMENT" ]; then
        return 0
      fi

      echo ""
      echo "Building Docker image..."
      if ! docker build -t brute-local:latest .; then
        echo "warning: Docker build failed, skipping deploy" >&2
        return 1
      fi

      echo "Loading image into k3d..."
      $K3D image import brute-local:latest --cluster $CLUSTER

      if [ -n "''${LLM_API_KEY:-}" ]; then
        echo "Creating secret from LLM_API_KEY..."
        $KUBECTL create secret generic brute-secrets \
          --namespace=brute \
          --from-literal=llm-api-key="$LLM_API_KEY" \
          --from-literal=llm-provider="''${LLM_PROVIDER:-anthropic}" \
          --dry-run=client -o yaml | $KUBECTL apply -f -
      else
        echo "note: LLM_API_KEY not set — pods will boot but LLM calls will fail until the secret is created"
      fi

      echo "Applying $DEPLOYMENT..."
      $KUBECTL apply -f "$DEPLOYMENT"

      sleep 2
      $KUBECTL logs -f -l app --namespace=brute --all-containers --ignore-errors 2>/dev/null &
      LOG_PID=$!

      echo "Waiting for rollout (timeout: 90s)..."
      DEPLOY_NAME=$(grep -A1 'kind: Deployment' "$DEPLOYMENT" | grep 'name:' | head -1 | awk '{print $2}')
      if [ -n "$DEPLOY_NAME" ]; then
        $KUBECTL rollout status deployment/"$DEPLOY_NAME" --namespace=brute --timeout=90s 2>/dev/null || echo "warning: rollout not ready within 90s"
      fi

      kill $LOG_PID 2>/dev/null
      wait $LOG_PID 2>/dev/null
    }

    cmd_up() {
      if ! command -v docker &> /dev/null || ! docker info &> /dev/null 2>&1; then
        echo "error: Docker is not running" >&2
        exit 1
      fi

      if $K3D cluster list 2>/dev/null | grep -q "$CLUSTER"; then
        echo "Cluster '$CLUSTER' already exists"
        $K3D kubeconfig get $CLUSTER > "$KUBECONFIG_FILE" 2>/dev/null
        $KUBECTL config set-context --current --namespace=brute 2>/dev/null
        echo "kubectl configured"
        exit 0
      fi

      echo "Creating k3d cluster '$CLUSTER'..."
      $K3D cluster create $CLUSTER \
        --wait \
        --timeout 120s \
        --agents 0 \
        --no-lb \
        --k3s-arg "--disable=traefik@server:0" \
        --k3s-arg "--disable=metrics-server@server:0"

      $K3D kubeconfig get $CLUSTER > "$KUBECONFIG_FILE" 2>/dev/null

      echo "Waiting for nodes..."
      $KUBECTL wait --for=condition=Ready nodes --all --timeout=120s 2>/dev/null

      wait_for_pods

      echo "Creating namespace 'brute'..."
      $KUBECTL create namespace brute 2>/dev/null || true
      $KUBECTL config set-context --current --namespace=brute 2>/dev/null

      deploy_app "$@"

      echo ""
      $KUBECTL get pods -A
      echo ""
      $KUBECTL get svc --namespace=brute 2>/dev/null
      echo ""
      echo "Cluster '$CLUSTER' is ready"
    }

    cmd_down() {
      $K3D cluster delete $CLUSTER 2>/dev/null
      rm -f "$KUBECONFIG_FILE"
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
      echo
      echo "=== Services ==="
      $KUBECTL get svc --namespace=brute 2>/dev/null || echo "(none)"
    }

    cmd_redeploy() {
      deploy_app "$@"
      echo ""
      $KUBECTL get pods --namespace=brute
      echo ""
      $KUBECTL get svc --namespace=brute 2>/dev/null
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
      LABEL=''${1:-app}
      $KUBECTL logs -l "$LABEL" --namespace=brute -f --all-containers --tail=-1
    }

    cmd_forward() {
      SVC=''${1:-brute-agent}
      LOCAL_PORT=''${2:-9292}
      REMOTE_PORT=''${3:-80}
      echo "Forwarding localhost:$LOCAL_PORT -> svc/$SVC:$REMOTE_PORT"
      $KUBECTL port-forward svc/$SVC --namespace=brute $LOCAL_PORT:$REMOTE_PORT
    }

    cmd_help() {
      echo "Usage: cluster <command> [args]"
      echo ""
      echo "Commands:"
      echo "  up [file]                      Create cluster and deploy (default: deployment.yaml)"
      echo "  down                           Destroy cluster"
      echo "  status                         Show cluster, nodes, pods, services"
      echo "  redeploy [file]                Rebuild and redeploy without recreating cluster"
      echo "  undeploy [file]                Remove deployed resources"
      echo "  load <image>                   Import Docker image into cluster"
      echo "  logs [label]                   Tail pod logs (default: app)"
      echo "  forward [svc] [local] [remote] Port-forward a service (default: brute-agent 9292 80)"
      echo "  help                           Show this help"
      echo ""
      echo "Environment:"
      echo "  LLM_API_KEY                    API key (injected as k8s secret)"
      echo "  LLM_PROVIDER                   Provider name (default: anthropic)"
    }

    COMMAND="$1"
    shift 2>/dev/null || true

    case "$COMMAND" in
      up)       cmd_up "$@" ;;
      down)     cmd_down "$@" ;;
      status)   cmd_status "$@" ;;
      redeploy) cmd_redeploy "$@" ;;
      undeploy) cmd_undeploy "$@" ;;
      load)     cmd_load "$@" ;;
      logs)     cmd_logs "$@" ;;
      forward)  cmd_forward "$@" ;;
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
    kubectl
    pkgs.kubernetes-helm
    cluster
  ];

  shellHook = ''
    export BUNDLE_PATH=vendor/bundle
    bundle install --quiet 2>/dev/null

    if ${pkgs.k3d}/bin/k3d cluster list 2>/dev/null | grep -q "${clusterName}"; then
      ${pkgs.k3d}/bin/k3d kubeconfig get ${clusterName} > ${kubeconfigPath} 2>/dev/null
      env KUBECONFIG=${kubeconfigPath} ${pkgs.kubectl}/bin/kubectl config set-context --current --namespace=brute 2>/dev/null
      CLUSTER_STATUS="connected (namespace: brute)"
    else
      CLUSTER_STATUS="not running (run: cluster up)"
    fi

    echo ""
    echo "Brute development environment"
    echo ""
    echo "  Ruby:    $(ruby --version | cut -d' ' -f2)"
    echo "  k3d:     $(${pkgs.k3d}/bin/k3d version | head -1 | awk '{print $3}')"
    echo "  cluster: $CLUSTER_STATUS"
    echo ""
    echo "  cluster up|down|status|redeploy|undeploy|load|logs|forward|help"
    echo ""
  '';

in
{
  inherit shellPackages shellHook cluster kubectl clusterName kubeconfigPath;
}
