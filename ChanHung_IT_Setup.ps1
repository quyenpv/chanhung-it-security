# ============================================================
#  CHẤN HƯNG HOLDING - IT HARDENING & ASSET REGISTRATION
#  Version  : 3.0
#  Mục đích : 1) Chặn tự động cài phần mềm
#             2) Thiết lập IP Static
#             3) Gửi thông tin máy lên Google Sheets
#             4) Kiểm tra bản quyền phần mềm
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
    [switch]$SkipLicenseCheck,       # Bỏ qua kiểm tra bản quyền
    [switch]$Silent                  # Không hỏi, dùng giá trị mặc định / param
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
#  BƯỚC 4: KIỂM TRA BẢN QUYỀN PHẦN MỀM (LICENSE CHECK)
# ─────────────────────────────────────────────────────────────

function Invoke-LicenseCheck {
    Write-Step "BƯỚC 4: Kiểm tra bản quyền phần mềm"

    $LC = @{
        LogPath    = "C:\ChanHung\Logs\LicenseCheck.log"
        ReportPath = "C:\ChanHung\Logs\LicenseReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
    }

    $logDir = Split-Path $LC.LogPath
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory $logDir -Force | Out-Null }

    function Write-LCLog {
        param([string]$Msg, [string]$Level = "INFO")
        $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')][$Level] $Msg"
        Add-Content $LC.LogPath $line -Encoding UTF8
        $col = switch ($Level) {
            "OK"    { "Green" }
            "WARN"  { "Yellow" }
            "CRACK" { "Red" }
            "INFO"  { "Cyan" }
            default { "White" }
        }
        Write-Host "    [$Level] $Msg" -ForegroundColor $col
    }

    function Add-Finding {
        param(
            [System.Collections.Generic.List[object]]$List,
            [string]$Name,
            [string]$Type,
            [string]$Risk,
            [string]$Detail
        )
        $List.Add([PSCustomObject]@{
            Name   = $Name
            Type   = $Type
            Risk   = $Risk
            Detail = $Detail
        }) | Out-Null
    }

    function Test-LocalKmsEndpoint {
        param([string]$Ip, [string]$HostName)
        $ipNorm = if ($Ip) { $Ip.Trim() } else { "" }
        $hostNorm = if ($HostName) { $HostName.Trim().ToLower() } else { "" }
        if ($ipNorm -in @("127.0.0.1", "::1", "0.0.0.0")) { return $true }
        if ($hostNorm -match '^(localhost|127\.0\.0\.1|::1)$') { return $true }
        if ($hostNorm -and ($hostNorm -eq $env:COMPUTERNAME.ToLower())) { return $true }
        return $false
    }

    function Resolve-KmsHostName {
        param([string]$HostName, [string]$SlmgrDlv)
        $hostNorm = if ($HostName) { $HostName.Trim().ToLower() } else { "" }
        if ($hostNorm) { return $hostNorm }
        if ($SlmgrDlv -match '(?im)kms machine name(?: from dns)?:\s*(\S+)') {
            return $Matches[1].Trim().ToLower()
        }
        return ""
    }

    function Get-SuspiciousKmsReason {
        param(
            [string]$HostName,
            [string]$Ip,
            [string]$SlmgrDlv = "",
            [string]$Channel = ""
        )
        $hostNorm = Resolve-KmsHostName -HostName $HostName -SlmgrDlv $SlmgrDlv
        if (-not $hostNorm) { return $null }
        if (Test-LocalKmsEndpoint -Ip $Ip -HostName $hostNorm) { return $null }

        foreach ($blocked in $KnownPirateKmsHosts) {
            $blockedNorm = $blocked.Trim().ToLower()
            if ($hostNorm -eq $blockedNorm -or $hostNorm -like "*.$blockedNorm") {
                return "KMS host crack đã biết: $hostNorm"
            }
        }
        foreach ($pat in $PirateKmsHostPatterns) {
            if ($hostNorm -match $pat) {
                return "KMS host khớp pattern crack: $hostNorm"
            }
        }
        if ($Channel -in @('Retail', 'OEM') -and $hostNorm -notmatch '\.(microsoft|windows)\.com$') {
            return "Kênh $Channel nhưng trỏ KMS bên ngoài ($hostNorm) — không hợp lệ với Retail/OEM"
        }
        return $null
    }

    function Get-SlmgrText {
        param([string[]]$SlmgrArgs)
        $slmgr = Join-Path $env:SystemRoot "System32\slmgr.vbs"
        if (-not (Test-Path $slmgr)) { return $null }
        try {
            return (& cscript.exe //nologo $slmgr @SlmgrArgs 2>&1 | Out-String).Trim()
        } catch { return $null }
    }

    function Get-WindowsChannelFromText {
        param([string]$Description, [string]$LicenseFamily, [string]$SlmgrDlv)
        $blob = "$Description $LicenseFamily $SlmgrDlv".ToUpper()
        if ($blob -match 'VOLUME_MAK|MAK CHANNEL|\bMAK\b') { return "MAK" }
        if ($blob -match 'VOLUME_KMS|KMSCLIENT|KMS CLIENT|\bKMS\b') { return "KMS" }
        if ($blob -match 'RETAIL') { return "Retail" }
        if ($blob -match 'OEM') { return "OEM" }
        if ($blob -match 'GVLK') { return "GVLK" }
        if ($blob -match 'EVAL|TRIAL') { return "Evaluation" }
        if ($LicenseFamily) { return $LicenseFamily }
        return "Unknown"
    }

    function Get-LicenseStatusText {
        param([int]$Status)
        switch ($Status) {
            1 { return "Đã kích hoạt hợp lệ" }
            2 { return "Đang trong thời gian dùng thử" }
            3 { return "Đang trong thời gian gia hạn" }
            4 { return "Kênh không hợp lệ" }
            5 { return "Đã hết hạn" }
            6 { return "Tạm ngưng" }
            default { return "Chưa kích hoạt (Status: $Status)" }
        }
    }

    function Find-OsppScript {
        $roots = @(
            "${env:ProgramFiles}\Microsoft Office",
            "${env:ProgramFiles(x86)}\Microsoft Office"
        )
        foreach ($root in $roots) {
            if (-not (Test-Path $root)) { continue }
            $script = Get-ChildItem $root -Filter "OSPP.VBS" -Recurse -Depth 3 -ErrorAction SilentlyContinue |
                Select-Object -First 1
            if ($script) { return $script.FullName }
        }
        return $null
    }

    function Get-OsppStatusText {
        $ospp = Find-OsppScript
        if (-not $ospp) { return $null }
        try {
            return (& cscript.exe //nologo $ospp /dstatus 2>&1 | Out-String).Trim()
        } catch { return $null }
    }

    function Parse-OsppProducts {
        param([string]$Text)
        if (-not $Text) { return @() }
        $products = [System.Collections.Generic.List[object]]::new()
        $blocks = [regex]::Split($Text, '(?=PRODUCT ID:)')
        foreach ($block in $blocks) {
            if ($block -notmatch 'PRODUCT ID:') { continue }
            $name = if ($block -match 'LICENSE NAME:\s*(.+)') { $Matches[1].Trim() } else { "Microsoft Office" }
            $desc = if ($block -match 'LICENSE DESCRIPTION:\s*(.+)') { $Matches[1].Trim() } else { "" }
            $status = if ($block -match 'LICENSE STATUS:\s*(.+)') { $Matches[1].Trim() } else { "Unknown" }
            $kmsHost = if ($block -match 'KMS machine name:\s*(.+)') { $Matches[1].Trim() } else { "" }
            $kmsIp = if ($block -match 'KMS machine IP address:\s*(.+)') { $Matches[1].Trim() } else { "" }
            $last5 = if ($block -match 'Last 5 characters of installed product key:\s*(.+)') { $Matches[1].Trim() } else { "" }
            $channel = Get-WindowsChannelFromText -Description $desc -LicenseFamily "" -SlmgrDlv ""
            $licensed = ($status -match '^---LICENSED---$|^LICENSED$')
            $products.Add([PSCustomObject]@{
                Name          = $name
                Description   = $desc
                Channel       = $channel
                LicenseStatus = $status
                Licensed      = $licensed
                PartialKey    = $last5
                KmsServer     = if ($kmsHost) { $kmsHost } else { $kmsIp }
                KmsIp         = $kmsIp
            }) | Out-Null
        }
        return @($products)
    }

    $KnownCrackTools = @(
        "KMSPico", "KMSAuto", "KMSActivator", "KMS_VL_ALL",
        "AutoKMS", "MiniKMS", "KMSOffline", "KMSELDI",
        "AAct", "AAct Network", "AIO Activator",
        "Windows Loader", "Windows KMS Activator", "Daz Loader",
        "RemoveWAT", "OEM7F7",
        "Office Toolkit", "EZ-Activator", "Office Activator",
        "Microsoft Toolkit", "HWIDGEN", "MAS", "Massgrave",
        "Keygen", "KeyGen", "Key Generator",
        "Patch.exe", "Crack.exe", "Loader.exe", "Bypass.exe",
        "Serial Finder", "License Bypasser",
        "Adobe Zii", "Adobe GenP", "GenP", "Zii",
        "Defender Control", "Defender Remover", "Kill Defender"
    )

    $SuspiciousFileNames = @(
        "crack.exe", "keygen.exe", "patch.exe", "loader.exe",
        "activator.exe", "bypass.exe", "unlocker.exe",
        "serial.exe", "registration.exe",
        "crack.dll", "patch.dll"
    )

    $KnownPirateKmsHosts = @(
        "kms.loli.best",
        "kms.digiboy.ir",
        "kms.chinancce.com",
        "kms8.msoffice365.com",
        "kms.srv.crsoo.com",
        "kms.03k.org",
        "kms.luody.info",
        "zhuxiaole.com",
        "kmscat.com"
    )
    $PirateKmsHostPatterns = @(
        '(?i)(^|\.)loli\.best$',
        '(?i)(^|\.)digiboy\.ir$',
        '(?i)(kmspico|kmsauto|massgrave|hwid\.|nvl\.app|kms\.srv)',
        '(?i)^kms[0-9]*\.(pub|pi|lol|best|info|org|net|cn|cc)$'
    )

    $CrackRegistryKeys = @(
        "HKLM:\SOFTWARE\KMSAuto",
        "HKLM:\SOFTWARE\KMSPico",
        "HKLM:\SOFTWARE\AAct",
        "HKCU:\SOFTWARE\KMSAuto",
        "HKCU:\SOFTWARE\KMSPico",
        "HKLM:\SYSTEM\CurrentControlSet\Services\KMSELDI",
        "HKLM:\SYSTEM\CurrentControlSet\Services\KMSAuto"
    )

    $MasMarkers = @(
        "C:\MAS",
        "C:\Microsoft Activation Scripts",
        "$env:USERPROFILE\Downloads\MAS"
    )

    $findings = [System.Collections.Generic.List[object]]::new()

    # ── Lớp 1: Tool / process / task crack ──
    Write-LCLog "--- LỚP 1: Kiểm tra tool crack đã cài ---" "INFO"
    $uninstallPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    foreach ($path in $uninstallPaths) {
        $items = Get-ItemProperty $path -ErrorAction SilentlyContinue
        if (-not $items) { continue }
        foreach ($item in @($items)) {
            $name = Get-RegProp $item 'DisplayName'
            if (-not $name) { continue }
            foreach ($crack in $KnownCrackTools) {
                if ($name -like "*$crack*") {
                    Add-Finding $findings $name "CrackTool" "CRACK" "Phần mềm crack đã cài: '$name'"
                    Write-LCLog "PHÁT HIỆN CRACK TOOL: $name" "CRACK"
                }
            }
        }
    }

    foreach ($proc in @(Get-Process -ErrorAction SilentlyContinue)) {
        foreach ($crack in $KnownCrackTools) {
            if ($proc.ProcessName -like "*$crack*" -or $proc.MainWindowTitle -like "*$crack*") {
                Add-Finding $findings $proc.ProcessName "CrackProcess" "CRACK" "Process crack đang chạy: '$($proc.ProcessName)'"
                Write-LCLog "CRACK TOOL ĐANG CHẠY: $($proc.ProcessName)" "CRACK"
            }
        }
    }

    foreach ($task in @(Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object {
        $_.TaskName -match 'KMS|AAct|Activat|KMSELDI|HWID|Massgrave|Microsoft Activation Scripts' -and
        $_.TaskName -ne "ChanHung-IT-Agent"
    })) {
        $taskType = if ($task.TaskName -match 'HWID|Massgrave|Activation Scripts') { "MasScheduledTask" } else { "CrackScheduledTask" }
        Add-Finding $findings $task.TaskName $taskType "CRACK" "Scheduled Task nghi ngờ crack/activator: '$($task.TaskName)'"
        Write-LCLog "TASK CRACK: $($task.TaskName)" "CRACK"
    }

    foreach ($marker in $MasMarkers) {
        if (Test-Path $marker) {
            Add-Finding $findings $marker "MasFolder" "CRACK" "Thư mục MAS/HWID activator: $marker"
            Write-LCLog "MAS/HWID MARKER: $marker" "CRACK"
        }
    }

    if (@($findings | Where-Object { $_.Type -in @("CrackTool","CrackProcess","CrackScheduledTask","MasScheduledTask","MasFolder") }).Count -eq 0) {
        Write-LCLog "Lớp 1 OK — Không phát hiện crack tool" "OK"
    }

    # ── Lớp 2: Registry / hosts / file crack ──
    Write-LCLog "--- LỚP 2: Registry, hosts & file dấu hiệu crack ---" "INFO"
    foreach ($key in $CrackRegistryKeys) {
        if (Test-Path $key) {
            Add-Finding $findings $key "CrackRegistry" "CRACK" "Registry key của crack tool: $key"
            Write-LCLog "CRACK REGISTRY: $key" "CRACK"
        }
    }

    $hostsLines = @(Get-Content "C:\Windows\System32\drivers\etc\hosts" -ErrorAction SilentlyContinue)
    $hostCrackDomains = @(
        "lm.licenses.adobe.com", "activate.adobe.com",
        "practivate.adobe.com", "ereg.adobe.com",
        "wip.autodesk.com", "register.autodesk.com"
    )
    foreach ($line in $hostsLines) {
        foreach ($domain in $hostCrackDomains) {
            if ($line -match [regex]::Escape($domain) -and $line -notmatch '^\s*#') {
                Add-Finding $findings $domain "HostsBlocked" "CRACK" "hosts file chặn domain license: '$line'"
                Write-LCLog "HOSTS FILE CRACK: $line" "CRACK"
            }
        }
    }

    foreach ($pattern in $SuspiciousFileNames) {
        foreach ($dir in @("C:\Program Files", "C:\Program Files (x86)", $env:APPDATA)) {
            if (-not (Test-Path $dir)) { continue }
            foreach ($f in @(Get-ChildItem $dir -Filter $pattern -Recurse -Depth 2 -ErrorAction SilentlyContinue | Select-Object -First 3)) {
                Add-Finding $findings $f.Name "SuspiciousFile" "CRACK" "File crack trong thư mục cài đặt: $($f.FullName)"
                Write-LCLog "FILE CRACK: $($f.FullName)" "CRACK"
            }
        }
    }

    # ── Lớp 3: Windows activation (WMI + slmgr + SPP registry) ──
    Write-LCLog "--- LỚP 3: Phân tích bản quyền Windows ---" "INFO"

    $slmgrDlv = Get-SlmgrText @("/dlv")
    $slmgrXpr = Get-SlmgrText @("/xpr")
    if ($slmgrDlv) { Write-LCLog "slmgr /dlv: đã thu thập" "INFO" }
    if ($slmgrXpr) { Write-LCLog "slmgr /xpr: $slmgrXpr" "INFO" }

    $winProduct = $null
    try {
        [array]$winCandidates = @(Get-CimInstance -ClassName SoftwareLicensingProduct -ErrorAction Stop |
            Where-Object { $_.Name -like "Windows*" -and $_.PartialProductKey })
        if ($winCandidates.Length -gt 0) {
            $winProduct = $winCandidates | Sort-Object {
                if ($_.LicenseStatus -eq 1) { 0 } else { 1 }
            } | Select-Object -First 1
        }
    } catch {
        Write-LCLog "Không đọc được WMI Windows: $_" "WARN"
    }

    $sppReg = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform" `
        -ErrorAction SilentlyContinue
    $sppKmsName = if ($sppReg) { Get-RegProp $sppReg 'KeyManagementServiceName' } else { "" }
    $sppKmsPort = if ($sppReg) { Get-RegProp $sppReg 'KeyManagementServiceListeningPort' } else { "" }

    $winChannel = "Unknown"
    $winStatusCode = 0
    $winStatusText = "Không xác định"
    $winKmsServer = ""
    $winKmsIp = ""
    $winGenuine = $false
    $winReason = "Không đọc được trạng thái Windows"

    if ($winProduct) {
        $winStatusCode = [int]$winProduct.LicenseStatus
        $winStatusText = Get-LicenseStatusText $winStatusCode
        $winChannel = Get-WindowsChannelFromText `
            -Description $winProduct.Description `
            -LicenseFamily $winProduct.LicenseFamily `
            -SlmgrDlv $slmgrDlv
        $winKmsServer = [string]$winProduct.DiscoveredKeyManagementServiceMachineName
        $winKmsIp = [string]$winProduct.DiscoveredKeyManagementServiceMachineIpAddress
        if (-not $winKmsServer -and $sppKmsName) { $winKmsServer = $sppKmsName }
        if (-not $winKmsServer) {
            $winKmsServer = Resolve-KmsHostName -HostName "" -SlmgrDlv $slmgrDlv
        }

        Write-LCLog "Windows: $winStatusText | Kênh: $winChannel | KMS: $(if ($winKmsServer) { $winKmsServer } else { 'N/A' })" `
            $(if ($winStatusCode -eq 1) { "OK" } else { "WARN" })

        $localKms = Test-LocalKmsEndpoint -Ip $winKmsIp -HostName $winKmsServer
        if ($localKms) {
            Add-Finding $findings "Windows KMS Local" "KMSLocal" "CRACK" `
                "Windows kích hoạt qua KMS LOCAL ($winKmsServer / $winKmsIp) — dấu hiệu crack điển hình"
            Write-LCLog "KMS LOCAL PHÁT HIỆN: Windows → $winKmsServer ($winKmsIp)" "CRACK"
        }

        $pirateKmsReason = Get-SuspiciousKmsReason -HostName $winKmsServer -Ip $winKmsIp `
            -SlmgrDlv $slmgrDlv -Channel $winChannel
        $pirateKms = [bool]$pirateKmsReason
        if ($pirateKms) {
            Add-Finding $findings "Windows KMS Remote" "PirateKms" "CRACK" `
                "Windows trỏ KMS crack/ngoài chuẩn: $pirateKmsReason"
            Write-LCLog "KMS CRACK/PIRATE: $winKmsServer — $pirateKmsReason" "CRACK"
        }

        if ($winStatusCode -eq 4) {
            Add-Finding $findings "Windows" "InvalidChannel" "CRACK" "Windows báo kênh không hợp lệ (LicenseStatus=4)"
            Write-LCLog "KÊNH KHÔNG HỢP LỆ: Windows LicenseStatus=4" "CRACK"
        } elseif ($winStatusCode -ne 1) {
            Add-Finding $findings "Windows" "WindowsActivation" "WARN" "Windows chưa kích hoạt hợp lệ: $winStatusText"
        }

        if ($winChannel -eq "KMS" -and -not $localKms -and -not $pirateKms -and $winStatusCode -eq 1) {
            Write-LCLog "KMS doanh nghiệp hợp lệ: $winKmsServer" "OK"
        }

        if ($slmgrXpr -match 'permanently activated|activated permanently|kích hoạt vĩnh viễn') {
            $winReason = "slmgr /xpr: kích hoạt vĩnh viễn"
        } elseif ($slmgrXpr -match 'will expire|hết hạn') {
            $winReason = "slmgr /xpr: kích hoạt tạm thời — $slmgrXpr"
            if ($winStatusCode -eq 1 -and $localKms) {
                Add-Finding $findings "Windows" "KmsExpiry" "CRACK" "Windows KMS tạm thời qua localhost: $slmgrXpr"
            }
        }

        $hasCrackSignal = @($findings | Where-Object {
            $_.Risk -eq "CRACK" -and $_.Type -match 'KMSLocal|PirateKms|InvalidChannel|CrackTool|CrackRegistry|Mas'
        }).Count -gt 0

        if ($winStatusCode -eq 1 -and -not $hasCrackSignal -and -not $localKms -and -not $pirateKms) {
            $winGenuine = $true
            if (-not $winReason) {
                $winReason = switch ($winChannel) {
                    "Retail" { "Retail/OEM — LicenseStatus=1, không có dấu hiệu crack" }
                    "OEM"    { "OEM — LicenseStatus=1, không có dấu hiệu crack" }
                    "MAK"    { "MAK Volume — LicenseStatus=1" }
                    "KMS"    { "KMS doanh nghiệp ($winKmsServer) — LicenseStatus=1" }
                    default  { "LicenseStatus=1, kênh $winChannel" }
                }
            }
        } elseif ($localKms -or $pirateKms -or $hasCrackSignal) {
            $winGenuine = $false
            $winReason = if ($pirateKmsReason) { $pirateKmsReason } else { "Nghi crack/KMS emulator — $winStatusText" }
        } elseif ($winStatusCode -ne 1) {
            $winGenuine = $false
            $winReason = $winStatusText
        } else {
            $winGenuine = $false
            $winReason = "Cần xem xét thêm — $winStatusText"
        }
    }

    # ── Lớp 4: Office activation (WMI + ospp.vbs) ──
    Write-LCLog "--- LỚP 4: Phân tích bản quyền Office ---" "INFO"

    $osppText = Get-OsppStatusText
    $osppProducts = Parse-OsppProducts $osppText
    $officeResults = [System.Collections.Generic.List[object]]::new()

    if ($osppProducts.Count -gt 0) {
        Write-LCLog "ospp.vbs: phát hiện $($osppProducts.Count) sản phẩm Office" "INFO"
    } else {
        Write-LCLog "ospp.vbs: không có Office hoặc không đọc được" "INFO"
    }

    try {
        [array]$officeWmi = @(Get-CimInstance -ClassName SoftwareLicensingProduct -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like "Microsoft Office*" -and $_.PartialProductKey })
    } catch { [array]$officeWmi = @() }

    if ($officeWmi.Length -gt 0 -and $osppProducts.Count -eq 0) {
        foreach ($op in $officeWmi) {
            $kmsHost = [string]$op.DiscoveredKeyManagementServiceMachineName
            $kmsIp = [string]$op.DiscoveredKeyManagementServiceMachineIpAddress
            $localKms = Test-LocalKmsEndpoint -Ip $kmsIp -HostName $kmsHost
            $channel = Get-WindowsChannelFromText -Description $op.Description -LicenseFamily $op.LicenseFamily -SlmgrDlv ""
            $pirateKmsReason = Get-SuspiciousKmsReason -HostName $kmsHost -Ip $kmsIp -Channel $channel
            $pirateKms = [bool]$pirateKmsReason
            $licensed = ($op.LicenseStatus -eq 1)
            $genuine = $licensed -and -not $localKms -and -not $pirateKms
            $reason = if ($localKms) { "Office KMS LOCAL — nghi crack" }
                     elseif ($pirateKmsReason) { $pirateKmsReason }
                     elseif ($licensed) { "LicenseStatus=1" }
                     else { Get-LicenseStatusText ([int]$op.LicenseStatus) }

            $officeResults.Add([PSCustomObject]@{
                Name          = $op.Name
                Channel       = $channel
                Licensed      = $licensed
                Genuine       = $genuine
                Reason        = $reason
                LicenseStatus = Get-LicenseStatusText ([int]$op.LicenseStatus)
                KmsServer     = $kmsHost
            }) | Out-Null

            if ($localKms) {
                Add-Finding $findings $op.Name "OfficeKMSLocal" "CRACK" "Office kích hoạt qua KMS LOCAL: $($op.Name)"
                Write-LCLog "OFFICE KMS LOCAL: $($op.Name)" "CRACK"
            } elseif ($pirateKms) {
                Add-Finding $findings $op.Name "OfficePirateKms" "CRACK" "Office KMS crack/ngoài chuẩn: $($op.Name) — $pirateKmsReason"
                Write-LCLog "OFFICE KMS CRACK: $($op.Name) — $pirateKmsReason" "CRACK"
            } elseif (-not $licensed) {
                Add-Finding $findings $op.Name "OfficeActivation" "WARN" "Office chưa kích hoạt: $($op.Name)"
                Write-LCLog "Office chưa kích hoạt: $($op.Name)" "WARN"
            } else {
                Write-LCLog "Office OK: $($op.Name)" "OK"
            }
        }
    } else {
        foreach ($op in $osppProducts) {
            $localKms = Test-LocalKmsEndpoint -Ip $op.KmsIp -HostName $op.KmsServer
            $pirateKmsReason = Get-SuspiciousKmsReason -HostName $op.KmsServer -Ip $op.KmsIp -Channel $op.Channel
            $pirateKms = [bool]$pirateKmsReason
            $genuine = $op.Licensed -and -not $localKms -and -not $pirateKms
            $reason = if ($localKms) { "Office KMS LOCAL — nghi crack" }
                     elseif ($pirateKmsReason) { $pirateKmsReason }
                     elseif ($op.Licensed) { "ospp: LICENSED" }
                     else { $op.LicenseStatus }

            $officeResults.Add([PSCustomObject]@{
                Name          = $op.Name
                Channel       = $op.Channel
                Licensed      = $op.Licensed
                Genuine       = $genuine
                Reason        = $reason
                LicenseStatus = $op.LicenseStatus
                KmsServer     = $op.KmsServer
            }) | Out-Null

            if ($localKms) {
                Add-Finding $findings $op.Name "OfficeKMSLocal" "CRACK" "Office kích hoạt qua KMS LOCAL: $($op.Name)"
                Write-LCLog "OFFICE KMS LOCAL: $($op.Name)" "CRACK"
            } elseif ($pirateKms) {
                Add-Finding $findings $op.Name "OfficePirateKms" "CRACK" "Office KMS crack/ngoài chuẩn: $($op.Name) — $pirateKmsReason"
                Write-LCLog "OFFICE KMS CRACK: $($op.Name) — $pirateKmsReason" "CRACK"
            } elseif (-not $op.Licensed) {
                Add-Finding $findings $op.Name "OfficeActivation" "WARN" "Office chưa kích hoạt: $($op.Name) ($($op.LicenseStatus))"
                Write-LCLog "Office chưa kích hoạt: $($op.Name)" "WARN"
            } else {
                Write-LCLog "Office OK: $($op.Name)" "OK"
            }
        }
    }

    # ── Tổng hợp verdict ──
    $allFindings = @($findings)
    $crackCount = @($allFindings | Where-Object Risk -eq "CRACK").Count
    $warnCount  = @($allFindings | Where-Object Risk -eq "WARN").Count

    $officeInstalled = $officeResults.Count -gt 0
    $officeAllGenuine = (-not $officeInstalled) -or (@($officeResults | Where-Object { -not $_.Genuine }).Count -eq 0)

    $overallVerdict = if ($crackCount -gt 0) { "CRACK_SUSPECTED" }
                      elseif ($winGenuine -and $officeAllGenuine) { "LICENSED" }
                      elseif (-not $winGenuine -and $crackCount -eq 0 -and $winStatusCode -in @(0, 2, 5, 6)) { "UNLICENSED" }
                      elseif (-not $winGenuine -or -not $officeAllGenuine) { "NEEDS_REVIEW" }
                      else { "NEEDS_REVIEW" }

    $overallRisk = switch ($overallVerdict) {
        "LICENSED"        { "🟢 HỢP LỆ" }
        "CRACK_SUSPECTED" { "🔴 CRACK PHÁT HIỆN" }
        "UNLICENSED"      { "🟡 CHƯA KÍCH HOẠT" }
        default           { "🟡 CẦN KIỂM TRA" }
    }

    $report = [PSCustomObject]@{
        Computer            = $env:COMPUTERNAME
        User                = $env:USERNAME
        ScanTime            = (Get-Date -Format "dd/MM/yyyy HH:mm:ss")
        OverallVerdict      = $overallVerdict
        OverallRisk         = $overallRisk
        CrackCount          = $crackCount
        WarnCount           = $warnCount
        WindowsChannel      = $winChannel
        WindowsGenuine      = $winGenuine
        WindowsGenuineReason= $winReason
        WindowsLicenseStatus= $winStatusText
        WindowsKmsServer    = $winKmsServer
        OfficeProducts      = @($officeResults)
        Findings            = $allFindings
    }

    # ── Lưu báo cáo ──
    $sep = "=" * 60
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add($sep)
    $lines.Add("  CHẤN HƯNG — BÁO CÁO KIỂM TRA BẢN QUYỀN")
    $lines.Add("  Máy       : $($report.Computer)")
    $lines.Add("  User      : $($report.User)")
    $lines.Add("  Thời gian : $($report.ScanTime)")
    $lines.Add("  Verdict   : $($report.OverallVerdict)")
    $lines.Add("  Kết quả   : $($report.OverallRisk)")
    $lines.Add("  Windows   : $($report.WindowsChannel) | Genuine=$($report.WindowsGenuine) | $($report.WindowsGenuineReason)")
    $lines.Add("  Crack     : $($report.CrackCount) phát hiện  |  Cảnh báo: $($report.WarnCount)")
    $lines.Add($sep)
    $lines.Add("")

    if ($report.OfficeProducts.Count -gt 0) {
        $lines.Add("  OFFICE:")
        foreach ($op in $report.OfficeProducts) {
            $lines.Add("    - $($op.Name) | $($op.Channel) | Licensed=$($op.Licensed) | Genuine=$($op.Genuine)")
        }
        $lines.Add("")
    }

    if ($report.Findings.Count -eq 0) {
        $lines.Add("  Không phát hiện vấn đề bản quyền.")
    } else {
        $lines.Add("  CHI TIẾT:")
        $lines.Add("")
        foreach ($f in ($report.Findings | Sort-Object Risk -Descending)) {
            $icon = switch ($f.Risk) {
                "CRACK" { "[CRACK]" }
                "WARN"  { "[WARN] " }
                default { "[INFO] " }
            }
            $lines.Add("  $icon $($f.Detail)")
        }
    }

    $lines.Add("")
    $lines.Add($sep)
    $lines | Out-File $LC.ReportPath -Encoding UTF8 -Force

    $boxColor = switch ($report.OverallVerdict) {
        "CRACK_SUSPECTED" { "Red" }
        "LICENSED"        { "Green" }
        default           { "Yellow" }
    }

    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════╗" -ForegroundColor $boxColor
    Write-Host "  ║  KẾT QUẢ KIỂM TRA BẢN QUYỀN                ║"
    Write-Host "  ║  $($report.OverallRisk.PadRight(44))║"
    Write-Host "  ║  Verdict: $($report.OverallVerdict.PadRight(36))║"
    Write-Host "  ║  Windows: $($report.WindowsChannel) | Genuine=$($report.WindowsGenuine.ToString().PadRight(15))║"
    Write-Host "  ║  Crack: $($report.CrackCount)  |  Cảnh báo: $($report.WarnCount.ToString().PadRight(24))║"
    Write-Host "  ╚══════════════════════════════════════════════╝"
    Write-Host "  Báo cáo: $($LC.ReportPath)" -ForegroundColor Gray
    Write-Host ""

    if ($report.Findings.Count -gt 0) {
        Write-Host "  CÁC VẤN ĐỀ PHÁT HIỆN:" -ForegroundColor Yellow
        foreach ($f in ($report.Findings | Sort-Object Risk -Descending)) {
            $col  = if ($f.Risk -eq "CRACK") { "Red" } else { "Yellow" }
            $icon = if ($f.Risk -eq "CRACK") { "[CRACK]" } else { "[WARN] " }
            Write-Host "    $icon $($f.Detail)" -ForegroundColor $col
        }
        Write-Host ""
    }

    Write-LCLog "=== HOÀN TẤT: $($report.OverallVerdict) | $($report.OverallRisk) | Crack=$($report.CrackCount) Warn=$($report.WarnCount) ==="

    return $report
}

# ─────────────────────────────────────────────────────────────
#  BƯỚC 5: GỬI DỮ LIỆU LÊN GOOGLE SHEETS
# ─────────────────────────────────────────────────────────────

function Send-ToGoogleSheets {
    param(
        [hashtable]$MachineInfo,
        [hashtable]$NetworkInfo,
        [hashtable]$SecurityInfo
    )

    Write-Step "BƯỚC 5: Gửi báo cáo lên Google Sheets"

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
#  BƯỚC 6: TẠO BÁO CÁO LOCAL
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
#  CHƯƠNG TRÌNH CHÍNH
# ─────────────────────────────────────────────────────────────

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
    if (-not $SkipLicenseCheck)  { Write-Host "    [3] Kiểm tra bản quyền phần mềm" -ForegroundColor White }
    if (-not $SkipReporting)     { Write-Host "    [4] Gửi báo cáo lên Google Sheets" -ForegroundColor White }
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

# ── Bước 4: Kiểm tra bản quyền ──
$licenseResult = $null
if (-not $SkipLicenseCheck) {
    $licenseResult = Invoke-LicenseCheck
}

if (-not $SkipReporting) {
    $sent = Send-ToGoogleSheets -MachineInfo $machineInfo -NetworkInfo $netResult -SecurityInfo $secResult
}

Write-LocalReport -MachineInfo $machineInfo -NetworkInfo $netResult -SecurityInfo $secResult

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
$licenseDisplay = if ($licenseResult) {
    switch ($licenseResult.OverallVerdict) {
        "LICENSED"        { "✅ Licensed              " }
        "CRACK_SUSPECTED" { "🔴 Crack suspected       " }
        "UNLICENSED"      { "🟡 Chưa kích hoạt       " }
        default           { "🟡 Cần kiểm tra          " }
    }
} elseif ($SkipLicenseCheck) { "⏭️  Bỏ qua                   " } else { "⚠️  Chưa kiểm tra           " }
$sheetDisplay = if ($sent)           { "✅ Thành công           " } else { "⚠️  Xem log local        " }
Write-Host "  ║  IP Static          : $ipDisplay║" -ForegroundColor Green
Write-Host "  ║  Kiểm tra bản quyền : $licenseDisplay║" -ForegroundColor $(if ($licenseResult) { switch ($licenseResult.OverallVerdict) { 'CRACK_SUSPECTED' {'Red'} 'LICENSED' {'Green'} default {'Yellow'} } } else { 'Green' })
Write-Host "  ║  Gửi Google Sheets  : $sheetDisplay║" -ForegroundColor Green
Write-Host "  ╚══════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

if (-not $Silent) {
    Write-Host "  Nhấn Enter để thoát..." -ForegroundColor Gray
    Read-Host | Out-Null
}
