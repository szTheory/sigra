---
created: 2026-07-28T00:00:00.000Z
status: pending
title: "HARD-02's loud-failure signal never worked — notify-failure-issue.sh died because the release-lane-rot GitHub label did not exist, so zero tracking issues were ever created"
area: release
files:
  - scripts/ci/notify-failure-issue.sh
  - .github/workflows/release-please.yml
  - .github/workflows/ci.yml
severity: high
source: 2026-07-28 quick task (post-release 1.4.0 bookkeeping) — diagnosed during the Sigra 1.4.0 Hex publish recovery
---

## What

The Phase 222 **HARD-02 "fail loudly, no silent rot"** mechanism **has never actually worked**,
because the GitHub label it depends on did not exist in the repository.

## Evidence

- `scripts/ci/notify-failure-issue.sh` line 33 creates the tracking issue with a
  `--label "$LABEL"` argument:

  ```bash
  gh issue create --label "$LABEL" --title "$TITLE" --body "$BODY"
  ```

  `LABEL` is set by the caller to the release-lane rot label name
  (`LABEL: release-lane-rot`, release-please.yml line 358 and ci.yml line 1535).

- On the 1.4.0 release the `notify-release-failure` job in run **30379435970** fired
  **CORRECTLY** — it detected the `gate-ci-green` failure and emitted a workflow error
  annotation naming the failed publish/gate for `v1.4.0` — and then **died because the label
  could not be added** (label not found), exiting 1.

- Net effect: **ZERO tracking issues were created**. `gh issue list --state open` returned
  empty. The loud signal was silent, which is exactly the failure mode Phase 222 built this to
  prevent. This was HARD-02's **first real firing**.

- **Blast radius is wider than the release lane.** `.github/workflows/ci.yml` line 1523 has a
  `Notify on red ci-gate (release-lane-rot)` job that calls the same shared script
  (`Open or update release-lane-rot tracking issue`, ci.yml line 1533). So **any red `ci-gate`
  on main has also been failing to raise an issue**, not just release-lane failures.

## Mitigation already applied — DONE 2026-07-28

The label was created:

```bash
gh label create release-lane-rot \
  --description "Release/CI lane failed to complete (HARD-02 loud signal from notify-failure-issue.sh)" \
  --color b60205
```

This unblocks the mechanism immediately, but it **does not prevent recurrence** — a fresh clone,
a new fork, or someone deleting the label re-breaks the signal silently. That is why this todo is
open and is about the durable fix, not about the label.

## Recommended durable fix (NOT implemented by this todo)

This todo records the diagnosis only. Nothing in `.github/` or `scripts/` was changed.

**Preferred:** make `scripts/ci/notify-failure-issue.sh` **self-healing** — check `gh label list`
for the label and create it when absent, before creating the issue. Then a fresh clone or a
deleted label cannot re-break the signal.

**Second option worth noting:** drop the `--label` argument from the `gh issue create` call and
apply the label afterwards via `gh issue edit`, allowed to fail soft. Then a label problem can
never suppress the issue itself.

## Lesson

**A fail-loudly mechanism that has never been exercised is not known to work.** Phase 222
verified this path with a dry-run / red-probe but evidently not against a real issue creation —
so the one step that actually touches the GitHub issue API went untested until it mattered.
