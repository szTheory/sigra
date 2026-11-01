---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "51"
subsystem: ci-reliability
tags: [ci-reliability, load-recovery, native, budget-decision]
requirements-completed: []
actuals:
  tasks: 2
  commits: 3
plan_head_before: d25dcdaa5
plan_head_after: 3995a8327
commits: 3
duration: ~5 min
completed: 2026-10-14
status: halted
---

# Phase 253 Plan 51: R2 native budget approval and first native window Summary

**Jon approved the R2 budget with retry; the first R2 native window (CR2-DESKTOP-MOBILE-FIRST) ran on a provably awake host but produced 0 accepted rows (native tests failed, work deadline reached), a terminal non-infrastructure halt. Task 3 was not run.**

## Decision (Task 1)

Selection: **approve**, note verbatim: "Approve with retry (Recommended)". Numbers presented: carried 2042596 ms / 6 launches; +645000 ms allowance (incl. one 120000 ms infra retry); D19-R2 cap 2687596 ms, max 11 launches; shared cap 5027596 ms, CLI max 20. Read-only R2 freeze check run before recording: passed ("fixed runner pinned, 253-40 lineage re-hashed, 2042596 ms/6 launches/7 spent carried, 22 rows, no capacity granted").

Approval record `253-LOAD-RECOVERY-BUDGET-APPROVAL-R2.json` (budget sha256 9bb278db..., freeze sha256 b26d5a0c..., retry_granted 1) committed `f50915418` before any launch.

## Task outcomes

- Preflight (zero charge) before the window: `{"holder_pid":55595,"ac_power":true,"assertions_sha256":"d1d74f2b5cf8cd7da915f2dd5425fc1cf033d86e904d8e7e6d817cc39f836a6b","checked_at":"2026-10-14T15:05:25.612Z"}`; earlier preflight pid 42886, AC power true. In-window host_awake receipt: holder 56500, ac_power true, no suspension.
- Ledger initialized and committed `652e65754` before setup; preparation charged 743 ms (ready).
- CR2-DESKTOP-MOBILE-FIRST: one CLI, 16 tests started; the list reporter showed every test reported failed (including the positive "waits for explicitly released LiveView readiness" at 16.7 s and the same-account collision test at 20.0 s) and the native command reached the reserved 105000 ms work deadline; the report was cut at row 8 of 16. The runner recorded 0 native rows, no sanitized report, CLI exit null (vs frozen 1), incomplete lifecycle receipt, no collision receipts. DB created and dropped (absence receipt count 0, setup exit 0). Charged 107343 ms (execution = wall). Evidence and raw logs committed `3995a8327`.
- Classification: not an infrastructure/host halt (host awake, no suspension, holder intact, test selection occurred), so per plan it is terminal. The infrastructure retry was NOT used (retry_granted 1, used 0). No diagnostic file written. Task 3 (three second-control windows) was not run.

## Charge and launches

- Carried 2042596 ms + preparation 743 + attempt 107343 = **2150682 ms** (D19-R2 cap 2687596; 536914 ms remaining).
- Physical launches: 7 (cap 11); spent slots: the seven prior plus CR2-DESKTOP-MOBILE-FIRST. Infra retry used 0/1.

## Likely cause (not asserted; for 253-52 / replanning)

Positive-control failures at 16.7 s and 20.0 s in a host with load average ~14 on 18 cores suggest the readiness/collision flows are timing out under host load, or a genuine regression in the controls; the app-log shows the collision test reaching the `save` event and the uniqueness query before SIGTERM. The test-log is truncated at the deadline so per-test error messages are unavailable; not investigated further to avoid unapproved native spend.

## Deviations from Plan

None - plan executed as written up to the terminal halt. Artifacts not produced: evidence for CR-DESKTOP-SECOND, CR-MOBILE-SECOND, CR-DARK-SECOND, CR2-INFRA-RETRY, and the infra diagnostic.

## Remaining gaps

All 22 R2 control rows remain unaccepted; CIREL-01/CIREL-02 stay open; `--verify-load-recovery --stage first` would fail. Needs a diagnosis/replan decision (253-52 cannot proceed on accepted controls). `.planning/config.json` untouched (sha256 8e312f6c...). No STATE/ROADMAP/REQUIREMENTS writes.

## Self-Check: PASSED

Commits f50915418, 652e65754, 3995a8327 exist; evidence and approval files present.
