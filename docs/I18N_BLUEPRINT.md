# I18N Blueprint (PORTABLE)

> Đi kèm pack. Agent **MUST** follow khi làm bất kỳ UI nào.  
> Không cần máy có repo khác.

## Locales (cố định)

| Code | BCP-47 | Default | Flag | Label (native, không dịch) |
|------|--------|---------|------|----------------------------|
| `vi` | `vi-VN` | **YES** | 🇻🇳 | Tiếng Việt |
| `en` | `en-US` | no | 🇺🇸 | English |
| `zh` | `zh-CN` | no | 🇨🇳 | 中文 |

## Files (bắt buộc tạo)

React Ant Design template dùng catalog theo domain:

```text
src/locales/vi-VN/*.json   <- source of truth
src/locales/en-US/*.json   <- same files + keys
src/locales/zh-CN/*.json   <- same files + keys
```

Stack khác có thể dùng `locales/{vi,en,zh}.json`, miễn mapping BCP-47 và key parity tương đương.

Key parity: mọi key có mặt ở cả 3 file. Missing → fallback `vi`.

## Switcher UI (bắt buộc)

- Hiện **cờ + tên bản ngữ** (không chỉ `VI/EN/ZH`)
- Thứ tự: 🇻🇳 → 🇺🇸 → 🇨🇳
- React template persist `language` = `vi-VN|en-US|zh-CN` trong namespaced Zustand preference store. Stack khác dùng cùng canonical UI adapter của app; localStorage cho client-only, cookie cho SSR/hybrid. Không tạo store/key độc lập trong component.
- `document.documentElement.lang` sync theo locale
- Font CJK khi `zh`: Noto Sans SC / PingFang SC / Microsoft YaHei

```html
<button type="button" aria-haspopup="listbox" aria-label="Language">
  <span aria-hidden="true">🇻🇳</span> Tiếng Việt
</button>
<ul role="listbox">
  <li role="option" data-locale="vi">🇻🇳 Tiếng Việt</li>
  <li role="option" data-locale="en">🇺🇸 English</li>
  <li role="option" data-locale="zh">🇨🇳 中文</li>
</ul>
```

## Rules

1. Không hard-code chuỗi UI trong component (trừ native names trong switcher).
2. Format số/ngày theo `vi-VN` / `en-US` / `zh-CN`.
3. Đơn vị kỹ thuật (ms, %, MB/s) giữ nguyên ký hiệu.
4. Marketing: thêm `hreflang` nếu có URL đa ngữ.

## Acceptance

```
[ ] 3 locale catalogs, same domain files + key parity
[ ] Default vi on first visit
[ ] Flags visible in switcher
[ ] locale persisted qua canonical namespaced adapter; server/bootstrap/client cung gia tri, khong flash/hydration mismatch
[ ] html[lang] updates
[ ] zh renders CJK correctly
```
