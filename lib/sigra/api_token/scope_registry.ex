defmodule Sigra.APIToken.ScopeRegistry do
  @moduledoc """
  Scope validation and registry for API tokens.

  Scopes follow a `resource:action` format (e.g., `"profile:read"`,
  `"sessions:write"`) and are validated against a registry of built-in
  and custom scopes.

  ## Built-in Scopes

  #{Enum.map_join(["profile:read", "profile:write", "sessions:read", "sessions:write", "api_tokens:read", "api_tokens:write", "mfa:read", "mfa:write"], "\n", &"  * `#{&1}`")}

  ## Custom Scopes

  Register custom scopes via the `:api_token` config:

      Sigra.Config.new!(
        repo: MyApp.Repo,
        user_schema: MyApp.User,
        api_token: [custom_scopes: ["billing:read", "billing:write"]]
      )

  ## Wildcard

  The special scope `"*"` grants access to all resources and actions.
  """

  @built_in_scopes [
    "profile:read",
    "profile:write",
    "sessions:read",
    "sessions:write",
    "api_tokens:read",
    "api_tokens:write",
    "mfa:read",
    "mfa:write"
  ]

  @scope_format ~r/^[a-z_]+:[a-z_]+$/

  @doc """
  Returns true if the scope string is valid format.

  Valid formats:
  - `"resource:action"` where both parts are lowercase letters and underscores
  - `"*"` wildcard scope

  ## Examples

      iex> Sigra.APIToken.ScopeRegistry.valid_format?("profile:read")
      true

      iex> Sigra.APIToken.ScopeRegistry.valid_format?("PROFILE:READ")
      false

      iex> Sigra.APIToken.ScopeRegistry.valid_format?("*")
      true

  """
  @doc since: "0.7.0"
  @spec valid_format?(String.t()) :: boolean()
  def valid_format?("*"), do: true
  def valid_format?(scope) when is_binary(scope), do: Regex.match?(@scope_format, scope)

  @doc """
  Returns all registered scopes (built-in + custom).

  ## Examples

      iex> config = Sigra.Config.new!(repo: R, user_schema: U)
      iex> "profile:read" in Sigra.APIToken.ScopeRegistry.all_scopes(config)
      true

  """
  @doc since: "0.7.0"
  @spec all_scopes(Sigra.Config.t()) :: [String.t()]
  def all_scopes(%Sigra.Config{api_token: api_token}) do
    custom = Keyword.get(api_token, :custom_scopes, [])
    @built_in_scopes ++ custom
  end

  @doc """
  Validates a list of scopes against the registry.

  Returns `:ok` if all scopes are valid format and registered,
  or an error tuple describing the issue.

  ## Examples

      iex> config = Sigra.Config.new!(repo: R, user_schema: U)
      iex> Sigra.APIToken.ScopeRegistry.validate_scopes(config, ["profile:read"])
      :ok

      iex> Sigra.APIToken.ScopeRegistry.validate_scopes(config, [])
      {:error, :scopes_required}

  """
  @doc since: "0.7.0"
  @spec validate_scopes(Sigra.Config.t(), [String.t()]) ::
          :ok
          | {:error,
             :scopes_required
             | {:invalid_format, [String.t()]}
             | {:unregistered_scopes, [String.t()]}}
  def validate_scopes(_config, []), do: {:error, :scopes_required}

  def validate_scopes(config, scopes) when is_list(scopes) do
    invalid_format = Enum.reject(scopes, &valid_format?/1)

    if invalid_format != [] do
      {:error, {:invalid_format, invalid_format}}
    else
      registered = MapSet.new(all_scopes(config) ++ ["*"])
      unregistered = Enum.reject(scopes, &MapSet.member?(registered, &1))

      if unregistered == [] do
        :ok
      else
        {:error, {:unregistered_scopes, unregistered}}
      end
    end
  end
end
