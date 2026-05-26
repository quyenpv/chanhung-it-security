# ================================================================
#  Module-LicenseCheck.ps1
#  Kiểm tra phần mềm có bản quyền hợp lệ hay bị crack
#  Tích hợp vào ChanHung_IT_Setup.ps1 & ChanHung_IT_Install.ps1
#
#  Các lớp kiểm tra:
#    1. Phát hiện tool crack phổ biến (KMSPico, AAct, ...)
#    2. Chữ ký số (Digital Signature) của file .exe
#    3. Kích hoạt Windows & Office
#    4. File nguy hiểm trong thư mục cài đặt
#    5. Registry dấu hiệu crack
#    6. Phần mềm cài từ nguồn không rõ (path bất thường)
# ================================================================

param([switch]$Silent, [switch]$ReportOnly)

#region ─── CONFIG ───────────────────────────────────────────────

$LC = @{
    LogPath      = "C:\ChanHung\Logs\LicenseCheck.log"
    ReportPath   = "C:\ChanHung\Logs\LicenseReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
    SheetWebhook = ""   # Điền webhook nếu muốn gửi Sheets riêng
}

# Tên / pattern các tool crack phổ biến
$KnownCrackTools = @(
    # KMS Activators
    "KMSPico", "KMSAuto", "KMSActivator", "KMS_VL_ALL",
    "AutoKMS", "MiniKMS", "KMSOffline", "KMSELDI",
    "AAct", "AAct Network", "AIO Activator",
    # Windows Loaders
    "Windows Loader", "Windows KMS Activator", "Daz Loader",
    "RemoveWAT", "OEM7F7",
    # Office Crack
    "Office Toolkit", "EZ-Activator", "Office Activator",
    "Microsoft Toolkit", "HWIDGEN", "MAS", "Massgrave",
    # Game / Software crack
    "Keygen", "KeyGen", "Key Generator",
    "Patch.exe", "Crack.exe", "Loader.exe", "Bypass.exe",
    "Serial Finder", "License Bypasser",
    # Adobe crack
    "Adobe Zii", "Adobe GenP", "GenP", "Zii",
    # Antivirus disabler (thường đi kèm crack)
    "Defender Control", "Defender Remover", "Kill Defender",
    "Windows Defender Disabler"
)

# Tên file crack thường gặp trong thư mục cài đặt
$SuspiciousFileNames = @(
    "crack.exe", "keygen.exe", "patch.exe", "loader.exe",
    "activator.exe", "bypass.exe", "unlocker.exe",
    "serial.exe", "registration.exe",
    "crack.dll", "patch.dll",
    "readme-crack.txt", "how to crack.txt", "activation.txt",
    "nfo.txt", "*.nfo"
)

# Registry keys thường để lại bởi KMS activators
$CrackRegistryKeys = @(
    "HKLM:\SOFTWARE\KMSAuto",
    "HKLM:\SOFTWARE\KMSPico",
    "HKLM:\SOFTWARE\AAct",
    "HKCU:\SOFTWARE\KMSAuto",
    "HKCU:\SOFTWARE\KMSPico",
    "HKLM:\SYSTEM\CurrentControlSet\Services\KMSELDI",
    "HKLM:\SYSTEM\CurrentControlSet\Services\KMSAuto"
)

# Path cài đặt bất thường (không phải Program Files / AppData hợp lệ)
$SuspiciousPaths = @(
    "$env:TEMP",
    "$env:USERPROFILE\Downloads",
    "C:\Users\Public",
    "C:\Windows\Temp"
)

# Publisher hợp lệ của các phần mềm phổ biến (whitelist chữ ký)
$TrustedPublishers = @(
    "Microsoft Corporation",
    "Microsoft Windows",
    "Adobe Inc.",
    "Adobe Systems",
    "Google LLC",
    "Mozilla Corporation",
    "Oracle Corporation",
    "Autodesk",
    "Zoom Video Communications",
    "Slack Technologies",
    "JetBrains",
    "VMware",
    "Foxit Software",
    "Nitro Software"
)

#endregion

#region ─── LOGGING ──────────────────────────────────────────────

function Write-LCLog {
    param([string]$Msg, [string]$Level = "INFO")
    $dir = Split-Path $LC.LogPath
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory $dir -Force | Out-Null }
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')][$Level] $Msg"
    Add-Content $LC.LogPath $line -Encoding UTF8
    if (-not $Silent) {
        $col = switch ($Level) {
            "OK"     { "Green" }
            "WARN"   { "Yellow" }
            "CRACK"  { "Red" }
            "INFO"   { "Cyan" }
            default  { "White" }
        }
        Write-Host "    [$Level] $Msg" -ForegroundColor $col
    }
}

#endregion

#region ─── LỚP 1: PHÁT HIỆN TOOL CRACK ─────────────────────────

function Test-CrackToolsInstalled {
    Write-LCLog "--- LỚP 1: Kiểm tra tool crack đã cài ---" "INFO"

    $found = @()

    # Kiểm tra trong registry Uninstall
    $regPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    foreach ($path in $regPaths) {
        $items = Get-ItemProperty $path -ErrorAction SilentlyContinue
        if (-not $items) { continue }
        foreach ($item in @($items)) {
            $name = $item.DisplayName
            if (-not $name) { continue }
            foreach ($crack in $KnownCrackTools) {
                if ($name -like "*$crack*") {
                    $found += [PSCustomObject]@{
                        Name      = $name
                        Type      = "CrackTool"
                        Risk      = "CRACK"
                        Detail    = "Phần mềm crack đã cài: '$name'"
                        InstallPath = $item.InstallLocation
                    }
                    Write-LCLog "PHÁT HIỆN CRACK TOOL: $name" "CRACK"
                }
            }
        }
    }

    # Kiểm tra process đang chạy
    $procs = Get-Process -ErrorAction SilentlyContinue
    foreach ($proc in $procs) {
        foreach ($crack in $KnownCrackTools) {
            if ($proc.ProcessName -like "*$crack*" -or $proc.MainWindowTitle -like "*$crack*") {
                $found += [PSCustomObject]@{
                    Name   = $proc.ProcessName
                    Type   = "CrackProcess"
                    Risk   = "CRACK"
                    Detail = "Process crack đang chạy: '$($proc.ProcessName)'"
                }
                Write-LCLog "CRACK TOOL ĐANG CHẠY: $($proc.ProcessName)" "CRACK"
            }
        }
    }

    # Kiểm tra Task Scheduler (KMS thường tạo task để chạy định kỳ)
    $tasks = Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object {
        $_.TaskName -match "KMS|AAct|Activat|KMSELDI" -and
        $_.TaskName -ne "ChanHung-IT-Agent"
    }
    foreach ($task in $tasks) {
        $found += [PSCustomObject]@{
            Name   = $task.TaskName
            Type   = "CrackScheduledTask"
            Risk   = "CRACK"
            Detail = "Scheduled Task nghi ngờ crack: '$($task.TaskName)'"
        }
        Write-LCLog "TASK CRACK: $($task.TaskName)" "CRACK"
    }

    if ($found.Count -eq 0) { Write-LCLog "Lớp 1 OK — Không phát hiện crack tool" "OK" }
    return $found
}

#endregion

#region ─── LỚP 2: CHỮ KÝ SỐ FILE EXE ──────────────────────────

function Test-DigitalSignatures {
    Write-LCLog "--- LỚP 2: Kiểm tra chữ ký số (Digital Signature) ---" "INFO"

    $results  = @()
    $checked  = 0
    $unsigned = 0
    $invalid  = 0

    # Lấy danh sách exe từ Program Files
    $searchPaths = @(
        "C:\Program Files",
        "C:\Program Files (x86)"
    )

    foreach ($basePath in $searchPaths) {
        if (-not (Test-Path $basePath)) { continue }

        # Chỉ lấy exe ở level 1-2 (không quét sâu quá chậm)
        $exeFiles = Get-ChildItem $basePath -Filter "*.exe" -Recurse -Depth 2 `
            -ErrorAction SilentlyContinue | Select-Object -First 200

        foreach ($exe in $exeFiles) {
            $checked++
            try {
                $sig = Get-AuthenticodeSignature $exe.FullName -ErrorAction Stop

                switch ($sig.Status) {
                    "Valid" {
                        # Kiểm tra publisher có trong trusted list không
                        $publisher = $sig.SignerCertificate.Subject
                        $trusted   = $false
                        foreach ($tp in $TrustedPublishers) {
                            if ($publisher -like "*$tp*") { $trusted = $true; break }
                        }
                        # Không thêm vào kết quả nếu valid — chỉ ghi nếu unknown publisher
                    }
                    "NotSigned" {
                        $unsigned++
                        # Chỉ báo nếu file có tên nghi ngờ
                        $suspicious = $false
                        foreach ($sf in $SuspiciousFileNames) {
                            if ($exe.Name -like $sf) { $suspicious = $true; break }
                        }
                        if ($suspicious) {
                            $results += [PSCustomObject]@{
                                Name   = $exe.Name
                                Type   = "UnsignedSuspicious"
                                Risk   = "WARN"
                                Detail = "File không có chữ ký + tên nghi ngờ: $($exe.FullName)"
                            }
                            Write-LCLog "Không có chữ ký (nghi ngờ): $($exe.Name)" "WARN"
                        }
                    }
                    "HashMismatch" {
                        $invalid++
                        $results += [PSCustomObject]@{
                            Name   = $exe.Name
                            Type   = "TamperedSignature"
                            Risk   = "CRACK"
                            Detail = "Chữ ký bị sửa/patch (hash mismatch): $($exe.FullName)"
                        }
                        Write-LCLog "CHỮ KÝ BỊ PATCH: $($exe.Name) — $($exe.FullName)" "CRACK"
                    }
                    "UnknownError" { }
                    default {
                        # NotTrusted, Incompatible, v.v.
                        if ($sig.Status -ne "UnknownError") {
                            $results += [PSCustomObject]@{
                                Name   = $exe.Name
                                Type   = "InvalidSignature"
                                Risk   = "WARN"
                                Detail = "Chữ ký không hợp lệ ($($sig.Status)): $($exe.FullName)"
                            }
                        }
                    }
                }
            } catch { }
        }
    }

    Write-LCLog "Lớp 2: Kiểm tra $checked file — $invalid chữ ký bị patch — $unsigned không có chữ ký" "INFO"
    if ($invalid -eq 0 -and ($results | Where-Object Risk -eq "CRACK").Count -eq 0) {
        Write-LCLog "Lớp 2 OK — Không phát hiện file bị patch" "OK"
    }
    return $results
}

#endregion

#region ─── LỚP 3: KÍCH HOẠT WINDOWS & OFFICE ───────────────────

function Test-ActivationStatus {
    Write-LCLog "--- LỚP 3: Kiểm tra kích hoạt Windows & Office ---" "INFO"

    $results = @()

    # Windows activation
    try {
        $wmi = Get-WmiObject SoftwareLicensingProduct -ErrorAction Stop |
            Where-Object { $_.Name -like "Windows*" -and $_.PartialProductKey }

        $winStatus = switch ($wmi.LicenseStatus) {
            1       { "Đã kích hoạt hợp lệ" }
            2       { "Đang trong thời gian dùng thử" }
            3       { "Đang trong thời gian gia hạn" }
            4       { "Kênh không hợp lệ" }
            5       { "Đã hết hạn" }
            6       { "Tạm ngưng" }
            default { "Chưa kích hoạt (Status: $($wmi.LicenseStatus))" }
        }

        $winRisk = if ($wmi.LicenseStatus -eq 1) { "OK" } else { "WARN" }
        Write-LCLog "Windows: $winStatus" $winRisk

        if ($wmi.LicenseStatus -ne 1) {
            $results += [PSCustomObject]@{
                Name   = "Windows"
                Type   = "WindowsActivation"
                Risk   = $winRisk
                Detail = "Windows chưa kích hoạt hợp lệ: $winStatus"
            }
        }

        # Kiểm tra KMS server (crack thường dùng KMS local)
        if ($wmi.DiscoveredKeyManagementServiceMachineIpAddress -eq "127.0.0.1" -or
            $wmi.DiscoveredKeyManagementServiceMachineName -match "localhost|127.0.0.1") {
            $results += [PSCustomObject]@{
                Name   = "Windows KMS Local"
                Type   = "KMSLocal"
                Risk   = "CRACK"
                Detail = "Windows kích hoạt qua KMS LOCAL (dấu hiệu crack điển hình!)"
            }
            Write-LCLog "KMS LOCAL PHÁT HIỆN: Windows kích hoạt qua 127.0.0.1!" "CRACK"
        }

    } catch {
        Write-LCLog "Không đọc được trạng thái Windows: $_" "WARN"
    }

    # Office activation
    $officeProducts = @()
    try {
        $officeWmi = Get-WmiObject SoftwareLicensingProduct -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like "Microsoft Office*" -and $_.PartialProductKey }

        foreach ($op in $officeWmi) {
            $officeStatus = switch ($op.LicenseStatus) {
                1       { "OK" }
                default { "WARN" }
            }

            if ($op.LicenseStatus -ne 1) {
                $results += [PSCustomObject]@{
                    Name   = $op.Name
                    Type   = "OfficeActivation"
                    Risk   = "WARN"
                    Detail = "Office chưa kích hoạt: $($op.Name) (Status: $($op.LicenseStatus))"
                }
                Write-LCLog "Office chưa kích hoạt: $($op.Name)" "WARN"
            } else {
                Write-LCLog "Office OK: $($op.Name)" "OK"
            }

            # KMS local cho Office
            if ($op.DiscoveredKeyManagementServiceMachineIpAddress -eq "127.0.0.1") {
                $results += [PSCustomObject]@{
                    Name   = $op.Name
                    Type   = "OfficeKMSLocal"
                    Risk   = "CRACK"
                    Detail = "Office kích hoạt qua KMS LOCAL: $($op.Name)"
                }
                Write-LCLog "OFFICE KMS LOCAL: $($op.Name)" "CRACK"
            }
        }
    } catch { }

    if ($results.Count -eq 0) { Write-LCLog "Lớp 3 OK — Windows & Office kích hoạt hợp lệ" "OK" }
    return $results
}

#endregion

#region ─── LỚP 4: FILE NGUY HIỂM TRONG THƯ MỤC CÀI ĐẶT ────────

function Test-SuspiciousFiles {
    Write-LCLog "--- LỚP 4: Tìm file crack trong thư mục cài đặt ---" "INFO"

    $results    = @()
    $searchDirs = @("C:\Program Files", "C:\Program Files (x86)", $env:APPDATA, $env:LOCALAPPDATA)

    foreach ($dir in $searchDirs) {
        if (-not (Test-Path $dir)) { continue }
        foreach ($pattern in $SuspiciousFileNames) {
            $found = Get-ChildItem $dir -Filter $pattern -Recurse -Depth 3 `
                -ErrorAction SilentlyContinue | Select-Object -First 5
            foreach ($f in $found) {
                $results += [PSCustomObject]@{
                    Name   = $f.Name
                    Type   = "SuspiciousFile"
                    Risk   = "CRACK"
                    Detail = "File crack trong thư mục cài đặt: $($f.FullName)"
                }
                Write-LCLog "FILE CRACK: $($f.FullName)" "CRACK"
            }
        }
    }

    if ($results.Count -eq 0) { Write-LCLog "Lớp 4 OK — Không tìm thấy file crack" "OK" }
    return $results
}

#endregion

#region ─── LỚP 5: REGISTRY DẤU HIỆU CRACK ──────────────────────

function Test-CrackRegistry {
    Write-LCLog "--- LỚP 5: Kiểm tra registry dấu hiệu crack ---" "INFO"

    $results = @()

    foreach ($key in $CrackRegistryKeys) {
        if (Test-Path $key) {
            $results += [PSCustomObject]@{
                Name   = $key
                Type   = "CrackRegistry"
                Risk   = "CRACK"
                Detail = "Registry key của crack tool: $key"
            }
            Write-LCLog "CRACK REGISTRY: $key" "CRACK"
        }
    }

    # Kiểm tra hosts file bị sửa để bypass license (adobe, autodesk, ...)
    $hosts     = Get-Content "C:\Windows\System32\drivers\etc\hosts" -ErrorAction SilentlyContinue
    $hostCrack = @(
        "lm.licenses.adobe.com", "activate.adobe.com",
        "practivate.adobe.com", "ereg.adobe.com",
        "wip.autodesk.com", "register.autodesk.com",
        "activation.cloud.techsmith.com"
    )
    foreach ($line in $hosts) {
        foreach ($domain in $hostCrack) {
            if ($line -match $domain -and $line -notmatch "^#" -and $line -notmatch "ChanHung") {
                $results += [PSCustomObject]@{
                    Name   = $domain
                    Type   = "HostsBlocked"
                    Risk   = "CRACK"
                    Detail = "hosts file chặn domain license: '$line' (dấu hiệu crack Adobe/Autodesk)"
                }
                Write-LCLog "HOSTS FILE CRACK: $line" "CRACK"
            }
        }
    }

    if ($results.Count -eq 0) { Write-LCLog "Lớp 5 OK — Không phát hiện registry crack" "OK" }
    return $results
}

#endregion

#region ─── LỚP 6: PHẦN MỀM CÀI TỪ NGUỒN BẤT THƯỜNG ───────────

function Test-SuspiciousInstallPaths {
    Write-LCLog "--- LỚP 6: Kiểm tra path cài đặt bất thường ---" "INFO"

    $results = @()
    $regPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    foreach ($path in $regPaths) {
        $items = Get-ItemProperty $path -ErrorAction SilentlyContinue
        if (-not $items) { continue }
        foreach ($item in @($items)) {
            $name        = $item.DisplayName
            $installPath = $item.InstallLocation
            if (-not $name -or -not $installPath) { continue }

            foreach ($suspPath in $SuspiciousPaths) {
                if ($installPath -like "$suspPath*") {
                    $results += [PSCustomObject]@{
                        Name   = $name
                        Type   = "SuspiciousInstallPath"
                        Risk   = "WARN"
                        Detail = "Cài từ path bất thường [$name]: $installPath"
                    }
                    Write-LCLog "PATH BẤT THƯỜNG: $name → $installPath" "WARN"
                }
            }
        }
    }

    if ($results.Count -eq 0) { Write-LCLog "Lớp 6 OK — Không phát hiện path bất thường" "OK" }
    return $results
}

#endregion

#region ─── TỔNG HỢP & BÁO CÁO ──────────────────────────────────

function Get-LicenseReport {
    param([array]$AllFindings)

    $crackCount = @($AllFindings | Where-Object Risk -eq "CRACK").Count
    $warnCount  = @($AllFindings | Where-Object Risk -eq "WARN").Count

    $overallRisk = if     ($crackCount -gt 0) { "🔴 CRACK PHÁT HIỆN" }
                  elseif ($warnCount  -gt 0) { "🟡 CẦN KIỂM TRA" }
                  else                        { "🟢 HỢP LỆ" }

    return [PSCustomObject]@{
        Computer     = $env:COMPUTERNAME
        User         = $env:USERNAME
        ScanTime     = (Get-Date -Format "dd/MM/yyyy HH:mm:ss")
        OverallRisk  = $overallRisk
        CrackCount   = $crackCount
        WarnCount    = $warnCount
        Findings     = $AllFindings
    }
}

function Write-LicenseReport {
    param($Report)

    $sep = "=" * 60

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add($sep)
    $lines.Add("  CHẤN HƯNG — BÁO CÁO KIỂM TRA BẢN QUYỀN")
    $lines.Add("  Máy       : $($Report.Computer)")
    $lines.Add("  User      : $($Report.User)")
    $lines.Add("  Thời gian : $($Report.ScanTime)")
    $lines.Add("  Kết quả   : $($Report.OverallRisk)")
    $lines.Add("  Crack     : $($Report.CrackCount) phát hiện  |  Cảnh báo: $($Report.WarnCount)")
    $lines.Add($sep)
    $lines.Add("")

    if ($Report.Findings.Count -eq 0) {
        $lines.Add("  Không phát hiện vấn đề bản quyền.")
    } else {
        $lines.Add("  CHI TIẾT:")
        $lines.Add("")
        foreach ($f in ($Report.Findings | Sort-Object Risk -Descending)) {
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

    if (-not $Silent) {
        Write-Host ""
        Write-Host "  ╔══════════════════════════════════════════════╗" -ForegroundColor $(
            if ($Report.CrackCount -gt 0) { "Red" } elseif ($Report.WarnCount -gt 0) { "Yellow" } else { "Green" })
        Write-Host "  ║  KẾT QUẢ KIỂM TRA BẢN QUYỀN                ║"
        Write-Host "  ║  $($Report.OverallRisk.PadRight(44))║"
        Write-Host "  ║  Crack: $($Report.CrackCount)  |  Cảnh báo: $($Report.WarnCount.ToString().PadRight(24))║"
        Write-Host "  ╚══════════════════════════════════════════════╝"
        Write-Host "  Báo cáo: $($LC.ReportPath)" -ForegroundColor Gray
        Write-Host ""

        if ($Report.Findings.Count -gt 0) {
            Write-Host "  CÁC VẤN ĐỀ PHÁT HIỆN:" -ForegroundColor Yellow
            foreach ($f in ($Report.Findings | Sort-Object Risk -Descending)) {
                $col  = if ($f.Risk -eq "CRACK") { "Red" } else { "Yellow" }
                $icon = if ($f.Risk -eq "CRACK") { "[CRACK]" } else { "[WARN] " }
                Write-Host "    $icon $($f.Detail)" -ForegroundColor $col
            }
            Write-Host ""
        }
    }
}

function Send-LicenseReportToSheets {
    param($Report, [string]$Webhook)

    $url = if ($Webhook) { $Webhook } elseif ($LC.SheetWebhook) { $LC.SheetWebhook } else { $null }
    if (-not $url) { return }

    $payload = @{
        _UpdateType  = "license_check"
        MachineName  = $Report.Computer
        CurrentUser  = $Report.User
        ScanTime     = $Report.ScanTime
        OverallRisk  = $Report.OverallRisk
        CrackCount   = $Report.CrackCount
        WarnCount    = $Report.WarnCount
        Details      = ($Report.Findings | ForEach-Object {
            "$($_.Risk): $($_.Detail)"
        }) -join " | "
    } | ConvertTo-Json -Depth 3 -Compress

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
        Invoke-RestMethod -Uri $url -Method POST -Body $bytes `
            -ContentType "application/json; charset=utf-8" -TimeoutSec 30 -UseBasicParsing | Out-Null
        Write-LCLog "Đã gửi báo cáo lên Google Sheets" "OK"
    } catch {
        Write-LCLog "Gửi Sheets thất bại: $_" "WARN"
    }
}

#endregion

#region ─── MAIN ─────────────────────────────────────────────────

function Invoke-LicenseCheck {
    param(
        [string]$SheetWebhook = "",
        [switch]$SkipSignature,   # Bỏ qua kiểm tra chữ ký (chậm ~30s)
        [switch]$Silent
    )

    if (-not $Silent) {
        Write-Host ""
        Write-Host "  =================================================" -ForegroundColor Cyan
        Write-Host "  KIỂM TRA BẢN QUYỀN PHẦN MỀM" -ForegroundColor Cyan
        Write-Host "  Máy: $env:COMPUTERNAME  |  $(Get-Date -Format 'dd/MM/yyyy HH:mm')" -ForegroundColor White
        Write-Host "  =================================================" -ForegroundColor Cyan
        Write-Host ""
    }

    Write-LCLog "=== BẮT ĐẦU QUÉT: $env:COMPUTERNAME ==="

    $all = @()
    $all += Test-CrackToolsInstalled
    if (-not $SkipSignature) { $all += Test-DigitalSignatures }
    $all += Test-ActivationStatus
    $all += Test-SuspiciousFiles
    $all += Test-CrackRegistry
    $all += Test-SuspiciousInstallPaths

    $report = Get-LicenseReport -AllFindings $all
    Write-LicenseReport -Report $report
    Send-LicenseReportToSheets -Report $report -Webhook $SheetWebhook

    Write-LCLog "=== HOÀN TẤT: $($report.OverallRisk) | Crack=$($report.CrackCount) Warn=$($report.WarnCount) ==="

    return $report
}

# Entry point khi gọi trực tiếp
Invoke-LicenseCheck -Silent:$Silent

#endregion
