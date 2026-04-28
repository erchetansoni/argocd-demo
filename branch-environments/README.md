# Branch-driven GitOps — Path B (submodule + Kustomize+Helm)

Implementation bundle for the architecture you described. After the one-time setup, any push to a valid branch on the source repo deploys itself automatically — no manual ArgoCD work.

## Architecture (Path B)

```
┌──────────────────────────────┐  push   ┌─────────────────────────┐
│ Repo 1: argocd-demo          │ ──────▶ │ GitHub Actions          │
│ (source: chart + manifests)  │         │ .github/workflows/      │
│ branches: main, dev, qa, ... │         │ deploy.yml              │
└──────────────┬───────────────┘         └────────────┬────────────┘
               │                          render +    │
               │ submodule              writes to     ▼
               │ ┌─────────────────────────────────────────────┐
               └▶│ Repo 2: argocd-demo-gitops                  │
                 │ ├── _source/  (submodule -> Repo 1)         │
                 │ ├── applicationset.yaml                     │
                 │ └── environments/<branch>/                  │
                 │     ├── kustomization.yaml                  │
                 │     ├── namespace.yaml                      │
                 │     └── app1-values.yaml                    │
                 └─────────────────────┬───────────────────────┘
                                       │ poll + clone w/ submodule
                                       ▼
                              ┌────────────────────┐
                              │ ArgoCD             │
                              │ ApplicationSet     │
                              │ (directory gen)    │
                              └─────────┬──────────┘
                                        ▼
                                   Kubernetes
                              (namespace = branch)
```

**Two writes, one read:** CI writes per-env values (small, fast). Submodule pointer bumps when chart structure changes (rare). ArgoCD only reads.

## Branch rules

| Branch | Action | Environment | Namespace | Hosts |
|---|---|---|---|---|
| `main` | deploy | `production` | `main` | `app{1,2,3}.chetan.com` |
| `dev` | deploy | `development` | `dev` | `app{1,2,3}.dev.chetan.com` |
| `stage` | deploy | `stage` | `stage` | `app{1,2,3}.stage.chetan.com` |
| `it` | deploy | `information-technology` | `it` | `app{1,2,3}.it.chetan.com` |
| `qa`, `demo`, … (no `/`) | deploy | `<branch>` | `<branch>` | `app{1,2,3}.<branch>.chetan.com` |
| `feature/*`, `bug/*`, anything with `/` | **skip** | — | — | — |

## Files in this bundle

```
branch-environments/
├── README.md                                     # this file
├── source-repo/                                  # → goes into argocd-demo
│   └── .github/
│       ├── workflows/deploy.yml                  # CI pipeline
│       ├── scripts/render-env.sh                 # envsubst renderer
│       └── templates/
│           ├── namespace.yaml.tpl
│           ├── app1-values.yaml.tpl
│           └── kustomization.yaml.tpl
└── gitops-repo/                                  # → goes into argocd-demo-gitops
    ├── README.md
    ├── .gitmodules                               # submodule pointer
    ├── applicationset.yaml                       # the only ApplicationSet
    ├── argocd-cm-patch.yaml                      # one-time ArgoCD ConfigMap patch
    └── environments/
        └── main/                                 # baseline; everything else is CI-generated
            ├── kustomization.yaml
            ├── namespace.yaml
            └── app1-values.yaml
```

## One-time setup

> URLs assumed:
> - source repo: `git@github.com:erchetansoni/argocd-demo.git`
> - gitops repo: `git@github.com:erchetansoni/argocd-demo-gitops.git`

### 1. Provision a CI write token

CI in `argocd-demo` must push to `argocd-demo-gitops`.
- Create a fine-grained PAT (or GitHub App installation token) on a service account with `Contents: Read & Write` scope on `argocd-demo-gitops`.
- In the **`argocd-demo` repo settings**, add it as Actions secret `GITOPS_TOKEN`.

### 2. Bootstrap the GitOps repo

```bash
git clone git@github.com:erchetansoni/argocd-demo-gitops.git
cd argocd-demo-gitops

# Add the source repo as a submodule
git submodule add -b main https://github.com/erchetansoni/argocd-demo.git _source

# Drop in bootstrap files (paths relative to this branch-environments/ dir)
cp ../argocd-demo/branch-environments/gitops-repo/applicationset.yaml .
cp ../argocd-demo/branch-environments/gitops-repo/argocd-cm-patch.yaml .
cp ../argocd-demo/branch-environments/gitops-repo/README.md .
mkdir -p environments/main
cp -r ../argocd-demo/branch-environments/gitops-repo/environments/main/. environments/main/

git add .
git commit -m "chore: bootstrap gitops repo [skip ci]"
git push -u origin main
```

### 3. Drop CI into the source repo

From inside the source repo (`argocd-demo`):

```bash
mkdir -p .github/workflows .github/scripts .github/templates
cp branch-environments/source-repo/.github/workflows/deploy.yml      .github/workflows/
cp branch-environments/source-repo/.github/scripts/render-env.sh     .github/scripts/
cp branch-environments/source-repo/.github/templates/*.tpl           .github/templates/
chmod +x .github/scripts/render-env.sh

git add .github/
git commit -m "ci: branch-driven gitops pipeline"
git push origin main
```

(Once you're satisfied, you can also delete `branch-environments/` from the source repo since its files are now installed.)

### 4. Configure ArgoCD (one-time)

```bash
# Enable Helm-in-Kustomize and allow loading from outside the kustomization root.
kubectl patch configmap argocd-cm -n argocd \
  --patch-file branch-environments/gitops-repo/argocd-cm-patch.yaml
kubectl rollout restart deploy/argocd-repo-server -n argocd
```

Submodules are cloned by default (`ARGOCD_GIT_MODULES_ENABLED=true`). If your source repo is private, register it in ArgoCD with credentials so the repo-server can clone the submodule.

### 5. Cut over from the existing root-app

Your current cluster runs the old `root-app` (Repo 3 layout) which deploys app1/2/3 directly. To switch to the ApplicationSet without downtime:

```bash
# (a) Apply the ApplicationSet — it will create env-main alongside the old apps.
kubectl apply -f branch-environments/gitops-repo/applicationset.yaml

# Wait until env-main shows Healthy/Synced in ArgoCD UI, on namespace `main`.
# This co-exists with the old apps (which live in their own namespaces: app1, app2, app3).

# (b) Remove the old root-app and its children.
kubectl delete -n argocd application root-app
kubectl delete -n argocd application app1 app2 app3 || true

# (c) Optionally, clean up the old per-app namespaces if you don't want them around.
kubectl delete namespace app1 app2 app3 || true
```

> The old setup deployed each app to its own namespace (`app1`, `app2`, `app3`). The new setup deploys all three apps **together** in one namespace per branch (`main`, `dev`, `qa`, …). Update DNS / clients accordingly.

### 6. Test

```bash
# valid branch
git checkout -b qa && git commit --allow-empty -m "test qa" && git push -u origin qa
# expect: environments/qa/ appears in argocd-demo-gitops within ~30s
# expect: argocd Application 'env-qa' shows up, namespace 'qa' is created

# invalid branch
git checkout -b feature/nope && git commit --allow-empty -m "skip" && git push -u origin feature/nope
# expect: workflow logs "Branch 'feature/nope' contains '/', skipping" and exits clean

# branch deletion (manual cleanup for now)
git push origin --delete qa
# the env-qa Application stays until you delete environments/qa/ in the gitops repo;
# once that folder is gone, ApplicationSet prunes env-qa automatically.
```

## Loop prevention (three layers)

1. CI runs only on the source repo; commits land in the gitops repo — different repo, no trigger.
2. CI commit messages always include `[skip ci]`.
3. The render script wipes `environments/<branch>/` before re-rendering, so commits are minimal and idempotent.

## Where to extend

- **Auto-cleanup on branch delete:** add a second job to `deploy.yml` triggered by `delete` events that removes `environments/<branch>/` from the gitops repo.
- **Per-env image tag:** the workflow already exports `IMAGE_TAG=${github.sha}` — wire it into `app1-values.yaml.tpl` (`image.tag: ${IMAGE_TAG}`) once you have a real image registry.
- **TLS:** add cert-manager annotations to the chart's ingress template and a `tls:` block parameterized by `${APP1_HOST}`.
- **Per-env source pinning:** swap the ApplicationSet for a multi-source pattern with `targetRevision: '{{ .path.basename }}'` so each env follows its own branch of the source repo.
