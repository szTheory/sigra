# Upgrading generated hosts for v1.5 auth capability gates

Sigra v1.5 adds runtime capability gates to newly generated authentication surfaces. All three switches default to `true`, so updating the dependency preserves existing behavior. Generated files belong to the host and are never overwritten automatically.

## Configure a consumer-only host

Add the desired switches to the host's existing `:sigra_config` entry:

```elixir
config :my_app, :sigra_config,
  mfa: [enabled: false],
  passkeys: [enabled: false],
  enterprise: [enabled: false]
```

OAuth remains separate. Continue configuring it under the application's existing `:sigra` or `:sigra_config` OAuth section:

```elixir
config :my_app, :sigra,
  oauth: [
    enabled: true,
    providers: [google: [client_id: "...", client_secret: "..."]]
  ]
```

The enterprise switch controls work-email discovery. Organization support can remain installed for tenancy, invitations, or policy without exposing discovery on the public login page. An install built with `--no-organizations` cannot provide enterprise discovery even when the switch is true.

## Adopt the gates in an existing generated host

Do not run the installer with `--force` over customized files. Generate a disposable host with the same flags and copy the relevant changes selectively:

1. Update the generated Accounts context's `sigra_config/0` to read the `:mfa`, `:passkeys`, `:enterprise`, and `:oauth` runtime sections. Add `mfa_capability_enabled?/0`, `passkeys_enabled?/0`, and `enterprise_sign_in_enabled?/0` delegates.
2. Add `ensure_mfa_capability/2`, `ensure_passkeys_capability/2`, and `ensure_auth_settings_capability/2` to the generated `UserAuth` module. Each disabled check must send a 404 and halt.
3. Add the matching router pipelines before authentication and sudo plugs on MFA, passkey, and account-security scopes. This ordering makes disabled routes explicitly unavailable instead of redirecting to login.
4. Pass `enterprise_sign_in_enabled` and the passkey capability into the generated login template. Hide both each form and its adjacent divider. Guard the enterprise POST action with the same capability.
5. In `MFASettingsLive`, assign both capability values, avoid loading disabled data, and render only enabled sections.
6. If JWT routes were generated, guard `POST /api/auth/token/mfa` and return a 404 response such as `{"error":"mfa_unavailable"}` when MFA is disabled.

Re-run the host test suite and assert both absence and endpoint behavior. At minimum, cover `GET /users/log_in`, `GET /users/mfa`, `GET /users/settings/mfa`, passkey option POSTs, enterprise discovery POSTs, and one independently enabled OAuth request.

## Migration and rollback

No database migration is required. Deploying the library alone leaves every capability enabled by default. Rollback is a configuration change: remove a key to restore the default, or set its `enabled` value explicitly. Keep endpoint checks and UI conditions driven by the same helper so a hidden control never leaves a callable generated route behind.
