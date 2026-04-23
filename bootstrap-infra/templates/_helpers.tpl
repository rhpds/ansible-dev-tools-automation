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
