#!/usr/bin/env bash
# ==========================================================
#  ShieldOps Cluster Bootstrap — v5.9.2 (AWS-Optimized, Full Edition)
#  Includes: Jenkins, Kubernetes, Helm, Docker, Flannel, Ingress,
#  Trivy, OWASP ZAP, Bandit, Safety, CodeQL, CycloneDX, sync_project, RESET
# ==========================================================

set -euo pipefail

# ---- Default Config ----
K8S_VERSION="${K8S_VERSION:-v1.31.3}"
CNI_CIDR="${CNI_CIDR:-10.244.0.0/16}"
HELM_RELEASE="${HELM_RELEASE:-shieldops}"
NAMESPACE="${NAMESPACE:-shieldops}"
JOIN_FILE="${JOIN_FILE:-/tmp/kubeadm_join.txt}"
CRI_SOCKET="${CRI_SOCKET:-/run/containerd/containerd.sock}"
FLANNEL_VERSION="${FLANNEL_VERSION:-v0.25.5}"
HELM_VERSION="${HELM_VERSION:-v3.16.3}"
ODC_CACHE_DIR="/tmp/odc-data"
PYTHON_VENV="/opt/shieldops-venv"
PROJECT_DIR="${PROJECT_DIR:-${HOME}/ShieldOps}"

# ---- Derived ----
K8S_CHANNEL="$(printf '%s\n' "${K8S_VERSION#v}" | awk -F. '{print $1 "." $2}')"
DOMAIN="$(hostname -I 2>/dev/null | awk '{print $1}')"
PUBLIC_IP="$(curl -4s --max-time 2 http://checkip.amazonaws.com || true)"
[[ -n "${PUBLIC_IP}" ]] || PUBLIC_IP="${DOMAIN:-127.0.0.1}"

# ---- Helpers ----
require_root() { [[ $EUID -eq 0 ]] || { echo "ERROR: Run with sudo/root privileges"; exit 1; }; }
cmd_exists() { command -v "$1" >/dev/null 2>&1; }
ok() { echo -e "\033[32m[OK]\033[0m $*"; }
log() { echo -e "\033[34m[INFO]\033[0m $*"; }
warn() { echo -e "\033[33m[WARN]\033[0m $*"; }

# ==========================================================
#  🧩 REGISTRY SETUP FROM USER ARG
# ==========================================================
set_registry_user() {
  local username="${1:-}"
  if [[ -z "$username" ]]; then
    echo -e "\n❌ ERROR: Missing Docker Hub username."
    echo "Usage: sudo ./shieldops-cluster-bootstrap.sh --master <dockerhub_username>"
    echo "Example: sudo ./shieldops-cluster-bootstrap.sh --master gauravchile"
    exit 1
  fi

  IMAGE_REGISTRY="docker.io/${username}/shieldops"
  export IMAGE_REGISTRY
  DOCKER_USER="${username}"
  export DOCKER_USER
  log "Using Docker Registry: ${IMAGE_REGISTRY}"
}

# ==========================================================
#  🔁 SYNC PROJECT FILES
# ==========================================================
sync_project() {
    local DIR="${PROJECT_DIR}"
    local REGISTRY="${IMAGE_REGISTRY}"

    echo "[info] REGISTRY = ${REGISTRY}"

    if [[ -z "$REGISTRY" ]]; then
        echo "❌ REGISTRY not provided for sync_project"
        exit 1
    fi

    if [[ -d "${DIR}" ]]; then
        echo "[info] Updating files in ${DIR} with REGISTRY=${REGISTRY}"

        find "${DIR}" -type f \( \
            -name "*.yaml" -o \
            -name "*.yml" -o \
            -name "Makefile" -o \
            -name "*.sh" -o \
            -name "Jenkinsfile" \
        \) -print0 | \
        xargs -0 sed -i "s|\${REGISTRY}|${REGISTRY}|g"

        echo "✅ sync_project completed successfully"
    else
        echo "[warn] Directory not found: ${DIR}; skipping file updates"
    fi
}

# ==========================================================
#  SMART TOOL DETECTION
# ==========================================================
tools_already_installed() {
  local tools=("docker" "kubectl" "helm" "trivy" "zap" "codeql" "node" "python3")
  local all_found=true
  for t in "${tools[@]}"; do
    if ! cmd_exists "$t"; then
      all_found=false
      break
    fi
  done
  $all_found
}

# ==========================================================
#  SYSTEM & TOOL INSTALLS
# ==========================================================
configure_containerd() {
  log "Configuring containerd runtime..."
  mkdir -p /etc/containerd
  if [[ ! -s /etc/containerd/config.toml ]]; then
    containerd config default | tee /etc/containerd/config.toml >/dev/null
  fi
  sed -i 's#sandbox_image = .*#sandbox_image = "registry.k8s.io/pause:3.10"#' /etc/containerd/config.toml || true
  sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml || true
  systemctl daemon-reload
  systemctl enable --now containerd
  ok "containerd configured"
}

install_docker() {
  if cmd_exists docker; then ok "Docker already installed"; return; fi
  log "Installing Docker Engine..."
  apt-get update -y && apt-get install -y docker.io
  systemctl enable --now docker
  configure_containerd
  ok "Docker & containerd ready"
}

install_kubernetes() {
  if cmd_exists kubectl && cmd_exists kubeadm; then ok "Kubernetes already installed"; return; fi
  log "Installing Kubernetes ${K8S_VERSION}..."
  curl -fsSL "https://pkgs.k8s.io/core:/stable:/v${K8S_CHANNEL}/deb/Release.key" | gpg --dearmor -o /usr/share/keyrings/k8s.gpg
  echo "deb [signed-by=/usr/share/keyrings/k8s.gpg] https://pkgs.k8s.io/core:/stable:/v${K8S_CHANNEL}/deb/ /" > /etc/apt/sources.list.d/k8s.list
  apt-get update -y && apt-get install -y kubelet kubeadm kubectl
  apt-mark hold kubelet kubeadm kubectl
  ok "Kubernetes core tools ready"
}

install_flannel() {
  log "Applying Flannel CNI (${FLANNEL_VERSION})..."
  kubectl apply --validate=false -f "https://raw.githubusercontent.com/flannel-io/flannel/${FLANNEL_VERSION}/Documentation/kube-flannel.yml"
  kubectl -n kube-flannel wait --for=condition=Ready pod -l app=flannel --timeout=180s || true
  ok "Flannel installed"
}

install_ingress() {
  log "Installing NGINX Ingress Controller..."
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml
  kubectl wait --namespace ingress-nginx --for=condition=ready pod -l app.kubernetes.io/component=controller --timeout=180s || true
  ok "Ingress controller ready"
}

install_helm() {
  if cmd_exists helm; then ok "Helm already installed"; return; fi
  log "Installing Helm ${HELM_VERSION}..."
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  ok "Helm ready"
}

install_tools() {
  if tools_already_installed; then
    ok "All DevSecOps tools already installed — skipping reinstallation"
    return
  fi
  log "Installing DevSecOps Tools..."
  apt-get update -y
  apt-get install -y curl wget git unzip python3 python3-venv python3-pip jq
  mkdir -p ${ODC_CACHE_DIR}
  chmod 777 ${ODC_CACHE_DIR}
  if [ ! -d "${PYTHON_VENV}" ]; then
    python3 -m venv ${PYTHON_VENV}
  fi
  . ${PYTHON_VENV}/bin/activate
  python -m pip install --upgrade pip
  pip install bandit safety
  deactivate
  ok "Python environment ready"

  if ! cmd_exists node; then
    log "Installing Node.js 20.x..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs
  fi
  npm install -g @cyclonedx/bom || true
  ok "Node.js + CycloneDX ready"

  if ! cmd_exists trivy; then
    log "Installing Trivy..."
    wget -qO- https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor -o /usr/share/keyrings/trivy.gpg
    echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb stable main" > /etc/apt/sources.list.d/trivy.list
    apt-get update -y && apt-get install -y trivy
  fi

  if ! cmd_exists zap; then
    log "Installing OWASP ZAP..."
    mkdir -p /opt/zap && cd /opt/zap
    wget -q https://github.com/zaproxy/zaproxy/releases/download/v2.15.0/ZAP_2.15.0_Linux.tar.gz
    tar -xzf ZAP_2.15.0_Linux.tar.gz
    ln -sf /opt/zap/ZAP_2.15.0/zap.sh /usr/local/bin/zap
  fi

  if ! cmd_exists codeql; then
    log "Installing GitHub CodeQL..."
    mkdir -p /opt/codeql && cd /opt/codeql
    wget -q https://github.com/github/codeql-cli-binaries/releases/latest/download/codeql-linux64.zip
    unzip -qo codeql-linux64.zip
    ln -sf /opt/codeql/codeql /usr/local/bin/codeql
  fi

  install_helm
  ok "All DevSecOps tools installed"
}

# ==========================================================
#  RESET CLUSTER
# ==========================================================
reset_cluster() {
  log "⚠️ Resetting ShieldOps cluster and environment..."
  systemctl stop jenkins docker containerd || true
  kubeadm reset -f || true
  rm -rf /etc/kubernetes /var/lib/etcd /root/.kube /home/ubuntu/.kube || true
  helm uninstall ${HELM_RELEASE} -n ${NAMESPACE} || true
  kubectl delete ns ${NAMESPACE} ingress-nginx kube-flannel -A --ignore-not-found=true || true
  docker system prune -af || true
  rm -rf ${ODC_CACHE_DIR} ${PYTHON_VENV} /opt/codeql /opt/zap || true
  systemctl restart docker || true
  ok "Cluster and environment reset complete."
}

# ==========================================================
#  MASTER SETUP
# ==========================================================
init_master() {
  log "Initializing ShieldOps Master Node..."
  install_docker
  install_kubernetes
  kubeadm init --pod-network-cidr="${CNI_CIDR}" --cri-socket="unix://${CRI_SOCKET}" --upload-certs --v=5
  export KUBECONFIG=/etc/kubernetes/admin.conf
  mkdir -p /home/ubuntu/.kube
  cp /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
  chown ubuntu:ubuntu /home/ubuntu/.kube/config
  install_flannel
  kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true
  install_ingress
  install_jenkins
  install_tools
  sync_project
  kubeadm token create --print-join-command | tee ${JOIN_FILE}
  ok "Master setup complete; join command saved at ${JOIN_FILE}"

  echo -e "\n==========================================="
  echo -e "✅ ShieldOps Master Setup Complete!"
  echo -e " - Docker Registry: ${IMAGE_REGISTRY}"
  echo -e " - Docker Hub User: ${DOCKER_USER}"
  echo -e "===========================================\n"
}

# ==========================================================
#  MAIN ENTRY
# ==========================================================
main() {
  require_root
  local action="${1:-}"
  local username="${2:-}"

  case "${action}" in
    --master)
      set_registry_user "$username"
      install_tools
      sync_project
      init_master
      ;;
    --worker) join_worker ;;
    --deploy) sync_project; deploy_helm ;;
    --tools)  install_tools ;;
    --docker) sync_project; docker_build_push ;;
    --reset)  reset_cluster ;;
    *)
      echo "Usage: $0 [--master | --worker | --deploy | --tools | --docker | --reset] <dockerhub_username>"
      exit 1
      ;;
  esac

  ok "ShieldOps bootstrap completed successfully."
  echo -e "✅ ShieldOps ready for Docker Hub user: ${DOCKER_USER:-unknown}\n👉 Registry: ${IMAGE_REGISTRY:-unset}\n"
}

main "$@"
