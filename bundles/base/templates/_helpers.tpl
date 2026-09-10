{{/*
Common helpers shared across home-cloud bundles.
*/}}

{{- define "hc.labels" -}}
app.kubernetes.io/part-of: "home-cloud"
app.kubernetes.io/managed-by: "{{ .Release.Service }}"
helm.sh/chart: "{{ .Chart.Name }}-{{ .Chart.Version }}"
{{- end -}}

{{- define "hc.fqdn" -}}
{{- if contains "." .host -}}
{{ .host }}
{{- else -}}
{{ .host }}.{{ .domain }}
{{- end -}}
{{- end -}}
