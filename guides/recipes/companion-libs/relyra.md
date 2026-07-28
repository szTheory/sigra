<!-- validated_against: relyra ~> 1.2 -->
<!-- last_validated: 2026-05-28 -->
# Recipe: Sigra + Relyra (SAML 2.0 SP federation)

Validated against: `relyra ~> 1.2` as of 2026-05-28

> **Sigra works fully standalone.** Relyra is an optional integration; Sigra ships without it, and removing the wiring below returns Sigra to standalone operation with no further changes.

## What this is

| Role | Library | Responsibility |
|------|---------|----------------|
| Session issuance + org-scoped identity | **Sigra** | Mints the session after the SAML ACS round-trip; owns `AuditEvent` rows, session lifecycle, and org membership context |
| SAML 2.0 SP — metadata, assertions, SLO | **Relyra** | Manages SP metadata, signing keys, IdP registration, assertion consumption, and IdP-initiated SLO |

Sigra owns **only** the org-scoped session it issues after the SAML assertion. Everything
SAML-specific — metadata storage, certificate rotation, IdP-initiated single logout — stays
with Relyra.

## OIDC vs SAML: which path?

| Scenario | Path |
|----------|------|
| Enterprise SSO via OIDC / SAML-via-broker IdP (Okta, Azure AD with OIDC front) | **Sigra v1.27 ENT-SSO** — `lib/sigra/enterprise_connections.ex`, `lib/sigra/enterprise_routing.ex`, `lib/sigra/oauth/enterprise_reconciliation.ex` handle OIDC-via-Assent in-library. No additional package needed. |
| Direct SAML 2.0 SP federation — IdP sends SAMLResponse to your ACS endpoint | **Relyra** (this recipe) — your app acts as the SAML Service Provider; Relyra handles the ceremony; Sigra mints the session after the ACS callback. |

If your IdP speaks OIDC (or OIDC-fronted SAML), prefer Sigra's built-in ENT-SSO surface.
Use Relyra when the IdP requires direct SAML 2.0 SP registration and SAMLResponse delivery.

## Prerequisites

- **Sigra user lookup/creation is working first** — the ACS callback maps the SAML subject
  to a Sigra user (looked up or created); `Sigra.Auth.create_session/4` then mints the
  session. Confirm normal login and user-create flows are green in `dev` before wiring Relyra.
- **Relyra `~> 1.2` is installed and configured** — SP metadata generated, IdP registration
  complete, ACS and SLO endpoints added to your router. See the
  [Relyra README](https://hex.pm/packages/relyra) for bootstrap steps.

## `mix.exs` snippet

**Host app only** — Sigra does not add Relyra as a dependency.

```elixir
defp deps do
  [
    {:sigra, "~> 1.4.0"},
    {:relyra, "~> 1.2"},
    # ... your other deps
  ]
end
```

If you are reading `main` before Hex shows `1.0.0`, use the latest published Sigra package or a source checkout until the release PR lands.

## Integration walkthrough

### 1. Initiate the SAML login

Call `Relyra.start_login/3` (`relyra.ex:28-29`, signature:
`start_login(connection, relay_context, opts \\ [])`) from your SSO initiation controller
action to build the AuthnRequest and redirect the browser to the IdP:

```elixir
def sso_login(conn, params) do
  relay_context = %{return_to: params["return_to"] || "/dashboard"}
  Relyra.start_login(conn, relay_context)
end
```

### 2. Handle the ACS callback and mint a Sigra session

After the IdP posts the SAMLResponse to your ACS endpoint, call
`Relyra.consume_response/3` (`relyra.ex:150-152`, signature:
`consume_response(response_payload, request_intent_or_opts, opts \\ [])`) to validate the
assertion and receive a `%Relyra.LoginResult{}` (per the Relyra moduledoc at `relyra.ex:6-12`).

Read the authenticated subject from the `%Relyra.LoginResult{}` that Relyra returns, look up
or create the corresponding Sigra user, then mint the session via
`Sigra.Auth.create_session/4` (`lib/sigra/auth.ex:1284`,
signature: `(config, user, metadata, opts \\ [])`):

```elixir
def acs(conn, %{"SAMLResponse" => saml_response} = params) do
  sigra_config = MyApp.Auth.sigra_config()

  with {:ok, login_result} <- Relyra.consume_response(saml_response, params),
       {:ok, user} <- MyApp.Accounts.find_or_create_from_saml(login_result),
       {:ok, session} <- Sigra.Auth.create_session(sigra_config, user, %{type: :saml}) do
    conn
    |> MyAppWeb.UserAuth.put_user_session_token(session.token)
    |> redirect(to: "/dashboard")
  else
    {:error, reason} ->
      conn
      |> put_flash(:error, "SSO login failed: #{inspect(reason)}")
      |> redirect(to: "/users/log_in")
  end
end
```

`Sigra.Auth.create_session/4` returns `{:ok, Sigra.Session.t()} | {:error, term()}`. The
`metadata` map is stored with the session — use it to record `type: :saml`, the IdP name,
or the SAML session index for SLO correlation.

**The session-mint entry point is always `Sigra.Auth.create_session/4`** at
`lib/sigra/auth.ex:1284`. The `lib/sigra/session.ex` module has no `create_session` function;
using any other module path causes an `UndefinedFunctionError` at runtime.

## Failure modes

### 1. Relyra dep absent at boot

If `{:relyra, "~> 1.2"}` is absent from the host's compiled deps, calls to
`Relyra.start_login/3` and `Relyra.consume_response/3` raise `UndefinedFunctionError`. No
Sigra boot warning is emitted. Ensure the dep is in `mix.exs` before enabling the SAML flow.

### 2. `consume_response/3` returns `{:error, _}` — assertion validation failed

Common causes: expired SAMLResponse (clock skew between SP and IdP), invalid signature
(SP certificate mismatch), or missing required attributes. Log the full error, confirm clock
sync, and verify the SP metadata registered with the IdP matches your current Relyra config.

### 3. `Sigra.Auth.create_session/4` returns `{:error, _}` — session creation failed

If the Sigra session store is unavailable or the user struct is invalid, `create_session/4`
returns an error. Ensure the user was successfully looked up or created before calling
`create_session/4`, and confirm the Sigra session store (`Sigra.SessionStores.Ecto`) is configured.

### 4. IdP-initiated SLO reaches your SLO endpoint while session is active

Relyra handles the SLO ceremony. After Relyra confirms the logout, invalidate the Sigra
session by calling `Sigra.Auth.delete_session/3` — signature `(config, hashed_token, opts \\ [])`
— passing your `Sigra.Config` (from `MyApp.Auth.sigra_config()`) as the first argument. The SAML
session index stored in your session metadata (`metadata[:saml_session_index]`) can help correlate
the SLO request to the right Sigra session.

## Non-goals

The following stay with Relyra — Sigra does not own them:

- **SAML metadata storage and SP descriptor generation** — Relyra manages `metadata.xml` and
  the `EntityDescriptor` the IdP requires.
- **Signing key management and certificate rotation** — Relyra holds the SP private key and
  handles certificate rollover.
- **IdP-initiated single logout (SLO)** — Relyra validates and dispatches the IdP-sent
  `<LogoutRequest>`; Sigra invalidates the session on notification.
- **SAML assertion attribute mapping** — mapping IdP attributes to your application's user
  fields is host-owned logic inside `find_or_create_from_saml/1`.

There is **no `--with-relyra` install flag** in `mix sigra.install`.

## See also

- [Suite integration overview](../../introduction/suite-integration.html) — companion-library
  ecosystem diagram and Diminishing Returns Wall framing
- [OAuth flow](../../flows/oauth.html) — Sigra's built-in OIDC-via-Assent consumer OAuth;
  contrast with the SAML SP path this recipe describes
- [Account lifecycle flow](../../flows/account-lifecycle.html) — user creation and deletion
  semantics relevant to `find_or_create_from_saml/1`
- [Lockspire recipe](./lockspire.html) — embedded OAuth/OIDC provider in the same host
