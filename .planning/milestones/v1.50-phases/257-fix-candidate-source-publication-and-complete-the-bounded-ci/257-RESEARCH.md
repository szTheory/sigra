# Phase 257 Research: single-ref candidate publication

## Recommendation

Use the existing Git transport from the contract-bound bare repository for one explicit push to PR368's existing head ref. Git's `push` protocol updates remote refs and sends object data the remote does not already have; GitHub documents pushing local commits to a remote. Pin the target ref and its expected prior SHA with `--force-with-lease=<ref>:<expected>`. The candidate commit is already in the bound local store and is a direct child of the saved PR368 head. A local bare-remote fixture can prove missing-object transfer and single-ref update without contacting GitHub.

Sources: [git-push](https://git-scm.com/docs/git-push) documents object transfer and explicit expected-value lease semantics; [GitHub push commits](https://docs.github.com/en/get-started/using-git/pushing-commits-to-a-remote-repository) documents the supported push path; GitHub's [reference update](https://docs.github.com/en/rest/git/refs) and [commit object](https://docs.github.com/en/rest/git/commits) APIs are separate. The conclusion that the existing SHA-only REST PATCH cannot upload the local object's pack is an inference from the endpoint contracts, not a verbatim GitHub claim.

## Required implementation checks

1. Before the push, prove the bound object repository and alternates are contained and unchanged, the target commit/tree and reachable closure are complete, and the target descends from the expected old PR368 head.
2. Re-read PR368, its exact head ref/SHA, `main`, and the frozen base immediately before mutation. Require one open PR, exact branch/base, and unchanged expected head. `contract.base_sha` is authoritative for both initial and final base checks.
3. Invoke Git with argv (no shell), exactly one `old/new` branch refspec, explicit lease, and no tags, implicit refs, extra destinations, or API fallback. Preserve the required credential helper without printing secrets. Record a sanitized command identity and output digest.
4. Reserve the one-use claim and mutation budget before starting the push. Treat any timeout, disconnect, nonzero result, or otherwise ambiguous outcome as consumed. Do not retry. Reconcile the remote ref, commit/tree, and PR through bounded read-only requests; do not start the workload until all match.
5. After successful postcondition checks, allow only the one resulting candidate CI workload. Use one 60-second watcher. Respect the 45-minute preparation window, 2,700-second outer timeout, 280 runner-minute cap, request limits, and hard rate-limit stops in `257-SCOPE.md`.

## Local regression strategy

Use a temporary bare remote seeded only with the old PR head. Push from the bound object store and assert the remote now contains the candidate commit and tree, the exact branch points to the target SHA, and unrelated refs are unchanged. A fixture with a different current head must fail the lease and leave refs unchanged. Also cover incomplete object closure, wrong parent/tree, duplicate or extra refspecs, timeout/ambiguous transport receipts, and attempted fallback. Run the production path with captured responses; no live push belongs in local tests.

## Measurement boundary

The source-publication change only unblocks candidate preparation. It does not prove either performance requirement. Measurement begins only after independent preparation verification and retains the existing forty-family/twenty-pair schedule, seed, balanced order, cache/source equivalence, percentile method, thresholds, job-cost accounting, request and mutation caps, and 48-hour window. Every failed or cancelled job remains in the result; missing comparability yields `insufficient_data`, and threshold failure yields `miss`.

## Failure modes to stop on

Stop before mutation for missing local objects, changed PR/base/head, non-descendant target, or a failed local fixture. After the single push, stop on a changed remote ref, failed postcondition, 403/429, timeout, unclear result, or any cap. The original Phase256 claim is consumed and must never be reused; this phase needs its own source-bound proposal and one-use claim.
