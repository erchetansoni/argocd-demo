# app2 (raw manifests)

Plain Kubernetes manifests — Deployment + Service + Ingress for [`mccutchen/go-httpbin`](https://github.com/mccutchen/go-httpbin), wrapped in a `kustomization.yaml` so other kustomizations can reference this directory.

Used by ArgoCD Applications named `<branch>-app2`. The per-env kustomization at `environments/<branch>/app2/` in the gitops repo:

1. Pulls these manifests in via `resources: ../../../_source/apps/app2`.
2. Sets the namespace.
3. Patches the Ingress host: `app2.chetan.com` → `app2.<branch>.chetan.com`.

## Layout

```
app2/
├── kustomization.yaml      # required so this dir can appear as a `resources:` entry
├── deployment.yaml
├── service.yaml
└── ingress.yaml            # default host (app2.chetan.com); per-env host applied via JSON6902 patch
```

## Editing rules

Edit any of the manifests freely. The default `app2.chetan.com` host stays here — env-specific hosts come from the kustomization patch in [.github/templates/app2/kustomization.yaml.tpl](../../.github/templates/app2/kustomization.yaml.tpl). Don't templatize the host inside this folder — it stays plain so the file is straightforward to read and `kubectl apply -f apps/app2/` works as a smoke test.
