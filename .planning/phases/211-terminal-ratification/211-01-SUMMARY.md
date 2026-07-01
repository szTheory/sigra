---
phase: 211-terminal-ratification
plan: "01"
subsystem: testing
tags: [playwright, snapshot, canary, quality-ledger, ci-gates, ratification]

requires:
  - phase: 210
    provides: "All 36 quality ledger tier cells flipped to bare `2`; terminal admin-quality-ledger.md state"
provides:
  - "GATE-01 leg A: terminal all-`2` ledger + forward-only monotonic lock verified (quality-ledger-monotonic.sh --base origin/main exits 0, 36 cells)"
  - "GATE-01 leg B: snapshot/canary in-phase idempotency vs HEAD proven on both lanes (0 changed slugs, both allowlists empty)"
  - "GATE-01 leg C: compare-mode zero PNG drift across all three admin-checkpoint Playwright projects (chromium/mobile/dark)"
  - "Design lane compare-mode proven (40 tests pass); board-* PNGs NOT re-recorded on darwin (CI-native gate preserved)"
  - "Origin/main canary reconciliation documented as integration-merge (PR #63) hand-off per D-02a mechanism (ii)"
affects: [211-02, 211-03, 211-04, 211-05, integration-merge-pr-63]

tech-stack:
  added: []
  patterns:
    - "D-02a mechanism (ii): prove idempotency vs HEAD in-phase; defer origin/main canary reconciliation to the integration merge — same pattern as Phase 204 D-05 (c96749fa precedent)"
    - "Compare-mode zero-drift is the approval: --base HEAD canary guard showing 0 changed slugs = idempotency proven (not --require-all which is pre-commit only)"

key-files:
  created: []
  modified: []

key-decisions:
  - "D-02a mechanism (ii) confirmed: prove snapshot/canary idempotency vs HEAD in-phase; the origin/main canary FAIL (5 stale checkpoint slugs incl. user-sessions added + WCAG-fixed impersonation-banner canary) is a publish-time reconciliation owned by the integration merge (PR #63), not Phase 211"
  - "WCAG AA contrast fix preserved: impersonation-banner canary bytes (Phase 204-03 .vt-status-pill fix) NOT reverted; canary NOT allowlisted"
  - "Board-* (admin-design) PNGs NOT re-recorded on darwin — design lane proven compare-mode only per CI-native baseline discipline"
  - "5 (not 4) non-canary checkpoint slugs drift vs origin/main: audit-explorer/user-audit/global-user-index/org-scoped-admin (modified) + user-sessions (added, 3 PNGs) — masked by canary early-exit in the guard; harmless for mechanism (ii)"

patterns-established:
  - "Terminal ratification verification pattern: run existing CI guards (quality-ledger-monotonic.sh + snapshot-canary-guard.sh) + Playwright compare-mode; no new tooling (D-04/D-10)"

requirements-completed: [GATE-01]

coverage:
  - id: D1
    description: "Terminal all-`2` quality ledger verified and forward-only monotonic lock holds (GATE-01 leg A)"
    requirement: GATE-01
    verification:
      - kind: other
        ref: "bash scripts/ci/quality-ledger-monotonic.sh --base origin/main → PASS (36 cells), exit 0"
        status: pass
    human_judgment: false
  - id: D2
    description: "Snapshot/canary in-phase idempotency vs HEAD proven on both checkpoint and design lanes; both allowlists empty (GATE-01 leg B)"
    requirement: GATE-01
    verification:
      - kind: other
        ref: "bash scripts/ci/snapshot-canary-guard.sh --base HEAD → PASS (0 changed slugs) [checkpoint lane]"
        status: pass
      - kind: other
        ref: "SNAP_DIR=admin-design... bash scripts/ci/snapshot-canary-guard.sh --base HEAD --canary board-notice → PASS (0 changed slugs) [design lane]"
        status: pass
      - kind: other
        ref: "grep -vcE checkpoint snapshot-allowlist → 0 non-comment lines; grep -vcE design snapshot-allowlist-design → 0 non-comment lines"
        status: pass
    human_judgment: false
  - id: D3
    description: "Compare-mode zero PNG drift across all three admin-checkpoint Playwright projects (GATE-01 leg C)"
    requirement: GATE-01
    verification:
      - kind: automated_ui
        ref: "npm test -- --project=admin-checkpoints-chromium → 1 passed (0 snapshot diffs)"
        status: pass
      - kind: automated_ui
        ref: "npm test -- --project=admin-checkpoints-mobile → 1 passed (0 snapshot diffs)"
        status: pass
      - kind: automated_ui
        ref: "npm test -- --project=admin-checkpoints-dark → 1 passed (0 snapshot diffs)"
        status: pass
      - kind: automated_ui
        ref: "npm test -- --project=admin-design-chromium → 40 passed (0 snapshot diffs) [compare-mode, darwin, no re-record]"
        status: pass
    human_judgment: false

duration: 8min
completed: 2026-07-01
status: complete
---

# Phase 211 Plan 01: Terminal Ratification — GATE-01 Verification Summary

**GATE-01 proven in-phase via D-02a mechanism (ii): all-36-cell bare-`2` ledger locked, both canary lanes 0-drift vs HEAD, three checkpoint Playwright projects pass compare-mode, both allowlists empty, origin/main reconciliation documented as integration-merge hand-off**

## Performance

- **Duration:** 8 min
- **Started:** 2026-07-01T19:57:52Z
- **Completed:** 2026-07-01T20:06:00Z
- **Tasks:** 3
- **Files modified:** 0 (verification-only plan; no files mutated)

## Accomplishments

- GATE-01 leg A: `quality-ledger-monotonic.sh --base origin/main` exits 0; all 36 tier cells in `guides/reference/admin-quality-ledger.md` read bare `2` with no decorators; ledger is UNMODIFIED by this plan (D-01 compliant)
- GATE-01 leg B: `snapshot-canary-guard.sh --base HEAD` PASSES (0 changed slugs) on both the checkpoint lane (impersonation-banner canary) and design lane (board-notice canary); both `snapshot-allowlist` and `snapshot-allowlist-design` contain 0 non-comment lines (empty at steady state)
- GATE-01 leg C: all three admin-checkpoint Playwright projects (`admin-checkpoints-chromium`, `admin-checkpoints-mobile`, `admin-checkpoints-dark`) pass in compare mode with zero PNG drift; the admin-design lane (40 tests) also passes compare-mode on darwin without re-recording any board-* PNGs

## Task Commits

These tasks are verification-only (no file mutations). A single combined verification commit is made covering all three tasks:

1. **Task 1: Verify terminal all-`2` ledger + forward-only monotonic lock** — verification PASS (no commit; combined below)
2. **Task 2: Prove snapshot/canary idempotency vs HEAD on both lanes** — verification PASS (no commit; combined below)
3. **Task 3: Compare-mode zero PNG drift across checkpoint Playwright projects** — verification PASS (no commit; combined below)

Combined verification commit: (see metadata commit below)

## Files Created/Modified

None — this plan is a verification pass only. No ledger cells were flipped (D-01, D-10), no PNGs were re-recorded (D-02), no allowlist slugs were added.

## Decisions Made

- **D-02a mechanism (ii) confirmed**: prove idempotency vs HEAD in-phase (already 0-drift live as of research capture); defer origin/main canary reconciliation to the integration merge (PR #63). Direct Phase 204 D-05 precedent (`c96749fa`, `204-03-SUMMARY.md:25,104,134`).
- **WCAG fix preserved**: the 204-03 `.vt-status-pill` contrast fix (impersonation-banner canary) is byte-stable at HEAD; it was NOT reverted and NOT allowlisted.
- **Board-* darwin exclusion honored**: admin-design lane proven compare-mode only; no `--update-snapshots` run for board-* on darwin (CI-native/ubuntu baselines).

## Deviations from Plan

None — plan executed exactly as specified. All three verification legs passed at the expected steady state documented in the research (RESEARCH §2 "Ground-Truth: --base HEAD PASSES 0-drift on both lanes").

One minor issue was encountered and self-resolved: the `npx --prefix` invocation for Playwright reported "Available projects: ''" when passing `--project=` flags directly. The equivalent `npm --prefix test -- --project=` form resolved this without changing any files or the test outcome.

## Origin/Main Canary Hand-Off (Integration Merge Documentation)

Per D-02a mechanism (ii), Phase 211 does NOT push to origin/main. The `--base origin/main` canary guard FAILs structurally (origin/main is 371 commits behind local main):

- **5 non-canary checkpoint slugs** drift vs origin/main: `audit-explorer`, `user-audit`, `global-user-index`, `org-scoped-admin` (all `modified`) + `user-sessions` (`added`, 3 PNGs — masked by the canary early-exit short-circuit in the guard)
- **impersonation-banner canary**: `modified` vs origin/main (the WCAG-fixed bytes; guard exits 1 immediately on this)
- **Design lane vs origin/main**: board-mg-* modified, board-cfg-user-detail added (CI-native; NOT re-recorded on darwin)

**Resolution path** (owned by the integration merge, PR #63 — NOT by Phase 211):
- The integration merge carries the WCAG-fixed canary bytes as its own established baseline on the PR branch
- Clean resolution: delete-then-`added` re-establishment per `ci.yml:1486-1498` pattern (design lane precedent) so the guard sees `added` (tolerated as "first-established") not `modified` (hard-forbidden); OR
- Fast-forward merge: after landing, origin/main carries the new bytes byte-stable for all subsequent PRs

This hand-off is documented here so the milestone close reads honestly. The in-phase proofs (HEAD 0-drift, ledger exit 0) are the canonical GATE-01 approval.

## Issues Encountered

None. The example dev server was already running on PORT=4011 (from a prior session), answered HTTP 200, and all Playwright projects passed on first run.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- GATE-01 is locked in-phase: all three legs proven, both allowlists empty, both canaries byte-stable
- Phase 211-02 (GATE-02: installer/example byte-parity + generated-host parity) is unblocked
- Note: phx_new 1.8.8 is installed locally (RESEARCH §4 BLOCKER flagged); Phase 211-02 must `mix archive.install --force hex phx_new 1.8.7` before the golden byte-diff (SEED-004 pin)

---
*Phase: 211-terminal-ratification*
*Completed: 2026-07-01*
