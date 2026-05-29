# Phase 140: Deprecation Hygiene + Verification & Docs Close - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-05-29
**Phase:** 140-deprecation-hygiene-verification-docs-close
**Mode:** assumptions
**Areas analyzed:** Phase 137 completion state, Deprecation removal-timeline convention, Proof-bundle shape, Docs placement, Stale-state reconciliation

## Assumptions Presented

### Phase 137 Completion State (PROOF-01 prerequisite)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| 137 code fully landed; ROADMAP "1/3"/`[ ]` entries are stale tracker drift; 140 only verifies 137 green | Confident | lib/sigra/optional_deps.ex (9 predicates + encryption_active?/1); 137-02/03 SUMMARY.md `completed: 2026-05-29`; remaining raw Code.ensure_loaded? sites are documented out-of-scope category (optional_deps.ex:11-50) |

### Deprecation Removal-Timeline Convention (DEPR-01/DEPR-02)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Express targets as Hex SemVer 0.x minors; cookie_opts/0 stub → 0.4.0, audit_forced_password_change/2 → 0.5.0; bake into @deprecated string + docs note | Likely | MAINTAINING.md:216-220 (pre-1.0 SemVer: 0.y minors = unit for removing public API); CHANGELOG.md:10 (v1.x = planning labels, repo stays 0.x); mix.exs:4 @version "0.3.0"; neither fn carries a removal target today |

### Proof-Bundle Shape (PROOF-01)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Reuse Phase 136 six-gate pattern verbatim; file 140-VERIFICATION.md with canonical frontmatter; add mix sigra.doctor vs test/example gate | Confident | 136-VERIFICATION.md exact commands; ci.yml:171-219 dep-off lane; lib/mix/tasks/sigra.doctor.ex exists, exits non-zero on misconfig (138-VERIFICATION.md); test/example app runnable (236 tests) |

### Docs Placement (DOC-01)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| doctor usage → guides/recipes/deployment.md; OptionalDeps + recipe-contract + deprecation-timeline notes → MAINTAINING.md ## sections; register extras in mix.exs | Likely | MAINTAINING.md:27/216/224 parallel maintainer sections, wired into ExDoc extras (mix.exs:184); recipe-contract test at test/sigra/recipes/companion_lib_contract_test.exs (maintainer-internal); groups_for_extras (mix.exs:227-234) requires registration |

### Stale-State Reconciliation
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Fix ROADMAP 137 checkboxes/progress (lines 45/70/71/135) in scope for DOC-01; STATE.md + branch-name drift deferred to /gsd-complete-milestone | Likely | ROADMAP.md:45/70/71 unchecked while optional_deps.ex + summaries exist; 137-LEARNINGS.md:21 flags STATE/branch drift separately; ROADMAP.md:41 precedence (ROADMAP+VERIFICATION over STATE) |

## Corrections Made

No corrections to assumptions 1, 3, 4, 5 — all confirmed ("Proceed — all correct").

### Deprecation removal targets (the one escalated decision — touches SemVer-facing public contract)
- **Original assumption:** cookie_opts/0 stub → 0.4.0; audit_forced_password_change/2 → 0.5.0 (staggered).
- **User decision:** Confirmed the recommended staggered schedule — **0.4.0 for the cookie_opts/0 stub, 0.5.0 for audit_forced_password_change/2**.
- **Reason:** One minor of soft-deprecation grace for the still-working function; the raising stub can go in the next minor. SemVer-clean.

## External Research

None performed — internal verification/docs phase; all evidence resolvable from codebase and planning artifacts.
