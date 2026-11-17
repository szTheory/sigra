# Phase 262 Generated Auth Msgid Rename Table

This table is the only Phase 262 authority for changing an existing generated-auth msgid. Source paths are relative to `priv/templates/sigra.install/`. Keep the `sigra` domain, routes, helpers, function names, form names, and unlisted msgids unchanged.

| Template | Surface | Old msgid | New msgid | Rationale |
|---|---|---|---|---|
| `core/registration_live.ex` | Existing-account link | `Log in` | `Sign in` | Apply the approved action vocabulary to the registration LiveView. |
| `core/registration_html.ex` | Existing-account link | `Log in` | `Sign in` | Keep controller-mode wording aligned with the LiveView. |
