apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: ${NAMESPACE}

resources:
  - ../../../_source/apps/app2

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

labels:
  - includeSelectors: false
    pairs:
      app: app2
      environment: ${ENVIRONMENT}
      branch: ${BRANCH}
