# After the first hour: toward solo production

You finished the [First hour with Sigra](first-hour.html) green loop or the deeper [Getting started](getting-started.html) spine. This page is an **ordered** “what to read next” path toward **solo production** confidence: it links outward instead of duplicating the deployment tables you already have in the recipe docs.

1. **Re-validate locally** — run your host `mix test`, repeat register → confirm (if enabled) → log in, and skim generated `UserAuth` / `Accounts` modules so you trust the scaffold in *this* repository before you change topology.
2. **Understand mail delivery tradeoffs** — read **[Mail delivery: inline vs Oban (TL;DR)](../recipes/deployment.html#mail-delivery-inline-vs-oban-tl-dr)** so you know when synchronous dev mail is fine and when production should queue or background-send.
3. **Walk the production checklist** — open **[Production checklist (read first)](../recipes/deployment.html#production-checklist-read-first)** before exposing a public HTTPS origin; it is a **pre-flight** list for cookies, TLS, and proxies—not a substitute for your own threat modeling.
4. **Add OAuth when you need it** — social/OIDC flows live in **[OAuth](../flows/oauth.html)**; wire providers only after sessions and mail behavior make sense for your users.
5. **Plan MFA before widening sensitive surfaces** — **[MFA](../flows/mfa.html)** covers TOTP enrollment, backup codes, and trust-this-browser patterns aligned with the v1.10 bundle assumptions.
6. **Defer API/JWT until you have a client** — **[API authentication](../flows/api-authentication.html)** is for programmatic access; session auth can stay the default for a long time.
7. **Treat passkeys as a product decision** — **[Passkeys](../recipes/passkeys.html)** documents RP ID, `origin`, and recovery; rename those values with your real domain before calling passkey-primary “production ready.”

## Assumed generator defaults

The tutorials use the minimal three-argument form:

    mix sigra.install Accounts User users

That command matches the **v1.10 default bundle** in this milestone: **LiveView** auth pages, **`binary_id`**, **organizations**, **admin**, and **passkeys** are all **on** unless you explicitly pass the `--no-*` switches. The human-readable scope table lives in **`.planning/v1.10-ADOPTER-SCOPE.md`** in the Sigra repository; for a stable browser link use [v1.10 adopter scope (source)](https://github.com/sztheory/sigra/blob/main/.planning/v1.10-ADOPTER-SCOPE.md). For exhaustive CLI truth, run **`mix help sigra.install`** or open **`Mix.Tasks.Sigra.Install`** on HexDocs.

## Sensitive flow: MFA (TOTP)

Enroll MFA only after you have an authenticator app ready. Follow **[MFA (TOTP)](../flows/mfa.html)**: generate the secret, scan the QR or paste the `otpauth` URI, and **store backup codes** somewhere durable before you rely on TOTP as a second factor. Backup codes are one-time recovery—losing both your device and the codes is an account-recovery incident, not something Sigra can magically undo.

## Password changes and session invalidation

Changing a password should invalidate other active sessions when you use database-backed tokens. The generated flows call into `Accounts` / `Sigra.Auth` helpers—see **[Change password](../flows/account-lifecycle.html#change-password)** in **[Account lifecycle](../flows/account-lifecycle.html)** for how password updates interact with remember-me cookies and concurrent logins, and **[Password reset](../flows/password-reset.html)** for the email link path that also rotates credentials safely.

> **Anti-patterns:** enrolling MFA without downloading backup codes; assuming production mail is synchronous without reading the deployment mail section; skipping the production checklist because “it works on localhost.”
