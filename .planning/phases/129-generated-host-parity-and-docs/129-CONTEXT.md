# Phase 129: Generated Host Parity And Docs - Context

**Gathered:** 2026-05-27 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Align generated templates, example app, install golden fixture, and public docs with the bounded data-lifecycle contract from Phases 127 and 128. This phase covers generated-host parity and documentation truth for `HOST-01` and `DOC-01`: host code should call the same library-owned export and lifecycle contracts, generated output should match templates, and docs should explain Sigra-owned data, host-owned data, optional-schema omissions, and deletion strategy consequences. This phase does not expand Sigra into generic compliance certification, generic BI export, SCIM, hosted control-plane behavior, or host-domain retention ownership.
</domain>

<decisions>
## Implementation Decisions

### Generated Lifecycle Parity
- **D-01:** Generated context wrappers, the example app, and install golden should keep account deletion as thin calls into `Sigra.Auth.schedule_deletion/3`, `Sigra.Auth.cancel_deletion/3`, and `Sigra.Account.deletion_status/1`.
- **D-02:** Generated host code should continue to supply host-specific repo, schema, scope, audit, token, and session context while the library owns enqueue, active-scheduled, stale-worker, and finalization truth.
- **D-03:** Lifecycle UI and copy in generated templates, example app, and golden fixtures must not over-claim hard deletion or permanent removal when the configured strategy is `:soft_delete`.

### Generated Export Boundary
- **D-04:** Phase 129 should add or align only thin generated/example/golden seams for `Sigra.DataExport.export_auth_data/3`, passing repo, user, and configured generated schemas without recreating payload shape in host code.
- **D-05:** The generated export seam must preserve Phase 127 semantics: versioned library-owned payload, stable top-level sections, curated sensitive-field serialization, explicit enterprise exclusion truth, and omission notes for missing optional Sigra-owned schemas.
- **D-06:** Generated host documentation and examples should position `Sigra.DataExport.export_auth_data/3` as Sigra-owned auth/account export that host apps may combine with their own host-domain export, not as a complete application data export.

### Install Golden Contract
- **D-07:** Treat the install golden fixture as generated-host contract evidence that must be updated after template and example parity changes, not as an independent source of behavior.
- **D-08:** Golden output should mirror the current generated wrappers, lifecycle copy, data-export seam, and controller/context naming produced by `mix sigra.install`.

### Documentation Truth Claims
- **D-09:** Docs should explicitly distinguish Sigra-owned auth/account data from host-owned domain data.
- **D-10:** Docs should document omission behavior for optional schemas so operators understand partial exports are explicit rather than silently complete.
- **D-11:** Docs should explain deletion strategy consequences: `:hard_delete` removes the user row subject to host constraints, `:soft_delete` preserves the row and PII while finalizing lifecycle state, and `:anonymize` preserves the row while clearing Sigra-owned PII.
- **D-12:** Docs and generated copy should soften broad phrases such as "all associated data" and unconditional "permanently removed" unless they are scoped to the configured strategy and Sigra-owned data.

### the agent's Discretion
- Exact generated wrapper name and placement, provided it matches existing context style and stays thin over `Sigra.DataExport.export_auth_data/3`.
- Exact documentation structure, provided account lifecycle, audit/auth export, and testing docs cover the required boundary and omission truth.
- Exact tests that pin golden parity, as long as template, example app, and install golden behavior are all represented.

### Folded Todos
None.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase and milestone contract
- `.planning/ROADMAP.md` - Phase 129 goal, success criteria, and dependency on Phase 128.
- `.planning/REQUIREMENTS.md` - `HOST-01` and `DOC-01` requirement definitions.
- `.planning/PROJECT.md` - active `DATA-LIFECYCLE` boundary and hybrid library/generated-host philosophy.
- `.planning/STATE.md` - current sequencing and Phase 129 readiness.
- `.planning/METHODOLOGY.md` - decisive-defaulting and escalation thresholds applied during context gathering.

### Prior phase authority
- `.planning/phases/127-versioned-auth-data-export/127-CONTEXT.md` - library-owned export payload contract and generated-host boundary.
- `.planning/phases/128-account-deletion-lifecycle-truth/128-CONTEXT.md` - library-owned lifecycle contract and generated-host wrapper boundary.
- `.planning/phases/128-account-deletion-lifecycle-truth/128-01-SUMMARY.md` - executable proof summary for enqueue shape, stale jobs, and soft-delete finalization.

### Library-owned contracts
- `lib/sigra/data_export.ex` - versioned auth/account export, optional-section omissions, safe serializers, and lifecycle status.
- `test/sigra/data_export_test.exs` - payload shape, lifecycle states, omission behavior, and sensitive-field exclusion proof.
- `lib/sigra/account/deletion.ex` - schedule, cancel, execute, active-scheduled predicate, enqueue helper, and finalization strategy truth.
- `lib/sigra/account.ex` - public account lifecycle API and audit co-fate wrappers.
- `lib/sigra/auth.ex` - generated-host-facing API that supplies repo/config/schema context.
- `lib/sigra/workers/account_deletion.ex` - Oban worker args contract and stale-job no-op behavior.

### Generated host and example surfaces
- `priv/templates/sigra.install/core/auth.ex` - generated context wrappers for lifecycle behavior and likely export seam.
- `priv/templates/sigra.install/core/settings_live.ex` - generated settings deletion copy and schedule flow.
- `priv/templates/sigra.install/core/reactivation_live.ex` - generated reactivation copy and cancel flow.
- `priv/templates/sigra.install/core/user.ex` - generated user lifecycle fields and deletion changeset.
- `priv/templates/sigra.install/admin/audit_export_controller.ex` - thin generated controller seam precedent for library-owned export behavior.
- `test/example/lib/example/accounts.ex` - example app context wrapper and impersonation guard around lifecycle operations.
- `test/example/lib/example_web/live/settings_live.ex` - example deletion schedule copy and flow.
- `test/example/lib/example_web/live/reactivation_live.ex` - example reactivation copy and cancel flow.
- `test/example/lib/example_web/controllers/admin/audit_export_controller.ex` - example thin controller seam precedent.
- `test/fixtures/install_golden/tree/` - generated-output fixture that should reflect current template behavior.

### Docs to align
- `guides/flows/account-lifecycle.md` - lifecycle strategy and deletion behavior narrative.
- `guides/flows/audit-logging.md` - audit export narrative and likely place to clarify auth/account export boundary.
- `guides/recipes/testing.md` - testing helper claims that must not overstate hard-delete behavior.
- `guides/introduction/getting-started.md` - entry-point cross-links if data-lifecycle docs need discoverability.
- `guides/recipes/deployment.md` - Oban/lifecycle worker setup reference.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Sigra.DataExport.export_auth_data/3` already returns a versioned Sigra-owned export with account lifecycle state, optional Sigra-owned sections, enterprise exclusion truth, and omissions.
- Existing generated lifecycle wrappers in `priv/templates/sigra.install/core/auth.ex` already delegate schedule/cancel/status to library APIs.
- Existing example lifecycle wrappers in `test/example/lib/example/accounts.ex` follow the same pattern while preserving impersonation guards.
- Existing install golden lifecycle wrappers mirror generated template behavior under `test/fixtures/install_golden/tree/`.
- `Sigra.Admin.Audit.Export` plus generated/example audit export controllers provide a thin-host-seam precedent for library-owned export logic.

### Established Patterns
- Sigra keeps security-sensitive and truth-sensitive contracts in the dependency; generated code supplies host schemas, routes, wrappers, and presentation.
- Generated host, example app, install golden, and public docs should agree before Phase 130 release-readiness proof.
- Optional generated schemas degrade explicitly through omission notes rather than hidden missing data or fake stubs.
- Data-lifecycle docs must stay bounded to Sigra-owned auth/account data and avoid implying legal/compliance completeness.

### Integration Points
- `priv/templates/sigra.install/core/auth.ex`, `test/example/lib/example/accounts.ex`, and `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts.ex` are likely primary implementation targets for the export wrapper seam.
- Generated and example LiveView copy around scheduled deletion may need wording changes to avoid unconditional permanent-removal claims.
- `guides/flows/account-lifecycle.md`, `guides/flows/audit-logging.md`, and `guides/recipes/testing.md` are the core documentation targets for boundary and omission truth.
- Golden parity should be validated after template changes, with tests or fixture checks pinning the generated output.
</code_context>

<specifics>
## Specific Ideas

- A generated helper such as `export_auth_data(user, opts \\ [])` should call `Sigra.DataExport.export_auth_data/3` with the generated repo and Sigra-owned optional schema modules, then allow caller opts to override or extend only schema/config inputs.
- Keep the export helper in the generated auth/accounts context rather than creating a new generated payload module unless planning finds a stronger existing pattern.
- Prefer docs language such as "Sigra-owned auth/account data" and "host applications remain responsible for their own domain data, retention policy, and legal interpretation."
- Prefer generated deletion copy that says the account is "scheduled for deletion according to your configured strategy" rather than promising all data will be permanently removed.
</specifics>

<deferred>
## Deferred Ideas

None - analysis stayed within phase scope.

### Reviewed Todos (not folded)
None.
</deferred>

---

*Phase: 129-generated-host-parity-and-docs*
*Context gathered: 2026-05-27*
