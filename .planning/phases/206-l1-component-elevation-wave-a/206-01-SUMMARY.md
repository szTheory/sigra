---
phase: "206"
plan: "01"
subsystem: ci-guards
status: complete
tags: [ci, css, conformance, guard, scripts]
completed: "2026-06-28"
duration: "~5m"

dependency_graph:
  requires: []
  provides:
    - scripts/ci/admin-css-conformance.sh
    - scripts/ci/admin-css-conformance.test.sh
  affects:
    - priv/templates/sigra.install/admin/sigra_admin.css
    - test/example/priv/static/assets/sigra_admin.css
    - test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css

tech_stack:
  added: []
  patterns:
    - grep-based CSS conformance guard (sibling of quality-ledger-monotonic.sh)
    - hermetic mktemp CSS fixture pattern for self-tests

key_files:
  created:
    - scripts/ci/admin-css-conformance.sh
    - scripts/ci/admin-css-conformance.test.sh
  modified:
    - priv/templates/sigra.install/admin/sigra_admin.css
    - test/example/priv/static/assets/sigra_admin.css
    - test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css

decisions:
  - "Guard checks: (a) no transition:all shorthand, (b) no raw hex outside :root blocks"
  - "Guard accepts positional arg or --css flag; defaults to sigra_admin.css template"
  - "ROOT auto-derived from BASH_SOURCE[0] following quality-ledger-monotonic.sh pattern"
  - "Lone raw-hex violation (.sg-btn--danger.is-armed color: #fff) fixed to var(--sg-color-on-brand) in source template + both generated copies for byte coherence (D-03)"
  - "Self-test uses 7 tests/10 assertions with hermetic mktemp fixtures; no real-repo side effects"

metrics:
  tasks_completed: 2
  tasks_total: 2
  files_created: 2
  files_modified: 3
  deviations: 1
---

# Phase 206 Plan 01: Admin CSS Conformance Guard Summary

**One-liner:** Grep-based CI guard asserting no `transition:all` and no raw hex outside `:root`, with hermetic self-test — plus lone `#fff` violation fixed to token reference.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Build admin-css-conformance.sh guard | 1c4af42d | scripts/ci/admin-css-conformance.sh, sigra_admin.css (×3) |
| 2 | Build admin-css-conformance.test.sh self-test | 695d3752 | scripts/ci/admin-css-conformance.test.sh |

## What Was Built

### Task 1: admin-css-conformance.sh

A lightweight grep-based CI guard that asserts two CSS conformance invariants across a CSS file:

- **CHECK 1:** No `transition: all` shorthand anywhere in the file (use specific transition properties)
- **CHECK 2:** No raw hex color literals outside `:root` token-definition blocks (use `var()` references)

Follows the `quality-ledger-monotonic.sh` sibling shape:
- `ROOT` auto-derived from `BASH_SOURCE[0]`
- `set -euo pipefail`
- `fail()` helper echoes to stderr with `admin-css-conformance: FAIL:` prefix and exits 1
- Named `PASS/FAIL` output prefix on every status line
- `--help` and unknown-arg guard (exit 2 on bad args)
- Positional argument or `--css <path>` flag for reuse in phases 207-211
- Defaults to `ROOT/priv/templates/sigra.install/admin/sigra_admin.css`

The awk-based `:root` tracker handles nested braces correctly, including the dual `:root` pattern (`@media (prefers-color-scheme: dark) { :root { ... } }`).

### Task 2: admin-css-conformance.test.sh

A hermetic self-test that proves the guard correctly rejects injected violations and accepts clean files. Uses `mktemp` CSS fixtures — no real-repo side effects.

Tests:
- **Test A:** Clean CSS (hex only in `:root`, `var()` outside) → exits 0, emits PASS
- **Test B:** `transition: all 0.2s` injection → exits non-zero; stderr contains `transition: all`
- **Test C:** Raw `#fff` outside `:root` → exits non-zero; output shows hex violation
- **Test D:** Dual `:root` blocks (light + dark `@media`) → exits 0 (all hex protected)
- **Test E:** `--css` flag routes to given file → exits 0 on clean file
- **Test F:** Positional arg overrides default → exits non-zero on violation file
- **Test G:** No real-repo side effects (git status shows no unexpected dirty files)

Result: **10/10 assertions pass**; summary line: "10 passed, 0 failed"

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed lone raw hex violation: .sg-btn--danger.is-armed color: #fff**

- **Found during:** Task 1 — guard exits 1 on current CSS due to line 506 `color: #fff`
- **Issue:** The plan context explicitly mentions "mirrors the real gap at sigra_admin.css:506" as the known violation case. The guard cannot exit 0 on the current CSS until this is fixed.
- **Fix:** Replaced `color: #fff` with `color: var(--sg-color-on-brand)` — the `--sg-color-on-brand` token is `#ffffff` in both light and dark modes, appropriate for text on the red danger armed background.
- **Files modified:**
  - `priv/templates/sigra.install/admin/sigra_admin.css` (source template)
  - `test/example/priv/static/assets/sigra_admin.css` (generated copy — byte-coherent per D-03)
  - `test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css` (golden fixture — byte-coherent per D-03)
- **Commit:** 1c4af42d

This was a Rule 1 auto-fix: the task acceptance criterion requires the guard to exit 0 on the current CSS, which required removing the violation that blocked it.

## Verification Results

```
bash scripts/ci/admin-css-conformance.sh
→ admin-css-conformance: PASS — ...sigra_admin.css

bash scripts/ci/admin-css-conformance.test.sh
→ Results: 10 passed, 0 failed
→ admin-css-conformance.test: PASS

test -x scripts/ci/admin-css-conformance.sh  → passes
test -x scripts/ci/admin-css-conformance.test.sh  → passes
```

## Known Stubs

None. Both scripts are fully implemented and operational.

## Threat Flags

No new threat surface beyond what the plan's threat model already covers (T-206-01, T-206-02 — both accepted as low-severity).

## Self-Check: PASSED

- `/Users/jon/projects/sigra/scripts/ci/admin-css-conformance.sh` — FOUND
- `/Users/jon/projects/sigra/scripts/ci/admin-css-conformance.test.sh` — FOUND
- Commit `1c4af42d` — FOUND in git log
- Commit `695d3752` — FOUND in git log
