---
status: resolved
trigger: "Phase 253-40 halt: scripts/ci/ci-registration-recovery.mjs runLoggedTree / --run-load-recovery did not enforce the 120000 ms native Playwright work deadline for slot CR-DESKTOP-MOBILE-FIRST — the Playwright CLI ran ~29 min (load avg ~12) until manually SIGTERMed; cleanup then exceeded its deadline and the owned DB drop failed."
created: 2026-10-14
updated: 2026-10-14
phase: 253
---

## Symptoms

- **Expected:** `--run-load-recovery` slot CR-DESKTOP-MOBILE-FIRST is bounded by its frozen 120000 ms command reservation. At the reserved work deadline the runner kills the whole Playwright process tree, runs owned cleanup within its 15000 ms reserve, drops the owned DB and writes the absence receipt.
- **Actual:** the Playwright CLI (`--project=admin-eval --project=admin-eval-mobile --project=admin-eval-dark`, launch 6) ran about 29 min with no runner kill. The test log shows one control hung 12.6 min and another 15.4 min. An operator sent SIGTERM to the CLI child. After that, runner cleanup exceeded the cleanup deadline, the DB drop failed, and there was no JSON report, no absence receipt and 0 of 16 rows. Charged 1765488 ms against a 120000 ms window, which also exceeds the D-19 cap of 1200000 ms.
- **Errors:** ledger stop_reason "native Playwright command reached the reserved work deadline; owned cleanup exceeded the 120,000 ms command limit; database drop failed at cleanup deadline; ..." (see evidence JSON).
- **Timeline:** first real native use of the 253-39 four-slot load-recovery runner (commit 2030ef101). 253-38 (da586d13f) changed `runLoggedTree`: it no longer cancels SIGKILL when the child exits first, it gained an abort `signal` option, and it has pid/group_signals/descendants_reaped fields. Synthetic teardown tests passed, but one SIGKILL-escalation test flaked once under parallel load in 253-39.
- **Reproduction:** native only. Do NOT reproduce natively. Reproduce OFFLINE with synthetic process trees, e.g. a child that ignores SIGTERM, a grandchild in a new session or process group like Chromium/webServer, or a busy event loop. The host had a load average of about 12.

## Evidence locations

- `.planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-NATIVE-EVIDENCE.json`
- `.planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-NATIVE-EVIDENCE.json.raw/CR-DESKTOP-MOBILE-FIRST/*/{app,drop,setup,test}-log.log`
- `.planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-40-SUMMARY.md`, `253-39-SUMMARY.md`, `253-38-SUMMARY.md`
- Code: `scripts/ci/ci-registration-recovery.mjs` (`runLoggedTree`, `--run-load-recovery` slot runner), `scripts/ci/ci-registration-recovery.test.mjs`

## Constraints

- OFFLINE only: no native Playwright CLI runs, no browser, no GitHub writes (no push/PR/dispatch).
- Prove any fix with synthetic process-tree tests under Node 20.18.1 (`ASDF_NODEJS_VERSION=20.18.1 asdf exec node --test ...`).
- `.planning/config.json` is a pinned uncommitted operator edit whose SHA-256/blob is asserted by the harness. Never modify, stage, commit or revert it.
- Do NOT edit or rewrite existing 253 PLAN/SUMMARY/evidence files; halted evidence stays preserved. Do NOT run gsd state/roadmap writer verbs (they flatten this phase's custom STATE.md/state.json).
- Delete `scripts/ci/__pycache__/` if created. Leave the tree clean except config.json.

## Current Focus

bug_class: Bohrbug in code, triggered by a deterministic environment condition (host system sleep / DarkWake cycling). Not a load race.
hypothesis: CONFIRMED. The host went into Maintenance Sleep three times during the native window and only ran in short DarkWake windows. The runner enforced its work deadline with one long relative setTimeout. That timer never fired during the run (it fired only after the operator's SIGTERM made the CLI exit). Nothing in the runner noticed the wall-clock overrun or held a sleep assertion. Cleanup then got a 1 ms drop budget because the window was already overspent, so the owned DB was orphaned.
reasoning_checkpoint:
  hypothesis: "The 120000 ms work deadline was not enforced because the macOS host slept repeatedly during the run (pmset: sleep 04:22:28-04:34:52, 04:35:37-04:51:00, 04:52:01-05:04:34 local). runLoggedTree relies on a single relative setTimeout armed once; across system sleep/DarkWake that kernel wait never elapsed. The runner had no wall-clock check, no periodic watchdog, no suspension detection and no sleep assertion."
  confirming_evidence:
    - "pmset -g log: sleeps of 744 s, 923 s and 753 s inside the run. Playwright's 'hung' controls took 12.6m (744 s sleep + about 10 s awake) and 15.4m (923 s sleep + about 3 s awake). The durations match to the second."
    - "app-log ~U timestamps (08:34:57Z, 08:35:16Z, 08:51:01Z) fall exactly inside the DarkWake windows 04:34:52-04:35:37 and 04:51:00-04:52:01 local."
    - "test_command.group_signals == ['SIGTERM','SIGTERM'] with no SIGKILL, timed_out true and duration_ms 1745192. This is only reachable when 'close' -> reap() ran first (SIGTERM #1) and the overdue deadline timer fired afterwards (expire SIGTERM #2). If the timer had fired while the CLI was alive, the 250 ms escalation would have recorded SIGKILL."
    - "drop_command timeout was Math.max(1, Math.min(7000, cleanupRemaining - 5000)) == 1 ms because cleanupRemaining was negative. That explains 'database drop failed at cleanup deadline' with duration 2 ms."
  falsification_test: "If the host had stayed awake for the whole window (no pmset Sleep entries between launch and the SIGTERM), or if group_signals had contained SIGKILL, this hypothesis would be wrong."
  fix_rationale: "(1) Hold a macOS PreventSystemSleep/idle assertion (caffeinate -i -s -w <runner pid>) for every native load-recovery window, so the host cannot sleep under the run. (2) Replace the single armed timer with a short-interval watchdog that compares max(monotonic elapsed, wall-clock elapsed) to the deadline. The first tick after any resume kills the tree. It also records suspension: tick gaps or wall-vs-monotonic skew beyond 5 s. (3) The slot runner treats detected suspension or wall overrun as terminal and charges the larger of wall and monotonic time. (4) The owned DB drop always gets a bounded cleanup floor, so an already-terminal overrun cannot orphan the database. (5) Removed the duplicate-SIGKILL race (cached 'killed' flag) that caused the 253-39 flake."
  blind_spots: "The exact XNU mechanism that kept the relative kevent wait from elapsing in DarkWake (absolute vs continuous timebase, DarkWake timer deferral) is not proven offline, because the machine cannot be slept from here. The fix does not depend on it: caffeinate prevents the condition, and the watchdog plus wall clock catches it on the first tick that runs."
  candidate_causes:
    - "environment: host system sleep / DarkWake cycling during the run (CONFIRMED by pmset log)"
    - "code: single relative setTimeout deadline with no wall-clock re-check, no watchdog and no sleep assertion (CONFIRMED by group_signals ordering)"
    - "code: drop budget collapses to 1 ms after overrun (CONFIRMED, secondary)"
    - "environment: CPU starvation at load avg 12 (ELIMINATED, see Eliminated)"
  and_gate: "yes. The failure needed the host to sleep (environment) AND the runner to rely on a timer with no wall-clock or suspension guard and no sleep assertion (code). Either guard alone would have bounded the window."
next_action: none. Fix committed in cf578a567; native confirmation is deferred to the next re-frozen load-recovery plan (the offline-only constraint applies).

## Evidence

- timestamp: 2026-10-14
  checked: 253-LOAD-RECOVERY-NATIVE-EVIDENCE.json attempts[-1].test_command and drop_command
  found: "test_command: timed_out=true, signal=SIGTERM, duration_ms=1745192, group_signals=[SIGTERM,SIGTERM], descendants_reaped=true. drop_command: timed_out=true, duration_ms=2, group_signals=[SIGTERM]."
  implication: "No SIGKILL was ever sent. A second SIGTERM can only come from reap() (on close) followed by expire() (the deadline timer). So the deadline timer fired only after the operator's SIGTERM, about 29 min late. The drop was given a 1 ms timeout."
- timestamp: 2026-10-14
  checked: test-log.log and playwright.config (test timeout 60000 ms)
  found: "Controls 'hung' for 12.6m and 15.4m, far beyond Playwright's own 60 s test timeout. Playwright measures with performance.now (monotonic)."
  implication: "Playwright's own timers also did not bound these tests. That points to a host-wide time discontinuity, not a runner-only bug."
- timestamp: 2026-10-14
  checked: app-log.log ~U[...] wall timestamps
  found: "Activity at 08:34:57Z, 08:35:16Z, then nothing until 08:51:01Z-08:51:02Z."
  implication: "There is a 16-min wall-clock gap with no app activity at all."
- timestamp: 2026-10-14
  checked: "pmset -g log, 2026-10-14 04:20-05:06 -0400"
  found: "Sleep 04:22:28 (744 s) -> DarkWake 04:34:52 (45 s) -> Maintenance Sleep 04:35:37 (923 s) -> DarkWake 04:51:00 (61 s) -> Sleep 04:52:01 (753 s) -> DarkWake 05:04:34. The evidence was committed at 05:04:42."
  implication: "The host was asleep for about 40 of the 43 wall minutes. The hung durations equal the sleep durations: 744 s + test time = 12.6m and 923 s + test time = 15.4m. The app timestamps fall inside the DarkWake windows. ROOT TRIGGER = system sleep."
- timestamp: 2026-10-14
  checked: runLoggedTree source (da586d13f)
  found: "The deadline is a single setTimeout(timeoutMs) armed once. There is no wall-clock re-check, no periodic watchdog, no suspension detection and no sleep assertion. The reap() poll caches 'killed' at reap start, so if escalationTimer pushes SIGKILL meanwhile, the poll pushes a second SIGKILL. That gives group_signals [SIGTERM,SIGKILL,SIGKILL], which is the deepEqual flake under load in the abort test."
  implication: "Code defects: deadline enforcement cannot survive a host time discontinuity, and there is a duplicate-SIGKILL race (the 253-39 flake)."
- timestamp: 2026-10-14
  checked: runLoadRecoverySlot finally block
  found: "drop timeout = Math.max(1, Math.min(7000, cleanupRemaining - 5000)). After an overrun this is 1 ms, so the owned DB is always orphaned."
  implication: "This is a secondary defect. Once work overran, the cleanup reserve could never drop the owned database."
- timestamp: 2026-10-14
  checked: baseline offline suite under Node 20.18.1
  found: "59/59 pass in scripts/ci/ci-registration-recovery.test.mjs."
  implication: "The existing synthetic tests never model a clock discontinuity."

- timestamp: 2026-10-14
  checked: "Synthetic regression tests under Node 20.18.1, RED against HEAD~ runner"
  found: "All 6 new runner/slot tests fail on the pre-fix code. The wall-jump and both-clock tests hang until the 120 s timer. The parallel escalation test reproduced the duplicate SIGKILL."
  implication: "The tests reproduce the defect classes offline."
- timestamp: 2026-10-14
  checked: "Hang found during stress runs: node:test file process never exited"
  found: "Active-handle dump showed a whenTreeReady FSEventWrap plus ProcessWrap still pending. On macOS the FSEvents stream starts asynchronously, so a tree.json rename that lands first is never reported. This is a second source of the 253-39 load flake."
  implication: "whenTreeReady now backs fs.watch with a 20 ms existence poll and settles once."

## Eliminated

- hypothesis: "CPU starvation at load average 12 delayed the runner's timer by 29 min"
  evidence: "The app served requests in milliseconds whenever the host was awake. The gaps line up exactly with pmset sleep intervals, not with load."
  timestamp: 2026-10-14
- hypothesis: "Process-group kill failed (ESRCH) because Chromium/webServer run in their own sessions"
  evidence: "No SIGKILL was ever attempted (group_signals has only SIGTERMs). The kill path was never reached during the run, and descendants_reaped=true at the end."
  timestamp: 2026-10-14

## Resolution

root_cause: "AND-gate (two contributing causes). (1) Environment: the macOS host went into Maintenance Sleep three times during the native window (744 s, 923 s, 753 s) and ran only in short DarkWake windows. (2) Code: runLoggedTree enforced the work deadline with one relative setTimeout, with no wall-clock re-check, no suspension detection and no sleep assertion. The timer did not fire until the operator's SIGTERM closed the CLI. Secondary: after the overrun the owned DB drop got a 1 ms budget (Math.max(1, cleanupRemaining - 5000)). Separate flake: the reap poll cached a 'killed' flag, so it could send a duplicate SIGKILL; also whenTreeReady relied on fs.watch alone, which can miss the rename under load on macOS."
fix: "runLoggedTree: a watchdog of at most 250 ms checks max(monotonic, wall) elapsed against the deadline and records suspended / wall_duration_ms / max_tick_gap_ms. It sends SIGKILL at most once. Clocks and kill are injectable. holdHostAwake holds caffeinate -i -s -m -w <runner pid> for each load slot, acquired before the predebit. runLoadRecoverySlot bounds stages by both clocks, halts on suspension, charges max(monotonic, wall), and floors the owned drop and absence query at 5000 ms after a terminal overrun. Verifier: the charge must equal max(execution, wall), and suspension rejects the attempt. Test helper whenTreeReady: watch plus poll."
verification:
  oracle_type: "specified (deadline, single SIGKILL, charge equals max clock, suspension halts, drop floor)"
  red_before_fix: "6/6 new tests fail against the pre-fix runner"
  suite: "81/81 pass, scripts/ci/ci-registration-recovery.test.mjs + ci-playwright-load.test.mjs, Node 20.18.1"
  stability: "38 full-suite runs under load (up to 10 concurrent suites + 6 CPU burners): 0 failures, 0 hangs, no new orphan processes"
  mutation: "6 mutants (wall clock ignored, drop floor removed, suspension not halting, unconditional SIGKILL, cached-flag poll, holdAwake skipped) are all killed"
  native: "NOT run (offline-only constraint). The committed load-recovery freeze pins the old runner blobs, so it will refuse to run until a new plan re-freezes. That is intended."
  guardrail_verdict: accepted
files_changed: [scripts/ci/ci-registration-recovery.mjs, scripts/ci/ci-registration-recovery.test.mjs]
commit: cf578a567
