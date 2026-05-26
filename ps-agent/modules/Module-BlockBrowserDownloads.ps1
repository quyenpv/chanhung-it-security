# ============================================================
#  MODULE: Block Browser Downloads
#  Version: 1.0.0
#  Mục đích: Chặn tải xuống file từ trình duyệt (Chrome, Edge, Firefox)
#  Yêu cầu: Chạy với quyền Administrator
# ============================================================

#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [switch]$Enable,
    [switch]$Disable,
    [switch]$Check
)

function Write-Log {
    param([string]$Message)
    $logPath = "C:\Program Files\ChanHung\PS-Agent\logs"
    if (-not (Test-Path $logPath)) {
        New-Item -ItemType Directory -Path $logPath -Force | Out-Null
    }
    $logFile = Join-Path $logPath "Module-BlockBrowserDownloads-$(Get-Date -Format 'yyyyMMdd').log"
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File -FilePath $logFile -Append
}

function Set-RegistryValue {
    param(
        [string]$Path,
        [string]$Name,
        $Value,
        [string]$Type = "DWord"
    )
    try {
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force
        return $true
    } catch {
        Write-Log "Lỗi khi set registry $Path\$Name: $($_.ToString())"
        return $false
    }
}

function Enable-BlockDownloads {
    Write-Log "Đang bật chặn tải xuống file từ trình duyệt..."
    
    # Chrome
    $chromePath = "HKLM\SOFTWARE\Policies\Google\Chrome"
    Set-RegistryValue "HKLM:\SOFTWARE\Policies\Google\Chrome" "DownloadRestrictions" 3
    Set-RegistryValue "HKLM:\SOFTWARE\Policies\Google\Chrome" "DownloadDirectory" ""
    
    # Edge
    Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Edge" "DownloadRestrictions" 3
    Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Edge" "DownloadDirectory" ""
    
    # Firefox
    Set-RegistryValue "HKLM:\SOFTWARE\Policies\Mozilla\Firefox" "DisableFirefoxStudies" 1
    Set-RegistryValue "HKLM:\SOFTWARE\Policies\Mozilla\Firefox" "DisableProfileRefresh" 1
    
    # Windows Global - Chặn file từ Internet
    Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Attachments" "SaveZoneInformation" 2
    Set-RegistryValue "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Attachments" "SaveZoneInformation" 2
    
    Write-Log "Đã bật chặn tải xuống file"
}

function Disable-BlockDownloads {
    Write-Log "Đang tắt chặn tải xuống file từ trình duyệt..."
    
    # Chrome
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Google\Chrome" -Name "DownloadRestrictions" -ErrorAction SilentlyContinue
    
    # Edge
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "DownloadRestrictions" -ErrorAction SilentlyContinue
    
    # Windows Global
    Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Attachments" "SaveZoneInformation" 1
    Set-RegistryValue "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Attachments" "SaveZoneInformation" 1
    
    Write-Log "Đã tắt chặn tải xuống file"
}

function Get-BlockDownloadsStatus {
    $status = @{
        Chrome = $false
        Edge = $false
        Windows = $false
    }
    
    $chromeRestriction = Get-ItemProperty "HKLM:\SOFTWARE\Policies\Google\Chrome" -Name "DownloadRestrictions" -ErrorAction SilentlyContinue
    if ($chromeRestriction -and $chromeRestriction.DownloadRestrictions -eq 3) {
        $status.Chrome = $true
    }
    
    $edgeRestriction = Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "DownloadRestrictions" -ErrorAction SilentlyContinue
    if ($edgeRestriction -and $edgeRestriction.DownloadRestrictions -eq 3) {
        $status.Edge = $true
    }
    
    $windowsRestriction = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Attachments" -Name "SaveZoneInformation" -ErrorAction SilentlyContinue
    if ($windowsRestriction -and $windowsRestriction.SaveZoneInformation -eq 2) {
        $status.Windows = $true
    }
    
    return $status
}

# Main logic
if ($Check) {
    $status = Get-BlockDownloadsStatus
    Write-Log "Trạng thái chặn tải xuống:"
    Write-Log "  Chrome: $($status.Chrome)"
    Write-Log "  Edge: $($status.Edge)"
    Write-Log "  Windows: $($status.Windows)"
} elseif ($Disable) {
    Disable-BlockDownloads
} else {
    Enable-BlockDownloads
}
