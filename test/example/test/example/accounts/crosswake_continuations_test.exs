defmodule Example.Accounts.CrosswakeContinuationsTest do
  use ExampleWeb.ConnCase, async: false

  import Ecto.Query
  import Example.AccountsFixtures

  alias Example.Accounts.CrosswakeContinuation
  alias Example.Accounts.CrosswakeContinuations
  alias Example.Repo

  @as_of ~U[2026-08-11 18:00:00.000000Z]

  test "issues a digest-only continuation with no canonical identifiers or evidence" do
    {raw_token, session, user} = session_with_raw_token(@as_of)

    assert {:ok, issued} = CrosswakeContinuations.issue(raw_token, @as_of)

    record = Repo.one!(from(c in CrosswakeContinuation, where: c.handle_digest == ^digest(issued.handle)))

    assert Map.keys(record) |> Enum.sort() ==
             [
               :__meta__,
               :__struct__,
               :audit_correlation_ref,
               :consumed_at,
               :expires_at,
               :handle_digest,
               :id,
               :inserted_at,
               :issued_at,
               :outcome,
               :pkce_challenge_digest,
               :reason,
               :return_ref,
               :return_route_id,
               :route_id,
               :session_ref,
               :session_version,
               :state_digest,
               :subject_ref,
               :updated_at
             ]

    inspected = inspect(record)
    refute inspected =~ issued.handle
    refute inspected =~ raw_token
    refute inspected =~ Base.encode16(session.hashed_token)
    refute inspected =~ session.id
    refute inspected =~ user.id
    refute Map.has_key?(record, :user_id)
    refute Map.has_key?(record, :session_id)
    refute Map.has_key?(record, :provider_payload)
    refute Map.has_key?(record, :evidence)
    refute Map.has_key?(record, :destination)
    refute Map.has_key?(record, :url)
  end

  test "local AuthReturn rejects missing or mismatched state and PKCE before evaluation" do
    {raw_token, _session, _user} = session_with_raw_token(@as_of)
    assert {:ok, issued} = CrosswakeContinuations.issue(raw_token, @as_of)

    assert {:deny, %{status: :deny, reason: :oauth_state_or_pkce_failure}} =
             CrosswakeContinuations.complete(
               issued.handle,
               raw_token,
               %{"state" => issued.state, "pkce_verifier" => "mismatched"},
               @as_of,
               evaluator: notifying_evaluator(self())
             )

    refute_receive :crosswake_evaluator_called
    assert_terminal(issued.handle, "denied", "oauth_state_or_pkce_failure")

    assert {:deny, %{reason: :invalid_or_expired_handle}} =
             CrosswakeContinuations.complete(
               issued.handle,
               raw_token,
               %{"state" => issued.state, "pkce_verifier" => issued.pkce_verifier},
               @as_of,
               evaluator: notifying_evaluator(self())
             )
  end

  test "claims strictly before expiry, denies at equality, and consumes every terminal result" do
    {raw_token, _session, _user} = session_with_raw_token(@as_of)
    assert {:ok, inside} = CrosswakeContinuations.issue(raw_token, @as_of, ttl_seconds: 10)

    assert {:allow, _} =
             CrosswakeContinuations.complete(
               inside.handle,
               raw_token,
               correlation(inside),
               DateTime.add(@as_of, 9, :second),
               evaluator: notifying_evaluator(self())
             )

    assert_receive :crosswake_evaluator_called
    assert_terminal(inside.handle, "allowed", "allowed")

    assert {:ok, boundary} = CrosswakeContinuations.issue(raw_token, @as_of, ttl_seconds: 10)

    assert {:deny, %{reason: :invalid_or_expired_handle}} =
             CrosswakeContinuations.complete(
               boundary.handle,
               raw_token,
               correlation(boundary),
               DateTime.add(@as_of, 10, :second),
               evaluator: notifying_evaluator(self())
             )

    record = by_handle!(boundary.handle)
    assert is_nil(record.consumed_at)
    assert is_nil(record.outcome)
  end

  test "sequential replay and synchronized concurrent claims produce exactly one evaluator winner" do
    {raw_token, _session, _user} = session_with_raw_token(@as_of)
    assert {:ok, issued} = CrosswakeContinuations.issue(raw_token, @as_of)

    assert {:allow, _} =
             CrosswakeContinuations.complete(
               issued.handle,
               raw_token,
               correlation(issued),
               @as_of,
               evaluator: notifying_evaluator(self())
             )

    assert_receive :crosswake_evaluator_called

    assert {:deny, %{reason: :invalid_or_expired_handle}} =
             CrosswakeContinuations.complete(issued.handle, raw_token, correlation(issued), @as_of)

    assert {:ok, racing} = CrosswakeContinuations.issue(raw_token, @as_of)
    parent = self()
    barrier = make_ref()

    tasks =
      for _ <- 1..2 do
        Task.async(fn ->
          Ecto.Adapters.SQL.Sandbox.allow(Repo, parent, self())
          send(parent, {:claim_ready, self(), barrier})

          receive do
            {:claim_go, ^barrier} ->
              CrosswakeContinuations.complete(
                racing.handle,
                raw_token,
                correlation(racing),
                @as_of,
                evaluator: notifying_evaluator(parent)
              )
          end
        end)
      end

    ready_pids = for _ <- 1..2, do: receive_ready(barrier)
    Enum.each(ready_pids, &send(&1, {:claim_go, barrier}))
    results = Enum.map(tasks, &Task.await(&1, 10_000))

    assert Enum.count(results, &match?({:allow, _}, &1)) == 1
    assert Enum.count(results, &match?({:deny, %{reason: :invalid_or_expired_handle}}, &1)) == 1
    assert_receive :crosswake_evaluator_called
    refute_receive :crosswake_evaluator_called
    assert_terminal(racing.handle, "allowed", "allowed")
  end

  test "separate departures retain independent digests and stored bindings" do
    {first_token, _first_session, _first_user} = session_with_raw_token(@as_of)
    {second_token, _second_session, _second_user} = session_with_raw_token(@as_of)
    assert {:ok, first} = CrosswakeContinuations.issue(first_token, @as_of)
    assert {:ok, second} = CrosswakeContinuations.issue(second_token, @as_of)

    refute first.handle == second.handle
    refute by_handle!(first.handle).handle_digest == by_handle!(second.handle).handle_digest

    assert {:deny, %{reason: :binding_mismatch}} =
             CrosswakeContinuations.complete(
               first.handle,
               second_token,
               correlation(first),
               @as_of,
               evaluator: notifying_evaluator(self())
             )

    refute_receive :crosswake_evaluator_called
    assert_terminal(first.handle, "denied", "binding_mismatch")

    assert {:allow, _} =
             CrosswakeContinuations.complete(
               second.handle,
               second_token,
               correlation(second),
               @as_of,
               evaluator: notifying_evaluator(self())
             )

    assert_receive :crosswake_evaluator_called
  end

  test "cleanup removes at most 500 oldest terminal rows without weakening live claims" do
    {raw_token, _session, _user} = session_with_raw_token(@as_of)

    old_records =
      for seconds <- 1..501 do
        assert {:ok, issued} =
                 CrosswakeContinuations.issue(raw_token, DateTime.add(@as_of, -seconds, :second))

        issued
      end

    assert {:ok, live} = CrosswakeContinuations.issue(raw_token, @as_of, ttl_seconds: 60)
    assert {500, nil} = CrosswakeContinuations.cleanup_expired(@as_of, limit: 500)

    assert Repo.aggregate(CrosswakeContinuation, :count) == 2
    assert Repo.exists?(from(c in CrosswakeContinuation, where: c.handle_digest == ^digest(live.handle)))

    assert {:allow, _} =
             CrosswakeContinuations.complete(
               live.handle,
               raw_token,
               correlation(live),
               @as_of,
               evaluator: notifying_evaluator(self())
             )

    assert_receive :crosswake_evaluator_called
    assert Enum.any?(old_records, &is_binary(&1.handle))
  end

  defp session_with_raw_token(as_of) do
    user = user_fixture()
    raw_bytes = :crypto.strong_rand_bytes(32)
    raw_token = Base.url_encode64(raw_bytes, padding: false)

    session =
      session_fixture(user, %{
        hashed_token: Sigra.Token.hash_token(raw_bytes),
        inserted_at: as_of,
        last_active_at: as_of
      })

    {raw_token, session, user}
  end

  defp correlation(issued), do: %{"state" => issued.state, "pkce_verifier" => issued.pkce_verifier}
  defp by_handle!(handle), do: Repo.one!(from(c in CrosswakeContinuation, where: c.handle_digest == ^digest(handle)))

  defp assert_terminal(handle, outcome, reason) do
    record = by_handle!(handle)
    assert is_struct(record.consumed_at, DateTime)
    assert record.outcome == outcome
    assert record.reason == reason
  end

  defp receive_ready(barrier) do
    assert_receive {:claim_ready, pid, ^barrier}
    pid
  end

  defp notifying_evaluator(test_pid) do
    fn _route, _context, _opts ->
      send(test_pid, :crosswake_evaluator_called)
      {:allow, %{}}
    end
  end

  defp digest(value), do: :crypto.hash(:sha256, value)
end
