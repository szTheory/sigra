---
phase: 223-get-current-on-hex-terminal-currency-proof
plan: 01
subsystem: infra
tags: [hex, release-ops, currency, retire]

# Dependency graph
requires:
  - phase: 221-p1-hex-currency-restoration
    provides: v1.2.0 + v1.3.0 published to Hex; retire runbook (folded todo)
provides:
  - "Pre-retire live-Hex snapshot proving latest_stable_version=1.20.0, latest_version=1.20.0, retirements={} (empty)"
affects: [223-02, 223-03]

# Tech tracking
tech-stack:
  added: []
  patterns: []

key-files:
  created:
    - .planning/phases/223-get-current-on-hex-terminal-currency-proof/223-01-SUMMARY.md
  modified: []

key-decisions:
  - "Task 1 only executed this dispatch; Task 2 (operator retire) is a blocking human-action checkpoint that cannot be automated (Hex 2.5 dropped CLI key-gen; device-flow token not authorized to retire)."

patterns-established: []

requirements-completed: []  # PROOF-01 remains open until Task 3 (post-retire verification) completes

coverage: []

# Metrics
duration: partial (Task 1 only)
completed: 2026-07-11
status: in-progress
---

# Phase 223 Plan 01: Pre-retire Hex Snapshot (Task 1 of 3) Summary

**Live Hex re-queried immediately before the operator retire step, confirming `latest_stable_version=1.20.0` with empty `retirements` — the exact drift condition that makes the retire necessary (PROOF-01 blocker).**

## Performance

- **Tasks completed this dispatch:** 1 of 3 (Task 1 only; Task 2 is a blocking operator checkpoint, Task 3 depends on Task 2)
- **Completed:** 2026-07-11

## Accomplishments
- Re-queried live Hex per D-02 (registry state drifts, never trust a stale observation) and recorded verbatim pre-retire evidence.
- Confirmed the pre-state matches the plan's expected trigger condition exactly: no retire has landed yet, so this is a real action for the operator, not a no-op verification.

## Pre-retire snapshot

Command:

```bash
curl -s https://hex.pm/api/packages/sigra | jq '.latest_stable_version, .latest_version, .retirements'
```

Verbatim output:

```
"1.20.0"
"1.20.0"
{}
```

This confirms `{:sigra, "~> 1.0"}` currently resolves to the stray `1.20.0` release
instead of the real GA (`1.3.0`), and that no retirement has been applied yet.

## Task Commits

1. **Task 1: Capture pre-retire live-Hex snapshot** - see plan metadata commit (docs-only; SUMMARY.md is the sole artifact for this task)

## Files Created/Modified
- `.planning/phases/223-get-current-on-hex-terminal-currency-proof/223-01-SUMMARY.md` - this file; pre-retire evidence recorded

## Decisions Made
- None beyond the plan's own design (autonomous: false, Task 2 requires operator action) - followed plan as specified for Task 1's scope.

## Deviations from Plan

None - Task 1 executed exactly as written.

## Issues Encountered

None.

## Next Phase Readiness

**BLOCKED on Task 2 (operator checkpoint) — not ready to proceed.**

This plan is paused at the Task 2 `checkpoint:human-action` gate (`gate="blocking"`). The
agent cannot mint a Hex API write key or run an interactive `mix hex.retire` command — this
requires the operator's own hex.pm dashboard credentials.

**Operator must:**
1. Mint an API **write** key at https://hex.pm/dashboard/keys (Hex 2.5 has no CLI key-gen;
   grant API / write permission).
2. Run:
   ```bash
   HEX_API_KEY=<key> mix hex.retire sigra 1.20.0 invalid --message "Published in error during dev cycle; not a real release — use 1.3.0+"
   ```
3. Confirm the command reports success (no "key not authorized" error). Do NOT paste the key
   into any committed file, log, or SUMMARY — env var only, for a single command.

**Reversible fallback (D-03), if ever needed:**
```bash
mix hex.retire sigra 1.20.0 --unretire
```

Once the operator confirms success, Task 3 (post-retire verification + fold todo to `done/`)
must run to close this plan. Until Task 3 verifies `latest_stable_version == "1.3.0"` and
`retirements` contains `1.20.0`, this plan is **not complete** and 223-02 (PUB-05) / 223-03
(PROOF-01) remain blocked.

## Operator decision (2026-07-11): retire DEFERRED indefinitely

At the Task 2 checkpoint the operator (Jon) declined to perform the retire: no time now, and
there are no real Sigra adopters yet, so the stray `1.20.0` is low-stakes to leave in place.
The retire is deferred indefinitely as a low-priority future follow-up
(`.planning/todos/pending/2026-07-03-hex-retire-stray-1-20-0.md`, third deferral) — NOT force-
completed and NOT fabricated as done.

**Consequence for Phase 223:** the phase is **paused/blocked**, not complete. Plan 223-01
stops at Task 2 (Task 3 cannot run without the retire); plans 223-02 (PUB-05 adopter
resolution) and 223-03 (PROOF-01 trust bundle) cannot be truthfully executed while
`latest_stable_version` is still `1.20.0`. Resuming Phase 223 requires the operator retire to
land first, after which `/gsd-execute-phase 223` picks up from Task 3.

**Root cause captured** (per the operator's request) in ADR 003
(`.planning/decisions/003-hex-release-versioning-no-tag-derived-publish.md`): an early publish
pipeline derived the Hex package version from arbitrary `v*` git tags and caught the milestone
tag `v1.20`, publishing a phantom `1.20.0`. Already structurally closed (Release-Please-driven
publish; no tag-triggered publish; milestone `vX.Y` tags stopped after v1.35).

---
*Phase: 223-get-current-on-hex-terminal-currency-proof*
*Plan 01 — Task 1 of 3 complete; Task 2 pending operator action*
