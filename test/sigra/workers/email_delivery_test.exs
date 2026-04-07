defmodule Sigra.Workers.EmailDeliveryTest do
  use ExUnit.Case, async: false

  alias Sigra.Workers.EmailDelivery

  # -- Mock modules for testing --

  defmodule MockUser do
    defstruct [:id, :email]
  end

  defmodule MockRepo do
    def get(MockUser, id) do
      case Process.get(:mock_repo_result, :default) do
        :nil_user -> nil
        :default -> %MockUser{id: id, email: "user@example.com"}
        user -> user
      end
    end
  end

  defmodule MockEmails do
    def confirmation_email(user, url, code) do
      %{
        subject: "Confirm your email",
        html_body: "<p>Confirm #{user.email} at #{url} with #{code}</p>",
        text_body: "Confirm #{user.email} at #{url} with #{code}"
      }
    end

    def reset_password_email(user, url) do
      %{
        subject: "Reset your password",
        html_body: "<p>Reset #{user.email} at #{url}</p>",
        text_body: "Reset #{user.email} at #{url}"
      }
    end

    def magic_link_email(user, url) do
      %{
        subject: "Log in to your account",
        html_body: "<p>Log in #{user.email} at #{url}</p>",
        text_body: "Log in #{user.email} at #{url}"
      }
    end
  end

  defmodule MockMailer do
    def deliver(to, subject, body) do
      case Process.get(:mock_mailer_result, :ok) do
        :ok -> {:ok, %{to: to, subject: subject, body: body}}
        :error -> {:error, :delivery_failed}
      end
    end
  end

  setup do
    Application.put_env(:sigra, :repo, MockRepo)
    Application.put_env(:sigra, :user_schema, MockUser)
    Application.put_env(:sigra, :email_module, MockEmails)
    Application.put_env(:sigra, :mailer, MockMailer)

    on_exit(fn ->
      Application.delete_env(:sigra, :repo)
      Application.delete_env(:sigra, :user_schema)
      Application.delete_env(:sigra, :email_module)
      Application.delete_env(:sigra, :mailer)
      Process.delete(:mock_repo_result)
      Process.delete(:mock_mailer_result)
    end)
  end

  describe "perform/1" do
    test "delivers confirmation email successfully" do
      job = %Oban.Job{
        args: %{
          "email_type" => "confirmation",
          "user_id" => 42,
          "token" => "abc123",
          "code" => "123456",
          "url" => "https://example.com/confirm"
        }
      }

      assert {:ok, :delivered} = EmailDelivery.perform(job)
    end

    test "delivers reset_password email successfully" do
      job = %Oban.Job{
        args: %{
          "email_type" => "reset_password",
          "user_id" => 42,
          "url" => "https://example.com/reset"
        }
      }

      assert {:ok, :delivered} = EmailDelivery.perform(job)
    end

    test "delivers magic_link email successfully" do
      job = %Oban.Job{
        args: %{
          "email_type" => "magic_link",
          "user_id" => 42,
          "url" => "https://example.com/magic"
        }
      }

      assert {:ok, :delivered} = EmailDelivery.perform(job)
    end

    test "returns {:cancel, :user_not_found} when user does not exist" do
      Process.put(:mock_repo_result, :nil_user)

      job = %Oban.Job{
        args: %{
          "email_type" => "confirmation",
          "user_id" => 999
        }
      }

      assert {:cancel, :user_not_found} = EmailDelivery.perform(job)
    end

    test "returns {:error, reason} when mailer delivery fails" do
      Process.put(:mock_mailer_result, :error)

      job = %Oban.Job{
        args: %{
          "email_type" => "confirmation",
          "user_id" => 42,
          "url" => "https://example.com/confirm",
          "code" => "123456"
        }
      }

      assert {:error, :delivery_failed} = EmailDelivery.perform(job)
    end

    test "returns {:cancel, _} for unknown email type" do
      job = %Oban.Job{
        args: %{
          "email_type" => "unknown_type",
          "user_id" => 42
        }
      }

      assert {:cancel, message} = EmailDelivery.perform(job)
      assert message =~ "unknown email type"
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
