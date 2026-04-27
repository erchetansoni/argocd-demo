#!/bin/bash

set -euo pipefail

########## Variables ##########################################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${ENV_FILE:-${SCRIPT_DIR}/.env}"

AWS_REGION="ap-south-1"
ENV_SECRET_NAME="argocd-demo/app-secrets"
FILE_SECRET_NAME="argocd-demo/app-secret-file"

# Set to false if you want AWS Secrets Manager recovery window behavior.
FORCE_DELETE_WITHOUT_RECOVERY="true"

########## 🧹 Delete AWS Secrets Manager Secrets ##############################
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

if ! command -v aws >/dev/null 2>&1; then
  echo "❌ aws CLI is not installed or not on PATH"
  exit 1
fi

export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY
export AWS_SESSION_TOKEN="${AWS_SESSION_TOKEN:-}"
export AWS_DEFAULT_REGION="${AWS_REGION}"

delete_secret() {
  local secret_name="$1"

  echo "🔎 Checking AWS secret '${secret_name}'..."
  if ! aws secretsmanager describe-secret \
    --secret-id "${secret_name}" \
    --region "${AWS_REGION}" >/dev/null 2>&1; then
    echo "ℹ️  Secret not found, skipping: ${secret_name}"
    return 0
  fi

  echo "🧹 Deleting AWS secret '${secret_name}'..."
  if [ "${FORCE_DELETE_WITHOUT_RECOVERY}" = "true" ]; then
    aws secretsmanager delete-secret \
      --secret-id "${secret_name}" \
      --force-delete-without-recovery \
      --region "${AWS_REGION}" >/dev/null
  else
    aws secretsmanager delete-secret \
      --secret-id "${secret_name}" \
      --region "${AWS_REGION}" >/dev/null
  fi

  echo "✅ Delete requested for: ${secret_name}"
}

delete_secret "${ENV_SECRET_NAME}"
delete_secret "${FILE_SECRET_NAME}"

echo "✅ AWS secret cleanup complete."
