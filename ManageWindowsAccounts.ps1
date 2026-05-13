# ==============================================================================
# CÔNG CỤ QUẢN LÝ TÀI KHOẢN WINDOWS (PHIÊN BẢN TƯƠNG THÍCH CAO)
# ==============================================================================

function Check-Admin {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host " [!] VUI LÒNG CHẠY POWERSHELL VỚI QUYỀN ADMINISTRATOR." -ForegroundColor Red
        pause
        exit
    }
}

function Create-LocalAdmin {
    Write-Host "`n--- [1] TẠO TÀI KHOẢN LOCAL ADMIN MỚI ---" -ForegroundColor Cyan
    
    $username = Read-Host " Nhập Username mới"
    if ([string]::IsNullOrWhiteSpace($username)) { return }

    $password = Read-Host " Nhập Password cho tài khoản $username"
    if ([string]::IsNullOrWhiteSpace($password)) { return }

    try {
        # Tạo user bằng lệnh net user (tương thích 100%)
        net user $username $password /add /y
        
        # Thêm vào nhóm Administrators (Quản trị viên)
        net localgroup Administrators $username /add
        
        # Thiết lập mật khẩu không hết hạn
        wmic useraccount where "name='$username'" set passwordexpires=false
        
        Write-Host " [OK] Đã tạo thành công tài khoản Admin: $username" -ForegroundColor Green
    } catch {
        Write-Host " [ERROR] Lỗi: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function List-And-Delete-User {
    Write-Host "`n--- [2] DANH SÁCH TÀI KHOẢN HIỆN CÓ ---" -ForegroundColor Cyan
    
    # Sử dụng WMI để lấy danh sách User (thay thế Get-LocalUser bị lỗi)
    $users = Get-WmiObject -Class Win32_UserAccount -Filter "LocalAccount='True'" | Select-Object Name, Caption, Disabled, FullName
    
    if ($null -eq $users) {
        Write-Host " [!] Không tìm thấy tài khoản nào." -ForegroundColor Yellow
        return
    }

    # Hiển thị danh sách
    $i = 0
    foreach ($u in $users) {
        $status = if ($u.Disabled -eq $true) { "Disabled" } else { "Enabled" }
        Write-Host " [$i] - Name: $($u.Name) ($status) - FullName: $($u.FullName)" -ForegroundColor White
        $i++
    }

    $choice = Read-Host "`n Nhập số thứ tự [index] của tài khoản muốn XÓA (Hoặc Enter để hủy)"
    
    if (-not [string]::IsNullOrWhiteSpace($choice)) {
        try {
            $index = [int]$choice
            if ($index -ge 0 -and $index -lt $i) {
                $userToDelete = $users[$index].Name
                
                # Không cho phép tự xóa chính mình nếu đang đăng nhập
                if ($userToDelete -eq $env:USERNAME) {
                    Write-Host " [!] Bạn không thể xóa tài khoản đang đăng nhập hiện tại!" -ForegroundColor Red
                    return
                }

                $confirm = Read-Host " Bạn chắc chắn muốn XÓA VĨNH VIỄN '$userToDelete'? (y/n)"
                if ($confirm -eq 'y' -or $confirm -eq 'Y') {
                    # Xóa user bằng lệnh net user
                    net user $userToDelete /delete
                    Write-Host " [OK] Đã xóa thành công tài khoản: $userToDelete" -ForegroundColor Green
                }
            } else {
                Write-Host " [!] Chỉ số không hợp lệ." -ForegroundColor Red
            }
        } catch {
            Write-Host " [!] Vui lòng chỉ nhập số." -ForegroundColor Red
        }
    }
}

# --- CHƯƠNG TRÌNH CHÍNH ---
Check-Admin

do {
    Clear-Host
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host "    HỆ THỐNG QUẢN TRỊ TÀI KHOẢN WINDOWS        " -ForegroundColor Cyan
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host " 1. Tạo tài khoản Local Admin mới"
    Write-Host " 2. Xem danh sách và Xóa tài khoản (Nhân sự cũ)"
    Write-Host " 3. Thoát"
    Write-Host "-----------------------------------------------"
    
    $menuChoice = Read-Host " Chọn một tùy chọn (1-3)"

    switch ($menuChoice) {
        "1" { Create-LocalAdmin; pause }
        "2" { List-And-Delete-User; pause }
        "3" { $running = $false }
        default { Write-Host " Lựa chọn không hợp lệ!"; Start-Sleep -Seconds 1 }
    }
} while ($menuChoice -ne "3")