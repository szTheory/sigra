defmodule Sigra.OAuth.Strategies.Google do
  @moduledoc """
  Wraps `Assent.Strategy.Google` for Sigra OAuth integration.

  Google uses OIDC with auto-discovery from `.well-known/openid-configuration` (D-18).
  Default scopes: `openid`, `email`, `profile`.
  """

  @default_scopes ["openid", "email", "profile"]

  @doc """
  Generates the authorization URL for Google OAuth.

  Delegates to `Assent.Strategy.Google`'s `authorize_url` function with merged config.
  """
  @doc since: "0.1.0"
  @spec authorize_url(keyword()) :: {:ok, map()} | {:error, term()}
  def authorize_url(provider_config) do
    ensure_assent!()
    config = build_config(provider_config)
    Assent.Strategy.Google.authorize_url(config)
  end

  @doc """
  Handles the OAuth callback from Google.

  Delegates to `Assent.Strategy.Google`'s `callback` function and normalizes the user info.
  """
  @doc since: "0.1.0"
  @spec callback(keyword(), map(), map()) :: {:ok, map(), map()} | {:error, term()}
  def callback(provider_config, params, session_params) do
    ensure_assent!()
    config = build_config(provider_config) |> Keyword.put(:session_params, session_params)

    case Assent.Strategy.Google.callback(config, params) do
      {:ok, %{user: user, token: token}} -> {:ok, normalize_user(user), token}
      {:error, error} -> {:error, error}
    end
  end

  @doc "Returns the default OAuth scopes for Google."
  @doc since: "0.1.0"
  @spec default_scopes() :: [String.t()]
  def default_scopes, do: @default_scopes

  @doc """
  Normalizes a Google user info map to a consistent shape.

  Returns a map with keys: `"sub"`, `"email"`, `"name"`, `"picture"`,
  `"email_verified"`, and `"raw"` (the original response).
  """
  @doc since: "0.1.0"
  @spec normalize_user(map()) :: map()
  def normalize_user(user) do
    %{
      "sub" => user["sub"],
      "email" => user["email"],
      "name" => user["name"],
      "picture" => user["picture"],
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

  defp build_config(provider_config) do
    scopes = Keyword.get(provider_config, :scopes, @default_scopes)

    provider_config
    |> Keyword.put_new(:authorization_params, [])
    |> Keyword.update!(
      :authorization_params,
      &Keyword.put_new(&1, :scope, Enum.join(scopes, " "))
    )
  end
end
