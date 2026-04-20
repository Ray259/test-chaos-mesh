#!/usr/bin/env bash
# ============================================================
#  stop.sh - Stop running cluster containers
# ============================================================
set -euo pipefail

CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }

CLUSTER_NAME="chaos-sandbox"

info "Stopping kind cluster containers for '${CLUSTER_NAME}'..."
CONTAINERS=$(docker ps -q --filter "label=io.x-k8s.kind.cluster=${CLUSTER_NAME}")

if [ -z "$CONTAINERS" ]; then
    warn "No running containers found for cluster '${CLUSTER_NAME}' - skipping."
    exit 0
fi

docker stop $CONTAINERS >/dev/null
ok "Cluster containers stopped successfully."
