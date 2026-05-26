# ChanHung IT Hardening Module
# Version: 1.0.0
# Purpose: Security hardening, IP Static config, and reporting

param(
    [string]$StaticIP = "",
    [string]$SubnetMask = "255.255.255.0",
    [string]$Gateway = "",
    [string]$DNS1 = "8.8.8.8",
    [string]$DNS2 = "8.8.4.4",
    [string]$GoogleScriptURL = "https://script.google.com/macros/s/AKfycbwxbL4cRf-fkcUj4FZ93Fi1F2SPUjkMubTgnF7YnBjhr2dq_oxWliEyjP87TigHNPmS/exec",
    [switch]$SkipNetworkConfig,
    [switch]$SkipSecurityHardening,
    [switch]$SkipReporting
)

# Whitelist machines (excluded from security hardening)
$ExcludedHostnames = @(
    "PC-ADMIN-01",
    "PC-ADMIN-02",
    "LAPTOP-IT-MGR",
    "VTU-QUYENPV",
    "PC-DEV-*"
)

function Test-IsExcluded {
    $hostname = $env:COMPUTERNAME.ToUpper()
    foreach ($pattern in $ExcludedHostnames) {
        if ([string]::IsNullOrWhiteSpace($pattern)) { continue }
        if ($hostname -like $pattern.Trim().ToUpper()) { return $true }
    }
    return $false
}

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logFile = Join-Path $env:TEMP "ITHardening-$($env:COMPUTERNAME).log"
    "$timestamp - $Message" | Out-File -FilePath $logFile -Append
}

function Set-RegistryValue {
    param([string]$Path, [string]$Name, $Value, [string]$Type = "DWord")
    try {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force
        return $true
    } catch {
        Write-Log "Registry error: $Path\$Name - $_"
        return $false
    }
}

function Get-ActiveAdapter {
    [array]$adapters = @(Get-NetAdapter -ErrorAction SilentlyContinue |
        Where-Object { $_.Status -eq "Up" -and $_.Name -notmatch "Loopback" -and $_.Name -notmatch "vEthernet" })
    
    [array]$physical = @($adapters | Where-Object { $_.InterfaceType -eq 6 -or $_.InterfaceType -eq 71 })
    if ($physical -and $physical.Length -gt 0) { return $physical[0] }
    if ($adapters -and $adapters.Length -gt 0) { return $adapters[0] }
    
    [array]$any = @(Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Up" })
    if ($any -and $any.Length -gt 0) { return $any[0] }
    return $null
}

function Test-ValidIP([string]$IP) {
    return ($IP -match '^\d{1,3}(\.\d{1,3}){3}$') -and ([System.Net.IPAddress]::TryParse($IP, [ref]$null))
}

function Invoke-SecurityHardening {
    Write-Log "Starting security hardening..."
    
    if (Test-IsExcluded) {
        Write-Log "Machine is whitelisted - skipping security hardening"
        return @{ BlockMSI=$false; BlockStore=$false; BlockElevated=$false; UACEnabled=$false }
    }
    
    $results = @{ BlockMSI=$false; BlockStore=$false; BlockElevated=$false; UACEnabled=$false }
    
    Write-Log "Blocking MSI installer for regular users..."
    $ok1 = Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer" "DisableMSI" 2
    $ok2 = Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer" "EnableUserControl" 0
    if ($ok1 -and $ok2) { $results.BlockMSI = $true }
    
    Write-Log "Disabling AlwaysInstallElevated..."
    $ok3 = Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer" "AlwaysInstallElevated" 0
    $ok4 = Set-RegistryValue "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Installer" "AlwaysInstallElevated" 0
    if ($ok3 -and $ok4) { $results.BlockElevated = $true }
    
    Write-Log "Configuring Windows Store..."
    $ok5 = Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore" "AutoDownload" 2
    $ok6 = Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore" "DisableStoreApps" 1
    if ($ok5) { $results.BlockStore = $true }
    
    Write-Log "Blocking AutoRun from USB and disks..."
    Set-RegistryValue "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" "NoDriveTypeAutoRun" 255 | Out-Null
    Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" "NoAutoplayfornonVolume" 1 | Out-Null
    
    Write-Log "Disabling auto-run for downloaded files..."
    Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Attachments" "SaveZoneInformation" 2 | Out-Null
    
    Write-Log "Checking UAC..."
    $uacVal = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" `
        -Name "EnableLUA" -ErrorAction SilentlyContinue).EnableLUA
    if ($uacVal -ne 1) {
        Set-RegistryValue "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" "EnableLUA" 1 | Out-Null
    }
    $results.UACEnabled = $true
    
    Write-Log "Security hardening completed"
    return $results
}

function Invoke-StaticIPConfig {
    Write-Log "Starting IP Static configuration..."
    
    $result = @{
        StaticIPSet=$false; DHCPEnabled="N/A"
        IPAddress=""; SubnetMask=$SubnetMask; Gateway=$Gateway
        DNS1=$DNS1; DNS2=$DNS2; AdapterName=""; MACAddress=""
    }
    
    $adapter = Get-ActiveAdapter
    if (-not $adapter) {
        Write-Log "No active network adapter found"
        return $result
    }
    
    $result.AdapterName = $adapter.Name
    $result.MACAddress = $adapter.MacAddress
    Write-Log "Adapter: $($adapter.Name) MAC: $($adapter.MacAddress)"
    
    $currentIP = Get-NetIPAddress -InterfaceAlias $adapter.Name `
        -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -notlike "169.*" } | Select-Object -First 1
    $currentGW = (Get-NetRoute -InterfaceAlias $adapter.Name `
        -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue |
        Select-Object -First 1).NextHop
    
    $curIPStr = if ($currentIP) { $currentIP.IPAddress } else { "(no IP)" }
    $curGWStr = if ($currentGW) { $currentGW } else { "(no gateway)" }
    Write-Log "Current IP: $curIPStr | Gateway: $curGWStr"
    
    if ([string]::IsNullOrWhiteSpace($StaticIP)) {
        $script:StaticIP = $curIPStr
        if ($currentIP -and $currentIP.PrefixLength) {
            $prefBits = $currentIP.PrefixLength
            $maskInt  = [uint32]([math]::Pow(2, 32) - [math]::Pow(2, 32 - $prefBits))
            $script:SubnetMask = (
                [string]([byte](($maskInt -shr 24) -band 0xFF)) + '.' +
                [string]([byte](($maskInt -shr 16) -band 0xFF)) + '.' +
                [string]([byte](($maskInt -shr  8) -band 0xFF)) + '.' +
                [string]([byte](($maskInt        ) -band 0xFF))
            )
        }
        if ([string]::IsNullOrWhiteSpace($script:Gateway)) { $script:Gateway = $curGWStr }
        
        if ($script:DNS1 -eq "8.8.8.8") {
            $curDns = Get-DnsClientServerAddress -InterfaceAlias $adapter.Name `
                -AddressFamily IPv4 -ErrorAction SilentlyContinue
            if ($curDns -and $curDns.ServerAddresses) {
                [array]$dnsArr = @($curDns.ServerAddresses)
                if ($dnsArr.Length -gt 0) { $script:DNS1 = $dnsArr[0] }
                if ($dnsArr.Length -gt 1) { $script:DNS2 = $dnsArr[1] }
            }
        }
        Write-Log "Using current IP: $($script:StaticIP) / $($script:SubnetMask)"
    }
    
    if (-not (Test-ValidIP $StaticIP)) {
        Write-Log "Invalid IP '$StaticIP' - skipping network config"
        return $result
    }
    
    $result.IPAddress  = $StaticIP
    $result.SubnetMask = $SubnetMask
    $result.Gateway    = $Gateway
    $result.DNS1       = $DNS1
    $result.DNS2       = $DNS2
    
    try {
        $maskBytes = [System.Net.IPAddress]::Parse($SubnetMask).GetAddressBytes()
        $prefixLen = ($maskBytes | ForEach-Object {
            [Convert]::ToString($_, 2).ToCharArray() | Where-Object { $_ -eq '1' }
        } | Measure-Object).Count
        
        Remove-NetIPAddress -InterfaceAlias $adapter.Name -AddressFamily IPv4 `
            -Confirm:$false -ErrorAction SilentlyContinue
        Remove-NetRoute -InterfaceAlias $adapter.Name -DestinationPrefix "0.0.0.0/0" `
            -Confirm:$false -ErrorAction SilentlyContinue
        Set-NetIPInterface -InterfaceAlias $adapter.Name -Dhcp Disabled -ErrorAction SilentlyContinue
        
        New-NetIPAddress `
            -InterfaceAlias $adapter.Name `
            -IPAddress      $StaticIP `
            -PrefixLength   $prefixLen `
            -DefaultGateway $Gateway `
            -ErrorAction Stop | Out-Null
        
        Set-DnsClientServerAddress `
            -InterfaceAlias  $adapter.Name `
            -ServerAddresses @($DNS1, $DNS2) `
            -ErrorAction SilentlyContinue
        
        & ipconfig /flushdns 2>&1 | Out-Null
        & ipconfig /registerdns 2>&1 | Out-Null
        Start-Sleep -Seconds 2
        
        $result.StaticIPSet = $true
        $result.DHCPEnabled = "Disabled"
        Write-Log "Static IP set: $StaticIP / $SubnetMask"
        
    } catch {
        Write-Log "Error configuring IP: $_"
    }
    
    return $result
}

function Get-MachineInfo {
    Write-Log "Collecting machine info..."
    
    $info = @{}
    $info.MachineName = $env:COMPUTERNAME
    $info.CurrentUser = "$env:USERDOMAIN\$env:USERNAME"
    $info.PSVersion = $PSVersionTable.PSVersion.ToString()
    
    $cs = Get-WmiObject Win32_ComputerSystem -ErrorAction SilentlyContinue
    $info.DomainWorkgroup = if ($cs -and $cs.PartOfDomain) { "Domain: $($cs.Domain)" }
                            else { "Workgroup: $(if ($cs) { $cs.Workgroup } else { 'N/A' })" }
    $info.ComputerModel = if ($cs) { "$($cs.Manufacturer) $($cs.Model)".Trim() } else { "N/A" }
    $info.RAM = if ($cs) { [math]::Round($cs.TotalPhysicalMemory / 1GB, 1).ToString() } else { "N/A" }
    
    $os = Get-WmiObject Win32_OperatingSystem -ErrorAction SilentlyContinue
    $info.OS = if ($os) { $os.Caption } else { "N/A" }
    $info.OSVersion = if ($os) { $os.Version } else { "N/A" }
    $info.OSBuild = if ($os) { $os.BuildNumber } else { "N/A" }
    $info.Architecture = if ($os) { $os.OSArchitecture } else { "N/A" }
    
    $cpu = Get-WmiObject Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
    $info.CPU = if ($cpu) { $cpu.Name.Trim() } else { "N/A" }
    
    $bios = Get-WmiObject Win32_BIOS -ErrorAction SilentlyContinue
    $info.SerialNumber = if ($bios) { $bios.SerialNumber } else { "N/A" }
    
    [array]$disks = @(Get-WmiObject Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction SilentlyContinue)
    $diskParts = [System.Collections.Generic.List[string]]::new()
    if ($disks -and $disks.Length -gt 0) {
        foreach ($d in $disks) {
            $tot = [math]::Round($d.Size / 1GB, 0)
            $fr  = [math]::Round($d.FreeSpace / 1GB, 0)
            $diskParts.Add("$($d.DeviceID) ${tot}GB (Free: ${fr}GB)")
        }
    }
    $info.DiskInfo = if ($diskParts.Count -gt 0) { $diskParts -join " | " } else { "N/A" }
    
    try {
        $def = Get-MpComputerStatus -ErrorAction Stop
        $info.DefenderStatus = if ($def.RealTimeProtectionEnabled) { "Enabled (Real-time)" } else { "Disabled Real-time" }
    } catch { $info.DefenderStatus = "Unknown" }
    
    try {
        [array]$fwProfiles = @(Get-NetFirewallProfile -ErrorAction Stop)
        [array]$fwOn = @($fwProfiles | Where-Object { $_.Enabled })
        $info.FirewallStatus = if ($fwOn -and $fwOn.Length -gt 0) { "Enabled: $($fwOn.Name -join ', ')" } else { "Disabled" }
    } catch { $info.FirewallStatus = "Unknown" }
    
    return $info
}

function Send-ToGoogleSheets {
    param(
        [hashtable]$MachineInfo,
        [hashtable]$NetworkInfo,
        [hashtable]$SecurityInfo
    )
    
    if ($GoogleScriptURL -like "*PASTE_YOUR*") {
        Write-Log "Google Script URL not configured"
        return $false
    }
    
    Write-Log "Sending report to Google Sheets..."
    
    $payload = @{
        MachineName    = $MachineInfo.MachineName
        CurrentUser    = $MachineInfo.CurrentUser
        OS             = $MachineInfo.OS
        OSVersion      = $MachineInfo.OSVersion
        OSBuild        = $MachineInfo.OSBuild
        Architecture   = $MachineInfo.Architecture
        CPU            = $MachineInfo.CPU
        RAM            = $MachineInfo.RAM
        DiskInfo       = $MachineInfo.DiskInfo
        PSVersion      = $MachineInfo.PSVersion
        SerialNumber   = $MachineInfo.SerialNumber
        ComputerModel  = $MachineInfo.ComputerModel
        DomainWorkgroup= $MachineInfo.DomainWorkgroup
        DefenderStatus = $MachineInfo.DefenderStatus
        FirewallStatus = $MachineInfo.FirewallStatus
        IPAddress      = $NetworkInfo.IPAddress
        SubnetMask     = $NetworkInfo.SubnetMask
        Gateway        = $NetworkInfo.Gateway
        DNS1           = $NetworkInfo.DNS1
        DNS2           = $NetworkInfo.DNS2
        MACAddress     = $NetworkInfo.MACAddress
        AdapterName    = $NetworkInfo.AdapterName
        StaticIPSet    = $NetworkInfo.StaticIPSet
        DHCPEnabled    = $NetworkInfo.DHCPEnabled
        BlockMSI       = $SecurityInfo.BlockMSI
        BlockStore     = $SecurityInfo.BlockStore
        BlockElevated  = $SecurityInfo.BlockElevated
        UACEnabled     = $SecurityInfo.UACEnabled
        IsWhitelisted  = (Test-IsExcluded)
    }
    
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $jsonString = $payload | ConvertTo-Json -Depth 5 -Compress
        $jsonBody = [System.Text.Encoding]::UTF8.GetBytes($jsonString)
        
        $response = Invoke-RestMethod `
            -Uri            $GoogleScriptURL `
            -Method         POST `
            -Body           $jsonBody `
            -ContentType    "application/json; charset=utf-8" `
            -TimeoutSec     60 `
            -UseBasicParsing `
            -ErrorAction    Stop
        
        if ($response.status -eq "success") {
            Write-Log "Report sent successfully"
            return $true
        } else {
            Write-Log "Report failed: $($response.message)"
            return $false
        }
    } catch {
        Write-Log "Error sending report: $_"
        return $false
    }
}

# Main execution
Write-Log "=== ChanHung IT Hardening Module Started ==="

$secResult = @{ BlockMSI=$false; BlockStore=$false; BlockElevated=$false; UACEnabled=$false }
$netResult = @{
    StaticIPSet=$false; DHCPEnabled="N/A"
    IPAddress=""; SubnetMask=""; Gateway=""
    DNS1=""; DNS2=""; AdapterName=""; MACAddress=""
}

if (-not $SkipSecurityHardening) {
    $secResult = Invoke-SecurityHardening
}

if (-not $SkipNetworkConfig) {
    $netResult = Invoke-StaticIPConfig
}

$machineInfo = Get-MachineInfo

if (-not $SkipReporting) {
    Send-ToGoogleSheets -MachineInfo $machineInfo -NetworkInfo $netResult -SecurityInfo $secResult
}

Write-Log "=== Module Completed ==="
