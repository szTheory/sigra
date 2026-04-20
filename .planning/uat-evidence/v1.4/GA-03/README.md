# GA-03 — Live Google OAuth vs library **OAuth** contract tests

**Machine baseline:** **`Sigra.OAuthTest`** and related modules exercise **`MockStrategy`** — authorize URL shape, HMAC-protected state, `handle_callback/4` without live HTTP. This proves **protocol handling** the library owns.

**Human baseline:** **Live Google** on a **dedicated test OAuth client** — register, login, provider linking, and email-match confirmation flows per **REQUIREMENTS.md GA-03**. Capture outcomes in `steps.md`; never paste client secrets — use env var **names** only.

**Coverage map:** See **`docs/uat-ci-coverage.md`** **SEED-4** row for the machine vs residual split.
