apiVersion: v1
kind: Secret
metadata:
  name: aws-secretsmanager-credentials
  namespace: ${NAMESPACE}
  labels:
    app.kubernetes.io/managed-by: argocd
    branch: ${BRANCH}
type: Opaque
stringData:
  access-key: ${AWS_ACCESS_KEY_ID}
  secret-access-key: ${AWS_SECRET_ACCESS_KEY}
  session-token: ${AWS_SESSION_TOKEN}
