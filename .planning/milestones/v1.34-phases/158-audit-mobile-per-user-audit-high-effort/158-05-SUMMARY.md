---
phase: 158-audit-mobile-per-user-audit-high-effort
plan: "05"
subsystem: admin-playwright
tags:
  - playwright
  - admin-checkpoints
  - user-audit
  - axe
  - zero-human-uat
  - audx-01
  - audx-02
  - audx-03
  - gate-01
  - gate-02
dependency_graph:
  requires:
    - 158-02 (AuditIndexLive dual-layout + quick-filter chips)
    - 158-03 (AuditUserLive dual-layout + chips + chrome)
    - 158-04 (UserShowLive compact audit_row)
  provides:
    - user-audit Playwright checkpoint x3 (chromium/mobile/dark), axe-gated
    - re-recorded audit-explorer baselines x3 (checked chip + dark contrast)
    - automated zero-human snapshot drift guard + recapture gate
  affects:
    - all future admin-HEEx phases (snapshot_drift_guard is a standing CI lane)
tech_stack:
  added: []
  patterns:
    - Self-justifying capture (assert tone-mapped DOM + chips + layout before screenshot)
    - Snapshot drift allowlist (committed manifest; empty steady-state)
    - Automated recapture gate (compare + guard + goldens replace human review)
key_files:
  created:
    - scripts/ci/snapshot-canary-guard.sh
    - scripts/ci/snapshot-recapture-gate.sh
    - test/example/priv/playwright/snapshot-allowlist
    - test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/user-audit-admin-checkpoints-chromium.png
    - test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/user-audit-admin-checkpoints-mobile.png
    - test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/user-audit-admin-checkpoints-dark.png
  modified:
    - test/example/priv/playwright/tests/admin-checkpoints.spec.ts
    - test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/audit-explorer-admin-checkpoints-{chromium,mobile,dark}.png
    - lib/sigra/admin/live/audit_index_live.ex
    - test/example/priv/static/assets/css/app.css
    - .github/workflows/ci.yml
decisions:
  - "Human-verify gate replaced by automation (user directive: zero human UAT, shift left to CI). Approval = scripts/ci/snapshot-recapture-gate.sh all-green."
  - "user-detail stayed BYTE-GREEN (not re-recorded): the spec's targetEmail is a dynamic user captured BEFORE the impersonation start/stop, so it has no impersonation rows at capture time. The 158-04 alice-demo-seed observation does not apply to the spec's dynamic user."
  - "Two real 158-02 bugs surfaced by the strengthened assertions + axe (would likely have been missed by human screenshot review): (1) chip checked-state atom-key bug; (2) dormant dark-mode WCAG contrast on the active chip."
  - "Global --sg-color-brand-strong dark-mode contrast gap deferred to a tracked todo (wide blast radius); only the narrow active-chip override applied here."
metrics:
  duration: "~1 session (incl. automation build + 2 bug fixes)"
  completed: "2026-06-04"
  tasks_completed: 2
  files_modified: 13
---

# Phase 158 Plan 05: user-audit checkpoint + automated zero-human baseline review

Added the `user-audit` Playwright checkpoint (GATE-01) and re-recorded the
`audit-explorer` baselines as intended deltas — but the plan's `checkpoint:human-verify`
gate (Task 2) was **replaced by automation** per the user's directive to shift
verification fully left (zero human UAT). The recording is approved by
`scripts/ci/snapshot-recapture-gate.sh` going all-green, and a standing CI lane now
prevents unintended baseline drift on every future PR.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | user-audit slug + self-justifying assertions + re-record baselines | 25ee1bf0 | admin-checkpoints.spec.ts + 6 PNGs |
| 2 | (was human-verify) → automated approval gate | 0d3c4d27 / b92777a4 | guard/gate scripts, allowlist, ci.yml, chip + css fixes |

## What Was Built

### user-audit checkpoint (GATE-01), self-justifying
Added to the authenticated journey after the impersonation STOP, across
chromium/mobile/dark. Before the screenshot it asserts: shared chrome
(`page_back` "Back to user", `scope_ribbon` "Global audit explorer"), per-project
layout (mobile cards visible / desktop table hidden and vice-versa), and an
impersonation row carrying `data-tone="info"` (the exact tone the ExUnit golden
pins). The screenshot is now a by-product of asserted-correct DOM. axe: 0
violations x3.

### audit-explorer strengthened + re-recorded (AUDX-02)
Asserts both quick-filter chips by real `name`/`value` ("Failures" outcome=failure;
"Impersonation" action_prefix=admin.impersonation), the active impersonation chip
is `checked`, and the dual-layout. Re-recorded x3 as intended deltas (the
now-correctly-checked chip + the dark contrast fix).

### Automated zero-human baseline review (the Task-2 replacement)
- `scripts/ci/snapshot-canary-guard.sh` — fails if any baseline PNG outside an
  explicit allowlist changes; slug-keyed across 3 projects; canary check;
  `--require-all`. Validated with positive + 3 negative tests (empty allowlist,
  declared-but-unchanged, canary touch).
- `test/example/priv/playwright/snapshot-allowlist` — committed intent manifest
  (declares `user-audit` + `audit-explorer` for this phase; reset to empty on merge).
- `scripts/ci/snapshot-recapture-gate.sh` — compare-mode spec (3 projects) +
  guard + ExUnit goldens (+ optional parity) = approval.
- `.github/workflows/ci.yml` — `snapshot_drift_guard` standing lane wired into `ci-gate`.

## Two real bugs surfaced (shift-left payoff)

1. **Chip checked-state bug (158-02):** `AuditIndexLive` chips read atom keys
   (`@current_params[:outcome]`/`[:action_prefix]`) against a string-keyed map →
   `checked` always nil → chips never reflected active filter. Fixed to
   `param_value/2` (matches the file's text inputs and `AuditUserLive`). Commit b92777a4.
2. **Dormant dark-mode WCAG fail (158-02):** fixing #1 made the active chip render,
   exposing `--sg-color-brand-strong` (#9a3412) on dark brand-soft (#412718) = 1.88:1.
   Narrow scoped dark override applied; **global** brand-strong dark gap (other
   brand-soft surfaces) tracked in
   `.planning/todos/pending/2026-06-04-admin-brand-strong-dark-contrast-gap.md`.

A human screenshot review would very likely have missed both.

## Deviations from Plan

- **Task 2 (human-verify) executed as automation, not a human gate** — per the
  user's explicit zero-human-UAT directive given mid-execution. The plan's
  intent (only intended deltas land; canaries intact; axe green; parity) is fully
  preserved, now machine-enforced and recurring in CI.
- **user-detail NOT re-recorded** (byte-green). The plan anticipated a possible
  user-detail delta from 158-04's impersonation tone; in the spec the targetEmail
  is a dynamic user captured before impersonation, so no delta exists. No surprise
  diff accepted.
- **Scope expanded** to fix the two 158-02 bugs the automation surfaced (both
  required for the axe gate + correct baselines).

## Verification

- `scripts/ci/snapshot-recapture-gate.sh user-audit audit-explorer` → PASS
  (compare 3/3 passed; guard PASS; goldens 19/0; parity CI-verified).
- `snapshot-canary-guard.sh` negative tests: empty allowlist FAILs; declared-but-
  unchanged FAILs; canary touch FAILs loudly. Canary restored byte-green.
- Final snapshot change set: `audit-explorer` x3 (M) + `user-audit` x3 (new);
  all 18 other slugs byte-green.
- `mix test` (root) — 2342 tests, 0 failures, 12 skipped.
- `mix test --include example_app` (host) — 266 tests, 0 failures.
- `mix compile --warnings-as-errors` (lib + example) — clean.
- ci.yml parses (YAML OK); `snapshot_drift_guard` in `ci-gate` needs + verify loop.

## Known Stubs

None.

## Threat Flags

- T-158-11 (info disclosure): user-audit captures the subject-scoped page; scoping
  unchanged (158-03). axe + asserted DOM confirm the intended scoped view.
- T-158-12 (baseline tampering): re-records now gated by the automated guard
  (allowlist) + recapture gate instead of human review — stronger, not weaker.

## Self-Check: PASSED

- user-audit slug present with tone-row + chrome + layout asserts (admin-checkpoints.spec.ts).
- 3 new user-audit PNGs + 3 re-recorded audit-explorer PNGs committed (25ee1bf0).
- Guard + gate scripts committed and validated (0d3c4d27); chip + css fixes (b92777a4).
- Root 2342/0, example 266/0, goldens 19/0; gate all-green.
