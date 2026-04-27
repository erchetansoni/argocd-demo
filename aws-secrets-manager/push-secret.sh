#!/bin/bash

set -euo pipefail

########## Variables ##########################################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${ENV_FILE:-${SCRIPT_DIR}/.env}"
SECRETS_FILE="${SECRETS_FILE:-${SCRIPT_DIR}/aws-secrets}"

AWS_REGION="ap-south-1"
SECRET_NAME="argocd-demo/app-secrets"
SECRET_DESCRIPTION="Secrets for the Argo CD KIND demo apps"
KMS_KEY_ID=""

SECRETS_JSON=""
CREATE_SECRET_ARGS=()

if [ ! -f "${ENV_FILE}" ]; then
  echo "❌ Missing env file: ${ENV_FILE}"
  echo "   Copy aws-secrets-manager/.env.example to aws-secrets-manager/.env and add AWS credentials."
  exit 1
fi

if [ ! -f "${SECRETS_FILE}" ]; then
  echo "❌ Missing secrets file: ${SECRETS_FILE}"
  echo "   Create aws-secrets-manager/aws-secrets with simple KEY=value pairs."
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

if ! command -v jq >/dev/null 2>&1; then
  echo "❌ jq is not installed or not on PATH"
  exit 1
fi

SECRETS_JSON=$(jq -Rn '
  reduce inputs as $line ({};
    ($line | sub("\r$"; "")) as $clean |
    if ($clean | test("^\\s*$|^\\s*#")) then
      .
    else
      ($clean | capture("^\\s*(?<key>[A-Za-z_][A-Za-z0-9_]*)\\s*=\\s*(?<value>.*)\\s*$")) as $item |
      .[$item.key] = $item.value
    end
  )
' "${SECRETS_FILE}")

if [ "${SECRETS_JSON}" = "{}" ]; then
  echo "❌ No secrets found in ${SECRETS_FILE}"
  exit 1
fi

export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY
export AWS_SESSION_TOKEN="${AWS_SESSION_TOKEN:-}"
export AWS_DEFAULT_REGION="${AWS_REGION}"

echo "🔐 Pushing secret '${SECRET_NAME}' to AWS Secrets Manager in region '${AWS_REGION}'..."

if aws secretsmanager describe-secret \
  --secret-id "${SECRET_NAME}" \
  --region "${AWS_REGION}" >/dev/null 2>&1; then
  aws secretsmanager put-secret-value \
    --secret-id "${SECRET_NAME}" \
    --secret-string "${SECRETS_JSON}" \
    --region "${AWS_REGION}" >/dev/null

  echo "✅ Updated existing secret: ${SECRET_NAME}"
else
  CREATE_SECRET_ARGS=(
    --name "${SECRET_NAME}"
    --description "${SECRET_DESCRIPTION}"
    --secret-string "${SECRETS_JSON}"
    --region "${AWS_REGION}"
  )

  if [ -n "${KMS_KEY_ID}" ]; then
    CREATE_SECRET_ARGS+=(--kms-key-id "${KMS_KEY_ID}")
  fi

  aws secretsmanager create-secret "${CREATE_SECRET_ARGS[@]}" >/dev/null
  echo "✅ Created new secret: ${SECRET_NAME}"
fi
