{{/*
Common helpers for the auth chart.
*/}}
{{- define "hc-auth.labels" -}}
app.kubernetes.io/part-of: "home-cloud"
app.kubernetes.io/managed-by: "{{ .Release.Service }}"
helm.sh/chart: "{{ .Chart.Name }}-{{ .Chart.Version }}"
{{- end -}}

{{- define "hc-auth.fqdn" -}}
{{- if contains "." .host -}}{{ .host }}{{- else -}}{{ .host }}.{{ .domain }}{{- end -}}
{{- end -}}
