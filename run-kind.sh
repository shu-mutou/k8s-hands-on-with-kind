#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd ${DIR}

KIND_VERSION="v0.10.0"
# Select kubernetes version for kind from https://github.com/kubernetes-sigs/kind/releases
KIND_NODE_VERSION="v1.20.2@sha256:8f7ea6e7642c0da54f04a7ee10431549c0257315b3a634f6ef2fecaaedb19bab"
KUBECTL_VERSION=${KUBECTL_VERSION:-"$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)"}

CLUSTER_NAME="kind-cluster"

TOOL_DIR="${DIR}/tools"
KIND_BIN="${TOOL_DIR}/kind"
KUBECTL_BIN="${TOOL_DIR}/kubectl"
KUBE_DIR="${DIR}/xube"
KUBECONFIG="${KUBE_DIR}/config"
KUBE_CACHE="${KUBE_DIR}/cache"
KUBECTL_SH="${DIR}/kubectl.sh"
PV_PATH="${DIR}/volume"

TMP_DIR="${DIR}/tmp"
mkdir -p ${TMP_DIR}

# Download kind and kubectl
mkdir -p ${TOOL_DIR}
ARCH=$(uname | awk '{print tolower($0)}')
KIND_URL="https://github.com/kubernetes-sigs/kind/releases/download/${KIND_VERSION}/kind-${ARCH}-amd64"
wget -nc -O ${KIND_BIN} ${KIND_URL}
chmod +x ${KIND_BIN}
${KIND_BIN} version

KUBECTL_URL="https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/${ARCH}/amd64/kubectl"
wget -nc -O ${KUBECTL_BIN} ${KUBECTL_URL}
chmod +x ${KUBECTL_BIN}

# Create directory for persistent volume
mkdir -p ${PV_PATH}

# Create config file for kind cluster
KIND_YAML="${TMP_DIR}/kind.yaml"
cat <<EOF > ${KIND_YAML}
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: ${CLUSTER_NAME}
nodes:
- role: control-plane
  image: kindest/node:${KIND_NODE_VERSION}
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

# Re-create cluster with kind
${KIND_BIN} delete cluster --name=${CLUSTER_NAME}
${KIND_BIN} create cluster --config=${KIND_YAML}

# Get kubeconfig
mkdir -p ${KUBE_CACHE}
${KIND_BIN} get kubeconfig --name=${CLUSTER_NAME} > ${KUBECONFIG}

# Create kubectl.sh
cat <<EOF > ${KUBECTL_SH}
#!/bin/bash

${KUBECTL_BIN} --kubeconfig ${KUBECONFIG} --cache-dir ${KUBE_CACHE} \${@}
EOF
chmod +x ${KUBECTL_SH}

# Current context is "kind" + ${CLUSTER_NAME}
${KUBECTL_SH} version
${KUBECTL_SH} cluster-info --context kind-${CLUSTER_NAME}

# Deploy Kubernetes Dashboard
${KUBECTL_SH} apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/aio/deploy/alternative.yaml
${KUBECTL_SH} delete service kubernetes-dashboard -n kubernetes-dashboard
KD_SERVICE=${TMP_DIR}/kd-service.yaml
cat <<EOF > ${KD_SERVICE}
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard-cluster-admin
  namespace: kubernetes-dashboard
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: kubernetes-dashboard
    namespace: kubernetes-dashboard

---

kind: Service
apiVersion: v1
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard
  namespace: kubernetes-dashboard
spec:
  type: NodePort
  ports:
    - port: 80
      targetPort: 9090
      nodePort: 30000
  selector:
    k8s-app: kubernetes-dashboard
EOF
${KUBECTL_SH} apply -f ${KD_SERVICE}

# Get token for dashboard login
SECRET_NAME=$(${KUBECTL_SH} -n kubernetes-dashboard get sa kubernetes-dashboard -ojsonpath="{.secrets[0].name}")
KD_TOKEN=$(${KUBECTL_SH} -n kubernetes-dashboard get secrets ${SECRET_NAME} -o=jsonpath='{.data.token}' | base64 -d)
echo ${KD_TOKEN} > "${KUBE_DIR}/kd-token"

# Finish
cat <<EOF
Kubernetes cluster is ready to use.

"kubectl" and "kind" is downloaded in "${TOOL_DIR}"
"kubeconfig" and cache directory for "kubectl" is created in "${KUBE_DIR}"

Instead of "kubectl", use "./kubectl.sh" that configured to use above settings.

TCP Ports "30001-30004" can be mapped to "NodePort" Services or Ingress Controllers .

The port "30000" is mapped to Kubernetes Dashboard.
You can access dashboard with "http://localhost:30000/#/login" and login using following token:

${KD_TOKEN}

Also, token is stored in "${KUBE_DIR}".
!!! THIS TOKEN HAS cluster-admin ROLE, SO IT CAN DO ANYTHING !!!

The ports "30080" and "30443" are kept for Ingress controller.

Directory for volumes is created at "${PV_PATH}".
Create sub-directories under above and use them for "PersistentVolume" with "storageClassName: standard" or container volumes with path "/volume".

!!! THIS CLUSTER IS NOT SECURE                   !!!
!!! DO NOT EXPOSE THIS CLUSTER TO PUBLIC NETWORK !!!
!!! DO NOT USE THIS CLUSTER FOR PRODUCTION       !!!

EOF
