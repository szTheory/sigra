defmodule Sigra.Planning.Phase244GeneratedAuthRuntimeProofTest do
  use ExUnit.Case, async: false

  @tag :phase_244_api
  test "fresh API-only host installs twice, migrates, compiles, and authenticates a PAT" do
    require_postgres!()
    require_phx_new!()

    root = File.cwd!()
    tmp = Path.join(System.tmp_dir!(), "sigra-phase-244-#{System.unique_integer([:positive])}")
    app = Path.join(tmp, "sigra_phase_244_api")
    database = "sigra_phase_244_api_#{Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)}"

    assert Regex.match?(~r/^sigra_phase_244_api_[0-9a-f]{16}$/, database),
           "generated database name must remain a bounded PostgreSQL identifier"

    on_exit(fn -> File.rm_rf!(tmp) end)

    run!(root, "mix", [
      "phx.new",
      app,
      "--no-install",
      "--no-dashboard",
      "--database",
      "postgres",
      "--module",
      "SigraPhase244Api",
      "--app",
      "sigra_phase_244_api"
    ])

    patch_mix!(app, root)
    patch_test_repo_config!(app, database)
    run!(app, "mix", ["deps.get"])

    for _ <- 1..2 do
      run!(app, "mix", [
        "sigra.install",
        "Accounts",
        "User",
        "users",
        "--api",
        "--no-live",
        "--no-organizations"
      ])
    end

    run!(app, "mix", ["ecto.create"])
    assert_database_ready!(database)
    run!(app, "mix", ["ecto.migrate"])
    write_smoke!(app)
    run!(app, "mix", ["compile"])
    run!(app, "mix", ["test", "test/pat_runtime_smoke_test.exs"])

    router = File.read!(Path.join(app, "lib/sigra_phase_244_api_web/router.ex"))
    config = File.read!(Path.join(app, "config/config.exs"))

    assert router =~ "Sigra.Plug.FetchAPIToken"
    assert router =~ "config: &SigraPhase244Api.Accounts.sigra_config/0"
    assert router =~ "scope_module: SigraPhase244Api.Accounts.Scope"
    assert router =~ "pipe_through [:api, :api_authenticated]"
    assert router =~ "pipe_through [:browser, :require_authenticated, :require_sudo]"

    refute router =~
             "pipe_through [:api, :api_authenticated]\n\n        get \"/tokens\", APITokenController"

    refute router =~ "FetchJWT"
    refute config =~ "jwt:"
  end

  @tag :phase_244_jwt
  test "fresh JWT-only host installs twice, migrates, compiles, and issues a strict host-scoped JWT" do
    require_postgres!()
    require_phx_new!()

    root = File.cwd!()
    tmp = Path.join(System.tmp_dir!(), "sigra-phase-244-#{System.unique_integer([:positive])}")
    app = Path.join(tmp, "sigra_phase_244_jwt")
    database = "sigra_phase_244_jwt_#{Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)}"

    assert Regex.match?(~r/^sigra_phase_244_jwt_[0-9a-f]{16}$/, database),
           "generated database name must remain a bounded PostgreSQL identifier"

    on_exit(fn -> File.rm_rf!(tmp) end)

    run!(root, "mix", [
      "phx.new",
      app,
      "--no-install",
      "--no-dashboard",
      "--database",
      "postgres",
      "--module",
      "SigraPhase244Jwt",
      "--app",
      "sigra_phase_244_jwt"
    ])

    patch_mix!(app, root)
    patch_test_repo_config!(app, database, "sigra_phase_244_jwt")
    run!(app, "mix", ["deps.get"])

    for install_attempt <- 1..2 do
      run!(app, "mix", [
        "sigra.install",
        "Accounts",
        "User",
        "users",
        "--jwt",
        "--no-live",
        "--no-organizations"
      ])

      if install_attempt == 1, do: run!(app, "mix", ["deps.get"])
    end

    run!(app, "mix", ["deps.get"])

    generated_config = File.read!(Path.join(app, "config/config.exs"))
    assert generated_config =~ "config :sigra_phase_244_jwt, :sigra_api"
    assert generated_config =~ "enabled: true"

    run!(app, "mix", ["ecto.create"])
    assert_database_ready!(database)
    run!(app, "mix", ["ecto.migrate"])
    run!(app, "mix", ["compile"])
    write_jwt_smoke!(app)
    run!(app, "mix", ["test", "test/jwt_runtime_smoke_test.exs"])

    router = File.read!(Path.join(app, "lib/sigra_phase_244_jwt_web/router.ex"))
    config = File.read!(Path.join(app, "config/config.exs"))
    jwt_delegate = File.read!(Path.join(app, "lib/sigra_phase_244_jwt/accounts/auth/jwt.ex"))

    assert router =~ "Sigra.Plug.FetchJWT"
    refute router =~ "FetchAPIToken"
    refute router =~ "FetchBearer"
    refute router =~ "TokenController"
    refute router =~ "post \"/token\""
    assert config =~ "enabled: true"
    assert config =~ "typ: \"JWT\""
    assert config =~ "issuer: \"sigra_phase_244_jwt\""
    assert config =~ "audience: [\"sigra_phase_244_jwt_api\"]"
    refute config =~ "api_token:"
    refute File.exists?(Path.join(app, "lib/sigra_phase_244_jwt/accounts/user_api_token.ex"))

    refute File.exists?(
             Path.join(app, "lib/sigra_phase_244_jwt_web/controllers/api_token_controller.ex")
           )

    refute jwt_delegate =~ "password"
    refute jwt_delegate =~ "conn"
    refute jwt_delegate =~ "params"
  end

  defp require_postgres! do
    case System.cmd("psql", ["-Atqc", "SELECT 1"], stderr_to_stdout: true, env: postgres_env()) do
      {"1\n", 0} -> :ok
      {output, _} -> flunk("PostgreSQL precondition failed: #{String.trim(output)}")
    end
  end

  defp assert_database_ready!(database) do
    readiness_args = ["-d", database, "-t", "5"]

    case System.cmd("pg_isready", readiness_args, stderr_to_stdout: true, env: postgres_env()) do
      {_output, 0} ->
        :ok

      {output, _} ->
        flunk("generated PostgreSQL database #{database} was not ready: #{String.trim(output)}")
    end

    case System.cmd("psql", ["-d", database, "-Atqc", "SELECT 1"],
           stderr_to_stdout: true,
           env: postgres_env()
         ) do
      {"1\n", 0} ->
        :ok

      {output, _} ->
        flunk(
          "generated PostgreSQL database #{database} was not queryable: #{String.trim(output)}"
        )
    end
  end

  defp require_phx_new! do
    case System.cmd("mix", ["phx.new", "--version"], stderr_to_stdout: true) do
      {_output, 0} -> :ok
      {output, _} -> flunk("phx_new precondition failed: #{String.trim(output)}")
    end
  end

  defp patch_mix!(app, root) do
    path = Path.join(app, "mix.exs")
    source = File.read!(path)
    anchor = "      {:phoenix,"

    patched =
      String.replace(
        source,
        anchor,
        "      {:sigra, path: #{inspect(root)}},\n      {:hammer, \"~> 7.3\"},\n" <> anchor,
        global: false
      )

    File.write!(path, patched)
  end

  defp patch_test_repo_config!(app, database, app_name \\ "sigra_phase_244_api") do
    path = Path.join(app, "config/test.exs")
    source = File.read!(path)

    {with_database, database_changes} =
      Regex.replace(
        ~r/database: "#{Regex.escape(app_name)}_test#\{System\.get_env\("MIX_TEST_PARTITION"\)\}",/,
        source,
        "database: #{inspect(database)},"
      )
      |> then(&{&1, if(&1 == source, do: 0, else: 1)})

    assert database_changes == 1,
           "generated test Repo config did not expose Phoenix's partitioned database anchor"

    {with_hostname, hostname_changes} =
      String.replace(
        with_database,
        "hostname: \"localhost\",",
        "hostname: System.fetch_env!(\"PGHOST\"),"
      )
      |> then(&{&1, if(&1 == with_database, do: 0, else: 1)})

    assert hostname_changes == 1, "generated test Repo config did not expose the hostname anchor"

    {patched, port_changes} =
      String.replace(
        with_hostname,
        "pool: Ecto.Adapters.SQL.Sandbox",
        "port: String.to_integer(System.fetch_env!(\"PGPORT\")),\n  pool: Ecto.Adapters.SQL.Sandbox"
      )
      |> then(&{&1, if(&1 == with_hostname, do: 0, else: 1)})

    assert port_changes == 1, "generated test Repo config did not expose the pool anchor"

    File.write!(path, patched)
  end

  defp write_smoke!(app) do
    write_pat_probe!(app)

    File.write!(Path.join(app, "test/pat_runtime_smoke_test.exs"), """
    defmodule SigraPhase244Api.PATRuntimeSmokeTest do
      use SigraPhase244ApiWeb.ConnCase, async: false

      import Phoenix.ConnTest
      import Ecto.Query
      import SigraPhase244Api.AccountsFixtures
      import SigraPhase244ApiWeb.ConnCaseHelpers, only: [log_in_user: 2]

      alias SigraPhase244Api.{Accounts, Repo}

      setup %{conn: conn} do
        owner = user_fixture()
        other =
          valid_user_attributes()
          |> then(&SigraPhase244Api.Accounts.User.registration_changeset(%SigraPhase244Api.Accounts.User{}, &1))
          |> Repo.insert!()

        conn = log_in_user(conn, owner)
        raw_token = Plug.Conn.get_session(conn, :user_token)
        {^owner, session} = Accounts.get_user_and_session_by_token(raw_token)
        :ok = Accounts.confirm_sudo(session.hashed_token)
        {^owner, refreshed_session} = Accounts.get_user_and_session_by_token(raw_token)
        assert %DateTime{} = refreshed_session.sudo_at
        assert DateTime.diff(DateTime.utc_now(), refreshed_session.sudo_at, :second) <= 1
        %{conn: conn, owner: owner, other: other, session: refreshed_session}
      end

      test \"a generated PAT authenticates through the emitted API route\", %{conn: conn, owner: user} do
        config = SigraPhase244Api.Accounts.sigra_config()
        {:ok, raw, token} = Sigra.Auth.create_api_token(config, user, %{name: \"proof\", scopes: [\"profile:read\"]})

        authenticated = conn |> put_req_header(\"authorization\", \"Bearer \" <> raw) |> get(\"/__sigra_phase_244_pat_probe\")
        assert response(authenticated, 200)
        assert %{
                 \"user_id\" => user_id,
                 \"credential_kind\" => \"personal_access_token\",
                 \"credential_id\" => credential_id,
                 \"scopes\" => [\"profile:read\"],
                 \"auth_method\" => \"api_token\",
                 \"assurance\" => []
               } = json_response(authenticated, 200)
        assert user_id == user.id
        assert credential_id == token.id

        for authorization <- [nil, \"Bearer\", \"Basic ignored\", \"Bearer invalid\"] do
          rejected = conn |> recycle() |> maybe_authorization(authorization) |> get(\"/__sigra_phase_244_pat_probe\")
          assert response(rejected, 401)
        end

        Repo.delete!(user)
        stale = conn |> recycle() |> put_req_header(\"authorization\", \"Bearer \" <> raw) |> get(\"/__sigra_phase_244_pat_probe\")
        assert response(stale, 401)
      end

      defp maybe_authorization(conn, nil), do: conn
      defp maybe_authorization(conn, value), do: put_req_header(conn, \"authorization\", value)

      test "real browser routes require authenticated fresh-sudo CSRF requests and preserve PAT rows on every rejected mutation", %{conn: conn, owner: owner, other: other, session: session} do
        fresh = get(conn, ~p\"/users/api-tokens\")
        assert response(fresh, 200)
        csrf = Plug.CSRFProtection.get_csrf_token()

        created =
          fresh
          |> recycle()
          |> put_req_header("x-csrf-token", csrf)
          |> post(~p\"/users/api-tokens\", %{"token" => %{"name" => "owner", "scopes" => ["profile:read"]}})

        assert response(created, 201) =~ "raw_key"
        [token] = owner_tokens(owner)

        listed = created |> recycle() |> get(~p\"/users/api-tokens\")
        assert response(listed, 200) =~ token.id

        revoked = listed |> recycle() |> put_req_header("x-csrf-token", csrf) |> delete(~p\"/users/api-tokens/\#{token.id}\")
        assert response(revoked, 200)

        for {method, path, params} <- [
              {:post, ~p\"/users/api-tokens\", %{"token" => %{"name" => "denied", "scopes" => ["profile:read"]}}},
              {:delete, ~p\"/users/api-tokens/\#{token.id}\", %{}}
            ] do
          before_rows = owner_rows(owner)
          denied = request_with_csrf(build_conn(), method, path, params)
          assert denied.halted
          assert owner_rows(owner) == before_rows
        end

        for csrf_value <- [nil, "invalid"] do
          before_rows = owner_rows(owner)
          denied = request_with_csrf(recycle(conn), :post, ~p\"/users/api-tokens\", %{"token" => %{"name" => "csrf", "scopes" => ["profile:read"]}}, csrf_value)
          assert denied.halted
          assert owner_rows(owner) == before_rows
        end

        stale = stale_sudo(recycle(conn), session)

        for {method, path, params} <- [
              {:post, ~p\"/users/api-tokens\", %{"token" => %{"name" => "stale", "scopes" => ["profile:read"]}}},
              {:delete, ~p\"/users/api-tokens/\#{token.id}\", %{}}
            ] do
          before_rows = owner_rows(owner)
          denied = request_with_csrf(stale, method, path, params, csrf)
          assert denied.halted
          assert owner_rows(owner) == before_rows
        end

        {:ok, _raw, foreign} = Sigra.Auth.create_api_token(Accounts.sigra_config(), other, %{name: "foreign", scopes: ["profile:read"]})
        foreign_conn = log_in_user(build_conn(), owner)
        foreign_raw_token = Plug.Conn.get_session(foreign_conn, :user_token)
        {^owner, foreign_session} = Accounts.get_user_and_session_by_token(foreign_raw_token)
        :ok = Accounts.confirm_sudo(foreign_session.hashed_token)
        foreign_ready = get(foreign_conn, ~p"/users/api-tokens")
        assert response(foreign_ready, 200)
        foreign_csrf = Plug.CSRFProtection.get_csrf_token()
        before_rows = owner_rows(owner)
        foreign_attempt = recycle(foreign_ready) |> put_req_header("x-csrf-token", foreign_csrf) |> delete(~p\"/users/api-tokens/\#{foreign.id}\")
        assert response(foreign_attempt, 404)
        assert owner_rows(owner) == before_rows
      end

      defp request_with_csrf(conn, :post, path, params), do: post(conn, path, params)
      defp request_with_csrf(conn, :delete, path, _params), do: delete(conn, path)
      defp request_with_csrf(conn, :post, path, params, nil), do: post(conn, path, params)
      defp request_with_csrf(conn, :post, path, params, csrf), do: conn |> put_req_header("x-csrf-token", csrf) |> post(path, params)
      defp request_with_csrf(conn, :delete, path, _params, nil), do: delete(conn, path)
      defp request_with_csrf(conn, :delete, path, _params, csrf), do: conn |> put_req_header("x-csrf-token", csrf) |> delete(path)

      defp owner_tokens(user), do: Sigra.Auth.list_api_tokens(Accounts.sigra_config(), user.id) |> elem(0)
      defp owner_rows(user), do: owner_tokens(user) |> Enum.map(&{&1.id, &1.revoked_at})

      defp stale_sudo(conn, session) do
        Repo.update_all(from(s in SigraPhase244Api.Accounts.UserSession, where: s.id == ^session.id), set: [sudo_at: DateTime.add(DateTime.utc_now(), -3_601, :second)])
        conn
      end
    end
    """)
  end

  defp write_pat_probe!(app) do
    router_path = Path.join(app, "lib/sigra_phase_244_api_web/router.ex")
    router = File.read!(router_path)
    anchor = "  # Sigra API\n"

    probe = """
      scope \"/__sigra_phase_244_pat_probe\", SigraPhase244ApiWeb do
        pipe_through [:api, :api_authenticated]

        get \"/\", PATRuntimeProbeController, :show
      end

    """

    patched = String.replace(router, anchor, probe <> anchor, global: false)
    assert patched != router, "generated router did not expose the Sigra API insertion anchor"

    assert String.split(patched, probe) |> length() == 2,
           "generated router probe anchor was replaced more than once"

    File.write!(router_path, patched)

    File.write!(
      Path.join(app, "lib/sigra_phase_244_api_web/controllers/pat_runtime_probe_controller.ex"),
      """
      defmodule SigraPhase244ApiWeb.PATRuntimeProbeController do
        use SigraPhase244ApiWeb, :controller

        def show(conn, _params) do
          auth = conn.private[:sigra_auth]

          json(conn, %{
            user_id: conn.assigns.current_scope.user.id,
            credential_kind: Atom.to_string(auth.credential_kind),
            credential_id: auth.credential_id,
            scopes: auth.scopes,
            auth_method: Atom.to_string(auth.auth_method),
            assurance: auth.assurance
          })
        end
      end
      """
    )
  end

  defp write_jwt_smoke!(app) do
    File.write!(Path.join(app, "test/jwt_runtime_smoke_test.exs"), """
    defmodule SigraPhase244Jwt.JWTRuntimeSmokeTest do
      use SigraPhase244Jwt.DataCase, async: false

      import Phoenix.ConnTest
      import SigraPhase244Jwt.AccountsFixtures

      alias SigraPhase244Jwt.Accounts

      test "host-policy delegate issues one scope and FetchJWT enforces configured claims" do
        user = user_fixture()
        {:ok, %{access_token: access_token}} = Accounts.JWT.create_jwt_tokens(user)
        config = Accounts.JWT.sigra_config()

        assert Keyword.get(config.jwt, :enabled)
        assert Keyword.get(config.jwt, :algorithm) == "HS256"
        assert Keyword.get(config.jwt, :typ) == "JWT"
        assert Keyword.get(config.jwt, :issuer) == "sigra_phase_244_jwt"
        assert Keyword.get(config.jwt, :audience) == ["sigra_phase_244_jwt_api"]

        conn = Plug.Test.conn(:get, "/") |> Plug.Conn.put_req_header("authorization", "Bearer " <> access_token)
        conn = Sigra.Plug.FetchJWT.call(conn, config: config, scope_module: Accounts.Scope)

        assert conn.assigns.current_scope.user.id == user.id
        assert conn.private[:sigra_auth].credential_kind == :jwt
        assert conn.private[:sigra_auth].scopes == ["read"]

        for {claim, value} <- [{"typ", "wrong"}, {"iss", "wrong"}, {"aud", "wrong"}, {"nbf", DateTime.utc_now() |> DateTime.add(60, :second) |> DateTime.to_unix()}] do
          forged = resign(access_token, config, claim, value)
          rejected = Plug.Test.conn(:get, "/") |> Plug.Conn.put_req_header("authorization", "Bearer " <> forged)
          rejected = Sigra.Plug.FetchJWT.call(rejected, config: config, scope_module: Accounts.Scope)
          assert rejected.assigns.current_scope == nil
        end

        for audience <- ["sigra_phase_244_jwt_api", ["wrong", "sigra_phase_244_jwt_api"]] do
          accepted = resign(access_token, config, "aud", audience)
          accepted_conn = Plug.Test.conn(:get, "/") |> Plug.Conn.put_req_header("authorization", "Bearer " <> accepted)
          accepted_conn = Sigra.Plug.FetchJWT.call(accepted_conn, config: config, scope_module: Accounts.Scope)
          assert accepted_conn.assigns.current_scope.user.id == user.id
        end
      end

      defp resign(token, config, "typ", typ) do
        {:ok, claims} = Sigra.JWT.verify_access(config, token)
        signer = configured_signer(config, typ)
        {:ok, resigned, _} = Joken.generate_and_sign(%{"typ" => typ}, claims, signer)
        resigned
      end

      defp resign(token, config, claim, value) do
        {:ok, claims} = Sigra.JWT.verify_access(config, token)
        signer = configured_signer(config, Keyword.fetch!(config.jwt, :typ))
        {:ok, resigned, _} = Joken.generate_and_sign(%{}, Map.put(claims, claim, value), signer)
        resigned
      end

      defp configured_signer(config, typ) do
        signer = Sigra.JWT.Signer.create_signer(config)
        %{signer | jws: JOSE.JWS.from_map(%{"alg" => signer.alg, "typ" => typ})}
      end
    end
    """)
  end

  defp run!(cwd, command, args) do
    {output, status} =
      System.cmd(command, args,
        cd: cwd,
        stderr_to_stdout: true,
        env: [{"MIX_ENV", "test"}, {"CLOAK_KEY", disposable_cloak_key()} | postgres_env()]
      )

    assert status == 0, "#{command} #{Enum.join(args, " ")} failed:\n#{output}"
  end

  defp postgres_env do
    for key <- ~w(PGHOST PGPORT PGUSER PGPASSWORD PGDATABASE),
        value = System.get_env(key),
        is_binary(value),
        do: {key, value}
  end

  # Matches the canonical fresh-host proof fixture. This is never a deployment secret.
  defp disposable_cloak_key, do: "MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY="
end
