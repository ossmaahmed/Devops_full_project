# Kubernetes monitoring

The `kube-prometheus-stack` chart installs Prometheus Operator, Prometheus, Alertmanager, Grafana, kube-state-metrics, and node-exporter. Its Kubernetes service discovery covers pods, kubelets, and nodes. Terraform separately installs the AWS CloudWatch Observability add-on for EKS nodes; Ansible installs the CloudWatch Agent on the Jenkins EC2.

Create the secrets before installing. Use a real Alertmanager-compatible webhook endpoint from your notification system; do not commit its URL or the Grafana password:

```powershell
kubectl create namespace monitoring
kubectl -n monitoring create secret generic grafana-admin `
  --from-literal=admin-user=admin `
  --from-literal=admin-password='REPLACE_WITH_A_STRONG_PASSWORD'
kubectl -n monitoring create secret generic alertmanager-webhook `
  --from-literal=webhook-url='REPLACE_WITH_YOUR_WEBHOOK_URL'
```

Install the stack and apply the project alerts/dashboard:

```powershell
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack `
  --namespace monitoring `
  --values monitoring/kube-prometheus-stack-values.yaml
kubectl apply -f monitoring/pod-resource-alerts.yaml
kubectl apply -f monitoring/nti-app-dashboard.yaml
```

The alert rules fire after CPU or memory remains above 80% of pod limits for five minutes. Notifications are delivered through the webhook secret. The app dashboard appears in Grafana under `NTI Application` after the sidecar discovers its ConfigMap. Terraform installs the EKS Metrics Server add-on for HPA resource metrics.

Open Grafana locally with:

```powershell
kubectl -n monitoring port-forward service/monitoring-grafana 3000:80
```

Then visit `http://localhost:3000` and sign in with the Grafana secret values.
