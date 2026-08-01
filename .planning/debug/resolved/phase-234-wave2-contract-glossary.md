---
status: resolved
trigger: "Diagnose and repair deterministic Wave 2 integration failures: CI contract test expects obsolete label; admin glossary bans login where sign-in is canonical."
created: 2026-07-31T22:22:28-04:00
updated: 2026-07-31T22:26:20-04:00
---

## Current Focus
<!-- OVERWRITE on each update - reflects NOW -->

bug_class: Bohrbug (deterministic contract/content mismatches)
hypothesis: "The OAuth CI contract still asserts Phase 233's partitioned `Run library tests`/file-list topology although Phase 234-01 intentionally replaced it with a sole `Run contributor CI gate` `MIX_ENV=test mix ci` owner; components.ex's visible `attr` documentation retains the banned `login` noun outside the preview carve-out."
test: "Completed targeted verification and scoped revert-and-reconfirm."
expecting: "Confirmed: all targeted tests pass after reapplication."
next_action: "Archive this resolved session and commit its durable debug record plus knowledge-base entry without staging unrelated planning changes."

reasoning_checkpoint:
  hypothesis: "Two independent stale contracts cause the failures: OA-01 asserts the retired CI label/command after Phase 234-01, and components.ex:1037 preserves forbidden visible documentation copy."
  confirming_evidence:
    - "The pre-fix OA-01 failure prints the current worker body, which contains `Run contributor CI gate` and `MIX_ENV=test mix ci`, contradicting only the test's `Run library tests` assertion."
    - "The pre-fix glossary failure identifies exactly lib/sigra/admin/components.ex:1037 and the source contains `doc: \"data-testid for the login preview card...\"`."
  falsification_test: "If the updated test's canonical assertions fail against the unmodified workflow, or the glossary still finds login after the targeted doc replacement, this root-cause model is false or incomplete."
  fix_rationale: "Updating the structural test to the intentional Phase 234 single-owner contract preserves OA-01's no-OAuth-exclusion guarantee; changing `login` to `sign-in` directly satisfies the canonical modifier rule without altering selector behavior."
  blind_spots: "This targeted run does not exercise the full database-backed suite; these two files are deterministic source-contract tests and their direct inputs are locally observable."
  candidate_causes:
    - "code: Phase 233 assertions remained in the OA-01 test after Phase 234 workflow topology changed."
    - "data: human-facing attr documentation retained a legacy glossary noun outside the intentional preview carve-out."
  and_gate: "yes — two independent failures require their own contributing stale artifacts; neither correction alone can pass both tests."

## Symptoms
<!-- Written during gathering, then IMMUTABLE -->

expected: "Phase 234 Wave 2 integration tests pass while CI uses the intentional 'Run contributor CI gate' label and admin chrome uses the canonical 'sign-in' terminology."
actual: "phase_58_oauth_oa01_ci_contract_test.exs fails on the renamed CI step label; glossary_test.exs fails because components.ex contains banned 'login'."
errors: "CI contract assertion mismatch for Run contributor CI gate; admin glossary banned noun/modifier login."
reproduction: "mix test test/sigra/planning/phase_58_oauth_oa01_ci_contract_test.exs test/sigra/admin/glossary_test.exs"
started: "Phase 234 Wave 2 integration verification."

## Eliminated
<!-- APPEND only - prevents re-investigating -->

## Evidence
<!-- APPEND only - facts discovered -->

- timestamp: 2026-07-31T22:22:28-04:00
  checked: "Working tree and debug-session inventory"
  found: "No active debug session exists. Unrelated user changes are present in .planning/config.json and .planning/v1.47-MILESTONE-AUDIT.md."
  implication: "The repair must be narrowly scoped and preserve existing changes."
- timestamp: 2026-07-31T22:22:28-04:00
  checked: "Phase 234-01/02 plans, summary, target tests, workflow owner, and preview_pair/1 context"
  found: "234-01 explicitly makes library_tests_shard the sole full-suite owner using literal `MIX_ENV=test mix ci` and the workflow labels that step `Run contributor CI gate`; the OA-01 test still asserts the previous `Run library tests` partition command. The glossary scanner preserves multi-line attr documentation, and components.ex:1037 says 'login preview card' while sign-in is the canonical modifier."
  implication: "Both failures are deterministic stale contracts, not runtime behavior or formatter effects."
- timestamp: 2026-07-31T22:23:20-04:00
  checked: "Pre-fix targeted test run"
  found: "3 tests ran with exactly 2 failures: OA-01 failed only because the job does not include `Run library tests`; the printed current job contains `Run contributor CI gate` and `MIX_ENV=test mix ci`. Glossary failed only on components.ex:1037 `login`."
  implication: "The hypothesis is directly confirmed; the workflow itself and the auth-preview selector values must remain unchanged."
- timestamp: 2026-07-31T22:24:24-04:00
  checked: "Post-fix targeted tests, scoped formatter check, and diff"
  found: "3 targeted tests passed; both edited files passed `mix format --check-formatted`; `git diff --check` passed; the diff only updates the stale structural assertions and one documentation noun."
  implication: "The fixes address the observed contracts without behavior deletion or selector/workflow mutation."
- timestamp: 2026-07-31T22:25:01-04:00
  checked: "Revert-and-reconfirm via path-limited stash"
  found: "With exactly the two repair files stashed, the same 3-test command reproduced the two original failures. After `git stash pop`, the command returned 3 tests, 0 failures."
  implication: "The scoped repair itself is causal for both corrected outcomes."
- timestamp: 2026-07-31T22:26:20-04:00
  checked: "MemPalace availability during archive"
  found: "The mempalace CLI is not installed in this environment."
  implication: "The committed knowledge-base entry is the durable recurrence fallback; semantic indexing was skipped."

## Resolution
<!-- OVERWRITE as understanding evolves -->

root_cause: "The Phase 58 OA-01 CI contract retained retired Phase 233 partition assertions after Phase 234-01 changed the sole library-suite owner to `Run contributor CI gate` / `MIX_ENV=test mix ci`; independently, components.ex's attr documentation used the banned `login` noun rather than canonical `sign-in`."
fix: "Updated the OA-01 structural contract to assert Phase 234's contributor gate and retained its OAuth-exclusion prohibition; changed only the components attr documentation noun to `sign-in`."
verification:
  target_test: {result: pass, command: "mix test test/sigra/planning/phase_58_oauth_oa01_ci_contract_test.exs test/sigra/admin/glossary_test.exs", observed: "3 tests, 0 failures"}
  mutation_check: {result: skipped, reason_if_skipped: "No Stryker or mutation-test configuration is present in this Elixir project."}
  no_op_deletion: {result: pass, deletion_justified_by_rca: false, observed: "Diff adds current CI assertions and replaces one noun; no behavior, branch, assertion, or source removal."}
  adjacent_tests: {result: pass, suites_run: ["test/sigra/planning/phase_58_oauth_oa01_ci_contract_test.exs", "test/sigra/admin/glossary_test.exs", "mix format --check-formatted (both edited files)"]}
  revert_and_reconfirm: {result: pass, bug_returned_on_revert: true, fixed_on_reapply: true}
  guardrail_verdict: accepted
files_changed: ["test/sigra/planning/phase_58_oauth_oa01_ci_contract_test.exs", "lib/sigra/admin/components.ex"]

## Prevention

why_not_caught: "The Phase 234-01 topology change had focused DX contracts, but the older Phase 58 OA-01 contract was not updated in the same change; the glossary test correctly caught the stale documentation noun during Wave 2 verification."
recurrence_guard: "test/sigra/planning/phase_58_oauth_oa01_ci_contract_test.exs now asserts the canonical `Run contributor CI gate` and `MIX_ENV=test mix ci` owner while retaining the OAuth-exclusion prohibition; test/sigra/admin/glossary_test.exs enforces `sign-in` in scanned admin chrome."
branching_5_whys:
  - "code: CI ownership changed from the Phase 233 partition to the Phase 234 contributor alias, but the older topology assertion remained. The updated OA-01 structural test now locks the current owner and command."
  - "data: An attr documentation string used legacy human copy outside the preview carve-out. The existing glossary scanner now guards the canonical modifier."
