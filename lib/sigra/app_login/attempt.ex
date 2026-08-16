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

  @spec build_locked_direct_mfa_multi(
          Ecto.Multi.t(),
          Sigra.Config.t(),
          String.t(),
          String.t(),
          keyword()
        ) :: Ecto.Multi.t()
  def build_locked_direct_mfa_multi(%Multi{} = multi, config, challenge, code, opts)
      when is_binary(challenge) and is_binary(code) and is_list(opts) do
    with schema when is_atom(schema) <- config.app_session[:app_login_challenge_schema],
         {:ok, digest} <- opaque_digest(challenge) do
      multi
      |> Multi.run(:direct_mfa_challenge, fn repo, _changes ->
        lock_valid_direct_challenge(repo, schema, digest, opts)
      end)
      |> Multi.run(:direct_mfa_user, fn repo, %{direct_mfa_challenge: challenge_row} ->
        case repo.get(config.user_schema, challenge_row.user_id) do
          nil -> {:error, :invalid_credentials}
          user -> {:ok, user}
        end
      end)
      |> Multi.run(:direct_mfa_factor, fn _repo, %{direct_mfa_user: user} ->
        verify_direct_factor(user, code, opts)
      end)
      |> Multi.update(:direct_mfa_consume, fn %{direct_mfa_challenge: challenge_row} ->
        Ecto.Changeset.change(challenge_row, consumed_at: now())
      end)
      |> Multi.merge(fn %{direct_mfa_challenge: challenge_row, direct_mfa_user: user} ->
        AppSession.build_issue_multi(Multi.new(), config, user, challenge_row.client_ref)
      end)
      |> append_direct_mfa_audit(config)
    else
      _ -> Multi.error(multi, :direct_mfa_challenge, :invalid_credentials)
    end
  end

  def build_locked_direct_mfa_multi(%Multi{} = multi, _config, _challenge, _code, _opts),
    do: Multi.error(multi, :direct_mfa_challenge, :invalid_credentials)

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

  defp lock_valid_direct_challenge(repo, schema, digest, opts) do
    challenge =
      repo.one(
        from(challenge in schema,
          where: challenge.digest == ^digest,
          lock: "FOR UPDATE"
        )
      )

    if valid_direct_challenge?(challenge, Keyword.get(opts, :profile_id)) do
      {:ok, challenge}
    else
      {:error, :invalid_credentials}
    end
  end

  defp valid_direct_challenge?(nil, _profile_id), do: false

  defp valid_direct_challenge?(challenge, nil) do
    challenge.kind == :direct_mfa and is_nil(challenge.consumed_at) and
      DateTime.compare(now(), challenge.expires_at) == :lt
  end

  defp valid_direct_challenge?(challenge, profile_id) when is_binary(profile_id) do
    valid_direct_challenge?(challenge, nil) and challenge.profile_id == profile_id
  end

  defp valid_direct_challenge?(_challenge, _profile_id), do: false

  defp verify_direct_factor(user, code, opts) do
    callback =
      case Keyword.get(opts, :factor, :totp) do
        :totp -> Keyword.get(opts, :mfa_verify)
        :backup_code -> Keyword.get(opts, :mfa_verify_backup)
        _ -> nil
      end

    if is_function(callback, 2) do
      try do
        case callback.(user, code) do
          {:ok, _result} -> {:ok, :verified}
          {:ok, _result, _metadata} -> {:ok, :verified}
          _ -> {:error, :invalid_credentials}
        end
      rescue
        _exception -> {:error, :invalid_credentials}
      catch
        _kind, _value -> {:error, :invalid_credentials}
      end
    else
      {:error, :invalid_credentials}
    end
  end

  defp opaque_digest(challenge) do
    case Base.url_decode64(challenge, padding: false) do
      {:ok, decoded} -> {:ok, Token.hash_token(decoded)}
      :error -> :error
    end
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

  defp append_direct_mfa_audit(multi, config) do
    Audit.log_multi_safe(
      multi,
      "session.app_login_direct_mfa",
      repo: config.repo,
      audit_schema: Keyword.get(Map.get(config, :audit, []), :audit_schema),
      actor_resolver: fn changes -> changes.direct_mfa_challenge.user_id end,
      target_resolver: fn changes -> changes.direct_mfa_challenge.user_id end,
      metadata_resolver: fn changes ->
        %{
          challenge_id: changes.direct_mfa_challenge.id,
          profile_id: changes.direct_mfa_challenge.profile_id,
          family_id: changes.app_session_family.id
        }
      end,
      audit_multi_step: :audit_direct_mfa_complete
    )
  end

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:microsecond)
end
