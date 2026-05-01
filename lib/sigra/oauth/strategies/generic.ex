defmodule Sigra.OAuth.Strategies.Generic do
  @moduledoc """
  Generic fallback strategy wrapper for any Assent strategy (D-13).

  Delegates to the Assent strategy module specified via the `:strategy` key
  in the provider config. This allows any Assent-supported provider to work
  with Sigra without a dedicated wrapper.

  ## Example

      # In config.exs:
      config :my_app, Sigra,
        oauth: [
          providers: [
            discord: [
              strategy: Assent.Strategy.Discord,
              client_id: "...",
              client_secret: "..."
            ]
          ]
        ]

  """

  @doc """
  Generates the authorization URL using the configured Assent strategy.

  Requires `:strategy` key in config pointing to an Assent strategy module.
  """
  @doc since: "0.1.0"
  @spec authorize_url(keyword()) :: {:ok, map()} | {:error, term()}
  def authorize_url(provider_config) do
    ensure_assent!()
    {strategy, config} = resolve_strategy(provider_config)
    strategy.authorize_url(config)
  end

  @doc """
  Handles the OAuth callback using the configured Assent strategy.

  Requires `:strategy` key in config pointing to an Assent strategy module.
  """
  @doc since: "0.1.0"
  @spec callback(keyword(), map(), map()) :: {:ok, map(), map()} | {:error, term()}
  def callback(provider_config, params, session_params) do
    ensure_assent!()
    {strategy, config} = resolve_strategy(provider_config)
    config = Keyword.put(config, :session_params, session_params)

    case strategy.callback(config, params) do
      {:ok, %{user: user, token: token}} -> {:ok, normalize_user(user), token}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Refreshes the OAuth access token using the configured Assent strategy.
  """
  @doc since: "0.1.21"
  @spec refresh(keyword(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def refresh(provider_config, refresh_token, _config \\ []) do
    ensure_assent!()
    {_strategy, config} = resolve_strategy(provider_config)

    # Use OAuth2.refresh_access_token directly since most custom strategies
    # either use standard OAuth2 or can handle this shape.
    case Assent.Strategy.OAuth2.refresh_access_token(config, %{"refresh_token" => refresh_token}) do
      {:ok, token} when is_map(token) -> {:ok, token}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Normalizes a generic provider user info map to a consistent shape.
  """
  @doc since: "0.1.0"
  @spec normalize_user(map()) :: map()
  def normalize_user(user) do
    sub = user["sub"] || to_string(user["id"] || "")

    %{
      "sub" => sub,
      "email" => user["email"],
      "name" => user["name"],
      "picture" => user["picture"] || user["avatar_url"],
      "email_verified" => user["email_verified"],
      "raw" => user
    }
  end

  @doc """
  Verifies that the Assent library is available.

  Raises a descriptive error if Assent is not loaded (D-14).
  Returns `:ok` if available.
  """
  @doc since: "0.1.0"
  @spec ensure_assent!() :: :ok
  def ensure_assent! do
    unless Code.ensure_loaded?(Assent) do
      raise "Assent is required for OAuth. Add {:assent, \"~> 0.3\"} to mix.exs and run: mix deps.get"
    end

    :ok
  end

  @spec resolve_strategy(keyword()) :: {module(), keyword()}
  defp resolve_strategy(provider_config) do
    case Keyword.fetch(provider_config, :strategy) do
      {:ok, strategy} ->
        config = Keyword.delete(provider_config, :strategy)
        {strategy, config}

      :error ->
        raise ArgumentError,
              "Generic OAuth strategy requires :strategy key in provider config. " <>
                "Example: [strategy: Assent.Strategy.Discord, client_id: \"...\"]"
    end
  end
end
