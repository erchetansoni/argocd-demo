# app1 (Helm chart)

A production-style Helm chart demonstrating:

- A Deployment + Service + Ingress for a stateless app (kuard).
- Two ConfigMaps (env-style and file-style).
- Two `ExternalSecret` resources that pull from AWS Secrets Manager via ESO + a cluster-wide `ClusterSecretStore` named `aws-secretsmanager`.

Used by ArgoCD Applications named `<branch>-app1` (one per environment). Each Application reads `environments/<branch>/app1/values.yaml` from the gitops repo and renders this chart with those values in namespace `<branch>`.

## Layout

```
app1/
├── Chart.yaml
├── values.yaml                          # default values (overridden per env)
└── templates/
    ├── deployment.yaml
    ├── service.yaml
    ├── ingress.yaml
    ├── configmap-env.yaml
    ├── configmap-file.yaml
    └── external-secrets/
        ├── external-secret-env.yaml     # references ClusterSecretStore: aws-secretsmanager
        └── external-secret-file.yaml
```

## ESO contract

The chart references `ClusterSecretStore/aws-secretsmanager` by name. That cluster-scoped resource is created **once** by [aws-secrets-manager/create-k8s-aws-credentials-secret.sh](../../aws-secrets-manager/create-k8s-aws-credentials-secret.sh) at cluster setup time — never via this chart and never via git (creds-in-git is blocked by GitHub push protection). All ExternalSecrets in any namespace can use this single store.

## Per-env values

Per-environment values are written to `environments/<branch>/app1/values.yaml` by CI ([.github/templates/app1/values.yaml.tpl](../../.github/templates/app1/values.yaml.tpl)). The values that vary per env are:

- `ingress.host` → `app1.<branch>.chetan.com` (or `app1.chetan.com` for `main`)
- `configEnv.ENVIRONMENT` / `configEnv.BRANCH` → derived from branch name
