# Phase 110: Session control plane verification closeout - Pattern Map

## Exact Analogs

| Need | Analog | Why it fits |
|---|---|---|
| Repaired-form verification artifact from shipped summaries | `.planning/phases/106-replay-verification-closeout/106-01-PLAN.md` | Same shape: convert already-executed summary/evidence into an authoritative `VERIFICATION.md`. |
| Active-truth reconciliation after verification lands | `.planning/phases/106-replay-verification-closeout/106-02-PLAN.md` | Same bounded rule: update only present-tense planning files after proof exists. |
| Validation-file reconciliation after closeout | `.planning/phases/107-webhook-policy-operator-truth/107-03-PLAN.md` | Same need: turn planned/pending validation truth into post-verification truth. |
| Verification artifact structure | `.planning/phases/98-reliable-delivery-pipeline/98-VERIFICATION.md`, `.planning/phases/104-failed-delivery-replay-controls/104-VERIFICATION.md`, `.planning/phases/105-webhook-egress-policy-and-deployment-controls/105-VERIFICATION.md` | Established headings, bounded claims, and implementation-vs-closeout wording. |
| Focused nested `test/example` rerun | `.planning/phases/109-security-activity-and-session-history-truth/109-02-SUMMARY.md`, `.planning/phases/109-security-activity-and-session-history-truth/109-03-SUMMARY.md` | Same domain and same example-app test files. |

## Recommended Structures

### Verification Artifact

Use the repaired-form structure already present in the repo:

- frontmatter with `phase`, `verified`, `status`, and score
- `## Requirements`
- `## Evidence`
- `## Attestation`
- `## Residuals`

The requirement table should explicitly say:

- Phase 108 implemented `SESS-02` plus the first `SESS-04/05` slice; Phase 110 authoritatively verified it.
- Phase 109 implemented `SESS-03` plus the remaining `SESS-04/05` alignment; Phase 110 authoritatively verified it.

### Validation Reconciliation

Follow the Phase 107 pattern:

- update the existing `108-VALIDATION.md` and `109-VALIDATION.md` in place
- keep the table shape
- flip only the rows now resolved by the closeout proof
- move frontmatter from planned state to completed/verified state once commands and artifacts exist

### Active Truth Reconciliation

Follow the Phase 106/107 pattern:

- edit only `.planning/PROJECT.md`, `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md`, `.planning/STATE.md`, and the live v1.24 audit
- keep implementation-vs-closeout history explicit
- avoid touching shipped archives

## Useful Command Pattern

When rerunning `test/example` focused suites, prefer the same `mix run -e "Mix.Tasks.Test.run([...])"` pattern already recorded in Phase 109 summaries. It keeps the closeout lane aligned with the current session-control surface instead of broadening into unrelated example-app suites.

## Anti-Patterns

- treating the old Phase 108 migration blocker as final truth without a current-head rerun
- writing one vague v1.24 verification file that erases the 108 vs 109 implementation split
- reconciling archived milestone files as part of this phase
- claiming v1.24 is archived/shipped if the work only reaches active audit-ready status
