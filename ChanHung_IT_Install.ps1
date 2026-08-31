# ============================================================
#  CHẤN HƯNG HOLDING - IT INSTALL HELPER  v3.0
#  Mở/đóng khóa Nuclear Lockdown + GitHub Auto-Update Agent
# ============================================================
#Requires -RunAsAdministrator
param(
    [string]$GoogleScriptURL = "https://script.google.com/macros/s/PASTE_YOUR_DEPLOYMENT_URL_HERE/exec",
    [int]$TimeoutMinutes     = 30,
    [switch]$Silent,

    # ── GitHub Agent config ──────────────────────────────────────
    [string]$GitHubOwner  = "chanhung-it",
    [string]$GitHubRepo   = "ps-agent",
    [string]$GitHubBranch = "main"
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

function Write-Header {
    Clear-Host
    Write-Host ""
    Write-Host "  =====================================================" -ForegroundColor Cyan
    Write-Host "  CHAN HUNG HOLDING - IT INSTALL HELPER  v3.0         " -ForegroundColor Cyan
    Write-Host "  NUCLEAR LOCKDOWN + GITHUB AUTO-UPDATE AGENT         " -ForegroundColor Cyan
    Write-Host "  =====================================================" -ForegroundColor Cyan
    Write-Host ""
}
function Write-OK   ([string]$T) { Write-Host "    [OK] $T" -ForegroundColor Green }
function Write-Warn ([string]$T) { Write-Host "    [!] $T" -ForegroundColor DarkYellow }
function Write-Err  ([string]$T) { Write-Host "    [ERR] $T" -ForegroundColor Red }
function Write-Info ([string]$T) { Write-Host "    [-] $T" -ForegroundColor Gray }
function Write-Step ([string]$T) { Write-Host "`n  > $T" -ForegroundColor Yellow }

function Set-Reg {
    param([string]$Path,[string]$Name,$Value,[string]$Type="DWord")
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force
}

# ─────────────────────────────────────────────────────────────
#  KHOA - ap dung lai tat ca 8 lop
# ─────────────────────────────────────────────────────────────
function Invoke-Lock {
    Write-Step "Dang KHOA lai tat ca 8 lop Nuclear Lockdown..."

    # Lớp 1: MSI
    $pi = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer"
    Set-Reg $pi "DisableMSI"            2
    Set-Reg $pi "EnableUserControl"     0
    Set-Reg $pi "AlwaysInstallElevated" 0
    Set-Reg $pi "DisablePatch"          1
    Set-Reg $pi "DisableLockdownPatch"  1
    Set-Reg "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Installer" "AlwaysInstallElevated" 0

    # Lớp 2: AppLocker service
    try { Set-Service "AppIDSvc" -StartupType Automatic; Start-Service "AppIDSvc" -ErrorAction SilentlyContinue } catch {}

    # Lớp 3: SRP
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Safer\CodeIdentifiers" "DefaultLevel" 131072

    # Lớp 5: WSH
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows Script Host\Settings" "Enabled" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows Script Host\Settings" "Enabled" 0

    # Lớp 6: PS Constrained
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "__PSLockdownPolicy" "4" String

    # Lớp 7: Package managers
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppInstaller" "EnableAppInstaller" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppInstaller" "EnableWindowsPackageManagerCommandLineInterfaces" 0

    # Lớp 8: Anti-bypass
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" "NoRun" 1
    Set-Reg "HKCU:\SOFTWARE\Policies\Microsoft\Windows\System" "DisableCMD" 2
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" "DisableRegistryTools" 1
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" "NoDriveTypeAutoRun" 255

    Write-OK "May da KHOA lai - tat ca 8 lop dang hoat dong"
    Write-Warn "Khoi dong lai may de mot so policy co hieu luc day du"
}

# ─────────────────────────────────────────────────────────────
#  MO KHOA - go tat ca 8 lop
# ─────────────────────────────────────────────────────────────
function Invoke-Unlock {
    Write-Step "Dang MO KHOA tat ca 8 lop..."

    # Lớp 1: MSI
    $pi = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer"
    Remove-ItemProperty $pi "DisableMSI"            -ErrorAction SilentlyContinue
    Remove-ItemProperty $pi "EnableUserControl"     -ErrorAction SilentlyContinue
    Remove-ItemProperty $pi "AlwaysInstallElevated" -ErrorAction SilentlyContinue
    Remove-ItemProperty $pi "DisablePatch"          -ErrorAction SilentlyContinue
    Remove-ItemProperty $pi "DisableLockdownPatch"  -ErrorAction SilentlyContinue
    Remove-ItemProperty "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Installer" `
        "AlwaysInstallElevated" -ErrorAction SilentlyContinue

    # Lop 3: SRP - dat ve Unrestricted
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Safer\CodeIdentifiers" "DefaultLevel" 262144
    # Xóa toàn bộ blocked paths
    $srpBlock = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Safer\CodeIdentifiers\0\Paths"
    if (Test-Path $srpBlock) { Remove-Item $srpBlock -Recurse -Force -ErrorAction SilentlyContinue }

    # Lớp 5: WSH
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows Script Host\Settings" "Enabled" 1
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows Script Host\Settings" "Enabled" 1

    # Lớp 6: PS Full Language
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "__PSLockdownPolicy" "8" String

    # Lớp 7: Package managers
    Remove-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppInstaller" `
        "EnableAppInstaller" -ErrorAction SilentlyContinue
    Remove-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppInstaller" `
        "EnableWindowsPackageManagerCommandLineInterfaces" -ErrorAction SilentlyContinue

    # Lớp 8: Anti-bypass
    Remove-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" `
        "NoRun" -ErrorAction SilentlyContinue
    Remove-ItemProperty "HKCU:\SOFTWARE\Policies\Microsoft\Windows\System" `
        "DisableCMD" -ErrorAction SilentlyContinue
    Remove-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" `
        "DisableRegistryTools" -ErrorAction SilentlyContinue

    # AppLocker: chuyển về AuditOnly (không chặn hoàn toàn)
    try {
        [xml]$al = Get-AppLockerPolicy -Effective -Xml -ErrorAction Stop
        $al.AppLockerPolicy.RuleCollection | ForEach-Object { $_.EnforcementMode = "AuditOnly" }
        $tmpXml = "$env:TEMP\al_unlock.xml"
        $al.Save($tmpXml)
        Set-AppLockerPolicy -XmlPolicy $tmpXml -ErrorAction SilentlyContinue
        Remove-Item $tmpXml -ErrorAction SilentlyContinue
    } catch {}

    Write-OK "May da MO KHOA hoan toan - co the cai phan mem"
    Write-Warn "Nho KHOA lai sau khi cai xong!"
}

# ─────────────────────────────────────────────────────────────
#  KIỂM TRA TRẠNG THÁI
# ─────────────────────────────────────────────────────────────
function Get-LockStatus {
    $props = Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer" -EA SilentlyContinue
    if ($null -eq $props) { return $false }
    $prop = $props.PSObject.Properties["DisableMSI"]
    if ($null -eq $prop) { return $false }
    return ($null -ne $prop.Value -and $prop.Value -eq 2)
}

function Get-StatusDetails {
    function Get-RegValueIfExists {
        param([Parameter(Mandatory=$true)][string]$Path, [Parameter(Mandatory=$true)][string]$Name)
        $props = Get-ItemProperty $Path -EA SilentlyContinue
        if ($null -eq $props) { return $null }
        $prop = $props.PSObject.Properties[$Name]
        if ($null -eq $prop) { return $null }
        return $prop.Value
    }

    $checks = [ordered]@{}
    $disableMsi    = Get-RegValueIfExists "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer" "DisableMSI"
    $checks["MSI (DisableMSI=2)"]          = ($null -ne $disableMsi -and $disableMsi -eq 2)

    $defaultLevel = Get-RegValueIfExists "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Safer\CodeIdentifiers" "DefaultLevel"
    $checks["SRP (DefaultLevel=Disallow)"] = ($null -ne $defaultLevel -and $defaultLevel -eq 131072)

    $wshEnabled = Get-RegValueIfExists "HKLM:\SOFTWARE\Microsoft\Windows Script Host\Settings" "Enabled"
    $checks["WSH (Enabled=0)"]             = ($null -ne $wshEnabled -and $wshEnabled -eq 0)

    $psLockdown   = Get-RegValueIfExists "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "__PSLockdownPolicy"
    $checks["PS Constrained (__PS=4)"]     = ($null -ne $psLockdown -and [string]$psLockdown -eq "4")

    $enableAppInstaller = Get-RegValueIfExists "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppInstaller" "EnableAppInstaller"
    $checks["WinGet disabled"]             = ($null -ne $enableAppInstaller -and $enableAppInstaller -eq 0)

    $noRun = Get-RegValueIfExists "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" "NoRun"
    $checks["Run dialog blocked"]          = ($null -ne $noRun -and $noRun -eq 1)
    return $checks
}

# ─────────────────────────────────────────────────────────────
#  GỬI CẬP NHẬT LÊN SHEETS
# ─────────────────────────────────────────────────────────────
function Send-UpdateToSheets {
    Write-Step "Cập nhật danh sách phần mềm lên Google Sheets..."
    if ($GoogleScriptURL -like "*PASTE_YOUR*") { Write-Warn "Chua cau hinh URL - bo qua"; return }

    $appDict = [System.Collections.Generic.Dictionary[string,hashtable]]::new([System.StringComparer]::OrdinalIgnoreCase)
    @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
      "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
      "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*") | ForEach-Object {
        $items = Get-ItemProperty $_ -ErrorAction SilentlyContinue
        if (-not $items) { return }
        foreach ($item in @($items)) {
            $col = $item.PSObject.Properties.Match('DisplayName')
            if ($col.Count -eq 0) { continue }
            $name = $col[0].Value
            if (-not $name -or $name.Trim() -eq '') { continue }
            $name = $name.Trim()
            if ($appDict.ContainsKey($name)) { continue }
            $appDict[$name] = @{
                Name        = $name
                Version     = $(($item.PSObject.Properties.Match('DisplayVersion') | Select-Object -First 1).Value)
                Publisher   = $(($item.PSObject.Properties.Match('Publisher')      | Select-Object -First 1).Value)
                InstallDate = $(($item.PSObject.Properties.Match('InstallDate')    | Select-Object -First 1).Value)
            }
        }
    }
    [array]$apps = @($appDict.Values | Sort-Object { $_["Name"] })
    Write-OK "Tìm thấy $($apps.Length) phần mềm"

    $payload = @{
        MachineName     = $env:COMPUTERNAME
        CurrentUser     = "$env:USERDOMAIN\$env:USERNAME"
        InstalledApps   = $apps
        SoftwareBlocked = (Get-LockStatus)
        _UpdateType     = "install_update"
    }
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $bytes = [System.Text.Encoding]::UTF8.GetBytes(($payload | ConvertTo-Json -Depth 5 -Compress))
        $resp  = Invoke-RestMethod -Uri $GoogleScriptURL -Method POST -Body $bytes `
            -ContentType "application/json; charset=utf-8" -TimeoutSec 30 -UseBasicParsing
        if ($resp.status -eq "success") { Write-OK "Google Sheets đã cập nhật!" }
        else { Write-Warn "Lỗi: $($resp.message)" }
    } catch { Write-Err "Không gửi được: $_" }
}

# ─────────────────────────────────────────────────────────────
#  GITHUB AGENT — TOKEN
# ─────────────────────────────────────────────────────────────
$script:AgentBaseDir   = "C:\ChanHung\Agent"
$script:AgentTokenFile = "C:\ChanHung\Agent\.token"
$script:AgentModsDir   = "C:\ChanHung\Agent\Modules"
$script:AgentVerFile   = "C:\ChanHung\Agent\version.json"
$script:AgentLogFile   = "C:\ChanHung\Logs\Agent.log"
$script:AgentTaskName  = "ChanHung-IT-Agent"
$script:GH_API         = "https://api.github.com/repos/$GitHubOwner/$GitHubRepo/contents"

function Save-AgentToken {
    param([string]$PlainToken)
    $enc = $PlainToken | ConvertTo-SecureString -AsPlainText -Force | ConvertFrom-SecureString
    $dir = Split-Path $script:AgentTokenFile
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory $dir -Force | Out-Null }
    $enc | Out-File $script:AgentTokenFile -Encoding UTF8 -Force
    attrib +h +s $script:AgentTokenFile
    Write-OK "Token đã lưu encrypted (DPAPI)"
}

function Get-AgentToken {
    if (-not (Test-Path $script:AgentTokenFile)) { return $null }
    try {
        $sec  = Get-Content $script:AgentTokenFile | ConvertTo-SecureString
        $cred = New-Object PSCredential("x", $sec)
        return $cred.GetNetworkCredential().Password
    } catch { return $null }
}

# ─────────────────────────────────────────────────────────────
#  GITHUB AGENT — HTTP / HASH
# ─────────────────────────────────────────────────────────────
function Invoke-GitHubAPI {
    param([string]$RepoPath, [string]$OutFile = $null, [string]$Token)
    $url = "$script:GH_API/$RepoPath`?ref=$GitHubBranch"
    $hdr = @{
        "Authorization"        = "Bearer $Token"
        "Accept"               = "application/vnd.github.v3.raw"
        "User-Agent"           = "ChanHung-Agent/$env:COMPUTERNAME"
        "X-GitHub-Api-Version" = "2022-11-28"
    }
    try {
        if ($OutFile) {
            Invoke-WebRequest -Uri $url -Headers $hdr -OutFile $OutFile `
                -UseBasicParsing -TimeoutSec 60 -ErrorAction Stop
            return $true
        }
        $r = Invoke-WebRequest -Uri $url -Headers $hdr -UseBasicParsing -TimeoutSec 30 -ErrorAction Stop
        return ($r.Content | ConvertFrom-Json)
    } catch {
        $code = $_.Exception.Response.StatusCode.value__
        if     ($code -eq 401) { Write-Err  "GitHub: Token hết hạn hoặc sai!" }
        elseif ($code -eq 404) { Write-Warn "GitHub: Không tìm thấy '$RepoPath'" }
        else                   { Write-Err  "GitHub API lỗi: $_" }
        return $null
    }
}

function Get-SHA256 { param([string]$Path)
    return (Get-FileHash $Path -Algorithm SHA256).Hash
}

function Test-SHA256 { param([string]$Path, [string]$Expected)
    $actual = Get-SHA256 $Path
    if ($actual -ne $Expected.ToUpper()) {
        Write-Err "Hash KHÔNG KHỚP [$([System.IO.Path]::GetFileName($Path))]"
        return $false
    }
    return $true
}

# ─────────────────────────────────────────────────────────────
#  GITHUB AGENT — SELF-UPDATE (script tự cập nhật chính nó)
# ─────────────────────────────────────────────────────────────
function Invoke-SelfUpdate {
    $token = Get-AgentToken
    if (-not $token) { return }   # Chưa cài agent — bỏ qua

    Write-Info "Kiểm tra self-update từ GitHub..."
    $manifest = Invoke-GitHubAPI -RepoPath "manifest.json" -Token $token
    if (-not $manifest) { return }

    # Tìm entry cho script chính trong manifest
    $selfEntry = $manifest.modules | Where-Object { $_.name -eq "ChanHung_IT_Install" }
    if (-not $selfEntry) { return }

    $localVer = if (Test-Path $script:AgentVerFile) {
        (Get-Content $script:AgentVerFile | ConvertFrom-Json).self_version
    } else { "0.0.0" }

    if ($selfEntry.version -eq $localVer) {
        Write-Info "Script đang dùng bản mới nhất (v$localVer)"
        return
    }

    Write-Step "Có bản mới v$($selfEntry.version) — đang tải..."
    $tmp = Join-Path $env:TEMP "ChanHung_IT_Install_new.ps1"
    $ok  = Invoke-GitHubAPI -RepoPath "modules/ChanHung_IT_Install.ps1" -OutFile $tmp -Token $token
    if (-not $ok) { return }

    if (-not (Test-SHA256 $tmp $selfEntry.sha256)) {
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        return
    }

    # Thay file hiện tại rồi restart
    $self = $PSCommandPath
    Copy-Item $tmp $self -Force
    Remove-Item $tmp -Force

    # Cập nhật version file
    $ver = if (Test-Path $script:AgentVerFile) {
        Get-Content $script:AgentVerFile | ConvertFrom-Json
    } else { [PSCustomObject]@{ version="0.0.0"; self_version="0.0.0"; modules=@{} } }
    $ver.self_version = $selfEntry.version
    $ver | ConvertTo-Json -Depth 5 | Out-File $script:AgentVerFile -Encoding UTF8 -Force

    Write-OK "Đã cập nhật lên v$($selfEntry.version) — khởi động lại script..."
    Start-Sleep -Seconds 2
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $self
    exit
}

# ─────────────────────────────────────────────────────────────
#  GITHUB AGENT — CÀI / GỠ / CHẠY
# ─────────────────────────────────────────────────────────────
function Install-Agent {
    Write-Step "Cài đặt ChanHung IT Agent..."

    # Nhập PAT
    $pat = Read-Host "  Nhập GitHub Personal Access Token (ghp_...)"
    if ($pat -notlike "ghp_*" -and $pat -notlike "github_pat_*") {
        Write-Err "Token không đúng định dạng (phải bắt đầu ghp_ hoặc github_pat_)"
        return
    }

    # Kiểm tra token bằng cách lấy manifest
    Write-Info "Kiểm tra kết nối GitHub..."
    $manifest = Invoke-GitHubAPI -RepoPath "manifest.json" -Token $pat
    if (-not $manifest) {
        Write-Err "Không kết nối được GitHub — kiểm tra lại token và tên repo."
        return
    }
    Write-OK "Kết nối GitHub OK — Manifest v$($manifest.version)"

    # Lưu token
    Save-AgentToken $pat

    # Tạo thư mục
    foreach ($d in @($script:AgentBaseDir, $script:AgentModsDir, "C:\ChanHung\Logs")) {
        if (-not (Test-Path $d)) { New-Item -ItemType Directory $d -Force | Out-Null }
    }

    # Tải ChanHung-Agent.ps1 từ repo về
    $agentDest = Join-Path $script:AgentBaseDir "ChanHung-Agent.ps1"
    $agentEntry = $manifest.modules | Where-Object { $_.name -eq "ChanHung-Agent" }

    if ($agentEntry) {
        $tmp = Join-Path $env:TEMP "agent_dl.ps1"
        $ok  = Invoke-GitHubAPI -RepoPath "modules/ChanHung-Agent.ps1" -OutFile $tmp -Token $pat
        if ($ok -and (Test-SHA256 $tmp $agentEntry.sha256)) {
            Move-Item $tmp $agentDest -Force
            Write-OK "Đã tải ChanHung-Agent.ps1"
        } else {
            Write-Warn "Không tải được agent từ GitHub — dùng bản nhúng"
            Remove-Item $tmp -Force -ErrorAction SilentlyContinue
            # Fallback: tạo agent stub tối giản
            @"
. `"$($PSCommandPath)`"
Start-AgentCheck
"@ | Out-File $agentDest -Encoding UTF8 -Force
        }
    } else {
        Write-Warn "Không tìm thấy ChanHung-Agent trong manifest — dùng self-run mode"
        @"
# Agent stub — chạy self-update từ script chính
powershell.exe -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass ``
    -File `"$($PSCommandPath)`" -Silent
"@ | Out-File $agentDest -Encoding UTF8 -Force
    }

    # Tạo Scheduled Task
    $action = New-ScheduledTaskAction `
        -Execute "powershell.exe" `
        -Argument "-NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$agentDest`""

    $trigger = New-ScheduledTaskTrigger `
        -RepetitionInterval (New-TimeSpan -Minutes 15) `
        -Once -At (Get-Date)

    $principal = New-ScheduledTaskPrincipal `
        -UserId "NT AUTHORITY\SYSTEM" `
        -LogonType ServiceAccount `
        -RunLevel Highest

    $settings = New-ScheduledTaskSettingsSet `
        -ExecutionTimeLimit (New-TimeSpan -Minutes 5) `
        -StartWhenAvailable `
        -RunOnlyIfNetworkAvailable `
        -RestartCount 3 `
        -RestartInterval (New-TimeSpan -Minutes 2)

    Unregister-ScheduledTask -TaskName $script:AgentTaskName -Confirm:$false -ErrorAction SilentlyContinue
    Register-ScheduledTask `
        -TaskName    $script:AgentTaskName `
        -Action      $action `
        -Trigger     $trigger `
        -Principal   $principal `
        -Settings    $settings `
        -Description "Chấn Hưng IT Agent — tự động cập nhật policy từ GitHub" | Out-Null

    # Ẩn thư mục agent
    attrib +h +s $script:AgentBaseDir

    # Chạy ngay lần đầu
    Start-ScheduledTask -TaskName $script:AgentTaskName -ErrorAction SilentlyContinue

    Write-OK "Agent đã cài và kích hoạt!"
    Write-Info "Scheduled Task: '$($script:AgentTaskName)' — chạy mỗi 15 phút"
    Write-Info "Thư mục: $script:AgentBaseDir"
}

function Uninstall-Agent {
    Write-Step "Gỡ cài đặt Agent..."
    Unregister-ScheduledTask -TaskName $script:AgentTaskName -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Item $script:AgentBaseDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-OK "Đã gỡ Agent và xóa Scheduled Task"
}

function Invoke-AgentNow {
    Write-Step "Chạy Agent ngay lập tức..."
    $token = Get-AgentToken
    if (-not $token) {
        Write-Err "Chưa cài Agent — chọn [5] để cài trước"
        return
    }

    $manifest = Invoke-GitHubAPI -RepoPath "manifest.json" -Token $token
    if (-not $manifest) { Write-Warn "Không lấy được manifest"; return }

    Write-OK "Manifest v$($manifest.version) — $($manifest.modules.Count) modules"

    $localVer = if (Test-Path $script:AgentVerFile) {
        $v = Get-Content $script:AgentVerFile | ConvertFrom-Json
        if ($v.modules -isnot [hashtable]) {
            $h = @{}; $v.modules.PSObject.Properties | ForEach-Object { $h[$_.Name] = $_.Value }
            $v.modules = $h
        }
        $v
    } else { [PSCustomObject]@{ version="0.0.0"; modules=@{} } }

    $updated = @()

    foreach ($mod in $manifest.modules) {
        if ($mod.name -eq "ChanHung-Agent" -or $mod.name -eq "ChanHung_IT_Install") { continue }

        $cachedHash = if ($localVer.modules -is [hashtable]) {
            $localVer.modules[$mod.name]
        } else {
            $localVer.modules.($mod.name)
        }

        if ($cachedHash -eq $mod.sha256) {
            Write-Info "Module [$($mod.name)] — không có gì mới"
            continue
        }

        Write-Info "Tải module: $($mod.name) v$($mod.version)"
        if (-not (Test-Path $script:AgentModsDir)) {
            New-Item -ItemType Directory $script:AgentModsDir -Force | Out-Null
        }
        $tmp  = Join-Path $env:TEMP "$($mod.name)_$(Get-Random).tmp"
        $dest = Join-Path $script:AgentModsDir "$($mod.name).ps1"

        $ok = Invoke-GitHubAPI -RepoPath "modules/$($mod.name).ps1" -OutFile $tmp -Token $token
        if (-not $ok) { continue }

        if (-not (Test-SHA256 $tmp $mod.sha256)) {
            Remove-Item $tmp -Force -ErrorAction SilentlyContinue
            continue
        }

        Move-Item $tmp $dest -Force
        Write-OK "Deploy: $($mod.name) v$($mod.version)"

        if ($mod.autorun) {
            Write-Info "Autorun: $($mod.name)"
            try { & $dest } catch { Write-Err "Autorun lỗi: $_" }
        }

        $updated += $mod.name
        if ($localVer.modules -is [hashtable]) {
            $localVer.modules[$mod.name] = $mod.sha256
        }
    }

    $localVer.version = $manifest.version
    $localVer | ConvertTo-Json -Depth 5 | Out-File $script:AgentVerFile -Encoding UTF8 -Force

    # Thực thi remote commands nếu có
    if ($manifest.commands) {
        $cmds = $manifest.commands | Where-Object {
            $_.target -eq "*" -or $_.target -eq $env:COMPUTERNAME -or
            ($_.target -is [array] -and $_.target -contains $env:COMPUTERNAME)
        }
        foreach ($cmd in $cmds) {
            $flag = Join-Path $script:AgentBaseDir "done_$($cmd.id).flag"
            if (Test-Path $flag) { continue }
            Write-Info "Thực thi lệnh: [$($cmd.id)] $($cmd.description)"
            try {
                switch ($cmd.type) {
                    "powershell"  { $block = [scriptblock]::Create($cmd.code); & $block }
                    "module"      {
                        $p = Join-Path $script:AgentModsDir "$($cmd.module).ps1"
                        if (Test-Path $p) { . $p; & $cmd.function }
                    }
                    "github_exec" {
                        $tmp = Join-Path $env:TEMP "exec_$($cmd.id).ps1"
                        $ok  = Invoke-GitHubAPI -RepoPath $cmd.repoPath -OutFile $tmp -Token $token
                        if ($ok -and (Test-SHA256 $tmp $cmd.sha256)) { & $tmp }
                        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
                    }
                }
                "done" | Out-File $flag -Encoding UTF8
                Write-OK "Lệnh [$($cmd.id)] OK"
            } catch { Write-Err "Lệnh [$($cmd.id)] lỗi: $_" }
        }
    }

    if ($updated.Count -gt 0) {
        Write-OK "Đã cập nhật $($updated.Count) module(s): $($updated -join ', ')"
    } else {
        Write-Info "Không có module nào cần cập nhật"
    }
}

function Get-AgentStatus {
    $taskExists = $null
    try {
        $taskExists = Get-ScheduledTask -TaskName $script:AgentTaskName -ErrorAction SilentlyContinue
    } catch {
        $taskExists = $null
    }
    $tokenOK    = $null -ne (Get-AgentToken)
    $verInfo    = if (Test-Path $script:AgentVerFile) {
        Get-Content $script:AgentVerFile | ConvertFrom-Json
    } else { $null }

    Write-Host ""
    Write-Host "  TRẠNG THÁI AGENT:" -ForegroundColor Cyan
    Write-Host "    $(if ($taskExists) {'[OK]'} else {'[--]'}) Scheduled Task" -ForegroundColor $(if ($taskExists) {'Green'} else {'DarkYellow'})
    Write-Host "    $(if ($tokenOK)    {'[OK]'} else {'[--]'}) GitHub Token" -ForegroundColor $(if ($tokenOK) {'Green'} else {'DarkYellow'})
    if ($verInfo) {
        Write-Host "    [-] Manifest version: $($verInfo.version)" -ForegroundColor Gray
        Write-Host "    [-] Script version  : $($verInfo.self_version)" -ForegroundColor Gray
    }
    $logLine = if (Test-Path $script:AgentLogFile) {
        Get-Content $script:AgentLogFile | Select-Object -Last 1
    } else { "(chưa có log)" }
    Write-Host "    [-] Log gần nhất: $logLine" -ForegroundColor Gray
}

# ─────────────────────────────────────────────────────────────
#  CHƯƠNG TRÌNH CHÍNH
# ─────────────────────────────────────────────────────────────

# Tự kiểm tra update từ GitHub (chỉ chạy khi đã cài agent)
try { Invoke-SelfUpdate } catch { <# bỏ qua lỗi self-update, không block menu #> }

Write-Header

# Canh bao neu phien PowerShell HIEN TAI dang bi ket o Constrained Language
# Mode. __PSLockdownPolicy chi duoc doc 1 lan luc powershell.exe khoi dong,
# nen neu phien nay khoi dong trong luc may dang KHOA thi du ban chon "Mo
# khoa" (option 1/3) va sua duoc registry, PHIEN NAY van se o CLM den khi
# dong cua so va mo lai. Bao truoc de tranh nham lan / crash khong ro ly do.
if ($ExecutionContext.SessionState.LanguageMode -eq 'ConstrainedLanguage') {
    Write-Warn "Phien PowerShell nay dang chay o Constrained Language Mode."
    Write-Warn "Mot so tinh nang (Agent, dem gio) co the loi/thieu chinh xac."
    Write-Warn "Neu vua Mo khoa: hay DONG cua so nay va mo PowerShell (Admin) MOI"
    Write-Warn "  thi phien moi moi nhan Full Language Mode."
    Write-Host ""
}

# Hiển thị trạng thái hiện tại chi tiết
$details    = Get-StatusDetails
$isLocked   = Get-LockStatus
$lockedCount = @($details.Values | Where-Object { $_ }).Count

Write-Host "  Máy: $env:COMPUTERNAME  |  User: $env:USERNAME" -ForegroundColor White
Write-Host ""
Write-Host "  TRẠNG THÁI LOCKDOWN:" -ForegroundColor Cyan

foreach ($k in $details.Keys) {
    $v    = $details[$k]
    $icon = if ($v) { "[LOCK]" } else { "[UNLOCK]" }
    $col  = if ($v) { "Green" } else { "DarkYellow" }
    Write-Host "    $icon $k" -ForegroundColor $col
}

Write-Host ""
$overallColor = if ($isLocked) { "Red" } else { "Green" }
$overallText  = if ($isLocked) { "DANG KHOA ($lockedCount/6 lop active)" } else { "DANG MO - co the cai phan mem" }
Write-Host "  Tổng thể: $overallText" -ForegroundColor $overallColor
Write-Host ""

# Hiển thị trạng thái Agent ngắn gọn trên menu
# Bọc try/catch: neu module ScheduledTasks khong nap duoc (vi du dang o
# Constrained Language Mode do lop khoa PS Constrained gay ra), -ErrorAction
# SilentlyContinue KHONG chan duoc loi "CouldNotAutoloadMatchingModule" vi
# loi nay xay ra o buoc discover lenh, truoc khi cmdlet duoc goi.
$agentTask = $null
try {
    $agentTask = Get-ScheduledTask -TaskName $script:AgentTaskName -ErrorAction SilentlyContinue
} catch {
    $agentTask = $null
}
$agentIcon = if ($agentTask) { "[ON] " } else { "[OFF]" }
$agentCol  = if ($agentTask) { "Green" } else { "DarkYellow" }

Write-Host "  Chọn thao tác:" -ForegroundColor Cyan
Write-Host "    [1] Mo khoa -> tu khoa lai sau $TimeoutMinutes phut" -ForegroundColor White
Write-Host "    [2] KHOA lai ngay (8 lop)" -ForegroundColor White
Write-Host "    [3] Mo khoa -> Cai xong -> Enter -> Khoa lai + cap nhat Sheets" -ForegroundColor White
Write-Host "    [4] Chi cap nhat danh sach phan mem len Sheets" -ForegroundColor White
Write-Host "    ──────────────────────────────────" -ForegroundColor DarkGray
Write-Host "    [5] Cai GitHub Agent (tu dong cap nhat policy)" -ForegroundColor Magenta
Write-Host "    [6] Chay Agent ngay ($agentIcon)" -ForegroundColor $agentCol
Write-Host "    [7] Trang thai Agent chi tiet" -ForegroundColor Magenta
Write-Host "    [8] Go Agent" -ForegroundColor DarkGray
Write-Host "    [Q] Thoat" -ForegroundColor Gray
Write-Host ""

$choice = Read-Host "  Lua chon"

switch ($choice.Trim().ToUpper()) {
    "1" {
        Invoke-Unlock
        if ($ExecutionContext.SessionState.LanguageMode -eq 'ConstrainedLanguage') {
            Write-Warn "Da mo khoa registry, nhung CUA SO PowerShell nay van dang"
            Write-Warn "  o Constrained Language Mode (chi doi khi mo cua so moi)."
        }
        Write-Host ""
        Write-Warn "Tu dong khoa lai sau $TimeoutMinutes phut."
        $endTime = (Get-Date).AddMinutes($TimeoutMinutes)
        while ((Get-Date) -lt $endTime) {
            # Dung ep kieu [int] thay vi [math]::Round/[math]::Floor: day la
            # type conversion chu khong phai goi static method, nen van chay
            # duoc ke ca khi dang o Constrained Language Mode.
            $rem  = [int](($endTime - (Get-Date)).TotalSeconds)
            $mins = [int]($rem / 60); $secs = $rem % 60
            Write-Host "`r  [TIMER] Khoa lai sau: ${mins}m ${secs}s   " -NoNewline -ForegroundColor DarkYellow
            Start-Sleep -Seconds 1
        }
        Write-Host ""
        Invoke-Lock
        Send-UpdateToSheets
    }
    "2" {
        Invoke-Lock
        Send-UpdateToSheets
    }
    "3" {
        Invoke-Unlock
        if ($ExecutionContext.SessionState.LanguageMode -eq 'ConstrainedLanguage') {
            Write-Warn "Da mo khoa registry, nhung CUA SO PowerShell nay van dang"
            Write-Warn "  o Constrained Language Mode (chi doi khi mo cua so moi)."
        }
        Write-Host ""
        Write-Host "  =================================================" -ForegroundColor Green
        Write-Host "  [OK]  MAY DA MO KHOA - cai phan mem di nhe!      " -ForegroundColor Green
        Write-Host "  Khi cai xong, quay lai day va bam Enter.         " -ForegroundColor Green
        Write-Host "  =================================================" -ForegroundColor Green
        Write-Host ""
        Read-Host "  [Bam Enter khi da cai xong]" | Out-Null
        Invoke-Lock
        Send-UpdateToSheets
    }
    "4" { Send-UpdateToSheets }
    "5" { Install-Agent }
    "6" { Invoke-AgentNow }
    "7" { Get-AgentStatus }
    "8" {
        $confirm = Read-Host "  Xác nhận gỡ Agent? (Y/N)"
        if ($confirm -eq 'Y') { Uninstall-Agent }
    }
    "Q" { Write-Host "  Da thoat." -ForegroundColor Gray; exit 0 }
    default { Write-Warn "Lua chon khong hop le." }
}

Write-Host ""
$finalLocked = Get-LockStatus
Write-Host "  ==================================================" -ForegroundColor Cyan
Write-Host "  Trang thai: $(if ($finalLocked) {'[LOCK] DANG KHOA (8 lop)          '} else {'[UNLOCK] DANG MO - nho khoa lai!   '})" -ForegroundColor Cyan
Write-Host "  ==================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Nhan Enter de thoat..." -ForegroundColor Gray
Read-Host | Out-Null
