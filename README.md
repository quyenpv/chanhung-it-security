# ChanHung IT Security - Auto-Update Agent

Hệ thống agent tự động cập nhật và cài đặt các module bảo mật từ GitHub xuống các máy client.

## Tổng quan

Hệ thống cho phép:
- Tự động pull code mới từ GitHub
- Tự động cài đặt lại khi có thay đổi
- Thực thi các module bảo mật theo lịch
- Gửi lệnh từ xa đến các máy client
- Verify integrity của module bằng SHA256

## Cấu trúc Project

```
ChanHung_IT_Security/
├── ps-agent/
│   ├── Install-ChanHungAgent.ps1    # Script cài đặt agent trên client
│   ├── Push-Module.ps1              # Script push module lên GitHub
│   ├── manifest.json                # Manifest quản lý modules và commands
│   └── modules/                     # Thư mục chứa các module
│       ├── Module-ITHardening.ps1
│       ├── Module-BlockBrowserDownloads.ps1
│       └── Module-USBControl.ps1
├── ChanHung_IT_Install.ps1          # Script cài đặt chính
├── ChanHung_IT_Setup.ps1            # Script setup
└── .github/
    └── workflows/
        └── update-manifest.yml      # GitHub Actions tự động update SHA256
```

## Cài đặt Agent trên Client

### Yêu cầu
- Windows 10/11 hoặc Windows Server
- Quyền Administrator
- Git đã được cài đặt (https://git-scm.com/download/win)
- GitHub PAT (Personal Access Token) với quyền Contents: Read-only

### Cách cài đặt

1. **Tạo GitHub PAT**
   - Vào GitHub Settings → Developer settings → Personal access tokens → Fine-grained tokens
   - Tạo token mới với quyền: `Contents: Read-only`
   - Lưu token này để sử dụng

2. **Chạy script cài đặt**
   ```powershell
   # Mở PowerShell với quyền Administrator
   cd ps-agent
   .\Install-ChanHungAgent.ps1 -PAT "your_github_pat_here"
   ```

   Hoặc để cấu hình tùy chỉnh:
   ```powershell
   .\Install-ChanHungAgent.ps1 `
       -GitHubOwner "quyenpv" `
       -GitHubRepo "chanhung-it-security" `
       -Branch "main" `
       -InstallPath "C:\Program Files\ChanHung\PS-Agent" `
       -PAT "your_github_pat_here"
   ```

3. **Xác nhận cài đặt**
   - Agent sẽ được cài đặt tại: `C:\Program Files\ChanHung\PS-Agent`
   - Scheduled task sẽ được tạo: `ChanHungPSAgent-Pull`
   - Agent sẽ tự động kiểm tra và cập nhật mỗi 15 phút

### Gỡ cài đặt

```powershell
cd ps-agent
.\Install-ChanHungAgent.ps1 -Uninstall
```

## Quản lý Modules

### Thêm module mới

1. Tạo file module trong thư mục `ps-agent/modules/`
2. Đặt tên theo format: `Module-Name.ps1`
3. Push module lên GitHub:
   ```powershell
   cd ps-agent
   .\Push-Module.ps1 -Module "Module-Name"
   ```

### Cấu hình Module trong manifest.json

```json
{
  "modules": {
    "Module-Name": {
      "filename": "Module-Name.ps1",
      "version": "1.0.0",
      "sha256": "hash_sẽ_được_tự_động_cập_nhật",
      "description": "Mô tả module",
      "enabled": true,
      "priority": "high",
      "target": "*"
    }
  }
}
```

**Thuộc tính:**
- `enabled`: true/false - Bật/tắt module
- `priority`: high/medium/low - Ưu tiên thực thi
- `target`: "*" (tất cả máy) hoặc tên máy cụ thể

## Gửi Lệnh Từ Xa

### Gửi lệnh khẩn cấp (Emergency)

```powershell
cd ps-agent
.\Push-Module.ps1 -SendCommand -Emergency -Target "*" -Code "Write-Host 'Emergency command'"
```

### Gửi lệnh theo lịch (Scheduled)

```powershell
cd ps-agent
.\Push-Module.ps1 -SendCommand -Target "PC-NAME" -Code "Restart-Computer -Force"
```

## GitHub Actions

Workflow `.github/workflows/update-manifest.yml` sẽ tự động:
- Tính SHA256 cho các module khi có thay đổi
- Cập nhật `manifest.json` với hash mới
- Commit và push thay đổi

## Xem Log

Log được lưu tại: `C:\Program Files\ChanHung\PS-Agent\logs\`

File log theo ngày: `agent-YYYYMMDD.log`

## Cấu hình Thời gian Kiểm tra

Mặc định: 15 phút

Để thay đổi, chỉnh sửa tham số trong `Install-ChanHungAgent.ps1`:
```powershell
$CheckIntervalMinutes = 30  # Thay đổi thành 30 phút
```

## Bảo mật

- GitHub PAT được lưu encrypted trong Windows Registry
- SHA256 verify đảm bảo integrity của module
- Agent chạy với quyền SYSTEM
- Tất cả log được ghi lại để audit

## Khắc phục sự cố

### Agent không pull được code
- Kiểm tra GitHub PAT còn hợp lệ không
- Kiểm tra kết nối internet
- Xem log tại `C:\Program Files\ChanHung\PS-Agent\logs\`

### Module không thực thi
- Kiểm tra `enabled: true` trong manifest.json
- Kiểm tra SHA256 có khớp không
- Xem log để biết lỗi cụ thể

### Scheduled task không chạy
- Mở Task Scheduler và kiểm tra task `ChanHungPSAgent-Pull`
- Kiểm tra quyền SYSTEM
- Chạy lại script cài đặt

## Quy trình làm việc

1. **Phát triển module mới**
   - Viết code trong `ps-agent/modules/`
   - Test trên máy local

2. **Push lên GitHub**
   ```powershell
   .\Push-Module.ps1 -Module "Module-Name"
   ```

3. **GitHub Actions tự động**
   - Tính SHA256
   - Cập nhật manifest.json

4. **Agent trên client tự động**
   - Pull code mới
   - Verify SHA256
   - Thực thi module

## Liên hệ

- Repository: https://github.com/quyenpv/chanhung-it-security
- Issues: https://github.com/quyenpv/chanhung-it-security/issues
