# GitOps Argo CD App-of-Apps Demo

This repo demonstrates an Argo CD app-of-apps deployment on a local KIND cluster.

The demo includes:

- KIND cluster creation
- NGINX Ingress Controller
- Argo CD
- External Secrets Operator
- Argo CD root app that creates child apps
- `app1` using ConfigMaps, AWS Secrets Manager env secrets, and AWS Secrets Manager file secrets
- `app2` as a second simple app

## Repository Layout

```text
k8s-cluster-setup/
  kind-cluster-config.yaml
  create-cluster.sh
  delete-cluster.sh
  install-nginx-ingress-controller.sh
  install-argocd.sh
  install-eso.sh

root-app/
  app.yaml

apps/
  app1/
    app.yaml
    deployment.yaml
    service.yaml
    ingress.yaml
    configmap-env.yaml
    configmap-file.yaml
    external-secrets/
      secret-store.yaml
      external-secret-env.yaml
      external-secret-file.yaml
  app2/
    app.yaml
    deployment.yaml
    service.yaml
    ingress.yaml

aws-secrets-manager/
  .env.example
  aws-secrets.example
  aws-secret-file.example
  push-secret-env.sh
  push-secret-file.sh
  create-k8s-aws-credentials-secret.sh
  delete-aws-secrets.sh
```

## Prerequisites

Install these locally:

```bash
docker
kind
kubectl
helm
aws
jq
```

You also need AWS credentials with access to Secrets Manager in the configured region.

## 1. Create The Local Cluster

The KIND config creates a cluster named `gitops-demo-cluster` and maps host ports `80` and `443`.

```bash
./k8s-cluster-setup/create-cluster.sh
```

This script currently runs the full platform setup:

1. Creates the KIND cluster.
2. Installs NGINX Ingress Controller.
3. Installs Argo CD.
4. Installs External Secrets Operator.

Validate:

```bash
kind get clusters
kubectl config current-context
kubectl get nodes -o wide
kubectl get pods -A
```

Expected context:

```text
kind-gitops-demo-cluster
```

## 2. Argo CD App-of-Apps

The root app is defined at:

```text
root-app/app.yaml
```

It points to the `apps/` directory and includes only child Argo CD app manifests:

```yaml
directory:
  recurse: true
  include: '*/app.yaml'
```

Apply the root app:

```bash
kubectl apply -f root-app/app.yaml
```

Watch the apps:

```bash
kubectl get applications -n argocd
```

Expected apps:

```text
root-app
app1
app2
```

The child apps create their own namespaces using:

```yaml
syncOptions:
  - CreateNamespace=true
```

## 3. App1

`app1` is deployed into namespace `app1`.

It uses:

- `configmap-env.yaml` for environment variables
- `configmap-file.yaml` for a mounted file
- AWS Secrets Manager env secrets synced by ESO
- AWS Secrets Manager file secrets synced by ESO
- NGINX ingress host `app1.chetan.com`

Important files:

```text
apps/app1/deployment.yaml
apps/app1/configmap-env.yaml
apps/app1/configmap-file.yaml
apps/app1/external-secrets/secret-store.yaml
apps/app1/external-secrets/external-secret-env.yaml
apps/app1/external-secrets/external-secret-file.yaml
```

The deployment consumes env values from:

```yaml
envFrom:
  - configMapRef:
      name: app1-config-env
  - secretRef:
      name: app1-secret-env
```

It mounts files from:

```text
/scripts
/aws-secrets
```

Validate app1:

```bash
kubectl get all,cm,secret,externalsecret,secretstore,ingress -n app1
```

Check inside the pod:

```bash
kubectl exec -n app1 deploy/app1 -- ls -l /scripts /aws-secrets
kubectl exec -n app1 deploy/app1 -- cat /aws-secrets/hello.sh
```

## 4. App2

`app2` is deployed into namespace `app2`.

Important files:

```text
apps/app2/app.yaml
apps/app2/deployment.yaml
apps/app2/service.yaml
apps/app2/ingress.yaml
```

Validate:

```bash
kubectl get all,ingress -n app2
```

## 5. AWS Secrets Manager Setup

The AWS helper files live in:

```text
aws-secrets-manager/
```

### AWS Credentials

Copy the example:

```bash
cp aws-secrets-manager/.env.example aws-secrets-manager/.env
```

Fill in only AWS credentials:

```bash
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_SESSION_TOKEN=
```

The real `.env` file is ignored by git.

### Env Secret Payload

Copy the example:

```bash
cp aws-secrets-manager/aws-secrets.example aws-secrets-manager/aws-secrets
```

Edit it with simple key-value pairs:

```text
APP_USERNAME=demo-user
APP_PASSWORD=change-me
API_KEY=change-me
```

Push it to AWS Secrets Manager:

```bash
./aws-secrets-manager/push-secret-env.sh
```

This creates or updates:

```text
argocd-demo/app-secrets
```

ESO pulls this into Kubernetes as:

```text
app1-secret-env
```

### File Secret Payload

Copy the example:

```bash
cp aws-secrets-manager/aws-secret-file.example aws-secrets-manager/aws-secret-file
```

Edit the file content, for example:

```sh
#!/bin/sh
echo "Hello from AWS Secrets Manager!"
```

Push it to AWS Secrets Manager:

```bash
./aws-secrets-manager/push-secret-file.sh
```

This creates or updates:

```text
argocd-demo/app-secret-file
```

The file content is stored under key:

```text
hello.sh
```

ESO pulls this into Kubernetes as:

```text
app1-secret-file
```

The app mounts it at:

```text
/aws-secrets/hello.sh
```

## 6. AWS Credentials Secret For ESO

ESO needs AWS credentials inside the `app1` namespace so the `SecretStore` can authenticate to AWS Secrets Manager.

Create that Kubernetes Secret from your local `.env`:

```bash
./aws-secrets-manager/create-k8s-aws-credentials-secret.sh
```

This creates:

```text
namespace: app1
secret: aws-secretsmanager-credentials
```

This Kubernetes Secret is not committed to Git.

## 7. Sync Flow

Typical full flow:

```bash
./aws-secrets-manager/push-secret-env.sh
./aws-secrets-manager/push-secret-file.sh
./aws-secrets-manager/create-k8s-aws-credentials-secret.sh

kubectl apply -f root-app/app.yaml
kubectl get applications -n argocd
```

If Argo CD has not refreshed yet:

```bash
kubectl annotate application root-app -n argocd argocd.argoproj.io/refresh=hard --overwrite
kubectl annotate application app1 -n argocd argocd.argoproj.io/refresh=hard --overwrite
kubectl annotate application app2 -n argocd argocd.argoproj.io/refresh=hard --overwrite
```

If you need to force a sync:

```bash
kubectl patch application root-app -n argocd --type merge -p '{"operation":{"sync":{"prune":true}}}'
kubectl patch application app1 -n argocd --type merge -p '{"operation":{"sync":{"prune":true}}}'
kubectl patch application app2 -n argocd --type merge -p '{"operation":{"sync":{"prune":true}}}'
```

## 8. Validate ESO Sync

Check ExternalSecret status:

```bash
kubectl get externalsecret -n app1
kubectl describe externalsecret app1-external-secret-env -n app1
kubectl describe externalsecret app1-external-secret-file -n app1
```

Check Kubernetes Secrets:

```bash
kubectl get secret app1-secret-env -n app1
kubectl get secret app1-secret-file -n app1
```

Check mounted file:

```bash
kubectl exec -n app1 deploy/app1 -- ls -l /aws-secrets
kubectl exec -n app1 deploy/app1 -- cat /aws-secrets/hello.sh
```

## 9. Delete AWS Secrets

To delete both AWS Secrets Manager secrets:

```bash
./aws-secrets-manager/delete-aws-secrets.sh
```

The script handles missing secrets safely. If only one exists, it deletes that one and skips the missing one.

Secrets deleted:

```text
argocd-demo/app-secrets
argocd-demo/app-secret-file
```

## 10. Reset The Demo Apps

Delete all Argo CD apps:

```bash
kubectl delete application --all -n argocd --ignore-not-found=true
```

Delete app namespaces:

```bash
kubectl delete namespace app1 app2 --ignore-not-found=true
```

Verify:

```bash
kubectl get applications -n argocd
kubectl get namespace app1 app2 --ignore-not-found
kubectl get ingress -A
```

There is also a reset runbook:

```text
argocd-reset-and-resync.md
```

## 11. Delete The KIND Cluster

```bash
./k8s-cluster-setup/delete-cluster.sh
```

## Notes

- Commit and push manifest changes before expecting Argo CD to sync them from GitHub.
- The Argo CD apps currently point to:

```text
https://github.com/erchetansoni/GitOps-ArgoCD-demo.git
```

- Real local secret files are ignored by git.
- The Kubernetes AWS credentials Secret is created manually from local `.env`; it should not be stored in Git.
