# Phase 97: Webhook Subscription Registry + Signed Dispatcher Contract - Pattern Map

**Mapped:** 2026-05-06
**Files analyzed:** 15 likely files/modules
**Analogs found:** 14 / 15

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/sigra/webhooks.ex` | service | CRUD + request-response | `lib/sigra/service_accounts.ex` | exact |
| `lib/sigra/webhooks/dispatcher.ex` | service | event-driven + request-response | `lib/sigra/auth.ex` `register_user_multi/2`; `lib/sigra/organizations.ex` `add_member_multi/5` | exact |
| `lib/sigra/webhooks/signature.ex` | utility | transform + request-response | `lib/sigra/token.ex`; `lib/sigra/mfa/trust.ex` | exact |
| `lib/sigra/workers/webhook_delivery.ex` | worker | event-driven | `lib/sigra/workers/email_delivery.ex` | exact |
| `lib/sigra/config.ex` | config | request-response | `lib/sigra/config.ex` `:api_token` / `:service_accounts` blocks | exact |
| `lib/sigra/optional_deps.ex` | config/utility | request-response | `lib/sigra/optional_deps.ex` `:async_email` / `:lifecycle_jobs` specs | exact |
| `test/fixtures/install_golden/tree/priv/repo/migrations/TIMESTAMP_create_webhook_tables.exs` | migration | CRUD | `test/fixtures/install_golden/tree/priv/repo/migrations/TIMESTAMP_create_organizations.exs`; `TIMESTAMP_create_audit_events.exs` | exact |
| `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/webhook_subscription.ex` | model | CRUD | `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/organization_invitation.ex` | exact |
| `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/webhook_event.ex` | model | event-driven | `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/audit_event.ex` | role-match |
| `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/webhook_delivery.ex` | model | event-driven | `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/audit_event.ex` | role-match |
| `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts.ex` webhook wrappers | context | request-response | `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts.ex` MFA wrappers | exact |
| `test/sigra/webhooks_audit_atomicity_test.exs` | test | event-driven | `test/sigra/service_accounts_audit_atomicity_test.exs` | exact |
| `test/sigra/workers/webhook_delivery_test.exs` | test | event-driven | `test/sigra/workers/account_deletion_test.exs` | exact |
| `test/sigra/webhooks_signature_test.exs` | test | transform | `test/sigra/passkeys/cose_serialization_test.exs` | role-match |
| `guides/flows/webhooks.md` / `guides/recipes/webhook-verification.md` | docs | request-response | `guides/flows/api-authentication.md`; `guides/recipes/m2m-service-accounts.md`; `guides/flows/audit-logging.md` | partial |

## Pattern Assignments

### 1. Subscription schema + context API

**Recommended analogs**

- Context/service API: `lib/sigra/service_accounts.ex:16-188`
- Generated schema: `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/organization_invitation.ex:1-85`
- Generated wrapper context: `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts.ex:599-670`

**Copy from `Sigra.ServiceAccounts` for the library API shape**

- `create/3`, `revoke/3`, `create_credential/4`, `revoke_credential/3` in [lib/sigra/service_accounts.ex](/Users/jon/projects/sigra/lib/sigra/service_accounts.ex:16)
- Consistent pattern:
  - fetch schema module from `%Sigra.Config{}`
  - build changeset via generated host schema
  - wrap write in `Ecto.Multi`
  - append audit step
  - normalize `{:ok, %{step: row}}` vs `{:error, step, reason, _}`

**Concrete core pattern** (`lib/sigra/service_accounts.ex:21-47`)

```elixir
changeset = schema.changeset(struct(schema), attrs)

Multi.new()
|> Multi.insert(:service_account, changeset)
|> append_audit(config, "service_account.create", scope, ...)
|> config.repo.transaction()
|> normalize_multi_result()
```

**Copy generated schema layout from `OrganizationInvitation`**

- Binary IDs + `@foreign_key_type :binary_id`: [organization_invitation.ex](/Users/jon/projects/sigra/test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/organization_invitation.ex:35)
- Timestamps as state flags instead of status enum: [organization_invitation.ex](/Users/jon/projects/sigra/test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/organization_invitation.ex:38)
- Changeset shape with `cast`, `validate_required`, `assoc_constraint`, `unique_constraint`: [organization_invitation.ex](/Users/jon/projects/sigra/test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/organization_invitation.ex:65)

**Recommendation**

- Model `WebhookSubscription` like a generated host schema, not a library-owned Ecto schema.
- Follow `ServiceAccounts` for the public API and wrapper orchestration.
- Follow `OrganizationInvitation` for field layout, constraints, and generated-file placement.

### 2. Event row + delivery row persistence

**Recommended analogs**

- Pure composable builder: `lib/sigra/auth.ex:197-247`
- Pure composed membership builder: `lib/sigra/organizations.ex:901-970`
- Audit-safe append semantics: `lib/sigra/audit.ex:221-302`
- Atomic multi-step mutation style: `lib/sigra/organizations/invitations.ex:199-215`, `lib/sigra/service_accounts.ex:27-47`

**Strongest pattern for webhook outbox insertion**

- `Sigra.Auth.register_user_multi/2` in [lib/sigra/auth.ex](/Users/jon/projects/sigra/lib/sigra/auth.ex:197)
  - zero Repo calls during construction
  - safe to `Ecto.Multi.append/2`
  - appends extra persisted side effects only when configured

**Concrete builder pattern** (`lib/sigra/auth.ex:223-247`)

```elixir
multi =
  Ecto.Multi.new()
  |> Ecto.Multi.insert(:user, changeset_fn.(attrs))

Audit.log_multi_safe(multi, "auth.register.success", ...)
```

**Composition pattern** (`lib/sigra/organizations.ex:901-970`)

- `add_member_multi/5` resolves prior-step values with `{:changes_key, atom}`
- uses `Multi.run` for derived row inputs
- inserts downstream row from prior changes

That is the closest precedent for:

1. insert webhook event row
2. derive matching subscriptions
3. insert per-subscription delivery rows
4. return a single composed `Ecto.Multi`

**Audit-atomic append pattern** (`lib/sigra/audit.ex:254-302`)

- `log_multi_safe/3` returns unchanged multi when feature disabled
- otherwise appends named insert step
- `emit_telemetry_from_changes/2` is called only after commit

**Recommendation**

- Implement webhook persistence as a pure builder, likely `build_dispatch_multi/…`, not as an inline `Repo.transact` hidden in every auth mutation.
- Use step names like `:webhook_event` and `:webhook_deliveries`, mirroring Sigra’s named-step convention.
- Prefer `Repo.transact/1` where the caller already uses it; this is already the modern pattern in [lib/sigra/auth.ex](/Users/jon/projects/sigra/lib/sigra/auth.ex:156) and [lib/sigra/organizations.ex](/Users/jon/projects/sigra/lib/sigra/organizations.ex:923).

### 3. Signing and verification helper modules

**Recommended analogs**

- Generic sign/verify + constant-time compare: `lib/sigra/token.ex:21-201`
- Purpose-specific signed payload with validation collapse: `lib/sigra/token.ex:119-184`
- Fixed-salt signed cookie helper: `lib/sigra/mfa/trust.ex:19-126`

**Copy from `Sigra.Token`**

- `generate/4` and `verify/4`: [lib/sigra/token.ex](/Users/jon/projects/sigra/lib/sigra/token.ex:21)
- invitation-envelope pattern for versioned payload validation: [lib/sigra/token.ex](/Users/jon/projects/sigra/lib/sigra/token.ex:119)
- `secure_compare/2` wrapper: [lib/sigra/token.ex](/Users/jon/projects/sigra/lib/sigra/token.ex:187)

**Copy from `Sigra.MFA.Trust`**

- fixed salt constant and small public API: [lib/sigra/mfa/trust.ex](/Users/jon/projects/sigra/lib/sigra/mfa/trust.ex:19)
- sign exact tuple payload, verify exact tuple shape, collapse mismatch to `{:error, :invalid}`: [lib/sigra/mfa/trust.ex](/Users/jon/projects/sigra/lib/sigra/mfa/trust.ex:86)

**Recommendation**

- Keep webhook signing isolated in a dedicated helper, not inline inside the worker.
- Mirror `Token.verify/4` and `MFA.Trust.verify/5` return shapes for malformed vs expired handling.
- For the receiver contract, document constant-time digest comparison explicitly, reusing the `Sigra.Token.secure_compare/2` posture.

### 4. Async worker and queue config

**Recommended analogs**

- Job enqueue seam: `lib/sigra/delivery.ex:24-70`
- Worker module + optional dep gate: `lib/sigra/workers/email_delivery.ex:1-152`
- Tenant-aware worker contract when scope matters: `lib/sigra/workers.ex:1-78`
- Worker with reconstructed scope from stringified args: `lib/sigra/workers/account_deletion.ex:78-183`
- Optional dep registry: `lib/sigra/optional_deps.ex:57-127`
- Config queue knobs: `lib/sigra/config.ex:628-722` and existing `email` options in module docs

**Important contrast from `Sigra.Delivery`**

- [lib/sigra/delivery.ex](/Users/jon/projects/sigra/lib/sigra/delivery.ex:24) supports `:auto` and sync fallback.
- Phase 97 explicitly says webhooks must not inherit that fallback.

**Copy from `EmailDelivery`**

- override `new/2` to enforce optional-dep availability before a job struct is built: [email_delivery.ex](/Users/jon/projects/sigra/lib/sigra/workers/email_delivery.ex:45)
- dual-defmodule pattern for compile-without-Oban support: [email_delivery.ex](/Users/jon/projects/sigra/lib/sigra/workers/email_delivery.ex:127)
- queue/max_attempts definition at `use Oban.Worker`: [email_delivery.ex](/Users/jon/projects/sigra/lib/sigra/workers/email_delivery.ex:32)

**Copy from `AccountDeletion` only if webhook worker needs tenant/audit scope**

- stringified arg validation before `Module.safe_concat`: [account_deletion.ex](/Users/jon/projects/sigra/lib/sigra/workers/account_deletion.ex:83)
- reconstruct minimal scope from IDs: [account_deletion.ex](/Users/jon/projects/sigra/lib/sigra/workers/account_deletion.ex:96)

**Recommendation**

- Add a new enforced optional-dep feature in `Sigra.OptionalDeps`, modeled on `:async_email` or `:lifecycle_jobs`.
- Add explicit NimbleOptions keys under a new `:webhooks` config section, modeled on `:api_token` / `:service_accounts` blocks in [lib/sigra/config.ex](/Users/jon/projects/sigra/lib/sigra/config.ex:628).
- Keep webhook queue config explicit like `oban_queue` / `oban_concurrency`; do not auto-detect into sync mode.

### 5. Public serializer boundaries

**No exact webhook analog exists yet. Use the nearest boundary modules and keep the gap explicit.**

**Closest existing boundaries**

- Operator-facing projection map: `lib/sigra/admin/audit/presenter.ex:1-55`
- Stable preview contract with documented allowed keys: `lib/sigra/admin/users/detail.ex:61-100`
- Explicit binary serializer helper: `lib/sigra/passkeys/cose_key.ex:1-22`

**What to copy**

- Separate “internal row” from “public map” concerns.
- Give the serializer its own module with a narrow API, like `present/2` or `serialize/1`.
- Document the output contract near the function, like `recent_audit_preview/3` does.

**Recommendation**

- Do not use audit rows or generated Ecto schemas as the public webhook payload directly.
- Introduce explicit serializer modules per public resource family or a single `Sigra.Webhooks.Serializer` namespace.
- Treat this as a deliberate new seam; there is no exact existing webhook serializer to clone.

### 6. Generated migration and schema layout

**Recommended analogs**

- Multi-table migration with comments + partial indexes: `test/fixtures/install_golden/tree/priv/repo/migrations/TIMESTAMP_create_organizations.exs:4-116`
- Append-only event row migration: `test/fixtures/install_golden/tree/priv/repo/migrations/TIMESTAMP_create_audit_events.exs:4-24`
- Security-related auth table layout: `test/fixtures/install_golden/tree/priv/repo/migrations/TIMESTAMP_create_sigra_auth_tables.exs:31-98`

**What to copy**

- binary primary keys and `timestamps(type: ...)`
- partial unique indexes for active/pending-state invariants
- append-only event rows with `updated_at: false` where rows should never mutate meaningfully

**Likely mapping**

- `webhook_subscriptions` should follow invitation-style durable state + partial uniqueness
- `webhook_events` and `webhook_deliveries` should follow audit-event style append-only/event-history layout

### 7. Tests and docs placement

**Recommended analogs**

- Audit/co-fate integration tests: `test/sigra/service_accounts_audit_atomicity_test.exs:1-242`
- Worker contract tests: `test/sigra/workers/account_deletion_test.exs:1-170`
- Small serializer/helper round-trip tests: `test/sigra/passkeys/cose_serialization_test.exs:1-22`
- Conceptual flow guide: `guides/flows/audit-logging.md:1-179`
- Feature recipe: `guides/recipes/m2m-service-accounts.md:1-173`
- API/contract-facing guide: `guides/flows/api-authentication.md:1-182`

**Recommendation**

- Put library behavior tests under `test/sigra/`.
- Put worker-specific tests under `test/sigra/workers/`.
- Put generated-host migration/schema changes under `test/fixtures/install_golden/tree/...`.
- Split docs into:
  - `guides/flows/webhooks.md` for the event model, headers, payload, retries contract
  - `guides/recipes/webhook-verification.md` for Plug/Phoenix raw-body verification wiring

## Shared Patterns

### Configuration surface

**Source:** [lib/sigra/config.ex](/Users/jon/projects/sigra/lib/sigra/config.ex:628)

- New feature config should be a top-level keyword section with nested validated keys.
- Best analogs are `:api_token` and `:service_accounts`, not ad hoc flat config keys.

### Optional dependency gating

**Source:** [lib/sigra/optional_deps.ex](/Users/jon/projects/sigra/lib/sigra/optional_deps.ex:57)

- Feature is declared once in `feature_specs_map/0`
- `ensure_available!/2` is called at first meaningful async use
- worker `new/2` also hard-fails early

### Audit-atomic `Ecto.Multi`

**Source:** [lib/sigra/audit.ex](/Users/jon/projects/sigra/lib/sigra/audit.ex:221), [lib/sigra/auth.ex](/Users/jon/projects/sigra/lib/sigra/auth.ex:197), [lib/sigra/organizations.ex](/Users/jon/projects/sigra/lib/sigra/organizations.ex:901)

- build pure multis
- append persisted side effects
- emit telemetry only after committed success

### Generated-host schema ownership

**Source:** [organization_invitation.ex](/Users/jon/projects/sigra/test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/organization_invitation.ex:1), [audit_event.ex](/Users/jon/projects/sigra/test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/audit_event.ex:1)

- security-critical orchestration stays in library
- concrete Ecto schemas live in generated host code

## No Exact Analog Found

| File/Concern | Reason | Use Instead |
|---|---|---|
| `lib/sigra/webhooks/serializer.ex` or equivalent public payload contract modules | Sigra has no existing external webhook/public-event serializer seam | Use `Sigra.Admin.Audit.Presenter` and `Sigra.Admin.Users.Detail.recent_audit_preview/3` as the nearest “shape internal row into stable consumer map” precedent |

## Metadata

**Analog search scope:** `lib/sigra/**`, `lib/sigra/workers/**`, `test/sigra/**`, `guides/**`, `test/fixtures/install_golden/tree/**`

**Strongest analogs by requested area**

1. Subscription schema + context API
   [lib/sigra/service_accounts.ex](/Users/jon/projects/sigra/lib/sigra/service_accounts.ex:16), [organization_invitation.ex](/Users/jon/projects/sigra/test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/organization_invitation.ex:1)
2. Event row + delivery row persistence
   [lib/sigra/auth.ex](/Users/jon/projects/sigra/lib/sigra/auth.ex:197), [lib/sigra/organizations.ex](/Users/jon/projects/sigra/lib/sigra/organizations.ex:901), [lib/sigra/audit.ex](/Users/jon/projects/sigra/lib/sigra/audit.ex:254)
3. Signing and verification helper modules
   [lib/sigra/token.ex](/Users/jon/projects/sigra/lib/sigra/token.ex:21), [lib/sigra/mfa/trust.ex](/Users/jon/projects/sigra/lib/sigra/mfa/trust.ex:73)
4. Async worker and queue config
   [lib/sigra/workers/email_delivery.ex](/Users/jon/projects/sigra/lib/sigra/workers/email_delivery.ex:1), [lib/sigra/workers/account_deletion.ex](/Users/jon/projects/sigra/lib/sigra/workers/account_deletion.ex:1), [lib/sigra/optional_deps.ex](/Users/jon/projects/sigra/lib/sigra/optional_deps.ex:57)
5. Tests and docs placement
   [test/sigra/service_accounts_audit_atomicity_test.exs](/Users/jon/projects/sigra/test/sigra/service_accounts_audit_atomicity_test.exs:1), [test/sigra/workers/account_deletion_test.exs](/Users/jon/projects/sigra/test/sigra/workers/account_deletion_test.exs:1), [guides/flows/audit-logging.md](/Users/jon/projects/sigra/guides/flows/audit-logging.md:1), [guides/recipes/m2m-service-accounts.md](/Users/jon/projects/sigra/guides/recipes/m2m-service-accounts.md:1)
