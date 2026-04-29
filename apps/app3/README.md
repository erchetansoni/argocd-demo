# app3 (raw manifests)

Plain Kubernetes manifests for [`traefik/whoami`](https://github.com/traefik/whoami) — same shape as [`app2/`](../app2/). Wrapped in a `kustomization.yaml` so the per-env kustomization in the gitops repo can include this directory as a resource and patch the ingress host.

Used by ArgoCD Applications named `<branch>-app3`.

## Layout

```
app3/
├── kustomization.yaml
├── deployment.yaml
├── service.yaml
└── ingress.yaml            # default host: app3.chetan.com
```

See [`apps/app2/README.md`](../app2/README.md) for editing notes — the rules are identical.
