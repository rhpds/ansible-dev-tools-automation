# DevSpaces Workspace Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Update both Helm charts to provision DevWorkspaces using the upstream ansible-devspaces image with auto-cloned workspace config from the ansible-devspaces-summit repo.

**Architecture:** Three files change: tenant values.yaml gets new configurable parameters, tenant devworkspace.yaml gets a full rewrite with routingClass/projects/overrides/env vars, and infra checluster.yaml gets its defaultComponents image updated to match. All validated with helm template + lint.

**Tech Stack:** Helm 3, DevWorkspace API v1alpha2, OpenShift Dev Spaces 3.27, ArgoCD sync-waves

**Spec:** `docs/superpowers/specs/2026-04-21-devspaces-workspace-integration-design.md`
**Issue:** https://github.com/leogallego/rhdp-ansible-dev-tools-automation/issues/2

---

### Task 1: Update bootstrap-tenant values.yaml

**Files:**
- Modify: `bootstrap-tenant/values.yaml` (full file, lines 1-6)

- [ ] **Step 1: Replace values.yaml with new parameters**

Replace the entire contents of `bootstrap-tenant/values.yaml` with:

```yaml
# Default values for bootstrap-tenant.
# This is a YAML-formatted file.
# Declare variables to be passed into your templates.

username: user1

cheCluster:
  namespace: openshift-devspaces

devworkspace:
  image: ghcr.io/ansible/ansible-devspaces
  tag: v26.4.4
  memoryRequest: 2Gi
  memoryLimit: 4Gi
  cpuRequest: 500m
  cpuLimit: 2000m
  project:
    name: ansible-devspaces-summit
    repo: https://github.com/leogallego/ansible-devspaces-summit.git
    revision: main
```

- [ ] **Step 2: Lint the chart to catch YAML errors**

Run: `helm lint ./bootstrap-tenant`

Expected: `1 chart(s) linted, 0 chart(s) failed` (may show warnings about template rendering before devworkspace.yaml is updated — that's expected at this stage)

- [ ] **Step 3: Commit**

```bash
git add bootstrap-tenant/values.yaml
git commit -m "feat(tenant): add devworkspace and cheCluster values

Add configurable parameters for the DevWorkspace image, resources,
and git project reference. Add cheCluster namespace for internal
dashboard URI. Closes partially #2."
```

---

### Task 2: Rewrite bootstrap-tenant DevWorkspace template

**Files:**
- Modify: `bootstrap-tenant/templates/devworkspace.yaml` (full file, lines 1-28)

- [ ] **Step 1: Replace devworkspace.yaml with the new template**

Replace the entire contents of `bootstrap-tenant/templates/devworkspace.yaml` with:

```yaml
---
apiVersion: workspace.devfile.io/v1alpha2
kind: DevWorkspace
metadata:
  name: ansible-dev-tools
  namespace: {{ .Values.username }}-devworkspace
  annotations:
    argocd.argoproj.io/sync-wave: "2"
spec:
  routingClass: che
  started: true
  contributions:
    - name: ide
      uri: >-
        http://devspaces-dashboard.{{ .Values.cheCluster.namespace }}.svc.cluster.local:8080/dashboard/api/editors/devfile?che-editor=che-incubator/che-code/latest
      components:
        - name: che-code-runtime-description
          container:
            env:
              - name: CODE_HOST
                value: "0.0.0.0"
  template:
    projects:
      - name: {{ .Values.devworkspace.project.name }}
        git:
          remotes:
            origin: {{ .Values.devworkspace.project.repo }}
          checkoutFrom:
            revision: {{ .Values.devworkspace.project.revision }}
    components:
      - name: tooling-container
        attributes:
          pod-overrides:
            metadata:
              annotations:
                io.kubernetes.cri-o.Devices: "/dev/fuse,/dev/net/tun"
            spec:
              hostUsers: false
          container-overrides:
            securityContext:
              procMount: Unmasked
        container:
          image: "{{ .Values.devworkspace.image }}:{{ .Values.devworkspace.tag }}"
          memoryRequest: {{ .Values.devworkspace.memoryRequest }}
          memoryLimit: {{ .Values.devworkspace.memoryLimit }}
          cpuRequest: {{ .Values.devworkspace.cpuRequest }}
          cpuLimit: {{ .Values.devworkspace.cpuLimit }}
          mountSources: true
          sourceMapping: /projects
          env:
            - name: ANSIBLE_HOME
              value: "/projects/{{ .Values.devworkspace.project.name }}/.ansible"
            - name: HOSTNAME
              value: ansible-devspaces
            - name: VSCODE_DEFAULT_WORKSPACE
              value: "/projects/{{ .Values.devworkspace.project.name }}/devspaces.code-workspace"
```

- [ ] **Step 2: Render the template and verify output**

Run: `helm template bootstrap-tenant ./bootstrap-tenant --set username=testuser`

Expected output should show:
- `metadata.namespace: testuser-devworkspace`
- `spec.routingClass: che`
- `contributions[0].uri` containing `openshift-devspaces.svc.cluster.local`
- `projects[0].name: ansible-devspaces-summit`
- `projects[0].git.remotes.origin: https://github.com/leogallego/ansible-devspaces-summit.git`
- `components[0].container.image: ghcr.io/ansible/ansible-devspaces:v26.4.4`
- `components[0].container.memoryRequest: 2Gi`
- `components[0].container.cpuLimit: 2000m`
- `env` with `ANSIBLE_HOME`, `HOSTNAME`, `VSCODE_DEFAULT_WORKSPACE`

- [ ] **Step 3: Lint the chart**

Run: `helm lint ./bootstrap-tenant`

Expected: `1 chart(s) linted, 0 chart(s) failed`

- [ ] **Step 4: Commit**

```bash
git add bootstrap-tenant/templates/devworkspace.yaml
git commit -m "feat(tenant): rewrite DevWorkspace for ansible-devspaces image

- Add routingClass: che (per DevSpaces 3.27 docs)
- Use internal dashboard URI for editor contribution
- Add projects section to auto-clone ansible-devspaces-summit repo
- Add pod/container overrides for nested Podman support
- Set resource requests/limits (2Gi/4Gi, 500m/2000m)
- Add ANSIBLE_HOME, VSCODE_DEFAULT_WORKSPACE, HOSTNAME env vars

Refs #2"
```

---

### Task 3: Update bootstrap-infra CheCluster defaultComponents image

**Files:**
- Modify: `bootstrap-infra/templates/checluster.yaml` (lines 39-55, the `defaultComponents` section)

- [ ] **Step 1: Update the defaultComponents section**

In `bootstrap-infra/templates/checluster.yaml`, replace the `defaultComponents` block (lines 39-55) from:

```yaml
    defaultComponents:
    - attributes:
        container-overrides:
          securityContext:
            procMount: Unmasked
        pod-overrides:
          metadata:
            annotations:
              io.kubernetes.cri-o.Devices: "/dev/fuse,/dev/net/tun"
          spec:
            hostUsers: false
      container:
        image: "quay.io/cgruver0/che/dev-tools:latest"
        memoryLimit: 6Gi
        mountSources: true
        sourceMapping: /projects
      name: dev-tools
```

with:

```yaml
    defaultComponents:
    - attributes:
        container-overrides:
          securityContext:
            procMount: Unmasked
        pod-overrides:
          metadata:
            annotations:
              io.kubernetes.cri-o.Devices: "/dev/fuse,/dev/net/tun"
          spec:
            hostUsers: false
      container:
        image: "ghcr.io/ansible/ansible-devspaces:v26.4.4"
        memoryLimit: 4Gi
        mountSources: true
        sourceMapping: /projects
      name: dev-tools
```

Two changes: image from `quay.io/cgruver0/che/dev-tools:latest` to `ghcr.io/ansible/ansible-devspaces:v26.4.4`, and memoryLimit from `6Gi` to `4Gi`.

- [ ] **Step 2: Render the template and verify**

Run: `helm template bootstrap-infra ./bootstrap-infra`

Expected: the `defaultComponents` section should show:
- `image: "ghcr.io/ansible/ansible-devspaces:v26.4.4"`
- `memoryLimit: 4Gi`

- [ ] **Step 3: Lint the chart**

Run: `helm lint ./bootstrap-infra`

Expected: `1 chart(s) linted, 0 chart(s) failed`

- [ ] **Step 4: Commit**

```bash
git add bootstrap-infra/templates/checluster.yaml
git commit -m "feat(infra): update CheCluster defaultComponents image

Switch from quay.io/cgruver0/che/dev-tools:latest to the upstream
ghcr.io/ansible/ansible-devspaces:v26.4.4 image. Reduce default
memoryLimit from 6Gi to 4Gi to match tenant DevWorkspace config.

Refs #2"
```

---

### Task 4: Full validation and CLAUDE.md update

**Files:**
- Validate: `bootstrap-tenant/` and `bootstrap-infra/` charts
- Modify: `CLAUDE.md` (update architecture section to reflect new values structure)

- [ ] **Step 1: Render both charts and verify cross-chart consistency**

Run both:
```bash
helm template bootstrap-infra ./bootstrap-infra
helm template bootstrap-tenant ./bootstrap-tenant --set username=user1
```

Verify:
- The CheCluster `defaultComponents` image matches the DevWorkspace `components` image (`ghcr.io/ansible/ansible-devspaces:v26.4.4`)
- The CheCluster `containerBuildConfiguration.openShiftSecurityContextConstraint` still references the SCC name from `bootstrap-infra/values.yaml`
- Both charts lint clean

- [ ] **Step 2: Lint both charts**

```bash
helm lint ./bootstrap-infra
helm lint ./bootstrap-tenant
```

Expected: both pass with `0 chart(s) failed`

- [ ] **Step 3: Update CLAUDE.md Key Configuration section**

Update the Key Configuration section in `CLAUDE.md` to reflect the new values structure:

```markdown
## Key Configuration

- `bootstrap-infra/values.yaml`: cluster domain (`deployer.domain`), API URL (`deployer.apiUrl`), SCC name, CheCluster name/namespace
- `bootstrap-tenant/values.yaml`: `username` (default: `user1`), `cheCluster.namespace`, `devworkspace` (image, tag, resources, project repo)
- The SCC name in `bootstrap-infra` is referenced by the CheCluster's `containerBuildConfiguration`; these must stay in sync
- The container image must match between CheCluster `defaultComponents` (infra) and DevWorkspace `template.components` (tenant)
```

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md with new tenant values structure

Refs #2"
```

---

### Task 5: Create branch, push, and open PR

- [ ] **Step 1: Create feature branch from current commits**

If not already on a feature branch:
```bash
git checkout -b feat/devspaces-workspace-integration
```

Note: if work was done on main, create the branch and cherry-pick or reset as needed.

- [ ] **Step 2: Push and open PR**

```bash
git push -u origin feat/devspaces-workspace-integration
gh pr create --title "Integrate ansible-devspaces-summit workspace" --body "$(cat <<'EOF'
## Summary
- Update DevWorkspace to use upstream `ghcr.io/ansible/ansible-devspaces:v26.4.4` image
- Auto-clone `ansible-devspaces-summit` repo as a DevWorkspace project
- Add `routingClass: che` and internal dashboard URI for editor contribution
- Add pod/container overrides for nested Podman (`procMount`, `hostUsers`, `/dev/fuse`)
- Set resource requests/limits (2Gi/4Gi memory, 500m/2000m CPU)
- Update CheCluster `defaultComponents` to match

## Test plan
- [ ] `helm lint ./bootstrap-infra` passes
- [ ] `helm lint ./bootstrap-tenant` passes
- [ ] `helm template bootstrap-infra ./bootstrap-infra` renders correctly
- [ ] `helm template bootstrap-tenant ./bootstrap-tenant --set username=user1` renders correctly
- [ ] Deploy to test cluster and verify workspace starts with ansible-devspaces-summit auto-cloned
- [ ] Verify VS Code opens with `.code-workspace` settings applied
- [ ] Verify nested podman works inside the workspace

Closes #2

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```
