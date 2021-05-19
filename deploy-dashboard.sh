#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd ${DIR}

usage() {
  echo "Usage: $0 [-p <dashboard service node port>]" 1>&2
  exit 1
}

while getopts :i:h OPT
do
  case $OPT in
    p) KD_NODE_PORT=$OPTARG ;;
    h) usage ;;
    \?) usage ;;
  esac
done

# Configs
${KD_NODE_PORT:-"30000"}

# Setup
KUBECTL_SH="${DIR}/kubectl.sh"
TMP_DIR="${DIR}/tmp"
mkdir -p ${TMP_DIR}

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
      nodePort: ${KD_NODE_PORT}
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

!!! Kubernetes Dashboard is ready to use !!!

The port "${KD_NODE_PORT}" was mapped to Kubernetes Dashboard.
You can access dashboard with "http://localhost:${KD_NODE_PORT}/#/login" and login using following token:

${KD_TOKEN}

Also, token was stored in "${KUBE_DIR}".
!!! THIS TOKEN HAS cluster-admin ROLE, SO IT CAN DO ANYTHING !!!
!!! TAKE CARE OF HANDLING THIS TOKEN                         !!!

EOF
