# Sources (HUMAN ATTRIBUTION ONLY)

> **Agents: DO NOT read this file during tasks.**  
> It exists so humans know what was distilled. Runtime source of truth = `.cursor/rules/*.mdc` + `AGENTS.md`.

This pack is a **standalone distillation**. Installing a project with this pack does **not** require cloning any upstream skill repo.

## Distilled from (historical)

### Local design

- `greencould-server-monitor/docs/ADMIN_UI_DESIGN_SYSTEM_GUIDELINE.md` → `03-admin-ui-greenmonitor.mdc`

### BUILD → `01`, `02`

- DavidEran/Claude-Skills (superpowers), garrytan/gstack, JuliusBrussee/caveman, DietrichGebert/ponytail, FabianWesner/claude-code-codex-skill, ayghri/i-have-adhd

### DESIGN → `03`–`05`

- nextlevelbuilder/ui-ux-pro-max-skill, senlindesign/taste-skill, pbakaus/impeccable, heygen-com/hyperframes, delphi-ai/animate-skill, iotron/gsap-cookbook

### RESEARCH → `06`

- somasays/skill-creator, m8e/graphify, mvanhorn/last30days-skill, OWENLEEzy/agent-browser-skill, Emily27-alt/find-skill, barkleesanders/claude-hud

### MARKETING → `07`

- haidrrrry/claude-remotion-skill, coreyhaines31/marketingskills, tjboudreaux/humanizer, thomichel/social-media-skills

### I18N → `08`

- GreenCould product requirement (vi default + en + zh + flags)

### CI/CD → `09` + `docs/GITHUB_CICD_BLUEPRINT.md`

- Distilled from greencould-server-monitor CI/CD + GitHub Docker autodeploy practices (GHCR, Windows self-hosted runner, Linux VPS SSH)

### WAF / Security → `10` + `docs/WAF_SECURITY_BLUEPRINT.md`

- Distilled from greencould-server-monitor `main-server/src/security/waf.js` + `input-guard.js` + mitigation WAF abuse patterns

### Theme + Responsive → `11` + `docs/THEME_RESPONSIVE_BLUEPRINT.md`

- Dark/light token completeness + multi-device breakpoints (mobile/tablet/laptop/PC/2K/4K) from GreenMonitor admin guideline + product requirements

### Toast + Searchable Select → `12` + `docs/TOAST_SELECT_BLUEPRINT.md`

- Toast/notification UX + mandatory Select2 (or equivalent) for entity/list pickers

To refresh the distillation later, a human may re-read upstreams and update the local `.mdc` / blueprint files — agents must not do that automatically per project.
