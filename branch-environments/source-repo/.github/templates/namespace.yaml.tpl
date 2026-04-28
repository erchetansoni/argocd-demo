apiVersion: v1
kind: Namespace
metadata:
  name: ${NAMESPACE}
  labels:
    app.kubernetes.io/managed-by: argocd
    environment: ${ENVIRONMENT}
    branch: ${BRANCH}
