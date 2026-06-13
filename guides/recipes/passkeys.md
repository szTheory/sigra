# Passkeys

Sigra ships passkeys as a first-class WebAuthn surface. The default install wires the routes, runtime config, browser hooks, and generated pages needed for both passkey enrollment and passkey-primary sign-in.

## What Sigra gives you

- passkey enrollment from `/users/settings/mfa`
- passkey registration options at `/users/settings/mfa/passkeys/options`
- passkey authentication options at `/users/log_in/passkey/options`
- MFA passkey completion at `/users/mfa/passkey`
- passkey-primary login at `/users/log_in/passkey`
- runtime config for `rp_id`, `origin`, timeouts, attestation, and `passkey_primary_enabled`

## Happy path: enroll a passkey

Start from a confirmed, signed-in user and visit `/users/settings/mfa`.

The generated page posts to:

1. `/users/settings/mfa/passkeys/options` to fetch registration options
2. `/users/settings/mfa/passkeys` to submit the browser ceremony result

On success the user lands back on:

    /users/settings/mfa#passkeys

This is the same route posture the example app and browser smoke exercise.

## Happy path: passkey-primary login

With `passkey_primary_enabled: true`, `/users/log_in` keeps the passkey form visible alongside password and magic-link fallback.

The generated login page includes:

- **Use a passkey**
- **Use password instead**
- **Email me a magic link**

When a known email is supplied, the browser requests options from:

    /users/log_in/passkey/options

Then it posts the signed assertion to:

    /users/log_in/passkey

This matters operationally: passkey-primary does not mean passkey-only. Sigra keeps recovery posture visible on the real login page.

## The config gate: `passkey_primary_enabled`

The generated runtime config includes:

    config :my_app, :sigra_config,
      passkeys: [
        rp_id: "localhost",
        rp_name: "My App",
        origin: "http://localhost:4000",
        passkey_primary_enabled: true
      ]

Set `passkey_primary_enabled: true` when you want passkeys promoted on the main login page. Set it to `false` if you only want passkeys as an MFA or settings-level enrollment surface.

## RP ID and origin

Two values are load-bearing:

- **RP ID**: the relying-party domain the authenticator binds credentials to
- **origin**: the full browser origin used during WebAuthn verification

Local development defaults are:

- `rp_id: "localhost"`
- `origin: "http://localhost:4000"`

In production, these must match the browser-facing host you actually serve.

## Rename playbook: RP ID and origin changes

If you rename domains, treat it as an operational migration.

1. Update `rp_id` and `origin` together.
2. Deploy the new runtime config.
3. Expect existing passkeys bound to the old RP ID to stop authenticating against the new domain.
4. Keep password, authenticator code, backup code, or magic link recovery available during the transition.
5. Ask affected users to enroll a new passkey on the new domain.

That is the practical consequence of the WebAuthn trust model, not a Sigra quirk.

## Recovery posture

Never roll out passkeys without another sign-in path. Sigra's generated copy already assumes recovery can happen through:

- password
- authenticator code
- backup code
- magic link

That same posture appears when a passkey sign-in attempt fails: the user is returned to a standard recovery path instead of being trapped in a dead end.

## Testing

Keep at least one real-browser passkey smoke test in your pipeline. The example app uses a virtual authenticator and hits the real options routes instead of mocking them away.

Focused controller coverage should include:

- `/users/settings/mfa/passkeys/options`
- `/users/settings/mfa/passkeys`
- `/users/log_in/passkey/options`
- `/users/log_in/passkey`

## Related

- [Getting Started](getting-started.html) — the default passkey-enabled walkthrough.
- [Upgrading to v1.1](upgrading-to-v1.1.html) — adding the passkey surface to an existing v1.0 install.
- [Multi-factor authentication](mfa.html) — TOTP, backup codes, and trust-this-browser alongside passkeys.
