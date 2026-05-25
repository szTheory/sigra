---
phase: 122
slug: enterprise-connection-contract-validation
status: verified
threats_open: 0
asvs_level: 1
created: 2026-05-25
---

# Phase 122 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Global OAuth config -> org-scoped enterprise state | Phase 122 had to avoid treating enterprise SSO as a global provider stub and instead persist organization-owned connection state. | Organization ids, provider metadata, lifecycle state, validation timestamps. |
| Saved config -> active config | A saved draft cannot be treated as active without successful OIDC preflight validation and an explicit activation step. | Persisted connection status, validation result, safe operator diagnostics. |
| Operator-entered secrets -> logs / diagnostics / UI | Validation failures must not surface raw client secrets or token-like values while still giving operators actionable feedback. | Client id, encrypted client secret, issuer metadata, sanitized error strings. |
| OIDC-first delivery -> future protocol seam | The initial OIDC implementation must not hard-code protocol-specific fields at the top level and block later protocol support. | Top-level protocol marker plus nested OIDC settings payload. |
| Library lifecycle -> generated-host UI | The generated host must render persisted lifecycle truth instead of inferring active state from field presence. | Persisted `status`, `last_validation_error`, and operator actions. |
| Org settings route -> unauthorized viewer | The enterprise configuration surface must stay behind the existing owner-gated organization settings route. | Enterprise connection presence, validation status, diagnostic copy. |
| Template source -> example / golden output | Installer templates and the committed example app must stay in sync so local development truth matches emitted host output. | Generated wrapper APIs, LiveView copy/actions, fixture output. |

---

## Threat Register

Threats are taken from the `<threat_model>` tables in `122-01-PLAN.md` and `122-02-PLAN.md`.

| Threat ID | Category | Component | Disposition | Mitigation | Status |
|-----------|----------|-----------|-------------|------------|--------|
| T-122-01 | Elevation of privilege | `Sigra.EnterpriseConnections` org-scoped persistence | mitigate | `get_connection/2`, `change_connection/3`, and `save_connection/3` always bind reads and writes to `scope.active_organization.id`; cross-org disable attempts return `:forbidden`; tests cover forced org ownership and reject paths. | closed |
| T-122-02 | Tampering | activation lifecycle | mitigate | The schema and lifecycle use explicit `:draft`, `:validation_failed`, `:active`, and `:disabled` states; `activate_connection/3` first validates and only then persists `:active`; failed activation persists `:validation_failed` and never leaves the row active. | closed |
| T-122-03 | Information disclosure | validation diagnostics | mitigate | Validation returns fixed safe error strings, persists only `last_validation_error`, clears that field on draft/active/disabled transitions, and the UI renders the safe persisted diagnostic rather than raw request payloads. | closed |
| T-122-04 | Tampering | protocol compatibility contract | mitigate | The host schema stores top-level `protocol` and a nested `embeds_one :oidc_settings` payload so OIDC-specific fields do not become the global enterprise contract. | closed |
| T-122-05 | Tampering | generated-host status UI | mitigate | The settings page badge renders persisted `status`; separate Save / Validate / Activate actions preserve lifecycle truth; failed validation shows a non-active flash and diagnostic instead of implying activation from filled fields. | closed |
| T-122-06 | Elevation of privilege | organization settings access | mitigate | The generated LiveView stays on the existing organization settings page and documents that non-owners are blocked by the `:org_scoped` owner gate before mount. | closed |
| T-122-07 | Repudiation | template / example drift | mitigate | Installer feature tests and golden-diff coverage lock the wrapper delegates, Enterprise SSO section, and lifecycle action copy across template and example output. | closed |

*Status: open · closed*

*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

### Summary threat flags

`122-01-SUMMARY.md` and `122-02-SUMMARY.md` do not define a `## Threat Flags` section; no additional flags were introduced beyond the plan threat models.

---

## Accepted Risks Log

No accepted risks.

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-05-25 | 7 | 7 | 0 | Codex / `gsd-secure-phase` (inline verification; `gsd-security-auditor` subagent type not available in this runtime) |

### Evidence notes (2026-05-25)

- **Org scoping / lifecycle:** `lib/sigra/enterprise_connections.ex` lines 17-39, 42-68, 71-127, 138-170.
- **OIDC validation / safe diagnostics:** `lib/sigra/enterprise_connections/validation.ex` lines 12-26, 44-60, 75-121.
- **Protocol-neutral host contract:** `priv/templates/sigra.install/organizations/enterprise_connection.ex` lines 15-47.
- **Truthful generated-host UI:** `priv/templates/sigra.install/organizations/live/organization_settings_live.ex` lines 154-230 and 330-378.
- **Scope and activation reject coverage:** `test/sigra/enterprise_connections/context_test.exs` lines 104-135; `test/sigra/enterprise_connections/activation_test.exs` lines 62-95.
- **Template/example parity coverage:** `test/sigra/admin/live/enterprise_connection_live_test.exs` lines 4-31; `test/sigra/install/features/organizations_test.exs`.
- **Fresh verification run:** `mix test test/sigra/enterprise_connections/schema_test.exs test/sigra/enterprise_connections/context_test.exs test/sigra/enterprise_connections/validation_test.exs test/sigra/enterprise_connections/activation_test.exs test/sigra/admin/live/enterprise_connection_live_test.exs test/sigra/install/features/organizations_test.exs test/sigra/install/golden_diff_test.exs` -> passed (`76 tests, 0 failures`) on 2026-05-25.

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-05-25
