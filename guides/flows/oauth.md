# OAuth and Social Login

Sigra wraps [Assent](https://hexdocs.pm/assent) for OAuth 2.0 and OpenID Connect (OIDC). Out of the box it supports Google, GitHub, Apple, and Facebook; additional providers are a few lines of config. This guide covers provider setup, the callback flow, account linking, and unlinking.

## What Sigra gives you

- **`Sigra.OAuth.authorize_url/3`** — returns the provider's authorization URL with PKCE state stored in the session.
- **`Sigra.OAuth.callback`** — handles the provider's callback: exchanges the code, fetches the user info, returns normalized user data.
- **`Sigra.Auth.register_oauth/4`** — creates a new user from OAuth user info.
- **`Sigra.Auth.login_oauth/4`** — logs in an existing user by provider identity.
- **`Sigra.Auth.link_provider/4`** — links a provider identity to an existing user account.
- **`Sigra.Auth.unlink_provider/4`** — unlinks a provider identity.
- **Generated `UserIdentity` schema** — stores `provider`, `provider_user_id`, encrypted `access_token` and `refresh_token` (via `cloak_ecto`).

## Provider configuration

Sigra reads provider config from `Sigra.Config.oauth[:providers]`:

    # config/config.exs
    config :my_app, MyApp.Auth.Config,
      repo: MyApp.Repo,
      user_schema: MyApp.Accounts.User,
      oauth: [
        enabled: true,
        providers: [
          google: [
            client_id: System.get_env("GOOGLE_CLIENT_ID"),
            client_secret: System.get_env("GOOGLE_CLIENT_SECRET"),
            redirect_uri: "https://myapp.com/auth/google/callback",
            scope: "openid email profile"
          ],
          github: [
            client_id: System.get_env("GITHUB_CLIENT_ID"),
            client_secret: System.get_env("GITHUB_CLIENT_SECRET"),
            redirect_uri: "https://myapp.com/auth/github/callback"
          ]
        ]
      ]

**Never hardcode client secrets** — always use `System.get_env/1`. See [Deployment](deployment.html) for env var management.

## Happy path

### Step 1: Start the flow

Generate a "Sign in with Google" button that links to `/auth/google`:

    <.link href={~p"/auth/google"} class="btn btn-google">
      Sign in with Google
    </.link>

The generated controller action:

    def request(conn, %{"provider" => provider}) do
      case Sigra.OAuth.authorize_url(config(), provider, conn) do
        {:ok, %{url: url, session_params: params}} ->
          conn
          |> put_session(:oauth_state, params)
          |> redirect(external: url)

        {:error, reason} ->
          conn
          |> put_flash(:error, "Could not start #{provider} sign-in: #{inspect(reason)}")
          |> redirect(to: ~p"/users/log-in")
      end
    end

`authorize_url/3` generates PKCE verifier + code challenge and stores them in the session (as `session_params`) so `callback/4` can verify the return trip.

### Step 2: Handle the callback

When the user authorizes, Google redirects them to `/auth/google/callback?code=...&state=...`. The controller:

    def callback(conn, %{"provider" => provider} = params) do
      session_params = get_session(conn, :oauth_state)

      case Sigra.OAuth.callback(config(), provider, params, session_params) do
        {:ok, %{user: user_info, token: token}} ->
          handle_oauth_user(conn, provider, user_info, token)

        {:error, reason} ->
          conn
          |> put_flash(:error, "Sign-in failed: #{inspect(reason)}")
          |> redirect(to: ~p"/users/log-in")
      end
    end

`Sigra.OAuth.callback` verifies the PKCE challenge, exchanges the code for tokens, fetches the user info endpoint, and normalizes the response across providers. The `user_info` map always has `:email`, `:provider_id`, `:name`, `:avatar_url`.

### Step 3: Three cases

Your `handle_oauth_user/3` handles the three possible states:

    defp handle_oauth_user(conn, provider, user_info, token) do
      case Accounts.find_or_create_oauth_user(provider, user_info, token) do
        {:ok, :new_user, user} ->
          conn
          |> put_flash(:info, "Welcome! Account created via #{provider}.")
          |> UserAuth.log_in_user(user)

        {:ok, :existing_user_linked, user} ->
          conn
          |> put_flash(:info, "Signed in via #{provider}.")
          |> UserAuth.log_in_user(user)

        {:ok, :needs_linking, user} ->
          # Email matches an existing user but no identity for this provider yet
          conn
          |> put_session(:pending_oauth_link, %{provider: provider, user_info: user_info, token: token})
          |> redirect(to: ~p"/auth/confirm-link")
      end
    end

The third case — "email matches existing user, but they've never signed in with this provider" — is where account-takeover risk lives. Sigra's recommendation: show a confirmation page asking the user to log in with their existing password before linking the new provider. Don't silently link.

## Account linking

The confirm-link page asks for the existing password:

    def handle_event("confirm_link", %{"user" => %{"password" => password}}, socket) do
      %{provider: provider, user_info: user_info, token: token} = get_session(socket, :pending_oauth_link)
      user = Accounts.get_user_by_email(user_info.email)

      case Accounts.get_user_by_email_and_password(user.email, password) do
        %User{} = verified_user ->
          {:ok, _identity} = Sigra.Auth.link_provider(config(), verified_user, %{provider: provider, user_info: user_info, token: token})
          UserAuth.log_in_user(socket, verified_user)

        nil ->
          {:noreply, put_flash(socket, :error, "Incorrect password")}
      end
    end

After linking, future sign-ins via that provider go straight through to `:existing_user_linked`.

## Unlinking

On the account settings page, let users unlink providers:

    def handle_event("unlink", %{"provider" => provider}, socket) do
      user = socket.assigns.current_scope.user

      case Sigra.Auth.unlink_provider(config(), user, provider) do
        {:ok, _} ->
          {:noreply, put_flash(socket, :info, "Unlinked #{provider}.")}

        {:error, :last_login_method} ->
          {:noreply, put_flash(socket, :error, "You cannot unlink your only sign-in method. Set a password first.")}
      end
    end

`unlink_provider/4` refuses to remove the last sign-in method — otherwise the user is locked out.

## Token encryption

Access tokens and refresh tokens are encrypted at rest via `cloak_ecto`. The generated `UserIdentity` schema uses `Cloak.Ecto.Binary` for the `access_token` and `refresh_token` fields. Configure your Cloak vault in `lib/my_app/vault.ex`:

    defmodule MyApp.Vault do
      use Cloak.Vault, otp_app: :my_app
    end

    config :my_app, MyApp.Vault,
      ciphers: [
        default: {Cloak.Ciphers.AES.GCM, tag: "AES.GCM.V1", key: System.get_env("CLOAK_KEY") |> Base.decode64!()}
      ]

`CLOAK_KEY` must be a 32-byte key base64-encoded. Generate with `:crypto.strong_rand_bytes(32) |> Base.encode64()`.

## Testing

    test "mock OAuth callback creates a new user" do
      params = Sigra.Testing.mock_oauth_callback(provider: :google, email: "alice@example.com")
      conn = get(build_conn(), ~p"/auth/google/callback", params)

      assert conn.assigns.current_scope.user.email == "alice@example.com"
    end

## Related

- [Account Lifecycle](account-lifecycle.html) — changing email after OAuth signup.
- [Deployment](deployment.html) — env var setup for client secrets.
- `Sigra.OAuth` — authorize_url, callback
- `Sigra.Auth.register_oauth/4`, `login_oauth/4`, `link_provider/4`, `unlink_provider/4`
