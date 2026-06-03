# OAuth, OIDC, and Enterprise Sign-In

Sigra wraps [Assent](https://hexdocs.pm/assent) for OAuth 2.0 and OpenID Connect (OIDC). Out of the box it supports social sign-in providers such as Google, GitHub, Apple, and Facebook, and it now also ships an organization-scoped enterprise OIDC path for bounded B2B SSO.

This guide is intentionally narrow. It explains:

- provider OAuth / OIDC basics for consumer-style sign-in,
- the bounded enterprise sign-in contract Sigra ships for organizations,
- which operator signals belong to setup, routing, reconciliation, and enforcement,
- and what Sigra does not claim in this milestone.

## What Sigra gives you

- **`Sigra.OAuth.authorize_url/3`** builds the provider authorization URL and stores PKCE state in the session.
- **`Sigra.OAuth.handle_callback/4`** exchanges the provider callback for normalized identity data.
- **`Sigra.Auth.register_oauth/4`** creates a new user from OAuth user info.
- **`Sigra.Auth.login_oauth/4`** logs in an existing user by provider identity.
- **`Sigra.Auth.link_provider/4`** links a provider identity to an existing account.
- **`Sigra.Auth.unlink_provider/4`** unlinks a provider identity while protecting the last sign-in method.
- **`Sigra.EnterpriseConnections`** owns organization-scoped enterprise connection lifecycle, validation, and activation truth.
- **`Sigra.EnterpriseRouting`** resolves enterprise login through an explicit organization route or bounded domain discovery.
- **`Sigra.OAuth.EnterpriseReconciliation`** owns just-in-time organization membership reconciliation and typed refusal outcomes.
- **`Sigra.Auth`** enforces SSO-only posture and break-glass denial truth for local password sign-in.

## Provider OAuth / OIDC basics

Sigra reads provider config from `Sigra.Config.oauth[:providers]`:

```elixir
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
```

Never hardcode client secrets. Use `System.get_env/1` or equivalent runtime secret management.

### Happy path

1. Start the flow with a link such as `~p"/auth/google"`.
2. `Sigra.OAuth.authorize_url/3` generates PKCE state and redirects to the provider.
3. `Sigra.OAuth.handle_callback/4` verifies the return trip, exchanges the code, and normalizes user info.
4. Your host app decides whether to register, log in, or require an explicit account-linking confirmation step.

### Account linking

If provider email matches an existing user without an existing identity row, Sigra recommends a confirmation flow that requires the existing password before linking. Do not silently link on email match alone.

### Unlinking

`Sigra.Auth.unlink_provider/4` refuses to remove the last sign-in method. Users must keep at least one viable path, or set a password first.

## Enterprise sign-in contract

Sigra's enterprise story in `v1.27 ENT-SSO` is deliberately bounded:

- **OIDC-first** and organization-scoped.
- **Thin-host**: the library owns the security-critical truth; generated/example hosts present it honestly.
- **Four operator stages**: setup, routing, reconciliation, and enforcement.
- **Representative proof**, not a broad certification matrix.

Sigra does not claim:

- SCIM or directory sync,
- hosted control plane behavior,
- opinionated authorization policy,
- live-provider certification across enterprise environments,
- or a general enterprise identity platform beyond bounded org-scoped sign-in.

## Enterprise setup

Each organization owns its own enterprise connection. The generated host exposes a draft → validate → activate lifecycle backed by `Sigra.EnterpriseConnections`.

Setup truth is intentionally machine-readable and bounded:

- saving keeps a **draft**,
- validation failures stay **non-active**,
- activation succeeds only after validation passes,
- and safe diagnostics live on persisted lifecycle state such as `validation_failed` plus `last_validation_error`.

When setup fails, operators should start here first:

- confirm issuer, client ID, client secret, scopes, and discovery document URI,
- run validation again,
- and treat `validation_failed` as the source of truth rather than guessing from callback behavior.

## Enterprise routing

Enterprise sign-in starts from an organization-aware path:

- explicit organization route such as `/organizations/:org/sso`, or
- bounded email-domain discovery that resolves to exactly one routable organization connection.

Routing stays fail-closed. The important outcome classes are:

- `:no_org_match`,
- `:multiple_org_matches`,
- `:org_connection_unavailable`.

Operators should use the canonical organization route whenever possible. Domain discovery is a convenience layer, not a second source of truth.

## Enterprise reconciliation

After callback, Sigra revalidates the routed organization context and reconciles the identity into the correct organization. This stage is owned by `Sigra.OAuth.Callback` and `Sigra.OAuth.EnterpriseReconciliation`.

Representative reconciliation outcomes include:

- `:existing_membership`,
- `:invitation_consumed`,
- `:jit_created`,
- `:ambiguous_email_match`,
- `:provider_subject_conflict`.

Unsafe reconciliation does not silently downgrade into another auth mode. The generated host keeps the user on the same organization-scoped enterprise recovery path.

## SSO-only enforcement and break-glass

Organizations can require enterprise sign-in for members while preserving explicit break-glass recovery.

The bounded enforcement contract is:

- local password sign-in is denied with `:sso_required` when SSO-only applies,
- denial happens before normal success or session creation,
- explicit break-glass members can keep password access,
- and break-glass means password sign-in and password reset only.

Magic links and passkeys are not the break-glass path for this milestone's SSO-only posture.

## Operator troubleshooting by stage

Use the first failing stage instead of reverse-engineering internals:

### 1. Setup

- Look for `validation_failed` and `last_validation_error`.
- Confirm OIDC discovery and client credentials.
- Do not assume an inactive connection is safe to route.

### 2. Routing

- Check whether the login used the explicit organization route or domain discovery.
- Investigate `:no_org_match`, `:multiple_org_matches`, or `:org_connection_unavailable`.
- Prefer the canonical organization-scoped sign-in route for retries.

### 3. Reconciliation

- Verify whether the callback produced `:existing_membership`, `:invitation_consumed`, or `:jit_created`.
- Treat `:ambiguous_email_match` and `:provider_subject_conflict` as safe refusals, not partial success.
- Keep recovery on the same organization enterprise path.

### 4. Enforcement

- If local password sign-in is denied, confirm whether SSO-only is enabled.
- Verify break-glass membership for the affected operator.
- Do not treat a denied local login as a callback or routing problem.

## Testing

Root and host proof should stay layered:

- root ExUnit for setup, routing, callback, reconciliation, and enforcement outcomes,
- `test/example` integration coverage for canonical success and denied paths,
- generated-host parity checks for installer templates,
- and one intentionally narrow browser lane for served-route proof.

See [../docs/uat-ci-coverage.md](../docs/uat-ci-coverage.md) for the machine-vs-human boundary.

## Token encryption

Access and refresh tokens are encrypted at rest via `cloak_ecto`. The generated `UserIdentity` schema uses `Cloak.Ecto.Binary` for token fields. Configure your vault in `lib/my_app/vault.ex`:

```elixir
defmodule MyApp.Vault do
  use Cloak.Vault, otp_app: :my_app
end

config :my_app, MyApp.Vault,
  ciphers: [
    default: {Cloak.Ciphers.AES.GCM, tag: "AES.GCM.V1", key: System.get_env("CLOAK_KEY") |> Base.decode64!()}
  ]
```

## Related

- [Account Lifecycle](account-lifecycle.html)
- [Deployment](deployment.html)
- [../docs/uat-ci-coverage.md](../docs/uat-ci-coverage.md)
- `Sigra.OAuth`
- `Sigra.EnterpriseConnections`
- `Sigra.EnterpriseRouting`
- `Sigra.OAuth.EnterpriseReconciliation`
- `Sigra.Auth`
