# Email + OTP Authentication Blueprint

Áp dụng bắt buộc cho mọi project. Email giao dịch phải được cấu hình sẵn; project có đăng nhập phải dùng **TOTP qua ứng dụng xác thực hoặc OTP qua email**, không được chỉ dùng mật khẩu.

## 1. Cấu hình email chuẩn

Dùng adapter độc lập nhà cung cấp (`EmailProvider`/`Mailer`) để business code không gọi trực tiếp SDK. Secrets chỉ đi qua secret manager hoặc biến môi trường:

```dotenv
EMAIL_PROVIDER=smtp
EMAIL_FROM_NAME=GreenCould
EMAIL_FROM_ADDRESS=no-reply@example.com
EMAIL_REPLY_TO=support@example.com
EMAIL_BASE_URL=https://example.com

# SMTP example — secret values are placeholders only
SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_SECURE=false
SMTP_USERNAME=change-me
SMTP_PASSWORD=change-me
```

- Validate các key bắt buộc khi khởi động phần email/auth; production thiếu/sai cấu hình phải fail rõ ràng, không âm thầm bỏ gửi.
- Development/test dùng Mailpit/MailHog, provider sandbox hoặc adapter ghi nhận message trong bộ nhớ. Không gửi nhầm tới người thật.
- Thiết lập SPF, DKIM, DMARC và domain `From` thống nhất trước production. Bounce/complaint phải được xử lý; không tiếp tục gửi tới địa chỉ bị suppression.
- Queue gửi nền với idempotency key, retry có exponential backoff và giới hạn; không giữ request đăng nhập chờ retry vô hạn.
- Có health/config check không làm lộ secret. Log message ID, template key và trạng thái; không log body nhạy cảm hoặc OTP.

## 2. Bộ template bắt buộc

Tối thiểu có: `auth.login_otp`, `auth.totp_enabled`, `auth.recovery_codes_changed`, `auth.security_alert`, `account.welcome`, `account.password_reset`. Mỗi template gồm HTML + plain text, subject và nội dung đủ `vi`, `en`, `zh`; thiếu bản dịch fallback về `vi`.

Template phải render phía server, escape mọi giá trị động, dùng URL HTTPS lấy từ allowlisted application base URL, không nhận URL tùy ý từ request. CSS email dùng inline style, bảng layout tương thích mail client, rộng tối đa 600px, responsive, alt text, tương phản tốt và không phụ thuộc ảnh để truyền tải thông tin chính.

### Mẫu HTML OTP chuyên nghiệp

```html
<!doctype html>
<html lang="{{locale}}">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>{{subject}}</title>
</head>
<body style="margin:0;background:#f3f6f4;color:#17211b;font-family:Arial,'Noto Sans',sans-serif;">
  <div style="display:none;max-height:0;overflow:hidden;opacity:0;">{{preheader}}</div>
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#f3f6f4;padding:24px 12px;">
    <tr><td align="center">
      <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:600px;background:#ffffff;border:1px solid #dce5df;border-radius:16px;overflow:hidden;">
        <tr><td style="padding:24px 32px;background:#123d2b;color:#ffffff;font-size:20px;font-weight:700;">{{brand_name}}</td></tr>
        <tr><td style="padding:32px;">
          <h1 style="margin:0 0 12px;font-size:24px;line-height:1.3;">{{heading}}</h1>
          <p style="margin:0 0 22px;color:#4b5d52;font-size:16px;line-height:1.6;">{{intro}}</p>
          <div role="text" aria-label="{{otp_label}}" style="margin:0 0 22px;padding:18px;text-align:center;background:#eef8f1;border:1px solid #b9dbc4;border-radius:12px;color:#123d2b;font-family:Consolas,monospace;font-size:32px;font-weight:700;letter-spacing:8px;">{{otp_code}}</div>
          <p style="margin:0 0 10px;font-size:14px;line-height:1.6;">{{expires_message}}</p>
          <p style="margin:0;color:#68786e;font-size:13px;line-height:1.6;">{{ignore_message}}</p>
        </td></tr>
        <tr><td style="padding:20px 32px;background:#f8faf8;color:#68786e;font-size:12px;line-height:1.5;">{{footer_text}}<br><a href="{{support_url}}" style="color:#16724a;">{{support_label}}</a></td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>
```

Không đưa tên chưa escape, OTP hoặc URL request trực tiếp vào HTML. Có snapshot/render test cho subject, HTML, text và ba locale. Test template bằng mailbox phổ biến và màn hình hẹp trước khi ship.

## 3. Luồng xác thực đăng nhập

Sau khi xác minh yếu tố đầu tiên, tạo challenge ràng buộc với user, mục đích `login`, session/device và thời gian. Chỉ hoàn tất session đăng nhập sau khi challenge OTP/TOTP hợp lệ.

### TOTP ứng dụng xác thực

- Theo chuẩn RFC 6238; secret được sinh bằng CSPRNG, mã hóa at rest bằng khóa quản lý riêng và không log/analytics.
- Enrollment chỉ hoàn tất sau khi user nhập một mã hợp lệ. QR/secret chỉ hiển thị trong phiên xác thực lại an toàn.
- Chấp nhận time window nhỏ theo thư viện chuẩn, ngăn tái sử dụng cùng timestep, đồng bộ giờ server.
- Cấp recovery codes ngẫu nhiên, hiển thị một lần, lưu hash, mỗi code dùng một lần. Thay đổi/tắt TOTP yêu cầu re-auth và gửi cảnh báo bảo mật.

### OTP qua email

- Sinh bằng CSPRNG; khuyến nghị 6 chữ số, hết hạn trong **5 phút**. Không dùng `Math.random`, UUID cắt ngắn hoặc mã dự đoán được.
- Lưu HMAC/hash có server-side secret cùng `challenge_id`, user, purpose, expiry, số lần thử; không lưu raw OTP.
- Một challenge chỉ dùng một lần. Resend tạo mã mới và vô hiệu mã cũ; cooldown tối thiểu 30 giây.
- Tối đa 5 lần nhập sai/challenge; rate-limit theo account + IP + device, có giới hạn theo cửa sổ và backoff. Giá trị cụ thể có thể siết chặt theo rủi ro.
- Response yêu cầu/resend luôn chung chung dù email có tồn tại hay không; thời gian phản hồi không được tạo kênh dò tài khoản rõ ràng.
- Không truyền OTP trong URL/query string. Sau thành công, rotate session ID, xóa challenge và ghi audit event không chứa mã.

## 4. UX, phục hồi và quản trị

- Cho phép paste/autofill (`autocomplete="one-time-code"`, `inputmode="numeric"` cho mã số), hiển thị thời hạn/cooldown rõ ràng và lỗi chung, dễ hiểu.
- Không dùng câu hỏi bảo mật làm recovery. Recovery thay đổi yếu tố xác thực phải re-auth, thông báo qua email và có audit trail.
- Admin/privileged account: ưu tiên bắt buộc TOTP; email OTP chỉ là phương án policy cho phép, không tự hạ cấp khi TOTP lỗi.
- Email và màn hình auth tuân thủ i18n `vi` mặc định + `en` + `zh`, dark/light và responsive theo các blueprint liên quan.

## 5. Acceptance checklist

- [ ] Provider adapter + env schema + startup validation + dev mail sink
- [ ] SPF/DKIM/DMARC và bounce/complaint plan cho production
- [ ] HTML + text templates chuyên nghiệp, responsive, escaped, đủ `vi/en/zh`
- [ ] Login có TOTP app hoặc email OTP; admin policy ưu tiên TOTP
- [ ] OTP expiry, single-use, digest storage, resend invalidation, attempt limit và rate-limit
- [ ] Generic anti-enumeration response; không log OTP/TOTP secret/recovery code
- [ ] Automated tests: render 3 locale, gửi adapter, đúng/sai/hết hạn/replay/resend/throttle OTP
- [ ] Session chỉ được tạo/rotate sau khi yếu tố OTP hợp lệ
