defmodule Sigra.RecoveryTestDispatcher do
  @behaviour Sigra.Recovery

  @impl true
  def enqueue(host_id, envelope, opts) do
    case Keyword.get(opts, :result, :ok) do
      :ok ->
        send(Keyword.fetch!(opts, :owner), {:recovery_enqueued, host_id, envelope})
        {:ok, :stored}

      other ->
        {:error, other}
    end
  end

  @impl true
  def checkpoint_once(_job_ref, _repo, _prepare, opts) do
    if owner = Keyword.get(opts, :owner), do: send(owner, :recovery_checkpoint_called)
    {:error, :unused}
  end
end

defmodule Sigra.RecoveryTestHandler do
  def prepare_recovery_request(_operation, _address), do: {:ok, %{descriptor: %{delivery: nil}}}
  def deliver_recovery_request(_descriptor), do: {:ok, :suppressed}
end

defmodule Sigra.RecoveryTestLimiter do
  @behaviour Sigra.RateLimiter

  @impl true
  def check_rate(key, max_requests, window_ms) do
    send(Process.get(:recovery_test_owner), {:rate_checked, key, max_requests, window_ms})
    {:deny, 1_000}
  end
end

defmodule Sigra.RecoveryTest do
  use ExUnit.Case, async: true

  alias Sigra.Recovery

  @secret String.duplicate("r", 64)

  test "an envelope issued outside its finite age is rejected" do
    assert {:ok, :accepted} =
             Recovery.enqueue(:reset, "expired@example.test",
               host_id: "test-host",
               secret_key_base: @secret,
               dispatcher: Sigra.RecoveryTestDispatcher,
               dispatch_opts: [owner: self()],
               issued_at: 1
             )

    assert_received {:recovery_enqueued, "test-host", envelope}
    assert elem(Recovery.decrypt_envelope(envelope, "test-host", @secret), 0) == :error
  end

  test "known and unknown addresses use the same encrypted dispatcher input" do
    for address <- ["known@example.test", "unknown@example.test"] do
      assert {:ok, :accepted} = enqueue(address, owner: self())
    end

    assert_received {:recovery_enqueued, "test-host", known_envelope}
    assert_received {:recovery_enqueued, "test-host", unknown_envelope}
    refute known_envelope =~ "known@example.test"
    refute unknown_envelope =~ "unknown@example.test"

    assert {:ok, {:reset, "known@example.test"}} =
             Recovery.decrypt_envelope(known_envelope, "test-host", @secret)

    assert {:ok, {:reset, "unknown@example.test"}} =
             Recovery.decrypt_envelope(unknown_envelope, "test-host", @secret)
  end

  test "rate limit denial happens before dispatch and preserves the reset key" do
    Process.put(:recovery_test_owner, self())

    assert {:error, :rate_limited} =
             enqueue("denied@example.test",
               owner: self(),
               rate_limiter: Sigra.RecoveryTestLimiter,
               max_requests: 7,
               window_ms: 123_000
             )

    assert_received {:rate_checked, "sigra:reset:denied@example.test", 7, 123_000}
    refute_received {:recovery_enqueued, _, _}
    Process.delete(:recovery_test_owner)
  end

  test "missing and failing dispatch configuration returns one fixed error" do
    assert {:error, :recovery_unavailable} = Recovery.enqueue(:reset, "known@example.test", [])

    assert {:error, :recovery_unavailable} =
             enqueue("known@example.test", owner: self(), result: :database_secret_failure)

    refute_received {:recovery_enqueued, _, _}
  end

  test "malformed addresses are distinguished without dispatch or account lookup" do
    assert {:error, :invalid_request} = Recovery.enqueue(:reset, "not-an-email", [])

    assert {:error, :invalid_request} =
             Recovery.enqueue(:magic_link, String.duplicate("a", 513), [])

    refute_received {:recovery_enqueued, _, _}
  end

  test "tampered and wrong-host envelopes are rejected" do
    assert {:ok, :accepted} = enqueue("known@example.test", owner: self())
    assert_received {:recovery_enqueued, "test-host", envelope}

    <<first, rest::binary>> = envelope
    tampered = <<Bitwise.bxor(first, 1), rest::binary>>

    assert {:error, :invalid_envelope} = Recovery.decrypt_envelope(tampered, "test-host", @secret)

    assert {:error, :invalid_envelope} =
             Recovery.decrypt_envelope(envelope, "other-host", @secret)

    <<first, rest::binary>> = envelope
    tampered = <<Bitwise.bxor(first, 1), rest::binary>>

    assert {:error, :invalid_envelope} =
             Recovery.process_request(1, "test-host", tampered,
               handler: Sigra.RecoveryTestHandler,
               dispatcher: Sigra.RecoveryTestDispatcher,
               repo: Sigra.Repo,
               secret_key_base: @secret,
               owner: self()
             )

    refute_received :recovery_checkpoint_called
  end

  defp enqueue(address, dispatch_overrides) do
    dispatch_opts =
      Keyword.merge([owner: self()], Keyword.take(dispatch_overrides, [:result]))

    api_opts = Keyword.drop(dispatch_overrides, [:owner, :result])

    Recovery.enqueue(
      :reset,
      address,
      Keyword.merge(
        [
          host_id: "test-host",
          secret_key_base: @secret,
          dispatcher: Sigra.RecoveryTestDispatcher,
          dispatch_opts: dispatch_opts
        ],
        api_opts
      )
    )
  end
end
