# Requirements: Sigra v1.22

**Defined:** 2026-05-06
**Core Value:** Authentication that works out of the box with great DX on the happy path AND on the rough edges — so developers can ship SaaS apps fast and grow with confidence.

**Milestone framing:** **Webhooks / outbound event pipeline** — turn Sigra into a reliable producer of auth and identity events for host apps and downstream systems. This milestone is about outbound machine-to-machine integration, not email UX. Research was performed because this is a new capability surface for the library.

## v1.22 Requirements

### Webhook delivery core

- [ ] **WH-01**: Host app can configure outbound webhook subscriptions for Sigra-owned auth and identity events, and Sigra emits a stable signed payload for each delivery with a unique delivery ID, event type, timestamp, and event body suitable for verification by the receiver.

### Delivery reliability

- [ ] **WH-02**: Each webhook subscription can limit which event types it receives, failed deliveries retry with a documented bounded policy, and permanently failed deliveries are retained in a dead-letter state with per-attempt history instead of disappearing silently.

### Admin and host UX

- [ ] **WH-03**: Generated admin LiveView lets adopters create, enable or disable, rotate, and inspect webhook subscriptions and delivery history, and the generated host gets the minimum wiring needed to expose the feature without reverse-engineering Sigra internals.

## Future Requirements

### Webhooks follow-ons

- **WH-04**: Secret rotation supports overlap windows and replay-safe rollover without delivery loss.
- **WH-05**: Maintainer or admin can manually replay a failed delivery from UI or CLI.
- **WH-06**: Adopter can constrain webhook egress with endpoint policy, IP allowlisting guidance, or tenant-specific controls.

### Session UX completeness

- **SESS-01**: Named device labels on session list ("Chrome on macOS").
- **SESS-02**: "Log out everywhere except this one" endpoint.
- **SESS-03**: Login-attempt history with geo and device.

### Email + i18n + deliverability

- **EMAIL-01**: Pluggable template module chain enabling host overrides without forking.
- **EMAIL-02**: i18n skeleton for auth emails.
- **EMAIL-03**: Bounce / complaint event stubs + production deliverability recipe.

### Passkey polish

- **PK-01**: Multi-authenticator management UI (list / rename / remove).
- **PK-02**: Passkey-only recovery flow (no password fallback).
- **PK-03**: Cross-device sync guidance + UX.

### Data export depth

- **DATA-01**: Audit-log export included in `Sigra.DataExport`.
- **DATA-02**: Anonymize-in-place mode for right-to-be-forgotten cascade.
- **DATA-03**: Export-format attestation + compliance recipe.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Inbound provider webhooks (for example Stripe or GitHub receivers) | v1.22 is about Sigra emitting auth events, not becoming a general inbound webhook consumer. |
| Public, non-admin webhook self-service UI | Keep management in the generated admin surface to preserve a clear trust boundary. |
| Outsourcing delivery to a third-party webhook SaaS by default | Sigra should ship a native first-party event pipeline before adding hosted-provider seams. |
| Folding the two install-smoke todos into this milestone | Useful hardening work, but not core to the outbound-event capability and would dilute the milestone focus. |
| Built-in downstream business automations | Sigra should emit trustworthy events; what adopters do with them remains host-owned. |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| WH-01 | 97 | Pending |
| WH-02 | 98 | Pending |
| WH-03 | 99 | Pending |

**Coverage:**
- v1.22 requirements: 3 total
- Mapped to phases: 3
- Unmapped: 0

---
*Requirements defined: 2026-05-06*
*Last updated: 2026-05-06 after milestone v1.22 initialization*
