# WAF Filter Security Blueprint (PORTABLE)

> Di kem pack. Agent **MUST** doc truoc khi viet / sua WAF, security middleware, Cloudflare rules, mitigation block-IP.  
> Khong can repo mau tren may. Quy tac nay la source of truth.

## 0. Acceptance gate

```
[ ] WAF bat mac dinh (WAF_ENABLED=true), che do block|log co cau hinh
[ ] Du category BLOCK toi thieu (muc 3)
[ ] Normalize input truoc khi match (decode URI de quy, HTML entity, unicode escape)
[ ] Quet: path + query + body + header nguy hiem
[ ] Whitelist toi thieu, uu tien EXACT path; khong whitelist ca /api
[ ] Rate limit + auto-block IP sau nhieu lan WAF hit
[ ] Log moi block (category, method, path rut gon, ip, payload slice)
[ ] Response 403 JSON on dinh, khong lo stack/internal
[ ] Input-guard kem: null-byte, CRLF header, HPP
[ ] Co test payload dai dien (SQLi/XSS/LFI/CMDi) -> 403
[ ] Secret / rule token khong commit
[ ] Co RBAC toi thieu ngay khi khoi tao: owner/security_admin/admin/operator/auditor/viewer
[ ] Co lenh security check canonical; CI bat buoc chay va block build/deploy neu fail
```

## 0.1. Bat buoc ngay khi khoi tao project

- Project phai tao security baseline truoc feature deployable dau tien: WAF/input guards, rate limit, audit event, RBAC, payload tests va CI gate.
- Project khong co HTTP ingress phai ghi ro `WAF applicability: not applicable - no HTTP ingress` trong tai lieu security, nhung van phai co RBAC, secret scanning/dependency audit phu hop. Khi them HTTP ingress, gate WAF day du co hieu luc ngay.
- Dinh nghia mot lenh canonical theo stack, vi du `npm run security:check`, `pytest -m security`, `dotnet test --filter Security` hoac tuong duong. Lenh nay phai gom test WAF/RBAC va duoc workflow CI goi truc tiep.
- Cam deploy khi security check thieu, bi skip, hoac that bai.

## 0.2. RBAC toi thieu bat buoc tu dau

| Role | Quyen toi thieu | Gioi han bat buoc |
|------|-----------------|-------------------|
| `owner` | Quan tri cao nhat, gan role dac quyen, break-glass | Khong dung cho tac vu hang ngay; moi hanh dong dac quyen phai audit |
| `security_admin` | Cau hinh WAF, whitelist, rate limit, block/unblock IP, xem security events | Khong sua/xoa audit event; khong tu nang minh thanh owner |
| `admin` | Quan tri user va cau hinh nghiep vu | Khong sua WAF/whitelist/IP ban neu khong co grant security rieng |
| `operator` | Van hanh, xem trang thai, thuc hien action duoc uy quyen | Khong quan tri role, WAF policy hoac audit log |
| `auditor` | Chi doc config, security events va audit trail | Tuyet doi khong mutation/export secret |
| `viewer` | Chi doc du lieu nghiep vu duoc cap | Khong co quyen van hanh, security hay quan tri |

Quy tac:

1. Deny-by-default, least privilege, permissions duoc enforce tai server/API cho moi request; UI chi la lop hien thi.
2. Khong nhan role/permission tu public signup, client payload, cookie hoac claim chua duoc server xac minh.
3. Bootstrap `owner` dau tien bang quy trinh server-side mot lan, co expiry/disable sau khi dung va co audit; khong hard-code tai khoan hoac mat khau mac dinh.
4. Moi thay doi role, WAF, whitelist, rate limit va IP ban phai ghi actor, target, before/after, reason, timestamp va correlation ID; audit event la append-only.
5. Tai khoan `owner` va `security_admin` bat buoc TOTP uu tien theo `docs/EMAIL_OTP_AUTH_BLUEPRINT.md`.
6. Test bat buoc: allow/deny matrix, cross-tenant access neu co tenant, tu nang quyen, gan role trai phep, sua/xoa audit, va quyen quan tri WAF.

## 1. Mo hinh bat buoc (2 tang)

```
Request
  -> null-byte / CRLF / HPP guards
  -> WAF scan (normalize -> match BLOCK patterns)
       | hit + mode=block -> 403 + log (+ count toward IP ban)
       | hit + mode=log   -> log only + next()
       | miss             -> next()
  -> auth / business routes
```

| Tier | Y nghia |
|------|---------|
| **BLOCK** | Pattern ro rang doc hai, an toan de reject |
| **LOG** | Nghi ngo / de false-positive - chi log, khong block (tuy chon mo rong) |

**MUST:** mac dinh production = `WAF_MODE=block`.  
**MUST NOT:** tat WAF tren production de "cho de debug" ma khong co thay the.

## 2. Pipeline normalize (bat buoc truoc regex)

1. Lay string tu path, `originalUrl`, query values + `k=v`, body flatten (depth <= 5), headers nguy hiem
2. `decodeURIComponent` de quy toi da 5 lan (bat double/triple encoding)
3. Decode HTML entities (`&lt;`, `&#x3c;`, ...)
4. Map `\u0027` / `\x27` / smart quotes -> ASCII quote
5. Bo qua chuoi rong / length < 3 sau normalize
6. Match regex **tren chuoi da normalize**, khong match raw lan dau roi bo qua encoded

### Headers bat buoc dua vao scan

```
referer, x-forwarded-for, x-original-url, x-rewrite-url,
x-forwarded-host, x-host, x-custom-ip-authorization,
x-forwarded-server, x-http-host-override, forwarded
```

## 3. Category filter bat buoc (BLOCK)

Moi project HTTP/API **MUST** cover cac category sau (regex tuong duong, khong copy mu):

| Category | Tin hieu bat buoc bat |
|----------|------------------------|
| **SQL Injection** | `union select`, `insert into`, `drop table`, `' or 1=1`, `sleep(`, `benchmark(`, `waitfor delay`, `xp_`/`sp_`, comment `--`/`#`/`/*` sau quote |
| **XSS** | `<script`, event handlers `on*=`, `javascript:`, `vbscript:`, `data:text/html`, iframe/object/embed, `document.cookie`, `eval(` |
| **Path Traversal / LFI** | `../`, `%2e%2e%2f`, overlong UTF8 `%c0%af`, `/etc/passwd`, `php://`, `%00` |
| **Command Injection** | `; ls`, `| bash`, `` `id` ``, `$(whoami)`, pipe toi shell |
| **CRLF** | `\r` / `\n` trong input/header attacker-controlled |
| **SSRF** | URL toi `127.`, `10.`, `192.168.`, `172.16-31.`, `169.254.169.254`, `localhost`, `metadata.google.internal`, `file://`, oast/collaborator domains |
| **XXE** | `<!ENTITY`, `<!DOCTYPE ... [`, `SYSTEM "` |
| **SSTI** | `{{...}}`, `${...}`, `#{...}`, `<%-...%>` |
| **NoSQL** | `$ne`, `$gt`, `$where`, `$regex` dang operator injection |
| **LDAP** | filter injection `*)(`, `objectClass=` |
| **Open Redirect** | param `redirect|url|next|return` = `https:` / `//` ngoai |

**Them khi stack can:** GraphQL introspection abuse, JWT none-alg probes, prototype pollution (`__proto__`, `constructor.prototype`).

## 4. Whitelist discipline

```
WHITELIST_PREFIXES  - static/install/agent assets that legitimately look like scripts
WHITELIST_EXACT     - rare API that must accept keyword-shaped fields (e.g. SMTP user)
```

**MUST:**
- Whitelist ngan, co comment ly do
- Prefer **exact path** cho API nhay cam
- Auth van chay sau WAF (whitelist khong thay the auth)

**MUST NOT:**
- Whitelist `/api` hoac `/`
- Whitelist theo User-Agent
- Bo WAF cho toan bo authenticated traffic

## 5. Rate limit + auto mitigation

| Control | Goi y |
|---------|--------|
| Global / IP | vd 120 req / 60s (chinh theo app) |
| Auth key | rate theo `user+ip` neu da dang nhap |
| WAF abuse | >= 5 WAF blocks / 60s / IP -> enqueue block_ip / ban tam thoi |
| Response | `429` + `Retry-After` khi rate limit |

Block IP **MUST** co: expire time, audit log, kha nang rollback, khong ban vinh vien mac dinh.

## 6. Logging & response

### Log moi hit

```
[WAF] BLOCKED|DETECTED | <category> | <METHOD> <path<=80> | ip=... | payload="<slice<=120>"
```

Dong thoi ghi security event DB/file: `type=waf_block`, khong luu full body secret.

### HTTP response (block mode)

```json
{ "success": false, "error": "Request blocked by security policy", "code": "WAF_BLOCK" }
```

Status `403`. **MUST NOT** tra regex name, stack trace, SQL error, hay payload echo day du.

## 7. Cau hinh env

| Env | Default | Y nghia |
|-----|---------|---------|
| `WAF_ENABLED` | `true` | Bat/tat |
| `WAF_MODE` | `block` | `block` \| `log` |

Staging co the `log` de do false-positive; promote `block` truoc production cutover.

## 8. Vi tri code goi y (portable)

```
src/security/
  waf.js            # patterns + middleware
  input-guard.js    # null-byte, CRLF, HPP, URL/SSRF helpers
  events.js         # persist waf_block
middleware order:
  trust proxy (cau hinh dung)
  -> nullByteGuard
  -> crlfHeaderGuard
  -> hppGuard
  -> wafMiddleware
  -> rateLimiter
  -> auth
  -> routes
```

## 9. Cloudflare / edge WAF (neu co)

Khi dung Cloudflare (hoac tuong duong):

1. Managed ruleset OWASP/Cloudflare ON
2. Custom rules cho path admin (`/api/admin`, `/login`) - challenge / block bot
3. Rate limiting rules tai edge (bo sung, khong thay the app WAF)
4. Khong dua secret app vao expression rule
5. Log/firewall events export duoc correlat voi app `waf_block`

App WAF van **bat buoc** (defense in depth) - edge co the miss encoding/body JSON.

## 10. Quy trinh them filter moi

1. Xac dinh category + false-positive risk
2. Viet regex tren **normalized** string; them test case encoded
3. Neu de false-positive -> LOG tier truoc 24-72h, roi moi BLOCK
4. Cap nhat whitelist neu can (exact only)
5. Chay payload suite toi thieu (muc 11)
6. Document ly do trong comment ASCII ngan

## 11. Test suite toi thieu (truoc khi claim xong)

Gui request (GET/POST) voi payload; ky vong **403** + `code=WAF_BLOCK`:

| Category | Vi du payload |
|----------|----------------|
| SQLi | `' OR '1'='1` / `1; DROP TABLE x--` |
| XSS | `<script>alert(1)</script>` / `" onmouseover=alert(1) x="` |
| LFI | `../../etc/passwd` / `%2e%2e%2fetc%2fpasswd` |
| CMDi | `; id` / `| bash` |
| SSRF | `http://127.0.0.1/` / `http://169.254.169.254/` |
| SSTI | `{{7*7}}` |
| Null | `%00` trong path/query |

Positive tests: login hop le, JSON business binh thuong, static assets whitelist **khong** bi 403.

## 12. Cam ky (anti-patterns)

- Chi quet `req.query`, bo `req.body` / headers
- Chi match raw, khong decode
- Block theo quoc gia / UA nhu thay the WAF
- Fail-open im lang khi regex throw (bat try/catch -> fail closed hoac log+continue co chu dich)
- Commit `.env` WAF secrets / Cloudflare API token
- Dung WAF thay input validation + parameterized SQL + authz

## 13. Agent procedure

1. Khi khoi tao/nhan project, doc file nay + `.cursor/rules/10-waf-security.mdc` va xac dinh HTTP ingress
2. Tao security baseline + RBAC muc 0.1-0.2 truoc feature deployable dau tien
3. Implement / sua filter theo muc 1-8
4. Tao lenh security check canonical, chay muc 11 + RBAC tests va noi vao CI
5. Pass gate muc 0 truoc khi noi "WAF xong" hoac "project san sang deploy"
6. Thieu file blueprint -> bao user cai lai pack; khong bia WAF khac chuan
