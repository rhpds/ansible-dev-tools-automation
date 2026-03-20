# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Helm charts for the lab **LB2236 — Getting Started with Ansible Development Tools: From Workstation to Production**. These charts are deployed exclusively via ArgoCD GitOps on OpenShift clusters to provision Red Hat DevSpaces environments with nested Podman support.

## Architecture

Two independent Helm charts, deployed by ArgoCD (templates use `argocd.argoproj.io/sync-wave` annotations for ordering):

- **`bootstrap-infra/`** — Cluster-level infrastructure (deployed once per cluster by an admin):
  - `SecurityContextConstraints` for nested Podman (`container_engine_t` SELinux, `SETUID`/`SETGID` capabilities, user namespaces)
  - `CheCluster` CR configuring OpenShift DevSpaces (dev environment defaults, container build settings, idle timeouts)

- **`bootstrap-tenant/`** — Per-user tenant setup (deployed per lab participant):
  - `DevWorkspace` resources (parameterized by `username`, default: `user1`)

## Common Commands

```bash
# Validate chart templates locally
helm template bootstrap-infra ./bootstrap-infra
helm template bootstrap-tenant ./bootstrap-tenant --set username=user1

# Lint charts
helm lint ./bootstrap-infra
helm lint ./bootstrap-tenant
```

## Key Configuration

- `bootstrap-infra/values.yaml`: cluster domain, API URL, SCC name, CheCluster namespace
- `bootstrap-tenant/values.yaml`: username for tenant provisioning
- The SCC name in `bootstrap-infra` is referenced by the CheCluster's `containerBuildConfiguration`; these must stay in sync
