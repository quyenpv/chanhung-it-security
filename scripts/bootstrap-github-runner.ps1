# One-file bootstrap for a GitHub Actions self-hosted runner on Windows Server.
# Run once from an elevated Windows PowerShell 5.1 session.
[CmdletBinding()]
param(
  [string]$RepositoryUrl,
  [string]$ProjectLabel,
  [string]$RunnerName = $env:COMPUTERNAME,
  [string]$RunnerRoot,
  [ValidateSet("x64", "arm64")]
  [string]$Architecture = "x64",
  [string]$RunnerVersion
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Assert-Administrator {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object Security.Principal.WindowsPrincipal($identity)
  if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Run this script from an elevated PowerShell session (Run as Administrator)."
  }
}

function Read-RequiredValue([string]$Prompt, [string]$CurrentValue) {
  $value = $CurrentValue
  if ([string]::IsNullOrWhiteSpace($value)) {
    $value = Read-Host $Prompt
  }
  if ([string]::IsNullOrWhiteSpace($value)) {
    throw "$Prompt is required."
  }
  return $value.Trim()
}

function Get-PlainText([Security.SecureString]$SecureValue) {
  $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureValue)
  try {
    return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
  } finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
  }
}

function Invoke-Native([string]$FilePath, [string[]]$Arguments) {
  & $FilePath @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "Command failed with exit code $LASTEXITCODE`: $FilePath"
  }
}

Assert-Administrator
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$RepositoryUrl = Read-RequiredValue "GitHub repository URL (https://github.com/owner/repo)" $RepositoryUrl
$ProjectLabel = Read-RequiredValue "Unique project runner label (for example my-project-production)" $ProjectLabel

if ($RepositoryUrl -notmatch '^https://github\.com/[^/]+/[^/]+/?$') {
  throw "RepositoryUrl must look like https://github.com/owner/repo"
}
if ($ProjectLabel -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{1,63}$') {
  throw "ProjectLabel must be 2-64 characters and contain only letters, numbers, dot, underscore, or hyphen."
}
if ($RunnerName -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$') {
  throw "RunnerName contains unsupported characters."
}

if ([string]::IsNullOrWhiteSpace($RunnerRoot)) {
  $RunnerRoot = "C:\actions-runner-$ProjectLabel"
}
$RunnerRoot = [IO.Path]::GetFullPath($RunnerRoot)
if (-not $RunnerRoot.StartsWith("C:\", [StringComparison]::OrdinalIgnoreCase)) {
  throw "RunnerRoot must be an absolute path on drive C:."
}

$releaseUri = if ([string]::IsNullOrWhiteSpace($RunnerVersion)) {
  "https://api.github.com/repos/actions/runner/releases/latest"
} else {
  $normalizedVersion = $RunnerVersion.TrimStart('v')
  "https://api.github.com/repos/actions/runner/releases/tags/v$normalizedVersion"
}

$headers = @{
  "Accept" = "application/vnd.github+json"
  "User-Agent" = "GreenCould-Runner-Bootstrap"
  "X-GitHub-Api-Version" = "2022-11-28"
}
$release = Invoke-RestMethod -Uri $releaseUri -Headers $headers -UseBasicParsing
$version = ([string]$release.tag_name).TrimStart('v')
$assetName = "actions-runner-win-$Architecture-$version.zip"
$asset = $release.assets | Where-Object { $_.name -eq $assetName } | Select-Object -First 1
if (-not $asset) {
  throw "Runner asset not found: $assetName"
}

New-Item -ItemType Directory -Path $RunnerRoot -Force | Out-Null
if (Test-Path -LiteralPath (Join-Path $RunnerRoot ".runner")) {
  throw "RunnerRoot is already configured: $RunnerRoot. Remove it through GitHub and config.cmd remove before reinstalling."
}

$archivePath = Join-Path $env:TEMP $assetName
try {
  Write-Host "Downloading GitHub Actions Runner $version..."
  Invoke-WebRequest -Uri $asset.browser_download_url -Headers $headers -UseBasicParsing -OutFile $archivePath

  $expectedDigest = [string]$asset.digest
  if (-not [string]::IsNullOrWhiteSpace($expectedDigest)) {
    $expectedHash = $expectedDigest -replace '^sha256:', ''
    $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $archivePath).Hash
    if ($actualHash -ine $expectedHash) {
      throw "Runner archive SHA-256 mismatch."
    }
    Write-Host "Runner archive SHA-256 verified."
  } else {
    Write-Warning "GitHub API did not provide an asset digest; TLS download completed but SHA-256 could not be pinned."
  }

  Expand-Archive -LiteralPath $archivePath -DestinationPath $RunnerRoot -Force
} finally {
  Remove-Item -LiteralPath $archivePath -Force -ErrorAction SilentlyContinue
}

$secureToken = Read-Host "Paste the short-lived GitHub runner registration token" -AsSecureString
$registrationToken = Get-PlainText $secureToken
if ([string]::IsNullOrWhiteSpace($registrationToken)) {
  throw "Runner registration token is required."
}

try {
  Push-Location $RunnerRoot
  try {
    Invoke-Native ".\config.cmd" @(
      "--unattended",
      "--url", $RepositoryUrl.TrimEnd('/'),
      "--token", $registrationToken,
      "--name", $RunnerName,
      "--labels", $ProjectLabel,
      "--work", "_work",
      "--replace"
    )
    Invoke-Native ".\svc.cmd" @("install")
    Invoke-Native ".\svc.cmd" @("start")
  } finally {
    Pop-Location
  }
} finally {
  $registrationToken = $null
  $secureToken.Dispose()
}

$escapedRoot = [Regex]::Escape($RunnerRoot)
$service = Get-CimInstance Win32_Service | Where-Object {
  $_.Name -like "actions.runner.*" -and $_.PathName -match $escapedRoot
} | Select-Object -First 1
if (-not $service) {
  throw "Runner was configured, but its Windows service was not found for $RunnerRoot"
}

Set-Service -Name $service.Name -StartupType Automatic
Start-Service -Name $service.Name
$serviceState = Get-Service -Name $service.Name
if ($serviceState.StartType -ne "Automatic" -or $serviceState.Status -ne "Running") {
  throw "Runner service verification failed: startup=$($serviceState.StartType), status=$($serviceState.Status)"
}

Write-Host "Runner installation completed."
Write-Host "Service: $($serviceState.Name)"
Write-Host "Startup: $($serviceState.StartType)"
Write-Host "Status:  $($serviceState.Status)"
Write-Host "Labels required by workflow: self-hosted, windows, $Architecture, $ProjectLabel"
Write-Host "Confirm the runner is Online in GitHub before enabling production deploy."
