<!-- validated_against: lockspire ~> 1.2 -->
<!-- last_validated: 2026-05-29 -->
# Recipe: Sigra + Lockspire (embedded OAuth/OIDC provider)

Validated against: `lockspire ~> 1.2` (`def616d`) as of 2026-05-29

> **Sigra works fully standalone.** Lockspire is an optional integration; Sigra ships without it, and removing the wiring below returns Sigra to standalone operation with no further changes.

## What this is

| Role | Library | Responsibility |
|------|---------|----------------|
| End-user authentication | **Sigra** | Sessions, passwords, MFA, passkeys, social login; issues session cookies and populates `current_scope` |
| OAuth/OIDC authorization server | **Lockspire** | Authorization codes, token issuance, client registry, consent for third-party apps calling your API |

This is a **concrete recipe** — it shows the `mix.exs` entry, the install command, and the
AccountResolver callbacks you must implement. For the architecture-level framing of why you
would run both roles in one Phoenix host, see the
[companion OAuth/OIDC provider recipe](../companion-oauth-provider.html).

## Prerequisites

- **Sigra end-user login is working first** — session cookies, plugs, and normal login/register
  flows must be green in `dev` before you wire the AccountResolver. Lockspire authorizes
  third-party clients **after** Sigra proves who the user is.
- **You actually need an embedded OAuth/OIDC server** — third-party clients, consent screens,
  and token issuance for external apps calling your API. If you only need social login for your
  own users, Sigra + Assent alone is sufficient.

## `mix.exs` snippet

**Host app only** — Sigra does not add Lockspire as a dependency.

```elixir
defp deps do
  [
    {:sigra, "~> 1.0"},
    {:lockspire, "~> 1.2"},
    # ... your other deps
  ]
end
```

If you are reading `main` before Hex shows `1.0.0`, use the latest published Sigra package or a source checkout until the release PR lands.

## Install the AccountResolver stub

Run the Lockspire generator to scaffold the AccountResolver with Sigra-oriented comments:

```
mix lockspire.install --sigra-host
```

This generates a `MyApp.AccountResolver` stub that you must complete. The stub is **host-owned
code** — it is not managed or updated by Lockspire after generation.

## The AccountResolver contract

Lockspire calls the AccountResolver to answer "who is logged in?" at authorization time. Pin
the behaviour to `lockspire/lib/lockspire/host/account_resolver.ex:14-39`.

The contract has **4 required callbacks** and **2 optional callbacks**:

| Callback | Arity | Status | Purpose |
|----------|-------|--------|---------|
| `resolve_current_account/2` | 2 | required | Resolve the account from the current conn/socket |
| `resolve_account/2` | 2 | required | Resolve an account by reference (e.g. for token exchange) |
| `build_claims/2` | 2 | required | Build the OIDC claims map for the account |
| `redirect_for_login/2` | 2 | required | Redirect to the Sigra login page when no session exists |
| `verify_backchannel_user_code/3` | 3 | optional | CIBA backchannel flows only — not needed for standard OAuth |
| `redirect_for_logout/2` | 2 | optional | Custom logout redirect; omit to use Lockspire's default |

A host that does not use CIBA backchannel flows does not need to implement
`verify_backchannel_user_code/3`.

### Implementing the required callbacks

The key Sigra integration point is `resolve_current_account/2`, which reads the authenticated
user from `conn.assigns.current_scope.user` (per `lib/sigra/scope.ex:18-25` — the `build/3`
constructor sets the `:user` field on the host-generated `%Scope{}` struct):

```elixir
defmodule MyApp.AccountResolver do
  @behaviour Lockspire.Host.AccountResolver

  @impl Lockspire.Host.AccountResolver
  def resolve_current_account(conn, _context) do
    case conn.assigns[:current_scope] do
      %{user: %{id: _} = user} -> {:ok, user}
      _ -> {:error, :unauthenticated}
    end
  end

  @impl Lockspire.Host.AccountResolver
  def resolve_account(account_reference, _context) do
    case MyApp.Accounts.get_user(account_reference) do
      nil -> {:error, :not_found}
      user -> {:ok, user}
    end
  end

  @impl Lockspire.Host.AccountResolver
  def build_claims(user, _context) do
    {:ok, %{
      sub: to_string(user.id),
      email: user.email,
      email_verified: user.confirmed_at != nil
    }}
  end

  @impl Lockspire.Host.AccountResolver
  def redirect_for_login(conn, context) do
    # URI-encode return_to — never interpolate caller-supplied values raw (open-redirect / injection risk).
    return_to = URI.encode_www_form(context.return_to)
    Phoenix.Controller.redirect(conn, to: "/users/log_in?return_to=#{return_to}")
  end
end
```

Register the resolver in your Lockspire config:

```elixir
config :lockspire, :account_resolver, MyApp.AccountResolver
```

**Subject (`sub`) stability:** use a stable, immutable user identifier (typically the user
primary key as a string). Do not use email or username as `sub` — they are mutable.

## Failure modes

### 1. Lockspire dep absent at boot

If `{:lockspire, "~> 1.2"}` is absent from the host's compiled deps, any call to Lockspire
modules raises `UndefinedFunctionError`. No Sigra boot warning is emitted — Sigra does not
know whether Lockspire is present.

### 2. `resolve_current_account/2` returns `{:error, :unauthenticated}`

When no Sigra session exists (e.g. the browser cookie is expired), `resolve_current_account/2`
should return `{:error, :unauthenticated}`. Lockspire then calls `redirect_for_login/2` to
bounce the user to the Sigra login page. Ensure `redirect_for_login/2` sets a `return_to`
parameter so the OAuth flow resumes after login.

### 3. `build_claims/2` raises or returns unexpected shape

If `build_claims/2` raises or returns a map that violates the OIDC claim contract, Lockspire
will return an authorization error to the third-party client. Add unit tests for
`build_claims/2` with representative user structs before going to production.

### 4. AccountResolver stub not completed after generation

Running `mix lockspire.install --sigra-host` generates a stub; the stub does not compile
without the required callbacks implemented. The generator leaves `# TODO:` markers at each
callback — complete them before running `mix compile`.

## Non-goals

- There is **no `sigra_lockspire` glue Hex package** at this time (ADR 001). The decision to
  defer a published glue package is revisited when: Lockspire Phase 6 (`RELS-01`/`RELS-02`)
  ships and is stable; the AccountResolver (or successor seam) APIs are semver-stable on both
  sides; and at least one public reference app exercises both libraries under CI.
- There is **no `--with-lockspire` install flag** in `mix sigra.install`. The wiring above
  requires host-owned code that `mix lockspire.install --sigra-host` scaffolds; no Sigra
  generator support is needed or planned.
- Sigra does **not** own client registry, consent screens, token storage, or token issuance.
  Those belong entirely to Lockspire.
- For the architecture-level framing (when to use an embedded AS, the "no mandatory Hex edge"
  rule of thumb), see the [companion OAuth/OIDC provider recipe](../companion-oauth-provider.html).

## See also

- [Companion OAuth/OIDC provider recipe](../companion-oauth-provider.html) — architecture-level
  framing: why run both roles in one host, rules of thumb for claims and subject stability
- [OAuth flow](../../flows/oauth.html) — Sigra's consumer OAuth (login with provider), distinct from
  the embedded AS pattern this recipe describes
- [Suite integration overview](../../introduction/suite-integration.html) — companion-library
  ecosystem diagram and Diminishing Returns Wall framing
- [Accrue recipe](./accrue.html) — seat-limit gating and subscription lifecycle via Accrue
