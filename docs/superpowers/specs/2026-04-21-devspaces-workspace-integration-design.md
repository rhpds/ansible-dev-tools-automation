# DevSpaces Workspace Integration Design

Integrate the [ansible-devspaces-summit](https://github.com/leogallego/ansible-devspaces-summit) workspace into the `bootstrap-tenant` Helm chart for automatic provisioning via ArgoCD.

Tracks: [Issue #2](https://github.com/leogallego/rhdp-ansible-dev-tools-automation/issues/2)

## Context

The current `bootstrap-tenant` DevWorkspace uses `quay.io/cgruver0/che/dev-tools:latest` with minimal configuration. The `ansible-devspaces-summit` repo provides a complete Ansible development environment (devfile, linter configs, VS Code workspace, ansible-navigator settings) built on the upstream `ghcr.io/ansible/ansible-devspaces:v26.4.4` image. This design integrates that workspace definition into the Helm chart so each lab participant gets a fully configured environment automatically.

## Approach

**Approach A: Git project reference** (selected). The `ansible-devspaces-summit` repo is added as a DevWorkspace project — DevSpaces auto-clones it on workspace start, bringing in all config files (`.ansible-lint`, `.yamllint`, `.editorconfig`, `.ansible-navigator.yml`, `devspaces.code-workspace`).

**Approach B: Inline embedding** (fallback). If the external git dependency becomes a problem, config files can be inlined into Helm templates. This is a straightforward migration from A.

## Files to Modify

### 1. `bootstrap-tenant/values.yaml`

Add configurable workspace parameters:

```yaml
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

### 2. `bootstrap-tenant/templates/devworkspace.yaml`

Full replacement of the DevWorkspace spec:

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

Key changes from current template:
- **`routingClass: che`** — required by DevSpaces for proper routing/auth (per docs section 10.3)
- **Internal dashboard URI** for editor contribution — avoids external internet dependency
- **`contributions` renamed** from `editor` to `ide` — matches docs convention
- **Component renamed** from `dev-tools` to `tooling-container` — matches upstream devfile
- **`projects` section** — auto-clones the config repo on workspace start
- **Pod/container overrides** — adds `procMount: Unmasked` (was missing from current template)
- **Resource requests and CPU limits** — bounded for shared cluster safety
- **Environment variables** — `ANSIBLE_HOME`, `VSCODE_DEFAULT_WORKSPACE`, `HOSTNAME`

### 3. `bootstrap-infra/templates/checluster.yaml`

Update `defaultComponents` image to match:

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

This keeps CheCluster defaults consistent with the DevWorkspace for any workspaces launched outside the Helm chart (e.g., manually from the DevSpaces dashboard).

## Cross-Chart Dependencies

| Value | bootstrap-infra | bootstrap-tenant |
|-------|----------------|-----------------|
| SCC name | `securityContextConstraints.name` | (referenced by CheCluster) |
| DevSpaces namespace | `cheCluster.namespace` | `cheCluster.namespace` |
| Container image | CheCluster `defaultComponents` | DevWorkspace `template.components` |

The SCC name and container image must stay in sync across both charts.

## Validation

```bash
helm template bootstrap-tenant ./bootstrap-tenant --set username=user1
helm template bootstrap-infra ./bootstrap-infra
helm lint ./bootstrap-tenant
helm lint ./bootstrap-infra
```

## References

- Source workspace: https://github.com/leogallego/ansible-devspaces-summit
- Upstream image: `ghcr.io/ansible/ansible-devspaces:v26.4.4`
- Red Hat OpenShift Dev Spaces 3.27 User Guide, Section 10.3 "Create Workspaces"
- Red Hat OpenShift Dev Spaces 3.27 Administration Guide, Section 2.3.3 "Dev Workspace operator"
- Devfile v2.2.2 spec: https://devfile.io/docs/2.2.0/
