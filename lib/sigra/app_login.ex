defmodule Sigra.AppLogin do
  @moduledoc """
  Hosted first-party app-login exchange facade.

  The exchange consumes an already-approved, digest-only hosted attempt and
  composes Phase 245 issuance into the same database transaction.
  """

  alias Ecto.Multi
  alias Sigra.Audit
  alias Sigra.AppLogin.Attempt
  alias Sigra.AppLogin.PKCE
  alias Sigra.Token

  @continuation_purpose "sigra-app-login-hosted-v1"
  @continuation_ttl 300
  @code_ttl 60

  def start_hosted(config, params, opts \\ []) do
    now = now(opts)

    with {:ok, profile, callback, state, challenge} <- hosted_request(config, params),
         secret when is_binary(secret) and secret != "" <- config.secret_key_base do
      payload = %{
        "profile_id" => profile.id,
        "callback" => callback,
        "state" => state,
        "challenge" => challenge,
        "issued_at" => DateTime.to_unix(now)
      }

      {:ok,
       %{
         continuation: Token.generate(secret, @continuation_purpose, payload),
         approval_required: true
       }}
    else
      _ -> {:error, :invalid_request}
    end
  end

  def approve_hosted(config, continuation, user, decision, opts \\ [])

  def approve_hosted(_config, _continuation, _user, :cancel, _opts), do: {:ok, :cancelled}

  def approve_hosted(config, continuation, user, :approve, opts) do
    now = now(opts)

    with {:ok, profile, payload} <- continuation(config, continuation, now),
         true <- is_map(user) and not is_nil(Map.get(user, :id)),
         schema when is_atom(schema) <- config.app_session[:app_login_code_schema],
         {code, _digest} <- Token.generate_hashed_token(),
         {:ok, _} <-
           config.repo.insert(
             struct!(schema, %{
               digest: Token.hash_token(code),
               verifier_digest: Token.hash_token(payload["challenge"]),
               profile_id: profile.id,
               callback: payload["callback"],
               user_id: user.id,
               client_ref: profile.client_ref,
               expires_at: DateTime.add(now, @code_ttl, :second)
             })
           ) do
      {:ok, %{code: code, callback: payload["callback"], state: payload["state"]}}
    else
      _ -> {:error, :invalid_continuation}
    end
  end

  def approve_hosted(_config, _continuation, _user, _decision, _opts),
    do: {:error, :invalid_continuation}

  @spec exchange_hosted(Sigra.Config.t(), String.t(), String.t(), map(), String.t()) ::
          {:ok, map()} | {:error, :invalid_code}
  def exchange_hosted(config, code, verifier, profile, callback) do
    multi =
      Multi.new()
      |> Attempt.build_locked_hosted_exchange_multi(config, code, verifier, profile, callback)

    try do
      case config.repo.transaction(multi) do
        {:ok, %{app_session_issue: credentials} = changes} ->
          Audit.emit_telemetry_from_changes(changes, [:audit_app_login_exchange])
          {:ok, credentials}

        {:error, _step, _reason, _changes} ->
          {:error, :invalid_code}
      end
    rescue
      _exception -> {:error, :invalid_code}
    end
  end

  defp hosted_request(config, params) when is_map(params) do
    with true <-
           Enum.sort(Map.keys(params)) == [
             "callback",
             "code_challenge",
             "code_challenge_method",
             "profile_id",
             "state"
           ],
         id when is_binary(id) <- params["profile_id"],
         callback when is_binary(callback) <- params["callback"],
         state when is_binary(state) and state != "" <- params["state"],
         challenge when is_binary(challenge) <- params["code_challenge"],
         true <- PKCE.valid_challenge?(challenge),
         "S256" <- params["code_challenge_method"],
         {:ok, profile} <- first_party_profile(config, id),
         true <- callback in profile.callback_uris do
      {:ok, profile, callback, state, challenge}
    else
      _ -> {:error, :invalid_request}
    end
  end

  defp hosted_request(_, _), do: {:error, :invalid_request}

  defp continuation(config, token, now) when is_binary(token) do
    with secret when is_binary(secret) and secret != "" <- config.secret_key_base,
         {:ok,
          %{
            "profile_id" => id,
            "callback" => callback,
            "state" => state,
            "challenge" => challenge,
            "issued_at" => issued_at
          } = payload} <-
           Token.verify(secret, @continuation_purpose, token, max_age: @continuation_ttl),
         true <-
           is_binary(callback) and is_binary(state) and state != "" and is_integer(issued_at),
         true <- DateTime.to_unix(now) < issued_at + @continuation_ttl,
         true <- PKCE.valid_challenge?(challenge),
         {:ok, profile} <- first_party_profile(config, id),
         true <- callback in profile.callback_uris do
      {:ok, profile, payload}
    else
      _ -> {:error, :invalid_continuation}
    end
  end

  defp continuation(_, _, _), do: {:error, :invalid_continuation}

  defp first_party_profile(config, id) when is_binary(id) do
    case Enum.find(config.app_session[:first_party_profiles] || [], &(&1.id == id)) do
      nil -> {:error, :invalid_request}
      profile -> {:ok, profile}
    end
  end

  defp first_party_profile(_, _), do: {:error, :invalid_request}

  defp now(opts) do
    now = Keyword.get(opts, :now, DateTime.utc_now())
    DateTime.from_unix!(DateTime.to_unix(now, :microsecond), :microsecond)
  end
end
