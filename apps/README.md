# apps/

The actual application source — what gets deployed to Kubernetes. The companion [`argocd-demo-gitops`](https://github.com/erchetansoni/argocd-demo-gitops) repo references this folder via a git submodule (`_source/`); CI per-environment kustomizations point at the apps inside this directory.

## Contents

| Folder | Type | Notes |
|---|---|---|
| [app1/](app1/) | Helm chart | Deployment + service + ingress + ConfigMaps + ExternalSecrets via ESO |
| [app2/](app2/) | Raw Kubernetes manifests | Plain `deployment.yaml` + `service.yaml` + `ingress.yaml` + `kustomization.yaml` |
| [app3/](app3/) | Raw Kubernetes manifests | Same shape as app2, different image (whoami) |

## How they're consumed

For each branch/environment, CI generates one kustomization.yaml per app at `environments/<branch>/<app>/` in the gitops repo. Those kustomizations resolve back to this folder via the submodule:

```
gitops-repo/environments/qa/app1/kustomization.yaml
  └── helmGlobals.chartHome: ../../../_source/apps  →  apps/app1/  (this folder)

gitops-repo/environments/qa/app2/kustomization.yaml
  └── resources: ../../../_source/apps/app2         →  apps/app2/  (this folder)
```

## Editing rules

Edit anything here freely. On push, CI bumps the gitops repo's submodule pointer to your commit, so ArgoCD picks up the change on the next reconcile.

> If you add a new top-level app (e.g. `app4`), also add `app4` to the static list in the ApplicationSet template at the gitops repo's [`applicationset.yaml`](https://github.com/erchetansoni/argocd-demo-gitops/blob/main/applicationset.yaml) and add a `app4/` template directory under [`.github/templates/`](../.github/templates/).
