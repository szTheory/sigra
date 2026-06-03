# Domain Pitfalls

**Domain:** Open Source Authentication Library Maintenance (Post-1.0)
**Researched:** 2026-06-01

## Critical Pitfalls

Mistakes that cause project abandonment, maintainer burnout, or loss of adopter trust.

### Pitfall 1: Breaking the "Diminishing Returns Wall" (Feature Creep)
**What goes wrong:** Maintainers start building requested features that fall outside the core scope (e.g., an advanced RBAC engine or a custom UI component library) to appease loud users.
**Why it happens:** The desire to make the library "do everything" and be universally helpful.
**Consequences:** The library becomes bloated, harder to maintain, and harder to secure. Maintainer burnout increases as they have to support non-core features.
**Prevention:** Strictly enforce the "Diminishing Returns Wall". Answer feature requests with hooks, adapters, or architectural guidance for the host application instead of core code.
**Detection:** Reviewing pull requests that add large amounts of domain-specific logic or new top-level configuration options.

### Pitfall 2: Silent Generator Breakage
**What goes wrong:** Updates to the core library rely on changes to the generated templates, but the upgrade documentation doesn't explain how existing users should update their customized code.
**Why it happens:** The maintainer tests the upgrade by running a fresh `mix sigra.install` rather than testing a migration from an older version.
**Consequences:** Existing users are stuck on older versions because upgrading breaks their application.
**Prevention:** Maintain a dedicated `upgrade_smoke` test lane that tests upgrading a published consumer app. Provide explicit, line-by-line migration guides.

## Moderate Pitfalls

### Pitfall 1: Neglecting Dependency Updates
**What goes wrong:** Transitive dependencies become outdated, leading to security vulnerabilities or compiler warnings on newer Elixir versions.
**Prevention:** Rely on Dependabot and ensure the CI pipeline runs against the latest supported Elixir/OTP matrix.

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Triage & Maintenance | Burnout from addressing every issue immediately | Establish a cadence; close stale issues automatically; say "no" ergonomically. |
| Strategic Bet Evaluation | Starting work on SCIM without real demand | Require a concrete enterprise adopter before initiating the milestone. |

## Sources

- Maintainer experience and ecosystem research.
- `MILESTONE-ARC.md`