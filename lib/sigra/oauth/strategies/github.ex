defmodule Sigra.OAuth.Strategies.Github do
  @moduledoc """
  Wraps `Assent.Strategy.Github` for Sigra OAuth integration.

  GitHub uses standard OAuth2. Default scopes: `user:email`.
  GitHub returns `id` as an integer, so `normalize_user/1` converts it to a string
  for consistent UID handling.
  """

  @default_scopes ["user:email"]

  @doc """
  Generates the authorization URL for GitHub OAuth.

  Delegates to `Assent.Strategy.Github.authorize_url/1` with merged config.
  """
  @doc since: "0.1.0"
  @spec authorize_url(keyword()) :: {:ok, map()} | {:error, term()}
  def authorize_url(provider_config) do
    ensure_assent!()
    config = build_config(provider_config)
    Assent.Strategy.Github.authorize_url(config)
  end

  @doc """
  Handles the OAuth callback from GitHub.

  Delegates to `Assent.Strategy.Github.callback/2` and normalizes the user info.
  """
  @doc since: "0.1.0"
  @spec callback(keyword(), map(), map()) :: {:ok, map(), map()} | {:error, term()}
  def callback(provider_config, params, session_params) do
    ensure_assent!()
    config = build_config(provider_config) |> Keyword.put(:session_params, session_params)

    case Assent.Strategy.Github.callback(config, params) do
      {:ok, %{user: user, token: token}} -> {:ok, normalize_user(user), token}
      {:error, error} -> {:error, error}
    end
  end

  @doc "Returns the default OAuth scopes for GitHub."
  @doc since: "0.1.0"
  @spec default_scopes() :: [String.t()]
  def default_scopes, do: @default_scopes

  @doc """
  Normalizes a GitHub user info map to a consistent shape.

  Falls back to `to_string(user["id"])` when `"sub"` is nil, since GitHub
  returns numeric IDs. Maps `"avatar_url"` to `"picture"` for consistency.
  """
  @doc since: "0.1.0"
  @spec normalize_user(map()) :: map()
  def normalize_user(user) do
    sub = user["sub"] || to_string(user["id"])

    %{
      "sub" => sub,
      "email" => user["email"],
      "name" => user["name"],
      "picture" => user["avatar_url"],
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
    |> Keyword.update!(:authorization_params, &Keyword.put_new(&1, :scope, Enum.join(scopes, " ")))
  end
end
