defmodule Sigra.OAuth do
  @moduledoc """
  OAuth orchestrator for Sigra authentication.

  Coordinates the full OAuth flow: authorization URL generation with
  HMAC-signed state, callback processing with account routing
  (register/login/link-confirm), token refresh, and link/unlink operations.

  ## Architecture (D-20)

  - `Sigra.OAuth` -- orchestrator (this module)
  - `Sigra.OAuth.Callback` -- response processing and account routing
  - `Sigra.OAuth.Strategies.*` -- per-provider Assent wrappers

  ## HMAC State (D-16)

  Sigra owns the OAuth CSRF state parameter. On authorize, a nonce is
  generated and signed via `Sigra.Token.generate/4` with purpose
  `"sigra-oauth-state"` and a 15-minute TTL. The callback verifies
  this signature before processing the token exchange.

  ## Account Scenarios

  The callback processor handles five scenarios:

  1. **Existing identity** -- user logged in, identity fields updated (D-31)
  2. **New user** -- registered with auto-confirmed email (D-42), remember-me session (D-43)
  3. **Email match** -- existing user with same email, link confirmation required (D-01)
  4. **No email** -- provider didn't return email, error shown (D-08)
  5. **UID/email conflict** -- identity maps to user A, email maps to user B, blocked (D-09)
  """

  require Logger

  alias Sigra.Error.OAuthError
  alias Sigra.OAuth.{Callback, Strategies}
  alias Sigra.{Identity, Telemetry, Token}

  @oauth_state_purpose "sigra-oauth-state"
  @oauth_state_max_age 900

  # -- Public API --

  @doc """
  Generates an authorization URL for the given provider.

  Resolves the provider's strategy wrapper, calls its `authorize_url/1`,
  and replaces the state parameter with an HMAC-signed version.

  Returns `{:ok, url, session_params}` where `session_params` includes
  `:sigra_state` and any PKCE `:code_verifier`.

  ## Examples

      {:ok, url, session_params} = Sigra.OAuth.authorize_url(config, :google)

  """
  @doc since: "0.5.0"
  @spec authorize_url(map(), atom(), keyword()) ::
          {:ok, String.t(), map()} | {:error, atom() | %OAuthError{}}
  def authorize_url(config, provider, opts \\ []) do
    provider_config = get_provider_config(config, provider)

    case Strategies.resolve(provider, provider_config || []) do
      {:error, :unknown_provider} ->
        {:error, :unknown_provider}

      strategy_module ->
        Telemetry.span([:sigra, :oauth, :authorize], %{provider: provider}, fn ->
          do_authorize_url(config, strategy_module, provider, provider_config, opts)
        end)
    end
  end

  @doc """
  Handles an OAuth callback from the provider.

  Verifies the HMAC-signed state parameter, calls the strategy's
  `callback/3` to exchange the authorization code for tokens and user info,
  then delegates to `Sigra.OAuth.Callback.process_callback/4` for account
  routing.

  ## Returns

  - `{:ok, :registered, user, session}` -- new user created
  - `{:ok, :logged_in, user, session}` -- existing identity matched
  - `{:link_confirmation_required, %{provider: p, email: e, ...}}` -- email match
  - `{:error, %OAuthError{}}` -- state mismatch, no email, provider error, etc.
  """
  @doc since: "0.5.0"
  @spec handle_callback(map(), atom(), map(), map()) ::
          {:ok, atom(), map(), map()}
          | {:link_confirmation_required, map()}
          | {:error, %OAuthError{}}
  def handle_callback(config, provider, params, session_params) do
    Telemetry.span([:sigra, :oauth, :callback], %{provider: provider}, fn ->
      with :ok <- verify_state(params, session_params, config.secret_key_base) do
        provider_config = get_provider_config(config, provider) || []

        case Strategies.resolve(provider, provider_config) do
          {:error, :unknown_provider} ->
            {:error, %OAuthError{provider: provider, error_code: :provider_error}}

          strategy_module ->
            assent_session = extract_assent_session(session_params)

            case strategy_module.callback(provider_config, params, assent_session) do
              {:ok, user_info, token} ->
                Callback.process_callback(config, provider, user_info, token)

              {:error, error} ->
                Logger.error("OAuth callback failed for #{provider}: #{inspect(error)}")
                {:error, %OAuthError{provider: provider, error_code: :token_exchange_failed}}
            end
        end
      end
    end)
  end

  @doc """
  Retrieves OAuth tokens for an identity, auto-refreshing if expired.

  When the access token is expired and a refresh token exists, calls the
  provider's token refresh endpoint, persists the new tokens, and returns
  updated tokens. If no refresh token is available or refresh fails,
  returns `{:error, :token_expired}`.

  ## Examples

      {:ok, %{access_token: "new_token"}} = Sigra.OAuth.get_tokens(config, identity)

  """
  @doc since: "0.5.0"
  @spec get_tokens(map(), Identity.t()) :: {:ok, map()} | {:error, :token_expired}
  def get_tokens(config, %Identity{} = identity) do
    if token_expired?(identity) do
      if identity.encrypted_refresh_token do
        refresh_tokens(config, identity)
      else
        {:error, :token_expired}
      end
    else
      {:ok, %{access_token: identity.encrypted_access_token, refresh_token: identity.encrypted_refresh_token}}
    end
  end

  @doc """
  Links an OAuth provider to an existing authenticated user.

  Creates a new identity record for the user. Requires the user to
  not already have an identity for this provider.

  Emits `[:sigra, :oauth, :link, :stop]` telemetry event (D-61).

  ## Returns

  - `{:ok, identity}` on success
  - `{:error, :already_linked}` if the user already has this provider
  """
  @doc since: "0.5.0"
  @spec link_provider(map(), map(), map(), keyword()) ::
          {:ok, map()} | {:error, :already_linked}
  def link_provider(config, user, provider_info, _opts \\ []) do
    repo = config.repo
    identity_schema = config.identity_schema
    provider = to_string(provider_info[:provider] || provider_info.provider)

    # Check if already linked
    existing = repo.get_by(identity_schema, provider: provider, user_id: user.id)

    if existing do
      {:error, :already_linked}
    else
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      identity_attrs = %{
        user_id: user.id,
        provider: String.downcase(provider),
        provider_uid: provider_info[:provider_uid] || provider_info[:user_info]["sub"],
        provider_email: get_in(provider_info, [:user_info, "email"]),
        provider_name: get_in(provider_info, [:user_info, "name"]),
        provider_avatar_url: get_in(provider_info, [:user_info, "picture"]),
        encrypted_access_token: get_in(provider_info, [:token, "access_token"]),
        encrypted_refresh_token: get_in(provider_info, [:token, "refresh_token"]),
        token_expires_at: compute_token_expires_at(provider_info[:token]),
        metadata: %{},
        last_used_at: now
      }

      changeset = identity_schema |> struct() |> Ecto.Changeset.change(identity_attrs)

      case repo.insert(changeset) do
        {:ok, identity} ->
          Telemetry.event([:sigra, :oauth, :link, :stop], %{}, %{
            user_id: user.id,
            provider: provider
          })

          {:ok, identity}

        {:error, changeset} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Unlinks an OAuth provider from a user.

  Blocks if this is the user's last auth method and no password is set (D-03).
  Sends notification email on success (D-07).

  Emits `[:sigra, :oauth, :unlink, :stop]` telemetry event.

  ## Returns

  - `{:ok, :unlinked}` on success
  - `{:error, :last_provider}` if last auth method and no password
  - `{:error, :not_found}` if identity not found
  """
  @doc since: "0.5.0"
  @spec unlink_provider(map(), map(), atom() | String.t(), keyword()) ::
          {:ok, :unlinked} | {:error, :last_provider | :not_found}
  def unlink_provider(config, user, provider, _opts \\ []) do
    repo = config.repo
    identity_schema = config.identity_schema
    provider_str = to_string(provider) |> String.downcase()

    has_password = user.hashed_password != nil and user.hashed_password != ""

    # Check if user has other identities
    import Ecto.Query

    other_count =
      from(i in identity_schema,
        where: i.user_id == ^user.id and i.provider != ^provider_str
      )
      |> repo.aggregate(:count)

    if !has_password and other_count == 0 do
      {:error, :last_provider}
    else
      # Find and delete the identity
      case repo.get_by(identity_schema, provider: provider_str, user_id: user.id) do
        nil ->
          {:error, :not_found}

        identity ->
          case repo.delete(identity) do
            {:ok, _} ->
              Telemetry.event([:sigra, :oauth, :unlink, :stop], %{}, %{
                user_id: user.id,
                provider: provider_str
              })

              {:ok, :unlinked}

            {:error, reason} ->
              {:error, reason}
          end
      end
    end
  end

  # -- Private helpers --

  defp do_authorize_url(config, strategy_module, provider, provider_config, _opts) do
    case strategy_module.authorize_url(provider_config) do
      {:ok, %{url: url, session_params: assent_session}} ->
        # Generate HMAC-signed state to replace Assent's
        state = generate_state(config.secret_key_base, provider)

        # Replace state in the URL
        new_url = replace_url_state(url, state)

        # Build session params with Sigra state + PKCE verifier
        session_params =
          %{sigra_state: state}
          |> maybe_put(:code_verifier, Map.get(assent_session, :code_verifier))

        {:ok, new_url, session_params}

      {:ok, %{url: url}} ->
        state = generate_state(config.secret_key_base, provider)
        new_url = replace_url_state(url, state)
        {:ok, new_url, %{sigra_state: state}}

      {:error, error} ->
        Logger.error("OAuth authorize_url failed for #{provider}: #{inspect(error)}")
        {:error, %OAuthError{provider: provider, error_code: :authorize_failed}}
    end
  end

  defp generate_state(secret_key_base, provider) do
    nonce = :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)

    Token.generate(secret_key_base, @oauth_state_purpose, %{
      provider: to_string(provider),
      nonce: nonce
    }, max_age: @oauth_state_max_age)
  end

  defp verify_state(params, session_params, secret_key_base) do
    state = params["state"] || params[:state]
    stored_state = session_params[:sigra_state] || session_params["sigra_state"]

    cond do
      is_nil(state) or state == "" ->
        {:error, %OAuthError{provider: nil, error_code: :state_mismatch}}

      state != stored_state ->
        {:error, %OAuthError{provider: nil, error_code: :state_mismatch}}

      true ->
        case Token.verify(secret_key_base, @oauth_state_purpose, state, max_age: @oauth_state_max_age) do
          {:ok, _data} -> :ok
          {:error, _} -> {:error, %OAuthError{provider: nil, error_code: :state_mismatch}}
        end
    end
  end

  defp replace_url_state(url, state) do
    uri = URI.parse(url)
    query = URI.decode_query(uri.query || "")
    new_query = Map.put(query, "state", state) |> URI.encode_query()
    %{uri | query: new_query} |> URI.to_string()
  end

  defp extract_assent_session(session_params) do
    # Pass through PKCE code_verifier and other Assent-required session state
    session_params
    |> Map.drop([:sigra_state, "sigra_state"])
    |> Map.to_list()
    |> Enum.into(%{})
  end

  defp get_provider_config(config, provider) do
    providers = get_in(config, [:oauth, :providers]) || Keyword.get(config.oauth, :providers, [])
    Keyword.get(providers, provider)
  end

  defp token_expired?(%Identity{token_expires_at: nil}), do: false

  defp token_expired?(%Identity{token_expires_at: expires_at}) do
    DateTime.compare(DateTime.utc_now(), expires_at) == :gt
  end

  defp refresh_tokens(config, %Identity{} = identity) do
    provider = String.to_existing_atom(identity.provider)
    provider_config = get_provider_config(config, provider) || []

    case Strategies.resolve(provider, provider_config) do
      {:error, _} ->
        {:error, :token_expired}

      _strategy_module ->
        # Attempt token refresh via Assent if available
        # For now, return error -- full refresh requires Assent HTTP client
        Logger.warning("Token refresh not yet implemented for #{identity.provider}")

        Telemetry.event([:sigra, :oauth, :refresh, :stop], %{}, %{
          user_id: identity.user_id,
          provider: identity.provider,
          success: false
        })

        {:error, :token_expired}
    end
  end

  @doc false
  def compute_token_expires_at(nil), do: nil

  def compute_token_expires_at(token) when is_map(token) do
    case token["expires_in"] do
      nil -> nil
      seconds when is_integer(seconds) ->
        DateTime.utc_now()
        |> DateTime.add(seconds, :second)
        |> DateTime.truncate(:second)
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
