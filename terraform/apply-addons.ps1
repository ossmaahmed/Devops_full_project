$ErrorActionPreference = "Stop"
$terraformRoot = $PSScriptRoot
$addonsRoot = Join-Path $terraformRoot "addons"

function Get-TerraformOutput([string]$Name) {
  $value = & terraform "-chdir=$terraformRoot" output -raw $Name
  if ($LASTEXITCODE -ne 0) {
    throw "Could not read Terraform output '$Name'. Apply the core configuration first."
  }
  return $value.Trim()
}

$variables = @{
  aws_region                = Get-TerraformOutput "aws_region"
  project_name              = Get-TerraformOutput "project_name"
  cluster_name              = Get-TerraformOutput "eks_cluster_name"
  cluster_oidc_issuer_url   = Get-TerraformOutput "eks_cluster_oidc_issuer_url"
  cluster_oidc_provider_arn = Get-TerraformOutput "eks_cluster_oidc_provider_arn"
  database_secret_arn       = Get-TerraformOutput "rds_secret_arn"
}

$initArgs = @("-chdir=$addonsRoot", "init")
$addonsBackend = Join-Path $addonsRoot "backend.tf"
$addonsBackendConfig = Join-Path $addonsRoot "backend.hcl"
if (Test-Path $addonsBackend) {
  if (-not (Test-Path $addonsBackendConfig)) {
    throw "Copy backend.hcl.example to backend.hcl and set the remote bucket before initializing addons."
  }
  $initArgs += "-backend-config=$addonsBackendConfig"
  $initArgs += "-migrate-state"
}
& terraform @initArgs
if ($LASTEXITCODE -ne 0) { throw "Terraform addons init failed." }

$workspace = & terraform "-chdir=$terraformRoot" workspace show
if ($LASTEXITCODE -ne 0) { throw "Could not read the active core Terraform workspace." }
$workspace = $workspace.Trim()

$workspaces = & terraform "-chdir=$addonsRoot" workspace list
if ($LASTEXITCODE -ne 0) { throw "Could not list Terraform addons workspaces." }
$existingWorkspaces = @($workspaces | ForEach-Object { $_.Trim() -replace "^\* ", "" })
if ($existingWorkspaces -notcontains $workspace) {
  & terraform "-chdir=$addonsRoot" workspace new $workspace
}
else {
  & terraform "-chdir=$addonsRoot" workspace select $workspace
}
if ($LASTEXITCODE -ne 0) { throw "Could not select the '$workspace' addons workspace." }

$applyArgs = @("-chdir=$addonsRoot", "apply")
foreach ($entry in $variables.GetEnumerator()) {
  $applyArgs += "-var=$($entry.Key)=$($entry.Value)"
}
& terraform @applyArgs
if ($LASTEXITCODE -ne 0) { throw "Terraform addons apply failed." }
