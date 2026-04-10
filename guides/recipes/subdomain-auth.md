# Subdomain Authentication

Sigra supports cookie-based auth across subdomains (`app.example.com`, `api.example.com`, `www.example.com`) via the `:cookie_domain` config option. This recipe covers the config, pitfalls, and the recommended deployment pattern.

## The config key

`:cookie_domain` is a top-level key on `Sigra.Config`. Defaults to `nil` (host-only cookies — safe for dev, test, and single-domain prod). Set a string to enable subdomain auth:

    config :my_app, MyApp.Auth.Config,
      cookie_domain: System.get_env("COOKIE_DOMAIN")

The value applies to all Sigra-managed cookies: remember-me, MFA trust, and any future cookie added to the library. It does NOT automatically configure the Phoenix session cookie itself — that lives in your `endpoint.ex` under `Plug.Session`. See below.

## Writing the domain value

**Always use a leading dot** so the cookie is recognized by every subdomain:

    # Good
    cookie_domain: ".example.com"

    # Bad — host-only, subdomains won't see the cookie
    cookie_domain: "example.com"

    # BAD — overly broad, leaks cookies to every `.com` site
    cookie_domain: ".com"

Scope the domain to your own registrable domain. Never use a public suffix like `.com`, `.co.uk`, or `.dev` — browsers will reject or you will leak session cookies to unrelated sites.

## Why there is no auto-detection

Sigra intentionally does NOT offer `:parent` or `:auto` atom values for `:cookie_domain`. Auto-detection requires knowledge of public-suffix boundaries that cannot be statically inferred from a request host (e.g., `foo.github.io` is a public suffix, `foo.example.com` is not). Sigra keeps the surface explicit — you pass a string, you own the choice.

## Configuring the Phoenix session cookie

The Phoenix session cookie (managed by `Plug.Session` in your `endpoint.ex`) is NOT controlled by Sigra. To share sessions across subdomains, edit your `lib/my_app_web/endpoint.ex`:

    plug Plug.Session,
      store: :cookie,
      key: "_my_app_key",
      signing_salt: "...",
      same_site: "Lax",
      domain: System.get_env("COOKIE_DOMAIN")

Keep this domain value in sync with `Sigra.Config.cookie_domain` — typically via the same env var.

## Prod boot warning

If `:cookie_domain` is `nil` when your app boots in `:prod`, Sigra emits a `Logger.warning` pointing to this guide. The warning is safe to ignore for single-domain deployments; silence it by setting `cookie_domain: nil` explicitly in your prod config (the warning only fires on unset, not on explicit nil — see `Sigra.Application`).

## Testing subdomain auth locally

`/etc/hosts` trick:

    127.0.0.1 app.localtest.me api.localtest.me

Then set `cookie_domain: ".localtest.me"` in `config/dev.exs`. `localtest.me` resolves to `127.0.0.1` for every subdomain out of the box.

## Common pitfalls

- **Remember-me cookies broken after browser restart** — you set `cookie_domain` after cookies were already issued. Clear cookies and log in again.
- **MFA trust cookie not recognized on sibling subdomain** — `Sigra.MFA.Trust.cookie_opts/1` honors `cookie_domain` only if you pass the config struct. Generated `mfa_challenge_controller` does this automatically; if you copy-paste into a custom controller, make sure you also pass the config.
- **Mixed-domain deployments** (`app.example.com` + `admin.anotherco.com`) — you need TWO cookie scopes. Sigra does not support per-request cookie domains today; file an issue if you need this.

## Related

- `Sigra.Config` — full option list
- `Sigra.MFA.Trust.cookie_opts/1` — MFA trust cookie
- [Deployment guide](deployment.html)
