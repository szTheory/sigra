# Phase 84: routing-honesty-reconciliation - Pattern Map

**Mapped:** 2026-04-25
**Files analyzed:** 6
**Analogs found:** 6 / 6

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `.planning/STATE.md` | config | transform | `.planning/phases/76-post-v1-12-cadence-lock-in/76-VERIFICATION.md` | role-match |
| `.planning/ROADMAP.md` | config | transform | `.planning/phases/52-roadmap-nyquist-milestone-honesty/52-01-PLAN.md` | exact |
| `.planning/PROJECT.md` | config | transform | `.planning/phases/40-tooling-release-ergonomics/40-01-PLAN.md` | exact |
| `.planning/MILESTONES.md` | config | transform | `.planning/phases/40-tooling-release-ergonomics/40-01-PLAN.md` | exact |
| `.planning/phases/84-routing-honesty-reconciliation/84-VERIFICATION.md` | test | transform | `.planning/phases/76-post-v1-12-cadence-lock-in/76-VERIFICATION.md` | exact |
| `.planning/phases/84-routing-honesty-reconciliation/84-VALIDATION.md` | test | transform | `.planning/phases/999.1-nyquist-retroactive-validation-pass/999.1-VALIDATION.md` | role-match |

## Pattern Assignments

### `.planning/ROADMAP.md`

**Primary analog:** `.planning/phases/52-roadmap-nyquist-milestone-honesty/52-01-PLAN.md`

**Why this is closest:** Phase 52 is the cleanest precedent for reconciling a misleading planning surface without touching runtime code. It uses one targeted roadmap edit plus a short reader-routing note.

**Task framing pattern** ([52-01-PLAN.md](/Users/jon/projects/sigra/.planning/phases/52-roadmap-nyquist-milestone-honesty/52-01-PLAN.md:21)):
```md
<objective>
Reconcile `.planning/ROADMAP.md` so phases ... no longer imply unfinished audit work ...
</objective>
```

**Reader-note insertion pattern** ([52-01-PLAN.md](/Users/jon/projects/sigra/.planning/phases/52-roadmap-nyquist-milestone-honesty/52-01-PLAN.md:61)):
```md
<task type="execute">
  <name>Task 2: Add reader note subsection ...</name>
```

**Acceptance style:** grep exact strings, preserve surrounding structure, avoid broad rewrites ([52-01-PLAN.md](/Users/jon/projects/sigra/.planning/phases/52-roadmap-nyquist-milestone-honesty/52-01-PLAN.md:80)).

**Apply to Phase 84:** Use one short task that updates the Phase 84 roadmap row and adjacent notes only if needed, with exact-string checks for:
- `Phase 84`
- `999.1` and `999.2` as archaeology-only
- `newly numbered phases`

### `.planning/PROJECT.md`

**Primary analog:** `.planning/phases/40-tooling-release-ergonomics/40-01-PLAN.md`

**Why this is closest:** Phase 40 is the best precedent for replacing stale live guidance while preserving historical context and pointing readers at the supported path.

**Supersession pattern** ([40-01-PLAN.md](/Users/jon/projects/sigra/.planning/phases/40-tooling-release-ergonomics/40-01-PLAN.md:75)):
```md
<task type="execute">
  <name>Task 2: Supersede audit-open narrative in MILESTONES and PROJECT</name>
```

**Instruction style** ([40-01-PLAN.md](/Users/jon/projects/sigra/.planning/phases/40-tooling-release-ergonomics/40-01-PLAN.md:83)):
```md
1. In `.planning/MILESTONES.md` ... replace that bullet ...
2. In `.planning/PROJECT.md`, update ... to match ...
```

**Key reusable rule from context** ([40-CONTEXT.md](/Users/jon/projects/sigra/.planning/phases/40-tooling-release-ergonomics/40-CONTEXT.md:21)):
```md
Formally deprecate reliance on ... in canonical maintainer/contributor paths ...
```

**Apply to Phase 84:** Update only the live posture lines already present in `PROJECT.md` ([PROJECT.md](/Users/jon/projects/sigra/.planning/PROJECT.md:93), [PROJECT.md](/Users/jon/projects/sigra/.planning/PROJECT.md:95), [PROJECT.md](/Users/jon/projects/sigra/.planning/PROJECT.md:125)). Keep it factual: tombstone remains, future work gets a new numbered phase, `STATE.md` is handoff-only.

### `.planning/MILESTONES.md`

**Primary analog:** `.planning/phases/40-tooling-release-ergonomics/40-01-PLAN.md`

**Why this is closest:** Same artifact class, same “live narrative vs archive honesty” constraint.

**Archive-honesty rule** ([40-CONTEXT.md](/Users/jon/projects/sigra/.planning/phases/40-tooling-release-ergonomics/40-CONTEXT.md:22)):
```md
Do not rewrite milestone archives for aesthetics. Do add supersession notes where live runbooks still instruct the broken command.
```

**Apply to Phase 84:** Touch only current carry-forward bullets such as [MILESTONES.md](/Users/jon/projects/sigra/.planning/MILESTONES.md:84). Do not rewrite old v1.3 history beyond clarifying that `999.1` and `999.2` are historical labels, not executable next steps.

### `.planning/STATE.md`

**Primary analog:** `.planning/phases/76-post-v1-12-cadence-lock-in/76-VERIFICATION.md`

**Why this is closest:** Phase 76 is the nearest recent planning-only phase that changed only planning posture and handoff surfaces.

**Planning-only attestation pattern** ([76-VERIFICATION.md](/Users/jon/projects/sigra/.planning/phases/76-post-v1-12-cadence-lock-in/76-VERIFICATION.md:14)):
```md
## Attestation

Planning artifacts only; no application code changes in Phase 76.
```

**Apply to Phase 84:** Keep the `STATE.md` edits minimal and operational:
- current focus says Phase 84, not `999.1`
- next command points to planning/execution for 84
- artifacts list points at `84-*` and tombstone refs, not at `999.1` as pending work

Current live lines already establish the desired tone: [STATE.md](/Users/jon/projects/sigra/.planning/STATE.md:26), [STATE.md](/Users/jon/projects/sigra/.planning/STATE.md:58), [STATE.md](/Users/jon/projects/sigra/.planning/STATE.md:62).

### `.planning/phases/84-routing-honesty-reconciliation/84-VERIFICATION.md`

**Primary analog:** `.planning/phases/76-post-v1-12-cadence-lock-in/76-VERIFICATION.md`

**Secondary analog:** `.planning/phases/52-roadmap-nyquist-milestone-honesty/52-VERIFICATION.md`

**Why these are closest:** 76 shows the minimal shape for a planning-only verification file; 52 shows how to verify planning-surface honesty with exact evidence bullets and no runtime claims.

**Minimal planning-only verification shape** ([76-VERIFICATION.md](/Users/jon/projects/sigra/.planning/phases/76-post-v1-12-cadence-lock-in/76-VERIFICATION.md:1)):
```md
# Phase 76 — Verification

## Requirements
| ID | Result | Evidence |

## Attestation
Planning artifacts only; no application code changes ...
```

**Evidence-table pattern** ([52-VERIFICATION.md](/Users/jon/projects/sigra/.planning/phases/52-roadmap-nyquist-milestone-honesty/52-VERIFICATION.md:9)):
```md
## Must-haves
| Item | Evidence |
```

**Apply to Phase 84:** Prefer a short verification file with:
- frontmatter
- `# Phase 84 — Verification`
- one `Requirements` or `Must-haves` table for `ROUTE-84-01..03`
- an `Attestation` line: planning artifacts only; no Sigra runtime/library changes
- grep-based checks only

### `.planning/phases/84-routing-honesty-reconciliation/84-VALIDATION.md`

**Primary analog:** `.planning/phases/999.1-nyquist-retroactive-validation-pass/999.1-VALIDATION.md`

**Why this is closest:** Phase 84 must preserve the tombstone boundary instead of copying Phase 36 substance into the new phase directory.

**Boundary pattern** ([999.1-CONTEXT.md](/Users/jon/projects/sigra/.planning/phases/999.1-nyquist-retroactive-validation-pass/999.1-CONTEXT.md:10)):
```md
This directory exists for archaeology, traceability, and agent routing only.
```

**No-reuse rule** ([999.1-CONTEXT.md](/Users/jon/projects/sigra/.planning/phases/999.1-nyquist-retroactive-validation-pass/999.1-CONTEXT.md:12)):
```md
Do not plan or implement audit/Nyquist scope under `999.1-*`; extend or refresh posture via new numbered phases ...
```

**Agent-routing pattern** ([999.1-VALIDATION.md](/Users/jon/projects/sigra/.planning/phases/999.1-nyquist-retroactive-validation-pass/999.1-VALIDATION.md:21)):
```md
Agent routing: ... When supersession text changes, update both this file and ... in one commit.
```

**Apply to Phase 84:** If `84-VALIDATION.md` changes at all, keep it short. It should point at the canonical tombstone pair and Phase 36, and explicitly avoid duplicating inventory/waiver bodies.

## Shared Patterns

### Pattern 1: Small planning-only phases should use exact-scope doc edits

**Sources:** [52-01-PLAN.md](/Users/jon/projects/sigra/.planning/phases/52-roadmap-nyquist-milestone-honesty/52-01-PLAN.md:35), [40-01-PLAN.md](/Users/jon/projects/sigra/.planning/phases/40-tooling-release-ergonomics/40-01-PLAN.md:45)

Use 2-4 small tasks, each bound to named files. Prefer “replace this bullet / add this subsection / keep everything else unchanged” over broad rewrite language.

### Pattern 2: Verification for doc-only phases should be grep-first

**Sources:** [52-01-PLAN.md](/Users/jon/projects/sigra/.planning/phases/52-roadmap-nyquist-milestone-honesty/52-01-PLAN.md:51), [40-01-PLAN.md](/Users/jon/projects/sigra/.planning/phases/40-tooling-release-ergonomics/40-01-PLAN.md:87), [76-VERIFICATION.md](/Users/jon/projects/sigra/.planning/phases/76-post-v1-12-cadence-lock-in/76-VERIFICATION.md:16)

Use exact-string `grep` checks, `test -f`, and at most one repo-wide search proving there are no stale live pointers left.

### Pattern 3: Preserve archaeology, but remove executable misrouting

**Sources:** [40-CONTEXT.md](/Users/jon/projects/sigra/.planning/phases/40-tooling-release-ergonomics/40-CONTEXT.md:22), [999.1-CONTEXT.md](/Users/jon/projects/sigra/.planning/phases/999.1-nyquist-retroactive-validation-pass/999.1-CONTEXT.md:38), [84-CONTEXT.md](/Users/jon/projects/sigra/.planning/phases/84-routing-honesty-reconciliation/84-CONTEXT.md:31)

Do not delete tombstones or old archive references. Replace only live “do this next” routing with a clear supported path.

## Recommended Plan Shape

Best fit is a **single small plan** or **two short plans max**.

**Recommended tasks:**
1. Reconcile live routing surfaces: `STATE.md`, `ROADMAP.md`, `PROJECT.md`, `MILESTONES.md`.
2. Create `84-VERIFICATION.md` as a planning-only evidence file with grep-based checks.
3. Optionally tighten `84-VALIDATION.md` only if needed to restate the tombstone boundary more explicitly.

**Verification boundary:** no runtime tests, no Sigra code changes, no duplication of Phase 36 bodies, no reopening `999.1`, and no new work under `999.x`.

