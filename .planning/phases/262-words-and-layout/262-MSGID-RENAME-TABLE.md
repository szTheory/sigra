# Phase 262 Generated Auth Msgid Rename Table

This table is the only Phase 262 authority for changing an existing generated-auth msgid. Source paths are relative to `priv/templates/sigra.install/`. Keep the `sigra` domain, routes, helpers, function names, form names, and unlisted msgids unchanged.

| Template | Surface | Old msgid | New msgid | Rationale |
|---|---|---|---|---|
| `core/registration_live.ex` | Existing-account link | `Log in` | `Sign in` | Apply the approved action vocabulary to the registration LiveView. |
| `core/registration_html.ex` | Existing-account link | `Log in` | `Sign in` | Keep controller-mode wording aligned with the LiveView. |
| `core/confirmation_live.ex` | Confirmed, already-confirmed, and sign-in-required links | `Log in` | `Sign in` | Keep all confirmation outcomes aligned with the approved action vocabulary. |
| `core/confirmation_live.ex` | Already-confirmed subtitle | `Your email was already confirmed. You can log in below.` | `Your email was already confirmed. You can sign in below.` | Keep the recovery instruction consistent with its link. |
| `core/confirmation_html.ex` | Already-confirmed subtitle | `Your email was already confirmed. You can log in below.` | `Your email was already confirmed. You can sign in below.` | Keep the controller-mode recovery instruction consistent. |
| `core/confirmation_html.ex` | Already-confirmed link | `Log in` | `Sign in` | Match the LiveView confirmation outcome. |
| `core/reset_password_live.ex` | Return link | `Back to log in` | `Back to sign in` | Use the approved sign-in wording on the reset request page. |
| `core/reset_password_html.ex` | Return link | `Back to log in` | `Back to sign in` | Keep controller-mode reset wording aligned with LiveView. |
| `core/emails.ex` | HTML and plain-text OAuth reset CTAs | `Log in with %{provider}` | `Sign in with %{provider}` | Use the canonical sign-in action in both versions of the generated OAuth reset email. |
| `core/settings_live.ex` | Account deletion strategy notice | `Schedule account deletion according to your configured deletion strategy. After the grace period expires, Sigra finalizes the account lifecycle according to that strategy.` | `Schedule account deletion according to your configured deletion strategy. After the grace period expires, the selected strategy is applied to your account.` | Remove library identity from host-owned auth copy while preserving the account deletion strategy and grace-period meaning. |
