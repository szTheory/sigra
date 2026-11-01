---
phase: 240-green-main-evidence-honest-pages-script
plan: 02
subsystem: ci
tags: [ci, evidence, prohibitions, workflow, green-04]
status: complete

requires:
  - "ci.yml:1401-1533 (`generated_admin_playwright_smoke`) as the copied source of truth"
  - "scripts/ci/prohibitions/_lib.mjs (`readSubject`, `readRepoFile`, `jobBlock`, `stripYamlComments`)"
  - "the prohibitions glob at ci.yml:383-393"
provides:
  - ".github/workflows/green-04-evidence.yml — dispatch-only n>=20 repeat harness"
  - "workflow name `GREEN-04 evidence (n>=20 repeat)`"
  - "job id `green_04_evidence_repeat`, job name `Generated admin Playwright smoke (GREEN-04 repeat)`"
  - "matrix key `repeat`, values 1..20"
  - "artifact names `generated-admin-report-${{ matrix.repeat }}`, `generated-admin-failure-diagnostics-${{ matrix.repeat }}`"
  - "scripts/ci/prohibitions/p20-green-04-evidence-step-parity.test.mjs (guard `p20`)"
  - "test/fixtures/prohibitions/p20-green-04-step-drift.yml (known-bad fixture)"
affects:
  - "Plan 03 (the collector) — must anchor on the job-name PREFIX, never byte equality"
  - "Plan 04 (dispatch + evidence capture) — owns the `AFTER-P20-GUARD-OBSERVED` slot and the dispatch"

tech-stack:
  added: []
  patterns:
    - "offline structural prohibition guard (node:test, dependency-free, no gh/token/network)"
    - "pure checker function shared by the real subject and the known-bad fixture (p15/p19 idiom)"
    - "non-vacuity floor: a zero-step parse is a failure, never a pass"

key-files:
  created:
    - .github/workflows/green-04-evidence.yml
    - scripts/ci/prohibitions/p20-green-04-evidence-step-parity.test.mjs
    - test/fixtures/prohibitions/p20-green-04-step-drift.yml
  modified: []

decisions:
  - "D-02's byte-faithfulness is enforced mechanically by p20 rather than asserted in a comment — a comment alone is the 'green gate that verified nothing' pattern this milestone exists to remove."
  - "Body-level artifact-name normalisation, not step-name normalisation: the `-${{ matrix.repeat }}` suffix lives on `with.name:` inside upload-step bodies; the step NAMES are byte-identical on both sides, so normalising step names would have been a no-op written as if it did work."
  - "p20 compares normalized step BODIES for all thirteen steps, not just the four upload steps — strictly stronger than the plan's floor, and the artifact-name suffix remains the one and only tolerated body difference."
  - "Guard id is `p20`: `ls scripts/ci/prohibitions/` returns p01-p17 and p19; there is no p18, and reusing a skipped id invites 'deleted or never born?' ambiguity."

metrics:
  duration: ~35m
  completed: 2026-09-18
  tasks: 3
  commits: 3

actuals:
  tokens: 8500
  tasks: 3
  commits: 3
---

# Phase 240 Plan 02: GREEN-04 Evidence Workflow + p20 Step-Parity Guard Summary

A dispatch-only 20-leg repeat harness that is a byte-faithful copy of `ci.yml`'s
`generated_admin_playwright_smoke`, plus the offline `p20` guard that makes the copy *provably* a
copy — demonstrated RED against a committed known-bad fixture in the commit the guard was born.

## What Was Built

### Task 1 — `.github/workflows/green-04-evidence.yml` (commit `60ff28a4`)

- `name: GREEN-04 evidence (n>=20 repeat)`, `on: workflow_dispatch` and nothing else,
  workflow-level `permissions: contents: read` only (T-240-02b, least privilege), **no**
  `concurrency` block.
- One job, id `green_04_evidence_repeat`, name
  `Generated admin Playwright smoke (GREEN-04 repeat)`, carrying the D-01 shape:
  job-level `if: github.ref == 'refs/heads/main'`, `runs-on: ubuntu-latest`,
  `timeout-minutes: 15`, the `services.postgres` block copied verbatim from `ci.yml:1422-1430`,
  and `strategy: { fail-fast: false, max-parallel: 5, matrix: { repeat: [1 … 20] } }` with all
  twenty integers listed explicitly.
- **THE JOB-NAME CONTRACT is recorded as a comment directly under the job's `name:` key**:
  because this job carries both a `name:` and a `strategy.matrix`, `GET /runs/{id}/jobs` returns
  twenty jobs named `Generated admin Playwright smoke (GREEN-04 repeat) (1)` … ` (20)`
  (`ci.yml:556-560` records the rule). Downstream selectors must be prefix/anchored-regex
  (`^<name> \((\d+)\)$`), never byte equality — a byte-equality selector harvests **zero** legs.
- All **thirteen** steps copied in order (three unnamed `uses:`, six named, four uploads) with
  every action pin at the identical 40-character commit SHA as `ci.yml` and its trailing version
  comment. Four distinct pins, seven `uses:` lines, all four SHAs verified present in `ci.yml`:
  `actions/checkout@3d3c42e5…`, `erlef/setup-beam@54075bcc…`, `actions/setup-node@82076278…`,
  `actions/upload-artifact@043fb46d…`.
- The three mandatory D-02 exceptions are each named **with its reason** in the file header:
  1. artifact names suffixed `-${{ matrix.repeat }}` — `upload-artifact` v7 errors on a duplicate
     artifact name within one run, so a literal copy fails on leg 2;
  2. `needs: release_ref_guard` omitted — unresolvable `needs:` is a workflow-validation error;
     its role is replaced by the job-level `if` (precedent `fast-01-remeasurement-evidence.yml:11`);
  3. workflow-level `concurrency` omitted — its group key references a pull-request number
     meaningless on a dispatch-only workflow, and `cancel-in-progress` would kill an in-flight
     20-leg matrix.
- Header cites `ci.yml:1401-1533` as the source of truth and names
  `scripts/ci/prohibitions/p20-green-04-evidence-step-parity.test.mjs` as the enforcing guard.
  `max-parallel: 5` carries its own D-04 reason comment (per-**account** concurrent-job ceiling,
  Free = 20 / Pro = 40, no public-repo exemption), and the matrix carries the D-07 cost note
  (3.73m measured × 20 ≈ 75-100 runner-minutes, one-off, operator-triggered).
- Per RESEARCH OQ3 the four `github.ref != 'refs/heads/main'` upload legs are kept **verbatim**
  even though the job-level `if` makes them dead.

### Task 2 — `p20` + its known-bad fixture (commit `962fa0b5`)

`scripts/ci/prohibitions/p20-green-04-evidence-step-parity.test.mjs`:

- House header contract (p15:1-31 shape): the `MUST NOT` sentence, the subject
  (`.github/workflows/green-04-evidence.yml`, redirectable via `GSD_PROHIB_SUBJECT`), the
  reference (`.github/workflows/ci.yml`, read from its real location and never substituted —
  a guard has exactly one substitutable subject), and
  **STRUCTURAL AND OFFLINE BY DESIGN — no gh, no token, no network**.
- Imports only `node:test`, `node:assert/strict` and `./_lib.mjs`. No dependency added, no
  `ci.yml` edit, no `mix.exs` edit — the glob at `ci.yml:383-393` picks it up (standing
  constraint 5).
- `stepList()` copied verbatim from `p15:40-56`. `stripYamlComments` applied to **both** sides
  before any content assertion — this workflow's own header comment quotes three of the four
  load-bearing commands, so a naive text match would misattribute prose to a trailing step.
- Pure `parityIssue(refSteps, evSteps)` so the real pair and the fixture run identical code.
  Order of checks: parse-broke (either side empty) → step-count drift (naming the steps missing
  from / extra in the copy) → first step-name divergence → first normalized step-**body**
  divergence → asymmetry on the four load-bearing commands (`npm ci`,
  `npx playwright install --with-deps chromium webkit`,
  `mix archive.install --force hex phx_new 1.8.8`,
  `scripts/ci/admin-acceptance-smoke.sh --test all`). Returns `null` only when every check passes.
- **Artifact-name normalisation scoped correctly.** The `-${{ matrix.repeat }}` suffix does not
  live on any step *name* — the four upload step names are byte-identical on both sides. The
  normalisation is applied inside step **bodies**, on `with.name:` values, so the D-02
  artifact-name exception is the one and only tolerated body difference and every other body edit
  still reports as drift. Blank lines (left behind by comment-stripping) and trailing whitespace
  are canonicalized away.
- Three `test()` blocks: behavior (real pair → `parityIssue` is `null`), non-vacuity floor (both
  parses non-empty, both find the acceptance-smoke invocation, and an injected empty list is
  asserted to be reported as a failure in both directions), and the negative control reading
  `test/fixtures/prohibitions/p20-green-04-step-drift.yml` through `readRepoFile`.

`test/fixtures/prohibitions/p20-green-04-step-drift.yml`: a copy of the evidence workflow with the
`Install Playwright browsers` step deleted — the most consequential possible drift, because the
smoke would still "run", against no browsers. It carries the `p06`-style prose header stating it is
a KNOWN-BAD fixture, that it is structurally valid so the non-vacuity floor **passes** and the red
comes from the clause under test, and naming the injected defect explicitly. Job id
`green_04_evidence_repeat` preserved so `jobBlock` resolves it.

### Task 3 — RED/green transcripts and the local gate

## Verbatim transcripts (raw material for Plan 04's `AFTER-P20-GUARD-OBSERVED` slot)

All three run through `bash -c`, never zsh (zsh does not word-split unquoted parameter expansions
and has produced a confident false negative in this repo before).

**RED half** — the guard pointed at the committed known-bad fixture:

```
$ GSD_PROHIB_SUBJECT=test/fixtures/prohibitions/p20-green-04-step-drift.yml \
    node --test --test-reporter=tap scripts/ci/prohibitions/p20-green-04-evidence-step-parity.test.mjs
EXIT=1
```

Verbatim assertion message (subtest 1, `not ok 1 - the evidence job step list matches ci.yml
generated_admin_playwright_smoke`):

```
step-count drift: ci.yml#generated_admin_playwright_smoke has 13 steps,
.github/workflows/green-04-evidence.yml#green_04_evidence_repeat has 12 — missing from the
evidence copy: `Install Playwright browsers`. The evidence copy is no longer the lane it claims
to prove (D-02).
```

Subtests 2 (non-vacuity floor) and 3 (negative control) both reported `ok` on that same run — the
red came from the clause under test, not from an empty parse. This is the ROADMAP standing
constraint 6 observation, made in commit `962fa0b5`, the commit the guard was born in.

**Green half** — the guard against the real pair:

```
$ node --test --test-reporter=tap scripts/ci/prohibitions/p20-green-04-evidence-step-parity.test.mjs
EXIT=0
# tests 3 / pass 3 / fail 0
```

**Shared glob unaffected** — p20 does not disturb p01-p19:

```
$ node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs
GLOB EXIT=0
# tests 93 / pass 93 / fail 0
```

**No dispatch happened** (D-13 orders the dispatch after the final code commit; it is Plan 04's
responsibility):

```
$ gh run list --workflow green-04-evidence.yml --limit 5
HTTP 404: workflow green-04-evidence.yml not found on the default branch
```

`workflow_dispatch` is not even offered yet — the file is not on the default branch.

**Local full gate:** test Postgres booted via `bash scripts/db/up.sh` (dynamic port 61985), env
sourced from `tmp/db.env`, `phx_new 1.8.8` archive reinstalled, then
`MIX_ENV=test mix ci` → **exit 2**, with `33 doctests, 3 properties, 2606 tests, 6 failures,
12 skipped`. All six failures are the pre-existing `Sigra.Audit.Forwarders.ThreadlineTest`
`UndefinedFunctionError … Threadline.attach/1` cluster (see Deferred Issues). Zero formatting
issues, zero Credo issues, and the generated-host lane reported `65 tests, 0 failures`. No
failure in this run is attributable to this plan's diff — the diff adds one workflow, one
`.test.mjs` guard and one YAML fixture, and touches no Elixir source, test, dep or config file.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 — Blocking] Task 1's `<automated>` verify snippet miscounts SHA-pinned `uses:` lines**

- **Found during:** Task 1 verification.
- **Issue:** The snippet asserts `sh.length !== 4` over
  `/uses:\s*\S+@[0-9a-f]{40}/g` and threw `expected 4 SHA-pinned uses, got 7`. The job genuinely
  has **seven** `uses:` lines — three setup actions plus four `upload-artifact` invocations — drawn
  from **four distinct** pinned actions. The plan's own acceptance criterion is the correct
  statement of the invariant: *"Every `uses:` in the file is a 40-character commit SHA that also
  appears in `.github/workflows/ci.yml` — verified by reading each pin against its `ci.yml`
  counterpart, **not by counting**."* The `4` in the snippet is the distinct-action count applied
  to a per-line matcher.
- **Fix:** Corrected the check rather than the file: assert 7 `uses:` lines, each SHA-pinned,
  each pin string present in `ci.yml`, and exactly 4 distinct pins. All other assertions in the
  snippet ran unchanged and passed (13 steps; 4 artifact names, all matrix-suffixed;
  job-level `if` present; no `needs:`/`concurrency:` outside comments; all four required literals
  present).
- **Files modified:** none — this was a defect in the verification snippet, not in the artifact.
- **Commit:** `60ff28a4` (the artifact it verifies).

**2. [Scope strengthening, not a deviation from intent] Body parity applied to all thirteen steps**

The plan's action text scopes the artifact-name normalisation to "the four upload steps' `text`".
`p20` compares normalized bodies for **all thirteen** steps with that same normalisation applied
globally. This is strictly stronger and preserves the stated behavior exactly: the
`-${{ matrix.repeat }}` suffix remains the one and only tolerated body difference, and every other
body edit — in any step — reports as drift.

## Deferred Issues

**6 pre-existing `Sigra.Audit.Forwarders.ThreadlineTest` failures** (`UndefinedFunctionError …
Threadline.attach/1`), causing `MIX_ENV=test mix ci` to exit 2. This is a local optional-dep
load-order artifact independently verified by the orchestrator as **not** caused by phase 240:
`origin/main` is exactly the phase base commit, no Elixir source/test/dep/config file has changed
on this branch, and CI on `main` shows library tests passing. Already logged to
`deferred-items.md` by plan 240-01. Not investigated and not fixed here (scope boundary: only
auto-fix issues directly caused by the current task's changes).

This means the Task 3 acceptance criterion "`MIX_ENV=test mix ci` exits 0" is **not met locally**,
for a reason exogenous to this plan. Every other Task 3 criterion is met verbatim.

## Authentication Gates

None.

## Known Stubs

None. Both new artifacts are fully wired: the workflow is complete and dispatchable once on the
default branch, and the guard is picked up by the existing prohibitions glob with zero workflow
edits.

## Threat Flags

None. The plan's threat register is fully discharged:

- **T-240-02** (Tampering, action pins) — mitigated: all seven `uses:` lines are 40-character
  commit SHAs, each verified present in `ci.yml`; four distinct pins, no tags.
- **T-240-02b** (EoP, token scope) — mitigated: workflow-level `permissions: contents: read` only;
  no `id-token`, no `attestations`, no `actions: write`.
- **T-240-05** (Repudiation, harness drift) — mitigated: `p20` asserts step-list, step-name,
  step-body and command parity against `ci.yml:1401-1533` on every PR, demonstrated RED against a
  committed known-bad fixture before acceptance.
- **T-240-SC** (npm installs) — accepted as planned: `npm ci` installs strictly from the committed
  `test/example/priv/playwright/package-lock.json`; no new package is introduced by this plan.

## ROADMAP scope-discipline reconciliation (on the record)

ROADMAP's scope-discipline line reads *"Reuse the FAST-01 n=52 machinery; build no new harness."*
This plan authors a new workflow, which a reviewer reading only the ROADMAP would read as violating
a binding constraint. It does not:

- **D-01** (locked, dated after the ROADMAP line) explicitly selects a **new dispatch-only
  evidence workflow** rather than a matrix on the live `ci.yml` job.
- **D-06** (rejected alternative, recorded; nothing implemented) records why the live-job matrix
  was refused: `ci.yml:556-560` documents that a bare matrix suffixes the job name, churning the PR
  lane and moving a job id Phase 241 SC-3/SC-5 is about to pin.
- **D-05** (rejected alternative, recorded; nothing implemented) likewise refuses dispatching
  `ci.yml` itself 20x — ≈20x full-DAG cost, and it re-runs `admin_eval_render`, currently red on
  `main`, polluting the very run list SC-2 reads.

The FAST-01 machinery is reused as a shape (dispatch-only + job-level ref guard, per
`fast-01-remeasurement-evidence.yml:11`) and, in Plan 03, as a copied pagination/emission core.
The later-dated locked decisions govern.

## Commits

| Task | Name | Commit | Files |
| ---- | ---- | ------ | ----- |
| 1 | Author `green-04-evidence.yml` | `60ff28a4` | `.github/workflows/green-04-evidence.yml` |
| 2 | `p20` guard + known-bad fixture | `962fa0b5` | `scripts/ci/prohibitions/p20-green-04-evidence-step-parity.test.mjs`, `test/fixtures/prohibitions/p20-green-04-step-drift.yml` |
| 3 | RED transcript + local gate | (docs) | this SUMMARY |

## Handoff to Plans 03 and 04

- **Plan 03 (collector):** the twenty Actions-API job names are
  `Generated admin Playwright smoke (GREEN-04 repeat) (1)` … ` (20)`. Anchor on
  `^Generated admin Playwright smoke \(GREEN-04 repeat\) \((\d+)\)$`. A `.name == "…(GREEN-04
  repeat)"` selector harvests **zero** legs.
- **Plan 04 (dispatch + evidence):** the RED/green/glob transcripts above are the raw material for
  the `AFTER-P20-GUARD-OBSERVED` slot (`236-EVIDENCE.md`'s `## AFTER-P17-GUARD-OBSERVED` is the
  shape). The dispatch must happen on a **clean tree at the final committed HEAD** (D-13), and
  `workflow_dispatch` only becomes available once `green-04-evidence.yml` is on the default branch.

## Self-Check: PASSED

- `.github/workflows/green-04-evidence.yml` — FOUND
- `scripts/ci/prohibitions/p20-green-04-evidence-step-parity.test.mjs` — FOUND
- `test/fixtures/prohibitions/p20-green-04-step-drift.yml` — FOUND
- commit `60ff28a4` — FOUND
- commit `962fa0b5` — FOUND
