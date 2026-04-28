#!/bin/bash

set -euo pipefail

########## Variables ##########################################################
ARGOCD_NAMESPACE="argocd"
ARGOCD_SERVER_DEPLOYMENT="argocd-server"
ARGOCD_HOST="argocd.chetan.com"
ARGOCD_MANIFEST_DIR="platform/argocd"
ARGOCD_INITIAL_ADMIN_SECRET="argocd-initial-admin-secret"

########## 🚀 Publish Argo CD #################################################
echo "🚀 Publishing Argo CD at http://${ARGOCD_HOST} ..."

if ! kubectl get namespace "${ARGOCD_NAMESPACE}" >/dev/null 2>&1; then
  echo "❌ Namespace '${ARGOCD_NAMESPACE}' does not exist. Install Argo CD first."
  exit 1
fi

if ! kubectl get deployment "${ARGOCD_SERVER_DEPLOYMENT}" -n "${ARGOCD_NAMESPACE}" >/dev/null 2>&1; then
  echo "❌ Deployment '${ARGOCD_SERVER_DEPLOYMENT}' was not found in namespace '${ARGOCD_NAMESPACE}'."
  exit 1
fi

if [ ! -d "${ARGOCD_MANIFEST_DIR}" ]; then
  echo "❌ Manifest directory not found: ${ARGOCD_MANIFEST_DIR}"
  exit 1
fi

kubectl apply -f "${ARGOCD_MANIFEST_DIR}"

echo "🔄 Restarting ${ARGOCD_SERVER_DEPLOYMENT} so server.insecure takes effect..."
kubectl rollout restart deployment "${ARGOCD_SERVER_DEPLOYMENT}" -n "${ARGOCD_NAMESPACE}"
kubectl rollout status deployment "${ARGOCD_SERVER_DEPLOYMENT}" -n "${ARGOCD_NAMESPACE}" --timeout=300s

echo "✅ Argo CD ingress is configured."
echo ""
echo "Add this to /etc/hosts if it is not already present:"
echo "127.0.0.1 ${ARGOCD_HOST}"
echo ""
echo "Open:"
echo "http://${ARGOCD_HOST}"
echo ""
echo "Username:"
echo "admin"
echo ""
echo "Password:"
if kubectl get secret "${ARGOCD_INITIAL_ADMIN_SECRET}" -n "${ARGOCD_NAMESPACE}" >/dev/null 2>&1; then
  kubectl get secret "${ARGOCD_INITIAL_ADMIN_SECRET}" \
    -n "${ARGOCD_NAMESPACE}" \
    -o jsonpath="{.data.password}" | base64 -d
  echo ""
else
  echo "Initial admin secret '${ARGOCD_INITIAL_ADMIN_SECRET}' was not found."
  echo "It may have been deleted after the password was changed."
fi
