defmodule Sigra.Workers.EmailDeliveryTest do
  use ExUnit.Case, async: true

  alias Sigra.Workers.EmailDelivery

  describe "perform/1" do
    test "executes successfully and returns {:ok, :delivered}" do
      job = %Oban.Job{
        args: %{
          "email_type" => "confirmation",
          "user_id" => 42,
          "token" => "abc123",
          "code" => nil,
          "url" => "https://example.com/confirm"
        }
      }

      assert {:ok, :delivered} = EmailDelivery.perform(job)
    end
  end

  describe "backoff/1" do
    test "returns exponential backoff values" do
      job1 = %Oban.Job{attempt: 1}
      job2 = %Oban.Job{attempt: 2}
      job3 = %Oban.Job{attempt: 3}

      backoff1 = EmailDelivery.backoff(job1)
      backoff2 = EmailDelivery.backoff(job2)
      backoff3 = EmailDelivery.backoff(job3)

      # Attempt 1: 1^4 + 15 + rand(1..10)*1 = 16..26
      assert backoff1 >= 16
      assert backoff1 <= 26

      # Attempt 2: 2^4 + 15 + rand(1..10)*2 = 33..51 (16+15+2..20)
      assert backoff2 >= 33
      assert backoff2 <= 51

      # Attempt 3: 3^4 + 15 + rand(1..10)*3 = 99..126 (81+15+3..30)
      assert backoff3 >= 99
      assert backoff3 <= 126
    end

    test "increases with each attempt" do
      # Use min possible values for comparison
      job1 = %Oban.Job{attempt: 1}
      job2 = %Oban.Job{attempt: 2}

      # Run multiple times to account for randomness
      results =
        for _ <- 1..10 do
          b1 = EmailDelivery.backoff(job1)
          b2 = EmailDelivery.backoff(job2)
          b2 > b1
        end

      # Should always be true given the exponential base
      assert Enum.all?(results)
    end
  end

  describe "new/2" do
    test "creates a valid changeset with queue" do
      args = %{"email_type" => "confirmation", "user_id" => 1}
      changeset = EmailDelivery.new(args, queue: "sigra_mailer")

      assert changeset.valid?
      assert changeset.changes[:args] == args
    end
  end
end
