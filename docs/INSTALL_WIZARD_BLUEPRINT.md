# Install Wizard & Delivery Packaging Blueprint (PORTABLE)

> File này đi kèm pack quy tắc **GreenCould Mandatory Rules**.  
> Áp dụng cho mọi dự án Web/API/Service cần đóng gói bàn giao cho bên thứ 3 hoặc tự động triển khai lần đầu mà không cần can thiệp code trực tiếp.

---

## 0. Nguyên Tắc Cốt Lõi (Core Principles)

1. **Zero-Config First Boot:** Khi triển khai mới từ file nén bàn giao hoặc `docker compose up -d`, người dùng truy cập Web sẽ được tự động chuyển hướng đến Trình cài đặt (`/install`).
2. **Multi-layer Production Safety (Bảo vệ tuyệt đối cho Server đang chạy):**
   - Hệ thống đang chạy trên Production tuyệt đối **không bao giờ** bị rơi vào trạng thái cài đặt lại hoặc hiển thị trang Wizard.
   - Hàm kiểm tra `IsInstalled()` bắt buộc kiểm tra 3 lớp:
     - *Lớp 1:* File cờ `.installed` (ví dụ `data/install/.installed`).
     - *Lớp 2:* Biến môi trường hệ thống đã có cấu hình thật (`JWT_SECRET`, `APP_KEY`, `DB_PASSWORD` chuẩn không phải dummy setup key).
     - *Lớp 3:* Cơ sở dữ liệu đã kết nối và có dữ liệu tài khoản quản trị `users`.
3. **Đồng bộ Database & Schema:** Bất kỳ thay đổi cấu trúc DB / model nào đều phải đồng bộ vào:
   - Danh sách Migration / Seeding của Install Controller.
   - File DDL PostgreSQL/MySQL rỗng `database/database.sql` và `install/database.sql`.
   - Script đóng gói bàn giao `scripts/package-for-delivery.ps1`.

---

## 1. Kiến Trúc Luồng Cài Đặt (Architecture Flow)

```
                       [Người dùng truy cập Web]
                                  │
                                  ▼
                     [Kiểm tra /api/install/status]
                                  │
                  ┌───────────────┴───────────────┐
                  ▼                               ▼
       [Chưa cài đặt (false)]           [Đã cài đặt (true)]
                  │                               │
                  ▼                               ▼
       Chuyển hướng sang /install        Chuyển hướng /login hoặc Dashboard
       (Khóa mọi API bảo mật khác)       (Khóa truy cập route /install)
                  │
        ┌─────────┴───────────────────────────────┐
        │  TRÌNH CÀI ĐẶT 3 BƯỚC (STEPPER)         │
        │                                         │
        │  Bước 1: Kiểm tra yêu cầu hệ thống     │
        │          - API Liveness                 │
        │          - Quyền ghi thư mục data       │
        │                                         │
        │  Bước 2: Cấu hình hệ thống              │
        │          - Kết nối Database + Nút Test  │
        │          - Tự sinh Secret/Token an toàn │
        │          - URL Domain hệ thống          │
        │          - Tạo tài khoản Owner đầu tiên │
        │                                         │
        │  Bước 3: Hoàn tất                       │
        │          - Tự động Migrate DB & Seed    │
        │          - Ghi file cấu hình .env       │
        │          - Tạo cờ .installed            │
        │          - Chuyển hướng sang /login     │
        └─────────────────────────────────────────┘
```

---

## 2. Thiết Kế Giao Diện Stepper 3 Bước (UI Contract)

Tuân thủ nghiêm ngặt **Theme & Responsive Blueprint**:
- Hỗ trợ đầy đủ **Dark / Light theme** tự động chuyển đổi qua CSS variables (`--ui-bg`, `--ui-accent`, `--ui-border`, `--ui-text`).
- Hỗ trợ đa ngôn ngữ i18n: **🇻🇳 Tiếng Việt (mặc định)**, **🇺🇸 English**, **🇨🇳 中文** (có dropdown cờ chuyển đổi trên header).
- Sử dụng Switch/Toggle thay cho Checkbox.
- Phản hồi trạng thái rõ ràng (Badge thành công/thất bại, Spinner loading, Toast notification khi test kết nối).

### Chi tiết các bước:
- **Bước 1 (Requirements):** Kiểm tra trạng thái sẵn sàng của backend, quyền ghi thư mục lưu trữ cờ, thông báo trực quan bằng icon tick xanh / chéo đỏ.
- **Bước 2 (Configuration):**
  - Nhập thông tin kết nối DB (Host, Port, User, Password, DB Name) + Nút **Kiểm tra kết nối** gọi API `POST /api/install/probe`.
  - Mục Bí mật & Token: Nút bấm **Tự sinh ngẫu nhiên (Auto-generate)** cho các token bảo mật (JWT Secret, App Key, API Token).
  - Mục Tài khoản Owner: Username, Email, Password, Confirm Password (kiểm tra độ dài tối thiểu >= 8 ký tự và khớp mật khẩu).
  - Nút **Cài đặt**: Gọi `POST /api/install/run` có Rate Limiting (tối đa 5 lần/phút/IP).
- **Bước 3 (Finished):** Hiển thị màn hình thành công, lưu ý khởi động lại container nếu cần và nút bấm dẫn thẳng tới trang Đăng nhập.

---

## 3. Backend API Contract (`/api/install/*`)

Tất cả các endpoint cài đặt phải là **Public (không yêu cầu JWT)** nhưng **tự động bị vô hiệu hóa (HTTP 403)** ngay khi hệ thống đã ở trạng thái `.installed`:

| Phương thức | Endpoint | Chức năng | Hành vi bảo mật |
|---|---|---|---|
| `GET` | `/api/install/status` | Trả về `{ installed: bool, version: string }` | Không yêu cầu auth. |
| `POST` | `/api/install/probe` | Test kết nối DB với payload `{ host, port, user, password, dbName }` | Trả về 403 nếu đã cài đặt. Validate hostname chống SSRF. |
| `POST` | `/api/install/run` | Thực hiện Migrate DB, Seed Role, tạo Owner, ghi `.env`, tạo file `.installed` | Trả về 403 nếu đã cài đặt. Giới hạn tần suất IP Rate-limit. |

---

## 4. Cơ Chế Khởi Tạo Database & File SQL Schema Mẫu

Mỗi project bàn giao bắt buộc phải chuẩn bị đồng thời 2 cơ chế:
1. **Auto Migration & Seeding:** Khi chạy qua Web Wizard, backend tự động thực hiện migration và seed đầy đủ role/admin.
2. **File Database SQL Schema rỗng:**
   - Đặt tại `database/database.sql` và `install/database.sql`.
   - Chứa toàn bộ DDL (bảng, khóa chính, khóa ngoại, indexes) và dữ liệu seed mặc định ban đầu.
   - Được đóng gói vào thư mục `database/` trong file ZIP bàn giao bên thứ 3.

---

## 5. Quy Chuẩn Đóng Gói Bàn Giao (`scripts/package-for-delivery.ps1`)

Mỗi dự án cần có script PowerShell `scripts/package-for-delivery.ps1` để tự động hóa việc đóng gói bàn giao:
- Đọc phiên bản canonical từ `release-versions.json`.
- Tạo thư mục `dist-delivery/ProjectName-Delivery-vX.Y.Z/`.
- Sao chép các file cấu hình Docker (`docker-compose.yml`, `.env.example`).
- Sao chép schema `database/database.sql`.
- Sao chép các file nhị phân Agent / Service thực thi (nếu có) — **Nghiêm cấm xóa file binary**.
- Tự động sinh tài liệu hướng dẫn triển khai `README-INSTALLATION.md` bằng tiếng Việt có dấu.
- Nén toàn bộ thành file ZIP `ProjectName-Delivery-vX.Y.Z.zip`.
