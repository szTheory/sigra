# Phase 84: Routing honesty reconciliation - Research

**Researched:** 2026-04-25
**Domain:** GSD planning-surface stewardship / routing integrity [VERIFIED: .planning/phases/84-routing-honesty-reconciliation/84-CONTEXT.md]
**Confidence:** HIGH [VERIFIED: .planning/STATE.md] [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/PROJECT.md] [VERIFIED: .planning/MILESTONES.md]

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
### D-84-01 — `999.1` stays closed

- Treat **`999.1`** as a historical tombstone only.
- Do **not** create **`999.1-*-PLAN.md`** or **`999.1-*-SUMMARY.md`** files.
- Do **not** re-open Nyquist work under the **999.x** namespace.

### D-84-02 — Active routing must point at real executable work

- **`STATE.md`**, **`ROADMAP.md`**, and other maintainer-facing planning summaries must not present **`999.1`** as current, next, or planned work.
- If a follow-up is needed, it must point at **Phase 84** or a later newly numbered phase.

### D-84-03 — Canonical evidence remains where it already shipped

- The canonical supersession pair for **`999.1`** remains:
  - **`.planning/phases/999.1-nyquist-retroactive-validation-pass/999.1-CONTEXT.md`**
  - **`.planning/phases/999.1-nyquist-retroactive-validation-pass/999.1-VALIDATION.md`**
- The canonical executed evidence remains under **Phase 36**.
- Phase 84 may reference those files but must not duplicate their substantive bodies.

### D-84-04 — Future validation work needs a new numbered phase

- Any fresh Nyquist, validation, or assurance pass after **v1.19** must be proposed as a new bounded numbered phase with explicit success criteria and verification gates.
- Avoid vague “re-run 999.1” language in all planning surfaces.

### Claude's Discretion

_Not explicitly listed in `84-CONTEXT.md`._ [VERIFIED: .planning/phases/84-routing-honesty-reconciliation/84-CONTEXT.md]

### Specific Ideas

- Prefer minimal, high-signal edits over broad restructuring.
- Keep terminology consistent: **archaeology-only**, **tombstone**, **newly numbered phase**.
- If automation is proposed later, it should enforce the same policy rather than replace it with another duplicated source of truth.

### Deferred Ideas (OUT OF SCOPE)
## Deferred Ideas

- CI or contract test that rejects `STATE.md` pointing at a superseded-only phase.
- Auto-generated “next phase” handoff derived from `ROADMAP.md`.
- Promotion of `999.2` into a real numbered phase if dependency work becomes active again.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ROUTE-84-01 | Eliminate active-workflow pointers that still treat `999.1` as next/current/planned work. [VERIFIED: .planning/REQUIREMENTS.md] | Live-surface grep gates on `STATE.md`, `ROADMAP.md`, `PROJECT.md`, and `MILESTONES.md`; see Validation Architecture. [VERIFIED: .planning/STATE.md] [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/PROJECT.md] [VERIFIED: .planning/MILESTONES.md] |
| ROUTE-84-02 | Keep `999.1` / `999.2` as archaeology-only labels rather than executable backlog items. [VERIFIED: .planning/REQUIREMENTS.md] | Preserve tombstone wording in `999.1-*`; preserve backlog wording in live docs; do not rewrite milestone archives unless explicitly requested. [VERIFIED: .planning/phases/999.1-nyquist-retroactive-validation-pass/999.1-CONTEXT.md] [VERIFIED: .planning/phases/999.1-nyquist-retroactive-validation-pass/999.1-VALIDATION.md] [VERIFIED: .planning/ROADMAP.md] |
| ROUTE-84-03 | Route any future assurance work to newly numbered phases, not `999.x`. [VERIFIED: .planning/REQUIREMENTS.md] | Preserve the wording convention already present in `84-CONTEXT.md`, `ROADMAP.md`, and `PROJECT.md`; add no new `999.1-*PLAN/SUMMARY` artifacts. [VERIFIED: .planning/phases/84-routing-honesty-reconciliation/84-CONTEXT.md] [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/PROJECT.md] |
</phase_requirements>

## Summary

Phase 84 is a planning-surface stewardship phase only; no Sigra runtime, library, generator, or host-app code changes are in scope. [VERIFIED: .planning/phases/84-routing-honesty-reconciliation/84-CONTEXT.md] The canonical supersession pair for `999.1` remains `999.1-CONTEXT.md` plus `999.1-VALIDATION.md`, and the canonical executed evidence remains under Phase 36 inventory and waivers. [VERIFIED: .planning/phases/84-routing-honesty-reconciliation/84-CONTEXT.md] [VERIFIED: .planning/phases/999.1-nyquist-retroactive-validation-pass/999.1-CONTEXT.md] [VERIFIED: .planning/phases/999.1-nyquist-retroactive-validation-pass/999.1-VALIDATION.md] [VERIFIED: .planning/phases/36-retroactive-nyquist-validation/36-INVENTORY.md] [VERIFIED: .planning/phases/36-retroactive-nyquist-validation/36-WAIVERS.md]

Current live planning hubs are already substantially reconciled: `STATE.md` points next work to Phase 84 and explicitly says `999.1` remains archaeology-only; `ROADMAP.md` frames Phase 84 as the live follow-up and keeps `999.1`/`999.2` in backlog archaeology; `PROJECT.md` states planning precedence and bans new assurance work under `999.x`; `MILESTONES.md` describes `999.1` and `999.2` as historical parking-lot labels. [VERIFIED: .planning/STATE.md] [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/PROJECT.md] [VERIFIED: .planning/MILESTONES.md]

The remaining direct invitations to reopen `999.1` appear in archived milestone documents, especially the old v1.0/v1.1 roadmaps. [VERIFIED: .planning/milestones/v1.0-ROADMAP.md] [VERIFIED: .planning/milestones/v1.1-ROADMAP.md] Those files are historical records, not live routing surfaces, and the current live docs already override them with archaeology-only wording and Phase 84 routing. [VERIFIED: .planning/PROJECT.md] [VERIFIED: .planning/ROADMAP.md] The smallest safe Phase 84 therefore stays bounded: verify and preserve live-surface honesty, tighten only any still-live wording found by grep at execution time, and leave archived milestone backlog prose untouched unless maintainers explicitly choose archive normalization. [VERIFIED: .planning/phases/84-routing-honesty-reconciliation/84-CONTEXT.md] [VERIFIED: .planning/milestones/v1.0-ROADMAP.md]

**Primary recommendation:** Execute Phase 84 as a live-planning audit and attestation pass with zero expected runtime/package work; only edit a live planning surface if a same-turn grep still exposes an executable `999.1` pointer, and do not rewrite archived milestone history by default. [VERIFIED: .planning/phases/84-routing-honesty-reconciliation/84-CONTEXT.md] [VERIFIED: .planning/STATE.md] [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/PROJECT.md] [VERIFIED: .planning/MILESTONES.md] [VERIFIED: .planning/milestones/v1.0-ROADMAP.md]

## Project Constraints (from CLAUDE.md)

- Start file-changing work through a GSD command so planning artifacts stay in sync. [VERIFIED: CLAUDE.md]
- `STATE.md`/planning work does not bypass the repo workflow, but direct edits are allowed here because the user explicitly asked for a research artifact in the phase directory. [VERIFIED: CLAUDE.md]
- Local full test execution needs a live Postgres at `localhost:5432` with `postgres/postgres`; this phase does not require runtime tests, so the planner should prefer grep/file-existence verification over `mix test`. [VERIFIED: CLAUDE.md]
- Project testing conventions remain comprehensive, AAA-style, and flat/self-contained when tests are needed later. [VERIFIED: CLAUDE.md]
- Phoenix 1.8+ / Ecto 3.x, PostgreSQL primary, OWASP posture, minimal deps, and LiveView-optional design are project-wide constraints, but this phase must not change runtime/library code. [VERIFIED: CLAUDE.md] [VERIFIED: .planning/phases/84-routing-honesty-reconciliation/84-CONTEXT.md]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Active routing truth for “what to do next” | Planning docs / repo metadata [VERIFIED: .planning/STATE.md] | — | `STATE.md`, `ROADMAP.md`, and `PROJECT.md` are the human/agent entry points for current work selection. [VERIFIED: .planning/STATE.md] [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/PROJECT.md] |
| Tombstone preservation for `999.1` | Phase tombstone directory [VERIFIED: .planning/phases/999.1-nyquist-retroactive-validation-pass/999.1-CONTEXT.md] | Phase 36 evidence [VERIFIED: .planning/phases/36-retroactive-nyquist-validation/36-INVENTORY.md] | `999.1-*` explains supersession; Phase 36 holds the real inventory/waivers. [VERIFIED: .planning/phases/999.1-nyquist-retroactive-validation-pass/999.1-VALIDATION.md] [VERIFIED: .planning/phases/36-retroactive-nyquist-validation/36-WAIVERS.md] |
| Future assurance routing | Live roadmap / project framing [VERIFIED: .planning/ROADMAP.md] | New numbered phase directories [VERIFIED: .planning/phases/84-routing-honesty-reconciliation/84-CONTEXT.md] | Live docs define that future validation work must use newly numbered phases, not `999.x`. [VERIFIED: .planning/PROJECT.md] [VERIFIED: .planning/phases/84-routing-honesty-reconciliation/84-CONTEXT.md] |
| Historical backlog archaeology | Archived milestone docs [VERIFIED: .planning/milestones/v1.0-ROADMAP.md] | `MILESTONES.md` carry-forward summaries [VERIFIED: .planning/MILESTONES.md] | Archive files record prior state and should not be mistaken for active routing surfaces. [VERIFIED: .planning/PROJECT.md] |

## Standard Stack

### Core
| Library / Artifact | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `.planning/STATE.md` | repo-local [VERIFIED: .planning/STATE.md] | Session handoff and next-step pointer | This is the live “what’s next” surface and must never point at superseded `999.1`. [VERIFIED: .planning/STATE.md] [VERIFIED: .planning/phases/999.1-nyquist-retroactive-validation-pass/999.1-CONTEXT.md] |
| `.planning/ROADMAP.md` | repo-local [VERIFIED: .planning/ROADMAP.md] | Canonical live roadmap / backlog routing | It already distinguishes planned Phase 84 from archaeology-only `999.x`. [VERIFIED: .planning/ROADMAP.md] |
| `999.1-CONTEXT.md` + `999.1-VALIDATION.md` | repo-local [VERIFIED: .planning/phases/999.1-nyquist-retroactive-validation-pass/999.1-CONTEXT.md] | Tombstone pair for superseded backlog label | The pair is the current canonical machine/human redirect for `999.1`. [VERIFIED: .planning/phases/999.1-nyquist-retroactive-validation-pass/999.1-CONTEXT.md] [VERIFIED: .planning/phases/999.1-nyquist-retroactive-validation-pass/999.1-VALIDATION.md] |

### Supporting
| Library / Artifact | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Phase 36 evidence (`36-INVENTORY.md`, `36-WAIVERS.md`) | repo-local [VERIFIED: .planning/phases/36-retroactive-nyquist-validation/36-INVENTORY.md] | Canonical executed Nyquist evidence | Use when a live planning surface needs to point to the real historical work without duplicating bodies. [VERIFIED: .planning/phases/36-retroactive-nyquist-validation/36-WAIVERS.md] |
| `rg` / file-existence checks | tooling present in session via repo workflow [VERIFIED: codebase grep] | Validation for doc-only routing integrity | Use for merge-gate style checks instead of runtime tests for this phase. [VERIFIED: .planning/phases/84-routing-honesty-reconciliation/84-VALIDATION.md] |
| `84-CONTEXT.md` + `84-VALIDATION.md` | repo-local [VERIFIED: .planning/phases/84-routing-honesty-reconciliation/84-CONTEXT.md] | Boundaries and verification contract for this cleanup | Use as the only Phase 84-specific execution scope; do not widen into archive rewriting or runtime work. [VERIFIED: .planning/phases/84-routing-honesty-reconciliation/84-VALIDATION.md] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Live-surface audit only [VERIFIED: .planning/STATE.md] | Rewrite archived milestone backlog text [VERIFIED: .planning/milestones/v1.0-ROADMAP.md] | Rewriting archives reduces historical fidelity and is not required to fix active routing because live docs already supersede archive wording. [VERIFIED: .planning/PROJECT.md] |
| Keep `999.1` closed [VERIFIED: .planning/phases/84-routing-honesty-reconciliation/84-CONTEXT.md] | Reopen work under `999.1-*` | This violates locked decisions and conflicts with the tombstone pair. [VERIFIED: .planning/phases/84-routing-honesty-reconciliation/84-CONTEXT.md] [VERIFIED: .planning/phases/999.1-nyquist-retroactive-validation-pass/999.1-CONTEXT.md] |
| Reference Phase 36 evidence [VERIFIED: .planning/phases/36-retroactive-nyquist-validation/36-INVENTORY.md] | Duplicate Phase 36 inventory/waiver bodies into Phase 84 docs | Duplication creates drift and contradicts locked decision D-84-03. [VERIFIED: .planning/phases/84-routing-honesty-reconciliation/84-CONTEXT.md] |

**Installation:** No package installation is required for this phase. [VERIFIED: .planning/phases/84-routing-honesty-reconciliation/84-CONTEXT.md]

**Version verification:** Not applicable; this phase uses existing planning artifacts and shell-level grep/file checks rather than adding runtime dependencies. [VERIFIED: .planning/phases/84-routing-honesty-reconciliation/84-CONTEXT.md]

## Architecture Patterns

### System Architecture Diagram

```text
Maintainer / agent request
        |
        v
Live planning hubs
STATE.md -> ROADMAP.md -> PROJECT.md
        |          |           |
        |          |           v
        |          |    rule: future assurance = new numbered phase
        |          v
        |    if 999.1 appears, treat as archaeology-only
        v
Phase 84 stewardship pass
        |
        +--> preserve tombstone pair
        |      999.1-CONTEXT.md + 999.1-VALIDATION.md
        |
        +--> point to canonical executed evidence
               Phase 36 INVENTORY + WAIVERS
        |
        +--> leave archived milestone history untouched by default
```

The primary data flow is “active routing surface -> tombstone redirect -> canonical evidence,” not “archive backlog -> executable work.” [VERIFIED: .planning/STATE.md] [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/phases/999.1-nyquist-retroactive-validation-pass/999.1-CONTEXT.md] [VERIFIED: .planning/phases/36-retroactive-nyquist-validation/36-INVENTORY.md]

### Recommended Project Structure
```text
.planning/
├── STATE.md                         # Current handoff and next-step routing
├── ROADMAP.md                       # Canonical live queue and backlog posture
├── PROJECT.md                       # Planning precedence and milestone framing
├── MILESTONES.md                    # Archived milestone summaries / carry-forward notes
└── phases/
    ├── 84-routing-honesty-reconciliation/
    │   ├── 84-CONTEXT.md            # Locked scope and wording conventions
    │   ├── 84-VALIDATION.md         # Doc-only acceptance checks
    │   └── 84-RESEARCH.md           # This research artifact
    ├── 999.1-nyquist-retroactive-validation-pass/
    │   ├── 999.1-CONTEXT.md         # Tombstone policy
    │   └── 999.1-VALIDATION.md      # Superseded pointer
    └── 36-retroactive-nyquist-validation/
        ├── 36-INVENTORY.md          # Canonical evidence
        └── 36-WAIVERS.md            # Canonical evidence
```

### Pattern 1: Hub-and-Spoke Routing
**What:** Keep live routing truth in `STATE.md`, `ROADMAP.md`, and `PROJECT.md`, and use `999.1-*` only as a redirect spoke to Phase 36 evidence. [VERIFIED: .planning/STATE.md] [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/PROJECT.md] [VERIFIED: .planning/phases/999.1-nyquist-retroactive-validation-pass/999.1-CONTEXT.md]
**When to use:** Any time a superseded backlog label still needs discoverability without becoming executable work. [VERIFIED: .planning/phases/999.1-nyquist-retroactive-validation-pass/999.1-CONTEXT.md]
**Example:**
```markdown
Current focus: v1.19 closed. Next planning follow-up: Phase 84. 999.1 remains archaeology-only.

999.1 — historical parking-lot label; keep as archaeology only. Do not plan new work under 999.x.
```
Source: local verified wording pattern from `STATE.md` and `ROADMAP.md`. [VERIFIED: .planning/STATE.md] [VERIFIED: .planning/ROADMAP.md]

### Pattern 2: Tombstone Pair, Not Reopened Phase
**What:** Preserve both `999.1-CONTEXT.md` and `999.1-VALIDATION.md` as the short supersession pair. [VERIFIED: .planning/phases/999.1-nyquist-retroactive-validation-pass/999.1-CONTEXT.md] [VERIFIED: .planning/phases/999.1-nyquist-retroactive-validation-pass/999.1-VALIDATION.md]
**When to use:** When agents and humans may grep for either context or validation artifacts and need the same redirect. [VERIFIED: .planning/phases/999.1-nyquist-retroactive-validation-pass/999.1-CONTEXT.md]
**Example:**
```markdown
# 999.1 — Superseded

The backlog card 999.1 is executed as v1.3 Phase 36. Evidence lives in 36-INVENTORY.md and 36-WAIVERS.md.
```
Source: local verified tombstone pattern. [VERIFIED: .planning/phases/999.1-nyquist-retroactive-validation-pass/999.1-VALIDATION.md]

### Pattern 3: Archive Freeze by Default
**What:** Treat archived milestone roadmaps as historical evidence, not live routing surfaces. [VERIFIED: .planning/milestones/v1.0-ROADMAP.md] [VERIFIED: .planning/milestones/v1.1-ROADMAP.md] [VERIFIED: .planning/PROJECT.md]
**When to use:** When older milestone docs still show obsolete backlog promotion language but live docs already supersede it. [VERIFIED: .planning/milestones/v1.0-ROADMAP.md] [VERIFIED: .planning/ROADMAP.md]
**Example:**
```markdown
Archive says: "promote with /gsd-discuss-phase 999.1"
Live rule says: future assurance work uses newly numbered phases.
Action: preserve archive, fix only live routing if stale.
```
Source: local verified contrast between archive and live docs. [VERIFIED: .planning/milestones/v1.0-ROADMAP.md] [VERIFIED: .planning/PROJECT.md]

### Anti-Patterns to Avoid
- **Reopening `999.1` with new plans or summaries:** This violates locked scope and turns a tombstone into an active namespace again. [VERIFIED: .planning/phases/84-routing-honesty-reconciliation/84-CONTEXT.md]
- **Duplicating Phase 36 inventory or waiver bodies into Phase 84 docs:** This creates drift and contradicts the “canonical evidence remains where it already shipped” rule. [VERIFIED: .planning/phases/84-routing-honesty-reconciliation/84-CONTEXT.md] [VERIFIED: .planning/phases/36-retroactive-nyquist-validation/36-INVENTORY.md]
- **Treating `STATE.md` as an independent roadmap:** `PROJECT.md` explicitly gives precedence to `ROADMAP.md` and phase verification/validation artifacts over conflicting `STATE.md` notes. [VERIFIED: .planning/PROJECT.md]
- **Normalizing archived milestone prose as part of this phase by default:** Archived docs still contain old backlog wording, but they are not the active routing surfaces and should stay archaeological unless maintainers explicitly request history cleanup. [VERIFIED: .planning/milestones/v1.0-ROADMAP.md] [VERIFIED: .planning/milestones/v1.1-ROADMAP.md] [VERIFIED: .planning/PROJECT.md]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Redirecting superseded phase work | New `999.1-*PLAN.md` or `999.1-*SUMMARY.md` files [VERIFIED: .planning/phases/84-routing-honesty-reconciliation/84-CONTEXT.md] | Existing tombstone pair + Phase 84 live routing [VERIFIED: .planning/phases/999.1-nyquist-retroactive-validation-pass/999.1-CONTEXT.md] | New execution files would falsely imply `999.1` is active again. [VERIFIED: .planning/phases/84-routing-honesty-reconciliation/84-CONTEXT.md] |
| Historical evidence recap | Re-copying Phase 36 tables into Phase 84 docs [VERIFIED: .planning/phases/36-retroactive-nyquist-validation/36-INVENTORY.md] | Link to `36-INVENTORY.md` / `36-WAIVERS.md` [VERIFIED: .planning/phases/36-retroactive-nyquist-validation/36-WAIVERS.md] | Canonical evidence already exists and duplication would drift. [VERIFIED: .planning/phases/84-routing-honesty-reconciliation/84-CONTEXT.md] |
| Active-work validation for doc-only changes | Runtime test suites or new helper libraries [VERIFIED: .planning/phases/84-routing-honesty-reconciliation/84-VALIDATION.md] | Grep and file-existence checks [VERIFIED: codebase grep] | The phase goal is wording/routing integrity, not behavior in Elixir runtime code. [VERIFIED: .planning/phases/84-routing-honesty-reconciliation/84-CONTEXT.md] |
| Fixing archive confusion | Broad milestone archive rewrites [VERIFIED: .planning/milestones/v1.0-ROADMAP.md] | Small live-surface clarification in current docs if needed [VERIFIED: .planning/ROADMAP.md] | Archive edits are higher-risk and lower-signal than reinforcing current canonical routing. [VERIFIED: .planning/PROJECT.md] |

**Key insight:** The safe implementation is not “rewrite every `999.1` mention”; it is “separate live routing from archaeology and guard only the live routing surfaces.” [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/PROJECT.md] [VERIFIED: .planning/milestones/v1.0-ROADMAP.md]

## Common Pitfalls

### Pitfall 1: Fixing Archives Instead of Live Routing
**What goes wrong:** The phase expands into editing old milestone archives because they still contain historical backlog language for `999.1`. [VERIFIED: .planning/milestones/v1.0-ROADMAP.md] [VERIFIED: .planning/milestones/v1.1-ROADMAP.md]
**Why it happens:** Grep finds every mention equally, but not every mention is a live executable pointer. [VERIFIED: codebase grep]
**How to avoid:** Split findings into live planning hubs vs archived milestones before editing anything. [VERIFIED: .planning/PROJECT.md]
**Warning signs:** Proposed edits touch `milestones/v1.0-ROADMAP.md` or `milestones/v1.1-ROADMAP.md` even though `STATE.md` and `ROADMAP.md` are already honest. [VERIFIED: .planning/STATE.md] [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/milestones/v1.0-ROADMAP.md]

### Pitfall 2: Breaking the Tombstone Pair
**What goes wrong:** One of `999.1-CONTEXT.md` or `999.1-VALIDATION.md` changes without the other, producing inconsistent supersession text. [VERIFIED: .planning/phases/999.1-nyquist-retroactive-validation-pass/999.1-CONTEXT.md] [VERIFIED: .planning/phases/999.1-nyquist-retroactive-validation-pass/999.1-VALIDATION.md]
**Why it happens:** Maintainers treat the files as separate artifacts instead of a paired redirect. [VERIFIED: .planning/phases/999.1-nyquist-retroactive-validation-pass/999.1-CONTEXT.md]
**How to avoid:** If a tombstone wording change is unavoidable, update both files in the same commit. [VERIFIED: .planning/phases/999.1-nyquist-retroactive-validation-pass/999.1-CONTEXT.md] [VERIFIED: .planning/phases/999.1-nyquist-retroactive-validation-pass/999.1-VALIDATION.md]
**Warning signs:** One file says “Phase 36” while the other points elsewhere or uses different routing rules. [VERIFIED: .planning/phases/999.1-nyquist-retroactive-validation-pass/999.1-VALIDATION.md]

### Pitfall 3: Letting `STATE.md` Behave Like a Second Roadmap
**What goes wrong:** `STATE.md` reintroduces a stale “next” pointer even while `ROADMAP.md` and `PROJECT.md` are correct. [VERIFIED: .planning/phases/999.1-nyquist-retroactive-validation-pass/999.1-CONTEXT.md]
**Why it happens:** Session handoff text is easier to update casually than roadmap posture. [VERIFIED: .planning/STATE.md]
**How to avoid:** Verify the `Current focus`, `Phase`, and `Next` lines in `STATE.md` against `ROADMAP.md` before closing Phase 84. [VERIFIED: .planning/STATE.md] [VERIFIED: .planning/ROADMAP.md]
**Warning signs:** `STATE.md` mentions `999.1` near “current,” “next,” or “ready to plan.” [VERIFIED: codebase grep]

## Code Examples

Verified patterns from local planning surfaces:

### Live-Surface Wording Pattern
```markdown
**Current focus:** v1.19 closed (82–83). Next planning follow-up: Phase 84. `999.1` remains archaeology-only.
```
Source: `.planning/STATE.md`. [VERIFIED: .planning/STATE.md]

### Backlog Archaeology Pattern
```markdown
- 999.1 / 999.2 — historical parking-lot labels; shipped in v1.3; keep directories under `.planning/phases/` as archaeology only. Do not plan new work under 999.x; use newly numbered phases.
```
Source: `.planning/ROADMAP.md`. [VERIFIED: .planning/ROADMAP.md]

### Planning-Precedence Pattern
```markdown
Planning precedence: ROADMAP.md + phase *-VERIFICATION.md / *-VALIDATION.md over conflicting STATE.md notes.
```
Source: `.planning/PROJECT.md`. [VERIFIED: .planning/PROJECT.md]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Archived v1.0 backlog invited promotion via `/gsd-discuss-phase 999.1`. [VERIFIED: .planning/milestones/v1.0-ROADMAP.md] | Live docs route current work to Phase 84 and treat `999.1` as archaeology-only. [VERIFIED: .planning/STATE.md] [VERIFIED: .planning/ROADMAP.md] | Archive wording dates to v1.0; live routing is updated by 2026-04-25. [VERIFIED: .planning/milestones/v1.0-ROADMAP.md] [VERIFIED: .planning/STATE.md] | Active workflows no longer depend on `999.1`, so Phase 84 should not reopen the namespace. [VERIFIED: .planning/STATE.md] [VERIFIED: .planning/phases/84-routing-honesty-reconciliation/84-CONTEXT.md] |
| `999.1` started as a backlog card for Nyquist backfill. [VERIFIED: .planning/milestones/v1.0-ROADMAP.md] | `999.1` is now a tombstone pair pointing to Phase 36 evidence. [VERIFIED: .planning/phases/999.1-nyquist-retroactive-validation-pass/999.1-CONTEXT.md] [VERIFIED: .planning/phases/999.1-nyquist-retroactive-validation-pass/999.1-VALIDATION.md] | Supersession is in place by 2026-04-23. [VERIFIED: .planning/phases/999.1-nyquist-retroactive-validation-pass/999.1-CONTEXT.md] | Future assurance work must use a new numbered phase. [VERIFIED: .planning/phases/84-routing-honesty-reconciliation/84-CONTEXT.md] |
| Phase 36 executed the retroactive Nyquist cleanup. [VERIFIED: .planning/phases/36-retroactive-nyquist-validation/36-INVENTORY.md] | Phase 84 is only routing-honesty cleanup and must reference, not duplicate, Phase 36 bodies. [VERIFIED: .planning/phases/84-routing-honesty-reconciliation/84-CONTEXT.md] | Phase 36 shipped 2026-04-17 to 2026-04-19; Phase 84 opened 2026-04-25. [VERIFIED: .planning/phases/36-retroactive-nyquist-validation/36-INVENTORY.md] [VERIFIED: .planning/phases/84-routing-honesty-reconciliation/84-CONTEXT.md] | Keeps the cleanup bounded and avoids archaeological duplication. [VERIFIED: .planning/phases/84-routing-honesty-reconciliation/84-CONTEXT.md] |

**Deprecated/outdated:**
- Reusing `999.1` as an execution namespace: replaced by tombstone-only routing plus new numbered phases for fresh assurance work. [VERIFIED: .planning/phases/84-routing-honesty-reconciliation/84-CONTEXT.md] [VERIFIED: .planning/phases/999.1-nyquist-retroactive-validation-pass/999.1-CONTEXT.md]

## Assumptions Log

All claims in this research were verified from the current repo state; no user-confirmation assumptions are required. [VERIFIED: codebase grep]

## Open Questions (RESOLVED)

1. **Should archived milestone backlog prose be normalized later?**
   - Resolution: **No, not in Phase 84.** Archived milestone docs remain archaeology unless maintainers explicitly promote a separate numbered archive-normalization phase. [VERIFIED: .planning/milestones/v1.0-ROADMAP.md] [VERIFIED: .planning/PROJECT.md]

2. **Does Phase 84 need any live-file edits at all beyond its own execution artifacts?**
   - Resolution: **Only if exact live-surface checks fail.** Execution should begin with anchored checks against the current routing fields in `STATE.md` plus explicit `/gsd-* 999.1` command pointers in live planning hubs; if those checks are already green, Phase 84 closes as an attestation/minimal-touch cleanup instead of forcing cosmetic edits. [VERIFIED: .planning/STATE.md] [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/PROJECT.md] [VERIFIED: .planning/MILESTONES.md] [VERIFIED: .planning/phases/84-routing-honesty-reconciliation/84-VALIDATION.md]

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Shell `rg` + file-existence checks over `.planning/` surfaces. [VERIFIED: .planning/phases/84-routing-honesty-reconciliation/84-VALIDATION.md] |
| Config file | none — phase-local validation is grep-driven. [VERIFIED: .planning/phases/84-routing-honesty-reconciliation/84-VALIDATION.md] |
| Quick run command | `rg -n "Phase 84|archaeology-only|newly numbered phase|999\\.1|999\\.2" .planning/STATE.md .planning/ROADMAP.md .planning/PROJECT.md .planning/MILESTONES.md .planning/phases/84-routing-honesty-reconciliation/84-CONTEXT.md .planning/phases/84-routing-honesty-reconciliation/84-VALIDATION.md .planning/phases/999.1-nyquist-retroactive-validation-pass/999.1-CONTEXT.md .planning/phases/999.1-nyquist-retroactive-validation-pass/999.1-VALIDATION.md` [VERIFIED: codebase grep] |
| Full suite command | `test -f .planning/phases/999.1-nyquist-retroactive-validation-pass/999.1-CONTEXT.md && test -f .planning/phases/999.1-nyquist-retroactive-validation-pass/999.1-VALIDATION.md && test -f .planning/phases/36-retroactive-nyquist-validation/36-INVENTORY.md && test -f .planning/phases/36-retroactive-nyquist-validation/36-WAIVERS.md && ! rg -n '^\\*\\*Next:\\*\\*.*999\\.1|^\\*\\*Planned Phase:\\*\\*.*999\\.1|^Phase:.*999\\.1|^Status:.*999\\.1' .planning/STATE.md && ! rg -n '/gsd-(discuss|plan|execute)-phase 999\\.1' .planning/STATE.md .planning/ROADMAP.md .planning/PROJECT.md .planning/MILESTONES.md` [VERIFIED: codebase grep] |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ROUTE-84-01 | No live planning surface treats `999.1` as next/current/planned work. [VERIFIED: .planning/REQUIREMENTS.md] | grep | `! rg -n '^\\*\\*Next:\\*\\*.*999\\.1|^\\*\\*Planned Phase:\\*\\*.*999\\.1|^Phase:.*999\\.1|^Status:.*999\\.1' .planning/STATE.md && ! rg -n '/gsd-(discuss|plan|execute)-phase 999\\.1' .planning/STATE.md .planning/ROADMAP.md .planning/PROJECT.md .planning/MILESTONES.md` | ✅ [VERIFIED: .planning/STATE.md] |
| ROUTE-84-02 | `999.1` / `999.2` are described as archaeology-only in live planning docs. [VERIFIED: .planning/REQUIREMENTS.md] | grep | `rg -n "archaeology-only|historical parking-lot label|Do not plan new work under \\*\\*999.x\\*\\*" .planning/ROADMAP.md .planning/PROJECT.md .planning/MILESTONES.md` | ✅ [VERIFIED: .planning/ROADMAP.md] |
| ROUTE-84-03 | Future assurance work is routed to new numbered phases, not `999.x`. [VERIFIED: .planning/REQUIREMENTS.md] | grep + file existence | `rg -n "newly numbered phase|new numbered phase|Phase 84|later newly numbered phase" .planning/phases/84-routing-honesty-reconciliation/84-CONTEXT.md .planning/ROADMAP.md .planning/PROJECT.md && test -f .planning/phases/999.1-nyquist-retroactive-validation-pass/999.1-CONTEXT.md && test -f .planning/phases/999.1-nyquist-retroactive-validation-pass/999.1-VALIDATION.md` | ✅ [VERIFIED: .planning/phases/84-routing-honesty-reconciliation/84-CONTEXT.md] |

### Sampling Rate
- **Per task commit:** run the quick grep suite above. [VERIFIED: .planning/phases/84-routing-honesty-reconciliation/84-VALIDATION.md]
- **Per wave merge:** run the full file-existence + negative-pointer grep suite. [VERIFIED: codebase grep]
- **Phase gate:** all live-surface negative checks green and canonical tombstone/evidence files still present before `/gsd-verify-work`. [VERIFIED: .planning/phases/84-routing-honesty-reconciliation/84-VALIDATION.md]

### Wave 0 Gaps
- [ ] No dedicated scripted contract exists yet for “live planning surface must not point at superseded phase”; Phase 84 should rely on explicit grep commands unless maintainers later promote the deferred CI idea. [VERIFIED: .planning/phases/84-routing-honesty-reconciliation/84-CONTEXT.md]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no [VERIFIED: .planning/phases/84-routing-honesty-reconciliation/84-CONTEXT.md] | Not in scope for doc-only routing work. [VERIFIED: .planning/phases/84-routing-honesty-reconciliation/84-CONTEXT.md] |
| V3 Session Management | no [VERIFIED: .planning/phases/84-routing-honesty-reconciliation/84-CONTEXT.md] | Not in scope for doc-only routing work. [VERIFIED: .planning/phases/84-routing-honesty-reconciliation/84-CONTEXT.md] |
| V4 Access Control | yes [VERIFIED: .planning/PROJECT.md] | Planning precedence keeps live routing authority in `ROADMAP.md` plus phase validation/verification artifacts rather than ad hoc notes. [VERIFIED: .planning/PROJECT.md] |
| V5 Input Validation | yes [VERIFIED: .planning/phases/84-routing-honesty-reconciliation/84-VALIDATION.md] | Exact grep/file-existence checks on live planning surfaces. [VERIFIED: codebase grep] |
| V6 Cryptography | no [VERIFIED: .planning/phases/84-routing-honesty-reconciliation/84-CONTEXT.md] | Not in scope. [VERIFIED: .planning/phases/84-routing-honesty-reconciliation/84-CONTEXT.md] |

### Known Threat Patterns for planning-surface stewardship

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Stale executable pointer to superseded `999.1` | Tampering [VERIFIED: .planning/phases/999.1-nyquist-retroactive-validation-pass/999.1-CONTEXT.md] | Negative grep gate on live routing surfaces and explicit Phase 84 routing. [VERIFIED: .planning/STATE.md] [VERIFIED: .planning/ROADMAP.md] |
| Duplicate source of truth between `STATE.md` and roadmap/phase artifacts | Repudiation [VERIFIED: .planning/PROJECT.md] | Enforce planning precedence and verify `STATE.md` against `ROADMAP.md` before closure. [VERIFIED: .planning/PROJECT.md] [VERIFIED: .planning/STATE.md] |
| Archive rewrite that erases historical context | Tampering [VERIFIED: .planning/milestones/v1.0-ROADMAP.md] | Keep archived milestone files frozen unless an explicit archive-normalization phase is approved. [VERIFIED: .planning/PROJECT.md] |

## Sources

### Primary (HIGH confidence)
- `.planning/phases/84-routing-honesty-reconciliation/84-CONTEXT.md` - locked scope, wording conventions, and canonical refs. [VERIFIED: .planning/phases/84-routing-honesty-reconciliation/84-CONTEXT.md]
- `.planning/phases/84-routing-honesty-reconciliation/84-VALIDATION.md` - doc-only validation expectations. [VERIFIED: .planning/phases/84-routing-honesty-reconciliation/84-VALIDATION.md]
- `.planning/STATE.md` - current live handoff routing. [VERIFIED: .planning/STATE.md]
- `.planning/ROADMAP.md` - current live roadmap/backlog posture for Phase 84 and `999.x`. [VERIFIED: .planning/ROADMAP.md]
- `.planning/PROJECT.md` - planning precedence and later-candidate routing rules. [VERIFIED: .planning/PROJECT.md]
- `.planning/MILESTONES.md` - archived milestone carry-forward summaries for `999.1` and `999.2`. [VERIFIED: .planning/MILESTONES.md]
- `.planning/phases/999.1-nyquist-retroactive-validation-pass/999.1-CONTEXT.md` - tombstone policy and paired-file rule. [VERIFIED: .planning/phases/999.1-nyquist-retroactive-validation-pass/999.1-CONTEXT.md]
- `.planning/phases/999.1-nyquist-retroactive-validation-pass/999.1-VALIDATION.md` - short superseded pointer. [VERIFIED: .planning/phases/999.1-nyquist-retroactive-validation-pass/999.1-VALIDATION.md]
- `.planning/phases/36-retroactive-nyquist-validation/36-INVENTORY.md` - canonical Phase 36 inventory. [VERIFIED: .planning/phases/36-retroactive-nyquist-validation/36-INVENTORY.md]
- `.planning/phases/36-retroactive-nyquist-validation/36-WAIVERS.md` - canonical Phase 36 waivers. [VERIFIED: .planning/phases/36-retroactive-nyquist-validation/36-WAIVERS.md]
- `.planning/milestones/v1.0-ROADMAP.md` and `.planning/milestones/v1.1-ROADMAP.md` - historical archive wording that should be treated as archaeology, not live routing. [VERIFIED: .planning/milestones/v1.0-ROADMAP.md] [VERIFIED: .planning/milestones/v1.1-ROADMAP.md]
- `CLAUDE.md` - project-specific workflow and testing constraints. [VERIFIED: CLAUDE.md]

### Secondary (MEDIUM confidence)
- None. [VERIFIED: codebase grep]

### Tertiary (LOW confidence)
- None. [VERIFIED: codebase grep]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - repo-local artifacts and grep-driven workflow were directly verified. [VERIFIED: .planning/STATE.md] [VERIFIED: .planning/ROADMAP.md]
- Architecture: HIGH - routing ownership and canonical evidence paths are explicit in current planning docs. [VERIFIED: .planning/PROJECT.md] [VERIFIED: .planning/phases/84-routing-honesty-reconciliation/84-CONTEXT.md]
- Pitfalls: HIGH - archive-vs-live tension and tombstone-pair rules are visible in current docs and grep output. [VERIFIED: .planning/milestones/v1.0-ROADMAP.md] [VERIFIED: .planning/phases/999.1-nyquist-retroactive-validation-pass/999.1-CONTEXT.md]

**Research date:** 2026-04-25
**Valid until:** 2026-05-02 [VERIFIED: .planning/STATE.md]

## RESEARCH COMPLETE

**Phase:** 84 - routing-honesty-reconciliation
**Confidence:** HIGH

### Key Findings
- Live planning hubs are already mostly reconciled: `STATE.md`, `ROADMAP.md`, `PROJECT.md`, and `MILESTONES.md` all treat `999.1` as archaeology-only and route active work to Phase 84 or later numbered phases. [VERIFIED: .planning/STATE.md] [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/PROJECT.md] [VERIFIED: .planning/MILESTONES.md]
- The canonical supersession pair is already correct and should be preserved as-is: `999.1-CONTEXT.md` plus `999.1-VALIDATION.md`; Phase 36 remains the only canonical evidence body. [VERIFIED: .planning/phases/999.1-nyquist-retroactive-validation-pass/999.1-CONTEXT.md] [VERIFIED: .planning/phases/999.1-nyquist-retroactive-validation-pass/999.1-VALIDATION.md] [VERIFIED: .planning/phases/36-retroactive-nyquist-validation/36-INVENTORY.md] [VERIFIED: .planning/phases/36-retroactive-nyquist-validation/36-WAIVERS.md]
- The stale “promote 999.1” language that still exists is in archived milestone docs, not live routing surfaces; Phase 84 should not rewrite those archives by default. [VERIFIED: .planning/milestones/v1.0-ROADMAP.md] [VERIFIED: .planning/milestones/v1.1-ROADMAP.md]
- The implementation should stay bounded to grep/file-existence validation and minimal wording preservation; no runtime/library/package work is needed. [VERIFIED: .planning/phases/84-routing-honesty-reconciliation/84-CONTEXT.md] [VERIFIED: .planning/phases/84-routing-honesty-reconciliation/84-VALIDATION.md]

### File Created
`.planning/phases/84-routing-honesty-reconciliation/84-RESEARCH.md`

### Confidence Assessment
| Area | Level | Reason |
|------|-------|--------|
| Standard Stack | HIGH | All recommended artifacts are repo-local planning files verified directly. [VERIFIED: .planning/STATE.md] |
| Architecture | HIGH | The hub/spoke routing model is explicit in current live docs and tombstone files. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/phases/999.1-nyquist-retroactive-validation-pass/999.1-CONTEXT.md] |
| Pitfalls | HIGH | The only remaining stale routing language is confined to archives, which was verified directly. [VERIFIED: .planning/milestones/v1.0-ROADMAP.md] |

### Open Questions
- None for Phase 84 planning. Archive normalization remains intentionally out of scope unless promoted as a later numbered phase. [VERIFIED: .planning/milestones/v1.0-ROADMAP.md] [VERIFIED: .planning/PROJECT.md]

### Ready for Planning
Research complete. Planner should keep Phase 84 as a small doc/planning cleanup or attestation phase, not a broad rewrite and not a reopened Nyquist effort. [VERIFIED: .planning/phases/84-routing-honesty-reconciliation/84-CONTEXT.md]
