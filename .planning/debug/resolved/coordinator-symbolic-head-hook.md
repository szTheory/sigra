---
status: resolved
trigger: "Plan 245-19 D-05: diagnose and resolve coordinator_symbolic_head_hook_unsupported for pinned /usr/bin/git 2.50.1 while preserving fail-closed mutation safety"
created: 2026-09-30T10:45:18-04:00
updated: 2026-09-30T11:49:00-04:00
---

## Current Focus
<!-- OVERWRITE on each update - reflects NOW -->

bug_class: Bohrbug, deterministic subprocess executable-selection mismatch
hypothesis: "Confirmed: explicit execution of the pinned Git path fixes the capability probe; supported-only disposable fixtures prevent the prior false success and prove pinned hook enforcement."
test: "Final Plan 245-19 Node, coordinator shell, and pruning shell suites; focused diff/syntax checks; revert-and-reconfirm of the one-line source fix."
expecting: "All deterministic checks pass with the pinned hook rejection and complete integration markers."
next_action: "Resume active Plan 245-19 with `$gsd-execute-phase 245 --gaps-only`; keep Phase 245 incomplete and preserve production fail-closed coordinator behavior."
reasoning_checkpoint:
  hypothesis: "The capability child executes ambient PATH Git because `env` launches an external `git` and bypasses the Bash `git()` function; the fixture then masks the unsupported outcome through an early success exit."
  confirming_evidence:
    - "Unmodified `verify --repo .` with Homebrew-first PATH reports coordinator_symbolic_head_hook_unsupported."
    - "Changing only PATH order to /usr/bin-first reports SUPPORTED for the same disposable hook probe."
    - "Unmodified shell suite returns 0 with only the unsupported message, before its final integration PASS marker."
  falsification_test: "If a poison Git first on PATH is never invoked before the fix, or if /usr/bin-first PATH still reports unsupported, executable selection is not causal. If the suite reaches its final PASS marker on the unsupported branch, the early-exit hypothesis is false."
  fix_rationale: "Execute the already validated absolute Git path for the token-cleared child; require the pinned-runtime fixture to prove supported hook behavior and finish all integration assertions."
  blind_spots: "The full suite has not yet run under the corrected probe; adjacent pruning tests may expose a separate failure."
  candidate_causes:
    - "code: `env ... git` resolves an external executable from PATH despite the pinned shell function."
    - "environment: Homebrew Git 2.41.0 precedes pinned Apple Git 2.50.1 on PATH."
    - "code: the fixture's unsupported branch exits success before integration assertions."
    - "config: a core.hooksPath override could suppress the hook, but the disposable probe configures its own hooks path and the PATH differential changes only executable selection."
  and_gate: "yes for the observed masked success: PATH ordering plus unpinned subprocess creates unsupported capability, and the fixture early-exit hides skipped checks; the capability failure itself requires the first two conditions."

## Symptoms
<!-- Written during gathering, then IMMUTABLE -->

expected: "While the shared coordinator lock is held, an uncoordinated linked-worktree symbolic HEAD change is rejected; local pruning remains fail-closed unless the exact pinned Git proves hook coverage."
actual: "`bash scripts/maintainers/repo-mutation-coordinator.sh verify --repo .` reports `coordinator_symbolic_head_hook_unsupported`. Static inspection shows the probe's `env ... git` child can select ambient PATH Git 2.41.0 while reporting the pinned `/usr/bin/git` 2.50.1. The coordinator test accepts this unsupported result as success and exits before its remaining integration cases."
errors: "coordinator_symbolic_head_hook_unsupported"
reproduction: "Run `bash scripts/maintainers/repo-mutation-coordinator.sh verify --repo .`; the capability probe operates in a disposable fixture. The prior production verification left refs, worktrees, and configuration unchanged."
started: "Surfaced during Plan 245-19 D-05 capability verification on 2026-09-30."

## Eliminated
<!-- APPEND only - prevents re-investigating -->

## Evidence
<!-- APPEND only - facts discovered -->

- timestamp: 2026-09-30T10:45:18-04:00
  checked: "User symptom checkpoint and recommendation review"
  found: "User confirmed the recorded symptom details and authorized proceeding with the recommended exact-executable fix and regression coverage."
  implication: "Proceed with the GSD debug session; preserve D-05 fail-closed behavior and avoid production coordinator installation or ref mutation."
- timestamp: 2026-09-30T10:45:18-04:00
  checked: "Coordinator implementation and ambient/pinned Git identities"
  found: "`repo-mutation-coordinator.sh` defines a `git()` function that invokes `/usr/bin/git`, but the capability mutation at line 105 invokes `env -u ... git`. In this workspace PATH Git is `/opt/homebrew/bin/git` 2.41.0; pinned `/usr/bin/git` is 2.50.1 with the configured digest."
  implication: "The current unsupported result does not measure the pinned executable; change the child invocation to the explicit pinned path and verify it under poisoned PATH."
- timestamp: 2026-09-30T10:45:18-04:00
  checked: "Coordinator integration fixture control flow"
  found: "`repo-mutation-coordinator.test.sh` accepts `coordinator_symbolic_head_hook_unsupported` as a successful result and exits before later lock, lease, and worktree checks. Its fake-PATH probe exercises the shell function but not the `env ... git` child."
  implication: "Make the pinned-runtime test require support and execute the full suite; retain an explicitly separate negative fixture only if the old runtime remains under test."
- timestamp: 2026-09-30T10:51:00-04:00
  checked: "Current tree and project skill discovery"
  found: "The coordinator script and test are clean, while many unrelated project files are dirty. No project skill directories were found and `.planning/config.json` has an empty `agent_skills` map."
  implication: "Modify only the coordinator script, its test, and this debug session; leave all unrelated files untouched."
- timestamp: 2026-09-30T10:53:00-04:00
  checked: "Unmodified coordinator suite and verification command"
  found: "The suite exits 0 in 0.47 seconds with only `PASS: unsupported runtime capability probe refused...`; production `verify --repo .` exits 1 with `coordinator_symbolic_head_hook_unsupported`. Ambient Git is `/opt/homebrew/bin/git` 2.41.0, pinned Git is `/usr/bin/git` 2.50.1."
  implication: "The suite's early success branch demonstrably skips all later checks; compare executable selection by changing PATH order."
- timestamp: 2026-09-30T10:56:00-04:00
  checked: "PATH-order differential on the unchanged disposable capability probe"
  found: "With `/usr/bin:/bin:/opt/homebrew/bin` PATH, the same `verify --repo .` reports `SUPPORTED: coordinator symbolic HEAD hook enforced git=/usr/bin/git version=git version 2.50.1 (Apple Git-155)` and then `coordinator_not_installed`; Homebrew-first PATH reported unsupported."
  implication: "Exact executable selection is causal; production verify only read repository state and mutated the probe's disposable fixture. The next check is an agent-authored regression under poisoned PATH."
- timestamp: 2026-09-30T11:00:00-04:00
  checked: "New PATH-poisoned regression before implementation change"
  found: "The test exits 1 and reports the ambient fake Git's unique `ambient PATH git must not run` message inside the capability probe's captured output. The target fixture remained unchanged."
  implication: "The new regression directly observes the subprocess bypass; it will reject a false fix that merely changes diagnostics or accepts unsupported capability."
- timestamp: 2026-09-30T11:03:00-04:00
  checked: "Same coordinator suite after the one-line executable fix"
  found: "The suite exits 0 and reaches its final lock/lease/worktree marker, but its later direct symbolic-HEAD check uses ambient Homebrew Git and reports `KNOWN LIMITATION` with `symbolic_head=bypassed-hook`."
  implication: "The capability proof is sound; tighten that existing fixture assertion so the pinned runtime itself must reject the direct update in the full suite."
- timestamp: 2026-09-30T11:07:00-04:00
  checked: "Tightened disposable coordinator suite"
  found: "The suite exits 0 and reports `PASS: pinned Git direct symbolic-ref HEAD is gated...` and final `symbolic_head=gated-by-hook; owner tokens, leases, hooks, and inventory verified`."
  implication: "The exact pinned runtime reaches the hook denial and the complete integration checks now run."
- timestamp: 2026-09-30T11:09:00-04:00
  checked: "Plan 245-19 adjacent tests"
  found: "Both Node test files pass all five tests. The disposable pruning shell fixture reaches supported capability and successful local deletion, then exits 1 at `capability-supported local prune did not reach the expected-OID deletion boundary under the coordinator`."
  implication: "The corrected capability gate exposed a previously skipped pruning fixture assertion; diagnose this adjacent failure before accepting the fix."
- timestamp: 2026-09-30T11:12:00-04:00
  checked: "Pruning shell fixture boundary handshake"
  found: "The fixture's fake PATH Git shim emits `delete-boundary` only when it sees `update-ref --no-deref -d`; the operator's validated Bash Git function bypasses PATH as required by D-05. Its output shows deletion completes while the shim never signals."
  implication: "The fixture uses an obsolete interception seam. A disposable chained reference-transaction hook can pause the pinned Git transaction at `prepared` while preserving production pinning."
- timestamp: 2026-09-30T11:20:00-04:00
  checked: "First chained-hook pruning fixture run"
  found: "The suite still timed out while deletion completed; no hook trace was collected."
  implication: "Instrument the disposable hook to determine whether it is invoked and whether its phase/payload predicate matches."
- timestamp: 2026-09-30T11:24:00-04:00
  checked: "Instrumented chained-hook pruning fixture"
  found: "The prior hook recorded `aborted`, then `prepared` and `committed` for deletion of refs/heads/stale/merged with zero new OID. No `preparing` phase appeared for that deletion."
  implication: "The exact deletion predicate matches, but the phase must be `prepared` for this pinned Git transaction."
- timestamp: 2026-09-30T11:27:00-04:00
  checked: "Pruning fixture with pause at actual prepared phase"
  found: "The test received the boundary signal and advanced, then failed because its competing worktree add used ambient Git and did not return the expected coordinator hook rejection."
  implication: "Use pinned Git for the competing mutation proof, consistent with the operator's D-05 executable contract."
- timestamp: 2026-09-30T11:31:00-04:00
  checked: "Pruning fixture with pinned competing worktree add"
  found: "The shell suite exits 0 and reports supported-runtime local deletion, competing-attach rejection, and snapshot object proof."
  implication: "The obsolete PATH interception caused the adjacent failure; the hook-based fixture now covers the real pinned executable. Remove its unsupported-success escape to prevent future skipped assertions."
- timestamp: 2026-09-30T11:36:00-04:00
  checked: "Pruning fixture after removing unsupported-success early exit"
  found: "The suite exits 0 and reaches the final supported-runtime deletion, competing-attach rejection, and object-proof marker."
  implication: "Both coordinator and adjacent pruning fixtures now require the pinned capability and complete their mutation checks."
- timestamp: 2026-09-30T11:38:00-04:00
  checked: "Revert-and-reconfirm red half"
  found: "With only the capability source line reverted, the coordinator fixture exits 1 and captures the ambient fake Git's `ambient PATH git must not run` diagnostic."
  implication: "The source line is necessary for the regression to pass; reapply it and confirm green."
- timestamp: 2026-09-30T11:41:00-04:00
  checked: "Revert-and-reconfirm green half"
  found: "After reapplying the exact one-line fix, the identical coordinator suite exits 0 with pinned hook rejection and the final `symbolic_head=gated-by-hook` marker."
  implication: "The executable selection change is both necessary and sufficient for the targeted regression."
- timestamp: 2026-09-30T11:44:00-04:00
  checked: "Focused diff, mutation runner discovery, shell syntax, and whitespace"
  found: "The source change replaces one executable token without deleting production behavior. Test deletions remove only false-success/ambient-bypass branches. No Stryker configuration exists. `bash -n` and `git diff --check` pass on all three changed scripts."
  implication: "No-op/deletion detector passes; Stryker-specific signal is skipped with reason, while the manual revert mutant is killed by the driving regression."

## Resolution
<!-- OVERWRITE as understanding evolves -->

root_cause: "The symbolic-HEAD probe executed ambient PATH Git 2.41.0 because `env -u ... git` bypassed the validated pinned Bash function, though diagnostics claimed `/usr/bin/git` 2.50.1. The coordinator fixture masked that failed capability by accepting unsupported as success and exiting before lock, lease, and worktree checks. A separate pruning fixture used a PATH Git shim for its pause and competing mutation, which the D-05 pinned Git contract correctly bypassed."
fix: "The capability child invokes the validated absolute Git path after clearing its token. The coordinator fixture poisons PATH, requires pinned hook enforcement and unchanged linked HEAD, and completes the full suite. The pruning fixture pauses through a disposable chained reference-transaction hook, runs the competing mutation with pinned Git, and requires supported capability before proceeding."
verification:
  target_test: {result: pass, command: "bash scripts/maintainers/repo-mutation-coordinator.test.sh", observed: "Poisoned-PATH install proved /usr/bin/git 2.50.1 hook rejection; final symbolic_head=gated-by-hook integration marker passed."}
  mutation_check: {result: skipped, reason_if_skipped: "No Stryker configuration exists for this Bash repository; a manual exact-site revert mutant was killed by the driving regression.", mutant_killed: true}
  no_op_deletion: {result: pass, deletion_justified_by_rca: false, observed: "Production change replaces one executable token and deletes no behavior. Removed test branches accepted unsupported capability and ambient hook bypass as success; their removal strengthens the oracle."}
  adjacent_tests: {result: pass, suites_run: ["node --test scripts/maintainers/prune-stale-branches-admission.test.mjs scripts/maintainers/repo-mutation-coordinator.test.mjs: 5/5", "bash scripts/maintainers/prune-stale-branches.test.sh: supported local deletion, competing attach rejection, 51 snapshotted objects readable"]}
  revert_and_reconfirm: {result: pass, bug_returned_on_revert: true, fixed_on_reapply: true, observed: "Old env ... git line returned ambient fake Git diagnostic; restoring $git_path returned complete gated-by-hook suite pass."}
  guardrail_verdict: accepted
  syntax_and_diff: "bash -n and git diff --check passed for all three changed scripts."
  environment_scope: "Disposable repositories only; no production coordinator installation or ref/config/worktree/origin mutation."
files_changed: [scripts/maintainers/repo-mutation-coordinator.sh, scripts/maintainers/repo-mutation-coordinator.test.sh, scripts/maintainers/prune-stale-branches.test.sh]

## Prevention

why_not_caught: "The capability probe's `env ... git` subprocess bypassed the exact-Git shell function. The PATH-poison fixture covered only calls through that function, and both shell suites accepted unsupported capability as success before running integration checks. The pruning fixture's PATH shim was incompatible with pinned Git and remained untested while the early exit hid it."
recurrence_guard: "A PATH-poisoned coordinator fixture proves no ambient Git subprocess runs, the pinned runtime rejects direct symbolic HEAD mutation, and the complete lock/lease/worktree suite runs. A disposable chained hook gives the pruning fixture a pinned-runtime deletion pause and competing-attach proof. Both suites fail if supported capability is absent."
branching_5_whys:
  - "code: The capability child resolved `git` from PATH instead of executing the configured absolute path; pass the validated executable path directly."
  - "test: The fake PATH test covered only the shell function; extend it across the `env` subprocess boundary."
  - "test control flow: An unsupported capability result returned success and skipped later checks; require the pinned runtime's positive proof before success."
  - "test seam: The pruning fixture relied on intercepting PATH Git, while D-05's pinned executable bypassed it; synchronize through Git's disposable chained transaction hook instead."
