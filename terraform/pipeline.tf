locals {
  pipeline_environment_parameters = {
    for parameter in flatten([
      for branch, target in var.pipeline_environments : [
        for key, value in target : {
          name  = "${branch}/${replace(key, "_", "-")}"
          value = value
        }
      ]
    ]) : parameter.name => parameter.value
  }
}

resource "aws_ssm_parameter" "pipeline_deploy_branches" {
  name        = "/${var.project_name}/pipeline/deploy-branches"
  description = "Branches with configured deployment targets"
  type        = "String"
  value       = length(var.pipeline_environments) > 0 ? join(",", sort(keys(var.pipeline_environments))) : "__none__"
}

resource "aws_ssm_parameter" "pipeline_environment" {
  for_each = local.pipeline_environment_parameters

  name        = "/${var.project_name}/pipeline/environments/${each.key}"
  description = "Non-secret deployment target for a Jenkins multibranch pipeline"
  type        = "String"
  value       = each.value
}
