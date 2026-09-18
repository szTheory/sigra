# Phase 240 Evidence Ledger

<!--
GRAMMAR TRAP — DO NOT REINTRODUCE THE BARE `captured` FORM.

`236-EVIDENCE.md`'s `## AFTER-P17-GUARD-OBSERVED` slot uses a bare `Status: captured` with no
parenthetical. That form FAILS p12's status regex
(`p12-run-id-provenance.test.mjs:44`: /^(captured \((run|runs) [\s\S]+\)|pending \(.+\))$/).
It survives today only because p12 is hardcoded to the Phase 230 ledger
(`p12-run-id-provenance.test.mjs:26`) and never reads the 236 one.

The ONLY legal forms in this ledger are:
  Status: pending (<reason> obligation)      <- the literal word `obligation` is required
  Status: captured (run <id>)
  Status: captured (runs <id>, <id>, ...)

Every captured slot additionally needs at least one fenced block naming the producing command,
and every run id cited in a `Status:` line must appear AGAIN in the slot body (p12's
corroboration rule counts the Status occurrence itself, so one more is required).

Generalising p12 from the Phase 230 hardcode to a ledger glob is Phase 241's call, not this
phase's. Until then this ledger is checked by running p12 with GSD_PROHIB_SUBJECT redirected at
it — see each slot's fenced block.
-->

**Status of this file as written (plan 240-04):** five of six slots are `captured`;
`## AFTER-ISSUE-231-CLOSED` remains `pending` and is owned by plan 240-05.

**This flip is a POST-EVIDENCE DOCUMENTATION COMMIT (D-13).** The receipt
`240-GREEN-04-EVIDENCE.json` recorded `head_sha`
(`abec92c4b33005e21b550a2f899fe1d1e0f817a1`) and `clean_tree: true` **at capture time**, on a
clean working tree, at the final committed HEAD of this phase's code. The commit that flips the
slots below lands *after* that capture and moves HEAD; that movement does **not** invalidate the
window, because the receipt is self-dating — the SHA the claim is about is inside the claim. The
commit that carries this ledger is documentation only: no source, workflow, script or test file
changes in it, so nothing it touches is a subject of any claim made here (RESEARCH §7, option ii).
This is the Phase 216 SC-5 trap inverted: there, a harness was green at a *pre-commit* SHA; here,
the capture is strictly *after* the last code commit.

## Two claims stated in writing up front

**(a) D-09 — `main`'s run-level red is a misattribution.** `ci.yml`'s **run-level** conclusion on
`main` is `failure` on some runs for a reason that lies **outside** `ci-gate`. On run
`35365693716` (HEAD `bca3ad72`) the only non-success job was `Admin eval render + probe`, which
`ci.yml:2089-2110` documents in prose as deliberately **not** in `ci-gate.needs` (it is the
expensive render-evidence lane, demoted to push/schedule/dispatch by Phase 230 FAST-03). On that
same run `Notify on red ci-gate` was `skipped`, which per `ci.yml:1645-1655` positively proves
`ci-gate` itself was **not** red — that job exists precisely to fire when `ci-gate` reds on `main`.
A naive `gh run list --branch main` reports red and invites the reader to attribute it to the
generated admin Playwright flake. It is not that. This is the Phase 238 lesson inverted: read the
**job**, not the run (D-08), and `scripts/ci/capture-green-04-evidence.sh` is built so the verdict
can only ever be computed from job conclusions.

**(b) D-10 — a green `ci-gate` is a nine-of-ten claim, and this phase discloses that.**
`ci.yml:1547-1557` lists exactly ten `ci-gate.needs` entries: `changes`,
`install_golden_contract`, `library_tests`, `library_tests_dep_off`, `install_smoke`,
`upgrade_smoke`, `example_http_smoke`, `example_playwright_smoke`,
`generated_admin_playwright_smoke`, `fast_checks`. **`example_unit_smoke` is absent from that
list** while being independently required by ruleset 14941512. So `ci-gate: success` does not mean
"every required context passed" — it means nine of the ten required contexts passed and the tenth
was never aggregated into the gate. Every SC-2 verdict in this ledger, and the `sc2.caveat` string
emitted into every receipt, carries that caveat verbatim. This phase **discloses** the gap; it does
not fix it. The fix is owned by
`.planning/todos/pending/2026-07-29-example-unit-smoke-required-but-absent-from-ci-gate-needs.md`.

## Slots

| Slot | What it is | How it was captured | Status |
|------|-----------|-------------------------|--------|
| [BEFORE-MAIN-RED-MISATTRIBUTION](#before-main-red-misattribution) | The pre-state: `main`'s run-level `failure` attributable to `admin_eval_render`, not to `ci-gate` or the generated-admin flake | `gh run view` on the `main` run plus `gh api .../jobs` read at the job level | captured |
| [AFTER-PAGES-LOUD-RED](#after-pages-loud-red) | The rewritten Pages script failing loudly instead of swallowing an error (plan 240-01) | the plan 240-01 Pages self-test, run offline against its stub and wired into `fast_checks` on `main` | captured |
| [AFTER-P20-GUARD-OBSERVED](#after-p20-guard-observed) | `p20` observed RED against its committed known-bad fixture and GREEN against the real pair (standing constraint 6) | `GSD_PROHIB_SUBJECT=<fixture> node --test` then the same command without the override | captured |
| [AFTER-GREEN-04-N20](#after-green-04-n20) | SC-1: twenty dispatch legs, every one concluded `success`, read at the job level | `gh workflow run green-04-evidence.yml` then `scripts/ci/capture-green-04-evidence.sh` | captured |
| [AFTER-CI-GATE-MAIN-WINDOW](#after-ci-gate-main-window) | SC-2: the `main` `ci.yml` window with per-lane job conclusions and the nine-of-ten caveat | the `sc2` half of the same receipt | captured |
| [AFTER-ISSUE-231-CLOSED](#after-issue-231-closed) | Issue #231 closed with a comment naming the run ids and the evidence window, proven by re-reading state | `gh issue close 231` then `gh issue view 231 --json state` | pending |

---

## BEFORE-MAIN-RED-MISATTRIBUTION

Status: captured (run 35365693716)

The claim evidenced: on `main` run `35365693716` (HEAD `bca3ad72`, event `push`,
created `2026-09-18T15:58:53Z`) the **run-level** conclusion is `failure`, the **only**
non-success job is `Admin eval render + probe (hard signal on push/schedule/dispatch; not in
ci-gate)`, the `ci-gate` job itself concluded `success`, and `Notify on red ci-gate
(release-lane-rot)` was `skipped` — which per `ci.yml:1645-1655` is itself positive proof that
`ci-gate` was not red. Re-read live at capture time (2026-09-18), and it still reads that way.

| Job (run 35365693716) | Conclusion |
|---|---|
| `ci-gate` | `success` |
| `Generated admin Playwright smoke` | `success` |
| `Admin eval render + probe (… not in ci-gate)` | `failure` |
| `Notify on red ci-gate (release-lane-rot)` | `skipped` |
| every other job | `success` |

```bash
gh api repos/szTheory/sigra/actions/runs/35365693716 \
  --jq '{id, conclusion, head_sha, head_branch, event, created_at}'
# => {"conclusion":"failure","created_at":"2026-09-18T15:58:53Z","event":"push",
#     "head_sha":"bca3ad72ccfabd0e4b5fd109cc631832f6f446e7","id":35365693716}

gh api "repos/szTheory/sigra/actions/runs/35365693716/jobs?filter=latest&per_page=100" \
  --jq '.jobs[] | select(.conclusion != "success") | {name, conclusion}'
# => {"conclusion":"failure","name":"Admin eval render + probe (hard signal on
#     push/schedule/dispatch; not in ci-gate)"}
# => {"conclusion":"skipped","name":"Notify on red ci-gate (release-lane-rot)"}
```

The same shape recurs at run `35052017063` (HEAD `b6e889c4`): run-level `failure`, sole
non-success job `Admin eval render + probe`, `Notify on red ci-gate` `skipped`. Two independent
instances of the misattribution, neither of them a `ci-gate` red and neither of them the
generated-admin flake.

## AFTER-PAGES-LOUD-RED

Status: captured (runs 35377012499, 35376244993)

The claim evidenced: the rewritten `scripts/ci/ensure-github-pages-legacy-branch.sh` (plan 240-01)
exits non-zero and names its reason on a non-404 error from `GET /repos/{repo}/pages`, rather than
falling through to the create arm. Its hermetic self-test
(`scripts/ci/ensure-github-pages-legacy-branch.test.sh`) is wired into `fast_checks` as the step
**`Pages legacy-branch script self-test`**, which ran green on PR run `35376244993` and again on
the `main` push run `35377012499` at HEAD `abec92c4`.

Four SC-3 RED transcripts, each captured by invoking the script directly under its stub with
`bash` (never `zsh`), recorded in `240-01-SUMMARY.md`:

```
$ FAKE_MODE=get_403 ... bash scripts/ci/ensure-github-pages-legacy-branch.sh
exit=1
ensure-github-pages-legacy-branch: GET /pages returned '403'; refusing to guess.
HTTP/2.0 403 Forbidden
{"message":"Resource not accessible by integration","status":"403"}

$ FAKE_MODE=get_500 ... bash scripts/ci/ensure-github-pages-legacy-branch.sh
exit=1
ensure-github-pages-legacy-branch: GET /pages returned '500'; refusing to guess.
HTTP/2.0 500 Internal Server Error
X-GitHub-Request-Id: DEAD:0403:BEEF
{"message":"Server Error (ref 403); Resource not accessible by integration was not the cause","status":"500"}

$ FAKE_MODE=put_422 ... bash scripts/ci/ensure-github-pages-legacy-branch.sh
exit=1
ensure-github-pages-legacy-branch: PUT /pages returned '422'.
HTTP/2.0 422 Unprocessable Entity
{"message":"Invalid request.","status":"422"}

$ FAKE_MODE=put_500 ... bash scripts/ci/ensure-github-pages-legacy-branch.sh
exit=1
ensure-github-pages-legacy-branch: PUT /pages returned '500'.
HTTP/2.0 500 Internal Server Error
{"message":"Server Error","status":"500"}
```

The `get_500` body carries the bare digits `403` twice — once in the request id, once in the
message — and the old unanchored match would have read it as "expected 403, carry on". It now
exits 1. That is the D-17 false-positive guard firing.

```bash
# the self-test is a step of fast_checks on the main run at the final committed HEAD
gh api "repos/szTheory/sigra/actions/runs/35377012499/jobs?filter=latest&per_page=100" \
  --jq '.jobs[] | select(.name | startswith("Fast checks")) | {conclusion,
        pages_step: [.steps[] | select(.name == "Pages legacy-branch script self-test")]}'
# => conclusion "success"; step "Pages legacy-branch script self-test" present and completed

# and on the PR run that gated the squash merge
gh run view 35376244993 --json conclusion,headBranch --jq '.'
```

## AFTER-P20-GUARD-OBSERVED

Status: captured (runs 35377012499, 35376244993)

The claim evidenced: `p20-green-04-evidence-step-parity.test.mjs` reports RED against
`test/fixtures/prohibitions/p20-green-04-step-drift.yml` (the known-bad fixture with
`Install Playwright browsers` deleted) and GREEN against the real
`green-04-evidence.yml` / `ci.yml` pair, with the shared prohibitions glob unaffected. Guard born
RED in commit `962fa0b5`; carried onto `main` by the squash at `abec92c4` and executed there by
the `fast_checks` step `Phase 230 prohibition guards` on run `35377012499` (and on PR run
`35376244993` before the merge). All three local invocations ran through `bash -c`, never zsh.

**RED half** — the guard pointed at the committed known-bad fixture:

```
$ GSD_PROHIB_SUBJECT=test/fixtures/prohibitions/p20-green-04-step-drift.yml \
    node --test --test-reporter=tap scripts/ci/prohibitions/p20-green-04-evidence-step-parity.test.mjs
EXIT=1
not ok 1 - the evidence job step list matches ci.yml generated_admin_playwright_smoke
  step-count drift: ci.yml#generated_admin_playwright_smoke has 13 steps,
  .github/workflows/green-04-evidence.yml#green_04_evidence_repeat has 12 — missing from the
  evidence copy: `Install Playwright browsers`. The evidence copy is no longer the lane it claims
  to prove (D-02).
```

Subtests 2 (non-vacuity floor) and 3 (negative control) both reported `ok` on that same run — the
red came from the clause under test, not from an empty parse.

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

```bash
# the same glob, executed on main as the fast_checks step `Phase 230 prohibition guards`
gh api "repos/szTheory/sigra/actions/runs/35377012499/jobs?filter=latest&per_page=100" \
  --jq '.jobs[] | select(.name | startswith("Fast checks")) | {conclusion,
        guards: [.steps[] | select(.name == "Phase 230 prohibition guards") | .conclusion]}'
# => {"conclusion":"success","guards":["success"]}

gh run view 35376244993 --json conclusion --jq '.conclusion'   # PR run, pre-merge: success
```

## AFTER-GREEN-04-N20

Status: captured (runs 35377050754)

The claim evidenced: a single `workflow_dispatch` of `green-04-evidence.yml` on `main`
(run `35377050754`, event `workflow_dispatch`, head_sha
`abec92c4b33005e21b550a2f899fe1d1e0f817a1`, created `2026-09-18T17:54:12Z`) produced twenty jobs
named `Generated admin Playwright smoke (GREEN-04 repeat) (1)` … ` (20)`, every one concluding
`success`, every one parented by that one dispatch run, and the receipt's `sc1.verdict` is `pass`.
No leg was re-run, re-dispatched or cancelled: `gh run list --workflow green-04-evidence.yml` has
exactly one entry.

D-13 satisfied inside the receipt: `head_sha = abec92c4b33005e21b550a2f899fe1d1e0f817a1`
(equal to `git rev-parse HEAD` at capture) and `clean_tree = true`. The collector refuses a dirty
tree (`dirty_tree`) and refuses a run whose head_sha is not HEAD
(`evidence_run_head_sha_is_not_final_committed_head`).

| matrix repeat | job id | conclusion | url |
|---|---|---|---|
| 1 | 105704082603 | success | https://github.com/szTheory/sigra/actions/runs/35377050754/job/105704082603 |
| 2 | 105704082678 | success | https://github.com/szTheory/sigra/actions/runs/35377050754/job/105704082678 |
| 3 | 105704082645 | success | https://github.com/szTheory/sigra/actions/runs/35377050754/job/105704082645 |
| 4 | 105704082720 | success | https://github.com/szTheory/sigra/actions/runs/35377050754/job/105704082720 |
| 5 | 105704082399 | success | https://github.com/szTheory/sigra/actions/runs/35377050754/job/105704082399 |
| 6 | 105704082855 | success | https://github.com/szTheory/sigra/actions/runs/35377050754/job/105704082855 |
| 7 | 105704082791 | success | https://github.com/szTheory/sigra/actions/runs/35377050754/job/105704082791 |
| 8 | 105704082676 | success | https://github.com/szTheory/sigra/actions/runs/35377050754/job/105704082676 |
| 9 | 105704082665 | success | https://github.com/szTheory/sigra/actions/runs/35377050754/job/105704082665 |
| 10 | 105704082865 | success | https://github.com/szTheory/sigra/actions/runs/35377050754/job/105704082865 |
| 11 | 105704082691 | success | https://github.com/szTheory/sigra/actions/runs/35377050754/job/105704082691 |
| 12 | 105704082937 | success | https://github.com/szTheory/sigra/actions/runs/35377050754/job/105704082937 |
| 13 | 105704082772 | success | https://github.com/szTheory/sigra/actions/runs/35377050754/job/105704082772 |
| 14 | 105704082699 | success | https://github.com/szTheory/sigra/actions/runs/35377050754/job/105704082699 |
| 15 | 105704082851 | success | https://github.com/szTheory/sigra/actions/runs/35377050754/job/105704082851 |
| 16 | 105704083995 | success | https://github.com/szTheory/sigra/actions/runs/35377050754/job/105704083995 |
| 17 | 105704084418 | success | https://github.com/szTheory/sigra/actions/runs/35377050754/job/105704084418 |
| 18 | 105704084035 | success | https://github.com/szTheory/sigra/actions/runs/35377050754/job/105704084035 |
| 19 | 105704083987 | success | https://github.com/szTheory/sigra/actions/runs/35377050754/job/105704083987 |
| 20 | 105704084166 | success | https://github.com/szTheory/sigra/actions/runs/35377050754/job/105704084166 |

```bash
gh run list --workflow green-04-evidence.yml --json databaseId,headSha,status,conclusion,event
# => [{"conclusion":"success","databaseId":35377050754,"event":"workflow_dispatch",
#      "headSha":"abec92c4b33005e21b550a2f899fe1d1e0f817a1","status":"completed"}]

gh run view 35377050754 --json jobs --jq '[.jobs[]
  | select(.name | startswith("Generated admin Playwright smoke (GREEN-04 repeat)"))
  | .conclusion] | group_by(.) | map({(.[0]//"null"): length}) | add'
# => {"success": 20}

bash scripts/ci/capture-green-04-evidence.sh \
  --output .planning/phases/240-green-main-evidence-honest-pages-script/240-GREEN-04-EVIDENCE.json \
  --run-id 35377050754 \
  --main-window-start 2026-09-16T03:29:55Z --main-window-end 2026-09-18T18:11:54Z
# => capture-green-04-evidence: wrote …/240-GREEN-04-EVIDENCE.json (sc1.leg_count=20 verdict=pass)

R=.planning/phases/240-green-main-evidence-honest-pages-script/240-GREEN-04-EVIDENCE.json
jq -e '.sc1.leg_count >= 20'                        "$R"
jq -e '.sc1.verdict == "pass"'                      "$R"
jq -e '[.sc1.legs[].conclusion] | unique == ["success"]' "$R"
jq -e '.clean_tree == true'                         "$R"
jq -e '.sc1.jobs_filter == "latest"'                "$R"
jq -e --arg h "$(git rev-parse HEAD)" '.head_sha == $h' "$R"
# all exit 0; negative control `jq -e '.sc1.leg_count >= 999' "$R"` exits 1
```

## AFTER-CI-GATE-MAIN-WINDOW

Status: captured (runs 35052017063, 35056270436, 35182589738, 35246681580, 35307612410, 35365693716, 35373550987, 35377012499)

The claim evidenced: over the declared `main` window — start `2026-09-16T03:29:55Z` (the
`created_at` of the oldest `main` `ci.yml` run at or after the Phase 236 flake fix landed at
`b6e889c4`, which is that very run), end `2026-09-18T18:11:54Z` (the capture instant) — `ci.yml`'s
`ci-gate` job concluded `success` on **every** one of the eight runs, and
`flake_attributable_red_count` — the number of `main` runs whose `Generated admin Playwright smoke`
job concluded `failure` — is **zero**. The verdict below is a per-lane **job** table, never a run
conclusion (D-08): two of the eight runs carry a run-level `failure` that belongs entirely to
`Admin eval render + probe`, the non-gate lane (see BEFORE-MAIN-RED-MISATTRIBUTION).

| main run | run conclusion (NOT the verdict) | `ci-gate` job | `Generated admin Playwright smoke` job |
|---|---|---|---|
| 35052017063 | failure | success | success |
| 35056270436 | success | success | success |
| 35182589738 | success | success | success |
| 35246681580 | success | success | success |
| 35307612410 | success | success | success |
| 35365693716 | failure | success | success |
| 35373550987 | success | success | success |
| 35377012499 | in_progress at capture (only `Admin eval render + probe` still running) | success | success |

`ci_gate_conclusions`: `{"success": 8, "failure": 0, "skipped": 0}`.
`flake_attributable_red_count`: `0`. `run_count`: `8`.

**The nine-of-ten caveat (D-10), stated in writing.** `example_unit_smoke` is **absent** from the
ten `ci-gate.needs` entries at `ci.yml:1547-1557` (`changes`, `install_golden_contract`,
`library_tests`, `library_tests_dep_off`, `install_smoke`, `upgrade_smoke`, `example_http_smoke`,
`example_playwright_smoke`, `generated_admin_playwright_smoke`, `fast_checks`) while being
independently required by ruleset 14941512. A `ci-gate: success` in this window is therefore a
**nine-of-ten** claim, not a whole-gate claim. This phase **discloses** that gap and does not fix
it; the fix is owned by
`.planning/todos/pending/2026-07-29-example-unit-smoke-required-but-absent-from-ci-gate-needs.md`.
(For what it is worth, `Example unit smoke (ExUnit + ConnTest)` did conclude `success` on run
35377012499 — but that is a separate observation, not something `ci-gate` aggregated.)

```bash
gh api "repos/szTheory/sigra/actions/workflows/ci.yml/runs?branch=main&created=2026-09-16T03:29:55Z..2026-09-18T18:11:54Z&per_page=100" \
  --jq '.total_count, [.workflow_runs[].id]'
# => 8
# => [35377012499,35373550987,35365693716,35307612410,35246681580,35182589738,35056270436,35052017063]

R=.planning/phases/240-green-main-evidence-honest-pages-script/240-GREEN-04-EVIDENCE.json
jq -e '.sc2.ci_gate_conclusions.failure == 0 and .sc2.flake_attributable_red_count == 0' "$R"
jq -e '(.sc2.caveat | length) > 0 and (.sc2.caveat | test("example_unit_smoke"))'        "$R"
jq -r '.sc2.runs[] | "\(.run_id) gate=\(.ci_gate_conclusion) smoke=\(.generated_admin_smoke_conclusion)"' "$R"
```

## AFTER-ISSUE-231-CLOSED

Status: pending (closure-proof obligation — D-24: the close is proven by re-reading issue state, never by the close command's exit code; plan 240-05 owns it)

The claim to evidence: issue #231 is `CLOSED`, and the closing comment names the dispatch run id,
the `main` window bounds, the live Pages payload, and the nine-of-ten caveat — so a reader can
re-derive the claim without trusting this ledger. A `captured` slot with no run id is an assertion
in prose wearing the costume of evidence; that is the exact defect p12 exists to catch.

```bash
gh issue comment 231 --body-file <closure-comment.md>
gh issue close 231
gh issue view 231 --json state,closedAt,comments -q '.state'
```
