#!/usr/bin/env bash
# ============================================================
#  start.sh - Start paused cluster containers
# ============================================================
set -euo pipefail

CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }

CLUSTER_NAME="chaos-sandbox"

info "Starting kind cluster containers for '${CLUSTER_NAME}'..."
CONTAINERS=$(docker ps -qa --filter "label=io.x-k8s.kind.cluster=${CLUSTER_NAME}")

if [ -z "$CONTAINERS" ]; then
    warn "No containers found for cluster '${CLUSTER_NAME}' - skipping. (Run setup.sh first)"
    exit 0
fi

docker start $CONTAINERS >/dev/null
ok "Cluster containers started successfully."

echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN} Access points (from host):${NC}"
echo -e "${GREEN}============================================================${NC}"
echo "  • Prometheus   → http://localhost:30090"
echo "  • Grafana      → http://localhost:30030  (admin / admin)"
echo "  • Alertmanager → http://localhost:30093"
echo "  • Mock App     → http://localhost:30080"
echo "  • Chaos Mesh   → http://localhost:31333"
echo ""
