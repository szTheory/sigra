# API Coverage — Phase 249 release closeout

> Full coverage by default within the actual Phase 249 integration surface. This matrix records the GitHub and public release operations used to close REL-02; it does not authorize unrelated provider features.

| capability | decision | reason |
|---|---|---|
| GitHub release tag, run, artifact, and source CI reads | INTEGRATE | D-01–D-04 already use these read-only identity joins to derive the committed sanitized receipt. |
| GitHub source-content and current-main reads | INTEGRATE | The live HexDocs source destination must resolve to the tagged gated commit. |
| GitHub paginated open-PR and changed-file inventory | INTEGRATE | D-08 requires a current, complete PR inventory and source-backed dispositions. |
| GitHub Release Please candidate refresh and CI registration | INTEGRATE | D-06's existing trusted-main path keeps candidate docs generation hands-off without bypassing ordinary CI. |
| GitHub promotion PR review, merge, head, and base reads | INTEGRATE | A reviewed, scoped promotion must be proven before protected merge. |
| GitHub scoped Phase 249 PR creation and protected merge | INTEGRATE | REL-02 is blocked until the receipt reaches protected main through review and required CI. |
| GitHub main receipt, Actions run, and ci-gate job reads | INTEGRATE | D-03/D-04 require final-main proof separate from immutable package-source proof. |
| GitHub rate-limit read and bounded CI watch | INTEGRATE | AGENTS.md requires bounded, single-watcher CI observation. |
| Unrelated PR and Release Please candidate mutation | OPT-OUT | D-10 gives unrelated PRs follow-up dispositions and allows Release Please merge only under its separate exact-head policy. |
| Hex package and versioned HexDocs reads | INTEGRATE | Existing Plans 01, 06, and 07 already proved REL-01 through read-only live joins; the gap plans retain that proof and recheck it at final acceptance. |
| Hex publish, retire, and tag mutation | OPT-OUT | The immutable Sigra 1.6.0 package and `v1.6.0` tag already exist under D-01; this gap closes protected-main evidence and repository state. |

The listed capabilities are the complete external surface scoped to this gap closure. Repository worktree preservation uses local Git, with exact paths and durable refs validated separately from the GitHub API.
