# Admin UI Blueprint (PORTABLE)

> Admin/dashboard/control panel moi dung `docs/REACT_ANTD_ADMIN_BLUEPRINT.md` lam source of truth.
> File nay giu cac quyet dinh UI cap cao va acceptance gate, khong tao mot design system song song voi Ant Design.

## 0. Acceptance gate

- [ ] Khoi tao/port theo `docs/REACT_ANTD_ADMIN_BLUEPRINT.md`.
- [ ] Ant Design theme token la nguon mau/component; custom shell bridge sang shared `--ui-*` tokens.
- [ ] Header + sidebar/mobile drawer + full-width main; menu tu route/quyen; overlay dung shared stacking scale.
- [ ] `/ui-elements` la living design system va `/settings` kiem thu preference/layout/theme.
- [ ] 🇻🇳 `vi-VN` mac dinh + 🇺🇸 `en-US` + 🇨🇳 `zh-CN`; khong hard-code text user-facing.
- [ ] Dark/light/auto + primary color persist, validate/migrate va apply khong flash.
- [ ] Form/picker/searchable select dung Ant Design component dung semantics.
- [ ] Boolean setting dung Switch; checkbox chi cho multi-selection/consent/row selection co nghia.
- [ ] Tabs nghiep vu dung Ant Design `Tabs type="card"`; active initial-load, tab khac lazy-load lan dau.
- [ ] Dataset co Card/Table parity khi ca hai view co gia tri; mot shared `Segmented` tren toolbar, doi view khong refetch.
- [ ] Feedback qua shared AntD message/notification/modal adapter, khong browser defaults; auto-dismiss theo toast blueprint.
- [ ] TanStack Query cho server cache, Zustand cho preference/client state, mot realtime client app-wide.
- [ ] Mobile/tablet/laptop/PC + 2K/4K density, full-width main, local table overflow, accessible controls.
- [ ] Auth production co TOTP/email OTP; backend deny-by-default RBAC; fake API chi dev.
- [ ] `pnpm lint -- --max-warnings=0`, `pnpm typecheck`, `pnpm test -- --run`, `pnpm build` pass.

## 1. Layout va design

- Mac dinh side navigation; cho phep top/two-column/mixed khi yeu cau nghiep vu.
- Header co menu mobile, global search, language, theme/accent, notification va user menu theo scope.
- Main la scroll owner, `width:100%`, `min-width:0`, khong boc toan page trong centered `max-width`.
- Desktop co sidebar; `<1024px` dung drawer. Filter stack tren mobile va mot hang tu tablet/laptop neu du cho.
- `ConfigProvider` + Ant Design algorithm/token dieu khien dark/light, primary color, radius va component surface.
- Custom CSS dung token; khong ep aesthetic terminal, emerald hay bang mau rieng cho moi project.

## 2. Component contract

- Entity picker: `Select showSearch`/`TreeSelect showSearch`; remote list co debounce/loading/empty/cancel.
- Picker: `ColorPicker`, `DatePicker/RangePicker`, `TimePicker/RangePicker`.
- Tables: semantic AntD Table, mot pagination contract, sort/filter/action accessible.
- Feedback: message ngan, notification co context, Alert inline, Result page, Modal confirm cho risk.
- Route tabbar shell va Tabs nghiep vu la hai layer khac nhau; khong dung state chung.
- Scroll-to-top target dung scroll owner; theme, toast, searchable select, responsive va Card/Table chi tiet theo cac blueprint lien quan.

## 3. Lien ket bat buoc

- Nen tang/template: `docs/REACT_ANTD_ADMIN_BLUEPRINT.md`
- I18n: `docs/I18N_BLUEPRINT.md`
- Theme/responsive/stacking/tabs/data views: `docs/THEME_RESPONSIVE_BLUEPRINT.md`
- Feedback/searchable picker: `docs/TOAST_SELECT_BLUEPRINT.md`
- Realtime: `.cursor/rules/13-realtime-background-data.mdc`
- Auth email/OTP: `docs/EMAIL_OTP_AUTH_BLUEPRINT.md`
- Security/RBAC: `docs/WAF_SECURITY_BLUEPRINT.md`
- Final visual gate: `docs/UI_DESIGN_CHECKLIST.md`

Neu bat ky blueprint bat buoc nao thieu, dung va yeu cau chay lai `scripts/install-to-project.ps1`.
