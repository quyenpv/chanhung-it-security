# GEMINI.md — GreenCould Mandatory Rules (Antigravity / Gemini)

Self-contained pack. Obey `AGENTS.md`, `.agent/rules/*.md`, and `.cursor/rules/*.mdc`.

## Must

- Answer first; keep replies tight
- Plan before coding (unless 1-file hotfix)
- Root-cause debug; escalate after 3 failed fixes
- Admin UI → `docs/REACT_ANTD_ADMIN_BLUEPRINT.md` + `docs/ADMIN_UI_BLUEPRINT.md` (canonical React Ant Design template contract)
- Marketing UI → `04` + `07` + checklist
- I18n → `docs/I18N_BLUEPRINT.md` (🇻🇳 default · 🇺🇸 · 🇨🇳)
- CI/CD → `docs/GITHUB_CICD_BLUEPRINT.md` (GHCR + runner/VPS)
- Security from initialization → WAF/input guards + WAF/RBAC tests + blocking CI gate; roles `owner`, `security_admin`, `admin`, `operator`, `auditor`, `viewer` → `docs/WAF_SECURITY_BLUEPRINT.md`
- Theme/responsive → full-width page shell/main by default, no centered narrow `max-w-*` + `mx-auto` gutters; `docs/THEME_RESPONSIVE_BLUEPRINT.md` (dark+light, mobile/tablet/laptop/PC)
- Toast/select → `docs/TOAST_SELECT_BLUEPRINT.md`
- Email/auth → `docs/EMAIL_OTP_AUTH_BLUEPRINT.md` (professional email templates + TOTP/email OTP login)
- Install Wizard & Delivery → `docs/INSTALL_WIZARD_BLUEPRINT.md` (khi thay đổi DB bắt buộc đồng bộ AutoMigrate/seed, database/database.sql, install/database.sql, và package-for-delivery.ps1; IsInstalled bảo vệ multi-layer cho production)
- Verify before claiming done
- **Do not fetch upstream skill repos or require another PC’s sample project**

## Modes

- `/ponytail` → one line only
- `/caveman` → compressed speech (code untouched)
