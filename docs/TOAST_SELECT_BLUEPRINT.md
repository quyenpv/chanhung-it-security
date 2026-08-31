# Toast / Notification + Searchable Select Blueprint (PORTABLE)

> Di kem pack. Agent **MUST** doc khi lam feedback UI hoac form chon doi tuong tu danh sach.  
> Khong can repo mau tren may.

## 0. Acceptance gate

```
[ ] Co he thong toast/notification dung chung (khong alert() native cho UX chinh)
[ ] Toast: success / info / warning / error (hoac mapping tuong duong)
[ ] Toast theo dark+light token; accent/severity mau dung var(--ui-*)
[ ] Moi toast auto-dismiss co progress bar dem nguoc dong bo chinh xac voi remaining time; hover/focus/interaction pause ca timer va bar, resume khong reset
[ ] Toast persistent khong gia progress; co nut dong/action ro rang; stack nhieu toast khong de len nhau vo han
[ ] Toast dung visual contract muc 1: surface/border/shadow/spacing/type/icon/motion/responsive/accessibility thong nhat, khong dung style mac dinh cua browser/library
[ ] Toast viewport la direct child cua body, fixed + --z-toast, top offset nam duoi header/navbar; khong bi header che va khong nam trong app-shell stacking context
[ ] Noi dung toast i18n (vi/en/zh); escape HTML neu co data dong
[ ] Chon doi tuong tu danh sach (>= ~8 muc HOAC data tu API/DB): Select2 hoac tuong duong CO TIM KIEM
[ ] Select thuong (<select> native / dropdown khong search) CHI cho enum ngan co dinh (vd 2-7 muc)
[ ] Searchable select: dark/light, keyboard, clear, loading, empty state
[ ] Mobile: dropdown search van dung duoc (touch, khong truncated vo hinh)
[ ] Dropdown dung layer theo owner: page/header=`--z-header-popover`, drawer=`--z-drawer-popover`, modal=`--z-modal-popover`; khong bi cat/chim
```

---

## 1. Toast / Notification (bat buoc)

### Khi nao MUST dung toast

| Su kien | Toast? |
|---------|--------|
| CRUD thanh cong / that bai | MUST |
| Copy / export / deploy / sync xong | MUST |
| Validation form (loi tong hop) | MUST (hoac inline + toast error) |
| WAF/block/permission denied tu API | MUST error |
| Realtime alert (server down, mitigation) | MUST neu product co alert |
| Confirm huy hanh dong nguy hiem | Dung modal confirm; toast sau khi xong |

**FORBIDDEN:** `window.alert`, `confirm`, `prompt` cho UX san pham (tru debug dev tam thoi).

### API goi y (portable)

```js
toast.success(message, { title?, durationMs? })
toast.info(message, { title?, durationMs? })
toast.warning(message, { title?, durationMs? })
toast.error(message, { title?, durationMs? })
```

### UX rules

1. Vi tri mac dinh: **top-right** (LTR) hoac top-center tren mobile neu hep.
2. Duration mac dinh: success/info ~4–5s; warning/error ~6–8s. Error nghiem trong co the persistent den khi user dong/action.
3. **Progress bat buoc cho moi toast auto-dismiss:** bar phai the hien remaining time thuc, bat dau day va giam deu ve 0 dung luc toast dong.
4. Timer va progress phai dung **cung mot monotonic deadline/remaining-time state**; cam dung mot `setTimeout` de dong va mot CSS duration doc lap de ve bar vi se drift.
5. Hover, `focus-within`, pointer down/interaction, hoac focus bang ban phim phai pause ca dismissal va progress; resume tiep tuc phan thoi gian con lai, khong restart full duration.
6. Toast persistent khong hien progress gia/vo han; phai co nut close hoac action ro rang.
7. Toi da ~3–5 toast hien thi; moi hon thi queue / thay the cu.
8. Mau:
   - success → `--ui-success` / accent emerald
   - warning → `--ui-warning`
   - error → `--ui-danger`
   - info → `--ui-accent` hoac blue token
9. Dark + light day du (border/surface/text).
10. `role="status"` (info/success) / `role="alert"` (warning/error); co nut close co accessible name.
11. Khong spam: debounce cung mot message trong khoang ngan.

### Visual contract — bat buoc, source of truth

**Container**

- Render qua shared toast portal la **direct child cua `body`**, khong mount ben trong header, app shell, main scroll container, modal root, hay bat ky ancestor tao stacking context.
- Toast viewport bat buoc `position: fixed; z-index: var(--z-toast); pointer-events: none`; tung toast/action dat lai `pointer-events: auto`.
- Shell phai expose chieu cao navbar/header dang hien thi qua `--ui-header-height` (cap nhat theo responsive/collapse). Toast dung `--ui-toast-gap` lam khoang cach an toan.
- Desktop co header: top-right va `top: calc(env(safe-area-inset-top) + var(--ui-header-height, 0px) + var(--ui-toast-gap, 12px))`; khong co header thi dat `--ui-header-height: 0px`. Width `min(380px, calc(100vw - 32px))`; gap 10–12px.
- Mobile `<640px`: top-center, cung header offset, cach hai ben 12–16px, width auto/full available; ton trong safe-area inset.
- Toi da 3–5 toast visible; toast moi vao theo mot chieu nhat quan, khong che navigation quan trong.

```css
:root {
  --ui-header-height: 0px; /* shell co header MUST override bang chieu cao thuc */
  --ui-toast-gap: 12px;
}

.toast-viewport {
  position: fixed;
  top: calc(env(safe-area-inset-top) + var(--ui-header-height) + var(--ui-toast-gap));
  right: max(16px, env(safe-area-inset-right));
  z-index: var(--z-toast);
  width: min(380px, calc(100vw - 32px));
  pointer-events: none;
}

.toast-viewport > * { pointer-events: auto; }
```

Neu header height thay doi theo breakpoint, resize, banner, collapse, hoac dynamic content, shell phai cap nhat token bang CSS responsive hoac `ResizeObserver`; cam hard-code mot offset chi dung cho desktop.

**Toast card**

- Layout grid/flex: severity icon 20–24px | content `min-width:0` | close button; progress nam sat day card.
- Padding noi dung 14–16px; gap 10–12px; radius 10–14px; border 1px; shadow mem, khong glow/neon.
- Surface/text/border chi dung theme tokens: `--ui-surface`, `--ui-text`, `--ui-text-dim`, `--ui-border`; neu project co toast-specific token thi map ve cac token nay.
- Title 14–15px, weight 600–700, line-height ~1.3; message 13–14px, line-height ~1.45, toi da 3–4 dong truoc khi wrap/expand hop ly.
- Icon dung SVG/icon system dong bo, khong emoji trang tri. Severity color chi danh cho icon, accent edge/progress va action; khong phu toan card bang mau bao hoa.
- Close button co focus ring ro, accessible name, target toi thieu 36px desktop va 44px mobile/touch.

**Severity mapping**

| Type | Icon | Color token | ARIA |
|------|------|-------------|------|
| success | check-circle | `--ui-success` | `role="status"` |
| info | info-circle | `--ui-accent` | `role="status"` |
| warning | warning-triangle | `--ui-warning` | `role="alert"` |
| error | error-circle | `--ui-danger` | `role="alert"` |

**Progress bar**

- Track cao 3–4px, full width sat day, background theo border/surface-soft; fill dung severity token tuong ung.
- Fill cap nhat bang `transform: scaleX(progress)` voi `transform-origin: left` (LTR), tranh animate width gay layout/reflow.
- Chuyen dong linear theo remaining time; pause/resume khong giat, khong quay ve 100%.
- Khi duration thay doi hoac tab browser bi background, tinh lai tu monotonic deadline de bar va dismissal van dong bo.

**Motion**

- Enter 180–240ms: opacity + translate 8–12px; exit 140–200ms, ngan hon enter. Khong bounce/rotate/scale qua da.
- Stack reposition mượt 160–220ms; khong lam nhay layout trang vi container fixed/portal.
- `prefers-reduced-motion: reduce`: bo translate/stack motion, dung opacity ngan hoac no-motion; countdown van cap nhat accessible va dismissal van chinh xac.

**FORBIDDEN:** toast library/browser default style; progress optional cho auto-dismiss; progress gia cho persistent toast; timer va bar chay hai clock; mau neon/gradient/glow qua muc; close target qua nho; toast che het chieu ngang mobile; mount toast viewport trong app shell/header/main; `top: 0` khi co header; header/navbar co layer bang/cao hon `--z-toast`; arbitrary `z-index: 9999`.

### Acceptance toast

1. Tao success/info/warning/error o dark va light: cung layout, dung severity token, contrast ro va khong lo style mac dinh library.
2. Voi duration test 5 giay, progress ve 0 cung luc toast dong; sai lech quan sat khong dang ke.
3. Hover va tab-focus giua countdown: timer + bar dung; blur/leave: tiep tuc remaining time, khong reset.
4. Toast persistent: khong progress, khong auto-close, close/action dung keyboard va screen reader.
5. Test stack 5 toast desktop/mobile, safe area, text dai 3 ngon ngu, reduced motion va `--z-toast` tren modal-popover.
6. Mo toast khi header/navbar dang hien thi va khi scroll: toan bo card + progress nam duoi day header voi gap 8–16px, khong co pixel nao bi che; DevTools xac minh portal la direct child cua `body` va computed z-index cao hon header.
7. Doi breakpoint/collapse/header height: toast offset cap nhat theo chieu cao thuc, khong de khoang trong sai va khong chong len navbar.

### Notification center (neu co chuong/bell)

- Badge dem chua doc; danh sach lich su; mark read
- Khong thay the toast realtime — toast = ephemeral, center = history

---

## 2. Searchable select — Select2 hoac tuong duong (bat buoc)

### Khi nao BAT BUOC co tim kiem

Dung **Select2**, **Tom Select**, **Choices.js**, **react-select**, **Downshift+combobox**, **Headless UI Combobox**, Ant Design `Select showSearch`, v.v. khi:

- Chon **doi tuong** tu danh sach: user, server, host, VM, group, role, tenant, product, IP, country, tag, …
- So luong option **>= 8**, HOAC danh sach lay tu API/DB (co the lon dan)
- Multi-select danh sach doi tuong
- Can typeahead / remote search (ajax)

### Khi nao duoc dung `<select>` native / dropdown thuong

Chi khi:

- Enum co dinh **rat ngan** (khoang **2–7** muc): theme dark/light, status all/online/offline, yes/no, sort order, …
- Khong phai “chon 1 ban ghi trong catalog”

### FORBIDDEN

- `<select>` dai hang chuc/tram server/user ma khong search
- Custom dropdown chi click, khong go loc duoc
- Autocomplete browser thuan cho chon entity business (thieu a11y/empty/loading)

### Searchable select — yeu cau toi thieu

| Capability | Required |
|------------|----------|
| Type to filter (client) | YES |
| Remote/ajax search neu list lon | YES khi API phan trang |
| Clear selection | YES (tru field bat buoc khong clear) |
| Keyboard (arrow, enter, escape) | YES |
| Loading + “no results” | YES |
| Multi-select + chip/tag (neu multi) | YES |
| Dark / light theme | YES (token) |
| i18n placeholder (“Tim kiem…”) | YES vi/en/zh |
| Disabled / readOnly state | YES |

### Pattern (y tuong)

```html
<!-- BAD: doi tuong nhieu -->
<select name="serverId">...</select>

<!-- GOOD: Select2 / equivalent -->
<select name="serverId" data-control="select2" data-placeholder="Tim server..."></select>
```

React vi du tuong duong: `react-select` / combobox voi `filterOption` + async `loadOptions`.

### Styling

- Border/surface theo `--ui-border` / `--ui-surface`
- Highlight option: `--ui-accent`
- Dropdown/listbox dung shared scope-aware tokens tu `docs/THEME_RESPONSIVE_BLUEPRINT.md`: page/header=`--z-header-popover`, drawer=`--z-drawer-popover`, modal=`--z-modal-popover`. Menu phai nam tren owning surface, khong bi ancestor overflow/stacking context cat; khi portal vao overlay root van giu layer scope cua owner
- Mobilе: menu khong bi cat; full-width hop ly

---

## 3. Agent procedure

1. Form/action co feedback → wire toast (muc 1)
2. Field chon entity/list → searchable select (muc 2); enum ngan moi dung select thuong
3. Pass gate muc 0
4. Thieu blueprint → bao cai pack
