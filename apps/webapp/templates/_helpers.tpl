{{- define "webapp.labels" -}}
app.kubernetes.io/name: webapp
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
environment: {{ .Values.environment }}
{{- end }}

{{- define "webapp.selectorLabels" -}}
app.kubernetes.io/name: webapp
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
