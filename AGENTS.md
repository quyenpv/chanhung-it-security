# AGENTS.md — GreenCould Mandatory Rules (SELF-CONTAINED + PORTABLE)

**Status:** Mandatory. Pack is complete on **any machine** after install — no reference repo needed.

## Do not waste tokens

- Never clone/fetch the original 22 skill GitHub repos for normal work.
- Never open `docs/SOURCES.md` while coding.
- Never require `greencould-server-monitor` (or any path on another PC).
- Obey: this file + `.cursor/rules/*.mdc` + portable blueprints under `docs/`.

## Portable blueprints (MUST for UI)

These files are **copied into each project** by the install script. On a new laptop, if the project has them, the agent has everything:

| File | When |
|------|------|
| `docs/REACT_ANTD_ADMIN_BLUEPRINT.md` | Canonical React + Ant Design admin template architecture and reuse workflow |
| `docs/ADMIN_UI_BLUEPRINT.md` | Admin / dashboard / control panel |
| `docs/I18N_BLUEPRINT.md` | Any UI (vi default + en + zh + flags) |
| `docs/UI_DESIGN_CHECKLIST.md` | Before claiming UI done |
| `docs/GITHUB_CICD_BLUEPRINT.md` | GitHub Actions, VPS sync, self-hosted runner |
| `docs/WAF_SECURITY_BLUEPRINT.md` | WAF filters, input guards, rate-limit / IP mitigation |
| `docs/THEME_RESPONSIVE_BLUEPRINT.md` | Dark/light full styles + mobile/tablet/laptop/PC |
| `docs/TOAST_SELECT_BLUEPRINT.md` | Toast/notifications + Select2 / searchable pickers |
| `docs/EMAIL_OTP_AUTH_BLUEPRINT.md` | Transactional email templates + TOTP/email OTP login |
| `docs/INSTALL_WIZARD_BLUEPRINT.md` | Install Wizard, schema initialization and third-party delivery packaging |

If missing → stop and ask user to re-install the pack. Do not invent design.

## Always-on rules

- `00-core-always.mdc`
- `01-build-plan-debug.mdc`
- `02-communication.mdc`
- `06-research-skills.mdc`
- `08-i18n-multilang.mdc`
- `09-github-cicd-deploy.mdc`
- `10-waf-security.mdc`
- `13-realtime-background-data.mdc`
- `14-email-otp-auth.mdc`

## Load when relevant

| Work | Rule + docs |
|------|-------------|
| Admin UI | `03-admin-ui-greenmonitor.mdc` + `docs/REACT_ANTD_ADMIN_BLUEPRINT.md` + `docs/ADMIN_UI_BLUEPRINT.md` |
| Marketing UI | `04-frontend-design.mdc` + checklist |
| Motion / video | `05-motion-video.mdc` |
| Marketing copy | `07-marketing-content.mdc` |
| GitHub / VPS / runner | `09-github-cicd-deploy.mdc` + `docs/GITHUB_CICD_BLUEPRINT.md` |
| WAF / security filters | `10-waf-security.mdc` + `docs/WAF_SECURITY_BLUEPRINT.md` |
| Theme + responsive | `11-theme-responsive.mdc` + `docs/THEME_RESPONSIVE_BLUEPRINT.md` |
| Toast + searchable select | `12-toast-select.mdc` + `docs/TOAST_SELECT_BLUEPRINT.md` |
| Email + login OTP | `14-email-otp-auth.mdc` + `docs/EMAIL_OTP_AUTH_BLUEPRINT.md` |
| Install Wizard & Delivery | `16-install-wizard-delivery.mdc` + `docs/INSTALL_WIZARD_BLUEPRINT.md` |

## Iron laws

1. Answer first
2. Plan before non-trivial code
3. Systematic debug; after 3 failed fixes → discuss architecture
4. Verify with evidence
5. Minimal diffs; no secrets
6. Match user language; exact code/errors
7. Admin React → canonical React Ant Design template + Ant Design tokens; do not invent a parallel admin stack/aesthetic. Marketing → anti-slop in `04`
8. I18n: **🇻🇳 Tiếng Việt (default) · 🇺🇸 English · 🇨🇳 中文** with flags
9. Release + deploy: one canonical version source; sync/read/bump with reason → validate → commit title bắt buộc bằng tiếng Việt có dấu → scoped push → follow the exact GitHub Actions run → build→GHCR→server→runtime verify. Khi user đã yêu cầu commit/push/deploy hoặc nói “sau khi test đạt”, tự tiếp tục toàn bộ chuỗi ngay khi gate xanh, không hỏi xác nhận lần hai. Windows runner phải cài bằng một file PowerShell và đăng ký Windows Service `Automatic` theo `docs/GITHUB_CICD_BLUEPRINT.md`
10. Security from project initialization: create WAF/input guards + payload tests + a blocking CI security check before the first deployable feature. Seed server-enforced deny-by-default RBAC roles `owner`, `security_admin`, `admin`, `operator`, `auditor`, `viewer`; no client-controlled role grants. Follow `docs/WAF_SECURITY_BLUEPRINT.md`.
11. Theme + devices: every UI page shell/main/section must use full available width by default, with no centered narrow `max-w-*` + `mx-auto` wrapper that leaves large empty side gutters; every component **dark + light** + **mobile / tablet / laptop / PC** per `docs/THEME_RESPONSIVE_BLUEPRINT.md`
12. Toast + pickers: use the shared toast visual contract (no browser/library defaults or `alert()`). Portal the fixed toast viewport directly under `body`, keep `--z-toast` above navbar layers, and position it below the measured header height + safe gap so it is never covered. Every auto-dismiss toast has a countdown progress bar synchronized to the same remaining-time clock, pausing with hover/focus/interaction and resuming without reset; persistent toast has no fake progress. Entity lists use Select2 or searchable equivalent per `docs/TOAST_SELECT_BLUEPRINT.md`
13. Realtime data: fetch/update in the background; never use `window.onload`, full-page reload, `window.location.reload()`, or require browser refresh to show fresh data
14. UI controls: use an accessible switch/toggle for boolean on/off settings. Checkbox is allowed only for independent multi-selection, consent/agreement, or table/card row selection tied to real batch actions; never substitute checkbox for an immediate on/off setting or switch for selecting many records
15. Tab data: on page load initial-load only the active tab; lazy-load each other group on first open, deduplicate concurrent activation, and retain its page-session cache. “Initial once” does not block polling, subscriptions, invalidation, reconnect sync, mutation reconciliation, or explicit error recovery against that cache
16. UI preference initialization: theme, accent/color, and locale use one documented canonical persistence adapter and precedence. Resolve and apply valid persisted values before first paint; system/default values are fallback-only. Refresh/hydration/remount must not flash, reset, or disagree across server and client
17. UI stacking: use the scope-aware layer scale in `docs/THEME_RESPONSIVE_BLUEPRINT.md`. Header, drawer, and modal popovers must sit above their owning surface without clipping; portal floating UI with its owner scope. Never patch stacking with arbitrary `z-index: 9999`
18. Tabs: React admin business tabs use Ant Design `Tabs` with `type="card"` by default and preserve its ARIA/keyboard behavior; route tabbar remains a separate shell concern. Other stacks use the equivalent joined rail+panel contract in `docs/THEME_RESPONSIVE_BLUEPRINT.md`. Do not ship disconnected pills/buttons or per-page ad-hoc tab styles
19. Email + OTP auth: every project configures transactional email with professional localized HTML + plain-text templates. Projects with authentication require authenticator-app TOTP or email OTP; never ship password-only login. Follow `docs/EMAIL_OTP_AUTH_BLUEPRINT.md`
20. Scroll to top: every UI project provides one shared accessible scroll-to-top button per `docs/THEME_RESPONSIVE_BLUEPRINT.md`. It appears only after meaningful scroll, targets the actual scroll owner, respects reduced motion and safe-area/bottom-nav offsets, uses `--z-floating-action`, and always derives background/hover/focus/contrast from the currently selected accent tokens without hard-coded defaults
21. Card + Table data views: every collection/dataset UI provides both modes. A data-tab group renders exactly one accessible Card/Table segmented control at the far right of the same toolbar row as its `ul[role="tablist"]`; it controls the active panel and preserves the mode across tab changes—never duplicate it per tab or inside panels. Both renderers share normalized cache/query, filters, sorting, selection, pagination, permissions, and realtime state; switching presentation never refetches, resets, reloads, or changes parity. Follow `docs/THEME_RESPONSIVE_BLUEPRINT.md`
22. React admin template: new React admin projects use the canonical local template at `D:\ChanHung_Ltd\App_Project_2026\App_React-antd-admin` when available, excluding `.git`, `node_modules`, build artifacts and `.env`; on other machines use the portable contract in `docs/REACT_ANTD_ADMIN_BLUEPRINT.md`. Existing projects are ported incrementally, not destructively replaced.
23. **Đồng bộ Database & Install Wizard (Bắt buộc cho mọi Agent)**: Khi có bất kỳ thay đổi hoặc cập nhật nào về cấu trúc Database (thêm/sửa model, bảng, cột, khóa ngoại, indexes hoặc seed data), **bắt buộc phải cập nhật đồng bộ**:
    - Migration và seed logic trong Controller cài đặt (`install.go` / install endpoint).
    - File DDL schema SQL rỗng `database/database.sql` và `install/database.sql`.
    - Script đóng gói bàn giao bên thứ 3 `scripts/package-for-delivery.ps1`.
    - Hàm `IsInstalled()` bắt buộc có 3 lớp kiểm tra an toàn (file cờ `.installed`, biến môi trường secrets hợp lệ, kiểm tra tài khoản người dùng trong DB) để bảo vệ 100% server production không bị rơi vào trang cài đặt.

## Modes

- Default: concise + answer-first
- `/ponytail` / “một dòng”: exactly one line
- `/caveman`: max compression (code untouched)
- Security / irreversible: full clarity
