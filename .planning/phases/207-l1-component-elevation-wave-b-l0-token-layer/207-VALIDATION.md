---
phase: 207
slug: l1-component-elevation-wave-b-l0-token-layer
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-28
---

# Phase 207 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Derived from `207-RESEARCH.md` § Validation Architecture. Zero-human UAT: every
> success criterion maps to an automated gate.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Playwright (admin-design lane) + bash CI guards + ExUnit (golden/component) |
| **Config file** | `test/example/priv/playwright/playwright.config.*` (projects: admin-design-chromium / -mobile / -dark) |
| **Quick run command** | `bash scripts/ci/admin-css-conformance.sh && bash scripts/ci/admin-token-completeness.sh && bash scripts/ci/quality-ledger-monotonic.sh --base origin/main` |
| **Full suite command** | `bash scripts/ci/snapshot-recapture-gate.sh <affected-slug…>` (boots example, 3 projects, goldens, canary guard) |
| **Estimated runtime** | static guards ~sub-second each; recapture gate ~minutes (only if CSS edits land) |

---

## Sampling Rate

- **After every task commit:** Run `admin-css-conformance.sh` + `admin-token-completeness.sh` + `quality-ledger-monotonic.sh --base origin/main` (all sub-second static checks)
- **After every plan wave:** Re-run the three static guards; run `snapshot-recapture-gate.sh <slug>` only if a CSS edit landed
- **Before `/gsd-verify-work`:** All guards exit 0; both allowlists empty; canaries (`impersonation-banner`, `board-notice`) byte-stable; full L0/L1 ledger column reads `2`
- **Max feedback latency:** < 5 seconds for static guards (recapture is opt-in, only on CSS change)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 207-01-* | 01 | 1 | COMP-03 | — | Bash guard reads repo files only; quoted expansions, no eval | CI guard | `bash scripts/ci/admin-token-completeness.test.sh` | ❌ W0 | ⬜ pending |
| 207-01-* | 01 | 1 | COMP-03 | — | N/A | CI guard | `bash scripts/ci/admin-token-completeness.sh` | ❌ W0 | ⬜ pending |
| 207-02-* | 02 | 1 | COMP-02 | — | Components axe-clean ×3 projects; no `transition: all`; reduced-motion stripped | e2e/axe | `admin-design.spec.ts` board specs (5 component boards × chromium/mobile/dark) | ✅ | ⬜ pending |
| 207-02-* | 02 | 1 | COMP-02 | — | N/A | CI guard | `bash scripts/ci/admin-css-conformance.sh` (motion + hex; +px if D-07 automated) | ✅ | ⬜ pending |
| 207-03-* | 03 | 2 | COMP-02, COMP-03 | — | Affected board PNGs recaptured; canaries byte-stable | snapshot | `bash scripts/ci/snapshot-recapture-gate.sh <slug…>` (no-op if no CSS edit) | ✅ | ⬜ pending |
| 207-04-* | 04 | 2 | COMP-02, COMP-03 | — | 6 rows → bare `2`; entire L0/L1 column `2` | CI guard | `bash scripts/ci/quality-ledger-monotonic.sh --base origin/main` | ✅ | ⬜ pending |

*Plan/wave shape is the recommended Phase-206 mirror (guards → audit → recapture/doc → ledger flip); the planner owns final task IDs.*
*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Success Criterion → Automated Proof Map

| # | Success Criterion | Concrete Automated Proof |
|---|-------------------|--------------------------|
| 1 | 5 components (`empty_state`, `page_back`, `scope_ribbon`, `field_help`, `skeleton`) axe-clean across chromium/mobile/dark; no `transition: all`; reduced-motion respected | `admin-design.spec.ts` → `assertBoardScreenshot('board-{empty-state,page-back,scope-ribbon,field-help,skeleton}')` runs `assertNoAxeViolations` (wcag2a/2aa/21a/21aa/22aa) + `toHaveScreenshot` ×3 projects; skeleton reduced-motion assertion (~653–677); field_help Escape+focus-restore (~695–711); motion guard `admin-css-conformance.sh` CHECK 1 (no `transition: all`) |
| 2 | L0 token conformance (no raw hex/px outside `--sg-*`; light/dark/system parity); `admin-token-reference.md` cites evidence | `admin-css-conformance.sh` CHECK 2 (no raw hex outside `:root`) **+ NEW** `admin-token-completeness.sh` (100/100 `:root` tokens == doc backticks) **+ NEW** narrow D-07 px check **OR** documented D-07a manual review; doc refreshed to cite the guard(s) |
| 3 | 5 component rows + `token-layer` row flipped to bare `2`; monotonic guard exits 0 | `quality-ledger-monotonic.sh --base origin/main` exits 0 (`awk -F'|'` col-4 bare-integer parse; 36 cells at baseline) |
| 4 | All 13 L1 cells + L0 cell read `2` | Same monotonic guard + visual ledger inspection; entire L0/L1 column == `2` |

---

## Wave 0 Requirements

- [ ] `scripts/ci/admin-token-completeness.sh` — NEW, covers COMP-03 criterion 2 (D-06): parse `--sg-*` `:root` LHS defs in `sigra_admin.css`, diff against documented backtick tokens in `admin-token-reference.md`, fail on divergence (100/100 at baseline)
- [ ] `scripts/ci/admin-token-completeness.test.sh` — NEW hermetic self-test (mirrors `admin-css-conformance.test.sh`)
- [ ] (optional) raw-px extension to `admin-css-conformance.sh` (D-07) **OR** a documented manual-review note in `admin-token-reference.md` (D-07a) — 38 current px occurrences are ~all legitimate, so prefer a narrow regex or take the pre-authorized fallback

*Everything else (axe harness, screenshot lane, motion/hex guard, monotonic guard, recapture gate, golden/component tests) already exists and is green — no additional Wave 0 work.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| D-07a raw-px review (only if the automated px check is abandoned as too noisy) | COMP-03 | 38 px occurrences are ~all legitimate (breakpoints, 1px hairlines, shadow/transform geometry, `border-radius: 999px`, a11y clip); a naive sweep is a false-positive trap | Document the reviewed px set in `admin-token-reference.md` as a target-size-style manual proxy; D-06 completeness guard remains the load-bearing COMP-03 proof |

*If the D-07 narrow regex lands clean, this row becomes N/A — prefer the automated path.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (`admin-token-completeness.sh` + self-test)
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s for static guards
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
