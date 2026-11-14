# Phase253 additional recovery source audit

Planning coverage only; both CIREL requirements and full phase verification remain open. No original plan01–14, failed receipt, freeze, ledger, shared state or source file is replaced. Existing completed plans01/03/04/05/06/11 are retained evidence, not tasks to run again. Original halted02/07/09/12 remain halted; blocked08/10/13/14 are superseded only after accepted proof.

| SOURCE | ID | Obligation | Plans | Status |
|---|---|---|---|---|
| GOAL | Phase253 | Selected current failures reproducible/fixed; true failures block green gates | 15–25 | COVERED |
| GOAL | SC1 | Cause-backed repair/regression/repeats or adequate honest no-flake path | 15–17;24–25 | COVERED |
| GOAL | SC2 | No blanket retries/sleeps; isolated real state | 15–17;21;24 | COVERED |
| GOAL | SC3 | Required names/coverage owners unchanged | 03–06 retained;19;21;24–25 | COVERED |
| GOAL | SC4 | Injected failure/cancel/missing/skip stays non-green | 19;21;23–25 | COVERED |
| REQ | CIREL-01 | Reproduce/fix selected measured failures with deterministic controls/repeats | 15–17;21;24–25 | COVERED |
| REQ | CIREL-02 | Preserve names/coverage; real failure/cancel/missing/skip blocks gate | 18–25;03–06 retained | COVERED |
| RESEARCH | R-01 | Versioned source-bound diagnosis/full replay | 01 retained;25 | COVERED |
| RESEARCH | R-02 | Select failed context before redaction cap; per-producer unknowns | 01 retained;15;17;25 | COVERED |
| RESEARCH | R-03 | Native Playwright statuses/exit/report selection | 15–17;19;21;24 | COVERED |
| RESEARCH | R-04 | No shared matrix output; five unique artifacts/directories | 05/06 retained;21;24 | COVERED |
| RESEARCH | R-05 | Unit internal owner and skip parity/non-vacuity | 03/04 retained;21;25 | COVERED |
| RESEARCH | R-06 | Real readiness/state/order and trace controls | 15–17 | COVERED |
| RESEARCH | R-07 | Actual pinned Playwright/Ecto/LiveView host identity | 15;17;24 | COVERED |
| RESEARCH | R-08 | Fixture/source/head/merge/workflow identity separate | 20–24 | COVERED |
| RESEARCH | R-09 | Six hosted outcomes and independent job/artifact checks | 18–19;22–23 | COVERED |
| RESEARCH | R-10 | No package/action upgrade;exact audited existing lock restore | 15;all threat SC rows | COVERED |
| RESEARCH | R-11 | Bounded redacted logs/artifacts/API trust/security | 15–16;18–20;23–25 | COVERED |
| RESEARCH | R-12 | Architecture responsibility tiers unchanged | 15–25 | COVERED |
| RESEARCH | R-13 | A1 metrics companion reader compatibility | 01 retained;25 | COVERED |
| RESEARCH | R-14 | A2 artifact pin survival/runtime origins pending | 06 retained;19;23–24 | COVERED |
| RESEARCH | R-15 | A3 standard-library record/native validator | 05 retained;19;21 | COVERED |
| RESEARCH | R-16 | A4 lock versus actual host versions | 15;17;24 | COVERED |
| RESEARCH | R-17 | Research resolved planning dispositions are not runtime facts | 15–17;23–25 | COVERED |
| CONTEXT | D-01 | Preserve252/replay and separate versioned diagnosis | 01 retained;25 | COVERED |
| CONTEXT | D-02 | TestD passing/TestZ historical correction | 01 retained;25 | COVERED |
| CONTEXT | D-03 | Three registration projects/current lead | 15–17 | COVERED |
| CONTEXT | D-04 | Demonstrate cause before targeted repair | 16–17 | COVERED |
| CONTEXT | D-05 | Native status/exit/original outcome truth | 15–17;19;23–25 | COVERED |
| CONTEXT | D-06 | Per-producer completeness/unknown missing log | 01 retained;15;17;25 | COVERED |
| CONTEXT | D-07 | Five seams, isolated state, single library owner,zero retries | 15–17;21;24 | COVERED |
| CONTEXT | D-08 | HTTP/LiveView/server readiness and negative signals | 15–17 | COVERED |
| CONTEXT | D-09 | Collision/isolation and actual ExUnit owner boundary | 16–17;24 | COVERED |
| CONTEXT | D-10 | Scoped first-failure trace/positive discard | 15–17 | COVERED |
| CONTEXT | D-11 | Exact source/cleanliness/tool identity | 15;20;22;24 | COVERED |
| CONTEXT | D-12 | Exact five required names/app sources | 03 retained;19;23–25 | COVERED |
| CONTEXT | D-13 | Internal unit gate needs/result/verdict | 03 retained;21;25 | COVERED |
| CONTEXT | D-14 | Exact five records/nonempty selected native reports | 05/06 retained;19;21;24 | COVERED |
| CONTEXT | D-15 | Unique seam/run/attempt artifacts/separate directories | 06 retained;21;24 | COVERED |
| CONTEXT | D-16 | Actual PR exact classifier/body skip parity | 04 retained;19;21;23–25 | COVERED |
| CONTEXT | D-17 | Literal failure/cancellation/native ownership negatives | 03/05/06 retained;16;21;23–25 | COVERED |
| CONTEXT | D-18 | Independent hosted provenance/read-only pins | 18–25 | COVERED |
| CONTEXT | D-19 | Frozen bounded diagnostics/spent-slot carry-forward | 15–17;25 | COVERED |
| CONTEXT | D-20 | Nine reserved fresh repeats/five integration seams | 17;21;24–25 | COVERED |
| CONTEXT | D-21 | Registered dispatch fixture/separate candidate workflow | 20;22–23 | COVERED |
| CONTEXT | D-22 | Six sources/separate verifier/finite measured window | 18–19;22–23;25 | COVERED |
| CONTEXT | D-23 | Normal exact-head and real docs-only PR shared budget | 20–21;24–25 | COVERED |
| CONTEXT | D-24 | Honest open gaps/no false no-flake/rate stops | 15–25 | COVERED |

Every required source obligation has a plan. All24 decisions have explicit task/action references in the new or retained canonical plan set. Unselected failures remain disclosed, not newly acquired. Deferred optimization/auth reuse/workers/shards/cache/Paid runners/UI/auth/generator/release work and Phase254/255 deliverables are excluded exactly as context specifies.

The three fallback edge items are preserved in253-REPLAN-EDGE-COVERAGE.json. CIREL-01 unclassified remains a flagged assumption; CIREL-02 empty/encoding have explicit executable planning contracts in19/21/25, not execution-pass claims. Two recalled transparency prohibitions were serialized with the installed projectProhibitions, descriptor-less and unresolved in15/24. They remain flagged-unverified for downstream review; no invented check_* wiring or dismissal.

New recovery plans have no dependency on halted09/12 or old blocked10/13/14. Shared source file owners are sequential: registration15→16→17; transport18→19; verifier19→21; publication20→22; canary adapter18→19→22. All local tools and source are complete before23 starts the fresh hosted window. The completion mode is implemented in21 before candidate freezing;25 uses it without altering frozen helpers. SDK adapter/index tests and disposition bytes are25's distinct verification-only outputs.

API surface coverage is a root-owned promotion proposal in253-REPLAN-COVERAGE.md. Canonical COVERAGE.md was absent at capture; root must promote the new scoped proposal before the API seal gate, without replacing any pre-existing coverage bytes unsafely.

