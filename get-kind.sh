#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd ${DIR}

usage() {
  echo "Usage: $0 [-i <kind version>] [-n <kindest/node version>]" 1>&2
  exit 1
}

while getopts :i:h OPT
do
  case $OPT in
    i) KIND_VERSION=$OPTARG ;;
    n) KINDEST_VERSION=$OPTARG ;;
    h) usage ;;
    \?) usage ;;
  esac
done

# Configs
KIND_VERSION=${KIND_VERSION:-"$(curl -s -I https://github.com/kubernetes-sigs/kind/releases/latest | grep ^location | grep -oP 'v\d+\.\d+\.\d+')"}
KINDEST_TAG=${KINDEST_TAG:-"$(curl -s https://registry.hub.docker.com/v2/repositories/kindest/node/tags | jq -r .results[0].name)"}
KINDEST_DIGEST=${KINDEST_DIGEST:-"$(curl -s https://registry.hub.docker.com/v2/repositories/kindest/node/tags | jq -r .results[0].digest)"}
KINDEST_VERSION=${KINDEST_VERSION:-"${KINDEST_TAG}@${KINDEST_DIGEST}"}

# Setup
TOOL_DIR="${DIR}/tools"
mkdir -p ${TOOL_DIR}

KIND_BIN="${TOOL_DIR}/kind-${KIND_VERSION}"

KUBECTL_VERSION=${KUBECTL_VERSION:-"$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)"}
KUBECTL_BIN="${TOOL_DIR}/kubectl-${KUBECTL_VERSION}"

# Download kind and kubectl
ARCH=$(uname | awk '{print tolower($0)}')
KIND_URL="https://github.com/kubernetes-sigs/kind/releases/download/${KIND_VERSION}/kind-${ARCH}-amd64"
wget -nc -O ${KIND_BIN} ${KIND_URL}
chmod +x ${KIND_BIN}

KUBECTL_URL="https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/${ARCH}/amd64/kubectl"
wget -nc -O ${KUBECTL_BIN} ${KUBECTL_URL}
chmod +x ${KUBECTL_BIN}

# Create symbolic link for kind and kubectl
# Also, create kind config using specified version of kindest/node
${DIR}/switch.sh kind ${KIND_VERSION}
${DIR}/switch.sh kubectl ${KUBECTL_VERSION}
${DIR}/switch.sh kindest ${KINDEST_VERSION}

# Gather info
KIND_INFO="$(${KIND_BIN} version)"
KUBECTL_INFO="$(${KUBECTL_BIN} version)"

# Reports
cat <<EOF

!!! kind was downloaded as ${KIND_BIN} !!!

kind info:
${KIND_INFO}"

!!! kubectl was downloaded as ${KUBECTL_BIN} !!!

kubectl info:
${KUBECTL_INFO}

EOF
