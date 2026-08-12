---
created: 2026-07-10T00:00:00.000Z
status: pending
title: Exclude the impersonation-banner canary from the auto-recapture PR lane (recurring noise)
area: ci
files:
  - .github/workflows/ci.yml
  - scripts/ci/snapshot-canary-guard.sh
source: 2026-07-10 v1.44 ship — each main-push opened a canary-only recapture PR (#75/#76/#77 closed).
---

## What

The push/schedule-triggered baseline-recapture lane (`admin_checkpoint_recapture`, branch
`ci/recapture-admin-checkpoints-<runid>`) opens a PR whenever its fresh CI render differs from the
committed baselines. During the v1.44 ship it opened **one canary-only PR per main-push** — #75,
#76, #77, each touching ONLY the 3 `impersonation-banner-admin-checkpoints-{chromium,dark,mobile}.png`
files. All three were closed as noise.

## Why it's noise (and will recur)

The `impersonation-banner` slug is the **never-allowlistable canary** (D-05/D-06) — it is
deliberately frozen and must NOT be updated via auto-recapture PRs. The committed canary bytes
already pass the **gating** `Example Playwright smoke` byte-compare (green on terminal PR #73), so
they are correct for the merge path. But the recapture lane renders via a slightly different path
and produces marginally different bytes, so it will keep proposing a canary "update" on every future
push to `main` — perpetual noise that a human must close, and a latent trap (merging one would
rewrite the frozen canary).

## Fix

Make the auto-recapture PR lane **skip the canary slug**: when the only drift in a recapture run is
`impersonation-banner`, do not open a PR (or filter the canary out of the recapture commit). The
canary is reconciled deliberately (the Phase 219/220 quarantine-PR dance), never via the routine
recapture lane. Keep the never-allowlistable `snapshot-canary-guard.sh` behavior unchanged — this
only stops the *recapture PR generator* from proposing canary changes.

Low severity (auto-PRs are harmless if closed), but worth doing to stop the recurring clutter and
remove the merge-the-wrong-PR footgun.
