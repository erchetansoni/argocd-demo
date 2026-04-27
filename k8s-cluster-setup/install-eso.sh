#!/bin/bash

########## 🔐 Install External Secrets Operator ###########################
echo "🔐 Installing External Secrets Operator..."

helm repo add external-secrets https://charts.external-secrets.io

helm upgrade --install external-secrets \
   external-secrets/external-secrets \
    -n external-secrets \
    --create-namespace \
  # --set installCRDs=true


echo "⏳ Waiting for External Secrets Operator deployment to be ready..."
kubectl wait deployment external-secrets \
  -n external-secrets \
  --for=condition=Available=True \
  --timeout=120s

echo "✅ External Secrets Operator is ready!"

########## ✅ Cluster Setup Complete ###########################