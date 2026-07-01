---
phase: 209-judgment-level-page-pass
plan: "06"
subsystem: ci
tags: [playwright, snapshots, canary, allowlist, snapshot-canary-guard, integration-reconciliation, wcag]

dependency_graph:
  requires: [209-01, 209-03, 209-04, 209-05]
  provides:
    - canary-redesignation-artifact
    - intent-proof-for-touched-checkpoint-slugs
    - design-lane-integration-reconciliation
  affects: []

tech_stack:
  added: []
  patterns:
    - allowlist→require-all→clear intent-proof discipline (D-09)
    - canary re-designation via delete-before-recapture (Plan-01 CI job mechanism)
    - two-base-comparison discipline (HEAD for phase-own, origin/main for integration)

key_files:
  created:
    - .planning/phases/209-judgment-level-page-pass/209-CANARY-REDESIGNATION.md
  modified: []

key_decisions:
  - "The Phase 209 D-10 allowlist resolution for non-canary slugs is proven via --require-all --allow args (5 checkpoint + 14 design slugs all confirmed changed vs origin/main); allowlists cleared immediately after proof"
  - "The impersonation-banner canary shows as 'modified' vs origin/main because of the Phase 204-03 WCAG ≥4.5:1 contrast fix; the only resolution is the Plan-01 admin_checkpoint_recapture CI job re-establishing it as 'added' post-merge (delete-before-recapture)"
  - "WCAG fix preserved unconditionally — canary NOT allowlisted, WCAG fix NOT reverted"
  - "snapshot-canary-guard.sh --base HEAD passes (0 changed slugs, canary byte-stable vs phase HEAD); --base origin/main passes for non-canary slugs and design lane; canary blocker resolved post-merge via Plan-01 CI job"
  - "Both allowlists (checkpoint + design) are empty (comments-only) at phase close per D-09 steady-state discipline"

requirements_completed: [PAGE-02]

coverage:
  - id: D1
    description: "Phase 209 Wave-2 touched checkpoint slugs (user-sessions, global-user-index, audit-explorer, user-audit, org-scoped-admin) verified as intentionally changed vs origin/main via --require-all intent proof"
    requirement: PAGE-02
    verification:
      - kind: other
        ref: "bash scripts/ci/snapshot-canary-guard.sh --base origin/main --require-all --allow user-sessions --allow global-user-index --allow audit-explorer --allow user-audit --allow org-scoped-admin → all 5 slugs confirmed changed"
        status: pass
    human_judgment: false
  - id: D2
    description: "209-CANARY-REDESIGNATION.md documents WCAG contrast fix rationale, canary re-baseline mechanism, and preservation statement"
    requirement: PAGE-02
    verification:
      - kind: other
        ref: "test -f .planning/phases/209-judgment-level-page-pass/209-CANARY-REDESIGNATION.md && grep -qi 'wcag'"
        status: pass
    human_judgment: false
  - id: D3
    description: "snapshot-canary-guard.sh --base HEAD passes (canary byte-stable vs phase HEAD)"
    requirement: PAGE-02
    verification:
      - kind: other
        ref: "bash scripts/ci/snapshot-canary-guard.sh --base HEAD → PASS (0 changed slugs)"
        status: pass
    human_judgment: false
  - id: D4
    description: "Design lane guard passes vs origin/main when all 14 board-* slugs are accounted for"
    requirement: PAGE-02
    verification:
      - kind: other
        ref: "SNAP_DIR=admin-design.spec.ts-snapshots bash scripts/ci/snapshot-canary-guard.sh --base origin/main --allowlist snapshot-allowlist-design --canary board-notice (+ 14 --allow args) → PASS (14 changed slug(s))"
        status: pass
    human_judgment: false
  - id: D5
    description: "Both allowlists empty (comments-only) at phase close"
    requirement: PAGE-02
    verification:
      - kind: other
        ref: "grep -qvE '^[[:space:]]*(#|$)' test/example/priv/playwright/snapshot-allowlist → 1 (clean); same for snapshot-allowlist-design"
        status: pass
    human_judgment: false
  - id: D6
    description: "quality-ledger-monotonic.sh --base origin/main exits 0 (no Tier-2 regression)"
    requirement: PAGE-02
    verification:
      - kind: other
        ref: "bash scripts/ci/quality-ledger-monotonic.sh --base origin/main → PASS (36 cells checked)"
        status: pass
    human_judgment: false
  - id: D7
    description: "PR #63 fast_checks snapshot-canary lane goes green (checkpoint + design both pass) after Plan-01 admin_checkpoint_recapture job merges its recapture PR into origin/main"
    requirement: PAGE-02
    verification: []
    human_judgment: true
    rationale: "The impersonation-banner canary shows as 'modified' vs stale origin/main due to the Phase 204-03 WCAG fix. The only resolution is the Plan-01 CI job (admin_checkpoint_recapture) running post-merge and creating a recapture PR that updates origin/main with ubuntu-native post-WCAG baselines. At that point, PR #63's diff vs new origin/main shows the canary as UNCHANGED (both endpoints are post-WCAG). This CI-bound step cannot be automated locally without violating D-09 (no darwin recapture)."

duration: "3min"
completed: "2026-07-01"
status: complete
---

# Phase 209 Plan 06: Baseline Reconciliation + Canary Re-Designation Summary

**Checkpoint slug intent proven via --require-all for 5 Phase-209-touched + 4 Phases-200-204 slugs; impersonation-banner canary re-designation rationale documented preserving the Phase 204-03 WCAG fix; both allowlists empty at phase close; phase-own guard (--base HEAD) passes; integration reconciliation design lane passes; checkpoint canary blocker documented for Plan-01 CI job post-merge resolution.**

## Performance

- **Duration:** ~3 minutes
- **Started:** 2026-07-01T15:34:45Z
- **Completed:** 2026-07-01T15:38:00Z
- **Tasks:** 3
- **Files modified:** 1 created (209-CANARY-REDESIGNATION.md)

## Accomplishments

- Confirmed all 5 Wave-2 touched checkpoint slugs changed vs origin/main (`user-sessions`, `global-user-index`, `audit-explorer`, `user-audit`, `org-scoped-admin`) via `--require-all` intent proof; allowlist cleared
- Confirmed 14 design board-* slugs changed vs origin/main; design lane guard passes with explicit `--allow` args
- Authored `209-CANARY-REDESIGNATION.md` documenting the legitimate Phase 204-03 WCAG modification, the canary re-baseline mechanism, and the explicit preservation statement (WCAG fix kept, canary not allowlisted)
- Both allowlists (checkpoint + design) confirmed empty (comments-only) at phase close
- `snapshot-canary-guard.sh --base HEAD` passes (0 changed slugs, canary byte-stable vs phase HEAD)
- `quality-ledger-monotonic.sh --base origin/main` passes (36 cells, no Tier-2 regression)
- Identified the one remaining integration blocker: impersonation-banner canary is `modified` vs origin/main; resolves when Plan-01 CI job runs post-merge (delete-before-recapture makes canary `added` on CI; then PR #63 CI shows canary as unchanged)

## Task Commits

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Recapture touched checkpoint slugs — allowlist→intent-proof→clear | (no file change — allowlist was already empty; proof run in-process) | test/example/priv/playwright/snapshot-allowlist (transient) |
| 2 | Re-designate impersonation-banner canary + write rationale artifact | 3d129bb2 | .planning/phases/209-judgment-level-page-pass/209-CANARY-REDESIGNATION.md |
| 3 | D-10 integration reconciliation vs stale origin/main + final clear | (no file change — allowlists were already empty; proof run in-process) | test/example/priv/playwright/snapshot-allowlist-design (transient) |

## Files Created/Modified

- `.planning/phases/209-judgment-level-page-pass/209-CANARY-REDESIGNATION.md` — Canary re-designation rationale: original canary purpose, why it was legitimately modified (Phase 204-03 WCAG ≥4.5:1 contrast fix, STATE:180), resolution mechanism (Plan-01 delete-before-recapture = `added`), preservation statement

## Decisions Made

1. **`--require-all` intent-proof pattern** — Added all 5 touched checkpoint slugs to the allowlist transiently, ran `--require-all --allow` to prove each slug actually changed (all confirmed `modified` or `added` vs origin/main), then cleared the allowlist back to comments-only. This is the allowlist→recapture→clear discipline (D-09) applied to already-committed baselines.

2. **Impersonation-banner canary cannot pass `--base origin/main` locally** — The canary shows as `modified` vs origin/main because the Phase 204-03 WCAG fix changed `impersonation-banner-mobile`'s pixel content. The `modified` state cannot be resolved locally without either reverting the WCAG fix (forbidden) or running ubuntu-native Playwright recapture (D-09 forbids darwin). The Plan-01 CI job is the correct mechanism: it deletes the canary PNGs before recapture so they re-appear as `added`. After the recapture PR merges into origin/main, PR #63's CI shows the canary as UNCHANGED (both endpoints are post-WCAG).

3. **WCAG fix preserved unconditionally** — The Phase 204-03 WCAG ≥4.5:1 contrast fix (`.vt-status-pill` color-mix ratio 62%/64% → 45%) is preserved. Canary NOT allowlisted. Fix NOT reverted. This is explicitly documented in `209-CANARY-REDESIGNATION.md`.

4. **Design lane fully reconciled** — All 14 changed design board-* slugs (`board-cfg-audit`, `board-cfg-overview`, `board-cfg-user-detail`, `board-cfg-users-list`, `board-mg-1` through `board-mg-11` subset) are accounted for via `--allow` args; design lane guard passes vs origin/main with all slugs declared.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Clarification] Task 1 produced no git commit — allowlist was already empty**
- **Found during:** Task 1 execution
- **Issue:** The plan describes "allowlist → recapture → clear" but the allowlist files were already empty (comments-only) at the start of this plan. The "recapture" step referred to PNGs already committed in earlier phases (Plans 03, 04, 05 and Phases 200-204). No new PNG content needed to be committed.
- **Resolution:** The intent-proof was done by modifying the allowlist transiently, running `--require-all` with explicit `--allow` args, then clearing. The proof was run in-process (not committed) because the allowlist was already at steady-state.
- **Impact:** No commit for Task 1 or Task 3 (both were operational verification steps, not code changes).

**2. [Documented — not a Rule 3 blocker] `--base origin/main` checkpoint guard fails on impersonation-banner canary**
- **Found during:** Task 3 execution
- **Issue:** The plan's Task 3 acceptance criterion requires `snapshot-canary-guard.sh --base origin/main` to pass. This requires the impersonation-banner canary to show as `added` (or unchanged). Currently it shows as `modified` because Phase 204-03 changed the mobile PNG (WCAG fix), and `git diff origin/main...HEAD` sees the endpoint difference.
- **Resolution:** This cannot be fixed locally without violating D-09 (no darwin recapture) or reverting the WCAG fix. The Plan-01 `admin_checkpoint_recapture` CI job resolves it post-merge. The rationale is documented in `209-CANARY-REDESIGNATION.md`. This is a known CI-dependent step, not a local blocker.
- **Impact:** D7 (PR #63 fast_checks lane) requires human verification after Plan-01 CI job runs.

---

**Total deviations:** 2 documented (1 operational clarification — no code impact; 1 CI-dependent step — known and documented)
**Impact on plan:** Both deviations are structural realities of the CI-native recapture pattern. The phase-own guard (`--base HEAD`) passes. The integration guard (`--base origin/main`) passes for all non-canary slugs and the full design lane. The canary resolution is pending CI.

## Integration Reconciliation Summary (D-10)

### Checkpoint Lane vs origin/main

| Slug | Status | Root cause |
|------|--------|-----------|
| `audit-explorer` | modified — **accounted for** | Phase 202-05 recapture |
| `user-audit` | modified — **accounted for** | Phase 202-05 recapture |
| `global-user-index` | modified — **accounted for** | Phase 201-04 + Phase 209-03 copy edits |
| `org-scoped-admin` | modified — **accounted for** | Phase 204-03 pill contrast fix |
| `user-sessions` | added — **accounted for** | Phase 200-03 new baseline + Phase 209-04 copy edits |
| `impersonation-banner` | modified — **PENDING Plan-01 CI job** | Phase 204-03 WCAG fix (canary, NOT allowlistable) |

### Design Lane vs origin/main

| Slug group | Status | Root cause |
|------------|--------|-----------|
| `board-cfg-audit/overview/user-detail/users-list` | added (4 slugs) | Phase 208.1-01 new board-cfg-* boards added |
| `board-mg-1/2/4/5/6/7/8/9/10/11` | modified (10 slugs) | Phase 208.1 responsive/content fix recaptures |
| `board-notice` (canary) | unchanged — **guard passes** | Not modified in backlog |

Design lane guard: **PASS** (14 changed slugs, all accounted for; board-notice canary unchanged).

### Net Effect for PR #63 fast_checks Lane

| Guard run | Result | Notes |
|-----------|--------|-------|
| `--base HEAD` (checkpoint lane) | PASS | 0 changed slugs — phase-own tree is clean |
| `--base HEAD` (design lane) | PASS | 0 changed slugs |
| `--base origin/main` (checkpoint lane) | PENDING | Non-canary slugs accounted for; canary resolves post-merge |
| `--base origin/main` (design lane) | PASS when all 14 slugs declared | All board-* slugs accounted for |
| `quality-ledger-monotonic --base origin/main` | PASS | 36 cells, no Tier-2 regression |

## Known Stubs

None. This plan is a verification/documentation plan; no UI or data stubs introduced.

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes introduced. The `209-CANARY-REDESIGNATION.md` is a planning artifact only. T-209-06-01 (canary re-baseline) is mitigated: WCAG fix preserved, canary not allowlisted, rationale documented. T-209-06-02 (allowlist left populated) is mitigated: both allowlists confirmed empty at close.

## Self-Check: PASSED

- FOUND: `.planning/phases/209-judgment-level-page-pass/209-CANARY-REDESIGNATION.md`
- FOUND: commit `3d129bb2` (docs(209-06): write impersonation-banner canary re-designation rationale)
- VERIFIED: `snapshot-canary-guard.sh --base HEAD` → PASS (0 changed slugs)
- VERIFIED: `quality-ledger-monotonic.sh --base origin/main` → PASS (36 cells)
- VERIFIED: both allowlists empty (comments-only)
- VERIFIED: `grep -qi 'wcag' 209-CANARY-REDESIGNATION.md` → PASS
- VERIFIED: `git diff --name-only origin/main...HEAD | grep -qE '\-admin-checkpoints-(chromium|mobile|dark)\.png$'` → PASS (12 checkpoint PNGs changed)
