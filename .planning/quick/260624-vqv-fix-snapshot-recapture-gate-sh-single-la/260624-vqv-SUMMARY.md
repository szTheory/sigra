---
quick_id: 260624-vqv
slug: fix-snapshot-recapture-gate-sh-single-la
date: 2026-06-24
status: complete
---

# Fix snapshot-recapture-gate.sh single-lane recapture (per-lane slug routing)

Resolves todo `recapture-gate-single-lane` (185-REVIEW WR-02).

## Problem
`scripts/ci/snapshot-recapture-gate.sh <slug>...` passed the SAME `--allow` slugs
with `--require-all` to BOTH the checkpoint lane (step b) and the design lane
(step b2). The two snapshot dirs are disjoint, and `snapshot-canary-guard.sh`'s
`--require-all` demands every allowed slug change *in that lane's* dir — so
recapturing one lane always failed the opposite lane's `--require-all`
("declared intended delta '<slug>' did not change"). The tool was unusable for
single-lane re-recording. MANUAL dev tool, not merge-blocking.

## Fix (`scripts/ci/snapshot-recapture-gate.sh` only — `cae8cbc9`)
- Route each positional slug to the lane(s) whose snapshot dir actually contains
  it, by globbing the working tree (`<slug>-admin-checkpoints-*.png` →
  `CK_ALLOW`; `<slug>-admin-design-*.png` → `DESIGN_ALLOW`). Newly-recorded,
  still-untracked PNGs route correctly because the glob hits the working tree.
- A slug in neither lane is a hard error (exit 2) — the gate stays strict, no
  silent drop. A slug present in both lanes routes to both (defensive).
- Each lane's guard call gets `--require-all` + its `--allow` subset ONLY when
  that lane owns ≥1 intended slug; otherwise the lane still runs its full
  drift/canary check (any unintended change in that lane still fails).
- Added a `RECAPTURE_DRYRUN=1` seam that prints the computed `CK_ALLOW` /
  `DESIGN_ALLOW` routing and exits 0 before the slow Playwright/mix lanes.
- `snapshot-canary-guard.sh` untouched (it already routes per-lane via `SNAP_DIR`).
- Bare positional interface preserved (`snapshot-recapture-gate.sh board-stat`).

## Verification (no booted server / no Playwright)
- `bash -n` clean; `shellcheck` clean on the changed code (the one SC2209 it
  reports is on the pre-existing `MIX_ENV=test mix test` subshell line, a known
  false positive on the env-prefix — not introduced here).
- Dry-run routing proof with REAL existing slugs (`audit-explorer` checkpoint,
  `board-applied-chip` design):
  - checkpoint-only slug → `CK_ALLOW=audit-explorer`, `DESIGN_ALLOW=(none)`.
  - design-only slug → `CK_ALLOW=(none)`, `DESIGN_ALLOW=board-applied-chip`.
  - both together → each routed to its own lane.
  - unknown slug → hard error, exit 2.
  (Used real slugs, so no throwaway PNGs were created — tree stayed clean.)

## CI-verified, not run locally
The full end-to-end lanes — (a)/(a2) compare-mode Playwright across 3 projects
each, and (c) the ExUnit component byte-goldens — are slow and need a booted demo
at `:4011`; they run in CI. This task's local proof targets the routing logic
(the actual bug), via the dry-run seam + the guard-arg construction.

## Commit
- `cae8cbc9` — fix(ci): route recapture-gate slugs per lane (single-lane recapture)
