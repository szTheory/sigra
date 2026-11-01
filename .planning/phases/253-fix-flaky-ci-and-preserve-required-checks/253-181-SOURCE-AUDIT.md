# Phase 253 Plan 181 source audit

Planning only. Entry was clean HEAD `b6bc388d562e15982964a9846f0fdd196ae8dc10`. This work adds one plan with three tasks and its two new planning records. Existing source, PLANs, SUMMARYs, reviews, evidence and shared state remain unchanged during planning. Root owns final independent review, shared routing and commits.

## Actual gaps and direct repair mapping

No Phase253 VERIFICATION.md exists. The current source is `253-178-EXECUTION-RECORD.json`, its halted SUMMARY/review and the exact diagnostics retained at `refs/gsd/phase253-execution178-diagnostics`, commit `9ca5fedd70f90e442976857ce1d45858a6693808`.

| Recorded gap | Inspected source and actual failure | New ownership and proof |
|---|---|---|
|178-REVIEW-01|expected_plan_amendment(168) replaces only the first automated body's extracted174 verifier. Independent amend_entry_plans repeats the omission. Saved probe counts are[1,0] across2bodies.|181T1: both original bodies get fail-closed receipt prefixes; real bridge/rehashed placement attacks and per-body refusal spies.|
|178-REVIEW-02|validate_sdk_copy_report hashes stdout but does not parse it or check argument/identity/manifest semantics. Retained report uses `not JSON`, arguments[bogus],sdk_identity{} and fake digest and was accepted.|181T2: replay exact fabrication, parse all four raw objects, exact queries/actual installed identity/committed manifest and redundant-field consistency; independent rehashed attacks.|
|178-REVIEW-03|run_sdk_copy coerces index rows into a dictionary and checks final incomplete/halts without exact180unique ID coverage. A missing completed row can preserve those counts.|181T2: exact181unique IDs before coercion in both stages, duplicate/missing/unknown/replaced-row negatives and cross-query totals. 181 adds one actual plan, so181 is the new exact universe.|
|178-TEST-01|test_nested_173_review_requires_original_location_schema_and_findings copies historical files to a directory without Git. check_historical_inputs runs git show for frozen175 commits. Full suite:16run/15pass/1error,exit1,167.106s.|181T1: real local Git/object fixture and intended positive/schema-negative checks; no production Git bypass. 181T3 reruns the full suite with all16retained and4new tests.|
|Continuation remains blocked|179 requires completed178;178 is halted. Existing180 and helper specify180pins/24halts and list178 as a proof owner. Those instructions cannot be executed honestly from the current state.|181T3: preserve original179/180 bytes before scoped execution-time amendments; repair181→existing179→existing180; exact181pins/25halts/73targets, no178owner/disposition. No duplicate acceptance/bridge plans.|

The helper/test hashes at entry match the exact preserved halted178 candidate. The historical review and failure are inputs, not a completed repair. The diagnostics' fifteen Git blobs are durable; temporary paths are not the only recovery location.

## Multi-source coverage

Covered means assigned instructions exist in this additive repair plus the retained phase plans. It does not mean implementation, hosted acceptance or whole-phase verification passed. No item below is waived or reduced.

| Source | ID / feature | Plan ownership | Status and practical limit |
|---|---|---|---|
|GOAL|Selected failures reproduced/fixed; real failures prevent green checks|Original diagnosis/control/gate plans;181 removes the local validator/routing blocker before179/180/168–172|COVERED; registration cause and hosted acceptance stay open|
|REQ|CIREL-01 deterministic selected-failure checks without retry/sleep masking|Existing native diagnosis/control evidence and168/172 honest disposition;181 preserves partial_not_reproduced|COVERED; this repair cannot prove registration reproduced/fixed|
|REQ|CIREL-02 names/useful coverage and injected failure/cancel/missing/skip refusal|Existing03–06 implementations;181 strict local consumers; existing170/171 hosted proof|COVERED; real hosted proof remains required|
|RESEARCH|Immutable baseline, complete replay, separate versioned correction|Original01 diagnosis;181 historical175/178 byte/commit bindings and preservation|COVERED; no Phase252 artifact changes|
|RESEARCH|Context before redaction cap; incomplete/unknown stays unknown|Existing collector/diagnosis plans;181 retains original missing-evidence outcomes|COVERED; no new collection window|
|RESEARCH|Standard-library helpers and one existing gate policy|181 existing Python/unittest/Git helper; existing verdict owner|COVERED; no package or competing gate|
|RESEARCH|Exact-five producers, nonempty native reports, skip/body parity|Existing03–06;181 preserves all future170/171 tasks/commands and172links|COVERED; no simulated result replaces a native report|
|RESEARCH|Source/PR head/checkout/workflow/run/attempt identities|Existing170/171 origin verification;181 exact SDK query/source bindings and local-only labeling|COVERED; local copy proves routing only|
|RESEARCH|Pinned tools, concrete readiness, isolation/order, scoped first-failure trace|Existing registration/control evidence and fixed selections;181 no new browser work|COVERED; original unproved cause remains literal|
|RESEARCH|Fixed budgets, native exits, no retry-until-green|179 original once-only contract;181 preserves parent/request/binary/tree/category/page limits and all earlier outcomes|COVERED; a failed deadline or deterministic check still stops execution|
|RESEARCH|Responsibility map / trust boundaries|Local Python owns parsing and Git bindings; real hosted metadata remains170/171's responsibility|COVERED; no synthetic origin is assigned to GitHub|
|RESEARCH|Strict required input types, UTF-8/raw-byte identity and safe retained output|181T1/T2 direct negative controls; inherited source blob handling and safe diagnostics|COVERED; legitimate empty tracked blobs remain byte-preserved|
|RESEARCH|Unresolved host versions, reproduction and record survival|Existing frozen runtime preflights/hosted plans and explicit open dispositions|COVERED as work/limitations; not assumed proven|
|CONTEXT|D-01 immutable252 and separate correction|181 historical binding/preservation; original01 diagnosis|COVERED|
|CONTEXT|D-02 reject passingTestD as failure|Original01 and181T3 conservation clause|COVERED; no newTestD fix|
|CONTEXT|D-03 registration is selected lead|Existing selected evidence;181T3 preserves cause unknown|COVERED|
|CONTEXT|D-04 reproduce before cause-backed change|Existing frozen reproduction/control path;181 retains partial_not_reproduced|COVERED; no speculative product/auth fix|
|CONTEXT|D-05 native outcomes and failed attempts|181T1 intended errors,181T2 parsed SDK facts,181T3 retains175/178halts|COVERED|
|CONTEXT|D-06 completeness/unknown and original hashes|181 diagnostic readbacks/native full-suite retention and invalid-input refusal|COVERED|
|CONTEXT|D-07 five isolated seams/owners/zero retries|Existing native work;181T3 unchanged allocations and downstream tasks|COVERED|
|CONTEXT|D-08 signal readiness rather than sleeps|Existing readiness/control work;181T3 conservation|COVERED|
|CONTEXT|D-09 collision/isolation and actual owner lifecycle|Existing state controls;181T3 conservation|COVERED|
|CONTEXT|D-10 scoped trace retention and safe diagnostics|Existing native trace work;181T3 conservation|COVERED|
|CONTEXT|D-11 exact source/tools/workflow identities|181 real Git fixture, actual SDK/Node hashes, committed input/source bindings|COVERED|
|CONTEXT|D-12 preserve five required names|Existing gate contract;180future170/171 unchanged by181T3|COVERED|
|CONTEXT|D-13 internal unit-smoke gate owner|Existing03;181T3 keeps owner intact|COVERED|
|CONTEXT|D-14 exact-five producer/native-report accounting|Existing05/06 and170/171;181T3 preserves their proof contracts|COVERED|
|CONTEXT|D-15 unique artifacts/separate producer directories|Existing05/06/170/171;181 no hosted mutation|COVERED|
|CONTEXT|D-16 actualPR docs-only body eligibility/parity|Existing04/170/171;181T3 preserves contracts|COVERED|
|CONTEXT|D-17 native failures/cancels/skips and negative controls|Existing gate/hosted work;181 rehashed consumer negatives and native failure retention|COVERED|
|CONTEXT|D-18 independent origin/source checks|181 parsed SDK/manifest/command checks;170/171 remain actual hosted owners|COVERED|
|CONTEXT|D-19 frozen limits/retained attempts|181 no native/hosted allocation;179 unchanged once-only contract|COVERED|
|CONTEXT|D-20 finite fresh repeats and no absence-of-flake claim|Existing native results/selections;181T3 conservation and open requirement|COVERED|
|CONTEXT|D-21 sealed registered workflow fixture|Existing170 preserved in future180spec|COVERED;181does not execute it|
|CONTEXT|D-22 six scenarios / original canary budget|Existing170 preserved;181 no extra jobs/requests/time/retry|COVERED|
|CONTEXT|D-23 real productionPR family/identity|Existing171 preserved;179local proof cannot fill172hosted links|COVERED|
|CONTEXT|D-24 honest incomplete status and bounded delivery|All181tasks retain open requirements; durable halt and exact next command|COVERED|

Deferred ideas, Phase254 speed optimization, Phase255 final contributor/report work and unrelated todos are exclusions, not newly unplanned scope. No source feature is removed. The missing registration reproduction/root cause and actual hosted results remain execution gaps owned by the retained chain; no source item is silently called complete.

## Dependency graph and exact accounting

| Active wave after181 amendments | Plan | Needs | Creates |
|---|---|---|---|
|1|181|Existing halted178 bytes and current source; depends_on[]|Three local repair tasks, new review and preserved179/180amendments|
|2|179|Completed181/new181review; unchanged source/deadline/no-attempt preconditions|One actual separately identified179outcome and success-only receipt|
|3|180|Verified179 and recoverable seven originals|Five future168–172amendments and actual SDK route report|
|4|168|180 plus actual179receipt consumer in both command bodies|OriginalR13 freeze|
|5|169|168|181pins/25halts/73targets contract|
|6|170|168+169|Original six-scenario hosted canary plus verifier|
|7|171|170|Original production/docs-only nativePR proof|
|8|172|171+169|Reopened completion evidence and exact73target bundle|

Only181 is ready when this additive plan is written. Existing179/180 keep their current blocked dependencies during planning;181T3 amends them after verified original readbacks. No dependency on halted178 is introduced. File coupling makes the three new tasks sequential within one plan, maximizing reuse without creating another acceptance identity.

| Real/simulated state | PLANs | Ordinary nonhalted summaries | Literal halts | Without SUMMARY |
|---|---:|---:|---:|---:|
|Clean entry|180|75|25|80|
|After planning181|181|75|25|81|
|After successful181|181|76|25|80|
|After successful179/180|181|78|25|78|
|After successful ordinary168–172, before actual disposition application|181|83|25|73|
|Temporary final simulation only|181|156(includes73 simulated dispositions)|25|0|

Exact halts:02/07/09/12/16/27/40/51/63/73/84/92/97/104/113/122/134/143/146/155/167/173/174/175/178. Sparse173member history is01–167 plus173–178. Original75 completed members and original71+176/177 unstarted targets remain unchanged.175/178 delivered helper/test receipts use their own producing commits. Proof of halted174/175/178 moves to181/179; no halted plan is an owner. Final disposition owner remains172.

## Grounding, limits and checks

- Level0 discovery: internal existing Python/unittest/Git/installed-SDK conventions; no new dependency or external interface. Current source functions and test fixtures were inspected directly. All five declared existing paths are tracked.
- Agent-skills query returned no configured skills. Project skill directories supplied no files. Graphify status reports disabled; no graph claim was made.
- `estimate-calibration` returned factor1,sample_count0,confidence low. Projection is44000raw/calibrated tokens for3tasks. No task modifies more than5files.
- Every task includes read_first, behavior, action, acceptance_criteria, reversibility, automated verification with immediately matching fails_when, and done. First task is a real consumer-to-command tracer with refusal and success controls.
- Four newly named regressions plus original16 checks require at least20 tests in the final suite. Prior runtime167.106s is retained; root uses background execution/short waits. No production verification command was executed during planning.
- Existing runnable verify command is inherited verbatim from178's real full-suite log. Focused test names are created before their commands run. The review-file check is intentionally not satisfiable at entry because181review does not exist and179still depends on178.
- The inherited CIREL-01 unclassified edge remains unresolved; empty/encoding predicates are explicit. The spec-less local-versus-hosted transparency prohibition stays flagged-unverified, without a manufactured descriptor or acceptance claim.
- Threat IDs432–434 continue after existing maximum431; reservedSC row remains. Unresolved current high findings block179.
- No dedicated local Write/Edit tool exists in this runtime; apply_patch is the available scoped file creation/edit tool. It writes only the three new owned planning files. No shell heredoc or existing-file rewrite is used during planning.

## Review01 revision

The single blocker in253-181-CHECK-01.md required actual automated proof that amended179/180 pass both schema and structure validation. Task3 now independently runs all four installed validator commands, requires exit0/validtrue and complete2task structures, and compares exact argv/raw stdout/SHA with the retained review rows. It binds each result to the current amended PLAN hash and review source_files, then checks waves2/3 and dependencies181/179. Five automated verification bodies now have matching fails_when statements. No other task, old PLAN, source or shared-state change is introduced.

Before revision the exact current PLAN/AUDIT/RECORD plus CHECK-01 status/bytes were preserved at refs/gsd/phase253-plan181-review01-inputs, commit977418ed664a23723a1e714716e04c553f7f8b97,parentb6bc388d562e15982964a9846f0fdd196ae8dc10. Root verified every Git readback. Worker immediately rechecked status/current SHA and exact git show bytes for the three owned paths before editing. Original blobs: PLANed582d6aae9a83e1689be5e01d3259d84c7e7fd4;AUDITcac736a4685287f868af41c1c40e9c481d4e733c;RECORD8de588ff1815711cb5edccf63931b3ca1de1b92c. CHECK-01 blobfe6a8df08165c812b12a9de2004d832fc893315c remains unchanged.

Root performs independent plan review and final current readiness checks, then commits the additive files. Immediate next command after those checks is `$gsd-execute-phase 253 --gaps-only`, starting with181. CIREL-01 remains `partial_not_reproduced`, CIREL-02 remains `unaccepted`, Phase253verification remains `not_started`. Phase254 is not started by this repair. After actual253completion, root checks254readiness before routing forward.
