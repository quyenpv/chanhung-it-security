# ============================================================
#  CHẤN HƯNG HOLDING - IT INSTALL HELPER  v2.0
#  Mở/đóng khóa Nuclear Lockdown để IT cài phần mềm
# ============================================================
#Requires -RunAsAdministrator
param(
    [string]$GoogleScriptURL = "https://script.google.com/macros/s/PASTE_YOUR_DEPLOYMENT_URL_HERE/exec",
    [int]$TimeoutMinutes     = 30,
    [switch]$Silent
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

function Write-Header {
    Clear-Host
    Write-Host ""
    Write-Host "  =====================================================" -ForegroundColor Cyan
    Write-Host "  CHAN HUNG HOLDING - IT INSTALL HELPER  v2.0         " -ForegroundColor Cyan
    Write-Host "  MO / DONG KHOA Nuclear Lockdown                     " -ForegroundColor Cyan
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
#  CHƯƠNG TRÌNH CHÍNH
# ─────────────────────────────────────────────────────────────
Write-Header

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

Write-Host "  Chọn thao tác:" -ForegroundColor Cyan
Write-Host "    [1] Mo khoa -> tu khoa lai sau $TimeoutMinutes phut" -ForegroundColor White
Write-Host "    [2] KHOA lai ngay (8 lop)" -ForegroundColor White
Write-Host "    [3] Mo khoa -> Cai xong -> Enter -> Khoa lai + cap nhat Sheets" -ForegroundColor White
Write-Host "    [4] Chỉ cập nhật danh sách phần mềm lên Sheets" -ForegroundColor White
Write-Host "    [Q] Thoat" -ForegroundColor Gray
Write-Host ""

$choice = Read-Host "  Lua chon"

switch ($choice.Trim().ToUpper()) {
    "1" {
        Invoke-Unlock
        Write-Host ""
        Write-Warn "Tu dong khoa lai sau $TimeoutMinutes phut."
        $endTime = (Get-Date).AddMinutes($TimeoutMinutes)
        while ((Get-Date) -lt $endTime) {
            $rem  = [math]::Round(($endTime - (Get-Date)).TotalSeconds)
            $mins = [math]::Floor($rem / 60); $secs = $rem % 60
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
