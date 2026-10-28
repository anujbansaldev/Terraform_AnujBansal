param(
  [Parameter(Mandatory = $true)][string]$BackendRepository,
  [Parameter(Mandatory = $true)][string]$FrontendRepository,
  [Parameter(Mandatory = $true)][string]$Tag
)

$ErrorActionPreference = "Stop"
Write-Warning "This script performs an ECR login and image push. Review and run it only during deployment."
aws ecr get-login-password | docker login --username AWS --password-stdin (($BackendRepository -split '/')[0])
docker push "$BackendRepository`:$Tag"
docker push "$FrontendRepository`:$Tag"
