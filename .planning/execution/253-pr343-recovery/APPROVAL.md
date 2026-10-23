# Exact read-only continuation

Approve only the SHA-256 of `proposal.json` in this directory for scope `pr343-read-only-7-gets`.

This permits at most seven GET requests to inspect existing draft PR343 and existing CI run39815188159, attempt1. It permits zero GitHub writes and zero CI launches. It preserves all closed budgets and uses a separate once-only accounting window. Last observed queued is historical, not a current result.

The literal answer, proposal hash, scope, approval time and expiry (at most24hours) must be recorded in a committed `approval.json` before `--run`. Prior approval of the now-closed paired attempt cannot activate this new window. Missing/expired/changed approval stops before HTTP.

After approval, continue Plan172 with `$gsd-execute-phase 253 --gaps-only`. No new quick task or plan is needed. After the snapshot, follow its actual conclusion; do not automatically publish docs refs, create another PR, rerun CI or accept hosted results.
