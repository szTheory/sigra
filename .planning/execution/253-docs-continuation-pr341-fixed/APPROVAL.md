# One fresh docs-only window

This bundle is not approved yet. A new explicit answer approving its committed bundle hash is required because the previous attempt is closed. Never copy or extend its old approvals or allocation.

After approval, create and commit exactly two new files before running the operator:

- `live-approval.json`: schema `sigra.phase253.docs-continuation-approval/v1`; decision `approve`; scope `docs-only`; exact bundle_sha256; literal decision_text; actual approved_at_epoch; expires_epoch at most24 hours later.
- `prs-approval.json`: schema_version `sigra.phase253.outward-action-approval/v1`; decision `approve`; section `docs_and_prs`; section_sha256 from approval-request.json; exact bundle_sha256; scope `docs-only`; same literal decision and timestamps.

The section digest retains the original publisher's wire format, which describes both PR families. It does not widen this new approval: the new overall approval and transport guard prohibit the normal family, dispatch, cancellation, reruns, updates, merge and cleanup. Only the two exact unused docs refs/commits and one exact draft docs-only PR can be created. Both approvals must have this new bundle hash; an old section approval is refused.

Run the offline self-check, then operator.py --run exactly once. The operator performs no Git fetch, canary dispatch or normal PR creation. It reads the existing canary and normal evidence offline; uses a new120-request/60-minute docs window; starts with a fresh charged rate read; stops at core<=250 or any403/429; uses the existing60-second collector polling; and never restarts a stopped window. The collector probes each docs ref for404 immediately before creating it. Occupied refs stop publication; no overwrite is permitted.

The source candidate remainsa6838a8f9; the independent comparison consumer repair is separately pinned. Only that verifier and its regression differ in the developer checkout. The docs commits were already prepared from the same candidate. The runtime publisher checks that distinction and rejects other product changes.

Successful completion independently verifies the original normal evidence and new docs evidence with equal source freezes. It records the separate windows rather than combining their ledgers. CIREL-01 remains partial_not_reproduced. Phase253 is not complete until its separate phase verification passes.

The previous docs-only attempt is closed at43b661d2b: one rate-limit read, zero PRs or CI launches, stopped because the stdin-launched collector could not import a sibling guard. This replacement loads the guard by its exact sibling file path, independent of Python search paths. Offline startup regression exercises the actual shell/subprocess path before a new approval is requested.
