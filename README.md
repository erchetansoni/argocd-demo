# GitOps Argo CD App-of-Apps Demo

This repo demonstrates an Argo CD app-of-apps deployment on a local KIND cluster.

The demo includes:

- KIND cluster creation
- NGINX Ingress Controller
- Argo CD
- External Secrets Operator
- Argo CD root app that creates child apps
- `app1` as a production-style Helm chart using ConfigMaps, AWS Secrets Manager env secrets, and AWS Secrets Manager file secrets
- `app2` as a second simple app
- `app3` as a simple raw-manifest app using `traefik/whoami:latest`

## Repository Layout

```text
k8s-cluster-setup/
  kind-cluster-config.yaml
  create-cluster.sh
  delete-cluster.sh
  install-nginx-ingress-controller.sh
  install-argocd.sh
  install-eso.sh
  publish-argocd.sh

platform/
  argocd/
    argocd-cmd-params-cm.yaml
    ingress.yaml

root-app/
  app.yaml
  apps/
    app1.yaml
    app2.yaml
    app3.yaml

apps/
  app1/
    Chart.yaml
    values.yaml
    templates/
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
    deployment.yaml
    service.yaml
    ingress.yaml
  app3/
    deployment.yaml
    service.yaml
    ingress.yaml

aws-secrets-manager/
  .env.example
  aws-secrets.example
  aws-secret-file.example
  setup-aws-secrets.sh
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
4. Publishes Argo CD at `http://argocd.chetan.com`.
5. Installs External Secrets Operator.

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

## 2. Publish Argo CD

Argo CD can be exposed through NGINX Ingress at:

```text
http://argocd.chetan.com
```

The manifests live in:

```text
platform/argocd/
```

Publish Argo CD:

```bash
./k8s-cluster-setup/publish-argocd.sh
```

The script:

1. Applies the Argo CD ingress manifests.
2. Enables `server.insecure` for local HTTP ingress.
3. Restarts `argocd-server`.
4. Prints the `/etc/hosts` entry.

Add this to `/etc/hosts` if needed:

```text
127.0.0.1 argocd.chetan.com
```

Then open:

```text
http://argocd.chetan.com
```

Default username:

```text
admin
```

The publish script prints the initial admin password if it still exists. You can also retrieve it manually:

```bash
kubectl get secret argocd-initial-admin-secret \
  -n argocd \
  -o jsonpath="{.data.password}" | base64 -d
echo
```

If the secret is missing, the admin password was likely changed and the initial password secret was removed.

## 3. Prepare AWS Secrets For App1

Do this after the cluster/platform setup and before applying the Argo CD root app. `app1` expects AWS Secrets Manager values to be available through External Secrets Operator.

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

These credentials are used for two things:

1. Pushing demo secrets into AWS Secrets Manager.
2. Creating a Kubernetes Secret in `app1` so ESO can read from AWS Secrets Manager.

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

You can push only this env-style secret with:

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

You can push only this file-style secret with:

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

### Recommended: Run All AWS Secret Setup Scripts

After `.env`, `aws-secrets`, and `aws-secret-file` are ready, run:

```bash
./aws-secrets-manager/setup-aws-secrets.sh
```

This script:

1. Adds execute permissions to the AWS helper scripts.
2. Runs `push-secret-env.sh`.
3. Runs `push-secret-file.sh`.
4. Runs `create-k8s-aws-credentials-secret.sh`.

The last step creates this Kubernetes Secret for ESO:

```yaml
namespace: app1
secret: aws-secretsmanager-credentials
```

This Kubernetes Secret is not committed to Git. To run only this step manually:

```bash
./aws-secrets-manager/create-k8s-aws-credentials-secret.sh
```

## 4. Argo CD App-of-Apps

The root app is defined at:

```text
root-app/app.yaml
```

It points to `root-app/apps`, which contains only child Argo CD `Application` manifests:

```yaml
source:
  path: root-app/apps
  directory:
    recurse: true
```

The actual app source folders live under `apps/`. This keeps app-of-apps manifests separate from deployable app manifests and Helm charts.

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
app3
```

The child apps create their own namespaces using:

```yaml
syncOptions:
  - CreateNamespace=true
```

## 5. Sync Flow

Typical full flow:

```bash
./aws-secrets-manager/setup-aws-secrets.sh

kubectl apply -f root-app/app.yaml
kubectl get applications -n argocd
```

If Argo CD has not refreshed yet:

```bash
kubectl annotate application root-app -n argocd argocd.argoproj.io/refresh=hard --overwrite
kubectl annotate application app1 -n argocd argocd.argoproj.io/refresh=hard --overwrite
kubectl annotate application app2 -n argocd argocd.argoproj.io/refresh=hard --overwrite
kubectl annotate application app3 -n argocd argocd.argoproj.io/refresh=hard --overwrite
```

If you need to force a sync:

```bash
kubectl patch application root-app -n argocd --type merge -p '{"operation":{"sync":{"prune":true}}}'
kubectl patch application app1 -n argocd --type merge -p '{"operation":{"sync":{"prune":true}}}'
kubectl patch application app2 -n argocd --type merge -p '{"operation":{"sync":{"prune":true}}}'
kubectl patch application app3 -n argocd --type merge -p '{"operation":{"sync":{"prune":true}}}'
```

## 6. App1

`app1` is deployed into namespace `app1`.

It is packaged as a Helm chart because it represents the more production-like example in this demo.

It uses:

- Helm values for environment variables
- Helm values for a mounted ConfigMap file
- AWS Secrets Manager env secrets synced by ESO
- AWS Secrets Manager file secrets synced by ESO
- NGINX ingress host `app1.chetan.com`

Important files:

```text
apps/app1/Chart.yaml
apps/app1/values.yaml
apps/app1/templates/deployment.yaml
apps/app1/templates/configmap-env.yaml
apps/app1/templates/configmap-file.yaml
apps/app1/templates/external-secrets/secret-store.yaml
apps/app1/templates/external-secrets/external-secret-env.yaml
apps/app1/templates/external-secrets/external-secret-file.yaml
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
helm template app1 apps/app1 --namespace app1
helm lint apps/app1
```

After sync:

```bash
kubectl get all,cm,secret,externalsecret,secretstore,ingress -n app1
```

Check inside the pod:

```bash
kubectl exec -n app1 deploy/app1 -- ls -l /scripts /aws-secrets
kubectl exec -n app1 deploy/app1 -- cat /aws-secrets/hello.sh
```

## 7. App2

`app2` is deployed into namespace `app2`.

Important files:

```text
apps/app2/deployment.yaml
apps/app2/service.yaml
apps/app2/ingress.yaml
```

Validate:

```bash
kubectl get all,ingress -n app2
```

## 8. App3

`app3` is deployed into namespace `app3`.

It is intentionally kept as plain Kubernetes YAML to showcase the simplest possible non-Helm app.

It uses:

```text
traefik/whoami:latest
```

Important files:

```text
apps/app3/deployment.yaml
apps/app3/service.yaml
apps/app3/ingress.yaml
```

Validate:

```bash
kubectl apply --dry-run=client -f apps/app3 -o name
```

Validate:

```bash
kubectl get all,ingress -n app3
```

Ingress host:

```text
app3.chetan.com
```

## 9. Validate ESO Sync

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

## 10. Delete AWS Secrets

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

## 11. Reset The Demo Apps

Delete all Argo CD apps:

```bash
kubectl delete application --all -n argocd --ignore-not-found=true
```

Delete app namespaces:

```bash
kubectl delete namespace app1 app2 --ignore-not-found=true
kubectl delete namespace app3 --ignore-not-found=true
```

Verify:

```bash
kubectl get applications -n argocd
kubectl get namespace app1 app2 --ignore-not-found
kubectl get namespace app3 --ignore-not-found
kubectl get ingress -A
```

There is also a reset runbook:

```text
argocd-reset-and-resync.md
```

## 12. Delete The KIND Cluster

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
