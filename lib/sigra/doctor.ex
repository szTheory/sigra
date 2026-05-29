defmodule Sigra.Doctor do
  @moduledoc """
  Pure diagnostic module that builds Sigra's nine-feature optional-dependency
  matrix, validates boot-time wiring for configured features, and returns a
  structured diagnosis result.

  ## Design

  `Sigra.Doctor` is a pure library module — no IO calls, no Mix.Task dependency,
  no side effects. All diagnostic logic lives here so that security-sensitive
  checks ship via `mix deps.update` rather than being locked in a generator or
  task layer.

  The Mix task `Mix.Tasks.Sigra.Doctor` is a thin formatter + exit shell that
  calls `run/1` here, formats the structured result, and handles exit codes. All
  IO formatting stays in the task.

  ## Injection Seam (D-04)

  `diagnose/1` accepts injected inputs so the matrix and wiring logic are
  unit-testable without toggling the ambient dep tree (since `Code.ensure_loaded?`
  cannot be toggled per-test). The injection keys are:

  - `:predicates` — a map of predicate name atom → boolean, overriding individual
    `Sigra.OptionalDeps` calls.
  - `:host_sigra` — the raw keyword config list (same shape as the two-hop config
    read in `Sigra.Application`).
  - `:oban_running` — a boolean override for both async-email and audit-forwarder
    Oban supervision checks (replaces the real internal `oban_running?/1` call in
    `Sigra.Audit.Forwarders`). When not provided, the real function is called.
  - `:module_loaded?` — a `(module :: atom() -> boolean())` function override for
    `Code.ensure_loaded?/1` used in the D-09 #4 forwarder-module-loaded check.
    Allows deterministic unit-testing of the not-loaded branch without relying on
    a module name that happens not to be defined in the runtime.

  When injection keys are absent, the real functions are called:
  - `Sigra.OptionalDeps.*_available?/0` for each of the nine availability predicates
  - `Sigra.OptionalDeps.encryption_active?/1` for encryption posture
  - the internal `oban_running?/1` in `Sigra.Audit.Forwarders` for supervised-Oban checks
  - `Code.ensure_loaded?/1` for dynamic forwarder-module existence checks

  ## OptionalDeps SOT (D-06)

  This module consumes `Sigra.OptionalDeps` predicates directly and must NOT call
  `Code.ensure_loaded?` itself to re-implement those checks — preserving the single
  source of truth established in Phase 137.

  The one narrow exception is the dynamic forwarder-module check: configured
  forwarder modules are host-provided dynamic atoms that cannot be listed in
  `OptionalDeps`, so `Code.ensure_loaded?(module)` is called directly for that
  check (mirrors the internal `attach_forwarders/0` in `Sigra.Application`).

  ## Deliberate Omissions (D-08)

  This module deliberately does NOT call:

  - the internal `verify_vault!/1` in `Sigra.Application` — it raises, which would abort the report before
    the full matrix prints.
  - the internal `attach_forwarders/0` in `Sigra.Application` — it raises `ArgumentError` on
    async-without-Oban, which would abort.

  Instead, doctor uses the non-raising mirrors: `Sigra.OptionalDeps.encryption_active?/1`
  and the internal `oban_running?/1` in `Sigra.Audit.Forwarders`.
  """

  # Feature definition struct (internal — not part of public API)
  @type feature_row :: %{
          feature: atom(),
          deps: [String.t()],
          state: :missing | :available | :loaded_active | :configured_but_missing,
          hint: String.t()
        }

  @type diagnosis :: %{
          rows: [feature_row()],
          wiring: [String.t()],
          verdict: :ok | :fail
        }

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Diagnoses the optional-dependency wiring for all nine Sigra features.

  Returns a structured map with:

  - `:rows` — list of nine feature row maps, each with `:feature`, `:deps`,
    `:state`, and `:hint` keys.
  - `:wiring` — list of wiring check failure strings (empty when all wiring is OK).
  - `:verdict` — `:ok` when no D-09 hard-fail conditions are present; `:fail`
    when any configured feature has broken wiring.

  ## Injection Options (for testing; all optional)

  - `:predicates` — map of predicate atom → boolean. Keys: `:oban`, `:bcrypt`,
    `:eqrcode`, `:threadline`, `:assent`, `:swoosh`, `:joken`, `:hammer`, `:req`,
    `:encryption_active`.
  - `:host_sigra` — raw keyword list of host application Sigra config.
  - `:oban_running` — boolean override for the Oban supervision check.
  - `:module_loaded?` — a `(module :: atom() -> boolean())` function override for
    `Code.ensure_loaded?/1` used in the D-09 #4 forwarder-module-loaded check.
    Allows deterministic unit-testing of the not-loaded branch without relying on
    a module name that happens not to be defined.
  """
  @spec diagnose(keyword()) :: diagnosis()
  def diagnose(opts \\ []) do
    predicates = Keyword.get(opts, :predicates, nil)
    host_sigra = resolve_host_sigra(opts)
    oban_running_override = Keyword.get(opts, :oban_running, nil)
    module_loaded_override = Keyword.get(opts, :module_loaded?, nil)

    resolved = resolve_predicates(predicates, host_sigra)
    oban_running = resolve_oban_running(oban_running_override)
    module_loaded? = resolve_module_loaded(module_loaded_override)

    {rows, wiring_failures, has_hard_fail} =
      build_matrix(resolved, host_sigra, oban_running, module_loaded?)

    verdict = if has_hard_fail, do: :fail, else: :ok

    %{
      rows: rows,
      wiring: wiring_failures,
      verdict: verdict
    }
  end

  @doc """
  Runs the diagnostic and returns the same structured map as `diagnose/1`.

  This is the entrypoint called by `Mix.Tasks.Sigra.Doctor`. All IO formatting
  and exit logic lives in the Mix task, not here.

  Accepts the same injection options as `diagnose/1`, plus:

  - `:quiet` — boolean; when `true`, hints are omitted from the returned rows
    (the Mix task uses this to tune output verbosity). The verdict and states are
    always returned regardless of `:quiet`.
  """
  @spec run(keyword()) :: diagnosis()
  def run(opts \\ []) do
    diagnose(opts)
  end

  # ---------------------------------------------------------------------------
  # Config resolution
  # ---------------------------------------------------------------------------

  defp resolve_host_sigra(opts) do
    case Keyword.fetch(opts, :host_sigra) do
      {:ok, host_sigra} ->
        host_sigra

      :error ->
        # Two-hop config read: mirrors application.ex lines 34-37
        otp_app = Application.get_env(:sigra, :otp_app)

        case otp_app && Application.get_env(otp_app, :sigra_config) do
          config when is_list(config) -> config
          _ -> []
        end
    end
  end

  defp resolve_predicates(nil, host_sigra) do
    %{
      oban: Sigra.OptionalDeps.oban_available?(),
      bcrypt: Sigra.OptionalDeps.bcrypt_available?(),
      eqrcode: Sigra.OptionalDeps.eqrcode_available?(),
      threadline: Sigra.OptionalDeps.threadline_available?(),
      assent: Sigra.OptionalDeps.assent_available?(),
      swoosh: Sigra.OptionalDeps.swoosh_available?(),
      joken: Sigra.OptionalDeps.joken_available?(),
      hammer: Sigra.OptionalDeps.hammer_available?(),
      req: Sigra.OptionalDeps.req_available?(),
      encryption_active: Sigra.OptionalDeps.encryption_active?(host_sigra)
    }
  end

  defp resolve_predicates(predicates, _host_sigra) when is_map(predicates) do
    predicates
  end

  defp resolve_oban_running(nil) do
    Sigra.Audit.Forwarders.oban_running?([])
  end

  defp resolve_oban_running(override) when is_boolean(override) do
    override
  end

  defp resolve_module_loaded(nil), do: &Code.ensure_loaded?/1
  defp resolve_module_loaded(f) when is_function(f, 1), do: f

  # ---------------------------------------------------------------------------
  # Matrix builder
  # ---------------------------------------------------------------------------

  defp build_matrix(preds, host_sigra, oban_running, module_loaded?) do
    # Build all nine feature rows; track wiring failures and hard-fail verdict
    {rows, wiring_failures, hard_fail} =
      feature_definitions()
      |> Enum.reduce({[], [], false}, fn feature_def, {rows_acc, wiring_acc, fail_acc} ->
        {row, wiring_msgs, is_hard_fail} =
          evaluate_feature(feature_def, preds, host_sigra, oban_running, module_loaded?)

        {
          [row | rows_acc],
          wiring_acc ++ wiring_msgs,
          fail_acc or is_hard_fail
        }
      end)

    {Enum.reverse(rows), wiring_failures, hard_fail}
  end

  # Returns a list of feature definition maps in D-05 stable order
  defp feature_definitions do
    [
      %{
        feature: :totp_mfa,
        deps: ["eqrcode"],
        availability_keys: [:eqrcode],
        configured?: &totp_configured?/1,
        hard_fail?: fn _preds, _host, _oban, _module_loaded? -> false end,
        hint_missing:
          ~s(Add `{:eqrcode, "~> 0.1"}` to mix.exs deps to enable TOTP QR code generation.),
        hint_available:
          ~s(EQRCode loaded. Enable TOTP/MFA in your sigra_config: `mfa: [enabled: true]`.),
        hint_active: ~s(TOTP/MFA is active. EQRCode loaded and MFA enabled in config.),
        hint_broken:
          ~s(MFA is configured but EQRCode is missing. Add `{:eqrcode, "~> 0.1"}` to mix.exs.)
      },
      %{
        feature: :password_migration,
        deps: ["bcrypt_elixir"],
        availability_keys: [:bcrypt],
        configured?: &bcrypt_configured?/1,
        hard_fail?: fn _preds, _host, _oban, _module_loaded? -> false end,
        hint_missing:
          ~s(Add `{:bcrypt_elixir, "~> 3.0"}` to mix.exs deps to enable transparent bcrypt→argon2id hash migration.),
        hint_available:
          ~s(Bcrypt loaded. Transparent hash migration path is available for users with legacy bcrypt passwords.),
        hint_active:
          ~s(Password migration active. Bcrypt loaded — legacy passwords will be re-hashed to Argon2id on login.),
        hint_broken:
          ~s(Bcrypt hash migration is implied but bcrypt_elixir is not loaded. Add `{:bcrypt_elixir, "~> 3.0"}` to mix.exs.)
      },
      %{
        feature: :oauth,
        deps: ["assent"],
        availability_keys: [:assent],
        configured?: &oauth_configured?/1,
        hard_fail?: fn _preds, _host, _oban, _module_loaded? -> false end,
        hint_missing:
          ~s(Add `{:assent, "~> 0.3"}` to mix.exs deps to enable OAuth/OIDC/social login.),
        hint_available:
          ~s(Assent loaded. Configure providers in sigra_config: `oauth: [providers: [google: [...]]]`.),
        hint_active:
          ~s(OAuth active. Assent loaded and OAuth providers configured.),
        hint_broken:
          ~s(OAuth providers are configured but Assent is missing. Add `{:assent, "~> 0.3"}` to mix.exs.)
      },
      %{
        feature: :rate_limiting,
        deps: ["hammer"],
        availability_keys: [:hammer],
        configured?: &rate_limiting_configured?/1,
        hard_fail?: fn _preds, _host, _oban, _module_loaded? -> false end,
        hint_missing:
          ~s(Add `{:hammer, "~> 7.3"}` to mix.exs deps to enable rate limiting.),
        hint_available:
          ~s(Hammer loaded. Configure rate limiting in sigra_config: `rate_limiting: [limiter: MyApp.RateLimiter]`.),
        hint_active:
          ~s(Rate limiting active. Hammer loaded and limiter configured.),
        hint_broken:
          ~s(Rate limiting is configured but Hammer is missing. Add `{:hammer, "~> 7.3"}` to mix.exs.)
      },
      %{
        feature: :jwt,
        deps: ["joken"],
        availability_keys: [:joken],
        configured?: &jwt_configured?/1,
        hard_fail?: fn _preds, _host, _oban, _module_loaded? -> false end,
        hint_missing:
          ~s(Add `{:joken, "~> 2.6"}` to mix.exs deps to enable JWT signing/verification.),
        hint_available:
          ~s(Joken loaded. Enable JWT in sigra_config: `jwt: [enabled: true]`.),
        hint_active:
          ~s(JWT active. Joken loaded and jwt: [enabled: true] in config.),
        hint_broken:
          ~s(JWT is enabled in config but Joken is missing. Add `{:joken, "~> 2.6"}` to mix.exs.)
      },
      %{
        feature: :async_email,
        deps: ["swoosh", "oban"],
        availability_keys: [:swoosh, :oban],
        configured?: &async_email_configured?/1,
        hard_fail?: &async_email_hard_fail?/4,
        hint_missing:
          ~s(Add `{:swoosh, "~> 1.5"}` and `{:oban, "~> 2.17"}` to mix.exs deps to enable async email delivery.),
        hint_available:
          ~s(Swoosh/Oban partially loaded. Set `email: [delivery_mode: :async]` in sigra_config to enable async email.),
        hint_active:
          ~s(Async email active. Swoosh and Oban loaded, delivery_mode: :async configured.),
        hint_broken:
          ~s(Async email is configured but Swoosh/Oban is missing or Oban is not supervised. Add deps and ensure Oban is in your supervision tree.)
      },
      %{
        feature: :audit_forwarding,
        deps: ["threadline", "oban"],
        availability_keys: [:threadline, :oban],
        configured?: &audit_forwarding_configured?/1,
        hard_fail?: &audit_forwarding_hard_fail?/4,
        hint_missing:
          ~s(Add `{:threadline, "~> 0.5"}` to mix.exs deps and configure `audit: [forwarders: [...]]` in sigra_config.),
        hint_available:
          ~s(Threadline/Oban partially loaded. Configure `audit: [forwarders: []]` in sigra_config to enable audit forwarding.),
        hint_active:
          ~s(Audit forwarding active. Forwarder deps loaded, forwarders configured, and Oban supervised.),
        hint_broken:
          ~s(Audit forwarding is configured but either: a forwarder module is not loaded, dispatch: :async is set but Oban is not supervised, or a dep is missing. Check forwarder config and ensure Oban is in your supervision tree.)
      },
      %{
        feature: :encryption,
        deps: ["cloak_ecto"],
        availability_keys: [:encryption_active],
        configured?: &encryption_configured?/1,
        hard_fail?: &encryption_hard_fail?/4,
        hint_missing:
          ~s(Add `{:cloak_ecto, "~> 1.3"}` to mix.exs and run `mix sigra.upgrade` to enable at-rest encryption.),
        hint_available:
          ~s(Encryption vault configured. Enable passkeys in sigra_config to activate.),
        hint_active:
          ~s(Encryption active. Vault configured and passkeys enabled.),
        hint_broken:
          "Encryption is required (passkeys enabled) but the encryption module is the plaintext stub. Run 'mix sigra.upgrade' and set CLOAK_KEY."
      },
      %{
        feature: :enterprise_connections,
        deps: ["req"],
        availability_keys: [:req],
        configured?: &enterprise_connections_configured?/1,
        hard_fail?: fn _preds, _host, _oban, _module_loaded? -> false end,
        hint_missing:
          ~s(Add `{:req, "~> 0.5"}` to mix.exs deps to enable enterprise connection validation.),
        hint_available:
          ~s(Req loaded. Configure `enterprise_connections: [...]` in sigra_config to enable.),
        hint_active:
          ~s(Enterprise connections active. Req loaded and enterprise_connections configured.),
        hint_broken:
          ~s(Enterprise connections are configured but Req is missing. Add `{:req, "~> 0.5"}` to mix.exs.)
      }
    ]
  end

  # Evaluates one feature and returns {row_map, wiring_failure_strings, is_hard_fail}
  defp evaluate_feature(feature_def, preds, host_sigra, oban_running, module_loaded?) do
    %{
      feature: feature,
      deps: deps,
      availability_keys: avail_keys,
      configured?: configured_fn,
      hard_fail?: hard_fail_fn
    } = feature_def

    any_dep_available = Enum.any?(avail_keys, fn key -> Map.get(preds, key, false) end)
    all_deps_available = Enum.all?(avail_keys, fn key -> Map.get(preds, key, false) end)
    configured = configured_fn.(host_sigra)
    is_hard_fail = hard_fail_fn.(preds, host_sigra, oban_running, module_loaded?)

    {state, hint} =
      cond do
        # D-09 hard-fail conditions override state to :configured_but_missing
        is_hard_fail ->
          {:configured_but_missing, feature_def.hint_broken}

        configured and all_deps_available ->
          {:loaded_active, feature_def.hint_active}

        configured and not any_dep_available ->
          {:configured_but_missing, feature_def.hint_broken}

        configured and any_dep_available and not all_deps_available ->
          # Some deps available, some not — configured with partial deps
          {:configured_but_missing, feature_def.hint_broken}

        not configured and any_dep_available ->
          {:available, feature_def.hint_available}

        true ->
          # not configured and no deps available
          {:missing, feature_def.hint_missing}
      end

    wiring_msg =
      if is_hard_fail do
        ["[#{feature}] #{hint}"]
      else
        []
      end

    row = %{
      feature: feature,
      deps: deps,
      state: state,
      hint: hint
    }

    {row, wiring_msg, is_hard_fail}
  end

  # ---------------------------------------------------------------------------
  # "Configured" predicates (read from host_sigra keyword list)
  # ---------------------------------------------------------------------------

  defp totp_configured?(host_sigra) do
    # Check :enabled sub-key, consistent with how other features gate on a switch.
    # mfa: [enabled: false, totp_drift_steps: 2] is a non-empty list with MFA disabled.
    mfa = sub(host_sigra, :mfa)
    is_list(mfa) and mfa != [] and Keyword.get(mfa, :enabled, true)
  end

  # password_migration: bcrypt presence doubles as configured indicator;
  # bcrypt in use implies the migration is configured. No explicit config flag.
  defp bcrypt_configured?(_host_sigra) do
    false
  end

  defp oauth_configured?(host_sigra) do
    # Mirror Sigra.Config.oauth_enabled?/1: honor the :enabled master switch.
    # A host with oauth: [enabled: false, providers: [...]] has OAuth intentionally off.
    oauth = sub(host_sigra, :oauth)
    Keyword.get(oauth, :enabled, true) and Keyword.get(oauth, :providers, []) != []
  end

  defp rate_limiting_configured?(host_sigra) do
    limiter = sub(host_sigra, :rate_limiting) |> Keyword.get(:limiter)
    not is_nil(limiter)
  end

  defp jwt_configured?(host_sigra) do
    sub(host_sigra, :jwt) |> Keyword.get(:enabled, false)
  end

  defp async_email_configured?(host_sigra) do
    sub(host_sigra, :email) |> Keyword.get(:delivery_mode) == :async
  end

  defp audit_forwarding_configured?(host_sigra) do
    forwarders = sub(host_sigra, :audit) |> Keyword.get(:forwarders, [])
    is_list(forwarders) and forwarders != []
  end

  defp encryption_configured?(host_sigra) do
    # Mirror Sigra.Application.verify_vault!/1: encryption is required only when
    # passkeys are enabled AND a user_schema is configured (verify_vault! short-circuits
    # to :ok when encrypted_binary_module/1 returns nil — i.e., no user_schema set).
    # Do not introduce divergent triggers (e.g. phantom :store_tokens key).
    # If OAuth-token-storage encryption becomes a genuine requirement, add the real
    # config key to Sigra.Config and verify_vault!/1 first, then mirror here.
    user_schema = Keyword.get(host_sigra, :user_schema)
    passkeys_enabled?(host_sigra) and not is_nil(user_schema)
  end

  defp enterprise_connections_configured?(host_sigra) do
    connections = sub(host_sigra, :enterprise_connections)
    is_list(connections) and connections != []
  end

  # ---------------------------------------------------------------------------
  # Sub-config helper (WR-05)
  # ---------------------------------------------------------------------------

  # Safely reads a sub-keyword-list from host_sigra. host_sigra is unvalidated
  # input (read from Application.get_env before NimbleOptions validation), so
  # type guarantees do not hold. Returns [] when key is absent or value is not
  # a keyword list (e.g. jwt: "true" instead of jwt: [enabled: true]).
  defp sub(host_sigra, key) do
    case Keyword.get(host_sigra, key, []) do
      l when is_list(l) -> l
      _ -> []
    end
  end

  # ---------------------------------------------------------------------------
  # Hard-fail predicates (D-09)
  # ---------------------------------------------------------------------------

  # D-09 #2: async email configured, Oban not supervised
  defp async_email_hard_fail?(_preds, host_sigra, oban_running, _module_loaded?) do
    async_email_configured?(host_sigra) and not oban_running
  end

  # D-09 #1 and #4: async forwarder without Oban OR forwarder module not loaded
  defp audit_forwarding_hard_fail?(_preds, host_sigra, oban_running, module_loaded?) do
    forwarders =
      sub(host_sigra, :audit)
      |> Keyword.get(:forwarders, [])

    Enum.any?(forwarders, fn
      forwarder_opts when is_list(forwarder_opts) ->
        module = Keyword.get(forwarder_opts, :module)
        dispatch = Keyword.get(forwarder_opts, :dispatch, :auto)

        # D-09 #4: forwarder module not loaded
        module_not_loaded = not is_nil(module) and not module_loaded?.(module)

        # D-09 #1: async dispatch but Oban not supervised
        async_without_oban = dispatch == :async and not oban_running

        module_not_loaded or async_without_oban

      _ ->
        # Malformed entry (e.g. :bad, or a map) is itself a misconfiguration — flag, don't crash.
        true
    end)
  end

  # D-09 #3: encryption-requiring feature is configured but encryption stub is active.
  # Hard-fail only when passkeys are enabled AND user_schema is set (matching verify_vault!/1
  # semantics — it short-circuits to :ok when encrypted_binary_module/1 returns nil).
  defp encryption_hard_fail?(preds, host_sigra, _oban_running, _module_loaded?) do
    encryption_required = encryption_configured?(host_sigra)
    encryption_active = Map.get(preds, :encryption_active, false)

    encryption_required and not encryption_active
  end

  # ---------------------------------------------------------------------------
  # Config helper predicates
  # ---------------------------------------------------------------------------

  defp passkeys_enabled?(host_sigra) do
    # Mirror Sigra.Application.passkeys_enabled?/1: absent :passkeys block defaults to
    # enabled: true (matching the config schema default and the install generator default).
    host_sigra
    |> Keyword.get(:passkeys, [])
    |> Keyword.get(:enabled, true)
  end
end
