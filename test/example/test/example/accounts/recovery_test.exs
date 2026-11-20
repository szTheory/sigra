defmodule Example.Accounts.RecoveryTest do
  use Example.DataCase, async: false

  import Ecto.Query
  import Example.AccountsFixtures
  import Swoosh.TestAssertions

  alias Example.Accounts
  alias Example.Accounts.AuditEvent
  alias Example.Accounts.UserToken
  alias Example.Repo
  alias Sigra.Workers.RecoveryRequest

  setup do
    previous_hosts = Application.get_env(:sigra, :recovery_hosts)
    Application.put_env(:sigra, :recovery_hosts, %{"example" => Accounts})

    start_supervised!(
      {Oban, name: Oban, repo: Repo, queues: false, plugins: false, testing: :manual}
    )

    on_exit(fn ->
      if is_nil(previous_hosts) do
        Application.delete_env(:sigra, :recovery_hosts)
      else
        Application.put_env(:sigra, :recovery_hosts, previous_hosts)
      end
    end)

    :ok
  end

  test "a persisted reset request delivers a redeemable link only after the worker runs" do
    user = user_fixture()

    assert {:ok, :accepted} = Accounts.enqueue_recovery_request(:reset, user.email)

    job =
      Repo.one!(
        from job in Oban.Job,
          where: job.worker == "Sigra.Workers.RecoveryRequest",
          where: job.queue == "sigra_recovery"
      )

    assert job.args["host_id"] == "example"
    assert is_binary(job.args["envelope"])
    refute job.args["envelope"] =~ user.email
    refute Map.has_key?(job.args, "email")
    refute Map.has_key?(job.args, "token")

    assert Repo.aggregate(
             from(token in UserToken,
               where: token.user_id == ^user.id and token.context == "reset_password"
             ),
             :count
           ) == 0

    assert Repo.aggregate(
             from(event in AuditEvent,
               where:
                 event.target_id == ^user.id and event.action == "auth.password_reset_request"
             ),
             :count
           ) == 0

    assert {:ok, :delivered} = RecoveryRequest.perform(job)

    assert Repo.aggregate(
             from(token in UserToken,
               where: token.user_id == ^user.id and token.context == "reset_password"
             ),
             :count
           ) == 1

    assert_email_sent(fn email ->
      send(self(), {:recovery_email, email})
      email.subject == "Reset your password"
    end)

    assert_received {:recovery_email, email}
    assert email.to == [{"", user.email}]

    assert [_, signed_token] =
             Regex.run(~r{/users/reset-password/([A-Za-z0-9_-]+)}, email.text_body)

    decoded = Base.url_decode64(signed_token, padding: false)
    assert elem(decoded, 0) == :ok
    {:ok, signed} = decoded

    verified =
      Plug.Crypto.verify(Accounts.recovery_secret_key_base(), "sigra-reset-token", signed)

    assert elem(verified, 0) == :ok
    {:ok, raw_token} = verified

    assert Repo.get_by(UserToken,
             token: Sigra.Token.hash_token(raw_token),
             context: "reset_password"
           )

    assert Accounts.get_user_by_reset_password_token(signed_token).id == user.id
  end
end
