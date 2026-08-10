defmodule Example.Accounts.CrosswakeSessionAdapterTest do
  use ExampleWeb.ConnCase, async: false

  import Example.AccountsFixtures

  alias Crosswake.Companions.Sigra.Contracts
  alias Crosswake.Companions.Sigra.AuthReturn
  alias Crosswake.Manifest.Types
  alias Example.Accounts.CrosswakeSessionAdapter
  alias Example.Accounts.CrosswakeSessionAdapter.ExpectedBinding
  alias Example.Repo

  @tag :crosswake_tracer
  test "freshly resolves a personal session and evaluates it without leaking credentials" do
    user = user_fixture()
    inserted_at = iso8601!("2026-08-09T12:00:00.123456Z")
    as_of = iso8601!("2026-08-09T12:01:00.000000Z")
    raw_token = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    raw_bytes = Base.url_decode64!(raw_token, padding: false)

    session =
      session_fixture(user, %{
        hashed_token: Sigra.Token.hash_token(raw_bytes),
        inserted_at: inserted_at,
        last_active_at: inserted_at
      })

    assert {:ok, binding} = CrosswakeSessionAdapter.expected_binding(raw_token, as_of)

    assert {:allow, result} =
             CrosswakeSessionAdapter.evaluate(
               raw_token,
               as_of,
               protected_route(),
               binding
             )

    assert result.org_id == nil
    assert result.session_ref == binding.session_ref
    assert result.subject_ref == binding.subject_ref
    assert result.session_version == binding.session_version
    assert result.session_ref != session.id
    assert result.subject_ref != user.id
    assert result.session_ref != raw_token
    assert result.subject_ref != raw_token
    assert result.session_ref != session.hashed_token
    assert result.subject_ref != session.hashed_token

    rendered = inspect(result)
    refute rendered =~ raw_token
    refute rendered =~ Base.encode16(session.hashed_token)
    refute rendered =~ session.id
    refute rendered =~ user.id
    refute Map.has_key?(result, :active_organization_id)
    refute Map.has_key?(result, :provider_payload)
    refute Map.has_key?(result, :oauth_credential)
  end

  @tag :crosswake_tracer
  test "released contract accepts a personal or nonblank organization scope and rejects blank scope" do
    attrs = lane_attrs()

    assert {:ok, personal_lane} =
             Contracts.new_session_authority_lane(Map.put(attrs, :org_id, nil))

    assert {:ok, personal_context} =
             Contracts.new_auth_context(%{session_authority_lane: personal_lane})

    assert personal_context.org_id == nil

    assert {:ok, organization_lane} =
             Contracts.new_session_authority_lane(Map.put(attrs, :org_id, "org_123"))

    assert {:error, errors} =
             Contracts.new_session_authority_lane(Map.put(attrs, :org_id, "   "))

    assert {:org_id, :invalid_optional_string} in errors
    assert organization_lane.org_id == "org_123"
  end

  @tag :crosswake_currentness
  test "host-binding failures deny before invoking the injected evaluator" do
    as_of = iso8601!("2026-08-09T12:01:00.000000Z")

    assert_denied_without_evaluator("not-a-cookie", as_of, %{})

    user = user_fixture()

    {raw_token, session} =
      session_with_raw_token(user, %{inserted_at: as_of, last_active_at: as_of})

    assert {:ok, binding} = CrosswakeSessionAdapter.expected_binding(raw_token, as_of)

    Repo.delete!(session)
    assert_denied_without_evaluator(raw_token, as_of, binding)

    user_without_session = user_fixture()

    {missing_subject_token, _session} =
      session_with_raw_token(user_without_session, %{inserted_at: as_of, last_active_at: as_of})

    assert {:ok, missing_subject_binding} =
             CrosswakeSessionAdapter.expected_binding(missing_subject_token, as_of)

    Repo.delete!(user_without_session)
    assert_denied_without_evaluator(missing_subject_token, as_of, missing_subject_binding)

    inactive_user = user_fixture()

    {inactive_token, inactive_session} =
      session_with_raw_token(inactive_user, %{inserted_at: as_of, last_active_at: as_of})

    assert {:ok, inactive_binding} =
             CrosswakeSessionAdapter.expected_binding(inactive_token, as_of)

    inactive_session
    |> Ecto.Changeset.change(type: "mfa_pending")
    |> Repo.update!()

    assert_denied_without_evaluator(inactive_token, as_of, inactive_binding)
  end

  @tag :crosswake_currentness
  test "a serialized binding cannot revive a deleted session" do
    as_of = iso8601!("2026-08-09T12:01:00.000000Z")
    user = user_fixture()

    {raw_token, session} =
      session_with_raw_token(user, %{inserted_at: as_of, last_active_at: as_of})

    assert {:ok, binding} = CrosswakeSessionAdapter.expected_binding(raw_token, as_of)

    assert {:allow, _result} =
             CrosswakeSessionAdapter.evaluate(
               raw_token,
               as_of,
               protected_route(),
               binding,
               evaluator: notifying_evaluator(self())
             )

    assert_receive :crosswake_evaluator_called

    Repo.delete!(session)
    assert_denied_without_evaluator(raw_token, as_of, binding)
  end

  @tag :crosswake_expiry
  test "standard sessions deny exactly at the idle boundary and allow one microsecond inside" do
    as_of = iso8601!("2026-08-09T12:30:00.000000Z")
    user = user_fixture()
    idle_timeout = 1_800

    {inside_token, _session} =
      session_with_raw_token(user, %{
        inserted_at: as_of,
        last_active_at:
          DateTime.add(as_of, -idle_timeout, :second) |> DateTime.add(1, :microsecond)
      })

    assert {:ok, inside_binding} = CrosswakeSessionAdapter.expected_binding(inside_token, as_of)

    assert {:allow, _result} =
             CrosswakeSessionAdapter.evaluate(
               inside_token,
               as_of,
               protected_route(),
               inside_binding,
               evaluator: notifying_evaluator(self())
             )

    assert_receive :crosswake_evaluator_called

    {boundary_token, _session} =
      session_with_raw_token(user, %{
        inserted_at: as_of,
        last_active_at: DateTime.add(as_of, -idle_timeout, :second)
      })

    assert {:error, :session_unavailable} =
             CrosswakeSessionAdapter.expected_binding(boundary_token, as_of)

    boundary_binding = %{}
    assert_denied_without_evaluator(boundary_token, as_of, boundary_binding)
  end

  @tag :crosswake_expiry
  test "standard sessions deny exactly at the absolute boundary and allow one microsecond inside" do
    as_of = iso8601!("2026-08-10T12:00:00.000000Z")
    user = user_fixture()
    absolute_timeout = 86_400

    {inside_token, _session} =
      session_with_raw_token(user, %{
        inserted_at:
          DateTime.add(as_of, -absolute_timeout, :second) |> DateTime.add(1, :microsecond),
        last_active_at: as_of
      })

    assert {:ok, inside_binding} = CrosswakeSessionAdapter.expected_binding(inside_token, as_of)

    assert {:allow, _result} =
             CrosswakeSessionAdapter.evaluate(
               inside_token,
               as_of,
               protected_route(),
               inside_binding,
               evaluator: notifying_evaluator(self())
             )

    assert_receive :crosswake_evaluator_called

    {boundary_token, _session} =
      session_with_raw_token(user, %{
        inserted_at: DateTime.add(as_of, -absolute_timeout, :second),
        last_active_at: as_of
      })

    assert {:error, :session_unavailable} =
             CrosswakeSessionAdapter.expected_binding(boundary_token, as_of)

    boundary_binding = %{}
    assert_denied_without_evaluator(boundary_token, as_of, boundary_binding)
  end

  @tag :crosswake_binding
  test "only a complete host-owned binding can reach the evaluator" do
    as_of = iso8601!("2026-08-09T12:01:00.000000Z")
    user = user_fixture()

    {raw_token, _session} =
      session_with_raw_token(user, %{inserted_at: as_of, last_active_at: as_of})

    assert {:ok, %ExpectedBinding{} = binding} =
             CrosswakeSessionAdapter.expected_binding(raw_token, as_of)

    assert {:allow, _result} =
             CrosswakeSessionAdapter.evaluate(
               raw_token,
               as_of,
               protected_route(),
               binding,
               evaluator: notifying_evaluator(self())
             )

    assert_receive :crosswake_evaluator_called

    for invalid_binding <- [
          %ExpectedBinding{binding | session_ref: "other-session"},
          %ExpectedBinding{binding | subject_ref: "other-subject"},
          %ExpectedBinding{binding | session_version: binding.session_version + 1},
          Map.from_struct(binding),
          %{}
        ] do
      assert_binding_denied_without_evaluator(raw_token, as_of, invalid_binding)
    end
  end

  @tag :crosswake_account_switch
  test "a valid replacement account or session cannot replace the continuation binding" do
    as_of = iso8601!("2026-08-09T12:01:00.000000Z")
    account_a = user_fixture()
    account_b = user_fixture()

    {a_token, _a_session} =
      session_with_raw_token(account_a, %{inserted_at: as_of, last_active_at: as_of})

    {a_second_token, _a_second_session} =
      session_with_raw_token(account_a, %{inserted_at: as_of, last_active_at: as_of})

    {b_token, _b_session} =
      session_with_raw_token(account_b, %{inserted_at: as_of, last_active_at: as_of})

    assert {:ok, binding_a} = CrosswakeSessionAdapter.expected_binding(a_token, as_of)
    assert {:ok, binding_b} = CrosswakeSessionAdapter.expected_binding(b_token, as_of)

    for replacement_token <- [b_token, a_second_token] do
      assert {:deny, denial} =
               CrosswakeSessionAdapter.evaluate(
                 replacement_token,
                 as_of,
                 protected_route(),
                 binding_a,
                 evaluator: notifying_evaluator(self())
               )

      assert denial == %{status: :deny, reason: :binding_mismatch}
      refute inspect(denial) =~ binding_a.session_ref
      refute inspect(denial) =~ binding_a.subject_ref
      refute inspect(denial) =~ binding_b.session_ref
      refute inspect(denial) =~ binding_b.subject_ref
      refute_receive :crosswake_evaluator_called
    end
  end

  @tag :crosswake_return_evidence
  test "approved hosted-return evidence cannot admit a route without a current session" do
    as_of = iso8601!("2026-08-09T12:01:00.000000Z")

    assert {:deny, %{status: :deny, reason: :session_unavailable}} =
             CrosswakeSessionAdapter.evaluate_return(
               "not-a-cookie",
               as_of,
               protected_route(),
               %ExpectedBinding{
                 session_ref: "session",
                 subject_ref: "subject",
                 session_version: 1
               },
               valid_return_envelope(),
               evaluator: notifying_evaluator(self())
             )

    refute_receive :crosswake_evaluator_called
  end

  @tag :crosswake_return_evidence
  test "approved hosted-return evidence cannot revive expired, revoked, or switched host state" do
    as_of = iso8601!("2026-08-09T12:30:00.000000Z")
    user = user_fixture()

    {expired_token, _expired_session} =
      session_with_raw_token(user, %{
        inserted_at: as_of,
        last_active_at: DateTime.add(as_of, -1_800, :second)
      })

    {revoked_token, revoked_session} =
      session_with_raw_token(user, %{inserted_at: as_of, last_active_at: as_of})

    assert {:ok, revoked_binding} = CrosswakeSessionAdapter.expected_binding(revoked_token, as_of)
    Repo.delete!(revoked_session)

    switched_user = user_fixture()

    {original_token, _original_session} =
      session_with_raw_token(user, %{inserted_at: as_of, last_active_at: as_of})

    {switched_token, _switched_session} =
      session_with_raw_token(switched_user, %{inserted_at: as_of, last_active_at: as_of})

    assert {:ok, original_binding} =
             CrosswakeSessionAdapter.expected_binding(original_token, as_of)

    for {raw_token, binding, expected_reason} <- [
          {expired_token,
           %ExpectedBinding{session_ref: "expired", subject_ref: "expired", session_version: 1},
           :session_unavailable},
          {revoked_token, revoked_binding, :session_unavailable},
          {switched_token, original_binding, :binding_mismatch}
        ] do
      assert {:deny, %{status: :deny, reason: ^expected_reason}} =
               CrosswakeSessionAdapter.evaluate_return(
                 raw_token,
                 as_of,
                 protected_route(),
                 binding,
                 valid_return_envelope(),
                 evaluator: notifying_evaluator(self())
               )

      refute_receive :crosswake_evaluator_called
    end
  end

  @tag :crosswake_return_evidence
  test "valid hosted-return evidence preserves host authority and evaluator inputs" do
    as_of = iso8601!("2026-08-09T12:01:00.000000Z")
    user = user_fixture()

    {raw_token, _session} =
      session_with_raw_token(user, %{inserted_at: as_of, last_active_at: as_of})

    assert {:ok, binding} = CrosswakeSessionAdapter.expected_binding(raw_token, as_of)
    route = protected_route()

    assert {:allow, result} =
             CrosswakeSessionAdapter.evaluate_return(
               raw_token,
               as_of,
               route,
               binding,
               valid_return_envelope(),
               evaluator: capturing_evaluator(self())
             )

    assert_receive {:crosswake_evaluator_called, ^route, _context,
                    [expected_session_version: session_version]}

    assert session_version == binding.session_version
    assert result.session_ref == binding.session_ref
    assert result.subject_ref == binding.subject_ref
    assert result.session_version == binding.session_version
    assert result.org_id == nil
    assert %AuthReturn.Envelope{return_ref: "return_ref"} = result.evidence
    refute Map.has_key?(result, :route_id)
  end

  @tag :crosswake_return_evidence
  test "released AuthReturn rejects every authority or credential smuggling field" do
    for field <- [
          :session_ref,
          :subject_ref,
          :org_id,
          :authority_state,
          :access_granted,
          :grant_access,
          :access_token,
          :stored_digest,
          :provider_payload,
          :authorization_code
        ] do
      assert {:error, errors} =
               AuthReturn.new_envelope(Map.put(valid_return_envelope(), field, "smuggled"))

      assert Enum.any?(errors, fn
               {:auth_return_envelope, {^field, rejection}}
               when rejection in [:forbidden, :unsupported_claim] ->
                 true

               _ ->
                 false
             end)
    end
  end

  @tag :crosswake_return_evidence
  test "invalid return evidence denies before host evaluation" do
    as_of = iso8601!("2026-08-09T12:01:00.000000Z")
    user = user_fixture()

    {raw_token, _session} =
      session_with_raw_token(user, %{inserted_at: as_of, last_active_at: as_of})

    assert {:ok, binding} = CrosswakeSessionAdapter.expected_binding(raw_token, as_of)

    assert {:deny, %{status: :deny, reason: :invalid_return_evidence}} =
             CrosswakeSessionAdapter.evaluate_return(
               raw_token,
               as_of,
               protected_route(),
               binding,
               Map.put(valid_return_envelope(), :session_ref, "smuggled"),
               evaluator: notifying_evaluator(self())
             )

    refute_receive :crosswake_evaluator_called
  end

  defp protected_route do
    Types.new_route_entry(
      id: "crosswake-tracer",
      path: "/crosswake-tracer",
      runtime: :phoenix,
      auth_min_level: :password,
      requires_recent_auth: 600,
      auth_posture: :strict_recent
    )
  end

  defp lane_attrs do
    %{
      session_ref: "session_ref",
      subject_ref: "subject_ref",
      state: :active,
      assurance_level: :password,
      authn_methods: [:password],
      authenticated_at: "2026-08-09T12:00:00Z",
      last_seen_at: "2026-08-09T12:00:00Z",
      idle_expires_at: "2026-08-09T12:30:00Z",
      absolute_expires_at: "2026-08-10T12:00:00Z",
      session_version: 1,
      as_of: "2026-08-09T12:01:00Z"
    }
  end

  defp valid_return_envelope do
    %{
      typ: "sigra.auth_return",
      return_ref: "return_ref",
      version: "1",
      issuer: "example",
      audience: "example",
      kind: :oauth,
      route_id: "crosswake-tracer",
      return_route_id: "crosswake-return",
      transport: :http_callback,
      issued_at: "2026-08-09T12:00:00Z",
      expires_at: "2026-08-09T12:05:00Z",
      replay_posture: :server_record_required,
      link_verification: :not_applicable,
      validation_posture: %{"state" => "matched"},
      evidence: %{
        provider_kind: :google,
        state: :matched,
        pkce: :verified,
        redirect: :verified,
        replay: :not_seen
      }
    }
  end

  defp session_with_raw_token(user, attrs) do
    raw_bytes = :crypto.strong_rand_bytes(32)
    raw_token = Base.url_encode64(raw_bytes, padding: false)

    session =
      session_fixture(user, Map.put(attrs, :hashed_token, Sigra.Token.hash_token(raw_bytes)))

    {raw_token, session}
  end

  defp assert_denied_without_evaluator(raw_token, as_of, binding) do
    assert {:deny, %{status: :deny, reason: :session_unavailable}} =
             CrosswakeSessionAdapter.evaluate(
               raw_token,
               as_of,
               protected_route(),
               binding,
               evaluator: notifying_evaluator(self())
             )

    refute_receive :crosswake_evaluator_called
  end

  defp assert_binding_denied_without_evaluator(raw_token, as_of, binding) do
    assert {:deny, %{status: :deny, reason: :binding_mismatch}} =
             CrosswakeSessionAdapter.evaluate(
               raw_token,
               as_of,
               protected_route(),
               binding,
               evaluator: notifying_evaluator(self())
             )

    refute_receive :crosswake_evaluator_called
  end

  defp notifying_evaluator(test_pid) do
    fn _route, _context, _opts ->
      send(test_pid, :crosswake_evaluator_called)
      {:allow, %{}}
    end
  end

  defp capturing_evaluator(test_pid) do
    fn route, context, opts ->
      send(test_pid, {:crosswake_evaluator_called, route, context, opts})
      {:allow, %{}}
    end
  end

  defp iso8601!(value) do
    {:ok, datetime, 0} = DateTime.from_iso8601(value)
    datetime
  end
end
