---
phase: 249-publish-and-prove-sigra-1-6-0
plan: 05
subsystem: release
tags: [preservation, protected-merge, closeout]
provides:
  - Verified preservation decisions for inherited work, including the single explicitly accepted historical loss.
  - A scoped protected merge for the source-bound 1.6.0 release change.
affects: [249-06, 249-08, 249-11, 249-12, release-closeout]
key-files:
  created: [.planning/phases/249-publish-and-prove-sigra-1-6-0/249-05-SUMMARY.md]
  modified: [.planning/phases/249-publish-and-prove-sigra-1-6-0/249-CLOSEOUT.json]
key-decisions:
  - "Resolve the original blocked preservation and promotion attempt through later scoped plans; do not rewrite its historical blocked evidence as a pass."
  - "Keep the exact old HANDOFF identity labeled accepted-loss, not recovered."
requirements-completed: [REL-01, REL-02]
coverage:
  - id: D1
    description: Inherited work has exact preservation references or a narrowly recorded accepted-loss exception.
    requirement: REL-02
    verification:
      - kind: other
        ref: "validate-closeout.mjs --mode preservation: accepted-with-recorded-loss; errors=[]; blockers=[]"
        status: pass
    human_judgment: false
  - id: D2
    description: The reviewed, exact-head release candidate merged through protected main.
    requirement: REL-02
    verification:
      - kind: other
        ref: "249-11-SUMMARY.md: PR #304 protected squash merge; candidate CI run 37992672660 passed"
        status: pass
    human_judgment: false
status: complete
completed: 2026-10-09
---

# Plan 249-05 — Preservation and Scoped Promotion

**The preservation and protected-promotion goals first attempted here were completed by the later, source-bound closeout plans.**

## Accomplishments

- Plan 249-08 refreshed and verified exact preservation refs for inherited paths. The one historical `.planning/HANDOFF.json` identity is recorded as user-authorized accepted loss; no recovery claim is made.
- Plan 249-11 promoted the reviewed release candidate through PR #304. Its exact candidate CI passed before protected squash merge to main `3c7d713f290c93de3b9fd54be7ece31d71f32787`.
- The original blocked Plan 05 record remains available at `refs/phase-249-preservation/117bdc87dbd370204c418486201d9b55` with SHA-256 `be28308539392ac9027834674d7ac1da2fcf9c9e81dcc45b6265726926d2408c`. It is preserved as history, not treated as current acceptance.

## Verification

- `node .planning/phases/249-publish-and-prove-sigra-1-6-0/validate-closeout.mjs --ledger .planning/phases/249-publish-and-prove-sigra-1-6-0/249-CLOSEOUT.json --mode preservation` — passed as `accepted-with-recorded-loss`, with no errors or blockers.
- PR #304 merged by protected squash auto-merge; its exact-head CI run `37992672660` passed.
- The later phase-wide terminal acceptance rechecks the full current PR and worktree inventory after all evidence commits.

## Original Execution Disposition

Plan 05's initial run was blocked because 95 inherited dirty paths did not yet have verified preservation refs, and promotion was not yet merged. Those original results remain byte-for-byte recoverable from the scoped preservation ref above. Plans 08 and 11 later closed those conditions under fresh evidence. This summary records the supersession and does not claim the earlier run was green.

## Next Phase Readiness

Plan 05's preservation and promotion outputs are now consumed by the final-main and terminal closeout evidence. The historical accepted-loss exception remains explicit and bounded.
