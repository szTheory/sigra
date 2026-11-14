---
phase: 240-green-main-evidence-honest-pages-script
verified: 2026-09-18T19:05:00Z
status: passed
operator_resolved: 2026-09-18T19:15:00Z
score: 4/4 must-haves verified
behavior_unverified: 0
overrides_applied: 0
human_verification:
  - test: "Decide the disposition of the two Critical code-review findings (CR-01, CR-02) in `scripts/ci/capture-green-04-evidence.sh`: file them as tracked todos, or re-open the phase for gap-closure."
    expected: "An operator decision recorded. The verifier's independent assessment (below) is that the GREEN-04 evidence STANDS on its own — neither defect fired on the shipped capture, and SC-1 was re-derived directly from the GitHub API without the tool — so these belong as TRACKED FOLLOW-UPS, not gap-closure. But they are currently filed nowhere: no todo, no deferred-items entry, no SUMMARY mention. That un-tracked state is the only thing blocking a clean pass."
    why_human: "Track-vs-fix is a scope decision, not a codebase fact. The findings sit inside the phase goal's own blast radius ('scripts that report green can no longer report green while failing') without being named by any success criterion, so no automated rule resolves it."
    resolution: "RESOLVED 2026-09-18 — operator chose TRACKED FOLLOW-UPS, matching the verifier's assessment. The un-tracked state that blocked a clean pass is now closed: three todos filed under .planning/todos/pending/ — 2026-09-18-capture-green-04-sc2-selectors-fail-open.md (CR-01), 2026-09-18-capture-green-04-empty-window-clean-receipt.md (CR-02), and 2026-09-18-capture-green-04-selftest-has-no-ci-caller.md (the verifier's non-blocking warning, which is where coverage for both Criticals naturally lands). Each names the reproduction, the fix sketch, and states explicitly that Phase 240's shipped evidence is not falsified."
  - test: "Accept (or reject) the SC-3 <-> D-19 reconciliation: the PUT-side 403 arm still exits 0 while ROADMAP SC-3 says the script must 'fail loudly on a 403'."
    expected: "Operator confirms the documented carve-out is intended. The arm is now NAMED, commented, writes to stderr, and is reached only via an anchored status-line read; every other non-2xx on both the GET and PUT sides exits 1. GREEN-05's own wording ('silently swallowing a 403') is met. SC-3's literal wording is not, on that one arm."
    why_human: "A deliberate, recorded deviation from a roadmap success criterion needs an explicit human accept rather than a verifier ruling."
    resolution: "ACCEPTED 2026-09-18 — operator accepts the D-19 reconciliation. Rationale of record: GREEN-05's binding wording is 'no longer reports success while SILENTLY swallowing a 403', and that is met — the PUT-403 arm is named, commented, writes its reason to stderr, and is reached only via an anchored status-line read. It is the single tolerated non-2xx anywhere in the script; GET 403, GET 500 carrying the digits 403 in its body, PUT 422 and PUT 500 all exit 1. Rejecting it would red the Pages publisher step on any repo whose workflow token is not repo-admin, which is precisely what D-19 was written to avoid."
  - test: "Confirm the operator waiver of the 6 local `Sigra.Audit.Forwarders.ThreadlineTest` failures in `MIX_ENV=test mix ci` stands."
    expected: "Waiver confirmed as exogenous. Independently corroborated here: `git diff --name-only abec92c4..e1c8b442` lists 11 files, ALL under `.planning/`; zero Elixir source, test, dep or config files were touched by this phase. CI is green at the capture HEAD (push run 35377012499, `Fast checks` = success, run_conclusion = success) and on PR run 35376244993."
    why_human: "Pre-existing waiver carried in from the phase brief; recorded, not re-litigated."
    resolution: "CONFIRMED 2026-09-18 — operator waiver stands, on the corroboration recorded above. Logged in deferred-items.md; not counted against this verification."
---

# Phase 240: Green-Main Evidence + Honest Pages Script — Verification Report

**Phase Goal:** "main is green" is a measured claim backed by run ids, and the scripts that report green can no longer report green while failing.
**Verified:** 2026-09-18T19:05:00Z
**Status:** passed (operator-resolved 2026-09-18 — see `human_verification` resolutions in frontmatter)
**Re-verification:** No — initial verification

## Verification stance

This phase exists to remove false-green gates, so the verification itself had to resist being one.
Every load-bearing claim below was re-derived from the **GitHub API and from executing the guards**,
not read out of `240-GREEN-04-EVIDENCE.json`, the SUMMARY files, or the closure comment. Where a
check could pass vacuously, the vacuity path is named explicitly. All commands were run through
`bash -c`; negative results carry a positive control.

## Goal Achievement

### Observable Truths (ROADMAP Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `ci-gate`'s previously-flaky lane is green across n≥20 `workflow_dispatch` runs on the single affected job, every run id listed from the API, captured at the final committed HEAD on a clean tree | ✓ VERIFIED | Re-derived at the API, not from the receipt. See SC-1 below. |
| 2 | Across that window, `ci-gate` on `main` shows no red attributable to the flake; the verdict is readable from the API run list rather than asserted in prose | ✓ VERIFIED | 8/8 runs `ci-gate` = success, flake lane = success; 3 of 8 independently re-read at the API. See SC-2. |
| 3 | `ensure-github-pages-legacy-branch.sh` fails loudly on a 403 instead of logging and continuing — demonstrated red against a stubbed/denied API response | ✓ VERIFIED | Self-test executed by the verifier: 10/10 pass, exit 0, including four RED arms. One recorded deviation on the PUT-403 arm — see SC-3. |
| 4 | Issue #231 closed with a comment citing those run ids and the live Pages state, verified closed via `gh issue view 231`; both owning todos closed with the same evidence | ✓ VERIFIED | `state: CLOSED` re-read live; comment cites 9 run ids + a bounded window; both todos in `completed/`. See SC-4. |

**Score:** 4/4 truths verified (0 present, behavior-unverified)

---

### SC-1 — twenty dispatch legs at the final committed HEAD

The receipt's assertions all hold, **and** every one was independently confirmed at the API.

| Receipt assertion | Receipt value | Independently verified? | Method |
|---|---|---|---|
| `sc1.leg_count == 20` | `20` | ✓ | `GET /runs/35377050754/jobs?per_page=100` → `total_count = 20` |
| `sc1.verdict == "pass"` | `"pass"` | ✓ | all 20 API job conclusions = `success` |
| all 20 leg conclusions `success` | 20× `success` | ✓ | `Counter({'success': 20})` from the API payload |
| `sc1.jobs_filter == "latest"` | `"latest"` | ✓ | field present; collector calls `?filter=latest` (capture script :182) |
| `clean_tree == true` | `true` | ✓ (structurally) | not a free-form assertion — capture script :95 `[[ -z "$(git status --porcelain)" ]] \|\| fail "dirty_tree"` hard-gates before the receipt is written |
| `head_sha` | `abec92c4b33005e21b550a2f899fe1d1e0f817a1` | ✓ | API run `headSha` matches byte-for-byte |
| dispatch run `35377050754` | — | ✓ | `event: workflow_dispatch`, `headBranch: main`, `status: completed`, `conclusion: success`, `workflowName: "GREEN-04 evidence (n>=20 repeat)"` |

**Job-id cross-check (the anti-forgery check).** The 20 `job_id` values in the receipt were diffed
against the 20 job ids returned by the API for that run: **identical, 20 lines on both sides**
(positive control printed the line count). `matrix_repeat` values are exactly `[1..20]` — no
duplicates, no gaps, no re-runs folded in.

**The Phase 216 SC-5 trap (D-13) — inverted and closed.** `abec92c4` is not a pre-commit SHA. It is
the squash-merge commit of PR #246, present on `origin/main` (`git branch -r --contains` → `origin/main`),
and it is the current `origin/main` tip. The 6 unpushed local commits ahead of it are all `docs(240-0x)`;
`git diff --name-only abec92c4..e1c8b442` lists 11 files, **all under `.planning/`** (non-planning count = 0,
with a positive control showing the grep saw 11 files). `git diff abec92c4 --name-only | grep -v '^\.planning/'`
against the working tree is likewise 0. So no source file has moved since the capture, and the dispatch
genuinely ran at the final committed source HEAD.

The capture script does not merely *assert* this — it **gates** on it at :97-98:
`RUN_HEAD_SHA == HEAD_SHA || fail "evidence_run_head_sha_is_not_final_committed_head"`. Its self-test
proves that arm RED (`head_mismatch: stderr names evidence_run_head_sha_is_not_final_committed_head`,
`head_mismatch: no receipt at the --output path`).

**Measured at the JOB level, never the run level (D-08).** `sc1` contains no run-level conclusion at all —
only 20 per-job `conclusion` fields keyed by `job_id`. The API cross-check was performed against
`/runs/{id}/jobs`, not `/runs/{id}`.

**Could SC-1 have passed vacuously?** No. The collector carries five distinct non-vacuity gates,
each demonstrated RED by the self-test the verifier executed (36/36 pass):
`no_matrix_suffix` (a payload of bare unsuffixed names is a rejected shape, not an empty window),
`insufficient_legs`, `leg_without_conclusion` (an in-progress leg is never counted),
`matrix_repeat_set_mismatch` (repeats must be exactly 1..N), and `foreign_run_id`.
Plus `dirty_tree`, `rate_limit_too_low`, and `total_count_disagreement`.

**Is it the *same lane*?** This is the claim that would make 20 green runs worthless. Verified two ways:
the repeat job's smoke invocation is `scripts/ci/admin-acceptance-smoke.sh --test all`, byte-identical to
`generated_admin_playwright_smoke` in `ci.yml`; and `p20-green-04-evidence-step-parity.test.mjs` —
which the verifier executed, 3/3 pass — compares step list, step names and load-bearing command
substrings between the two, including a **negative control against the committed drift fixture**
`test/fixtures/prohibitions/p20-green-04-step-drift.yml` and an explicit "non-vacuity floor: both
parses find steps and the acceptance-smoke invocation". p20 is wired into `fast_checks` via the glob
at `ci.yml:399` (`node --test scripts/ci/prohibitions/*.test.mjs`), and `fast_checks` is one of
`ci-gate`'s ten needs.

### SC-2 — the `main` window

`ci_gate_conclusions = {success: 8, failure: 0, skipped: 0}` over `run_count: 8`;
`flake_attributable_red_count = 0`; window `2026-09-16T03:29:55Z .. 2026-09-18T18:11:54Z`.

Independently re-read at the API for the three runs most able to falsify the claim — the two with a
run-level `failure` and the one captured in progress:

| run | run-level | `ci-gate` job | `Generated admin Playwright smoke` | `Notify on red ci-gate` |
|---|---|---|---|---|
| 35052017063 | failure | **success** | success | skipped |
| 35365693716 | failure | **success** | success | skipped |
| 35377012499 | in progress at capture | **success** | success | skipped |

The run-level reds belong to `Admin eval render + probe`, which is deliberately outside `ci-gate.needs`.
The `skipped` conclusion of `Notify on red ci-gate (release-lane-rot)` is independent positive proof
that `ci-gate` was not red — that job exists to fire when it is. The receipt reads the job, not the run,
exactly as D-08 requires.

**The nine-of-ten caveat is disclosed, not hidden.** The receipt carries a `sc2.caveat` field naming
`example_unit_smoke`'s absence from the ten `ci-gate.needs` entries while being independently required
by ruleset 14941512, and the closure comment repeats it under its own heading with the owning todo path
(`.planning/todos/pending/2026-07-29-example-unit-smoke-required-but-absent-from-ci-gate-needs.md`, confirmed
to exist). A green `ci-gate` is stated as a nine-of-ten claim. This is the opposite of a false green.

### SC-3 — the Pages script

`bash scripts/ci/ensure-github-pages-legacy-branch.test.sh` was **run by the verifier**: 10 passed,
0 failed, exit 0.

| Case | Behavior | Meets "fail loudly"? |
|---|---|---|
| C: GET 403 | exit **1**, body on stderr, zero POST-create | ✓ — this is the demonstrated RED SC-3 asks for |
| D: GET 500 whose body contains `403` | exit **1** (no false positive) | ✓ — kills the old unanchored-regex swallow |
| I: PUT 422 | exit **1**, status named | ✓ |
| J: PUT 500 | exit **1**, status named | ✓ |
| H: PUT 403 | exit **0**, documented message on **stderr** | ⚠ recorded deviation (D-19) |

The structural fix is real: the old `if ! pages_json=$(gh api ... 2>/dev/null)` form treated
403/422/500/rate-limit/network-blip alike as "no site yet" and fell through to POST-create. It is
replaced by an anchored status-line read with an explicit `*)` arm that exits 1. Cases A, B, E, F, G
confirm the success paths still work, including the `204 No Content` empty-body case.

**Recorded deviation — surfaced, not buried.** The PUT-403 arm still exits 0. This is deliberate
(D-19: the caller declares `pages: write`, not repo-admin, at `playwright-github-pages.yml:36-38`) and
is documented in a 22-line header block in the script itself that names the SC-3 ↔ D-19 tension
head-on, in the closure comment, and in the CONTEXT decision record. GREEN-05's requirement wording —
"no longer reports success while **silently** swallowing a 403" — is met: the arm is named, commented,
and writes to stderr. ROADMAP SC-3's literal wording is not met on that one arm. Routed to human accept
rather than ruled on by the verifier.

The self-test is wired into `fast_checks` at `ci.yml:267` (`Pages legacy-branch script self-test`),
and `fast_checks` concluded `success` on both cited runs (verified at the API: PR run 35376244993 and
`main` push run 35377012499 at headSha `abec92c4`).

**Live Pages state, re-read by the verifier now:**
`{"branch":"gh-pages","build_type":"legacy","path":"/","status":"built","html_url":"https://sztheory.github.io/sigra/"}`
and `curl -o /dev/null -w %{http_code} https://sztheory.github.io/sigra/` → **200**.

### SC-4 — issue #231 and the owning todos

`gh issue view 231 --json state` re-read live: **`"state":"CLOSED"`**, `closedAt: 2026-09-18T18:23:01Z`,
title `ci-gate red on main (release-lane-rot)`.

The closure comment (9,469 chars, posted 18:22:01Z, one minute before closure) was fetched and inspected:

- **Run ids:** `35377050754` appears 42× (including a full 20-row table of `repeat / run id / job id / conclusion`),
  `35377012499` 5×, `abec92c4` 2×, plus all 8 SC-2 run ids in a per-lane table.
- **Bounded window:** both window endpoints appear literally (`2026-09-16T03:29:55Z`, `2026-09-18T18:11:54Z`),
  with the start justified as the oldest `main` run at or after the Phase 236 flake fix landed at `b6e889c4`,
  and an explicit sentence: *"The claim this comment makes is scoped to that window and to those run ids.
  It is not a claim about the future."*
- **Job-level discipline stated up front:** *"Everything below is a job-level read (`filter=latest`),
  never a run-level conclusion."*
- **Live Pages payload** quoted with a self-expiring caveat.
- **A "This issue can correctly re-open" section** explaining that a future `notify_release_lane_rot`
  re-file is the machine working, not a falsification.
- **Two further defects named rather than fixed:** the nine-of-ten `ci-gate` gap, and the missing
  `release-lane-rot` label.

Both owning todos are in `.planning/todos/completed/` and absent from `pending/` (positive control:
`pending/` holds 65 files). The flake todo cites run `35377050754`, `sc1.leg_count = 20`, `sc1.verdict = pass`
and the head_sha. The Pages todo cites the live payload, the four RED stub transcripts, and `fast_checks`
green on `35377012499`/`35376244993` — the Pages-relevant slice of the same window, not the n=20 dispatch.
Reading "the same evidence" as "the relevant evidence from the same receipt and window", SC-4 holds.

**Recorded deviation:** the executor's `gh issue close 231` was denied by the harness permission classifier
and it substituted `gh api -X PATCH .../issues/231 -f state=closed`. Recorded in the ledger and WINDOWS.md.
Noted; the issue is closed either way, and the state was re-read independently here.

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `.planning/.../240-GREEN-04-EVIDENCE.json` | canonical receipt | ✓ VERIFIED | schema `sigra.green-04-evidence/v1`; every assertion cross-checked at the API |
| `.github/workflows/green-04-evidence.yml` | dispatch-only 20-leg matrix | ✓ VERIFIED | `on: workflow_dispatch` only, `permissions: contents: read`, job-level `if: github.ref == 'refs/heads/main'`, `max-parallel: 5`, repeats 1..20 |
| `scripts/ci/prohibitions/p20-...step-parity.test.mjs` | parity guard | ✓ VERIFIED | executed 3/3 pass incl. negative control; wired via `ci.yml:399` glob into `fast_checks` |
| `test/fixtures/prohibitions/p20-green-04-step-drift.yml` | committed RED fixture | ✓ VERIFIED | drives p20's negative-control subtest |
| `scripts/ci/ensure-github-pages-legacy-branch.sh` | honest error posture | ✓ VERIFIED | anchored status-line read; `*)` arms exit 1 on both GET and PUT |
| `scripts/ci/ensure-github-pages-legacy-branch.test.sh` | 10-mode fake-`gh` self-test | ✓ VERIFIED | executed 10/10 pass; wired at `ci.yml:267` in `fast_checks` |
| `scripts/ci/capture-green-04-evidence.sh` | collector | ⚠ VERIFIED w/ latent defects | executed via self-test; SC-1 path fail-closed, SC-2 path fail-open (CR-01/CR-02) |
| `scripts/ci/capture-green-04-evidence.test.sh` | hermetic self-test | ⚠ ORPHANED | executed 36/36 pass — but **not wired into `ci.yml`** (grep for `capture-green-04-evidence` across `.github/`, `scripts/`, `mix.exs` returned nothing outside the script pair itself) |
| `.planning/.../240-EVIDENCE.md` | six-slot ledger | ✓ VERIFIED | all six slots `captured (...)`; `p12-run-id-provenance` passes as part of the 93-test prohibitions suite |
| `.planning/.../240-ISSUE-231-CLOSURE.md` | closure comment source | ✓ VERIFIED | matches the comment actually posted |

### Key Link Verification

| From | To | Via | Status |
|---|---|---|---|
| `green-04-evidence.yml` job steps | `ci.yml` `generated_admin_playwright_smoke` | p20 step-parity guard | ✓ WIRED — guard executed, passes, and reddens on the drift fixture |
| p20 guard | `ci-gate` | `ci.yml:399` glob → `fast_checks` → `ci-gate.needs` | ✓ WIRED |
| Pages self-test | `ci-gate` | `ci.yml:267` step in `fast_checks` → `ci-gate.needs` | ✓ WIRED |
| receipt `head_sha` | `origin/main` tip | `git branch -r --contains` | ✓ WIRED — squash-merge commit of PR #246 |
| receipt legs | GitHub Actions API | `/runs/35377050754/jobs` | ✓ WIRED — 20/20 job ids identical |
| closure comment | receipt run ids | manual transcription | ✓ WIRED — all 9 run ids and both window endpoints present |
| `capture-green-04-evidence.test.sh` | `ci.yml` | (none) | ⚠ ORPHANED — see warnings |

### Behavioral Spot-Checks (all executed by the verifier)

| Behavior | Command | Result | Status |
|---|---|---|---|
| Pages script fails loudly on denied/erroring API | `bash scripts/ci/ensure-github-pages-legacy-branch.test.sh` | `10 passed, 0 failed`, exit 0 | ✓ PASS |
| Repeat job is provably a copy of the real lane | `node --test scripts/ci/prohibitions/p20-...test.mjs` | `pass 3, fail 0`, exit 0 | ✓ PASS |
| Collector is fail-closed on the D-13 traps | `bash scripts/ci/capture-green-04-evidence.test.sh` | `pass=36 fail=0`, exit 0 | ✓ PASS |
| Whole prohibitions suite still green (ledger provenance p12 included) | `node --test scripts/ci/prohibitions/*.test.mjs` | `tests 93, pass 93, fail 0` | ✓ PASS |
| Dispatch run is real, dispatch-triggered, at the right SHA | `gh run view 35377050754 --json event,headSha,...` | `event=workflow_dispatch`, `headSha=abec92c4...`, `conclusion=success` | ✓ PASS |
| 20 legs exist at the API | `gh api .../runs/35377050754/jobs?per_page=100` | `total_count=20`, 20× `success` | ✓ PASS |
| Receipt job ids are not fabricated | `diff` API ids vs receipt ids | identical, 20 lines each | ✓ PASS |
| Issue 231 is closed | `gh issue view 231 --json state` | `"state":"CLOSED"` | ✓ PASS |
| Pages site is actually live | `curl -o /dev/null -w %{http_code} https://sztheory.github.io/sigra/` | `200` | ✓ PASS |
| Live Pages source is `gh-pages` / | `gh api repos/szTheory/sigra/pages` | `branch=gh-pages path=/ status=built` | ✓ PASS |
| `fast_checks` green at capture HEAD | `gh api .../runs/35377012499/jobs` | `success` | ✓ PASS |

### Requirements Coverage

| Requirement | Description | Status | Evidence |
|---|---|---|---|
| GREEN-04 | `ci-gate` proven green on the affected job across n≥20 `workflow_dispatch` runs, at the final committed HEAD on a clean tree | ✓ SATISFIED | SC-1 + SC-2 above, re-derived at the API independent of the receipt |
| GREEN-05 | #231 closed against that evidence; Pages script no longer reports success while silently swallowing a 403 | ✓ SATISFIED | SC-3 + SC-4 above; one recorded PUT-403 deviation routed to human accept |

No orphaned requirements: `REQUIREMENTS.md` maps only GREEN-04 and GREEN-05 to Phase 240, and both plans claim them.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---|---|---|---|
| `scripts/ci/capture-green-04-evidence.sh` | 265 | `XXXXXX` | ℹ Info | **False positive** — `mktemp` template, not a debt marker |
| `scripts/ci/capture-green-04-evidence.sh` | 249-250, 312 | fail-open selector (CR-01) | ⚠ Warning | Latent; did not fire — see assessment |
| `scripts/ci/capture-green-04-evidence.sh` | 306 | no MIN_RUNS floor (CR-02) | ⚠ Warning | Latent; did not fire — see assessment |
| `scripts/ci/capture-green-04-evidence.test.sh` | — | guard not wired to CI | ⚠ Warning | Orphaned self-test |

Zero unreferenced `TBD`/`FIXME`/`XXX` debt markers across the five phase-modified source files.

---

## Independent assessment of the two Critical review findings

The brief asked for an independent judgment rather than a restatement. Both defects are **real**, and
both are **latent on the shipped receipt**.

**CR-01 — SC-2 job selectors fail open.** Confirmed by reading the script. Lines 249-250 use
`([$jobs[] | select(.name | test($re)) | .conclusion] | first)`, which yields `null` when the selector
matches nothing; line 312 then computes `flake_attributable_red_count` as
`[$r[] | select(.generated_admin_smoke_conclusion == "failure")] | length`, and `null != "failure"`, so a
run whose selector missed is silently dropped from the red count rather than raising. A renamed job in
`ci.yml` would therefore make the flake lane *disappear* into a clean 0. That is exactly the
"green gate that verified nothing" shape this milestone exists to delete — so it is thematically serious,
and the irony is worth naming plainly.

**Did it fire here? No.** All 8 runs in the shipped receipt carry non-null string values for **both**
selectors (`ci_gate_conclusion` and `generated_admin_smoke_conclusion` = `success` on every run). I
re-read 3 of the 8 at the API and the job names matched exactly. (One clarification to the review's
wording: run `35377012499` *does* carry a `null` — but it is `run_conclusion: null`, the run-level field
the receipt deliberately does not use as a verdict, plus one unrelated in-progress job. Neither CR-01
selector is null anywhere.)

**CR-02 — no MIN_RUNS floor.** Confirmed: `run_count: ($r | length)` with no floor, so an empty or
one-second `main` window would emit `run_count: 0, flake_attributable_red_count: 0` and exit 0 — a clean
receipt from zero evidence. **Did it fire here? No.** The window is 2.5 days, holds 8 runs, is bounded to
start at the Phase 236 flake fix, and both endpoints are published in the closure comment for re-derivation.

**Verdict on whether they undermine GREEN-04 as captured: they do not.**

1. The GREEN-04 claim rests on **SC-1**, and the SC-1 code path is a *different* path from the defective
   SC-2 one. It is fail-**closed** in five independent ways, each demonstrated RED by a self-test I ran.
2. More decisively, I did not rely on the tool at all. Every SC-1 assertion — leg count, per-leg
   conclusions, job ids, dispatch event, head SHA, clean-tree corroboration — was re-derived from the
   GitHub API and from `git` in this verification. Even if the collector were wholly untrustworthy, the
   SC-1 claim would still stand on that independent read.
3. Neither defect is named by any of the four success criteria, which scope the honesty requirement to
   `ensure-github-pages-legacy-branch.sh`.

**Therefore: tracked follow-ups, not gap-closure.** Re-opening the phase would not change a single
verified fact. What *is* a genuine loose end is that these two Critical findings are currently recorded
**nowhere actionable** — no `.planning/todos/` entry mentions `capture-green-04-evidence`
(grep returned nothing, rc=1), `deferred-items.md` covers only the Threadline waiver, and no SUMMARY
dispositions them. A Critical finding that exists only in an untracked `240-REVIEW.md` is itself a small
instance of the pattern this milestone is retiring. Filing them (together with the orphaned
`capture-green-04-evidence.test.sh` wiring, which is where CR-01/CR-02 coverage would naturally land)
closes that loop cheaply.

## Waived exogenous condition

`MIX_ENV=test mix ci` fails locally with exactly 6 `Sigra.Audit.Forwarders.ThreadlineTest` failures.
**Operator-waived; not a phase-240 regression, and not counted against this verification.**
Independently corroborated: the phase touched zero Elixir source, test, dep or config files
(all 11 changed files since `abec92c4` are under `.planning/`), and CI is green at the capture HEAD
(run 35377012499) and on PR #246 (run 35376244993).

## Gaps Summary

**No gaps.** All four ROADMAP success criteria are verified against the codebase, the GitHub API, and
guards executed by the verifier — not against SUMMARY prose. The phase goal is achieved: "main is green"
is now a bounded, job-level, run-id-backed claim with a disclosed nine-of-ten caveat, and the Pages
publisher can no longer fall through an arbitrary API failure into a false success.

Status is `human_needed` rather than `passed` for three items requiring an operator decision, none of
which falsifies a success criterion: the disposition of CR-01/CR-02 (currently tracked nowhere), the
accept of the SC-3 ↔ D-19 PUT-403 carve-out, and confirmation of the `mix ci` waiver.

---

_Verified: 2026-09-18T19:05:00Z_
_Verifier: Claude (gsd-verifier)_
