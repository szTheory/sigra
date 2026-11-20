defmodule Sigra.RecoveryTestDispatcher do
  @behaviour Sigra.Recovery

  @impl true
  def enqueue(host_id, envelope, opts) do
    send(Keyword.fetch!(opts, :owner), {:recovery_enqueued, host_id, envelope})
    {:ok, :stored}
  end

  @impl true
  def checkpoint_once(_job_ref, _repo, _prepare, _opts), do: {:error, :unused}
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
end
