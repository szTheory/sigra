defmodule Sigra.Application do
  @moduledoc """
  OTP application callback for Sigra.

  Sigra itself does not start any long-lived processes — it is a library
  whose security primitives run inline in the host application. This
  callback exists so that one-shot startup diagnostics (configuration
  checks, missing optional-dep warnings) can run when the host app boots.

  Today it performs a single boot-time check: if the host has configured
  `config :sigra, :audit, retention_days: N` but does not have Oban in the
  dep tree, log a warning advising the inline fallback path
  (`Sigra.Audit.cleanup/1`). See Phase 9 decisions D-09, D-10, D-36.
  """

  use Application

  require Logger
  alias Sigra.OptionalDeps

  @impl Application
  def start(_type, _args) do
    maybe_warn_audit_cleanup_fallback()
    maybe_warn_missing_cookie_domain()
    verify_vault!()

    Supervisor.start_link([], strategy: :one_for_one, name: Sigra.Supervisor)
  end

  @doc false
  def maybe_warn_missing_cookie_domain do
    env = Sigra.Env.current()
    otp_app = Application.get_env(:sigra, :otp_app)

    cookie_domain =
      case otp_app && Application.get_env(otp_app, :sigra_config) do
        opts when is_list(opts) -> Keyword.get(opts, :cookie_domain)
        _ -> nil
      end

    maybe_warn_missing_cookie_domain(env, cookie_domain)
  end

  @doc false
  def maybe_warn_missing_cookie_domain(:prod, nil) do
    Logger.warning("""
    [Sigra] cookie_domain is not set in :prod.

    Sigra-managed cookies (remember-me, MFA trust) will be issued as host-only
    cookies. If you use subdomain auth (e.g., app.example.com + api.example.com),
    users will NOT stay signed in across subdomains.

    Set it in your runtime config:

        config :my_app, MyApp.Auth.Config,
          cookie_domain: System.get_env("COOKIE_DOMAIN")

    See guides/recipes/subdomain-auth.md for details. To silence this warning on
    a single-domain deployment, set `cookie_domain: ""` explicitly (not
    recommended) or ignore — host-only is the safer default for single-domain.
    """)

    :ok
  end

  def maybe_warn_missing_cookie_domain(_env, _cookie_domain), do: :ok

  @doc false
  def maybe_warn_audit_cleanup_fallback do
    retention = Application.get_env(:sigra, :audit, [])[:retention_days]
    maybe_warn_audit_cleanup_fallback(retention)
  end

  @doc false
  def maybe_warn_audit_cleanup_fallback(retention, dependency_loaded? \\ &Code.ensure_loaded?/1)
      when is_function(dependency_loaded?, 1) do
    oban_loaded? = dependency_loaded?.(Oban)

    cond do
      is_nil(retention) ->
        :ok

      oban_loaded? ->
        :ok

      true ->
        Logger.warning("""
        [Sigra.Audit] retention_days=#{inspect(retention)} is configured but Oban is not loaded.
        Audit log retention cleanup will not run automatically.
        Call Sigra.Audit.cleanup(repo: MyApp.Repo, audit_schema: MyApp.Accounts.AuditEvent, retention_days: #{retention})
        from your own scheduler, or add :oban to your mix.exs deps.
        """)

        :ok
    end
  end

  @doc false
  def compile_warning_rows(context) do
    OptionalDeps.feature_specs()
    |> Enum.filter(&(&1.compile_warning? == :when_enabled))
    |> Enum.map(&OptionalDeps.doctor_row(&1.feature, context))
    |> Enum.filter(&(&1.enabled? and not &1.loaded?))
  end

  defmacro warn_for_enabled_optional_deps!(context_ast) do
    {context, _binding} = Code.eval_quoted(context_ast, [], __CALLER__)
    rows = __MODULE__.compile_warning_rows(context)

    Enum.each(rows, fn row ->
      IO.warn(
        """
        [Sigra] compile-time optional dependency warning for #{row.feature}.
        Dependency: #{row.dependency} (#{row.spec})
        Evidence: #{row.evidence}
        #{row.remediation}
        """,
        Macro.Env.stacktrace(__CALLER__)
      )
    end)

    quote do
      :ok
    end
  end

  @doc false
  def verify_vault! do
    otp_app = Application.get_env(:sigra, :otp_app)

    host_sigra =
      case otp_app && Application.get_env(otp_app, :sigra_config) do
        opts when is_list(opts) -> opts
        _ -> []
      end

    verify_vault!(host_sigra)
  end

  @doc false
  def verify_vault!(host_sigra) when is_list(host_sigra) do
    if passkeys_enabled?(host_sigra) do
      case encrypted_binary_module(host_sigra) do
        nil ->
          :ok

        module ->
          Code.ensure_loaded?(module)

          if function_exported?(module, :__sigra_encryption_mode__, 0) and
               module.__sigra_encryption_mode__() == :stub do
            raise """
            [Sigra] passkeys are enabled but #{inspect(module)} is still the plaintext stub.

            Promote the app to a real Cloak vault before booting with passkeys:

                mix sigra.upgrade --yes

            Then set a Base64-encoded 32-byte CLOAK_KEY in your environment.
            """
          end
      end
    end

    :ok
  end

  defp passkeys_enabled?(host_sigra) do
    host_sigra
    |> Keyword.get(:passkeys, [])
    |> Keyword.get(:enabled, true)
  end

  defp encrypted_binary_module(host_sigra) do
    case Keyword.get(host_sigra, :user_schema) do
      module when is_atom(module) and not is_nil(module) ->
        module
        |> Module.split()
        |> Enum.drop(-1)
        |> Kernel.++(["Encrypted", "Binary"])
        |> Module.concat()

      _ ->
        nil
    end
  end
end
