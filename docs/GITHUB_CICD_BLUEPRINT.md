# GitHub + Server/VPS CI/CD Blueprint (PORTABLE)

> File nay di kem pack. Agent **MUST** doc truoc khi them CI/CD / deploy.  
> Khong can may co repo mau. Dung ASCII trong script PowerShell tren Windows Server.

## 0. Acceptance gate

```
[ ] Co dung 1 canonical version source; build/runtime doc version tu nguon nay
[ ] Version chi bump khi user/release policy yeu cau; doc version hien tai sau khi sync main
[ ] Version/changelog/generated release metadata va security gates da validate
[ ] Canonical security-check command chay WAF payload + RBAC tests; workflow fail/skip thi khong build/deploy
[ ] Tieu de commit bang tieng Viet co dau, neu ro ly do release; staged diff khong gom thay doi ngoai pham vi
[ ] Push khong force main, khong bo qua hooks, khong lo token trong remote/command/log
[ ] Branch chinh: main (hoac master da doi ten) - deploy chi tu branch nay + tag v*
[ ] Workflow: build tren ubuntu-latest, push GHCR, roi moi deploy
[ ] permissions: contents:read + packages:write (build); packages:read (deploy)
[ ] Secrets khong commit (.env, .env.docker chi nam tren server)
[ ] Self-hosted runner (Windows) HOAC SSH deploy (Linux VPS) da cau hinh
[ ] Windows runner cai bang 1 file `scripts/bootstrap-github-runner.ps1`
[ ] Windows runner la service: StartupType=Automatic + Status=Running + GitHub Online
[ ] Runner chay nhu service / auto-start sau reboot
[ ] Deploy script strip bien moi truong rong tu GitHub Actions
[ ] Healthcheck sau deploy
[ ] Da theo doi dung GitHub Actions run cua commit/tag vua push den khi hoan tat
[ ] Runtime target tra ve dung version/commit/image vua deploy + smoke test dat
[ ] concurrency group production, cancel-in-progress: false
```

## 0.1 Quy trinh cap nhat phien ban va push deploy

Ap dung truoc pipeline o muc 1:

1. Xac dinh canonical version source hien co (`release-versions.json`, `VERSION`, manifest, hoac file duoc repo quy dinh). Khong tao them nguon version thu hai.
2. Chi bump khi user yeu cau ro rang hoac release policy cua repo yeu cau. Fetch remote, kiem tra branch/upstream, tich hop `main` moi nhat an toan, sau do doc version hien tai tu file canonical.
3. Dung SemVer neu repo khong co chuan khac. Project nhieu thanh phan chi bump thanh phan duoc phat hanh. Build arg, binary metadata va runtime `/version` phai lay tu canonical source.
4. Cap nhat changelog/release note/version-history seed/generated metadata neu repo co. Ly do phai noi *vi sao* cap nhat de audit va rollback, khong chi ke ten file da sua.
5. Chay version validator + test/build/lint/security gate + commit-message gate cua repo. Cam `--no-verify`.
6. Doc `git status`, staged diff va commit sap tao; giu nguyen thay doi khong lien quan. Tieu de moi commit push len GitHub bat buoc bang tieng Viet co dau va kem ly do thay doi; chi mien Merge/Revert tu dong.
7. Push branch binh thuong. Cam force-push `main`; chi tao/push tag khi user yeu cau hoac release policy ghi ro. Cam chen token vao remote URL hay command line.
8. Theo doi GitHub Actions run gan voi dung commit/tag. Push thanh cong khong dong nghia deploy thanh cong.
9. Chi ket luan xong sau khi build, GHCR push, deploy, healthcheck deu xanh va runtime target xac nhan dung version/commit/image; chay smoke test nho tren URL dich thuc te.

Neu khong co quyen/tool de theo doi Actions hoac runtime, bao ro `push thanh cong, deploy chua duoc xac minh`; khong dung mot run xanh cu lam bang chung.

## 0.2 Tu dong tiep tuc sau khi test dat - khong hoi lai

Neu user da giao thay doi kem yeu cau commit/push/deploy, hoac noi `sau khi test dat`, `hoan thanh`, `deploy luon` hay y tuong duong, lenh ban dau la uy quyen cho toan bo chuoi:

```
implement -> test/gates xanh -> stage dung pham vi -> commit tieng Viet co dau
          -> push -> theo doi dung GitHub Actions run -> verify runtime
```

Agent **PHAI tu tiep tuc**, khong hoi lai `co commit/push/deploy khong?` sau khi test xanh va khong dung o viec bao cao ket qua test.

Chi dung va xin huong dan/quyen moi khi:

- test, build, security hoac release gate that bai;
- staged diff co thay doi khong ro chu so huu/ngoai pham vi;
- co secret hoac du lieu nhay cam;
- branch/upstream khong ro, credential/quyen GitHub/server bi thieu;
- thao tac can force-push, tao tag, bump version hoac release ngoai yeu cau ban dau.

Neu external action bi chan, bao loi nguyen van va trang thai chinh xac; khong noi deploy thanh cong.

## 1. Mo hinh bat buoc (GreenCould standard)

```
Developer push -> GitHub
                 |
                 v
        [Job build-push]  runs-on: ubuntu-latest
                 |  build Dockerfile
                 |  push ghcr.io/<owner>/<image>:app-<sha>
                 |           + :app-latest
                 v
   +-------------+--------------+
   |                            |
   v                            v
[Job deploy-windows]      [Job deploy-linux-vps]  (tuy chon)
 self-hosted runner         ubuntu-latest + SSH
 labels: self-hosted,       secrets: VPS_HOST, VPS_SSH_KEY
   windows, <project>       docker compose pull + up -d
   pull + compose up
```

**MUST:** Build o cloud (ubuntu-latest). Deploy o server (self-hosted) hoac qua SSH toi VPS.  
**MUST NOT:** Build Docker image nang tren may developer roi copy tay len server nhu quy trinh chinh.

## 2. Cau truc repo bat buoc

```
[project-root]/
├── .github/workflows/build-push-deploy.yml
├── Dockerfile
├── docker-compose.server.yml          # Windows Docker Desktop / server
├── docker-compose.linux-vps.yml       # Linux VPS (neu co)
├── scripts/
│   ├── setup-server-auto-deploy.ps1   # bootstrap 1 lan (Windows)
│   ├── bootstrap-github-runner.ps1    # cai runner + git + docker (Windows)
│   ├── github-actions-deploy.ps1      # goi tu Actions
│   ├── github-actions-deploy.cmd      # wrapper ASCII cho shell: cmd
│   ├── github-actions-healthcheck.ps1
│   └── github-actions-healthcheck.cmd
└── .env.docker                        # CHI tren server - trong .gitignore
```

## 3. GitHub cau hinh

### 3.1 Permissions (workflow)

```yaml
permissions:
  contents: read
  packages: write
```

Deploy job: `packages: read`.

### 3.2 Secrets (khong commit)

| Secret | Khi nao |
|--------|---------|
| `SERVER_DEPLOY_PATH` | Optional - Windows deploy root |
| `DASHBOARD_PASSWORD` / `POSTGRES_PASSWORD` / `AGENT_SHARED_KEY` | Chi khi `recreate_env=true` |
| `CLOUDFLARED_TOKEN` | Neu CI cap nhat tunnel |
| `VPS_HOST` | Linux VPS SSH deploy |
| `VPS_SSH_KEY` | Private key SSH (ed25519) |

**Mac dinh:** secrets ung dung nam trong `.env.docker` tren server. GitHub khong can secret app neu khong recreate env.

### 3.3 Variables (repo)

| Variable | Vi du |
|----------|--------|
| `PROJECT_NAME` | ten project |
| `APP_PORT` / `MONITOR_PORT` | port public |
| `RECREATE_ENV` | `false` |

### 3.4 Branch / trigger

```yaml
on:
  push:
    branches: [main]
    tags: ["v*"]
  workflow_dispatch:
    inputs:
      skip_deploy: { type: boolean, default: false }
      recreate_env: { type: boolean, default: false }
```

## 4. Self-hosted runner tren may server (Windows) - bat buoc neu deploy Windows

GitHub **khong** tu cai runner. Chay **1 lan** tren server trong PowerShell mo bang Run as Administrator:

1. GitHub -> Settings -> Actions -> Runners -> New self-hosted runner -> copy registration token.
2. Copy/chay duy nhat file da duoc pack cai vao project:

```powershell
.\scripts\bootstrap-github-runner.ps1 `
  -RepositoryUrl "https://github.com/<owner>/<repo>" `
  -ProjectLabel "<project-label>"
```

Script tu dong tai runner Windows moi nhat, kiem tra SHA-256 neu GitHub API co digest, hoi registration token bang secure prompt, config runner, cai `svc.cmd install`, dat service `Automatic`, start va verify `Running`. Token ngan han khong duoc ghi vao file/log/remote URL.

**Bat buoc:** Moi project Windows deploy dung one-file bootstrap nay (hoac mot file tuong duong day du). Khong giao cho user checklist tai/giai nen/config/service thu cong. `run.cmd` chi de debug, khong duoc dung lam production auto-start.

Labels **MUST** khop workflow:

```yaml
runs-on:
  - self-hosted
  - windows
  - <project-label>
```

Sau reboot: service runner **MUST** tu chay. Kiem tra:

```powershell
Get-Service actions.runner.*
# hoac
cd C:\actions-runner-<project>
.\run.cmd   # chi dung debug; production dung service
```

Acceptance sau bootstrap va sau mot lan reboot:

```powershell
$runner = Get-Service actions.runner.*
$runner | Select-Object Name, StartType, Status
# StartType phai la Automatic; Status phai la Running
```

GitHub -> Settings -> Actions -> Runners phai hien runner `Online` va co dung label `self-hosted`, `windows`, architecture, `<project-label>`.

### Runner Linux VPS (neu chon self-hosted thay vi SSH)

```bash
# tren VPS, user co docker
mkdir -p ~/actions-runner && cd ~/actions-runner
# download runner tu GitHub UI, roi:
./config.sh --url https://github.com/<owner>/<repo> --token <REG_TOKEN> --labels self-hosted,linux,<project-label>
sudo ./svc.sh install
sudo ./svc.sh start
```

## 5. Dong bo len server / VPS

### A) Windows self-hosted (uu tien khi server Windows)

Moi push `main`:

1. Checkout sparse: compose + deploy scripts
2. `docker login ghcr.io`
3. Goi `github-actions-deploy.cmd` voi `APP_IMAGE=ghcr.io/...:app-<sha>`
4. Script: strip empty env -> `docker compose --env-file .env.docker -f docker-compose.server.yml pull` -> `up -d --remove-orphans`
5. Healthcheck HTTP/container

### B) Linux VPS qua SSH (tu GitHub-hosted runner)

Secrets: `VPS_HOST`, `VPS_SSH_KEY` (port tuy chon, vd 22 hoac 1812).

```
scp compose + sql can thiet
ssh:
  cap nhat APP_IMAGE trong .env.docker
  docker login ghcr.io
  docker compose -f docker-compose.linux-vps.yml --env-file .env.docker pull
  docker compose ... up -d --force-recreate
  healthcheck (docker ps / curl)
  docker logout
```

**MUST:** `.env.docker` o lai tren VPS, khong copy tu CI (tru recreate co chu dich).

## 6. Bay bat buoc phai tranh (Windows PowerShell)

1. **ASCII only** trong `.ps1` / `.cmd` chay tren Windows Server (PS5). Cam em-dash, smart quotes, tieng Viet co dau trong script.
2. **Native command + `$ErrorActionPreference = Stop`:** tam `SilentlyContinue`, doc `$LASTEXITCODE`, roi bat lai.
3. **Empty GitHub env ghi de `.env.docker`:** truoc `docker compose`, xoa bien rong:

```powershell
foreach ($k in @("POSTGRES_PASSWORD","AGENT_SHARED_KEY","CLOUDFLARED_TOKEN","DASHBOARD_PASSWORD")) {
  if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($k))) {
    Remove-Item "Env:$k" -ErrorAction SilentlyContinue
  }
}
```

4. **Khong hardcode DeployRoot** - lay tu env `DEPLOY_ROOT` hoac parent cua script.
5. **recreate_env=true** chi khi xoay secret co chu dich (se logout user).

## 7. Workflow skeleton (rut gon)

```yaml
name: Build Push Deploy
on:
  push:
    branches: [main]
    tags: ["v*"]
  workflow_dispatch:
    inputs:
      skip_deploy: { type: boolean, default: false }

concurrency:
  group: <project>-production
  cancel-in-progress: false

permissions:
  contents: read
  packages: write

jobs:
  build-push:
    runs-on: ubuntu-latest
    outputs:
      app_tag: ${{ steps.meta.outputs.app_tag }}
    steps:
      - uses: actions/checkout@v4
      - id: meta
        run: echo "app_tag=app-${GITHUB_SHA}" >> "$GITHUB_OUTPUT"
      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - uses: docker/build-push-action@v6
        with:
          push: true
          tags: |
            ghcr.io/${{ github.repository_owner }}/${{ github.event.repository.name }}:${{ steps.meta.outputs.app_tag }}
            ghcr.io/${{ github.repository_owner }}/${{ github.event.repository.name }}:app-latest

  deploy-windows:
    needs: build-push
    if: ${{ github.event_name != 'workflow_dispatch' || inputs.skip_deploy != true }}
    runs-on: [self-hosted, windows, <project-label>]
    steps:
      - uses: actions/checkout@v4
      - run: call scripts\github-actions-deploy.cmd
        shell: cmd
        env:
          APP_IMAGE: ghcr.io/${{ github.repository_owner }}/${{ github.event.repository.name }}:${{ needs.build-push.outputs.app_tag }}
          DEPLOY_ROOT: ${{ secrets.SERVER_DEPLOY_PATH }}
```

Dien job `deploy-linux-vps` khi co VPS (muc 5B).

## 8. Checklist van hanh server

```
[ ] Docker dang chay (Desktop service / dockerd)
[ ] Runner Online tren GitHub -> Settings -> Actions -> Runners
[ ] Labels khop workflow
[ ] .env.docker ton tai, khong trong git
[ ] Push thu len main -> Actions xanh -> container image moi
[ ] Health URL / docker ps OK
```

## 9. Agent procedure

1. Doc file nay + `.cursor/rules/09-github-cicd-deploy.mdc`.
2. Neu co release: thuc hien muc 0.1, giu mot version source va chay moi release gate cua repo.
3. Tao/sua workflow + scripts theo skeleton (ASCII).
4. Huong dan user bootstrap runner **1 lan** tren server (khong pretend CI tu cai runner).
5. Khong commit secret; khong dua token vao remote URL/command/log.
6. Theo doi dung Actions run va xac minh runtime target.
7. Pass gate muc 0 truoc khi noi "CI/CD xong".
