# Project Research — STACK for v1.27 ENT-SSO

**Project:** Sigra  
**Milestone:** v1.27 ENT-SSO  
**Researched:** 2026-05-25  
**Confidence:** HIGH

## Recommendation

Keep the milestone OIDC-first on top of the current Sigra substrate. Reuse Sigra's existing OAuth/OIDC orchestration, organization model, sessions, audit semantics, and generated-host pattern. Do not widen the first cut into SCIM or a hosted identity-control-plane story.

## Current Stack To Reuse

- Phoenix `~> 1.8` and LiveView generated-host flows already back Sigra's auth and admin surfaces.
- Assent is already the library's external identity substrate, with first-class OIDC support proven in source and docs.
- Ecto/Postgres already back organizations, memberships, invitations, sessions, identities, and audit trails.
- Existing generated-host proof lanes, example app, and browser/system verification should be extended rather than replaced.

## Recommended Additions

- **Assent OIDC** as the first enterprise protocol path.
  Why: official docs clearly support OIDC discovery, nonce, PKCE/session params, and ID token validation.
- **Provider-agnostic enterprise connection contract** in Sigra, even if only OIDC ships in the first cut.
  Why: keeps the public/host contract stable if a later SAML provider lands.
- **Email-domain discovery plus explicit org-routed entry** on generated-host surfaces.
  Why: enterprise login usually needs both a deterministic path and a user-friendly discovery path.

## Avoid Adding In This Milestone

- A second auth stack parallel to `Sigra.OAuth`.
- A hosted admin portal or tenant onboarding control plane.
- SCIM / directory sync.
- Protocol-specific cryptography or XML handling in Sigra core unless the implementation research proves a bounded, honest SAML path.

## External Corroboration

- Assent OIDC docs confirm first-class OIDC support and session-bound nonce/state handling.
- django-allauth's SAML docs are strong prior art for org-slug-routed SSO entry and for rejecting IdP-initiated flows by default.
- WorkOS docs are useful prior art for metadata/manual setup, ACS/entity-ID posture, and operator-facing setup truth.

## Sources

- `lib/sigra/oauth.ex`
- `lib/sigra/oauth/callback.ex`
- `lib/sigra/organizations.ex`
- `guides/flows/oauth.md`
- `guides/recipes/multi-tenant.md`
- https://hexdocs.pm/assent/Assent.Strategy.OIDC.html
- https://docs.allauth.org/en/latest/socialaccount/providers/saml.html
- https://workos.com/docs/integrations/saml/overview
