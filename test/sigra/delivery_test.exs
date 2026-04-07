defmodule Sigra.DeliveryTest do
  use ExUnit.Case, async: true

  import Mox

  alias Sigra.Delivery

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
      # Use a simple module that captures the insert call
      defmodule FakeOban do
        def insert(changeset) do
          {:ok, %{id: 1, args: changeset.changes[:args]}}
        end
      end

      args = %{user_id: 42, token: "abc123"}

      assert {:ok, %{id: 1, args: job_args}} =
               Delivery.deliver_async(:confirmation, args, oban: FakeOban)

      assert job_args["email_type"] == "confirmation"
      assert job_args["user_id"] == 42
    end

    test "returns {:error, reason} when Oban.insert fails" do
      defmodule FailingOban do
        def insert(_changeset) do
          {:error, :queue_full}
        end
      end

      args = %{user_id: 1}

      assert {:error, :queue_full} =
               Delivery.deliver_async(:reset, args, oban: FailingOban)
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
      defmodule FakeOban2 do
        def insert(changeset) do
          {:ok, %{id: 2, args: changeset.changes[:args]}}
        end
      end

      args = %{user_id: 1, token: "tok"}

      assert {:ok, _job} =
               Delivery.deliver(:reset, args,
                 delivery_mode: :async,
                 oban: FakeOban2
               )
    end

    test "with delivery_mode: :auto detects Oban presence" do
      # Oban is loaded in test env, so auto should route to async
      defmodule FakeOban3 do
        def insert(changeset) do
          {:ok, %{id: 3, args: changeset.changes[:args]}}
        end
      end

      args = %{user_id: 1, token: "tok"}

      assert {:ok, _job} =
               Delivery.deliver(:confirmation, args,
                 delivery_mode: :auto,
                 oban: FakeOban3
               )
    end
  end
end
