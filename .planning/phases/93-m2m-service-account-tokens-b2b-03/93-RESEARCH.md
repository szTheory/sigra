# Phase 93: M2M / service-account tokens (B2B-03) — Research

**Researched:** 2026-05-01
**Domain:** OAuth 2.0 client_credentials grant + service-account principals on existing JWT path
**Confidence:** HIGH

## Summary

Phase 93 implements RFC 6749 `client_credentials` for org-scoped service-account (SA) principals on Sigra's existing dual-mode bearer auth path. CONTEXT.md locks 24 decisions (D-93-01..D-93-24); the planner's job is to translate those into 6 already-titled plans without re-litigating the domain. UI-SPEC.md (revision 1) locks every visible string and component placement for the admin LiveView. There is no greenfield ambiguity left at the design level; this research scopes the **implementation surface** so plan boundaries do not overlap and no integration point is missed.

**Key environmental fact discovered during research (HIGH confidence, verified by grep on `lib/`):** Phase 93 is **partially started** on disk. `lib/sigra/jwt.ex` already contains `generate_service_account_tokens/3` + a `verify_service_account_epoch/2` branch in `verify_access/2`, and `lib/sigra/plug/fetch_bearer.ex` already forks on `claims["actor_type"] == "service_account"` and calls `Sigra.ServiceAccounts.commit_verify_failure_audit/3`. **However, `Sigra.ServiceAccounts` does not exist** (`find lib -name "service_accounts*"` returns nothing). The library currently has dangling references that prevent compilation. STATE.md / ROADMAP.md mark Phase 93 "complete" — that is incorrect. No `93-*-PLAN.md` files exist on disk. The phase needs to be planned and executed; existing partial integrations should be **kept and finished**, not deleted, because they already encode the locked CONTEXT decisions correctly.

**Primary recommendation:** Plan 93-01 must include a "complete the partial library context module" wave that finishes `Sigra.ServiceAccounts` against the existing dangling references. Plans 93-02 through 93-06 then wire generator templates, controller, LiveView, recipe, and verification on top of a now-compiling library. The atomic-Multi orchestrator pattern is mature (every Phase 91 / 82 / 80 / 77 / 73 mutation uses it); Phase 93 mirrors `Sigra.Organizations.do_set_mfa_policy/4` (mfa_policy_change) one-for-one for each of the five SA mutations.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| SA principal CRUD + audit Multi orchestration | Library (`Sigra.ServiceAccounts` context) | — | Security-critical; matches `Sigra.Organizations` shape; orchestrator owns the txn (D-AUD-01) |
| SA + credential schemas | Generated host (`<App>.ServiceAccount`, `<App>.ServiceAccountCredential`) | — | Hosts own data shape per Sigra hybrid lib+generator philosophy; library never hard-codes table names |
| `client_secret` hash + verify primitives | Library (`Sigra.Token.generate_hashed_token/0` + `Sigra.Token.hash_token/1`, REUSED) | — | Already exists for API tokens; SHA-256 over 32-byte random; no new crypto |
| JWT issuance for SA | Library (`Sigra.JWT.generate_service_account_tokens/3`, EXISTS) | — | Single JWT module; SA path already extended |
| JWT verify with SA epoch + credential `revoked_at` | Library (`Sigra.JWT.verify_access/2` SA branch, EXISTS) | — | Single verify entry point; honors ROADMAP SC #5 |
| Bearer extraction + dual-mode dispatch | Library (`Sigra.Plug.FetchBearer`, EXISTS with SA fork) | — | Single auth entry point; no parallel pipeline |
| `RequireMembership` / `RequireOrgMfa` SA short-circuit | Library plugs (NEW guards added to existing modules) | — | Top-of-function guards; mirrors Phase 91 D-91-07 |
| `/oauth/token` controller | Generated host (`<App>Web.OAuthTokenController`) + library helper (`Sigra.OAuth.Token`) | — | Controller is HTTP shell; library `issue_token/3` does the work |
| Admin LiveView (CRUD + credential disclosure modal) | Generated host (`<App>Web.OrganizationServiceAccountsLive`) | — | Hybrid lib+generator: host owns presentation; sudo gating per UI-SPEC |
| Generator gating (`--organizations` AND `--jwt`) | Library installer (`Sigra.Install.Features.Organizations` extension) | — | Existing `enabled?/1` pattern; SA artifacts opt out cleanly when either flag is off |
| Audit row writes | Library (`Sigra.Audit.log_multi_safe/3`, REUSED) | — | Existing audit composer; new action strings only |

## Standard Stack

### Core (existing — no new deps)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Phoenix | ~> 1.8 (1.8.5) | Routing, controller, LiveView | Already locked by Sigra; Phase 93 adds one controller + one LiveView |
| Ecto + Ecto.SQL | ~> 3.12 (3.13.5) | Schemas, migrations, Multi composition | Atomic-audit pattern uses `Ecto.Multi`; `Repo.transact/2` (3.13+) optional |
| Joken | ~> 2.6 (optional) | JWT signing for SA access tokens | Already used by `Sigra.JWT.generate_tokens/4`; SA path reuses `Joken.generate_and_sign/3` |
| nimble_options | ~> 1.1 | New `:service_accounts` option keyword in `Sigra.Config` schema | Sigra-wide standard for config validation |

### Supporting (existing infrastructure)

| Library / Module | Purpose | When to Use |
|------------------|---------|-------------|
| `Sigra.Token.generate_hashed_token/0` + `Sigra.Token.hash_token/1` | `client_secret` 32-byte random + SHA-256 hashing | Credential creation; verification |
| `Sigra.Audit.log_multi_safe/3` | Append audit insert step to a Multi | All five SA mutation audit rows + `service_account.token_issued` |
| `Sigra.APIToken.ScopeRegistry.validate_scopes/2` | Validate `resource:action` scope strings | Reused for SA scope validation; hosts add scopes via `:custom_scopes` config |
| `Sigra.Plug.RequireSudo` (existing) | Sudo gate on create/revoke admin actions | Wired into LiveView mount/event handlers per D-93-17 |

### Alternatives Considered (already locked by CONTEXT — DO NOT re-debate)

| Instead of | Could Use | Tradeoff (already adjudicated) |
|------------|-----------|----------|
| Separate `service_accounts` table | Synthetic User row | GitLab-regret anti-pattern; locked by D-93-01 |
| `client_id` + `client_secret` | PAT-style single bearer | RFC 6749 violation; locked by D-93-03 |
| `service_account_credentials` join table | Single-credential-per-SA | Destructive rotation; locked by D-93-02 |
| `Sigra.JWT.generate_service_account_tokens/3` (NEW function, EXISTS) | Extend `generate_tokens/4` with SA branch | Already shipped as separate function — KEEP |

### Installation

No new mix.exs deps. Phase 93 is purely additive within the existing stack.

**Version verification (npm equivalent for Hex — verified against hex.pm, May 2026):**
- `joken ~> 2.6` — current 2.6.2 (Jan 2026); already an optional dep, confirmed
- `nimble_options ~> 1.1` — current 1.1.1; already in deps tree
- `phoenix ~> 1.8` — current 1.8.5; already in deps tree

## Architecture Patterns

### System Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────────┐
│                         External Caller                              │
│  POST /oauth/token  body: grant_type=client_credentials              │
│                     auth: Basic <base64(client_id:client_secret)>    │
│                           OR form fields client_id + client_secret   │
└──────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────────┐
│            <App>Web.OAuthTokenController.create/2 (NEW)              │
│  • Parse Basic auth header OR form-encoded credentials               │
│  • Match on params["grant_type"]                                     │
│    ├─ "client_credentials" → Sigra.ServiceAccounts.issue_token/3     │
│    └─ _ → 400 {"error":"unsupported_grant_type"}                     │
└──────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────────┐
│         Sigra.ServiceAccounts.issue_token/3 (NEW LIB FN)             │
│  • Lookup credential by client_id (DB)                               │
│  • Verify SHA-256(client_secret) matches hashed_client_secret        │
│  • Verify credential.revoked_at == nil and not expired               │
│  • Verify service_account.revoked_at == nil                          │
│  • Validate requested scopes are subset of SA's granted scopes       │
│  • Delegate JWT mint to Sigra.JWT.generate_service_account_tokens/3  │
│    (which performs the issuance audit + last_used_at bump in 1 Multi)│
│  Returns {:ok, %{access_token, token_type:"Bearer", expires_in,scope}│
│       | {:error, :invalid_client | :invalid_scope | :sa_aborted}     │
└──────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────────┐
│           Sigra.JWT.generate_service_account_tokens/3 (EXISTS)       │
│  • build_service_account_claims/4 → JWT payload                      │
│  • Multi.new |> append_token_issued_audit |> repo.transaction        │
│  • On {:ok, _} → Joken.generate_and_sign + return access_token       │
└──────────────────────────────────────────────────────────────────────┘
                              │
                              │  JWT returned to caller
                              ▼
─ ── ── ── ── ── ── ── (subsequent API request) ── ── ── ── ── ── ── ──
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────────┐
│   GET /api/protected  Authorization: Bearer eyJ...<jwt>...           │
└──────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────────┐
│         Sigra.Plug.FetchBearer.call/2 (EXISTS — SA fork in)          │
│  • detect "eyJ" prefix → JWT path                                    │
│  • Sigra.JWT.verify_access/2                                         │
│    ├─ verify_epoch checks claims["actor_type"]:                      │
│    │   ├─ "service_account" → verify_service_account_epoch/2         │
│    │   │     • load SA + credential rows                             │
│    │   │     • check sa.revoked_at, credential.revoked_at, expires_at│
│    │   │     • check sa.token_epoch == claims["epoch"]               │
│    │   └─ else → user epoch check (existing)                         │
│  • build_jwt_scope/3 forks on actor_type:                            │
│    ├─ "service_account" → loads org_id from claims, builds scope:    │
│    │     {user: nil, active_organization: org, role: sa.role,        │
│    │      actor_type: :service_account, service_account_id: sa.id,   │
│    │      token_scopes: claims["scopes"], auth_method: :jwt}         │
│    └─ else → existing user scope build                               │
│  • Failure path: maybe_audit_jwt_failure for SA → calls              │
│    Sigra.ServiceAccounts.commit_verify_failure_audit/3 (NEW)         │
└──────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────────┐
│  Plugs in pipeline: RequireMembership, RequireOrgMfa (NEW guards)    │
│  • Top-of-call short-circuit: if scope.actor_type == :service_account│
│    → return conn unchanged. SA's organization_id IS the membership.  │
└──────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
            Host controller / LiveView reads current_scope
            • scope.user == nil
            • scope.actor_type == :service_account
            • scope.service_account_id populated
            • scope.role populated (or nil) from sa.role
```

### Recommended Project Structure

```
lib/sigra/
├── service_accounts.ex        # NEW: top-level context (parallel to Sigra.Organizations)
├── service_accounts/          # OPTIONAL — only if planner splits internals
│   └── (none required for v1.21)
├── oauth/
│   └── token.ex               # NEW: Sigra.OAuth.Token — RFC 6749 grant dispatch helper
├── jwt.ex                     # MODIFIED (already partial — finish references)
├── plug/
│   ├── fetch_bearer.ex        # MODIFIED (already partial — finish references)
│   ├── require_membership.ex  # MODIFIED (add SA short-circuit guard)
│   └── require_org_mfa.ex     # MODIFIED (add SA short-circuit guard)
├── scope.ex                   # MODIFIED (add :service_account_id field threading)
└── config.ex                  # MODIFIED (add :service_accounts NimbleOptions key)

priv/templates/sigra.install/
├── core/
│   ├── scope.ex                       # MODIFIED (add service_account_id: nil to defstruct)
│   └── oauth_token_controller.ex      # NEW
├── organizations/
│   ├── service_account.ex                                # NEW schema template
│   ├── service_account_credential.ex                     # NEW schema template
│   ├── service_accounts_migration.exs                    # NEW Postgres-only migration
│   ├── router_injection.ex                               # MODIFIED (add /service-accounts route)
│   └── live/
│       └── organization_service_accounts_live.ex         # NEW LiveView
└── sigra.upgrade/
    └── alter_add_service_accounts.exs                    # NEW v1.21 upgrade migration

test/sigra/
├── service_accounts_test.exs                       # NEW unit (CRUD + revoke)
├── service_accounts_audit_atomicity_test.exs       # NEW Postgres + fault injection
├── oauth/token_test.exs                            # NEW RFC 6749 envelope conformance
├── jwt_test.exs                                    # EXTENDED (SA actor_type cases)
└── plug/
    ├── fetch_bearer_test.exs                       # EXTENDED (SA scope-build assertions)
    ├── require_membership_test.exs                 # EXTENDED (SA short-circuit assertion)
    └── require_org_mfa_test.exs                    # EXTENDED (SA short-circuit assertion)

test/example/test/example_web/integration/
└── service_account_e2e_test.exs                    # NEW generator-host integration

guides/recipes/
├── m2m-service-accounts.md                         # NEW recipe (D-93-Discretion: lock name)
└── role-based-access-control.md                    # MODIFIED (Authorizing service-account requests section)
```

### Pattern 1: Atomic Multi orchestrator + audit (locked from D-AUD-01..D-AUD-08)

**What:** Every state-changing SA operation owns a single `Repo.transaction/1` (or `Repo.transact/2`) that combines the domain write and the audit row insert via `Sigra.Audit.log_multi_safe/3`.

**When to use:** All five Phase 93 SA mutations (create, revoke, credential_create, credential_revoke, token_issued).

**Example (mirrors `Sigra.Organizations.do_set_mfa_policy/4` at lib/sigra/organizations.ex:1499):**

```elixir
# Source: lib/sigra/organizations.ex:1499 (verbatim shape; SA equivalent shown)
defp do_create(config, scope, organization, attrs) do
  changeset = ServiceAccount.changeset(%ServiceAccount{}, Map.put(attrs, :organization_id, organization.id))

  result =
    try do
      Multi.new()
      |> Multi.insert(:service_account, changeset)
      |> append_audit(config, "service_account.create", scope,
        metadata: %{
          service_account_id: nil,  # resolved via target_resolver in changes map
          name: attrs.name,
          scopes: attrs.scopes
        }
      )
      |> config.repo.transact()
      |> normalize_multi_result()
    rescue
      e ->
        reason = if match?(%Ecto.ConstraintError{}, e), do: :constraint_violation, else: :database_error

        :telemetry.execute(
          [:sigra, :audit, :log_safe_error],
          %{count: 1},
          %{action: "service_account.create", reason: reason}
        )

        {:error, :service_account_aborted}
    end

  case result do
    {:ok, %{service_account: sa}} -> {:ok, sa}
    error -> error
  end
end

defp append_audit(multi, config, action, scope, extra) do
  audit_opts = [
    repo: config.repo,
    audit_schema: config[:audit_schema],
    actor_id: get_in_scope(scope, :user, :id),
    metadata: Keyword.get(extra, :metadata, %{})
  ]
  Sigra.Audit.log_multi_safe(multi, action, audit_opts)
end
```

### Pattern 2: Audit-only Multi for issuance (mirrors Phase 81 audit-only shape)

**What:** `service_account.token_issued` is audit-only at the issuance moment but must roll back if audit insert fails (per D-93-22 / D-AUD-08 — issuance is co-fated with `last_used_at` bump on the credential row, mirroring D-AUD-08 over JWT refresh).

**When to use:** Inside `Sigra.JWT.generate_service_account_tokens/3` (already in place — finish wiring `Sigra.ServiceAccounts.append_token_issued_audit/3` callback).

**Example shape:**

```elixir
multi =
  Multi.new()
  |> Multi.update(:credential_last_used,
       Ecto.Changeset.change(credential, last_used_at: DateTime.utc_now()))
  |> Sigra.Audit.log_multi_safe("service_account.token_issued",
       repo: config.repo,
       audit_schema: config[:audit_schema],
       organization_id: service_account.organization_id,
       metadata: %{
         service_account_id: service_account.id,
         credential_id: credential.id,
         scopes: service_account.scopes,
         jti: claims["jti"],
         ip_address: claims["ip_address"]  # planner: thread from controller via opts
       },
       audit_multi_step: :audit_sa_token_issued
     )

case config.repo.transaction(multi) do
  {:ok, changes} ->
    Audit.emit_telemetry_from_changes(changes, [:audit_sa_token_issued])
    # ... mint JWT, return
  {:error, _failed, _reason, _changes} ->
    {:error, :service_account_token_issuance_aborted}
end
```

### Pattern 3: Top-of-function actor_type short-circuit (D-93-13, D-93-14)

**What:** `RequireMembership.call/2` and `RequireOrgMfa.call/2` add a single `cond` branch at the top: if `scope.actor_type == :service_account`, return `conn` unchanged.

**Example (RequireOrgMfa shape):**

```elixir
# Source: lib/sigra/plug/require_org_mfa.ex (existing structure shown; SA guard added)
def call(%Plug.Conn{} = conn, opts) do
  # ... existing fetches ...
  scope = conn.assigns[:current_scope]

  cond do
    is_nil(scope) or is_nil(scope.user) or is_nil(scope.active_organization) ->
      conn

    # NEW Phase 93 short-circuit (D-93-14, locked from Phase 91 D-91-07)
    Map.get(scope, :actor_type) == :service_account ->
      conn

    Map.get(scope.active_organization, :enforce_mfa_for_members, false) == false ->
      conn
    # ... rest unchanged ...
  end
end
```

For `RequireMembership`, the SA guard goes BEFORE the existing `is_nil(scope) or is_nil(scope.active_organization)` clause because SA scope has `active_organization` populated by FetchBearer. (Planner: verify ordering against pipeline — SA scope ALSO has `active_organization`, so without the guard `RequireMembership` would still pass since `required` is empty by default; the guard is needed only when `:roles` is non-empty AND scope.membership is nil. Plan must add the guard explicitly to communicate intent and prevent role-check on SA.)

### Pattern 4: FetchBearer JWT branch fork (D-93-11)

**What:** Inside `do_fetch/2`'s JWT clause, when `claims["actor_type"] == "service_account"`, build scope directly from the claims (no `Scope.Hydration` extension).

**Status:** ALREADY IMPLEMENTED at lib/sigra/plug/fetch_bearer.ex:122 (`build_jwt_scope/3` SA clause). Plan 93-02 work: confirm the implementation matches CONTEXT, finish references to `Sigra.ServiceAccounts.commit_verify_failure_audit/3`.

### Anti-Patterns to Avoid (CONTEXT-locked — research must respect)

- **Synthetic `%User{}` for SA in `scope.user`** — silent-nil bugs (`scope.user.email` propagates into emails / audit metadata); GitLab regret pattern. Locked OUT by D-93-04.
- **Single-credential-per-SA (PAT shape)** — destructive rotation; loses audit lineage. Locked OUT by D-93-02.
- **`Sigra.Plug.FetchServiceAccountBearer` parallel pipeline** — explicitly forbidden by ROADMAP SC #5.
- **Extending `Sigra.Scope.Hydration` with SA branches** — couples hydration to actor type; SA has no membership row. Locked OUT by D-93-11.
- **Refresh tokens for `client_credentials`** — RFC 6749 §4.4.3 SHOULD NOT. Locked OUT by D-93-07.
- **Auditing successful `Sigra.APIToken.verify/2`** — D-27 holds for the verify hot-path. Issuance audit is the only success-path audit (D-93-20 documents the asymmetry).
- **Synthesizing fake `%OrganizationMembership{}` for SA** — pollutes membership query path; locked OUT by D-93-13.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| RFC 6749 token-grant wire shape | Custom JSON envelope | Hand-write per RFC 6749 §5.1 / §5.2 spec verbatim | The spec IS the standard; deviation breaks every SDK. There is no Elixir lib that ships an RFC 6749 server controller for a third-party stack — Doorkeeper is Rails-only. Sigra ships its own ~40-line controller against the spec. |
| `client_secret` hashing | Custom KDF | `Sigra.Token.hash_token/1` (SHA-256) | Already proven over API tokens; rotation works; constant-time compare via `Plug.Crypto.secure_compare`. |
| Audit Multi composition | New `Sigra.Audit.log_sa/3` helper | `Sigra.Audit.log_multi_safe/3` (REUSED) | Existing composer handles `:audit_schema=nil` no-op, `:audit_multi_step` naming, `:metadata` sanitization (D-23 forbidden keys), telemetry emission. New action strings only. |
| JWT signing / claims | New `Sigra.SA.JWT` module | `Sigra.JWT.generate_service_account_tokens/3` (EXISTS) | Single JWT module; SA branch already in. |
| Bearer token extraction | New `Sigra.Plug.FetchSABearer` | `Sigra.Plug.FetchBearer` (EXISTS — SA fork in) | ROADMAP SC #5 lock. |
| Scope validation (`resource:action` format) | Custom regex | `Sigra.APIToken.ScopeRegistry.validate_scopes/2` (REUSED) | Same scope grammar as API tokens; hosts add SA-relevant scopes via `:custom_scopes`. |
| Constant-time string compare for client_secret | `==` operator | `Plug.Crypto.secure_compare/2` | Timing attacks on SA enumeration (T2 in threat model below). |

**Key insight:** Phase 93 has zero genuinely new primitives. Everything is composition over existing Sigra modules + RFC 6749 wire-spec compliance. The risk is integration completeness, not novel design.

## Runtime State Inventory

> Phase 93 is greenfield within Sigra (new tables, new module). However, since the library has existing partial state from a prior incomplete attempt, this section documents what's on disk now.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — no SA rows exist anywhere; no production deployments of Phase 93 partial code (would not compile) | None |
| Live service config | None — `/oauth/token` route not registered anywhere | None |
| OS-registered state | None | None |
| Secrets/env vars | None — no SA-specific env vars introduced; client_secret is per-credential DB-stored | None |
| Build artifacts / installed packages | `Sigra.ServiceAccounts` referenced from `lib/sigra/jwt.ex:55` (`alias Sigra.{APIToken, Audit, ServiceAccounts}`) and `lib/sigra/plug/fetch_bearer.ex:27` (`alias Sigra.ServiceAccounts`) — but the module file does NOT exist. Library WILL NOT COMPILE without finishing the partial work. | Plan 93-01 wave 0: create `lib/sigra/service_accounts.ex` with at minimum the four functions referenced from existing code: `append_token_issued_audit/3` (called from JWT line 137), `commit_verify_failure_audit/3` (called from FetchBearer line 188). Library compiles after this; subsequent waves add the public CRUD API. |

**Verification step the planner MUST add to wave 0:** `mix compile --warnings-as-errors` must pass before any other plan task starts.

## Common Pitfalls

### Pitfall 1: Library has dangling `Sigra.ServiceAccounts` references RIGHT NOW

**What goes wrong:** Any execution agent that pulls main and tries to `mix test` will get an `(UndefinedFunctionError) function Sigra.ServiceAccounts.append_token_issued_audit/3 is undefined (module Sigra.ServiceAccounts is not available)`.

**Why it happens:** Prior work landed `lib/sigra/jwt.ex` SA path and `lib/sigra/plug/fetch_bearer.ex` SA fork without landing the central context module. STATE.md / ROADMAP.md falsely report "complete".

**How to avoid:** Plan 93-01 wave 0 creates a stub `Sigra.ServiceAccounts` with the two referenced callbacks so the library compiles immediately. Subsequent waves replace the stubs with full implementations.

**Warning signs:** `mix compile` fails with `Sigra.ServiceAccounts.X/N is undefined` references at lines 137 (jwt.ex), 188 (fetch_bearer.ex).

### Pitfall 2: `Sigra.Config` `:service_accounts` keyword does not exist

**What goes wrong:** `Sigra.JWT.verify_service_account_epoch/2` (lib/sigra/jwt.ex:478) calls `Keyword.get(config.service_accounts, :service_account_schema)`. `Sigra.Config` schema (lib/sigra/config.ex) has no `:service_accounts` key. `config.service_accounts` returns `nil` and `Keyword.get(nil, ...)` crashes.

**Why it happens:** Same reason as Pitfall 1 — partial wiring landed without the corresponding NimbleOptions schema entry.

**How to avoid:** Plan 93-02 (or 93-01 wave 0) extends `Sigra.Config` `@schema` with:

```elixir
service_accounts: [
  type: :keyword_list,
  default: [],
  doc: "Service-account / M2M token options (Phase 93 / B2B-03).",
  keys: [
    service_account_schema: [
      type: {:or, [:atom, nil]}, default: nil,
      doc: "The generated host ServiceAccount Ecto schema module."
    ],
    service_account_credential_schema: [
      type: {:or, [:atom, nil]}, default: nil,
      doc: "The generated host ServiceAccountCredential Ecto schema module."
    ],
    client_id_byte_size: [
      type: :pos_integer, default: 24,
      doc: "Random bytes in the client_id (after `sigra_sa_` prefix). Default: 24."
    ]
  ]
]
```

And extends the `:jwt` keys list with:

```elixir
client_credentials_access_ttl: [
  type: :pos_integer, default: 3600,
  doc: "Access token TTL in seconds for client_credentials grant. Default: 3600 (1 hour)."
]
```

**Warning signs:** `KeyError` on `config.service_accounts` at runtime; tests pass without exercising the SA verify path then break in integration.

### Pitfall 3: Generated host Scope template missing `:service_account_id` field

**What goes wrong:** `Sigra.Plug.FetchBearer.build_jwt_scope/3` SA clause builds a map with `service_account_id:` key (line 137), then calls `scope_module.new(attrs)`. Generated `<App>.Scope.new/1` from `priv/templates/sigra.install/core/scope.ex` (line 73) only accepts `%User{}` — `new/1` is currently `def new(%User{} = user)` and `def new(nil)`. Map is rejected with `FunctionClauseError`.

**Why it happens:** Scope template has `:role` and `:actor_type` reserved (Phase 92) but never extended with `:service_account_id` because Phase 93 was supposed to do that. `scope_module.new/1` was never extended to accept a map of attrs.

**How to avoid:** Plan 93-02 modifies BOTH:
1. `priv/templates/sigra.install/core/scope.ex` `defstruct` — add `service_account_id: nil`.
2. `priv/templates/sigra.install/core/scope.ex` — add a NEW `def new(%{} = attrs) when is_map(attrs)` clause that builds a `%__MODULE__{}` from the map (mirrors how `Sigra.Scope.build/3` already accepts a map of fields).
3. `lib/sigra/scope.ex` `build/3`, `from_opts/2`, `from_config/2` — add `:service_account_id` to the additive Keyword.get list.

**Warning signs:** `FetchBearer` SA fork tests fail with `FunctionClauseError` on `scope_module.new/1`.

### Pitfall 4: `audit_event.actor_type` column already exists; no migration needed

**What goes wrong:** Planner adds an `alter audit_events add :actor_type` migration "to support SA audit rows" — discovers it already exists from Phase 9 area work (default `"user"`).

**Why it happens:** D-93-19 explicitly notes the column is unchanged. Easy to miss when scanning audit-event templates.

**How to avoid:** Plan 93-04 (audit + golden-diff) verifies via grep on `priv/templates/sigra.install/core/create_audit_events.exs` that the column exists with index, then writes the verification one-liner. NO new migration.

**Warning signs:** Duplicate `actor_type` column attempt fails with `column already exists` at install time.

### Pitfall 5: `RequireMembership` SA short-circuit ordering

**What goes wrong:** Naive guard placement at top of `RequireMembership.call/2` ALSO short-circuits when `scope.active_organization == nil` for SA — but FetchBearer always populates `active_organization` for SA from `claims["org_id"]`. The bigger risk: putting the SA guard AFTER the `is_nil(scope) or is_nil(scope.active_organization)` clause means an SA without `active_organization` (impossible per FetchBearer contract, but defensive) returns 401 instead of passing through. Either ordering is correct in practice — but the planner must lock one.

**How to avoid:** Plan 93-02: place SA guard as the FIRST `cond` clause (above the nil-scope check) so SA requests bypass all subsequent clauses unconditionally. Add an explicit comment referencing D-93-13.

### Pitfall 6: Audit metadata leaking client_secret

**What goes wrong:** A planner copy-paste of `Sigra.APIToken.do_create/4`'s audit metadata pattern includes the raw token. For SA credentials the equivalent leak would be including `client_secret` in `service_account.credential_create` metadata.

**Why it happens:** D-23 forbidden-keys list catches `password`, `client_secret`, etc. — but only if the metadata Map literally uses those keys. A typo (`client_secret_`, `clientSecret`) would slip through.

**How to avoid:** D-93-21 metadata table is locked: `service_account.credential_create` metadata is `%{service_account_id, credential_id, client_id_prefix, expires_at}` — `client_id_prefix` is just the first ~12 chars (the `sigra_sa_` portion + a few). Plan 93-01 has a metadata sanitization assertion in the unit test. The forbidden-keys defense is in `Sigra.Audit.Changeset` — already enforced.

## Code Examples

### Common Operation 1: Sigra.ServiceAccounts.create/3 (orchestrator skeleton)

```elixir
# Source: NEW lib/sigra/service_accounts.ex — mirrors lib/sigra/organizations.ex:1499 shape
defmodule Sigra.ServiceAccounts do
  @moduledoc """
  Service-account context: org-scoped principals that authenticate API
  calls via OAuth 2.0 client_credentials grant (RFC 6749 §4.4).

  All public functions follow the orchestrator pattern (D-AUD-01):
  the context owns Repo.transaction/Multi/log_multi_safe; schemas
  remain audit-agnostic. See AUDIT-ATOMICITY-DEFAULTS.md.
  """

  alias Ecto.Multi
  alias Sigra.{Audit, Token}

  @spec create(Sigra.Config.t(), map(), map()) ::
          {:ok, struct()} | {:error, Ecto.Changeset.t() | :service_account_aborted}
  def create(config, scope, attrs) when is_map(attrs) do
    schema = fetch_sa_schema!(config)
    organization_id = Map.fetch!(attrs, :organization_id)

    changeset = schema.changeset(struct(schema), Map.put(attrs, :token_epoch, 0))

    multi =
      Multi.new()
      |> Multi.insert(:service_account, changeset)
      |> append_audit(config, "service_account.create", scope,
        target_resolver: fn %{service_account: sa} -> sa.id end,
        organization_id: organization_id,
        metadata: %{name: attrs.name, scopes: attrs[:scopes] || []}
      )

    run_with_aborted_atom(config, multi, "service_account.create", :service_account_aborted)
  end

  # ... revoke/3, create_credential/3, revoke_credential/3, issue_token/3, ...

  defp run_with_aborted_atom(config, multi, action, aborted_atom) do
    try do
      case config.repo.transaction(multi) do
        {:ok, changes} ->
          Audit.emit_telemetry_from_changes(changes)
          {:ok, primary_change(changes)}

        {:error, _step, %Ecto.Changeset{} = cs, _} ->
          {:error, cs}

        {:error, _step, _reason, _} ->
          {:error, aborted_atom}
      end
    rescue
      e ->
        reason = if match?(%Ecto.ConstraintError{}, e), do: :constraint_violation, else: :database_error
        :telemetry.execute([:sigra, :audit, :log_safe_error], %{count: 1},
          %{action: action, reason: reason})
        {:error, aborted_atom}
    end
  end
end
```

### Common Operation 2: OAuth Token Controller skeleton

```elixir
# Source: NEW priv/templates/sigra.install/core/oauth_token_controller.ex
defmodule <%= web_module %>.OAuthTokenController do
  @moduledoc """
  RFC 6749 OAuth 2.0 Token endpoint.

  Currently supports `grant_type=client_credentials` only (Phase 93 / B2B-03).
  Other grant types return `unsupported_grant_type` per RFC 6749 §5.2.
  """
  use <%= web_module %>, :controller

  alias <%= context_module %>, as: Auth

  def create(conn, params) do
    config = Auth.sigra_config()

    with {:ok, client_id, client_secret} <- extract_client_credentials(conn, params),
         "client_credentials" <- params["grant_type"] do
      case Sigra.OAuth.Token.client_credentials(config,
             client_id: client_id,
             client_secret: client_secret,
             scope: params["scope"]
           ) do
        {:ok, %{access_token: jwt, expires_in: ttl, scope: scope}} ->
          conn
          |> put_resp_header("cache-control", "no-store")
          |> put_resp_header("pragma", "no-cache")
          |> put_status(200)
          |> json(%{
            access_token: jwt,
            token_type: "Bearer",
            expires_in: ttl,
            scope: scope
          })

        {:error, :invalid_client} ->
          send_error(conn, 401, "invalid_client", "Client authentication failed.")

        {:error, :invalid_scope} ->
          send_error(conn, 400, "invalid_scope", "Requested scope is not granted to this client.")

        {:error, :service_account_token_issuance_aborted} ->
          send_error(conn, 500, "server_error", "Token issuance could not complete atomically.")
      end
    else
      {:error, :missing_credentials} ->
        send_error(conn, 401, "invalid_client", "Client credentials required.")

      grant when is_binary(grant) ->
        send_error(conn, 400, "unsupported_grant_type",
          "Grant type \"#{grant}\" is not supported. Use \"client_credentials\".")

      _ ->
        send_error(conn, 400, "invalid_request", "Missing or invalid request parameters.")
    end
  end

  defp extract_client_credentials(conn, params) do
    case get_req_header(conn, "authorization") do
      ["Basic " <> b64] ->
        with {:ok, decoded} <- Base.decode64(b64),
             [client_id, client_secret] <- String.split(decoded, ":", parts: 2) do
          {:ok, client_id, client_secret}
        else
          _ -> {:error, :missing_credentials}
        end

      _ ->
        case {params["client_id"], params["client_secret"]} do
          {id, secret} when is_binary(id) and is_binary(secret) -> {:ok, id, secret}
          _ -> {:error, :missing_credentials}
        end
    end
  end

  defp send_error(conn, status, error, description) do
    conn
    |> put_resp_header("cache-control", "no-store")
    |> put_status(status)
    |> json(%{error: error, error_description: description})
  end
end
```

### Common Operation 3: SA Schema Template

```elixir
# Source: NEW priv/templates/sigra.install/organizations/service_account.ex
defmodule <%= context_module %>.ServiceAccount do
  use Ecto.Schema
  import Ecto.Changeset

<%= if binary_id do %>
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
<% end %>
  schema "service_accounts" do
    field :name, :string
    field :scopes, {:array, :string}, default: []
    field :role, :string
    field :token_epoch, :integer, default: 0
    field :revoked_at, :utc_datetime_usec
    field :last_used_at, :utc_datetime_usec

    belongs_to :organization, <%= context_module %>.Organization
    belongs_to :created_by, <%= context_module %>.<%= schema_alias %>,
      foreign_key: :created_by_user_id

    has_many :credentials, <%= context_module %>.ServiceAccountCredential

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(sa, attrs) do
    sa
    |> cast(attrs, [:name, :scopes, :role, :organization_id, :created_by_user_id,
                    :token_epoch, :revoked_at, :last_used_at])
    |> validate_required([:name, :organization_id])
    |> validate_length(:name, min: 1, max: 255)
    |> unique_constraint([:organization_id, :name],
         name: :service_accounts_organization_id_name_index,
         message: "A service account with that name already exists in this organization.")
    |> foreign_key_constraint(:organization_id)
  end
end
```

### Common Operation 4: Postgres-only Migration

```elixir
# Source: NEW priv/templates/sigra.install/organizations/service_accounts_migration.exs
defmodule <%= app_module %>.Repo.Migrations.CreateServiceAccounts do
  use Ecto.Migration

  def change do
    create table(:service_accounts<%= if binary_id do %>, primary_key: false<% end %>) do
<%= if binary_id do %>
      add :id, :binary_id, primary_key: true
<% end %>
      add :organization_id, references(:organizations,<%= if binary_id do %> type: :binary_id,<% end %> on_delete: :delete_all),
        null: false
      add :name, :string, null: false
      add :scopes, {:array, :string}, null: false, default: []
      add :role, :string
      add :token_epoch, :integer, null: false, default: 0
      add :revoked_at, :utc_datetime_usec
      add :last_used_at, :utc_datetime_usec
      add :created_by_user_id, references(:users<%= if binary_id do %>, type: :binary_id<% end %>, on_delete: :nilify_all)

      timestamps(type: :utc_datetime_usec)
    end

    create index(:service_accounts, [:organization_id])
    create unique_index(:service_accounts, [:organization_id, :name])

    create table(:service_account_credentials<%= if binary_id do %>, primary_key: false<% end %>) do
<%= if binary_id do %>
      add :id, :binary_id, primary_key: true
<% end %>
      add :service_account_id, references(:service_accounts,<%= if binary_id do %> type: :binary_id,<% end %> on_delete: :delete_all),
        null: false
      add :client_id, :string, null: false
      add :hashed_client_secret, :string, null: false
      add :expires_at, :utc_datetime_usec
      add :last_used_at, :utc_datetime_usec
      add :revoked_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:service_account_credentials, [:client_id])
    create index(:service_account_credentials, [:service_account_id])
    create index(:service_account_credentials, [:service_account_id],
      where: "revoked_at IS NULL",
      name: :service_account_credentials_active_index)
  end
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Synthetic bot users for M2M (GitLab early model) | Separate principal table (GitHub Apps, Auth0, Okta) | ~2018-2020 industry consolidation | Sigra D-93-01 follows current standard |
| Single-credential PAT for SA | Multi-credential rotation table (AWS IAM, Google Cloud SA, Okta, Auth0 M2M) | ~2017-onward | Sigra D-93-02 ships correct shape from v1 |
| Custom auth scheme on M2M endpoints | RFC 6749 client_credentials | RFC 6749 published 2012; industry conformant since ~2015 | Sigra D-93-03/05 conforms |
| Refresh tokens for M2M | No refresh tokens; re-POST to /oauth/token (RFC 6749 §4.4.3) | Spec since 2012; convention since 2015 | Sigra D-93-07 conforms |
| Per-credential epoch fields | Per-principal epoch + per-credential revoked_at | Current Auth0/Okta pattern | Sigra D-93-12 follows |

**Deprecated/outdated:**
- "Audit verifies on every API request" — D-27 holds; modern best practice is to audit issuance + failures, not successful verifies (massive write volume; observability via telemetry/last_used_at is sufficient).
- Aud claim mandatory for OAuth 2 access tokens — RFC 9068 recommends but doesn't require; D-93-10 leaves to planner discretion (lean: skip for symmetry with existing user JWTs in v1.21).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Brave/Exa/Firecrawl unavailable per init context — verified web research happened during discuss-phase only | tool_strategy | Low — CONTEXT.md already has the research synthesized; planner doesn't need fresh web lookups |
| A2 | The existing partial work in `lib/sigra/jwt.ex` and `lib/sigra/plug/fetch_bearer.ex` is **correct** per CONTEXT.md and should be **kept**, not rewritten. Verified by reading the code against D-93-09/10/11/12 — implementation matches decisions. | Pitfall 1 fix strategy | Low — re-reading both files confirms they implement the locked decisions; rework would be regression risk. Plan 93-02 should add tests proving the existing implementation matches CONTEXT, not reimplement. |
| A3 | `Repo.transact/2` (Ecto 3.13+) is the preferred orchestrator entry point over `Repo.transaction/1` for new code, per `lib/sigra/organizations.ex:1514` precedent | Code Examples | Low — both work; transact returns `{:ok, value} | {:error, value}` flat tuples making `normalize_multi_result` simpler. Planner can choose. |
| A4 | `client_id` byte size of 24 base64url chars after `sigra_sa_` prefix gives ~144 bits entropy — sufficient. | Pitfall 2 config | Low — within industry norms (Stripe restricted keys are 32 chars; Auth0 client IDs are 32). |
| A5 | The recipe filename `m2m-service-accounts.md` is more discoverable than `client-credentials.md` — planner discretion | Code Examples / project structure | Trivial — both are valid; recipe content matters more than filename. |
| A6 | The `/oauth/token` route belongs in **core** router_injection (not organizations) because it represents Sigra's RFC 6749 surface generally; SA happens to be the only grant in v1.21 but `password` / `authorization_code` could land later in core too. | Architecture Diagram | Low — moving the route between injections later is a one-line edit. |

**If this table is empty:** N/A — Phase 93 has 6 minor planner-discretion items, all explicitly delegated by CONTEXT.md.

## Open Questions

1. **Should Plan 93-02 update STATE.md / ROADMAP.md to mark Phase 93 "in progress" before doing any work, or wait until 93-VERIFICATION.md lands?**
   - What we know: STATE.md / ROADMAP.md currently say "complete" / "6/6 plans complete" but no PLAN files exist on disk and library has dangling references.
   - What's unclear: Whether the orchestrator wants the planning-truth surgical edit at the start of 93-01 or as part of 93-06 (verification close).
   - Recommendation: Plan 93-06 already covers "roadmap/requirements canonicalization + 93-VERIFICATION.md" — fold the STATE.md fix into 93-06's surgical-edit pattern. Plan 93-01 starts work without touching planning truth; 93-06 closes the loop. This mirrors Phase 91 D-91-12 maneuver (CONTEXT references it).

2. **For `service_account.token_issued` audit metadata, should `ip_address` be threaded from the controller into the library `issue_token/3` call, or read directly from `Plug.Conn` somewhere?**
   - What we know: D-93-21 specifies `ip_address` in the metadata; library context modules don't accept `Plug.Conn`.
   - What's unclear: Plumbing path — `opts: [ip_address: ...]` keyword from controller vs `Sigra.Audit` having a Plug-aware helper.
   - Recommendation: Plan 93-03 (controller) extracts `conn.remote_ip` (formatted via `:inet.ntoa/1`) and passes as `:ip_address` opt to `Sigra.OAuth.Token.client_credentials/2`, which threads it into the audit metadata. Same pattern as how `Sigra.APIToken.verify/2` accepts ip context.

3. **Are there any existing host adopters who would be broken by adding `service_account_id: nil` to the generated `Scope` `defstruct`?**
   - What we know: `defstruct` additions are backward-compatible in Elixir (existing pattern matches still work); scope template extensions in Phase 92 (`role`, `actor_type`) followed this pattern without breakage.
   - What's unclear: Whether any host has manually customized the scope module to remove fields or use a strict `@enforce_keys`.
   - Recommendation: Document the additive change in CHANGELOG `[Unreleased]` and the v1.21 upgrade guide (per the Phase 93 upgrade migration). Plan 93-05 (recipe + golden install fixture refresh) handles this.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| PostgreSQL 16 (localhost:5432, postgres/postgres) | All Phase 93 tests + atomicity test + generator-host integration | ✓ | 16-alpine via docker (per CLAUDE.md "Local development prerequisites") | None — Phase 94 declares Postgres-only |
| Joken | `Sigra.JWT` SA path | ✓ | optional dep already installed | None — JWT feature requires it |
| Phoenix 1.8 | LiveView templates + controller | ✓ | 1.8.5 | None |
| Ecto 3.13 with `Repo.transact/2` | Orchestrator (preferred) | ✓ | 3.13.5 | Use `Repo.transaction/1` (also works) |
| Elixir 1.18+ | New code | ✓ | per `mix.exs` | None |

**Missing dependencies with no fallback:** None.

**Missing dependencies with fallback:** None — Phase 93 reuses the existing stack entirely.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir built-in) |
| Config file | `test/test_helper.exs` |
| Quick run command | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/service_accounts_test.exs --max-failures 1` |
| Full suite command | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| B2B-03 | SA create lifecycle + atomic audit | unit + atomicity | `mix test test/sigra/service_accounts_test.exs test/sigra/service_accounts_audit_atomicity_test.exs` | Wave 0 (NEW) |
| B2B-03 | JWT issued for SA via `/oauth/token` returns valid JWT | integration | `mix test test/sigra/oauth/token_test.exs` | Wave 0 (NEW) |
| B2B-03 | JWT verify path forks on `actor_type` | unit | `mix test test/sigra/jwt_test.exs` (extend) | Yes (extend) |
| B2B-03 | FetchBearer SA fork builds correct scope | unit | `mix test test/sigra/plug/fetch_bearer_test.exs` (extend) | Yes (extend) |
| B2B-03 | RequireMembership / RequireOrgMfa SA short-circuit | unit | `mix test test/sigra/plug/require_membership_test.exs test/sigra/plug/require_org_mfa_test.exs` (extend) | Yes (extend) |
| B2B-03 | Generator gating on `--organizations` AND `--jwt` | install golden | `mix test test/sigra/install/golden_diff_test.exs` (extend) | Yes (extend) |
| B2B-03 | E2E: mint SA token, call protected endpoint, revoke, assert 401 | integration | `mix test --only integration test/example/test/example_web/integration/service_account_e2e_test.exs` | Wave 0 (NEW) |
| B2B-03 | Audit row exists for create / revoke / token_issued / token_verify.failure | integration | covered by E2E above; assertions on audit_events table | covered |

### Sampling Rate

- **Per task commit:** Quick run for the touched module (e.g., `mix test test/sigra/service_accounts_test.exs --max-failures 1`)
- **Per wave merge:** `mix test test/sigra/service_accounts_test.exs test/sigra/service_accounts_audit_atomicity_test.exs test/sigra/oauth/token_test.exs test/sigra/jwt_test.exs test/sigra/plug/`
- **Phase gate:** Full suite green on Postgres before `/gsd-verify-work`. Plus `mix credo --strict` and `mix dialyzer` clean.

### Wave 0 Gaps

- [ ] `lib/sigra/service_accounts.ex` — REQUIRED to make library compile (Pitfall 1). Initially a stub with `append_token_issued_audit/3` + `commit_verify_failure_audit/3` returning sensible defaults; subsequent waves replace with real impls.
- [ ] `Sigra.Config` `:service_accounts` keyword schema entry + `:client_credentials_access_ttl` jwt sub-key (Pitfall 2)
- [ ] `test/sigra/service_accounts_test.exs` — covers create/revoke/credential lifecycle
- [ ] `test/sigra/service_accounts_audit_atomicity_test.exs` — Postgres + CHECK fault injection (mirrors `test/sigra/jwt_refresh_audit_cofate_test.exs`)
- [ ] `test/sigra/oauth/token_test.exs` — RFC 6749 envelope conformance (success + every error code)
- [ ] `test/example/test/example_web/integration/service_account_e2e_test.exs` — generator-host E2E (per ROADMAP SC #4)
- [ ] No new framework install needed; ExUnit + Postgres already in place per CLAUDE.md

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | RFC 6749 §2.3.1 client password (Basic + form-encoded); SHA-256 hashed `client_secret` at rest; `Plug.Crypto.secure_compare` for constant-time client_secret verification |
| V3 Session Management | partial | JWT TTL 3600s; per-SA `token_epoch` for atomic O(1) revocation; per-credential `revoked_at`; no refresh tokens (RFC §4.4.3) |
| V4 Access Control | yes | `scope.actor_type == :service_account` discrimination; `Sigra.Authz.can?/3` host-owned policy module; scope.role optional for RBAC reuse |
| V5 Input Validation | yes | NimbleOptions for config; Ecto changesets with `validate_required` / `validate_length` / `unique_constraint`; `Sigra.APIToken.ScopeRegistry` for scope format |
| V6 Cryptography | yes | `:crypto.strong_rand_bytes` for client_secret (via `Sigra.Token.generate_hashed_token/0`); SHA-256 for hashing; never hand-roll |
| V7 Error Handling | yes | RFC 6749 §5.2 envelope; never leak whether client_id exists vs client_secret wrong (T2 mitigation); generic `invalid_client` for both |
| V10 Malicious Code | n/a | No code execution surfaces |

### Known Threat Patterns for OAuth 2.0 client_credentials on Phoenix/Ecto

| Threat | STRIDE | Standard Mitigation | Code Hook (where planner adds guard) |
|--------|--------|---------------------|---------------------------------------|
| **T1** Client secret leakage at credential create modal (XSS, accidental logging, DOM persistence) | Information Disclosure | `select-all` + explicit "saved" confirm; modal not dismissible by Esc/backdrop; secret never written to audit metadata or telemetry events | UI-SPEC.md "Credential disclosure modal" section (already locked); audit metadata D-93-21 omits client_secret; ServiceAccount.create returns secret in non-persisted struct field |
| **T2** SA enumeration via timing on `/oauth/token` (different latency for nonexistent client_id vs wrong secret) | Information Disclosure | (a) Always do a constant-time compare on a placeholder hash when client_id not found; (b) Single error atom `:invalid_client` for both branches; (c) Identical HTTP envelope | `Sigra.OAuth.Token.client_credentials/2` — when credential lookup fails, still call `Plug.Crypto.secure_compare` against a precomputed dummy hash before returning `{:error, :invalid_client}` |
| **T3** Revoked-token bypass (post-revoke JWT continues to verify until expiry) | Elevation of Privilege | Per-SA `token_epoch` bump on revoke + epoch claim check on every `verify_access`; per-credential `revoked_at` checked on every verify | `Sigra.JWT.verify_service_account_epoch/2` (EXISTS at lib/sigra/jwt.ex:478) — already implements both checks; planner adds atomicity test for "revoke + immediate next request" assertion |
| **T4** Cross-org privilege escalation via crafted JWT claim (attacker mints claims for org B using SA from org A) | Elevation of Privilege | JWT signature verification (HS256/RS256) + `service_account.organization_id` is loaded from DB on verify, not trusted from claim | `Sigra.Plug.FetchBearer.build_jwt_scope/3` SA clause (EXISTS) — loads org via `claims["org_id"]` but only AFTER signature verify confirms claim integrity; planner test asserts that tampering with `org_id` claim fails signature verify |
| **T5** `client_secret` in audit logs / telemetry / error envelope | Information Disclosure | D-23 forbidden-keys defense (already enforced in `Sigra.Audit.Changeset`); D-93-21 metadata schemas explicitly omit client_secret; `error_description` on `/oauth/token` 401 never echoes credentials | `Sigra.Audit.Changeset` (EXISTS) + `Sigra.OAuth.Token` error envelope (NEW) — planner test asserts `inspect/1` on every audit row never contains the secret |
| **T6** No rate-limiting on `/oauth/token` (credential stuffing) | Denial of Service / Elevation of Privilege | Wire `Sigra.Plug.RateLimit` into the `/oauth/token` pipeline; default 10/min/IP (per existing `:rate_limiting` config) | `priv/templates/sigra.install/core/oauth_token_controller.ex` route — Plan 93-03 adds `:api_throttle` pipeline (or similar) before the controller. CONTEXT did not lock this; planner discretion. **Recommendation:** include in Plan 93-03 because RFC 6749 alone doesn't mandate it but production B2B requires it. |
| **T7** Replay attack on JWT (same JWT used twice across requests) | Spoofing | Standard JWT replay defense relies on `jti` + short TTL; SA tokens are intentionally bearer (anyone holding it can use it); for stronger M2M, RFC 8705 mTLS-bound tokens (deferred per CONTEXT). | None for v1.21 — accepted residual risk; documented in recipe |

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| B2B-03 | Org admin can issue, list, and revoke org-scoped service-account tokens that authenticate API calls via `client_credentials` grant on the existing JWT path, distinguishable in `current_scope` and audit rows from user-tied tokens. | Architecture diagram + Patterns 1-4 + Code Examples 1-4 + Validation Architecture + Threat Model rows T1-T6 |

## Project Constraints (from CLAUDE.md)

The following directives MUST be honored by every plan and execution wave. Violations require explicit user override.

| Constraint | Source | Enforcement Hook |
|------------|--------|------------------|
| Phoenix 1.8+ / Ecto 3.x as blessed path | CLAUDE.md "Constraints" | All new templates target Phoenix 1.8 idioms; LiveView precedents are existing 1.8 templates |
| PostgreSQL primary; MySQL/SQLite via conditional migrations | CLAUDE.md + Phase 94 (Postgres-only) | New migration template is Postgres-only; no `if adapter == :mysql` branches |
| OWASP standards throughout; Argon2id default; HMAC-protected tokens; enumeration prevention by default | CLAUDE.md "Constraints" | T2 mitigation (constant-time compare on missing client_id); SHA-256 hashing of client_secret; D-23 forbidden keys |
| Minimal transitive deps; copy-paste over deps when code is small and stable | CLAUDE.md | Phase 93 adds zero new mix.exs deps |
| LiveView supported but optional; HTTP POST not LV events for login | CLAUDE.md | `/oauth/token` is a plain controller (HTTP POST); LV is admin-only |
| Comprehensive spec coverage — happy path, main error cases, boundary conditions; AAA style, flat, self-contained | CLAUDE.md "Testing" | Validation Architecture lists 7 distinct test files |
| `mix test` requires live Postgres at localhost:5432 with credentials postgres/postgres — no `:postgres` tag exclusion | CLAUDE.md "Local development prerequisites" | All new tests assume Postgres available; no skip-when-no-DB markers |
| GSD workflow enforcement: file-changing tools only after starting through GSD command | CLAUDE.md "GSD Workflow Enforcement" | Plans 93-01..93-06 all run under `/gsd-execute-phase`; this RESEARCH.md is consumed by `/gsd-plan-phase` |
| Library must compile clean against `mix compile --warnings-as-errors` | Implicit (CI hook in Phase 95) | Wave 0 of Plan 93-01 fixes the existing dangling references (Pitfall 1) |
| ExDoc must build clean against `mix docs --warnings-as-errors` | Implicit | Recipe + new module @moduledocs follow precedent |

## Plan Scaffolding Hint (one-paragraph per plan)

Mapping the six already-titled plans to CONTEXT.md decisions, with explicit boundary cuts so plans don't overlap.

### 93-01 — Normalize service-account lifecycle/audit verbs, stable errors, atomicity proof

**Scope:** Build `lib/sigra/service_accounts.ex` from zero. **Wave 0** finishes the existing dangling references (Pitfall 1) so `mix compile` passes — minimum surface: `append_token_issued_audit/3` (called from `Sigra.JWT`) + `commit_verify_failure_audit/3` (called from `Sigra.Plug.FetchBearer`). **Wave 1** adds the public API: `create/3`, `revoke/3`, `create_credential/3`, `revoke_credential/3`, `issue_token/3` — each following the orchestrator pattern (D-AUD-01 / D-93-22). **Wave 2** adds the unit test suite (`test/sigra/service_accounts_test.exs`) and the atomicity test (`test/sigra/service_accounts_audit_atomicity_test.exs`, mirrors Phase 82's `jwt_refresh_audit_cofate_test.exs` shape). **Wave 3** locks the audit verb names (present-tense per D-93-19) and the stable error atoms (`:service_account_aborted` / `:service_account_credential_aborted` per Claude's Discretion). **Out of scope for 93-01:** generator templates, plug guards, controller, LiveView, recipe — those land in 93-02 through 93-05.

### 93-02 — Lock JWT, FetchBearer, membership, org-MFA service-account parity

**Scope:** Confirm and harden the four library plug/JWT integration points. **Step 1:** Audit existing partial code in `lib/sigra/jwt.ex` (`generate_service_account_tokens/3`, `verify_service_account_epoch/2`, `build_service_account_claims/4`) and `lib/sigra/plug/fetch_bearer.ex` (SA fork in `build_jwt_scope/3`, SA failure-audit in `maybe_audit_jwt_failure/3`) against CONTEXT D-93-09/10/11/12. Add unit tests proving conformance. **Step 2:** Add `:service_account_id` field to `Sigra.Scope.build/3`, `from_opts/2`, `from_config/2` (Pitfall 3 lib side). **Step 3:** Add `Sigra.Config` `:service_accounts` NimbleOptions key + `jwt: [client_credentials_access_ttl: ...]` (Pitfall 2). **Step 4:** Add SA short-circuit guards to `Sigra.Plug.RequireMembership.call/2` (D-93-13) and `Sigra.Plug.RequireOrgMfa.call/2` (D-93-14). **Step 5:** Extend `test/sigra/jwt_test.exs`, `test/sigra/plug/fetch_bearer_test.exs`, `test/sigra/plug/require_membership_test.exs`, `test/sigra/plug/require_org_mfa_test.exs` with SA-actor-type cases. **Out of scope:** generator templates, OAuth controller, LiveView.

### 93-03 — Generator gating + direct /oauth/token controller coverage

**Scope:** Generator-side OAuth token surface. **Wave 1:** Add `Sigra.OAuth.Token` library helper (`client_credentials/2` returning the `{:ok, %{access_token, expires_in, scope}}` envelope, mapping internal errors to RFC 6749 §5.2 atoms). **Wave 2:** Create `priv/templates/sigra.install/core/oauth_token_controller.ex` (the controller skeleton from Code Examples §2 above) — both Basic auth and form-encoded credentials per RFC 6749 §2.3.1; explicit `Cache-Control: no-store` per §5.1; success/error envelopes per §5.1/§5.2. **Wave 3:** Extend `Sigra.Install.Features.Core` (or `Features.Organizations`) with the controller emission gated on `opts[:organizations] AND opts[:jwt]` per D-93-18; add the `/oauth/token` route to core router_injection (planner discretion; lean: core). **Wave 4:** Add `test/sigra/oauth/token_test.exs` proving every RFC 6749 §5.2 error code path + Basic auth + form-encoded auth + `Cache-Control: no-store` header + threading `client_credentials` through. **Wave 5:** Wire `Sigra.Plug.RateLimit` into the `/oauth/token` route (T6 mitigation; planner discretion). **Out of scope:** LiveView surface (93-04), recipe (93-05).

### 93-04 — Generated/example service-account UI, sudo, service_account_id scope parity

**Scope:** Generator-side UI surface. **Wave 1:** Schema + migration templates (Code Examples §3 + §4). **Wave 2:** `priv/templates/sigra.install/core/scope.ex` extension — add `service_account_id: nil` to `defstruct`, add `def new(%{} = attrs) when is_map(attrs)` clause (Pitfall 3 host side). **Wave 3:** `priv/templates/sigra.install/organizations/live/organization_service_accounts_live.ex` — implement per UI-SPEC.md verbatim (every visible string locked; LiveView mounts under `:organization_scoped` block; index + detail via `live_action`; modals per UI-SPEC State Inventory; sudo on create + revoke for both SA + credential per D-93-17). **Wave 4:** Extend `priv/templates/sigra.install/organizations/router_injection.ex` with `live "/service-accounts", OrganizationServiceAccountsLive, :index` and `live "/service-accounts/:id", OrganizationServiceAccountsLive, :show` inside the existing `:organization_scoped` `live_session`. **Wave 5:** Extend `Sigra.Install.Features.Organizations.files/1` and `migrations/1` with the new templates, gated on `--jwt` per D-93-18. **Wave 6:** Two LV hooks in `assets/js` of generated host: confirm `DialogModal` exists (it does); add `CopyToClipboard` (NEW per UI-SPEC). **Out of scope:** library context (93-01), library plugs (93-02), controller (93-03), recipe (93-05), upgrade migration (93-05 or 93-06).

### 93-05 — Service-account recipe + golden install fixture refresh

**Scope:** Documentation + adopter onboarding. **Wave 1:** Author `guides/recipes/m2m-service-accounts.md` covering: (a) `mix sigra.install --jwt --organizations` prerequisite, (b) admin LiveView walkthrough with screenshots, (c) `curl` example hitting `/oauth/token` with both Basic auth and form-encoded, (d) host `<App>.SigraAuthz` actor_type branch (extends Phase 92 RBAC recipe), (e) scope-list authorization examples, (f) credential rotation flow. Compile clean against `mix docs --warnings-as-errors`. **Wave 2:** Add an "Authorizing service-account requests" section to `guides/recipes/role-based-access-control.md` (Phase 92 recipe) showing `case scope.actor_type do :user -> ...; :service_account -> ... end` in `MyApp.SigraAuthz.can?/3`. **Wave 3:** Author `priv/templates/sigra.install/sigra.upgrade/alter_add_service_accounts.exs` (idempotent `create_if_not_exists` for both SA tables; structural twin of `priv/templates/sigra.install/sigra.upgrade/alter_add_personal.exs`). **Wave 4:** Refresh the install golden-diff fixture for the new templates; `test/sigra/install/golden_diff_test.exs` extended to cover SA artifacts under `--jwt --organizations` and confirm omission under `--no-jwt` and `--no-organizations`. **Wave 5:** `mix.exs` ExDoc `extras` registration (already covered by `Recipes: ~r{guides/recipes/.?}` per CONTEXT). **Out of scope:** STATE.md / ROADMAP.md surgical edits (93-06).

### 93-06 — Roadmap/requirements canonicalization + 93-VERIFICATION.md

**Scope:** Phase close. **Wave 1:** Surgical edit to ROADMAP.md Phase 93 success criterion #3 wording — `service_account.created` → `service_account.create` and `service_account.revoked` → `service_account.revoke` (D-93-19; mirrors Phase 91 D-91-12 maneuver). **Wave 2:** Surgical edit to STATE.md (Open Question #1 above) reflecting actual completion state once 93-01..93-05 land. **Wave 3:** Surgical edit to REQUIREMENTS.md B2B-03 row + `## Traceability` row marking complete with merge SHA. **Wave 4:** Surgical edit to CHANGELOG.md `[Unreleased]` adding the B2B-03 trace bullet. **Wave 5:** Author `93-VERIFICATION.md` with: (a) full library suite green on Postgres, (b) generator-host integration green, (c) golden-diff stable, (d) JWT path covers both `:user` and `:service_account` actor types, (e) dual-mode auth plug remains single entry point (grep proof: no new `Sigra.Plug.FetchSA*` modules), (f) `mix credo --strict` clean, (g) `mix dialyzer` clean, (h) `mix docs --warnings-as-errors` clean, (i) zero `log_safe/3` debt added (grep proof). **Wave 6:** Run `gsd-sdk` planning-truth refresh.

## Sources

### Primary (HIGH confidence — verified in this research session)

- **`lib/sigra/jwt.ex`** (verified read) — confirms partial Phase 93 implementation already in place: `generate_service_account_tokens/3` (line 120), `verify_service_account_epoch/2` (line 478), `build_service_account_claims/4` (line 428), `verify_epoch/2` SA fork (line 454).
- **`lib/sigra/plug/fetch_bearer.ex`** (verified read) — confirms SA fork in `build_jwt_scope/3` (line 122), `maybe_audit_jwt_failure/3` calls `Sigra.ServiceAccounts.commit_verify_failure_audit/3` (line 188).
- **`lib/sigra/plug/require_membership.ex` + `require_org_mfa.ex`** (verified read) — confirm Phase 91/92 plug shape; SA short-circuit not yet added.
- **`lib/sigra/scope.ex`** (verified read) — confirms `:role` and `:actor_type` accepted but `:service_account_id` NOT yet plumbed.
- **`lib/sigra/organizations.ex` lines 1499-1577** (verified read) — confirms orchestrator-with-aborted-atom pattern for atomic Multi + audit (mirror for SA mutations).
- **`lib/sigra/audit.ex` lines 254-310** (verified read) — confirms `log_multi_safe/3` signature, `:audit_multi_step` keyword, `emit_telemetry_from_changes/2` shape.
- **`lib/sigra/api_token.ex` lines 80-244** (verified read) — confirms `do_create/4` orchestrator pattern + `commit_api_token_verify_failure_audit/2` audit-only Multi pattern (template for SA verify-failure audit).
- **`lib/sigra/install/feature.ex` + `features/organizations.ex`** (verified read) — confirms generator-feature behaviour callbacks and the `enabled?/1` pattern for `--organizations` gating.
- **`lib/sigra/config.ex` lines 1-100** (verified read) — confirms `:service_accounts` keyword absent; planner must add.
- **`priv/templates/sigra.install/core/scope.ex`** (verified read) — confirms scope template `defstruct` carries `:role` + `:actor_type` (Phase 92) but NOT `:service_account_id`; `def new/1` only accepts `%User{}` or `nil` — needs map clause.
- **`priv/templates/sigra.install/core/audit_event.ex` line 29** (verified read) — confirms `actor_type` column already exists with default `"user"` (D-93-19 lock confirmed).
- **`priv/templates/sigra.install/organizations/router_injection.ex`** (verified read) — confirms `:organization_scoped` `live_session` block exists at line 46; route is `/organizations/:org` (UI-SPEC says `:slug` — minor discrepancy planner should resolve).
- **`.planning/phases/93-m2m-service-account-tokens-b2b-03/93-CONTEXT.md`** — 24 locked decisions, all verified present.
- **`.planning/phases/93-m2m-service-account-tokens-b2b-03/93-UI-SPEC.md`** — revision 1, approved, all visible strings locked.
- **`.planning/AUDIT-ATOMICITY-DEFAULTS.md`** D-AUD-01..D-AUD-12 — verified relevant for D-93-22.
- **`.planning/phases/91-org-level-mfa-enforcement-b2b-01/91-CONTEXT.md`** D-91-07 / D-91-12 / D-91-15 — referenced by CONTEXT for SA short-circuit pre-declaration.

### Secondary (MEDIUM confidence — referenced from CONTEXT, not re-verified this session)

- IETF RFC 6749 §4.4 / §2.3.1 / §5.1 / §5.2 — wire shape for `client_credentials` grant; CONTEXT cites verbatim and locks the wire envelope.
- IETF RFC 9068 §2.2 — `sub == client_id` convention (D-93-09).
- Industry M2M defaults: Auth0, Okta, AWS IAM, Google Cloud SA, GitHub Apps installation tokens — all converge on 3600s TTL + multi-credential rotation + issuance audit (D-93-08, D-93-02, D-93-20).

### Tertiary (LOW confidence — not directly verified in this session, no new claims made)

- None — this RESEARCH.md does not introduce new ecosystem claims; CONTEXT.md already did the deep ecosystem research with subagents.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries verified in `mix.lock` / hex.pm; no new deps
- Architecture: HIGH — all integration points verified by reading source code
- Pitfalls: HIGH — Pitfalls 1–5 are direct observations of the partial state on disk; Pitfall 6 is preventive against a known D-23 violation pattern
- Threat model: HIGH for T1-T5 (standard OAuth threats with locked mitigations); MEDIUM for T6 (rate-limiting) since CONTEXT didn't lock it but planner should include

**Research date:** 2026-05-01
**Valid until:** 2026-06-01 (30 days — stable phase; CONTEXT decisions are locked)
