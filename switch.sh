#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd ${DIR}

usage() {
  echo "Usage: $0 <kind|kubectl|kindest> <version>" 1>&2
  exit 1
}

if [ $# -ne 2 ]; then
  usage
fi

APP=$1
VER=$2

if [ $APP = "kind" ] || [ $APP = "kubectl" ]; then
  # Re-create symbolic link
  TOOL_DIR="${DIR}/tools"
  rm -fr ${TOOL_DIR}/${APP}
  ln -s ./${APP}-${VER} ${TOOL_DIR}/${APP}
else
  # Create temporary directory
  TMP_DIR="${DIR}/tmp"
  mkdir -p ${TMP_DIR}

  # Create directory for persistent volume
  PV_PATH="${DIR}/volume"
  mkdir -p ${PV_PATH}

  # Create config file for kind cluster
  KIND_CONFIG="${TMP_DIR}/kind.yaml"
  cat <<EOF > ${KIND_CONFIG}
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: kind-cluster
nodes:
- role: control-plane
  image: kindest/node:${VER}
  extraMounts:
  - hostPath: ${PV_PATH}
    containerPath: /volume
  extraPortMappings:
  - containerPort: 30000
    hostPort: 30000
  - containerPort: 30001
    hostPort: 30001
  - containerPort: 30002
    hostPort: 30002
  - containerPort: 30003
    hostPort: 30003
  - containerPort: 30004
    hostPort: 30004
  - containerPort: 30080
    hostPort: 30080
  - containerPort: 30443
    hostPort: 30443
- role: worker
  extraMounts:
  - hostPath: ${PV_PATH}
    containerPath: /volume
- role: worker
  extraMounts:
  - hostPath: ${PV_PATH}
    containerPath: /volume
EOF

fi
