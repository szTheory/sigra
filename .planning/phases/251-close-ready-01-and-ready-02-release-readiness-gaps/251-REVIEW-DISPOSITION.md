---
phase: 251
review: 251-REVIEW.md
titles: json
findings:
  - id: CR-04
    severity: critical
    disposition: open
    title: "[BLOCKER] T-251-11: Package source assertions are generated from the claimed result"
  - id: CR-05
    severity: critical
    disposition: open
    title: "[BLOCKER] T-251-12: Independent audit trusts fabricated source digests and assertion booleans"
  - id: CR-06
    severity: critical
    disposition: open
    title: "[BLOCKER] T-251-13: READY-02 does not require every captured worktree item in the join"
  - id: CR-07
    severity: critical
    disposition: open
    title: "[BLOCKER] T-251-14: Preservation validation ignores the named ref and record decision"
  - id: CR-01
    severity: critical
    disposition: fixed
    title: "Final inventory carries old PR dispositions onto changed identities"
  - id: CR-02
    severity: critical
    disposition: fixed
    title: "READY-01 accepts package checks with unbound evidence text"
  - id: CR-03
    severity: critical
    disposition: fixed
    title: "READY-02 can pass while a secondary worktree is dirty"
open: 4
total: 7
recorded: 2026-10-11T23:18:04.310Z
---

# Phase 251: Code Review Disposition

| Finding | Severity | Disposition | Source |
|---------|----------|-------------|--------|
| CR-04 | critical | open | - |
| CR-05 | critical | open | - |
| CR-06 | critical | open | - |
| CR-07 | critical | open | - |
| CR-01 | critical | fixed | `validate-release-readiness.mjs`; RED `251-03-task1-red-evidence.json` and `251-03-task2-red-evidence.json`; GREEN regressions `final inventory invalidates disposition when any captured PR identity component changes`, `requires unique complete PR identities and stable numeric ordering in snapshots`, and `final inventory sorts PRs numerically and rejects duplicate or null identities`; fresh 31-test validator suite passed. (not in the current review) |
| CR-02 | critical | fixed | `verify-247-readiness.mjs`, `verify-v149-traceability.mjs`; RED `251-04-task1-red-evidence.json` and `251-04-task2-red-evidence.json`; GREEN regressions `package checks reject wrong path, commit, blob, digest, and assertion identity`, `the refreshed Phase 251 source artifact binds every named package check to trusted source refs`, `independent audit rejects a satisfied READY-01 row whose guide ref points to candidate bytes`, and `independent audit rejects each changed READY-01 check source or result identity`; fresh readiness and traceability suites passed. (not in the current review) |
| CR-03 | critical | fixed | `verify-247-readiness.mjs`; RED `251-05-task1-red-evidence.json`; GREEN regressions `secondary-worktree dirty paths stay in the READY-02 disposition and preservation join`, `clean secondary worktrees do not create phantom dirty inherited items`, and `scoped preservation records read back exact item identity and PR dispositions cite current source paths`; current packet independently passes `--check-251`. (not in the current review) |

Dispositions: `open` (recorded, not yet triaged), `fixed`, `skipped`, `deferred`.
Set `deferred` by hand and put the reason in the Source cell; both are preserved. A `|` in the reason is kept as prose and escaped on the next run.
Re-running the gate keeps every row it can. A row the current review no longer reports is kept and its Source cell flagged, so a finding does not leave this record silently. ONE exception: when a finding id is REUSED by a different finding, the earlier decision cannot keep a row — the id is taken — and it is dropped. A RECORDED decision (anything but `open`) is named on the console when that happens; a row still at `open` is replaced silently, because `open` records no decision to lose.
