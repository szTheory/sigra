# Password Reset

Sigra's password reset flow uses a one-time, HMAC-signed token with a 60-minute TTL. The user requests a reset, clicks an email link, sets a new password, and every one of their existing sessions is invalidated. This guide covers the full lifecycle.

## What Sigra gives you

- **`MyAppWeb.ResetPasswordLive`** — two LiveViews: one for "request a reset" and one for "enter your new password."
- **`MyApp.Accounts.queue_recovery_request/2`** — generated public request entry point. It checks the configured limiter and durably queues an encrypted request before account lookup.
- **`MyApp.Accounts.deliver_user_reset_password_instructions/2`** — synchronous compatibility helper for trusted internal callers; generated public forms do not call it.
- **`MyApp.Accounts.get_user_by_reset_password_token/1`** — verifies the token (HMAC, hash lookup, TTL) and returns the user.
- **`MyApp.Accounts.reset_user_password/2`** — updates the password, deletes the reset token, and invalidates every session and token for that user.
- **`Sigra.Auth.request_password_reset/3`** — library primitive. For an address with no account it returns `{:ok, :sent}`; for an account it returns the signed token and URL. The generated `deliver_user_reset_password_instructions/2` normalizes both to `{:ok, :sent}`, or returns `{:error, :rate_limited}` when the configured limiter denies the request.
- **`Sigra.Auth.reset_password/4`** — library primitive. Verifies the HMAC, looks up the token by hash, and enforces the configured reset TTL (60 minutes by default).

## Happy path

### Step 1: Request a reset

The generated `ResetPasswordLive` renders a form with one field: email. Submitting it calls:

    Accounts.queue_recovery_request(:reset, email)

The generated LiveView and controller call `queue_recovery_request(:reset, email)`. The context checks the configured limiter before queue admission. A valid request is encrypted and persisted by the dispatcher; account lookup, token and audit writes, URL construction, and delivery happen later in the worker. A successful admission and a rate-limited or malformed address receive the same generic acknowledgment. A dispatcher failure receives the same generic service error for registered and unknown addresses; there is no synchronous fallback. The generated-host install smoke submits an existing and an unknown address and checks the same public response, plus token creation only for the existing account.

The worker generates a 32-byte random token, signs the raw token with HMAC using the app's `secret_key_base`, stores the token hash in `auth.user_tokens` with `context: "reset_password"`, and renders the email template. The generated public request path does not call `deliver_user_reset_password_instructions/2`.

### Configure durable dispatch

The installer adds the host registry and default dispatcher settings to `config/config.exs`. Oban is optional. To use the built-in dispatcher, add Oban as a host dependency and fetch it:

    # mix.exs
    def deps do
      [
        {:oban, "~> 2.17"}
      ]
    end

Fetch the dependency:

    mix deps.get

Create a migration:

    mix ecto.gen.migration add_oban_jobs_table

Use Oban's version-aware migration API in the generated migration:

    defmodule MyApp.Repo.Migrations.AddObanJobsTable do
      use Ecto.Migration

      def up, do: Oban.Migration.up()
      def down, do: Oban.Migration.down()
    end

Then apply the migration:

    mix ecto.migrate

If Oban is already installed and migrated, keep its existing dependency and migration. Add the recovery queue to your existing Oban configuration, preserving its other queues, and supervise Oban in the host application:

    # config/config.exs
    config :my_app, Oban,
      repo: MyApp.Repo,
      queues: [default: 10, sigra_recovery: 10]

Include `{Oban, Application.fetch_env!(:my_app, Oban)}` in the existing application supervision tree.

See the [Oban 2.17 installation guide](https://oban.hexdocs.pm/2.17.11/installation.html) for the complete dependency, migration, and supervision setup.

The generated settings are equivalent to:

    config :sigra, :recovery_hosts, %{"my_app" => MyApp.Accounts}
    config :my_app, :sigra_recovery,
      host_id: "my_app",
      dispatcher: Sigra.Workers.RecoveryRequest,
      dispatch_opts: [queue: :sigra_recovery]

The queue name must match `dispatch_opts` and the Oban queue. After deploy or a queue config change, check that the Oban instance and its configured queue producer are available:

    Oban.whereis(Oban)
    Oban.check_queue(queue: :sigra_recovery)

The first call checks the default Oban supervisor; the second inspects the configured local queue producer on that node. It does not prove that every node in a cluster has the queue. Oban's response for a missing or unconfigured queue varies across supported versions, so handle the installed version's result or exception and treat an absent producer as unavailable. Monitor the queue's available, executing, retryable, and discarded jobs across your deployment using your normal Oban operational tooling. If queue supervision or insertion is unavailable, the public endpoint returns its generic service error and does no synchronous account lookup or delivery.

Oban is not required. A host adapter configured as `dispatcher:` must implement the `enqueue/3` and `checkpoint_once/4` callbacks declared by `Sigra.Recovery`. `enqueue/3` must persist the encrypted envelope and return success only after it is durable. `checkpoint_once/4` must run the supplied `prepare` callback and persist its encrypted outcome in one transaction tied to a stable job reference. This makes token and audit writes idempotent across worker retries. Do not write a queue adapter that acknowledges before durable persistence.

Recovery jobs contain a host identifier and encrypted request envelope; the worker checkpoint is encrypted too. The envelope and checkpoint use the host endpoint's `secret_key_base` and are valid for at most 24 hours. Restrict access to Oban job rows, database backups, and any operational tooling that exposes job metadata; configure Oban's successful and failed job retention separately from this cryptographic expiry. Drain the recovery queue before rotating `secret_key_base` so pending jobs and checkpoints remain decryptable. If delivery fails after checkpointing, retries reuse the same prepared link (reset links expire after 60 minutes by default; magic links after 10 minutes), for up to three Oban attempts. A mail provider may accept a message just before a worker crash, so delivery is at least once and a retry can send the same link again. Worker failures use the fixed `:recovery_failed` category; generated public responses do not include internal error details.

Hosts generated before queued recovery was added own their emitted controllers and context code. Updating the `:sigra` dependency does not rewrite those files: port the current `queue_recovery_request/2` helper and recovery worker callbacks into the host's generated Auth/Accounts module, change both reset request handlers and the magic-link request handler to queue-only admission, then add the host registry, `:sigra_recovery` configuration, and running queue. Keep existing synchronous `Sigra.Auth.request_password_reset/3`, `request_magic_link/3`, and `Accounts.deliver_user_reset_password_instructions/2` for trusted internal compatibility callers; never expose their account-dependent results from a public endpoint.

For magic links, the generated redemption path rechecks that the mailbox is still current and that magic-link sign-in and host policy allow access before consuming the token. Users with MFA enabled enter the MFA-pending flow instead of receiving a fully authenticated session directly.

**Scope of this claim:** the example app compares status, redirect, flash, and page for one request; a generated-host smoke checks the same public response plus the token-count result. When configured, the email limiter checks a normalized email key before queue admission, so a denied request returns the same `:rate_limited` result for an existing or unknown address and creates no job. The limiter is disabled by default. These checks do not establish timing equivalence, the production limiter's behavior, or parity of internal library results after admission.

### Step 2: Click the email link

The email body contains a URL like:

    https://myapp.com/users/reset-password/SFMyNTY.g2gDbQ...

The visible portion after `/users/reset-password/` is the HMAC-signed token. When the user clicks it, `ResetPasswordLive` (mounted for `:edit`) calls:

    def mount(%{"token" => token}, _session, socket) do
      socket = assign(socket, token: token)

      case Accounts.get_user_by_reset_password_token(token) do
        %User{} = user ->
          {:ok, assign(socket, user: user, form: to_form(Accounts.change_user_password(user)))}

        nil ->
          {:ok,
           socket
           |> put_flash(:error, "Reset password link is invalid or it has expired.")
           |> redirect(to: ~p"/")}
      end
    end

`get_user_by_reset_password_token/1` verifies:

1. The HMAC signature (rejects tampered tokens).
2. The hash exists in `auth.user_tokens` (rejects fabricated or already-used tokens).
3. `inserted_at + configured TTL > now` (60 minutes by default; rejects expired tokens).

The signature rejects tampering, the stored hash rejects fabricated or consumed tokens, and the TTL rejects expired links. These checks do not establish timing equivalence for reset requests.

### Step 3: Enter new password

The LiveView renders the new-password form. Submitting calls:

    def handle_event("reset", %{"user" => user_params}, socket) do
      case Accounts.reset_user_password(socket.assigns.user, user_params) do
        {:ok, _user} ->
          {:noreply,
           socket
           |> put_flash(:info, "Password reset successfully.")
           |> redirect(to: ~p"/users/log-in")}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply, assign(socket, form: to_form(changeset))}
      end
    end

Inside `reset_user_password/2`:

    def reset_user_password(user, attrs) do
      Ecto.Multi.new()
      |> Ecto.Multi.update(:user, User.password_changeset(user, attrs))
      |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, :all))
      |> Repo.transact()
      |> case do
        {:ok, %{user: user}} -> {:ok, user}
        {:error, :user, changeset, _} -> {:error, changeset}
      end
    end

Note: `by_user_and_contexts_query(user, :all)` deletes **every** token for that user — all sessions (including the current one on other devices), all remember-me cookies, all pending confirmation tokens, all magic links. The user must log in fresh on every device.

## TTL configuration

The reset token TTL is 60 minutes by default. To change it:

    # config/config.exs
    config :my_app, :sigra_config,
      token_ttl: [reset_password: 30 * 60]  # 30 minutes, in seconds

Shorter is safer (smaller attack window) but worsens UX if the email is delayed.

## Rate limiting

Reset requests are a common enumeration vector and an email-bomb vector. Generated account helpers read the limiter and reset-request settings from `:sigra_config`:

    config :my_app, :sigra_config,
      rate_limiting: [limiter: Sigra.RateLimiters.Hammer],
      reset: [max_requests: 3, window_seconds: 60]

    config :sigra, :hammer_module, MyApp.RateLimit

The host must add the optional `:hammer` dependency, define and supervise the Hammer module, or supply its own module implementing `Sigra.RateLimiter`. `nil` (the default) disables rate limiting.

With this config, the fourth request for the same normalized email within 60 seconds is throttled before queue admission. A denied request returns `{:error, :rate_limited}` for either address and creates no recovery job. The same settings are available for magic links under `magic_link: [max_requests: 3, window_seconds: 900]`. When the limiter allows a request, the generated public endpoint returns after queue admission; the worker later performs account-specific work. The synchronous compatibility APIs still have account-dependent results and behavior. These facts do not establish timing equivalence.

## Why all sessions are invalidated

When a password is reset, Sigra assumes the user forgot it (best case) or that an attacker had access (worst case). In both cases, every existing session must be invalidated:

- Any other device still logged in could be the attacker.
- Any lingering remember-me cookie must stop working.
- Any pending magic-link or confirmation token should be revoked.

The `delete_all` on `auth.user_tokens` handles all of this in one query.

## Testing

    test "delivers reset email" do
      user = Sigra.Testing.user_fixture()

      Accounts.deliver_user_reset_password_instructions(user.email, &"/reset/#{&1}")

      Sigra.Testing.assert_email_sent(to: user.email, subject: "Reset")
    end

    test "resets password and invalidates sessions" do
      %{user: user, conn: _conn} = Sigra.Testing.authenticated_fixture()
      {:ok, %{to_reset: token}} = Sigra.Auth.request_password_reset(Repo, user.email, user_token_schema: UserToken)

      assert {:ok, updated} = Accounts.reset_user_password(user, %{"password" => "brandnewpw1234"})
      Sigra.Testing.assert_sessions_invalidated(Repo, updated)
    end

## Related

- [Login and Logout](login-and-logout.html) — session token lifecycle.
- [Account Lifecycle](account-lifecycle.html) — change password without a reset token.
- [Audit Logging](audit-logging.html) — reset attempts are logged as `auth.password_reset_request` and `auth.password_reset.success|failure`.
- `Sigra.Auth.request_password_reset/3` and `Sigra.Auth.reset_password/4` — library primitives.
