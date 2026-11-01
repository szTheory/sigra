# Phase 253 recovery source audit

The six new plans add bounded work to the original eight; they do not rewrite the original plan, freeze, evidence or halted statuses. The planning capture is `253-RECOVERY-PLANNING-CAPTURE.json`, committed at `81f713e8d`; earlier bytes are recoverable at `b8aefd58bbd4595e37e328680f832e9f445c1a5e`. Five original plans are complete, 02 and 07 are halted, 08 is blocked, both requirements are open and phase verification has not started. The setup-only proof is 3/3 HTTP 200 and database cleanup in 76 seconds with zero browsers; it does not explain the historical registration failure.

| Source | ID | Required outcome or constraint | Covered by | Status |
|---|---|---|---|---|
| GOAL | Phase 253 | Selected current flake reproduced/fixed and real failures keep required checks red | 01, 03–06; recovery 09–14 | COVERED; pending execution |
| GOAL | criterion 1 | Cause-backed reproduction, regression and repeat under one predeclared cumulative ledger; honest no-flake only with adequate diagnostics | 01, recovery 09–10, 14 | COVERED |
| GOAL | criterion 2 | Zero retry, signal readiness, real app/database isolation | 02 halted; recovery 09–10 | COVERED |
| GOAL | criterion 3 | Required names and useful owners remain, no check removal | 03–06; recovery 11–13 | COVERED |
| GOAL | criterion 4 | Failure/cancellation/missing/skip cannot make gate green | 03–06; recovery 11–13 | COVERED |
| REQ | CIREL-01 | Reproduce and fix selected flake with deterministic controls and repeats | 01; recovery 09–10, 14 | COVERED; requirement still open |
| REQ | CIREL-02 | Preserve useful coverage and required names, prove negative gate outcomes | 03–06; recovery 11–14 | COVERED; requirement still open |
| RESEARCH | immutable replay and companion diagnosis | Preserve complete Phase 252 replay and correct Test D/Test Z without rewriting history | 01 complete; 14 links original | COVERED |
| RESEARCH | failed producer/step context | Native outcome first; hashes, ranges, clipping and unknowns | 01 complete; 09, 14 retain | COVERED |
| RESEARCH | pinned browser and current cause | Playwright 1.59.1, actual Ecto/LiveView, three affected projects; no presumed cause | 09–10 | COVERED |
| RESEARCH | signal/state/trace | LiveView versus controller readiness, fresh database, first failure trace | 09–10 | COVERED |
| RESEARCH | internal lane ownership | Example unit smoke needs/result/verdict | 03 complete; 13 proves PR | COVERED |
| RESEARCH | five records/native reports | Exact five seams, selected bodies and independent matrix outcome | 05–06 complete; 12–13 prove hosted | COVERED |
| RESEARCH | manifest and docs parity | Selected body, not aggregate, is docs-only boundary | 04 complete; 13 real PR | COVERED |
| RESEARCH | fixture/source/PR identity | Separate candidate/fixture/head/merge; digest-bound GitHub metadata | 11–14 | COVERED |
| RESEARCH | no new package, native tools | Existing Bash/Node/Python/Mix/Playwright and pinned actions | 09–14 | COVERED |
| RESEARCH | budgets and security | Bounded requests/jobs/time, rate stop, safe traces/artifacts | 09–14 | COVERED |
| CONTEXT | D-01 | Preserve Phase 252 inputs and separate diagnosis | 01 complete; 14 | COVERED |
| CONTEXT | D-02 | Reject passing settled-findings Test D lead; name failed Test Z | 01 complete | COVERED |
| CONTEXT | D-03 | Three selected registration projects from real failed runs | 09 | COVERED |
| CONTEXT | D-04 | Reproduce observed condition before fix | 09–10 | COVERED |
| CONTEXT | D-05 | Native job/step/command outcomes, expected negatives distinct | 01 complete; 09, 12–14 | COVERED |
| CONTEXT | D-06 | Per-producer selected context and unknowns | 01 complete; 09, 14 | COVERED |
| CONTEXT | D-07 | Five seams, separate apps/databases, one worker, zero retries | 05–06 complete; 09–10, 13 | COVERED |
| CONTEXT | D-08 | Boot HTTP, LiveView connection, server outcome and broken wait | 10 | COVERED |
| CONTEXT | D-09 | Collision/isolation and applicable Sandbox owner checks | 10 | COVERED |
| CONTEXT | D-10 | First-failure trace, clean-pass discard and safe retention | 09–10 | COVERED |
| CONTEXT | D-11 | Exact checkout and pinned observed toolchain | 09 | COVERED |
| CONTEXT | D-12 | Exact five names and internal-only ci-gate | 03 complete; 11, 13 | COVERED |
| CONTEXT | D-13 | Example unit smoke internal owner | 03 complete | COVERED |
| CONTEXT | D-14 | Exact five producers and complete native selected reports | 05–06 complete; 12–13 | COVERED |
| CONTEXT | D-15 | Unique per-seam artifacts and separate downloads | 06 complete; 12–13 | COVERED |
| CONTEXT | D-16 | Real PR successful classifier true; body skips and manifest parity | 04, 07 local repair; 12 synthetic and 13 real PR | COVERED |
| CONTEXT | D-17 | Preserve native exits/cancellation and negative fixtures | 03–06; 11–13 | COVERED |
| CONTEXT | D-18 | Independently check job/step/artifact origin and digest | 11–14 | COVERED |
| CONTEXT | D-19 | One pre-browser ledger reserves three diagnostics, six controls and one flexible diagnosed retry; reproduction stays at or below ten launches and twenty charged minutes for the registration signature | 09–10 | COVERED |
| CONTEXT | D-20 | Same ledger separately reserves up to nine fresh affected-project passes plus the one flexible retry if needed there; five frozen seam selections run once in the normal PR and are checked at completion | 09–10, 13–14 | COVERED |
| CONTEXT | D-21 | Sealed registered-path dispatch fixture and candidate helper source | 11–12 | COVERED |
| CONTEXT | D-22 | Six real canary scenarios, separate verifier and fixed ceiling | 11–12 | COVERED |
| CONTEXT | D-23 | Normal production PR and real docs-only PR within separate frozen budget | 13 | COVERED |
| CONTEXT | D-24 | Honest acceptance, single watcher, rate hard stop, no false no-flake | 09–14 | COVERED |

The Plan 09 freeze now allocates all Plan 09–10 native registration work before its first browser action: 3 initial project diagnostics + 6 project/round control bundles = 9 D-19 launches at up to 2 minutes each (18 minutes). One independently diagnosed retry is reserved across both stages: if used in reproduction, D-19 reaches 10 launches/20 minutes; if used in post-fix acceptance, D-19 remains 9/18 and D-20 reaches 10 launches/40 minutes. D-20 separately authorizes 3 fresh post-fix passes per affected project; the same freeze reserves the three-project worst case of 9 fresh passes at up to 4 minutes each (36 minutes), plus that single retry only if it was not used earlier. One non-resetting ledger thus caps either branch at 19 total launches and at most 58 charged minutes, below the 60-minute total with at least 2 minutes unallocated; setup/browser/cleanup and failed attempts debit their slots. The post-diagnosis acceptance freeze binds source and affected-project subset only and cannot add capacity. A needed run that cannot fit stops with CIREL-01 open. Plan 10 verifies the target controls/repeats, Plan 13 supplies the preselected five native seam runs through the ordinary production PR, and Plan 14 joins both receipts for final CIREL-01 acceptance; Plan 10 cannot claim that final integration early.

`CONTEXT.md` deferred ideas remain excluded: product/public API changes, UI redesign, generator changes, release or rules changes, broad upgrades, paid runners, Phase 254 optimization and Phase 255 reporting. The original requirement statuses remain open until real evidence passes. The API-coverage detector returned `detected:false` for the phase section plus all 14 plan bodies; these plans extend existing GitHub CI calls rather than introducing a new external API integration. Assumption-delta returned `detected:false`; no schema-relevant file pattern is planned. The project uses ASVS level 1 with high severity blocking; all six new plans include unique phase-wide threat IDs 17–28 and the reserved supply-chain row.

The deterministic no-SPEC fallback supplied three unresolved edge probes in `/private/tmp/sigra-253-recovery-edge-coverage.json`: CIREL-01 unclassified, and CIREL-02 empty and encoding. They remain unresolved/unclassified in `253-RECOVERY-EDGE-COVERAGE.json`; no fabricated resolution is claimed. The prohibition probe found no new bespoke values/safety prohibition beyond locked fail-closed and privacy constraints, which are already task acceptance and threat-model checks. Any security canon remains with phase security verification.

Execution routing is grounded in the current SDK: `gsd_run query phase-plan-index 253` emits `gap_closure` for every plan; all new plans have `gap_closure: true` and no dependency on halted 02 or 07. `$gsd-execute-phase 253 --gaps-only` selects 09 and 11 initially. It excludes blocked original 08. Plan 14 creates an explicit supersession summary for 08 only after both requirements pass and read-back preserves historical bytes. Then unfiltered `$gsd-execute-phase 253` can reach whole-phase verification. No new plan represents phase execution or verification as completed now.
