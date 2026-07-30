# Phase 231 — Observed-Run Evidence Ledger

**A claim without a verbatim run ID is not evidence.** Every conclusion, duration, job-count or
log-line claim anywhere in this phase's eleven SUMMARYs — and this requirement's own closing
verdict — must carry the run ID it was measured from and the exact command (`gh run view`,
`gh api .../logs`, or `scripts/ci/ci-run-metrics.sh`) that produced it. A YAML condition that
"looks right," or a claim that reads plausibly but names no run, is not proof that a run executed
the behavior it describes. `.planning/v1.42-CI-GATE-REMEDIATION-FINDINGS.md` is the precedent
failure this ledger exists to prevent — a milestone that passed audits which were "code-level
reads that never executed the specs" while the required Playwright check carried ~15 real
failures. `.planning/ROADMAP.md`'s "Verification Philosophy (binds every phase)" section states
the same rule for this phase: success criteria are proven by *running CI and reading measured
numbers*, never by reading YAML.

This phase's five success criteria have each produced a receipt inside their own plan's SUMMARY.
This ledger gathers those eleven scattered claims into one place a reader can check against the
five criteria without re-opening every SUMMARY — inheriting Phase 230's evidence-ledger format
contract verbatim (`230-EVIDENCE.md`), which `scripts/ci/prohibitions/_lib.mjs`'s `parseEvidenceSlots`
is deliberately generic across every phase's ledger to enforce, with no opt-in marker.

---

## Slot Index

| Slot | What it is | Serves | How captured | Status |
|------|-----------|--------|--------------|--------|
| [BEFORE-NIGHTLY-BASELINE](#before-nightly-baseline) | Nightly run `30425416933`, the pre-fix measured baseline | GATE-01 (SC-1's "before" half) | `ci-run-metrics.sh --jobs 30425416933` | captured (run 30425416933) |
| [AFTER-GENERATED-HOST-SMOKE](#after-generated-host-smoke) | Generated-host parity executing, non-skipped, on two real `pull_request` events | GATE-02 (SC-2) | `gh run view --json jobs` + `gh api .../logs` | captured (runs 30521272305, 30523049209) |
| [AFTER-ROT-PROBE](#after-rot-probe) | `ci-gate`'s honest-skip verdict proven in both directions, two event types | GATE-03 (SC-3) | `gh workflow run` + `gh run view --json jobs` | captured (runs 30526744204, 30526771018, 30526727106) |
| [AFTER-EVAL-HARNESS](#after-eval-harness) | `admin_eval_render`'s b1-b6 guards executing and passing, mask removed, two independent commits | GATE-04 (SC-4) | `gh run view --log --job <id>` | captured (runs 30512523387, 30514238789) |
| [AFTER-RELEASE-LANE-WAIT](#after-release-lane-wait) | The extracted `wait-for-ci-gate.sh` polling loop, invoked live against a real completed push-to-main run | DX-05 (SC-5) | `bash scripts/ci/wait-for-ci-gate.sh` | captured (run 30466318240) |
| [AFTER-PAGES-PUBLISHER](#after-pages-publisher) | The GitHub Pages publisher seeded and green; the Pages-source self-heal question diagnosed | GATE-01 (D-17/D-18) | `gh workflow run` + `gh api .../pages` | captured (run 30529885885) |
| [AFTER-NIGHTLY-POST-MERGE](#after-nightly-post-merge) | The first `schedule`-triggered nightly after this phase merges | GATE-01 (SC-1's "after" half) | `gh run view <id> --json jobs` (post-merge, not yet run) | pending (structural obligation: requires a `schedule` event this phase cannot force forward) |

---

## BEFORE-NIGHTLY-BASELINE

Status: captured (run 30425416933)

The pre-fix nightly baseline every later slot in this ledger is measured against. Run
`30425416933` (`2026-07-29T05:33Z`, head `018229e5`, **pre**-Phase-230-merge) is the same run
`231-CONTEXT.md` D-16 and `231-RESEARCH.md` § "GATE-01: Nightly Red Inventory" both cite.

Command:

```
bash scripts/ci/ci-run-metrics.sh --jobs 30425416933
```

Output (verbatim, re-captured 2026-07-30 — GitHub retains workflow run data for the full window):

```
job                                                                    conclusion  duration_s  duration
Fast checks (milestone/installer/contracts/snapshot/ledger guards)     success     28s         0m28s
Install matrix (flag combinations) (--no-organizations)                success     116s        1m56s
Example unit smoke (ExUnit + ConnTest)                                 success     50s         0m50s
Release ref guard                                                      success     3s          0m3s
Passkeys opt-out smoke                                                 success     182s        3m2s
Passkeys manual fallback smoke                                         success     118s        1m58s
Nightly probe (forced-failure self-test)                               success     3s          0m3s
Install matrix (flag combinations) (--no-passkeys)                     success     117s        1m57s
Install matrix (flag combinations)                                     success     125s        2m5s
Install matrix (flag combinations) (--no-organizations --no-passkeys)  success     120s        2m0s
Upgrade smoke (published source series -> local candidate)             success     115s        1m55s
Generated admin Playwright smoke                                       failure     229s        3m49s
Example HTTP smoke (boot + curl critical routes)                       success     54s         0m54s
Example Playwright smoke (full lifecycle)                              success     1611s       26m51s
Library tests shard 2                                                  success     316s        5m16s
Install smoke (fresh phx.new + sigra.install)                          success     116s        1m56s
Admin eval render + probe (evidence only, not a merge gate)            failure     851s        14m11s
Recapture admin-design baselines (in-CI)                               success     1126s       18m46s
Install golden + idempotency contract (subprocess harness)             success     336s        5m36s
Library tests (dep-off — Threadline absent)                            success     74s         1m14s
Recapture admin-checkpoint baselines (in-CI)                           success     243s        4m3s
Library tests shard 1                                                  success     463s        7m43s
Library tests                                                          success     2s          0m2s
ci-gate                                                                failure     4s          0m4s
Notify on red ci-gate (release-lane-rot)                               success     7s          0m7s
```

**25 jobs, 3 non-success, 22 success.** The three non-success jobs, matching `231-RESEARCH.md:924-930`
exactly:

| Job | `databaseId` | Conclusion | Duration | Owner |
|---|---|---|---|---|
| `Generated admin Playwright smoke` | `90490780778` | `failure` | `229s` | GATE-02 (the 320px assertion) |
| `Admin eval render + probe (evidence only, not a merge gate)` | `90490780796` | `failure` | `851s` | GATE-04 (bugs 1 and 2) |
| `ci-gate` | `90494800754` | `failure` | `4s` | propagation from the first (`admin_eval_render`'s own `continue-on-error` keeps it from also reddening `ci-gate`) |

**Reconciling "23 green" against this table, recorded rather than silently repeated.**
`231-CONTEXT.md` D-16 describes this same run as "25 jobs, 23 green," a figure that predates the
live re-verification in `231-RESEARCH.md` and is off by one against the actual job list: 25 total
minus 3 non-success (not 2) leaves **22** `success` jobs, not 23. `231-RESEARCH.md`'s own
"live-verified" inventory already carries the correct 3-row table quoted above; this re-capture,
independently re-run 2026-07-30, reproduces the identical three job IDs, conclusions and
durations. The accurate figure — the one this ledger and `231-11-PLAN.md`'s own baseline slot
description are built from — is **22 success / 3 non-success**, not "23 green." `Notify on red
ci-gate (release-lane-rot)` fired (`success`, `7s`) because `ci-gate` failed on this run,
consistent with D-23's already-proven notifier behavior.

This is GATE-01's before half: every requirement this phase closed (GATE-02, GATE-03, GATE-04,
DX-05) traces its own "why did the nightly redden" question back to one of these three rows.

---

## AFTER-GENERATED-HOST-SMOKE

Status: captured (runs 30521272305, 30523049209)

GATE-02's SC-2: generated-host parity verified by a job that **executes on a real PR**, not one
that reports pass by being skipped. Two independent `pull_request`-event runs, both at plan
231-07's own commits, both the first time this lane has ever executed on a real PR event in this
repository's history.

Commands:

```
gh run view 30521272305 --repo szTheory/sigra --json jobs \
  -q '.jobs[] | select(.name=="Generated admin Playwright smoke")'
gh run view 30523049209 --repo szTheory/sigra --json jobs \
  -q '.jobs[] | select(.name=="Generated admin Playwright smoke")'
```

Output (verbatim, re-captured 2026-07-30):

```
$ gh run view 30521272305 ...
{"completedAt":"2026-07-30T07:02:30Z","conclusion":"success","databaseId":90802076501,"startedAt":"2026-07-30T06:58:10Z"}

$ gh run view 30523049209 ...
{"completedAt":"2026-07-30T07:32:20Z","conclusion":"success","databaseId":90807615885,"startedAt":"2026-07-30T07:28:10Z"}
```

Both non-`skipped`, both `startedAt != completedAt` (a real duration, not a ~0s skip record).
Log lines from each job, re-captured verbatim:

```
$ gh api repos/szTheory/sigra/actions/jobs/90802076501/logs | grep -E "Running 9 tests|passed"
Running 9 tests using 1 worker
  8 passed (12.8s)
  1 passed (2.0s)

$ gh api repos/szTheory/sigra/actions/jobs/90807615885/logs | grep -E "Running 9 tests|passed"
Running 9 tests using 1 worker
  8 passed (12.3s)
  1 passed (2.0s)
```

Zero `failed` lines on either run. `30523049209`'s `ci-gate` job also concluded `success`
(`databaseId: 90810431954`), confirming `generated_admin_playwright_smoke` is `ci-gate.needs`-blocking
on this run, not merely visible (`ci.yml:1849-1861`).

**Sample size, stated explicitly.** These two runs are the two `pull_request`-event observations
`231-07-SUMMARY.md` records; they sit atop a much larger sample the phase's gap-closure work
already built — 8 consecutive green `workflow_dispatch` runs on the corrected CSS fix
(`70bed477`, `231-GAP-GATE02-SUMMARY.md`) plus these 2 `pull_request` runs and 2 more
`workflow_dispatch` confirmations (`231-07-SUMMARY.md`'s own table), for **12 consecutive green
job-level observations, 0 failures**, across 3 shas and both trigger types, against a
formerly-measured ~38-60% failure rate on the pre-fix content. This ledger cites the 2
`pull_request`-event runs directly because SC-2's literal text requires execution "on a real PR";
the fuller 12-run tally is recorded in `231-GAP-GATE02-SUMMARY.md` and `231-07-SUMMARY.md` rather
than re-transcribed here.

## Restated Success Criterion (SC-2)

`231-RESEARCH.md` finding C-4 established that SC-2's implied observable (`9 passed`) never
appears in any log: `scripts/ci/admin-acceptance-smoke.sh --test all` invokes Playwright twice, so
a green run prints two separate summary lines, not one combined count.

**Operative restatement — verify against this, not a literal `9 passed` grep:**

> `Generated admin Playwright smoke` reports `conclusion: success` with `startedAt != completedAt`
> (a real duration, not `skipped`), and its log contains `Running 9 tests using 1 worker` followed
> by `8 passed` and then `1 passed`, with zero `failed` lines.

Both evidencing job logs are quoted verbatim above (`90802076501`, `90807615885`), and both match
this restated wording exactly. This restatement was written down before this ledger existed
— `231-RESEARCH.md:352`, `231-VALIDATION.md:87`, and `231-07-PLAN.md:23` all carry the identical
phrasing — so this section transcribes an existing recorded restatement rather than inventing a
new one at ledger-writing time.

---

## AFTER-ROT-PROBE

Status: captured (runs 30526744204, 30526771018, 30526727106)

GATE-03's SC-3: `ci-gate` fails when a needed lane is skipped by a rotted condition and passes
when a lane is skipped by a correct event gate — both demonstrated live, at the same commit
(`d7f75397974af93d2485ab9f70454fe0ce88d289a6`), across two event types.

Commands:

```
gh workflow run "CI" --repo szTheory/sigra --ref worktree-discuss-231 \
  -f force_rot_probe=false -f recapture_branch=worktree-discuss-231
gh workflow run "CI" --repo szTheory/sigra --ref worktree-discuss-231 \
  -f force_rot_probe=true -f recapture_branch=worktree-discuss-231
gh run view 30526744204 --repo szTheory/sigra --json jobs -q '.jobs[] | select(.name=="ci-gate")'
gh run view 30526771018 --repo szTheory/sigra --json jobs -q '.jobs[] | select(.name=="ci-gate")'
gh run view 30526727106 --repo szTheory/sigra --json jobs -q '.jobs[] | select(.name=="ci-gate")'
```

**Run 1 — clean control (`30526744204`, `workflow_dispatch`, `ci-gate` job `90824424228`,
conclusion `success`):**

```
Honest-skip verdict -- event: workflow_dispatch, docs_only: false

lane                              result   verdict
install_golden_contract           success  PASS
library_tests                     success  PASS
library_tests_dep_off             success  PASS
install_smoke                     success  PASS
upgrade_smoke                     success  PASS
example_http_smoke                success  PASS
example_playwright_smoke          success  PASS
generated_admin_playwright_smoke  success  PASS
fast_checks                       success  PASS

  every skip (if any) on this lane set is legitimately gated for this event, and no allowed gate is rotted.
```

All nine lanes `success` (zero `skipped`) — confirming D-03's "no `ci-gate.needs` lane may
legitimately skip on a non-`pull_request` event."

**Run 2 — rot probe (`30526771018`, `workflow_dispatch`, `ci-gate` job `90823547343`, conclusion
`failure`):**

```
*** ROT PROBE ACTIVE (--force-rot-probe): forcing example_playwright_smoke to a skipped result carrying
a synthetic rotted gate, self-test purposes only -- this run does not reflect real CI ***
Honest-skip verdict -- event: workflow_dispatch, docs_only: false

lane                              result   verdict
...
example_playwright_smoke          skipped  FAIL
...

  FAIL example_playwright_smoke: lane 'example_playwright_smoke' skipped on event 'workflow_dispatch', which
  is not in the legitimate-skip set for this event; manifest gate: "github.head_ref == 'ship/rot-probe-synthetic'"
##[error]Process completed with exit code 1.
```

The verdict names the specific rotted lane and quotes its synthetic gate string, satisfying SC-3's
"whose log names the specific lane and its gate string."

**Run 3 — live `pull_request` run (`30526727106`, PR #125 synchronize, same commit, `ci-gate` job
`90822708355`, conclusion `success`):**

```
Honest-skip verdict -- event: pull_request, docs_only: false

lane                              result   verdict
...
upgrade_smoke                     skipped  PASS
...

  every skip (if any) on this lane set is legitimately gated for this event, and no allowed gate is rotted.
```

`upgrade_smoke`'s genuinely event-gated skip observed live (not merely hermetically) reporting
`PASS` — D-03's `pull_request`-only allow-set branch, exercised on a real PR.

**Sample size, stated explicitly.** 3 live runs, 2 event types, 1 deliberate failure + 2 passes,
all at commit `d7f75397`, per `231-09-SUMMARY.md`'s own stated economy: the fail-direction
mechanism is re-provable forever via `force_rot_probe`, so a fourth or fifth dispatch would add no
new information.

---

## AFTER-EVAL-HARNESS

Status: captured (runs 30512523387, 30514238789)

GATE-04's SC-4: `admin_eval_render` concludes `success` on its new lane, with the harness's own
`(b1)`-`(b6)` guards demonstrably executing — proven on two independent commits, the second of
which is the first observation captured on a lane carrying **no job-level mask** (231-06 removed
`ci.yml:2450`'s `continue-on-error: true` between the two runs).

**Observation 1 (plan 231-05, run `30512523387`, job `90775422130`, sha `af1b192c`):**

```
$ gh run view --job 90775422130 --repo szTheory/sigra --log | grep -E "admin-eval-harness:|-guard:|-check:|-lint:|-monotonic:|award-guard:"
admin-eval-harness: (a) render matrix + probes + bundles (3 projects)
Running 192 tests using 1 worker
  192 passed (22.1m)
admin-eval-harness: (a2) fix-queue derivation + open_findings update (D-12)
admin-eval-harness: (b1) stale-render guard
stale-render-guard: PASS (171 bundle(s) verified at HEAD af1b192c5033834450533f0c2adfeeecd743ad74)
admin-eval-harness: (b2) evidence anchor integrity check
evidence-anchor-check: PASS (171 bundle(s), 4596 finding(s) checked)
admin-eval-harness: (b3) fix-queue derived-field lint (auto_eligible, priority, open_findings)
fix-queue-lint: PASS (134 queue entries validated)
admin-eval-harness: (b4) quality findings consistency guard (working-tree vs committed HEAD)
quality-findings-monotonic: PASS (checked vs HEAD)
admin-eval-harness: (b5) award ledger verify-then-climb guard (working-tree vs committed HEAD)
award-guard: PASS (32 cells checked vs HEAD)
admin-eval-harness: (b6) settled findings lint
settled-findings-lint: PASS (no data rows — trivially valid)
admin-eval-harness: PASS — all phases green
```

Job `conclusion: success`, `startedAt: 2026-07-30T03:58:34Z`, `completedAt: 2026-07-30T04:20:50Z`
(wall-clock ~22m16s). This run still carried `ci.yml:2450`'s job-level `continue-on-error: true`
at dispatch time — its `success` was a genuine pass, not yet load-bearing against a mask.

**Observation 2 (plan 231-06, run `30514238789`, job `90780471290`, sha `91d42bf8`) — the first
observation captured on a lane with the mask removed:**

```
$ gh run view --job 90780471290 --repo szTheory/sigra --log | grep -E "admin-eval-harness:|-guard:|-check:|-lint:|-monotonic:|award-guard:"
admin-eval-harness: (a) render matrix + probes + bundles (3 projects)
admin-eval-harness: (a2) fix-queue derivation + open_findings update (D-12)
admin-eval-harness: (b1) stale-render guard
stale-render-guard: PASS (171 bundle(s) verified at HEAD 91d42bf84fbaa542429b3c8e9e8cd005e745d4c3)
admin-eval-harness: (b2) evidence anchor integrity check
evidence-anchor-check: PASS (171 bundle(s), 4596 finding(s) checked)
admin-eval-harness: (b3) fix-queue derived-field lint (auto_eligible, priority, open_findings)
fix-queue-lint: PASS (134 queue entries validated)
admin-eval-harness: (b4) quality findings consistency guard (working-tree vs committed HEAD)
quality-findings-monotonic: PASS (checked vs HEAD)
admin-eval-harness: (b5) award ledger verify-then-climb guard (working-tree vs committed HEAD)
award-guard: PASS (32 cells checked vs HEAD)
admin-eval-harness: (b6) settled findings lint
settled-findings-lint: PASS (no data rows — trivially valid)
admin-eval-harness: PASS — all phases green
```

Job `conclusion: success`, wall-clock ~23m55s. `stale-render-guard`'s own line names this run's
own `headSha` (`91d42bf8...`), confirming the committed-HEAD trap held. `ci-gate`'s own log on
this same run (job `90782956499`) lists nine required lanes and no `ADMIN_EVAL_RENDER` entry at
all — confirming `admin_eval_render` remains absent from `ci-gate.needs`, so this observation
proves a hard signal on push/schedule/dispatch, not a merge-blocking one.

**Why both banners are needed, not just one.** Banners prove reach; the job's own `conclusion`
proves pass — job-green alone does not distinguish "guards ran and passed" from "guards were
reached but no-opped" (D-14). Both runs show all seven banner lines in order, none missing, and
both jobs conclude `success`.

---

## AFTER-RELEASE-LANE-WAIT

Status: captured (run 30466318240)

DX-05's SC-5: `gate-ci-green` completes inside its polling ceiling on a real push-to-`main` run.
`gate-ci-green` itself carries `if: needs.release-please.outputs.release_created == 'true'`, so it
structurally never runs on an ordinary push (`231-01-SUMMARY.md`'s own "standing-receipt" note,
marked `verification: backstop` in this phase's own must_haves). The in-phase receipt is the
extracted polling script (`scripts/ci/wait-for-ci-gate.sh`) invoked live against a real completed
run's SHA, exercising the exact `gh run list` / `gh run view` logic `gate-ci-green` will run on the
next real release.

Command:

```
SHA="$(gh run view 30466318240 --repo szTheory/sigra --json headSha -q .headSha)"
bash scripts/ci/wait-for-ci-gate.sh --sha "$SHA" --repo szTheory/sigra --no-dispatch --format json
```

Output (verbatim, from `231-01-SUMMARY.md`, re-derivable against the same run since GitHub
retains run data for the full window):

```
$ echo "$SHA"
20e4fe3b9349d2da160d3c01fc580af7d1128317

$ bash scripts/ci/wait-for-ci-gate.sh --sha "$SHA" --repo szTheory/sigra --no-dispatch --format json
{
  "sha": "20e4fe3b9349d2da160d3c01fc580af7d1128317",
  "run_url": "https://github.com/szTheory/sigra/actions/runs/30466318240",
  "attempts": 1,
  "verdict": "PASS"
}
$ echo $?
0
```

Exit 0, `attempts: 1`, well inside the 120-attempt (`D-20`) ceiling. This is a genuine observation
— a real `gh run list` call filtered by the SHA, a real `gh run view --json jobs` call confirming
`ci-gate`'s conclusion, a real `gh run view --json url` call — not a YAML read.

**Standing-receipt note, stated per the plan's own `verification: backstop` truth.** The
"on the next real release, `gate-ci-green` completes inside the 120-attempt ceiling" half of SC-5
cannot be observed in this phase (`gate-ci-green` never runs on an ordinary push). This slot is
the full in-phase receipt available; the real-release confirmation is a standing obligation for
the next actual Hex release, not a phase blocker — consistent with D-21's owner-selected posture.

---

## AFTER-PAGES-PUBLISHER

Status: captured (run 30529885885)

GATE-01's two structural sub-items owned entirely by this phase (not an observation of GATE-02/
GATE-04): D-17 (the Pages publisher seeds before boot) and D-18 (whether the Pages-source self-heal
fires once the publisher can finally succeed).

Command:

```
gh workflow run "Playwright reports (GitHub Pages)" --repo szTheory/sigra --ref worktree-discuss-231
```

Output (verbatim, from `231-10-SUMMARY.md`): run `30529885885` (`workflow_dispatch`, ref
`worktree-discuss-231`, commit `8e9e7839`), job `90829454715` (`Publish Playwright site`),
conclusion `success`:

```
Run admin checkpoints (chromium, mobile, dark-chromium):
  ✓  [admin-checkpoints-chromium] captures curated admin review pages across desktop/mobile/dark (37.4s)
  ✘  [admin-checkpoints-mobile]   captures curated admin review pages across desktop/mobile/dark (1.0m)
       Test timeout of 60000ms exceeded (waitForLiveViewReady — unrelated, known-class first-load flake)
  ✓  [admin-checkpoints-mobile]   captures curated admin review pages across desktop/mobile/dark (retry #1) (49.9s)
  ✓  [admin-checkpoints-dark]     captures curated admin review pages across desktop/mobile/dark (37.3s)
  1 flaky
  2 passed (3.2m)
```

**Zero failures at the assertion that failed on scheduled run `30432494488`**
(`admin-checkpoints.spec.ts:230`, the pagination-link assertion). The one flake observed is an
unrelated, previously-catalogued `waitForLiveViewReady` first-load timeout
(`.planning/todos/resolved/2026-07-04-admin-eval-first-nav-flake.md`), which passed cleanly on
Playwright's own retry #1. D-17's diagnosis and fix are confirmed directly, on a real run, not
the diff.

**D-18, answered precisely — not self-healed, not confirmed-broken, structurally unobservable
pre-merge:**

```
$ gh api repos/szTheory/sigra/actions/jobs/90829454715 --jq \
    '.steps[] | select(.name | test("Publish to gh-pages|Point GitHub Pages")) | {name, status, conclusion}'
{"conclusion":"skipped","name":"Publish to gh-pages branch","status":"completed"}
{"conclusion":"skipped","name":"Point GitHub Pages at gh-pages (REST API)","status":"completed"}

$ gh api repos/szTheory/sigra/pages
{"build_type":"legacy","source":{"branch":"main","path":"/"}, ...}
```

Both self-heal steps are hard-gated on `github.ref == 'refs/heads/main'`; the dispatch ran on
`worktree-discuss-231`, so both `skipped`. The live Pages source is confirmed unchanged
(`branch: main, path: /`) immediately after the run. No pre-merge `workflow_dispatch` can satisfy
both the fix and the `ref == main` gate simultaneously — dispatching from `main` would run
`main`'s pre-fix copy, and dispatching from the phase branch fails the ref gate. This is recorded
under GATE-01's fallback disposition below, not claimed as either outcome.

---

## AFTER-NIGHTLY-POST-MERGE

Status: pending (structural obligation: requires a `schedule` event this phase cannot force forward)

GATE-01's SC-1 "after" half: the first `schedule`-triggered nightly run after this phase merges to
`main`. The cron (`30 4 * * *`, `ci.yml:22-24`) cannot be forced forward, and no
`workflow_dispatch` produces a `schedule` event — a dispatched run is a structurally different
trigger, not a substitute (the same class of "structurally unobservable pre-merge" finding D-21
already established for `gate-ci-green`, and AFTER-PAGES-PUBLISHER re-establishes above for the
Pages self-heal). This slot is booked honestly as pending rather than claimed from a proxy run.

Exact capture command, to be run against the first scheduled run's ID once it exists:

```
gh run view <first-scheduled-run-after-merge-id> --repo szTheory/sigra --json jobs
```

Whoever captures this run flips this slot's status to `captured (run <id>)`, pastes the verbatim
`--json jobs` output (or `bash scripts/ci/ci-run-metrics.sh --jobs <id>` table) exactly as every
other slot in this ledger does, and records the disposition against the procedure in the section
below — written down now, before the run exists.

---

## GATE-01 Disposition Procedure (D-16, written before any post-merge run exists)

This section is analysis, not a slot — it carries no `BEFORE-`/`AFTER-` heading and is deliberately
written now, before AFTER-NIGHTLY-POST-MERGE has a run to point at, so that if the first nightly is
not literally green, the response is a pre-agreed procedure rather than an after-the-fact
negotiation about how green is green enough.

**Primary target: literal green.** No job in the run concludes outside the `{success, skipped}`
pair. This is the target this phase pursued throughout — GATE-02 and GATE-04's fixes exist
specifically so the nightly's two substantive reds (see the per-red table below) no longer occur.

**Fallback, held in reserve, not adopted up front.** The fallback — "every remaining red lane is a
filed, diagnosed defect with an owner" — is available **only** when every remaining red on the
captured run satisfies all three of: (1) it is filed as a written defect (a todo, an issue, or an
equivalent tracked artifact), (2) that filing carries a diagnosis (what fails and why, not merely
"this is red"), and (3) that filing names an **owner**. The fallback is explicitly **not**
available as a way to wave through a red nobody has diagnosed — an un-filed, un-diagnosed,
un-owned red on the captured run means GATE-01 is **not** satisfied, full stop, regardless of how
many other jobs are green.

**A nightly green because lanes did not execute is not a satisfied criterion.** `ci-gate` treats
`skipped` as a pass; a nightly that is "green" only because its exhaustive lanes silently stopped
running would satisfy nothing this requirement cares about. GATE-03's honest-skip verdict
(`scripts/ci/honest-skip-verdict.sh`, wired into `ci-gate` by plan 231-09) is what distinguishes a
legitimate event-gated skip from a rotted one, and — because `ci-gate` itself carries no event
restriction (`if: always()`) — it runs on the `schedule` lane exactly as it does on `push` and
`pull_request`. If the nightly's own `ci-gate` job is green, GATE-03's verdict is part of what made
it green: a rotted skip on the nightly would fail `ci-gate` the same way the AFTER-ROT-PROBE slot
above proves it does on `workflow_dispatch` and `pull_request`. A `skipped` conclusion on the
nightly is therefore not, by itself, grounds for suspicion — but an un-filed job-level `failure` is
never absorbed into "green" by this procedure regardless of what `ci-gate`'s own aggregate says.

**Per-red disposition table, for the baseline run's three non-success jobs.** Each row states
which plan fixed the underlying defect and which slot in this ledger proves the fix, so a reader
checking the first post-merge nightly against this baseline does not have to reconstruct the chain
themselves:

| Baseline job (run `30425416933`) | Conclusion | Owning defect | Fixed by | Proof slot |
|---|---|---|---|---|
| `Generated admin Playwright smoke` | `failure` (229s) | GATE-02's 320px reflow assertion (D-08/D-09), corrected across four rounds in `231-GAP-GATE02` | plans 231-02, `231-GAP-GATE02`, 231-07 | [AFTER-GENERATED-HOST-SMOKE](#after-generated-host-smoke) |
| `Admin eval render + probe` | `failure` (851s) | GATE-04's two Playwright-phase bugs (WebKit not installed, `SVGAnimatedString` crash) plus the job-level mask | plans 231-04, 231-05, 231-06 | [AFTER-EVAL-HARNESS](#after-eval-harness) |
| `ci-gate` | `failure` (4s) | Propagation from `Generated admin Playwright smoke`'s own failure (`ci-gate.needs`) | same as row 1 (no independent defect) | [AFTER-GENERATED-HOST-SMOKE](#after-generated-host-smoke) |

Every one of the baseline's three non-success jobs traces to a fix this phase already shipped and
already proved on a live run, independent of the nightly itself — restating the phase's own
framing that GATE-01 is largely **an observation of GATE-02 and GATE-04**, not independent work.
If the first post-merge nightly reproduces any of these three exactly, that is a regression against
an already-proven fix and should be investigated as such, not treated as a fresh unknown.

**Two GATE-01 items that are NOT part of the CI nightly** — recorded here so a reader does not look
for them inside the `ci.yml` nightly `schedule` run:

1. **The Pages publisher** (`playwright-github-pages.yml`) is a separate workflow on its own cron
   (`45 6 * * *`, distinct from `ci.yml`'s `30 4 * * *`). D-17's fix (the `Run demo seeds` step) and
   its proof are recorded in [AFTER-PAGES-PUBLISHER](#after-pages-publisher) above, captured against
   plan 231-10's dispatched run `30529885885`, not against any `ci.yml` nightly run.
2. **The Pages build deployment** (`pages-build-deployment`) is a GitHub-managed workflow, not
   repository YAML this phase can dispatch or observe directly. D-18's self-heal question is
   diagnosed — not guessed at — in [AFTER-PAGES-PUBLISHER](#after-pages-publisher): the self-heal
   script is hard-gated to `github.ref == 'refs/heads/main'` and could not be exercised from any
   pre-merge dispatch. **This item is filed under GATE-01's fallback branch**, per the disposition
   table above's third eligibility test:
   - **Filed:** `.planning/todos/pending/2026-07-29-github-pages-source-builds-main-root-not-gh-pages.md`
   - **Diagnosed:** the todo states the exact structural gate (`github.ref == 'refs/heads/main'`)
     and both candidate root causes (insufficient `GITHUB_TOKEN` scope vs. a Settings-level Pages
     block), left open rather than guessed at.
   - **Owner:** repo admin (the todo requires a live Settings → Pages read/write this phase's CI
     token cannot perform pre-merge) — the same human-gated class D-18 explicitly fences this into,
     alongside the already-deferred Hex retire (`.planning/todos/pending/2026-07-03-hex-retire-stray-1-20-0.md`).
   - The todo names its own first observable event (this PR's merge-triggered push, or the next
     `45 6 * * *` schedule run) and the exact `gh api repos/szTheory/sigra/pages` command to re-check
     it — so this filing is a live, actionable backstop, not a dead-letter finding.

**Non-vacuity clause for the observation itself.** An observation that reads nothing is a broken
read, not a green nightly — the same posture D-04 established for the honest-skip manifest,
applied here to the nightly observation itself. Each of the following is a **failure of the
observation**, never evidence of health, and must not be recorded as `captured` if it occurs:

1. **An empty jobs array.** `gh run view <id> --json jobs` returning `{"jobs": []}` (or an
   equivalent empty result) means the read broke, not that the nightly had nothing to check.
2. **An unresolvable run ID.** A run ID that `gh run view` cannot resolve (deleted, wrong repo,
   typo) means no observation happened at all — it must not be recorded as if a run were checked.
3. **A status citing no run ID.** A slot whose `Status:` line says `captured` but names no run ID
   is, by `p12-run-id-provenance.test.mjs`'s own enforced grammar, not distinguishable from a claim
   invented without ever running the command — and is exactly the class of "a number nobody can
   re-derive" this whole ledger exists to prevent.

---

## Pre-Merge Hygiene Check

GitHub honors a `[skip ci]` (or `[ci skip]`) token found **anywhere** in a commit message, and a
squash merge concatenates every commit body in the branch into one squash commit message
(`MAINTAINING.md` § "Squash-merge `[skip ci]` footgun"). One occurrence anywhere in this phase's
commit series — even inside prose describing another job's own commits, which this phase's own
`231-RESEARCH.md` and several SUMMARYs do when discussing `admin_design_recapture` — would
silently skip the entire push-to-main CI run when this branch squash-merges, eliminating SC-1's
nightly evidence path before it could ever materialise (`231-RESEARCH.md` Pitfall 9).

**Scan, run against this branch's full commit series relative to `origin/main`:**

```
git fetch origin main
MB="$(git merge-base origin/main HEAD)"
git log "$MB"..HEAD --format=%B | grep -i 'skip ci'
```

**Result, re-captured 2026-07-30 at this ledger's own final commit:**

```
$ git merge-base origin/main HEAD
64c39f3b5cdce64a6ee60513f5fcdfb8af5c6fba

$ git rev-list --count 64c39f3b5cdce64a6ee60513f5fcdfb8af5c6fba..HEAD
55 commits

$ git log 64c39f3b5cdce64a6ee60513f5fcdfb8af5c6fba..HEAD --format=%B | grep -i 'skip ci'
(no output)
$ echo $?
1
```

**55 commits scanned, 0 occurrences of `skip ci` (case-insensitive) in any subject or body across
the full range.** The scan is a genuine full-series check, not a spot check of the latest commit —
`git log <range> --format=%B` concatenates every commit's subject and body across the entire range
into one stream, matching exactly what a squash merge would produce. No remediation was required.

**Terminal guard confirmation — every guard this phase built or extended, run once more at this
ledger's own final commit, immediately before the PR is handed to review:**

```
$ node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs
# tests 66
# pass 66
# fail 0

$ bash scripts/ci/wait-for-ci-gate.test.sh
Results: 11 passed, 0 failed
wait-for-ci-gate.test: PASS

$ bash scripts/ci/honest-skip-verdict.test.sh
Results: 20 passed, 0 failed
honest-skip-verdict.test: PASS

$ bash scripts/ci/playwright-cache-key-guard.test.sh
Results: 8 passed, 0 failed
playwright-cache-key-guard.test: PASS

$ bash scripts/ci/fix-queue-lint.test.sh
7 checks: 7 passed, 0 failed
fix-queue-lint.test.sh: PASS

$ bash scripts/ci/quality-findings-monotonic.test.sh
Results: 11 passed, 0 failed
quality-findings-monotonic.test: PASS

$ bash scripts/ci/ci-demotion-observer.test.sh
Results: 19 passed, 0 failed
ci-demotion-observer.test: PASS

$ actionlint -shellcheck= .github/workflows/ci.yml .github/workflows/ci-observe.yml \
    .github/workflows/playwright-github-pages.yml .github/workflows/release-please.yml
(exit 0, no output)
```

Every guard this phase shipped or extended (`p14`, `p15`, `p16`, and every `p10`/`p05` change,
all folded into the 66-test prohibition suite above; plus the six standalone `scripts/ci/*.test.sh`
pairs this phase created or extended: `wait-for-ci-gate`, `honest-skip-verdict`,
`playwright-cache-key-guard`, `fix-queue-lint`, `quality-findings-monotonic`,
`ci-demotion-observer`) is green in one place, at the same commit this hygiene check itself was
run against. This is the last point at which the phase's own guards are all confirmed green before
the PR is handed to review.
