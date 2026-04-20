#!/usr/bin/env bash
# ============================================================
#  teardown.sh - Destroy the Chaos Engineering Sandbox
# ============================================================
#  Soft teardown (default): Removes experiments, apps, and Helm releases.
#  Hard teardown (--hard): Deletes the kind cluster entirely.
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }

CLUSTER_NAME="chaos-sandbox"
HARD_MODE=false

if [[ "${1:-}" == "--hard" ]]; then
  HARD_MODE=true
fi

if [ "$HARD_MODE" = false ]; then
  info "Performing SOFT teardown (leaving cluster running). Use --hard to delete the cluster."
else
  warn "Performing HARD teardown (cluster will be deleted)."
fi

# ── 1. Delete active chaos experiments ──────────────────────
info "Cleaning up chaos experiments..."
if kubectl get -f "${ROOT_DIR}/experiments/" &>/dev/null; then
  kubectl delete -f "${ROOT_DIR}/experiments/" --ignore-not-found
  ok "Experiments cleaned."
else
  warn "No active experiments found - skipping."
fi

# ── 2. Delete mock target application ───────────────────────
info "Removing mock-target application..."
if kubectl get -n mock-app deployment/mock-target &>/dev/null; then
  kubectl delete -f "${ROOT_DIR}/apps/mock-target/deployment.yaml"
  kubectl delete -f "${ROOT_DIR}/apps/mock-target/service.yaml"
  ok "Mock-target removed."
else
  warn "Mock-target application not found - skipping."
fi

# ── 3. Uninstall Chaos Mesh ─────────────────────────────────
info "Uninstalling Chaos Mesh..."
helm uninstall chaos-mesh --namespace chaos-mesh 2>/dev/null || warn "Chaos Mesh release not found - skipping."

# ── 4. Uninstall kube-prometheus-stack ──────────────────────
info "Uninstalling kube-prometheus-stack..."
helm uninstall kube-prometheus-stack --namespace monitoring 2>/dev/null || warn "Prometheus release not found - skipping."

# Remove CRDs left behind by the prometheus stack
info "Removing Prometheus CRDs..."
kubectl delete crd --ignore-not-found \
  alertmanagerconfigs.monitoring.coreos.com \
  alertmanagers.monitoring.coreos.com \
  podmonitors.monitoring.coreos.com \
  probes.monitoring.coreos.com \
  prometheusagents.monitoring.coreos.com \
  prometheuses.monitoring.coreos.com \
  prometheusrules.monitoring.coreos.com \
  scrapeconfigs.monitoring.coreos.com \
  servicemonitors.monitoring.coreos.com \
  thanosrulers.monitoring.coreos.com 2>/dev/null || true

# ── 5. Delete the kind cluster (HARD MODE ONLY) ─────────────
if [ "$HARD_MODE" = true ]; then
  if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    info "Deleting kind cluster '${CLUSTER_NAME}'..."
    kind delete cluster --name "${CLUSTER_NAME}"
    ok "Cluster '${CLUSTER_NAME}' deleted."
  else
    warn "Kind cluster '${CLUSTER_NAME}' not found - skipping."
  fi
else
  info "Skipping kind cluster deletion (soft teardown)."
fi

echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN} Sandbox teardown complete.${NC}"
echo -e "${GREEN}============================================================${NC}"
