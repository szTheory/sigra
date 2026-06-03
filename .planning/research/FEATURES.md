# Feature Landscape

**Domain:** Open Source Authentication Library Maintenance (Post-1.0)
**Researched:** 2026-06-01

## Table Stakes

Features users expect from a post-1.0 library. Missing = product feels unstable or abandoned.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Hex Dependency Updates | Prevent security vulnerabilities | Low | Dependabot handles the PRs; maintainers must review and merge. |
| Bug Triage & Fixes | Adopters encounter edge cases | Variable | Requires a repeatable process for validating and reproducing issues. |
| Documentation Drift Fixes | Outdated docs destroy trust | Low | Includes updating AI indices (`llms.txt`) and guides. |
| Elixir/OTP Compatibility | Language evolves | Medium | Fixing compiler and deprecation warnings on new OTP/Elixir releases. |

## Differentiators (Strategic Bets)

New capabilities to explicitly prioritize *only* if strong adopter demand exists. Not expected, but valued by specific cohorts.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| SCIM / Directory Sync | Unlocks enterprise adoption (Okta/Entra integration) | High | Explicitly deprioritized until JIT proves insufficient for an adopter. |
| `sigra_lockspire` Glue | Interoperability with OAuth authorization servers | Medium | Blocked per ADR 001 until a companion-app trigger fires. |
| Threadline Correlation | Full suite integration for logging | Low | Blocked on a stable Threadline injection seam. |

## Anti-Features

Features to explicitly NOT build (The "Diminishing Returns Wall").

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Opinionated RBAC / Zanzibar | Host applications have unique domain requirements | Provide identity primitives (`user_id`, `organization_id`); let the host own the policy. |
| Billing & Subscriptions | Pure domain logic, unrelated to authentication | Expose webhook egress so the host can sync identity state to billing. |
| Frontend Component Libraries | Locks adopters into specific CSS/JS frameworks | Generate functional HTML/Tailwind; let the host customize the aesthetics. |
| Hosted Control-Plane UI | Unnecessary expansion of the library | Focus on the core authentication primitives and APIs. |

## Feature Dependencies

`Adopter Demand -> SCIM Directory Sync` (SCIM requires a concrete enterprise contract)
`Lockspire Stabilization -> sigra_lockspire Glue Package`

## MVP Recommendation

Prioritize:
1. Issue Triage and Bug Fixing
2. Framework compatibility verification
3. Dependabot PRs

Defer: SCIM / Directory Sync (until enterprise demand is proven).

## Sources

- `MILESTONE-ARC.md`
- `PROJECT.md`