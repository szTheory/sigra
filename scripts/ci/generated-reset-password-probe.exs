defmodule <%= app_module %>.GeneratedRecoveryDispatcher do
  @behaviour Sigra.Recovery

  @table "sigra_generated_recovery_jobs"
  @repo <%= app_module %>.Repo

  @impl true
  def enqueue(host_id, envelope, _opts) do
    case @repo.query!(
           "INSERT INTO #{@table} (host_id, envelope) VALUES ($1, $2) RETURNING id",
           [host_id, envelope]
         ) do
      %{rows: [[id]]} -> {:ok, id}
      _ -> {:error, :recovery_unavailable}
    end
  rescue
    _ -> {:error, :recovery_unavailable}
  end

  @impl true
  def checkpoint_once(job_ref, repo, prepare, opts) do
    host_id = Keyword.fetch!(opts, :host_id)
    secret = Keyword.fetch!(opts, :secret_key_base)

    case repo.transact(fn ->
           case repo.query!(
                  "SELECT checkpoint FROM #{@table} WHERE id = $1 AND host_id = $2 FOR UPDATE",
                  [job_ref, host_id]
                ) do
             %{rows: []} ->
               {:error, :missing_job}

             %{rows: [[encrypted]]} when is_binary(encrypted) ->
               case Sigra.Recovery.decrypt_checkpoint(secret, host_id, job_ref, encrypted) do
                 {:ok, descriptor} -> {:ok, {descriptor, false, %{}}}
                 {:error, _} -> {:error, :invalid_checkpoint}
               end

             %{rows: [[nil]]} ->
               with {:ok, %{descriptor: descriptor, audit_changes: audit_changes}} <- prepare.(),
                    {:ok, encrypted} <-
                      Sigra.Recovery.encrypt_checkpoint(secret, host_id, job_ref, descriptor),
                    %{num_rows: 1} <-
                      repo.query!(
                        "UPDATE #{@table} SET checkpoint = $1 WHERE id = $2 AND host_id = $3",
                        [encrypted, job_ref, host_id]
                      ) do
                 {:ok, {descriptor, true, audit_changes}}
               else
                 _ -> {:error, :recovery_failed}
               end
           end
         end) do
      {:ok, {descriptor, fresh?, audit_changes}} ->
        {:ok, descriptor, fresh?, audit_changes}

      {:error, _reason} ->
        {:error, :recovery_failed}
    end
  rescue
    _ -> {:error, :recovery_failed}
  end

  def jobs do
    @repo.query!(
      "SELECT id, host_id, envelope FROM #{@table} ORDER BY id"
    ).rows
  end

  def setup_table do
    @repo.query!("""
    CREATE TABLE IF NOT EXISTS #{@table} (
      id bigserial PRIMARY KEY,
      host_id text NOT NULL,
      envelope text NOT NULL,
      checkpoint text
    )
    """)

    @repo.query!("TRUNCATE TABLE #{@table} RESTART IDENTITY")
  end
end

defmodule <%= app_module %>.GeneratedResetPasswordProbeTest do
  use <%= app_module %>Web.ConnCase, async: false

  import Ecto.Query, only: [from: 2]
  import Phoenix.LiveViewTest

  alias <%= app_module %>.Accounts.AuditEvent
  alias <%= app_module %>.Accounts.UserToken
  alias <%= app_module %>.AccountsFixtures
  alias <%= app_module %>.Repo

  @dispatcher <%= app_module %>.GeneratedRecoveryDispatcher
  @host_id "generated-smoke"
  @reset_flash "If your email is in our system, you will receive reset instructions shortly."
  @magic_flash "If your email is registered, you will receive a magic link shortly."

  setup do
    @dispatcher.setup_table()
    otp_app = Application.fetch_env!(:sigra, :otp_app)
    previous = Application.get_env(otp_app, :sigra_recovery)

    Application.put_env(otp_app, :sigra_recovery,
      host_id: @host_id,
      dispatcher: @dispatcher,
      dispatch_opts: []
    )

    on_exit(fn ->
      if is_nil(previous) do
        Application.delete_env(otp_app, :sigra_recovery)
      else
        Application.put_env(otp_app, :sigra_recovery, previous)
      end
    end)

    :ok
  end

  test "fresh generated host queues reset and magic requests without Oban or account-side effects",
       %{conn: conn} do
    assert_no_oban_dependency!()
    user = AccountsFixtures.user_fixture()
    unknown_email = AccountsFixtures.unique_user_email()
    audit_count = Repo.aggregate(AuditEvent, :count, :id)

    {reset_redirect, reset_flash} = submit_reset_request(conn, user.email)
    {unknown_reset_redirect, unknown_reset_flash} =
      submit_reset_request(build_conn(), unknown_email)

    assert {reset_redirect, reset_flash} == {unknown_reset_redirect, unknown_reset_flash}
    assert reset_redirect == "/users/log_in"
    assert reset_flash["info"] == @reset_flash

    {magic_redirect, magic_response} = submit_magic_link_request(build_conn(), user.email)
    {unknown_magic_redirect, unknown_magic_response} =
      submit_magic_link_request(build_conn(), unknown_email)

    assert {magic_redirect, magic_response} == {unknown_magic_redirect, unknown_magic_response}
    assert magic_redirect == "/users/log_in"
    assert magic_response.flash["info"] == @magic_flash

    assert length(@dispatcher.jobs()) == 4
    assert reset_tokens_for(user.id) == []
    assert tokens_for("magic_link", user.id) == []
    assert Repo.aggregate(AuditEvent, :count, :id) == audit_count
    refute_received {:email, _email}

    assert Enum.all?(@dispatcher.jobs(), fn [_id, host_id, envelope] ->
             host_id == @host_id and is_binary(envelope) and envelope != ""
           end)

    assert Enum.map(drain_jobs(), &elem(&1, 1)) == [
             :delivered,
             :no_delivery,
             :delivered,
             :no_delivery
           ]

    assert [%UserToken{context: "reset_password"}] = reset_tokens_for(user.id)
    assert [%UserToken{context: "magic_link"} = magic_token] = tokens_for("magic_link", user.id)
    assert tokens_for_email("reset_password", unknown_email) == []
    assert tokens_for_email("magic_link", unknown_email) == []

    assert_received {:email, reset_email}
    assert_received {:email, magic_email}
    assert email_contains?(reset_email, user.email, "/users/reset-password/")
    assert email_contains?(magic_email, user.email, "/users/log_in/")

    reset_token = email_token(reset_email, "/users/reset-password/")
    magic_link = email_token(magic_email, "/users/log_in/")

    # Password reset revokes every outstanding credential for the user, so
    # redeem the magic link first. This proves each independently delivered
    # URL works without weakening the cross-token revocation behavior.
    magic_conn = get(build_conn(), "/users/log_in/#{magic_link}")
    assert redirected_to(magic_conn) == "/"
    assert get_session(magic_conn, :user_token)
    refute Repo.get(UserToken, magic_token.id)

    {:ok, reset_view, reset_html} = live(build_conn(), "/users/reset-password/#{reset_token}")
    assert reset_html =~ ~s(id="reset_password_form")
    assert has_element?(reset_view, "#reset_password_form")

    new_password = "A much stronger reset password 2026!"

    reset_view
    |> form("#reset_password_form", user: %{password: new_password, password_confirmation: new_password})
    |> render_submit()

    assert reset_tokens_for(user.id) == []
    {:ok, replay_view, replay_html} = live(build_conn(), "/users/reset-password/#{reset_token}")
    assert replay_html =~ "This password reset link has expired or was already used."
    assert has_element?(replay_view, ~s(a[href="/users/reset-password"]))
    refute has_element?(replay_view, "#reset_password_form")
  end

  test "generated reset controller action uses the durable dispatcher", %{conn: conn} do
    user = AccountsFixtures.user_fixture()
    conn = controller_conn(conn)

    response =
      <%= app_module %>Web.ResetPasswordController.create(conn, %{
        "user" => %{"email" => user.email}
      })

    assert redirected_to(response) == "/users/log_in"
    assert Phoenix.Flash.get(response.assigns.flash, :info) == @reset_flash
    assert reset_tokens_for(user.id) == []
    assert [[_id, @host_id, envelope]] = @dispatcher.jobs()
    assert is_binary(envelope) and envelope != ""
  end

  test "default dispatcher failure stays generic and side-effect-free", %{conn: conn} do
    user = AccountsFixtures.user_fixture()
    unknown_email = AccountsFixtures.unique_user_email()
    audit_count = Repo.aggregate(AuditEvent, :count, :id)
    otp_app = Application.fetch_env!(:sigra, :otp_app)

    Application.put_env(otp_app, :sigra_recovery,
      host_id: @host_id,
      dispatcher: Sigra.Workers.RecoveryRequest,
      dispatch_opts: [queue: :sigra_recovery]
    )

    reset_results =
      Enum.map([user.email, unknown_email], fn email ->
        response =
          <%= app_module %>Web.ResetPasswordController.create(controller_conn(conn), %{
            "user" => %{"email" => email}
          })

        {response.status, redirected_to(response), Phoenix.Flash.get(response.assigns.flash, :error)}
      end)

    assert [reset_known, reset_unknown] = reset_results
    assert reset_known == reset_unknown
    assert elem(reset_known, 0) == 302
    assert elem(reset_known, 1) == "/users/log_in"
    assert elem(reset_known, 2) == "We couldn't send your request right now. Please try again later."

    magic_results =
      Enum.map([user.email, unknown_email], fn email ->
        response =
          post(build_conn(), "/users/log_in", %{
            "_action" => "magic_link",
            "user" => %{"email" => email}
          })

        {response.status, redirected_to(response), Phoenix.Flash.get(response.assigns.flash, :error)}
      end)

    assert [magic_known, magic_unknown] = magic_results
    assert magic_known == magic_unknown
    assert elem(magic_known, 0) == 302
    assert elem(magic_known, 1) == "/users/log_in"
    assert elem(magic_known, 2) == "We couldn't send your request right now. Please try again later."

    assert @dispatcher.jobs() == []
    assert reset_tokens_for(user.id) == []
    assert tokens_for("magic_link", user.id) == []
    assert Repo.aggregate(AuditEvent, :count, :id) == audit_count
    refute_received {:email, _email}
  end

  defp assert_no_oban_dependency! do
    mix_exs = File.read!("mix.exs")
    refute mix_exs =~ ~r/\{\s*:oban\s*,/
  end

  defp submit_reset_request(conn, email) do
    {:ok, view, html} = live(conn, "/users/reset-password")
    assert html =~ ~s(id="reset_password_request_form")

    outcome =
      view
      |> form("#reset_password_request_form", user: %{email: email})
      |> render_submit()

    assert {:error, {:redirect, %{to: "/users/log_in"}}} = outcome
    flash = assert_redirect(view, "/users/log_in")
    {"/users/log_in", flash}
  end

  defp submit_magic_link_request(conn, email) do
    response =
      post(conn, "/users/log_in", %{
        "_action" => "magic_link",
        "user" => %{"email" => email}
      })

    assert redirected_to(response) == "/users/log_in"
    {"/users/log_in",
     %{
       flash: %{
         "info" => Phoenix.Flash.get(response.assigns.flash, :info),
         "error" => Phoenix.Flash.get(response.assigns.flash, :error)
       },
       status: response.status
     }}
  end

  defp controller_conn(conn) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Phoenix.Controller.fetch_flash()
  end

  defp drain_jobs do
    for [id, host_id, envelope] <- @dispatcher.jobs() do
      Sigra.Recovery.process_request(id, host_id, envelope,
        handler: <%= app_module %>.Accounts,
        dispatcher: @dispatcher,
        repo: Repo,
        secret_key_base: <%= app_module %>.Accounts.recovery_secret_key_base()
      )
    end
  end

  defp reset_tokens_for(user_id), do: tokens_for("reset_password", user_id)

  defp tokens_for(context, user_id) do
    Repo.all(
      from token in UserToken,
        where: token.context == ^context and token.user_id == ^user_id
    )
  end

  defp tokens_for_email(context, email) do
    Repo.all(
      from token in UserToken,
        where: token.context == ^context and token.sent_to == ^email
    )
  end

  defp email_contains?(email, recipient, route) do
    recipient_match? =
      Enum.any?(email.to, fn
        {_name, address} -> address == recipient
        address when is_binary(address) -> address == recipient
      end)

    recipient_match? and String.contains?(email.text_body || "", route)
  end

  defp email_token(email, route) do
    body = email.text_body || ""
    [_, token] = Regex.run(Regex.compile!(Regex.escape(route) <> "([A-Za-z0-9_-]+)"), body)
    token
  end
end
