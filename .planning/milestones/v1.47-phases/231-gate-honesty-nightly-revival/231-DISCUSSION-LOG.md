# Phase 231: Gate Honesty + Nightly Revival - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in `231-CONTEXT.md` — this log preserves the analysis.

**Date:** 2026-07-29
**Phase:** 231-gate-honesty-nightly-revival
**Mode:** assumptions
**Areas analyzed:** GATE-03 honest-skip enforcement, GATE-02 stale `head_ref`, GATE-04
`admin_eval_render` order of operations, GATE-01 nightly revival, DX-05 release lane, sequencing,
success-criterion observation

**Method note:** the analyzer made **24 live `gh` observations across 20 run IDs** before forming
any assumption. This produced two corrections to the written record and one wholly new finding
(below), none of which were derivable from a source read.

## Assumptions Presented

### GATE-03 — honest-skip enumeration and enforcement

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Consume `.github/ci-skip-manifest.tsv` rather than building a new enumeration | Confident | Manifest header block explicitly assigns this to GATE-03; `scripts/ci/prohibitions/honest-skip-parity.test.mjs`; `MAINTAINING.md:142-199` |
| Enforce from a step inside the existing `ci-gate` job, not a new job | Confident | `ci.yml:1789-1840`, consequence already owned at `:1831`; ~10 `scripts/ci/*.sh`+`*.test.sh` pairs at `ci.yml:155-230` |
| PR honest-skip set is exactly `{upgrade_smoke, library_tests_dep_off (docs-only)}`; no needed lane may skip on non-PR events | Confident | `ci.yml:1793-1802`, `:848`, `:1674`, `:138-141`; observed on PR run `30412458437` |
| Zero parsed rows = broken parse, must fail | Confident | `scripts/ci/ci-demotion-observer.sh:70-80` |
| Prove SC-3's fail direction with a dispatch-input probe, not a branch experiment | Likely | `ci.yml:8-12, 2585-2595` (`nightly_probe` / `force_fail_probe`) |

### GATE-02 — replacing the stale `head_ref`

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Delete the `if:` at `ci.yml:1674` outright; do **not** substitute `!= 'pull_request'` | Confident | GATE-02 requirement text; `MAINTAINING.md:274` residual |
| Cost is ~0 wall-clock / ~4 runner-min; no FAST-01 conflict | Confident | Job durations 222-268s across runs `30425416933`, `30389700235`, `30387490396`, `30379435985`, `30374856611`, `30325414426`; PR pole 989s of a 1012s wall (`30412458437`); only dep is `release_ref_guard` (3s) |
| The `admin-generated.spec.ts:176` failure is a ~38% sticky flake, not transient — must be fixed before enabling | Confident (rate); **Unclear** (root cause) | 8 pass / 5 fail sample; fails on retry too; contradicts `230-VERIFICATION.md:174` |
| Deleting the clause requires same-commit edits to the manifest row, `MAINTAINING.md:137`, and `:274` | Confident | `honest-skip-parity.test.mjs` fails in every direction, runs on every PR |

### GATE-04 — order of operations

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Strict order: install webkit + re-token cache key → fix `probes.ts:380` → read b1-b6 → only then delete job-level `continue-on-error` | Confident | Push run `30472016250` job `90644402928`: `76 failed, 116 passed (16.2m)`, exit 1 at phase (a); `playwright.config.ts:215-217`; `ci.yml:2517`; 230-CONTEXT D-16 |
| Step-level `continue-on-error` at `ci.yml:2548` stays (only job-level `:2450` is removed) | Confident | `:2548` precedes the artifact upload and the re-fail step at `:2560-2565` |
| "Guards executed" is observed via literal `(b1)`…`(b6)` banners + `PASS — all phases green` + job conclusion | Confident | `scripts/ci/admin-eval-harness.sh:63, 93-116`; `stale-render-guard.sh` runs nowhere else |
| A third defect class is likely — b1-b6 have never executed in CI | Likely | `fix-queue-build.mjs` rewrites `open_findings` in the working tree; b3/b4/b5 compare against committed HEAD (`--base HEAD`, `admin-eval-harness.sh:99-113`); `stale-render-guard.sh:1-24`; v1.44 fix-queue-lint prior art |

### GATE-01 — nightly revival

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Literal green is reachable; fallback held in reserve | Confident | Nightly `30425416933`: 25 jobs, 23 green; the only two reds are GATE-02's and GATE-04's defects |
| The GitHub-Pages publisher red is a **missing seeds prelude**, not spec drift | Confident (locator + gap); Likely (seeds alone fixes it) | Scheduled run `30432494488` fails all three checkpoint projects at `admin-checkpoints.spec.ts:230`; `playwright-github-pages.yml:81`→`:95` has no seeds step vs `ci.yml:1288`, `:1950`, `:2258`, `:2506` |
| `pages-build-deployment` is a **new, unfiled** red — Pages builds main's repo root, not `gh-pages` | Confident (red + cause); Unclear (self-heal) | Six consecutive failures `30472014592`, `30466317343`, `30461965393`, `30389698709`, `30387487782`, `30379433249`; Jekyll `github-pages v232` rendering `AGENTS.md`/`CHANGELOG.md`/`brandbook/**` from `/github/workspace/.`; `ensure-github-pages-legacy-branch.sh` runs only after a successful publish |
| GATE-01 requires deleting `ci-observe.yml:130-136` | Confident | That code's own comment: "REMOVAL CONDITION: Phase 231 GATE-01"; `MAINTAINING.md:255-262` |

### DX-05 — release lane

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `max_attempts` 60→120 at `release-please.yml:119` + add `timeout-minutes` to the job | Confident | Run `30379435985` succeeded at ~17:17Z; its waiter `30379435970` gave up at 17:16:37Z; post-230 push wall 28m29s (`30466318240`), historical max 42.3m; job at `:96-104` has no `timeout-minutes` (inherits 360) |
| SC-5's literal wording is not directly observable in-phase | Likely | `release-please.yml:100` — `if: release_created == 'true'` never fires on an ordinary push |
| Make `notify-failure-issue.sh` self-healing with a `gh`-shadowing self-test | Confident | Todo's own preference; stub technique at `ci-demotion-observer.sh:37-39` |
| The red-probe is **already observed** — cite issue #118, do not re-stage | Confident | Issue #118 created 2026-07-29T01:39:14Z by run `30414636733`, 3 idempotent comments from `30414885679`, `30425416933`, `30461966943`; notifier `failure` on `30331796188` (pre-label) → `success` on `30425416933` (post-label) |

### Sequencing and observation

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| GATE-02 fix → GATE-04 fix → GATE-02 enable → GATE-03 → GATE-01; DX-05 parallel | Confident | Nightly `30425416933` job list shows GATE-01's reds *are* the other two defects; GATE-03 landing first would enshrine a known-rotted gate in its own oracle |
| Every SC closes on a named run ID + named command | Confident | `ROADMAP.md:40-43`; `.planning/v1.42-CI-GATE-REMEDIATION-FINDINGS.md` |

## Corrections Made

Three questions cleared METHODOLOGY.md's escalation threshold and were put to the owner. **All three
were answered with the recommended option.**

### DX-05 proof route
- **Question:** SC-5 requires observing `gate-ci-green` complete inside its ceiling on a real
  push-to-main, but the job only runs when `release_created == 'true'`.
- **Owner selection:** *Extract + live-invoke* — pull the polling loop into
  `scripts/ci/wait-for-ci-gate.sh` with a hermetic self-test in `fast_checks`, invoke it live against
  a real completed push-to-main SHA, and book next-real-release confirmation as a standing receipt.
- **Rejected:** blocking the phase on a real release; shipping the fix with the proof deferred.
- **Recorded as:** D-21.

### `pages-build-deployment` scope
- **Question:** A newly-discovered daily red on `main` that no todo covers and no GATE-0x requirement
  names — in or out of GATE-01?
- **Owner selection:** *Fix the publisher, then reassess* — in scope only insofar as the seeds fix
  lets `ensure-github-pages-legacy-branch.sh` finally run; if it does not self-heal, file it as a
  diagnosed defect with an owner under SC-1's fallback branch rather than expanding into a
  repo-admin Pages reconfiguration.
- **Rejected:** owning it fully (adds a human-gated step); deferring it entirely.
- **Recorded as:** D-18.

### Generated-smoke flake diagnosis appetite
- **Question:** The ~38% 320px flake blocks GATE-02 and its root cause is unconfirmed.
- **Owner selection:** *Diagnose in-phase from artifacts* — treat it as a first-class work item, pull
  the `generated-admin-failure-diagnostics` artifact from run `30425416933`, confirm or kill the
  webfont-metrics hypothesis, fix properly. GATE-02 does not enable until green.
- **Rejected:** time-box then quarantine the assertion; fix as a standalone pre-phase task.
- **Recorded as:** D-09.

**No presented assumption was overturned.** The corrections above resolved open routing questions
the analyzer deliberately escalated rather than defaulted.

## Corrections to the Written Record

Two prior artifacts are contradicted by this phase's live evidence, and the correction is recorded
in CONTEXT rather than left to diverge silently:

1. **`230-VERIFICATION.md:174`** classified the `admin-generated.spec.ts:176` failure as "transient".
   Measured: **~38%, sticky within a run** (fails on the retry). Corrected by D-08.
2. **`.planning/todos/pending/2026-07-27-playwright-github-pages-publisher-red.md`** hypothesised
   "real spec drift" and floated `continue-on-error` as a remedy. Actual cause is a **missing
   `Run demo seeds` step** in the publisher's boot prelude; the floated remedy is both unnecessary
   and forbidden by 230's D-15. Corrected by D-17.

## New Finding (no prior artifact covers it)

`pages-build-deployment` has failed on six consecutive pushes because GitHub Pages is building
`main`'s repo root as a Jekyll site rather than the `gh-pages` branch the publisher targets.
`scripts/ci/ensure-github-pages-legacy-branch.sh` would correct the source but only executes after a
successful publish — and the publisher has been red daily, so it has never executed. Chicken-and-egg.
Scoped by D-18.

## Methodology Lenses Applied

- **Decisive Defaulting** — applied to GATE-03's mechanism (consume the manifest; no new
  enumeration), GATE-04's fix shape (install WebKit rather than delete the mobile project), the
  DX-05 ceiling value (120 attempts), and the label fix (self-heal over soft-fail `gh issue edit`).
  None touch security posture, public contract, or generated-host output, so no option menu was
  warranted.
- **Escalation Threshold** — three items escalated (above). Notably kept *below* the line: GATE-02's
  PR cost, which the runtime numbers settle decisively (~4m under a 989s pole) rather than needing a
  judgment call.
- **Research Depth Calibration** — ROADMAP, REQUIREMENTS, METHODOLOGY, 230-CONTEXT/VERIFICATION, all
  five `resolves_phase: 231` todos, the SEED-005 addendum and the v1.42 findings read before any
  assumption was formed; then 24 live `gh` observations across 20 run IDs.
- **Discuss-Phase Default** — recommendation-first throughout; one winner per area, with a runner-up
  recorded only where the rejected path was live (literal `!= 'pull_request'` for GATE-02;
  drop-the-mobile-project for GATE-04; inline re-derivation for GATE-03).
- **Prompt And Prior-Art Weighting** — Phase 230 left explicit forward instructions in three places
  (the `ci-skip-manifest.tsv` header, `ci-observe.yml:16-23` and `:130-136`, `MAINTAINING.md:255-262`).
  Where they align with the requirement text they were treated as sufficient authority to decide
  rather than reopened.

## Needs External Research

Carried into `231-RESEARCH.md` scope:

- **The 320px flake root cause.** The webfont-metrics hypothesis is a hypothesis, not a codebase
  fact. Diagnosis needs the `generated-admin-failure-diagnostics` artifact (`test-failed-1.png`) from
  run `30425416933`, and possibly Playwright's font-loading semantics.
- **GitHub Pages source-of-truth semantics.** Whether `pages-build-deployment` self-heals once
  `ensure-github-pages-legacy-branch.sh` runs, or whether the source must change via repo Settings /
  `PUT /repos/{owner}/{repo}/pages`. Needs the Pages API docs plus `gh api repos/szTheory/sigra/pages`.
- **`gh label create` token scope.** Whether `issues: write` suffices for label creation with
  `GITHUB_TOKEN`, or whether `metadata`/`administration` is required — confirm before relying on
  D-22's self-heal path.

## Human-Gated Steps

- **`release-lane-rot` label — already done.** Created manually by Jon on 2026-07-28
  (`gh label create release-lane-rot --color b60205`). No further manual action *provided* D-22's
  self-heal lands; without it the manual step silently becomes load-bearing again on any fork or
  accidental deletion.
- **GitHub Pages source configuration** — potentially a repo-admin action. Bounded by D-18: if the
  `GITHUB_TOKEN` path is blocked, this is filed rather than performed.
- **Ruleset 14941512** — untouched by this phase, by decision. Both SEED-005 P1-2 and the
  `example_unit_smoke` gap are deferred.
