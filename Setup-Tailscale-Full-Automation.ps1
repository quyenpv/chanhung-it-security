<#
.SYNOPSIS
    Script tu dong hoa: Tai, Cai dat va Cau hinh Tailscale Subnet Router.
    Da thay doi link tai MSI chinh xac tu Tailscale.com.
#>

# 1. Kiem tra quyen Administrator
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "LOI: Vui long chay script bang quyen Administrator!" -ForegroundColor Red
    pause
    exit
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   HE THONG TU DONG HOA TAILSCALE - CHAN HUNG HOLDING     " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 2. Kiem tra va Cai dat Tailscale neu chua co
$tsExe = "C:\Program Files\Tailscale\tailscale.exe"
if (!(Test-Path $tsExe)) {
    Write-Host "`n[BUOC 1] Khong tim thay Tailscale. Bat dau tai va cai dat..." -ForegroundColor Yellow
    
    # SỬA ĐỔI: Xác định link tải chính xác dựa trên kiến trúc hệ điều hành
    $arch = if ([Environment]::Is64BitOperatingSystem) { "amd64" } else { "386" }
    $url = "https://pkgs.tailscale.com/stable/tailscale-setup-latest-$arch.msi"
    $output = "$env:TEMP\tailscale-setup.msi"
    
    try {
        Write-Host " -> Dang cau hinh TLS 1.2 va TLS 1.3 de bao mat ket noi..." -ForegroundColor Gray
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
        
        Write-Host " -> Dang tai bo cai tu URL: $url" -ForegroundColor Gray
        Invoke-WebRequest -Uri $url -OutFile $output -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" -ErrorAction Stop
        
        Write-Host " -> Dang cai dat (Silent Install)... Vui long cho giay lat." -ForegroundColor Gray
        Start-Process msiexec.exe -ArgumentList "/i `"$output`" /quiet /norestart" -Wait
        
        Write-Host " -> Cai dat hoan tat!" -ForegroundColor Green
    } catch {
        Write-Host " -> LOI: Khong the tai bo cai. Chi tiet loi: $_" -ForegroundColor Red
        pause
        exit
    }
} else {
    Write-Host "`n[BUOC 1] Tailscale da duoc cai dat san." -ForegroundColor Green
}

# 3. Goi y dai IP LAN thuc te
$currentIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { 
    $_.InterfaceAlias -notlike "*Loopback*" -and 
    $_.IPAddress -notlike "169.254.*" -and 
    $_.IPAddress -notlike "100.*" 
}).IPAddress[0]

$suggestedRoute = $currentIP.Substring(0, $currentIP.LastIndexOf('.')) + ".0/24"

Write-Host "`n[BUOC 2] XAC DINH DAI MANG NOI BO" -ForegroundColor Yellow
Write-Host "Goi y dai mang tai day: $suggestedRoute" -ForegroundColor Gray
$lanRoute = Read-Host "Nhap dai IP muon quang ba (Mac dinh: $suggestedRoute)"
if ([string]::IsNullOrWhiteSpace($lanRoute)) { $lanRoute = $suggestedRoute }

# 4. Cau hinh Registry IP Forwarding
Write-Host "`n[BUOC 3] Dang thiet lap Registry cho IP Forwarding..." -ForegroundColor Yellow
$regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
Set-ItemProperty -Path $regPath -Name "IPEnableRouter" -Value 1
Write-Host " -> OK: Da bat IPEnableRouter." -ForegroundColor Green

# 5. Bat Forwarding tren cac card mang
Set-NetIPInterface -Forwarding Enabled -ErrorAction SilentlyContinue

# 6. Mo Firewall cho phep Ping
Write-Host "`n[BUOC 4] Dang mo Firewall cho phep Ping..." -ForegroundColor Yellow
netsh advfirewall firewall add rule name="Allow ICMPv4 Inbound (Tailscale)" protocol=icmpv4:8,any dir=in action=allow | Out-Null
Write-Host " -> OK: Firewall da san sang." -ForegroundColor Green

# 7. Khoi chay Tailscale va thiet lap Route
Write-Host "`n[BUOC 5] Dang kich hoat luong mang Tailscale..." -ForegroundColor Yellow

# Cho mot chut de dich vu Tailscale on dinh sau khi cai dat
Start-Sleep -Seconds 5

& "C:\Program Files\Tailscale\tailscale.exe" up --advertise-routes=$lanRoute --reset
Write-Host " -> OK: Da gui yeu cau Advertise Route: $lanRoute" -ForegroundColor Green

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "           DA HOAN TAT QUY TRINH TU DONG" -ForegroundColor Cyan
Write-Host "1. HAY KHOI DONG LAI MAY TINH de kich hoat Registry." -ForegroundColor Red
Write-Host "2. Dang nhap Tailscale va APPROVE route tren Admin Console." -ForegroundColor Magenta
Write-Host "==========================================================" -ForegroundColor Cyan
pause