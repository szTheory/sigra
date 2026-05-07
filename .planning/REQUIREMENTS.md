# Requirements: Sigra

**Defined:** 2026-05-07
**Core Value:** Authentication that works out of the box with great DX on the happy path AND on the rough edges — so developers can ship SaaS apps fast and grow with confidence, without wiring together 4+ libraries or maintaining security-sensitive code themselves.

## v1 Requirements

### Webhook operator trust

- [ ] **WH-04**: Adopter can rotate a webhook signing secret with an overlap window, complete the cutover without delivery loss, and retire the old secret without reopening replay risk.
- [ ] **WH-05**: Maintainer or admin can manually replay a failed or dead-lettered delivery from supported control surfaces while preserving truthful delivery history.
- [ ] **WH-06**: Adopter can enforce outbound webhook endpoint policy, including allowlisting guidance and deployment-specific controls, without forking Sigra internals.

## v2 Requirements

### Session UX completeness

- **SESS-01**: Named device labels on session list ("Chrome on macOS").
- **SESS-02**: "Log out everywhere except this one" endpoint.
- **SESS-03**: Login-attempt history with geo and device.

### Email + i18n + deliverability

- **EMAIL-01**: Pluggable template module chain enabling host overrides without forking.
- **EMAIL-02**: i18n skeleton for auth emails.
- **EMAIL-03**: Bounce / complaint event stubs plus production deliverability recipe.

### Passkey polish

- **PK-01**: Multi-authenticator management UI (list / rename / remove).
- **PK-02**: Passkey-only recovery flow (no password fallback).
- **PK-03**: Cross-device sync guidance plus UX.

### Data export depth

- **DATA-01**: Audit-log export included in `Sigra.DataExport`.
- **DATA-02**: Anonymize-in-place mode for right-to-be-forgotten cascade.
- **DATA-03**: Export-format attestation plus compliance recipe.

### Release follow-up

- **REL-01**: Cut the next Sigra release after the webhook operator-trust milestone closes with reconciled changelog, roadmap, and evidence.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Inbound provider webhooks | The current milestone continues Sigra's outbound event surface; becoming a general inbound webhook consumer is a separate product line. |
| Arbitrary event transformation or scripting before delivery | Adds a second automation platform before the core trust and control seams are hardened. |
| Custom retry-policy tuning per subscription | Useful later, but not the highest-leverage blocker compared with safe rotation, replay, and network-boundary controls. |
| Tier-3 UX polish outside webhooks | Session, email, passkey, and data-export follow-ons remain lower-priority than closing webhook adoption blockers. |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| WH-04 | Phase 103 | Pending |
| WH-05 | Phase 104 | Pending |
| WH-06 | Phase 105 | Pending |

**Coverage:**
- v1 requirements: 3 total
- Mapped to phases: 3
- Unmapped: 0

---
*Requirements defined: 2026-05-07*
*Last updated: 2026-05-07 after opening milestone v1.23*
