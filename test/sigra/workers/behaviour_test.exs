defmodule Sigra.WorkersBehaviourTest do
  use ExUnit.Case, async: true

  alias Sigra.Workers

  # Stub worker used to verify that Sigra.Workers.new/3 validates required
  # args BEFORE delegating to the underlying worker's new/2. We do not want
  # to go through an actual Oban enqueue in this test — the point is the
  # fail-fast arg validation, not the Oban call path.
  defmodule StubWorker do
    @behaviour Sigra.Workers

    @impl Sigra.Workers
    def perform(_scope, _args), do: :ok

    # Pretend to be an Oban.Worker: just echo args so we know the apply
    # dispatch worked and we did not raise on missing args.
    def new(args, opts) when is_map(args) and is_list(opts) do
      {:ok, %{args: args, opts: opts}}
    end
  end

  describe "new/3 required-key validation" do
    test "raises ArgumentError with 'organization_id' in message when absent" do
      assert_raise ArgumentError, ~r/organization_id/, fn ->
        Workers.new(StubWorker, %{"actor_id" => nil}, [])
      end
    end

    test "raises ArgumentError with 'actor_id' in message when absent" do
      assert_raise ArgumentError, ~r/actor_id/, fn ->
        Workers.new(StubWorker, %{"organization_id" => nil}, [])
      end
    end

    test "accepts nil values for both required keys" do
      assert {:ok, %{args: args}} =
               Workers.new(StubWorker, %{"organization_id" => nil, "actor_id" => nil}, [])

      assert args["organization_id"] == nil
      assert args["actor_id"] == nil
    end

    test "does NOT require audit_schema (worker-specific concern)" do
      assert {:ok, _} =
               Workers.new(
                 StubWorker,
                 %{"organization_id" => "org-1", "actor_id" => "user-1"},
                 []
               )
    end

    test "forwards opts through to the worker" do
      assert {:ok, %{opts: [queue: :custom]}} =
               Workers.new(
                 StubWorker,
                 %{"organization_id" => "org-1", "actor_id" => "user-1"},
                 queue: :custom
               )
    end
  end

  describe "fetch_arg!/2" do
    test "returns the value when the key is present" do
      assert "hello" == Workers.fetch_arg!(%{"foo" => "hello"}, "foo")
    end

    test "returns nil when the key is present with a nil value" do
      assert nil == Workers.fetch_arg!(%{"foo" => nil}, "foo")
    end

    test "raises KeyError when the key is absent" do
      assert_raise KeyError, fn -> Workers.fetch_arg!(%{}, "absent") end
    end
  end
end
