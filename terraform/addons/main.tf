module "external_secrets" {
  source = "../modules/external_secrets"

  project_name              = var.project_name
  aws_region                = var.aws_region
  cluster_oidc_issuer_url   = var.cluster_oidc_issuer_url
  cluster_oidc_provider_arn = var.cluster_oidc_provider_arn
  database_secret_arn       = var.database_secret_arn
}

module "app_namespace" {
  source = "../modules/kubernetes_namespace"

  name = var.application_namespace
}
