# Terminology

Auth carries a lot of jargon. This page is a scannable decoder for the terms you'll see across Sigra's docs, library code, and generated host code. Each entry is a one-liner — links point to the guide section that goes deeper.

> If you skim only one section, skim **Crypto & hashing** and **Authentication patterns**. Everything else builds on those.

---

## Crypto & hashing

- **Argon2id** — The default password-hashing algorithm. Memory-hard (resistant to GPU/ASIC attacks), winner of the 2015 Password Hashing Competition. Sigra hashes every new password with Argon2id; bcrypt hashes are accepted on login and transparently re-hashed.
- **bcrypt** — The previous-generation password hash. Still secure but not memory-hard. Sigra accepts existing bcrypt hashes for login (verify-and-upgrade), but never creates new ones.
- **HMAC** — Hash-based Message Authentication Code. A way to sign a string with a secret key so the recipient can verify the string wasn't tampered with. Used everywhere in Sigra: token signing, OAuth state, webhook signatures, session integrity.
- **secure_compare** — A comparison function that takes constant time regardless of where two strings differ. Prevents timing-side-channel leaks (e.g. learning a token byte-by-byte from response timings).
- **salt** — A random string mixed into a password hash so two users with the same password get different hashes. Argon2id and bcrypt both salt automatically.

## Authentication patterns

- **Session** — A server-side record proving a user is signed in. Sigra stores sessions in Postgres (not JWTs) so you can list them, revoke them, and tag them with device/IP metadata.
- **Magic link** — A passwordless sign-in: the user enters their email, gets a signed one-time URL, clicks it, and lands signed in. Confirms the email address as a side-effect.
- **Remember-me** — A long-lived cookie token that re-authenticates a user after their session cookie expires. The user opted into "trust this browser" — explicit, not silent.
- **Sudo / step-up auth** — Re-authentication required for sensitive actions (e.g. changing email, deleting account). Even an authenticated session has to prove freshness.
- **Lockout** — Temporarily blocking a user after N failed login attempts. Configurable threshold + duration.
- **Suspicious login** — Pattern-based detection of unusual sign-ins (new geography, new device, multiple rapid failures). Sigra emits an event; the host decides whether to email, block, or step up.

## MFA & TOTP

- **MFA** — Multi-factor authentication. The second factor (after password) is something you have (TOTP app) or are (passkey/biometric).
- **TOTP** — Time-based One-Time Password. The 6-digit codes apps like Google Authenticator generate every 30 seconds. RFC 6238.
- **NimbleTOTP** — The Dashbit-maintained Elixir library that implements RFC 6238. Sigra wraps it; you don't call it directly.
- **Backup codes** — Single-use codes generated at MFA enrollment so a user can sign in if they lose their authenticator app. Sigra stores hashed (not plaintext) and consumes atomically.
- **Drift window** — TOTP allows a small time difference (typically ±1 step = ±30s) between client and server clocks. Outside the window, the code is rejected.
- **Replay prevention** — Sigra tracks the last successfully-used TOTP step number per user. Even if the same code arrives twice within the drift window, the second submission is rejected.
- **Trust-this-device** — A browser cookie that lets a user skip MFA on a known device. Time-bounded, audited, revocable.

## Passkeys & WebAuthn

- **Passkey** — A public/private keypair stored on a user's device (phone, security key, browser keychain) that signs auth challenges. Replaces or augments passwords.
- **WebAuthn** — The W3C standard that defines how browsers, devices, and servers cooperate to register and authenticate passkeys.
- **RP / Relying Party** — In WebAuthn jargon, the *Relying Party* is your app — the system relying on the passkey to authenticate the user.
- **RP ID** — Your app's domain (e.g. `myapp.com`). Passkeys are scoped to an RP ID; a passkey for `myapp.com` won't work on `evil.com`.
- **Attestation** — Optional proof from the authenticator about *what kind* of device made the passkey (e.g. "this is a real YubiKey"). Most apps use `attestation: :none`.
- **Ceremony** — A multi-step exchange between browser and server to register or authenticate a passkey. Sigra handles both ceremonies via the `wax_` library.
- **Passkey-primary mode** — Passkey is the *only* sign-in method; password is optional or absent.
- **Passkey-as-MFA mode** — Password signs you in; passkey is the second factor.

## OAuth

- **OAuth** — A protocol that lets a user sign in to your app using their account at another service (Google, GitHub, Apple). Sigra wraps Assent for the heavy lifting.
- **Provider** — The other service (Google, GitHub, etc.). The user has an identity there; OAuth proves they own it.
- **Identity** — A row in your DB linking a Sigra user to a provider account. One Sigra user can have multiple identities.
- **PKCE** — Proof Key for Code Exchange. A security extension that prevents authorization code interception attacks. Sigra-via-Assent uses PKCE on every OAuth flow.
- **State parameter** — A signed value sent to the OAuth provider and echoed back. Sigra HMAC-signs the state with a 15-minute TTL so a forged callback can't impersonate a real flow.
- **Token refresh** — Long-lived OAuth access requires refreshing tokens before they expire. Sigra dispatches refresh per-provider (Google, GitHub, Apple, Facebook, Generic).

## API auth

- **Bearer token** — A token sent in the `Authorization: Bearer <token>` header. Authenticates an API request without a session cookie.
- **PAT** — Personal Access Token. A user-issued bearer token with a `sigra_sk_*` prefix, scopes, expiry, and usage tracking. Shown once at creation; stored as a hash.
- **JWT** — JSON Web Token. A self-contained signed token (HS256/RS256/ES256) carrying claims. Sigra issues JWTs on the API path when `--jwt` is enabled.
- **Scope** — A capability tag on a token (`read:users`, `write:billing`). The token's scopes constrain what the API call can do.
- **Family-based refresh** — JWT refresh tokens are issued in a *family*: rotating one refresh token issues a new pair and invalidates the old. If an old refresh token is reused, the entire family is revoked (compromise detection).
- **M2M** — Machine-to-machine. Authentication where both parties are programs (no human in the loop). Sigra supports M2M via service-account credentials.
- **Service account** — A non-human account that authenticates via `client_credentials` grant, identified with `actor_type: :service_account`.
- **client_credentials grant** — An OAuth grant type for M2M: the client exchanges its credentials directly for an access token, with no user authorization step.

## Authentication vs Authorization

- **Authentication (Authn)** — *Who are you?* Sigra owns this.
- **Authorization (Authz)** — *What are you allowed to do?* Sigra ships seams (`Sigra.Authz` behaviour, role-on-membership) but the policy lives in your app.
- **RBAC** — Role-Based Access Control. Users have roles; roles have permissions. The classic model.
- **Role-on-membership** — RBAC scoped to organization membership rather than to a global user. A user can be `admin` in Org A and `member` in Org B.

## Multi-tenancy & organizations

- **Organization** — A tenant in your app — the parent of users, invitations, settings, and (via your code) billing/data.
- **Membership** — The link between a user and an organization. Carries the role.
- **Invitation** — A token-based invite to join an org. Public-acceptance route; auto-create or join.
- **Active organization** — The currently-selected org for the signed-in user. Sigra threads this through `current_scope`.
- **Tenant-aware audit** — Audit events that record which org they happened in, so the admin explorer can scope per-tenant.

## Audit & operations

- **Audit event** — A structured row recording who did what, to whom, with what metadata. Written to a host-owned table.
- **Co-fated writes** — Domain mutation (e.g. password change) and audit insert happen inside one `Ecto.Multi`. If audit insert fails, the password change rolls back. Both succeed or both don't. **This is one of Sigra's distinctive correctness properties.**
- **Structured log** — A log entry as a JSON-shaped record (action, actor, resource, metadata) rather than a freeform string.
- **Retention** — How long audit rows live before being purged. Configurable.
- **Telemetry** — Elixir's standard way to emit events for observability. Sigra emits telemetry for every significant flow.

## Webhooks

- **Outbound webhook** — Sigra notifying *your* webhook subscribers about events (account created, password changed, etc.). Sigra is the producer.
- **Signed envelope** — The webhook payload includes an HMAC signature so subscribers can verify it came from your app. Sigra signs every delivery.
- **Durable retries** — Failed deliveries are persisted to the DB and retried with exponential backoff. Not in-memory — survives a restart.
- **DLQ / dead-letter queue** — After max retries, the delivery is marked `dead_lettered` and stops retrying. Operators inspect and manually replay.
- **Egress policy** — A policy that denies HTTP calls to private/loopback IPs (e.g. `127.0.0.1`, `10.0.0.0/8`). Prevents SSRF where a webhook URL points at internal infrastructure.
- **Secret rotation with overlap window** — When a webhook secret rotates, signatures from the *previous* secret continue verifying for a configurable overlap period. Prevents downtime during the rotation roll.
- **Replay recovery** — Re-sending a previously-failed delivery, generating a new lineage row to keep audit trails coherent.

## Generators & adopter terms

- **Lib + generator hybrid** — Sigra's architecture: dangerous code in the hex package, schemas/LiveViews/contexts generated into your repo. `mix deps.update` patches the first; you own the second.
- **Generated code** — Phoenix-shaped Elixir Sigra writes into your project at install time. You commit it, edit it, and customize it like any other code.
- **Override seam** — A specific point in generated code where the host is meant to customize (an email template body, a `current_scope` enrichment hook, etc.).
- **Optional dependency** — A library Sigra uses *if you include it*. Hammer (rate limiting), Oban (background jobs), bcrypt (legacy hash verify), eqrcode (QR codes) — all optional. `mix sigra.doctor` shows what's reachable.

---

## See also

- [`guides/introduction/getting-started.md`](getting-started.html) — first-hour walkthrough
- [`guides/flows/`](.) — deep dives on each auth flow (login, OAuth, MFA, etc.)
- [`guides/recipes/`](.) — task-shaped solutions (deployment, multi-tenant, RBAC, M2M, …)
