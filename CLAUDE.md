# CLAUDE.md — GreenCould Mandatory Rules

This repo uses the **self-contained** GreenCould rules pack.

Follow `AGENTS.md` and `.cursor/rules/*.mdc` only.

## Non-negotiables

- Plan → implement → verify for non-trivial work
- Systematic debugging before patches
- Answer first; no fluff
- Admin UI = canonical React Ant Design template architecture in `docs/REACT_ANTD_ADMIN_BLUEPRINT.md` + rule `03`
- Marketing UI = `04-frontend-design` (anti-slop)
- I18n: 🇻🇳 Tiếng Việt (default) · 🇺🇸 English · 🇨🇳 中文 with flags (`08` + `docs/I18N_BLUEPRINT.md`)
- Admin UI: follow `docs/REACT_ANTD_ADMIN_BLUEPRINT.md` + `docs/ADMIN_UI_BLUEPRINT.md` in this project; use Ant Design tokens, not a parallel aesthetic
- CI/CD: follow `docs/GITHUB_CICD_BLUEPRINT.md` — build→GHCR→self-hosted runner and/or VPS SSH; runner as OS service
- Security from initialization: create WAF/input guards, automated WAF/RBAC tests and a blocking CI gate; seed server-enforced `owner`, `security_admin`, `admin`, `operator`, `auditor`, `viewer`. Follow `docs/WAF_SECURITY_BLUEPRINT.md`.
- Theme/responsive: follow `docs/THEME_RESPONSIVE_BLUEPRINT.md` — page shell/main full width by default, không co cụm giữa bằng `max-w-*` + `mx-auto`; mọi component dark+light + mobile/tablet/laptop/PC
- Toast/select: follow `docs/TOAST_SELECT_BLUEPRINT.md` — toast (không alert); Select2/searchable cho list đối tượng
- Email/auth: follow `docs/EMAIL_OTP_AUTH_BLUEPRINT.md` — transactional HTML + text templates; login uses authenticator TOTP or email OTP
- **Install Wizard & Database Sync**: follow `docs/INSTALL_WIZARD_BLUEPRINT.md` — khi cập nhật database/models, bắt buộc đồng bộ Controller cài đặt (AutoMigrate & seed), schema SQL rỗng `database/database.sql`, `install/database.sql` và script `scripts/package-for-delivery.ps1`.
- Never commit secrets
- **Never fetch the original 22 skill repos** — this pack already encodes the mandatory rules
