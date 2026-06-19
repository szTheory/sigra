---
id: recapture-gate-single-lane
created: 2026-06-14
source: 185-REVIEW.md (WR-02)
severity: warning
area: scripts/ci/snapshot-recapture-gate.sh
---

# snapshot-recapture-gate.sh breaks single-lane recapture (shared --require-all slugs)

**Problem (WR-02, confirmed):** `snapshot-recapture-gate.sh` passes the same
intended `--allow <slug>` args with `--require-all` to BOTH the checkpoint lane
(step b) and the design lane (step b2). `snapshot-canary-guard.sh`'s
`--require-all` enforces that every ALLOWED slug appears in that lane's
`CHANGED_SLUGS`. Since no slug exists in both snapshot dirs at once, recapturing
only the design lane (or only the checkpoint lane) fails at the opposite lane's
`--require-all` check with "declared intended delta '<slug>' did not change".

**Impact:** The recapture gate is unusable for single-lane re-recording. It is a
MANUAL developer tool (not in the merge-blocking CI path — the live drift guards
in the `snapshot_drift_guard` job do NOT share `--require-all` and work
correctly), so this is non-blocking but should be fixed for DX.

**Why deferred:** The fix needs a design decision on two-lane slug routing
(options: lane-tagged slugs, per-lane intended-slug subsets, or "intended slug
must change in at least one lane" semantics). Not a mechanical fix.

**Suggested fix direction:** Route intended slugs to the lane they belong to —
e.g. accept `--design <slug>` / `--checkpoint <slug>`, or detect each slug's
lane from which snapshot dir contains it, and only apply `--require-all` per
lane against that lane's intended subset.

**Verification when fixed:** recapturing only a design slug
(`scripts/ci/snapshot-recapture-gate.sh board-stat`) passes both lanes; same for
a checkpoint-only slug.
