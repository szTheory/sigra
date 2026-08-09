defmodule Example.Accounts.CrosswakeSessionAdapter do
  @moduledoc """
  Host-owned projection boundary between a current SIGRA session cookie and the
  released Crosswake evaluator.

  The raw cookie is used only for canonical host lookup. Crosswake receives
  newly derived, keyed opaque references and server-owned session facts.
  """

  alias Crosswake.Companions.Sigra.Contracts
  alias Crosswake.Companions.Sigra.Evaluator
  alias Crosswake.Manifest.Types.RouteEntry
  alias Example.Accounts

  @type result ::
          {:allow,
           %{
             status: :allow,
             session_ref: String.t(),
             subject_ref: String.t(),
             session_version: non_neg_integer(),
             org_id: nil
           }}
          | {:deny, %{status: :deny, reason: atom() | String.t()}}

  @doc """
  Resolves a current host session and returns its safe expected binding.

  A continuation may retain this opaque binding, but `evaluate/4` always
  resolves the cookie again and compares it to the newly derived binding.
  """
  @spec expected_binding(binary()) :: {:ok, map()} | {:error, :session_unavailable}
  def expected_binding(raw_token) when is_binary(raw_token) do
    case Accounts.get_user_and_session_by_token(raw_token) do
      {user, session} -> {:ok, binding(user, session)}
      nil -> {:error, :session_unavailable}
    end
  end

  def expected_binding(_raw_token), do: {:error, :session_unavailable}

  @doc """
  Freshly resolves and validates `raw_token`, then evaluates `route` using
  only fact-only Crosswake contracts. `expected_binding` must originate from
  the host; it is checked against this call's newly resolved session.
  """
  @spec evaluate(binary(), DateTime.t(), RouteEntry.t(), map()) :: result()
  def evaluate(raw_token, %DateTime{} = as_of, %RouteEntry{} = route, expected_binding)
      when is_binary(raw_token) and is_map(expected_binding) do
    with {user, session} <- Accounts.get_user_and_session_by_token(raw_token),
         :ok <- validate_current_session(session, as_of),
         current_binding <- binding(user, session),
         :ok <- match_binding(expected_binding, current_binding),
         {:ok, lane} <- new_lane(current_binding, session, as_of),
         {:ok, context} <- Contracts.new_auth_context(%{session_authority_lane: lane}),
         evaluator_result <-
           Evaluator.evaluate_route_auth(route, context,
             expected_session_version: current_binding.session_version
           ) do
      format_evaluator_result(evaluator_result, current_binding)
    else
      nil -> deny(:session_unavailable)
      {:error, :session_unavailable} -> deny(:session_unavailable)
      {:error, :binding_mismatch} -> deny(:binding_mismatch)
      {:error, _contract_error} -> deny(:projection_failed)
    end
  end

  def evaluate(_raw_token, _as_of, _route, _expected_binding), do: deny(:session_unavailable)

  defp new_lane(binding, session, as_of) do
    session_config = Accounts.sigra_config().session
    idle_timeout = Keyword.get(session_config, :idle_timeout, 1_800)
    absolute_timeout = Keyword.get(session_config, :absolute_timeout, 86_400)

    Contracts.new_session_authority_lane(%{
      session_ref: binding.session_ref,
      subject_ref: binding.subject_ref,
      org_id: nil,
      state: :active,
      assurance_level: :password,
      authn_methods: [:password],
      authenticated_at: timestamp(session.inserted_at),
      last_seen_at: timestamp(session.last_active_at),
      idle_expires_at: timestamp(DateTime.add(session.last_active_at, idle_timeout, :second)),
      absolute_expires_at:
        timestamp(DateTime.add(session.inserted_at, absolute_timeout, :second)),
      session_version: binding.session_version,
      as_of: timestamp(as_of),
      remembered: remembered?(session),
      cached: false
    })
  end

  defp validate_current_session(session, as_of) do
    session_config = Accounts.sigra_config().session
    idle_timeout = Keyword.get(session_config, :idle_timeout, 1_800)
    absolute_timeout = Keyword.get(session_config, :absolute_timeout, 86_400)

    with true <- standard_or_remembered?(session),
         %DateTime{} = inserted_at <- session.inserted_at,
         %DateTime{} = last_active_at <- session.last_active_at,
         true <-
           DateTime.compare(as_of, DateTime.add(inserted_at, absolute_timeout, :second)) == :lt,
         true <-
           DateTime.compare(as_of, DateTime.add(last_active_at, idle_timeout, :second)) == :lt do
      :ok
    else
      _ -> {:error, :session_unavailable}
    end
  end

  defp binding(user, session) do
    %{
      session_ref: opaque_ref("sigra-crosswake/session", session.id),
      subject_ref: opaque_ref("sigra-crosswake/subject", user.id),
      session_version: session_version(session.inserted_at)
    }
  end

  defp match_binding(expected, current) do
    if Map.take(expected, [:session_ref, :subject_ref, :session_version]) == current do
      :ok
    else
      {:error, :binding_mismatch}
    end
  end

  defp format_evaluator_result({:allow, _result}, binding) do
    {:allow, Map.merge(%{status: :allow, org_id: nil}, binding)}
  end

  defp format_evaluator_result({:deny, finding}, _binding), do: deny(finding.code)

  defp deny(reason), do: {:deny, %{status: :deny, reason: reason}}

  defp opaque_ref(domain, id) do
    :crypto.mac(:hmac, :sha256, host_secret(), domain <> ":" <> to_string(id))
    |> Base.url_encode64(padding: false)
  end

  defp host_secret do
    Application.fetch_env!(:example, ExampleWeb.Endpoint)
    |> Keyword.fetch!(:secret_key_base)
  end

  defp session_version(%DateTime{} = inserted_at),
    do: max(DateTime.to_unix(inserted_at, :microsecond), 0)

  defp timestamp(%DateTime{} = value),
    do: value |> DateTime.truncate(:second) |> DateTime.to_iso8601()

  defp remembered?(session), do: session.type in [:remember_me, "remember_me"]

  defp standard_or_remembered?(session),
    do: session.type in [:standard, "standard", :remember_me, "remember_me"]
end
