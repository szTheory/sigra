# Phase 35: Shift-Left Verification Automation — Context

**Gathered:** 2026-04-17  
**Status:** Complete — phase executed 2026-04-17 (6/6 plans; see `35-VERIFICATION.md` and `35-*-SUMMARY.md`)  
**Source:** `.planning/ROADMAP.md` Phase 35 block (discuss-phase not run; roadmap success criteria treated as locked scope)

<domain>

## Phase boundary

Deliver **machine gates** that would have caught INT-01–INT-04 **before** the v1.2 milestone audit, and automate mechanically verifiable items from Phase 30/31 human-UAT notes (audit explorer readability signals where possible; artifact bundle **presence and size** contract).

Out of scope: replacing human judgment on “is this UX good”; rewriting product features beyond what gates require.

</domain>

<decisions>

## Locked decisions (from roadmap)

### D-35.1 — Generator emission audit (SC1)

- Add `test/sigra/templates/generator_emission_audit_test.exs` that scans `priv/templates/sigra.install/**` for EEx references of the form `<%= web_module %>.*` and asserts each implied host module is covered by that template file’s owning feature’s `files/1` list (partition templates by `admin/`, `core/`, `organizations/`, `passkeys/` → `Sigra.Install.Features.Admin` / `Core` / `Organizations` / `Passkeys`).

### D-35.2 — Dead-text / nav drift (SC2)

- Extend `test/sigra/templates/installer_drift_test.exs` with **generalized** `must_not` patterns for “navigation label rendered as inert `<span>` inside `<li>`” class (INT-04), not only the Users row—keep the existing fixture discipline (`@fixtures` list, repo-root anchoring).

### D-35.3 — Accessibility + visual baselines (SC3)

- Add `@axe-core/playwright` violations scan at each of the **five** curated checkpoint pages in `tests/admin-checkpoints.spec.ts` (and parity on generated-host lane where those checkpoints exist in `admin-generated.spec.ts`).
- Add Playwright `expect(page).toHaveScreenshot(...)` (or `toHaveScreenshot` on locator) with **committed** baselines for the same five views × **three** projects (`admin-checkpoints-chromium`, `admin-checkpoints-mobile`, `admin-checkpoints-dark`) defined in `test/example/priv/playwright/playwright.config.ts`; extend to generated-host project names as applicable so **15** PNG contracts (5×3) are meaningful.

### D-35.4 — Milestone verification doc gate (SC4)

- Add `scripts/ci/milestone-verification-gate.sh` and wire it into `.github/workflows/ci.yml` so merges cannot leave a v1.2 roadmap phase without a matching `NN-VERIFICATION.md` under `.planning/phases/` when that phase is marked complete in `ROADMAP.md` (mechanical grep/table contract—mirror rigor of `scripts/ci/phase34-uat-contracts.sh`).

### D-35.5 — Installer-scoped pre-merge audit (SC5)

- New CI job **on PR paths** touching `priv/templates/sigra.install/**` OR `lib/sigra/install/**` that runs a **fast** shell gate derived from `.planning/milestones/v1.2-MILESTONE-AUDIT.md` integration **critical** items (INT-01..INT-03 minimum: router mounts, controller templates emitted, `Features.Admin.files/1` includes audit export + impersonation templates).

### D-35.6 — Artifact bundle contract (SC6)

- Automated assertion that all **15** expected checkpoint PNGs exist and exceed a **minimum byte size** floor after a full admin-checkpoints run; document reviewer steps in **`CONTRIBUTING.md`** (create at repo root if absent).

</decisions>

<canonical_refs>

## Canonical references

**Downstream agents MUST read these before implementing.**

### Roadmap / audit

- `.planning/ROADMAP.md` — Phase 35 success criteria (SC1–SC6)
- `.planning/milestones/v1.2-MILESTONE-AUDIT.md` — INT-01..INT-05 definitions for installer-scoped gate

### Existing gates (patterns)

- `test/sigra/templates/installer_drift_test.exs` — drift fixture discipline
- `scripts/ci/phase34-uat-contracts.sh` — mechanical doc + shell gate style
- `.github/workflows/ci.yml` — `example_playwright_smoke`, `generated_admin_playwright_smoke` jobs

### Playwright / checkpoints

- `test/example/priv/playwright/tests/admin-checkpoints.spec.ts` — five checkpoint journey
- `test/example/priv/playwright/tests/admin-generated.spec.ts` — generated-host captures
- `test/example/priv/playwright/playwright.config.ts` — project partitioning
- `test/example/priv/playwright/helpers/adminArtifacts.ts` — naming + paths

### Installer source of truth

- `lib/sigra/install/features/core.ex` — `files/1` shape
- `lib/sigra/install/features/admin.ex` — `files/1` + admin templates
- `lib/sigra/install/features/organizations.ex`, `lib/sigra/install/features/passkeys.ex`

</canonical_refs>

<specifics>

## Notes

- `gsd-sdk query` is unavailable in this workspace; planning was executed manually with the same artifacts the workflow expects.

</specifics>

<deferred>

## Deferred

- Full pixel-diff policy for **all** admin specs (only the five curated checkpoints + three projects per roadmap).
- Broader milestone audit score automation (beyond INT critical greps).

</deferred>

---

_Phase: 35-shift-left-verification-automation_
