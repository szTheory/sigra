# Phase 152: Strategic Bet Evaluation Gate - Research

**Researched:** 2026-06-01
**Domain:** Documentation / Process Stewardship
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Greenfield enterprise features (like SCIM or new auth primitives) will remain blocked unless an explicit enterprise adopter contract requires them.
- **D-02:** When SCIM is eventually unblocked by an enterprise contract, it will use the `ex_scim` dependency rather than a custom minimal implementation.
- **D-03:** Lockspire integration will remain a host-owned responsibility (manual stub generation) rather than a published glue package (`sigra_lockspire`).
- **D-04:** Threadline trace-correlation ID propagation is deferred until Threadline provides a stable upstream injection seam (noting that external research shows Threadline v0.5.0+ has unblocked this seam).

### the agent's Discretion
None

### Deferred Ideas (OUT OF SCOPE)
None — analysis stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| STRAT-01 | A formal evaluation document is created to assess if accumulated adopter demand warrants beginning work on `SCIM`, `sigra_lockspire`, or `Threadline` correlation. | Identified target doc structure for tracking deferrals and bet scoping. |
| STRAT-02 | The evaluation explicitly defines the threshold of adopter demand required to override the maintenance-first default and violate the Diminishing Returns Wall. | Addressed by D-01: requires an enterprise adopter contract explicitly blocked by the missing feature. |
| STRAT-03 | Any approved strategic bet includes deeper research scoping (e.g., `ex_scim` vs custom implementations for directory sync) to prepare for future implementation phases. | Addressed by D-02: `ex_scim` package is the documented integration path over hand-rolling minimal endpoints. |
</phase_requirements>

## Summary

This phase transitions the project from feature development to long-term stewardship by establishing a formal evaluation gate for incoming enterprise feature requests. The primary objective is to evaluate three specific strategic bets (`SCIM`, `sigra_lockspire`, and `Threadline`) against the Diminishing Returns Wall, producing a formal decision document.

**Primary recommendation:** Create a formal evaluation document `.planning/decisions/002-strategic-bets-v1.33.md` that codifies the strict demand thresholds (D-01), defers the `sigra_lockspire` (D-03) and `Threadline` (D-04) work, and explicitly scopes the SCIM implementation path using `ex_scim` (D-02).

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Evaluation Gate | Process/Documentation | — | Purely structural/organizational artifact. No application code is modified in this phase. |

## Standard Stack

No new dependencies are introduced in this phase, as the output is a documentation artifact.

However, the evaluation of the SCIM strategic bet scopes future usage of:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `ex_scim` | `~> 0.2.0` | SCIM v2.0 protocol parsing | Pre-built Hex package that handles complex SCIM request validation, avoiding hand-rolling RFC-compliant `GET/POST/PATCH` logic on `/Users`. |

## Package Legitimacy Audit

> **Note:** This phase involves documentation only and does not install external packages. `ex_scim` is evaluated for future use.

| Package | Registry | Age | Downloads | Source Repo | slopcheck | Disposition |
|---------|----------|-----|-----------|-------------|-----------|-------------|
| `ex_scim` | hex.pm | 2 mo | 432 all time | github.com/ExScim/ex_scim | `[ASSUMED]` | Flagged — planner must add checkpoint when implemented |

*Slopcheck is unavailable for Elixir Hex packages. All packages above are tagged `[ASSUMED]` and the planner must gate future installation behind a `checkpoint:human-verify` task.*

## Architecture Patterns

### Recommended Project Structure
For documenting strategic bets, follow the existing decision tracking pattern:
```
.planning/decisions/
├── 001-defer-sigra-lockspire-glue-package.md
└── 002-strategic-bets-v1.33.md     # Output of this phase
```

### Pattern 1: Formal Evaluation Document
**What:** A structured Markdown document assessing proposed strategic bets against defined project thresholds.
**When to use:** When feature requests cross the Diminishing Returns Wall (e.g., enterprise directory sync).
**Example Structure:**
```markdown
# Strategic Bet Evaluation: v1.33

## Threshold for Action
(Define the D-01 criteria: explicit enterprise adopter contract blocked)

## Bet: SCIM / Directory Sync
- **Status:** Pending concrete enterprise block
- **Implementation Scope:** Must use `ex_scim` dependency rather than custom implementation.

## Bet: sigra_lockspire Glue
- **Status:** Deferred
- **Evaluation:** Remains a host-owned responsibility (manual stub generation).

## Bet: Threadline Correlation
- **Status:** Deferred
- **Evaluation:** Deferred until stable upstream injection seam exists (though external research notes Threadline v0.5.0+ may unblock this).
```

### Anti-Patterns to Avoid
- **Proactive Implementation:** Building code for deferred bets while documenting them, violating the phase boundaries.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| SCIM protocol endpoints | Custom `/Users` endpoints for GET/POST/PATCH | `ex_scim` | Handling conflict resolution, idempotency, and RFC compliance for SCIM is complex; use pre-existing Hex packages. |

**Key insight:** Writing code for hypothetical enterprise scenarios creates unbound maintenance burden. Strict deferment is the correct technical choice unless forced by contracts.

## Common Pitfalls

### Pitfall 1: Scope Creep during Evaluation
**What goes wrong:** Creating "proof of concept" code for deferred bets while documenting them.
**Why it happens:** The desire to make the evaluation document more comprehensive or test assumptions via code.
**How to avoid:** Strictly limit the phase to research and documentation. Any actual code for SCIM or Threadline violates the phase scope and maintenance-first posture.

### Pitfall 2: Vague Threshold Definitions
**What goes wrong:** Establishing criteria like "when many users ask for it" or "if there is high demand."
**Why it happens:** Reluctance to set a hard boundary or tell users "no."
**How to avoid:** Enforce D-01 explicitly: an enterprise adopter contract must be concretely blocked by the lack of the feature.

## Code Examples

Verified patterns from official sources:

### [Documenting Deferrals]
```markdown
## Bet: sigra_lockspire Glue
**Status:** Deferred
**Evaluation:** Lockspire integration will remain a host-owned responsibility rather than a published glue package.
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Proactive feature development | Demand-driven, maintenance-first gating | v1.33 (Post-1.0) | Drastically reduces technical debt and aligns library solely with proven operator needs. |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Slopcheck cannot verify Elixir Hex packages natively. | Package Legitimacy Audit | No runtime risk since `ex_scim` is not being installed in this phase. Planner must use human verification when eventually installed. |

## Environment Availability

Step 2.6: SKIPPED (no external dependencies identified for a documentation phase)

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | bash script (documentation phase) |
| Config file | none |
| Quick run command | `ls .planning/decisions/002-strategic-bets*.md` |
| Full suite command | `cat .planning/decisions/002-strategic-bets*.md` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| STRAT-01 | Evaluation document created | smoke | `test -f .planning/decisions/002-strategic-bets-v1.33.md` | ✅ Wave 0 |
| STRAT-02 | Threshold explicitly defined (D-01) | unit | `grep -qi "enterprise adopter contract" .planning/decisions/002-strategic-bets-v1.33.md` | ✅ Wave 0 |
| STRAT-03 | SCIM implementation scoped | unit | `grep -qi "ex_scim" .planning/decisions/002-strategic-bets-v1.33.md` | ✅ Wave 0 |

### Sampling Rate
- **Per task commit:** `ls .planning/decisions/`
- **Per wave merge:** `cat .planning/decisions/002-strategic-bets-v1.33.md`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
None — existing test infrastructure covers all phase requirements.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | no | — |
| V6 Cryptography | no | — |

*This phase consists entirely of documentation and process updates. No application code or security controls are modified.*

## Sources

### Primary (HIGH confidence)
- `152-CONTEXT.md` - Phase constraints and locked decisions.
- `REQUIREMENTS.md` - Phase requirements (STRAT-01, STRAT-02, STRAT-03).
- `mix hex.info ex_scim` - Verified `ex_scim` v0.2.0 exists as a SCIM protocol parsing dependency.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Documentation phase only; dependency scoped strictly based on context.
- Architecture: HIGH - Decision documents follow the established `.planning/decisions/` pattern.
- Pitfalls: HIGH - Pitfalls align perfectly with project constraints and the Diminishing Returns Wall.

**Research date:** 2026-06-01
**Valid until:** 2026-12-01