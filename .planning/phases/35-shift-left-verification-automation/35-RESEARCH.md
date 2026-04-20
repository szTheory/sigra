# Phase 35 — Technical Research

**Question:** What do we need to know to **plan** shift-left verification automation well?

### 1. Generator emission drift (INT-01..INT-03 class)

**Problem:** Templates under `priv/templates/sigra.install/` reference `<%= web_module %>.Module.Name` but `Sigra.Install.Features.*.files/1` can omit a file—runtime host compiles, installer “works”, integration gaps surface only in generated apps.

**Approach:**

- Partition template paths by top-level folder after `priv/templates/sigra.install/`: `admin` → `Sigra.Install.Features.Admin`, `core` → `Core`, `organizations` → `Organizations`, `passkeys` → `Passkeys`.
- Build a **canonical binding** in the test (minimal keyword list: `web_module: "ExampleWeb"`, `otp_app: :example`, `context_module: "Example.Accounts"`, …) matching patterns in `test/sigra/install/features/*_test.exs`.
- For each `.ex` / `.heex` template file, collect regex matches of `<%= web_module %>\.([A-Za-z0-9_.]+)`; normalize trailing segments to **expected relative template stem** by convention (`ExampleWeb.Admin.Foo` → `admin/foo.ex` or similar)—document the mapping once in test `@moduledoc`.
- Assert every match’s implied emitted path appears in **that feature’s** `files(binding)` output (string list second element of tuples).

**Pitfalls:** HEEx files may reference modules differently; only assert on generator **Elixir** templates first if HEEx is ambiguous; expand later.

### 2. Installer drift `must_not` generalization (INT-04)

**Current:** `installer_drift_test.exs` uses per-fixture `must_not` (e.g. dead `<span>Users</span>`).

**Extension:** Add one shared helper clause or **macro-less** loop over admin shell templates that forbids `<li>\s*<span[^>]*>` without a sibling `href` pattern for known nav labels—**prefer** a small set of high-signal regexes called out in ROADMAP (“dead-text navigation labels”) rather than parsing HEEx AST.

### 3. axe-core + Playwright screenshots

**Deps:** `@axe-core/playwright` (devDependency next to `@playwright/test@^1.48.0`). API: `import AxeBuilder from '@axe-core/playwright'` then `await new AxeBuilder({ page }).analyze()`; assert `violations` length === 0 with a capped pretty-print on failure.

**Screenshots:** Use `expect(page).toHaveScreenshot({ maxDiffPixels: N })` with committed snapshots; set `snapshotPathTemplate` or per-project `expect` options so **chromium / mobile / dark** get distinct files. Align snapshot names with `adminArtifactName()` slug scheme where possible.

**CI:** Existing jobs already run three checkpoint projects for example; extend **the same** pattern for generated-host project if not already tripled.

### 4. Milestone `VERIFICATION.md` gate

**Pattern:** `phase34-uat-contracts.sh` uses `grep -q` contracts on a known file. For Phase 35, script should:

- Parse `.planning/ROADMAP.md` “Progress” table rows for the **current milestone** (v1.2): for each line containing `| NN\.` and status **Complete**, require `.planning/phases/*/NN-*-VERIFICATION.md` exists (glob or fixed mapping table maintained in script for phases 27–35).

**Alternative (simpler v1):** Maintain explicit `REQUIRED_VERIFICATION_PHASES=(27 28 … 34)` array updated when phases close—less fragile than parsing Markdown tables.

**Recommendation:** Start with explicit array + `find` for `NN-*-VERIFICATION.md`; add comment “sync with ROADMAP when phase completes”.

### 5. Installer-scoped CI job

**Triggers:** `paths` filter in `ci.yml` on `priv/templates/sigra.install/**`, `lib/sigra/install/**`.

**Checks (bash):**

- `grep -q 'UsersIndexLive'` (and `UserShowLive`) in `priv/templates/sigra.install/admin/router_injection.ex`
- `grep -q 'defmodule'` in `priv/templates/sigra.install/admin/impersonation_controller.ex`
- `grep -q 'audit_export_controller'` in `lib/sigra/install/features/admin.ex` inside `files(` block (or assert path string in `files/1` list literals)

These mirror INT-01..INT-03 **detection**, not product logic.

### 6. Artifact bundle contract

**Count:** Five checkpoint names × three Playwright projects = **15** PNGs under `test/example/priv/playwright/artifacts/admin-checkpoints/` (or paths returned by `captureAdminCheckpoint`—confirm in CI upload list in `ci.yml`).

**Assertion:** After `npx playwright test tests/admin-checkpoints.spec.ts` with all three projects, shell script or small Node script verifies `find … -name '*.png' | wc -l` ≥ 15 and `stat` size ≥ **5000** bytes each (tune threshold in one constant).

**Docs:** Add `CONTRIBUTING.md` section “Reviewing admin CI artifacts” listing artifact job names, download steps, and the 15 PNG checklist.

---

## Validation Architecture

**Nyquist dimensions for this phase:**

| Dimension | How addressed |
|-----------|----------------|
| 1. Requirement traceability | Each plan maps to ROADMAP SC1–SC6 |
| 2. Automated verify per task | `mix test`, `npx playwright test`, `bash -n`, `bash scripts/ci/*.sh` |
| 3. Wave boundaries | Wave 1 = ExUnit gates; Wave 2 = Playwright; Wave 3 = CI scripts; Wave 4 = contract + docs |
| 4. Flake control | Screenshot `maxDiffPixels`; Playwright retries already in CI—preserve |
| 5. Security regression | Installer gates prevent shipping broken admin surface (availability/authz wiring) |
| 6. Performance | Installer job stays **grep-only** + optional `mix compile` skip |
| 7. Docs drift | `CONTRIBUTING.md` + gate script comments |
| 8. Sampling / continuity | `35-VALIDATION.md` per-task commands |

**Primary test commands:**

- `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/templates/generator_emission_audit_test.exs test/sigra/templates/installer_drift_test.exs`
- `cd test/example/priv/playwright && npm ci && npx playwright test tests/admin-checkpoints.spec.ts --project=admin-checkpoints-chromium --project=admin-checkpoints-mobile --project=admin-checkpoints-dark`

## RESEARCH COMPLETE
