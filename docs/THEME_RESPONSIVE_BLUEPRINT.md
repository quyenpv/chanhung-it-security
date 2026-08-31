# Theme + Responsive Blueprint (PORTABLE)

> Di kem pack. Agent **MUST** doc khi lam bat ky UI/component.  
> Moi thanh phan **MUST** ho tro day du **dark + light** va **responsive**: mobile, tablet, laptop, PC/desktop.

## 0. Acceptance gate

```
[ ] Moi component dung token theme (khong hard-code mau chi dung cho 1 mode)
[ ] Doi data-theme / class dark|light -> toan bo UI doi (bg, text, border, input, modal, table, chart, toast)
[ ] Light mode: contrast chu/nen dat AA; khong "dark styles bi lo" (chu trang tren nen sang)
[ ] Dark mode: khong chu den tren nen toi; border/divider van nhin thay
[ ] Theme toggle (hoac inherit system + override) + persist qua canonical namespaced preference adapter
[ ] Project khai bao mot persistence adapter + precedence ro rang; truoc first paint theme duoc doc tu canonical source (cookie cho SSR hoac synchronous client storage cho client-only app)
[ ] Toggle va initializer cung doc/ghi mot theme key; system/default chi la fallback khi chua co lua chon da luu
[ ] Truoc first paint, mau/accent da chon duoc doc qua cung persistence adapter va gan vao root/CSS variables; refresh khong hien mau mac dinh roi moi tra lai mau da chon
[ ] Color picker va initializer cung doc/ghi mot color key; mau mac dinh chi la fallback khi chua co gia tri da luu
[ ] Viewport meta co width=device-width
[ ] Page shell/main/section full width by default; khong dung centered narrow `max-w-*` + `mx-auto` tren toan trang lam du 2 ben
[ ] Mobile <768: layout 1 cot, touch target >=44px, khong overflow ngang page
[ ] Tablet 768-1023: 2 cot / drawer nav hop ly
[ ] Laptop 1024-1439: shell day du, sidebar co the collapse
[ ] PC >=1440 (va 2K/4K neu admin): grid/table stretch full width
[ ] Khong ship component "desktop-only" ma khong co fallback mobile
[ ] Navbar/header va floating UI dung scope-aware layer tokens: header-popover, drawer-popover, modal-popover; menu nam tren owning surface va khong bi overflow/stacking context cat hoặc chim
[ ] Moi UI project co shared scroll-to-top button: chi hien sau meaningful scroll, dung current accent tokens, safe-area/bottom-nav aware, keyboard + reduced-motion OK
[ ] Moi collection/dataset co ca Card + Table views; trong data-tab group chi co 1 shared switch nam ben phai cung dong voi tablist, khong lap trong tung panel; switch chi doi presentation va khong fetch lai
```

## 1. Dark / Light — bat buoc cho MOI component

### Nguon mau duy nhat

- Tat ca mau qua CSS variables (hoac theme tokens framework tuong duong).
- Bat theme bang `html[data-theme="dark|light"]` **hoac** class `.dark` tren root — chon 1 he, dung nhat project.
- React admin: Ant Design `ConfigProvider`/theme token la source of truth; expose token bridge `--ui-*` cho custom shell CSS theo `docs/REACT_ANTD_ADMIN_BLUEPRINT.md`.

### Khoi tao va persist theme — bat buoc

1. Project phai khai bao **mot canonical persistence adapter** cho lua chon UI. SSR/SSR-hybrid dung cookie doc duoc tren server de bootstrap; client-only app co the dung synchronous client storage. Toggle va startup initializer phai dung cung adapter, key va quy uoc gia tri.
2. Doc gia tri persist va gan `data-theme`/class root **truoc first paint** (SSR/server layout, inline bootstrap script an toan, hoac co che pre-hydration tuong duong) de tranh flash/jump sai theme.
3. Chi khi cookie/bien persist khong ton tai moi duoc fallback sang `prefers-color-scheme`; project default chi dung khi ca hai nguon tren khong xac dinh duoc theme.
4. Refresh, dieu huong, hydrate, remount component, reconnect, hay fetch data khong duoc reset hoac ghi de theme nguoi dung da luu.
5. Ap dung cung quy trinh cho mau/accent nguoi dung chon: doc gia tri persist da validate va gan root attribute/CSS variables truoc first paint; chi fallback mau mac dinh khi khong co gia tri da luu.
6. Neu theme va accent luu rieng, phai khoi tao ca hai trong cung bootstrap truoc paint; khong cho phep mot gia tri dung trong khi gia tri con lai bi flash ve mac dinh.
7. Neu bat buoc mirror cookie va client storage, phai document precedence; cookie/bootstrap authority thang trong first paint, sau do adapter dong bo atomic. Cam moi component tu doc tung store va tu quyet dinh gia tri.

**FORBIDDEN:**

- Hard-code `light`/`dark` lam theme khoi tao ma khong doc cookie/bien persist.
- Gan theme co dinh trong mount effect, layout, middleware, template, hoac script roi ghi de lua chon da luu.
- Render theme mac dinh truoc, sau do moi doc persist trong effect lam UI flash/nhay theme khi refresh.
- Dung key/nguon luu khac nhau giua toggle va startup initializer.
- Hard-code/reset `data-accent`, CSS accent variables, hoac mau tuy chon khi startup/hydration ma khong doc gia tri persist truoc.
- Render mau mac dinh truoc roi moi khoi phuc mau da chon trong mount effect, gay flash/nhay mau khi refresh.
- Ghi de mot gia tri mau persist hop le bang default trong qua trinh bootstrap.
- Doc cookie va client storage doc lap ma khong co precedence, gay server/client chon hai gia tri khac nhau hoac hydration mismatch.

### Component checklist (moi UI piece)

| Surface | Dark + Light MUST cover |
|---------|-------------------------|
| Page / section bg | `--ui-bg` / panel |
| Card / modal / dropdown | surface + border |
| Text / heading / muted | `--ui-text` / `--ui-text-dim` |
| Input / select / textarea | bg, border, placeholder, focus ring |
| Table header / row hover | surface-2 + hover token |
| Button primary | accent (ok shared) + text contrast ca 2 mode |
| Button ghost/secondary | khong dung mau chi hop 1 mode |
| Divider / skeleton | border-soft |
| Chart / map / canvas | palette theo theme hoac CSS var |
| Shadow / overlay | opacity phu hop ca 2 mode |
| Scrollbar | `var(--ui-accent)` (da bat buoc rieng) |
| Tabs | active/inactive/hover/focus + panel seam theo muc Tabs |
| Scroll-to-top | current accent + contrast + hover/focus + disabled/hidden state |
| Card/Table view | segmented control + two complete responsive renderers sharing one data state |

### FORBIDDEN

- `bg-white text-black` co dinh trong component shared (pha dark)
- `bg-slate-900 text-white` co dinh (pha light)
- `dark:` utilities **mot nua** (chi style dark, light vo tinh vo chu)
- Anh/icon chi nhin ro 1 mode (thieu variant hoac filter)
- Inline `style={{ color: '#fff' }}` cho text UI

### REQUIRED pattern

```css
.card {
  background: var(--ui-surface);
  color: var(--ui-text);
  border: 1px solid var(--ui-border);
}
.input {
  background: var(--ui-bg-panel);
  color: var(--ui-text);
  border: 1px solid var(--ui-border);
}
.input::placeholder { color: var(--ui-text-dim); }
```

Tailwind: uu tien `bg-[var(--ui-surface)] text-[var(--ui-text)]` (hoac map vao theme config), khong hard-code slate/zinc cho ca 2 mode.

### Tabs visual contract — bat buoc, source of truth

**React Ant Design admin:** dung `Tabs type="card"` lam implementation chuan va giu nguyen DOM/ARIA/keyboard behavior cua Ant Design. Token-override de dat surface/accent/contrast; khong thay DOM AntD bang CSS/HTML mau ben duoi. Route tabbar cua shell la mot concern rieng. Cac stack khac dung contract portable ben duoi.

Ap dung cho business/settings/data tabs va tab trong card/modal. Hinh tham chieu duoc chuan hoa thanh mot component token-based, khong copy mau/size hard-code.

**Cau truc va hinh dang**

- Mot `.tabs-shell` chua tab rail va **mot panel surface chung**. Rail nam sat canh tren panel; active tab va panel phai nhin nhu mot khoi lien mach.
- Rail la hang ngang, `display:flex`, can day trai; gap 8–20px tuy density. Tab co chieu cao dong nhat 42–48px, padding ngang 18–28px, `min-width` hop ly, label can giua.
- Tab co bo goc tren 10–12px; hai goc duoi vuong/gan vuong de noi voi panel. Cam pill full-radius, cac nut roi rac, kich thuoc active/inactive khac nhau, hoac moi tab mot style.
- Panel co `background: var(--ui-surface)`, border theme token, radius duoi 10–12px, padding responsive 16–24px; khong lap border-top ben duoi active tab.
- Mot accent seam 2px chay o canh tren panel/duoi rail. Active tab che dung doan seam cua no va noi lien vao panel, khong de khe 1px, double border hoac tab noi lung chung.

**State contract**

- Active: background `--ui-accent`, text co contrast AA, border accent; label weight 600–700. Co the dung accent-hover/subtle gradient rat nhe neu design system da co token, cam gradient tuy y.
- Inactive: `--ui-bg-panel`/`--ui-surface-2`, text `--ui-text-dim`, border `--ui-border`; hover tang contrast nhe, khong bien thanh active gia.
- Focus-visible: ring 2px bang `--ui-accent`, co offset ro va khong bi container cat.
- Disabled: opacity/giam contrast co kiem soat, `aria-disabled="true"`, khong clickable; khong chi dung mau de bieu thi state.
- Motion: color/background/border 150–220ms; panel content co the fade 120–180ms. Cam layout shift, bounce, slide dai hoac animate chieu cao lam trang nhay.

```css
.tabs-shell {
  --tabs-line: 2px;
}
.tabs-list {
  display: flex;
  align-items: end;
  gap: 12px;
  overflow-x: auto;
  border-bottom: var(--tabs-line) solid var(--ui-accent);
  scrollbar-width: thin;
}
.tabs-list [role="tab"] {
  flex: 0 0 auto;
  min-height: 44px;
  padding: 0 22px;
  border: 1px solid var(--ui-border);
  border-bottom: 0;
  border-radius: 11px 11px 0 0;
  background: var(--ui-bg-panel);
  color: var(--ui-text-dim);
}
.tabs-list [role="tab"][aria-selected="true"] {
  background: var(--ui-accent);
  color: var(--ui-accent-contrast, #fff);
  border-color: var(--ui-accent);
}
.tabs-panel {
  padding: clamp(16px, 2vw, 24px);
  border: 1px solid var(--ui-border);
  border-top: 0;
  border-radius: 0 0 11px 11px;
  background: var(--ui-surface);
  color: var(--ui-text);
}
```

**Semantic + interaction bat buoc**

```html
<div class="tabs-shell">
  <ul class="tabs-list" role="tablist" aria-label="..."><li role="presentation"><button role="tab" id="tab-a" aria-selected="true" aria-controls="panel-a" tabindex="0">...</button></li></ul>
  <section class="tabs-panel" role="tabpanel" id="panel-a" aria-labelledby="tab-a">...</section>
</div>
```

- `ul > li > button` (hoac semantic tuong duong cua framework); cam click handler tren `li` khong focus/keyboard duoc.
- Dung **roving tabindex**: chi active tab co `tabindex="0"`; tab con lai `-1`. Ho tro Left/Right, Home/End; Enter/Space neu activation la manual.
- Moi tab/panel co cap ID duy nhat qua `aria-controls` + `aria-labelledby`; hidden panel dung `hidden`/unmount co quan ly, khong de focus vao content an.
- Khi doi tab, giu focus tren tab; khong full-page reload. Data lifecycle phai theo `13-realtime-background-data.mdc`.

**Responsive**

- Mobile/tablet: rail `overflow-x:auto`, khong wrap; tab giu min-height 44px, label khong bi cat vo hinh. Khi active thay doi, scroll tab vao view bang co che khong gay page horizontal overflow.
- Nhieu tab: uu tien scroll rail; khong tu dong bien thanh dropdown tru khi product co design rieng va van cung cap semantics/accessibility tuong duong.
- Panel content responsive doc lap; tab rail khong ep panel co min-width desktop.

**FORBIDDEN:** pills/disconnected buttons; underline-only khong co panel relationship khi UI yeu cau tab-container; tab wrap nhieu hang; active state chi bang mau chu; hard-code teal/white/gray; border kep/khe ho giua active tab va panel; click-only `li`; moi trang tu che tab style khac nhau; React admin bo qua Ant Design Tabs de tu dung tab DOM/CSS.

**Acceptance:** kiem tra active/inactive/hover/focus/disabled trong dark + light; keyboard Left/Right/Home/End; mobile horizontal scroll; label vi/en/zh; active tab lien panel khong gap/double border; doi tab khong reload va lazy-load dung rule 13.

### Scroll-to-top button — bat buoc cho moi UI project

Moi website, admin, dashboard, portal hay ung dung co page/main scroll phai dung **mot shared component** scroll-to-top. Cam moi page tu tao mot bien the rieng.

**Hanh vi**

- Xac dinh dung scroll owner: `window/document` neu page scroll, hoac main scroll container neu app shell dung `overflow:auto`. Cam luon goi `window.scrollTo` khi noi dung thuc te scroll trong `<main>`.
- Chi hien sau meaningful scroll: mac dinh `max(400px, 50vh)` hoac threshold project token tuong duong. Khi o gan dau trang, button an bang `opacity/visibility/pointer-events` va khong nam trong tab order.
- Click/Enter/Space cuon ve `top: 0` cua dung owner. Dung smooth scroll khi motion duoc phep; `prefers-reduced-motion: reduce` phai dung `behavior: auto`.
- Theo doi scroll bang passive listener, IntersectionObserver sentinel, hoac framework hook; cleanup listener khi unmount, throttle/rAF neu can. Cam polling lien tuc, `window.onload`, reload hay navigation.
- Sau khi cuon ve dau, khong tu y cuop focus khoi button; neu UX can chuyen focus den main heading thi phai lam co chu dich va tranh gay bat ngo cho screen reader.

**Visual contract**

- Nut tron hoac rounded-square dong nhat design system, kich thuoc 44–48px; icon arrow-up/chevron-up SVG 18–22px, khong emoji/text mui ten tho.
- Background `var(--ui-accent)`, hover `var(--ui-accent-hover)`, icon/text `var(--ui-accent-contrast, #fff)`; focus-visible ring tu accent token voi offset ro tren dark + light.
- Cam hard-code emerald/blue/default accent. Khi `data-accent`/color preference thay doi, computed color cua button phai doi ngay ma khong remount/reload.
- Shadow/border dung token, nhe va ro khoi content; khong neon/glow/gradient tuy y. Transition opacity/transform/color 150–220ms; reduced-motion bo translate/scale.
- `position: fixed`; desktop neo bottom-right, mobile co the bottom-center/right theo product nhung phai ton trong safe-area va bottom navigation.

```css
:root {
  --ui-bottom-nav-height: 0px;
  --ui-scrolltop-gap: 16px;
}

.scroll-to-top {
  position: fixed;
  right: max(var(--ui-scrolltop-gap), env(safe-area-inset-right));
  bottom: calc(env(safe-area-inset-bottom) + var(--ui-bottom-nav-height) + var(--ui-scrolltop-gap));
  z-index: var(--z-floating-action);
  inline-size: 46px;
  block-size: 46px;
  border-radius: 50%;
  background: var(--ui-accent);
  color: var(--ui-accent-contrast, #fff);
}
.scroll-to-top:hover { background: var(--ui-accent-hover); }
.scroll-to-top[data-visible="false"] {
  opacity: 0;
  visibility: hidden;
  pointer-events: none;
}
```

**Accessibility + i18n**

- Dung `<button type="button">`, khong dung clickable `div`; accessible name tu i18n catalog, vi du `aria-label={t('common.scrollToTop')}` du ca vi/en/zh.
- Icon decorative dung `aria-hidden="true"`; focus-visible bat buoc; touch target toi thieu 44×44px.
- Khi an, button khong focus duoc (`visibility:hidden` hoac quan ly `tabindex` tuong duong). Khong chi dua vao opacity.

**Layer + collision**

- Dung `--z-floating-action`; button tren content/sticky shell nhung duoi header popover, drawer, modal va toast.
- Shell co bottom nav/action bar phai expose `--ui-bottom-nav-height` theo chieu cao thuc. Neu co chat widget/FAB khac, dung mot floating-action stack/gap chung; cam de cac nut chong len nhau.
- Khi modal/drawer blocking mo, an scroll-to-top hoac dam bao no nam duoi backdrop va khong nhan pointer/focus.

**FORBIDDEN:** button luon hien khi dang o top; hard-code mau; `z-index:9999`; che bottom nav/CTA/chat/toast; chi hoat dong voi window trong khi main la scroll owner; thieu label/focus; smooth motion bat buoc khi reduced-motion; full-page reload/navigation de ve dau.

**Acceptance:** test page-scroll va main-container-scroll; dark/light; tung accent; desktop/mobile safe-area + bottom nav; keyboard; reduced-motion; modal/drawer open; threshold show/hide; click dua dung owner ve 0 va khong reload.

### Card + Table data views — bat buoc

Moi man hinh hien thi **tap du lieu/collection** (server, user, VM, log, event, order, product, ticket, file, record, ...) phai co dong thoi hai presentation modes: **Card** va **Table**. Detail view cua mot record don le, chart-only analytic, form, wizard, editor, hoac noi dung prose khong bi xem la collection.

**Shared state — mot data source duy nhat**

- Fetch/subscribe data mot lan theo `13-realtime-background-data.mdc`; Card va Table render tu cung normalized cache/store/query result. Cam `fetchCards()` va `fetchTable()` cho cung dataset.
- Filter, search, sort, pagination/cursor, selected entities, permission masking, realtime patches, loading/error/empty state la shared state. Doi view khong reset bat ky state nao.
- Switching Card ↔ Table la client-side presentation change: khong reload, navigation bat buoc, initial skeleton lai, duplicate request/subscription, hoac scroll page ve top ngoai y muon.
- Persist view preference bang canonical UI persistence adapter neu product can ghi nho qua refresh; neu khong, it nhat giu trong page session. Key phai stable theo dataset/route, vi du `gc.view.servers = card|table`; persisted value duoc validate.

**View switch control**

- Dung two-button segmented control `[Card] [Table]`, co icon + label i18n; cam checkbox, switch on/off, plain select, text link hoac hai button style khong lien quan.
- Container dung `role="group"` voi accessible label; moi button dung `aria-pressed="true|false"`. Active mode dung accent token + contrast; inactive dung neutral surface/border; focus-visible ro.
- Touch target toi thieu 44px; label vi/en/zh khong bi cat. Tren mobile co the icon + short label nhung accessible name van day du.

**Dat switch khi dataset nam trong tabs — bat buoc**

- Tao mot `.tabs-toolbar` duy nhat gom `ul[role="tablist"]` o ben trai va Card/Table segmented control o ben phai **tren cung mot hang**.
- Tablist dung `flex:1; min-width:0; overflow-x:auto`; view switch dung `flex:0 0 auto`, can phai, khong bi cuon theo tab rail va khong roi xuong trong moi panel.
- Mot tab group chi co **dung mot instance** view switch. Cam render switch ben trong `tabpanel`, trong tung tab component, lap lai tren moi dataset, hoac tao state Card/Table rieng cho tung tab.
- Shared view mode ap dung cho dataset cua tab dang active va duoc giu khi chuyen tab: dang Card thi tab data tiep theo mo Card; dang Table thi mo Table. Moi tab van dung cache/query rieng theo rule 13, nhung presentation preference la state chung cua tab group.
- Neu active tab khong phai collection/dataset, control co the an co dieu kien va bi loai khoi tab order; khi quay lai data tab, khoi phuc shared view mode. Cam de mot control khong co tac dung van clickable.
- Trang dataset khong co tablist thi dat switch o ben phai filter/page header nhu cu; quy tac “mot lan” ap dung theo moi data workspace/tab group doc lap.

```html
<div class="tabs-toolbar">
  <ul class="tabs-list" role="tablist" aria-label="..."><!-- tabs --></ul>
  <div class="data-view-switch" role="group" aria-label="..."><button type="button" aria-pressed="true">...</button><button type="button" aria-pressed="false">...</button></div>
</div>
<section role="tabpanel"><!-- Card OR Table renderer; no duplicated switch --></section>
```

```css
.tabs-toolbar {
  display: flex;
  align-items: end;
  gap: 12px;
  border-bottom: 2px solid var(--ui-accent);
}
.tabs-toolbar .tabs-list {
  flex: 1 1 auto;
  min-width: 0;
  border-bottom: 0;
}
.data-view-switch {
  flex: 0 0 auto;
  margin-inline-start: auto;
  margin-bottom: 6px;
}
```

- Mobile van giu cung mot toolbar row: tablist scroll ngang trong phan con lai, switch co dinh ben phai. Neu viewport cuc hep, label co the visually-hidden chi con icon nhung accessible name day du; cam dua switch xuong ben trong panel.

**Card mode**

- Responsive grid: mobile 1 cot; tablet 2; laptop/desktop tang cot theo available width. Card dung theme surface/border/radius tokens, khong hard-code mau.
- Moi card hien identity/title, primary status va cac field quan trong nhat; secondary fields co thu tu ro. Actions co accessible name, khong chi hien khi hover.
- Card mode khong duoc bo mat du lieu/action nghiep vu thiet yeu chi co o Table; neu can, dung details/expand/action menu co the truy cap bang keyboard.

**Table mode**

- Header ro, semantic `<table>` khi du lieu tabular; column heading dung `<th scope="col">`, row identity dung `<th scope="row">` khi phu hop.
- Mobile van phai truy cap duoc Table: dung local `overflow-x:auto`, sticky identity/action column neu can; cam an hoan toan Table hoac bien Table thanh Card ma user khong the chon lai.
- Sort state co accessible name/`aria-sort`; row actions va selection keyboard accessible. Boolean setting dung Switch; row/multi-selection co the dung checkbox khi gan voi batch action that va co accessible label.

**Parity bat buoc**

- Card va Table phai co parity cho CRUD/action, permission, status, freshness, filter result count, empty/error/loading state va selected entity state.
- Moi mode co the toi uu mat do thong tin, nhung khong duoc dua ra tong so record/logic filter/sort khac nhau.
- View switch khong tao API call moi; network evidence phai cho thay cung cache/query key duoc reuse.

**FORBIDDEN:** chi co Card tren mobile hoac chi Table tren desktop; hai endpoint/query rieng cho cung dataset; doi view lam mat filter/selection/page; hard-code view mac dinh ghi de preference; checkbox de doi Card/Table; table gia bang `div` thieu semantics khi data tabular; Card va Table co actions/permissions khac nhau; lap view switch trong moi tab/panel; dat switch thanh mot hang rieng ben trong content khi da co tablist; moi tab mot view-mode state khac nhau.

**Acceptance:** voi cung filter/sort/page, doi Card ↔ Table va xac minh record count/identity/actions giong nhau; Network khong co second initial request; realtime update xuat hien o mode hien tai va van dung khi doi mode; trong moi data-tab group DOM chi co 1 view switch o ben phai cung row voi tablist va khong co switch trong panel; doi tab van giu mode; test dark/light, vi/en/zh, mobile/tablet/laptop/PC, keyboard va persisted/page-session preference.

### Verify thu cong toi thieu

1. Bat **dark** -> soi card, form, table, modal, toast, empty state  
2. Bat **light** -> cung cac man do  
3. Doi accent -> primary + scrollbar van dung  
4. Chon dark -> full refresh -> frame dau tien va UI sau hydrate van dark, khong flash light  
5. Chon light -> full refresh -> frame dau tien va UI sau hydrate van light, khong flash dark  
6. Xac minh cookie/bien persist, root attribute/class, toggle va initializer cung mot gia tri; khong co lenh hard-code ghi de khi khoi tao  
7. Chon tung mau/accent -> full refresh -> frame dau tien, scrollbar, primary controls va UI sau hydrate giu dung mau da chon, khong flash mau mac dinh  
8. Xac minh color picker, bootstrap initializer, root attribute/CSS variables va cookie/bien persist cung mot gia tri da validate  

## 2. Responsive da thiet bi — bat buoc

### Breakpoint chuan (bat buoc dung / tuong duong)

| Thiet bi | Width | Layout ky vong |
|----------|-------|----------------|
| **Mobile** | `< 768px` | 1 cot; nav drawer/hamburger; stack filter; table scroll hoac card fallback |
| **Tablet** | `768px – 1023px` | 2 cot noi dung khi hop ly; nav drawer hoac rail hep |
| **Laptop** | `1024px – 1439px` | Sidebar + main; filter 1 hang; grid ~3 cot |
| **PC / Desktop** | `1440px – 1919px` | Sidebar expanded; grid ~4 cot; full width main |
| **2K** | `1920px – 2559px` | grid ~5 cot (admin densisty) |
| **4K / ultrawide** | `≥ 2560px` | grid ~6 cot; van full width, khong co cum giua |

### Shell / navigation

| Viewport | Sidebar / Nav |
|----------|----------------|
| ≥ 1024px | Sidebar fixed (co the icon-collapse) |
| < 1024px | Off-canvas drawer + overlay; nut menu tren header |

### Full-width page shell — bat buoc

- Mac dinh moi UI page shell, `<main>`, dashboard surface, content section va data workspace phai lap day chieu ngang kha dung: `width: 100%`, `max-width: none`, `min-width: 0`.
- Dung responsive padding/gap de tao khoang tho, khong dung `max-w-5xl` / `max-w-6xl` / `max-w-7xl` / `max-w-screen-*` + `mx-auto` cho wrapper bao toan trang neu lam man hinh co cum giua.
- Voi app co sidebar: shell la flex/grid full viewport; main sau sidebar phai `flex: 1; min-width: 0; width: 100%; max-width: none`.
- Card grid, table, map, chart, tab panel va dashboard workspace phai stretch trong main. Tren PC/2K/4K tang cot/mat do theo available width thay vi de hai ben trong.
- Ngoai le hop le: modal, popover, dropdown, form dialog nho, hoac block van ban dai ben trong mot full-width section co the gioi han reading width (`max-w-prose`, `65ch`).
- Truoc khi claim UI xong, chup/kiem tra desktop rong 1440/1920/2560 neu co the; fail neu page shell bi can giua va hai ben du thua lon.

#### Shared stacking scale (source of truth cho moi UI)

```css
:root {
  --z-content: 0;
  --z-sticky: 100;
  --z-floating-action: 150;
  --z-header-popover: 200;
  --z-drawer-backdrop: 300;
  --z-drawer: 310;
  --z-drawer-popover: 320;
  --z-modal-backdrop: 400;
  --z-modal: 410;
  --z-modal-popover: 420;
  --z-toast: 500;
}
```

Thu tu: **content < sticky header/nav < floating action < header popover < drawer/backdrop < drawer popover < modal/backdrop < modal popover < toast**.

- Navbar/header phai co positioned `z-index: var(--z-sticky)`; dropdown/popover/menu cua header dung `--z-header-popover`.
- Floating UI phai dung layer theo **owning surface**: trong drawer dung `--z-drawer-popover`, trong modal dung `--z-modal-popover`. Khi portal vao overlay root, giu dung scope cua owner; khong ha tat ca menu ve mot `--z-dropdown` chung.
- Kiem tra ancestor `overflow`, `transform`, `filter`, `contain`, `isolation`, va opacity tao stacking/clipping context. Dung portal overlay root khi floating menu khong the thoat context an toan.
- Cam page content/widget dat layer cao hon header popover; cam dung `z-index: 9999` tuy y thay cho thang layer nay.
- `--z-toast` la global top UI layer trong thang nay; navbar/header khong duoc bang/cao hon no. Toast viewport van phai dat duoi header theo visual offset (`--ui-header-height` + gap), khong dung z-index de cho toast de len che controls cua navbar.

### Quy tac component responsive

1. **Mobile-first** CSS/Tailwind: base = mobile, roi `md:` / `lg:` / `xl:` nang cap.
2. Flex/grid: `flex-col` -> `md:flex-row` khi can hang ngang.
3. Khong `overflow-x` o `body` (tru bang co `overflow-x: auto` cuc bo).
4. Anh/video: `max-width: 100%`; hero full-bleed van doc duoc tren mobile.
5. Touch: nut/icon clickable ≥ **44×44px** tren mobile/tablet.
6. Filter bar admin: stack doc tren mobile, **1 hang** tu `md+` (xem ADMIN blueprint).
7. Modal: full-screen hoac near-full tren mobile; centered tren desktop.
8. Font: tranh text > viewport; heading scale theo breakpoint.

### FORBIDDEN responsive

- Chi test Chrome desktop width
- `position: fixed` element che mat noi dung tren mobile (khong co safe padding)
- Bang nhieu cot khong co scroll/fallback -> chu be nat tren dien thoai
- An toan bo chuc nang tren mobile ma khong co duong thay the

## 3. Meta + testing matrix

```html
<meta name="viewport" content="width=device-width, initial-scale=1" />
```

Truoc khi claim UI xong, kiem tra nhanh:

| | Dark | Light |
|--|------|-------|
| Mobile 390 | [ ] | [ ] |
| Tablet 768 | [ ] | [ ] |
| Laptop 1280 | [ ] | [ ] |
| PC 1440 / 1920 | [ ] | [ ] |

## 4. Agent procedure

1. Doc file nay + `docs/UI_DESIGN_CHECKLIST.md`
2. Admin: them `docs/REACT_ANTD_ADMIN_BLUEPRINT.md` + `docs/ADMIN_UI_BLUEPRINT.md`
3. Moi component moi: tokens theme + breakpoint tu muc 2
4. Pass gate muc 0 + matrix muc 3
5. Thieu blueprint -> bao cai pack; khong biа breakpoint/theme khac chuan
