---
phase: 235-terminal-ratification-measured-not-read
plan: 16
status: resolved
blocked_at: null
updated: 2026-09-08T21:22:13-04:00
---

# Plan 235-16 execution diagnostics

Task 1 completed on scoped branch branch `ci/phase-235-16-source-complete` with
the required RED/GREEN sequence:

- `47a88f14` — failing source-complete evidence contracts
- `18a33772` — source-complete metrics, collector, workflow, verifier, and contracts

The focused gate passed locally: `ci-run-metrics.test.sh` 11/11,
`capture-fast-01-gap-closure.test.sh` PASS, and the source-complete plus
terminal-ratification ExUnit command 25 tests / 0 failures. PR #232 is the sole
scoped PR: <https://github.com/szTheory/sigra/pull/232>.

## Protected CI attempts

Run `34294963286` failed the required Library tests aggregate because the local
Phase 235 chain contained two non-canonically formatted evidence contracts. The
format-only blocking fix plus the historical workflow filename assertion update
was committed as `4c46c55f`; the expanded local contract set passed 33 tests / 0
failures.

Run `34295647672` then passed Fast checks and every Playwright/install/example
lane but failed the required Library tests aggregate in `mix hex.audit`:

- locked package: `hackney 1.25.0`
- `EEF-CVE-2026-47075` / `CVE-2026-47075` — MEDIUM
- `EEF-CVE-2026-47076` / `CVE-2026-47076` — MEDIUM
- `EEF-CVE-2026-47069` / `CVE-2026-47069` — LOW
- `EEF-CVE-2026-47071` / `CVE-2026-47071` — HIGH

The same `hackney 1.25.0` lock is present on `origin/main`, so this is a newly
published, pre-existing dependency advisory rather than a Plan 235-16 code
regression. Hex reports `4.7.4` as current, while the retained dependency graph
contains `threadline`'s `~> 1.18` and `tzdata`'s `~> 1.17` constraints. Resolving
the required security gate therefore needs a package/constraint migration or a
separately authorized policy decision.

Plan 235-16 explicitly prohibits package changes, and AGENTS.md prohibits
waiving or auto-approving missing CI evidence. PR #232 remains open and was not
merged; no evidence workflow dispatch occurred. Task 2 is blocked until an
authorized dependency-security change restores the required Library tests check.

## GitHub API discipline

- Live ruleset: `14941512`, active on the default branch, five strict required checks.
- REST budget before run `34294963286`: 5000 remaining.
- REST budget before run `34295647672`: 5000 remaining.
- Each run used one watcher with `--compact --interval 60 --exit-status`.
- Each completed run had one structured-summary fetch and one failed-log fetch.
- No HTTP 403/429 response occurred and no workflow dispatch occurred.

## Resolution

The user explicitly authorized a separately scoped dependency-security migration.
Commit `6b2a7983` adds a repository-only Hackney 4 override for dev/test, updates
the lock to `hackney 4.7.4` and `tzdata 1.1.5`, and removes the obsolete Hackney
1.x transitive entries. `mix hex.audit` reports no retired or advisory packages;
the focused Threadline integration set passed 23 tests / 0 failures.

The exact contributor gate also exposed one stale historical evidence-coverage
assertion, repaired in `bca5ae2e`; the four focused Phase 235 contracts then
passed 35 tests / 0 failures.

PR #232 passed protected CI run `34298307012` with all five strict required
checks green and was squash-merged as protected-main commit
`158aca14b11de13cbc5ab2fdea1bff790cc7ab29`. The repository disallows merge
commits, so the plan's literal branch-HEAD ancestry check is inapplicable after
the required squash; all seven declared evidence-path blobs were compared
directly and match the tested PR head `2e77218678dfc5a0bc57c5e23afbfd46d6c1016d`.
No `fast-01-gap-closure-evidence.yml` dispatch occurred during Plan 235-16.
