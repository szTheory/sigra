defmodule Sigra.Install.Features.Core do
  @moduledoc """
  `Sigra.Install.Feature` implementation for v1.0's core authentication
  scaffold: users, sessions, tokens, MFA, sudo, reset password, confirmation,
  audit events, and (optionally) API token, JWT, and LiveView UI.

  Owns every template under `priv/templates/sigra.install/core/` and every
  router/config/runtime.exs injection needed to wire the v1.0 auth surface
  into a fresh Phoenix app. This module is the single mandatory feature in
  the `mix sigra.install` walker's canonical feature list.

  `enabled?/1` always returns `true` — Core is mandatory (Phase 11 Success
  Criterion #4). The `--api` / `--jwt` / `--live` flags are Core-owned
  sub-options that gate file groups, not whole features; they live here
  rather than as separate features because they are historical v1.0 options
  with deeply intertwined shared state (the API token schema references the
  same users table, the login page is always emitted regardless of `--live`,
  etc.).

  ## Binding contract

  Features.Core expects a binding keyword list shaped like the one built
  in `Mix.Tasks.Sigra.Install.generate/4`:

    * `:otp_app` — atom or string (the host app's otp_app, e.g. `:my_app`)
    * `:context_alias` — string (the context's module suffix, e.g. `"Accounts"`)
    * `:context_module` — string (the full context module as an inspected
      string, e.g. `"MyApp.Accounts"`)
    * `:schema_alias` — string (the schema suffix, e.g. `"User"`)
    * `:web_module` — string (e.g. `"MyAppWeb"`)
    * `:opts` — keyword sublist gating `:live` / `:api` / `:jwt`

  Migration targets and injection bodies are derived from these fields at
  callback invocation time; Features.Core does not read the filesystem
  directly (`post_instructions/2` is the lone exception — it reads
  `config/config.exs`, `config/runtime.exs`, and `config/dev.exs` to detect
  host-app Oban and Swoosh integration, matching the v1.0 monolith's
  `inject_oban_queue/1` and `inject_swoosh_config/2` helpers).

  ## Isolation invariant (Pitfall X-1)

  This module contains ZERO references to `Features.Organizations`,
  `Features.Passkeys`, or `Features.Admin`. That boundary is what makes
  `mix sigra.install --no-organizations` produce a compiling app even with
  no Organizations code present in a future phase. The isolation is enforced
  mechanically by `Sigra.Install.Features.CoreTest`'s isolation test.
  """

  @behaviour Sigra.Install.Feature

  alias Sigra.Install.Injection

  @impl true
  def enabled?(_opts), do: true

  @impl true
  def files(binding) do
    opts = Keyword.get(binding, :opts, [])

    live? = Keyword.get(opts, :live, true)
    api? = Keyword.get(opts, :api, false) || Keyword.get(opts, :jwt, false)
    jwt? = Keyword.get(opts, :jwt, false)

    base_files(binding) ++
      ui_files(binding, live?) ++
      api_files(binding, api?) ++
      jwt_files(binding, jwt?)
  end

  @impl true
  def migrations(_binding) do
    [
      {:primary, "core/migration.exs", "create_sigra_auth_tables.exs"},
      {:api_token, "core/api_token_migration.exs", "create_user_api_tokens.exs"},
      {:audit_events, "core/create_audit_events.exs", "create_audit_events.exs"}
    ]
  end

  @impl true
  def injections(binding) do
    web_module = fetch!(binding, :web_module)
    context_module = fetch!(binding, :context_module)
    schema_alias = fetch!(binding, :schema_alias)
    repo_module = fetch!(binding, :repo_module)
    otp_app_str = otp_app_str(binding)
    api? = api_enabled?(binding)
    jwt? = jwt_enabled?(binding)
    live? = live_enabled?(binding)

    base =
      [
        router_injection(otp_app_str, web_module, live?),
        config_injection(otp_app_str, context_module, schema_alias, repo_module),
        test_config_injection(),
        conn_case_injection(web_module)
      ]

    base
    |> Kernel.++(if api?, do: api_injections(otp_app_str, web_module, jwt?), else: [])
    |> Enum.reject(&is_nil/1)
  end

  @impl true
  def post_instructions(binding, _report) do
    opts = Keyword.get(binding, :opts, [])
    otp_app_str = otp_app_str(binding)
    app_module = fetch!(binding, :app_module)

    base_instructions(opts) ++
      oban_instructions(otp_app_str) ++
      swoosh_instructions(otp_app_str, app_module)
  end

  # ──────────────────────────────────────────────────────────────────────────
  # files/1 helpers
  # ──────────────────────────────────────────────────────────────────────────

  defp base_files(binding) do
    otp_app = otp_app_str(binding)
    ctx = context_underscore(binding)
    web = "#{otp_app}_web"

    [
      # Core schemas + context
      {:eex, "core/user.ex", Path.join(["lib", otp_app, ctx, "user.ex"])},
      {:eex, "core/user_token.ex", Path.join(["lib", otp_app, ctx, "user_token.ex"])},
      {:eex, "core/scope.ex", Path.join(["lib", otp_app, ctx, "scope.ex"])},
      {:eex, "core/auth.ex", Path.join(["lib", otp_app, "#{ctx}.ex"])},

      # Plug + error handler
      {:eex, "core/user_auth.ex", Path.join(["lib", web, "user_auth.ex"])},
      {:eex, "core/error_handler.ex", Path.join(["lib", web, "auth_error_handler.ex"])},

      # Session controller (always — Phase 10.1.1 B9/D-12)
      {:eex, "core/session_controller.ex",
       Path.join(["lib", web, "controllers", "session_controller.ex"])},

      # Test support
      {:eex, "core/auth_fixtures.ex",
       Path.join(["test", "support", "fixtures", "auth_fixtures.ex"])},
      {:eex, "core/conn_case_helpers.ex", Path.join(["test", "support", "conn_case_helpers.ex"])},

      # Phase 3: email flow
      {:eex, "core/emails.ex", Path.join(["lib", otp_app, ctx, "emails.ex"])},
      {:eex, "core/auth_mailer.ex", Path.join(["lib", otp_app, ctx, "mailer.ex"])},
      {:eex, "core/confirmation_controller.ex",
       Path.join(["lib", web, "controllers", "confirmation_controller.ex"])},
      {:eex, "core/confirmation_html.ex",
       Path.join(["lib", web, "controllers", "confirmation_html.ex"])},
      {:eex, "core/reset_password_controller.ex",
       Path.join(["lib", web, "controllers", "reset_password_controller.ex"])},
      {:eex, "core/reset_password_html.ex",
       Path.join(["lib", web, "controllers", "reset_password_html.ex"])},

      # Phase 4: session management + sudo
      {:eex, "core/user_session.ex", Path.join(["lib", otp_app, ctx, "user_session.ex"])},
      {:eex, "core/sudo_controller.ex",
       Path.join(["lib", web, "controllers", "auth", "sudo_controller.ex"])},
      {:eex, "core/sudo_html.ex", Path.join(["lib", web, "controllers", "auth", "sudo_html.ex"])},

      # Phase 6: MFA (always generated — gated at runtime by user opt-in)
      {:eex, "core/user_mfa_credential.ex",
       Path.join(["lib", otp_app, ctx, "user_mfa_credential.ex"])},
      {:eex, "core/user_backup_code.ex", Path.join(["lib", otp_app, ctx, "user_backup_code.ex"])},
      {:eex, "core/mfa_challenge_controller.ex",
       Path.join(["lib", web, "controllers", "mfa_challenge_controller.ex"])},
      {:eex, "core/mfa_challenge_html.ex",
       Path.join(["lib", web, "controllers", "mfa_challenge_html.ex"])},

      # Phase 9: audit schema (migration is in migrations/1)
      {:eex, "core/audit_event.ex", Path.join(["lib", otp_app, ctx, "audit_event.ex"])},

      # Phase 10.1: Encrypted.Binary passthrough stub
      {:eex, "core/encrypted.ex", Path.join(["lib", otp_app, ctx, "encrypted.ex"])},

      # Phase 10.1: Swoosh mailer wrapper (skipped if host already has one)
      {:eex, "core/mailer.ex", Path.join(["lib", otp_app, "mailer.ex"])}
    ]
  end

  defp ui_files(binding, true) do
    otp_app = otp_app_str(binding)
    web = "#{otp_app}_web"

    [
      # login_html.ex renders into session_html.ex — always present
      # (Phase 10.1.1 B9/D-12: login is a plain controller in every mode)
      {:eex, "core/login_html.ex", Path.join(["lib", web, "controllers", "session_html.ex"])},

      # LiveView pages
      {:eex, "core/registration_live.ex",
       Path.join(["lib", web, "live", "registration_live.ex"])},
      {:eex, "core/confirmation_live.ex",
       Path.join(["lib", web, "live", "confirmation_live.ex"])},
      {:eex, "core/reset_password_live.ex",
       Path.join(["lib", web, "live", "reset_password_live.ex"])},
      {:eex, "core/session_live.ex", Path.join(["lib", web, "live", "auth", "session_live.ex"])},
      {:eex, "core/mfa_challenge_live.ex",
       Path.join(["lib", web, "live", "mfa_challenge_live.ex"])},
      {:eex, "core/mfa_settings_live.ex",
       Path.join(["lib", web, "live", "mfa_settings_live.ex"])},
      {:eex, "core/settings_live.ex", Path.join(["lib", web, "live", "settings_live.ex"])},
      {:eex, "core/reactivation_live.ex", Path.join(["lib", web, "live", "reactivation_live.ex"])}
    ]
  end

  defp ui_files(binding, false) do
    otp_app = otp_app_str(binding)
    web = "#{otp_app}_web"

    [
      {:eex, "core/login_html.ex", Path.join(["lib", web, "controllers", "session_html.ex"])},
      {:eex, "core/registration_html.ex",
       Path.join(["lib", web, "controllers", "registration_html.ex"])},
      {:eex, "core/mfa_settings_html.ex",
       Path.join(["lib", web, "controllers", "mfa_settings_html.ex"])}
    ]
  end

  defp api_files(_binding, false), do: []

  defp api_files(binding, true) do
    otp_app = otp_app_str(binding)
    ctx = context_underscore(binding)
    web = "#{otp_app}_web"

    [
      {:eex, "core/user_api_token.ex", Path.join(["lib", otp_app, ctx, "user_api_token.ex"])},
      {:eex, "core/api_token_controller.ex",
       Path.join(["lib", web, "controllers", "api_token_controller.ex"])}
    ]
  end

  defp jwt_files(_binding, false), do: []

  defp jwt_files(binding, true) do
    otp_app = otp_app_str(binding)
    web = "#{otp_app}_web"

    [
      {:eex, "core/token_controller.ex",
       Path.join(["lib", web, "controllers", "token_controller.ex"])}
    ]
  end

  # ──────────────────────────────────────────────────────────────────────────
  # injections/1 helpers
  #
  # These %Injection{} records describe the router/config/runtime.exs edits
  # currently emitted inline by `lib/mix/tasks/sigra.install.ex:inject_into_files/2`.
  # The walker (Wave 4) will pass each record to `Sigra.Install.Injector.apply/2`.
  # ──────────────────────────────────────────────────────────────────────────

  defp router_injection(otp_app, web_module, live?) do
    live_routes =
      if live? do
        "\n        live \"/register\", RegistrationLive\n"
      else
        """

                get "/register", RegistrationController, :new
                post "/register", RegistrationController, :create
        """
      end

    confirmation_routes =
      if live? do
        """

                live "/confirm", ConfirmationLive
                live "/confirm/:token", ConfirmationLive, :confirm
        """
      else
        """

                get "/confirm", ConfirmationController, :new
                post "/confirm", ConfirmationController, :create
                get "/confirm/:token", ConfirmationController, :confirm
                post "/confirm/resend", ConfirmationController, :resend
        """
      end

    reset_routes =
      if live? do
        """

                live "/reset-password", ResetPasswordLive
                live "/reset-password/:token", ResetPasswordLive, :edit
        """
      else
        """

                get "/reset-password", ResetPasswordController, :new
                post "/reset-password", ResetPasswordController, :create
                get "/reset-password/:token", ResetPasswordController, :edit
                put "/reset-password/:token", ResetPasswordController, :update
        """
      end

    session_management_routes =
      if live? do
        "\n        live \"/sessions\", Auth.SessionLive, :index\n"
      else
        ""
      end

    sudo_routes = """

          get "/sudo", Auth.SudoController, :new
          post "/sudo", Auth.SudoController, :create
    """

    mfa_challenge_routes =
      if live? do
        "\n        live \"/mfa\", MFAChallengeLive\n"
      else
        """

                get "/mfa", MFAChallengeController, :new
                post "/mfa", MFAChallengeController, :create
        """
      end

    mfa_settings_routes =
      if live? do
        "\n        live \"/settings/mfa\", MFASettingsLive\n"
      else
        ""
      end

    account_lifecycle_routes =
      if live? do
        """

                live "/settings", SettingsLive, :edit
                live "/reactivation", ReactivationLive
        """
      else
        ""
      end

    content = """
      # Sigra authentication
      import #{web_module}.UserAuth

      pipeline :require_authenticated do
        plug :require_authenticated_user
        plug :require_mfa
      end

      # MFA challenge (accessible with mfa_pending sessions, D-24)
      scope "/users", #{web_module} do
        pipe_through [:browser]
    #{mfa_challenge_routes}
      end

      scope "/users", #{web_module} do
        pipe_through [:browser, :redirect_if_user_is_authenticated]

        # Phase 10.1.1 B9: login page is a plain controller, not a LiveView.
        get "/log_in", SessionController, :new
    #{live_routes}
        post "/log_in", SessionController, :create
        get "/log_in/:token", SessionController, :magic_link
    #{confirmation_routes}
    #{reset_routes}
      end

      scope "/users", #{web_module} do
        pipe_through [:browser, :require_authenticated]

        delete "/log_out", SessionController, :delete
    #{session_management_routes}#{sudo_routes}#{mfa_settings_routes}#{account_lifecycle_routes}
      end
    """

    %Injection{
      target: Path.join(["lib", "#{otp_app}_web", "router.ex"]),
      marker: "# Sigra authentication",
      anchor: :before_last_end,
      content: content
    }
  end

  defp config_injection(otp_app, context_module, schema_alias, repo_module) do
    content = """

    # Sigra authentication
    config :#{otp_app}, :sigra,
      repo: #{repo_module},
      user_schema: #{context_module}.#{schema_alias}

    # Sigra worker runtime config (used by Oban workers)
    config :sigra,
      repo: #{repo_module},
      user_schema: #{context_module}.#{schema_alias},
      email_module: #{context_module}.Emails,
      mailer: #{context_module}.Mailer
    """

    %Injection{
      target: Path.join(["config", "config.exs"]),
      marker: "# Sigra authentication",
      anchor: :before_last_end,
      content: content
    }
  end

  defp test_config_injection do
    content = """

    # Sigra authentication
    # Speed up password hashing in tests
    config :argon2_elixir, t_cost: 1, m_cost: 8
    """

    %Injection{
      target: Path.join(["config", "test.exs"]),
      marker: "# Sigra authentication",
      anchor: :before_last_end,
      content: content
    }
  end

  defp conn_case_injection(web_module) do
    %Injection{
      target: Path.join(["test", "support", "conn_case.ex"]),
      marker: "#{web_module}.ConnCaseHelpers",
      anchor: :before_last_end,
      content: "      import #{web_module}.ConnCaseHelpers"
    }
  end

  defp api_injections(otp_app, web_module, jwt?) do
    api_router_content = """
      # Sigra API
      pipeline :api_authenticated do
        plug Sigra.Plug.FetchBearer
        plug Sigra.Plug.RequireAuthenticated,
          error_handler: #{web_module}.AuthErrorHandler
      end

      scope "/api", #{web_module} do
        pipe_through [:api, :api_authenticated]

        get "/tokens", APITokenController, :index
        post "/tokens", APITokenController, :create
        delete "/tokens/:id", APITokenController, :delete
        delete "/tokens", APITokenController, :delete_all
      end

      # # Mixed-mode pipeline (uncomment if you need endpoints that accept both session and bearer auth)
      # pipeline :api_or_browser do
      #   plug Sigra.Plug.FetchBearer
      #   plug Sigra.Plug.FetchSession
      # end
    """

    api_config_content = """

    # Sigra API token configuration
    config :#{otp_app}, :sigra_api,
      api_token: [
        prefix: "sigra_sk_",
        max_tokens_per_user: 25,
        default_scopes: ["read"]
      ]
    """

    jwt_config_tail =
      if jwt? do
        "\n  jwt: [\n    algorithm: \"HS256\",\n    access_ttl: 900,\n    refresh_ttl: 2_592_000\n  ]\n"
      else
        ""
      end

    router_target = Path.join(["lib", "#{otp_app}_web", "router.ex"])
    config_target = Path.join(["config", "config.exs"])

    api_list = [
      %Injection{
        target: router_target,
        marker: "# Sigra API",
        anchor: :before_last_end,
        content: api_router_content
      },
      %Injection{
        target: config_target,
        marker: "api_token:",
        anchor: :before_last_end,
        content: api_config_content <> jwt_config_tail
      }
    ]

    if jwt? do
      jwt_router_content = """
        # Sigra JWT
        scope "/api/auth", #{web_module} do
          pipe_through :api

          post "/token", TokenController, :create
          post "/token/refresh", TokenController, :refresh
          post "/token/mfa", TokenController, :mfa
          delete "/token", TokenController, :revoke
        end
      """

      api_list ++
        [
          %Injection{
            target: router_target,
            marker: "# Sigra JWT",
            anchor: :before_last_end,
            content: jwt_router_content
          }
        ]
    else
      api_list
    end
  end

  # ──────────────────────────────────────────────────────────────────────────
  # post_instructions/2 helpers
  # ──────────────────────────────────────────────────────────────────────────

  defp base_instructions(opts) do
    live_line =
      if Keyword.get(opts, :live, true) do
        "  LiveView pages were generated for login, registration, and session management.\n"
      else
        "  LiveView pages were NOT generated (--no-live). Use the SessionController for login.\n"
      end

    api_line =
      if Keyword.get(opts, :api, false) || Keyword.get(opts, :jwt, false) do
        "  API token endpoints were generated at /api/tokens.\n  Add the functions from auth_api_token.ex to your Auth context.\n"
      else
        ""
      end

    jwt_line =
      if Keyword.get(opts, :jwt, false) do
        "  JWT authentication endpoints were generated at /api/auth/token.\n"
      else
        ""
      end

    [
      """

      Sigra authentication has been installed!

      Next steps:

        1. Run the migration:

               mix ecto.migrate

        2. Add the authentication pipeline to your router:

               # In lib/your_app_web/router.ex
               # Routes were auto-injected if the router was found.

        3. Review the generated configuration in config/config.exs

        4. (Optional) Set up rate limiting with Hammer:

               # In your application.ex children list:
               {MyApp.RateLimit, clean_period: :timer.minutes(1)}

               # Create lib/my_app/rate_limit.ex:
               defmodule MyApp.RateLimit do
                 use Hammer, backend: :ets
               end

      """,
      live_line,
      "\n",
      api_line,
      jwt_line,
      "\n"
    ]
  end

  # Ported verbatim from `Mix.Tasks.Sigra.Install.inject_oban_queue/1`.
  # Detection-and-report over host-app config files. No side effects.
  defp oban_instructions(otp_app) do
    runtime_config = Path.join(["config", "runtime.exs"])
    config_path = Path.join(["config", "config.exs"])

    target =
      cond do
        File.exists?(runtime_config) && File.read!(runtime_config) =~ "Oban" -> runtime_config
        File.exists?(config_path) && File.read!(config_path) =~ "Oban" -> config_path
        true -> nil
      end

    if target do
      content = File.read!(target)

      if content =~ "sigra_mailer" do
        [[:yellow, "* already configured ", :reset, "Oban sigra_mailer queue\n"]]
      else
        [
          [:green, "* detected Oban config in ", :reset, target, "\n"],
          [
            :yellow,
            "  Add the sigra_mailer queue to your Oban config:\n",
            :reset,
            "    config :#{otp_app}, Oban, queues: [sigra_mailer: 10]\n"
          ]
        ]
      end
    else
      [
        [
          :yellow,
          "* Oban not detected. ",
          :reset,
          "Email delivery will use synchronous mode.\n",
          "  To enable async delivery, add Oban and configure the sigra_mailer queue.\n"
        ]
      ]
    end
  end

  # Ported verbatim from `Mix.Tasks.Sigra.Install.inject_swoosh_config/2`.
  # Detection-and-report + ONE file write (preserved for byte-identity
  # with the v1.0 monolith). The write is the only true side effect inside
  # `post_instructions/2` and is intentional — removing it would break the
  # golden-diff contract.
  defp swoosh_instructions(otp_app, app_module) do
    dev_config = Path.join(["config", "dev.exs"])

    if File.exists?(dev_config) do
      content = File.read!(dev_config)

      if content =~ "Swoosh" do
        [[:yellow, "* already configured ", :reset, "Swoosh in ", dev_config, "\n"]]
      else
        swoosh_block = """

        # Sigra email delivery (dev) — adapter is set on the raw Swoosh.Mailer
        # module, not the Sigra.Mailer behaviour wrapper.
        config :#{otp_app}, #{app_module}.Mailer,
          adapter: Swoosh.Adapters.Local

        config :swoosh, :api_client, false
        """

        File.write!(dev_config, content <> swoosh_block)
        [[:green, "* injecting ", :reset, "Swoosh dev config into ", dev_config, "\n"]]
      end
    else
      []
    end
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Binding accessors
  # ──────────────────────────────────────────────────────────────────────────

  defp fetch!(binding, key) do
    case Keyword.fetch(binding, key) do
      {:ok, value} -> value
      :error -> raise KeyError, key: key, term: binding
    end
  end

  defp otp_app_str(binding) do
    case fetch!(binding, :otp_app) do
      atom when is_atom(atom) -> Atom.to_string(atom)
      str when is_binary(str) -> str
    end
  end

  defp context_underscore(binding) do
    binding
    |> fetch!(:context_alias)
    |> Macro.underscore()
  end

  defp api_enabled?(binding) do
    opts = Keyword.get(binding, :opts, [])
    Keyword.get(opts, :api, false) || Keyword.get(opts, :jwt, false)
  end

  defp jwt_enabled?(binding) do
    Keyword.get(Keyword.get(binding, :opts, []), :jwt, false)
  end

  defp live_enabled?(binding) do
    Keyword.get(Keyword.get(binding, :opts, []), :live, true)
  end
end
