defmodule Example.Accounts.CrosswakeNativeBridgeTest do
  use ExampleWeb.ConnCase, async: false

  import Example.AccountsFixtures

  alias Crosswake.Companions.Sigra.AuthReturn
  alias Crosswake.Manifest.Types
  alias Example.Accounts.CrosswakeNativeBridge
  alias Example.Accounts.CrosswakeSessionAdapter
  alias Example.Repo

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
