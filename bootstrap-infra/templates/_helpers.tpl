{{/*
Return the host for the OpenVSX server
*/}}
{{- define "bootstrap.openvsx.host" -}}
{{- .Values.openvsx.route.host | default (printf "openvsx-server.%s" .Values.deployer.domain) | default "open-vsx.org" }}
{{- end -}}

{{/*
Return the URL for the OpenVSX server
*/}}
{{- define "bootstrap.openvsx.url" -}}
{{- printf "https://%s" (include "bootstrap.openvsx.host" .) }}
{{- end -}}

{{/*
Dev Spaces Image
*/}}
{{- define "bootstrap.devspaces.image" -}}
{{- printf "image-registry.openshift-image-registry.svc:5000/openshift/%s" (.Values.cheCluster.container.source | splitList "/" | last) }}
{{- end -}}

{{/*
EE Minimal Image
*/}}
{{- define "bootstrap.ee-minimal.image" -}}
{{- printf "image-registry.openshift-image-registry.svc:5000/openshift/%s" (.Values.eeImage | splitList "/" | last) }}
{{- end -}}
