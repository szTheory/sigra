# Phase 127: Versioned Auth Data Export - Context

**Gathered:** 2026-05-27 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Stabilize the Sigra-owned auth/account export payload with versioning, lifecycle fields, optional sections, and explicit omission truth. This phase covers the library export contract and targeted tests for payload shape and optional-schema degradation. It does not expand Sigra into generic BI/reporting export, SCIM, hosted-control-plane behavior, legal certification, or host-domain data ownership.
</domain>

<decisions>
## Implementation Decisions

### Public Contract Boundary
- **D-01:** Keep the stable payload contract in library code through `Sigra.DataExport.export_auth_data/3`.
- **D-02:** Generated-host code should only provide configured schemas or thin wrappers around the library contract; it must not become the owner of the export payload shape.

### Payload Shape
- **D-03:** Preserve the current structured, versioned map shape rather than flattening or renaming sections.
- **D-04:** The export should keep stable top-level sections for version metadata, account lifecycle, sessions, identities, audit, MFA, organizations, explicit enterprise/non-user-owned exclusions, and omissions.

### Lifecycle Truth
- **D-05:** Account export lifecycle truth should include both raw lifecycle fields and a derived lifecycle state aligned with `Sigra.Account.Deletion.status/1`.
- **D-06:** Keep lifecycle data bounded to Sigra-owned account fields; do not infer host retention policy or host-owned domain deletion semantics.

### Optional Schema Degradation
- **D-07:** Missing optional schemas must produce present-but-empty section values plus explicit omission notes.
- **D-08:** Omission notes should cover every optional Sigra-owned section that can be unavailable, not only audit, membership, and MFA credentials.
- **D-09:** Missing optional schemas should not raise and should not remove keys from the export payload.

### Sensitive Auth Material
- **D-10:** Export credential-related records as curated Sigra-owned summaries or safe field subsets, not raw generated structs.
- **D-11:** Do not export replay-relevant or secret-bearing material such as session token hashes, encrypted OAuth tokens, encrypted TOTP secrets, passkey credential/public-key blobs, or backup-code hashes.
- **D-12:** Backup codes remain summary-only: count and explicit non-export reason.

### the agent's Discretion
- Exact field names inside curated section items, provided they are stable, documented by tests, and avoid secret material.
- Whether omission notes are strings or structured maps, as long as the operator-facing export remains explicit and tests pin the behavior.
- Exact test helper modules and fixture shape for configured-schema coverage.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase and milestone contract
- `.planning/ROADMAP.md` — Phase 127 goal, scope boundary, success criteria, and active milestone non-goals.
- `.planning/REQUIREMENTS.md` — `EXP-01` and `EXP-02` define required export sections and omission truth.
- `.planning/PROJECT.md` — active `DATA-LIFECYCLE` goals, product boundaries, and hybrid library/generated-host philosophy.
- `.planning/STATE.md` — current sequencing and explicit instruction to keep data-lifecycle repair bounded.
- `.planning/METHODOLOGY.md` — decisive-defaulting and escalation thresholds applied during context gathering.

### Existing export and lifecycle code
- `lib/sigra/data_export.ex` — existing versioned export contract and current optional-schema behavior.
- `test/sigra/data_export_test.exs` — current payload-shape and degradation tests to extend.
- `lib/sigra/account/deletion.ex` — lifecycle status semantics and deletion field behavior.
- `lib/sigra/account.ex` — account lifecycle API and audit posture around deletion operations.

### Generated schema surfaces
- `priv/templates/sigra.install/core/user.ex` — account lifecycle fields available on generated users.
- `priv/templates/sigra.install/core/user_session.ex` — session fields, including sensitive token hash that must not be exported raw.
- `priv/templates/sigra.gen.oauth/user_identity.ex` — OAuth identity fields, including encrypted access/refresh tokens that must not be exported raw.
- `priv/templates/sigra.install/core/audit_event.ex` — audit event fields that can be included when `:audit_schema` is configured.
- `priv/templates/sigra.install/core/user_mfa_credential.ex` — MFA credential fields, including encrypted secret that must not be exported raw.
- `priv/templates/sigra.install/core/user_backup_code.ex` — backup-code hash storage; export remains summary-only.
- `priv/templates/sigra.install/passkeys/user_passkey.ex` — passkey fields, including credential material that must not be exported raw.
- `priv/templates/sigra.install/organizations/organization_membership.ex` — organization membership fields for configured organization exports.

### Prior-art patterns
- `.planning/phases/22-passkeys-generator-wiring/22-CONTEXT.md` — optional feature omission truth and structural honesty precedent.
- `.planning/phases/32-generated-installer-admin-surface-parity/32-RESEARCH.md` — generated controller as thin seam over library-owned export behavior.
- `lib/sigra/admin/audit/export.ex` — library-owned admin audit export orchestration precedent.
- `priv/templates/sigra.install/admin/audit_export_controller.ex` — generated-host thin adapter precedent.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Sigra.DataExport.export_auth_data/3`: already returns `schema_version`, `exported_at`, account, sessions, identities, audit, MFA, organizations, enterprise, and omissions sections.
- `Sigra.Account.Deletion.status/1`: existing source of truth for `{:scheduled, days}`, `:deleted`, and `:not_scheduled` lifecycle interpretation.
- `fetch_records/3`, `count_records/3`, and `fetch_audit_records/3` in `lib/sigra/data_export.ex`: reusable query seams, but raw-record output must be replaced or wrapped with safe serialization.
- `Sigra.Admin.Audit.Export`: precedent for library-owned export orchestration with generated host controllers only passing config.

### Established Patterns
- Sigra keeps security-sensitive contracts in the dependency and uses generated host code for schemas, routes, wrappers, and presentation.
- Optional generated features use structural omission and explicit truth rather than runtime-hidden or fake stub surfaces.
- Export and audit claims must be bounded: Sigra can describe Sigra-owned auth/account data, but not host-owned regulatory or domain-data completeness.
- Tests are expected to pin both configured-schema behavior and missing-schema degradation.

### Integration Points
- `lib/sigra/data_export.ex` is the primary implementation target for Phase 127.
- `test/sigra/data_export_test.exs` is the primary proof target for payload shape, configured optional sections, sensitive-field exclusion, and omission notes.
- Generated host parity is mainly Phase 129, but Phase 127 should keep the public API easy for generated contexts/controllers to call later.

</code_context>

<specifics>
## Specific Ideas

- Treat `schema_version: 1` as the current payload version unless implementation uncovers a compelling reason to bump; Phase 127 is stabilization, not a new export family.
- Prefer explicit safe summaries such as counts, ids, provider names, timestamps, roles, actions, and non-secret metadata over returning raw structs.
- Enterprise connections should remain explicitly excluded from per-user export because they are organization-scoped rather than user-owned.

</specifics>

<deferred>
## Deferred Ideas

None — analysis stayed within phase scope.
</deferred>

---

*Phase: 127-versioned-auth-data-export*
*Context gathered: 2026-05-27*
