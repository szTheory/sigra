# Project Research — ARCHITECTURE for v1.27 ENT-SSO

**Project:** Sigra  
**Milestone:** v1.27 ENT-SSO  
**Researched:** 2026-05-25  
**Confidence:** MEDIUM-HIGH

## Architectural Direction

Keep enterprise SSO inside Sigra's existing architecture:

- library owns security-critical enterprise login orchestration, reconciliation rules, and audit/session truth
- generated host owns routes, forms, admin screens, and app-specific policy copy

Do not introduce a second identity orchestration stack next to `Sigra.OAuth`.

## Likely Component Split

1. **Enterprise connection contract**
   - library-owned config/validation layer for organization-bound enterprise connections
   - stores activation truth, connection type, and routing metadata

2. **Enterprise entry and callback routing**
   - generated-host routes for explicit org entry
   - optional email-domain discovery path
   - callback paths that resolve back into the correct organization context

3. **JIT reconciliation layer**
   - library-owned logic that maps enterprise identity claims into existing users, memberships, or safe failures
   - reuses existing organizations/invitations/membership invariants instead of bypassing them

4. **Enforcement and exemptions**
   - organization-level SSO-only posture
   - explicit per-user break-glass exemption seam
   - server-side enforcement, not UI-only gating

5. **Proof and diagnostics**
   - generated-host docs and diagnostics surfaces
   - browser/example/system proof over the enterprise path

## Existing Seams To Reuse

- `Sigra.OAuth` and `Sigra.OAuth.Callback`
- `Sigra.Organizations` and invitations/membership logic
- current session and scope hydration model
- audit event/query infrastructure
- generated-host install/upgrade/docs patterns

## Strong Boundaries

- Enterprise login is authentication and identity-routing work, not authorization-policy work.
- Organization membership invariants remain owned by the existing org substrate.
- Protocol-specific setup UX belongs in generated host code, not in a hosted Sigra control plane.

## Sources

- `lib/sigra/oauth.ex`
- `lib/sigra/oauth/callback.ex`
- `lib/sigra/organizations.ex`
- `lib/sigra/organizations/invitations.ex`
- `README.md`
