defmodule ExampleWeb.ServiceAccountE2ETest do
  @moduledoc """
  ROADMAP success criterion #4 generator-host E2E lifecycle proof.

  Drives the full Phase 93 service-account flow in a single test:

    1. admin signs in
    2. creates SA via Sigra.ServiceAccounts.create/3 (context call — Plan 93-09 LiveView
       forms not yet implemented; documented as deviation in 93-10-SUMMARY.md)
    3. creates a credential via Sigra.ServiceAccounts.create_credential/4
    4. captures plaintext client_secret from the {:ok, cred, plaintext_secret} return
    5. exchanges (client_id, client_secret) at POST /oauth/token (RFC 6749 client_credentials)
    6. calls the protected /service-account/probe endpoint with Bearer JWT
    7. revokes the SA via Sigra.ServiceAccounts.revoke/3
    8. retries the protected endpoint -> 401

  Audit-row assertions interleave the steps to lock D-93-19 / D-93-21
  contracts, including `client_secret`-forbidden defense-in-depth on BOTH
  `service_account.credential_create` AND `service_account.token_issued`
  audit metadata. Atomicity is proven separately in
  test/sigra/service_accounts_audit_atomicity_test.exs (Plan 93-06).

  ## Deviation from Plan 93-10

  Plan 93-10 specifies driving LiveView forms for create SA / create credential /
  revoke SA (depending on Plan 93-09 output). Plan 93-09 has not yet been executed
  in this wave; the LiveView at test/example/lib/example_web/live/
  organization_service_accounts_live.ex is a minimal list-only implementation
  without create/credential/revoke forms. The context-call approach used here
  fully proves ROADMAP SC #4 (create -> mint -> call -> revoke -> 401) and all
  audit-row contracts. LiveView-driven path deferred to a follow-up task once
  Plan 93-09 completes.
  """

  use ExampleWeb.ConnCase, async: false

  # Phoenix.LiveViewTest exposes `live/2`, `form/3`, `render_submit/2`,
  # `render_click/1`, `element/2`, AND `assert_patch/2`.
  import Phoenix.LiveViewTest

  # `Ecto.Query.from/2` is a defmacro — it must be imported, NOT delegated
  # via a defp wrapper (a function body cannot delegate to a macro).
  import Ecto.Query

  alias Example.AccountsFixtures
  alias Example.Accounts
  alias Example.Accounts.AuditEvent
  alias Example.Repo

  @admin_password "supersecret-admin-password!123"

  setup do
    admin = AccountsFixtures.user_fixture(%{password: @admin_password})
    org = AccountsFixtures.create_organization(%{name: "ACME Corp", slug: "acme-corp-#{System.unique_integer([:positive])}"})
    _membership = AccountsFixtures.create_membership(admin, org, :owner)

    admin_conn = AccountsFixtures.log_in_user_with_org(build_conn(), admin, org)

    {:ok, admin: admin, org: org, admin_conn: admin_conn}
  end

  describe "service-account LiveView index mount (prerequisite check)" do
    test "mounts the SA index LiveView and shows empty-state copy", %{admin_conn: admin_conn, org: org} do
      {:ok, _lv, html} = live(admin_conn, ~p"/organizations/#{org.slug}/service-accounts")
      assert html =~ "No service accounts yet"
    end
  end

  describe "service-account lifecycle E2E (ROADMAP SC #4)" do
    test "admin creates SA -> mints JWT -> calls protected endpoint -> revokes -> next call 401",
         %{admin: admin, org: org} do
      config = Accounts.sigra_config()

      # Build a scope with the admin user and org for SA operations (D-93-22: scope required).
      membership = Repo.get_by!(Example.Accounts.OrganizationMembership,
        user_id: admin.id,
        organization_id: org.id
      )
      scope = admin
              |> Example.Accounts.Scope.for_user()
              |> Example.Accounts.Scope.put_active_organization(org, membership)

      # ----- 1. create SA via context call (Plan 93-09 LiveView not yet available) -----
      {:ok, sa} = Sigra.ServiceAccounts.create(config, scope, %{
        name: "ci-bot",
        scopes: ["deploy:write"],
        organization_id: org.id,
        created_by_user_id: admin.id
      })

      assert sa.name == "ci-bot"
      assert sa.organization_id == org.id
      assert is_nil(sa.revoked_at)

      # ----- 2. assert audit row: service_account.create -----
      assert_audit_row!(action: "service_account.create",
                        actor_type_col: "user",
                        metadata_contains_key: "name")

      # ----- 3. create credential via context call -----
      {:ok, cred, client_secret} = Sigra.ServiceAccounts.create_credential(config, scope, sa)

      assert String.starts_with?(cred.client_id, "sigra_sa_")
      assert byte_size(client_secret) > 16
      client_id = cred.client_id

      # ----- 4. audit row: service_account.credential_create -----
      assert_audit_row!(action: "service_account.credential_create",
                        actor_type_col: "user",
                        metadata_contains_key: "client_id_prefix",
                        metadata_forbidden_substring: "client_secret")

      # ----- 5. mint JWT via /oauth/token (RFC 6749 client_credentials) -----
      basic = Base.encode64("#{client_id}:#{client_secret}")

      token_conn =
        build_conn()
        |> put_req_header("authorization", "Basic #{basic}")
        |> put_req_header("content-type", "application/x-www-form-urlencoded")
        |> post(~p"/oauth/token", "grant_type=client_credentials")

      token_body = json_response(token_conn, 200)
      assert token_body["token_type"] == "Bearer"
      assert token_body["expires_in"] == 3600
      access_token = token_body["access_token"]
      assert is_binary(access_token)
      assert byte_size(access_token) > 20

      # ----- 6. audit row: service_account.token_issued (D-93-20 + D-93-21) -----
      # D-93-21 defense-in-depth: client_secret must NOT appear in token_issued
      # audit metadata even though the issuance path doesn't see plaintext directly.
      assert_audit_row!(action: "service_account.token_issued",
                        actor_type_col: "service_account",
                        metadata_contains_key: "service_account_id",
                        metadata_forbidden_substring: "client_secret")

      # ----- 7. call protected endpoint with bearer token -----
      probe_conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{access_token}")
        |> get(~p"/api/service-account/probe")

      probe = json_response(probe_conn, 200)
      assert probe["actor_type"] == "service_account"
      assert probe["service_account_id"] == sa.id
      assert probe["organization_id"] == org.id
      assert probe["user_id"] in [nil]   # D-93-04: user is nil for SA requests

      # ----- 8. revoke SA via context call (Plan 93-09 LiveView not yet available) -----
      # NOTE: When Plan 93-09 LiveView forms are available, this step will use:
      #   form[phx-submit=revoke_service_account] with %{typed_confirm: "ci-bot",
      #   current_password: @admin_password}. The typed_confirm field enforces
      #   D-93-17: user must type the SA name exactly before the revoke is accepted.
      {:ok, revoked_sa} = Sigra.ServiceAccounts.revoke(config, scope, sa)
      assert revoked_sa.revoked_at != nil
      # token_epoch bumped — all live JWTs for this SA are invalidated
      assert revoked_sa.token_epoch > sa.token_epoch

      # ----- 9. audit row: service_account.revoke -----
      assert_audit_row!(action: "service_account.revoke",
                        actor_type_col: "user",
                        metadata_contains_key: "service_account_id")

      # ----- 10. retry protected endpoint with the old token -> 401 -----
      retry_conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{access_token}")
        |> get(~p"/api/service-account/probe")

      assert retry_conn.status == 401,
             "Expected 401 after SA revocation; got #{retry_conn.status}"

      # ----- 11. assert verify-failure audit row -----
      assert_verify_failure_audit_for_sa!(sa.id)
    end
  end

  # --- helpers ----------------------------------------------------------------

  defp assert_audit_row!(opts) do
    action = Keyword.fetch!(opts, :action)

    rows =
      from(e in AuditEvent, where: e.action == ^action)
      |> Repo.all()

    assert rows != [],
           "Expected at least one audit_events row with action=#{action}"

    if actor_type_val = opts[:actor_type_col] do
      assert Enum.any?(rows, fn r -> r.actor_type == actor_type_val end),
             "Expected at least one #{action} row with actor_type column = #{inspect(actor_type_val)}"
    end

    if key = opts[:metadata_contains_key] do
      assert Enum.any?(rows, fn r ->
               md = r.metadata || %{}
               Map.has_key?(md, key) or Map.has_key?(md, String.to_atom(key))
             end),
             "Expected at least one #{action} row whose metadata has key #{inspect(key)}"
    end

    if forbidden = opts[:metadata_forbidden_substring] do
      for r <- rows do
        md = inspect(r.metadata || %{})

        refute md =~ forbidden,
               "audit_events.action=#{action} metadata must NOT contain #{forbidden}; row: #{md}"
      end
    end

    :ok
  end

  defp assert_verify_failure_audit_for_sa!(sa_id) do
    rows =
      from(e in AuditEvent, where: e.action == "api.token_verify.failure")
      |> Repo.all()

    assert rows != [],
           "Expected at least one api.token_verify.failure audit row after SA revocation"

    sa_rows =
      Enum.filter(rows, fn r ->
        md = r.metadata || %{}
        Map.get(md, "actor_type") == "service_account" or
          Map.get(md, :actor_type) == "service_account" or
          r.actor_type == "service_account"
      end)

    assert sa_rows != [],
           "Expected at least one api.token_verify.failure row with actor_type=service_account"

    # At least one row's metadata has the revoked SA's id
    assert Enum.any?(sa_rows, fn r ->
             md = r.metadata || %{}

             Map.get(md, "service_account_id") == sa_id or
               Map.get(md, :service_account_id) == sa_id
           end),
           "Expected at least one verify_failure row whose metadata.service_account_id matches SA #{sa_id}"

    # Assert reason is present (either :token_revoked, :epoch_mismatch, or :revoked)
    assert Enum.any?(sa_rows, fn r ->
             md = r.metadata || %{}
             reason = Map.get(md, "reason") || Map.get(md, :reason)
             reason in ["token_revoked", "epoch_mismatch", "revoked", :token_revoked, :epoch_mismatch, :revoked]
           end),
           "Expected at least one verify_failure row with a known revocation reason"
  end

  # NOTE: When Plan 93-09 LiveView forms (create SA / create credential / revoke)
  # are available, the lifecycle test should be updated to drive the UI forms
  # instead of direct context calls. After `render_submit` on `create_service_account`,
  # call `assert_patch(lv, ~r{/service-accounts/[^/]+$})` to verify the LV patched
  # to the SA detail URL. The `typed_confirm` field on `revoke_service_account`
  # enforces D-93-17: the user must type the SA name exactly before the revoke is
  # accepted (e.g., `render_submit(form, %{typed_confirm: "ci-bot", current_password: ...})`).

  # NOTE: do NOT add a `defp from/2` delegate here. `Ecto.Query.from/2` is
  # a defmacro and cannot be wrapped by a function body — that would fail
  # to compile. Use `import Ecto.Query` at module level (above) instead.
end
