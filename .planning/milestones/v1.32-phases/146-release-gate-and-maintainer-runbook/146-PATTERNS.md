# Phase 146: Release Gate And Maintainer Runbook - Pattern Map

**Mapped:** 2026-05-31  
**Files analyzed:** 8  
**Analogs found:** 8 / 8

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `docs/release-runbook-v1-0.md` (new; exact name at planner discretion) | runbook-doc | request-response | `scripts/uat/RUNBOOK.md` | role-match |
| `MAINTAINING.md` | runbook-doc | request-response | `MAINTAINING.md` | exact |
| `docs/NEXT-STEPS-MANUAL.md` | runbook-doc | request-response | `docs/NEXT-STEPS-MANUAL.md` | exact |
| `docs/ga-evidence.md` | docs-router | request-response | `docs/ga-evidence.md` | exact |
| `.github/workflows/release-please.yml` | config-workflow | event-driven | `.github/workflows/release-please.yml` | exact |
| `.github/workflows/hex-publish.yml` | config-workflow | event-driven | `.github/workflows/hex-publish.yml` | exact |
| `release-please-config.json` | config | transform | `release-please-config.json` | exact |
| `mix.exs` (docs/source-link gate references only) | config | transform | `mix.exs` | exact |

## Pattern Assignments

### `docs/release-runbook-v1-0.md` (runbook-doc, request-response)

**Analog:** `scripts/uat/RUNBOOK.md`

**Runbook structure pattern** (`scripts/uat/RUNBOOK.md:3-11`):
```markdown
## CI vs manual (shift-left)

| Work type | Use this runbook when… |
|-----------|-------------------------|
| **CI already covers it** | ... link workflow run URLs + commit SHA ... |
| **Residual row** | ... run the relevant section below. |
```

**Checklist/step granularity pattern** (`scripts/uat/RUNBOOK.md:82-90`):
```markdown
Each item has:
- **Phase / source**
- **Steps**
- **Expected**
- **Pass criteria**
- **Notes**
```

### `MAINTAINING.md` (runbook-doc, request-response)

**Analog:** `MAINTAINING.md`

**Pointer-not-duplication pattern** (`MAINTAINING.md:144-156`):
```markdown
Phase 146 owns the detailed ... release gates ... policy. Do not duplicate that full gate matrix here.
...
**Recovery / one-off publish:** Actions → Hex publish (manual recovery) ...
```

**Deterministic release sequence pattern** (`MAINTAINING.md:150-154`):
```markdown
1. Conventional commits on `main` ...
2. Merge the Release PR ... creates GitHub Release + `v<version>` tag ...
3. Secrets ...
4. Released version anchor ...
```

### `docs/NEXT-STEPS-MANUAL.md` (runbook-doc, request-response)

**Analog:** `docs/NEXT-STEPS-MANUAL.md`

**Concise fallback routing pattern** (`docs/NEXT-STEPS-MANUAL.md:3-6`):
```markdown
Use this when something cannot be driven by GitHub Actions ...
Default Hex + GitHub releases: see MAINTAINING.md → Release automation ...
Recovery: Actions → Hex publish (manual recovery).
```

### `docs/ga-evidence.md` (docs-router, request-response)

**Analog:** `docs/ga-evidence.md`

**Router page pattern** (`docs/ga-evidence.md:3-16`):
```markdown
This page is a router ... it does not duplicate the ... matrix; it points to canonical artifacts.
## Where to read next
- ...
```

### `.github/workflows/release-please.yml` (config-workflow, event-driven)

**Analog:** `.github/workflows/release-please.yml`

**Release-ref enforcement pattern** (`.github/workflows/release-please.yml:50-72`):
```yaml
publish-hex:
  needs: release-please
  if: ${{ needs.release-please.outputs.release_created == 'true' }}
  ...
  - uses: actions/checkout@...
    with:
      ref: ${{ needs.release-please.outputs.tag_name }}
```

**Version truth and gate pattern** (`.github/workflows/release-please.yml:101-116`):
```yaml
- name: Verify release version in mix.exs
  run: grep -n "@version \"${{ needs.release-please.outputs.version }}\"" mix.exs

- name: Dry run Hex publish
  run: mix hex.publish --dry-run --yes
```

**Post-publish visibility retry pattern** (`.github/workflows/release-please.yml:122-136`):
```yaml
- name: Verify version on Hex.pm
  run: |
    for i in $(seq 1 36); do
      if curl -fsS "https://hex.pm/api/packages/sigra/releases/${VERSION}" | grep -q "\"version\""; then
        exit 0
      fi
      sleep 10
    done
    exit 1
```

### `.github/workflows/hex-publish.yml` (config-workflow, event-driven)

**Analog:** `.github/workflows/hex-publish.yml`

**Manual recovery input contract pattern** (`.github/workflows/hex-publish.yml:9-19`):
```yaml
on:
  workflow_dispatch:
    inputs:
      tag: { required: true }
      release_version: { required: true }
```

**Release-ref + version guard pattern** (`.github/workflows/hex-publish.yml:40-43`, `66-68`):
```yaml
- uses: actions/checkout@...
  with:
    ref: ${{ inputs.tag }}
- name: Verify release version in mix.exs
  run: grep -n "@version \"${{ inputs.release_version }}\"" mix.exs
```

### `release-please-config.json` (config, transform)

**Analog:** `release-please-config.json`

**One-time release override pattern** (`release-please-config.json:6-11`):
```json
"packages": {
  ".": {
    "include-v-in-tag": true,
    "release-as": "1.0.0"
  }
}
```

### `mix.exs` (config, transform)

**Analog:** `mix.exs`

**Source-link truth pattern** (`mix.exs:181-183`):
```elixir
# before mix hex.publish, ensure git tag v#{@version} exists ...
source_ref: "v#{@version}",
source_url: @source_url,
```

## Shared Patterns

### Release Ref Immutability
**Source:** `.github/workflows/release-please.yml:69-72`, `.github/workflows/hex-publish.yml:40-43`  
**Apply to:** Release/publish workflow steps and runbook instructions
```yaml
with:
  ref: ${{ needs.release-please.outputs.tag_name }}   # automated path
with:
  ref: ${{ inputs.tag }}                               # manual recovery path
```

### Version Cross-Check Guard
**Source:** `.github/workflows/release-please.yml:101-103`, `.github/workflows/hex-publish.yml:66-68`  
**Apply to:** Gate matrix and publish/recovery checklists
```yaml
run: grep -n "@version \"${{ ...version... }}\"" mix.exs
```

### Dry-Run Then Publish
**Source:** `.github/workflows/release-please.yml:112-120`, `.github/workflows/hex-publish.yml:83-91`  
**Apply to:** Automated and manual publish branches
```yaml
run: mix hex.publish --dry-run --yes
run: mix hex.publish --yes
```

### CI-As-Truth Evidence Routing
**Source:** `.github/workflows/ci.yml:122-169`, `.github/workflows/ci.yml:269-319`, `.github/workflows/ci.yml:538-603`, `.github/workflows/ci.yml:602-773`, `.github/workflows/ci.yml:859-910`  
**Apply to:** Release gate matrix rows for required lanes
```yaml
library_tests
install_smoke
example_http_smoke
example_playwright_smoke
generated_admin_playwright_smoke
```

### Maintainer Pointer Surface
**Source:** `MAINTAINING.md:144-156`, `docs/NEXT-STEPS-MANUAL.md:3-6`, `docs/ga-evidence.md:3-16`  
**Apply to:** Keep runbook canonical in one file; other docs route to it
```markdown
Do not duplicate full matrix here.
Use this page as router/pointer.
```

## No Analog Found

None. All scoped file types already exist with strong analogs.

## Metadata

**Analog search scope:** `docs/`, `.github/workflows/`, `scripts/`, root config/docs files  
**Files scanned:** 11  
**Pattern extraction date:** 2026-05-31
