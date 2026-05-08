---
id: SEED-003
status: deferred
planted: 2026-05-06
planted_during: v1.22 gap-closure planning
trigger_when: After Phases 101 and 102 are executed and verified, when the webhook milestone can be closed honestly
scope: Small to Medium
---

# SEED-003: Cut the next Sigra release at the natural v1.22 milestone-close point

## Why This Matters

It has been a while since the last release, and the repo has accumulated enough real work that the next cut should be a milestone-shaped release, not an arbitrary patch push. But the current planning state still says "finish and reconcile the webhook milestone" rather than "ship today."

As of 2026-05-06:

- Phase **101** is planned but not executed
- Phase **102** still exists to finish generated-host proof and planning-state reconciliation
- `.planning/v1.22-MILESTONE-AUDIT.md` still records real milestone gaps, not just clerical lag

That means the right release posture is:

- **Do not cut yet**
- **Do cut once v1.22 closes honestly**

This seed exists so the team does not forget to convert milestone completion into a release at the appropriate natural point.

## When to Surface

Trigger this seed at the first moment all of the following are true:

1. Phase **101** is executed and verified
2. Phase **102** is executed and verified
3. `ROADMAP.md`, `REQUIREMENTS.md`, `STATE.md`, and the milestone verification/validation artifacts all tell the same post-gap-closure story
4. The webhook milestone can be closed without caveats or "known drift" footnotes

This seed should surface:

- during milestone closeout for **v1.22**
- or immediately after Phase **102** if that phase completes the remaining release-blocking truth work

This seed should **not** surface during current gap-closure execution if the milestone is still materially incomplete.

## Scope Estimate

**Small to medium** release-prep slice:

- decide the version to cut from the actual delta since the last release
- confirm release notes / changelog tell the same story as the milestone artifacts
- run the final release-confidence verification set
- tag and publish only after the milestone closeout is honest
- then start the next release cycle / milestone planning from a clean post-release state

## Breadcrumbs

- `.planning/ROADMAP.md` — active phases 101 and 102 define the remaining webhook milestone closure work
- `.planning/REQUIREMENTS.md` — `WH-01..03` milestone truth that must be satisfied before release
- `.planning/STATE.md` — current milestone status, which should agree with release posture before cutting
- `.planning/v1.22-MILESTONE-AUDIT.md` — why release is not ready yet as of 2026-05-06
- `.planning/phases/101-operator-delivery-state-truth/` — query/UI truth gap closure
- `.planning/phases/102-generated-host-proof-and-planning-reconciliation/` — generated-host proof and planning reconciliation

## Notes

- The release should be cut because the milestone is complete, not because "it has been a while."
- If Phase 102 reveals further substantive product or proof gaps, this seed stays deferred until those are closed.
- Once this seed surfaces, the expected next action is release prep plus milestone closeout, not opening another unrelated feature phase first.
