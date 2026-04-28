apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: ${NAMESPACE}

resources:
  - namespace.yaml
  - ../../_source/apps/app2
  - ../../_source/apps/app3

helmCharts:
  - name: app1
    releaseName: app1
    path: ../../_source/apps/app1
    valuesFile: app1-values.yaml
    namespace: ${NAMESPACE}

patches:
  - target:
      group: networking.k8s.io
      version: v1
      kind: Ingress
      name: app2-ingress
    patch: |-
      - op: replace
        path: /spec/rules/0/host
        value: ${APP2_HOST}
  - target:
      group: networking.k8s.io
      version: v1
      kind: Ingress
      name: app3-ingress
    patch: |-
      - op: replace
        path: /spec/rules/0/host
        value: ${APP3_HOST}

commonLabels:
  environment: ${ENVIRONMENT}
  branch: ${BRANCH}
