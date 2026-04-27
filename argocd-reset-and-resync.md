# Argo CD App-of-Apps Reset and Re-sync

This runbook keeps Argo CD and the ingress controller installed, but removes the demo apps so the app-of-apps flow can be shown again from a clean state.

## Delete Demo Argo CD Apps

```bash
kubectl delete application --all -n argocd --ignore-not-found=true
```

Verify they are gone:

```bash
kubectl get applications -n argocd
```

Expected result:

```text
No resources found in argocd namespace.
```

## Delete Demo App Namespaces

```bash
kubectl delete namespace app1 app2 --ignore-not-found=true
```

Wait until both namespaces disappear:

```bash
kubectl get namespace app1 app2 --ignore-not-found
```

Expected result: no output.

## Re-sync Everything

Make sure your local manifest changes are committed and pushed, because the Argo CD Applications use the GitHub repo as their source.

Apply the root app:

```bash
kubectl apply -f root-app/app.yaml
```

Watch Argo CD create the child apps:

```bash
kubectl get applications -n argocd
```

Expected apps:

```text
root-app
app1
app2
```

Then watch the app namespaces and workloads:

```bash
kubectl get namespaces app1 app2
kubectl get all,cm,ingress -n app1
kubectl get all,ingress -n app2
```

If an app is not refreshed yet, ask Argo CD to refresh it:

```bash
kubectl annotate application root-app -n argocd argocd.argoproj.io/refresh=hard --overwrite
```

After `app1` and `app2` exist, refresh the child apps too:

```bash
kubectl annotate application app1 -n argocd argocd.argoproj.io/refresh=hard --overwrite
kubectl annotate application app2 -n argocd argocd.argoproj.io/refresh=hard --overwrite
```

If automated sync is enabled, Argo CD should sync after refresh. To force a sync without the Argo CD CLI, patch the sync operation:

```bash
kubectl patch application root-app -n argocd --type merge -p '{"operation":{"sync":{"prune":true}}}'
```

After `app1` and `app2` exist, force child syncs if needed:

```bash
kubectl patch application app1 -n argocd --type merge -p '{"operation":{"sync":{"prune":true}}}'
kubectl patch application app2 -n argocd --type merge -p '{"operation":{"sync":{"prune":true}}}'
```

## Useful Checks

```bash
kubectl get pods -n argocd
kubectl get pods -n ingress-nginx
kubectl get applications -n argocd
kubectl get ingress -A
```
