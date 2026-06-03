<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- N/A - No CONTEXT.md present for this phase.

### the agent's Discretion
- Approach to establishing the triage and bugfix cadence.
- Documentation strategy for `mix sigra.upgrade` template updates.

### Deferred Ideas (OUT OF SCOPE)
- Greenfield Feature Implementation (The baseline must be stable before expanding the surface area).
- Opinionated RBAC or Generic Admin UI (Out of scope for post-1.0 authentication library).
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| MAINT-01 | Maintainer runbook includes a clear, repeatable process for monitoring adopter feedback, triaging issues, and prioritizing bug fixes without accumulating technical debt. | `MAINTAINING.md` currently covers milestone cadences and releases, but lacks a formalized "Issue Triage" cadence section. We must add one. |
| MAINT-02 | Known high-priority bugs and adopter-reported friction points are diagnosed and patched in the codebase. | Verification of `.planning/todos/pending/` and `v1.11-TRIAGE.md` confirms **zero** currently open high-priority bugs or queued P0/P1 defects. |
| MAINT-03 | A documented process exists for communicating generated-host template updates to adopters who have already run `mix sigra.install` prior to minor/patch bumps. | `mix sigra.upgrade` exists and enforces clean-git trees. We must formally document its use for patch updates in the runbook and `CHANGELOG.md`. |
</phase_requirements>

# Phase 150: Issue Triage & Bugfix Cadence - Research

**Researched:** 2026-06-01
**Domain:** Open-source maintenance, issue triage, semver update distribution
**Confidence:** HIGH

## Summary

This phase transitions Sigra into a post-1.0 maintenance posture. The ecosystem standard for hybrid (library + generator) frameworks dictates that security, maintenance, and operator trust supersede greenfield development. 

Currently, `MAINTAINING.md` covers release automation and Nyquist CI policies, but lacks a formalized periodic triage cadence. Furthermore, a review of `.planning/todos/pending/` and recent triage documents (e.g., `v1.11-TRIAGE.md`) confirms there are currently **zero** known open high-priority bugs. 

**Primary recommendation:** Formalize a "Triage & Bugfix Cadence" section in `MAINTAINING.md`, confirm the zero-bug state for MAINT-02, and document the `mix sigra.upgrade` workflow for distributing generated template patches to adopters.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Library Core Patches | Mix (Hex) | — | Core logic is delivered via `mix deps.update sigra`. |
| Template/Host Patches | Sigra Generator | Mix | Changes to controllers/views are delivered via `mix sigra.upgrade`. |
| Triage Tracking | GitHub Issues | `.planning/` | Public feedback flows through GH; internal maintenance is tracked via planning docs. |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `gh` CLI | Latest | Issue monitoring | Native GitHub issue interaction. |
| `mix sigra.upgrade` | Current | Template patch distribution | Built-in tool that enforces a clean git working tree before injecting template changes. |

## Package Legitimacy Audit

> No external packages are installed in this phase.

## Architecture Patterns

### Pattern 1: Hybrid Update Distribution
**What:** Distributing patches in a library + generator architecture.
**When to use:** When shipping a bug fix that affects both core library code and generated host templates.
**Example:**
1. **Maintainer Action:** Release a patch version (e.g., `1.0.1`) and document in `CHANGELOG.md` that a template upgrade is required.
2. **Adopter Action:** 
   ```bash
   mix deps.update sigra
   mix sigra.upgrade --yes
   git diff # Adopter resolves any conflicts with custom modifications
   ```

### Anti-Patterns to Avoid
- **Silent Template Drift:** Patching a generated template in the repository but failing to tell existing adopters to run `mix sigra.upgrade`, leaving their apps vulnerable or broken.
- **Unbounded Feature Creep:** Using bugfix patches to introduce new features. Post-1.0 patches must respect the "Diminishing Returns Wall".

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Enforcing safe template updates | Ad-hoc file overwrites | `mix sigra.upgrade` | It explicitly checks for dirty git trees to prevent data loss. |

## Runtime State Inventory

> This phase is primarily a process and documentation update. No live runtime state renaming or data migrations are required.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None | none |
| Live service config | None | none |
| OS-registered state | None | none |
| Secrets/env vars | None | none |
| Build artifacts | None | none |

## Common Pitfalls

### Pitfall 1: Adopters missing template updates
**What goes wrong:** Adopters run `mix deps.update sigra` but fail to run `mix sigra.upgrade`, leading to a mismatch between the core library (e.g., plugs/macros) and the host controllers.
**Why it happens:** The upgrade process isn't prominently communicated in patch notes.
**How to avoid:** Enforce a maintainer rule to explicitly list `mix sigra.upgrade` in `CHANGELOG.md` under a "Template Updates Required" header whenever generator templates are touched.

## Code Examples

### Maintainer Runbook Addition (Triage Cadence)
```markdown
## Issue Triage & Bugfix Cadence

1. **Monitor:** Check GitHub issues (`gh issue list`) weekly. 
2. **Categorize:** Label issues as `bug` (core logic), `friction` (DX/documentation), or `enhancement` (feature request).
3. **Prioritize:** Address `bug` and `friction` items in the next patch release. Defer `enhancement` items to strategic bet evaluations.
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual file copy | `mix sigra.upgrade` | Pre-1.0 | Safer, repeatable template updates for adopters. |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | There are no hidden/undocumented P0/P1 bugs outside of GitHub issues and `.planning/`. | Summary / MAINT-02 | If a critical bug exists in a separate channel (e.g., a private Slack), MAINT-02 would be falsely reported as complete. |

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `gh` | GitHub triage | ✓ | System | Web UI |

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit |
| Config file | `mix.exs` / `test/test_helper.exs` |
| Quick run command | `mix test` |
| Full suite command | `mix test && bash scripts/ci/upgrade-smoke.sh` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| MAINT-01 | Runbook documented | Manual | N/A (Documentation) | ✅ Wave 0 |
| MAINT-02 | Bug fixes patched | Unit/Int | `mix test` | ✅ Wave 0 |
| MAINT-03 | Update process documented | Manual | N/A (Documentation) | ✅ Wave 0 |

### Wave 0 Gaps
None — existing test infrastructure covers all phase requirements, and there are no new code modules introduced.

## Sources

### Primary (HIGH confidence)
- `/Users/jon/projects/sigra/MAINTAINING.md` - Verified current runbook contents.
- `/Users/jon/projects/sigra/.planning/v1.11-TRIAGE.md` - Verified 0 open issues and zero queued P0/P1 defects.
- `/Users/jon/projects/sigra/lib/mix/tasks/sigra.upgrade.ex` - Verified the behavior and arguments of the upgrade task.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Verified via repo source code.
- Architecture: HIGH - Adheres to existing Sigra hybrid model.
- Pitfalls: HIGH - Extrapolated from the hybrid distribution mechanics.

**Research date:** 2026-06-01
**Valid until:** 2026-07-01