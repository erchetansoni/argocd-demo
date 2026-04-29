# platform/

Cluster-platform configuration that isn't part of any application — applied once at setup time, not via the per-branch GitOps flow.

## Contents

| Path | Purpose |
|---|---|
| [argocd/argocd-cmd-params-cm.yaml](argocd/argocd-cmd-params-cm.yaml) | Sets `server.insecure: "true"` so the NGINX Ingress can terminate TLS in front of ArgoCD without server-side TLS (kind demo only) |
| [argocd/ingress.yaml](argocd/ingress.yaml) | Ingress for ArgoCD UI at `http://argocd.chetan.com` |

These are applied automatically by [`../k8s-cluster-setup/publish-argocd.sh`](../k8s-cluster-setup/publish-argocd.sh).

## Why is this not in the GitOps flow?

The GitOps flow (CI → gitops repo → ApplicationSet → Applications) deploys **applications**. ArgoCD itself, the ingress controller, and the way you reach ArgoCD's UI are *bootstrap* concerns — they need to exist *before* ArgoCD can manage anything. Keeping them as one-time `kubectl apply` is the simpler dependency story.

A more advanced setup might use ArgoCD to manage itself ("App-of-Apps for the platform") or a separate platform-bootstrap tool (Argo CD Autopilot, Cluster API + addon manager, etc.). Out of scope for this demo.
