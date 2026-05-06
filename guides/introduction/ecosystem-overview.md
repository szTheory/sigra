# Where Sigra Fits — The Auth Stack at a Glance

If you're starting a Phoenix SaaS and trying to figure out which auth libraries you need, in what order, and where they hand off to each other — this page is for you. It explains Sigra's role and points to its companion libraries so you don't have to reverse-engineer the picture.

> **TL;DR.** Sigra owns *who the user is*. Companion libraries cover the two adjacent jobs Sigra deliberately doesn't do: **issuing OAuth/OIDC tokens to other apps** (Lockspire) and **accepting SAML logins from your customers' corporate IdPs** (Relyra). All three compose through small, host-owned glue modules.

## The three jobs of an auth stack

Most Phoenix SaaS apps end up needing some mix of these three jobs. They are different concerns and Sigra's design intentionally only covers the first.

| # | Job | What it means | Library |
|---|-----|---------------|---------|
| 1 | **Inbound — local auth** | Your users sign up and log in to *your* app (passwords, magic links, MFA, passkeys, social login as a *consumer*) | **Sigra** |
| 2 | **Inbound — federated auth** | Your *enterprise customers'* employees log in via *their* corporate SSO (SAML) | [Relyra](https://github.com/szTheory/relyra) (WIP) |
| 3 | **Outbound — be an OAuth provider** | *Other apps* ask your users for permission to call your API on their behalf | [Lockspire](https://github.com/szTheory/lockspire) |

Two different directions:

- **Inbound** = a person proves who they are *to your app*.
- **Outbound** = your app proves a person's identity *to another piece of software*.

Sigra and Relyra are inbound. Lockspire is outbound. Lockspire doesn't care *how* a user originally logged in — it just needs an active Sigra session to mint tokens against.

## A typical Phoenix SaaS journey

You usually do not adopt all three at once. Most projects walk this path:

1. **Day 0 — Just Sigra.** `mix sigra.install` gets you registration, login, MFA, passkeys, sessions, audit, optional orgs/RBAC. For most B2C and B2B-SMB products, this is the entire auth stack. Stop here unless you have a concrete need below.
2. **First enterprise customer that wants SAML SSO** → add **Relyra**. Their IdP (Okta, Entra, Google Workspace, etc.) hands off a verified assertion → your glue code finds-or-creates a Sigra user → starts a Sigra session. From every other module's point of view (including Lockspire, if present), the user just logged in.
3. **First third-party developer who wants to build on your API** (think "Slack apps" or "Zapier integrations") → add **Lockspire**. Now external apps can do an OAuth dance against your service: the user lands on your page, sees a consent screen, approves, and the third-party app gets tokens to call your API as that user.

If your product never has third-party API consumers, you never need Lockspire. If your customers never demand SAML, you never need Relyra. Sigra alone is the common case.

## How it actually wires together

```text
                                     ┌──────────────────────────────────────────┐
                                     │       Phoenix host application           │
  Browser (your users) ──────────────►  Sigra plugs / LiveView / context        │
                                     │      └─► creates Sigra session           │
                                     │                                          │
  SAML IdP (Okta, Entra) ────────────►  Relyra ACS endpoint                     │
                                     │      └─► host glue: find-or-create user  │
                                     │           └─► creates Sigra session      │
                                     │                                          │
  Third-party OAuth client ──────────►  Lockspire /authorize, /token, /userinfo │
                                     │      └─► AccountResolver reads           │
                                     │           Sigra's current_scope          │
                                     │           and builds claims              │
                                     └──────────────────────────────────────────┘
```

The key insight: **Sigra's session is the single source of truth for "who is logged in."** Both Relyra (after a SAML assertion) and Lockspire (when issuing tokens) talk to that one session through small, host-owned glue modules.

## The integration seams (what *you* write)

Both companion libraries integrate through host-owned glue, not deep coupling. The glue is generated for you and you fill in the parts that depend on your app's data model.

### Lockspire ↔ Sigra

Lockspire defines a single behaviour, `Lockspire.Host.AccountResolver`, with six callbacks: "who is logged in now," "look up an account by reference" (used during introspection and refresh), "redirect to login," "build claims," "redirect to logout," and (for CIBA flows) "verify a backchannel user code."

Generate a Sigra-aware stub from your host:

```bash
mix lockspire.install --sigra-host
```

The generator emits a host-owned module with comments pointing at Sigra's `current_scope`. You fill in the bits that need your data: which user fields go into `id_token`, which into `userinfo`, how org membership and roles map to claims.

A typical implementation is ~80 lines:

```elixir
defmodule MyApp.Lockspire.HostImpl do
  @behaviour Lockspire.Host.AccountResolver

  def resolve_current_account(conn, _ctx) do
    case conn.assigns[:current_scope] do
      %{user: user} -> {:ok, user}
      _ -> {:redirect, %Lockspire.Host.InteractionResult{login_path: "/users/log-in"}}
    end
  end

  def build_claims(user, ctx) do
    {:ok,
     %Lockspire.Host.Claims{
       subject: to_string(user.id),
       id_token: %{"email" => user.email, "email_verified" => !!user.confirmed_at},
       userinfo: %{
         "email" => user.email,
         "name" => user.name,
         "org_ids" => MyApp.Accounts.org_ids_for(user),
         "roles" => MyApp.Accounts.roles_for(user, ctx.scopes)
       }
     }}
  end

  # ... redirect_for_login/2, redirect_for_logout/2, verify_backchannel_user_code/3
end
```

Why does the generator live in **Lockspire** and not in Sigra? Lockspire owns the behaviour contract, so it owns the codegen for the glue that satisfies it. Sigra exposes a stable `current_scope` shape; Lockspire knows what to do with it. This keeps Sigra's surface and dependency footprint clean while giving Lockspire adopters a one-stop install command.

See the deeper recipe at [Companion OAuth provider](../recipes/companion-oauth-provider.html).

### Relyra ↔ Sigra

Relyra terminates SAML at its ACS endpoint and hands you a verified assertion. Your host glue looks up or creates a Sigra user from the assertion's attributes (typically `email` plus `(provider, provider_uid)`) and then starts a Sigra session. From there, every other layer treats the user identically to a password login.

Concretely:

1. Relyra ACS controller returns `{:ok, assertion}` with attributes
2. Host code maps assertion attributes to a Sigra user — a small `MyApp.Accounts.upsert_from_saml/1` you write that keys on `(provider, provider_uid)` with `email` as a secondary lookup
3. Host code: `Sigra.Auth.create_session(config, user, %{auth_method: :saml})` → `%Sigra.Session{}` with a fresh raw `:token`
4. `Plug.Conn.put_session(conn, :user_token, session.token)` and redirect

This makes SAML "just another login method" from the rest of the app's perspective. If Lockspire is also present, SAML-originated users get OAuth tokens through the same Lockspire endpoints that password-originated users do. No special path.

Relyra is currently early — see its repo for current scope.

## When you don't need a companion lib

A common mistake is reaching for an OAuth provider library when all you actually need is "log in with Google" for *your* product's users. That's covered by Sigra alone via Assent (see [OAuth flow](../flows/oauth.html)).

| Need | Solution |
|------|----------|
| "Let users log in with Google/GitHub/Apple" | Sigra's built-in OAuth consumer support — no Lockspire needed |
| "Let *external developers* build apps that call my API on behalf of users" | Lockspire |
| "Let my enterprise customers' employees SSO in with their corporate IdP" | Relyra |
| "Replace my entire login UI with a managed identity provider" | Out of scope for this stack — evaluate dedicated CIAM products |

## Subject identity and claim hygiene

A few rules of thumb that apply across companion integrations:

- **`sub`** (subject) for any token you issue should be a stable internal identifier — Sigra's user primary key as a string is the typical choice. Never use email, even though it's tempting; users change emails.
- **Claims** should come from the same authorization context your app already trusts. If your app uses Sigra's organizations + RBAC, your Lockspire claims should reflect those rather than re-deriving membership from scratch.
- **No mandatory Hex dependency** between Sigra and the companion libraries. Integration is host-generated code, not a runtime import. This keeps each library's dependency surface minimal and avoids version lock.
- **Login redirects** (Lockspire's `redirect_for_login`) should point at your real Sigra login route and preserve any query params the companion needs to resume its flow.

## Decision summary

Coming back to the original question — "where do all these libs fit, and what do I need next?" Walk it like this:

```text
Building a Phoenix SaaS auth stack?
  │
  ├─► Need users to log in?
  │     └─► Sigra. Always. Start here.
  │
  ├─► Need third-party apps to integrate with your API?
  │     └─► Add Lockspire. mix lockspire.install --sigra-host.
  │
  └─► Need enterprise SSO for customers?
        └─► Add Relyra. Wire its ACS to create-or-find a Sigra user.
```

Each library has tight non-goals. Sigra never owns OAuth issuance. Lockspire never owns user tables. Relyra never owns sessions. The clean separation is what makes the stack composable.

## See also

- [Companion OAuth provider recipe](../recipes/companion-oauth-provider.html) — the deeper recipe, focused on Sigra↔Lockspire
- [OAuth (login with provider) flow](../flows/oauth.html) — Sigra-as-consumer ("log in with Google"), distinct from Lockspire-as-provider
- [Multi-tenant guide](../recipes/multi-tenant.html) — relevant if your claims need org context
- [Role-based access control](../recipes/role-based-access-control.html) — relevant if your claims need roles
