# Requirements: Sigra v1.21 — B2B-ready & production-honest

**Defined:** 2026-04-28
**Core Value:** Authentication that works out of the box with great DX on the happy path AND on the rough edges — so developers can ship SaaS apps fast and grow with confidence.

## v1.21 Requirements

Requirements for the v1.21 milestone. Each maps to exactly one roadmap phase (91-96).

### B2B Trust

- [x] **B2B-01**: Org admin can require MFA for all members of an organization, blocking access for non-MFA-enrolled members until enrollment, with the policy change recorded as an atomic audit row.
- [ ] **B2B-02**: Generated host receives a `role` field on `OrganizationMembership`, a `Sigra.Authz` `can?/3` behaviour, scope-struct `:role` propagation, and a recipe doc demonstrating role-based policy implementation — without the library shipping any opinionated roles.
- [ ] **B2B-03**: Org admin can issue, list, and revoke org-scoped service-account tokens that authenticate API calls via `client_credentials` grant on the existing JWT path, distinguishable in `current_scope` and audit rows from user-tied tokens.

### Production Hardening

- [ ] **HARD-01**: `mix sigra.install` refuses to run against a non-Postgres adapter with a clear error; all unimplemented MySQL / SQLite migration branches are removed; PROJECT.md / README / mix.exs / getting-started honestly state PostgreSQL as the only supported adapter.
- [ ] **HARD-02**: Each optional dependency (Oban / Bcrypt / EQRCode) raises a clear, actionable error at first use when missing instead of compiling to silent nil; `mix sigra.doctor` reports per-feature dep status; CI matrix toggles each optional dep off and verifies behavior.
- [ ] **HARD-03**: OAuth token refresh works for GitHub / Apple / Facebook / Generic providers (replacing the `lib/sigra/oauth.ex:174` "not yet implemented" warning) with provider-specific refresh dispatch via Assent and atomic `oauth.token_refreshed` audit rows.

### API Polish

- [ ] **API-01**: API responses on rate-limited paths carry `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset`, and `Retry-After` headers populated from Hammer state via a dedicated plug wired into the dual-mode auth pipeline in generator templates.

## Future Requirements

Tracked but not in v1.21 roadmap.

### Webhooks (v1.22 candidate)

- **WH-01**: Outbound webhook subscription registry + dispatcher with HMAC signature verification.
- **WH-02**: Per-subscription event filtering, retry policy, dead-letter queue.
- **WH-03**: Admin LiveView to manage subscriptions + view delivery history.

### Session UX completeness

- **SESS-01**: Named device labels on session list ("Chrome on macOS").
- **SESS-02**: "Log out everywhere except this one" endpoint.
- **SESS-03**: Login-attempt history with geo + device.

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

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| MySQL adapter | Removed via HARD-01. `citext` + JSONB foundation is PG-locked. PROJECT.md claim was aspirational. |
| SQLite adapter | Same as MySQL. Dev/embedded use cases fall outside Sigra's SaaS production target. |
| Built-in opinionated roles (owner/admin/member) | RBAC stays seams-only per B2B-02. Hosts implement roles in their own `Authz` module using the recipe. |
| Webhooks / outbound event pipeline | Deferred to v1.22 as its own design-first milestone. |
| Session UX (named devices, "logout everywhere except this") | Tier-3 polish; not B2B-blocking. Future requirements section. |
| Email template overrides + i18n + bounce handling | Tier-3; existing `Sigra.EmailTemplates` behaviour suffices for v1.21 adopters. |
| Passkey multi-authenticator + recovery | Tier-3; passkey adoption is still early. |
| DataExport depth (audit export, anonymize-in-place) | Tier-3; only matters at compliance review. |
| `sigra_lockspire` glue package (ADR 001) | Awaiting companion-app trigger. |
| Phase 999.x archaeology | Pure planning hygiene. Tombstone-only. |
| Announcement / blog / HN / community work | User-excluded. v1.20 launch already shipped. |
| SAML / OAuth IdP / SCIM / full RBAC engine | Permanently out of scope per PROJECT.md. |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| B2B-01 | 91 | Complete |
| B2B-02 | 92 | Pending |
| B2B-03 | 93 | Pending |
| HARD-01 | 94 | Pending |
| HARD-02 | 95 | Pending |
| HARD-03 | 96 | Pending |
| API-01 | 96 | Pending |

**Coverage:**
- v1.21 requirements: 7 total
- Mapped to phases: 7 (Phases 91–96; Phase 96 bundles HARD-03 + API-01)
- Unmapped: 0

---
*Requirements defined: 2026-04-28*
*Last updated: 2026-04-29 after Phase 91 completion*
