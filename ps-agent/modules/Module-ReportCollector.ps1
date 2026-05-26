# ================================================================
#  Module-ReportCollector.ps1
#  Thu thập báo cáo từ các máy client về máy chủ
#  Gửi kết quả LicenseCheck về central server
# ================================================================

param([switch]$Silent)

#region ─── CONFIG ───────────────────────────────────────────────

$RC = @{
    LogPath        = "C:\ChanHung\Logs\ReportCollector.log"
    CentralServer  = "\\SERVER\ChanHung\Reports"  # Thay bằng server path
    ReportTypes    = @("LicenseCheck", "ITHardening")
    RetentionDays  = 30
}

#endregion

#region ─── LOGGING ──────────────────────────────────────────────

function Write-RCLog {
    param([string]$Msg, [string]$Level = "INFO")
    $dir = Split-Path $RC.LogPath
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory $dir -Force | Out-Null }
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')][$Level] $Msg"
    Add-Content $RC.LogPath $line -Encoding UTF8
    if (-not $Silent) {
        $col = switch ($Level) {
            "OK"     { "Green" }
            "WARN"   { "Yellow" }
            "ERROR"  { "Red" }
            "INFO"   { "Cyan" }
            default  { "White" }
        }
        Write-Host "    [$Level] $Msg" -ForegroundColor $col
    }
}

#endregion

#region ─── COLLECT REPORTS ───────────────────────────────────────

function Collect-LocalReports {
    Write-RCLog "--- Thu thập báo cáo local ---" "INFO"
    
    $reports = @()
    
    # Thu thập LicenseCheck reports
    $licenseReports = Get-ChildItem "C:\ChanHung\Logs\LicenseReport_*.txt" -ErrorAction SilentlyContinue
    foreach ($report in $licenseReports) {
        $content = Get-Content $report.FullName -Raw
        $reports += [PSCustomObject]@{
            Type      = "LicenseCheck"
            Machine   = $env:COMPUTERNAME
            User      = $env:USERNAME
            Timestamp = $report.LastWriteTime
            Content   = $content
            FilePath  = $report.FullName
        }
        Write-RCLog "Thu thập: $($report.Name)" "INFO"
    }
    
    # Thu thập IT Hardening reports (nếu có)
    $itReports = Get-ChildItem "C:\ChanHung\Logs\ITHardening_*.txt" -ErrorAction SilentlyContinue
    foreach ($report in $itReports) {
        $content = Get-Content $report.FullName -Raw
        $reports += [PSCustomObject]@{
            Type      = "ITHardening"
            Machine   = $env:COMPUTERNAME
            User      = $env:USERNAME
            Timestamp = $report.LastWriteTime
            Content   = $content
            FilePath  = $report.FullName
        }
        Write-RCLog "Thu thập: $($report.Name)" "INFO"
    }
    
    Write-RCLog "Đã thu thập $($reports.Count) báo cáo" "OK"
    return $reports
}

function Send-ReportsToCentral {
    param([array]$Reports)
    
    if (-not $Reports) { return }
    
    Write-RCLog "--- Gửi báo cáo về central server ---" "INFO"
    
    # Tạo thư mục trên central server
    $machineDir = Join-Path $RC.CentralServer $env:COMPUTERNAME
    if (-not (Test-Path $machineDir)) {
        try {
            New-Item -ItemType Directory $machineDir -Force | Out-Null
            Write-RCLog "Đã tạo thư mục: $machineDir" "OK"
        } catch {
            Write-RCLog "Không thể tạo thư mục trên server: $_" "ERROR"
            return
        }
    }
    
    # Copy báo cáo
    $sent = 0
    foreach ($report in $Reports) {
        try {
            $destFile = Join-Path $machineDir "$($report.Type)_$($report.Timestamp.ToString('yyyyMMdd_HHmmss')).txt"
            Copy-Item $report.FilePath $destFile -Force
            $sent++
            Write-RCLog "Đã gửi: $($report.Type)" "OK"
        } catch {
            Write-RCLog "Lỗi gửi báo cáo: $_" "ERROR"
        }
    }
    
    Write-RCLog "Đã gửi $sent/$($Reports.Count) báo cáo" "OK"
}

function Cleanup-OldReports {
    Write-RCLog "--- Dọn dẹp báo cáo cũ ---" "INFO"
    
    $cutoff = (Get-Date).AddDays(-$RC.RetentionDays)
    
    # Xóa báo cáo local cũ
    $oldReports = Get-ChildItem "C:\ChanHung\Logs\*.txt" -ErrorAction SilentlyContinue | 
        Where-Object { $_.LastWriteTime -lt $cutoff }
    
    foreach ($report in $oldReports) {
        try {
            Remove-Item $report.FullName -Force
            Write-RCLog "Đã xóa: $($report.Name)" "INFO"
        } catch {
            Write-RCLog "Lỗi xóa: $($report.Name)" "WARN"
        }
    }
    
    Write-RCLog "Đã xóa $($oldReports.Count) báo cáo cũ" "OK"
}

#endregion

#region ─── MAIN ─────────────────────────────────────────────────

function Invoke-ReportCollector {
    if (-not $Silent) {
        Write-Host ""
        Write-Host "  =================================================" -ForegroundColor Cyan
        Write-Host "  THU THẬP BÁO CÁO TỪ CLIENT" -ForegroundColor Cyan
        Write-Host "  Máy: $env:COMPUTERNAME  |  $(Get-Date -Format 'dd/MM/yyyy HH:mm')" -ForegroundColor White
        Write-Host "  =================================================" -ForegroundColor Cyan
        Write-Host ""
    }
    
    Write-RCLog "=== BẮT ĐẦU THU THẬP: $env:COMPUTERNAME ==="
    
    $reports = Collect-LocalReports
    Send-ReportsToCentral -Reports $reports
    Cleanup-OldReports
    
    Write-RCLog "=== HOÀN TẤT THU THẬP ==="
    
    if (-not $Silent) {
        Write-Host ""
        Write-Host "  Đã thu thập và gửi báo cáo thành công" -ForegroundColor Green
        Write-Host "  Central Server: $RC.CentralServer" -ForegroundColor Gray
        Write-Host ""
    }
}

# Entry point
Invoke-ReportCollector

#endregion
