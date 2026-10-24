---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "164"
subsystem: ci-reliability
status: complete
tags: [ci-reliability, load-recovery, transport-sensitivity, link-form, full-suite, red-first, r15]
requires: ["253-155 (halted; Tasks 1-2 committed)"]
provides:
  - "dry-run --repos-link-form: explicit, scope-checked /repos/ link form for pre-146 --transport-from transports"
  - "summary key link_form_override"
  - "HistoricalTransportLinkFormTests (blind spot #5 positive control + four knob refusals)"
  - "253-155 Task 3 closed by one green block (full dry-run suite 78 tests)"
affects: ["253-165", "253-166", "253-167", "253-168", "253-169", "253-170", "253-171", "253-172"]
tech-stack:
  added: []
  patterns: ["explicit opt-in fake knob instead of capability detection", "R15-FULL-SUITE rule"]
key-files:
  created: []
  modified:
    - scripts/ci/ci-gate-canary-dryrun.py
    - scripts/ci/ci-gate-canary-dryrun.test.py
key-decisions:
  - "R15: fix the TransportSensitivityTests regression with an explicit --repos-link-form knob, not capability detection (fail-open) and not by weakening the default live fake"
  - "R15-FULL-SUITE: a plan changing how a fake emits a Link header, route path, redirect Location or host must run the full dry-run suite with the Ran-N count gated, in the same plan"
  - "R15 supersession: 253-156..163 superseded one-for-one by 253-165..172; their PLAN files stay byte-identical"
requirements-completed: []
estimate: {tokens: 60000, tasks: 2}
actuals:
  tokens: 3200
  tasks: 2
  commits: 2
plan_head_before: 5ef3ec349
plan_head_after: 87b30a3c77e38f136ea561c480b20643c7ec7b4e
duration: "about 2h15m (02:45Z to 04:56Z on 2026-10-20, mostly the 80-minute full suite)"
completed: 2026-10-20
---

# Phase 253 Plan 164: --repos-link-form knob and closure of 253-155 Task 3 Summary

**The dry-run gate gains an opt-in, scope-checked `--repos-link-form` knob. With it, the 253-108 sensitivity transports (375b41138 and its parent) reach artifact_zip again. The default live-policy fake still emits GitHub's `/repositories/1207487684/` form, and a new control shows a pre-146 transport refusing that form. 253-155 Task 3 is closed by one green block: the full dry-run suite ran 78 tests OK, and every listed suite passed.**

Zero GitHub requests, fetches or pushes. No native Playwright launch. The 253-155 SUMMARY stays `status: halted` at its pinned sha256.

## Precondition (Task 1)

All checks held:
- The 253-155 SUMMARY is `status: halted`, sha256 a4b7c954…5045c.
- 42516baf4, fe0730aa5, e38c74aac, 89b8c8618 and 31782efcf are ancestors of HEAD.
- PLANs 164..172 are in HEAD.
- PRESERVATION-R12 and PRESERVATION-R13 pass `shasum -c` (exit 0 each).
- origin/main is 09df342a82e03c3d5d40173c912b70e827f7eadc.
- The tree was clean except config.json.

R15 deadline guard, margin 1 (exit 0):
```
R13 canary deadline guard: margin 1 d, projected check_runs pages 4 of 10, canary deadline 2026-11-02T19:18:40.000Z
```
Positive control, margin 20 (exit 1, as required):
```
R13 canary deadline guard: margin 20 d, projected check_runs pages 14 of 10, canary deadline 2026-11-02T19:18:40.000Z
```
The guard printed the same margin-1 line again at SUMMARY time (04:56Z).

## Task 1: the knob (RED first)

### RED (commit b5313790c, test file only)
I ran `python3 scripts/ci/ci-gate-canary-dryrun.test.py TransportSensitivityTests HistoricalTransportLinkFormTests` in the background under `caffeinate -i -s`, from 02:47Z to 02:51Z. Result: `Ran 6 tests in 263.384s`, `FAILED (failures=6)` (the four refusal subTests count separately), exit 1.

Failing, as expected:
- `test_the_pre_fix_transport_fails_the_live_policy_gate_at_artifact_zip_with_origin_rejected`: `AssertionError: None != 'failed' : {'runner_error': ... }`. The runner exited with `error: unrecognized arguments: --repos-link-form` and printed no JSON.
- `test_the_redirect_fix_transport_passes_the_same_gate`: `AssertionError: None != 0 : {'runner_error': ...}` (same cause).
- `test_the_knob_is_refused_outside_its_scope`: all four subTests show `AssertionError: False is not true : exit 2; stderr ... [--seed-r9-refs] ...`. The literal message was absent and argparse printed usage.

Passing, as expected:
- `test_a_pre_146_transport_refuses_the_default_live_link_form_at_preflight_page_2` passed before the fix. This is the RED positive control.
- `test_the_fix_is_not_the_latest_fix_253_107_commit` passed.
- `test_the_hermetic_mode_result_for_the_pre_fix_transport_is_recorded` recorded `hermetic --transport-from 375b4113805618e48a925d2841ca66545987a2f4^: exit 0, status passed, stop None`.

### Restatements (file:line before → after, ci-gate-canary-dryrun.test.py)
- **(i)** `test_the_pre_fix_transport_fails_the_live_policy_gate_at_artifact_zip_with_origin_rejected`: def :500 → :500.
  - The live_run call at :501 gains `"--repos-link-form"`.
  - The existing assertions :502-510 are byte-unchanged.
  - Two assertions are added at :511-513: `link_form_override == "repos"`, and exactly one check_runs paginated read `{"route": "check_runs", "pages": 3, "next_link_forms": ["repos"]}`.
- **(j)** `test_the_redirect_fix_transport_passes_the_same_gate`: def :512 → :515.
  - The live_run call at :516 gains `"--repos-link-form"`.
  - The existing assertions :517-522 are byte-unchanged.
  - The same two assertions are added at :523-525.
- `test_the_fix_is_not_the_latest_fix_253_107_commit` is unchanged. `test_the_hermetic_mode_result_for_the_pre_fix_transport_is_recorded` is unchanged and moved from :521 to :527; it has no knob.
- New: `class HistoricalTransportLinkFormTests` at :537. Its literal messages are class attributes, so the region between the hermetic test and the next `class` line stays free of the knob string, which the verify block checks.

### GREEN (commit 87b30a3c7, ci-gate-canary-dryrun.py only)
- `--repos-link-form` (store_true). The help names the 253-108 sensitivity transports and the pre-146 /repos/ form.
- After parse_args: `parser.error(REPOS_LINK_FORM_SCOPE)` unless both `--live-policy` and `--transport-from` are given.
- Live allocation branch: the transport under test is already loaded there. If it has `GITHUB_REPOSITORY_ID == 1207487684`, the run:
  - sets `summary.stop` to the second literal;
  - writes it to stderr;
  - raises DryRunError before any request to the fake (nonzero exit).
- `server.repos_link_form` is set beside `server.live`, through a new keyword `start_fake(..., repos_link_form=False)`.
- `_check_runs_link` gets a new first branch for `live and repos_link_form`: `https://{API_HOST}/repos/{REPO}/commits/{sha}/check-runs`. The existing live base line (the /repositories/{GITHUB_REPOSITORY_ID}/ f-string), its docstring and the hermetic line are byte-unchanged. No removed diff line names /repositories/.
- The summary key `link_form_override` is `"repos"` with the knob and `None` otherwise.

The audit checker reported no moved anchor, so the R13 audit record was not touched.

### Task 1 verify block
It ran verbatim, in the background under `caffeinate -i -s`, from 03:03:08Z to 03:26:17Z on AC power. Results:
- TransportSensitivityTests + HistoricalTransportLinkFormTests + DryRunPaginatedCheckRunsTests: `Ran 12 tests in 1345.748s OK`.
- ci-hermetic-live-audit: `Ran 54 tests in 42.182s OK`.
- Every grep, diff, commit-order, sha and checklist check passed.
- **VERIFY-EXIT 0.**

(Before committing the fix, I also ran a GREEN check of the two classes from 02:52Z to 03:02Z: 6 tests OK, VERIFY-EXIT 0.)

## Task 2: 253-155 Task 3 closed as one block

It ran verbatim, in the background under `caffeinate -i -s`. Power source: `Now drawing from 'AC Power'`. Start 2026-10-20T03:26:40Z, end 04:56:08Z. It ran once and was not interrupted. **VERIFY-EXIT 0.**

| Suite | Result |
|---|---|
| ci-gate-canary-dryrun.test.py (full, no filter) | **Ran 78 tests in 4822.597s, OK** (gate ≥ 78) |
| ci-gate-canary-flow.test.py | Ran 23, OK |
| ci-hosted-gate-verify.test.py | Ran 150, OK |
| ci-hosted-transport.test.py | Ran 83, OK |
| ci-gate-canary-recovery.test.py | Ran 5, OK |
| ci-shape-probe.test.py | Ran 19, OK |
| ci-git-publication.test.py | Ran 107, OK |
| ci-hermetic-live-audit.test.py | Ran 54, OK |
| bash ci-gate-canary.test.sh | "local fixture contract passed"; "ci-gate-canary tests passed" |
| bash ci-pr-proof.test.sh | Ran 100, OK |

The diff checks passed:
- Since the 253-155 Task 2 fix commit (89b8c8618), only ci-gate-canary-dryrun.py and its test changed under scripts/ci.
- Nothing under scripts/ci changed after 87b30a3c7.
- The inventory names only the three declared test files, and the positive control (non-empty) held.
- The 253-155 and 253-146 SUMMARYs, PRESERVATION-R12 and R13, config.json and state.json (70229 bytes) are unchanged.

**253-155 Task 3 is closed by this block.** The 253-155 SUMMARY stays halted and byte-identical.

### Post-change inventory (19 lines)
Disposition: every line's content is **unchanged since 89b8c8618**, and there are no new lines. The eight dry-run lines shifted by +44 because of the new tests at :511-513, :523-525 and :537-574.
```
scripts/ci/ci-gate-canary-flow.test.py:271   identity is missing or duplicated (assertIn)      unchanged
scripts/ci/ci-gate-canary-dryrun.test.py:134 def test_the_second_invocation...retained_preflight unchanged
scripts/ci/ci-gate-canary-dryrun.test.py:138 retained_preflight_reverified                      unchanged
scripts/ci/ci-gate-canary-dryrun.test.py:292 native check-run app/source identity is missing    unchanged
scripts/ci/ci-gate-canary-dryrun.test.py:307 control("preflight-repeat", ...retained_preflight) unchanged
scripts/ci/ci-gate-canary-dryrun.test.py:1418 (was :1374) retained_preflight_reverified          unchanged, moved
scripts/ci/ci-gate-canary-dryrun.test.py:1436 (was :1392) def test_the_retained_preflight_is... unchanged, moved
scripts/ci/ci-gate-canary-dryrun.test.py:1437 (was :1393) docstring                              unchanged, moved
scripts/ci/ci-gate-canary-dryrun.test.py:1442 (was :1398) re.search(^retained_preflight...)     unchanged, moved
scripts/ci/ci-gate-canary-dryrun.test.py:1443 (was :1399) assertIsNotNone(match...)            unchanged, moved
scripts/ci/ci-gate-canary-dryrun.test.py:1466 (was :1422) + match.group(0) + "retained_preflight" unchanged, moved
scripts/ci/ci-gate-canary-dryrun.test.py:1474 (was :1430) runner.server_parent_check_runs(...)  unchanged, moved
scripts/ci/ci-gate-canary-dryrun.test.py:1478 (was :1434) assertGreaterEqual(... == name), 1  unchanged, moved
scripts/ci/ci-hosted-gate-verify.test.py:763  "check_runs": native_runs                          unchanged
scripts/ci/ci-hosted-gate-verify.test.py:817  def check_run(                                     unchanged
scripts/ci/ci-hosted-gate-verify.test.py:851  "check_runs": runs                                 unchanged
scripts/ci/ci-hosted-gate-verify.test.py:918  "six producers, mixed app"                         unchanged
scripts/ci/ci-hosted-gate-verify.test.py:1012 identity is missing or duplicated                  unchanged
scripts/ci/ci-hosted-gate-verify.test.py:1061 def runs(                                          unchanged
```
I confirmed this mechanically: for each of the three files, the grep at 89b8c8618 and at HEAD gives identical content once line numbers are stripped.

## R15 decisions recorded (from the plan, for 253-165..172)
- **The knob, not capability detection.** TransportSensitivityTests exist to prove that the live-policy gate catches the 253-104 redirect defect and that the 253-107 fix passes. Both arms use pre-146 transports, so one knob on the same fake keeps the comparison controlled. Capability detection was rejected because it fails open: if the current transport ever lost GITHUB_REPOSITORY_ID, the default gate would quietly switch to the /repos/ form and pass, which is blind spot #5 again. Changing the default fake or dropping pages was rejected because it would weaken the live-policy fidelity.
- **Blind spot #5 stays visible.** `test_a_pre_146_transport_refuses_the_default_live_link_form_at_preflight_page_2` shows that the fix transport, on the default gate, stops with pagination_destination_rejected and never reaches artifact_zip.
- **R15-FULL-SUITE.** A plan that changes how a fake emits a Link header, a route path, a redirect Location or a host runs the full dry-run suite, with "Ran N tests" gated, in the same plan. 253-165, 253-167 and 253-172 inherit the rule.
- **Supersession.** 253-156..163 are superseded one for one by 253-165..172, and their PLAN files stay byte-identical. 253-156's precondition (a complete 253-155 SUMMARY) can never hold.
- **Hard deadline guard.** It is the precondition of 164..169, and the deadline is 2026-11-02T19:18:40Z. The preflight stays at 7 of the R13 table's 16.

## Commits
- b5313790c: test(253-164): historical sensitivity transports get an explicit /repos/ link-form knob (RED)
- 87b30a3c7: feat(253-164): dry-run --repos-link-form isolates the 253-108 sensitivity transports from the /repositories/<id>/ link form

## Deviations from Plan
None in the product or tests. One process note: before committing, I ran an extra GREEN check of the two classes, so that the single feat commit the verify block requires would not need a follow-up. That run changed nothing.

## Threat Flags
None. The knob is a test-harness flag, and it is refused outside its scope (T-253-378).

## Known Stubs
None.

Full Phase 253 verification stays not_started. CIREL-02 stays open; later R15 plans cover it.

## Self-Check: PASSED
- scripts/ci/ci-gate-canary-dryrun.py and its test exist and are committed.
- b5313790c and 87b30a3c7 are ancestors of HEAD.
- Both verify blocks ended with VERIFY-EXIT 0.
