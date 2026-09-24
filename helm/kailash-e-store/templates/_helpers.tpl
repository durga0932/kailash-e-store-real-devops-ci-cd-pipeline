{{- define "kailash-e-store.name" -}}
{{- .Chart.Name -}}
{{- end -}}

{{- define "kailash-e-store.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
