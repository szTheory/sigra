defmodule Example.Accounts.CrosswakeSessionAdapter do
  @moduledoc """
  Host-owned projection boundary between a current SIGRA session cookie and the
  released Crosswake evaluator.

  The raw cookie is used only for canonical host lookup. Crosswake receives
  newly derived, keyed opaque references and server-owned session facts.
  """

  alias Crosswake.Companions.Sigra.Contracts
  alias Crosswake.Companions.Sigra.Evaluator
  alias Crosswake.Companions.Sigra.AuthReturn
  alias Crosswake.Manifest.Types.RouteEntry
  alias Example.Accounts

  defmodule ExpectedBinding do
    @moduledoc false

    @enforce_keys [:session_ref, :subject_ref, :session_version]
    defstruct [:session_ref, :subject_ref, :session_version]

    @type t :: %__MODULE__{
            session_ref: String.t(),
            subject_ref: String.t(),
            session_version: non_neg_integer()
          }
  end

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
  @spec expected_binding(binary(), DateTime.t()) ::
          {:ok, ExpectedBinding.t()} | {:error, :session_unavailable}
  def expected_binding(raw_token, as_of \\ DateTime.utc_now())

  def expected_binding(raw_token, as_of)
      when is_binary(raw_token) and is_struct(as_of, DateTime) do
    with {user, session} <- Accounts.get_user_and_session_by_token(raw_token),
         :ok <- validate_current_session(session, as_of) do
      {:ok, binding(user, session)}
    else
      _ -> {:error, :session_unavailable}
    end
  end

  def expected_binding(_raw_token, _as_of), do: {:error, :session_unavailable}

  @doc "Freshly authenticates an opaque app-session access credential and derives its host binding."
  def expected_app_session_binding(raw_access_token, as_of \\ DateTime.utc_now())

  def expected_app_session_binding(raw_access_token, %DateTime{} = as_of)
      when is_binary(raw_access_token) do
    with {:ok, state} <- current_app_session(raw_access_token, as_of) do
      {:ok, app_session_binding(state)}
    else
      _ -> {:error, :session_unavailable}
    end
  end

  def expected_app_session_binding(_, _), do: {:error, :session_unavailable}

  @doc "Reauthenticates and reloads app-session rows before projecting bounded Crosswake facts."
  def evaluate_app_session(
        raw_access_token,
        %DateTime{} = as_of,
        %RouteEntry{} = route,
        expected_binding,
        opts \\ []
      )
      when is_binary(raw_access_token) and is_list(opts) do
    with {:ok, state} <- current_app_session(raw_access_token, as_of),
         current_binding <- app_session_binding(state),
         :ok <- match_binding(expected_binding, current_binding),
         {:ok, lane} <- new_app_session_lane(current_binding, state, as_of),
         {:ok, context} <- Contracts.new_auth_context(%{session_authority_lane: lane}),
         evaluator_result <-
           evaluator(opts).(route, context,
             expected_session_version: current_binding.session_version
           ) do
      format_evaluator_result(evaluator_result, current_binding)
    else
      {:error, :binding_mismatch} -> deny(:binding_mismatch)
      _ -> deny(:session_unavailable)
    end
  end

  @doc """
  Freshly resolves and validates `raw_token`, then evaluates `route` using
  only fact-only Crosswake contracts. `expected_binding` must originate from
  the host; it is checked against this call's newly resolved session.
  """
  @spec evaluate(binary(), DateTime.t(), RouteEntry.t(), ExpectedBinding.t()) :: result()
  def evaluate(
        raw_token,
        %DateTime{} = as_of,
        %RouteEntry{} = route,
        expected_binding
      )
      when is_binary(raw_token) do
    evaluate(raw_token, as_of, route, expected_binding, [])
  end

  @doc false
  @spec evaluate(binary(), DateTime.t(), RouteEntry.t(), ExpectedBinding.t(), keyword()) ::
          result()
  def evaluate(
        raw_token,
        %DateTime{} = as_of,
        %RouteEntry{} = route,
        expected_binding,
        opts
      )
      when is_binary(raw_token) and is_list(opts) do
    with {user, session} <- Accounts.get_user_and_session_by_token(raw_token),
         :ok <- validate_current_session(session, as_of),
         current_binding <- binding(user, session),
         :ok <- match_binding(expected_binding, current_binding),
         {:ok, lane} <- new_lane(current_binding, session, as_of),
         {:ok, context} <- Contracts.new_auth_context(%{session_authority_lane: lane}),
         evaluator_result <-
           evaluator(opts).(route, context,
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

  def evaluate(_raw_token, _as_of, _route, _expected_binding, _opts),
    do: deny(:session_unavailable)

  @doc """
  Evaluates a hosted return after validating its released evidence envelope.

  Return evidence is parsed before host authority, but it never supplies or
  changes the session binding, projected lane, route, or evaluator options.
  Only a fresh host session can reach the evaluator; approved evidence is
  returned separately for host navigation or audit handling.
  """
  @spec evaluate_return(
          binary(),
          DateTime.t(),
          RouteEntry.t(),
          ExpectedBinding.t(),
          map() | keyword()
        ) :: result()
  def evaluate_return(raw_token, as_of, route, expected_binding, return_input) do
    evaluate_return(raw_token, as_of, route, expected_binding, return_input, [])
  end

  @doc false
  @spec evaluate_return(
          binary(),
          DateTime.t(),
          RouteEntry.t(),
          ExpectedBinding.t(),
          map() | keyword(),
          keyword()
        ) :: result()
  def evaluate_return(raw_token, as_of, route, expected_binding, return_input, opts)
      when is_list(opts) do
    with {:ok, evidence} <- validated_return_envelope(return_input),
         {:allow, result} <- evaluate(raw_token, as_of, route, expected_binding, opts) do
      {:allow, Map.put(result, :evidence, evidence)}
    else
      {:deny, _reason} = denial -> denial
      {:error, _invalid_evidence} -> deny(:invalid_return_evidence)
    end
  end

  def evaluate_return(_raw_token, _as_of, _route, _expected_binding, _return_input, _opts),
    do: deny(:invalid_return_evidence)

  defp validated_return_envelope(%AuthReturn.Envelope{} = envelope) do
    case AuthReturn.validate_envelope(envelope) do
      :ok -> {:ok, envelope}
      {:error, _errors} = error -> error
    end
  end

  defp validated_return_envelope(return_input), do: AuthReturn.new_envelope(return_input)

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

  defp new_app_session_lane(binding, state, as_of) do
    Contracts.new_session_authority_lane(%{
      session_ref: binding.session_ref,
      subject_ref: binding.subject_ref,
      org_id: nil,
      state: :active,
      assurance_level: :none,
      authn_methods: [:app_session],
      authenticated_at: timestamp(state.token.inserted_at),
      last_seen_at: timestamp(as_of),
      idle_expires_at: timestamp(state.token.expires_at),
      absolute_expires_at: timestamp(state.family.absolute_expires_at),
      session_version: binding.session_version,
      as_of: timestamp(as_of),
      remembered: false,
      cached: false
    })
  end

  defp current_app_session(raw_access_token, as_of) do
    config = Accounts.sigra_config()

    with {:ok, %{user_id: user_id, family_id: family_id, token_id: token_id}} <-
           Sigra.AppSession.authenticate(config, raw_access_token),
         user when not is_nil(user) <- config.repo.get(config.user_schema, user_id),
         token when not is_nil(token) <-
           config.repo.get(Example.Accounts.UserAppSessionToken, token_id),
         family when not is_nil(family) <-
           config.repo.get(Example.Accounts.UserAppSessionFamily, family_id),
         true <- token.family_id == family.id and family.user_id == user.id,
         true <-
           is_nil(token.consumed_at) and is_nil(token.superseded_at) and is_nil(token.revoked_at),
         true <- is_nil(family.revoked_at),
         true <- DateTime.compare(as_of, token.expires_at) == :lt,
         true <- DateTime.compare(as_of, family.absolute_expires_at) == :lt do
      {:ok, %{user: user, token: token, family: family}}
    else
      _ -> {:error, :session_unavailable}
    end
  end

  defp app_session_binding(state) do
    %ExpectedBinding{
      session_ref: opaque_ref("sigra-crosswake/app-session", state.family.id),
      subject_ref: opaque_ref("sigra-crosswake/subject", state.user.id),
      session_version: session_version(state.token.inserted_at)
    }
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
    %ExpectedBinding{
      session_ref: opaque_ref("sigra-crosswake/session", session.id),
      subject_ref: opaque_ref("sigra-crosswake/subject", user.id),
      session_version: session_version(session.inserted_at)
    }
  end

  defp match_binding(%ExpectedBinding{} = expected, %ExpectedBinding{} = current) do
    session_ref_matches? = secure_ref_equal?(expected.session_ref, current.session_ref)
    subject_ref_matches? = secure_ref_equal?(expected.subject_ref, current.subject_ref)
    version_matches? = expected.session_version == current.session_version

    if session_ref_matches? and subject_ref_matches? and version_matches? do
      :ok
    else
      {:error, :binding_mismatch}
    end
  end

  defp match_binding(_expected, _current), do: {:error, :binding_mismatch}

  defp secure_ref_equal?(left, right) when is_binary(left) and is_binary(right),
    do: Plug.Crypto.secure_compare(left, right)

  defp secure_ref_equal?(_left, _right), do: false

  defp format_evaluator_result({:allow, _result}, binding) do
    {:allow, Map.merge(%{status: :allow, org_id: nil}, binding)}
  end

  defp format_evaluator_result({:deny, finding}, _binding), do: deny(finding.code)

  defp evaluator(opts) do
    Keyword.get(opts, :evaluator, &Evaluator.evaluate_route_auth/3)
  end

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
