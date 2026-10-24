# 253-173 execution-halt recovery source and amendment audit

Planning-only draft for root review. No product/native/hosted acceptance ran during this planning pass. No whole-phase VERIFICATION.md or diagnosed UAT exists. The gap source is the immutable 253-167-SUMMARY.md, status halted; its failed Task 3 command reused N for the Node path and the full-suite count. Tasks 1/2 were delivered; the separate diagnostic tail is not acceptance. Full phase verification remains not_started.

## Exact scope and dependencies

One new plan, 253-173, two tasks, wave 1, depends_on empty. Its explicit precondition checks the existing 253-166 SUMMARY's complete status and exact SHA-256, plus the exact current publisher and dry-run source hashes; these are direct artifact inputs without a dependency edge to blocked historical 166. It reads halted 167 as evidence without requiring any halted ancestor to become complete. Task 1 owns reviewed command correction and a NEW complete offline acceptance block. Task 2 owns the retained new log and independent hash-bound receipt. No original attempt is retried or reclassified.

Existing continuation is reused: 168 W2 depends on 173; 169 W3 depends on 168; 170 W4 depends on 168/169; 171 W5 depends on 170; 172 W6 depends on 171/169. This set has six plans, seventeen existing-plus-new tasks, six execution waves 1-6. 170/171 retain their approval/operator gates and autonomous:false. No outward approval, request budget, source parent, actual tree cap or product source is changed by this planning pass.

The first R13 contract in 169 remains absent at planning. Its repaired historical partition is 01-167: completed 75 = R12 65 + 136-142 + 164-166; halted 21 = R12 17 + 143/146/155/167; unstarted 71 unchanged. Completed 168 and 173 are proof owners outside that partition. Pin PLANs 01-173 and the 173 receipt/log/review/SUMMARY. Keep 167 halted with original-summary and delivered-key-file receipts. Map 149/158 -> 173, the 143 proof map's 167 owner -> 173, and 167 -> 173 for only Task 3 new acceptance. Final bundle owner remains 172. No disposition for 167 or executed 173; the 71 target paths stay unchanged.

## Preservation before amendments

Capture boundary: HEAD 82d49646f7e1356ddaa34b87e15e283f4b0735df, branch phase-244-playwright-measurement. Capture record: .planning/recovery/phase253-gap-planning-20261020/capture.json; recovery-copy commit 631e146dd79cbd2d2d6c92b7dac6db60db1a1347. It includes exact recovery copies of dirty config/runtime-switch record and 272 clean prior-commit readbacks.

Before editing each target, the planner rechecked clean source status, current SHA-256 against capture, and byte-for-byte git show of the recorded prior commit. All five matched. Prior target identities:
- 168: bf19fb871582f6c728e8dc137d7cc3aaf2d90a975ba8a52dab76e8fdf42d73b3
- 169: ae9e32f09db12c4376bc9e2e028f320bb1d5af6dc4084ffa61cd9fbf01a4288a
- 170: adbf8a708910841fa164f094712356e4adc898b2f7b5ffe20f21cb03395c478d
- 171: 642b845b9c03c324c703e8fc0355bd3bec298f550a94b4aecb70042c5bbac182
- 172: 8a9ae3c90653681e769057d35e17634f1478d4b2d7fa11dc1338ac0f21403220

All remain recoverable from their recorded prior commit 82d49646f7e1356ddaa34b87e15e283f4b0735df. No pre-168 PLAN, existing SUMMARY, historical evidence, shared state/config/roadmap, or original dirty input is modified by this planner. No commit was made by the planner.

## Every permitted amendment and why

| File | Scoped repair | Execution reason |
|---|---|---|
| 168 | Dependency/readiness moves from halted 167 to completed 173; read 173 receipt; state actual 377-byte tree margin and unchanged 2097152 cap | Its old complete-167 precondition was unreachable |
| 169 | Partition 01-167, 75/21/71 counts, 173 owner/receipt tests, 173 PLAN pin, original 167 frozen receipts and proof map; retain r13 name/final owner/71 targets | Old contract would call 167 completed or use it as proof owner and omit 173 |
| 170 | Common clean-input/preservation repair only | Old dirty config hash does not match current preserved config |
| 171 | Common clean-input/preservation repair only | Same; preserves all outward action boundaries |
| 172 | Keep 21 halted records, remap 149/158, pin 173, disclose 167 halt/new acceptance separately, forbid dispositions for 167/173 | Old counts/disclosures omit the new halt and successor |
| All 168-172 | Protect through PLAN 173; replace obsolete config hash/state size and permissive dirty-config status checks with clean committed inputs; record/preserve starting shared bytes | Root will commit exact current config/runtime record before execution; old product helper only accepts the obsolete hash when config is dirty |

Root explicitly confirmed it will commit current config and original runtime-switch record bytes without changing them, after comparing the capture hashes. This is an execution prerequisite, not an instruction to restore old config or edit the publisher. The new receipt checks shared bytes against the producing commit. Product-only graph packing excludes .planning, so additive planning evidence does not consume the 377-byte product-tree margin; 173 and 168 still recompute the actual projection and halt on over-cap output.

## Multi-source coverage

COVERED here means an explicit implementation/proof/status owner exists, not that acceptance passed.

| Source | Item | Owner | Coverage / remaining evidence |
|---|---|---|---|
| GOAL | Selected flaky failures reproducible/fixed; real failures block green checks | Existing 01-172 plus 173 | COVERED as phase work/status reporting; selected cause still not_reproduced, hosted proof absent |
| REQ | CIREL-01 | Existing preserved diagnosis/controls/disposition; 173 receipt; 172 literal completion | COVERED reporting; partial, reproduced/fixed clause remains unmet; no reset or invented fix |
| REQ | CIREL-02 | Existing gate code; 173 local regression; 170/171 hosted; 172 completion | COVERED planned proof; still unaccepted |
| RESEARCH | Preserve full replay and separate diagnosis; select context before redaction and retain unknowns | Original 01 and preserved later records; 172 | COVERED preserved, no recollection |
| RESEARCH | Pinned registration tools, signals/state/trace, cause before fix, fresh repeats | Existing original/recovery records; 172 literal partial status | COVERED disposition/status; no fresh cause proof claimed |
| RESEARCH | Existing verdict owner, exact five native reports/records, body skip parity | Existing 03-06 code; 173 regression; 170/171/172 proof | COVERED planned proof |
| RESEARCH | Independent run/attempt/source/workflow/artifact identity; separate local/hosted/PR evidence | 170/171/172; 173 local-only receipt | COVERED; actual hosted proof still missing |
| RESEARCH | Standard library, no new dependency, bounded validated inputs, safe logs and fixed limits | 173 plus existing 168-172 | COVERED |
| CONTEXT | D-01 immutable original artifacts/complete replay | 173 T1/T2; 169/172 preserved pins | COVERED |
| CONTEXT | D-02 correct Test D/Test Z diagnosis | Preserved diagnosis; 172 T1 | COVERED |
| CONTEXT | D-03 registration lead, not proved cause | Existing disposition; 173 explicit assumption; 172 T1 | COVERED reporting |
| CONTEXT | D-04 cause before fix/no speculative product auth changes | Existing partial disposition; 173 scope; 172 T1 | COVERED reporting |
| CONTEXT | D-05 literal outcomes and native failures | 173 new whole-block log/receipt; 172 | COVERED |
| CONTEXT | D-06 missing/clipped input remains unknown | Preserved diagnosis; 169/172 | COVERED |
| CONTEXT | D-07 five seams/state/workers/retries/library owner | Existing code; 170/171; 172 | COVERED unchanged |
| CONTEXT | D-08 signal readiness/no sleeps | Existing controls; 172 literal status | COVERED unchanged |
| CONTEXT | D-09 collision/isolation ownership | Existing controls; 172 literal status | COVERED unchanged |
| CONTEXT | D-10 first-failure traces/synthetic safe accounts | Existing evidence; 172 | COVERED unchanged |
| CONTEXT | D-11 exact source/tools/cleanliness | 173; 168; 170/171 | COVERED |
| CONTEXT | D-12 five required names/read effective rules | 170/171; 172 | COVERED |
| CONTEXT | D-13 internal unit-owner gate | Existing 03/06; 170/171/172 | COVERED |
| CONTEXT | D-14 exact five full-body native reports | Existing 05/06; 170/171/172 | COVERED |
| CONTEXT | D-15 unique origin-bound artifacts | Existing code; 170/171 | COVERED |
| CONTEXT | D-16 actual PR classifier/body skip and manifest parity | Existing code; 171/172 | COVERED |
| CONTEXT | D-17 exits/cancellation/missing/skip failures preserved | 173 local regression; 170/171/172 hosted | COVERED |
| CONTEXT | D-18 independent hosted origin, local proof separation | 173 local-only receipt; 170/171/172 | COVERED |
| CONTEXT | D-19 finite diagnostics/reproduction and originals | Preserved ledgers/disposition; 173 no reset | COVERED |
| CONTEXT | D-20 fresh affected repeats/integration owners | Existing results/status; 171/172 | COVERED reporting |
| CONTEXT | D-21 sealed registered canary fixture/ref | 168/170 | COVERED |
| CONTEXT | D-22 six actual canary scenarios/limits | 170 unchanged; 173 scoped paging not a full-run pass | COVERED |
| CONTEXT | D-23 production PR evidence/head vs checkout | 171 unchanged; 172 | COVERED |
| CONTEXT | D-24 honest not_reproduced/incomplete/partial and no UAT substitute | 173 receipt; 169/172 | COVERED |

Deferred optimization, shared auth, topology, runbook/comparison, product UI/auth, external services, unrelated backlog and unselected history collection remain excluded under CONTEXT.md. No new task implements a deferred item.

## Capability contributions, probes and discovery

Reuse existing RESEARCH/PATTERNS/VALIDATION; Level 0 internal recovery with existing commands, no package/library discovery. No SPEC/UI-SPEC/AI-SPEC or codebase map is available. Parent's context-drift probe reported no stale artifacts; shared state is nonetheless visibly stale at 47 plans versus the captured 172 PLANs / 96 SUMMARYs. Graph status is disabled. No agent skills were configured for gsd-planner. Estimate calibration factor 1, sample count 0, confidence low; new plan raw/calibrated 30000 tokens.

Applied planner contributions from /private/tmp/sigra253-plan-pre.json:
- API coverage: existing COVERAGE.md already enumerates the scoped GitHub evidence/publication surface and opt-outs. This recovery integrates no additional API capability; do not expand it.
- Assumption delta: detector matched "additional recovery plans" in old roadmap prose. Explicit no-change decision in 173 keeps immutable attempt identity; no new model or primary-key decision.
- Schema push: no scope path matches the listed ORM/schema patterns; no push task.
- Security: ASVS1 high/critical blocking; new IDs T-253-407..409 continue after 406, plus reserved SC.

All three spec-less fallback candidates remain visible:
- CIREL-01/unclassified: flagged assumption, unresolved selected cause; partial_not_reproduced remains literal.
- CIREL-02/empty: scoped resolution in 173 T2 refuses absent/empty log, review, receipt, suite count, projection tree list and gate JSON; hosted reports remain owned by 170/171/172.
- CIREL-02/encoding: scoped resolution in 173 T2 hashes original bytes, requires strict UTF-8 JSON/logs, exact safe paths, lowercase ASCII hashes and serialized byte cap.

Prohibition probe: do not turn command repair/diagnostic tail into accepted flake/hosted evidence; do not disguise full-run category exhaustion or increase budgets/tree cap. These are explicit receipt/status/paging checks, still pending execution.

## Planning checks and route

Only frontmatter/schema, plan structure, bash -n and read-only source/path/preservation checks are authorized during planning. Long acceptance suites, native runs, GitHub requests, branches and further agents are not run here. Root owns independent review, readiness/global checks, shared state alignment and all commits.

Proposed immediate command: $gsd-execute-phase 253 --gaps-only, explicitly selecting independent 173 first according to checked readiness. After the completed-input preconditions pass and 173 succeeds, the existing 168-172 chain remains in waves 2-6. Root must inspect SDK routing; no readiness inference may depend on completing or changing halted historical ancestors. This recovery does not complete implementation, CIREL acceptance or full phase verification.

## Review iteration 1 correction

The original draft and review are preserved at 8aefae4a05a8f200eb79df57d42dbe91ba6d2f17. Their wave-85 dependency on 166 and continuation waves 86-90 are superseded by this correction. 253-173-CHECK-01.md identified that the installed SDK inherited halted ancestors through 166; /private/tmp/sigra253-index.json and /private/tmp/sigra253-ready.json recorded zero runnable plans. Current 173 therefore has depends_on empty and wave 1, with direct completed-summary/source hash preconditions; the five active continuations occupy waves 2-6 with their dependency edges otherwise unchanged. Historical pre-168 PLANs and all existing SUMMARYs remain unchanged.

The second blocker is addressed by comparing the projection-declared largest_tree_body_bytes with max(tree_requests[].body_bytes) and max_tree_body_bytes with 2097152 before accepting the receipt's maximum and remaining margin. Existing tree, request, blob and category caps remain unchanged. Original 167 remains halted; CIREL-01 remains partial_not_reproduced, CIREL-02 remains unaccepted, and full phase verification remains not_started. Only plan syntax/diff checks and read-only SDK readiness are checked in this revision; no acceptance body, product suite or hosted/native action runs. Root owns independent checking and the final planning commit.

Read-only installed-SDK results after correction: phase-plan-index reports 173 ready true, wave 1, depends_on empty and blocked_by empty; 168-172 have waves 2-6, ready false while their active predecessor work remains incomplete, and no inherited halted blockers. init.execute-phase reports runnable_count 6 and lists 168-173 as the active eligible set; its list is not permission to bypass the wave/dependency order. bash -n passed all 17 automated bodies without executing them, and git diff --check passed.
