# Project Research Summary

**Project:** Sigra v1.27 ENT-SSO  
**Domain:** Enterprise SSO and B2B connections for a Phoenix authentication library  
**Researched:** 2026-05-25  
**Confidence:** HIGH

## Executive Summary

Sigra is already strong enough that the next milestone should be a concentrated adopter wedge, not more surface-area polish. The repo-grounded evidence points to enterprise SSO as that wedge: the library already ships organizations, MFA posture, RBAC seams, service-account tokens, OAuth/OIDC login, admin/audit/operator truth, and generated-host proof. What it does not yet ship is the thing B2B teams need to close enterprise deals: org-aware enterprise login routing plus JIT membership truth.

The safest milestone shape is OIDC-first. Assent clearly supports OIDC today; the repo does not yet prove an equivalent first-class SAML substrate. The milestone should therefore build a provider-agnostic enterprise connection contract, but only promise the protocol path it can implement honestly inside this cut. That still closes a real adopter gap without forcing Sigra into premature hosted-control-plane or SCIM work.

## Key Findings

- **Best next wedge:** `ENT-SSO`
- **Protocol stance:** OIDC-first, future-compatible seam for SAML
- **Critical outcomes:** org-aware entry, JIT reconciliation, SSO-only enforcement, break-glass truth, generated-host/operator proof
- **Non-goals:** SCIM, hosted control plane, opinionated authorization, broad company-directory lifecycle automation

## Suggested Phase Structure

1. **Phase 122 — Enterprise connection contract & validation**
2. **Phase 123 — Org-aware routing and enterprise login entry**
3. **Phase 124 — JIT membership provisioning and safe reconciliation**
4. **Phase 125 — SSO-only enforcement and break-glass truth**
5. **Phase 126 — Generated-host proof, diagnostics, and docs**

## Sources

- `.planning/MILESTONE-ARC.md`
- `.planning/PROJECT.md`
- `lib/sigra/oauth.ex`
- `lib/sigra/oauth/callback.ex`
- `lib/sigra/organizations.ex`
- `lib/sigra/organizations/invitations.ex`
- `guides/flows/oauth.md`
- `guides/recipes/multi-tenant.md`
- `prompts/Phoenix Auth Library — Jobs to Be Done, Personas & User Flows.md`
- https://hexdocs.pm/assent/Assent.Strategy.OIDC.html
- https://docs.allauth.org/en/latest/socialaccount/providers/saml.html
- https://workos.com/docs/integrations/saml/overview

---
*Research completed: 2026-05-25*
*Ready for roadmap: yes*
