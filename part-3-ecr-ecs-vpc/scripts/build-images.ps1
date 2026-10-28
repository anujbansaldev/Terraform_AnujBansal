param(
  [Parameter(Mandatory = $true)][string]$BackendRepository,
  [Parameter(Mandatory = $true)][string]$FrontendRepository,
  [Parameter(Mandatory = $true)][string]$Tag
)

$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
docker build -f (Join-Path $repoRoot "part-3-ecr-ecs-vpc\ecr\backend.Dockerfile") -t "$BackendRepository`:$Tag" $repoRoot
docker build -f (Join-Path $repoRoot "part-3-ecr-ecs-vpc\ecr\frontend.Dockerfile") -t "$FrontendRepository`:$Tag" $repoRoot
Write-Host "Images built locally. Push only after reviewing the repository and tag."
