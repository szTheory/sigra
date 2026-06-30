# v1.42 backlog integration — Fast checks snapshot-canary drift (milestone gate)

**Filed:** 2026-06-30 (during Phase 208.1 execution)
**Scope:** MILESTONE-INTEGRATION — NOT Phase 208.1. Surfaced by the first real CI run
on the v1.42 integration PR (#63, `ship/v1.42-ci-gate-remediation` → `main`).
**Severity:** Blocks a fully-green v1.42 backlog merge; does NOT block Phase 208.1
(whose exit criterion — `Example Playwright smoke (full lifecycle)` green — is met).

## What

The `fast_checks` CI job (`Fast checks (milestone/installer/contracts/snapshot/ledger guards)`)
fails on its **snapshot-canary-guard** step (`scripts/ci/snapshot-canary-guard.sh --base origin/main`).
It is the only red lane left on the integration PR that is **not** a Phase 208.1 regression.

Local reproduction (from repo root, `origin/main` fetched):
```
bash scripts/ci/snapshot-canary-guard.sh --base origin/main
# FAIL: unintended snapshot change: audit-explorer (modified) — not in allowlist
# FAIL: unintended snapshot change: user-audit (modified) — not in allowlist
# FAIL: unintended snapshot change: global-user-index (modified) — not in allowlist
# FAIL: unintended snapshot change: org-scoped-admin (modified) — not in allowlist
# FAIL: canary snapshot modified: 'impersonation-banner' must stay byte-green
```

## Root cause (verified)

These snapshot modifications are **cumulative backlog drift from Phases 200–204**, not 208.1.
The guard compares against the stale `origin/main` (the backlog is 314 commits ahead, never
pushed/PR'd), and the per-phase allowlist is reset to empty at each phase close — so every
snapshot recapture since `origin/main` shows as unallowlisted "drift". Commits responsible
(`git log origin/main..HEAD -- test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/`):

- `4c3ce3cf` test(200-03): add user-sessions snapshot baselines (3 projects)
- `af735d75` test(201-04): recapture global-user-index at list-scale + sync design gallery baselines
- `e7c5b0c7` test(202-05): recapture audit-explorer and user-audit checkpoint baselines
- `c96749fa` fix(204-03): raise .vt-status-pill contrast ≥4.5:1 + recapture mobile baselines
  → this is the one that modified the **impersonation-banner** canary (mobile) intentionally.

The design-lane board-* baselines also all show as changed (CI-native recapture in 208.1-04),
but the **design_gallery seam is green** on PR #63, so those match current CI rendering.

## Policy tension to resolve

`snapshot-canary-guard.sh` forbids ANY modify/delete of an established canary
(`impersonation-banner`). Phase 204-03 deliberately changed `impersonation-banner-mobile`
as part of a WCAG contrast fix. So the integration needs an explicit decision:
1. **Allowlist the legitimate slugs** — add `audit-explorer`, `user-audit`,
   `global-user-index`, `org-scoped-admin` (and the design board-* if the design-lane guard
   needs it) to the appropriate allowlist(s) for the integration PR.
2. **Canary decision** — either (a) revert `impersonation-banner-mobile` to `origin/main`'s
   byte version (re-opening 204-03's mobile contrast issue), or (b) re-baseline / re-designate
   the canary with a documented rationale, or (c) add a one-time integration exception.
   This is a cross-phase canary-discipline call — do NOT guess-fix.

## Suggested home

This is a strong candidate for the **Phase 209 "single binding gate"** referenced in STATE
(the IA/integration gate), or a dedicated v1.42 integration phase. Treat as the real
"can the v1.42 backlog merge cleanly" gate.

## Evidence pointers

- Integration PR: #63 (`ship/v1.42-ci-gate-remediation` → `main`, draft)
- Red run with full breakdown: gh run 28447218183 (first PR run)
- `Example Playwright smoke (full lifecycle)`: GREEN (24m51s) — phase 208.1 exit criterion met
- Phase 208.1's own regression (sudo copy → Library/Install red) fixed in `cbe0b928`
