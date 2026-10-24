---
phase: 240-green-main-evidence-honest-pages-script
plan: 03
subsystem: ci
tags: [ci, evidence, collector, green-04, pagination, p12]
status: complete

requires:
  - "scripts/ci/capture-terminal-ratification-evidence.sh:47-92 (the pagination core, copied verbatim)"
  - "scripts/ci/capture-fast-01-remeasurement.sh:84-92 (the canonical-output idiom)"
  - ".github/workflows/green-04-evidence.yml (plan 240-02) — the job `name:` the SC-1 selector prefixes on"
  - "scripts/ci/prohibitions/_lib.mjs:254-294 (`parseEvidenceSlots`, the ledger slot grammar)"
provides:
  - "scripts/ci/capture-green-04-evidence.sh — fixed-parameter, fail-closed SC-1/SC-2 collector"
  - "scripts/ci/capture-green-04-evidence.test.sh — 36-assertion hermetic self-test"
  - "receipt schema `sigra.green-04-evidence/v1`"
  - "failure tokens: no_matrix_suffix, insufficient_legs, leg_without_conclusion, foreign_run_id, matrix_repeat_set_mismatch, dirty_tree, evidence_run_head_sha_is_not_final_committed_head, rate_limit_too_low, gh_not_found, jq_not_found"
  - ".planning/phases/240-.../240-EVIDENCE.md — six pending p12-grammar slots"
  - ".planning/phases/240-.../COVERAGE.md — reconciled against the implemented collector"
affects:
  - "Plan 04 — owns the dispatch, the live capture, the slot flips to `captured`, and the GREEN-04 requirement mark"

tech-stack:
  added: []
  patterns:
    - "non-steerable collector: repo/workflow/job-selector/filter are fixed constants; only run id, window bounds and output path are arguments"
    - "anchored-regex job selection with a named capture group supplying matrix_repeat from the same parse that selected the leg"
    - "rejected-shape vs empty-window distinction (`no_matrix_suffix` vs `insufficient_legs`)"
    - "single stub generator driving both the positive case and its negative control (FAKE_JOB_NAME_SHAPE)"

key-files:
  created:
    - scripts/ci/capture-green-04-evidence.sh
    - scripts/ci/capture-green-04-evidence.test.sh
    - .planning/phases/240-green-main-evidence-honest-pages-script/240-EVIDENCE.md
  modified:
    - .planning/phases/240-green-main-evidence-honest-pages-script/COVERAGE.md

decisions:
  - "The bare-name detector uses an anchored `test(\"^JOB_NAME$\")` rather than `.name == $jn`, so `grep -n '\\.name =='` over the collector returns zero hits anywhere in the file, not merely on the SC-1 leg selector."
  - "The `filter=latest` value reaches both `/jobs` endpoint strings through the `JOBS_FILTER` constant (`filter=${JOBS_FILTER}`) rather than as a repeated literal — D-11's requirement is that the value be chosen explicitly and recorded in the receipt, both of which hold, with one source of truth instead of three."
  - "The self-test is deliberately NOT wired into ci.yml, following `capture-fast-01-remeasurement.test.sh` and `capture-terminal-ratification-evidence.test.sh`, neither of which has a CI caller; this collector is operator-invoked once."
  - "Collector emission adds `sc2.runs[].ci_gate_conclusion` and `sc2.runs[].generated_admin_smoke_conclusion` alongside the full per-run `jobs[]` list, so the two aggregate counters in the receipt are re-derivable from the same receipt rather than having to be trusted."

metrics:
  duration: ~50m
  completed: 2026-09-18
  tasks: 3
  commits: 3

actuals:
  tokens: 31000
  tasks: 3
  commits: 3
---

# Phase 240 Plan 03: GREEN-04 Evidence Collector + Ledger Skeleton Summary

A fail-closed, non-steerable collector that reads SC-1 (the n≥20 dispatch legs) and SC-2 (the
`main` window) at the **job** conclusion level and emits a byte-stable JSON receipt, plus a
36-assertion hermetic harness that was **observed RED** against a byte-equality selector mutation,
plus the six-slot p12-grammar ledger skeleton with every slot still `pending`.

## What Was Built

### Task 1 — `scripts/ci/capture-green-04-evidence.sh` (commit `6b2064f6`)

- Header records the dual provenance (`capture-terminal-ratification-evidence.sh:47-92` for the
  pagination core; `capture-fast-01-remeasurement.sh:84-92` for the canonical-output idiom) and
  states explicitly that `capture-fast-01-remeasurement.sh` is **not** extended, because its
  cutoff constants at `:5-11` are pinned by
  `test/sigra/planning/phase_235_fast_01_remeasurement_contract_test.exs` (D-12).
- Fixed, non-configurable constants: `REPO`, `EVIDENCE_WORKFLOW`, `CI_WORKFLOW`, `JOB_NAME`,
  `CI_JOB_NAME`, `CI_GATE_JOB_NAME`, `JOBS_FILTER="latest"`, `MIN_LEGS=20`, `MAX_PAGES=10000`,
  `SCHEMA_VERSION="sigra.green-04-evidence/v1"`, `SC2_CAVEAT`. **No `${VAR:-default}` form appears
  in any of them** — nothing is overridable by environment or argument.
- Argument surface is exactly `--output`, `--run-id`, `--main-window-start`, `--main-window-end`.
  Any other flag exits non-zero naming `unknown_argument`. Run id and both window bounds are
  format-validated, and an inverted window fails `main_window_inverted`.
- Preflight in order, each fail-closed: `gh_not_found` / `jq_not_found` / `git_not_found`; exactly
  one rate-limit read (`rate_limit_too_low` at ≤250 remaining); then the D-13 pair —
  `dirty_tree` and `evidence_run_head_sha_is_not_final_committed_head`.
- `request_page` / `validate_manifest` / `collect_pages` copied **verbatim**. Every D-11 assertion
  comes with them: `per_page=100`, `total_count_changed`, `total_count_disagreement`,
  `absent_terminal_empty_page`, `non_contiguous_or_duplicate_page`, `nonterminal_empty_page`,
  `duplicate_item_id`, `pagination_bound_reached`.
- **The selector contract.** `regex_escape` escapes the job name's literal parentheses, and the
  leg selector is `^Generated admin Playwright smoke \(GREEN-04 repeat\) \((?<repeat>[0-9]+)\)$`
  — anchored at both ends and **requiring** the ` (N)` suffix. `matrix_repeat` is read from that
  named capture group, i.e. from the same parse that performed the selection, never from a second
  differently-shaped one. `grep -n '\.name =='` over the file returns **zero** hits.
- **Rejected shape vs empty window.** A payload of bare, unsuffixed names fails with the distinct
  token `no_matrix_suffix`, not `insufficient_legs`. Conflating those two is exactly what would
  hide a selector bug behind a plausible "no legs yet".
- Further SC-1 assertions: `insufficient_legs` (<20), `leg_without_conclusion` (any null
  conclusion — queued, in_progress or cancelled), `matrix_repeat_set_mismatch` (the set must be
  exactly 1..20), `foreign_run_id` (every leg parented by the one dispatch run).
  `sc1.verdict` is `pass` only when all 20 concluded `success`.
- SC-2 walks `workflows/ci.yml/runs?branch=main&created=<start>..<end>`, then `/runs/{id}/jobs`
  per run, recording the run-level conclusion **and** the per-job conclusions but computing the
  verdict from the jobs (D-08). `ci_gate_conclusions` counts the `ci-gate` job's conclusion;
  `flake_attributable_red_count` counts `main` runs whose `Generated admin Playwright smoke` job
  concluded `failure`. `sc2.caveat` is the literal nine-of-ten disclosure naming
  `example_unit_smoke`, the ten `ci-gate.needs` entries at `ci.yml:1547-1557`, and ruleset
  14941512.
- Emission through `jq -S -n` with `--slurpfile`, `sc1.legs` sorted by `matrix_repeat` and
  `sc2.runs` by `run_id`, written to a temp file **inside the output directory** and `mv -f`'d
  into place only after every assertion has passed. `head_sha` and `clean_tree` are in the receipt
  itself, so the claim is self-dating and a later ledger commit cannot invalidate it.
- The script does **not** write `240-EVIDENCE.md`. The JSON is the receipt; the markdown is the
  claim.

### Task 2 — `scripts/ci/capture-green-04-evidence.test.sh` (commit `941d679d`)

36 assertions, all passing, fully offline: a recording `gh` stub on `PATH` and a throwaway git
repository in `$TMP` so the D-13 `git status` / `git rev-parse HEAD` assertions read real git state.

**The stub reproduces the shape the real API emits.** All twenty leg objects come from a single
`for (( i = 1; i <= LEGS; i++ ))` loop whose `name` is `"$JOB_NAME ($i)"`, verified to produce the
literal `Generated admin Playwright smoke (GREEN-04 repeat) (1)` and ` (20)`.
`FAKE_JOB_NAME_SHAPE` (`suffixed` default, `bare`) drives the `bare_job_names` negative control
**off that same generator**, so the positive case and its negative control cannot drift apart and
the harness can never go green against a payload the Actions API never produces.

Cases: `ok` (exit 0, `leg_count == 20`, `verdict == "pass"`, `[.sc1.legs[].matrix_repeat] ==
[range(1;21)]`, `jobs_filter == "latest"` on both sides, `head_sha`/`clean_tree` recorded, `sc2`
verdict green while every `run_conclusion` is `failure` — the D-09 misattribution reproduced in the
fixture, `sc2.caveat` naming `example_unit_smoke`); `bare_job_names` → `no_matrix_suffix`;
`truncated` (`total_count` 45 vs 30 items) → `total_count_disagreement`; `empty_jobs` →
`insufficient_legs`; `leg_in_progress` → `leg_without_conclusion`; `head_mismatch` →
`evidence_run_head_sha_is_not_final_committed_head`; `rate_limited` → `rate_limit_too_low` with
**zero** `/jobs?` lines in the call log; `dirty_tree` → `dirty_tree` with zero `/jobs?` lines;
unknown-flag rejection; and determinism (`cmp` of two captures of the same window reports no
difference). Every expected failure asserts its **reason token**, not merely a non-zero exit, and
every failure case additionally asserts the `--output` path does not exist — proving the
temp-then-`mv -f` discipline held.

**Non-vacuity, observed rather than assumed.** The harness was run against a deliberately mutated
collector whose `LEG_NAME_RE` was flipped to the byte-equality shape `^${JOB_NAME_ESC}$`:

```
$ sed -i '' 's|^LEG_NAME_RE=.*|LEG_NAME_RE="^${JOB_NAME_ESC}$"|' scripts/ci/capture-green-04-evidence.sh
$ bash scripts/ci/capture-green-04-evidence.test.sh
pass=23 fail=13
capture-green-04-evidence.test: FAIL
```

Restored, the same harness reports `pass=36 fail=0` / `capture-green-04-evidence.test: PASS`, and
`git diff --stat` on the collector is empty (the mutation left no residue).

**This self-test is intentionally unwired from CI**, following the precedent of
`capture-fast-01-remeasurement.test.sh` and `capture-terminal-ratification-evidence.test.sh` —
neither has a CI caller either, because both collectors, like this one, are operator-invoked once
rather than running on the PR path.

### Task 3 — `COVERAGE.md` reconciliation + `240-EVIDENCE.md` skeleton (commit `dc24949e`)

`COVERAGE.md` was re-read against the collector **as actually implemented**. The collector issues
exactly four distinct external reads — `GET /rate_limit`,
`GET /repos/{repo}/actions/runs/{id}`, `GET /repos/{repo}/actions/runs/{id}/jobs?filter=latest`
(twice: SC-1 legs, and once per `main` run for SC-2), and
`GET /repos/{repo}/actions/workflows/ci.yml/runs?branch=main&created=…` — and **all four already
carried an `INTEGRATE` row**. No row was added; no row moved to `OPT-OUT`. Every `OPT-OUT` row
still carries a non-empty reason. A reconciliation section records the endpoint-by-endpoint check
and notes that the remaining `INTEGRATE` rows (dispatches, the four Pages endpoints, the three
issue endpoints) belong to plans 01 and 04, not to this collector — `INTEGRATE` is a phase-level
decision, not a per-script one.

`240-EVIDENCE.md` was authored with exactly six level-2 slots in the required order:
`BEFORE-MAIN-RED-MISATTRIBUTION`, `AFTER-PAGES-LOUD-RED`, `AFTER-P20-GUARD-OBSERVED`,
`AFTER-GREEN-04-N20`, `AFTER-CI-GATE-MAIN-WINDOW`, `AFTER-ISSUE-231-CLOSED`. Every slot carries a
`Status: pending (<reason> obligation)` line with the literal word **obligation**, and at least one
fenced block holding the exact command that will later produce its evidence; every fenced block
contains a `gh api`, `gh run`, `gh workflow`, `gh issue` or `jq` invocation.

The header carries an HTML comment naming the bare-`captured` grammar trap: `236-EVIDENCE.md`'s
`## AFTER-P17-GUARD-OBSERVED` uses `Status: captured` with no parenthetical, which **fails** p12's
status regex and passes today only because p12 never reads that ledger. The only legal captured
forms are `captured (run <id>)` and `captured (runs <id>, <id>, …)`, and the comment says so, so a
later editor cannot reintroduce the bare form by copying the analog.

The header also states both claims in prose, as required regardless of what Plan 04 later
evidences: **(a) D-09** — `main`'s run-level `failure` is a misattribution; on run `35365693716`
(HEAD `bca3ad72`) the only non-success job was `Admin eval render + probe`, documented at
`ci.yml:2089-2110` as deliberately outside `ci-gate.needs`, and `Notify on red ci-gate` was
`skipped`, which per `ci.yml:1645-1655` positively proves `ci-gate` itself was not red.
**(b) D-10** — `example_unit_smoke` is absent from the ten `ci-gate.needs` entries at
`ci.yml:1547-1557` (enumerated verbatim in the ledger) while being independently required by
ruleset 14941512, so `ci-gate: success` is a nine-of-ten claim. This phase discloses it; the fix is
owned by `.planning/todos/pending/2026-07-29-example-unit-smoke-required-but-absent-from-ci-gate-needs.md`.

## Verbatim transcripts

**p12 redirected at the new ledger** — the expected failure, recorded as the plan requires:

```
$ GSD_PROHIB_SUBJECT=.planning/phases/240-green-main-evidence-honest-pages-script/240-EVIDENCE.md \
    node --test --test-reporter=tap scripts/ci/prohibitions/p12-run-id-provenance.test.mjs
ok 1 - the ledger parse finds a non-trivial set of observation slots
ok 2 - every slot declares a Status in the allowed grammar
not ok 3 - every captured slot names at least one run ID in its Status
  error: 'only 0 captured slot(s) — too few for this assertion to mean anything.'
ok 4 - every captured slot carries a fenced block naming the producing command
ok 5 - each captured slot Status run ID also appears in that slot body
ok 6 - a pending slot books its obligation instead of claiming a number
# tests 6 / pass 5 / fail 1
```

The single failure is the **captured-count floor** (`captured.length >= 3`), exactly as predicted,
and **not** the `evidence ledger parsed to zero BEFORE-*/AFTER-* slots` error — subtest 1 passed,
so the parse found ≥4 slots (six, confirmed independently by the Task 3 `<verify>` snippet, which
printed all six names). Plan 04 flips the slots to `captured` and re-runs this to green.

**Slot-count verify:**

```
$ node -e "…/^## ((?:BEFORE|AFTER)-[A-Z0-9-]+)\s*$/gm … expect 6 … no bare captured Status"
SLOTS OK: BEFORE-MAIN-RED-MISATTRIBUTION, AFTER-PAGES-LOUD-RED, AFTER-P20-GUARD-OBSERVED,
AFTER-GREEN-04-N20, AFTER-CI-GATE-MAIN-WINDOW, AFTER-ISSUE-231-CLOSED
```

**Shared prohibitions glob unaffected by the new ledger:**

```
$ node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs
# tests 93 / pass 93 / fail 0
```

**Collector syntax + selector-contract greps:**

```
$ bash -n scripts/ci/capture-green-04-evidence.sh                       # exit 0
$ grep -n '\.name ==' scripts/ci/capture-green-04-evidence.sh           # NO HITS
$ grep -n '^JOB_NAME=' scripts/ci/capture-green-04-evidence.sh
47:JOB_NAME="Generated admin Playwright smoke (GREEN-04 repeat)"
$ sed -n '53p' .github/workflows/green-04-evidence.yml
    name: Generated admin Playwright smoke (GREEN-04 repeat)
```

Prefix identity holds: the constant is the workflow's `name:` value with **no** ` (N)` suffix.

**No dispatch happened.** This plan issued zero live GitHub API calls — every `gh` invocation in
this plan's work went to the hermetic stub. The dispatch and the live capture are Plan 04's,
and are operator-credentialed.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 — Blocking] The bare-name detector avoids `.name ==` entirely**

- **Found during:** Task 1.
- **Issue:** The plan's `no_matrix_suffix` path needs to detect jobs matching `JOB_NAME` with no
  suffix, and the natural jq for that is `select(.name == $jn)`. But Task 1's acceptance criterion
  is `grep -n '\.name ==' … returns **no** hit for the SC-1 leg selector` — a `.name ==` anywhere
  in the file makes that grep ambiguous for a later reviewer, who then has to reason about which
  occurrence is the selector.
- **Fix:** The bare detector uses an anchored regex `test("^${JOB_NAME_ESC}$")` instead. The grep
  now returns zero hits **anywhere** in the file, which is strictly stronger and unambiguous.
- **Files modified:** `scripts/ci/capture-green-04-evidence.sh`.
- **Commit:** `6b2064f6`.

### Documented divergences (not defects)

**2. `filter=latest` reaches the endpoint strings through the `JOBS_FILTER` constant**

Task 1's acceptance criterion reads "`filter=latest` appears in both `/jobs` endpoint strings". In
the implementation both strings read `…/jobs?filter=${JOBS_FILTER}` with `JOBS_FILTER="latest"` as
a fixed constant, so the literal `filter=latest` appears once (in the constant) and reaches both
call sites by substitution — confirmed in the live call log
(`grep -q 'filter=latest&per_page=100&page=1'` is an asserted test case). D-11's requirement is
that the filter be **chosen explicitly rather than left to the endpoint default**, and that it be
recorded in the receipt; both hold (`.sc1.jobs_filter` and `.sc2.jobs_filter` are asserted equal to
`"latest"` in the self-test). A repeated literal would have been three sources of truth for one
decision.

**3. Receipt carries two extra per-run fields beyond the RESEARCH §2 shape**

`sc2.runs[]` additionally carries `ci_gate_conclusion` and `generated_admin_smoke_conclusion`
alongside the full `jobs[]` list, and `sc2` carries `run_count` and `job_name`. This is additive:
it makes `ci_gate_conclusions` and `flake_attributable_red_count` re-derivable from the receipt
itself rather than having to be trusted, which is the whole posture of this phase.

### Warnings from the wave-1 handoff, discharged

- **The `sh.length !== 4` uses-pin snippet was not reused.** This plan has no `uses:` counting
  assertion of any kind; nothing was copied from 240-02 Task 1's verification snippet.
- **GREEN-04 was NOT marked complete.** No `requirements.mark-complete` was run in this plan.
  `.planning/REQUIREMENTS.md` is untouched by all three commits (`git show --stat` on
  `6b2064f6`, `941d679d`, `dc24949e` lists no requirements file). GREEN-04's text requires n≥20
  proven green at the final committed HEAD, which has not happened; **Plan 04 marks it.**
- **The pre-existing `mix ci` failure cluster was not investigated.** See Deferred Issues.

## Deferred Issues

**6 pre-existing `Sigra.Audit.Forwarders.ThreadlineTest` failures** (`UndefinedFunctionError …
Sigra.Audit.Forwarders.Threadline.attach/1 is undefined`) cause `MIX_ENV=test mix ci` to exit 2.
Local run on this plan's HEAD:

```
33 doctests, 3 properties, 2606 tests, 6 failures, 12 skipped (22 excluded)
…
65 tests, 0 failures (2599 excluded)        # generated-host / example lane
```

Byte-identical counts to the 240-02 run. Independently verified by the orchestrator as **not**
caused by phase 240 (`origin/main` is the phase base commit, no Elixir source/test/dep/config file
has changed on this branch, and CI on `main` shows library tests passing). Already logged in
`deferred-items.md`. Not investigated and not fixed here — scope boundary.

This means the Task 3 acceptance criterion "`MIX_ENV=test mix ci` exits 0" is **not met locally**,
for a reason exogenous to this plan. Zero formatting issues and zero Credo issues. Every other
Task 3 criterion is met verbatim, and
`node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs` exits 0 (93/93).

## Authentication Gates

None. Every `gh` call in this plan's work was served by the hermetic stub; no token was used and
no live API was read.

## Known Stubs

None in shipped code. The `gh` stub in `capture-green-04-evidence.test.sh` is a test double by
design, and its fidelity is the point of the `bare_job_names` negative control.

## Threat Flags

None. The plan's register is discharged:

- **T-240-03** (Repudiation, window selection) — mitigated: repo, both workflow ids, both job-name
  selectors and `filter` are fixed constants with no `${VAR:-}` escape; only `--run-id`,
  `--output` and the window bounds are arguments, and an unknown flag exits non-zero (asserted).
  `head_sha` + `clean_tree` are in the receipt (asserted).
- **T-240-03b** (Information Disclosure, silent truncation) — mitigated: the copied pagination core
  plus the `truncated` self-test case, which proves a `total_count`/length disagreement becomes a
  hard failure with no receipt written.
- **T-240-03c** (Spoofing, run-level vs job-level) — mitigated: both verdicts come from
  `/runs/{id}/jobs`; the `ok` fixture deliberately sets every `main` `run_conclusion` to `failure`
  while `ci-gate` is `success`, and the self-test asserts the receipt reports green — the D-09
  misattribution reproduced as a test.
- **T-240-03d** (Tampering, jq over untrusted text) — mitigated: response bodies are only piped to
  `jq` with `-e` schema assertions; never `eval`ed, never interpolated into a further shell
  command.
- **T-240-SC** (package-manager installs) — accepted as planned: no dependency added; only `gh`,
  `jq`, `git` and `bash`.

## Commits

| Task | Name | Commit | Files |
| ---- | ---- | ------ | ----- |
| 1 | Fail-closed non-steerable collector | `6b2064f6` | `scripts/ci/capture-green-04-evidence.sh` |
| 2 | Hermetic stub harness | `941d679d` | `scripts/ci/capture-green-04-evidence.test.sh` |
| 3 | COVERAGE reconciliation + ledger skeleton | `dc24949e` | `COVERAGE.md`, `240-EVIDENCE.md` |

## Handoff to Plan 04

- Invoke the collector as
  `scripts/ci/capture-green-04-evidence.sh --output <path> --run-id <dispatch id>
  --main-window-start <UTC> --main-window-end <UTC>` on a **clean tree at the final committed
  HEAD** — it refuses anything else (`dirty_tree`,
  `evidence_run_head_sha_is_not_final_committed_head`). Dispatch **after** the last code commit.
- The six ledger slots are all `pending`; flipping ≥3 to `captured (run <id>)` /
  `captured (runs …)` is what turns p12 green under `GSD_PROHIB_SUBJECT`. Each cited run id must
  appear **again** in the slot body, not only in the `Status:` line.
- **Plan 04 marks GREEN-04 complete.** This plan deliberately did not.
- Raw material for `AFTER-P20-GUARD-OBSERVED` is in `240-02-SUMMARY.md`; for
  `AFTER-GREEN-04-N20` and `AFTER-CI-GATE-MAIN-WINDOW` it is the receipt this collector emits.

## Self-Check: PASSED

- `scripts/ci/capture-green-04-evidence.sh` — FOUND (executable, `bash -n` exit 0)
- `scripts/ci/capture-green-04-evidence.test.sh` — FOUND (exit 0, `pass=36 fail=0`)
- `.planning/phases/240-green-main-evidence-honest-pages-script/COVERAGE.md` — FOUND (modified)
- `.planning/phases/240-green-main-evidence-honest-pages-script/240-EVIDENCE.md` — FOUND (6 slots)
- commit `6b2064f6` — FOUND
- commit `941d679d` — FOUND
- commit `dc24949e` — FOUND
