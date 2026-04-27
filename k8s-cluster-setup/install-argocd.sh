#!/bin/bash

########## 🎯 Install ArgoCD ###########################
echo "🎯 Installing ArgoCD..."
# Variables
ARGOCD_VERSION="3.3.8"   # <-- Update this if you want a different version

echo "🚀 Installing Argo CD version v${ARGOCD_VERSION} ..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -n argocd \
  --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/v${ARGOCD_VERSION}/manifests/install.yaml

echo "⏳ Waiting for ArgoCD pods to be ready..."

# Wait for the deployment to be created
echo "⏳ Waiting for ArgoCD server deployment to be created..."
for i in {1..30}; do
  if kubectl get deployment -n argocd argocd-server > /dev/null 2>&1; then
    sleep 5
    break
  fi
  sleep 2
done

# Wait for ArgoCD server to be ready
echo "⏳ Waiting for ArgoCD server to be ready..."
kubectl wait --namespace argocd \
  --for=condition=available deployment/argocd-server \
  --timeout=300s

if [ $? -eq 0 ]; then
  echo "✅ ArgoCD is ready!"
else
  echo "❌ Timeout waiting for ArgoCD."
  echo "🔍 Checking pod status in argocd namespace..."
  kubectl get pods -n argocd
  exit 1
fi
