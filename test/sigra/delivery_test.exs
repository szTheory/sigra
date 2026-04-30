defmodule Sigra.DeliveryTest do
  use ExUnit.Case, async: true

  import Mox

  alias Sigra.Delivery
  alias Sigra.OptionalDeps.MissingDependencyError
  alias Sigra.Workers.EmailDelivery

  # Fake Oban modules for testing async delivery without a running Oban instance
  defmodule FakeOban do
    def insert(changeset) do
      {:ok, %{id: 1, args: changeset.changes[:args]}}
    end
  end

  defmodule FailingOban do
    def insert(_changeset) do
      {:error, :queue_full}
    end
  end

  setup :verify_on_exit!

  describe "deliver_sync/3" do
    test "calls mailer.deliver and returns {:ok, result}" do
      Sigra.MockMailer
      |> expect(:deliver, fn "user@example.com", "Welcome", %{text: "Hello"} ->
        {:ok, %{id: "msg-123"}}
      end)

      args = %{to: "user@example.com", subject: "Welcome", body: %{text: "Hello"}}

      assert {:ok, %{id: "msg-123"}} =
               Delivery.deliver_sync(:confirmation, args, mailer: Sigra.MockMailer)
    end

    test "returns {:error, reason} when mailer fails" do
      Sigra.MockMailer
      |> expect(:deliver, fn _to, _subject, _body ->
        {:error, :smtp_error}
      end)

      args = %{to: "user@example.com", subject: "Reset", body: %{text: "Reset link"}}

      assert {:error, :smtp_error} =
               Delivery.deliver_sync(:reset, args, mailer: Sigra.MockMailer)
    end
  end

  describe "build_job/3" do
    test "builds an Oban job changeset with correct args" do
      args = %{user_id: 42, token: "abc123", code: nil, url: "https://example.com/confirm"}

      changeset = Delivery.build_job(:confirmation, args, oban_queue: "sigra_mailer")

      assert changeset.valid?
      assert changeset.changes[:args]["email_type"] == "confirmation"
      assert changeset.changes[:args]["user_id"] == 42
      assert changeset.changes[:args]["token"] == "abc123"
      assert changeset.changes[:args]["url"] == "https://example.com/confirm"
    end

    test "uses default oban_queue when not specified" do
      args = %{user_id: 1}

      changeset = Delivery.build_job(:reset, args)

      assert changeset.valid?
      assert changeset.changes[:queue] == "sigra_mailer"
    end

    test "stores only minimal args (not email body)" do
      args = %{user_id: 42, token: "tok", code: "123456", url: "https://example.com"}

      changeset = Delivery.build_job(:confirmation, args)
      job_args = changeset.changes[:args]

      # Only these keys should be present (T-3-INFRA-01)
      assert Map.keys(job_args) |> Enum.sort() ==
               ["code", "email_type", "token", "url", "user_id"]
    end
  end

  describe "deliver_async/3" do
    test "inserts an Oban job via Oban.insert" do
      args = %{user_id: 42, token: "abc123"}

      assert {:ok, %{id: 1, args: job_args}} =
               Delivery.deliver_async(:confirmation, args, oban: FakeOban)

      assert job_args["email_type"] == "confirmation"
      assert job_args["user_id"] == 42
    end

    test "returns {:error, reason} when Oban.insert fails" do
      args = %{user_id: 1}

      assert {:error, :queue_full} =
               Delivery.deliver_async(:reset, args, oban: FailingOban)
    end

    test "raises a tagged missing dependency error when async delivery is requested without Oban" do
      args = %{user_id: 42, token: "abc123"}

      assert_raise MissingDependencyError, ~r/optional dependency missing for async_email/, fn ->
        Delivery.deliver_async(:confirmation, args, dependency_loaded?: fn _spec -> false end)
      end
    end
  end

  describe "deliver/3" do
    test "with delivery_mode: :sync uses synchronous path" do
      Sigra.MockMailer
      |> expect(:deliver, fn "user@example.com", "Test", %{text: "body"} ->
        {:ok, :sent}
      end)

      args = %{to: "user@example.com", subject: "Test", body: %{text: "body"}}

      assert {:ok, :sent} =
               Delivery.deliver(:test_email, args,
                 delivery_mode: :sync,
                 mailer: Sigra.MockMailer
               )
    end

    test "with delivery_mode: :async uses Oban path" do
      args = %{user_id: 1, token: "tok"}

      assert {:ok, _job} =
               Delivery.deliver(:reset, args,
                 delivery_mode: :async,
                 oban: FakeOban
               )
    end

    test "with delivery_mode: :async raises when Oban is unavailable" do
      args = %{user_id: 1, token: "tok"}

      assert_raise MissingDependencyError, ~r/optional dependency missing for async_email/, fn ->
        Delivery.deliver(:reset, args,
          delivery_mode: :async,
          dependency_loaded?: fn _spec -> false end
        )
      end
    end

    test "with delivery_mode: :auto routes to :sync when Oban is not supervised" do
      # Oban is loadable in test env (it's a library dep) but NOT supervised,
      # so :auto must route to :sync — otherwise apps that add {:oban, ...} to
      # deps without wiring the supervisor would crash on insert.
      Sigra.MockMailer
      |> expect(:deliver, fn "user@example.com", "Test", %{text: "body"} ->
        {:ok, :sent}
      end)

      args = %{to: "user@example.com", subject: "Test", body: %{text: "body"}}

      assert {:ok, :sent} =
               Delivery.deliver(:test_email, args,
                 delivery_mode: :auto,
                 dependency_loaded?: fn _spec -> false end,
                 mailer: Sigra.MockMailer
               )
    end

    test "with delivery_mode: :auto routes to :async when Oban process is registered" do
      # Simulate a supervised Oban by registering a dummy process under the
      # Oban name. Delivery.oban_running?/0 checks Process.whereis(Oban).
      dummy = spawn(fn -> Process.sleep(:infinity) end)
      Process.register(dummy, Oban)
      on_exit(fn -> Process.exit(dummy, :kill) end)

      args = %{user_id: 1, token: "tok"}

      assert {:ok, _job} =
               Delivery.deliver(:confirmation, args,
                 delivery_mode: :auto,
                 oban: FakeOban
               )
    end
  end

  describe "EmailDelivery worker boundary" do
    test "stays loadable and raises a tagged missing dependency error at first queue-backed use" do
      assert Code.ensure_loaded?(EmailDelivery)

      assert_raise MissingDependencyError, ~r/optional dependency missing for async_email/, fn ->
        EmailDelivery.new(%{"email_type" => "confirmation", "user_id" => 42},
          dependency_loaded?: fn _spec -> false end
        )
      end
    end
  end
end
