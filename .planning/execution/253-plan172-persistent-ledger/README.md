# Plan 172: repaired-source paired proof

The offline execution bundle is ready for review. No CI was launched, no GitHub request was made, and no approval or budget was activated during preparation. See `APPROVAL.md` and `approval-request.json` for the exact proposed action.

The objects contain the exact product bytes from `5e13621e5`. The normal candidate is `c8443e2bd9576bb0284d6c78a7212659a5af85fd`; docs base is `4524f17e1b791dd4d2c2ae597c053a8e37e8095e`; docs head is `a4c2b64119fa89ada8a6dbbe1f729a24fb6bfc21`. Disposable Git-store readback checks every product path, mode and blob. The docs base changes only the workflow branch filter; the docs head changes only one guide. GitHub main/ref freshness remains unchecked until an approved execution begins.

`run_pair.py` defaults to an offline check. With a new committed approval, `--run` can publish the candidate, create and collect the two draft PRs, and invoke `verify_pair.py`. Publication and PR collection have separate new limits; the two PRs share one append-only ledger. Every transport request passes a source-specific guard. The proposed sequence is 15 publication requests under a 23-request ceiling, followed by at most 120 PR collection requests. No canary fixture is published. No dispatch, rerun or merge is permitted.

The result checker requires the exact repaired-source freeze, verifies each actual PR family and their shared ledger, checks the measured candidate publication, rechecks unchanged gate inputs and verifies the old canaries without rewriting their source or run identities. PR341's old normal success cannot substitute for the repaired normal source. PR342 stays a failure. Synthetic test fixtures never create requirements evidence.

Sixteen scoped regressions exercise approval scope/expiry, old-source rejection, the publication request bodies and response checker, rate limits, changed main, occupied refs, duplicate PR creation, missing evidence and real shell/transport startup with networking disabled. The separate four source-scope regressions remain required. A startup test caught Python's `operator.py` filename shadowing a standard module; the new executable is named `run_pair.py` and the failing startup now passes.

Implementation of this offline bundle is complete. Hosted verification is pending. CIREL-01 remains `partial_not_reproduced`; no new green PR can substitute for reproducing the original registration failure. Phase 253 is not verified. The 29 historical halts, 73 blocked plans, Plan 179 receipt, Plan 180 history and all closed limits remain intact.

Next GSD command: `$gsd-execute-phase 253 --gaps-only`, conditional on approval of this bundle. Continue the same Plan 172. No new quick task or plan number. If execution stops, preserve its real results and diagnose inline; never reopen that attempt.

The prior attempt afe01a308 stopped after one rate-limit read and zero writes/CI. This continuation preserves it byte-for-byte. The new publication ceiling is reduced to23; both attempts plus the proposed120 PR requests remain within the previously proposed144 total. This adapter stores recovery blobs in the permanent Git object store. Its actual dirty-ledger write/read-back runs before allocation or HTTP. The live command requires Git metadata write permission; use the execution tool's approved escalation. No old allocation is reopened.
