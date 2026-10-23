---
created: 2026-10-01T18:07:38Z
status: pending
title: Investigate local Node and Git pipe EOF stalls across runtimes
area: testing
severity: moderate
files:
  - scripts/maintainers/prune-stale-branches-readiness.mjs
source: Plan 245-26 automated regression verification
---

The prescribed regression suite repeatedly stalled in pinned Git 2.50.1
`hash-object --stdin` on macOS 26.6.2. Process samples showed Git waiting in
`read` while Node waited in `SyncProcessRunner`. A 683,388-byte committed-source
reproducer timed out on Node 20.18.1 and 24.19.0, including outside the sandbox;
the initial full-suite stalls used Node 22.14.0. Changing runtimes did not fix it.

The same bytes passed 1,000 exact-blob comparisons using regular-file stdin.
Plan 26 therefore makes a bounded verification-blocker repair in `blobForBytes`:
private temporary hash input, the same pinned path-aware Git hash command, and
cleanup in `finally`. The authoritative committed readiness artifact and all
source/route validation retain their original semantics. The large-source
capture/verify regression passed under Node 22.14.0.

Investigate the underlying runtime/OS pipe EOF behavior independently. Do not
infer that Node 24 resolves it or waive interrupted/timeout evidence. This
follow-up does not authorize broader helper changes or any production pruning.

Machine-readable observations and stack excerpts are preserved in
`.planning/phases/245-branch-prune-local-and-remote/245-26-RUNTIME-DIAGNOSTIC.json`.
