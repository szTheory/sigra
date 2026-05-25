# Project Research — FEATURES for v1.27 ENT-SSO

**Project:** Sigra  
**Milestone:** v1.27 ENT-SSO  
**Researched:** 2026-05-25  
**Confidence:** HIGH

## Table Stakes For This Milestone

| Category | Feature | Why it matters |
|----------|---------|----------------|
| Enterprise connection setup | Org admin can configure enterprise connection settings and see whether the connection is valid before activation | Enterprise teams need setup truth, not trial-and-error callback failures |
| Login routing | User can reach the correct enterprise login path by explicit org route or verified email-domain discovery | Removes support friction and matches real B2B SaaS expectations |
| JIT provisioning | First successful enterprise login can create or reconcile org membership safely | Makes SSO usable without pre-seeding every membership |
| Enforcement | Org can require SSO while preserving explicit break-glass exemptions | Contract-signing enterprises expect policy enforcement without total operator lockout |
| Operator truth | Generated-host/operator surfaces explain status, denial reasons, and non-goals | Keeps the milestone honest and supportable |

## Differentiators Worth Shipping

- Reuse of Sigra's existing org, audit, and session substrate instead of a bolted-on enterprise sidecar.
- Safe account-reconciliation rules that refuse ambiguous matches instead of silently taking over an existing account.
- Generated-host proof and docs that make enterprise login behavior legible to adopters.

## Anti-Features / Defer

- SCIM provisioning or deprovisioning.
- Generic company-directory management.
- Hosted control plane behavior.
- Opinionated RBAC or policy engine work beyond the existing seams.
- Broad SAML platform promises that are not backed by the implemented protocol path.

## Milestone Shape

This milestone should be judged by whether a Phoenix SaaS team can credibly tell an enterprise prospect:

1. "Each customer org can use enterprise login."
2. "Users land in the correct org and membership safely."
3. "We can enforce SSO without locking out break-glass users."
4. "The setup and failure modes are documented and diagnosable."

## Sources

- `prompts/Phoenix Auth Library — Jobs to Be Done, Personas & User Flows.md`
- `.planning/MILESTONE-ARC.md`
- `guides/flows/oauth.md`
- `guides/recipes/multi-tenant.md`
