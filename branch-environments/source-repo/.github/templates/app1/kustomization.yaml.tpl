apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: ${NAMESPACE}

helmGlobals:
  chartHome: ../../../_source/apps

helmCharts:
  - name: app1
    releaseName: app1
    valuesFile: values.yaml
    namespace: ${NAMESPACE}

labels:
  - includeSelectors: false
    pairs:
      app: app1
      environment: ${ENVIRONMENT}
      branch: ${BRANCH}
