#!/bin/bash

set -euo pipefail

########## Variables ##########################################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${ENV_FILE:-${SCRIPT_DIR}/.env}"

NAMESPACE="external-secrets"
K8S_SECRET_NAME="aws-secretsmanager-credentials"
CLUSTER_STORE_NAME="aws-secretsmanager"
AWS_REGION="ap-south-1"

ACCESS_KEY_FIELD="access-key"
SECRET_ACCESS_KEY_FIELD="secret-access-key"
SESSION_TOKEN_FIELD="session-token"

########## Create K8s Secret + ClusterSecretStore #############################
if [ ! -f "${ENV_FILE}" ]; then
  echo "❌ Missing env file: ${ENV_FILE}"
  echo "   Copy aws-secrets-manager/.env.example to aws-secrets-manager/.env and add AWS credentials."
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "${ENV_FILE}"
set +a

if [ -z "${AWS_ACCESS_KEY_ID:-}" ]; then
  echo "❌ AWS_ACCESS_KEY_ID is required in ${ENV_FILE}"
  exit 1
fi

if [ -z "${AWS_SECRET_ACCESS_KEY:-}" ]; then
  echo "❌ AWS_SECRET_ACCESS_KEY is required in ${ENV_FILE}"
  exit 1
fi

echo "🔑 Creating Kubernetes Secret '${K8S_SECRET_NAME}' in namespace '${NAMESPACE}'..."
kubectl create secret generic "${K8S_SECRET_NAME}" \
  --namespace "${NAMESPACE}" \
  --from-literal="${ACCESS_KEY_FIELD}=${AWS_ACCESS_KEY_ID}" \
  --from-literal="${SECRET_ACCESS_KEY_FIELD}=${AWS_SECRET_ACCESS_KEY}" \
  --from-literal="${SESSION_TOKEN_FIELD}=${AWS_SESSION_TOKEN:-}" \
  --dry-run=client \
  -o yaml | kubectl apply -f -

echo "🔗 Applying ClusterSecretStore '${CLUSTER_STORE_NAME}'..."
cat <<EOF | kubectl apply -f -
apiVersion: external-secrets.io/v1
kind: ClusterSecretStore
metadata:
  name: ${CLUSTER_STORE_NAME}
spec:
  provider:
    aws:
      service: SecretsManager
      region: ${AWS_REGION}
      auth:
        secretRef:
          accessKeyIDSecretRef:
            name: ${K8S_SECRET_NAME}
            key: ${ACCESS_KEY_FIELD}
            namespace: ${NAMESPACE}
          secretAccessKeySecretRef:
            name: ${K8S_SECRET_NAME}
            key: ${SECRET_ACCESS_KEY_FIELD}
            namespace: ${NAMESPACE}
          sessionTokenSecretRef:
            name: ${K8S_SECRET_NAME}
            key: ${SESSION_TOKEN_FIELD}
            namespace: ${NAMESPACE}
EOF

echo "✅ ClusterSecretStore '${CLUSTER_STORE_NAME}' ready — usable from any namespace."
