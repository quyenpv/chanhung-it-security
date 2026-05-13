# ============================================================
#  CHẤN HƯNG HOLDING - IT HARDENING & ASSET REGISTRATION
#  Version  : 3.0  (+ GitHub Auto-Update Agent)
#  Mục đích : 1) Chặn tự động cài phần mềm
#             2) Thiết lập IP Static
#             3) Gửi thông tin máy lên Google Sheets
#             4) Cài GitHub Agent tự cập nhật policy
# ------------------------------------------------------------
#  YÊU CẦU  : Chạy với quyền Administrator
#  Lệnh chạy:
#    PowerShell -ExecutionPolicy Bypass -File ChanHung_IT_Setup.ps1
# ============================================================

#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    # ── Mạng ──
    [string]$StaticIP   = "",            # Để trống = tự hỏi người dùng
    [string]$SubnetMask = "255.255.255.0",
    [string]$Gateway    = "",
    [string]$DNS1       = "8.8.8.8",
    [string]$DNS2       = "8.8.4.4",

    # ── Google Sheets ──
    # Dán URL Web App sau khi deploy Google Apps Script vào đây:
    [string]$GoogleScriptURL = "https://script.google.com/macros/s/AKfycbwxbL4cRf-fkcUj4FZ93Fi1F2SPUjkMubTgnF7YnBjhr2dq_oxWliEyjP87TigHNPmS/exec",

    # ── Chế độ ──
    [switch]$SkipNetworkConfig,      # Bỏ qua cấu hình mạng
    [switch]$SkipSecurityHardening,  # Bỏ qua chặn phần mềm
    [switch]$SkipReporting,          # Bỏ qua gửi báo cáo
    [switch]$Silent,                 # Không hỏi, dùng giá trị mặc định / param

    # ── GitHub Agent ──
    [string]$GitHubOwner  = "chanhung-it",
    [string]$GitHubRepo   = "ps-agent",
    [string]$GitHubBranch = "main",
    [switch]$SkipAgent                # Bỏ qua bước cài Agent
)

# ============================================================
#  DANH SÁCH MÁY LOẠI TRỪ — ĐỌC TỪ GOOGLE SHEETS
# ------------------------------------------------------------
#  Tạo sheet tên "WHITELIST" trong Google Sheets, cột A ghi
#  tên máy (1 dòng / máy). Hỗ trợ wildcard: PC-DEV-*
#  Script sẽ tự fetch danh sách này mỗi lần chạy.
#  Nếu không fetch được → dùng danh sách dự phòng bên dưới.
# ============================================================

# Danh sách dự phòng (dùng khi mất mạng / chưa có sheet WHITELIST)
$ExcludedHostnames_Fallback = @(
    "PC-ADMIN-01"
    "PC-ADMIN-02"
    "LAPTOP-IT-MGR"
    "VTU-QUYENPV"
    "PC-DEV-*"
)

# Biến global — sẽ được điền bởi Get-WhitelistFromSheets
$ExcludedHostnames = $ExcludedHostnames_Fallback
# ============================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

# ─────────────────────────────────────────────────────────────
#  KIỂM TRA WHITELIST
# ─────────────────────────────────────────────────────────────

function Get-WhitelistFromSheets {
    # Gọi endpoint GET ?action=whitelist để lấy danh sách máy loại trừ từ sheet WHITELIST
    if ($GoogleScriptURL -like "*PASTE_YOUR*") { return }
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $url = "$GoogleScriptURL`?action=whitelist"
        $resp = Invoke-RestMethod -Uri $url -Method GET -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop
        if ($resp.status -eq "ok" -and $resp.hostnames) {
            [array]$fetched = @($resp.hostnames | Where-Object { $_ -and $_.Trim() -ne "" })
            if ($fetched.Length -gt 0) {
                $script:ExcludedHostnames = $fetched
                Write-OK "Whitelist: đọc $($fetched.Length) máy từ Google Sheets"
                return
            }
        }
        Write-Warn "Whitelist: Sheet WHITELIST trống hoặc chưa tạo — dùng danh sách dự phòng"
    } catch {
        Write-Warn "Whitelist: Không fetch được từ Sheets — dùng danh sách dự phòng ($_)"
    }
}

function Test-IsExcluded {
    $hostname = $env:COMPUTERNAME.ToUpper()
    foreach ($pattern in $ExcludedHostnames) {
        if ([string]::IsNullOrWhiteSpace($pattern)) { continue }
        if ($hostname -like $pattern.Trim().ToUpper()) { return $true }
    }
    return $false
}

# ─────────────────────────────────────────────────────────────
#  HÀM TIỆN ÍCH
# ─────────────────────────────────────────────────────────────

function Write-Header {
    Clear-Host
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║   CHẤN HƯNG HOLDING - IT HARDENING TOOL  v2.7       ║" -ForegroundColor Cyan
    Write-Host "  ║   Bảo mật máy tính & Đăng ký tài sản IT             ║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step  ([string]$Text) { Write-Host "`n  ► $Text" -ForegroundColor Yellow }
function Write-OK    ([string]$Text) { Write-Host "    [✓] $Text" -ForegroundColor Green }
function Write-Warn  ([string]$Text) { Write-Host "    [!] $Text" -ForegroundColor DarkYellow }
function Write-Err   ([string]$Text) { Write-Host "    [✗] $Text" -ForegroundColor Red }
function Write-Info  ([string]$Text) { Write-Host "    [-] $Text" -ForegroundColor Gray }

function Set-RegistryValue {
    param([string]$Path, [string]$Name, $Value, [string]$Type = "DWord")
    try {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force
        return $true
    } catch {
        Write-Err "Không thể ghi registry: $Path\$Name — $_"
        return $false
    }
}

function Get-ActiveAdapter {
    # ── FIX v2.2 ──
    # Bỏ HardwareInterface (không tồn tại trên mọi phiên bản Windows)
    # Dùng [array] + .Length thay vì @() + .Count để tránh lỗi StrictMode
    [array]$adapters = @(Get-NetAdapter -ErrorAction SilentlyContinue |
        Where-Object { $_.Status -eq "Up" -and $_.Name -notmatch "Loopback" -and $_.Name -notmatch "vEthernet" })

    # Ưu tiên Ethernet (6) hoặc Wi-Fi (71)
    [array]$physical = @($adapters | Where-Object { $_.InterfaceType -eq 6 -or $_.InterfaceType -eq 71 })
    if ($physical -and $physical.Length -gt 0) { return $physical[0] }
    if ($adapters -and $adapters.Length -gt 0) { return $adapters[0] }

    # Fallback tuyệt đối
    [array]$any = @(Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Up" })
    if ($any -and $any.Length -gt 0) { return $any[0] }
    return $null
}

function Test-ValidIP([string]$IP) {
    return ($IP -match '^\d{1,3}(\.\d{1,3}){3}$') -and ([System.Net.IPAddress]::TryParse($IP, [ref]$null))
}

function Get-RegProp {
    # FIX v2.4: Đọc property từ registry object an toàn dưới Set-StrictMode -Version Latest
    # PSObject.Properties.Match() trả về PSMemberInfoCollection (luôn có .Count, không throw)
    # Nhưng truy cập .Value trên collection rỗng VẪN throw dưới StrictMode
    # => Kiểm tra Count > 0 trước, lấy phần tử [0].Value thay vì .Value trên collection
    param($Item, [string]$PropName)
    $col = $Item.PSObject.Properties.Match($PropName)
    if ($col.Count -gt 0) {
        $val = $col[0].Value
        if ($null -ne $val) { return $val.ToString() }
    }
    return ''
}

# ─────────────────────────────────────────────────────────────
#  PHÁT HIỆN PHẦN MỀM DIỆT VIRUS
# ─────────────────────────────────────────────────────────────

function Get-AntivirusInfo {
    <#
    .SYNOPSIS
        Phát hiện phần mềm diệt virus qua 3 nguồn:
        1. WMI AntiVirusProduct (Windows Security Center)
        2. Windows Defender (Get-MpComputerStatus)
        3. Quét registry & process thông dụng (fallback)
    .OUTPUTS
        Hashtable: AntivirusName, AntivirusState
    #>
    $result = @{ AntivirusName = "Không phát hiện"; AntivirusState = "" }

    # ── Nguồn 1: Windows Security Center (WMI) ──
    # Hoạt động tốt trên Windows 10/11, trả về tất cả AV đã đăng ký
    try {
        [array]$avProducts = @(Get-WmiObject -Namespace "root\SecurityCenter2" `
            -Class AntiVirusProduct -ErrorAction Stop)

        if ($avProducts -and $avProducts.Length -gt 0) {
            $names  = [System.Collections.Generic.List[string]]::new()
            $states = [System.Collections.Generic.List[string]]::new()

            foreach ($av in $avProducts) {
                $names.Add($av.displayName)

                # productState là số hex 6 chữ số:
                # Byte 1 (bits 12-19): loại sản phẩm
                # Byte 2 (bits 4-11) : trạng thái real-time (10=bật, 01=tắt)
                # Byte 3 (bits 0-3)  : cập nhật định nghĩa (00=ok, 10=lỗi thời)
                $state     = $av.productState
                $rtEnabled = (($state -band 0x1000) -ne 0)  # bit 12
                $defUpToDate = (($state -band 0x10) -eq 0)  # bit 4

                $stateStr  = if ($rtEnabled) { "✅ Đang bảo vệ" } else { "⚠️ Tắt bảo vệ" }
                $stateStr += if ($defUpToDate) { " | Định nghĩa mới" } else { " | ⚠️ Định nghĩa cũ" }
                $states.Add($stateStr)
            }

            $result.AntivirusName  = $names  -join " / "
            $result.AntivirusState = $states -join " | "
            return $result
        }
    } catch { }

    # ── Nguồn 2: Windows Defender fallback ──
    try {
        $def = Get-MpComputerStatus -ErrorAction Stop
        $result.AntivirusName = "Windows Defender"

        $stateStr = if ($def.RealTimeProtectionEnabled) { "✅ Đang bảo vệ" } else { "⚠️ Tắt bảo vệ" }

        # Kiểm tra định nghĩa virus
        $defAge = (Get-Date) - $def.AntivirusSignatureLastUpdated
        if ($defAge.TotalDays -le 3) {
            $stateStr += " | Định nghĩa mới ($([math]::Round($defAge.TotalHours,0))h trước)"
        } elseif ($defAge.TotalDays -le 7) {
            $stateStr += " | ⚠️ Định nghĩa $([math]::Round($defAge.TotalDays,0)) ngày trước"
        } else {
            $stateStr += " | ❌ Định nghĩa lỗi thời ($([math]::Round($defAge.TotalDays,0)) ngày)"
        }

        # Kiểm tra scan gần nhất
        if ($def.QuickScanEndTime -and $def.QuickScanEndTime.Year -gt 2000) {
            $scanAge = (Get-Date) - $def.QuickScanEndTime
            $stateStr += " | Quét: $([math]::Round($scanAge.TotalDays,0)) ngày trước"
        }

        $result.AntivirusState = $stateStr
        return $result
    } catch { }

    # ── Nguồn 3: Quét process & registry (fallback cho môi trường domain) ──
    $knownAV = @{
        "avgui"         = "AVG Antivirus"
        "avastui"       = "Avast Antivirus"
        "bdagent"       = "Bitdefender"
        "egui"          = "ESET NOD32"
        "mcshield"      = "McAfee"
        "nortonsecurity"= "Norton Security"
        "kav"           = "Kaspersky"
        "mbam"          = "Malwarebytes"
        "csc"           = "CrowdStrike Falcon"
        "sensecncproc"  = "CrowdStrike Falcon"
        "cylancesvc"    = "Cylance"
        "trapsagent"    = "Palo Alto Traps"
        "savservice"    = "Sophos"
        "spybot"        = "Spybot"
        "drweb"         = "Dr.Web"
        "fsav"          = "F-Secure"
        "tmproxy"       = "Trend Micro"
        "ntrtscan"      = "Trend Micro OfficeScan"
        "vbsvcagt"      = "Viettel CyberShield"
        "bkavservice"   = "BKAV"
        "bkavhome"      = "BKAV Home"
        "cmcavscanner"  = "CMC Antivirus"
    }

    $foundAV = [System.Collections.Generic.List[string]]::new()

    # Quét process đang chạy
    [array]$procs = @(Get-Process -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty Name)
    foreach ($p in $procs) {
        $pLow = $p.ToLower()
        foreach ($k in $knownAV.Keys) {
            if ($pLow -like "*$k*" -and -not $foundAV.Contains($knownAV[$k])) {
                $foundAV.Add($knownAV[$k])
            }
        }
    }

    if ($foundAV.Count -gt 0) {
        $result.AntivirusName  = $foundAV -join " / "
        $result.AntivirusState = "✅ Phát hiện qua process"
    } else {
        $result.AntivirusName  = "Không phát hiện"
        $result.AntivirusState = "⚠️ Có thể chưa cài AV hoặc AV dùng service ẩn"
    }

    return $result
}

# ─────────────────────────────────────────────────────────────
#  BƯỚC 1: CHẶN TỰ ĐỘNG CÀI PHẦN MỀM
# ─────────────────────────────────────────────────────────────

function Invoke-SecurityHardening {
    Write-Step "BƯỚC 1: Cấu hình chính sách cài đặt phần mềm"

    $results = @{ BlockMSI=$false; BlockStore=$false; BlockElevated=$false; UACEnabled=$false }

    Write-Info "Chặn cài đặt MSI cho người dùng thường..."
    $ok1 = Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer" "DisableMSI" 2
    $ok2 = Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer" "EnableUserControl" 0
    if ($ok1 -and $ok2) { Write-OK "Đã chặn MSI installer cho người dùng thường"; $results.BlockMSI = $true }

    Write-Info "Vô hiệu hóa AlwaysInstallElevated..."
    $ok3 = Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer" "AlwaysInstallElevated" 0
    $ok4 = Set-RegistryValue "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Installer" "AlwaysInstallElevated" 0
    if ($ok3 -and $ok4) { Write-OK "Đã vô hiệu hóa AlwaysInstallElevated"; $results.BlockElevated = $true }

    Write-Info "Cấu hình Windows Store..."
    $ok5 = Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore" "AutoDownload" 2
    $ok6 = Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore" "DisableStoreApps" 1
    if ($ok5) { Write-OK "Đã tắt tự động tải ứng dụng từ Store"; $results.BlockStore = $true }
    if ($ok6) { Write-OK "Đã chặn cài ứng dụng Store mới" }

    Write-Info "Chặn AutoRun từ USB và đĩa..."
    Set-RegistryValue "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" "NoDriveTypeAutoRun" 255 | Out-Null
    Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" "NoAutoplayfornonVolume" 1 | Out-Null
    Write-OK "Đã chặn AutoRun từ tất cả thiết bị"

    Write-Info "Tắt tự động chạy file tải từ Internet..."
    Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Attachments" "SaveZoneInformation" 2 | Out-Null
    Write-OK "Đã cấu hình chính sách file Internet"

    Write-Info "Kiểm tra UAC..."
    $uacVal = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" `
        -Name "EnableLUA" -ErrorAction SilentlyContinue).EnableLUA
    if ($uacVal -ne 1) {
        Set-RegistryValue "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" "EnableLUA" 1 | Out-Null
        Write-Warn "UAC đã được bật lại (trước đó đang tắt)"
    } else { Write-OK "UAC đang hoạt động" }
    $results.UACEnabled = $true

    Write-Host ""
    Write-OK "Hoàn tất cấu hình bảo mật chặn cài phần mềm"
    return $results
}

# ─────────────────────────────────────────────────────────────
#  BƯỚC 2: THIẾT LẬP IP STATIC
# ─────────────────────────────────────────────────────────────

function Invoke-StaticIPConfig {
    Write-Step "BƯỚC 2: Cấu hình địa chỉ IP Static"

    $result = @{
        StaticIPSet=$false; DHCPEnabled="N/A"
        IPAddress=""; SubnetMask=$SubnetMask; Gateway=$Gateway
        DNS1=$DNS1; DNS2=$DNS2; AdapterName=""; MACAddress=""
    }

    $adapter = Get-ActiveAdapter
    if (-not $adapter) {
        Write-Err "Không tìm thấy network adapter đang hoạt động!"
        return $result
    }

    $result.AdapterName = $adapter.Name
    $result.MACAddress  = $adapter.MacAddress
    Write-Info "Adapter: $($adapter.Name)  MAC: $($adapter.MacAddress)"

    $currentIP = Get-NetIPAddress -InterfaceAlias $adapter.Name `
        -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -notlike "169.*" } | Select-Object -First 1
    $currentGW = (Get-NetRoute -InterfaceAlias $adapter.Name `
        -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue |
        Select-Object -First 1).NextHop

    $curIPStr = if ($currentIP) { $currentIP.IPAddress } else { "(chưa có IP)" }
    $curGWStr = if ($currentGW) { $currentGW }           else { "(chưa có gateway)" }
    Write-Info "IP hiện tại: $curIPStr  |  Gateway: $curGWStr"

    # Tự động dùng IP hiện tại nếu không truyền tham số -StaticIP
    # Không hỏi người dùng — đây là hành vi mặc định
    if ([string]::IsNullOrWhiteSpace($StaticIP)) {
        $script:StaticIP = $curIPStr

        # Lấy subnet mask từ prefix length hiện tại
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
        # Gateway & DNS: dùng giá trị hiện tại nếu chưa có
        if ([string]::IsNullOrWhiteSpace($script:Gateway)) { $script:Gateway = $curGWStr }

        # DNS: đọc từ adapter nếu chưa được truyền tham số
        if ($script:DNS1 -eq "8.8.8.8") {
            $curDns = Get-DnsClientServerAddress -InterfaceAlias $adapter.Name `
                -AddressFamily IPv4 -ErrorAction SilentlyContinue
            if ($curDns -and $curDns.ServerAddresses) {
                [array]$dnsArr = @($curDns.ServerAddresses)
                if ($dnsArr.Length -gt 0) { $script:DNS1 = $dnsArr[0] }
                if ($dnsArr.Length -gt 1) { $script:DNS2 = $dnsArr[1] }
            }
        }
        Write-Info "Tự động dùng IP hiện tại: $($script:StaticIP) / $($script:SubnetMask)"
        Write-Info "Gateway: $($script:Gateway)  |  DNS: $($script:DNS1), $($script:DNS2)"
    }

    if (-not (Test-ValidIP $StaticIP)) {
        Write-Err "Địa chỉ IP '$StaticIP' không hợp lệ! Bỏ qua cấu hình mạng."
        $result.IPAddress = $curIPStr
        return $result
    }

    $result.IPAddress  = $StaticIP
    $result.SubnetMask = $SubnetMask
    $result.Gateway    = $Gateway
    $result.DNS1       = $DNS1
    $result.DNS2       = $DNS2

    Write-Host ""
    Write-Info "Đang áp dụng cấu hình IP Static..."

    try {
        # Tính prefix length
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

        # FIX v2.3: Flush DNS cache sau khi đổi DNS server
        # Nếu không flush, Windows vẫn dùng cache cũ → không resolve được tên miền
        Write-Info "Đang flush DNS cache..."
        & ipconfig /flushdns 2>&1 | Out-Null
        & ipconfig /registerdns 2>&1 | Out-Null
        # Chờ adapter ổn định
        Start-Sleep -Seconds 2

        $result.StaticIPSet = $true
        $result.DHCPEnabled = "Disabled"
        Write-OK "Đã đặt IP Static: $StaticIP / $SubnetMask"
        Write-OK "Default Gateway : $Gateway"
        Write-OK "DNS             : $DNS1  |  $DNS2"
        Write-OK "DNS cache đã được flush"

    } catch {
        Write-Err "Lỗi khi cấu hình IP: $_"
        $result.IPAddress = $curIPStr
    }

    return $result
}

# ─────────────────────────────────────────────────────────────
#  BƯỚC 3: THU THẬP THÔNG TIN MÁY
# ─────────────────────────────────────────────────────────────

function Get-MachineInfo {
    Write-Step "BƯỚC 3: Thu thập thông tin máy tính"

    $info = @{}

    Write-Info "Đang đọc thông tin hệ thống..."
    $info.MachineName = $env:COMPUTERNAME
    $info.CurrentUser = "$env:USERDOMAIN\$env:USERNAME"
    $info.PSVersion   = $PSVersionTable.PSVersion.ToString()

    $cs = Get-WmiObject Win32_ComputerSystem -ErrorAction SilentlyContinue
    $info.DomainWorkgroup = if ($cs -and $cs.PartOfDomain) { "Domain: $($cs.Domain)" }
                            else { "Workgroup: $(if ($cs) { $cs.Workgroup } else { 'N/A' })" }
    $info.ComputerModel = if ($cs) { "$($cs.Manufacturer) $($cs.Model)".Trim() } else { "N/A" }
    $info.RAM = if ($cs) { [math]::Round($cs.TotalPhysicalMemory / 1GB, 1).ToString() } else { "N/A" }

    $os = Get-WmiObject Win32_OperatingSystem -ErrorAction SilentlyContinue
    $info.OS           = if ($os) { $os.Caption }        else { "N/A" }
    $info.OSVersion    = if ($os) { $os.Version }        else { "N/A" }
    $info.OSBuild      = if ($os) { $os.BuildNumber }    else { "N/A" }
    $info.Architecture = if ($os) { $os.OSArchitecture } else { "N/A" }

    $cpu = Get-WmiObject Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
    $info.CPU = if ($cpu) { $cpu.Name.Trim() } else { "N/A" }

    $bios = Get-WmiObject Win32_BIOS -ErrorAction SilentlyContinue
    $info.SerialNumber = if ($bios) { $bios.SerialNumber } else { "N/A" }

    Write-Info "Đang đọc thông tin ổ cứng..."
    [array]$disks = @(Get-WmiObject Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction SilentlyContinue)
    $diskParts = [System.Collections.Generic.List[string]]::new()
    if ($disks -and $disks.Length -gt 0) {
        foreach ($d in $disks) {
            $tot = [math]::Round($d.Size / 1GB, 0)
            $fr  = [math]::Round($d.FreeSpace / 1GB, 0)
            $diskParts.Add("$($d.DeviceID) ${tot}GB (Còn: ${fr}GB)")
        }
    }
    $info.DiskInfo = if ($diskParts.Count -gt 0) { $diskParts -join " | " } else { "N/A" }

    Write-Info "Đang kiểm tra trạng thái bảo mật..."
    try {
        $def = Get-MpComputerStatus -ErrorAction Stop
        $info.DefenderStatus = if ($def.RealTimeProtectionEnabled) { "Đang bật (Real-time)" } else { "Tắt Real-time" }
    } catch { $info.DefenderStatus = "Không xác định" }

    try {
        [array]$fwProfiles = @(Get-NetFirewallProfile -ErrorAction Stop)
        [array]$fwOn = @($fwProfiles | Where-Object { $_.Enabled })
        $info.FirewallStatus = if ($fwOn -and $fwOn.Length -gt 0) { "Bật: $($fwOn.Name -join ', ')" } else { "Tắt" }
    } catch { $info.FirewallStatus = "Không xác định" }

    try {
        $wuReg = Get-ItemProperty `
            "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -ErrorAction SilentlyContinue
        $info.WindowsUpdate = switch ($wuReg.AUOptions) {
            2 { "Chỉ thông báo" }; 3 { "Tự động tải, hỏi khi cài" }
            4 { "Tự động tải và cài" }; 5 { "Người dùng chọn" }
            default { "Mặc định Windows" }
        }
    } catch { $info.WindowsUpdate = "Mặc định" }

    # ── Phần mềm diệt virus ──
    Write-Info "Đang quét phần mềm diệt virus..."
    $avInfo = Get-AntivirusInfo
    $info.AntivirusName  = $avInfo.AntivirusName
    $info.AntivirusState = $avInfo.AntivirusState
    Write-OK "Antivirus: $($avInfo.AntivirusName)"

    # ── Danh sách phần mềm ──
    Write-Info "Đang lấy danh sách phần mềm cài đặt (có thể mất 30–60 giây)..."

    # FIX v2.3: Dùng Dictionary để dedup thay vì Group-Object
    # Group-Object { $_["Name"] } không hoạt động đúng với hashtable trên PS 5.1
    $appDict = [System.Collections.Generic.Dictionary[string, hashtable]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )

    $regPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    foreach ($regPath in $regPaths) {
        # ErrorAction SilentlyContinue ở đây đủ để bỏ qua key không tồn tại
        $items = Get-ItemProperty $regPath -ErrorAction SilentlyContinue
        if (-not $items) { continue }

        foreach ($item in @($items)) {
            # FIX v2.3: Dùng PSObject.Properties để đọc property an toàn dưới StrictMode
            # $item.DisplayVersion sẽ THROW nếu property không tồn tại khi StrictMode=Latest
            # PSObject.Properties.Match() trả về empty collection (không throw) nếu không có
            $displayName = Get-RegProp $item 'DisplayName'
            if (-not $displayName -or $displayName.Trim() -eq '') { continue }

            $name = $displayName.Trim()
            if ($appDict.ContainsKey($name)) { continue }   # dedup

            $appDict[$name] = @{
                Name        = $name
                Version     = Get-RegProp $item 'DisplayVersion'
                Publisher   = Get-RegProp $item 'Publisher'
                InstallDate = Get-RegProp $item 'InstallDate'
            }
        }
    }

    # Sắp xếp theo tên và chuyển về array
    [array]$apps = @($appDict.Values | Sort-Object { $_["Name"] })

    $info.InstalledApps = $apps
    $appCount = if ($apps) { $apps.Length } else { 0 }
    Write-OK "Tìm thấy $appCount phần mềm cài đặt"

    return $info
}

# ─────────────────────────────────────────────────────────────
#  BƯỚC 4: GỬI DỮ LIỆU LÊN GOOGLE SHEETS
# ─────────────────────────────────────────────────────────────

function Send-ToGoogleSheets {
    param(
        [hashtable]$MachineInfo,
        [hashtable]$NetworkInfo,
        [hashtable]$SecurityInfo
    )

    Write-Step "BƯỚC 4: Gửi báo cáo lên Google Sheets"

    if ($GoogleScriptURL -like "*PASTE_YOUR*") {
        Write-Warn "Chưa cấu hình Google Script URL!"
        Write-Info "Mở file .ps1, tìm `$GoogleScriptURL và dán URL Web App vào."
        return $false
    }

    Write-Info "Đang chuẩn bị payload JSON..."

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
        WindowsUpdate  = $MachineInfo.WindowsUpdate
        InstalledApps  = $MachineInfo.InstalledApps
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
        SoftwareBlocked= ($SecurityInfo.BlockMSI -and $SecurityInfo.BlockStore -and $SecurityInfo.BlockElevated)
        IsWhitelisted  = (Test-IsExcluded)
        AntivirusName  = $MachineInfo.AntivirusName
        AntivirusState = $MachineInfo.AntivirusState
    }

    # FIX v2.5: ConvertTo-Json trả về string Unicode nhưng Invoke-RestMethod
    # gửi theo encoding mặc định của Windows (thường Windows-1252) → tiếng Việt vỡ.
    # Ép sang UTF-8 bytes trước, truyền vào -Body dạng byte array là cách duy nhất
    # đảm bảo 100% UTF-8 trên mọi máy Windows bất kể Regional Settings.
    $jsonString = $payload | ConvertTo-Json -Depth 5 -Compress
    $jsonBody   = [System.Text.Encoding]::UTF8.GetBytes($jsonString)
    Write-Info "Đang gửi đến Google Sheets ($($MachineInfo.MachineName))..."

    # FIX v2.3: Retry khi gặp lỗi DNS (xảy ra ngay sau khi đổi Static IP/DNS mới)
    $maxRetry  = 2
    $retryWait = 5
    $attempt   = 0
    $errMsg    = ""

    while ($attempt -le $maxRetry) {
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

            $response = Invoke-RestMethod `
                -Uri            $GoogleScriptURL `
                -Method         POST `
                -Body           $jsonBody `
                -ContentType    "application/json; charset=utf-8" `
                -TimeoutSec     60 `
                -UseBasicParsing `
                -ErrorAction    Stop

            if ($response.status -eq "success") {
                Write-OK "Đã gửi thành công! Sheet: $($response.machine)"
                return $true
            } else {
                Write-Warn "Gửi có lỗi: $($response.message)"
                return $false
            }

        } catch {
            $errMsg = $_.ToString()
            if ($errMsg -match "could not be resolved|NameResolution|DNS" -and $attempt -lt $maxRetry) {
                $attempt++
                Write-Warn "DNS chưa sẵn sàng — thử lại lần $attempt/$maxRetry sau ${retryWait}s..."
                Start-Sleep -Seconds $retryWait
                & ipconfig /flushdns 2>&1 | Out-Null
                continue  # quay lại while
            }
            break
        }
    }

    # ── Xử lý lỗi sau hết retry ──
    if ($errMsg -match "401") {
        Write-Err "Lỗi 401 — Google Apps Script từ chối (Unauthorized)"
        Write-Host ""
        Write-Host "  ┌── CÁCH SỬA LỖI 401 ───────────────────────────────────┐" -ForegroundColor Yellow
        Write-Host "  │  1. Mở Google Sheets → Extensions → Apps Script        │" -ForegroundColor Yellow
        Write-Host "  │  2. Click Deploy → Manage deployments                  │" -ForegroundColor Yellow
        Write-Host "  │  3. Chỉnh sửa deployment hiện có (icon bút chì)        │" -ForegroundColor Yellow
        Write-Host "  │  4. 'Who has access' → đổi thành 'Anyone'              │" -ForegroundColor Yellow
        Write-Host "  │  5. Bấm Deploy → copy URL mới → dán vào `$GoogleScriptURL │" -ForegroundColor Yellow
        Write-Host "  │  ⚠️  Không dùng 'Test deployment' — phải dùng URL chính  │" -ForegroundColor Yellow
        Write-Host "  └────────────────────────────────────────────────────────┘" -ForegroundColor Yellow
        Write-Host ""
    } elseif ($errMsg -match "404") {
        Write-Err "Lỗi 404 — URL Web App không đúng hoặc đã bị xóa."
        Write-Info "Kiểm tra lại `$GoogleScriptURL trong file .ps1."
    } elseif ($errMsg -match "could not be resolved|NameResolution|DNS") {
        Write-Err "Không thể kết nối Google — DNS vẫn chưa hoạt động sau $maxRetry lần thử."
        Write-Info "Chạy lại script sau vài phút, hoặc mở cmd gõ: ipconfig /flushdns"
    } elseif ($errMsg -match "timeout|timed out") {
        Write-Err "Timeout — Script mất quá nhiều thời gian phản hồi."
        Write-Info "Thử chạy lại hoặc kiểm tra kết nối Internet."
    } elseif ($errMsg) {
        Write-Err "Lỗi kết nối: $errMsg"
    }

    Write-Info "Đã lưu log local: $env:TEMP\ChanHung_IT_Report.json"
    $jsonString | Out-File "$env:TEMP\ChanHung_IT_Report.json" -Encoding UTF8
    return $false
}

# ─────────────────────────────────────────────────────────────
#  BƯỚC 5: TẠO BÁO CÁO LOCAL
# ─────────────────────────────────────────────────────────────

function Write-LocalReport {
    param(
        [hashtable]$MachineInfo,
        [hashtable]$NetworkInfo,
        [hashtable]$SecurityInfo
    )

    $reportPath = "$env:USERPROFILE\Desktop\ChanHung_IT_Report_$($MachineInfo.MachineName).txt"

    # FIX v2.2: Dùng List[string] + $sep tách riêng
    # Nguyên nhân lỗi cũ: @("=" * 60, "chuỗi tiếp theo") khiến PS parse nhầm
    # "=" * (60, "chuỗi") → lỗi "Cannot convert Object[] to Int32"
    $sep   = "=" * 60
    $lines = [System.Collections.Generic.List[string]]::new()

    $lines.Add($sep)
    $lines.Add("  CHẤN HƯNG HOLDING - BÁO CÁO CẤU HÌNH MÁY")
    $lines.Add("  Ngày xuất  : $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')")
    $lines.Add("  Phiên bản  : ChanHung_IT_Setup v2.2")
    $lines.Add($sep)
    $lines.Add("")
    $lines.Add("[ THÔNG TIN MÁY ]")
    $lines.Add("  Tên máy      : $($MachineInfo.MachineName)")
    $lines.Add("  Người dùng   : $($MachineInfo.CurrentUser)")
    $lines.Add("  Domain/WG    : $($MachineInfo.DomainWorkgroup)")
    $lines.Add("  Model        : $($MachineInfo.ComputerModel)")
    $lines.Add("  OS           : $($MachineInfo.OS) ($($MachineInfo.OSVersion))")
    $lines.Add("  CPU          : $($MachineInfo.CPU)")
    $lines.Add("  RAM          : $($MachineInfo.RAM) GB")
    $lines.Add("  Ổ cứng       : $($MachineInfo.DiskInfo)")
    $lines.Add("  Serial BIOS  : $($MachineInfo.SerialNumber)")
    $lines.Add("  PowerShell   : $($MachineInfo.PSVersion)")
    $lines.Add("")
    $lines.Add("[ CẤU HÌNH MẠNG ]")
    $lines.Add("  IP Address   : $($NetworkInfo.IPAddress)")
    $lines.Add("  Subnet Mask  : $($NetworkInfo.SubnetMask)")
    $lines.Add("  Gateway      : $($NetworkInfo.Gateway)")
    $lines.Add("  DNS          : $($NetworkInfo.DNS1)  |  $($NetworkInfo.DNS2)")
    $lines.Add("  MAC Address  : $($NetworkInfo.MACAddress)")
    $lines.Add("  Adapter      : $($NetworkInfo.AdapterName)")
    $lines.Add("  Loại IP      : $(if ($NetworkInfo.StaticIPSet) {'STATIC (đã đặt)'} else {'DHCP / chưa đổi'})")
    $lines.Add("")
    $lines.Add("[ BẢO MẬT ]")
    $wlNote = if (Test-IsExcluded) { " (máy whitelist — bỏ qua)" } else { "" }
    $lines.Add("  Chặn MSI     : $(if ($SecurityInfo.BlockMSI) {'✓ Đã bật'} else {"✗ Chưa bật$wlNote"})")
    $lines.Add("  Chặn Store   : $(if ($SecurityInfo.BlockStore) {'✓ Đã bật'} else {"✗ Chưa bật$wlNote"})")
    $lines.Add("  Elev.Block   : $(if ($SecurityInfo.BlockElevated) {'✓ Đã bật'} else {"✗ Chưa bật$wlNote"})")
    $lines.Add("  UAC          : $(if ($SecurityInfo.UACEnabled) {'✓ Bật'} else {'✗ Tắt'})")
    $lines.Add("  Defender     : $($MachineInfo.DefenderStatus)")
    $lines.Add("  Firewall     : $($MachineInfo.FirewallStatus)")
    $lines.Add("")

    [array]$apps = @($MachineInfo.InstalledApps)
    $appCount = if ($apps) { $apps.Length } else { 0 }
    $lines.Add("[ PHẦN MỀM ($appCount ứng dụng) ]")

    if ($apps -and $appCount -gt 0) {
        foreach ($app in $apps) {
            $ver = if ($app["Version"]) { "  v$($app['Version'])" } else { "" }
            $lines.Add("  - $($app['Name'])$ver")
        }
    } else {
        $lines.Add("  (Không có dữ liệu)")
    }

    $lines.Add("")
    $lines.Add($sep)

    $lines | Out-File $reportPath -Encoding UTF8
    Write-OK "Đã lưu báo cáo: $reportPath"
}

# ─────────────────────────────────────────────────────────────
#  GITHUB AGENT — BIẾN & TOKEN
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
    foreach ($d in @($script:AgentBaseDir, "C:\ChanHung\Logs")) {
        if (-not (Test-Path $d)) { New-Item -ItemType Directory $d -Force | Out-Null }
    }
    $enc | Out-File $script:AgentTokenFile -Encoding UTF8 -Force
    attrib +h +s $script:AgentTokenFile
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
#  GITHUB AGENT — HTTP & HASH
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
        elseif ($code -eq 404) { Write-Warn "GitHub: Không tìm thấy '$RepoPath' trên repo" }
        else                   { Write-Err  "GitHub API lỗi [$RepoPath]: $_" }
        return $null
    }
}

function Get-SHA256 { param([string]$Path)
    return (Get-FileHash $Path -Algorithm SHA256).Hash
}
function Test-SHA256 { param([string]$Path, [string]$Expected)
    $actual = Get-SHA256 $Path
    if ($actual -ne $Expected.ToUpper()) {
        Write-Err "Hash KHÔNG KHỚP: $([System.IO.Path]::GetFileName($Path))"
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

    $manifest = Invoke-GitHubAPI -RepoPath "manifest.json" -Token $token
    if (-not $manifest) { return }

    $selfEntry = $manifest.modules | Where-Object { $_.name -eq "ChanHung_IT_Setup" }
    if (-not $selfEntry) { return }

    $localVer = if (Test-Path $script:AgentVerFile) {
        try { (Get-Content $script:AgentVerFile | ConvertFrom-Json).self_version } catch { "0.0.0" }
    } else { "0.0.0" }

    if ($selfEntry.version -eq $localVer) { return }   # Đang dùng bản mới nhất

    Write-Info "Phát hiện phiên bản mới v$($selfEntry.version) — đang tải..."
    $tmp = Join-Path $env:TEMP "ChanHung_IT_Setup_new.ps1"
    $ok  = Invoke-GitHubAPI -RepoPath "modules/ChanHung_IT_Setup.ps1" -OutFile $tmp -Token $token
    if (-not $ok) { return }
    if (-not (Test-SHA256 $tmp $selfEntry.sha256)) {
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        return
    }

    Copy-Item $tmp $PSCommandPath -Force
    Remove-Item $tmp -Force

    # Lưu version mới
    $ver = if (Test-Path $script:AgentVerFile) {
        try { Get-Content $script:AgentVerFile | ConvertFrom-Json } catch { [PSCustomObject]@{ version="0.0.0"; self_version="0.0.0"; modules=@{} } }
    } else { [PSCustomObject]@{ version="0.0.0"; self_version="0.0.0"; modules=@{} } }
    $ver | Add-Member -NotePropertyName "self_version" -NotePropertyValue $selfEntry.version -Force
    $ver | ConvertTo-Json -Depth 5 | Out-File $script:AgentVerFile -Encoding UTF8 -Force

    Write-OK "Đã cập nhật script lên v$($selfEntry.version) — khởi động lại..."
    Start-Sleep -Seconds 2
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath @($PSBoundParameters.GetEnumerator() | ForEach-Object { "-$($_.Key)"; if ($_.Value -isnot [switch]) { $_.Value } })
    exit
}

# ─────────────────────────────────────────────────────────────
#  GITHUB AGENT — CÀI ĐẶT SCHEDULED TASK
# ─────────────────────────────────────────────────────────────

function Install-GitHubAgent {
    param([string]$Token)

    Write-Step "BƯỚC 5: Cài GitHub Auto-Update Agent"

    # Kiểm tra token
    Write-Info "Kiểm tra kết nối GitHub..."
    $manifest = Invoke-GitHubAPI -RepoPath "manifest.json" -Token $Token
    if (-not $manifest) {
        Write-Err "Không kết nối được GitHub. Kiểm tra lại token và tên repo."
        return $false
    }
    Write-OK "GitHub OK — Manifest v$($manifest.version)"

    # Lưu token encrypted
    Save-AgentToken $Token
    Write-OK "Token đã lưu encrypted (DPAPI — chỉ đọc được trên máy này)"

    # Tạo thư mục
    foreach ($d in @($script:AgentBaseDir, $script:AgentModsDir, "C:\ChanHung\Logs")) {
        if (-not (Test-Path $d)) { New-Item -ItemType Directory $d -Force | Out-Null }
    }

    # Tải ChanHung-Agent.ps1 từ GitHub
    $agentDest  = Join-Path $script:AgentBaseDir "ChanHung-Agent.ps1"
    $agentEntry = $manifest.modules | Where-Object { $_.name -eq "ChanHung-Agent" }

    if ($agentEntry) {
        $tmp = Join-Path $env:TEMP "ChanHung-Agent_dl.ps1"
        $ok  = Invoke-GitHubAPI -RepoPath "modules/ChanHung-Agent.ps1" -OutFile $tmp -Token $Token
        if ($ok -and (Test-SHA256 $tmp $agentEntry.sha256)) {
            Move-Item $tmp $agentDest -Force
            Write-OK "Đã tải ChanHung-Agent.ps1 từ GitHub"
        } else {
            Remove-Item $tmp -Force -ErrorAction SilentlyContinue
            Write-Warn "Không tải được agent — dùng self-run mode"
            # Stub: agent gọi lại script chính ở chế độ silent
            "powershell.exe -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Silent -SkipAgent" |
                Out-File $agentDest -Encoding UTF8 -Force
        }
    } else {
        Write-Warn "ChanHung-Agent chưa có trong manifest — dùng self-run mode"
        "powershell.exe -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Silent -SkipAgent" |
            Out-File $agentDest -Encoding UTF8 -Force
    }

    # Tạo Scheduled Task — chạy với SYSTEM mỗi 15 phút
    $action = New-ScheduledTaskAction `
        -Execute  "powershell.exe" `
        -Argument "-NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$agentDest`""

    $trigger = New-ScheduledTaskTrigger `
        -RepetitionInterval (New-TimeSpan -Minutes 15) `
        -Once -At (Get-Date)

    $principal = New-ScheduledTaskPrincipal `
        -UserId    "NT AUTHORITY\SYSTEM" `
        -LogonType ServiceAccount `
        -RunLevel  Highest

    $settings = New-ScheduledTaskSettingsSet `
        -ExecutionTimeLimit    (New-TimeSpan -Minutes 5) `
        -StartWhenAvailable `
        -RunOnlyIfNetworkAvailable `
        -RestartCount          3 `
        -RestartInterval       (New-TimeSpan -Minutes 2)

    Unregister-ScheduledTask -TaskName $script:AgentTaskName -Confirm:$false -ErrorAction SilentlyContinue
    Register-ScheduledTask `
        -TaskName    $script:AgentTaskName `
        -Action      $action `
        -Trigger     $trigger `
        -Principal   $principal `
        -Settings    $settings `
        -Description "Chấn Hưng IT Agent — tự cập nhật policy từ GitHub" | Out-Null

    # Ẩn thư mục agent
    attrib +h +s $script:AgentBaseDir

    # Kích hoạt ngay
    Start-ScheduledTask -TaskName $script:AgentTaskName -ErrorAction SilentlyContinue

    Write-OK "Agent đã cài và kích hoạt!"
    Write-Info "Scheduled Task '$($script:AgentTaskName)' — tự chạy mỗi 15 phút"
    Write-Info "Từ nay chỉ cần push module lên GitHub, máy này tự cập nhật."
    return $true
}

# ─────────────────────────────────────────────────────────────
#  CHƯƠNG TRÌNH CHÍNH
# ─────────────────────────────────────────────────────────────

# Tự kiểm tra update từ GitHub (chỉ chạy khi đã cài agent)
try { Invoke-SelfUpdate } catch { <# không block wizard nếu lỗi #> }



# ── Fetch whitelist từ Google Sheets ──
Write-Info "Đang đọc danh sách whitelist từ Google Sheets..."
Get-WhitelistFromSheets

# ── Kiểm tra Whitelist ──
$isExcluded = Test-IsExcluded

if ($isExcluded) {
    $matchedPattern = $ExcludedHostnames |
        Where-Object { $env:COMPUTERNAME.ToUpper() -like $_.Trim().ToUpper() } |
        Select-Object -First 1

    Write-Host "  ⚠️  MÁY NÀY NẰM TRONG DANH SÁCH LOẠI TRỪ" -ForegroundColor DarkYellow
    Write-Host "  ┌──────────────────────────────────────────────────────┐" -ForegroundColor DarkYellow
    Write-Host "  │  Hostname : $($env:COMPUTERNAME.PadRight(44))│" -ForegroundColor DarkYellow
    Write-Host "  │  Khớp với: $($matchedPattern.PadRight(45))│" -ForegroundColor DarkYellow
    Write-Host "  │                                                      │" -ForegroundColor DarkYellow
    Write-Host "  │  ⏭️  Bỏ qua : Chặn cài đặt phần mềm                 │" -ForegroundColor DarkYellow
    Write-Host "  │  ✅ Vẫn làm: Set IP Static                           │" -ForegroundColor DarkYellow
    Write-Host "  │  ✅ Vẫn làm: Gửi báo cáo lên Google Sheets           │" -ForegroundColor DarkYellow
    Write-Host "  └──────────────────────────────────────────────────────┘" -ForegroundColor DarkYellow
    Write-Host ""
    $SkipSecurityHardening = $true
}

# ── Xác nhận ──
if (-not $Silent) {
    Write-Host "  Máy tính : $env:COMPUTERNAME" -ForegroundColor White
    Write-Host "  User     : $env:USERNAME"     -ForegroundColor White
    Write-Host "  Thời gian: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')" -ForegroundColor White
    Write-Host ""
    Write-Host "  Script sẽ thực hiện:" -ForegroundColor Cyan
    if (-not $SkipSecurityHardening) {
        Write-Host "    [1] Chặn tự động cài đặt phần mềm" -ForegroundColor White
    } else {
        Write-Host "    [1] Chặn phần mềm  →  ⏭️  BỎ QUA (máy trong whitelist)" -ForegroundColor DarkYellow
    }
    if (-not $SkipNetworkConfig) { Write-Host "    [2] Cấu hình IP Static"            -ForegroundColor White }
    if (-not $SkipReporting)     { Write-Host "    [3] Gửi báo cáo lên Google Sheets" -ForegroundColor White }
    $agentAlready = $null -ne (Get-ScheduledTask -TaskName $script:AgentTaskName -ErrorAction SilentlyContinue)
    if (-not $SkipAgent) {
        if ($agentAlready) {
            Write-Host "    [5] GitHub Agent         →  ✅ Đã cài (bỏ qua)" -ForegroundColor DarkGray
        } else {
            Write-Host "    [5] Cài GitHub Auto-Update Agent" -ForegroundColor Magenta
        }
    }
    Write-Host ""

    $confirm = Read-Host "  Tiếp tục? [Y/N]"
    if ($confirm -notmatch "^[Yy]") {
        Write-Host "  Đã hủy." -ForegroundColor Red
        exit 0
    }
}

# ── Chạy các bước ──
$secResult = @{ BlockMSI=$false; BlockStore=$false; BlockElevated=$false; UACEnabled=$false }
$netResult = @{
    StaticIPSet=$false; DHCPEnabled="N/A"
    IPAddress=""; SubnetMask=""; Gateway=""
    DNS1=""; DNS2=""; AdapterName=""; MACAddress=""
}
$sent = $false

if (-not $SkipSecurityHardening) {
    $secResult = Invoke-SecurityHardening
}

if (-not $SkipNetworkConfig) {
    $netResult = Invoke-StaticIPConfig
} else {
    # Đọc thông tin mạng hiện tại mà không thay đổi cấu hình
    $adapter = Get-ActiveAdapter
    if ($adapter) {
        $netResult.AdapterName = $adapter.Name
        $netResult.MACAddress  = $adapter.MacAddress

        $curIP = Get-NetIPAddress -InterfaceAlias $adapter.Name `
            -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Where-Object { $_.IPAddress -notlike "169.*" } | Select-Object -First 1
        if ($curIP) { $netResult.IPAddress = $curIP.IPAddress }

        $curGW = (Get-NetRoute -InterfaceAlias $adapter.Name -DestinationPrefix "0.0.0.0/0" `
            -ErrorAction SilentlyContinue | Select-Object -First 1).NextHop
        if ($curGW) { $netResult.Gateway = $curGW }

        $dhcpStatus = (Get-NetIPInterface -InterfaceAlias $adapter.Name `
            -AddressFamily IPv4 -ErrorAction SilentlyContinue).Dhcp
        $netResult.DHCPEnabled = if ($dhcpStatus) { $dhcpStatus.ToString() } else { "Unknown" }

        $dnsInfo = Get-DnsClientServerAddress -InterfaceAlias $adapter.Name `
            -AddressFamily IPv4 -ErrorAction SilentlyContinue
        if ($dnsInfo -and $dnsInfo.ServerAddresses) {
            [array]$dnsArr = @($dnsInfo.ServerAddresses)
            $netResult.DNS1 = if ($dnsArr.Length -gt 0) { $dnsArr[0] } else { "" }
            $netResult.DNS2 = if ($dnsArr.Length -gt 1) { $dnsArr[1] } else { "" }
        }
    }
}

$machineInfo = Get-MachineInfo

if (-not $SkipReporting) {
    $sent = Send-ToGoogleSheets -MachineInfo $machineInfo -NetworkInfo $netResult -SecurityInfo $secResult
}

Write-LocalReport -MachineInfo $machineInfo -NetworkInfo $netResult -SecurityInfo $secResult

# ── Bước 5: Cài GitHub Agent ──
$agentInstalled = $false
if (-not $SkipAgent) {
    $agentAlreadyInstalled = $null -ne (Get-ScheduledTask -TaskName $script:AgentTaskName -ErrorAction SilentlyContinue)

    if ($agentAlreadyInstalled) {
        Write-Info "GitHub Agent đã cài trước đó — bỏ qua"
        $agentInstalled = $true
    } elseif (-not $Silent) {
        Write-Host ""
        Write-Host "  ┌─────────────────────────────────────────────────────┐" -ForegroundColor Magenta
        Write-Host "  │  GITHUB AUTO-UPDATE AGENT                           │" -ForegroundColor Magenta
        Write-Host "  │  Máy sẽ tự cập nhật policy qua GitHub mỗi 15 phút  │" -ForegroundColor Magenta
        Write-Host "  │  Cần: GitHub PAT (Fine-grained, Contents: Read)     │" -ForegroundColor Magenta
        Write-Host "  └─────────────────────────────────────────────────────┘" -ForegroundColor Magenta
        Write-Host ""
        $installAgent = Read-Host "  Cài GitHub Agent không? [Y/N]"
        if ($installAgent -match "^[Yy]") {
            $pat = Read-Host "  Nhập GitHub Personal Access Token (ghp_...)"
            if ($pat -match "^(ghp_|github_pat_)") {
                $agentInstalled = Install-GitHubAgent -Token $pat
            } else {
                Write-Warn "Token không đúng định dạng — bỏ qua bước này"
            }
        }
    }
}

# ── Tổng kết ──
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "  ║             HOÀN TẤT - KẾT QUẢ                  ║" -ForegroundColor Green
Write-Host "  ╠══════════════════════════════════════════════════╣" -ForegroundColor Green

if ($isExcluded) {
    Write-Host "  ║  Chặn cài phần mềm : ⏭️  Bỏ qua (Whitelist)         ║" -ForegroundColor DarkYellow
} else {
    $secStatus = if ($secResult.BlockMSI) { "✅ OK                          " } else { "❌ Lỗi                         " }
    Write-Host "  ║  Chặn cài phần mềm : $secStatus║" -ForegroundColor Green
}

$ipDisplay    = if ($netResult.StaticIPSet) { "✅ $($netResult.IPAddress)".PadRight(22) } else { "⚠️  Giữ cấu hình cũ     " }
$sheetDisplay = if ($sent)           { "✅ Thành công           " } else { "⚠️  Xem log local        " }
$agentDisplay = if ($agentInstalled) { "✅ Đang chạy (15 phút)  " } elseif ($SkipAgent) { "⏭️  Bỏ qua               " } else { "⚠️  Chưa cài             " }
Write-Host "  ║  IP Static          : $ipDisplay║" -ForegroundColor Green
Write-Host "  ║  Gửi Google Sheets  : $sheetDisplay║" -ForegroundColor Green
Write-Host "  ║  GitHub Agent       : $agentDisplay║" -ForegroundColor $(if ($agentInstalled) {'Green'} else {'DarkYellow'})
Write-Host "  ╚══════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

if (-not $Silent) {
    Write-Host "  Nhấn Enter để thoát..." -ForegroundColor Gray
    Read-Host | Out-Null
}
