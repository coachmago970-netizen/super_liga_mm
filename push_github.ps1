param(
  [Parameter(Mandatory = $true)]
  [string]$RepoUrl,

  [string]$Branch = "main",
  [string]$CommitMessage = "chore: upload projeto",
  [string]$GitUserName = "",
  [string]$GitUserEmail = ""
)

$ErrorActionPreference = "Stop"

function Step([string]$message) {
  Write-Host ""
  Write-Host "==> $message" -ForegroundColor Cyan
}

function RunGit {
  param([string[]]$GitArgs)
  & git @GitArgs
  if ($LASTEXITCODE -ne 0) {
    throw "Falha ao executar: git $($GitArgs -join ' ')"
  }
}

function GetRepoOwner([string]$url) {
  if ($url -match "github\.com[:/](?<owner>[^/]+)/(?<repo>[^/]+?)(\.git)?$") {
    return $Matches["owner"]
  }
  return ""
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  throw "Git nao encontrado. Instale o Git e tente novamente."
}

$projectRoot = $PSScriptRoot
Set-Location $projectRoot

Step "Marcando pasta como segura no Git"
RunGit @("config", "--global", "--add", "safe.directory", $projectRoot)

Step "Preparando repositorio"
if (-not (Test-Path ".git")) {
  RunGit @("init")
}

RunGit @("checkout", "-B", $Branch)

Step "Configurando identidade do commit"
$configuredName = [string](& git config user.name 2>$null)
$configuredEmail = [string](& git config user.email 2>$null)
$configuredName = $configuredName.Trim()
$configuredEmail = $configuredEmail.Trim()

if ([string]::IsNullOrWhiteSpace($configuredName) -or [string]::IsNullOrWhiteSpace($configuredEmail)) {
  $owner = GetRepoOwner $RepoUrl
  $fallbackName = if ($owner) { $owner } else { "super-liga-mm" }
  $fallbackEmail = if ($owner) { "$owner@users.noreply.github.com" } else { "super-liga-mm@users.noreply.github.com" }

  $finalName = if ([string]::IsNullOrWhiteSpace($GitUserName)) { $fallbackName } else { $GitUserName.Trim() }
  $finalEmail = if ([string]::IsNullOrWhiteSpace($GitUserEmail)) { $fallbackEmail } else { $GitUserEmail.Trim() }

  RunGit @("config", "user.name", $finalName)
  RunGit @("config", "user.email", $finalEmail)
  Write-Host "Identidade configurada para este projeto: $finalName <$finalEmail>"
}

Step "Adicionando arquivos"
RunGit @("add", "-A")

Step "Criando commit (se houver alteracoes)"
& git diff --cached --quiet
if ($LASTEXITCODE -eq 1) {
  RunGit @("commit", "-m", $CommitMessage)
} elseif ($LASTEXITCODE -gt 1) {
  throw "Falha ao verificar alteracoes com git diff --cached --quiet"
} else {
  Write-Host "Nenhuma alteracao nova para commit."
}

Step "Configurando remoto origin"
$originExists = $false
& git remote get-url origin *> $null
if ($LASTEXITCODE -eq 0) { $originExists = $true }

if ($originExists) {
  RunGit @("remote", "set-url", "origin", $RepoUrl)
} else {
  RunGit @("remote", "add", "origin", $RepoUrl)
}

Step "Enviando para o GitHub"
RunGit @("push", "-u", "origin", $Branch)

Write-Host ""
Write-Host "Upload concluido com sucesso." -ForegroundColor Green
