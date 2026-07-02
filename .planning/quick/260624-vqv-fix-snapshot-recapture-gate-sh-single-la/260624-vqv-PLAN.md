---
quick_id: 260624-vqv
slug: fix-snapshot-recapture-gate-sh-single-la
date: 2026-06-24
status: planned
---

# Fix snapshot-recapture-gate.sh single-lane recapture (per-lane slug routing)

## Goal
Make `scripts/ci/snapshot-recapture-gate.sh <slug>...` usable for single-lane
re-recording. Today it passes the SAME `--allow` slugs with `--require-all` to
BOTH the checkpoint lane (step b) and the design lane (step b2); since no slug
lives in both snapshot dirs, the opposite lane's `--require-all` always fails
("declared intended delta '<slug>' did not change"). MANUAL dev tool, not
merge-blocking.

Resolves todo `recapture-gate-single-lane`.

## Task — auto-route positional slugs to their lane
**File:** `scripts/ci/snapshot-recapture-gate.sh` only (snapshot-canary-guard.sh
already routes per-lane via `SNAP_DIR` — untouched).

- Define `CK_SNAP_DIR` (checkpoints) + `DESIGN_SNAP_DIR` (design).
- For each positional slug, glob the working tree:
  - `${CK_SNAP_DIR}/<slug>-admin-checkpoints-*.png` exists → `CK_ALLOW`.
  - `${DESIGN_SNAP_DIR}/<slug>-admin-design-*.png` exists → `DESIGN_ALLOW`.
  - neither → hard error; both → route to both.
- Step (b): pass only `CK_ALLOW` as `--allow …`; add `--require-all` only if
  `CK_ALLOW` non-empty. Step (b2): same with `DESIGN_ALLOW`.
- `RECAPTURE_DRYRUN=1` seam: print routed subsets, exit 0 before the Playwright/mix
  lanes.

Preserves the bare positional interface (`snapshot-recapture-gate.sh board-stat`).

## Verify (no booted server / no Playwright)
- `bash -n` + `shellcheck` clean.
- Dry-run routing proof with throwaway fake PNGs in each snapshot dir: design slug
  → DESIGN only; checkpoint slug → CK only; unknown slug → hard error. Remove fakes
  after (clean tree).
- SUMMARY notes the full e2e (steps a/a2/c) is CI-verified, not run locally.
