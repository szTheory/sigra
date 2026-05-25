# Phase 122: Enterprise Connection Contract & Validation - Patterns

## Planned Files -> Closest Analogs

| Planned file | Role | Closest analog | Why it matches |
|--------------|------|----------------|----------------|
| `lib/sigra/enterprise_connections.ex` | library-first org-scoped context | `lib/sigra/organizations.ex` | Same pattern: host-owned schemas, Sigra-owned security-critical CRUD and lifecycle logic. |
| `lib/sigra/enterprise_connections/validation.ex` | external integration validation service | `lib/sigra/oauth.ex`, `lib/sigra/oauth/strategies/generic.ex` | Reuses Assent-centric protocol handling and safe error/audit posture for identity integrations. |
| `priv/templates/sigra.install/organizations/enterprise_connection.ex` | generated host schema | `priv/templates/sigra.install/organizations/organization.ex`, `priv/templates/sigra.install/core/user_api_token.ex` | Existing generated schemas show how Sigra emits host-owned Ecto records while preserving library invariants. |
| `priv/templates/sigra.install/organizations/live/organization_settings_live.ex` | generated-host operator surface | existing `priv/templates/sigra.install/organizations/live/organization_settings_live.ex` | Phase 122 should extend the current org settings surface rather than invent a new control plane. |
| `lib/sigra/install/features/organizations.ex` | installer wiring | existing `lib/sigra/install/features/organizations.ex` | This feature already owns org-scoped schemas, router injections, and org settings templates. |
| `test/sigra/enterprise_connections/*` | new subsystem tests | `test/sigra/oauth/*`, `test/sigra/organizations/*` | OAuth tests cover protocol contract edges; organizations tests cover org-scoped library invariants. |
| `test/sigra/install/features/organizations_test.exs` | generated-host template regression tests | existing `test/sigra/install/features/organizations_test.exs` | Best place to lock in template/UI truth and installer-emitted files. |

## Concrete Reuse Notes

### Org-scoped context pattern

- `Sigra.Organizations` validates config with `use ...` and host-owned schemas.
- Thin host wrapper delegates in `test/example/lib/example/organizations.ex`.
- Phase 122 should mirror that split: library-owned connection logic, host-owned connection schema, thin wrapper delegates for LiveView callers.

### OIDC strategy pattern

- `Sigra.OAuth.Strategies.resolve/2` and `Sigra.OAuth.Strategies.Generic` already normalize arbitrary Assent strategies.
- `test/sigra/oauth/assent_oidc_contract_test.exs` proves `Assent.Strategy.OIDC` is part of the intended substrate.
- Validation code should use Assent/Req-backed OIDC discovery semantics rather than custom protocol logic.

### Generated-host operator surface pattern

- `OrganizationSettingsLive` already centralizes org-owned operator actions on one page with thin event handlers and library calls.
- Phase 122 should extend that page with an enterprise SSO section whose state comes from library APIs, not local heuristics.

### Installer / template pattern

- `Sigra.Install.Features.Organizations.files/1` registers all org-scoped schemas and LiveViews.
- New enterprise connection schema and any org-settings template additions should stay under the organizations feature to preserve `--no-organizations` isolation.

## High-Risk Drift Points

- Do not put enterprise connection state in `config.oauth[:providers]`; that is a global config pattern, not an org-scoped persistence pattern.
- Do not have the generated-host LiveView infer `active` by checking field presence; the library should own the lifecycle state.
- Keep all new templates and feature registrations inside the organizations feature to avoid breaking install isolation or golden diff coverage.
