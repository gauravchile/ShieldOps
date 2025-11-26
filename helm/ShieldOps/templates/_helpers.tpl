{{/*
Generate a chart name
*/}}
{{- define "shieldops.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Generate a fully qualified app name
*/}}
{{- define "shieldops.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" (include "shieldops.name" .) .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end -}}

{{/*
Generate API component name (for backend deployments, services, etc.)
*/}}
{{- define "shieldops.apiFullname" -}}
{{- printf "%s-api" (include "shieldops.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Chart label helper
*/}}
{{- define "shieldops.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" -}}
{{- end -}}

{{/*
Common selector labels
*/}}
{{- define "shieldops.selectorLabels" -}}
app.kubernetes.io/name: {{ include "shieldops.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Common metadata labels
*/}}
{{- define "shieldops.labels" -}}
helm.sh/chart: {{ include "shieldops.chart" . }}
{{ include "shieldops.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}
