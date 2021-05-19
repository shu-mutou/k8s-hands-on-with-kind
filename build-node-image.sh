#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd ${DIR}

usage() {
  echo "Usage: $0  [-s <source code directory>] [-b <branch>]" 1>&2
  exit 1
}

while getopts :s:b:h OPT
do
  case $OPT in
    s) K8S_SRC=$OPTARG ;;
    b) K8S_BRANCH=$OPTARG ;;
    h) usage ;;
    \?) usage ;;
  esac
done
# Configs
GOPATH=${GOPATH:-"${HOME}/go"}
K8S_SRC=${K8S_SRC:-"${GOPATH}/src/github.com/kubernetes/kubernetes/"}
K8S_BRANCH=${K8S_BRANCH:-"master"}

LOG_LEVEL=${LOG_LEVEL:-"5"}

# Setup
TMP_DIR="${DIR}/tmp"
mkdir -p ${TMP_DIR}

TOOL_DIR="${DIR}/tools"
mkdir -p ${TOOL_DIR}
KIND_BIN="${TOOL_DIR}/kind"
KUBECTL_BIN="${TOOL_DIR}/kubectl-${K8S_BRANCH}"

# Checkout targeted kubernetes branch
cd ${K8S_SRC}
git fetch -t
git checkout -b ${K8S_BRANCH} ${K8S_BRANCH}

# Build container image for targeted kubernetes branch.
# Also, all of kubernetes components that include kubectl were built.
cd ${DIR}
${KIND_BIN} build node-image ${K8S_SRC} --image kindest/node:${K8S_BRANCH} -v ${LOG_LEVEL}

# Copy built kubectl
ARCH=$(uname | awk '{print tolower($0)}')
cp -f "${K8S_SRC}/_output/dockerized/bin/${ARCH}/amd64/kubectl" ${KUBECTL_BIN}

# Create symbolic link for kubectl
# Also, create kind config using specified version of kindest/node
./switch.sh kubectl ${K8S_BRANCH}
./switch.sh kindest ${K8S_BRANCH}

# Gather info
KIND_INFO="$(${KIND_BIN} version)"
KUBECTL_INFO="$(${KUBECTL_BIN} version)"
KINDEST_INFO="$(docker images|grep kindest|grep ${K8S_BRANCH})"

# Reports
cat <<EOF

!!! following kind was used !!!

kind info:
${KIND_INFO}"

!!! kubectl was built as ${KUBECTL_INFO} !!!

kubectl info:
${KUBECTL_INFO}"

!!! kindest/node image was built as kindest/node:${K8S_BRANCH} !!!

kindest/node image info:
${KINDEST_INFO}

EOF
