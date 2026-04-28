# argocd-demo-gitops

Single source of truth ArgoCD watches. Do **not** edit `environments/<branch>/` by hand — those folders are owned by CI in the [argocd-demo](https://github.com/erchetansoni/argocd-demo) source repo.

## Layout

```
.
├── _source/                       # submodule -> argocd-demo (branch: main)
├── applicationset.yaml            # the only ApplicationSet (applied once at setup)
├── argocd-cm-patch.yaml           # one-time ConfigMap patch (kustomize buildOptions)
└── environments/
    └── <branch>/
        ├── kustomization.yaml     # entry point ArgoCD reads
        ├── namespace.yaml
        ├── app1-values.yaml       # values for the chart at _source/apps/app1
        └── (CI may add more)
```

## How a sync works

1. ArgoCD reads `environments/<branch>/kustomization.yaml`.
2. Kustomize:
   - includes `namespace.yaml`,
   - pulls raw manifests from `_source/apps/app2` and `_source/apps/app3`,
   - renders the Helm chart at `_source/apps/app1` with `app1-values.yaml`,
   - patches the `app2-ingress` and `app3-ingress` host fields per environment.
3. ArgoCD applies everything to namespace `<branch>`.

## Updating the submodule

The submodule is pinned to a commit. To pull the latest source:

```bash
git submodule update --remote _source
git add _source
git commit -m "chore: bump _source"
git push
```

ArgoCD will reconcile every Application against the new chart/manifest definitions.

> **Note:** the submodule pointer is global across all envs. If you need per-env source pinning, switch the ApplicationSet to a multi-source pattern (`targetRevision` per env).
