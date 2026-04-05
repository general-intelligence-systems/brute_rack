# Shared Nix module for Brute agent deployments.
#
# Provides:
#   - Ruby + bundler for running the agent
#   - kubectl + helm for Kubernetes
#   - kubectl wrapper that automatically uses the cluster kubeconfig
#   - Single `cluster` command: cluster {up,down,status,redeploy,undeploy,load,logs,forward}
#   - k3s cluster image built via streamLayeredImage (no k3d dependency)
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
  containerName = "brute-k3s";
  kubeconfigPath = "/tmp/${clusterName}-kubeconfig.yaml";
  imageName = "brute-k3s:latest";

  # kubectl wrapper — automatically uses the cluster kubeconfig.
  kubectl = pkgs.writeShellScriptBin "kubectl" ''
    if [ -f "${kubeconfigPath}" ]; then
      exec env KUBECONFIG="${kubeconfigPath}" ${pkgs.kubectl}/bin/kubectl "$@"
    else
      echo "No cluster kubeconfig found. Run: cluster up" >&2
      exit 1
    fi
  '';

  cluster = pkgs.writeShellScriptBin "cluster" ''
    KUBECTL="env KUBECONFIG=${kubeconfigPath} ${pkgs.kubectl}/bin/kubectl"
    CONTAINER="${containerName}"
    KUBECONFIG_FILE="${kubeconfigPath}"
    IMAGE="${imageName}"
    NIX_DIR="$(dirname "$(readlink -f "$0")")/../../../nix"

    wait_for_k3s() {
      echo "Waiting for k3s..."
      local i=0
      while ! docker exec $CONTAINER kubectl get nodes 2>/dev/null | grep -q " Ready"; do
        i=$((i + 1))
        if [ $i -gt 60 ]; then
          echo "error: k3s failed to start within 120s" >&2
          docker logs $CONTAINER --tail 20 2>&1
          return 1
        fi
        sleep 2
      done
    }

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

      echo "Loading app image into k3s..."
      docker save brute-local:latest | docker exec -i $CONTAINER ctr images import -

      # Create secret from LLM_API_KEY env var
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

      # Stream pod logs during rollout
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

      # Check if container already exists
      if docker ps --format '{{.Names}}' | grep -q "^$CONTAINER$"; then
        echo "Cluster '$CONTAINER' already running"
        docker exec $CONTAINER cat /etc/rancher/k3s/k3s.yaml 2>/dev/null \
          | sed "s|127.0.0.1|127.0.0.1|" > "$KUBECONFIG_FILE"
        $KUBECTL config set-context --current --namespace=brute 2>/dev/null
        echo "kubectl configured"
        exit 0
      fi

      # Remove stopped container if it exists
      docker rm -f $CONTAINER 2>/dev/null

      # Build k3s image if not loaded
      if ! docker image inspect $IMAGE >/dev/null 2>&1; then
        echo "Building k3s cluster image (first time only)..."
        # Find the flake dir — walk up from the current dir looking for nix/flake.nix
        FLAKE_DIR=""
        CHECK_DIR="$PWD"
        while [ "$CHECK_DIR" != "/" ]; do
          if [ -f "$CHECK_DIR/nix/flake.nix" ]; then
            FLAKE_DIR="$CHECK_DIR/nix"
            break
          fi
          CHECK_DIR="$(dirname "$CHECK_DIR")"
        done

        if [ -z "$FLAKE_DIR" ]; then
          echo "error: Cannot find nix/flake.nix to build cluster image" >&2
          exit 1
        fi

        nix build "$FLAKE_DIR#cluster-image" --no-link --print-out-paths | xargs -I{} sh -c 'cat {} | docker load'
      fi

      echo "Starting k3s cluster..."
      docker run -d --privileged \
        --name $CONTAINER \
        -p 6443:6443 \
        $IMAGE

      wait_for_k3s || exit 1

      # Extract kubeconfig
      docker exec $CONTAINER cat /etc/rancher/k3s/k3s.yaml \
        | sed "s|127.0.0.1|127.0.0.1|" > "$KUBECONFIG_FILE"

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
      echo "Cluster is ready"
    }

    cmd_down() {
      docker rm -f $CONTAINER 2>/dev/null
      rm -f "$KUBECONFIG_FILE"
      echo "Cluster deleted"
    }

    cmd_load() {
      if [ -z "$1" ]; then
        echo "Usage: cluster load <image:tag>"
        exit 1
      fi
      docker save "$1" | docker exec -i $CONTAINER ctr images import -
      echo "Loaded $1 into cluster"
    }

    cmd_status() {
      echo "=== Container ==="
      docker ps --filter "name=$CONTAINER" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null
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
      $KUBECTL logs -l "$LABEL" --namespace=brute -f --all-containers
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
    kubectl
    pkgs.kubernetes-helm
    cluster
  ];

  shellHook = ''
    export BUNDLE_PATH=vendor/bundle
    bundle install --quiet 2>/dev/null

    # Write kubeconfig if cluster container is running
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${containerName}$"; then
      docker exec ${containerName} cat /etc/rancher/k3s/k3s.yaml 2>/dev/null \
        | sed "s|127.0.0.1|127.0.0.1|" > ${kubeconfigPath}
      env KUBECONFIG=${kubeconfigPath} ${pkgs.kubectl}/bin/kubectl config set-context --current --namespace=brute 2>/dev/null
      CLUSTER_STATUS="connected (namespace: brute)"
    else
      CLUSTER_STATUS="not running (run: cluster up)"
    fi

    echo ""
    echo "Brute development environment"
    echo ""
    echo "  Ruby:    $(ruby --version | cut -d' ' -f2)"
    echo "  cluster: $CLUSTER_STATUS"
    echo ""
    echo "  cluster up|down|status|redeploy|undeploy|load|logs|forward|help"
    echo ""
  '';

in
{
  inherit shellPackages shellHook cluster kubectl clusterName kubeconfigPath;
}
