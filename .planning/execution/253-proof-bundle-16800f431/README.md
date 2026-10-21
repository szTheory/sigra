# Offline execution bundle for repaired source16800f431

This bundle is prepared for review. It has not fetched main, queried GitHub, created an approval/allocation/ledger, or launched CI. All product files remain at16800f431. The existing closed windows and Plan171 halt remain unchanged.

The earlier proposal installed the fixture at the unregistered workflow path and used the old docs-branch trigger. This additive bundle corrects both. The candidate commit8e87e1dc and candidate tree28924e64 are unchanged and still match the previously tested repaired product. The fixture child now installs the manual canary at registered `.github/workflows/ci.yml`; the docs base changes only the CI branch-filter line for the new scoped docs refs. Exact corrected objects are in bundle.json/publication.json/object-recipe.json. The original proposal remains unchanged.

`prepare.py` reads the pinned source, applies the explicit helper-copy changes in adapter.diff, and writes objects only to a disposable object store. helper-origins.json binds source blobs and generated copies. objects.pack retains the277 new objects relative to the source and parent, so the bundle does not rely on a surviving temporary directory. No product helper has been edited. The scoped copies retain existing category caps, predebiting, independent verification and redaction, while restricting new refs and requiring the additional approval/window guard before every request.

The one `operator.py --run` handles the whole authorized attempt: fresh main fetch and exact-parent merge check; charged API budget/fresh-ref checks; canary publication, six expected outcomes and independent verifier; then a separate normal/docs-only draft PR window, with independent family/pair verification. It stops and saves an attempt result on any failure. No rerun, new window, silent source/ref substitution or old runner invocation is available. Allocation templates contain invalid pending source bindings and are not active allocations.

| Proposed window | Requests | Time | Other caps |
|---|---:|---:|---|
| New source canary |117|60 minutes|45 tiny jobs,7 dispatches,1 cancellation; publication at most24 requests|
| New normal/docs-only draft PRs |120|60 minutes|2 draft PRs; docs publication at most14 requests|

Reruns are zero. Publication still projects19/24 requests and2,092,801/2,097,152 bytes for the largest tree body. Category reservations for infrastructure retry remain disabled, unspent and nontransferable. The extra charged rate/ref checks consume the existing preflight category, never a larger cap. Reaching that cap stops. Polling is at least60 seconds, one watcher per run; a remaining core API allowance of250 or less, or403/429, stops collection. Structured summaries are fetched once; failed logs only when a run fails.

Only the refs `gsd/253-proof-16800f431-{candidate,fixture,docs-base,docs-head}` may be created. Each is create-only. Existing PR338/run39651372938, old refs and budgets are never updated or retried. The old canary85/117 and failed PR19/120 remain literal. Current phase counts remain183 plans,80 completed,29 halted and74 without summaries. Plan179 is not replayed. No historical outcome becomes successful because this bundle exists.

The prior unfinished Plan172 depended on halted171 and described old R13 records. Its exact prior bytes are recoverable at a96a80bda with read-back identities in plan172-prior.json. The current pending plan now provides the new approval checkpoint and guarded continuation under normal execute-phase. This is an amendment to the unfinished plan, not another numbered plan. The current copy is bound by the bundle and SDK readiness must show172 runnable pending its explicit approval. Old171 remains halted.

Offline checks:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 .planning/execution/253-proof-bundle-16800f431/operator.py --self-check
PYTHONDONTWRITEBYTECODE=1 python3 .planning/execution/253-proof-bundle-16800f431/test_bundle.py
```

Read APPROVAL.md and approval-request.json before hosted authorization. Current preparation is complete only when the checks pass and these files are committed. Actual hosted proof and whole-phase verification remain incomplete. CIREL-01's original selected failure remains partial_not_reproduced; successful new PRs alone do not prove that clause.

Next normal command, conditional on explicit hosted approval of this bundle:

```text
$gsd-execute-phase 253 --gaps-only
```
