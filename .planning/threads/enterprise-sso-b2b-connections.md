---
slug: enterprise-sso-b2b-connections
title: Enterprise SSO & B2B connections milestone investigation
status: resolved
created: 2026-05-25
updated: 2026-05-26
---

# Thread: Enterprise SSO & B2B connections milestone investigation

## Goal

Capture the open investigation needed to turn `ENT-SSO` into a tight next milestone instead of a vague enterprise bucket.

## Context

*Created 2026-05-25.*

- Repo-grounded milestone assessment kept `ENT-SSO` as the best next wedge after `v1.26 PK-LIFECYCLE`.
- The shipped substrate is already strong for this milestone: org-aware auth (`Sigra.Organizations`), org-level MFA posture, RBAC seams, service-account tokens, OAuth/OIDC login via Assent, admin/audit/operator surfaces, and generated-host proof.
- The missing adopter-facing contract is org-level enterprise login routing plus JIT membership provisioning. That is the gap most likely to block B2B/enterprise deals before narrower export/compliance work.
- `guides/flows/oauth.md` and `lib/sigra/oauth.ex` prove Sigra already owns OAuth/OIDC login orchestration, state, callback routing, token refresh, and linking/unlinking. The next milestone should reuse that posture rather than invent a second auth stack.
- `guides/recipes/multi-tenant.md` and `lib/sigra/organizations.ex` prove the org/membership model is already the runtime anchor for tenant-aware login outcomes.
- Current external corroboration:
  - Assent official docs clearly support OIDC as a first-class strategy, but repo inspection did not surface an equivalent first-class SAML strategy in the current Sigra substrate.
  - django-allauth's SAML docs are useful prior art for org-slug-based SSO routing and for rejecting IdP-initiated SSO by default.
  - WorkOS docs are useful prior art for the operator setup posture: metadata/manual config split, SP metadata, ACS URL, entity ID, and attribute mapping expectations.
- The likely milestone boundary should stay narrower than "enterprise identity platform":
  - org-aware SSO connection model
  - tenant routing into the right IdP
  - JIT account/membership reconciliation
  - SSO-only / break-glass truth
  - support/proof/docs posture
- Keep these out of the first milestone unless repo research materially changes:
  - full SCIM directory sync
  - hosted admin portal / control plane behavior
  - product-specific authorization policy
  - broad organization lifecycle automation unrelated to login

## References

- `.planning/MILESTONE-ARC.md`
- `.planning/PROJECT.md`
- `prompts/Phoenix Auth Library — Jobs to Be Done, Personas & User Flows.md`
- `prompts/Building the gold-standard Elixir:Phoenix authentication library.md`
- `guides/flows/oauth.md`
- `guides/recipes/multi-tenant.md`
- `lib/sigra/oauth.ex`
- `lib/sigra/organizations.ex`
- https://hexdocs.pm/assent/Assent.Strategy.OIDC.html
- https://docs.allauth.org/en/latest/socialaccount/providers/saml.html
- https://workos.com/docs/integrations/saml/overview

## Next Steps

- Decide whether the first cut is OIDC-first with a narrow SAML seam, or whether a real SAML provider path is mature enough to ship in the same milestone.
- Define the org-level connection model: slug-routed, domain-routed, or both.
- Define the JIT provisioning truth against the existing memberships/invitations substrate.
- Define SSO-only and break-glass rules without weakening the current recovery-first posture.
- Define proof posture early: generated-host/browser evidence, operator docs, and explicit non-goals.
