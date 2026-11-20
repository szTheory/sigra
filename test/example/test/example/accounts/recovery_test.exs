defmodule Example.RecoveryDatabaseDispatcher do
  @behaviour Sigra.Recovery

  import Ecto.Query

  @checkpoint_key "example_recovery_checkpoint_v1"

  @impl true
  def enqueue(host_id, envelope, opts) do
    repo = Keyword.fetch!(opts, :repo)

    Oban.Job.new(%{"host_id" => host_id, "envelope" => envelope},
      worker: __MODULE__,
      queue: :sigra_recovery
    )
    |> repo.insert()
  end

  @impl true
  def checkpoint_once(job_ref, repo, prepare, opts) do
    host_id = Keyword.fetch!(opts, :host_id)
    secret = Keyword.fetch!(opts, :secret_key_base)
    prefix = Keyword.get(opts, :prefix, "public")

    transaction_result =
      repo.transact(fn ->
        job =
          repo.one(
            from job in Oban.Job,
              prefix: ^prefix,
              where: job.id == ^job_ref,
              lock: "FOR UPDATE"
          )

        case job && Map.get(job.meta || %{}, @checkpoint_key) do
          nil ->
            case prepare.() do
              {:ok, %{descriptor: descriptor, audit_changes: audit_changes}} ->
                if Keyword.get(opts, :fail_checkpoint, false) do
                  {:error, :injected_checkpoint_failure}
                else
                  {:ok, encrypted} =
                    Sigra.Recovery.encrypt_checkpoint(secret, host_id, job_ref, descriptor)

                  changeset =
                    Oban.Job.update(job, %{
                      meta: Map.put(job.meta || %{}, @checkpoint_key, encrypted)
                    })

                  with {:ok, _updated} <- repo.update(changeset, prefix: prefix) do
                    {:ok, {descriptor, true, audit_changes}}
                  end
                end

              _ ->
                {:error, :prepare_failed}
            end

          encrypted when is_binary(encrypted) ->
            case Sigra.Recovery.decrypt_checkpoint(secret, host_id, job_ref, encrypted) do
              {:ok, descriptor} -> {:ok, {descriptor, false, %{}}}
              _ -> {:error, :invalid_checkpoint}
            end

          _ ->
            {:error, :missing_job}
        end
      end)

    case transaction_result do
      {:ok, {descriptor, fresh?, audit_changes}} ->
        {:ok, descriptor, fresh?, audit_changes}

      {:error, _} ->
        {:error, :recovery_failed}
    end
  end
end

defmodule Example.RecoveryFailOnceMailer do
  @behaviour Sigra.Mailer

  @impl true
  def deliver(to, subject, body) do
    if Process.get(:recovery_mailer_fail_next, false) do
      Process.delete(:recovery_mailer_fail_next)
      send(self(), {:recovery_mailer, :failed, to, subject, body})
      {:error, :injected_delivery_failure}
    else
      send(self(), {:recovery_mailer, :accepted, to, subject, body})
      {:ok, :accepted}
    end
  end
end

defmodule Example.Accounts.RecoveryTest do
  use Example.DataCase, async: false

  import Ecto.Query
  import Example.AccountsFixtures
  import Swoosh.TestAssertions

  alias Example.Accounts
  alias Example.Accounts.AuditEvent
  alias Example.Accounts.UserToken
  alias Example.Accounts.Scope
  alias Example.Repo
  alias Sigra.Workers.RecoveryRequest

  setup tags do
    previous_hosts = Application.get_env(:sigra, :recovery_hosts)
    Application.put_env(:sigra, :recovery_hosts, %{"example" => Accounts})

    if tags[:recovery_oban] do
      start_supervised!(
        {Oban, name: Oban, repo: Repo, queues: false, plugins: false, testing: :manual}
      )
    end

    on_exit(fn ->
      if is_nil(previous_hosts) do
        Application.delete_env(:sigra, :recovery_hosts)
      else
        Application.put_env(:sigra, :recovery_hosts, previous_hosts)
      end
    end)

    :ok
  end

  @tag :recovery_oban
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

  @tag :recovery_oban
  test "a persisted magic-link request delivers a single-use link only after the worker runs" do
    user = user_fixture()

    assert {:ok, :accepted} = Accounts.enqueue_recovery_request(:magic_link, user.email)

    job =
      Repo.one!(
        from job in Oban.Job,
          where: job.worker == "Sigra.Workers.RecoveryRequest",
          where: job.queue == "sigra_recovery"
      )

    refute Repo.get_by(UserToken, user_id: user.id, context: "magic_link")
    assert {:ok, :delivered} = RecoveryRequest.perform(job)

    assert_email_sent(fn email ->
      send(self(), {:magic_link_email, email})
      email.subject == "Log in to Example"
    end)

    assert_received {:magic_link_email, email}
    assert email.to == [{"", user.email}]

    assert [_, raw_token] = Regex.run(~r{/users/log_in/([A-Za-z0-9_-]+)}, email.text_body)
    assert {:ok, redeemed_user} = Accounts.verify_magic_link(raw_token)
    assert redeemed_user.id == user.id
    refute Repo.get_by(UserToken, user_id: user.id, context: "magic_link")
    assert {:error, :invalid} = Accounts.verify_magic_link(raw_token)
  end

  test "a host database dispatcher works without starting Oban" do
    user = user_fixture()
    assert Oban.whereis(Oban) == nil

    assert {:ok, :accepted} =
             enqueue_with_dispatcher(user.email, Example.RecoveryDatabaseDispatcher, repo: Repo)

    job =
      Repo.one!(
        from job in Oban.Job,
          where: job.worker == "Example.RecoveryDatabaseDispatcher"
      )

    assert job.args["host_id"] == "example"
    refute job.args["envelope"] =~ user.email

    assert {:ok, :delivered} =
             Sigra.Recovery.process_request(
               job.id,
               "example",
               job.args["envelope"],
               handler: Accounts,
               dispatcher: Example.RecoveryDatabaseDispatcher,
               repo: Repo,
               secret_key_base: Accounts.recovery_secret_key_base(),
               prefix: "public"
             )

    assert Repo.get_by(UserToken, user_id: user.id, context: "reset_password")
  end

  test "an unknown address reaches the worker without token, audit, or mail" do
    assert {:ok, :accepted} =
             enqueue_with_dispatcher(
               "missing-#{System.unique_integer([:positive])}@example.test",
               Example.RecoveryDatabaseDispatcher,
               repo: Repo
             )

    job =
      Repo.one!(
        from job in Oban.Job,
          where: job.worker == "Example.RecoveryDatabaseDispatcher"
      )

    assert {:ok, :no_delivery} =
             Sigra.Recovery.process_request(
               job.id,
               "example",
               job.args["envelope"],
               handler: Accounts,
               dispatcher: Example.RecoveryDatabaseDispatcher,
               repo: Repo,
               secret_key_base: Accounts.recovery_secret_key_base(),
               prefix: "public"
             )

    assert Repo.aggregate(UserToken, :count) == 0
    assert Repo.aggregate(AuditEvent, :count) == 0
    refute_email_sent()
  end

  @tag :recovery_oban
  test "an SSO-only reset request sends the existing enterprise guidance email" do
    user = user_fixture()
    owner = user_fixture()
    organization = create_organization(%{name: "Acme Recovery", slug: "acme-recovery"})
    create_membership(owner, organization, :owner)
    create_membership(user, organization, :member)

    assert {:ok, _policy_state} =
             Example.Organizations.enable_sso_only(
               %Scope{user: owner, active_organization: organization},
               [owner.id]
             )

    assert {:ok, :accepted} = Accounts.enqueue_recovery_request(:reset, user.email)

    job =
      Repo.one!(
        from job in Oban.Job,
          where: job.worker == "Sigra.Workers.RecoveryRequest",
          where: job.queue == "sigra_recovery"
      )

    assert {:ok, :delivered} = RecoveryRequest.perform(job)

    assert_email_sent(fn email ->
      email.subject == "Use enterprise sign-in" and
        String.contains?(email.text_body, "/organizations/acme-recovery/sso")
    end)

    refute Repo.get_by(UserToken, user_id: user.id, context: "reset_password")
    refute Repo.get_by(AuditEvent, target_id: user.id, action: "auth.password_reset_request")
  end

  test "issuance and audit roll back when the durable checkpoint fails" do
    user = user_fixture()

    assert {:ok, :accepted} =
             enqueue_with_dispatcher(user.email, Example.RecoveryDatabaseDispatcher, repo: Repo)

    job =
      Repo.one!(
        from job in Oban.Job,
          where: job.worker == "Example.RecoveryDatabaseDispatcher"
      )

    assert {:error, :recovery_failed} =
             Sigra.Recovery.process_request(
               job.id,
               "example",
               job.args["envelope"],
               handler: Accounts,
               dispatcher: Example.RecoveryDatabaseDispatcher,
               repo: Repo,
               secret_key_base: Accounts.recovery_secret_key_base(),
               prefix: "public",
               fail_checkpoint: true
             )

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
  end

  @tag :recovery_oban
  test "a mailbox change suppresses a checkpointed recovery retry" do
    user = user_fixture()
    original_email = user.email
    previous_mailer = Application.get_env(:example, :recovery_mailer)
    Application.put_env(:example, :recovery_mailer, Example.RecoveryFailOnceMailer)
    Process.put(:recovery_mailer_fail_next, true)

    on_exit(fn ->
      Process.delete(:recovery_mailer_fail_next)

      if is_nil(previous_mailer) do
        Application.delete_env(:example, :recovery_mailer)
      else
        Application.put_env(:example, :recovery_mailer, previous_mailer)
      end
    end)

    assert {:ok, :accepted} = Accounts.enqueue_recovery_request(:reset, original_email)

    job =
      Repo.one!(
        from job in Oban.Job,
          where: job.worker == "Sigra.Workers.RecoveryRequest",
          where: job.queue == "sigra_recovery"
      )

    assert {:error, :recovery_failed} = RecoveryRequest.perform(job)
    assert_received {:recovery_mailer, :failed, ^original_email, "Reset your password", _body}

    user
    |> Ecto.Changeset.change(email: "changed-#{System.unique_integer([:positive])}@example.com")
    |> Repo.update!()

    assert {:ok, :delivered} = RecoveryRequest.perform(job)
    refute_received {:recovery_mailer, :accepted, _, _, _}
  end

  test "a magic link is not consumed after the account requires SSO" do
    user = user_fixture()
    owner = user_fixture()
    organization = create_organization(%{name: "Acme Magic Link", slug: "acme-magic-link"})
    create_membership(owner, organization, :owner)
    create_membership(user, organization, :member)

    assert {:ok, {raw_token, _url}} =
             Accounts.request_magic_link(user.email, &"https://example.test/magic/#{&1}")

    {:ok, decoded_token} = Base.url_decode64(raw_token, padding: false)
    hashed_token = Sigra.Token.hash_token(decoded_token)

    assert Repo.get_by(UserToken, token: hashed_token, context: "magic_link")

    assert {:ok, _policy_state} =
             Example.Organizations.enable_sso_only(
               %Scope{user: owner, active_organization: organization},
               [owner.id]
             )

    assert {:error, :invalid} = Accounts.verify_magic_link(raw_token)
    assert Repo.get_by(UserToken, token: hashed_token, context: "magic_link")

    refute Repo.get_by(AuditEvent,
             target_id: user.id,
             action: "auth.magic_link_verify.success"
           )
  end

  test "a magic link sent to an old mailbox is not consumed" do
    user = user_fixture()

    assert {:ok, {raw_token, _url}} =
             Accounts.request_magic_link(user.email, &"https://example.test/magic/#{&1}")

    {:ok, decoded_token} = Base.url_decode64(raw_token, padding: false)
    hashed_token = Sigra.Token.hash_token(decoded_token)

    user
    |> Ecto.Changeset.change(email: "changed-#{System.unique_integer([:positive])}@example.test")
    |> Repo.update!()

    assert {:error, :invalid} = Accounts.verify_magic_link(raw_token)
    assert Repo.get_by(UserToken, token: hashed_token, context: "magic_link")
  end

  @tag :recovery_oban
  test "a mail retry reuses the checkpointed link and does not replace a redeemed token" do
    user = user_fixture()
    expected_email = user.email
    previous_mailer = Application.get_env(:example, :recovery_mailer)
    Application.put_env(:example, :recovery_mailer, Example.RecoveryFailOnceMailer)
    Process.put(:recovery_mailer_fail_next, true)

    on_exit(fn ->
      Process.delete(:recovery_mailer_fail_next)

      if is_nil(previous_mailer) do
        Application.delete_env(:example, :recovery_mailer)
      else
        Application.put_env(:example, :recovery_mailer, previous_mailer)
      end
    end)

    assert {:ok, :accepted} = Accounts.enqueue_recovery_request(:reset, user.email)

    job =
      Repo.one!(
        from job in Oban.Job,
          where: job.worker == "Sigra.Workers.RecoveryRequest",
          where: job.queue == "sigra_recovery"
      )

    assert {:error, :recovery_failed} = RecoveryRequest.perform(job)

    assert_received {:recovery_mailer, :failed, ^expected_email, "Reset your password",
                     failed_body}

    assert Repo.aggregate(
             from(token in UserToken,
               where: token.user_id == ^user.id and token.context == "reset_password"
             ),
             :count
           ) == 1

    assert {:ok, :delivered} = RecoveryRequest.perform(job)

    assert_received {:recovery_mailer, :accepted, ^expected_email, "Reset your password",
                     accepted_body}

    failed_token = extract_reset_token(failed_body.text)
    accepted_token = extract_reset_token(accepted_body.text)
    assert failed_token == accepted_token

    assert Repo.aggregate(
             from(event in AuditEvent,
               where:
                 event.target_id == ^user.id and event.action == "auth.password_reset_request"
             ),
             :count
           ) == 1

    new_password = "a-much-longer-new-password-456!"

    assert {:ok, _updated_user} =
             Accounts.reset_user_password(failed_token, %{
               password: new_password,
               password_confirmation: new_password
             })

    assert {:ok, :delivered} = RecoveryRequest.perform(job)
    refute_received {:recovery_mailer, :accepted, _, _, _}

    assert Repo.aggregate(
             from(token in UserToken,
               where: token.user_id == ^user.id and token.context == "reset_password"
             ),
             :count
           ) == 0
  end

  defp extract_reset_token(body) do
    [_, token] = Regex.run(~r{/users/reset-password/([A-Za-z0-9_-]+)}, body)
    token
  end

  defp enqueue_with_dispatcher(email, dispatcher, dispatch_opts) do
    Sigra.Recovery.enqueue(:reset, email,
      host_id: "example",
      secret_key_base: Accounts.recovery_secret_key_base(),
      dispatcher: dispatcher,
      dispatch_opts: Keyword.put(dispatch_opts, :repo, Repo)
    )
  end
end
