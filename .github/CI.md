# .github/

CI for this repo. Two workflows handle the entire branch → environment lifecycle:

| Workflow | Trigger | What it does |
|---|---|---|
| [workflows/deploy.yml](workflows/deploy.yml) | `push` to any branch | Render an env folder for the branch and commit it to `argocd-demo-gitops` |
| [workflows/cleanup.yml](workflows/cleanup.yml) | `delete` branch event | Remove that env's folder from `argocd-demo-gitops` |

Together they implement: *push branch → env appears, delete branch → env disappears*. ArgoCD does the rest.

## Files

```
.github/
├── workflows/
│   ├── deploy.yml          # on push: render + commit + push
│   └── cleanup.yml         # on delete: rm folder + commit + push
├── scripts/
│   └── render-env.sh       # envsubst over .tpl files; writes to gitops/environments/<branch>/
└── templates/
    ├── app1/
    │   ├── kustomization.yaml.tpl   # references chart via submodule (helmGlobals.chartHome)
    │   └── values.yaml.tpl          # per-env Helm values
    ├── app2/kustomization.yaml.tpl  # raw manifests + ingress host patch
    └── app3/kustomization.yaml.tpl  # raw manifests + ingress host patch
```

## Required GitHub Actions secret

| Secret | Scope | Why |
|---|---|---|
| `GITOPS_TOKEN` | `Contents: Read & Write` on `argocd-demo-gitops` | The deploy and cleanup workflows commit to that repo |

Set under repo Settings → Actions → Secrets.

## Branch validation

Both workflows skip any branch name containing `/` (so `feature/foo`, `bug/x`, `hotfix/y` never trigger anything). `cleanup.yml` additionally refuses to wipe `environments/main` from a delete event as a safety guard.

## Render flow (deploy.yml)

```
1. Resolve branch (skip if contains '/')
2. Map: branch → environment, namespace, host_prefix
3. Checkout source repo (templates)
4. Checkout gitops repo with submodules:true (token: GITOPS_TOKEN)
5. Bump _source submodule pointer to GITHUB_SHA
6. render-env.sh: envsubst .tpl files → gitops/environments/<branch>/
7. Commit (env folder + bumped submodule) and push, message: "ci(<branch>): sync from <sha> [skip ci]"
```

## Adding a new app

1. Add `appN/` under [`../apps/`](../apps/) with either a Helm chart or a `kustomization.yaml` + raw manifests.
2. Add `appN/` template directory here under `templates/` (mirror app2 or app1's shape).
3. Add the new app to the static list in the [ApplicationSet](https://github.com/erchetansoni/argocd-demo-gitops/blob/main/applicationset.yaml).

That's it — no other touchpoints.
