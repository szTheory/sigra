# Phase 124: jit-provisioning-safe-reconciliation - Pattern Map

**Mapped:** 2026-05-25
**Files analyzed:** 7
**Analogs found:** 7 / 7

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/sigra/oauth/callback.ex` | controller | request-response | `lib/sigra/oauth/callback.ex` | exact |
| `lib/sigra/oauth/enterprise_reconciliation.ex` | service | CRUD | `lib/sigra/oauth/callback.ex` | role-match |
| `lib/sigra/organizations/invitations.ex` | service | CRUD | `lib/sigra/organizations/invitations.ex` | exact |
| `test/sigra/oauth/enterprise_reconciliation_test.exs` | test | request-response | `test/sigra/oauth/enterprise_callback_test.exs` | role-match |
| `test/example/lib/example_web/controllers/enterprise_sso_controller.ex` | controller | request-response | `test/example/lib/example_web/controllers/enterprise_sso_controller.ex` | exact |
| `test/example/test/example_web/controllers/enterprise_sso_controller_test.exs` | test | request-response | `test/example/test/example_web/controllers/enterprise_sso_controller_test.exs` | exact |
| `test/example/test/example_web/integration/enterprise_sso_reconciliation_flow_test.exs` | test | request-response | `test/example/test/example_web/integration/enterprise_sso_routing_flow_test.exs` | role-match |

## Pattern Assignments

### `lib/sigra/oauth/callback.ex` (controller, request-response)

**Analog:** `lib/sigra/oauth/callback.ex`

**Imports + module boundary** (lines 23-30):
```elixir
require Logger

alias Ecto.Multi
alias Sigra.Audit
alias Sigra.Error.OAuthError
alias Sigra.EnterpriseRouting
alias Sigra.Telemetry
```

**Callback entrypoint with fail-closed enterprise context validation** (lines 54-68):
```elixir
def process_callback(config, provider, user_info, token, opts \\ []) do
  email = user_info["email"]

  if is_nil(email) or email == "" do
    Logger.error("OAuth callback for #{provider}: provider returned no email")
    {:error, %OAuthError{provider: provider, error_code: :no_email}}
  else
    with {:ok, enterprise_context} <-
           validate_enterprise_context(config, provider, Keyword.get(opts, :enterprise_context)) do
      provider_str = to_string(provider) |> String.downcase()
      provider_uid = to_string(user_info["sub"])

      do_process(config, provider, provider_str, provider_uid, user_info, token, enterprise_context)
    end
  end
end
```

**Existing identity vs email-match branch shape** (lines 79-111):
```elixir
identity = repo.get_by(identity_schema, provider: provider_str, provider_uid: provider_uid)

cond do
  identity != nil ->
    handle_existing_identity(
      config,
      repo,
      identity,
      user_info,
      token,
      provider,
      enterprise_context
    )

  true ->
    email = user_info["email"]
    existing_user = repo.get_by(user_schema, email: email)

    if existing_user do
      {:link_confirmation_required,
       %{
         provider: provider,
         provider_uid: user_info["sub"],
         email: email
       }}
    else
      register_oauth_user(config, provider, provider_str, user_info, token, enterprise_context)
    end
end
```

**Session metadata contract** (lines 353-364):
```elixir
%{
  type: session_type,
  auth_method: :oauth,
  provider: provider
}
|> maybe_put(:active_organization_id, enterprise_context && enterprise_context.organization_id)
|> maybe_put(:enterprise_connection_id, enterprise_context && enterprise_context.connection_id)
|> maybe_put(:enterprise_routing_source, enterprise_context && enterprise_context.routing_source)
```

**Enterprise context validation pattern** (lines 369-388):
```elixir
cond do
  is_nil(state_context) or is_nil(session_context) ->
    {:error, %OAuthError{provider: provider, error_code: :enterprise_context_mismatch}}

  state_context != session_context ->
    {:error, %OAuthError{provider: provider, error_code: :enterprise_context_mismatch}}

  true ->
    case EnterpriseRouting.get_routable_connection(config, %{id: state_context.organization_id}) do
      {:ok, %{connection_id: connection_id}} when connection_id == state_context.connection_id ->
        {:ok, state_context}

      _ ->
        {:error, %OAuthError{provider: provider, error_code: :org_connection_unavailable}}
    end
end
```

**Copy for Phase 124:** keep this file as the thin callback orchestrator. Put the new decision tree behind a dedicated reconciliation function/module and keep `OAuthError`-based refusal mapping at this layer.

---

### `lib/sigra/oauth/enterprise_reconciliation.ex` (service, CRUD)

**Primary analog:** `lib/sigra/oauth/callback.ex`

**Secondary analogs:** `lib/sigra/organizations.ex`, `lib/sigra/organizations/invitations.ex`

**Service-style Multi composition** from `lib/sigra/oauth/callback.ex` lines 264-301:
```elixir
multi =
  Multi.new()
  |> Multi.run(:user, fn _repo, _changes ->
    user_attrs = %{
      email: user_info["email"],
      confirmed_at: confirmed_at
    }

    changeset =
      user_schema
      |> struct()
      |> Ecto.Changeset.change(user_attrs)

    repo.insert(changeset)
  end)
  |> Multi.run(:identity, fn _repo, %{user: user} ->
    identity_attrs = %{
      user_id: user.id,
      provider: provider_str,
      provider_uid: to_string(user_info["sub"])
    }

    changeset =
      identity_schema
      |> struct()
      |> Ecto.Changeset.change(identity_attrs)

    repo.insert(changeset)
  end)
```

**Pure membership-builder composition** from `lib/sigra/organizations.ex` lines 807-823:
```elixir
Multi.new()
|> Multi.run(:add_member_resolve_user, fn _repo, changes ->
  user =
    case user_ref do
      {:changes_key, key} -> Map.fetch!(changes, key)
      %_{} = u -> u
    end

  {:ok, user}
end)
|> Multi.insert(:membership, fn %{add_member_resolve_user: user} ->
  build_membership_changeset(membership_schema, org, user, role)
end)
|> append_audit(config, "organization.member_add", scope,
  metadata: add_member_audit_metadata(user_ref, role)
)
```

**Exact invite-consumption composition** from `lib/sigra/organizations/invitations.ex` lines 567-592:
```elixir
Multi.new()
|> Multi.append(
  Sigra.Organizations.add_member_multi(config, user_scope, org, user, invitation.role)
)
|> Multi.update(:accept_invitation, accept_changeset)
|> append_audit(config, "organization.invitation.accepted", user_scope,
  metadata: %{invitation_id: invitation.id, role: to_string(invitation.role)}
)
|> config.repo.transact()
|> case do
  {:ok, %{membership: m, accept_invitation: inv}} ->
    {:ok, %{membership: m, invitation: inv}}
```

**Normalization helper to copy** from `lib/sigra/auth.ex` lines 78-82:
```elixir
def normalize_email(nil), do: nil

def normalize_email(email) when is_binary(email) do
  email |> String.trim() |> String.downcase()
end
```

**DB-owned idempotency contract** from `lib/sigra/organizations.ex` lines 1186-1193 and `priv/templates/sigra.gen.oauth/oauth_migration.exs` lines 22-23:
```elixir
struct(membership_schema)
|> Ecto.Changeset.cast(%{role: role}, [:role])
|> Ecto.Changeset.validate_required([:role])
|> Ecto.Changeset.put_change(:organization_id, org.id)
|> Ecto.Changeset.put_change(:user_id, user.id)
|> Ecto.Changeset.unique_constraint([:user_id, :organization_id])
```

```elixir
create unique_index(:user_identities, [:user_id, :provider])
create unique_index(:user_identities, [:provider, :provider_uid])
```

**Copy for Phase 124:** build this module as a library-owned transactional service returning explicit outcomes like `:existing_membership`, `:invitation_consumed`, `:jit_created`, and typed refusal atoms. Keep repo writes inside one `Ecto.Multi`.

---

### `lib/sigra/organizations/invitations.ex` (service, CRUD)

**Analog:** `lib/sigra/organizations/invitations.ex`

**Mismatch/no-leak validation pattern** (lines 505-542):
```elixir
defp assert_bound_email(bound_email, row_email) do
  if String.downcase(to_string(bound_email)) == String.downcase(to_string(row_email)) do
    :ok
  else
    {:error, :email_mismatch}
  end
end

defp assert_user_matches_invitation(%{email: user_email}, %{email: inv_email}) do
  if String.downcase(to_string(user_email)) == String.downcase(to_string(inv_email)) do
    :ok
  else
    {:error, :mismatch}
  end
end
```

**Accept path result normalization** (lines 567-592):
```elixir
|> config.repo.transact()
|> case do
  {:ok, %{membership: m, accept_invitation: inv}} ->
    {:ok, %{membership: m, invitation: inv}}

  {:error, _step, %Ecto.Changeset{} = cs, _} ->
    {:error, cs}

  {:error, _step, reason, _} ->
    {:error, reason}
end
```

**Signup-path append pattern** (lines 613-635):
```elixir
Multi.new()
|> Multi.append(Sigra.Auth.register_user_multi(params_with_locked_email, register_opts))
|> Multi.run(:confirm_user, fn repo, %{user: user} ->
  repo.update(Ecto.Changeset.change(user, %{confirmed_at: now}))
end)
|> Multi.append(
  Sigra.Organizations.add_member_multi(
    config,
    signup_scope,
    org,
    {:changes_key, :confirm_user},
    invitation.role
  )
)
|> Multi.update(:accept_invitation, accept_stamp_fn)
|> append_audit(config, "organization.invitation.accepted", signup_scope, ...)
```

**Copy for Phase 124:** if you add a helper for exact pending-invite consumption without token verification, keep the same exact-match, typed-error, and `Multi.append/2` composition style instead of adding direct controller-side writes.

---

### `test/sigra/oauth/enterprise_reconciliation_test.exs` (test, request-response)

**Analog:** `test/sigra/oauth/enterprise_callback_test.exs`

**Test-module structure** (lines 1-8):
```elixir
defmodule Sigra.OAuth.EnterpriseCallbackTest do
  use ExUnit.Case, async: true

  import Sigra.Test.OAuthHelpers

  alias Sigra.Error.OAuthError
  alias Sigra.OAuth
end
```

**Inline repo stub pattern** (lines 57-101):
```elixir
defmodule EnterpriseCallbackRepo do
  alias Sigra.OAuth.EnterpriseCallbackTest.{TestConnection, TestOrganization}

  def get(TestOrganization, "org-acme"), do: @organization
  def get_by(Sigra.Test.MockIdentity, clauses) do
    if clauses[:provider_uid] == "provider_uid_123" do
      %Sigra.Test.MockIdentity{...}
    end
  end

  def update(changeset), do: {:ok, Ecto.Changeset.apply_changes(changeset)}
  def transaction(%Ecto.Multi{} = multi), do: Sigra.Test.MultiStub.run(__MODULE__, multi)
  def insert(%Ecto.Changeset{} = changeset), do: {:ok, Ecto.Changeset.apply_changes(changeset)}
end
```

**Expectation style for typed failure outcomes** (lines 169-186, 210-233):
```elixir
assert {:error, %OAuthError{error_code: :enterprise_context_mismatch}} =
         OAuth.handle_callback(config, :mock, params, mismatched_session)
```

```elixir
assert {:error, %OAuthError{error_code: :org_connection_unavailable}} =
         OAuth.Callback.process_callback(
           config,
           :mock,
           mock_user_info(),
           mock_token(),
           enterprise_context: context
         )
```

**Copy for Phase 124:** keep new reconciliation tests at the library boundary with focused fake repos and explicit assertions on typed outcomes, not controller redirects.

---

### `test/example/lib/example_web/controllers/enterprise_sso_controller.ex` (controller, request-response)

**Analog:** `test/example/lib/example_web/controllers/enterprise_sso_controller.ex`

**Thin controller delegation pattern** (lines 49-77):
```elixir
session_params = get_session(conn, @enterprise_session_key) || %{}

with {:ok, routing} <- Organizations.get_routable_enterprise_connection(org_slug) do
  case oauth_module().handle_callback(
         enterprise_sigra_config(routing.connection),
         :oidc,
         params,
         session_params
       ) do
    {:ok, _result, user, session_metadata} ->
      metadata =
        session_metadata
        |> Map.put(:ip, client_ip(conn))
        |> Map.put(:user_agent, client_user_agent(conn))
```

**Session issuance stays controller-owned** (lines 65-71):
```elixir
case Sigra.Auth.create_session(Auth.sigra_config(), user, metadata, []) do
  {:ok, session} ->
    conn
    |> delete_session(@enterprise_session_key)
    |> put_flash(:info, "Welcome!")
    |> UserAuth.put_user_session_token(session.token)
    |> redirect(to: ~p"/organizations/#{org_slug}/settings")
```

**Error mapping pattern** (lines 80-97, 147-154):
```elixir
{:link_confirmation_required, _info} ->
  conn
  |> delete_session(@enterprise_session_key)
  |> put_flash(:error, "Finish sign-in with your existing account before linking enterprise access.")
  |> redirect(to: ~p"/organizations/#{org_slug}/sso")
```

```elixir
defp oauth_error_message(%OAuthError{error_code: :enterprise_context_mismatch}),
  do: "Your enterprise sign-in session expired. Please try again."

defp oauth_error_message(%OAuthError{error_code: :org_connection_unavailable}),
  do: "Enterprise sign-in is not available for this organization right now."
```

**Return-to discipline source** from `test/example/lib/example_web/user_auth.ex` lines 67-73:
```elixir
user_return_to = get_session(conn, :user_return_to)

conn
|> renew_session()
|> put_token_in_session(token)
|> maybe_write_remember_me_cookie(token, params)
|> redirect(to: user_return_to || signed_in_path(conn))
```

**Copy for Phase 124:** keep the controller thin. It should consume a typed reconciliation result, issue the cookie session only on safe success, and replace the hardcoded settings redirect with `return_to` compatibility logic plus `/organizations` fallback.

---

### `test/example/test/example_web/controllers/enterprise_sso_controller_test.exs` (test, request-response)

**Analog:** `test/example/test/example_web/controllers/enterprise_sso_controller_test.exs`

**Mock external OAuth module pattern** (lines 11-19):
```elixir
defmodule MockEnterpriseOAuth do
  def authorize_url(_config, :oidc, opts) do
    {:ok, "https://idp.example.com/authorize", %{state: "state-123", enterprise: opts[:enterprise]}}
  end

  def handle_callback(_config, :oidc, _params, _session_params) do
    key = {__MODULE__, :callback_result}
    :persistent_term.get(key)
  end
end
```

**Controller success assertion pattern** (lines 95-106):
```elixir
conn =
  conn
  |> init_test_session(%{
    enterprise_auth_session: %{state: "state-123", enterprise_context: %{organization_id: organization.id}}
  })
  |> put_req_header("user-agent", "ExUnit")
  |> get(~p"/organizations/#{organization.slug}/sso/callback?code=auth-code&state=state-123")

assert redirected_to(conn) == ~p"/organizations/#{organization.slug}/settings"
assert get_session(conn, :enterprise_auth_session) == nil
assert get_session(conn, :user_token)
```

**Retryable failure assertion pattern** (lines 112-124):
```elixir
:persistent_term.put(
  {MockEnterpriseOAuth, :callback_result},
  {:error, %OAuthError{provider: :oidc, error_code: :enterprise_context_mismatch}}
)

assert redirected_to(conn) == ~p"/organizations/#{organization.slug}/sso"
assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "session expired"
```

**Copy for Phase 124:** update this file in place. Keep the same test harness, but swap redirect expectations to the new `return_to` / `/organizations` contract and add unsafe-outcome assertions for “no `:user_token`”.

---

### `test/example/test/example_web/integration/enterprise_sso_reconciliation_flow_test.exs` (test, request-response)

**Analog:** `test/example/test/example_web/integration/enterprise_sso_routing_flow_test.exs`

**Integration flow shape** (lines 10-33):
```elixir
test "enterprise discovery routes the user into the canonical organization entry page", %{
  conn: conn
} do
  organization = create_organization(%{name: "Acme", slug: "acme"})
  create_enterprise_connection(organization, ["acme.example"])

  conn =
    post(conn, ~p"/users/log_in", %{
      "_action" => "enterprise",
      "user" => %{"email" => "person@acme.example"}
    })

  assert redirected_to(conn) == ~p"/organizations/acme/sso?#{%{routing_source: "domain_discovery"}}"
end
```

**Fixture helper reuse** (lines 35-53):
```elixir
defp create_enterprise_connection(organization, login_hint_domains) do
  %Example.Accounts.EnterpriseConnection{}
  |> Example.Accounts.EnterpriseConnection.changeset(%{
    organization_id: organization.id,
    protocol: :oidc,
    status: :active,
    display_name: "Enterprise #{System.unique_integer([:positive])}",
    login_hint_domains: login_hint_domains,
    oidc_settings: %{...}
  })
  |> Repo.insert!()
end
```

**Copy for Phase 124:** use this file as the example-app proof layer for the full success/failure journey: org-compatible `return_to`, `/organizations` fallback, first-time JIT success messaging, and no session on unsafe reconciliation.

## Shared Patterns

### Enterprise Context Validation
**Source:** `lib/sigra/oauth/callback.ex` lines 369-388  
**Apply to:** `lib/sigra/oauth/callback.ex`, `lib/sigra/oauth/enterprise_reconciliation.ex`
```elixir
cond do
  is_nil(state_context) or is_nil(session_context) ->
    {:error, %OAuthError{provider: provider, error_code: :enterprise_context_mismatch}}

  state_context != session_context ->
    {:error, %OAuthError{provider: provider, error_code: :enterprise_context_mismatch}}

  true ->
    case EnterpriseRouting.get_routable_connection(config, %{id: state_context.organization_id}) do
      {:ok, %{connection_id: connection_id}} when connection_id == state_context.connection_id ->
        {:ok, state_context}

      _ ->
        {:error, %OAuthError{provider: provider, error_code: :org_connection_unavailable}}
    end
end
```

### Session Truth Before First Audit
**Source:** `lib/sigra/auth.ex` lines 1316-1352  
**Apply to:** all successful enterprise callback paths
```elixir
{final_session, active_org} =
  case Map.get(metadata, :active_organization_id) do
    org_id when not is_nil(org_id) ->
      assign_explicit_active_organization(config, session, session_store, store_opts, org_id)

    _ ->
      case config.organizations_module do
        nil -> {session, nil}
        om -> resolve_and_assign_org(config, om, user, session, session_store, store_opts, opts)
      end
  end

Sigra.Audit.log_safe(
  "session.create",
  scope,
  Keyword.merge(audit_opts,
    actor_id: user.id,
    metadata: %{type: Map.get(metadata, :type, :standard), session_id: final_session.id}
  )
)
```

### Membership + Invite Uniqueness
**Source:** `lib/sigra/organizations.ex` lines 1186-1193 and `test/example/priv/repo/migrations/20260410125245_create_organizations.exs` lines 34, 57-60  
**Apply to:** all membership reconciliation branches
```elixir
|> Ecto.Changeset.unique_constraint([:user_id, :organization_id])
```

```elixir
create(unique_index(:organization_memberships, [:user_id, :organization_id]))

create(
  unique_index(:organization_invitations, [:organization_id, :email],
    where: "accepted_at IS NULL AND revoked_at IS NULL",
    name: :organization_invitations_pending_index
  )
)
```

### Return-To Discipline
**Source:** `test/example/lib/example_web/user_auth.ex` lines 67-73 and 571  
**Apply to:** example-app enterprise success redirect
```elixir
user_return_to = get_session(conn, :user_return_to)

conn
|> renew_session()
|> put_token_in_session(token)
|> maybe_write_remember_me_cookie(token, params)
|> redirect(to: user_return_to || signed_in_path(conn))
```

```elixir
defp signed_in_path(_conn), do: ~p"/"
```

## No Analog Found

None. Every scoped file has a strong repo-local analog.

## Metadata

**Analog search scope:** `lib/`, `test/`, `test/example/`, `priv/templates/`, `test/example/priv/repo/migrations/`  
**Files scanned:** 16  
**Pattern extraction date:** 2026-05-25
