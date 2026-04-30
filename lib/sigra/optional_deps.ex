defmodule Sigra.OptionalDeps do
  @moduledoc """
  Authoritative registry for Sigra's optional dependency policy.

  Each feature entry carries enough metadata for runtime checks, doctor rows,
  and future compile-warning work without scattering dependency logic across
  the codebase.
  """

  alias Sigra.OptionalDeps.MissingDependencyError
  alias Sigra.Install.Features.Core, as: InstallCore

  @type feature :: :async_email | :bcrypt_migration | :jwt | :oauth | :rate_limit | :swoosh | :totp_qr

  @type feature_spec :: %{
          feature: feature(),
          dependency: atom(),
          dependency_spec: String.t(),
          dependency_modules: [module()],
          support_tier: :phase_95 | :advisory,
          enforced?: boolean(),
          doctor?: boolean(),
          compile_warning?: :when_enabled | :advisory_only | :never,
          remediation: String.t(),
          enabled?: (term() -> boolean()),
          evidence: (term() -> String.t())
        }

  @spec feature_specs() :: [feature_spec()]
  def feature_specs, do: Enum.map(feature_specs_map(), fn {_feature, spec} -> spec end)

  @spec feature_spec!(feature()) :: feature_spec()
  def feature_spec!(feature), do: Keyword.fetch!(feature_specs_map(), feature)

  @spec dependency_loaded?(feature() | feature_spec()) :: boolean()
  def dependency_loaded?(feature_or_spec) do
    feature_or_spec
    |> normalize_spec()
    |> dependency_loaded?(%{})
  end

  @spec feature_enabled?(feature() | feature_spec(), term()) :: boolean()
  def feature_enabled?(feature_or_spec, context \\ []) do
    spec = normalize_spec(feature_or_spec)
    context = normalize_context(context)
    spec.enabled?.(context.data)
  end

  @spec ensure_available!(feature(), term()) :: :ok
  def ensure_available!(feature, context \\ []) do
    spec = feature_spec!(feature)
    context = normalize_context(context)
    enabled? = spec.enabled?.(context.data)
    loaded? = dependency_loaded?(spec, context)

    if spec.enforced? and enabled? and not loaded? do
      raise MissingDependencyError,
        feature: spec.feature,
        dependency: spec.dependency,
        spec: spec.dependency_spec,
        evidence: spec.evidence.(context.data),
        remediation: spec.remediation
    end

    :ok
  end

  @spec doctor_row(feature(), term()) :: map()
  def doctor_row(feature, context \\ []) do
    spec = feature_spec!(feature)
    context = normalize_context(context)
    enabled? = spec.enabled?.(context.data)
    loaded? = dependency_loaded?(spec, context)

    %{
      feature: spec.feature,
      dependency: spec.dependency,
      spec: spec.dependency_spec,
      support_tier: spec.support_tier,
      enforced?: spec.enforced?,
      enabled?: enabled?,
      loaded?: loaded?,
      blocking?: spec.enforced? and enabled? and not loaded?,
      status: status_for(spec, enabled?, loaded?),
      evidence: spec.evidence.(context.data),
      remediation: spec.remediation
    }
  end

  defp normalize_spec(%{feature: _feature} = spec), do: spec
  defp normalize_spec(feature) when is_atom(feature), do: feature_spec!(feature)

  defp feature_specs_map do
    [
      async_email: %{
        feature: :async_email,
        dependency: :oban,
        dependency_spec: "~> 2.17",
        dependency_modules: [Oban],
        support_tier: :phase_95,
        enforced?: true,
        doctor?: true,
        compile_warning?: :when_enabled,
        remediation: InstallCore.optional_dependency_remediation(:async_email),
        enabled?: fn context -> async_email_enabled?(context) end,
        evidence: fn context -> async_email_evidence(context) end
      },
      bcrypt_migration: %{
        feature: :bcrypt_migration,
        dependency: :bcrypt_elixir,
        dependency_spec: "~> 3.3",
        dependency_modules: [Bcrypt],
        support_tier: :phase_95,
        enforced?: true,
        doctor?: true,
        compile_warning?: :never,
        remediation: InstallCore.optional_dependency_remediation(:bcrypt_migration),
        enabled?: fn context -> bcrypt_migration_enabled?(context) end,
        evidence: fn context -> bcrypt_migration_evidence(context) end
      },
      totp_qr: %{
        feature: :totp_qr,
        dependency: :eqrcode,
        dependency_spec: "~> 0.2.1",
        dependency_modules: [EQRCode],
        support_tier: :phase_95,
        enforced?: true,
        doctor?: true,
        compile_warning?: :when_enabled,
        remediation: InstallCore.optional_dependency_remediation(:totp_qr),
        enabled?: fn context -> totp_qr_enabled?(context) end,
        evidence: fn context -> totp_qr_evidence(context) end
      },
      jwt: %{
        feature: :jwt,
        dependency: :joken,
        dependency_spec: "~> 2.6",
        dependency_modules: [Joken],
        support_tier: :phase_95,
        enforced?: true,
        doctor?: true,
        compile_warning?: :when_enabled,
        remediation: InstallCore.optional_dependency_remediation(:jwt),
        enabled?: fn context -> jwt_enabled?(context) end,
        evidence: fn context -> jwt_evidence(context) end
      },
      rate_limit: %{
        feature: :rate_limit,
        dependency: :hammer,
        dependency_spec: "~> 7.3",
        dependency_modules: [Hammer],
        support_tier: :advisory,
        enforced?: false,
        doctor?: true,
        compile_warning?: :advisory_only,
        remediation: InstallCore.optional_dependency_remediation(:rate_limit),
        enabled?: fn context -> rate_limit_enabled?(context) end,
        evidence: fn context -> rate_limit_evidence(context) end
      },
      oauth: %{
        feature: :oauth,
        dependency: :assent,
        dependency_spec: "~> 0.3",
        dependency_modules: [Assent.Strategy.Google],
        support_tier: :advisory,
        enforced?: false,
        doctor?: true,
        compile_warning?: :advisory_only,
        remediation: InstallCore.optional_dependency_remediation(:oauth),
        enabled?: fn context -> oauth_enabled?(context) end,
        evidence: fn context -> oauth_evidence(context) end
      },
      swoosh: %{
        feature: :swoosh,
        dependency: :swoosh,
        dependency_spec: "~> 1.5",
        dependency_modules: [Swoosh.Email],
        support_tier: :advisory,
        enforced?: false,
        doctor?: true,
        compile_warning?: :advisory_only,
        remediation: InstallCore.optional_dependency_remediation(:swoosh),
        enabled?: fn context -> swoosh_enabled?(context) end,
        evidence: fn context -> swoosh_evidence(context) end
      }
    ]
  end

  defp normalize_context(%Sigra.Config{} = config), do: %{data: %{config: config}, loader: &default_loader/1}

  defp normalize_context(context) when is_list(context) do
    loader = Keyword.get(context, :dependency_loaded?, &default_loader/1)
    config = Keyword.get(context, :config)

    data =
      context
      |> Keyword.delete(:dependency_loaded?)
      |> Keyword.delete(:config)
      |> Enum.into(%{})
      |> maybe_put_config(config)

    %{data: data, loader: loader}
  end

  defp normalize_context(%{} = context), do: %{data: context, loader: &default_loader/1}
  defp normalize_context(context), do: %{data: %{value: context}, loader: &default_loader/1}

  defp maybe_put_config(data, nil), do: data
  defp maybe_put_config(data, config), do: Map.put(data, :config, config)

  defp dependency_loaded?(spec, %{loader: loader}), do: loader.(spec)
  defp dependency_loaded?(spec, _context), do: default_loader(spec)

  defp default_loader(spec) do
    Enum.any?(spec.dependency_modules, &Code.ensure_loaded?/1)
  end

  defp status_for(_spec, true, true), do: :ok
  defp status_for(spec, true, false) when spec.enforced?, do: :missing
  defp status_for(_spec, true, false), do: :advisory
  defp status_for(spec, false, _loaded?) when spec.enforced?, do: :inactive
  defp status_for(_spec, false, _loaded?), do: :advisory

  defp jwt_enabled?(context) do
    jwt_config =
      case Map.get(context, :jwt) do
        jwt when is_list(jwt) -> jwt
        _other -> config_value(context, :jwt, [])
      end

    Keyword.get(jwt_config, :enabled, false)
  end

  defp jwt_evidence(context) do
    if jwt_enabled?(context) do
      if is_list(Map.get(context, :jwt)) do
        "jwt[:enabled] == true"
      else
        "config.jwt[:enabled] == true"
      end
    else
      if is_list(Map.get(context, :jwt)) do
        "jwt[:enabled] != true"
      else
        "config.jwt[:enabled] != true"
      end
    end
  end

  defp async_email_enabled?(context) do
    Map.get(context, :delivery_mode) == :async or
      context
      |> config_value(:email, [])
      |> Keyword.get(:delivery_mode) == :async
  end

  defp async_email_evidence(context) do
    if async_email_enabled?(context) do
      "delivery mode is explicitly :async"
    else
      "delivery mode is not :async"
    end
  end

  defp bcrypt_migration_enabled?(context) do
    case Map.get(context, :password_hash) do
      "$2" <> _rest -> true
      _other -> Map.get(context, :has_bcrypt_hash?, false)
    end
  end

  defp bcrypt_migration_evidence(context) do
    if bcrypt_migration_enabled?(context) do
      "bcrypt password verification was requested"
    else
      "no bcrypt password verification requested"
    end
  end

  defp totp_qr_enabled?(context) do
    Map.get(context, :mfa_enrollment) == :qr or Map.get(context, :render_qr?, false)
  end

  defp totp_qr_evidence(context) do
    if totp_qr_enabled?(context) do
      "MFA enrollment requested QR rendering"
    else
      "MFA enrollment did not request QR rendering"
    end
  end

  defp rate_limit_enabled?(context) do
    Map.get(context, :rate_limiter) == Sigra.RateLimiters.Hammer or
      context
      |> config_value(:rate_limiting, [])
      |> Keyword.get(:limiter) == Sigra.RateLimiters.Hammer
  end

  defp rate_limit_evidence(context) do
    if rate_limit_enabled?(context) do
      "rate limiting explicitly configured with Sigra.RateLimiters.Hammer"
    else
      "rate limiting not explicitly configured"
    end
  end

  defp oauth_enabled?(context) do
    Map.get(context, :oauth_enabled?, false) or
      context
      |> config_value(:oauth, [])
      |> Keyword.get(:providers, [])
      |> Enum.any?()
  end

  defp oauth_evidence(context) do
    if oauth_enabled?(context) do
      "OAuth providers are configured"
    else
      "OAuth providers are not explicitly configured"
    end
  end

  defp swoosh_enabled?(context) do
    Map.get(context, :mailer_backend) == :swoosh or Map.get(context, :email_provider) == :swoosh
  end

  defp swoosh_evidence(context) do
    if swoosh_enabled?(context) do
      "Swoosh-backed delivery is configured"
    else
      "Swoosh-backed delivery is not explicitly configured"
    end
  end

  defp config_value(%{config: %Sigra.Config{} = config}, field, default), do: Map.get(config, field, default)
  defp config_value(_context, _field, default), do: default
end
