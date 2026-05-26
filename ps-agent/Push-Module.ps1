# ============================================================
#  CHẤN HƯNG HOLDING - PUSH MODULE TO GITHUB
#  Version: 1.0
#  Mục đích: Push module mới hoặc gửi lệnh đến ps-agent repository
#  Yêu cầu: GitHub PAT với quyền Contents: Read/Write
# ============================================================

[CmdletBinding()]
param(
    [Parameter(ParameterSetName="PushModule")]
    [string]$Module,
    
    [Parameter(ParameterSetName="PushModule")]
    [switch]$AutoRun,
    
    [Parameter(ParameterSetName="SendCommand")]
    [switch]$SendCommand,
    
    [Parameter(ParameterSetName="SendCommand")]
    [string]$Target = "*",  # "*" = tất cả máy, hoặc tên máy cụ thể
    
    [Parameter(ParameterSetName="SendCommand")]
    [string]$Code,
    
    [Parameter(ParameterSetName="SendCommand")]
    [switch]$Emergency,
    
    [string]$GitHubOwner = "quyenpv",
    [string]$GitHubRepo = "chanhung-it-security",
    [string]$Branch = "main"
)

# ─────────────────────────────────────────────────────────────
#  CẤU HÌNH
# ─────────────────────────────────────────────────────────────

$RepoPath = $PSScriptRoot
$ModulesPath = Join-Path $RepoPath "modules"
$ManifestPath = Join-Path $RepoPath "manifest.json"

# ─────────────────────────────────────────────────────────────
#  HÀM TIỆN ÍCH
# ─────────────────────────────────────────────────────────────

function Write-Step  ([string]$Text) { Write-Host "`n  ► $Text" -ForegroundColor Yellow }
function Write-OK    ([string]$Text) { Write-Host "    [✓] $Text" -ForegroundColor Green }
function Write-Warn  ([string]$Text) { Write-Host "    [!] $Text" -ForegroundColor DarkYellow }
function Write-Err   ([string]$Text) { Write-Host "    [✗] $Text" -ForegroundColor Red }
function Write-Info  ([string]$Text) { Write-Host "    [-] $Text" -ForegroundColor Gray }

function Get-GitHubPAT {
    # Ưu tiên biến môi trường
    if ($env:GITHUB_PAT) {
        return $env:GITHUB_PAT
    }
    
    # Hỏi người dùng
    $pat = Read-Host "Nhập GitHub PAT (Fine-grained token với quyền Contents: Read/Write)"
    if ([string]::IsNullOrWhiteSpace($pat)) {
        throw "GitHub PAT không được để trống"
    }
    return $pat
}

function Test-GitRepo {
    $gitDir = Join-Path $RepoPath ".git"
    return Test-Path $gitDir
}

function Invoke-GitPush {
    param(
        [string]$Message,
        [string]$PAT
    )
    
    Write-Step "Đang push lên GitHub..."
    
    # Configure git user
    & git config user.email "quyenpv@users.noreply.github.com"
    & git config user.name "quyenpv"
    
    # Add all changes
    & git add .
    & git commit -m $Message
    
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "Không có thay đổi để commit"
        return
    }
    
    # Push with authentication
    $authUrl = "https://${PAT}@github.com/${GitHubOwner}/${GitHubRepo}.git"
    & git push $authUrl $Branch
    
    if ($LASTEXITCODE -eq 0) {
        Write-OK "Đã push thành công lên GitHub"
        Write-Info "GitHub Actions sẽ tự động tính SHA256 và cập nhật manifest.json"
    } else {
        throw "Push thất bại. Kiểm tra PAT và quyền truy cập."
    }
}

# ─────────────────────────────────────────────────────────────
#  PUSH MODULE MỚI
# ─────────────────────────────────────────────────────────────

if ($PSCmdlet.ParameterSetName -eq "PushModule") {
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║   CHẤN HƯNG HOLDING - PUSH MODULE TO GITHUB         ║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    if (-not (Test-GitRepo)) {
        Write-Err "Thư mục hiện tại không phải là Git repository"
        Write-Info "Chạy: git init"
        exit 1
    }
    
    if ([string]::IsNullOrWhiteSpace($Module)) {
        $Module = Read-Host "Nhập tên module (ví dụ: Module-BlockBrowserDownloads)"
    }
    
    $moduleFile = Join-Path $ModulesPath "$Module.ps1"
    
    if (-not (Test-Path $moduleFile)) {
        Write-Err "Không tìm thấy module: $moduleFile"
        exit 1
    }
    
    Write-OK "Tìm thấy module: $Module"
    
    # Đọc và hiển thị module info
    $content = Get-Content $moduleFile -Raw
    Write-Info "Đang kiểm tra module..."
    
    # Cập nhật manifest.json (tạm thời - GitHub Actions sẽ tính SHA256)
    $manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json
    
    if (-not $manifest.modules.$Module) {
        Write-Warn "Module chưa có trong manifest.json"
        $version = Read-Host "Nhập phiên bản (mặc định 1.0.0)"
        if ([string]::IsNullOrWhiteSpace($version)) { $version = "1.0.0" }
        
        $description = Read-Host "Nhập mô tả module"
        $target = Read-Host "Nhập target (mặc định *)"
        if ([string]::IsNullOrWhiteSpace($target)) { $target = "*" }
        
        $newModule = @{
            filename = "$Module.ps1"
            version = $version
            sha256 = ""  # Sẽ được GitHub Actions điền
            description = $description
            enabled = $true
            priority = "medium"
            target = $target
        }
        
        $manifest.modules | Add-Member -MemberType NoteProperty -Name $Module -Value $newModule -Force
        $manifest | ConvertTo-Json -Depth 10 | Set-Content $ManifestPath
        Write-OK "Đã thêm module vào manifest.json"
    } else {
        Write-OK "Module đã có trong manifest.json"
    }
    
    # Push lên GitHub
    $pat = Get-GitHubPAT
    Invoke-GitPush -Message "feat: update module $Module" -PAT $pat
    
    Write-Host ""
    Write-OK "Hoàn tất!"
    Write-Info "GitHub Actions sẽ tự động tính SHA256 và cập nhật manifest.json trong vài phút"
    Write-Info "Kiểm tra tại: https://github.com/${GitHubOwner}/${GitHubRepo}/actions"
}

# ─────────────────────────────────────────────────────────────
#  GỬI LỆNH ĐẾN MÁY CLIENT
# ─────────────────────────────────────────────────────────────

if ($PSCmdlet.ParameterSetName -eq "SendCommand") {
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║   CHẤN HƯNG HOLDING - SEND COMMAND TO AGENTS       ║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    if (-not (Test-GitRepo)) {
        Write-Err "Thư mục hiện tại không phải là Git repository"
        exit 1
    }
    
    if ([string]::IsNullOrWhiteSpace($Code)) {
        $Code = Read-Host "Nhập lệnh PowerShell"
    }
    
    Write-OK "Target: $Target"
    Write-OK "Command: $Code"
    
    # Đọc manifest.json
    $manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json
    
    # Tạo command object
    $commandObj = @{
        id = [Guid]::NewGuid().ToString()
        target = $Target
        code = $Code
        timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        emergency = $Emergency.IsPresent
        executed = $false
    }
    
    # Thêm vào manifest
    if ($Emergency) {
        $manifest.commands.emergency += @($commandObj)
    } else {
        $manifest.commands.scheduled += @($commandObj)
    }
    
    # Lưu manifest.json
    $manifest | ConvertTo-Json -Depth 10 | Set-Content $ManifestPath
    Write-OK "Đã thêm lệnh vào manifest.json"
    
    # Push lên GitHub
    $pat = Get-GitHubPAT
    $commandType = if ($Emergency) { "EMERGENCY" } else { "SCHEDULED" }
    Invoke-GitPush -Message "cmd: add $commandType command to $Target" -PAT $pat
    
    Write-Host ""
    Write-OK "Đã gửi lệnh thành công!"
    Write-Info "Các máy client sẽ thực thi lệnh trong vòng 15 phút"
    Write-Info "Kiểm tra manifest tại: https://github.com/${GitHubOwner}/${GitHubRepo}/blob/main/manifest.json"
}
