# aws-secrets-manager/

One-time bootstrap scripts that:
1. Push demo secrets into AWS Secrets Manager (the *upstream*).
2. Create the cluster-side `aws-secretsmanager-credentials` Secret + `ClusterSecretStore` so ESO can authenticate from any namespace.

ArgoCD ExternalSecrets in the chart point at the cluster store by name; they do not contain creds. **Creds never enter git.**

## Scripts

| Script | Purpose | Run when |
|---|---|---|
| [setup-aws-secrets.sh](setup-aws-secrets.sh) | Wrapper — runs all three below in order | First-time setup of a fresh AWS account |
| [push-secret-env.sh](push-secret-env.sh) | Pushes `aws-secrets` (key=value file) → AWS Secrets Manager as `argocd-demo/app-secrets` | First-time / when env-style secrets change |
| [push-secret-file.sh](push-secret-file.sh) | Pushes `aws-secret-file` → AWS Secrets Manager as `argocd-demo/app-secret-file` | First-time / when file-style secret changes |
| [create-k8s-aws-credentials-secret.sh](create-k8s-aws-credentials-secret.sh) | Creates the K8s creds Secret in `external-secrets` ns AND applies the `ClusterSecretStore` CR | Every cluster rebuild (or when AWS session creds rotate) |
| [delete-aws-secrets.sh](delete-aws-secrets.sh) | Removes secrets from AWS Secrets Manager | Cleanup |

## Files

| File | Purpose |
|---|---|
| `.env.example` → `.env` | AWS access key / secret / session token (gitignored) |
| `aws-secrets.example` → `aws-secrets` | Plain key=value pairs that become the env-style secret (gitignored) |
| `aws-secret-file.example` → `aws-secret-file` | Arbitrary content that becomes the file-style secret (gitignored) |

## Typical flow

```bash
# Once, for a brand-new AWS account:
cp .env.example .env                   # fill in AWS creds
cp aws-secrets.example aws-secrets     # fill in app secrets
cp aws-secret-file.example aws-secret-file
./setup-aws-secrets.sh

# Every cluster rebuild after that (only the K8s side):
./create-k8s-aws-credentials-secret.sh
```

## Why creds-in-git is blocked

GitHub Push Protection scans commits for known credential patterns. AWS access keys + secret keys committed to a repo (even a private one) get rejected at push time. ESO with `ClusterSecretStore` sidesteps this entirely — the only place creds exist is the cluster, where they're a regular K8s Secret in the `external-secrets` namespace.

## Regenerating after creds rotate

If you receive new AWS session credentials:

```bash
# Update .env with new AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY / AWS_SESSION_TOKEN
./create-k8s-aws-credentials-secret.sh   # idempotent — patches the existing Secret + ClusterSecretStore
```

ESO automatically re-authenticates on the next refresh interval.
