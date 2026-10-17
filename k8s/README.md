# Kubernetes manifests

This standalone manifest set runs the frontend, backend, and MySQL in Kubernetes. The AWS pipeline uses the Helm chart in `app/helm/nti-app` and Terraform-managed RDS instead; do not deploy both paths into the same namespace.

The manifests are grouped by component and can be applied together with Kustomize:

Before applying:

1. Replace the example frontend and backend image references with immutable images from your registry.
2. Copy `secrets/secrets.example.yaml` to `secrets/secrets.yaml` once and set strong passwords:

   ```powershell
   Copy-Item k8s/secrets/secrets.example.yaml k8s/secrets/secrets.yaml
   ```

   `secrets.yaml` is gitignored. Never commit real credentials or use the example passwords.
3. Update the VPC CIDR in `policies/networkpolicy.yaml` to match the cluster VPC.

Apply the namespace first, then the local Secret and the remaining resources:

```powershell
kubectl apply -f k8s/namespace/namespace.yaml
kubectl apply -f k8s/secrets/secrets.yaml
kubectl apply -k k8s
```

The frontend Service uses NodePort `30080` to match the Terraform ALB target group. The network policies permit VPC ingress to the frontend, frontend-to-backend, backend-to-MySQL, and DNS only.
