{{- define "hc-sls.labels" -}}
app.kubernetes.io/part-of: "home-cloud"
app.kubernetes.io/managed-by: "{{ .Release.Service }}"
helm.sh/chart: "{{ .Chart.Name }}-{{ .Chart.Version }}"
{{- end -}}
{{- define "hc-sls.fqdn" -}}
{{- if contains "." .host -}}{{ .host }}{{- else -}}{{ .host }}.{{ .domain }}{{- end -}}
{{- end -}}
