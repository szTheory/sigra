---
status: resolved_offline
trigger: "User requested a new route after the repeated Phase255.1 loop and authorized choosing a separate scope; Phase256 Plan02 then halted at its local source-feasibility gate."
created: 2026-11-04
updated: 2026-11-04
goal: find_and_fix_offline
audit_acknowledged:
  milestone: v1.50
  at: 2026-11-10
  status: resolved_offline
---

## Symptoms

- Expected: establish an exact, auditable pair of source trees and continue only if the existing one-update Phase256 scope can be met; otherwise provide a concrete local recovery path without repeating Phase255.1 or asking for routine approvals.
- Actual: Plan256-02 halted before source-store/proposal creation. The selected historical environment patch fails `git apply --check` against both retained source roles, and the production change-signature check returns false for both.
- Error: `READY-SOURCE.patch` (`c20a9f16392201288a2fc1da3a5e0b3f750984fc237f2b800d75d6ead6ba98d2`) has workflow/action/test preimages that do not match candidate `856c02bbd0dac83a29e388a0644d0fd51839b38f` or control `de7d80d67de7c9f57e0a67cff90b36620c384f01`, both compared with base `970055abcf1ee4e8b5d8ebcf79de0eeecf4f223d`. Historical environment checks pass and the Phase01 diagnostics patch applies to both roles, but neither is a current Phase256 source proof.
- Timeline: Phase256 Plan01 completed on 2026-11-04; Plan02 executed and halted at the local source-feasibility gate on 2026-11-04. No hosted request, branch update, workflow workload, or measurement sample was used.
- Reproduction: run the exact `git apply --check` and production `_phase256_change_signature_contains` comparisons recorded in `.planning/execution/256/OFFLINE-RECOVERY.json` and `.planning/execution/256/SOURCE-CHECK.json` for both retained role refs.
- Source of symptoms: terminal Plan256-02 summary and machine-readable local evidence. No user interview is needed to restate these facts.

## Current Focus

hypothesis: The halt is caused by a mismatch between a historical composite patch's preimages/change signature and the exact retained role histories; the proof may be demanding historical patch application even where equivalent environment behavior/content already exists.
test: Inspect the patch's file/hunk lineage against base and both exact role trees; inspect the production signature verifier and environment checker; determine whether an exact content/hunk proof can preserve the same assurance without reusing historical outcomes or weakening source identity, common-repair equality, or the one-update limit.
expecting: Identify either a bounded source-only reconstruction that preserves the current proof rule and approved four-path treatment, or a narrowly scoped, independently reviewable verification change grounded in exact final-tree behavior. If neither is possible inside the approved scope, retain a precise blocked result and explain the additional scope required.
next_action: Execute independently checked Plan256-06, which uses exact base/final content and actual production source/proposal checks; Plan02 remains immutable and halted.

Constraints:
- Phase255.1 remains immutable, halted history; its exhausted allowance cannot be reused.
- Do not perform hosted requests, GitHub API calls, PR mutation, CI dispatch, or measurement during this local diagnosis.
- Keep the Phase256 limits and approved candidate-only treatment unchanged. Do not weaken the source proof policy without independent review and a recorded decision.
- Preserve dirty planning/evidence bytes before replacement. `.git` is read-only; do not commit.
- User has approved choosing a separate recovery scope and ordinary bounded CI without per-run approval; any new local test/build and any hosted action must remain within the recorded Phase256 authorization and timeout/caps.

## Evidence

- `.planning/phases/256-repair-ci-diagnostics-and-complete-bounded-speed-comparison/256-02-SUMMARY.md`
- `.planning/execution/256/OFFLINE-RECOVERY.json`
- `.planning/execution/256/LOCAL-VERIFICATION.json`
- `.planning/execution/256/SOURCE-CHECK.json`
- `.planning/debug/phase256-source-lineage-investigation/SESSION.md`
- `.planning/debug/phase256-source-lineage-investigation/revision03/INDEPENDENT-REVIEW.md`
- `.planning/debug/phase256-source-lineage-investigation/revision03/VERIFICATION.json`

## Resolution

root_cause: The historical patch was a composite of repairs already present in the pinned installed base. The production verifier incorrectly required those inherited lines to appear as new base-to-role diff hunks, also required obsolete file content and only RUNNER_TEMP reports, and its bare object-store path reader treated a directory as a file. The original positive fixture masked these errors by substituting old files and patches.
fix: Pin exact installed-base and role final blobs, retain the evolved phase232 regression, verify the complete four-path candidate treatment diff, accept both supported report layouts, treat the bound object store as a directory and reject symlinks in every alternate-path component. Add the source-recovery namespace and acyclic canonical payload/reciprocal contract binding under Plan06 with independent review before actual source creation.
verification: Revision03 production-path fixtures, baseline replay, guard mutations, adjacent tests and independent code review passed. Plan06 passed an independent plan review. Actual Phase256 object store, source commits, source check, proposal/adoption closure and one-update feasibility remain unproved; Plan02 is still halted.
files_changed:
  - scripts/ci/ci-repaired-comparison.py
  - scripts/ci/ci-repaired-comparison.test.py
  - scripts/ci/ci_metrics_security.py
  - .planning/phases/256-repair-ci-diagnostics-and-complete-bounded-speed-comparison/256-06-PLAN.md
  - .planning/phases/256-repair-ci-diagnostics-and-complete-bounded-speed-comparison/256-03-PLAN.md
  - .planning/phases/256-repair-ci-diagnostics-and-complete-bounded-speed-comparison/256-04-PLAN.md

## Eliminated

- hypothesis: Phase255.1 can be resumed or its spent preparation allowance reused
  evidence: the scope and handoff mark it halted historical work; Plan02 records zero Phase256 external spend and does not reopen the old allowance
- hypothesis: the diagnostics patch itself is asymmetrical between the two retained roles
  evidence: Plan02 recorded that the Phase01 diagnostics patch applies to both retained role trees
