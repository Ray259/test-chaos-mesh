#!/usr/bin/env bash
# ============================================================
#  setup.sh - Bootstrap the Chaos Engineering Sandbox
# ============================================================
#  Creates a kind cluster, deploys the observability stack,
#  installs Chaos Mesh, and deploys the mock target application.
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# ── Colour helpers ──────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ── Pre-flight checks ──────────────────────────────────────
for cmd in docker kind kubectl helm; do
  command -v "$cmd" &>/dev/null || err "'$cmd' is not installed. Please install it first."
done

CLUSTER_NAME="chaos-sandbox"
KIND_CONFIG="${ROOT_DIR}/infrastructure/cluster/kind-config.yaml"

# ── 1. Create kind cluster ─────────────────────────────────
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
  warn "Kind cluster '${CLUSTER_NAME}' already exists - skipping creation."
else
  info "Creating kind cluster '${CLUSTER_NAME}'..."
  kind create cluster --config "${KIND_CONFIG}" --wait 120s
  ok "Cluster '${CLUSTER_NAME}' created."
fi

kubectl cluster-info --context "kind-${CLUSTER_NAME}"

# ── 2. Create namespaces ───────────────────────────────────
info "Creating namespaces..."
kubectl create namespace monitoring   --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace mock-app     --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace chaos-mesh   --dry-run=client -o yaml | kubectl apply -f -
ok "Namespaces ready."

# ── 3. Deploy mock applications ─────────────────────────────
info "Deploying mock applications (target + db)..."
kubectl apply -f "${ROOT_DIR}/apps/mock-target/deployment.yaml"
kubectl apply -f "${ROOT_DIR}/apps/mock-target/service.yaml"
kubectl apply -f "${ROOT_DIR}/apps/mock-db/deployment.yaml"

kubectl rollout status deployment/mock-target -n mock-app --timeout=120s
kubectl rollout status deployment/mock-db -n mock-app --timeout=120s
ok "Applications deployed."

# ── 4. Install kube-prometheus-stack ────────────────────────
info "Adding Prometheus Community Helm repo..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo update

info "Installing kube-prometheus-stack..."
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values "${ROOT_DIR}/infrastructure/observability/prometheus-values.yaml" \
  --wait --timeout 15m
ok "kube-prometheus-stack installed."

# ── 5. Install Chaos Mesh ──────────────────────────────────
info "Adding Chaos Mesh Helm repo..."
helm repo add chaos-mesh https://charts.chaos-mesh.org 2>/dev/null || true
helm repo update

info "Installing Chaos Mesh..."
helm upgrade --install chaos-mesh chaos-mesh/chaos-mesh \
  --namespace chaos-mesh \
  --values "${ROOT_DIR}/infrastructure/chaos-mesh/values.yaml" \
  --version 2.7.0 \
  --wait --timeout 15m
ok "Chaos Mesh installed."

# ── 6. Apply CRD-dependent resources ───────────────────────
info "Applying ServiceMonitors and NetworkPolicies..."
kubectl apply -f "${ROOT_DIR}/apps/mock-db/servicemonitor.yaml"
kubectl apply -f "${ROOT_DIR}/infrastructure/network-policies/deny-cross-namespace.yaml"
ok "Resources applied."

# ── 7. Summary ──────────────────────────────────────────────
echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN} Chaos Engineering Sandbox is READY!${NC}"
echo -e "${GREEN}============================================================${NC}"
echo ""
info "Access points (from host):"
echo "  • Prometheus   → http://localhost:30090"
echo "  • Grafana      → http://localhost:30030  (admin / admin)"
echo "  • Alertmanager → http://localhost:30093"
echo "  • Mock App     → http://localhost:30080"
echo "  • Chaos Mesh   → http://localhost:31333"
echo ""
info "To inject chaos, run:"
echo "  kubectl apply -f ${ROOT_DIR}/experiments/network-loss-chaos.yaml"
echo "  kubectl apply -f ${ROOT_DIR}/experiments/io-chaos-db.yaml"
echo "  kubectl apply -f ${ROOT_DIR}/experiments/pod-kill-db.yaml"
echo "  kubectl apply -f ${ROOT_DIR}/experiments/security-chaos.yaml"

echo ""
info "To tear everything down, run:"
echo "  ${SCRIPT_DIR}/teardown.sh"