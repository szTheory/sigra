# Phase 253 planning source audit

This is a plan-coverage audit, not execution evidence or phase acceptance. Existing Phase 252 inputs remain unchanged. The current registration cause is unknown; the plans preserve an explicit CIREL-01 gap if the bounded reproduction cannot prove it.

## Write-ahead input preservation

The prior 253-VALIDATION.md bytes were committed at ref c87dfb3b5ea73d64708537a3b43aafaa60348bf9 and read back exactly by the parent before this planning task. Immediately before scoped refinement, git status for that path was clean; SHA-256 of both worktree bytes and the ref's blob was f5e56c0382c6d4843d0a7e689b1db1acfe5de26427dc568b1961e785698804a5. The ref retains the exact prior path/status/bytes. 253-RESEARCH.md was preserved at the same ref with SHA-256 67899812cdd5a637ea6956c93d24688870c214841249e677703e94fdd85da306.

## Multi-source coverage

| Source | ID | Required outcome or constraint | Plans | Status |
|---|---|---|---|---|
| GOAL | Phase 253 | Selected flaky CI failures reproducible and fixed, while real failures prevent required checks passing | 01–08 | COVERED conditionally: CIREL-01 remains open if cause/evidence cannot be proved |
| REQ | CIREL-01 | Reproduce/fix selected current failures with deterministic controls and repeats, no blanket retries or sleeps | 01, 02, 08 | COVERED |
| REQ | CIREL-02 | Preserve useful coverage and exact required names; injected failure/cancel/missing/skip stays non-green | 03–08 | COVERED |
| RESEARCH | Diagnosis companion | Versioned record, full legacy replay, corrected Test D/Test Z and source hashes | 01 | COVERED |
| RESEARCH | Per-producer context | Native result first, selected context before redaction cap, completeness/unknown | 01 | COVERED |
| RESEARCH | Registration lead | Pinned current-source browser/server reproduction with signal/state/trace controls | 02 | COVERED |
| RESEARCH | Gate ownership | Existing honest-skip verdict owns example_unit_smoke dependency/result/decision | 03 | COVERED |
| RESEARCH | Skip parity | Correct aggregate/body mismatch and preserve p10/p21 inventory floors | 04 | COVERED |
| RESEARCH | Five records/reports | Exact five seams, all selected native reports complete/nonempty and matched | 05, 06 | COVERED |
| RESEARCH | Native failure semantics | No result override, shared matrix outputs, retries or expensive cancellation boot | 05, 06 | COVERED |
| RESEARCH | Hosted provenance | Independent jobs/steps/artifact digest against source/workflow identities | 07, 08 | COVERED |
| RESEARCH | Fixture and PR | Bounded sealed dispatch fixture then normal production PR proof | 07, 08 | COVERED |
| RESEARCH | Security | Redaction, synthetic data, bounded artifacts, read-only ordinary CI, exact identity | 01, 02, 05–08 | COVERED |
| CONTEXT | D-01 | Preserve Phase 252 bytes and full legacy replay; companion correction | 01 | COVERED |
| CONTEXT | D-02 | Passing Test D rejected, historical Test Z correctly retained | 01 | COVERED |
| CONTEXT | D-03 | Current registration lead and all three projects | 02 | COVERED |
| CONTEXT | D-04 | Prove condition before targeted harness fix; preserve negative control | 02 | COVERED |
| CONTEXT | D-05 | Native actual failed step, expected vs actual, no keyword-only cause | 01 | COVERED |
| CONTEXT | D-06 | Per-producer completeness and context before cap | 01 | COVERED |
| CONTEXT | D-07 | Five browser seams and isolated app/database; ExUnit owner | 02, 06 | COVERED |
| CONTEXT | D-08 | HTTP/LiveView/server readiness with delayed/missing controls | 02 | COVERED |
| CONTEXT | D-09 | Collision/order and Sandbox ownership boundaries | 02 | COVERED |
| CONTEXT | D-10 | Scoped first-failure traces and safe retention | 02 | COVERED |
| CONTEXT | D-11 | Exact checkout/tool identity; restore lockfile Playwright 1.59.1 | 02 | COVERED |
| CONTEXT | D-12 | Five exact effective required names; no sixth check | 03, 06, 08 | COVERED |
| CONTEXT | D-13 | Unit smoke internal gate needs/result/verdict | 03 | COVERED |
| CONTEXT | D-14 | Five producer/body records and complete native reports | 05, 06 | COVERED |
| CONTEXT | D-15 | Unique seam/run/attempt artifacts, separate downloads, no shared output | 05, 06 | COVERED |
| CONTEXT | D-16 | Real PR docs-only successful classifier, body boundary parity | 04–06 | COVERED |
| CONTEXT | D-17 | Native exits/cancellation and negative injection controls | 03–07 | COVERED |
| CONTEXT | D-18 | Independent GitHub origin, read-only ordinary CI | 07, 08 | COVERED |
| CONTEXT | D-19 | Three-signature and diagnostic/reproduction hard budgets | 01, 02 | COVERED |
| CONTEXT | D-20 | Fresh affected-project repeats and conditional ExUnit seeds | 02, 08 | COVERED |
| CONTEXT | D-21 | Registered scoped ci.yml dispatch fixture and candidate helpers | 07 | COVERED |
| CONTEXT | D-22 | Six canary scenarios, separate verifier and hard budgets | 07 | COVERED |
| CONTEXT | D-23 | Normal production PR family, distinct head/merge/source identities | 08 | COVERED |
| CONTEXT | D-24 | Honest unresolved status and one watcher/rate stops | 02, 07, 08 | COVERED |

Deferred Phase 254 optimization, Phase 255 broad runbook/comparison, public auth/generator/UI changes, releases and old release-record recovery are excluded by CONTEXT.md. No plan implements them.

## Probe and checkpoint dispositions

- The no-SPEC fallback supplied two resolved CIREL-02 edges: empty/null/singleton/duplicate/incomplete producer sets fail, and names use exact byte equality. Both are explicit 253-05 must-have truths and CLI fixtures. Its unclassified CIREL-01 probe remains a flagged assumption: the selected registration cause cannot be classified before execution; 253-02/08 must retain the requirement gap if it stays unknown.
- No bespoke values prohibition survived the precision filter. Ordinary input, origin and secret handling belong to the edge checks and threat registers; no invented prohibition check descriptor is emitted.
- API-coverage detector over phase section plus all eight plans returned detected:false, with no skip. The phase acquires bounded GitHub evidence for an existing CI workflow; it does not integrate a new external service API. No COVERAGE.md is required.
- Assumption-delta detector returned detected:false. No schema-relevant ORM paths were found. Graphify is disabled in project configuration.
- No new dependency is selected. Plan 02 restores packages already pinned by the existing Playwright lockfile. The package legitimacy gate is resolved by the exact-version audit in 253-RESEARCH.md and 253-PACKAGE-AUDIT.json: all eleven audited locked packages returned OK; exact registry integrity matched the lockfile, and no audited postinstall was present. The unversioned latest-release SUS result and version-aware correction remain recorded. No install occurred during planning.

## Research-resolution disposition

The three research issues have resolved **planning treatments**, recorded in 253-RESEARCH.md under “Resolved Research Dispositions; Runtime Facts Pending.” This resolves the research-resolution planning gate without claiming that execution has found the answers. The source audit still marks coverage, not acceptance.

| Missing runtime fact | Chosen owner and frozen probe | Negative or missing-proof outcome |
|---|---|---|
| Cause of the current registration failure | 253-01 task 2 uses the saved archive, with additional diagnostics capped at 60 requests/15 minutes. 253-02 tasks 1–3 freeze exact source/projects/order and run pinned browser/server, readiness/state and negative controls within D-19's ten invocations/20 minutes per signature and 60 minutes total. | Unproved, outside-boundary, non-reproduced or exhausted diagnosis stays `not_reproduced`/`diagnosis_incomplete`; 253-08 task 2 keeps CIREL-01 open under D-24. |
| Actual hosted browser/example-app versions | 253-02 task 1 restores lockfile Playwright 1.59.1 and records command-observed versions and host/source identity before reproduction; 253-08 task 1 binds the normal PR evidence to actual checkout/workflow identity within its separate 120-request/60-minute limit. | Unavailable or mismatched host/source version makes that run unusable as comparable CIREL-01 proof. Archived hosted versions remain unknown unless retained evidence can establish them. |
| Record/report survival and correct origin on dispatch and PR | 253-05/06 local contracts precede 253-07's six-scenario fixture plus independent verifier (45 jobs/60 minutes/120 requests); 253-08 task 1 separately proves a normal PR family within 120 requests/60 minutes. | Missing, empty, incomplete or wrong-origin native proof, unavailable run or exceeded budget leaves CIREL-02 open in 253-08 task 2. Fixture dispatch never stands in for production PR proof. |

No application reproduction, hosted canary, production PR run or phase acceptance is asserted by this disposition. Actual runtime findings and any requirement gap remain execution outputs.

## Dependency and file-ownership graph

| Wave | Plans | Output or dependency |
|---|---|---|
| 1 | 01, 02, 03, 04, 05 | Diagnosis, registration evidence, unit gate, manifest parity and validator use disjoint edit paths |
| 2 | 06 | Needs 03/04/05; revisits ci.yml only after 03 and wires validator |
| 3 | 07 | Needs 06; scoped fixture consumes candidate shared gate helpers |
| 4 | 08 | Needs 02/07; normal PR and honest completion consume both evidence streams |

Plan 02's unresolved-cause outcome is a durable handoff, not a skipped-fix pass. It does not block independent waves 03–07. Plan 08 records CIREL-01 as open if the actual selected cause/fix remains unproved.

## Source-path grounding

All named existing edit, source and verification paths were checked in git tracking. New scripts and phase evidence paths are declared in their creating plan/task before a later task reads them. There is no ignored runtime mirror in plan file ownership. The prior proven verification commands are reused for ci-run-metrics, honest-skip, ci-playwright-report and ci-measure-workflow contracts; new commands point to files created by preceding task actions.

## Draft preservation before independent review

All drafted plans, refined validation, source audit and pattern map were committed at 735fe64ba66e094401e3efc27a53f3ba8371317a; parent verified exact read-back before this audit correction. 253-06/07-PLAN-PRESERVED-20261012.md preserve exact earlier draft bytes in the same commit. Those copies remain historical draft records and are not executable PLAN.md files. Initial capture was clean at cdbc002b163a737b15c1e55106d396b492366c29.
