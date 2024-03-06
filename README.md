# ArgoCD sops-secrets Configuration Management Plugin

This plugin allows ArgoCD to decrypt sops-encrypted files stored in git before applying them against Kubernetes clusters.
Currently, it supports the following types of applications:

- plain manifests
- kustomize-ed
- helm charts
- ytt
