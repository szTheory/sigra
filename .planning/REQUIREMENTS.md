# Requirements: Sigra v1.27 ENT-SSO

**Defined:** 2026-05-25  
**Core Value:** Authentication that works out of the box with great DX on the happy path AND on the rough edges — so developers can ship SaaS apps fast and grow with confidence.

## v1.27 Requirements

### Enterprise connection model

- [ ] **SSO-01**: Organization admins can configure an enterprise OIDC connection for their organization using validated discovery and client settings.
- [ ] **SSO-02**: Sigra refuses to activate an unusable enterprise connection and exposes setup truth clearly enough that operators do not need to reverse-engineer callback failures.

### Enterprise routing and login

- [ ] **SSO-03**: Users can enter enterprise login through an org-aware entry path that resolves the correct organization connection by explicit org route or verified email-domain discovery.
- [ ] **SSO-04**: Successful enterprise login signs the user into the correct organization and preserves Sigra's existing session and audit truth.

### JIT provisioning and reconciliation

- [ ] **JIT-01**: Enterprise login can provision or reconcile organization membership just in time without bypassing the existing org invariants.
- [ ] **JIT-02**: Ambiguous enterprise identity matches fail safely instead of silently linking the wrong account.

### Enforcement and operator truth

- [ ] **ENF-01**: Organizations can require SSO for members while preserving explicit break-glass exemptions for allowed users.
- [ ] **OPS-01**: Generated-host proof, diagnostics, and docs make the bounded enterprise SSO contract legible for adopters and operators.

## Future Requirements

### Enterprise follow-ons

- **SAML-01**: Sigra supports a first-class SAML enterprise connection path with honest operator setup and validation semantics.
- **SCIM-01**: Organizations can synchronize lifecycle changes from their directory provider without weakening Sigra's auth and membership invariants.

### Data lifecycle

- **DATA-01**: Sigra exposes a coherent auth-data export contract and linked audit/lifecycle guidance for compliance-sensitive adopters.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Full SCIM / directory sync | Higher breadth and proof burden than the current login-routing wedge; defer until enterprise login truth is real. |
| Hosted control plane / Admin Portal equivalent | Outside Sigra's library boundary; generated-host and docs remain the primary operator surface. |
| Opinionated authorization / role engine | Sigra continues to provide identity and seams, not product-specific access policy. |
| Broad company-directory lifecycle automation unrelated to login | Keep this milestone anchored to enterprise authentication and org membership truth. |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| SSO-01 | Phase 122 | Pending |
| SSO-02 | Phase 122 | Pending |
| SSO-03 | Phase 123 | Pending |
| SSO-04 | Phase 124 | Pending |
| JIT-01 | Phase 124 | Pending |
| JIT-02 | Phase 124 | Pending |
| ENF-01 | Phase 125 | Pending |
| OPS-01 | Phase 126 | Pending |

**Coverage:**
- v1.27 requirements: 8 total
- Mapped to phases: 8
- Unmapped: 0

---
*Requirements defined: 2026-05-25*
*Last updated: 2026-05-25 after milestone initialization*
