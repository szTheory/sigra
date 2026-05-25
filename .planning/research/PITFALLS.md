# Project Research — PITFALLS for v1.27 ENT-SSO

**Project:** Sigra  
**Milestone:** v1.27 ENT-SSO  
**Researched:** 2026-05-25  
**Confidence:** HIGH

## Pitfall 1 — Silent account takeover during enterprise reconciliation

**What goes wrong:** enterprise callback matches by email alone and auto-links the wrong existing user.

**Avoid by:**
- requiring a deterministic reconciliation rule
- rejecting ambiguous matches
- keeping JIT provisioning and identity-link rules library-owned

## Pitfall 2 — Wrong-org routing

**What goes wrong:** a user starts enterprise login from one org surface and lands in another org, or domain discovery routes to the wrong tenant.

**Avoid by:**
- explicit org-routed entry paths
- careful email-domain verification rules
- audit and session truth that preserve which org initiated the flow

## Pitfall 3 — UI-only SSO-only enforcement

**What goes wrong:** password login looks disabled in the UI, but direct routes or copied host logic still allow bypass.

**Avoid by:**
- server-side enforcement in the auth path
- explicit break-glass seams
- direct-path tests for denied password flows

## Pitfall 4 — Overclaiming SAML support

**What goes wrong:** milestone copy promises "enterprise SSO" broadly while the actual implementation is only solid for OIDC.

**Avoid by:**
- naming the protocol truth precisely
- keeping SAML behind an explicit seam unless the implementation is truly real
- documenting non-goals and bounded follow-ons

## Pitfall 5 — Support-hostile setup truth

**What goes wrong:** adopters cannot tell whether the enterprise connection is misconfigured, inactive, claim-mismatched, or blocked by policy.

**Avoid by:**
- setup validation before activation
- explicit operator diagnostics and docs
- proof artifacts covering failure modes, not only happy-path login

## Sources

- `lib/sigra/oauth.ex`
- `lib/sigra/oauth/callback.ex`
- `guides/flows/oauth.md`
- `prompts/Phoenix Auth Library — Jobs to Be Done, Personas & User Flows.md`
- https://docs.allauth.org/en/latest/socialaccount/providers/saml.html
- https://workos.com/docs/integrations/saml/overview
