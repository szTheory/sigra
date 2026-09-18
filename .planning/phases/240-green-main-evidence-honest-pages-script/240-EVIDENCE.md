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

**Status of this file as written (plan 240-03):** all six slots are `pending`. Plan 240-04 owns
the dispatch, the capture and the flip to `captured`.

## Two claims stated in writing up front

**(a) D-09 — `main`'s run-level red is a misattribution.** `ci.yml`'s **run-level** conclusion on
`main` is currently `failure` for a reason that lies **outside** `ci-gate`. On run `35365693716`
(HEAD `bca3ad72`) the only non-success job was `Admin eval render + probe`, which `ci.yml:2089-2110`
documents in prose as deliberately **not** in `ci-gate.needs` (it is the expensive render-evidence
lane, demoted to push/schedule/dispatch by Phase 230 FAST-03). On that same run
`Notify on red ci-gate` was `skipped`, which per `ci.yml:1645-1655` positively proves `ci-gate`
itself was **not** red — that job exists precisely to fire when `ci-gate` reds on `main`. A naive
`gh run list --branch main` reports red and invites the reader to attribute it to the generated
admin Playwright flake. It is not that. This is the Phase 238 lesson inverted: read the **job**,
not the run (D-08), and `scripts/ci/capture-green-04-evidence.sh` is built so the verdict can only
ever be computed from job conclusions.

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

| Slot | What it is | How it will be captured | Status |
|------|-----------|-------------------------|--------|
| [BEFORE-MAIN-RED-MISATTRIBUTION](#before-main-red-misattribution) | The pre-state: `main`'s run-level `failure` attributable to `admin_eval_render`, not to `ci-gate` or the generated-admin flake | `gh run view` on the `main` run plus `gh api .../jobs` read at the job level | pending |
| [AFTER-PAGES-LOUD-RED](#after-pages-loud-red) | The rewritten Pages script failing loudly instead of swallowing an error (plan 240-01) | the plan 240-01 Pages self-test, run offline against its stub | pending |
| [AFTER-P20-GUARD-OBSERVED](#after-p20-guard-observed) | `p20` observed RED against its committed known-bad fixture and GREEN against the real pair (standing constraint 6) | `GSD_PROHIB_SUBJECT=<fixture> node --test` then the same command without the override | pending |
| [AFTER-GREEN-04-N20](#after-green-04-n20) | SC-1: twenty dispatch legs, every one concluded `success`, read at the job level | `gh workflow run green-04-evidence.yml` then `scripts/ci/capture-green-04-evidence.sh` | pending |
| [AFTER-CI-GATE-MAIN-WINDOW](#after-ci-gate-main-window) | SC-2: the `main` `ci.yml` window with per-lane job conclusions and the nine-of-ten caveat | the `sc2` half of the same receipt | pending |
| [AFTER-ISSUE-231-CLOSED](#after-issue-231-closed) | Issue #231 closed with a comment naming the run ids and the evidence window, proven by re-reading state | `gh issue close 231` then `gh issue view 231 --json state` | pending |

---

## BEFORE-MAIN-RED-MISATTRIBUTION

Status: pending (pre-state obligation — the misattribution must be recorded from the live API before the n>=20 window is dispatched, or the "before" is reconstructed from memory)

The claim to evidence: `main`'s run-level conclusion is `failure`, the single non-success job is
`Admin eval render + probe`, `ci-gate` itself concluded `success`, and `Notify on red ci-gate` was
`skipped` — which per `ci.yml:1645-1655` is itself positive proof that `ci-gate` was not red.
Run `35365693716` (HEAD `bca3ad72`) is the already-known instance; the capture must confirm it
still reads that way and name the run id it actually read.

```bash
gh run view 35365693716 --json databaseId,conclusion,headSha,headBranch,event
gh api repos/szTheory/sigra/actions/runs/35365693716/jobs?filter=latest \
  --jq '.jobs[] | {name, conclusion}'
```

## AFTER-PAGES-LOUD-RED

Status: pending (loud-failure obligation — a Pages script that swallows an error is the exact defect this phase removes, so its loudness must be observed, not asserted)

The claim to evidence: the rewritten `scripts/ci/…pages…` script (plan 240-01) exits non-zero and
names its reason on a non-404 error from `GET /repos/{repo}/pages`, rather than falling through to
the create arm. Captured from the plan 240-01 self-test, which is hermetic and wired into CI.

```bash
bash scripts/ci/publish-pages.test.sh
gh api repos/szTheory/sigra/pages --jq '.html_url, .source.branch'
```

## AFTER-P20-GUARD-OBSERVED

Status: pending (standing-constraint-6 obligation — a guard that has never been seen red is a green gate that verified nothing)

The claim to evidence: `p20-green-04-evidence-step-parity.test.mjs` reports RED against
`test/fixtures/prohibitions/p20-green-04-step-drift.yml` (the known-bad fixture with
`Install Playwright browsers` deleted) and GREEN against the real
`green-04-evidence.yml` / `ci.yml` pair, with the shared prohibitions glob unaffected. The raw
transcripts already exist in `240-02-SUMMARY.md`; this slot flips to `captured` once a CI run id
carries them.

```bash
GSD_PROHIB_SUBJECT=test/fixtures/prohibitions/p20-green-04-step-drift.yml \
  node --test --test-reporter=tap scripts/ci/prohibitions/p20-green-04-evidence-step-parity.test.mjs   # expect EXIT=1
node --test --test-reporter=tap scripts/ci/prohibitions/p20-green-04-evidence-step-parity.test.mjs     # expect EXIT=0
node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs                                      # expect EXIT=0
gh run view <ci-run-id> --json jobs -q '.jobs[] | select(.name=="fast_checks")'
```

## AFTER-GREEN-04-N20

Status: pending (n>=20 dispatch obligation — the dispatch costs 75-100 runner-minutes and must happen on a clean tree at the final committed HEAD, so it is deliberately the last act of the phase)

The claim to evidence: a single `workflow_dispatch` of `green-04-evidence.yml` on `main` produces
twenty jobs named `Generated admin Playwright smoke (GREEN-04 repeat) (1)` … ` (20)`, every one
concluding `success`, every one parented by that one dispatch run, and the receipt's
`sc1.verdict` is `pass`. D-13: the collector refuses to run on a dirty tree, and refuses a run
whose `head_sha` is not `git rev-parse HEAD` — the Phase 216 SC-5 trap.

```bash
gh workflow run green-04-evidence.yml --ref main
gh run list --workflow green-04-evidence.yml --limit 1 --json databaseId,headSha,status
scripts/ci/capture-green-04-evidence.sh \
  --output .planning/phases/240-green-main-evidence-honest-pages-script/240-green-04-receipt.json \
  --run-id <dispatch-run-id> \
  --main-window-start <UTC> --main-window-end <UTC>
jq -e '.sc1.leg_count == 20 and .sc1.verdict == "pass"' \
  .planning/phases/240-green-main-evidence-honest-pages-script/240-green-04-receipt.json
```

## AFTER-CI-GATE-MAIN-WINDOW

Status: pending (per-lane window obligation — "main is green" must be readable from the API run list at the job level, not asserted in prose)

The claim to evidence: over the declared `main` window, `ci.yml`'s `ci-gate` job concluded
`success` on every run, and `flake_attributable_red_count` — the number of `main` runs whose
`Generated admin Playwright smoke` job concluded `failure` — is zero. The verdict is a per-lane job
table, never a run conclusion (D-08). **The nine-of-ten caveat above applies and is emitted into
the receipt as `sc2.caveat`:** `example_unit_smoke` is required by ruleset 14941512 yet absent from
the ten `ci-gate.needs` entries at `ci.yml:1547-1557`.

```bash
gh api "repos/szTheory/sigra/actions/workflows/ci.yml/runs?branch=main&created=<start>..<end>&per_page=100" \
  --jq '.total_count, [.workflow_runs[].id]'
jq -e '.sc2.ci_gate_conclusions.failure == 0 and .sc2.flake_attributable_red_count == 0' \
  .planning/phases/240-green-main-evidence-honest-pages-script/240-green-04-receipt.json
jq -r '.sc2.caveat' \
  .planning/phases/240-green-main-evidence-honest-pages-script/240-green-04-receipt.json
```

## AFTER-ISSUE-231-CLOSED

Status: pending (closure-proof obligation — D-24: the close is proven by re-reading issue state, never by the close command's exit code)

The claim to evidence: issue #231 is `CLOSED`, and the closing comment names the dispatch run id,
the `main` window bounds, the live Pages payload, and the nine-of-ten caveat — so a reader can
re-derive the claim without trusting this ledger. A `captured` slot with no run id is an assertion
in prose wearing the costume of evidence; that is the exact defect p12 exists to catch.

```bash
gh issue comment 231 --body-file <closure-comment.md>
gh issue close 231
gh issue view 231 --json state,closedAt,comments -q '.state'
```
