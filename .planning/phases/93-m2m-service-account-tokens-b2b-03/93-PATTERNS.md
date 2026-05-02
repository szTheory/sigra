# Phase 93: M2M / service-account tokens (B2B-03) — Pattern Map

**Mapped:** 2026-05-01
**Files analyzed:** 22 (NEW + MODIFIED + EXTENDED test files)
**Analogs found:** 22 / 22 (zero green-field — every file has a strong codebase precedent)

## File Classification

Working set extracted from 93-CONTEXT.md `### Integration Points` and 93-RESEARCH.md `### Recommended Project Structure`. Status legend: **NEW** = file does not exist; **MODIFIED** = file exists, surgical edit; **EXTENDED** = test file exists, add cases; **PARTIAL** = code already in place per RESEARCH but unreferenced (Pitfall 1).

| Target file | Status | Role | Data Flow | Closest analog | Match |
|-------------|--------|------|-----------|----------------|-------|
| `lib/sigra/service_accounts.ex` | NEW | lib context | CRUD + audit-Multi | `lib/sigra/organizations.ex` | exact (orchestrator twin) |
| `lib/sigra/oauth/token.ex` | NEW | lib helper (RFC 6749 grant logic) | request-response | `lib/sigra/api_token.ex` `do_create/4` | role-match (atomic Multi + audit + token mint) |
| `lib/sigra/jwt.ex` | PARTIAL | jwt minting | request-response | self (already implemented per RESEARCH A2) | exact |
| `lib/sigra/plug/fetch_bearer.ex` | PARTIAL | plug | request-response | self (already implemented per RESEARCH A2) | exact |
| `lib/sigra/plug/require_membership.ex` | MODIFIED | plug | request-response | self (add SA short-circuit cond branch) | exact (D-93-13) |
| `lib/sigra/plug/require_org_mfa.ex` | MODIFIED | plug | request-response | self (add SA short-circuit cond branch) | exact (D-93-14, Phase 91 D-91-07 pre-declared) |
| `lib/sigra/scope.ex` | MODIFIED | lib helper | data carrier | self (additive `:service_account_id` field) | exact (mirrors Phase 92 `:role`/`:actor_type` plumbing) |
| `lib/sigra/config.ex` | MODIFIED | NimbleOptions schema | config | self (mirror `:api_token` keys block) | exact |
| `priv/templates/sigra.install/organizations/service_account.ex` | NEW | schema template | data carrier | `priv/templates/sigra.install/core/user_api_token.ex` + `organizations/organization_membership.ex` | composite (org-scoped FKs from membership; `revoked_at` + `last_used_at` from api_token) |
| `priv/templates/sigra.install/organizations/service_account_credential.ex` | NEW | schema template | data carrier | `priv/templates/sigra.install/core/user_api_token.ex` | exact (`hashed_token` → `hashed_client_secret`, `prefix` → `client_id`) |
| `priv/templates/sigra.install/organizations/service_accounts_migration.exs` | NEW | migration template | DDL | `priv/templates/sigra.install/organizations/migration.exs` (+ `core/api_token_migration.exs`) | exact (org-scoped table shape + `:array, :string` scopes column + revoked-only partial index) |
| `priv/templates/sigra.install/organizations/router_injection.ex` | MODIFIED | router config | request-response | self (add 2 `live` lines into existing `live_session :organization_scoped` block) | exact |
| `priv/templates/sigra.install/organizations/live/organization_service_accounts_live.ex` | NEW | LiveView template | event-driven | `priv/templates/sigra.install/organizations/live/organization_members_live.ex` (structural twin) + `organization_settings_live.ex` (sudo + danger-zone twin) | exact (UI-SPEC §"Structural twin") |
| `priv/templates/sigra.install/core/oauth_token_controller.ex` | NEW | controller template | request-response | `priv/templates/sigra.install/core/api_token_controller.ex` | role-match (JSON envelope + bearer handling pattern; RFC 6749 wire is hand-spec) |
| `priv/templates/sigra.install/core/scope.ex` | MODIFIED | schema template | data carrier | self (additive `service_account_id: nil` + new `def new(%{} = attrs)` clause) | exact |
| `priv/templates/sigra.upgrade/alter_add_service_accounts.exs` | NEW | upgrade migration | DDL | `priv/templates/sigra.upgrade/alter_add_personal.exs` | exact (idempotent `add_if_not_exists`/`create_if_not_exists` shape) |
| `test/sigra/service_accounts_test.exs` | NEW | unit test | CRUD | `test/sigra/api_token_test.exs` (mock-repo pattern) | role-match |
| `test/sigra/service_accounts_audit_atomicity_test.exs` | NEW | integration test (Postgres + CHECK) | atomicity proof | `test/sigra/jwt_refresh_audit_cofate_test.exs` | exact (RESEARCH §"Validation Architecture" cites this as the shape) |
| `test/sigra/oauth/token_test.exs` | NEW | integration test (RFC 6749 envelope) | request-response | `test/sigra/oauth/oauth_test.exs` (Sigra.OAuth orchestrator) + `test/sigra/api_token_test.exs` (token verify wire) | role-match |
| `test/sigra/jwt_test.exs` | EXTENDED | unit test | mint+verify | self (extend with SA actor_type cases) | exact |
| `test/sigra/plug/{require_membership,require_org_mfa,fetch_bearer}_test.exs` | EXTENDED | unit test | plug | self (add SA short-circuit cases) | exact |
| `test/example/test/example_web/integration/service_account_e2e_test.exs` | NEW | E2E integration | full request lifecycle | `test/example/test/example_web/integration/org_mfa_enforcement_test.exs` | exact (only existing org-scoped E2E in the project) |
| `guides/recipes/m2m-service-accounts.md` | NEW | recipe | docs | `guides/recipes/role-based-access-control.md` (Phase 92 — closest in shape; has lib+host+config narrative) | role-match |

## Pattern Assignments

### Library context: `lib/sigra/service_accounts.ex` (NEW)

**Role:** lib context (parallel to `Sigra.Organizations`).
**Data flow:** atomic Multi (CRUD + audit; co-fated rollback; D-AUD-01..D-AUD-08).
**Analog:** `lib/sigra/organizations.ex`.
**Why:** RESEARCH §"Common Operation 1" + CONTEXT canonical-refs explicitly designate `update_organization/4` (line ~504) and `do_set_mfa_policy/4` (line 1499) and `append_audit/5` (line 1568) as the orchestrator template.

**Module scaffolding pattern** (mirrors `lib/sigra/organizations.ex` lines 35–39 alias block + lines 442–464 public-API doc + private orchestrator):

```elixir
# Source pattern: lib/sigra/organizations.ex:35-39 + 442-464 + 1499-1535
require Logger
alias Ecto.Multi
alias Sigra.Audit

# -- Public API --
@spec create(Sigra.Config.t(), map(), map()) :: {:ok, struct()} | {:error, term()}
def create(config, scope, attrs) do
  case scope do
    %{user: %{id: user_id}} when not is_nil(user_id) ->
      do_create(config, scope, attrs, user_id)
    _ ->
      raise ArgumentError, "create/3 requires a scope with a loaded user (got: #{inspect(scope)})"
  end
end
```

**Atomic-Multi orchestrator pattern** (verbatim from `lib/sigra/organizations.ex:1499-1535` `do_set_mfa_policy/4` — the closest in shape because it's a single-row update + audit, exactly the shape `revoke/3`, `create_credential/3`, `revoke_credential/3` need):

```elixir
# Source: lib/sigra/organizations.ex:1499-1535 (verbatim shape; SA equivalent)
defp do_set_mfa_policy(config, scope, org, value) do
  changeset = set_mfa_policy_changeset(org, value)

  if changeset.changes == %{} do
    {:ok, org}
  else
    old_value = Map.get(org, :enforce_mfa_for_members, false)

    result =
      try do
        Multi.new()
        |> Multi.update(:organization, changeset)
        |> append_audit(config, "organization.mfa_policy_change", scope,
          metadata: %{old_value: old_value, new_value: value}
        )
        |> config.repo.transact()
        |> normalize_multi_result_for_mfa_policy()
      rescue
        e ->
          reason = if match?(%Ecto.ConstraintError{}, e), do: :constraint_violation, else: :database_error
          :telemetry.execute([:sigra, :audit, :log_safe_error], %{count: 1},
            %{action: "organization.mfa_policy_change", reason: reason})
          {:error, :mfa_policy_aborted}
      end

    case result do
      {:ok, %{organization: updated}} -> {:ok, updated}
      error -> error
    end
  end
end
```

**Two-step Multi pattern** (for `create/3` which inserts the SA + emits audit row referencing the just-inserted SA's id; mirrors `lib/sigra/organizations.ex:466-496` `do_create_organization/4` verbatim):

```elixir
# Source: lib/sigra/organizations.ex:466-496 — two-step Multi where step 2 references step 1's struct
defp do_create_organization(config, scope, attrs, owner_user_id) do
  org_schema = config.schemas.organization
  membership_schema = config.schemas.membership

  changeset =
    org_schema
    |> build_org_changeset(attrs, config)
    |> Ecto.Changeset.put_change(:owner_user_id, owner_user_id)

  with {:ok, changeset} <-
         run_before_hook(config, :before_create_organization, [changeset, scope]) do
    result =
      Multi.new()
      |> Multi.insert(:organization, changeset)
      |> Multi.insert(:membership, fn %{organization: org} ->
        build_membership_changeset(membership_schema, org, scope.user, config.owner_role)
      end)
      |> append_audit(config, "organization.create", scope)
      |> config.repo.transaction()
      |> normalize_multi_result()

    case result do
      {:ok, %{organization: org}} -> ...
    end
  end
end
```

**`append_audit/5` private helper** (verbatim from `lib/sigra/organizations.ex:1568-1577` — every Phase 93 mutation calls this):

```elixir
# Source: lib/sigra/organizations.ex:1568-1577 — copy verbatim into Sigra.ServiceAccounts
defp append_audit(multi, config, action, scope, extra \\ []) do
  audit_opts = [
    repo: config.repo,
    audit_schema: config[:audit_schema],
    actor_id: get_in_scope(scope, :user, :id),
    metadata: Keyword.get(extra, :metadata, %{})
  ]

  Audit.log_multi_safe(multi, action, audit_opts)
end

defp get_in_scope(scope, :user, :id) do
  case scope do
    %{user: %{id: id}} -> id
    _ -> nil
  end
end
```

**`normalize_multi_result/1` shape** (verbatim from `lib/sigra/organizations.ex:1560-1566`):

```elixir
# Source: lib/sigra/organizations.ex:1560-1566 — universal Multi-result normalizer
defp normalize_multi_result({:ok, changes}), do: {:ok, changes}
defp normalize_multi_result({:error, _step, %Ecto.Changeset{} = cs, _}), do: {:error, cs}
defp normalize_multi_result({:error, _step, reason, _}), do: {:error, reason}
```

**Audit-only Multi pattern** (for `append_token_issued_audit/3` and `commit_verify_failure_audit/3` — the two callbacks already invoked from `lib/sigra/jwt.ex:137` and `lib/sigra/plug/fetch_bearer.ex:188`; mirrors `lib/sigra/api_token.ex:207-244` `commit_api_token_verify_failure_audit/2`):

```elixir
# Source: lib/sigra/api_token.ex:207-244 — audit-only Multi with try/rescue + telemetry on log_safe_error
defp commit_api_token_verify_failure_audit(config, opts) do
  case Keyword.get(opts, :audit_schema) do
    nil -> :ok
    _ ->
      multi =
        Multi.new()
        |> Audit.log_multi_safe(
          "api.token_verify.failure",
          Keyword.put(opts, :audit_multi_step, :audit_api_token_verify_failure)
        )

      try do
        case config.repo.transaction(multi) do
          {:ok, changes} ->
            Audit.emit_telemetry_from_changes(changes, [:audit_api_token_verify_failure])
          {:error, :audit_api_token_verify_failure, %Ecto.Changeset{} = cs, _} ->
            verify_failure_audit_emit_invalid_changeset(cs)
          {:error, failed, reason, _} ->
            raise "unexpected Ecto.Multi failure: #{inspect(failed)} => #{inspect(reason)}"
        end
      rescue
        e ->
          if verify_failure_audit_rescue?(e) do
            :telemetry.execute([:sigra, :audit, :log_safe_error], %{count: 1},
              %{action: "api.token_verify.failure", reason: :constraint_violation})
          else
            reraise(e, __STACKTRACE__)
          end
      end
  end
end
```

---

### Library helper: `lib/sigra/oauth/token.ex` (NEW)

**Role:** lib helper (RFC 6749 grant-logic wrapper called by the generated controller).
**Data flow:** request-response (`client_credentials/2` returns `{:ok, %{access_token, expires_in, scope}}` or `{:error, atom}` mapped to RFC 6749 §5.2 codes).
**Analog:** `lib/sigra/api_token.ex` `do_create/4` (lines 97–145) — same shape: validate inputs → atomic Multi → return token + record.
**Why:** This module is the bridge between the controller and `Sigra.JWT.generate_service_account_tokens/3` + `Sigra.ServiceAccounts.issue_token/3`. The closest existing Sigra module that mints a credential and wraps it in a stable result envelope is `Sigra.APIToken.do_create/4`.

**Wrapping pattern** (mirrors `lib/sigra/api_token.ex:97-145` `do_create/4`):

```elixir
# Source: lib/sigra/api_token.ex:97-145 — validate → Multi → emit telemetry → return envelope
defp do_create(config, user, attrs, prefix) do
  {raw_random, _hash_of_random} = Token.generate_hashed_token()
  raw_key = prefix <> raw_random
  hashed_token = Token.hash_token(raw_key)

  schema = Keyword.fetch!(config.api_token, :api_token_schema)

  changeset =
    schema.changeset(struct(schema), %{
      user_id: user.id, hashed_token: hashed_token, prefix: prefix,
      name: attrs.name, scopes: attrs.scopes, expires_at: Map.get(attrs, :expires_at)
    })

  multi =
    Multi.new()
    |> Multi.insert(:api_token, changeset)
    |> Audit.log_multi_safe("api.token_create", audit_opts)

  case config.repo.transaction(multi) do
    {:ok, %{api_token: token_record} = changes} ->
      Audit.emit_telemetry_from_changes(changes)
      {:ok, raw_key, token_record}
    {:error, :api_token, %Ecto.Changeset{} = cs, _} ->
      {:error, cs}
    {:error, failed, reason, _} ->
      raise "unexpected Ecto.Multi failure from do_create/4: #{inspect(failed)} => #{inspect(reason)}"
  end
end
```

**Constant-time client_secret compare** (T2 mitigation per RESEARCH §"Threat Patterns"; not a direct code analog because Sigra doesn't currently do timing-safe SA lookup — pattern is `Plug.Crypto.secure_compare/2` against a precomputed dummy hash when client_id lookup fails). Reference: `lib/sigra/api_token.ex` already uses `Plug.Crypto.secure_compare` for hashed-token compare; copy that habit.

---

### Existing-but-partial library files (already implement CONTEXT decisions per RESEARCH A2)

Per RESEARCH §"Assumptions Log A2" and §"Common Pitfalls #1", the SA paths in `lib/sigra/jwt.ex` and `lib/sigra/plug/fetch_bearer.ex` are already in place and correct. Plan 93-02 verifies + adds tests; does NOT re-implement. The shape is shown here so the planner / executor can confirm match without re-reading.

#### `lib/sigra/jwt.ex` — `generate_service_account_tokens/3` (lines 113–149)

```elixir
# Source: lib/sigra/jwt.ex:113-149 (verified in place; planner adds tests)
def generate_service_account_tokens(config, service_account, credential) do
  Signer.ensure_joken!()
  jwt_config = config.jwt

  unless Keyword.get(jwt_config, :enabled, false) do
    raise RuntimeError, "JWT support is not enabled. Set jwt: [enabled: true] in config."
  end

  Telemetry.span([:sigra, :jwt, :generate_service_account], %{service_account_id: service_account.id}, fn ->
    signer = Signer.create_signer(config)
    access_ttl = Keyword.get(jwt_config, :client_credentials_access_ttl, 3600)
    now = DateTime.utc_now() |> DateTime.to_unix()

    claims = build_service_account_claims(config, service_account, credential, now, access_ttl)

    multi =
      Multi.new()
      |> ServiceAccounts.append_token_issued_audit(config, service_account, credential)

    case config.repo.transaction(multi) do
      {:ok, changes} ->
        Audit.emit_telemetry_from_changes(changes)
        {:ok, jwt, _full_claims} = Joken.generate_and_sign(%{}, claims, signer)
        {:ok, %{access_token: jwt, refresh_token: nil, expires_in: access_ttl}}
      {:error, _failed, _reason, _changes} = error -> error
    end
  end)
end
```

#### `lib/sigra/jwt.ex` — `build_service_account_claims/4` (lines 428–444)

```elixir
# Source: lib/sigra/jwt.ex:428-444 — already implements D-93-09 (sub == client_id) + D-93-10 (claims set)
defp build_service_account_claims(config, service_account, credential, now, access_ttl) do
  jwt_config = config.jwt

  %{
    "sub" => credential.client_id,                          # D-93-09: sub IS client_id (RFC 9068 §2.2)
    "iat" => now,
    "exp" => now + access_ttl,
    "jti" => Ecto.UUID.generate(),
    "iss" => Keyword.get(jwt_config, :issuer) || to_string(config.otp_app),
    "scopes" => Map.get(service_account, :scopes, []),
    "epoch" => Map.get(service_account, :token_epoch, 0),  # D-93-12: per-SA token_epoch
    "actor_type" => "service_account",                      # D-93-11: scope fork key
    "service_account_id" => service_account.id,
    "credential_id" => credential.id,
    "org_id" => service_account.organization_id
  }
end
```

#### `lib/sigra/jwt.ex` — `verify_service_account_epoch/2` (lines 478–500)

```elixir
# Source: lib/sigra/jwt.ex:478-500 — D-93-12 atomic revocation: SA epoch + per-credential revoked_at
defp verify_service_account_epoch(config, claims) do
  schema = Keyword.get(config.service_accounts, :service_account_schema)
  credential_schema = Keyword.get(config.service_accounts, :service_account_credential_schema)

  with schema when not is_nil(schema) <- schema,
       service_account_id when not is_nil(service_account_id) <- claims["service_account_id"],
       %_{} = service_account <- config.repo.get(schema, service_account_id),
       credential_schema when not is_nil(credential_schema) <- credential_schema,
       credential_id when not is_nil(credential_id) <- claims["credential_id"],
       %_{} = credential <- config.repo.get(credential_schema, credential_id) do
    service_account_epoch = Map.get(service_account, :token_epoch, 0)
    claim_epoch = claims["epoch"] || 0

    if service_account.revoked_at == nil and credential.revoked_at == nil and
         not credential_expired?(credential) and service_account_epoch == claim_epoch do
      {:ok, claims}
    else
      {:error, :epoch_mismatch}
    end
  else
    _ -> {:error, :invalid_token}
  end
end
```

#### `lib/sigra/plug/fetch_bearer.ex` — `build_jwt_scope/3` SA fork (lines 122–145)

```elixir
# Source: lib/sigra/plug/fetch_bearer.ex:122-145 (verified in place; D-93-11 single-fork point)
defp build_jwt_scope(config, scope_module, %{"actor_type" => "service_account"} = claims) do
  service_account_schema = Keyword.get(config.service_accounts, :service_account_schema)

  with schema when not is_nil(schema) <- service_account_schema,
       service_account_id when not is_nil(service_account_id) <- claims["service_account_id"],
       %_{} = service_account <- config.repo.get(schema, service_account_id),
       nil <- service_account.revoked_at,
       %_{} = organization <- load_organization(config, claims["org_id"]) do
    build_scope(scope_module, %{
      user: nil,                        # D-93-04: scope.user = nil (NO synthetic user)
      active_organization: organization,
      membership: nil,                  # D-93-13: SA has no membership row
      impersonating_from: nil,
      role: Map.get(service_account, :role),
      actor_type: :service_account,     # D-93-11 tagged-union key
      service_account_id: service_account.id,
      token_scopes: claims["scopes"],
      auth_method: :jwt,
      token_id: claims["jti"]
    })
  else
    _ -> nil
  end
end
```

---

### Plug short-circuits: `lib/sigra/plug/require_membership.ex` + `lib/sigra/plug/require_org_mfa.ex` (MODIFIED)

**Role:** plug.
**Data flow:** request-response (top-of-`call/2` `cond` clause).
**Analog:** self — both plugs already use a `cond` block in `call/2`; SA short-circuit becomes a NEW first clause.
**Why:** D-93-13 + D-93-14 + RESEARCH §"Pattern 3" + Pitfall #5 lock the placement (FIRST `cond` clause, ahead of the existing nil-scope check).

**`require_membership.ex` `call/2` current shape** (verbatim lines 141–162, ahead of edit):

```elixir
# Source: lib/sigra/plug/require_membership.ex:141-162 — add SA guard as new FIRST cond clause
def call(%Plug.Conn{} = conn, opts) do
  error_handler = Keyword.fetch!(opts, :error_handler)
  required = Keyword.fetch!(opts, :roles)
  scope = conn.assigns[:current_scope]

  cond do
    is_nil(scope) or is_nil(scope.active_organization) ->
      conn
      |> error_handler.auth_error(:no_active_org, opts)
      |> Plug.Conn.halt()

    required != [] and scope.membership.role not in required ->
      error_opts = Keyword.put(opts, :required_roles, required)
      conn
      |> error_handler.auth_error(:insufficient_role, error_opts)
      |> Plug.Conn.halt()

    true -> conn
  end
end
```

**Edit shape** (insert as FIRST `cond` clause per Pitfall #5):

```elixir
cond do
  # NEW Phase 93 D-93-13 short-circuit. SA scope's organization_id is the
  # implicit membership; no OrganizationMembership row lookup. Mirrors
  # Phase 91 D-91-07 pre-declaration for RequireOrgMfa.
  Map.get(scope || %{}, :actor_type) == :service_account ->
    conn

  is_nil(scope) or is_nil(scope.active_organization) ->
    ...
end
```

**`require_org_mfa.ex` `call/2` current shape** (verbatim lines 36–58):

```elixir
# Source: lib/sigra/plug/require_org_mfa.ex:36-58
def call(%Plug.Conn{} = conn, opts) do
  error_handler = Keyword.fetch!(opts, :error_handler)
  mfa_check_fn = Keyword.fetch!(opts, :mfa_check_fn)
  enrollment_path = Keyword.fetch!(opts, :enrollment_path)
  scope = conn.assigns[:current_scope]

  cond do
    is_nil(scope) or is_nil(scope.user) or is_nil(scope.active_organization) ->
      conn

    Map.get(scope.active_organization, :enforce_mfa_for_members, false) == false ->
      conn

    mfa_check_fn.(scope.user) -> conn

    true ->
      conn
      |> put_session(:user_return_to, safe_return_to(current_request_path(conn), scope))
      |> error_handler.auth_error(:org_mfa_required, enrollment_path: enrollment_path)
      |> halt()
  end
end
```

**Edit shape** (RESEARCH §"Pattern 3" example — insert SA guard ahead of the policy check, after the nil-scope guard so the existing `is_nil(scope.user)` clause catches non-SA-and-no-user cases):

```elixir
cond do
  is_nil(scope) or is_nil(scope.user) or is_nil(scope.active_organization) ->
    conn

  # NEW Phase 93 D-93-14 short-circuit (locked from Phase 91 D-91-07).
  # SAs are exempt from member-MFA enforcement — separate actor class.
  Map.get(scope, :actor_type) == :service_account ->
    conn

  Map.get(scope.active_organization, :enforce_mfa_for_members, false) == false ->
    conn
  ...
end
```

---

### Lib `Sigra.Scope`: `lib/sigra/scope.ex` (MODIFIED)

**Role:** lib helper / data-carrier constructor.
**Data flow:** struct construction.
**Analog:** self — Phase 92 already added `:role` and `:actor_type` additively; Phase 93 mirrors that exact plumbing for `:service_account_id`.
**Why:** RESEARCH §"Pitfall 3" lib side; CONTEXT D-93-04 + Integration Points "MODIFIED `Sigra.Scope`".

**Current `build/3` shape** (verbatim lines 40–55) — extend by adding `:service_account_id` to the keyword fetches:

```elixir
# Source: lib/sigra/scope.ex:40-55 — extend with service_account_id (additive)
def build(scope_module, user, opts \\ []) when is_atom(scope_module) and is_list(opts) do
  struct(scope_module,
    user: user,
    active_organization: Keyword.get(opts, :active_organization),
    membership: Keyword.get(opts, :membership),
    impersonating_from: Keyword.get(opts, :impersonating_from),
    # Phase 92 / B2B-02 (Plan 92-03): additive RBAC seam fields.
    role: Keyword.get(opts, :role),
    actor_type: Keyword.get(opts, :actor_type)
    # PHASE 93 ADD: service_account_id: Keyword.get(opts, :service_account_id)
  )
end
```

Same additive edit applies to `from_opts/2` (lines 81–93) and `from_config/2` (lines 108–121).

---

### Config: `lib/sigra/config.ex` (MODIFIED)

**Role:** NimbleOptions schema.
**Analog:** self — `:api_token` keys block (line 41) is the exact shape `:service_accounts` mirrors.
**Why:** RESEARCH §"Pitfall 2" provides the exact NimbleOptions schema fragment to add.

**Existing `:api_token` block shape** (verbatim line 41 — single line in the source, formatted here):

```elixir
# Source: lib/sigra/config.ex:41 — mirror this shape for :service_accounts
api_token: [
  type: :keyword_list, default: [], doc: "API token options.",
  keys: [
    prefix: [type: {:or, [:string, nil]}, default: nil, doc: "Token prefix..."],
    custom_scopes: [type: {:list, :string}, default: [], doc: "Custom scope strings..."],
    api_token_schema: [type: {:or, [:atom, nil]}, default: nil, doc: "The generated UserAPIToken schema module."]
    # ... ~10 more keys
  ]
]
```

**Edit shape** (verbatim from RESEARCH Pitfall 2):

```elixir
service_accounts: [
  type: :keyword_list, default: [],
  doc: "Service-account / M2M token options (Phase 93 / B2B-03).",
  keys: [
    service_account_schema: [type: {:or, [:atom, nil]}, default: nil,
      doc: "The generated host ServiceAccount Ecto schema module."],
    service_account_credential_schema: [type: {:or, [:atom, nil]}, default: nil,
      doc: "The generated host ServiceAccountCredential Ecto schema module."],
    client_id_byte_size: [type: :pos_integer, default: 24,
      doc: "Random bytes in the client_id (after `sigra_sa_` prefix). Default: 24."]
  ]
]

# In the :jwt keys list, add:
client_credentials_access_ttl: [type: :pos_integer, default: 3600,
  doc: "Access token TTL in seconds for client_credentials grant. Default: 3600 (1 hour)."]
```

---

### Schema templates (NEW)

#### `priv/templates/sigra.install/organizations/service_account.ex`

**Role:** schema template.
**Analog (composite):**
- **Org-FK + `belongs_to :organization` shape:** `priv/templates/sigra.install/organizations/organization_membership.ex` lines 31–51.
- **`revoked_at` + `last_used_at` audit columns + `{:array, :string}` scopes:** `priv/templates/sigra.install/core/user_api_token.ex` lines 21–32.

**Why:** No existing template carries BOTH org-scoped FKs AND token-revocation audit columns; the new template is the union of these two shapes.

**Org-membership shape excerpt** (lines 31–51):

```eex
# Source: priv/templates/sigra.install/organizations/organization_membership.ex:31-51
use Ecto.Schema
import Ecto.Changeset
<%= if binary_id do %>
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
<% end %>
schema "organization_memberships" do
  field :role, Sigra.Ecto.Types.RoleAtom

  belongs_to :organization, <%= context_module %>.Organization
  belongs_to :user, <%= context_module %>.<%= schema_alias %>

  timestamps(type: :utc_datetime)
end
```

**Token-revocation columns excerpt** (lines 21–32 of `user_api_token.ex`):

```eex
# Source: priv/templates/sigra.install/core/user_api_token.ex:21-32
schema "user_api_tokens" do
  field :hashed_token, :binary
  field :prefix, :string
  field :name, :string
  field :scopes, {:array, :string}, default: []
  field :last_used_at, :utc_datetime_usec
  field :expires_at, :utc_datetime
  field :revoked_at, :utc_datetime
  field :inserted_at, :utc_datetime_usec

  belongs_to :user, <%= context_module %>.<%= schema_alias %>
end
```

**Composed `service_account.ex` shape** (RESEARCH §"Common Operation 3" — copy verbatim):

```eex
# Source: NEW priv/templates/sigra.install/organizations/service_account.ex (RESEARCH §"Common Operation 3")
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

#### `priv/templates/sigra.install/organizations/service_account_credential.ex`

**Role:** schema template.
**Analog:** `priv/templates/sigra.install/core/user_api_token.ex` lines 1–33.
**Why:** Closest in the codebase — both have a hashed-token column + revoked_at + last_used_at + parent FK. Difference: `hashed_token` becomes `hashed_client_secret`, `prefix` becomes `client_id`, parent FK is `service_account_id` not `user_id`.

**Verbatim source for shape** (lines 21–32 already shown above).

**Composed credential template:**

```eex
defmodule <%= context_module %>.ServiceAccountCredential do
  use Ecto.Schema
  import Ecto.Changeset
<%= if binary_id do %>
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
<% end %>
  schema "service_account_credentials" do
    field :client_id, :string
    field :hashed_client_secret, :string
    field :expires_at, :utc_datetime_usec
    field :last_used_at, :utc_datetime_usec
    field :revoked_at, :utc_datetime_usec

    belongs_to :service_account, <%= context_module %>.ServiceAccount

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(credential, attrs) do
    credential
    |> cast(attrs, [:client_id, :hashed_client_secret, :expires_at,
                    :last_used_at, :revoked_at, :service_account_id])
    |> validate_required([:client_id, :hashed_client_secret, :service_account_id])
    |> unique_constraint(:client_id)
  end
end
```

---

### Migration template: `priv/templates/sigra.install/organizations/service_accounts_migration.exs` (NEW)

**Role:** migration template (Postgres-only post-Phase-94 — no `binary_id` adapter branching beyond what existing org migration uses).
**Analog (composite):**
- **Two-table org-scoped DDL with FKs and indexes:** `priv/templates/sigra.install/organizations/migration.exs` lines 4–51 (creates `organizations` + `organization_memberships`).
- **Token-style columns (`hashed_token`, `revoked_at`, partial unique index on hashed token):** `priv/templates/sigra.install/core/api_token_migration.exs` lines 4–25.

**Org migration two-table shape excerpt** (verbatim lines 4–51 of `migration.exs`):

```eex
# Source: priv/templates/sigra.install/organizations/migration.exs:4-51 — two-table create with org FK
def up do
  create table(:organizations<%= if binary_id do %>, primary_key: false<% end %>) do
<%= if binary_id do %>      add :id, :binary_id, primary_key: true
<% end %>      add :name, :string, null: false, size: 255
    add :slug, :citext, null: false
    add :owner_user_id, references(:<%= table_name %><%= if binary_id do %>, type: :binary_id<% end %>, on_delete: :nilify_all)
    add :enforce_mfa_for_members, :boolean, null: false, default: false
    timestamps(type: :utc_datetime)
  end

  create unique_index(:organizations, [:slug], where: "deleted_at IS NULL", name: :organizations_slug_active_index)

  create table(:organization_memberships<%= if binary_id do %>, primary_key: false<% end %>) do
<%= if binary_id do %>      add :id, :binary_id, primary_key: true
<% end %>      add :role, :string
    add :organization_id, references(:organizations<%= if binary_id do %>, type: :binary_id<% end %>, on_delete: :delete_all), null: false
    add :user_id, references(:<%= table_name %><%= if binary_id do %>, type: :binary_id<% end %>, on_delete: :delete_all), null: false
    timestamps(type: :utc_datetime)
  end

  create unique_index(:organization_memberships, [:user_id, :organization_id])
  create index(:organization_memberships, [:organization_id])
end
```

**API token migration revocation/index pattern** (verbatim lines 4–25 of `api_token_migration.exs`):

```eex
# Source: priv/templates/sigra.install/core/api_token_migration.exs:4-25 — partial-index on revoked_at + token_epoch alter
def up do
  create table(:user_api_tokens, primary_key: false) do
    add :id, :binary_id, primary_key: true
    add :user_id, references(:<%= table_name %>, type: :binary_id, on_delete: :delete_all), null: false
    add :hashed_token, :binary, null: false
    add :scopes, {:array, :string}, default: []
    add :revoked_at, :utc_datetime
    add :inserted_at, :utc_datetime_usec, null: false, default: fragment("now()")
  end

  create unique_index(:user_api_tokens, [:hashed_token])
  create index(:user_api_tokens, [:user_id, :revoked_at, :expires_at])

  alter table(:<%= table_name %>) do
    add_if_not_exists :token_epoch, :integer, default: 0, null: false
  end
end
```

**Composed migration** (RESEARCH §"Common Operation 4" — copy verbatim into the new template):

```eex
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

---

### Upgrade migration template: `priv/templates/sigra.upgrade/alter_add_service_accounts.exs` (NEW)

**Role:** upgrade migration (idempotent for v1.20 → v1.21 adopters).
**Analog:** `priv/templates/sigra.upgrade/alter_add_personal.exs` (35 lines — exact structural twin per CONTEXT canonical-refs).
**Why:** Same idempotency pattern: `add_if_not_exists` + `create_if_not_exists` so re-running a partially-applied migration is safe.

**Source pattern** (verbatim 35 lines):

```elixir
# Source: priv/templates/sigra.upgrade/alter_add_personal.exs:1-35 — copy this idempotency shape
defmodule <%= repo_module %>.Migrations.AddPersonalToOrganizations do
  @moduledoc """
  Phase 18 D-01: add `personal` column + partial unique index ...

  Uses `add_if_not_exists` / `create_if_not_exists` so a re-run on a
  schema that already has the column is a safe no-op.
  """
  use Ecto.Migration

  def up do
    alter table(:organizations) do
      add_if_not_exists :personal, :boolean, null: false, default: false
    end

    create_if_not_exists unique_index(:organizations, [:owner_user_id],
                           where: "personal = true",
                           name: :organizations_personal_owner_uidx
                         )
  end

  def down do
    drop_if_exists index(:organizations, [:owner_user_id],
                     name: :organizations_personal_owner_uidx
                   )
    alter table(:organizations) do
      remove_if_exists :personal, :boolean
    end
  end
end
```

For Phase 93, the upgrade migration wraps the same two `create table` blocks from the install migration above in `create_if_not_exists`, with no `alter` blocks (the tables don't pre-exist).

---

### Scope template: `priv/templates/sigra.install/core/scope.ex` (MODIFIED)

**Role:** schema template (struct + constructors).
**Analog:** self — `defstruct` line 40 already carries the Phase 92 additive fields.
**Why:** RESEARCH §"Pitfall 3" (host side) requires TWO additive edits:
1. Add `service_account_id: nil` to `defstruct`.
2. Add `def new(%{} = attrs) when is_map(attrs)` clause so `Sigra.Plug.FetchBearer.build_jwt_scope/3` SA fork (which passes a map of attrs at line 130) doesn't `FunctionClauseError`.

**Current `defstruct` shape** (verbatim lines 40–45):

```eex
# Source: priv/templates/sigra.install/core/scope.ex:40-45 — extend with service_account_id: nil
defstruct user: nil,
          active_organization: nil,
          membership: nil,
          impersonating_from: nil,
          role: nil,
          actor_type: nil
          # PHASE 93 ADD: service_account_id: nil
```

**Current `def new/1` shape** (verbatim lines 73–77 — needs new `def new(%{} = attrs)` clause):

```eex
# Source: priv/templates/sigra.install/core/scope.ex:73-77 — add map-attrs clause
def new(%<%= schema_alias %>{} = user) do
  %__MODULE__{user: user}
end

def new(nil), do: nil

# PHASE 93 ADD a third clause that accepts the FetchBearer map shape:
# def new(%{} = attrs) when is_map(attrs) do
#   struct(__MODULE__, attrs)
# end
```

---

### LiveView template: `priv/templates/sigra.install/organizations/live/organization_service_accounts_live.ex` (NEW)

**Role:** LiveView template.
**Analog (UI-SPEC-locked):**
- **Structural twin** (`mount/3`, `render/1`, `handle_event/3` line-for-line shape, sidebar entry, action overflow menu, table/load-more pagination): `priv/templates/sigra.install/organizations/live/organization_members_live.ex` lines 1–500. UI-SPEC §"Structural twin" mandates this match.
- **Sudo-ladder twin** (inline `current_password` field, typed-confirm, danger-zone red border): `priv/templates/sigra.install/organizations/live/organization_settings_live.ex` lines 60–223 (esp. lines 161–183 slug-change form with sudo + lines 187–222 danger-zone soft-delete).

**Header + actions pattern from members LV** (verbatim lines 355–378):

```eex
# Source: priv/templates/sigra.install/organizations/live/organization_members_live.ex:355-378
<.header>
  Members ({@total_count})
  <:actions>
    <.button
      :if={can_manage_members?(@current_scope, @invitation_admin_roles)}
      type="button"
      phx-click="open_invite_modal"
      id="invite-member-button"
    >
      Invite member
    </.button>
    <.button
      :if={not can_manage_members?(@current_scope, @invitation_admin_roles)}
      disabled aria-disabled="true"
      title="Only owners and admins can invite members"
    >
      Invite member
    </.button>
  </:actions>
</.header>
```

**Table + overflow-menu pattern** (verbatim lines 380–423):

```eex
# Source: organization_members_live.ex:380-423 — table with action overflow menu
<section id="members-section" class="overflow-x-auto">
  <.table id="members-table" rows={@streams.members}>
    <:col :let={{_dom_id, m}} label="Email">{m.user.email}</:col>
    <:col :let={{_dom_id, m}} label="Role">
      <span class={["badge", role_badge_class(m.role)]}>{humanize_role(m.role)}</span>
    </:col>
    <:col :let={{_dom_id, _m}} label="Status">
      <span class="badge badge-ghost">Active</span>
    </:col>
    <:col :let={{_dom_id, m}} label="Joined">{relative_time(m.inserted_at)}</:col>
    <:action :let={{_dom_id, m}}>
      <details class="dropdown dropdown-end">
        <summary class="btn btn-ghost btn-xs">
          <.icon name="hero-ellipsis-horizontal" class="size-4" />
          <span class="sr-only">Member actions</span>
        </summary>
        <ul class="menu dropdown-content bg-base-100 rounded-box z-10 w-40 p-1 shadow">
          <li><button type="button" phx-click="open_role_modal" phx-value-id={m.id}>Change role</button></li>
          <li><button type="button" class="text-error" phx-click="open_remove_modal" phx-value-id={m.id}>Remove</button></li>
        </ul>
      </details>
    </:action>
  </.table>

  <.button :if={@has_more} phx-click="load_more" class="mt-4">Load more</.button>
</section>
```

**Sudo + typed-confirm danger-zone pattern** (verbatim lines 187–222 of `organization_settings_live.ex`):

```eex
# Source: organization_settings_live.ex:187-222 — sudo-ladder + typed-confirm + red border
<section class="mt-8 rounded-lg border border-error/40 border-l-4 border-l-error bg-base-100 p-6">
  <h2 class="text-lg font-semibold text-error">Danger zone</h2>
  <p class="text-sm mt-1">Soft-delete this organization. Members lose access immediately.</p>

  <%%= if @delete_form_open? do %>
    <.form for={@delete_form} phx-submit="soft_delete" class="mt-4 space-y-3">
      <.input
        field={@delete_form[:password]}
        type="password" label="Current password"
        autocomplete="current-password" required
      />
      <.input
        field={@delete_form[:confirm_name]}
        label={"Type " <> @org.name <> " to confirm"}
        required
      />
      <div class="flex gap-2">
        <.button type="submit" class="btn btn-error" phx-disable-with="Deleting...">
          Delete organization permanently
        </.button>
        <.button type="button" phx-click="close_delete_form" class="btn btn-ghost">Cancel</.button>
      </div>
    </.form>
  <%% else %>
    <.button phx-click="open_delete_form" class="btn btn-error btn-soft mt-4">
      Delete organization
    </.button>
  <%% end %>
</section>
```

**Mount pattern (admin gate + redirect)** (verbatim lines 30–57 of `organization_settings_live.ex`):

```eex
# Source: organization_settings_live.ex:30-57 — mount with role-gate redirect
@impl true
def mount(_params, _session, socket) do
  scope = socket.assigns.current_scope
  org = scope.active_organization

  if can_manage_settings?(scope) do
    socket =
      socket
      |> assign(:page_title, "Organization settings")
      |> assign(:org, org)
      ...
    {:ok, socket}
  else
    {:ok,
     socket
     |> put_flash(:error, "You don't have permission to manage organization settings.")
     |> redirect(to: ~p"/organizations/#{org.slug}/members")}
  end
end
```

**Modal-open with explicit warning** pattern (verbatim lines 161–170 of `organization_settings_live.ex`):

```eex
# Source: organization_settings_live.ex:161-170 — alert-warning-soft pattern (mirrors disclosure modal warning)
<div role="alert" class="alert alert-warning alert-soft">
  <.icon name="hero-exclamation-triangle" class="w-5 h-5" />
  <span>
    Your current slug <code>{@org.slug}</code>
    will redirect to the new slug for 7 days, after which it becomes
    available to other organizations.
  </span>
</div>
```

**UI-SPEC contract** (`93-UI-SPEC.md`, revision 1, approved): every visible string, color class, spacing token, accessibility lock, and modal state is locked. Executor renders verbatim from UI-SPEC; this PATTERNS.md provides the structural code shape, UI-SPEC provides the copy + visuals.

---

### Controller template: `priv/templates/sigra.install/core/oauth_token_controller.ex` (NEW)

**Role:** controller template.
**Analog:** `priv/templates/sigra.install/core/api_token_controller.ex` (154 lines).
**Why:** Same module-level shape (`use <%= web_module %>, :controller`, `alias <%= context_module %>, as: Auth`, `Auth.sigra_config()` access, JSON envelopes via `json/2` + `put_status/2`); difference is the wire shape — RFC 6749 §5.1/§5.2 envelope replaces the Sigra-shaped one.

**Module-shell pattern** (verbatim lines 1–22):

```eex
# Source: priv/templates/sigra.install/core/api_token_controller.ex:1-22 — controller shell shape
defmodule <%= web_module %>.APITokenController do
  @moduledoc """
  JSON API controller for managing personal access tokens.

  Provides CRUD endpoints for API token management:
    - `GET /api/tokens` -- list active tokens (paginated)
    - `POST /api/tokens` -- create a new token (returns raw key once)
    ...

  All endpoints require bearer authentication with `api_tokens:read` or
  `api_tokens:write` scopes. Token creation requires sudo mode.

  Generated by `mix sigra.install --api`. Customize freely -- this
  module is owned by your application.
  """

  use <%= web_module %>, :controller

  alias <%= context_module %>, as: Auth
```

**JSON-error helper pattern** (verbatim lines 107–111):

```eex
# Source: api_token_controller.ex:107-111 — error envelope shape (replace per RFC 6749 §5.2)
defp impersonation_forbidden(conn, message \\ @impersonation_denial_message) do
  conn
  |> put_status(:forbidden)
  |> json(%{error: "impersonation_forbidden", message: message})
end
```

**Composed `oauth_token_controller.ex`** (RESEARCH §"Common Operation 2" — copy verbatim into the new template, including the RFC 6749 §2.3.1 dual auth-mechanism extraction):

```eex
# Source: NEW priv/templates/sigra.install/core/oauth_token_controller.ex (RESEARCH §"Common Operation 2")
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
          |> json(%{access_token: jwt, token_type: "Bearer", expires_in: ttl, scope: scope})

        {:error, :invalid_client} ->
          send_error(conn, 401, "invalid_client", "Client authentication failed.")

        {:error, :invalid_scope} ->
          send_error(conn, 400, "invalid_scope", "Requested scope is not granted to this client.")
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

---

### Router injection: `priv/templates/sigra.install/organizations/router_injection.ex` (MODIFIED)

**Role:** router config.
**Analog:** self — `live_session :organization_scoped` block (lines 46–55) already mounts `OrganizationMembersLive` and `OrganizationSettingsLive`; Phase 93 adds two `live` lines.
**Why:** UI-SPEC §"Structural twin" mandates the SA LV mounts inside the existing block to inherit the `:org_scoped` pipeline (RequireMembership, RequireOrgMfa, OrganizationScope on_mount).

**Current `:organization_scoped` block** (verbatim lines 46–55):

```eex
# Source: priv/templates/sigra.install/organizations/router_injection.ex:46-55
live_session :organization_scoped,
  on_mount: [
    {<%= web_module %>.UserAuth, :ensure_authenticated},
    {<%= web_module %>.UserAuth, :assign_user_organizations},
    {Sigra.LiveView.OrganizationScope, []},
    {Sigra.LiveView.RequireOrgMfa, [mfa_check_fn: &<%= app_module %>.Accounts.mfa_enabled?/1]}
  ] do
  live "/settings", OrganizationSettingsLive, :edit
  live "/members", OrganizationMembersLive, :index
  # PHASE 93 ADD:
  # live "/service-accounts", OrganizationServiceAccountsLive, :index
  # live "/service-accounts/:id", OrganizationServiceAccountsLive, :show
end
```

**Core router_injection** (separate file, not shown above) needs the `/oauth/token` POST route added at the same time. Per CONTEXT D-93-05 + RESEARCH A6, this lives in **core router_injection** (the route is Sigra's RFC 6749 surface generally, not org-specific). Authenticates via `client_id`+`client_secret` so requires NO bearer auth pipeline.

---

### Test analogs (NEW + EXTENDED)

#### `test/sigra/service_accounts_test.exs` (NEW unit test)

**Role:** unit test (mock-repo).
**Analog:** `test/sigra/api_token_test.exs` lines 1–60 (mock schema + mock repo + multi simulator).
**Why:** Closest pattern in the codebase for testing a context module that owns an atomic Multi without a live DB.

**Mock-schema + mock-repo pattern** (verbatim lines 1–60):

```elixir
# Source: test/sigra/api_token_test.exs:1-60 — mock schema + mock repo for unit tests
defmodule Sigra.APITokenTest do
  use ExUnit.Case, async: true
  alias Sigra.APIToken

  defmodule MockAPITokenSchema do
    use Ecto.Schema

    schema "user_api_tokens" do
      field :user_id, :integer
      field :hashed_token, :binary
      field :name, :string
      field :scopes, {:array, :string}
      timestamps()
    end

    def changeset(struct, attrs) do
      struct
      |> Ecto.Changeset.cast(attrs, [:user_id, :hashed_token, :name, :scopes])
      |> Ecto.Changeset.validate_required([:user_id, :hashed_token, :name, :scopes])
    end
  end

  defmodule MockRepo do
    @behaviour Sigra.APITokenTest.RepoBehaviour
    def insert(changeset, _opts) do
      if changeset.valid? do
        token = Ecto.Changeset.apply_changes(changeset)
        {:ok, Map.put(token, :id, System.unique_integer([:positive]))}
      else
        {:error, changeset}
      end
    end

    def transaction(%Ecto.Multi{} = multi) do
      ...
    end
  end
end
```

#### `test/sigra/service_accounts_audit_atomicity_test.exs` (NEW Postgres + CHECK fault injection)

**Role:** integration test (Postgres CHECK-guard fault injection proves co-fated rollback).
**Analog:** `test/sigra/jwt_refresh_audit_cofate_test.exs` lines 1–280 (RESEARCH explicitly cites this as the shape; it's the established Sigra atomicity-proof pattern).
**Why:** This is the canonical Sigra atomicity-proof shape (mirrors Phase 82's contribution). Same setup (PostgresRepo + uuid-ossp + DROP/CREATE tables + audit_events table + telemetry handler), same CHECK-guard pattern (`ALTER TABLE audit_events ADD CONSTRAINT ... CHECK (action <> '...')`), same assertion: under the guard, the SA mutation must return `{:error, :service_account_aborted}` AND the SA-table row count must equal `before_*` (rollback proof).

**CHECK-guard fault-injection pattern** (verbatim lines 216–261):

```elixir
# Source: test/sigra/jwt_refresh_audit_cofate_test.exs:216-261 — CHECK-guard atomicity proof
test "happy path fault injection: audit CHECK rejects api.jwt_refresh → jwt_refresh_aborted, no partial rotation",
     %{repo: repo} do
  Ecto.Adapters.SQL.query!(
    repo,
    """
    ALTER TABLE audit_events
    ADD CONSTRAINT jwt_refresh_cofate_happy_guard CHECK (action <> 'api.jwt_refresh')
    """,
    []
  )

  try do
    user = insert_user!(repo)
    cfg = sigra_config(repo)
    opts = token_opts()
    {raw_refresh, _} = RefreshToken.create(cfg, user, ["profile:read"], opts)

    before_tokens = count(repo, "jwt_refresh_cofate_user_tokens")

    ref =
      :telemetry.attach({__MODULE__, :jwt_cofate_happy_guard},
        [:sigra, :audit, :log_safe_error],
        &VerifyFailureTelemetryHandler.handle_event/4, self())

    try do
      assert {:error, :jwt_refresh_aborted} = JWT.refresh(cfg, raw_refresh, opts)

      assert_receive {:telemetry, [:sigra, :audit, :log_safe_error], %{count: 1},
                      %{action: "api.jwt_refresh", reason: :constraint_violation}}
    after
      :telemetry.detach(ref)
    end

    assert count(repo, "jwt_refresh_cofate_user_tokens") == before_tokens
    assert count_where(repo, "audit_events", "action = 'api.jwt_refresh'") == 0
  after
    Ecto.Adapters.SQL.query!(repo,
      "ALTER TABLE audit_events DROP CONSTRAINT IF EXISTS jwt_refresh_cofate_happy_guard", [])
  end
end
```

**setup pattern with PostgresRepo + DROP/CREATE** (verbatim lines 51–129):

```elixir
# Source: test/sigra/jwt_refresh_audit_cofate_test.exs:51-129 — PostgresRepo setup + uuid-ossp + audit_events table
setup do
  start_supervised!({PostgresRepo, PostgresRepo.default_config()})
  repo = PostgresRepo

  Ecto.Adapters.SQL.query!(repo, "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"", [])

  for t <- ["service_account_credentials", "service_accounts"] do  # adapt to phase
    Ecto.Adapters.SQL.query!(repo, "DROP TABLE IF EXISTS #{t} CASCADE", [])
  end

  # CREATE TABLE service_accounts ...
  # CREATE TABLE service_account_credentials ...

  Ecto.Adapters.SQL.query!(repo, """
    CREATE TABLE IF NOT EXISTS audit_events (
      id uuid PRIMARY KEY,
      occurred_at timestamp NOT NULL DEFAULT now(),
      action varchar(255) NOT NULL,
      outcome varchar(32) NOT NULL DEFAULT 'success',
      actor_id uuid,
      actor_type varchar(64) NOT NULL DEFAULT 'user',
      ...
    )
    """, [])

  Ecto.Adapters.SQL.query!(repo, "TRUNCATE TABLE audit_events RESTART IDENTITY CASCADE", [])

  %{repo: repo}
end
```

#### `test/sigra/oauth/token_test.exs` (NEW RFC 6749 envelope conformance)

**Role:** integration test (controller + lib `Sigra.OAuth.Token` end-to-end).
**Analog:** `test/sigra/oauth/oauth_test.exs` (Sigra.OAuth orchestrator unit pattern) + `test/sigra/api_token_test.exs` (Plug-conn-builder pattern). Plus `test/example/test/example_web/oauth_controller_test.exs` for the conn pattern.
**Why:** No existing Sigra test covers an `application/x-www-form-urlencoded` POST that returns an RFC 6749 JSON envelope. Closest analogs cover OAuth callback wire shape (oauth_test.exs) and bearer extraction (fetch_bearer_test.exs). Test must hand-build the conn with `put_req_header("content-type", "application/x-www-form-urlencoded")` and assert `Cache-Control: no-store` per §5.1, then assert each error code path per §5.2.

#### `test/sigra/jwt_test.exs` + `test/sigra/plug/{require_membership,require_org_mfa,fetch_bearer}_test.exs` (EXTENDED)

**Role:** unit test extensions (add SA actor_type cases).
**Analog:** self (existing test files; add SA-flavored describe blocks).
**Pattern:** the existing `test/sigra/plug/fetch_bearer_test.exs` (verified lines 1–46) uses an in-process `defmodule TestScope do def new(data), do: data end` — same pattern works for SA scope assertions.

```elixir
# Source: test/sigra/plug/fetch_bearer_test.exs:1-46 — in-process TestScope and Plug.Test conn pattern
defmodule Sigra.Plug.FetchBearerTest do
  use ExUnit.Case, async: true
  import Plug.Test
  alias Sigra.Plug.FetchBearer

  defmodule TestScope do
    @moduledoc false
    def new(data), do: data
  end

  defp test_config(overrides \\ []) do
    %Sigra.Config{
      repo: Sigra.TestRepo,
      user_schema: Sigra.TestUser,
      otp_app: :test_app,
      secret_key_base: String.duplicate("a", 64),
      api_token: Keyword.get(overrides, :api_token, prefix: "test_app_sk_", api_token_schema: Sigra.TestAPIToken),
      jwt: Keyword.get(overrides, :jwt, enabled: false)
    }
  end
end
```

#### `test/example/test/example_web/integration/service_account_e2e_test.exs` (NEW E2E)

**Role:** generator-host E2E integration test.
**Analog:** `test/example/test/example_web/integration/org_mfa_enforcement_test.exs` (103 lines — only existing org-scoped E2E in the project; verified lines 1–103).
**Why:** Mirrors the established generator-host integration shape: `use ExampleWeb.ConnCase, async: false`, `Repo` + schema aliases, `log_in_user(conn, user)` helper, `live(conn, ~p"...")` for LV interaction, direct `Repo.all(from a in AuditEvent, ...)` for audit assertion, `redirected_to(conn) == "..."` for plug-halt assertion.

**Setup + audit-row assertion pattern** (verbatim lines 1–80 of `org_mfa_enforcement_test.exs`):

```elixir
# Source: test/example/test/example_web/integration/org_mfa_enforcement_test.exs:1-80 — E2E shape
defmodule ExampleWeb.OrgMfaEnforcementTest do
  use ExampleWeb.ConnCase, async: false

  import Ecto.Query
  import Phoenix.LiveViewTest

  alias Example.Accounts.{AuditEvent, Organization, OrganizationMembership}
  alias Example.Repo

  defp create_org!(user, role, attrs) do
    {:ok, org} =
      %Organization{}
      |> Organization.changeset(Map.merge(%{name: "Org #{n}", slug: "org-#{n}"}, attrs))
      |> Repo.insert()
    {:ok, _} = %OrganizationMembership{} |> OrganizationMembership.changeset(...) |> Repo.insert()
    org
  end

  test "admin enables policy and enforcement applies per organization", %{conn: conn} do
    %{user: admin} = Example.AccountsFixtures.mfa_user_fixture()
    enforced_org = create_org!(admin, :admin, %{name: "Enforced Org", slug: "enforced-org"})
    admin_conn = log_in_user(conn, admin)

    {:ok, lv, _html} = live(admin_conn, ~p"/organizations/#{enforced_org.slug}/settings")

    lv |> element("input[phx-click=toggle_mfa_policy]") |> render_click()
    lv |> element("form[phx-submit=save_mfa_policy]") |> render_submit()

    assert Repo.reload!(enforced_org).enforce_mfa_for_members == true

    audit_rows =
      Repo.all(
        from(a in AuditEvent,
          where: a.action == "organization.mfa_policy_change",
          order_by: [asc: a.inserted_at])
      )

    assert [%AuditEvent{} = audit] = audit_rows
    assert audit.actor_id == admin.id
    assert audit.metadata["new_value"] == true

    blocked_conn =
      build_conn() |> log_in_user(member) |> get(~p"/organizations/#{enforced_org.slug}/members")

    assert redirected_to(blocked_conn) == "/users/settings/mfa"
  end
end
```

**SA-specific E2E shape** (extension — no analog yet; the new test sits at this exact path and follows the same shape, but adds a `Plug.Conn.put_req_header("authorization", "Bearer #{jwt}")` step after minting the SA token via `/oauth/token`):

```elixir
# NEW shape, modeled on org_mfa_enforcement_test.exs above
test "SA E2E: mint via /oauth/token, call protected endpoint, revoke SA, next call fails 401" do
  admin_conn = log_in_user(conn, admin)
  {:ok, lv, _} = live(admin_conn, ~p"/organizations/#{org.slug}/service-accounts")
  # ... create SA via LV form, capture client_id+client_secret from disclosure modal assigns ...

  # Exchange for JWT via RFC 6749 client_credentials grant
  token_conn =
    build_conn()
    |> put_req_header("content-type", "application/x-www-form-urlencoded")
    |> put_req_header("authorization", "Basic " <> Base.encode64("#{client_id}:#{client_secret}"))
    |> post(~p"/oauth/token", "grant_type=client_credentials")

  assert %{"access_token" => jwt, "token_type" => "Bearer"} = json_response(token_conn, 200)

  # Call protected endpoint with the SA JWT
  api_conn = build_conn() |> put_req_header("authorization", "Bearer #{jwt}") |> get(~p"/api/protected")
  assert json_response(api_conn, 200)

  # Revoke SA via LV, verify next call 401s
  lv |> element("button[phx-click=open_revoke_sa_modal]") |> render_click()
  lv |> element("form[phx-submit=revoke_sa]") |> render_submit()
  api_conn2 = build_conn() |> put_req_header("authorization", "Bearer #{jwt}") |> get(~p"/api/protected")
  assert json_response(api_conn2, 401)

  # Audit row assertions
  audit_rows = Repo.all(from a in AuditEvent, where: a.action in [
    "service_account.create", "service_account.revoke",
    "service_account.token_issued", "api.token_verify.failure"
  ])
  assert length(audit_rows) >= 4
  assert Enum.any?(audit_rows, &(&1.actor_type == "service_account"))
end
```

---

### Recipe: `guides/recipes/m2m-service-accounts.md` (NEW)

**Role:** recipe (markdown; ExDoc-registered via `mix.exs` `Recipes: ~r{guides/recipes/.?}`).
**Analog:** `guides/recipes/role-based-access-control.md` (Phase 92 — 252 lines; closest in shape because it covers a lib-feature + host-app hook + config narrative, exactly the SA shape).
**Why:** RBAC recipe is Phase 92's deliverable; Phase 93 extends Phase 92's `MyApp.SigraAuthz.can?/3` actor_type branch (CONTEXT D-93-15 explicitly references this).

**Recipe section pattern** (verbatim sections from `role-based-access-control.md`):

```markdown
# Source: guides/recipes/role-based-access-control.md — section structure to mirror
# Role-Based Access Control                       <- top-level title

## What Sigra ships                                <- "moving parts" inventory
## The generated allow-all starter                 <- code block of generated stub
## Replace the starter with deny-by-default        <- worked example
## Calling can?/3 from controllers and LiveViews   <- usage examples
## How the scope role gets populated               <- internals trace
## Testing your policy                             <- test recipe
## Customizing the role taxonomy                   <- extension point
## Role-gated router pipelines (optional)          <- advanced usage
## What can?/3 should NOT decide                   <- anti-patterns
## Related                                         <- crosslinks
```

**M2M recipe outline** (RESEARCH §"Plan Scaffolding Hint 93-05" — sections to author):

1. Prerequisite: `mix sigra.install --jwt --organizations`
2. Admin LiveView walkthrough (with screenshot reference; no actual screenshots in v1.21)
3. RFC 6749 `POST /oauth/token` `curl` example with both Basic auth and form-encoded
4. Host `<App>.SigraAuthz` actor_type branch (extends Phase 92 RBAC recipe pattern at lines 47–78)
5. Scope-list authorization examples
6. Credential rotation flow

**Phase 92 recipe extension** — the existing `guides/recipes/role-based-access-control.md` gets a NEW "## Authorizing service-account requests" section. The pattern to insert mirrors the existing `def can?/3` clause pattern (verbatim lines 47–78 source):

```markdown
# Source: role-based-access-control.md:47-78 — pattern to extend with SA actor_type branch

    defmodule MyApp.SigraAuthz do
      @behaviour Sigra.Authz

      # Phase 93 ADDITION: service-account branch
      def can?(action, subject, %{actor_type: :service_account, role: role} = scope) do
        # ... SA-specific rules; e.g. CI bots can :deploy, audit bots can :read ...
      end

      # Phase 92 user branches stay below
      def can?(:read, _subject, %{role: role}) when role in [:owner, :admin, :member], do: true
      def can?({:manage, :members}, _subject, %{role: role}) when role in [:owner, :admin], do: true
      ...
      def can?(_action, _subject, _scope), do: false
    end
```

---

## Shared Patterns

These cross-cutting patterns apply to multiple Phase 93 files. Each plan's action section should reference the source line range below.

### Atomic Multi + audit (D-AUD-01..D-AUD-08)

**Source:** `lib/sigra/organizations.ex:1499-1535` (`do_set_mfa_policy/4`) + `:1568-1577` (`append_audit/5`) + `:1560-1566` (`normalize_multi_result/1`).

**Apply to:**
- `Sigra.ServiceAccounts.create/3`, `revoke/3`, `create_credential/3`, `revoke_credential/3`, `issue_token/3`
- `Sigra.OAuth.Token.client_credentials/2` (wraps `issue_token/3`)
- The five new audit verbs from D-93-19

**Excerpt** already shown in §"Library context" above.

### Audit-only Multi for failure paths

**Source:** `lib/sigra/api_token.ex:207-244` (`commit_api_token_verify_failure_audit/2`).

**Apply to:**
- `Sigra.ServiceAccounts.commit_verify_failure_audit/3` (called from FetchBearer line 188)
- Any future audit-only path (`api.token_verify.failure` SA writes)

**Excerpt** already shown in §"Library context" above.

### `Sigra.Audit.log_multi_safe/3` — uniform audit composer

**Source:** `lib/sigra/audit.ex:254-273`. Called from EVERY audit Multi step in the codebase (verified: organizations, api_token, jwt, oauth, mfa, impersonation, account, passkeys all use it).

```elixir
# Source: lib/sigra/audit.ex:254-273 — universal audit-step composer
@spec log_multi_safe(Ecto.Multi.t(), String.t(), opts()) :: Ecto.Multi.t()
def log_multi_safe(%Ecto.Multi{} = multi, action, opts)
    when is_binary(action) and is_list(opts) do
  case Keyword.get(opts, :audit_schema) do
    nil -> multi   # No audit configured → no-op insert
    _ -> do_log_multi(multi, action, opts, true)
  end
end

defp do_log_multi(multi, action, opts, allow_reserved?) do
  audit_schema = Keyword.fetch!(opts, :audit_schema)
  resolver = Keyword.get(opts, :actor_resolver)
  cs_opts = changeset_opts(opts, allow_reserved?)
  step = Keyword.get(opts, :audit_multi_step, :audit)

  Ecto.Multi.insert(multi, step, fn changes ->
    attrs = build_attrs(action, opts, resolver, changes)
    Changeset.changeset(struct(audit_schema), attrs, cs_opts)
  end)
end
```

**Apply to:** every Multi step that emits an audit row in Phase 93. Use `:audit_multi_step` named-step keyword when the same Multi could carry multiple audit rows (e.g., `service_account.token_issued` keyed `:audit_sa_token_issued`).

### `Sigra.Token.generate_hashed_token/0` + `Sigra.Token.hash_token/1`

**Source:** `lib/sigra/api_token.ex:97-100` `do_create/4` lines 97–100.

```elixir
# Source: lib/sigra/api_token.ex:97-100 — token generation + hashing primitives (REUSE for client_secret)
defp do_create(config, user, attrs, prefix) do
  {raw_random, _hash_of_random} = Token.generate_hashed_token()
  raw_key = prefix <> raw_random
  hashed_token = Token.hash_token(raw_key)
  ...
end
```

**Apply to:** `client_secret` generation in `Sigra.ServiceAccounts.create_credential/3`. The `prefix` for SA is `"sigra_sa_"` per D-93-03; `raw_random` byte count from `:client_id_byte_size` config (default 24 — see §"Config" above). Use `Plug.Crypto.secure_compare/2` (the codebase already does, in `Sigra.APIToken.verify`) for client_secret comparison.

### Telemetry on log-safe-error (audit failure observability)

**Source:** `lib/sigra/organizations.ex:1521-1525` + `lib/sigra/api_token.ex:235-239`.

```elixir
# Source: lib/sigra/organizations.ex:1521-1525 — emit telemetry when audit insert fails (D-AUD-08)
:telemetry.execute(
  [:sigra, :audit, :log_safe_error],
  %{count: 1},
  %{action: "<action_name>", reason: :constraint_violation}
)
```

**Apply to:** every `try/rescue` block in Phase 93 SA mutations + the audit-only verify-failure path. The atomicity test (`service_accounts_audit_atomicity_test.exs`) attaches a telemetry handler and asserts on this event under CHECK-guard fault injection.

### Phoenix 1.8 LiveView modal + sudo-form pattern

**Source:** `priv/templates/sigra.install/organizations/live/organization_settings_live.ex:187-222` (danger-zone with sudo + typed-confirm) + `priv/templates/sigra.install/organizations/live/organization_members_live.ex:469-559` (modal + inline-error pattern).

**Apply to:** every modal in `OrganizationServiceAccountsLive` per UI-SPEC State Inventory (Create SA, Create credential, Disclosure, Revoke SA, Revoke credential).

### Generator-feature gating (`--organizations` AND `--jwt`)

**Source:** `lib/sigra/install/feature.ex` + `lib/sigra/install/features/organizations.ex` (`enabled?/1` callback).

**Apply to:** `Sigra.Install.Features.Organizations.files/1` and `migrations/1` extension to emit SA artifacts only when `opts[:organizations]` AND `opts[:jwt]` are both truthy per D-93-18.

---

## No Analog Found

**Empty list** — every Phase 93 file maps to at least one strong existing analog:

- `lib/sigra/oauth/token.ex` (the RFC 6749 grant-logic helper) is the only file where the wire shape itself (form-encoded body, `Authorization: Basic`, `Cache-Control: no-store`, RFC 6749 §5.1/§5.2 envelope) has no Sigra precedent — but the WRAPPING code (validate inputs → atomic Multi → return envelope → map errors to atoms) is `Sigra.APIToken.do_create/4` shape, and the wire spec itself is documented verbatim in CONTEXT canonical-refs (RFC 6749 §4.4 / §2.3.1 / §5.1 / §5.2). Per RESEARCH §"Don't Hand-Roll": "Hand-write per RFC 6749 §5.1 / §5.2 spec verbatim — there is no Elixir lib that ships an RFC 6749 server controller for a third-party stack."

---

## Reuse Map — what each new file calls into

This table reverses the analysis: for each NEW or MODIFIED Phase 93 file, list the existing modules / functions it calls. Lets the planner verify "no new primitive snuck in" and lets the executor pick the right alias block.

| New/Modified file | Reuses (existing) |
|-------------------|-------------------|
| `Sigra.ServiceAccounts.create/3` | `Ecto.Multi.new/0`, `Multi.insert/3`, `Sigra.Audit.log_multi_safe/3`, `Sigra.Audit.emit_telemetry_from_changes/2`, `:telemetry.execute/3` |
| `Sigra.ServiceAccounts.revoke/3` | `Ecto.Multi`, `Sigra.Audit.log_multi_safe/3`, `Ecto.Changeset.change/2` (set `revoked_at` + bump `token_epoch` in one Multi per D-93-12) |
| `Sigra.ServiceAccounts.create_credential/3` | `Sigra.Token.generate_hashed_token/0`, `Sigra.Token.hash_token/1`, `Sigra.APIToken.ScopeRegistry.validate_scopes/2` (reuse SA-relevant scopes), `Sigra.Audit.log_multi_safe/3` |
| `Sigra.ServiceAccounts.revoke_credential/3` | `Ecto.Multi.update/3`, `Sigra.Audit.log_multi_safe/3` |
| `Sigra.ServiceAccounts.issue_token/3` | `Sigra.JWT.generate_service_account_tokens/3` (already in place at `lib/sigra/jwt.ex:120`) |
| `Sigra.ServiceAccounts.append_token_issued_audit/3` | `Ecto.Multi.update/3` (credential `last_used_at` bump), `Sigra.Audit.log_multi_safe/3` keyed `:audit_sa_token_issued` |
| `Sigra.ServiceAccounts.commit_verify_failure_audit/3` | `Sigra.Audit.log_multi_safe/3` keyed `:audit_sa_verify_failure`, `:telemetry.execute/3` (mirrors `Sigra.APIToken.commit_api_token_verify_failure_audit/2` shape) |
| `Sigra.OAuth.Token.client_credentials/2` | `Sigra.ServiceAccounts.issue_token/3`, `Sigra.APIToken.ScopeRegistry.validate_scopes/2`, `Plug.Crypto.secure_compare/2` (T2 timing mitigation) |
| `oauth_token_controller.ex` (template) | `Sigra.OAuth.Token.client_credentials/2`, `Phoenix.Controller.json/2`, `Plug.Conn.put_resp_header/3`, `Base.decode64/1` (Basic auth extraction) |
| `organization_service_accounts_live.ex` (template) | `<App>.ServiceAccounts.create/3`/`revoke/3`/`create_credential/3`/`revoke_credential/3` (host-side wrapper that calls `Sigra.ServiceAccounts`), `Sigra.Crypto.verify_password/2` (sudo gate per D-93-17), generated `<.header>`, `<.button>`, `<.input>`, `<.table>`, `<.icon>`, `<.form>`, `<.link>` core components |
| `service_account.ex` schema (template) | `Ecto.Schema`, `Ecto.Changeset` — no Sigra-lib calls (schemas stay audit-agnostic per D-AUD-01 / library separation) |
| `service_account_credential.ex` schema (template) | Same as above |
| `service_accounts_migration.exs` (template) | `Ecto.Migration` only |
| `alter_add_service_accounts.exs` upgrade (template) | `Ecto.Migration` only (idempotent `add_if_not_exists`/`create_if_not_exists`) |
| `Sigra.Plug.RequireMembership` SA short-circuit | `Map.get/3` only — no library calls; pattern-match on `scope.actor_type` |
| `Sigra.Plug.RequireOrgMfa` SA short-circuit | Same as above |
| `Sigra.Scope.build/3` `:service_account_id` thread | `struct/2` — additive `Keyword.get(opts, :service_account_id)` |
| `Scope` template `defstruct` + `def new(%{} = attrs)` | `struct/2` — host-owned, no Sigra calls |
| `Sigra.Config` `:service_accounts` schema entry | NimbleOptions schema — declarative; consumed by `Sigra.Config.new!/1` |
| `service_accounts_test.exs` (unit) | `Sigra.ServiceAccounts.*` (subject under test), in-process MockRepo + MockSchema (mirrors `api_token_test.exs:1-60`) |
| `service_accounts_audit_atomicity_test.exs` (Postgres) | `Sigra.Test.PostgresRepo`, `Sigra.Test.AuditEvent`, `Ecto.Adapters.SQL.query!/3` (CHECK-guard ALTER), `:telemetry.attach/4` (mirrors `jwt_refresh_audit_cofate_test.exs:51-280`) |
| `oauth/token_test.exs` (RFC 6749 envelope) | `Plug.Test.conn/3`, `put_req_header/3` for Basic + form-encoded, `Phoenix.ConnTest.json_response/2`, `Sigra.OAuth.Token.client_credentials/2` directly |
| `service_account_e2e_test.exs` (E2E) | `ExampleWeb.ConnCase`, `Phoenix.LiveViewTest.live/2`+`render_click/1`+`render_submit/1`, `Phoenix.ConnTest.json_response/2`, `Plug.Conn.put_req_header/3` (Bearer JWT), `Repo.all(from a in AuditEvent, where: ...)` (mirrors `org_mfa_enforcement_test.exs:1-103`) |
| `m2m-service-accounts.md` recipe | None (markdown only); structural mirror of `role-based-access-control.md` |

---

## Metadata

**Analog search scope:**
- `lib/sigra/` (66 files; orchestrator + plug + schema seam)
- `priv/templates/sigra.install/` (4 subdirs: core/, organizations/, organizations/live/, admin/, passkeys/)
- `priv/templates/sigra.upgrade/` (4 files; idempotent migrations)
- `test/sigra/` (~70 files; unit + atomicity)
- `test/sigra/plug/` (18 files; plug unit-tests)
- `test/example/test/example_web/integration/` (3 files; the only E2E directory in the project)
- `guides/recipes/` (8 files; recipe shape + ExDoc layout)

**Files scanned (Read-tool reads):**
- 8 lib files (organizations, jwt, fetch_bearer, require_membership, require_org_mfa, scope, audit, api_token, oauth)
- 10 template files (organization, organization_membership, migration, router_injection, members LV, settings LV, api_token_controller, user_api_token, api_token_migration, scope, alter_add_personal upgrade)
- 4 test files (jwt_refresh_audit_cofate, fetch_bearer_test, api_token_test, org_mfa_enforcement_test, role-based-access-control recipe)
- All 3 phase planning docs (CONTEXT, RESEARCH, UI-SPEC)

**Pattern extraction date:** 2026-05-01.

**Key insight:** Phase 93 has zero genuinely novel primitives. Every NEW file maps to an existing analog within the same project. The risk axis is **integration completeness** (Pitfall 1: dangling references; Pitfall 3: Scope template needs `def new(%{})` clause), not novel design. Plan 93-01 wave 0's `mix compile` gate is the single most important cross-cutting verification.
