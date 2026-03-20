# Ansible Dev Tools Automation

GitOps automation for lab **LB2236 — Getting Started with Ansible Development Tools: From Workstation to Production**.

Helm charts deployed via ArgoCD on OpenShift to provision Red Hat DevSpaces environments with nested Podman support.

## Charts

- **bootstrap-infra** — Cluster-level setup: SecurityContextConstraints for nested Podman and CheCluster CR for DevSpaces configuration.
- **bootstrap-tenant** — Per-user setup: DevWorkspace resources provisioned for each lab participant.
