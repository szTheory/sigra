## Closing against measured evidence — bounded window, not a permanent claim

This issue was opened by the `notify_release_lane_rot` job (`.github/workflows/ci.yml:1647-1684`)
as the HARD-01 loud signal for a red `ci-gate` on `main`. It is being closed because `ci-gate` has
been measured green across a declared window, and the generated-admin Playwright flake that drove
the original red has been measured away over twenty repeat legs.

Everything below is a job-level read (`filter=latest`), never a run-level conclusion. The receipt
these numbers were transcribed from is
`.planning/phases/240-green-main-evidence-honest-pages-script/240-GREEN-04-EVIDENCE.json`
(schema `sigra.green-04-evidence/v1`), captured on a clean tree at
`head_sha abec92c4b33005e21b550a2f899fe1d1e0f817a1`.

### Evidence window

```
runs 35377050754, 35052017063, 35056270436, 35182589738, 35246681580, 35307612410, 35365693716, 35373550987, 35377012499, 2026-09-16T03:29:55Z..2026-09-18T18:11:54Z
```

Window start is the `created_at` of the oldest `main` `ci.yml` run at or after the Phase 236 flake
fix landed at `b6e889c4` (that run is `35052017063`). Window end is the capture instant. **The claim
this comment makes is scoped to that window and to those run ids. It is not a claim about the
future.**

### SC-1 — twenty repeat legs of the generated-admin lane, all green

A single `workflow_dispatch` of `green-04-evidence.yml` on `main` — **run `35377050754`**, head_sha
`abec92c4b33005e21b550a2f899fe1d1e0f817a1` — produced twenty matrix jobs named
`Generated admin Playwright smoke (GREEN-04 repeat) (1)` … `(20)`. `sc1.leg_count = 20`,
`sc1.verdict = pass`, and every leg concluded `success`. No leg was re-run, re-dispatched or
cancelled.

| repeat | run id | job id | conclusion |
|---|---|---|---|
| 1 | 35377050754 | [105704082603](https://github.com/szTheory/sigra/actions/runs/35377050754/job/105704082603) | success |
| 2 | 35377050754 | [105704082678](https://github.com/szTheory/sigra/actions/runs/35377050754/job/105704082678) | success |
| 3 | 35377050754 | [105704082645](https://github.com/szTheory/sigra/actions/runs/35377050754/job/105704082645) | success |
| 4 | 35377050754 | [105704082720](https://github.com/szTheory/sigra/actions/runs/35377050754/job/105704082720) | success |
| 5 | 35377050754 | [105704082399](https://github.com/szTheory/sigra/actions/runs/35377050754/job/105704082399) | success |
| 6 | 35377050754 | [105704082855](https://github.com/szTheory/sigra/actions/runs/35377050754/job/105704082855) | success |
| 7 | 35377050754 | [105704082791](https://github.com/szTheory/sigra/actions/runs/35377050754/job/105704082791) | success |
| 8 | 35377050754 | [105704082676](https://github.com/szTheory/sigra/actions/runs/35377050754/job/105704082676) | success |
| 9 | 35377050754 | [105704082665](https://github.com/szTheory/sigra/actions/runs/35377050754/job/105704082665) | success |
| 10 | 35377050754 | [105704082865](https://github.com/szTheory/sigra/actions/runs/35377050754/job/105704082865) | success |
| 11 | 35377050754 | [105704082691](https://github.com/szTheory/sigra/actions/runs/35377050754/job/105704082691) | success |
| 12 | 35377050754 | [105704082937](https://github.com/szTheory/sigra/actions/runs/35377050754/job/105704082937) | success |
| 13 | 35377050754 | [105704082772](https://github.com/szTheory/sigra/actions/runs/35377050754/job/105704082772) | success |
| 14 | 35377050754 | [105704082699](https://github.com/szTheory/sigra/actions/runs/35377050754/job/105704082699) | success |
| 15 | 35377050754 | [105704082851](https://github.com/szTheory/sigra/actions/runs/35377050754/job/105704082851) | success |
| 16 | 35377050754 | [105704083995](https://github.com/szTheory/sigra/actions/runs/35377050754/job/105704083995) | success |
| 17 | 35377050754 | [105704084418](https://github.com/szTheory/sigra/actions/runs/35377050754/job/105704084418) | success |
| 18 | 35377050754 | [105704084035](https://github.com/szTheory/sigra/actions/runs/35377050754/job/105704084035) | success |
| 19 | 35377050754 | [105704083987](https://github.com/szTheory/sigra/actions/runs/35377050754/job/105704083987) | success |
| 20 | 35377050754 | [105704084166](https://github.com/szTheory/sigra/actions/runs/35377050754/job/105704084166) | success |

### SC-2 — the `main` window, read per lane

`ci_gate_conclusions`: `{"success": 8, "failure": 0, "skipped": 0}` over `run_count: 8`.
`flake_attributable_red_count` (the number of `main` runs whose `Generated admin Playwright smoke`
job concluded `failure`): **0**.

| main run | run-level conclusion (**not** the verdict) | `ci-gate` job | `Generated admin Playwright smoke` job |
|---|---|---|---|
| [35052017063](https://github.com/szTheory/sigra/actions/runs/35052017063) | failure | success | success |
| [35056270436](https://github.com/szTheory/sigra/actions/runs/35056270436) | success | success | success |
| [35182589738](https://github.com/szTheory/sigra/actions/runs/35182589738) | success | success | success |
| [35246681580](https://github.com/szTheory/sigra/actions/runs/35246681580) | success | success | success |
| [35307612410](https://github.com/szTheory/sigra/actions/runs/35307612410) | success | success | success |
| [35365693716](https://github.com/szTheory/sigra/actions/runs/35365693716) | failure | success | success |
| [35373550987](https://github.com/szTheory/sigra/actions/runs/35373550987) | success | success | success |
| [35377012499](https://github.com/szTheory/sigra/actions/runs/35377012499) | in_progress at capture (only `Admin eval render + probe` still running) | success | success |

The two run-level `failure`s belong entirely to `Admin eval render + probe (hard signal on
push/schedule/dispatch; not in ci-gate)`, which is deliberately outside `ci-gate.needs`. On both of
those runs `Notify on red ci-gate (release-lane-rot)` concluded `skipped` — which is itself positive
proof that `ci-gate` was not red, since that job exists precisely to fire when it is. Reading the
run instead of the job is exactly the misattribution this window was measured to rule out.

### Disclosed caveat: a green `ci-gate` is a nine-of-ten claim

`ci.yml:1547-1557` lists exactly ten `ci-gate.needs` entries: `changes`,
`install_golden_contract`, `library_tests`, `library_tests_dep_off`, `install_smoke`,
`upgrade_smoke`, `example_http_smoke`, `example_playwright_smoke`,
`generated_admin_playwright_smoke`, `fast_checks`. **`example_unit_smoke` is absent from that
list** while being independently required by ruleset `14941512`. So `ci-gate: success` in this
window means nine of the ten required contexts passed and the tenth was never aggregated into the
gate. That gap is disclosed here and is **not** fixed by this work; it is owned by its own tracked
todo (`.planning/todos/pending/2026-07-29-example-unit-smoke-required-but-absent-from-ci-gate-needs.md`).
(`Example unit smoke (ExUnit + ConnTest)` did in fact conclude `success` on run
`35377012499` — but that is a separate observation, not something `ci-gate` aggregated.)

### The Pages publisher can no longer report success while the site stays broken

`scripts/ci/ensure-github-pages-legacy-branch.sh` previously treated any failure of
`GET /repos/{repo}/pages` as "no Pages site configured" and fell through to the create arm, and
matched the PUT-side 403 with an unanchored regex that could match a bare `403` anywhere in an
unrelated error body. It now exits `1`, naming the status, on every non-2xx Pages response except
the single documented case where the workflow's `pages: write` token is not repo-admin and the PUT
legitimately 403s — that one arm stays tolerable and is commented as such. Four stubbed RED
transcripts were captured directly against the script's fake-API stub and are recorded in the
phase's plan-01 summary: `FAKE_MODE=get_403`, `FAKE_MODE=get_500`, `FAKE_MODE=put_422` and
`FAKE_MODE=put_500`, each exiting `1`. The `get_500` body carries the bare digits `403` twice, once
in the request id and once in the message, and the old unanchored match would have read it as
"expected 403, carry on". The script's hermetic self-test now runs as the `Pages legacy-branch
script self-test` step of `fast_checks`, green on `main` run `35377012499`.

### Live Pages payload, re-read at closure time

```json
{"url":"https://api.github.com/repos/szTheory/sigra/pages","status":"built","cname":null,"custom_404":false,"html_url":"https://sztheory.github.io/sigra/","build_type":"legacy","source":{"branch":"gh-pages","path":"/"},"public":true,"protected_domain_state":null,"pending_domain_unverified_at":null,"https_enforced":true}
```

`source.branch` is `gh-pages` and `status` is `built`. This is a point-in-time read and expires;
re-read it rather than quoting this block later.

### This issue can correctly re-open

`notify_release_lane_rot` (`ci.yml:1647-1684`) opens or updates an issue titled exactly
`ci-gate red on main (release-lane-rot)` — the title of this issue — on **any** future `failure`
of `ci-gate` on a non-`pull_request` event. If that happens, the re-file is the machine working
correctly; it does not falsify anything claimed above, because everything above is scoped to the
run ids and the window stated at the top. Nothing here asserts that `main` is permanently green.

Separately, the `release-lane-rot` label this job applies does not currently exist in the
repository. That is a known, separately tracked defect and is named here rather than fixed.
