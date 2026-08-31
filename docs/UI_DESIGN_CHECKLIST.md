# UI Design Checklist (PORTABLE — mọi loại UI)

Agent chạy checklist này trước khi báo “UI xong”. Tất cả nằm trong pack — không cần máy có project mẫu.

## A. Mọi UI

- [ ] I18n: `docs/I18N_BLUEPRINT.md` đã áp dụng (🇻🇳 mặc định, 🇺🇸, 🇨🇳)
- [ ] Không hard-code user-facing strings
- [ ] Focus states visible
- [ ] No secret/PII in client logs
- [ ] **Full width:** không co cụm giữa với 2 bên trống lớn (cấm `max-w-*` + `mx-auto` trên page shell)
- [ ] **Scrollbar:** thumb theo accent đang chọn (`var(--ui-accent)`), đổi khi đổi accent
- [ ] **Dark + Light:** mọi component đủ style cả 2 mode qua token (`docs/THEME_RESPONSIVE_BLUEPRINT.md`)
- [ ] **Pre-paint persistence:** theme + accent + locale doc qua cung canonical adapter; full refresh frame dau dung ngay gia tri da luu, khong flash/hydration mismatch
- [ ] **Responsive:** mobile `<768` · tablet `768–1023` · laptop `1024–1439` · PC `≥1440`
- [ ] Matrix smoke: Mobile/Tablet/Laptop/PC × Dark/Light
- [ ] **Toast:** shared visual contract, dark/light, severity icon/token, responsive portal `--z-toast`; không browser/library default và không `alert()`
- [ ] **Toast countdown:** mọi auto-dismiss toast có progress đồng bộ cùng remaining-time clock; hover/focus/interaction pause cả bar + timer, resume không reset; persistent toast không có progress giả
- [ ] **Toast/header:** viewport portal trực tiếp dưới `body`, fixed `--z-toast`, computed layer cao hơn navbar nhưng top offset nằm dưới chiều cao header + gap; scroll/resize/mobile không bị header che
- [ ] **Select:** chọn đối tượng/list dài → Select2 hoặc tương đương có search; enum ngắn mới dùng `<select>` thường
- [ ] **Đúng semantics:** setting bật/tắt dùng Switch; checkbox chỉ cho multi-selection, consent/agreement hoặc row selection có batch action; đều có label/trạng thái accessible
- [ ] **Stacking:** dung shared scope-aware tokens; header/drawer/modal popover noi tren owning surface, khong bi ancestor `overflow`/stacking context cat; portal van giu dung owner scope
- [ ] **Tabbed data:** page boot chi initial-load active tab; tab khac load khi mo lan dau; rapid activation khong tao request trung
- [ ] **Background freshness:** reopen tab khong lap initial snapshot/skeleton, nhung polling/subscription/invalidation/reconnect van cap nhat cache tai cho
- [ ] **Tab visual:** React admin dùng Ant Design `Tabs type="card"`; stack khác dùng rail nối panel tương đương; không pill/disconnected/ad-hoc style
- [ ] **Tab a11y/responsive:** tablist/tab/tabpanel + aria mapping + roving tabindex + Arrow/Home/End; mobile scroll ngang khong wrap/overflow page, active tab duoc dua vao view
- [ ] **Scroll to top:** shared accessible button co o moi UI project; threshold show/hide, target dung scroll owner, current accent/hover/focus, dark/light, reduced-motion, safe-area/bottom-nav va layer collision deu dat
- [ ] **Card/Table:** moi collection co ca hai views; moi data-tab group chi 1 segmented control ben phai cung row tablist, khong per-tab/panel; mode giu khi doi tab, cung cache/filter/sort/selection/pagination/realtime va switch khong request/reset/reload

## B. Admin / Dashboard / Control panel

- [ ] Follow `docs/REACT_ANTD_ADMIN_BLUEPRINT.md` + `docs/ADMIN_UI_BLUEPRINT.md` end-to-end
- [ ] `/ui-elements` phản ánh component contract và `/settings` kiểm thử theme/layout/preferences đang ship
- [ ] Ant Design token là source of truth cho component; custom shell CSS chỉ dùng token bridge/shared variables
- [ ] Persisted theme/primary color hợp lệ thắng fallback ngay first paint; migration không reset lựa chọn
- [ ] Filter bar not vertically broken on `md+`
- [ ] `tabular-nums` on live numbers
- [ ] XSS-safe dynamic text
- [ ] Main sau sidebar = `flex:1; width:100%; max-width:none`
- [ ] Scrollbar webkit + `scrollbar-color` dùng `--ui-accent` / `--ui-accent-hover`
- [ ] Sidebar drawer trên tablet/mobile; fixed trên laptop/PC
- [ ] Toast cho CRUD/API; searchable select cho server/user/group/…
- [ ] Mo header/navbar dropdown tren card, sticky table, chart/map va khi scroll: menu van hien tron ven
- [ ] Mo picker trong drawer va modal: menu nam tren owner; toast van tren cung; khong `z-index: 9999`

## C. Marketing / Landing

- [ ] Follow `.cursor/rules/04-frontend-design.mdc`
- [ ] One hero composition (brand + 1 headline + 1 support + CTA + 1 visual)
- [ ] No purple-gradient / Inter-display AI slop
- [ ] No hero overlay badges
- [ ] 2–3 intentional motions max (`05-motion-video`)
- [ ] Copy humanized (`07-marketing-content`)
- [ ] Hero / sections full-bleed where required; không co cụm shell giữa màn
- [ ] Scrollbar theo accent nếu site có accent token
- [ ] Dark + light đủ cho mọi section/component
- [ ] Mobile + tablet + laptop + PC đều usable

## D. Nếu thiếu blueprint trong project

1. Báo user: pack chưa được cài đủ.
2. Chỉ dẫn: chạy `greencould-skill-agent/scripts/install-to-project.ps1`.
3. **Không** bịa design system khác.

## E. GitHub / VPS / runner

- [ ] Follow `docs/GITHUB_CICD_BLUEPRINT.md`
- [ ] Build on `ubuntu-latest` → push GHCR → deploy on server
- [ ] Self-hosted runner as OS service (auto-start) **or** VPS SSH secrets set
- [ ] No secrets in git; `.env.docker` stays on server
- [ ] Empty CI env vars stripped before compose
- [ ] Healthcheck after deploy

## F. WAF / security filters

- [ ] Security baseline được tạo từ đầu project, không chờ đến khi có sự cố/file WAF
- [ ] Follow `docs/WAF_SECURITY_BLUEPRINT.md`
- [ ] Normalize before match; scan path/query/body/dangerous headers
- [ ] BLOCK categories tối thiểu đủ (SQLi, XSS, LFI, CMDi, CRLF, SSRF, XXE, SSTI, NoSQL, LDAP, Open Redirect)
- [ ] Whitelist tối thiểu (không whitelist cả `/api`)
- [ ] Rate-limit + auto IP block có expiry + audit
- [ ] Payload tests → 403 `WAF_BLOCK`
- [ ] Roles `owner`, `security_admin`, `admin`, `operator`, `auditor`, `viewer` được enforce server-side và có deny tests
- [ ] Canonical security-check command chạy bắt buộc trong CI; lỗi/skip chặn deploy
