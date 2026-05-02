defmodule Sigra.OAuth.Strategies.Facebook do
  @moduledoc """
  Wraps `Assent.Strategy.Facebook` for Sigra OAuth integration.

  Facebook uses standard OAuth2. Default scopes: `email`, `public_profile`.

  **Important:** Facebook does NOT verify email addresses (Pitfall 1 from RESEARCH.md).
  `normalize_user/1` always forces `"email_verified" => false` regardless of what
  Facebook returns. Downstream code must honor this flag and require email confirmation
  for Facebook-authenticated users.
  """

  @default_scopes ["email", "public_profile"]

  @doc """
  Generates the authorization URL for Facebook OAuth.

  Delegates to `Assent.Strategy.Facebook`'s `authorize_url` function with merged config.
  """
  @doc since: "0.1.0"
  @spec authorize_url(keyword()) :: {:ok, map()} | {:error, term()}
  def authorize_url(provider_config) do
    ensure_assent!()
    config = build_config(provider_config)
    Assent.Strategy.Facebook.authorize_url(config)
  end

  @doc """
  Handles the OAuth callback from Facebook.

  Delegates to `Assent.Strategy.Facebook`'s `callback` function and normalizes the user info.
  """
  @doc since: "0.1.0"
  @spec callback(keyword(), map(), map()) :: {:ok, map(), map()} | {:error, term()}
  def callback(provider_config, params, session_params) do
    ensure_assent!()
    config = build_config(provider_config) |> Keyword.put(:session_params, session_params)

    case Assent.Strategy.Facebook.callback(config, params) do
      {:ok, %{user: user, token: token}} -> {:ok, normalize_user(user), token}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Refreshes the OAuth access token.

  Delegates to `Assent.Strategy.OAuth2.refresh_access_token/2` with merged config.
  """
  @doc since: "0.1.21"
  @spec refresh(keyword(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def refresh(provider_config, refresh_token, _config \\ []) do
    ensure_assent!()
    config = build_config(provider_config)

    # Use apply/3 so the call is resolved at runtime — direct `M.f/a` calls
    # leak Assent's symbol table at compile time, which fails
    # `--warnings-as-errors` in path-dep installs that don't declare Assent.
    # `ensure_assent!/0` above already raises if Assent is absent at runtime.
    case apply(Assent.Strategy.OAuth2, :refresh_access_token, [
           config,
           %{"refresh_token" => refresh_token}
         ]) do
      {:ok, token} when is_map(token) -> {:ok, token}
      {:error, error} -> {:error, error}
    end
  end

  @doc "Returns the default OAuth scopes for Facebook."
  @doc since: "0.1.0"
  @spec default_scopes() :: [String.t()]
  def default_scopes, do: @default_scopes

  @doc """
  Normalizes a Facebook user info map to a consistent shape.

  Always forces `"email_verified" => false` because Facebook does not verify
  email addresses. Falls back to `to_string(user["id"])` when `"sub"` is nil.
  """
  @doc since: "0.1.0"
  @spec normalize_user(map()) :: map()
  def normalize_user(user) do
    sub = user["sub"] || to_string(user["id"])

    %{
      "sub" => sub,
      "email" => user["email"],
      "name" => user["name"],
      "picture" => user["picture"],
      "email_verified" => false,
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
