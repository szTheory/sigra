# Phase 250: Close v1.49 audit gaps - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in `250-CONTEXT.md`.

**Date:** 2026-10-09
**Phase:** 250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat
**Mode:** assumptions
**Areas analyzed:** Verifier freshness and evidence identity; hosted canary safety; phase ownership and traceability

## Assumptions Presented

### Phase 247 candidate verification
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Verify READY-01/02 independently against a single reconciled, approved candidate tuple and its matching readiness, exact-head CI, dry-run, and disposition records. | Confident | `247-RELEASE-READINESS.json`, `247-VALIDATION.md`, `247-10-REBIND-PROPOSAL.json`, `.planning/ROADMAP.md` |

The evidence has a material identity conflict: readiness/validation record candidate `d76d7f2306f6099063a80a420d2d8a4e04c7785f`, while the later rebind proposal and roadmap name `0e773d3614a242e4fbcdd34c418ecb8a307703d6`. The planner must make the verifier fail closed until immutable evidence resolves the exact tuple.

### Phase 248 hosted receipts
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| A dedicated, exact-identity canary can prove hosted failure and cancellation delivery without invoking release/publish jobs; reuse the receipt validator and hosted artifact path, and keep test receipts separate from production receipts. | Likely | `.github/workflows/release-please.yml`, `.github/workflows/release-run-observer.yml`, `scripts/ci/release-observer.sh`, `scripts/ci/release-receipt.sh`, `.planning/METHODOLOGY.md` |
| AUTO-01 can be reconciled from current protected-environment setup and existing success evidence, while AUTO-02 remains open until both hosted terminal artifacts are retrieved and validated. | Confident | `248-USER-SETUP.md`, `248-VALIDATION.md`, stale `248-VERIFICATION.md` |

### Phase 249 acceptance and requirement ownership
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| REL-01/02 use the passing final-acceptance evidence ref with package-source and final-main identities kept distinct; retain the historical HANDOFF loss as explicitly accepted, not recovered. | Confident | `refs/heads/evidence/phase-249-final-acceptance`, `249-VERIFICATION.md`, `249-12-SUMMARY.md`, `249-PRESERVATION.json` |
| Phase 250 closes verification only; original requirement assignments stay with Phases 247/248/249, and final traceability is updated only after those verifiers and canary receipts agree. | Confident | `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md`, `.planning/v1.49-MILESTONE-AUDIT.md` |

## Corrections Made

No corrections requested. The user's standing instruction delegates phase-scoped recommendations to the agent, asks for one coherent recommendation set, and prioritizes automated verification and reduced operator toil; those defaults were applied to these operational choices.

## External Research

- GitHub's `workflow_run` event triggers on completion regardless of the source conclusion, and the receiving workflow must exist on the default branch. The receiver can access tokens/secrets even if the source cannot; do not run untrusted source code or trust its artifacts in the privileged observer. [Events that trigger workflows](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows), [secure use reference](https://docs.github.com/en/actions/reference/security/secure-use).
- Cross-run artifact retrieval needs an identifier/token, and `retention-days` cannot exceed the repository/organization limit. The canary must retrieve the persisted artifacts and validate exact source-run binding rather than treating upload success as proof. [Artifact storage and retrieval](https://docs.github.com/en/actions/tutorials/store-and-share-data).

## Reviewed Todos

No todos were folded. The phase matcher returned broad heuristic matches; the closest Release Please note-placement and label items are handled by Phases 247/248, the Playwright canary item is unrelated, and the verifier EXIT-trap item belongs to historical Phase 235 rather than this release observer path.
