---
status: resolved_offline
created: 2026-11-04
updated: 2026-11-04
parent_session: .planning/debug/phase256-source-lineage.md
goal: find_and_fix_offline
---

## Current Focus

bug_class: Bohrbug (deterministic source/signature mismatch)
hypothesis: Confirmed: source verification used historical patch preimages and stale final-file assumptions instead of the approved retained-plus-diagnostics content.
test: Source regression, exact projected candidate treatment diff, byte-preserved baseline replay, seeded content-guard mutation, adjacent authorization/source-checker/diagnostic tests.
expecting: Independent review approved revision03 implementation and its offline fixture; actual source materialization and adoption feasibility remain unproved.
next_action: Parent records the distinct concrete recovery scope using these reviewed source-proof changes, then proves actual retained-plus-diagnostics source materialization, proposal/adoption closure and one-update feasibility before any hosted route. Plan02 remains halted; no user acknowledgment is needed for the completed offline work.
candidate_causes:
  - data: wrong historical composite patch for selected role lineage
  - config: incorrect base identity selected for cumulative signature comparison
  - code: verifier treats historical changed-line multiset as required final-tree semantics
  - data: required final behavior genuinely missing
and_gate: No; the bad predicates independently reject the source (OR failure branches). All must be corrected for acceptance; they share one root design error in how historical source evidence is interpreted.

## Symptoms

Inherited immutable symptoms from parent session; Plan02 halted with no external spend, both historical environment checks passed, selected composite patch and changed-line signatures failed.

## Evidence

- Read parent session first, terminal Plan02 summary, OFFLINE-RECOVERY, SOURCE-CHECK, selected patch, production environment checker and selected-repair verifier. Existing parent session and all terminal evidence remain untouched.
- No semantic recall tool is available; knowledge-base fallback contains no matching source-signature issue.
- SBFL skipped: this is a deterministic source-data/proof mismatch without per-test coverage or an identified failing test spectrum.
- Production verifier checks exact blobs and separate final-tree environment/diagnostics behavior, then additionally requires historical changed-line multisets in base-to-source diffs.
- probe.py confirmed every one of eight READY-SOURCE final environment blobs equals installed base 970055abcf1ee4e8b5d8ebcf79de0eeecf4f223d. Both retained role cumulative diffs fail environment and common-regression signatures.
- Both roles retain exact helper/GREEN-04 blobs and digest-pinned PostgreSQL images. Their action reports use the supported workspace layout, while the verifier incorrectly requires RUNNER_TEMP.
- The retained phase232 test has evolved to cover recorder-enabled/sequential and combined Mix, browser policy and lockfile-driven cache keys. Requiring the earlier exact whole-file hash would discard useful later coverage.
- The existing positive test substitutes current workspace action/workflow, earlier phase232 content, and complete historical patch responses. It therefore cannot expose the real source-lineage failures.
- The exact Plan01 diagnostic patch (431acdbe4064eb7076ad7085fd24eb0bc80a125cd5894a55f9a6a897e22e7e61) applies to both role files in disposable non-repository directories without Git writes. The projected workflow hashes are candidate 620125b72d509efb5eb03774e3fea8f1d08e4ed0e91a9524c612304c996719e3 and control ed9615a86fa321180021c2bb4ecdb47f18ca736d760173b6b784406a106859a0; diagnostic test hash is identical, 6eb9576ae93e4d5261f94a1b01c8106503cf19db2a616268160716a680947881.

reasoning_checkpoint:
  hypothesis: The verifier rejects legitimate retained-plus-diagnostics trees because it mistakes historical delta lines for required final content, requires an obsolete test blob, and hardcodes one of two supported report layouts.
  confirming_evidence:
    - All eight environment blobs already equal the selected repair in the installed base; base-to-role diffs cannot introduce those same blobs again.
    - The real retained roles pass the environment checker and the exact reviewed diagnostics patch applies to each.
    - The positive fixture replaces all failing real inputs with unrelated bytes/diffs.
  falsification_test: Real retained blobs plus the exact diagnostic patch fail independent final-content checks, or strict final hash pins permit a mutated workflow/action/test/helper to pass after receipt hashes are recomputed.
  fix_rationale: Pin the exact final projected workflow/action/test blobs, retain every reviewed helper/GREEN-04 hash, prove the installed base contains all eight original repair blobs, and retain the ten-path exact common-regression and runtime hashes. This replaces unsuitable historical delta predicates with narrower exact final content checks.
  blind_spots: No new source store/commits or proposal closure may be built in this offline scope. Independent review is required before policy use. Adoption, one-update feasibility and hosted outcomes remain unproven.
  candidate_causes:
    - code: historical-delta predicates and one-layout report check
    - data: selected historical patches and evolved role trees have different preimages
    - config: incorrect base selected (ruled out as primary cause by exact base blobs and ancestry)
  and_gate: No; historical signatures, phase232 whole-file hash and report path are independent rejecting gates, sharing one historical-evidence interpretation error. Addressing only one leaves other rejection branches.

- RED: the revised regression uses real retained action/phase232 blobs, exact reviewed diagnostic projection, and real projected four-path diff; the saved original verifier fails with phase256_environment_repair_blob_not_selected:candidate:test/sigra/planning/phase_232_playwright_economics_test.exs.
- GREEN: strict final environment profile plus exact base-profile readback accepts that projection. Every environment path is mutated with recomputed producer-supplied hashes and rejected; wrong base, changed base helper, common/runtime blob tampering, reference drift and treatment mutation remain rejected.
- The complete projected control-to-candidate diff is independently computed with git diff --no-index from disposable files and matches the unchanged approved four-path treatment signature exactly.
- VERIFICATION.json contains fresh source/test identities, baseline/fixed/mutant outputs, Phase256/Plan10 adjacent tests, source-checker tests, diagnostics tests and diff whitespace checks. No working source revert or Git write was needed; the baseline replay compiles the exact saved pre-fix bytes with the actual source filename.
- Independent review requested changes: the producer duplicates the stale phase232/report predicates before the corrected readback verifier. Review artifact remains immutable; its final digest is 7d9bf8e70712a5c6e260f211e5812e68a2ec2a308fe8fc4be103d90d7772696c.
- The revision02 regression invokes the real producer, bound Git reader and real environment checker with only command transport stubbed over exact immutable/projected bytes. It immediately reproduced an additional preceding failure: _fresh_local_path requires a file by default, but both producer/readback pass the required objects.git directory. The resulting error is fresh_preparation_phase256_source_object_repository_path_invalid. Canonicalizing the disposable fixture root did not change that failure, ruling out a temp-path alias cause.
- Revision02 fix rationale: resolve the repository without the file-only predicate, retain/add explicit directory/symlink/alternate checks, and share the exact base/final environment profile between producer and readback. This corrects inconsistent path typing and prevents producer/readback proof drift; it does not bypass containment or transport checks.
- Revision02 production-path regression passes through _phase256_fresh_preparation_verify_sources and persisted _phase256_verify_source_check, with real contract_git_reader and real environment checker logic (four checker executions across producer/readback). Only subprocess transport is stubbed over retained/projected source bytes and fixture metadata. The temporary metadata directory is not initialized as a repository and contains no Git objects/commits. Its passed fixture receipt is not a Phase256 source proof.
- Revision02 rejects changed report paths, missing report arguments and extra action content even after supplied blob/hunk hashes are recomputed. The saved revision01 producer fails at the directory-as-file predicate; changing only that predicate in memory exposes its stale phase232 blob predicate. The revised producer/readback both pass; disabling the shared final-content guard is killed by the producer regression.
- revision02/VERIFICATION.json records those counterfactuals and fresh adjacent suite/check outputs. Original LOCAL-FIX.patch, LOCAL-FIX.json, PROOF.json, VERIFICATION.json and INDEPENDENT-REVIEW.md were retained unchanged. New revision02 artifacts contain the cumulative and incremental patches with before/after identity records.
- Revision02 re-review (revision02/INDEPENDENT-REVIEW.md, dc443d4c1e460de7543e9bb013cb6ffd8f08ee5d07deb0041356e510b631fbd7) confirmed producer/profile fixes but reproduced acceptance of a symlinked objects/info parent with a valid alternates file outside the object store.
- Revision03 RED: test_contract_git_reader_rejects_symlinked_alternate_components_before_transport fails specifically for objects/info with ValueError not raised. The objects directory and alternates leaf cases already reject. This confirms an incomplete ancestor check, not missing root/leaf validation.
- Revision03 reasoning checkpoint: hypothesis is that checking only objects and alternates misses the intervening info symlink. Falsification is acceptance of any linked component after validating the full component chain, or command transport on rejection. Fix uses one shared canonical, contained, non-symlink directory/file layout checker in reader and both prechecks, before Git discovery. Blind spot remains actual newly materialized store/commit closure, forbidden by this offline scope. Candidate branches are code (incomplete parent validation) and data (valid alternate text behind an external parent); both are needed for this observed bypass. Existing exact content/profile/identity/limit checks stay intact.
- Revision03 GREEN: shared contract_git_alternates_path validates canonical containment and each fixed component's directory/file type and non-symlink status. The reader uses it before construction and before every read; producer and readback use it before root-object discovery. Linked objects, info and alternates paths reject at reader/producer/readback with zero command-transport calls. An already-created reader also rejects links introduced afterward. Normal producer and persisted readback still pass.
- Revision03 verification: saved revision02 security bytes reproduce the objects/info acceptance; fixed code passes; replacing the shared checker with a direct path return makes the regression fail. Fresh bounded Phase256/Plan10, environment checker, diagnostics, finite-policy and diff checks all pass. revision03/VERIFICATION.json binds all three current files. The existing inventory integration was not run because it creates Git objects, outside this no-object-creation scope; no such integration result is claimed.

## Eliminated

- hypothesis: Missing original environment helper/GREEN-04 source or registry pins causes the reported halt.
  evidence: Exact selected eight-file environment profile already exists in installed base; retained roles preserve helper/GREEN-04 hashes and all fifteen digest-pinned PostgreSQL images.
- hypothesis: Merely choose a different base or reapply the historical composite patch.
  evidence: Installed base is an ancestor of both roles and already exactly contains the selected environment profile; reapplying a patch that creates existing helpers cannot establish the intended final content. The evolved phase232 test and later action recorder must remain.

## Resolution

root_cause: The Phase256 source verifier interprets historical deltas/preimages as final source semantics. The original environment repair already exists in installed main, later approved changes evolve phase232/action files, and both supported report layouts are valid; cumulative patch signatures, the earlier phase232 blob and a RUNNER_TEMP-only marker therefore reject valid retained-plus-diagnostics content. The positive fixture hid these defects by substituting old blobs and historical patches.
fix: Locally pin exact retained-plus-Plan01 workflow/action/evolved-test content, require exact eight-file original environment profile in pinned installed base, retain original helper/GREEN-04 hashes and ten-path common-regression/runtime identities, and remove unsuitable historical-delta/single-layout predicates. Share that profile between producer and readback; resolve the object-store directory without a file-only predicate. Share canonical containment/type/symlink validation for every objects.git/objects/info/alternates component in reader and both prechecks, before command transport, and revalidate before each Git read. Replace fixture substitutions with retained content, independently calculated projected diff and full producer/readback coverage. Revision03 independently approved for the implementation and offline fixture; actual source/adoption proof and hosted authority remain unclaimed.
oracle_type: specified (approved retained identities, reviewed exact diagnostics patch, original treatment signature and fail-closed source equality)
verification:
  target_test: { result: pass, detail: real retained-plus-diagnostics producer and persisted readback logic with command transport fixture }
  mutation_check: { result: pass, mutant_killed: true, detail: source-guard removal makes refreshed-hash tampering subtests fail; no dependency added }
  no_op_deletion: { result: pass, deletion_justified_by_rca: true, detail: historical deltas replaced by narrower independent exact final/base blob pins; no acceptance gate bypass }
  adjacent_tests: { result: pass, suites_run: [Phase256ScopeTests, Plan10CandidateOnlyBoundaryTests, ci-playwright-environment-check.test.py, ci-diagnostics-canary.test.py] }
  revert_and_reconfirm: { result: pass, bug_returned_on_revert: true, fixed_on_reapply: true, detail: exact byte-preserved baseline compiled under actual source filename versus current code; live workspace and Git were not reverted }
  guardrail_verdict: accepted
  independent_review: revision01 and revision02 requested changes; revision03 approved implementation and offline fixture only, with actual source proof and hosted authority unclaimed
files_changed:
  - scripts/ci/ci-repaired-comparison.py
  - scripts/ci/ci-repaired-comparison.test.py
  - scripts/ci/ci_metrics_security.py

## Final independent disposition

Revision03 independent review approved the implementation and offline fixture, with no remaining blocker or warning in the scoped changes. Both prior findings are closed: the producer now shares the exact final-content profile, and all fixed object-store path components are validated before transport and each bound Git read. The review is `revision03/INDEPENDENT-REVIEW.md` (SHA256 `aaa7e05664eb0e5165cd4c7cb9171d9079c67bb27feb050a8adefb892cc42de6`).

This is a completed offline diagnosis and local fix, not completed Phase256 acceptance. No actual source store, source commit, production `SOURCE-CHECK`, proposal/adoption closure, hosted workload, mutation, request or measurement was created. Plan02, its terminal summary, original dirty debug file and parent-owned route/state files remain unchanged. The parent assistant acts next to make the separate recovery concrete; the user does not need to repeat facts or acknowledge these local checks.
artifacts:
  - .planning/debug/phase256-source-lineage-investigation/PROOF.json
  - .planning/debug/phase256-source-lineage-investigation/VERIFICATION.json
  - .planning/debug/phase256-source-lineage-investigation/LOCAL-FIX.patch
  - .planning/debug/phase256-source-lineage-investigation/LOCAL-FIX.json
  - .planning/debug/phase256-source-lineage-investigation/revision02/LOCAL-FIX.patch
  - .planning/debug/phase256-source-lineage-investigation/revision02/REVISION02.patch
  - .planning/debug/phase256-source-lineage-investigation/revision02/LOCAL-FIX.json
  - .planning/debug/phase256-source-lineage-investigation/revision02/VERIFICATION.json
  - .planning/debug/phase256-source-lineage-investigation/revision03/LOCAL-FIX.patch
  - .planning/debug/phase256-source-lineage-investigation/revision03/REVISION03.patch
  - .planning/debug/phase256-source-lineage-investigation/revision03/LOCAL-FIX.json
  - .planning/debug/phase256-source-lineage-investigation/revision03/VERIFICATION.json

## Scope and smallest recovery route

1. Independently review the final-content profile change against the pinned original base, both retained roles, the exact Plan01 patch and unchanged candidate treatment. This local fix is ready for that review.
2. If accepted under a distinct recorded recovery decision, use those same retained roles plus only the exact Plan01 diagnostic patch to materialize the two current source commits in the already specified single scoped object store. Keep installed main, common runtime/regression identities and all existing caps unchanged. Do not reapply READY-SOURCE.patch or create reconstruction commits that replay historical repairs.
3. Run the actual new contract-bound two-role source producer, proposal/adoption closure, environment helper replays and single-update/zero-control-preparation-I/O feasibility checks. These remain unproved in this deliberately narrower offline task. Any failure stops before hosted I/O; existing terminal Plan02 and historical receipts stay immutable.

## Lesson and parent-session focus proposal

Historical repair patches identify selected changes; their additions/deletions are not a final-tree oracle once those repairs are in the installed base. Pin independently derived final content for shared repaired files and test the real retained trees. A positive fixture must never return historical patch text in place of a requested actual diff or substitute an old regression-test blob to hide source evolution.

The initial focused test stopped at the readback verifier and therefore missed duplicate producer predicates and a preceding directory/file mismatch. Source-proof changes need a regression through the real producer and its persisted receipt consumer, with stubbing restricted to command transport. Share proof logic so the producer and replay cannot independently drift.

Path isolation requires checking every ancestor, not merely the object directory and final alternate file. A regular leaf behind a symlinked info directory still escapes the source store. Test each component with valid file content behind it and require rejection before command transport; retain a positive normal-layout producer/readback case.

Suggested parent Current Focus after its required preservation: root cause confirmed with three rejecting predicates; strict final-content local fix and regression ready for independent review at LOCAL-FIX.patch/PROOF.json/VERIFICATION.json; keep all source/materialization/hosted routes stopped until review and the distinct recovery decision. No user acknowledgment or per-run approval is needed for the completed offline work.
