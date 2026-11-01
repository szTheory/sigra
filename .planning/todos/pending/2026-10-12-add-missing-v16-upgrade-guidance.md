---
created: 2026-10-12T13:30:59.683141+00:00
status: pending
area: docs
priority: high
milestone_origin: v1.49
requirement_origin: READY-01
---

# Add the missing 1.6 upgrade guidance to maintained docs

The immutable published Sigra 1.6.0 source (`9e80cb78d6374b1ed4074d5fef6b613fee879dca`) lacks `guides/introduction/upgrading-to-v1.6.md` and a README entry linking to it. Candidate-only guide files do not help readers of the published release.

In separately scoped documentation work, provide an accurate current upgrade guide and README link based on the actual released code: shipped changes, supported compatibility, generated-host actions or no action, and the `~> 1.6.0` update/check path. Check the links and statements automatically and deliver through normal review.

Keep the original package/tag unchanged. Do not republish 1.6.0 or claim that adding a guide later repairs the old missing approval/test records. This task is a present-day docs correction, and it does not block starting the queued CI reliability milestone.

Source: `.planning/milestones/v1.49-CLOSEOUT-DECISION.json` and the archived Phase251 reconciliation.
