#!/bin/bash

set -euo pipefail

########## Variables ##########################################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PUSH_SECRET_ENV_SCRIPT="${SCRIPT_DIR}/push-secret-env.sh"
PUSH_SECRET_FILE_SCRIPT="${SCRIPT_DIR}/push-secret-file.sh"
CREATE_K8S_AWS_CREDENTIALS_SECRET_SCRIPT="${SCRIPT_DIR}/create-k8s-aws-credentials-secret.sh"

SCRIPTS_TO_RUN=(
  "${PUSH_SECRET_ENV_SCRIPT}"
  "${PUSH_SECRET_FILE_SCRIPT}"
  "${CREATE_K8S_AWS_CREDENTIALS_SECRET_SCRIPT}"
)

########## 🚀 Setup AWS Secrets For Demo ######################################
for script in "${SCRIPTS_TO_RUN[@]}"; do
  if [ ! -f "${script}" ]; then
    echo "❌ Required script not found: ${script}"
    exit 1
  fi

  chmod +x "${script}"
done

echo "🚀 Pushing env-style secret to AWS Secrets Manager..."
"${PUSH_SECRET_ENV_SCRIPT}"

echo "🚀 Pushing file-style secret to AWS Secrets Manager..."
"${PUSH_SECRET_FILE_SCRIPT}"

echo "🚀 Creating Kubernetes AWS credentials Secret for ESO..."
"${CREATE_K8S_AWS_CREDENTIALS_SECRET_SCRIPT}"

echo "✅ AWS Secrets Manager setup complete."
