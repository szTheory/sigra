defmodule Example.Accounts.CrosswakeNativeBridge do
  @moduledoc """
  Host-owned native return and offline replay projection boundary.

  Native posture is evidence only. The session adapter re-resolves the host
  session and remains the sole path to the Crosswake evaluator.
  """

  alias Crosswake.Companions.Sigra.AuthReturn
  alias Crosswake.Offline.Journal.Entry
  alias Crosswake.Offline.Replay
  alias Crosswake.Manifest.Types.RouteEntry
  alias Example.Accounts.CrosswakeSessionAdapter
  alias Example.Accounts.CrosswakeSessionAdapter.ExpectedBinding
  alias Example.LearningTwin

  @native_evidence_keys [
    :platform,
    :transport,
    :link_verification,
    :callback_binding,
    :replay,
    :native_assertion_ref
  ]

  @doc """
  Converts locally validated native posture into released `NativeEvidence`.

  The caller supplies no callback material, credential, account identity, or
  authority decision. A valid envelope is always evaluated through the fresh
  host-session check in `CrosswakeSessionAdapter`.
  """
  @spec evaluate_return(
          binary(),
          DateTime.t(),
          RouteEntry.t(),
          ExpectedBinding.t(),
          map() | keyword(),
          keyword()
        ) :: CrosswakeSessionAdapter.result()
  def evaluate_return(
        raw_token,
        as_of,
        %RouteEntry{} = route,
        %ExpectedBinding{} = binding,
        posture,
        opts
      )
      when is_binary(raw_token) and is_struct(as_of, DateTime) and is_list(opts) do
    with {:ok, evidence} <- native_evidence(posture),
         {:ok, envelope} <- native_envelope(route, as_of, evidence) do
      CrosswakeSessionAdapter.evaluate_return(raw_token, as_of, route, binding, envelope, opts)
    else
      {:error, _reason} -> {:deny, %{status: :deny, reason: :invalid_return_evidence}}
    end
  end

  def evaluate_return(_raw_token, _as_of, _route, _binding, _posture, _opts),
    do: {:deny, %{status: :deny, reason: :invalid_return_evidence}}

  @doc """
  Preserves a released journal entry's correlation fields in replay vocabulary.

  This is intentionally a structural conversion: neither an owner nor a
  terminal status is accepted or derived here.
  """
  @spec replay_request(Entry.t()) :: Replay.Request.t()
  def replay_request(%Entry{} = entry), do: Replay.request_for_entry(entry)

  @doc """
  Replays a request through the host-owned learning twin and projects its
  already-persisted terminal receipt back into released Crosswake vocabulary.
  """
  @spec replay_outcome(map(), Replay.Request.t()) :: Replay.Outcome.t() | {:error, atom()}
  def replay_outcome(scope, %Replay.Request{} = request) when is_map(scope) do
    with {:ok, receipt} <- LearningTwin.replay(scope, request.payload, []),
         {:ok, status} <- outcome_status(receipt.outcome) do
      outcome(request, status, receipt)
    end
  end

  def replay_outcome(_scope, _request), do: {:error, :invalid_replay}

  defp native_evidence(posture) when is_list(posture), do: native_evidence(Map.new(posture))

  defp native_evidence(posture) when is_map(posture) do
    if Map.keys(posture) |> MapSet.new() == MapSet.new(@native_evidence_keys) do
      posture
      |> Map.take(@native_evidence_keys)
      |> AuthReturn.new_native_evidence()
    else
      {:error, :unsupported_native_posture}
    end
  end

  defp native_evidence(_posture), do: {:error, :unsupported_native_posture}

  defp native_envelope(route, as_of, evidence) do
    AuthReturn.new_envelope(%{
      typ: "sigra.auth_return",
      return_ref: opaque_return_ref(route.id, evidence.native_assertion_ref),
      version: "1",
      issuer: "example",
      audience: "example",
      kind: :native_auth,
      route_id: route.id,
      return_route_id: route.id,
      transport: evidence.transport,
      issued_at: as_of,
      expires_at: DateTime.add(as_of, 300, :second),
      replay_posture: :server_record_required,
      link_verification: evidence.link_verification,
      validation_posture: %{"callback_binding" => Atom.to_string(evidence.callback_binding)},
      evidence: evidence
    })
  end

  defp opaque_return_ref(route_id, assertion_ref) do
    :crypto.hash(:sha256, "sigra-crosswake/native-return:" <> route_id <> ":" <> assertion_ref)
    |> Base.url_encode64(padding: false)
  end

  defp outcome_status("accepted"), do: {:ok, :accepted}
  defp outcome_status("rejected"), do: {:ok, :rejected}
  defp outcome_status("conflict"), do: {:ok, :conflict}
  defp outcome_status(_outcome), do: {:error, :invalid_replay}

  defp outcome(request, :accepted, receipt) do
    Replay.accepted(request,
      authoritative_state: receipt_state(receipt),
      checkpoint: receipt.base_checkpoint
    )
  end

  defp outcome(request, :rejected, receipt) do
    Replay.rejected(request,
      authoritative_state: receipt_state(receipt),
      checkpoint: receipt.base_checkpoint,
      reason: "host_rejected"
    )
  end

  defp outcome(request, :conflict, receipt) do
    Replay.conflict(request,
      authoritative_state: receipt_state(receipt),
      checkpoint: receipt.base_checkpoint,
      reason: "host_conflict"
    )
  end

  defp receipt_state(receipt) do
    %{
      client_mutation_id: receipt.client_mutation_id,
      terminal_at: DateTime.to_iso8601(receipt.terminal_at)
    }
  end
end
