# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Helm charts for the lab **LB2236 — Getting Started with Ansible Development Tools: From Workstation to Production**. Deployed exclusively via ArgoCD GitOps on OpenShift clusters to provision Red Hat DevSpaces environments with nested Podman support.

## Architecture

Two independent Helm charts deployed by ArgoCD:

- **`bootstrap-infra/`** — Cluster-level infrastructure (deployed once per cluster):
  - `SecurityContextConstraints` — enables nested Podman via `container_engine_t` SELinux type, `SETUID`/`SETGID` capabilities, and `userNamespaceLevel: RequirePodLevel`
  - `CheCluster` CR — configures OpenShift DevSpaces (editor, container build, idle timeouts, default workspace components)

- **`bootstrap-tenant/`** — Per-user tenant (deployed per lab participant):
  - `Namespace` — user-scoped namespace (`<username>-devworkspace`) with Che labels
  - `DevWorkspace` — workspace definition with editor contributions and dev-tools container

### Sync-Wave Ordering

Each chart uses `argocd.argoproj.io/sync-wave` annotations to control deployment order. Annotation values must be quoted strings (`"1"`, `"2"`). Within each chart:

- **bootstrap-infra**: SCC (wave 1) → CheCluster (wave 2)
- **bootstrap-tenant**: Namespace (wave 1) → DevWorkspace (wave 2)

### Cross-Chart Dependencies

- The SCC name (`securityContextConstraints.name` in `bootstrap-infra/values.yaml`) is referenced by the CheCluster's `containerBuildConfiguration.openShiftSecurityContextConstraint` — these must stay in sync.
- The dev-tools container image (`ghcr.io/ansible/ansible-devspaces:v26.4.4`) appears in both the CheCluster `defaultComponents` and the DevWorkspace `template.components` — keep them consistent.

### DevWorkspace Structure

The DevWorkspace spec has three distinct sections:
- `spec.routingClass: che` — required for DevSpaces routing and auth.
- `spec.contributions` — editor plugin (che-code) via internal dashboard URI; top-level field alongside `spec.template`, not nested inside it.
- `spec.template.projects` — git repos auto-cloned on workspace start (currently `ansible-devspaces-summit`).
- `spec.template.components` — the tooling container definition with pod/container overrides for nested Podman.

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

- `bootstrap-infra/values.yaml`: cluster domain (`deployer.domain`), API URL (`deployer.apiUrl`), SCC name, CheCluster name/namespace
- `bootstrap-tenant/values.yaml`: `username` (default: `user1`), `cheCluster.namespace`, `devworkspace` (image, tag, resources, project repo)
- The container image must match between CheCluster `defaultComponents` (infra) and DevWorkspace `template.components` (tenant)
