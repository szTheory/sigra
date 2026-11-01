# Plan172 continuation: existing PR recovery prepared offline

Implemented and tested a separate collector for existing draft PR343 and run39815188159, attempt1. Commit `cc7cc2749` contains the code, independent raw-ledger verifier, narrowed transport and exact proposal. Proposal SHA-256: `fc408f26336fd8aa1493d15f43dc3ee91a793e57969774018c0138a10a95bcf3`.

Fresh offline verification:19 recovery tests pass, including the whole entry point, actual transport predebit accounting with an injected connection, exact seven-request ceiling, refusals on changed PR/source/run attempt, incomplete inventories and HTTP403/429/core allowance limits. The six original discovery regressions also pass. The old paired bundle's offline self-check still verifies hash723893190ae070c03c91b9da0fbeeeed952b21b438a7d28ecade114ef2db674a. All354 retained file hashes match. This continuation performed zero external requests and launched zero CI runs. Tests used temporary outputs and injected responses; none are live hosted evidence.

The separate proposed window allows at most seven GETs over ten minutes. It reads API allowance, PR343, candidate checks, exact run, attempt1 jobs, artifact metadata and PR343 again. A nonterminal run stops after four reads. There is no polling, implicit retry, redirect, download, GitHub write, ref movement, PR creation, dispatch, rerun or merge. Closed windows remain closed. The collector requires a fresh exact approval before HTTP and refuses to restart.

The run's present conclusion is still unknown. Last saved status queued is historical. Even a successful metadata snapshot does not pass hosted acceptance: browser record downloads and the absent docs-only PR remain outstanding. CIREL-01 stays partial_not_reproduced; CIREL-02 stays unaccepted; Phase253 is unverified. Historical29 halts, Plan179 receipt, Plan180 history, all prior evidence and closed budgets remain unchanged. Exact prior shared-state bytes are recoverable at f57780c5a with verified readback in253-pr343-recovery/state-preservation.json.

This file records the completed offline task within the still-open Plan172. It is deliberately not the phase directory's253-172-SUMMARY.md; execution must resume the existing plan rather than skip it.

Checkpoint: approve the exact read-only proposal above, scope `pr343-read-only-7-gets`. After that approval, continue `$gsd-execute-phase 253 --gaps-only` to collect from the existing PR. No new quick task or plan number.
