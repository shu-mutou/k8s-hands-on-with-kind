#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd ${DIR}

TOOL_DIR="${DIR}/tools"
KIND_BIN="${TOOL_DIR}/kind"

# Shutdown cluster with kind
${KIND_BIN} delete cluster --name=kind-cluster
