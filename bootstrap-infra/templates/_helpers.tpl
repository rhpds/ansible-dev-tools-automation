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
Dev Spaces Image — resolves to the internal registry path for the first synced image
*/}}
{{- define "bootstrap.devspaces.image" -}}
{{- $first := index .Values.imageSync.images 0 -}}
{{- printf "%s/%s/%s" .Values.imageSync.destination.registry .Values.imageSync.destination.namespace $first.destination }}
{{- end -}}
