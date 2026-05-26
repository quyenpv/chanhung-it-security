# ============================================================
#  MODULE: USB Control
#  Version: 1.0.0
#  Mục đích: Kiểm soát thiết bị USB (chặn/cho phép đọc/ghi)
#  Yêu cầu: Chạy với quyền Administrator
# ============================================================

#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [ValidateSet("BlockAll", "AllowAll", "ReadOnly", "WriteOnly")]
    [string]$Mode = "BlockAll",
    
    [switch]$Check,
    [string[]]$AllowedDevices = @()  # List of allowed USB device IDs
)

function Write-Log {
    param([string]$Message)
    $logPath = "C:\Program Files\ChanHung\PS-Agent\logs"
    if (-not (Test-Path $logPath)) {
        New-Item -ItemType Directory -Path $logPath -Force | Out-Null
    }
    $logFile = Join-Path $logPath "Module-USBControl-$(Get-Date -Format 'yyyyMMdd').log"
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

function Set-USBPolicy {
    param([string]$PolicyMode)
    
    Write-Log "Đang cấu hình USB policy: $PolicyMode"
    
    $usbPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\RemovableStorageDevices"
    
    switch ($PolicyMode) {
        "BlockAll" {
            # Chặn tất cả USB storage
            Set-RegistryValue "$usbPath\{53f5630d-b6bf-11d0-94f2-00a0c91efb8b}" "Deny_All" 1
            Set-RegistryValue "$usbPath\{53f5630b-b6bf-11d0-94f2-00a0c91efb8b}" "Deny_All" 1
            Set-RegistryValue "$usbPath\{53f56308-b6bf-11d0-94f2-00a0c91efb8b}" "Deny_All" 1
            
            # Disable USB via registry
            Set-RegistryValue "HKLM:\SYSTEM\CurrentControlSet\Services\USBSTOR" "Start" 4
            
            Write-Log "Đã chặn tất cả thiết bị USB"
        }
        
        "AllowAll" {
            # Cho phép tất cả USB storage
            Set-RegistryValue "$usbPath\{53f5630d-b6bf-11d0-94f2-00a0c91efb8b}" "Deny_All" 0
            Set-RegistryValue "$usbPath\{53f5630b-b6bf-11d0-94f2-00a0c91efb8b}" "Deny_All" 0
            Set-RegistryValue "$usbPath\{53f56308-b6bf-11d0-94f2-00a0c91efb8b}" "Deny_All" 0
            
            # Enable USB via registry
            Set-RegistryValue "HKLM:\SYSTEM\CurrentControlSet\Services\USBSTOR" "Start" 3
            
            Write-Log "Đã cho phép tất cả thiết bị USB"
        }
        
        "ReadOnly" {
            # Chỉ cho phép đọc từ USB
            Set-RegistryValue "$usbPath\{53f5630d-b6bf-11d0-94f2-00a0c91efb8b}" "Deny_All" 0
            Set-RegistryValue "$usbPath\{53f5630d-b6bf-11d0-94f2-00a0c91efb8b}" "Deny_Write" 1
            
            Set-RegistryValue "$usbPath\{53f5630b-b6bf-11d0-94f2-00a0c91efb8b}" "Deny_All" 0
            Set-RegistryValue "$usbPath\{53f5630b-b6bf-11d0-94f2-00a0c91efb8b}" "Deny_Write" 1
            
            # Enable USB via registry
            Set-RegistryValue "HKLM:\SYSTEM\CurrentControlSet\Services\USBSTOR" "Start" 3
            
            Write-Log "Đã cấu hình USB chỉ đọc"
        }
        
        "WriteOnly" {
            # Chỉ cho phép ghi (không đọc - trường hợp hiếm dùng)
            Set-RegistryValue "$usbPath\{53f5630d-b6bf-11d0-94f2-00a0c91efb8b}" "Deny_All" 0
            Set-RegistryValue "$usbPath\{53f5630d-b6bf-11d0-94f2-00a0c91efb8b}" "Deny_Read" 1
            
            Set-RegistryValue "$usbPath\{53f5630b-b6bf-11d0-94f2-00a0c91efb8b}" "Deny_All" 0
            Set-RegistryValue "$usbPath\{53f5630b-b6bf-11d0-94f2-00a0c91efb8b}" "Deny_Read" 1
            
            # Enable USB via registry
            Set-RegistryValue "HKLM:\SYSTEM\CurrentControlSet\Services\USBSTOR" "Start" 3
            
            Write-Log "Đã cấu hình USB chỉ ghi"
        }
    }
}

function Get-USBPolicyStatus {
    $status = @{
        USBStorageService = $null
        DenyAll = $false
        DenyWrite = $false
        DenyRead = $false
    }
    
    # Check USBSTOR service
    $usbstorStart = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\USBSTOR" -Name "Start" -ErrorAction SilentlyContinue
    if ($usbstorStart) {
        $status.USBStorageService = switch ($usbstorStart.Start) {
            3 { "Enabled" }
            4 { "Disabled" }
            default { "Unknown" }
        }
    }
    
    # Check Removable Storage Devices policy
    $usbPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\RemovableStorageDevices"
    $denyAll = Get-ItemProperty "$usbPath\{53f5630d-b6bf-11d0-94f2-00a0c91efb8b}" -Name "Deny_All" -ErrorAction SilentlyContinue
    if ($denyAll) {
        $status.DenyAll = $denyAll.Deny_All -eq 1
    }
    
    $denyWrite = Get-ItemProperty "$usbPath\{53f5630d-b6bf-11d0-94f2-00a0c91efb8b}" -Name "Deny_Write" -ErrorAction SilentlyContinue
    if ($denyWrite) {
        $status.DenyWrite = $denyWrite.Deny_Write -eq 1
    }
    
    $denyRead = Get-ItemProperty "$usbPath\{53f5630d-b6bf-11d0-94f2-00a0c91efb8b}" -Name "Deny_Read" -ErrorAction SilentlyContinue
    if ($denyRead) {
        $status.DenyRead = $denyRead.Deny_Read -eq 1
    }
    
    return $status
}

function Get-ConnectedUSBDevices {
    Write-Log "Đang quét thiết bị USB đã kết nối..."
    
    $devices = Get-PnpDevice | Where-Object { 
        $_.Class -eq "USB" -or $_.FriendlyName -like "*USB*" -or $_.InstanceId -like "*USB*"
    }
    
    $usbDevices = @()
    foreach ($device in $devices) {
        if ($device.Status -eq "OK") {
            $usbDevices += @{
                Name = $device.FriendlyName
                InstanceId = $device.InstanceId
                Class = $device.Class
            }
        }
    }
    
    Write-Log "Tìm thấy $($usbDevices.Count) thiết bị USB"
    return $usbDevices
}

# Main logic
if ($Check) {
    $status = Get-USBPolicyStatus
    Write-Log "Trạng thái USB Policy:"
    Write-Log "  USB Storage Service: $($status.USBStorageService)"
    Write-Log "  Deny All: $($status.DenyAll)"
    Write-Log "  Deny Write: $($status.DenyWrite)"
    Write-Log "  Deny Read: $($status.DenyRead)"
    
    $devices = Get-ConnectedUSBDevices
    Write-Log "Các thiết bị USB đang kết nối:"
    foreach ($device in $devices) {
        Write-Log "  - $($device.Name) ($($device.InstanceId))"
    }
} else {
    Set-USBPolicy -PolicyMode $Mode
}
