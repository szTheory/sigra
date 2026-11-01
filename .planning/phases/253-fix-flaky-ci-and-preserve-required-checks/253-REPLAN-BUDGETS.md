# Phase 253 additional recovery budgets

Planning contract, not an execution receipt. Existing freezes, ledgers, failed source runs and halted clocks remain immutable. This record adds no unlimited budget and makes no phase-acceptance claim.

## Registration: carry forward the spent command

The original recovery D19-DIAG-01 is spent: zero browser launches, setup/drop exit1, 3,768 ms charged including1,667 ms prelaunch setup. Its rejected sanitized-log hashes remain rejected. It cannot be reused. Historical original Plan02's exhausted attempt stays separate history and is not silently reclassified.

| Remaining regular D-19 command | Native selection | Source-stage owner | Maximum charged ms |
|---|---|---|---:|
| R-DIAG-DESKTOP | admin-eval board-mg-9/populated | 15 | 120000 |
| R-DIAG-MOBILE | admin-eval-mobile board-mg-9/populated | 15 | 120000 |
| R-DIAG-CONTROL-DARK | admin-eval-dark selected board plus all five first controls, ONE command | 16 | 120000 |
| R-CONTROL-FIRST-DESKTOP | five frozen first controls | 16 | 120000 |
| R-CONTROL-FIRST-MOBILE | five frozen first controls | 16 | 120000 |
| R-CONTROL-SECOND-DESKTOP | fresh-state/pass-trace controls | 16 | 120000 |
| R-CONTROL-SECOND-MOBILE | fresh-state/pass-trace controls | 16 | 120000 |
| R-CONTROL-SECOND-DARK | fresh-state/pass-trace controls | 16 | 120000 |

The new source revision maps the two unused old diagnostic slots and six unused old control slots to these eight commands, freezing the new order/argv before any new setup. The spent slot contributes one of D-19's invocation reservations but no new launch. A dark diagnostic and its first controls share one command to avoid inventing a ninth remaining regular slot. Every selected native case still runs and has its own original result.

Common measured dependency preparation reserves116232 ms in a NEW D-19 preparation record; it does not reopen the spent slot. Record every install, version probe and compile command; use only port-independent dependencies there. Per-attempt cold endpoint build/setup/server/drop use the same unique physical MIX_BUILD_PATH and remain inside the command's120000 ms. No shared endpoint build or uncharged warmup. If preparation/boot/controls/cleanup cannot fit, record the exact blocker.

| Accounting | ms | minutes |
|---|---:|---:|
| Historical charged setup | 3768 | 0.0628 |
| New common preparation | 116232 | 1.9372 |
| Eight regular commands | 960000 | 16 |
| D-19 subtotal | 1080000 | 18 |
| Sole shared retry if D-19 | 120000 | 2 |
| Nine fixed D-20 acceptance commands, three/project | 2160000 | 36 |
| Sole shared retry if D-20 instead | 240000 | 4 |

D-19 has at most10 invocation reservations including the spent one and the optional retry,20 charged minutes. The shared retry is independently diagnosed infrastructure only; the deterministic port/build defect cannot consume it. D-20's nine fixed reservations are conditional on a demonstrated cause-backed repair; no borrowed diagnostic/control/repeat command. If no cause is proved, expire them. Stage source amendments grant zero new capacity.

Either retry branch consumes at most19 total command reservations including the spent zero-launch attempt, at most18 NEW browser launches, and at most58 cumulative charged minutes (D-19 retry:20+36=56; D-20 retry:18+40=58). The outer locked total is60; the existing stricter58-minute recovery ceiling is retained. Original old records are not accepted merely to carry their charges. Missing original preceding-order log stays unknown. Additional archived-diagnostic acquisition remains a separately frozen <=60 requests/15 minutes; these plans allocate zero new history requests.

The repair-regression title is frozen before work. When no repair exists during the second control round it remains pending, then shares the first D-20 command after repair; no extra native command is concealed. Five full integration seam selections are owned once by the normal production PR, not by additional local browser invocations. Narrow ExUnit seeds101/202/303 apply only to relevant changed ownership; their ordinary task receipts remain explicit.

## Canary: distinct reviewed window, bounded measured new traffic

Plan12's epoch1791909792,34-second halt and3 known gh API command entries remain historical and closed/expired. Their actual HTTP count is UNPROVEN because no wire status/header/redirect proof exists. The earlier failed run38347679431/ref and older20 accounted/reserved entries also remain historical. No statement claims historical actual HTTP <=120.

The explicit new reviewed allocation has120 accounted slots:3 are reserved for the known historical commands,117 permit NEW measured phase-owned HTTP acquisition/publication/dispatch transactions. This is a new finite source/window identity, not a reset/resume of the old ledger. Old unknown HTTP cannot be converted to exact measurement. If acceptance requires a single exact historical+new HTTP bound, that claim is unavailable; disclose it, not an invented numeric override.

| New transaction reservation | Maximum requests | Contents |
|---|---:|---|
| Preflight | 8 | rate1, effective branch-rules pages2, legacy protection1, check integration/app identity1, registered workflow1, server parent commit/tree2 |
| Git object/ref publication | 24 | <=10 binary blob calls +2 inline-content trees +2 commits +2 commit availability reads +6 scoped ref absence/create/readbacks +2 workflow blob reads |
| Dispatches | 7 | six source scenarios plus one separate verifier |
| Run discovery | 7 | one positively matching discovery per dispatched run |
| Rate pre-watch | 7 | one per run, plus all later response rate headers checked |
| Terminal polls | 18 | full-pass3, docs-only3, failed-body2, missing-seam2, unexpected-skip2, cancellation3, verifier3 |
| Attempt-job pages | 7 | one complete page per source/verifier, full page requires a reservation or blocks |
| Artifact pages | 7 | each source/verifier, including cancelled artifact absence |
| Result ZIP hops | 12 | five non-cancelled source results and one verifier result, two measured hops each |
| Failed-log hops | 6 | three actual failed-source cases, two hops each |
| Positively identified cancel | 1 | exact source run/ref/SHA/attempt only |
| Sole infrastructure retry | 13 | dispatch1, discovery1, rate1, polls3, jobs1, artifacts1, result hops2, failed-log hops2, bounded state-read1 |
| **New measured maximum** | **117** | all request failures, redirects and pages charged before use |
| Historical known-command reservation | 3 | explicitly not proof of old actual HTTP |
| **Accounted allocation** | **120** | no claim of measured120 across history |

The final object graph is prepared locally before the first request. Text source blobs use documented inline UTF-8 Git tree content, so no source file is dropped to fit a standalone blob-call cap. Only binary content needs separately counted blob POSTs. Two final tree/commit sources are exact candidate and distinct fixture. Request bodies are capped at2MiB; incompatible/too-large/missing objects block BEFORE the window.

Clock starts at the first preflight/publication transaction and includes upload, GitHub queue/polls, failed requests, cancellation, download and separate verifier. <=60 elapsed minutes, <=45 actually executed lightweight jobs; six six-job scenarios plus one possible six-job retry and one verifier are at most43. Count original/retry/cancelled executed jobs, not just final chosen receipts. Actual Actions job checkout/upload dependency traffic is governed by the frozen native job/pin contract; the117 limit measures all phase-owned API/acquisition/publication traffic. No opaque Git push publishes objects outside this count. A separate verifier receives bounded compact retained API receipts and performs no uncontrolled extra GitHub acquisition; any added phase-owned request requires an existing reservation.

A per-run lock permits one watcher,60-second intervals, terminal poll as the single structured run summary. No gh run watch hidden calls, no duplicate terminal GET. Stop401/403/429 or core<=250 until reset, no immediate retry. Invalid/expired/halted source needs a new reviewed plan, not automatic another window. Unused capacity is not borrowed to hide new operations.

## Production: both real PR families share one allocation

Normal PR uses the exact candidate ref already published/proved in the canary. Docs base contains only the scoped pull_request branch-filter exception, docs head only guides/reference/phase253-docs-only-proof.md. The active checkout's workflow is not mutated for that exception. Both PRs stay draft/unmerged.

| Reservation | Requests |
|---|---:|
| Fresh preflight | 8 |
| Docs base/head object/ref publication | 14 |
| Two draft PR creations | 2 |
| PR/head/merge/workflow/diff identity | 8 |
| Run discovery | 4 |
| Pre-watch rate reads | 2 |
| Terminal polls: normal15, docs12 | 27 |
| Attempt jobs pages | 4 |
| Native check pages | 4 |
| Artifact metadata pages | 4 |
| Five normal + five docs record/report ZIPs, two hops each | 20 |
| Failed-log hops | 2 |
| One infrastructure rerun: rerun1, discovery1, rate1, polls3, jobs2, checks1, artifacts2, native ZIP hops10 | 21 |
| **Combined maximum** | **120** |

Both PR families plus publication and the one diagnosed retry share <=120 actual measured requests and60 elapsed minutes from first request. No production per-PR reset, borrowed canary requests, unlimited pages/redirects or extra full-seam runs. Read complete effective rules and actual app/source identities, native five producer/terminal results, genuine classifier success/exact true, and exact tested merge/workflow separately from head. If the run cannot finish in its finite polling/page/body budget, keep missing proof open.

## Fixed limits and acceptance

Dispatch inputs <=10 keys and65535 Unicode scalar characters in the compact UTF-8 inputs JSON; an additional <=65535 UTF-8-byte guard is conservative. No normalization of identities. Exactly one safe canary-result.json ZIP member, <=2MiB compressed, <=4MiB streamed extraction. Independent measured receipt/status/header/digest reconciliation is mandatory. Old raw secret reconstruction and secret-redacted stale-hash acceptance are forbidden.

The numeric arithmetic authorizes preparation and finite execution under the reviewed freeze only. Both reliability requirements remain open until their actual acceptance proof passes; planning and local tests cannot turn absent native/hosted evidence green.

