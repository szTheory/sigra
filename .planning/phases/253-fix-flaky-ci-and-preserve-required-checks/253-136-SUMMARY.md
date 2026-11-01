---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "136"
subsystem: ci-reliability
tags: [ci-reliability, load-recovery, main-freshness, operator-run, r12]
requires:
  - phase: 253-fix-flaky-ci-and-preserve-required-checks
    provides: "253-133 R11 canary (complete, preserved), 253-134 halted PR window and its offline five-conflict diagnosis against 4ff6c50e4"
provides:
  - "PRESERVATION-R12.sha256: 128 lines (87 PRESERVATION-R11 lines unchanged and in order, plus 41 R11 lines), sha256 72ea87c5c9fe7c7cb2a9798b20122a65435823dc1e04a9fdbc8d47c3344ad16d; shasum -c exits 0"
  - "Jon's main_fetch read approval (committed alone, 886c8d8ef, sha256 b21172c6...2ade)"
  - "Committed fetch runner 253-R12-MAIN-FETCH-OPERATOR.sh (8b1a17f39, sha256 ff77049e...6b66), run by Jon"
  - "Runner-committed MAIN-FETCH-R12 record (c9397e566): fetched main 09df342a82e03c3d5d40173c912b70e827f7eadc, the R12 server parent"
  - "253-134 diagnosis confirmed against real main: R11 candidate 2b239a98 vs 09df342a exits 1 with the same five conflicts; the 84ebcea60 control exits 0"
affects: ["253-137", "253-138", "253-139", "253-140", "253-141", "253-144"]
key-files:
  created:
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-PRESERVATION-R12.sha256
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-MAIN-FETCH-APPROVAL-R12.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-R12-MAIN-FETCH-OPERATOR.sh
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-MAIN-FETCH-R12.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-136-SUMMARY.md
  modified: []
key-decisions:
  - "Complete, not halted: the Task 4 verify exited 0. No halt rule tripped: the record status is fetched and every value re-derives offline; 84ebcea60, 4ff6c50e4 and 09df342a are ancestors of (or equal to) the fetched SHA; the R11 candidate conflicts with fetched main (exit 1) while the 84ebcea60 control is clean (exit 0)."
  - "Merge versus rebuild, as planned: no local merge of main into the working branch in R12. The R12 candidate is rebuilt as a single commit whose parent is --server-parent = 09df342a (fetched here), so the normal PR head is a direct child of the base tip."
  - "Main-hold recommendation stands: hold merges to main from now until the R12 PR window (253-144). If main moves, 253-144 step 0 re-fetches and accepts the move only if the candidate still merges cleanly; a conflicting move halts that window before any API request."
  - "requirements-completed stays []: CIREL-02 stays open until 253-144; CIREL-01 stays partial under the 253-89 not_reproduced disposition; whole-phase verification stays not_started."
requirements-completed: []
estimate: {tokens: 30000, tasks: 4}
actuals:
  tokens: 9000
  tasks: 4
  commits: 4
commits: 4
plan_head_before: aa75d1649384950c50ecc8aea1c1281e3da8124b
plan_head_after: c9397e5660911c71c5728681a8ee4b0a8fcc76c7
duration: 9min (first plan commit 03:34:49Z to record commit 03:43:56Z, 2026-10-19 UTC)
completed: 2026-10-19
status: complete
---

# Phase 253 Plan 136: R12 main fetch (operator-run) Summary

**Jon approved a single `git fetch --no-tags origin main` and ran it himself from the committed runner. Local `origin/main` moved forward by exactly one commit, from 4ff6c50e4 to 09df342a82e03c3d5d40173c912b70e827f7eadc ("ci: Dependabot grouping + Playwright cache fixes (#332)", committed 2026-10-16T08:49:28-04:00). That is the same base PR #337 recorded. Re-run offline against real main, the 253-134 diagnosis holds: the R11 candidate 2b239a98 conflicts on the same five paths, and the 84ebcea60 control is clean. R12 now has a current server parent that can be proven offline. No GitHub API request was made, and no ref on GitHub was created or moved.**

## Performance

- **Decision:** 2026-10-19T03:32Z (Jon, AskUserQuestion).
- **Plan commits:** checklist 03:34:49Z, approval 03:35:00Z, runner 03:39:09Z, record 03:43:56Z (UTC).
- **Fetch:** the runner printed "FETCH STARTS 2026-10-19T03:43:55Z". The record's `fetched_at_utc` is 2026-10-19T03:43:56Z.
- **Tasks:** 4 of 4. **Files:** 3 records and the runner, plus this SUMMARY.

## Task 1: offline gates and decision (orchestrator, Jon)

- The orchestrator ran the Task 1 gates and presented the one command, its local-only effect, the main-hold recommendation and the PR #337 note.
- **Jon's verbatim decision**, from his own AskUserQuestion reply: decision **"approve"**, decision_text **"Approve (Recommended)"**, no note. The approval record carries `decision: approve`, `decision_text: "Approve (Recommended)"`, `note: ""`, `section: main_fetch`, and exactly one authorized command: `git fetch --no-tags origin main (once, run by Jon from 253-R12-MAIN-FETCH-OPERATOR.sh)`.

## Task 2: preservation, approval, runner (executor)

- `c45be1b4f` committed PRESERVATION-R12.sha256 alone: 128 lines (all 87 PRESERVATION-R11 lines, followed by 41 new R11 lines), sha256 **72ea87c5c9fe7c7cb2a9798b20122a65435823dc1e04a9fdbc8d47c3344ad16d**.
- `886c8d8ef` committed the approval alone (sha256 b21172c63fc33cf978c52f8117356c3ab5d8dc7546cf455d454e836144d32ade).
- `8b1a17f39` committed the runner alone (sha256 ff77049e384a4b80bed13d459efe38f6526dcff1d2d421fb4d307e166cb96b66).

## Task 3: the fetch (Jon, via `!`)

- Jon ran the runner. Its output: "FETCH STARTS 2026-10-19T03:43:55Z", "4ff6c50e4..09df342a8  main -> origin/main", record commit c9397e566, "FETCHED main 09df342a82e03c3d5d40173c912b70e827f7eadc (2026-10-16T08:49:28-04:00) ci: Dependabot grouping + Playwright cache fixes (#332)", "DONE 09df342a82e03c3d5d40173c912b70e827f7eadc".
- The record lists `local_refs_changed: [refs/remotes/origin/main]` and `anomalies: []`.

## Task 4: offline re-derivation (executor)

The verify block was run by the orchestrator at c9397e566 and again by this executor before writing this SUMMARY. Both runs exited 0. As a positive control, the same block with the origin/main comparison altered (`"x$M"`) exits 1.

| Claim | Record | Offline re-derivation |
|---|---|---|
| status | fetched | yes |
| fetched_main_sha | 09df342a82e03c3d5d40173c912b70e827f7eadc | `git rev-parse refs/remotes/origin/main` and `git rev-parse FETCH_HEAD` both 09df342a...; `.git/FETCH_HEAD` reads "branch 'main' of https://github.com/szTheory/sigra"; `git cat-file -t` returns commit |
| committer time / subject | 2026-10-16T08:49:28-04:00 / "ci: Dependabot grouping + Playwright cache fixes (#332)" | same via `git log` |
| before_origin_main | 4ff6c50e4c6122ed8f27e67473f3b6408b3aaa97 | ancestor of the fetched SHA |
| ancestry 84ebcea60 / 4ff6c50e4 / 09df342a | true / true / true | `git merge-base --is-ancestor` all succeed. 09df342a **is the fetched tip** (equal), not just an ancestor. Main only moved forward. |
| commits since 4ff6c50e4 | 1 (not truncated) | `git log 4ff6c50e4..origin/main` lists exactly 09df342a (#332), the expected list |
| R11 candidate vs fetched main | exit 1, five conflicts | `git merge-tree --write-tree --name-only 2b239a98 09df342a` exits 1 with `.release-please-manifest.json`, `CHANGELOG.md`, `doc/llms.txt`, `mix.exs`, `test/example/priv/playwright/tests/admin-eval.spec.ts` |
| control vs 84ebcea60 | exit 0 | exits 0, with no conflicts (tree 05fc6801a) |
| approval binding | commit 886c8d8ef, sha256 b21172c6... | the approval's add-commit and current sha256 match; the approval commit is an ancestor of the record commit c9397e566 |
| PRESERVATION-R12 | — | `shasum -a 256 -c --quiet` exits 0 |

- **Conflicts compared with 253-134:** the five paths against fetched main 09df342a are **identical** to the five 253-134 found against 4ff6c50e4. #332 adds no new conflict and resolves none. This confirms the diagnosis: GitHub creates no pull_request run for a conflicting PR, which is hermetic-vs-live blind spot #4.
- **.planning paths main changed since 84ebcea60** (informational): one path, `.planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/250-249-CURRENT-PROOF-DIAGNOSTIC.json`. The publication takes `.planning` from the server parent, so this path does not reach the local branch.

## Merge versus rebuild, and the main hold

- As planned, there is no local merge in R12. A merge of main into the working branch would hit about 45 files with non-mechanical conflicts (merge base 417130bd), including the reviewed ci.yml. Integrating the branch with main is milestone-merge work, outside Phase 253.
- Instead, the R12 candidate is rebuilt with `--server-parent` = **09df342a82e03c3d5d40173c912b70e827f7eadc**. The PR head is then a direct child of the base tip, so GitHub's test merge is clean by construction.
- **Recommendation:** hold merges to main until the R12 PR window (253-144). If main moves, 253-144 step 0 re-fetches and accepts the move only if the candidate still merges cleanly. A conflicting move halts that window before any API request and forces a new freeze and canary.

## Commits

| Commit | Subject |
|---|---|
| c45be1b4f | docs(253-136): R12 preservation checklist |
| 886c8d8ef | docs(253-136): record Jon's R12 main-fetch approval |
| 8b1a17f39 | docs(253-136): R12 main-fetch operator runner (Jon runs the fetch) |
| c9397e566 | docs(253-136): record the R12 main fetch (runner, Jon) |

The SUMMARY commit ("docs(253-136): complete R12 main fetch plan") follows. It is not counted in `commits:`, in line with earlier 253 SUMMARYs.

## Deviations from Plan

These are the Task 2 executor's deviations, all hardening only. None loosens a gate.

1. **[Rule 2] Self-check scope:** the runner self-check allows the untracked runner only before its own commit.
2. **[Rule 1] pipefail fix** in the runner's merge-tree probe (as reported by the Task 2 executor).
3. **[Rule 2] Extra offline guards** in the runner: an already-fetched guard, a re-check of 253-134, a fetch-config check, `GIT_TERMINAL_PROMPT=0`, and the `local_refs_changed` and `anomalies` record fields.
4. **No-network rehearsal** in a throwaway local clone, deleted afterwards. It made no hosted request.

Task 4 had no deviations.

## Remaining gaps

- **CIREL-02** stays open until 253-144 (R12 PR window); 253-145 applies acceptance.
- **CIREL-01** stays partial under the 253-89 not_reproduced disposition.
- Draft PR #337 stays open and untouched, for Jon.
- Full Phase 253 verification stays not_started.

## Handoff to 253-137

- Server parent: **09df342a82e03c3d5d40173c912b70e827f7eadc** (record `.planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-MAIN-FETCH-R12.json`, sha256 35fd1543a87d7abfe50949b1d1b616c3afd18f868e7382de871028681515b90e, committed in c9397e566).
- Local `refs/remotes/origin/main` = FETCH_HEAD = 09df342a. The working branch HEAD is unchanged apart from the 253-136 docs commits.
- PRESERVATION-R12 sha256: 72ea87c5c9fe7c7cb2a9798b20122a65435823dc1e04a9fdbc8d47c3344ad16d (128 lines).

## Self-Check: PASSED

- All four R12 files exist and are each committed alone in plan order (c45be1b4f, 886c8d8ef, 8b1a17f39, c9397e566). All four commits are ancestors of HEAD.
- config.json sha256 8e312f6c...0b8d (uncommitted, unchanged); state.json is 70229 bytes with sha256 prefix e45278c2cee0.
