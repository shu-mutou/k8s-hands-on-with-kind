#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd ${DIR}

usage() {
  echo "Usage: $0 [-c <kind config file>] [-x <do not deploy dashboard>]" 1>&2
  exit 1
}

while getopts :i:xh OPT
do
  case $OPT in
    c) KIND_CONFIG=$OPTARG ;;
    x) IGNORE_DASHBOARD=1 ;;
    h) usage ;;
    \?) usage ;;
  esac
done

# Configs
TMP_DIR="./tmp"
KIND_CONFIG=${KIND_CONFIG:-"${TMP_DIR}/kind.yaml"}

# Setup
TOOL_DIR="${DIR}/tools"
KIND_BIN="${TOOL_DIR}/kind"
KUBECTL_BIN="${TOOL_DIR}/kubectl"
PV_PATH="${DIR}/volume"

# Re-create working directory for kubectl
KUBECTL_SH="${DIR}/kubectl.sh"
mkdir -p ${TMP_DIR}
KUBECONFIG="${TMP_DIR}/config"
KUBE_CACHE="${TMP_DIR}/cache"
mkdir -p ${KUBE_CACHE}

# Re-create cluster with kind
${KIND_BIN} delete cluster --name=kind-cluster
${KIND_BIN} create cluster --config=${KIND_CONFIG}

# Get kubeconfig
${KIND_BIN} get kubeconfig --name=kind-cluster > ${KUBECONFIG}

# Create kubectl.sh
cat <<EOF > ${KUBECTL_SH}
#!/bin/bash

${KUBECTL_BIN} --kubeconfig ${KUBECONFIG} --cache-dir ${KUBE_CACHE} \${@}
EOF
chmod +x ${KUBECTL_SH}

# Gather info
KIND_INFO="$(${KIND_BIN} version)"
KUBECLT_INFO="$(${KUBECTL_SH} version)"
CLUSTER_INFO="$(${KUBECTL_SH} cluster-info --context kind-kind-cluster)"

# Reports
cat <<EOF

!!! Kubernetes cluster is ready to use !!!

kind info:
${KIND_INFO}"

cluster info:
${CLUSTER_INFO}

kubectl info:
${KUBECTL_INFO}

"kubeconfig" and cache directory for "kubectl" is created in "${TMP_DIR}"

Instead of "kubectl" in ${TOOL_DIR}, use "./kubectl.sh" that configured to use above "kubeconfig".

TCP ports "30001-30004" can be mapped to "NodePort" Services.
TCP ports "30080" and "30443" are kept for Ingress controller.
TCP ports "30000" is kept for Kubernetes Dashboard.

Directory for volumes is created at "${PV_PATH}".
Create sub-directories under above and use them for "PersistentVolume" with "storageClassName: standard" or container volumes with path "/volume".

!!! THIS CLUSTER IS NOT SECURE                   !!!
!!! DO NOT EXPOSE THIS CLUSTER TO PUBLIC NETWORK !!!
!!! DO NOT USE THIS CLUSTER FOR PRODUCTION       !!!

EOF

# Deploy Kubernetes Dashboard
IGNORE_DASHBOARD=${IGNORE_DASHBOARD:-0}
if [ ! ${IGNORE_DASHBOARD} -eq 1 ]; then
  ./deploy-dashboard.sh
fi
