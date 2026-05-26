# ============================================================
#  CHAN HUNG HOLDING - INSTALL PS-AGENT
#  Version: 1.0
#  Purpose: Install agent on client to auto-pull and execute modules
#  Requirement: Run with Administrator privileges
# ============================================================

#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [string]$GitHubOwner = "quyenpv",
    [string]$GitHubRepo = "chanhung-it-security",
    [string]$Branch = "main",
    [string]$InstallPath = "C:\Program Files\ChanHung\PS-Agent",
    [string]$PAT,
    [switch]$Uninstall,
    [switch]$Force
)

$ServiceName = "ChanHungPSAgent"
$ServiceDisplayName = "ChanHung PS Agent"
$ServiceDescription = "ChanHung Holding - Policy Agent: Auto pull and execute modules from GitHub"
$CheckIntervalMinutes = 15

function Write-Step  ([string]$Text) { Write-Host "`n  ► $Text" -ForegroundColor Yellow }
function Write-OK    ([string]$Text) { Write-Host "    [OK] $Text" -ForegroundColor Green }
function Write-Warn  ([string]$Text) { Write-Host "    [!] $Text" -ForegroundColor DarkYellow }
function Write-Err   ([string]$Text) { Write-Host "    [X] $Text" -ForegroundColor Red }
function Write-Info  ([string]$Text) { Write-Host "    [-] $Text" -ForegroundColor Gray }

function Save-AgentToken {
    param([string]$Token)
    $regPath = "HKLM:\SOFTWARE\ChanHung\PS-Agent"
    if (-not (Test-Path $regPath)) {
        New-Item -Path $regPath -Force | Out-Null
    }
    $secureToken = ConvertTo-SecureString $Token -AsPlainText -Force
    $encryptedToken = ConvertFrom-SecureString $secureToken
    Set-ItemProperty -Path $regPath -Name "GitHubPAT" -Value $encryptedToken -Force
    Write-OK "Saved GitHub PAT (encrypted) to registry"
}

function Get-AgentToken {
    $regPath = "HKLM:\SOFTWARE\ChanHung\PS-Agent"
    if (Test-Path $regPath) {
        $encryptedToken = Get-ItemProperty -Path $regPath -Name "GitHubPAT" -ErrorAction SilentlyContinue
        if ($encryptedToken) {
            $secureToken = ConvertTo-SecureString $encryptedToken.GitHubPAT
            $token = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
                [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
            )
            return $token
        }
    }
    return $null
}

function Remove-AgentToken {
    $regPath = "HKLM:\SOFTWARE\ChanHung\PS-Agent"
    if (Test-Path $regPath) {
        Remove-ItemProperty -Path $regPath -Name "GitHubPAT" -ErrorAction SilentlyContinue
    }
}

function Test-GitInstalled {
    try {
        $gitVersion = & git --version 2>&1
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    }
}

if ($Uninstall) {
    Write-Host ""
    Write-Host "  UNINSTALL PS-AGENT" -ForegroundColor Cyan
    Write-Host ""
    Write-Step "Stopping and removing Windows Service..."
    $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if ($service) {
        Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
        & sc.exe delete $ServiceName 2>&1 | Out-Null
        Write-OK "Removed service"
    } else {
        Write-Warn "Service does not exist"
    }
    Write-Step "Removing installation files..."
    if (Test-Path $InstallPath) {
        Remove-Item -Path $InstallPath -Recurse -Force -ErrorAction SilentlyContinue
        Write-OK "Removed installation directory"
    }
    Write-Step "Removing GitHub PAT from registry..."
    Remove-AgentToken
    Write-OK "Removed token"
    Write-Step "Removing scheduled task..."
    Unregister-ScheduledTask -TaskName "ChanHungPSAgent-Pull" -ErrorAction SilentlyContinue
    Write-Host ""
    Write-OK "PS-Agent uninstall completed!"
    exit 0
}

Write-Host ""
Write-Host "  INSTALL PS-AGENT" -ForegroundColor Cyan
Write-Host ""

Write-Step "Checking Git..."
if (-not (Test-GitInstalled)) {
    Write-Err "Git is not installed!"
    Write-Info "Please install Git from: https://git-scm.com/download/win"
    exit 1
}
Write-OK "Git is installed"

Write-Step "Configuring GitHub Authentication..."
if ([string]::IsNullOrWhiteSpace($PAT)) {
    $existingToken = Get-AgentToken
    if ($existingToken) {
        Write-Info "Found existing GitHub PAT in registry"
        $useExisting = Read-Host "Use existing token? (Y/N)"
        if ($useExisting -eq "Y" -or $useExisting -eq "y") {
            $PAT = $existingToken
        } else {
            $PAT = Read-Host "Enter new GitHub PAT"
        }
    } else {
        $PAT = Read-Host "Enter GitHub PAT"
    }
}

if ([string]::IsNullOrWhiteSpace($PAT)) {
    Write-Err "GitHub PAT cannot be empty!"
    exit 1
}

Save-AgentToken -Token $PAT

Write-Step "Creating installation directory..."
if (-not (Test-Path $InstallPath)) {
    New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
    Write-OK "Created directory: $InstallPath"
} else {
    Write-Info "Directory already exists: $InstallPath"
}

Write-Step "Cloning/Pulling repository from GitHub..."
$repoPath = Join-Path $InstallPath "repo"

if (Test-Path $repoPath) {
    Write-Info "Repository exists, pulling..."
    Set-Location $repoPath
    & git fetch origin
    & git pull origin $Branch
    if ($LASTEXITCODE -eq 0) {
        Write-OK "Pull successful"
    } else {
        Write-Warn "Pull failed, re-cloning..."
        Set-Location $InstallPath
        Remove-Item -Path $repoPath -Recurse -Force -ErrorAction SilentlyContinue
        & git clone "https://${PAT}@github.com/${GitHubOwner}/${GitHubRepo}.git" repo
        if ($LASTEXITCODE -eq 0) {
            Write-OK "Clone successful"
        } else {
            Write-Err "Clone failed. Check PAT and access permissions."
            exit 1
        }
    }
} else {
    Set-Location $InstallPath
    & git clone "https://${PAT}@github.com/${GitHubOwner}/${GitHubRepo}.git" repo
    if ($LASTEXITCODE -eq 0) {
        Write-OK "Clone successful"
    } else {
        Write-Err "Clone failed. Check PAT and access permissions."
        exit 1
    }
}

Write-Step "Creating main agent script..."
$agentScript = @'
# ChanHung PS Agent - Main Script
$ErrorActionPreference = "Continue"

$config = @{
    InstallPath = "C:\Program Files\ChanHung\PS-Agent"
    GitHubOwner = "quyenpv"
    GitHubRepo = "chanhung-it-security"
    Branch = "main"
}

$repoPath = Join-Path $config.InstallPath "repo"
$manifestPath = Join-Path $repoPath "manifest.json"
$modulesPath = Join-Path $repoPath "modules"
$logPath = Join-Path $config.InstallPath "logs"

if (-not (Test-Path $logPath)) {
    New-Item -ItemType Directory -Path $logPath -Force | Out-Null
}

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logFile = Join-Path $logPath "agent-$(Get-Date -Format 'yyyyMMdd').log"
    "$timestamp - $Message" | Out-File -FilePath $logFile -Append
}

function Get-AgentToken {
    $regPath = "HKLM:\SOFTWARE\ChanHung\PS-Agent"
    if (Test-Path $regPath) {
        $encryptedToken = Get-ItemProperty -Path $regPath -Name "GitHubPAT" -ErrorAction SilentlyContinue
        if ($encryptedToken) {
            $secureToken = ConvertTo-SecureString $encryptedToken.GitHubPAT
            $token = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
                [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
            )
            return $token
        }
    }
    return $null
}

function Update-Repository {
    Write-Log "Updating repository..."
    try {
        Set-Location $repoPath
        $pat = Get-AgentToken
        if (-not $pat) {
            Write-Log "ERROR: GitHub PAT not found"
            return $false
        }
        $oldCommit = & git rev-parse HEAD
        & git fetch origin
        & git pull origin $config.Branch
        if ($LASTEXITCODE -eq 0) {
            $newCommit = & git rev-parse HEAD
            if ($oldCommit -ne $newCommit) {
                Write-Log "Repository updated successfully (changes detected)"
                return $true, $true
            } else {
                Write-Log "Repository updated (no changes)"
                return $true, $false
            }
        } else {
            Write-Log "ERROR: Pull failed"
            return $false, $false
        }
    } catch {
        Write-Log "ERROR: $($_.ToString())"
        return $false, $false
    }
}

function Get-FileSHA256 {
    param([string]$FilePath)
    if (Test-Path $FilePath) {
        $hash = Get-FileHash -Path $FilePath -Algorithm SHA256
        return $hash.Hash.ToLower()
    }
    return $null
}

function Invoke-Modules {
    Write-Log "Executing modules..."
    if (-not (Test-Path $manifestPath)) {
        Write-Log "ERROR: manifest.json not found"
        return
    }
    try {
        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
        $hostname = $env:COMPUTERNAME.ToUpper()
        foreach ($moduleName in $manifest.modules.PSObject.Properties.Name) {
            $moduleConfig = $manifest.modules.$moduleName
            if (-not $moduleConfig.enabled) {
                continue
            }
            if ($moduleConfig.target -ne "*" -and $hostname -notlike $moduleConfig.target) {
                continue
            }
            $moduleFile = Join-Path $modulesPath $moduleConfig.filename
            if (-not (Test-Path $moduleFile)) {
                Write-Log "ERROR: Module file not found: $moduleFile"
                continue
            }
            if ($moduleConfig.sha256) {
                $actualSHA256 = Get-FileSHA256 -FilePath $moduleFile
                if ($actualSHA256 -ne $moduleConfig.sha256.ToLower()) {
                    Write-Log "ERROR: SHA256 mismatch for module $moduleName"
                    Write-Log "  Expected: $($moduleConfig.sha256)"
                    Write-Log "  Actual: $actualSHA256"
                    continue
                }
            }
            Write-Log "Executing module: $moduleName"
            try {
                & $moduleFile
                Write-Log "Module executed: $moduleName"
            } catch {
                Write-Log "ERROR executing module $moduleName: $($_.ToString())"
            }
        }
    } catch {
        Write-Log "ERROR: $($_.ToString())"
    }
}

function Invoke-Commands {
    Write-Log "Checking commands..."
    if (-not (Test-Path $manifestPath)) {
        return
    }
    try {
        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
        $hostname = $env:COMPUTERNAME.ToUpper()
        foreach ($cmd in $manifest.commands.emergency) {
            if ($cmd.executed) { continue }
            if ($cmd.target -ne "*" -and $hostname -notlike $cmd.target) { continue }
            Write-Log "Executing emergency command: $($cmd.id)"
            try {
                Invoke-Expression $cmd.code
                Write-Log "Emergency command executed: $($cmd.id)"
            } catch {
                Write-Log "ERROR executing emergency command: $($_.ToString())"
            }
        }
        foreach ($cmd in $manifest.commands.scheduled) {
            if ($cmd.executed) { continue }
            if ($cmd.target -ne "*" -and $hostname -notlike $cmd.target) { continue }
            Write-Log "Executing scheduled command: $($cmd.id)"
            try {
                Invoke-Expression $cmd.code
                Write-Log "Scheduled command executed: $($cmd.id)"
            } catch {
                Write-Log "ERROR executing scheduled command: $($_.ToString())"
            }
        }
    } catch {
        Write-Log "ERROR: $($_.ToString())"
    }
}

Write-Log "=== PS Agent Started ==="
while ($true) {
    $updateSuccess, $hasChanges = Update-Repository
    if ($updateSuccess -and $hasChanges) {
        Write-Log "Code changes detected, re-running installation..."
        try {
            $installScript = Join-Path $repoPath "ChanHung_IT_Install.ps1"
            if (Test-Path $installScript) {
                & $installScript
                Write-Log "Re-installation completed successfully"
            } else {
                Write-Log "Installation script not found: $installScript"
            }
        } catch {
            Write-Log "ERROR during re-installation: $($_.ToString())"
        }
    }
    Invoke-Modules
    Invoke-Commands
    Write-Log "Waiting 15 minutes..."
    Start-Sleep -Seconds 900
}
'@

$agentScriptPath = Join-Path $InstallPath "PS-Agent.ps1"
$agentScript -replace "quyenpv", $GitHubOwner -replace "chanhung-it-security", $GitHubRepo -replace "main", $Branch -replace "C:\\Program Files\\ChanHung\\PS-Agent", $InstallPath | Set-Content $agentScriptPath

Write-OK "Created main agent script"

Write-Step "Creating scheduled task..."
$taskAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$agentScriptPath`""
$taskTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes $CheckIntervalMinutes)
Register-ScheduledTask -TaskName "ChanHungPSAgent-Pull" -Action $taskAction -Trigger $taskTrigger -Description $ServiceDescription -User "SYSTEM" -RunLevel Highest -Force | Out-Null
Write-OK "Created scheduled task"

Write-Host ""
Write-OK "PS-Agent installation completed!"
Write-Host ""
Write-Host "  Installation info:"
Write-Host "    - Path: $InstallPath"
Write-Host "    - Repository: https://github.com/${GitHubOwner}/${GitHubRepo}"
Write-Host "    - Branch: $Branch"
Write-Host "    - Check interval: $CheckIntervalMinutes minutes"
Write-Host ""
Write-Info "Agent will auto-pull and execute modules every $CheckIntervalMinutes minutes"
Write-Info "View logs at: $InstallPath\logs"
Write-Info "To uninstall, run: .\Install-ChanHungAgent.ps1 -Uninstall"
