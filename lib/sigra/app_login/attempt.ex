defmodule Sigra.AppLogin.Attempt do
  @moduledoc false

  import Ecto.Query

  alias Ecto.Multi
  alias Sigra.Audit
  alias Sigra.AppLogin.PKCE
  alias Sigra.AppSession
  alias Sigra.Token

  @spec build_locked_hosted_exchange_multi(
          Ecto.Multi.t(),
          Sigra.Config.t(),
          String.t(),
          String.t(),
          map(),
          String.t()
        ) :: Ecto.Multi.t()
  def build_locked_hosted_exchange_multi(
        %Multi{} = multi,
        config,
        code,
        verifier,
        profile,
        callback
      ) do
    with {:ok, profile_id, client_ref} <- profile_binding(profile),
         attempt_schema when is_atom(attempt_schema) <- config.app_session[:app_login_code_schema],
         true <- is_binary(code) and is_binary(verifier) and is_binary(callback),
         challenge when is_binary(challenge) <- PKCE.challenge(verifier) do
      code_digest = Token.hash_token(code)
      challenge_digest = Token.hash_token(challenge)

      multi
      |> Multi.run(:app_login_attempt, fn repo, _changes ->
        lock_valid_attempt(
          repo,
          attempt_schema,
          code_digest,
          challenge_digest,
          profile_id,
          client_ref,
          callback
        )
      end)
      |> Multi.update(:app_login_consume_attempt, fn %{app_login_attempt: attempt} ->
        Ecto.Changeset.change(attempt, consumed_at: now())
      end)
      |> Multi.run(:app_login_user, fn repo, %{app_login_attempt: attempt} ->
        case repo.get(config.user_schema, attempt.user_id) do
          nil -> {:error, :invalid_code}
          user -> {:ok, user}
        end
      end)
      |> Multi.merge(fn %{app_login_attempt: attempt, app_login_user: user} ->
        AppSession.build_issue_multi(Multi.new(), config, user, attempt.client_ref)
      end)
      |> append_hosted_exchange_audit(config)
    else
      _ -> Multi.error(multi, :app_login_attempt, :invalid_code)
    end
  end

  defp lock_valid_attempt(
         repo,
         attempt_schema,
         code_digest,
         challenge_digest,
         profile_id,
         client_ref,
         callback
       ) do
    attempt =
      repo.one(
        from(attempt in attempt_schema,
          where: attempt.digest == ^code_digest,
          lock: "FOR UPDATE"
        )
      )

    if valid_attempt?(attempt, challenge_digest, profile_id, client_ref, callback) do
      {:ok, attempt}
    else
      {:error, :invalid_code}
    end
  end

  defp valid_attempt?(nil, _challenge_digest, _profile_id, _client_ref, _callback), do: false

  defp valid_attempt?(attempt, challenge_digest, profile_id, client_ref, callback) do
    is_nil(attempt.consumed_at) and DateTime.compare(now(), attempt.expires_at) == :lt and
      attempt.profile_id == profile_id and attempt.client_ref == client_ref and
      attempt.callback == callback and
      Plug.Crypto.secure_compare(attempt.verifier_digest, challenge_digest)
  end

  defp profile_binding(%{id: id, client_ref: client_ref})
       when is_binary(id) and is_binary(client_ref),
       do: {:ok, id, client_ref}

  defp profile_binding(_), do: {:error, :invalid_code}

  defp append_hosted_exchange_audit(multi, config) do
    Audit.log_multi_safe(
      multi,
      "session.app_login_exchange",
      repo: config.repo,
      audit_schema: Keyword.get(Map.get(config, :audit, []), :audit_schema),
      actor_resolver: fn changes -> changes.app_login_attempt.user_id end,
      target_resolver: fn changes -> changes.app_login_attempt.user_id end,
      metadata_resolver: fn changes ->
        %{
          attempt_id: changes.app_login_attempt.id,
          profile_id: changes.app_login_attempt.profile_id,
          family_id: changes.app_session_family.id
        }
      end,
      audit_multi_step: :audit_app_login_exchange
    )
  end

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:microsecond)
end
