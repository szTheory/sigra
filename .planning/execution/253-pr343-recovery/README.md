# Plan172: recover the existing PR

The old collector queried GitHub's workflow list and received no runs. Saved commit checks and a direct response prove that PR343 already started run39815188159. This recovery uses commit checks as hints, then checks the exact run, PR, source, base, repository and attempt. It never creates a PR or launches CI.

The executable is `python3 -B .planning/execution/253-pr343-recovery/run.py --run`. Without `--run` it checks the proposal offline. The live entry point requires an exact committed approval of proposal.json, writes a separate once-only window, records every HTTP request before sending it, preserves previous ledger bytes under permanent Git refs, and closes even on failure. Run the whole live command with Git metadata write permission. Do not run the old paired bundle again.

The maximum is seven GETs in ten minutes: API allowance; draft PR343; candidate commit checks; run39815188159; attempt1 jobs; artifact metadata; PR343 again. If the run is still queued or running, collection stops after four GETs. There are no polls, retries, redirects, downloads, writes to GitHub, ref changes, merges, dispatches or reruns. HTTP403/429 and core allowance250 or lower stop collection. Incomplete lists stop rather than quietly omitting evidence. A second invocation refuses to restart the window.

This is a run-status and metadata recovery. Even a successful run cannot complete hosted acceptance from these responses: actual browser record downloads and the absent docs-only PR still need to be addressed afterward. CIREL-01 stays partial_not_reproduced and CIREL-02 stays unaccepted. No snapshot is a substitute for the paired hosted verifier.

Offline tests exercise the saved real contradiction, independent verification of raw ledger bodies, actual HTTP transport request accounting with an injected connection, and the complete entry point with saved responses. Test transport and entry-point outputs live only in temporary directories. They are never recorded as live evidence.

All historical artifacts, the old approval, both closed windows, Plan179 receipt, Plan180 history and29 historical halts remain unchanged. The proposal describes a separate maximum of seven read-only requests; it does not refill any closed budget. There are no new product edits, quick tasks or plan numbers.

Verification:

```
PYTHONDONTWRITEBYTECODE=1 python3 -B -m unittest discover -s .planning/execution/253-pr343-recovery -p 'test_*.py' -v
PYTHONDONTWRITEBYTECODE=1 python3 -B -m unittest discover -s .planning/execution/253-pr343-diagnosis -p 'test_*.py' -v
python3 -B .planning/execution/253-pr343-recovery/run.py
```
