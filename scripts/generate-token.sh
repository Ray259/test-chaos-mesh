#!/usr/bin/env bash
# ============================================================
#  generate-token.sh - Create RBAC and generate Dashboard token
# ============================================================
set -euo pipefail

CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

usage() {
    echo "Usage: $0 [manager|viewer] [namespace]"
    echo "Example: $0 manager default"
    exit 1
}

ROLE_TYPE=${1:-""}
NAMESPACE=${2:-"default"}

# Interactive selection if no role provided
if [[ -z "$ROLE_TYPE" ]]; then
    echo -e "${YELLOW}No role specified. Please choose a role:${NC}"
    echo "1) Manager (Full access to chaos resources)"
    echo "2) Viewer  (Read-only access)"
    read -p "Select [1-2]: " choice
    case $choice in
        1) ROLE_TYPE="manager" ;;
        2) ROLE_TYPE="viewer" ;;
        *) err "Invalid selection." ;;
    esac
fi

if [[ "$ROLE_TYPE" != "manager" && "$ROLE_TYPE" != "viewer" ]]; then
    usage
fi

SA_NAME="chaos-dashboard-$ROLE_TYPE"
ROLE_NAME="chaos-dashboard-$ROLE_TYPE-role"
BINDING_NAME="chaos-dashboard-$ROLE_TYPE-binding"

info "Generating $ROLE_TYPE token in namespace '$NAMESPACE'..."

# 1. Create ServiceAccount
kubectl create sa "$SA_NAME" -n "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# 2. Create Role
if [[ "$ROLE_TYPE" == "viewer" ]]; then
    verbs='["get", "list", "watch"]'
else
    verbs='["*"]'
fi

cat <<EOF | kubectl apply -f -
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  namespace: $NAMESPACE
  name: $ROLE_NAME
rules:
- apiGroups: [""]
  resources: ["pods", "namespaces"]
  verbs: ["get", "watch", "list"]
- apiGroups: ["chaos-mesh.org"]
  resources: ["*"]
  verbs: $verbs
EOF

# 3. Create RoleBinding
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: $BINDING_NAME
  namespace: $NAMESPACE
subjects:
- kind: ServiceAccount
  name: $SA_NAME
  namespace: $NAMESPACE
roleRef:
  kind: Role
  name: $ROLE_NAME
  apiGroup: rbac.authorization.k8s.io
EOF

# 4. Generate Token
info "Fetching token..."
TOKEN=$(kubectl create token "$SA_NAME" -n "$NAMESPACE")

echo -e "\n${GREEN}============================================================${NC}"
echo -e "${GREEN} TOKEN FOR $ROLE_TYPE ($NAMESPACE):${NC}"
echo -e "${GREEN}============================================================${NC}"
echo "$TOKEN"
echo -e "${GREEN}============================================================${NC}\n"
ok "Done."
