defmodule Example.Accounts.CrosswakeContinuations do
  @moduledoc false

  import Ecto.Query, warn: false

  alias Crosswake.Companions.Sigra.AuthReturn
  alias Crosswake.Manifest.Types
  alias Example.Accounts.CrosswakeContinuation
  alias Example.Accounts.CrosswakeSessionAdapter
  alias Example.Accounts.CrosswakeSessionAdapter.ExpectedBinding
  alias Example.Repo

  @route_id "crosswake-hosted-account"
  @return_route_id "crosswake-hosted-return"
  @destination "/app"
  @issuer "example-local-reference"
  @audience "example"

  def issue(raw_token, as_of \\ DateTime.utc_now(), opts \\ [])

  def issue(raw_token, %DateTime{} = as_of, opts) when is_binary(raw_token) and is_list(opts) do
    ttl =
      Keyword.get(
        opts,
        :ttl_seconds,
        Application.fetch_env!(:example, :crosswake_continuation_ttl_seconds)
      )

    with {:ok, binding} <- CrosswakeSessionAdapter.expected_binding(raw_token, as_of),
         true <- is_integer(ttl) and ttl > 0,
         {:ok, continuation} <- insert_continuation(binding, as_of, ttl) do
      {:ok, continuation}
    else
      {:error, :session_unavailable} -> {:error, :session_unavailable}
      false -> {:error, :invalid_ttl}
      {:error, _changeset} -> {:error, :issue_failed}
    end
  end

  def issue(_raw_token, _as_of, _opts), do: {:error, :session_unavailable}

  def complete(handle, raw_token, return_input, as_of \\ DateTime.utc_now(), opts \\ [])

  def complete(handle, raw_token, return_input, %DateTime{} = as_of, opts)
      when is_binary(handle) and is_binary(raw_token) and is_map(return_input) and is_list(opts) do
    evaluator_opts = evaluator_opts(opts)

    case claim(handle, as_of) do
      {:ok, continuation} ->
        result = complete_claimed(continuation, raw_token, return_input, as_of, evaluator_opts)
        record_outcome(continuation, result)
        result

      {:error, reason} ->
        {:deny, %{status: :deny, reason: reason}}
    end
  end

  def complete(_handle, _raw_token, _return_input, _as_of, _opts),
    do: {:deny, %{status: :deny, reason: :invalid_or_expired_handle}}

  def cleanup_expired(as_of \\ DateTime.utc_now(), opts \\ [])

  def cleanup_expired(%DateTime{} = as_of, opts) when is_list(opts) do
    limit = opts |> Keyword.get(:limit, 500) |> min(500) |> max(1)

    terminal_ids =
      from(c in CrosswakeContinuation,
        where: c.expires_at <= ^as_of or not is_nil(c.consumed_at),
        order_by: [asc: c.expires_at, asc: c.id],
        limit: ^limit,
        select: c.id
      )

    from(c in CrosswakeContinuation, where: c.id in subquery(terminal_ids))
    |> Repo.delete_all()
  end

  def cleanup_expired(_as_of, _opts), do: {0, nil}

  def destination, do: @destination

  defp insert_continuation(binding, as_of, ttl) do
    handle = random_value()
    state = random_value()
    pkce_verifier = random_value()

    attrs = %{
      handle_digest: digest(handle),
      state_digest: digest(state),
      pkce_challenge_digest: pkce_challenge(pkce_verifier),
      return_ref: random_value(),
      session_ref: binding.session_ref,
      subject_ref: binding.subject_ref,
      session_version: binding.session_version,
      route_id: @route_id,
      return_route_id: @return_route_id,
      issued_at: as_of,
      expires_at: DateTime.add(as_of, ttl, :second),
      audit_correlation_ref: random_value()
    }

    case attrs
         |> CrosswakeContinuation.issue_changeset()
         |> Repo.insert() do
      {:ok, record} ->
        {:ok,
         %{
           handle: handle,
           state: state,
           pkce_verifier: pkce_verifier,
           expires_at: record.expires_at
         }}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp claim(handle, as_of) do
    handle_digest = digest(handle)

    claim_query =
      from(c in CrosswakeContinuation,
        where:
          c.handle_digest == ^handle_digest and is_nil(c.consumed_at) and c.expires_at > ^as_of,
        select: c
      )

    case Repo.update_all(claim_query, set: [consumed_at: as_of]) do
      {1, [continuation]} ->
        {:ok, continuation}

      _ ->
        {:error, :invalid_or_expired_handle}
    end
  end

  defp validate_correlation(continuation, %{"state" => state, "pkce_verifier" => verifier})
       when is_binary(state) and is_binary(verifier) do
    if secure_digest_match?(continuation.state_digest, digest(state)) and
         secure_digest_match?(continuation.pkce_challenge_digest, pkce_challenge(verifier)) do
      :ok
    else
      {:error, :oauth_state_or_pkce_failure}
    end
  end

  defp validate_correlation(_continuation, _input) do
    {:error, :oauth_state_or_pkce_failure}
  end

  defp complete_claimed(continuation, raw_token, return_input, as_of, evaluator_opts) do
    with :ok <- validate_correlation(continuation, return_input),
         {:ok, envelope} <- auth_return(continuation) do
      CrosswakeSessionAdapter.evaluate_return(
        raw_token,
        as_of,
        route(),
        expected_binding(continuation),
        envelope,
        evaluator_opts
      )
    else
      {:error, reason} -> {:deny, %{status: :deny, reason: normalize_reason(reason)}}
    end
  end

  defp auth_return(continuation) do
    with {:ok, envelope} <-
           AuthReturn.new_envelope(%{
             typ: "sigra.auth_return",
             return_ref: continuation.return_ref,
             version: "1",
             issuer: @issuer,
             audience: @audience,
             kind: :oauth,
             route_id: continuation.route_id,
             return_route_id: continuation.return_route_id,
             transport: :http_callback,
             issued_at: timestamp(continuation.issued_at),
             expires_at: timestamp(continuation.expires_at),
             replay_posture: :server_record_required,
             link_verification: :not_applicable,
             validation_posture: %{"state" => "matched", "pkce" => "verified"},
             evidence: %{
               provider_kind: :local_reference,
               state: :matched,
               pkce: :verified,
               redirect: :verified,
               replay: :not_seen
             }
           }) do
      {:ok, Map.from_struct(envelope)}
    end
  end

  defp expected_binding(continuation) do
    %ExpectedBinding{
      session_ref: continuation.session_ref,
      subject_ref: continuation.subject_ref,
      session_version: continuation.session_version
    }
  end

  defp route do
    Types.new_route_entry(
      id: @route_id,
      path: @destination,
      runtime: :phoenix,
      auth_min_level: :password,
      requires_recent_auth: 600,
      auth_posture: :strict_recent
    )
  end

  defp record_outcome(continuation, {:allow, _result}) do
    continuation |> CrosswakeContinuation.outcome_changeset("allowed", :allowed) |> Repo.update()
  end

  defp record_outcome(continuation, {:deny, %{reason: reason}}) do
    continuation |> CrosswakeContinuation.outcome_changeset("denied", reason) |> Repo.update()
  end

  defp normalize_reason(reason)
       when reason in [
              :oauth_state_or_pkce_failure,
              :invalid_return_evidence,
              :session_unavailable,
              :binding_mismatch,
              :route_denied
            ],
       do: reason

  defp normalize_reason(_reason), do: :route_denied

  defp random_value, do: :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  defp digest(value), do: :crypto.hash(:sha256, value)
  defp pkce_challenge(value), do: digest(value)

  defp secure_digest_match?(left, right),
    do: is_binary(left) and Plug.Crypto.secure_compare(left, right)

  defp timestamp(value), do: value |> DateTime.truncate(:second) |> DateTime.to_iso8601()

  defp evaluator_opts(opts) do
    case Keyword.get(opts, :evaluator, Application.get_env(:example, :crosswake_evaluator)) do
      evaluator when is_function(evaluator, 3) -> [evaluator: evaluator]
      _ -> []
    end
  end
end
