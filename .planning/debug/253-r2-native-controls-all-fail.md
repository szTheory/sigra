---
status: diagnosed
trigger: "253-51 R2 native window CR2-DESKTOP-MOBILE-FIRST halted: every reached Playwright test failed unexpectedly, incl. the positive control"
created: 2026-10-14
updated: 2026-10-14
goal: find_root_cause_only
---

## Current Focus

bug_class: Bohrbug (deterministic: positive control failed at an identical 16.7s on desktop AND mobile in R2, and on mobile in 253-40 too; collision control asserts a UI path the app cannot reach)
hypothesis: CONFIRMED (AND-gate fired; 3 contributing causes + 1 by-design evidence loss), see Resolution
next_action: none (diagnose-only). Hand to planner: fix the two control-design defects in the spec, add per-test failure persistence, then re-budget.

reasoning_checkpoint:
  hypothesis: "The halt is caused by two never-passable control designs in admin-eval.spec.ts (positive fills before LiveView joins, so the join re-render wipes the email field and the required-field browser validation blocks submit; collision expects an enumeration-safe flash that the example app never renders because unsafe_validate_unique pre-empts the DB constraint). Each failing row burns a 15s expect timeout, which pushes 16 rows past the 78.4s left after a 24.8s ecto.setup inside the 105000 ms work deadline. The runner discards the error text because the list reporter prints failures only in onEnd, JSON is written only in onEnd, and tempRoot (including --output with error-context/traces) is rmSync'd."
  confirming_evidence:
    - "app-log: positive (desktop L8-20, mobile L240-252) GET /users/register -> CONNECTED :websocket -> MOUNT -> Replied, then ZERO validate/save events before the next test's GET"
    - "app-log: zero ':longpoll' transports -> the held websocket was released before the 2500ms longPollFallbackMs fallback; LiveView did join"
    - "registration_live.ex:35,41 both inputs `required`; app.js:2864 morphdom INPUT handler `s.value !== e.value && (s.value = e.value)`; app.js ~3329 only the focused input is preserved (mergeFocusedInput)"
    - "test 5 control proves `required` blocks phx-submit: L214 validate(email) then L216 POST from form.submit(), with NO 'save' event from its Create-an-account click (empty password)"
    - "collision: L195-199 save -> SELECT TRUE from Ecto.Changeset.unsafe_validate_unique/4 -> Replied in 4ms, no INSERT; user.ex:90 unsafe_validate_unique; ecto changeset.ex:2754 opts=[validation: :unsafe_unique] has no :constraint; sigra auth.ex:1839-1843 email_taken_error? requires constraint: :unique -> {:error, changeset} -> 'Oops' alert, never the 'If this email is available' flash"
  falsification_test: "A preserved per-test error for the positive showing a waitForSelector('[data-phx-session].phx-connected') timeout (instead of expect(alert).toContainText timeout with empty #user_email) would falsify the wipe mechanism; a collision error showing the flash visible but some other assertion failing would falsify cause 2."
  fix_rationale: "N/A (diagnose-only); direction in Resolution."
  blind_spots: "No per-test error text exists for R2 or 253-40 (by design loss). The positive mechanism (join morph wipes non-focused email) is inferred from code + server-side absence of events, not observed in-browser. Dark-board render-bundle row duration was never observed (not reached in R2 or 253-40)."
  candidate_causes:
    - "code (test design): positive fills before readiness release; collision expects unreachable copy"
    - "code (app): unsafe_validate_unique short-circuits Sigra.Auth.register's :email_taken branch in the example host"
    - "config/budget: 105000 ms work deadline includes 24.8s ecto.setup; only 78.4s left for 16 rows"
    - "environment: load avg ~14 on 18 cores (ruled out as primary; see Eliminated)"
    - "tooling: list reporter + onEnd-only JSON + tempRoot rmSync destroy failure text on deadline kill"
  and_gate: "yes: the deadline halt needs BOTH failing controls (each ~15s timeout) AND the setup-inclusive budget; the missing diagnosis needs the deadline kill AND the reporter/tempRoot design."

## Symptoms

DATA_START
- expected: CR2-DESKTOP-MOBILE-FIRST runs 16 frozen tests (admin-eval, admin-eval-mobile, admin-eval-dark projects; positive readiness control passes, deliberate negative controls fail as expected, CLI exit 1 per freeze), all within a 120000 ms window (105000 ms work deadline).
- actual: list reporter, 1 worker. Rows 1-8 of 16 all show ✘ (unexpected): positive "registration waits for explicitly released LiveView readiness" 16.7s (desktop and mobile), "stops when readiness never released" 2.0/2.6s, "fails when readiness wait deliberately broken" 2.1/2.3s, "detects a deliberate same-account collision" 20.0s, "retains the first forced assertion failure trace" 3.5s. Work deadline (105000 ms) reached at ~row 8; CLI exit null; no sanitized report; per-test error text never printed (list reporter prints errors at end).
- app-log shows the collision test reaching the `save` event and the uniqueness query before SIGTERM.
- Host: awake (caffeinate holder in assertions, AC power, host_awake suspended=false), load avg ~14 on 18 cores from unrelated processes.
- Charge now 2150682 / 2687596 ms cap, 7/11 launches, infra retry unused (not eligible: non-infrastructure halt).
- reproduction: NOT allowed natively. Offline only.
DATA_END

## Evidence locations

- .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-NATIVE-EVIDENCE-R2.json
- .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-NATIVE-EVIDENCE-R2.json.raw/CR2-DESKTOP-MOBILE-FIRST/attempt-01/ (test-log.log, app-log.log, setup-log.log, database-absence.log)
- .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-51-SUMMARY.md
- .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-NATIVE-FREEZE-R2.json (frozen selection, env, command)
- scripts/ci/ci-registration-recovery.mjs (runner; how CLI is launched, reporter, env, deadline)
- test/example/priv/playwright/tests/admin-eval.spec.ts, test/example/priv/playwright/helpers/registrationControls.mjs, playwright config
- prior halt: .planning/debug/resolved/253-native-deadline-not-enforced.md; 253-40 evidence (253-LOAD-RECOVERY-NATIVE-EVIDENCE.json.raw) — compare test-log there

## Constraints

- OFFLINE ONLY: no native Playwright runs, no --run-load-recovery, no GitHub writes/push.
- Do not edit the runner, freeze, evidence, or any PLAN file (frozen hashes). Do not touch STATE.md/state.json. Never modify .planning/config.json (pinned).
- Use asdf Node 20.18.1 ($HOME/.asdf/installs/nodejs/20.18.1/bin/node). Delete scripts/ci/__pycache__ after python.
- Diagnose only: deliverable is a Root Cause Report (no fix applied). Commit only this debug file.

## Eliminated

- hypothesis: The negative controls being marked "unexpected" means the runner/spec expectation wiring is broken.
  evidence: playwright/lib/reporters/list.js:182-189 prints ✘ whenever result.status !== 'passed'; expected-vs-unexpected is only the green/red colour, which is stripped in the non-TTY log. The spec declares no test.fail(); the freeze evaluates expectations itself (selection.project_selections[].expected = expected_failure; slot.expected_cli_exit = 1; runner loadR2 check at ci-registration-recovery.mjs:~4180). So ✘ on rows 2/3/5/7/8 is the designed outcome, not a defect. Their short durations (1.5s internal timeouts) match the designed failure points.
  timestamp: 2026-10-14
- hypothesis: The held websocket was never released / LiveView fell back to longpoll and never connected (positive).
  evidence: app-log shows CONNECTED Transport :websocket + MOUNT + Replied for the positive on both desktop (L13-20) and mobile (L245-252); zero ':longpoll' transports anywhere in the log. A connectToServer() only happens after release(), and MOUNT requires a phx_join from the page, so release happened and the page's mocked socket opened (playwright-core webSocketMockSource _apiConnect/_ensureOpened).
  timestamp: 2026-10-14
- hypothesis: Host load (avg ~14 / 18 cores) or host sleep caused the failures.
  evidence: setup/test/drop max_tick_gap_ms 2-4, suspended=false, wall==exec 107343 ms. Failures are deterministic duration signatures (16.7s identical desktop+mobile in R2 and mobile in 253-40 = 15s expect/action timeout + ~1.7s), not load jitter. Load may inflate setup (24.8s) but does not cause the assertion failures.
  timestamp: 2026-10-14

## Evidence

- timestamp: 2026-10-14
  checked: R2 test-log.log vs 253-40 test-log (253-LOAD-RECOVERY-NATIVE-EVIDENCE.json.raw/CR-DESKTOP-MOBILE-FIRST/attempt-01/test-log.log)
  found: Same 8 rows both runs. Positive: R2 16.7s/16.7s; 253-40 12.6m (desktop, pre-deadline-fix hang) / 16.7s (mobile). Collision: R2 20.0s, 253-40 17.8s. Negatives 1.8-2.8s.
  implication: Positive and collision failures are reproducible across two windows; not transient.
- timestamp: 2026-10-14
  checked: freeze R2 selection/slot vs current spec + config
  found: Spec blob pinned (16be5032...); argv --workers=1 --retries=0 --trace=retain-on-failure; config playwright.registration-recovery.config.ts inherits production reporters [list, html, json(SIGRA_PLAYWRIGHT_JSON)], expect.timeout 15000, actionTimeout 15000, timeout 60000. No test.fail() annotations; expectations are runner-evaluated.
  implication: 16.7s = one 15s timeout + ~1.7s of goto/setup. No freeze/spec mismatch.
- timestamp: 2026-10-14
  checked: app-log.log positive control (desktop L8-20; mobile L240-252)
  found: GET /users/register -> Sent 200 -> CONNECTED :websocket -> MOUNT RegistrationLive -> Replied in 1-2ms, then NO HANDLE EVENT (no validate, no save) before the next test's GET /users/register. No held-positive email appears anywhere in the log.
  implication: Readiness release and LiveView join both happened; the submit never produced a phx-submit "save".
- timestamp: 2026-10-14
  checked: spec positive flow (admin-eval.spec.ts:271-357) + helpers/registrationControls.mjs runHeldRegistrationControl
  found: Order is waitForHold -> fill(email, password) WHILE HELD (pre-join) -> assertNoPost -> release -> waitUntilReady -> submit -> assertSuccess(expect alert toContainText 'Account created successfully!').
  implication: Fields are filled before LiveView's join render patches the form.
- timestamp: 2026-10-14
  checked: test/example/priv/static/assets/js/app.js (bundled LiveView 1.1.28 / morphdom)
  found: L2864 morphdom INPUT handler sets `s.value = e.value` when it differs; DOMPatch (~L3329) preserves only the focused input (mergeFocusedInput) and morphs all others. Server renders email from an empty changeset (no value attr).
  implication: On join, the non-focused email input is reset to "" (password, focused last by fill, survives).
- timestamp: 2026-10-14
  checked: test/example/lib/example_web/live/registration_live.ex:35,41
  found: Both email and password inputs are `required`.
  implication: Clicking "Create an account" with empty email triggers browser constraint validation; no submit event, so no phx-submit "save" -> assertSuccess waits 15s -> 16.7s.
- timestamp: 2026-10-14
  checked: app-log test 5 (forced trace) L200-229 as an in-run positive control for the `required` mechanism
  found: validate(email) at L214, then POST /users/log_in at L216 (from the explicit form.submit()), with NO "save" event from the preceding Create-an-account click (password left empty by design).
  implication: Proves in this very run that a click with an empty required field emits no phx-submit to the server.
- timestamp: 2026-10-14
  checked: collision control app-log L175-199 (desktop) and L410-432 (mobile)
  found: First registration succeeds (INSERT users, POST /users/log_in 302). Second: save -> `SELECT TRUE FROM auth.users ... ↳ Ecto.Changeset.unsafe_validate_unique/4` -> Replied in 4ms, no INSERT.
  implication: Duplicate is rejected by the pre-insert unsafe validation, not by the DB unique constraint.
- timestamp: 2026-10-14
  checked: test/example/lib/example/accounts/user.ex:87-95, deps/ecto/lib/ecto/changeset.ex:2754, lib/sigra/auth.ex:164-191 and 1839-1843, registration_live.ex:131-144
  found: unsafe_validate_unique error opts = [validation: :unsafe_unique, fields: [:email]] (no :constraint); Sigra.Auth.register maps to {:error, :email_taken} ONLY when an :email error has constraint: :unique; otherwise {:error, changeset}. RegistrationLive renders the enumeration-safe flash only on :email_taken; on changeset it renders "Oops, something went wrong!" + field error.
  implication: The collision control's assertion `getByText('If this email is available, your account has been created...')` is unreachable in the example host -> 15s expect timeout -> 20.0s. Assertion added in 35b493540 (253-16); unsafe_validate_unique present since 2f1790e8f (April). The control has never been passable.
- timestamp: 2026-10-14
  checked: R2 evidence attempt timings (253-LOAD-RECOVERY-NATIVE-EVIDENCE-R2.json)
  found: setup (mix ecto.setup) 24,793 ms; app boot ~1,850 ms; Playwright CLI 78,357 ms then SIGTERM (timed_out=true); drop 891 ms; exec=wall=charged 107,343 ms. Sum of 8 completed rows = 65.9s; ~12.5s = CLI start, chromium+webkit launches, and partial row 9 (mobile collision, killed after its uniqueness query at app-log L432 / SIGTERM L435).
  implication: Only ~78.4s of the 105,000 ms work deadline is available to 16 rows because ecto.setup and app boot are charged to the same deadline.
- timestamp: 2026-10-14
  checked: runner runHeldLoadRecoverySlotR2 (scripts/ci/ci-registration-recovery.mjs:4183-4345) + playwright/lib/reporters/{list,line,json}.js
  found: CLI receives `--output=<tempRoot>/playwright-output`, JSON via SIGRA_PLAYWRIGHT_JSON=<tempRoot>/playwright-report.json, html to <tempRoot>/html-report. json.js writes only in onEnd (L60, L232); list.js onTestEnd prints just the status row (L163-192), failures only in base.js epilogue (L258-266, onEnd). On timeout the runner throws before reading the report; only setup/app/test/drop logs + database-absence are copied to rawAttempt; `fs.rmSync(tempRoot)` at L4342 deletes playwright-output (error-context.md, trace.zip written per-test at test end).
  implication: Per-test error text is discarded by design whenever the CLI is killed. line.js onTestEnd (L95-102) prints formatFailure inline for unexpected outcomes.

## Resolution

root_cause: "AND-gate (3 contributing causes): (1) POSITIVE control design defect: admin-eval.spec.ts fills email+password while the LiveView connection is held (before join); on release the join render morphs the form and resets the non-focused email input to the server's empty value (app.js:2864 morphdom INPUT handler; only the focused password survives), so the click on 'Create an account' is blocked by the `required` constraint (registration_live.ex:35), no phx-submit 'save' is sent (app-log: no events after MOUNT), and assertSuccess times out after 15s => 16.7s on desktop and mobile. (2) COLLISION control asserts an unreachable UI: the example host's User.registration_changeset runs unsafe_validate_unique (user.ex:90), whose error lacks constraint: :unique, so Sigra.Auth.register returns {:error, changeset} instead of :email_taken (auth.ex:164-191,1839-1843) and the page never shows 'If this email is available...' => 15s expect timeout => 20.0s. (3) BUDGET: the 105000 ms work deadline also covers ecto.setup (24.8s) + app boot (~1.9s), leaving 78.4s for 16 rows; with each of the 6 positive/collision rows burning a ~15s timeout the window is infeasible, so the CLI was SIGTERM'd during row 9 (exit null, no JSON). Plus a by-design evidence loss: list reporter + onEnd-only JSON + rmSync(tempRoot) discard every per-test error on a deadline kill. The ✘ marks on negative controls are NOT a defect (list.js marks any non-passed status ✘; expectations are runner-evaluated)."
fix: "(not applied, diagnose-only) see return report Suggested Fix Direction"
verification: ""
files_changed: []
