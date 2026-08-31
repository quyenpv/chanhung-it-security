# React Ant Design Admin Template Blueprint (PORTABLE)

> Nguon chuan cho moi project admin noi bo moi. Ban mau goc tren may quan ly:
> `D:\ChanHung_Ltd\App_Project_2026\App_React-antd-admin`.
> File nay ghi lai contract portable; project sau khi cai pack khong duoc phu thuoc duong dan may tren.

## 0. Thu tu uu tien

1. Neu khoi tao project admin React moi va template goc co san: nhan ban template, sau do thay branding/demo data.
2. Neu project da ton tai: port theo kien truc va contract trong file nay; khong ghi de code nghiep vu hoac doi framework hang loat.
3. Neu template goc khong co tren may: file nay + cac blueprint duoc lien ket la du de trien khai; khong clone/fetch repo mau.
4. Version trong `package.json` cua project la nguon phien ban canonical. Khong dong bang version dependency theo file nay; giu lockfile cua template khi nhan ban va nang cap co chu dich.

## 1. Nen tang va lenh gate

Stack chuan cua template tai thoi diem chot:

- React + TypeScript + Vite, package manager `pnpm`.
- Ant Design + `@ant-design/pro-components` cho UI.
- React Router cho route, route guard va metadata menu.
- Zustand `persist` cho UI preference/client state.
- TanStack Query cho server state/cache.
- i18next + react-i18next; Ant Design locale dong bo.
- `ky` cho HTTP; mot realtime client dung chung cho WebSocket/SSE/polling.
- Tailwind utility chi ho tro layout/spacing; Ant Design token la nguon style component.

Gate bat buoc truoc khi giao:

```bash
pnpm install
pnpm lint -- --max-warnings=0
pnpm typecheck
pnpm test -- --run
pnpm build
```

Khi can preview tai root `/`: `pnpm build:local` va `pnpm preview:local`.

Build production khong duoc nhung fake server, khong doc state/build cu, khong commit `.env` hoac secret.

## 2. Cau truc bat buoc

```text
src/
  api/                         typed API theo domain
  components/                  shared UI va provider
  hooks/                       reusable hooks
  layout/                      root/header/sidebar/mobile/content/tabbar/footer
  locales/{vi-VN,en-US,zh-CN}/ catalog tach theo domain
  pages/<module>/              page va component chi dung trong module
  realtime/                    mot client ket noi dung chung
  router/guard/                auth/permission guard
  router/routes/modules/       route tinh cua module
  store/                       auth/access/preferences/tabs
  styles/                      global reset, token bridge, responsive
fake/                          mock API chi cho dev/local preview
tests/                         behavior tests
```

Module moi: tao page, them route module, dat typed API theo domain, dung TanStack Query cho server state, va dua moi text user-facing vao catalog i18n ngay khi tao. Shared component dat trong `src/components`; component rieng nam canh page.

## 3. Shell va dieu huong

- Shell chuan gom header, sidebar/menu, mobile drawer, content, optional route tabbar va footer.
- Ho tro side, top, two-column va mixed navigation neu project can; mac dinh side navigation.
- Desktop co sidebar; duoi `1024px` dung mobile drawer. Main la scroll owner, full available width, `min-width: 0`.
- Menu sinh tu route metadata/quyen; route guard va server authorization phai cung deny-by-default. An menu khong thay the server RBAC.
- Route tabbar cua shell dung cho page dang mo va KeepAlive. Tabs nghiep vu ben trong page la Ant Design `Tabs`; khong tron hai loai state.
- KeepAlive co gioi han va lifecycle ro; subscription/timer chi chay khi page active, cleanup khi inactive/unmount.
- Header co global search, language, theme/accent, notification va user menu khi cac tinh nang nay thuoc scope.

Stacking va overlay theo `docs/THEME_RESPONSIVE_BLUEPRINT.md`. Ant Design `Modal`, `Drawer`, `Dropdown`, `Select`, `Tooltip`, `Popover`, `DatePicker` phai dung portal/container phu hop owner va map z-index vao shared scale; cam arbitrary `9999`.

## 4. Design system: Ant Design la nguon chuan

- `ConfigProvider`/Ant Design theme algorithm va token la source of truth cho component color, radius, typography va control height.
- Bridge token can dung cho shell/custom CSS thanh bien `--ui-*`; khong duy tri mot bang mau terminal/emerald tach roi.
- Dark/light/auto va primary color phai thay doi toan bo Ant Design + custom surface dong bo.
- Navbar co nut theme color de test nhanh; trang Settings co theme, radius, layout, sidebar, tabbar, animation va footer preference khi scope can.
- `src/pages/ui-elements` la living design system: chi chua component mau/usage rules, khong chua logic nghiep vu that.
- Uu tien Ant Design component truoc custom widget: `Form`, `Select showSearch`, `TreeSelect`, `DatePicker`, `TimePicker`, `ColorPicker`, `Table`, `Pagination`, `Tabs`, `Modal`, `Drawer`, `Alert`, `Result`, `message`/`notification` thong qua adapter chung.
- Khong copy CSS noi bo cua Ant Design. Custom CSS chi cho shell, token bridge, composition hoac behavior chua co san.

## 5. Component va nghiep vu UI

### Form va picker

- Dung `Form` + `Form.Item`; validation gan field, tong hop loi co feedback ro.
- Danh sach entity/API hoac >=8 muc: `Select showSearch`, `TreeSelect showSearch` hoac searchable combobox; remote list co debounce, cancel request cu, loading, empty va pagination.
- Mau/ngay/gio dung dung `ColorPicker`, `DatePicker/RangePicker`, `TimePicker/RangePicker`; khong thay bang text input tu do.
- Boolean setting hoac hanh dong bat/tat co hieu luc ngay: `Switch`, label ro va accessible name.
- Checkbox duoc dung cho multi-selection doc lap, agreement/consent va row selection/batch action. Khong dung checkbox de thay cho mot setting on/off; khong dung switch cho chon nhieu record.

### Tabs

- Tabs nghiep vu cung cap dung Ant Design `Tabs`, mac dinh `type="card"`; keyboard/ARIA do AntD cung cap phai duoc giu nguyen.
- Tablist scroll/overflow tren man hep; active tab va panel co quan he ro. Khong tu ve pill/disconnected buttons thay Tabs.
- Du lieu chi initial-load active tab; tab khac lazy-load lan dau, deduplicate request va giu page-session/query cache. Realtime/invalidation van duoc phep cap nhat cache.

### Data display

- Moi dataset co Card va Table view neu ca hai cach doc co gia tri. Mot `Segmented` Card/Table nam tren toolbar chung, dung chung query/cache/filter/sort/pagination/selection/permission/realtime state; doi view khong refetch.
- Ant Design `Table` la chuan cho du lieu tabular, pagination duy nhat, responsive horizontal scroll/sticky columns khi can.
- Row checkbox chi hien khi co batch action that va Table `rowSelection` co label/a11y phu hop. Card view khong bat buoc checkbox neu khong co batch action; neu co batch action, Card phai co selection parity.
- Search/export/action, loading/empty/error va total count phai dong nhat giua Card/Table.

### Feedback

- Dung mot adapter chung bao quanh Ant Design `App` message/notification/modal API; khong goi static API rai rac, `alert`, `confirm`, `prompt`.
- `message` cho feedback ngan; `notification` cho noi dung can nhieu context/action; `Alert` cho noi dung trong luong; `Result` cho trang thai toan trang; `Modal.confirm` cho hanh dong nguy hiem.
- Neu auto-dismiss, adapter phai dap ung progress/pause/accessibility contract trong `docs/TOAST_SELECT_BLUEPRINT.md`; khong mac dinh rang API thu vien da dap ung.

## 6. Preference, theme va i18n

- Mot Zustand persisted preference store la adapter canonical cho theme, primary color, locale, navigation/sidebar va preference shell.
- Namespace storage theo app; schema co `version` + `migrate`. Validate persisted value va chi fallback khi khong hop le.
- Locale canonical: `vi-VN` mac dinh, `en-US`, `zh-CN`; dong bo i18next, `document.documentElement.lang` va Ant Design locale. Switcher hien 🇻🇳 Tiếng Việt, 🇺🇸 English, 🇨🇳 中文.
- Apply preference truoc frame dau tien hoac dung bootstrap/hydration strategy khong flash/reset. Migration khong duoc vo dieu kien ghi de locale/theme hop le cua nguoi dung.
- User-facing strings trong page, UI Elements va demo duoc giu lai phai i18n.

## 7. Data, realtime va quyen

- TanStack Query quan ly fetch/cache/invalidation; request layer typed, co refresh-token coordination va error mapping.
- Mot realtime client app-wide; reconnect co backoff + jitter, re-auth/resubscribe va reconcile/invalidate cache sau reconnect.
- Khong `window.onload`, full-page reload hoac yeu cau user refresh de co data moi.
- UI access control chi la presentation; backend phai enforce role/permission. Seed roles theo `docs/WAF_SECURITY_BLUEPRINT.md`.
- Authenticated project phai ghep password/code screen cua template voi TOTP hoac email OTP that theo `docs/EMAIL_OTP_AUTH_BLUEPRINT.md`; demo password/code API khong duoc coi la production auth.

## 8. Khoi tao project tu template

Khi duoc phep tao project moi tu template:

1. Copy source co kiem soat, bo `.git`, `node_modules`, `dist/build`, `.env`, log/cache va artifact local.
2. Giu `pnpm-lock.yaml`, build scripts, provider, layout, router, preference, locales, UI Elements va Settings lam baseline.
3. Doi package name, app namespace, title, logo, company, copyright, API base URL qua config/env; xoa credential/demo account hard-coded.
4. Chon frontend-route hoac backend-route authority theo backend thuc; khong bat ca hai tuy tien.
5. Fake server chi dev; production build va Docker image khong mang fake endpoints.
6. Them WAF/RBAC/security CI va OTP/email baseline truoc feature deployable dau tien.
7. Chay toan bo gate muc 1 va visual matrix cua `docs/UI_DESIGN_CHECKLIST.md`.

## 9. Acceptance gate

- [ ] Project moi co provenance tu template hoac document ly do port vao app hien huu.
- [ ] Kien truc route/layout/store/query/i18n khong bi thay bang mot stack song song.
- [ ] `/ui-elements` va `/settings` con hoat dong, phan anh component/theme dang dung.
- [ ] `vi-VN` la mac dinh; en-US/zh-CN day du va AntD locale dong bo.
- [ ] Dark/light/auto, primary color va preference persist khong flash/reset.
- [ ] Mobile/tablet/laptop/PC, full-width main, overlay va scroll owner dung.
- [ ] Checkbox/Switch dung dung semantics; Tabs dung AntD card; Card/Table parity dat.
- [ ] Query cache, realtime reconnect va KeepAlive lifecycle khong tao duplicate work.
- [ ] Auth production co TOTP/email OTP; RBAC server-side; fake API khong vao production.
- [ ] Lint, typecheck, test, build deu pass; khong secret/artifact local trong source.
