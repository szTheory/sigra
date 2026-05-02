# Service Accounts (M2M / `client_credentials`)

Sigra's service-account flow lets CI, internal services, and scheduled jobs
authenticate as an organization without using a member password. The transport
is the standard OAuth 2.0 `client_credentials` grant on `POST /oauth/token`,
and the resulting bearer token stays on Sigra's existing JWT verification path.

## What Sigra ships

| Layer | Owner | What you get |
| --- | --- | --- |
| Library | Sigra | `Sigra.ServiceAccounts`, `Sigra.OAuth.Token.client_credentials/2`, service-account JWT claims, service-account verification in `Sigra.Plug.FetchBearer`, and service-account short-circuits in `Sigra.Plug.RequireMembership` / `Sigra.Plug.RequireOrgMfa`. |
| Generated host | You | `<App>.ServiceAccount`, `<App>.ServiceAccountCredential`, `OAuthTokenController`, `/organizations/:org/service-accounts` LiveView, and the service-account migration template. |

## Prerequisite

Install Sigra with both organizations and JWT enabled:

```bash
mix sigra.install --jwt --organizations
mix ecto.migrate
```

Service-account artifacts are intentionally gated on both flags. Without
organizations there is no org scope for the credential, and without JWT there
is no access-token path to mint.

## The request shape

Sigra accepts both RFC 6749 client-auth mechanisms at the token endpoint.

### Recommended: HTTP Basic auth

```bash
curl -X POST https://your-app.example.com/oauth/token \
  -u "$SIGRA_CLIENT_ID:$SIGRA_CLIENT_SECRET" \
  -d "grant_type=client_credentials"
```

### Supported: form-encoded credentials

```bash
curl -X POST https://your-app.example.com/oauth/token \
  -d "grant_type=client_credentials" \
  -d "client_id=$SIGRA_CLIENT_ID" \
  -d "client_secret=$SIGRA_CLIENT_SECRET"
```

### Success response

```json
{
  "access_token": "eyJ...<jwt>...",
  "token_type": "Bearer",
  "expires_in": 3600,
  "scope": "deploy:write billing:read"
}
```

Sigra does **not** return a refresh token for this grant. Re-post to
`/oauth/token` when the access token expires.

## Scope shape inside your app

For service-account requests, `current_scope` is deliberately distinct from a
human-user scope:

```elixir
%MyApp.Accounts.Scope{
  user: nil,
  actor_type: :service_account,
  service_account_id: "sa_...",
  active_organization: %MyApp.Accounts.Organization{},
  role: nil | :your_host_defined_role,
  token_scopes: ["deploy:write", "billing:read"],
  auth_method: :jwt
}
```

That means any code that assumes `scope.user.id` is always present needs to be
updated to branch on `scope.actor_type`.

## Calling a protected endpoint

```bash
curl https://your-app.example.com/api/service-account/probe \
  -H "Authorization: Bearer $JWT"
```

The request stays on the same `Sigra.Plug.FetchBearer` path as user JWTs. There
is no parallel machine-token pipeline to maintain.

## Authorizing service-account requests

If you already implemented the Phase 92 RBAC seam, extend your host authz
module to branch on `scope.actor_type`:

```elixir
defmodule MyApp.SigraAuthz do
  @behaviour Sigra.Authz

  def can?(action, _subject, %{actor_type: :service_account, token_scopes: scopes}) do
    case {action, scopes} do
      {{:manage, :deployments}, scopes} when "deploy:write" in scopes -> true
      {{:read, :billing}, scopes} when "billing:read" in scopes -> true
      _ -> false
    end
  end

  def can?(action, subject, %{actor_type: :user} = scope) do
    # existing user-role logic
    MyApp.LegacyAuthz.can?(action, subject, scope)
  end

  def can?(_action, _subject, _scope), do: false
end
```

If you want a host-defined role on service accounts, populate
`service_accounts.role` and branch on `scope.role` the same way you do for user
memberships.

## Rate limiting

Sigra v1.21 does **not** wire framework-level rate limiting into the generated
`/oauth/token` route. Credential enumeration is already neutralised at the
library layer — `Sigra.OAuth.Token` runs a constant-time `secure_compare`
against a dummy hash even when the `client_id` does not exist, and returns the
single `:invalid_client` error atom for all five failure sub-cases (unknown
`client_id`, wrong `client_secret`, revoked credential, expired credential,
revoked service account). Timing and error-shape attacks are closed.

The residual concern is unbounded credential-stuffing **request volume**.
Mitigate it one of two ways:

1. **At the edge (recommended for v1.21):** apply per-IP rate limits at your
   reverse proxy / WAF / CDN — typically 10–60 requests per minute per IP for
   `/oauth/token`.
2. **In your own pipeline:** add `Sigra.Plug.RateLimit` (Hammer-backed) before
   the OAuth controller in your router, e.g.:

   ```elixir
   pipeline :oauth_throttled do
     plug :accepts, ["json"]
     plug Sigra.Plug.RateLimit, scope: :ip, limit: 10, period: 60_000
   end

   scope "/", MyAppWeb do
     pipe_through :oauth_throttled
     post "/oauth/token", OAuthTokenController, :create
   end
   ```

A future Sigra release (v1.22 follow-up, AR-93-02) will wire this directly
into the generated route so adopters get the protection by default.

## Rotation flow

Sigra models service accounts and credentials separately so you can rotate
without downtime:

1. Create a new credential for the existing service account.
2. Deploy the new `client_id` / `client_secret` to your service.
3. Verify the new credential can mint a token and call your protected API.
4. Revoke the old credential.

Revoking the service account itself is the hard stop. It bumps the
service-account token epoch so all live tokens for that account fail on the
next request.

## Related

- [Role-Based Access Control](./role-based-access-control.md)
- [Multi-Tenant Setup](./multi-tenant.md)
- [Deployment](./deployment.md)
