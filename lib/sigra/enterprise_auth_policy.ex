defmodule Sigra.EnterpriseAuthPolicy do
  @moduledoc """
  Host-aware local-auth policy evaluation for enterprise SSO enforcement.
  """

  @type decision :: :allow | {:deny, atom(), map()}

  @doc false
  @spec password_login_allowed?(Sigra.Config.t() | keyword(), struct(), keyword()) :: decision()
  def password_login_allowed?(config_or_opts, user, opts \\ []) do
    evaluate(config_or_opts, user, opts, :password_login, :sso_required)
  end

  @doc false
  @spec password_reset_allowed?(Sigra.Config.t() | keyword(), struct(), keyword()) :: decision()
  def password_reset_allowed?(config_or_opts, user, opts \\ []) do
    evaluate(config_or_opts, user, opts, :password_reset, :password_reset_denied)
  end

  defp evaluate(config_or_opts, user, opts, field, denial_reason) do
    policy = resolve_policy(config_or_opts, user, opts)

    case Map.get(policy, field, :allow) do
      :deny -> {:deny, denial_reason, denial_metadata(policy, denial_reason)}
      _ -> :allow
    end
  end

  defp resolve_policy(%Sigra.Config{} = config, user, opts) do
    case config.organizations_module do
      module when is_atom(module) ->
        if function_exported?(module, :local_auth_policy_for, 2) do
          normalize_policy(module.local_auth_policy_for(user, opts))
        else
          %{}
        end

      _ ->
        %{}
    end
  end

  defp resolve_policy(opts_source, user, opts) when is_list(opts_source) do
    policy_source =
      Keyword.get(opts_source, :enterprise_auth_policy) ||
        Keyword.get(opts, :enterprise_auth_policy)

    case policy_source do
      module when is_atom(module) ->
        if function_exported?(module, :local_auth_policy_for, 2) do
          normalize_policy(module.local_auth_policy_for(user, opts))
        else
          %{}
        end

      fun when is_function(fun, 2) ->
        normalize_policy(fun.(user, opts))

      _ ->
        %{}
    end
  end

  defp normalize_policy(%{} = policy), do: policy
  defp normalize_policy(_), do: %{}

  defp denial_metadata(policy, denial_reason) do
    %{}
    |> maybe_put(:reason, denial_reason)
    |> maybe_put(:organization_id, Map.get(policy, :organization_id))
    |> maybe_put(:break_glass, Map.get(policy, :break_glass))
    |> maybe_put(:enforcement_mode, Map.get(policy, :enforcement_mode))
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
