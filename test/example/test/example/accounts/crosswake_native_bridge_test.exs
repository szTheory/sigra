defmodule Example.Accounts.CrosswakeNativeBridgeTest do
  use ExampleWeb.ConnCase, async: false

  import Example.AccountsFixtures

  alias Crosswake.Companions.Sigra.AuthReturn
  alias Crosswake.Offline.Journal
  alias Crosswake.Offline.Replay
  alias Crosswake.Manifest.Types
  alias Example.Accounts.CrosswakeNativeBridge
  alias Example.Accounts.CrosswakeSessionAdapter
  alias Example.Accounts.Auth.AppSessions
  alias Example.LearningTwin.{Lease, ReplayReceipt}
  alias Example.Repo

  setup do
    {_, nil} = Repo.delete_all(ReplayReceipt)
    {_, nil} = Repo.delete_all(Lease)
    :ok
  end

  @tag :crosswake_native_bridge
  test "projects allowlisted iOS and Android evidence only after fresh host authority" do
    as_of = ~U[2026-08-19 12:00:00.000000Z]
    user = user_fixture()

    for {platform, transport, link_verification} <- [
          {:ios, :verified_https_link, :verified},
          {:android, :custom_scheme, :not_applicable}
        ] do
      {raw_token, _session} = session_with_raw_token(user, as_of)
      assert {:ok, binding} = CrosswakeSessionAdapter.expected_binding(raw_token, as_of)

      assert {:allow, %{evidence: %AuthReturn.Envelope{kind: :native_auth} = envelope}} =
               CrosswakeNativeBridge.evaluate_return(
                 raw_token,
                 as_of,
                 protected_route(),
                 binding,
                 native_posture(platform, transport, link_verification),
                 evaluator: capturing_evaluator(self())
               )

      assert %AuthReturn.NativeEvidence{
               platform: ^platform,
               transport: ^transport,
               link_verification: ^link_verification,
               callback_binding: :matched,
               replay: :not_seen,
               native_assertion_ref: "assertion-ref"
             } = envelope.evidence

      assert_receive {:crosswake_evaluator_called, _route, _context,
                      [expected_session_version: _session_version]}

      rendered = inspect(envelope)
      refute rendered =~ raw_token
      refute rendered =~ user.id
      refute rendered =~ "authorization_code"
      refute rendered =~ "pkce_verifier"
    end
  end

  @tag :crosswake_native_bridge
  test "revoked, binding-mismatched, and sensitive native input deny before evaluator invocation" do
    as_of = ~U[2026-08-19 12:00:00.000000Z]
    user = user_fixture()

    {revoked_token, revoked_session} = session_with_raw_token(user, as_of)
    assert {:ok, revoked_binding} = CrosswakeSessionAdapter.expected_binding(revoked_token, as_of)
    Repo.delete!(revoked_session)

    assert {:deny, %{reason: :session_unavailable}} =
             CrosswakeNativeBridge.evaluate_return(
               revoked_token,
               as_of,
               protected_route(),
               revoked_binding,
               native_posture(:ios, :verified_https_link, :verified),
               evaluator: notifying_evaluator(self())
             )

    refute_receive :crosswake_evaluator_called

    {current_token, _session} = session_with_raw_token(user, as_of)
    assert {:ok, current_binding} = CrosswakeSessionAdapter.expected_binding(current_token, as_of)

    assert {:deny, %{reason: :binding_mismatch}} =
             CrosswakeNativeBridge.evaluate_return(
               current_token,
               as_of,
               protected_route(),
               %{current_binding | session_ref: "other-session"},
               native_posture(:android, :custom_scheme, :not_applicable),
               evaluator: notifying_evaluator(self())
             )

    refute_receive :crosswake_evaluator_called

    assert {:deny, %{reason: :invalid_return_evidence}} =
             CrosswakeNativeBridge.evaluate_return(
               current_token,
               as_of,
               protected_route(),
               current_binding,
               Map.put(
                 native_posture(:ios, :verified_https_link, :verified),
                 :access_token,
                 "secret"
               ),
               evaluator: notifying_evaluator(self())
             )

    refute_receive :crosswake_evaluator_called
  end

  @tag :crosswake_native_replay
  test "maps journal identity exactly and leaves terminal status to the host" do
    user = user_fixture()
    scope = %{user: user}
    lease_fixture(user, "lt_replay", DateTime.add(DateTime.utc_now(), 1, :hour))

    for {name, payload, expected_status} <- [
          {"accepted", replay_payload("accepted"), :accepted},
          {"rejected", replay_payload("rejected", %{"answer" => ""}), :rejected},
          {"conflict", replay_payload("conflict", %{"base_checkpoint" => "stale"}), :conflict}
        ] do
      entry = journal_entry(name, payload)

      assert %Replay.Request{} = request = CrosswakeNativeBridge.replay_request(entry)
      assert request.route_id == entry.route_id
      assert request.sync_seam == entry.sync_seam
      assert request.journal_entry_id == entry.id
      assert request.client_mutation_id == entry.client_mutation_id
      assert request.idempotency_key == entry.idempotency_key
      assert request.base_checkpoint == entry.base_checkpoint
      assert request.payload == entry.payload

      assert %Replay.Outcome{status: ^expected_status} =
               CrosswakeNativeBridge.replay_outcome(scope, request)
    end
  end

  @tag :crosswake_native_replay
  test "duplicate and account-isolated replay receipts remain host-owned" do
    user = user_fixture()
    other_user = user_fixture()
    scope = %{user: user}
    other_scope = %{user: other_user}
    lease_fixture(user, "lt_owner", DateTime.add(DateTime.utc_now(), 1, :hour))
    lease_fixture(other_user, "lt_other", DateTime.add(DateTime.utc_now(), 1, :hour))

    request =
      CrosswakeNativeBridge.replay_request(
        journal_entry("duplicate", replay_payload("duplicate"))
      )

    assert %Replay.Outcome{status: :accepted} =
             first =
             CrosswakeNativeBridge.replay_outcome(scope, request)

    assert %Replay.Outcome{status: :accepted} =
             second =
             CrosswakeNativeBridge.replay_outcome(scope, request)

    assert first.authoritative_state == second.authoritative_state
    assert Repo.aggregate(ReplayReceipt, :count) == 1

    assert %Replay.Outcome{status: :accepted} =
             CrosswakeNativeBridge.replay_outcome(other_scope, request)

    assert Repo.aggregate(ReplayReceipt, :count) == 2
  end

  @tag :crosswake_native_replay
  test "rejects replay payload owner and terminal-status smuggling" do
    user = user_fixture()
    scope = %{user: user}
    lease_fixture(user, "lt_secure", DateTime.add(DateTime.utc_now(), 1, :hour))

    for smuggled <- [
          %{"account_partition" => "lt_other"},
          %{"user_id" => "other-user"},
          %{"outcome" => "accepted"},
          %{"status" => "accepted"}
        ] do
      request =
        journal_entry("smuggled", Map.merge(replay_payload("smuggled"), smuggled))
        |> CrosswakeNativeBridge.replay_request()

      assert {:error, :invalid_replay} = CrosswakeNativeBridge.replay_outcome(scope, request)
    end

    assert Repo.aggregate(ReplayReceipt, :count) == 0
  end

  @tag :crosswake_native_app_session
  test "app-session return reloads token family and user and never evaluates stale authority" do
    as_of = DateTime.utc_now() |> DateTime.truncate(:microsecond)
    user = user_fixture()
    assert {:ok, original} = Sigra.AppSession.issue(AppSessions.sigra_config(), user, "ios-native-proof")

    assert {:allow, allowed} =
             CrosswakeNativeBridge.evaluate_app_session_return(
               original.access_token,
               as_of,
               native_posture(:ios, :verified_https_link, :verified),
               evaluator: notifying_evaluator(self())
             )

    assert_receive :crosswake_evaluator_called
    rendered = inspect(allowed)
    refute rendered =~ original.access_token
    refute rendered =~ original.refresh_token
    refute rendered =~ original.family_id
    refute rendered =~ user.id

    assert {:ok, replacement} = AppSessions.refresh(original.refresh_token)

    assert {:deny, %{reason: :invalid_return_evidence}} =
             CrosswakeNativeBridge.evaluate_app_session_return(
               original.access_token,
               DateTime.utc_now(),
               native_posture(:ios, :verified_https_link, :verified),
               evaluator: notifying_evaluator(self())
             )

    refute_receive :crosswake_evaluator_called

    assert {:allow, _} =
             CrosswakeNativeBridge.evaluate_app_session_return(
               replacement.access_token,
               DateTime.utc_now(),
               native_posture(:ios, :verified_https_link, :verified),
               evaluator: notifying_evaluator(self())
             )

    assert_receive :crosswake_evaluator_called
    assert {:ok, _} = AppSessions.revoke_family(user, replacement.family_id)

    assert {:deny, %{reason: :invalid_return_evidence}} =
             CrosswakeNativeBridge.evaluate_app_session_return(
               replacement.access_token,
               DateTime.utc_now(),
               native_posture(:ios, :verified_https_link, :verified),
               evaluator: notifying_evaluator(self())
             )

    refute_receive :crosswake_evaluator_called
  end

  defp native_posture(platform, transport, link_verification) do
    %{
      platform: platform,
      transport: transport,
      link_verification: link_verification,
      callback_binding: :matched,
      replay: :not_seen,
      native_assertion_ref: "assertion-ref"
    }
  end

  defp protected_route do
    Types.new_route_entry(
      id: "crosswake-native-proof",
      path: "/crosswake-native-proof",
      runtime: :phoenix,
      auth_min_level: :password,
      requires_recent_auth: 600,
      auth_posture: :strict_recent
    )
  end

  defp session_with_raw_token(user, as_of) do
    raw_token = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    raw_bytes = Base.url_decode64!(raw_token, padding: false)

    session =
      session_fixture(user, %{
        hashed_token: Sigra.Token.hash_token(raw_bytes),
        inserted_at: as_of,
        last_active_at: as_of
      })

    {raw_token, session}
  end

  defp journal_entry(name, payload) do
    Journal.new_entry(
      id: "journal-#{name}",
      route_id: "learning-twin-replay",
      sync_seam: "learning-twin",
      operation: :replay,
      payload: payload,
      client_mutation_id: payload["client_mutation_id"],
      idempotency_key: payload["idempotency_key"],
      base_checkpoint: payload["base_checkpoint"]
    )
  end

  defp replay_payload(id, overrides \\ %{}) do
    Map.merge(
      %{
        "client_mutation_id" => "mutation-#{id}",
        "idempotency_key" => "idempotency-#{id}",
        "base_checkpoint" => "market-morning-v1",
        "action" => "answer",
        "answer" => "apples"
      },
      overrides
    )
  end

  defp lease_fixture(user, partition, expires_at) do
    Repo.insert!(%Lease{
      user_id: user.id,
      account_partition: partition,
      issued_at: ~U[2026-08-19 12:00:00.000000Z],
      expires_at: expires_at
    })
  end

  defp capturing_evaluator(pid) do
    fn route, context, opts ->
      send(pid, {:crosswake_evaluator_called, route, context, opts})
      {:allow, %{}}
    end
  end

  defp notifying_evaluator(pid) do
    fn _route, _context, _opts ->
      send(pid, :crosswake_evaluator_called)
      {:allow, %{}}
    end
  end
end
