# Phase 3: Email Flows and Transactional Email - Research

**Researched:** 2026-04-06
**Domain:** Email delivery, token-based auth flows, async job processing, EEx template generation
**Confidence:** HIGH

## Summary

Phase 3 builds email confirmation, password reset, and transactional email delivery on top of the existing Phase 2 foundation. The codebase already has substantial scaffolding: `Sigra.Auth` handles registration/authentication, `Sigra.Token` provides hashed token generation, `Sigra.Mailer` defines the delivery behaviour, `Sigra.RateLimiter` provides rate limiting, and the generated `UserToken` schema already has `build_email_token/2` and `verify_email_token_query/2` for confirm and reset_password contexts. The generated `auth.ex` context template already contains stub functions for `deliver_user_confirmation_instructions/2`, `confirm_user/1`, `deliver_user_reset_password_instructions/2`, `get_user_by_reset_password_token/1`, and `reset_user_password/2` -- these need to be evolved to integrate with real email delivery.

The work divides into: (1) library-side functions in `Sigra.Auth` for confirmation/reset verification, (2) Oban worker for async delivery with inline fallback, (3) Swoosh-based email module and multipart HTML+text templates generated into the host app, (4) NimbleOptions config extensions, (5) controllers/LiveViews for confirmation and reset flows, and (6) testing helpers. Swoosh 1.25.0, Oban 2.21.1, and Hammer 7.3.0 are already locked in `mix.lock`.

**Primary recommendation:** Extend existing stubs rather than rewriting. The generated `auth.ex` and `user_token.ex` templates already have the token CRUD for confirm/reset -- Phase 3 wires in real email delivery (Swoosh + Oban), adds the 6-digit code path, and builds the UI routes.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Link-first, code as fallback. Email contains a clickable confirmation link (primary) AND a 6-digit code below it. Link auto-confirms; code is for users who can't click (mobile paste issues, corporate email proxies).
- **D-02:** Configurable behavior for unconfirmed users via `:unconfirmed_access` config (`:allow_with_banner` | `:block`). Default: `:allow_with_banner`. Both modes implemented.
- **D-03:** Confirmation token TTL: 48 hours by default, configurable via `:confirmation_ttl`.
- **D-04:** Resend via both explicit button and auto-resend on blocked login attempts. Rate limited: 3 per email per 15 minutes. Auto-resend shows explicit feedback: "Account not yet confirmed. We've sent a new confirmation email."
- **D-05:** 6-digit confirmation code: random numeric, stored as SHA-256 hash in user_tokens with context "confirm_code". Separate token record from link token. Rate-limited code entry: 5 attempts per user per 15 minutes.
- **D-06:** Separate paths for link vs code: link click goes to `/users/confirm/{token}` (auto-confirms). Code entry is a separate form at `/users/confirm` with text input.
- **D-07:** Expired token shows dedicated error page with "Send new confirmation email" button (email pre-filled if possible). Not a dead end.
- **D-08:** Magic link counts as confirmation (already implemented in Phase 2). Confirmation email only needed for password-based registrations. No changes to magic link flow.
- **D-09:** Double-click on confirmation link: first click confirms and deletes token, second click shows friendly "Your email is already confirmed" page with login link.
- **D-10:** Multiple confirmation emails before clicking any: all tokens remain valid until TTL expires. Clicking any one confirms the user. Orphaned tokens cleaned up by cron.
- **D-11:** Email change with re-verification is out of scope (ACCT-01, separate phase). Phase 3 builds the confirmation primitives.
- **D-12:** Clean minimal HTML with inline CSS. No framework deps. Works across all email clients (Gmail, Outlook, Apple Mail). Logo placeholder, consistent header/footer.
- **D-13:** Generated EEx templates in host app. Generator creates email module and templates that developer owns and can modify directly. Same "own your code" pattern as phx.gen.auth.
- **D-14:** Phase 3 generates templates for: confirmation, password reset, and magic link emails. Lockout notification and suspicious login are Phase 4 scope.
- **D-15:** Shared layout function: `base_layout/2` in generated email module wraps content with consistent header (app name) and footer. Each email calls it. DRY.
- **D-16:** Mailer behaviour body evolves from plain map to structured: `%{html: html_string, text: text_string}` for multipart. String body still works (treated as text-only). Backward compatible.
- **D-17:** Config-driven from address: `:from_email` in Sigra config. Default: `"noreply@{app_domain}"` from endpoint config. Generator sets it in config.exs.
- **D-18:** Single email module: `MyApp.Auth.Emails` with `confirmation_email/2`, `reset_password_email/2`, `magic_link_email/2`. Each returns a Swoosh.Email struct.
- **D-19:** Generator configures Swoosh local mailbox adapter for dev email preview. Phoenix 1.8 apps likely already have this -- generator detects and skips if present.
- **D-20:** Descriptive email subjects: "Confirm your email", "Reset your password". These go to the requester's own inbox -- no enumeration concern.
- **D-21:** Single generic email worker: `Sigra.Workers.EmailDelivery` in the library. Takes email type + args. Queue: configurable via `:oban_queue` config (default: `"sigra_mailer"`). Concurrency: configurable (default: 10).
- **D-22:** Worker lives in library, host app configures. Generator injects Oban queue config into host app's Oban setup. Worker code updatable via `mix deps.update`.
- **D-23:** Explicit delivery API: `deliver_async/2` and `deliver_sync/2`. Generated context picks which to call based on config. No unified magic function.
- **D-24:** Inline fallback when Oban absent: Claude's discretion on implementation (synchronous in calling process vs Task.async).
- **D-25:** Retry: max_attempts 3, exponential backoff (~15s, ~60s). If all fail, Oban marks as discarded.
- **D-26:** Delivery mode: auto-detect Oban presence via `Code.ensure_loaded?` with explicit override via `:delivery_mode` config (`:async` | `:sync` | `:auto`). Default: `:auto`.
- **D-27:** Token cleanup: both Oban cron job (`Sigra.Workers.TokenCleanup`, runs daily, deletes tokens older than max TTL) AND opportunistic cleanup on token verification. Belt and suspenders.
- **D-28:** Reset token TTL: 60 minutes by default, configurable via `:reset_token_ttl`.
- **D-29:** After password reset, invalidate all sessions except newly created one. Auto-login after reset -- user lands in the app, not the login page.
- **D-30:** Expired/used reset link shows dedicated error page: "This reset link has expired (or was already used)." with "Request new reset email" button. Same pattern as confirmation expired.
- **D-31:** Password reset is link-only (no code entry option). Link goes to form for new password entry.
- **D-32:** Rate limited: 3 requests per email per 15 minutes (same as magic link and confirmation resend).
- **D-33:** Same password policy for reset as registration (Phase 2 D-22). No password history/reuse prevention.
- **D-34:** Real-time password strength feedback on reset form via phx-change (reuses same component from registration).
- **D-35:** OAuth-only accounts requesting reset: send email suggesting OAuth login ("You signed up with [Provider]. Log in with [Provider] instead, or set a password from your settings."). Enumeration-safe since email is still sent.
- **D-36:** SHA-256 hash for DB storage + HMAC-signed URL via Plug.Crypto.sign with purpose-specific salt. Double protection: token must exist in DB AND signature must be valid.
- **D-37:** 6-digit confirmation codes: SHA-256 hashed, rate-limited entry (5/15min). No HMAC signing -- brute force protection from rate limiting + short TTL.
- **D-38:** Enumeration prevention: always return "If that email exists, we've sent instructions." Dummy hash operation for non-existent emails to match timing. No DB write for non-existent emails.
- **D-39:** No CSRF on link click (GET). CSRF on form submissions (POST for code entry, password reset). Token itself is proof of authorization for GET.
- **D-40:** Token lookups already constant-time: SHA-256 hash comparison in DB query. Plug.Crypto.secure_compare for user-supplied values.
- **D-41:** Single `mix sigra.install` generates everything core, including confirmation, password reset, and email templates. No separate `mix sigra.gen.email`. Separate generators only for truly optional features (OAuth, MFA, API tokens).
- **D-42:** Phase 3 templates added alongside existing ones in `priv/templates/sigra.install/`. Flat structure.
- **D-43:** Controllers primary, LiveView optional (same pattern as Phase 2 D-53). `--live` flag for LiveView pages.
- **D-44:** URL structure follows Phoenix 1.8 conventions: `/users/confirm/{token}`, `/users/confirm`, `/users/reset-password`, `/users/reset-password/{token}`.
- **D-45:** Swoosh test adapter + assertion helpers in `Sigra.Testing`: `assert_email_sent/1`, `extract_confirmation_token/1`, `extract_reset_token/1`.
- **D-46:** Oban.Testing helpers for worker tests: `assert_enqueued worker: Sigra.Workers.EmailDelivery`. When Oban absent, tests use sync path. Both paths covered.
- **D-47:** Consistent per-email rate limits: confirmation resend 3/15min, password reset 3/15min, code entry 5/user/15min. All configurable via NimbleOptions.
- **D-48:** Per-email only in Phase 3. Per-IP rate limiting is Phase 4 scope (SEC-02).
- **D-49:** Confirmation code entry: simple form, auto-submit on 6 digits via phx-change. Error flash on invalid/expired. Resend link below.
- **D-50:** Password reset form: new password + confirm password + strength meter via phx-change. Submit validates match + policy.
- **D-51:** Library (Sigra): token generation/verification, HMAC signing, delivery orchestration (deliver_async/deliver_sync), Oban worker, email telemetry, token cleanup worker. Generated into host: email module with templates, routes, controllers/LiveViews, auth context functions (confirm_user, reset_password).
- **D-52:** Extend Sigra.Auth with: `confirm_user/3`, `request_password_reset/3`, `reset_password/4`, `verify_confirmation_token/3`, `verify_confirmation_code/3`. Generated context: `deliver_confirmation_email/2`, `deliver_reset_password_email/2`. Follows Phase 2 D-43 conventions exactly.
- **D-53:** Nested under existing sections + new email section. `confirmation:` (ttl, code_length, unconfirmed_access), `reset:` (ttl, rate_limit), `email:` (from_address, oban_queue, delivery_mode). Follows Phase 1 D-06 pattern.
- **D-54:** Generated `MyApp.Auth.Mailer` implements `Sigra.Mailer` behaviour. Builds Swoosh.Email struct from body map, calls `MyApp.Mailer.deliver/1`.
- **D-55:** Generator configures Swoosh adapters: dev -> Local, test -> Test, prod -> TODO with common adapter examples. Detects existing config and skips if present.
- **D-56:** Flash messages for controller redirects, inline errors for LiveView forms. Expired token pages use dedicated error template with action button.
- **D-57:** All user-facing strings gettext-ready. Works in English out of the box, translatable via standard Phoenix i18n.
- **D-58:** New spans: `[:sigra, :email, :deliver, :start/:stop/:exception]`, `[:sigra, :confirmation, :verify, :start/:stop]`. New events: `[:sigra, :confirmation, :sent]`, `[:sigra, :reset, :requested]`, `[:sigra, :reset, :completed]`, `[:sigra, :token, :expired]`. Metadata: email_type, delivery_method, user_id (no email addresses).
- **D-59:** New guides: "Email Confirmation", "Password Reset", "Customizing Email Templates". Update: Sigra.Auth @moduledoc, Sigra.Mailer @moduledoc with body map format, Sigra.Telemetry event catalog.
- **D-60:** No new migration needed. Existing user_tokens table (token, context, sent_to, user_id, inserted_at) is sufficient. TTL computed from inserted_at + duration. New token contexts: "confirm", "confirm_code", "reset_password".
- **D-61:** Sudo mode is Phase 4 only. Password reset doesn't need sudo (user proves identity via email token).

### Claude's Discretion
- Email template visual design details (colors, spacing, typography within "clean minimal" constraint)
- Inline fallback implementation choice (synchronous vs Task.async)
- Generated email template format (Elixir module with string interpolation vs EEx files vs Swoosh struct builders)
- Token cleanup cron schedule details
- Exact auto-submit JS behavior for 6-digit code input
- ExDoc guide page structure and content depth

### Deferred Ideas (OUT OF SCOPE)
- Email change with re-verification (ACCT-01) -- separate Account Lifecycle phase
- Lockout notification emails -- Phase 4 (Security Baseline)
- Suspicious login notification emails -- Phase 4 (Security Baseline)
- Per-IP rate limiting -- Phase 4 (SEC-02)
- Sudo/re-auth mode -- Phase 4 (SESS-09)
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CONF-01 | New registrations trigger confirmation email automatically (async via Oban) | Oban worker pattern (D-21), auto-trigger on register (D-08), Swoosh email construction |
| CONF-02 | Confirmation via link click or code entry | Dual-path tokens: link token with HMAC (D-36), code token SHA-256 (D-37), separate routes (D-06) |
| CONF-03 | Configurable behavior for unconfirmed users (allow login with banner vs block login) | NimbleOptions `:unconfirmed_access` config (D-02), existing `require_confirmation` in Config |
| CONF-04 | Resend confirmation with rate limiting | RateLimiter behaviour already exists, 3/15min limit (D-47), auto-resend on blocked login (D-04) |
| CONF-05 | Token expiry with helpful error and resend link (default 48h TTL) | Existing `token_ttl.confirm` in Config (48h), dedicated error page pattern (D-07) |
| CONF-06 | Tokens are single-use, HMAC-protected, hashed before storage | Existing Token.generate_hashed_token + Plug.Crypto.sign (D-36), UserToken.build_email_token (D-60) |
| RESET-01 | User can request password reset via email | Existing `deliver_user_reset_password_instructions` stub, extend with real delivery |
| RESET-02 | Email enumeration prevention (generic message regardless of email existence) | Existing pattern in Auth.authenticate, dummy hash (D-38), safe_message in Error module |
| RESET-03 | HMAC-protected, time-limited, single-use reset tokens (default 60min TTL) | Existing `token_ttl.reset_password` (1h), Plug.Crypto.sign with purpose salt (D-36) |
| RESET-04 | Password change invalidates all existing sessions except current | Existing `reset_user_password` in auth.ex uses Multi to delete_all tokens (D-29) |
| RESET-05 | Expired/used token shows helpful error with link to request new one | Dedicated error page pattern (D-30), same UX as confirmation expired (D-07) |
| EMAIL-01 | Confirmation, password reset, lockout notification, suspicious login emails | Phase 3 covers confirmation + reset + magic link. Lockout/suspicious = Phase 4 (D-14) |
| EMAIL-02 | Integration with Swoosh (or pluggable mailer behaviour) | Swoosh 1.25.0 locked, Sigra.Mailer behaviour exists, generated mailer wrapper (D-54) |
| EMAIL-03 | HTML + text multipart emails | Swoosh.Email html_body/text_body, evolved body type %{html:, text:} (D-16) |
| EMAIL-04 | Easy email template customization (generated templates user can modify) | Generated EEx in priv/templates/, "own your code" pattern (D-13), MyApp.Auth.Emails (D-18) |
| EMAIL-05 | Async delivery via Oban with inline fallback | Oban 2.21.1 locked, EmailDelivery worker (D-21), Code.ensure_loaded? detection (D-26) |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

- **Framework:** Phoenix 1.8+ / Ecto 3.x as blessed path
- **Security:** OWASP standards. All tokens HMAC-protected. Enumeration prevention by default.
- **Dependencies:** Minimal transitive deps. Copy-paste over deps when code is small and stable.
- **Testing:** Comprehensive spec coverage -- happy path, main error cases, boundary conditions. AAA style, flat, self-contained.
- **Architecture:** Security-critical code in library; customizable code generated into host app. Behaviours + callbacks, no macros.
- **Swoosh:** Optional dep (`{:swoosh, "~> 1.5", optional: true}`). Generated mailer wraps host app's Swoosh.
- **Oban:** Optional dep (`{:oban, "~> 2.17", optional: true}`). Make Oban integration optional -- email sends inline if absent.
- **Hammer:** Optional dep. If not included, Sigra falls back to Noop rate limiter with logged warning.

## Standard Stack

### Core (already in mix.exs)
| Library | Version | Purpose | Status |
|---------|---------|---------|--------|
| swoosh | 1.25.0 | Email composition and delivery | Locked, optional dep |
| oban | 2.21.1 | Async job processing for email delivery + token cleanup | Locked, optional dep |
| hammer | 7.3.0 | Rate limiting (confirmation resend, reset requests, code entry) | Locked, optional dep |
| plug_crypto | (transitive via phoenix) | HMAC signing for email tokens via `Plug.Crypto.sign/4` | Available |
| phoenix | 1.8.5 | Controllers, LiveView, routing, gettext | Locked |
| ecto | 3.13.5 | Schema, Multi, queries | Locked |
| nimble_options | 1.1.1 | Config validation | Locked |
| mox | 1.1.x | Test mocks for mailer, rate limiter | Locked (test only) |

No new dependencies needed. All libraries are already in mix.exs.

## Architecture Patterns

### Library vs Generated Code Boundary

```
lib/sigra/ (LIBRARY - updated via mix deps.update)
  auth.ex              -- Add: confirm_user/3, request_password_reset/3,
                          reset_password/4, verify_confirmation_token/3,
                          verify_confirmation_code/3
  config.ex            -- Add: confirmation:, reset:, email: NimbleOptions sections
  delivery.ex          -- NEW: deliver_async/2, deliver_sync/2, delivery mode detection
  mailer.ex            -- Evolve: body type to accept %{html:, text:}
  workers/
    email_delivery.ex  -- NEW: Oban worker for async email
    token_cleanup.ex   -- NEW: Oban cron worker for expired token cleanup
  telemetry.ex         -- Add: email/confirmation/reset event catalog
  testing.ex           -- Add: assert_email_sent/1, extract_*_token/1
  error.ex             -- Add: :already_confirmed, :unconfirmed safe messages

priv/templates/sigra.install/ (GENERATED - owned by developer)
  emails.ex            -- NEW: MyApp.Auth.Emails with base_layout/2,
                          confirmation_email/2, reset_password_email/2,
                          magic_link_email/2
  auth_mailer.ex       -- NEW: MyApp.Auth.Mailer implementing Sigra.Mailer
  confirmation_controller.ex      -- NEW (or confirmation_live.ex with --live)
  confirmation_html.ex            -- NEW
  reset_password_controller.ex    -- NEW (or reset_password_live.ex with --live)
  reset_password_html.ex          -- NEW
  auth.ex              -- EXTEND: wire in deliver_confirmation_email,
                          deliver_reset_password_email, confirm_user
  user_auth.ex         -- EXTEND: unconfirmed_access plug behavior
```

### Token Architecture (D-36, D-37)

Two token strategies for confirmation, one for reset:

```
Confirmation Link Token:
  1. Generate: {raw, hashed} = Token.generate_hashed_token()
  2. HMAC sign: signed_url = Plug.Crypto.sign(secret, "sigra-confirm-token", raw)
  3. Store: INSERT user_tokens (token: hashed, context: "confirm", sent_to: email)
  4. Email URL: /users/confirm/{signed_url}
  5. Verify: Plug.Crypto.verify(secret, "sigra-confirm-token", signed_url)
             -> decode raw -> SHA-256 -> lookup in DB

Confirmation Code:
  1. Generate: code = Enum.random(100_000..999_999) |> to_string()
  2. Store: INSERT user_tokens (token: SHA-256(code), context: "confirm_code", sent_to: email)
  3. Email body: includes "Your confirmation code: 123456"
  4. Verify: SHA-256(submitted_code) -> lookup in DB
  5. Rate limit: 5 attempts per user per 15 min

Password Reset Token:
  1. Same as confirmation link (HMAC + hash) with context "reset_password"
  2. 60-minute TTL (vs 48h for confirmation)
  3. Single-use: deleted on successful reset
  4. Reset invalidates all sessions via Ecto.Multi delete_all
```

### Oban Worker Pattern (D-21, D-22, D-25)

```elixir
# lib/sigra/workers/email_delivery.ex
defmodule Sigra.Workers.EmailDelivery do
  use Oban.Worker,
    queue: :sigra_mailer,  # configurable
    max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"email_type" => type, "user_id" => user_id} = args}) do
    # Reconstruct email from type + args
    # Call mailer.deliver/3
    # Return :ok | {:error, reason}
  end

  @impl Oban.Worker
  def backoff(%Oban.Job{attempt: attempt}) do
    # ~15s, ~60s (exponential with jitter per D-25)
    trunc(:math.pow(attempt, 4) + 15 + :rand.uniform(10) * attempt)
  end
end
```

### Delivery Orchestration (D-23, D-24, D-26)

```elixir
# lib/sigra/delivery.ex
defmodule Sigra.Delivery do
  @doc "Delivers email asynchronously via Oban."
  def deliver_async(email_type, args, opts) do
    # Builds Oban job changeset
    # Inserts via Oban.insert/1
  end

  @doc "Delivers email synchronously in calling process."
  def deliver_sync(mailer, to, subject, body) do
    mailer.deliver(to, subject, body)
  end

  @doc "Auto-detect: Oban loaded? -> async, else -> sync"
  def deliver(email_type, args, opts) do
    case delivery_mode(opts) do
      :async -> deliver_async(email_type, args, opts)
      :sync  -> deliver_sync(...)
    end
  end

  defp delivery_mode(opts) do
    case Keyword.get(opts, :delivery_mode, :auto) do
      :auto -> if Code.ensure_loaded?(Oban), do: :async, else: :sync
      mode  -> mode
    end
  end
end
```

### Inline Fallback Recommendation (Claude's Discretion)

Use synchronous delivery in the calling process (not `Task.async`). Rationale:
- `Task.async` without supervision loses error visibility
- `Task.Supervisor` adds complexity for a fallback path
- Synchronous delivery is the simplest correct option
- If Oban is absent, the developer has already accepted no async -- sync in-process is expected
- Swoosh delivery is typically fast (<1s for API adapters)

### Generated Email Module Pattern (D-18, D-15)

```elixir
# priv/templates/sigra.install/emails.ex -> MyApp.Auth.Emails
defmodule <%= context_module %>.Emails do
  import Swoosh.Email

  @from_address {"<%= app_name %>", "<%= from_email %>"}

  def confirmation_email(user, url, code) do
    base_email(user.email)
    |> subject("Confirm your email")
    |> html_body(confirmation_html(user, url, code))
    |> text_body(confirmation_text(user, url, code))
  end

  def reset_password_email(user, url) do
    base_email(user.email)
    |> subject("Reset your password")
    |> html_body(reset_password_html(user, url))
    |> text_body(reset_password_text(user, url))
  end

  def magic_link_email(user, url) do
    base_email(user.email)
    |> subject("Log in to <%= app_name %>")
    |> html_body(magic_link_html(user, url))
    |> text_body(magic_link_text(user, url))
  end

  # Shared layout wrapper (D-15)
  defp base_email(to) do
    new()
    |> to(to)
    |> from(@from_address)
  end

  defp base_layout(content_html) do
    # Minimal HTML with inline CSS, logo placeholder, header/footer
  end
end
```

### Generated Email Template Format (Claude's Discretion)

Use Elixir module with string interpolation (not separate EEx files). Rationale:
- Simpler for developers to find and edit (single file, no separate template lookup)
- Phoenix 1.8 phx.gen.auth uses the same pattern (notifier functions return strings)
- HTML email templates are typically static enough that EEx file separation adds overhead
- Each email function builds its own HTML/text content inline
- `base_layout/1` wraps content HTML in the shared layout structure

### Token Cleanup Cron (D-27, Claude's Discretion)

```elixir
# lib/sigra/workers/token_cleanup.ex
defmodule Sigra.Workers.TokenCleanup do
  use Oban.Worker, queue: :sigra_maintenance, max_attempts: 1

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    # Delete tokens where inserted_at < now - max_ttl
    # max_ttl = max(confirm_ttl, reset_ttl, magic_link_ttl) + buffer
    # Runs daily at 3:00 AM UTC (configured in host Oban crontab)
  end
end
```

Recommended cron schedule: daily at 03:00 UTC. Generator injects into host Oban config:
```elixir
crontab: [
  {"0 3 * * *", Sigra.Workers.TokenCleanup}
]
```

### Unconfirmed Access Modes (D-02)

```elixir
# In Sigra.Config confirmation: section
unconfirmed_access: [
  type: {:in, [:allow_with_banner, :block]},
  default: :allow_with_banner,
  doc: "How to handle unconfirmed users. :allow_with_banner lets them in with a flash, :block prevents login."
]
```

Implementation in generated `user_auth.ex` plug pipeline:
- `:allow_with_banner` -- user is logged in, flash message set: "Please confirm your email. [Resend]"
- `:block` -- login returns `{:error, :unconfirmed}`, user redirected to confirmation page

### HMAC Token URL Signing (D-36)

The existing `Sigra.Token` already has `generate/4` (wraps `Plug.Crypto.sign`) and `verify/4` (wraps `Plug.Crypto.verify`). For email tokens, the flow is:

```elixir
# Generate
{raw, hashed} = Token.generate_hashed_token()
# Store hashed in DB
signed = Token.generate(secret_key_base, "sigra-confirm-token", raw)
url = "/users/confirm/#{signed}"

# Verify
{:ok, raw} = Token.verify(secret_key_base, "sigra-confirm-token", signed, max_age: 172_800)
hashed = Token.hash_token(raw)
# Lookup hashed in DB -> find user
```

This adds HMAC protection on top of SHA-256 hashing -- tokens are useless without the server secret AND must exist in the DB.

### Anti-Patterns to Avoid

- **Storing raw tokens in DB:** Always store SHA-256 hash. Raw goes to user only.
- **Timing-based email enumeration:** Always perform a dummy hash operation when email not found (D-38). The existing `Sigra.Crypto` module already has this pattern.
- **DB write for non-existent emails:** Do NOT insert a token record when the email doesn't exist in the system. Return generic success, perform dummy hash for timing.
- **JWT for email tokens:** Use opaque hashed tokens, not JWTs. JWTs are stateless and cannot be revoked per-token.
- **Single token for both link and code:** Use separate token records (D-05). Link token is HMAC-signed; code is not. Different contexts ("confirm" vs "confirm_code") prevent confusion.
- **Blocking on email delivery in request cycle:** Use Oban for async. Even with inline fallback, never let email delivery failure block the HTTP response for enumeration-safe endpoints (return success regardless).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Email composition | Raw string building | `Swoosh.Email` struct builder | Handles multipart, headers, encoding, attachments |
| Async delivery | `Task.async` / GenServer | `Oban` worker with retry | Database-backed, survives restarts, exponential backoff |
| Rate limiting | Counter in ETS/Agent | `Hammer` via `Sigra.RateLimiter` | Atomic, window-based, already integrated |
| Token HMAC | Manual `:crypto.mac` | `Plug.Crypto.sign/verify` | Constant-time, handles key derivation, rotation-safe |
| Email HTML layout | Complex template engine | Inline CSS string functions | Email clients strip `<style>` tags; inline CSS is the only reliable approach |
| Password hashing timing | Manual `:timer.sleep` | `Sigra.Crypto.dummy_hash/0` | Already exists in Phase 2, matches real hash timing |

## Common Pitfalls

### Pitfall 1: Double Token Encoding
**What goes wrong:** The `build_email_token/2` in the existing `user_token.ex` template already Base64-encodes the raw token (line: `Base.url_encode64(raw_token, padding: false)`), and then `verify_email_token_query` decodes it. If the HMAC signing layer also Base64-encodes, you get double-encoding.
**Why it happens:** `Token.generate_hashed_token()` returns `{base64_raw, hashed}`. The template then re-encodes the already-encoded string.
**How to avoid:** The HMAC signing should take the raw bytes (before Base64), not the Base64 string. Or use the existing `build_email_token` pattern which handles encoding consistently. Review the existing `UserToken.build_email_token` carefully -- it already does `{raw_token, hashed_token} = Sigra.Token.generate_hashed_token()` then `Base.url_encode64(raw_token, padding: false)`, meaning `raw_token` is ALREADY Base64. The HMAC layer wraps the Base64 string, which is fine as long as `verify_email_token_query` handles the unwrapping consistently.
**Warning signs:** Token verification always returns `:invalid` despite correct token in URL.

### Pitfall 2: Oban Worker Serialization
**What goes wrong:** Oban args must be JSON-serializable (strings, numbers, booleans, lists, maps). Passing Swoosh.Email structs, atoms, or PIDs as args causes silent failures.
**Why it happens:** Oban stores args as JSONB in PostgreSQL.
**How to avoid:** Pass only primitive data to worker args: `%{"email_type" => "confirmation", "user_id" => user_id, "url" => url}`. The worker reconstructs the email from these primitives by calling the generated email module.
**Warning signs:** Jobs fail immediately with encoding errors.

### Pitfall 3: Race Condition on Confirmation + Login
**What goes wrong:** User clicks confirm link while simultaneously trying to log in with `:block` mode. The login check finds `confirmed_at: nil`, but by the time it returns the error, the confirmation has completed.
**Why it happens:** Non-atomic read-then-act on `confirmed_at`.
**How to avoid:** Accept this as benign -- the user simply retries login and it works. The confirmation is the authoritative operation. Don't add complex locking.
**Warning signs:** User reports "account not confirmed" after clicking confirmation link.

### Pitfall 4: Enumeration via Timing on Confirmation Resend
**What goes wrong:** Resend endpoint for existing users does DB lookup + token insert + email enqueue. For non-existing users, it returns immediately. Timing difference reveals email existence.
**Why it happens:** Async operations (Oban insert) have different timing from no-ops.
**How to avoid:** For non-existing emails, perform dummy hash (already in `Sigra.Crypto`) and return same response. The Oban insert is fast enough that timing differences are negligible, but the dummy hash matches the hash computation timing.
**Warning signs:** Penetration tester flags timing differences on resend endpoint.

### Pitfall 5: Stale Config in Oban Worker
**What goes wrong:** Worker reads config at job execution time, but config may have changed since job was enqueued.
**Why it happens:** Oban jobs are persistent -- they survive app restarts and config changes.
**How to avoid:** Store essential config values (mailer module, from_email) as job args, not fetched at runtime. The worker should be self-contained with all data needed to deliver.
**Warning signs:** Emails sent with wrong from address after config change.

### Pitfall 6: Missing Oban Queue Declaration
**What goes wrong:** Jobs are enqueued to `sigra_mailer` queue but the queue is not declared in host app's Oban config. Jobs sit in DB forever, never executed.
**Why it happens:** Generator must inject queue config into host app's `config.exs`.
**How to avoid:** Generator must add `queues: [sigra_mailer: 10]` to Oban config. Also add a runtime check in `deliver_async` that logs a warning if the queue appears misconfigured. Include in install instructions.
**Warning signs:** Emails never arrive; `oban_jobs` table fills up with `available` state jobs.

## Code Examples

### Swoosh Email Construction (verified from Swoosh 1.25.0 docs)

```elixir
import Swoosh.Email

new()
|> to({"User Name", "user@example.com"})
|> from({"MyApp", "noreply@myapp.com"})
|> subject("Confirm your email")
|> html_body("<h1>Welcome</h1><p>Click <a href=\"#{url}\">here</a> to confirm.</p>")
|> text_body("Welcome!\n\nVisit this link to confirm: #{url}")
```

Source: https://hexdocs.pm/swoosh/Swoosh.Email.html

### Oban Worker Definition (verified from Oban 2.21.1 docs)

```elixir
defmodule Sigra.Workers.EmailDelivery do
  use Oban.Worker,
    queue: :sigra_mailer,
    max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"email_type" => type} = args}) do
    # args always have string keys (Oban serializes to JSON)
    case deliver_email(type, args) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @impl Oban.Worker
  def backoff(%Oban.Job{attempt: attempt}) do
    # ~15s for attempt 2, ~60s for attempt 3
    trunc(:math.pow(attempt, 4) + 15 + :rand.uniform(10) * attempt)
  end
end
```

Source: https://hexdocs.pm/oban/Oban.Worker.html

### Oban Job Insertion

```elixir
%{"email_type" => "confirmation", "user_id" => user.id, "url" => url, "code" => code}
|> Sigra.Workers.EmailDelivery.new()
|> Oban.insert()
```

### Oban Testing (verified from Oban 2.21.1 docs)

```elixir
# In test config:
config :my_app, Oban, testing: :manual

# In test:
use Oban.Testing, repo: MyApp.Repo

assert_enqueued worker: Sigra.Workers.EmailDelivery,
  args: %{"email_type" => "confirmation", "user_id" => user.id}
```

Source: https://hexdocs.pm/oban/Oban.Testing.html

### Swoosh Test Assertions (verified from Swoosh docs)

```elixir
# In test config:
config :my_app, MyApp.Mailer, adapter: Swoosh.Adapters.Test

# In test:
import Swoosh.TestAssertions

assert_email_sent(fn email ->
  assert email.to == [{"", user.email}]
  assert email.subject == "Confirm your email"
end)
```

Source: https://hexdocs.pm/swoosh/Swoosh.html

### Plug.Crypto Token Signing (already in codebase)

```elixir
# Sign (wraps raw token for URL)
signed = Plug.Crypto.sign(secret_key_base, "sigra-confirm-token", raw_token)

# Verify (unwraps and validates)
case Plug.Crypto.verify(secret_key_base, "sigra-confirm-token", signed, max_age: 172_800) do
  {:ok, raw_token} -> # valid, proceed to DB lookup
  {:error, :expired} -> {:error, :expired}
  {:error, _} -> {:error, :invalid}
end
```

### 6-Digit Code Generation

```elixir
# Generate random 6-digit code
code = :rand.uniform(900_000) + 99_999  # 100000-999999
code_string = Integer.to_string(code)

# Hash for storage
hashed_code = :crypto.hash(:sha256, code_string)

# Store in user_tokens with context "confirm_code"
%{
  token: hashed_code,
  context: "confirm_code",
  sent_to: user.email,
  user_id: user.id
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Phoenix 1.7 `UserNotifier` with `deliver/3` logging to terminal | Phoenix 1.8 `UserNotifier` with Swoosh delivery + magic links | Phoenix 1.8 (Aug 2025) | Swoosh is now the default mailer in generated Phoenix apps |
| Oban 2.17 `perform/1` with `%{args: args}` | Oban 2.21 same API, stable | Mar 2026 | No breaking changes since 2.17 |
| `Ecto.Multi` for transactional operations | `Repo.transact/2` in Ecto 3.13 | Ecto 3.13 (2025) | Cleaner API, replaces deprecated `Repo.transaction/2` |
| Hammer 6.x API | Hammer 7.x complete rewrite | Hammer 7.0 (2025) | New API, built-in ETS backend, breaking changes from 6.x |

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (built-in) + Mox 1.1.x |
| Config file | `test/test_helper.exs` |
| Quick run command | `mix test --only phase3` |
| Full suite command | `mix test` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CONF-01 | Registration triggers confirmation email | integration | `mix test test/sigra/auth_test.exs::confirm_on_register -x` | Needs extension |
| CONF-02 | Confirm via link or code | unit | `mix test test/sigra/confirmation_test.exs -x` | Wave 0 |
| CONF-03 | Unconfirmed access modes | unit | `mix test test/sigra/auth_test.exs::unconfirmed_access -x` | Needs extension |
| CONF-04 | Resend with rate limiting | unit | `mix test test/sigra/confirmation_test.exs::resend -x` | Wave 0 |
| CONF-05 | Token expiry + helpful error | unit | `mix test test/sigra/confirmation_test.exs::expired -x` | Wave 0 |
| CONF-06 | Single-use HMAC tokens | unit | `mix test test/sigra/token_test.exs::hmac -x` | Needs extension |
| RESET-01 | Request reset via email | integration | `mix test test/sigra/reset_password_test.exs -x` | Wave 0 |
| RESET-02 | Enumeration prevention | unit | `mix test test/sigra/reset_password_test.exs::enumeration -x` | Wave 0 |
| RESET-03 | HMAC token with TTL | unit | `mix test test/sigra/reset_password_test.exs::token -x` | Wave 0 |
| RESET-04 | Session invalidation on reset | integration | `mix test test/sigra/reset_password_test.exs::sessions -x` | Wave 0 |
| RESET-05 | Expired token UX | unit | `mix test test/sigra/reset_password_test.exs::expired -x` | Wave 0 |
| EMAIL-01 | Email types generated | unit | `mix test test/sigra/emails_test.exs -x` | Wave 0 |
| EMAIL-02 | Swoosh integration | unit | `mix test test/sigra/delivery_test.exs -x` | Wave 0 |
| EMAIL-03 | HTML + text multipart | unit | `mix test test/sigra/emails_test.exs::multipart -x` | Wave 0 |
| EMAIL-04 | Template customization | generator test | `mix test test/mix/sigra_install_test.exs -x` | Needs extension |
| EMAIL-05 | Oban async + inline fallback | unit | `mix test test/sigra/delivery_test.exs -x` | Wave 0 |

### Sampling Rate
- **Per task commit:** `mix test --only phase3`
- **Per wave merge:** `mix test`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `test/sigra/confirmation_test.exs` -- covers CONF-02, CONF-04, CONF-05
- [ ] `test/sigra/reset_password_test.exs` -- covers RESET-01 through RESET-05
- [ ] `test/sigra/delivery_test.exs` -- covers EMAIL-02, EMAIL-05
- [ ] `test/sigra/emails_test.exs` -- covers EMAIL-01, EMAIL-03
- [ ] `test/sigra/workers/email_delivery_test.exs` -- Oban worker tests
- [ ] `test/sigra/workers/token_cleanup_test.exs` -- cron job tests
- [ ] Mox mock for `Sigra.Mailer` in `test/test_helper.exs` (add `Mox.defmock(Sigra.MockMailer, for: Sigra.Mailer)`)

## Open Questions

1. **HMAC wrapping of existing token flow**
   - What we know: `UserToken.build_email_token/2` generates `{base64_raw, token_struct}`. The base64_raw is what goes in the URL today.
   - What's unclear: Should the HMAC signing wrap the base64_raw string, or should we restructure to sign the raw bytes? The existing `verify_email_token_query` expects a base64-encoded string.
   - Recommendation: Sign the base64_raw string with `Plug.Crypto.sign`. On verify, `Plug.Crypto.verify` returns the base64_raw, which feeds directly into `verify_email_token_query`. This avoids changing the existing token verification chain.

2. **Oban worker reconstruction of email**
   - What we know: Worker args must be JSON-serializable. The worker needs to call the host app's generated email module.
   - What's unclear: How does the library worker reference the host app's email module at runtime?
   - Recommendation: Pass the email module as a config option (`:email_module` in Sigra.Config). Worker reads it from config. Alternative: pass the fully qualified module name as a string arg and `String.to_existing_atom/1` it.

3. **Auto-submit JS for 6-digit code (Claude's Discretion)**
   - What we know: D-49 says auto-submit on 6 digits via phx-change.
   - What's unclear: Exact JS hook implementation.
   - Recommendation: Use `phx-change` on the input field. In the LiveView `handle_event`, check if `String.length(code) == 6` and if so, trigger verification. No custom JS hook needed -- LiveView's `phx-change` fires on every keystroke. For controllers, use a JS hook that submits the form when input length reaches 6.

## Sources

### Primary (HIGH confidence)
- Swoosh 1.25.0 hexdocs -- Email struct builder API, test assertions, adapter config
- Oban 2.21.1 hexdocs -- Worker definition, perform/1, args serialization, testing helpers
- Existing codebase -- `lib/sigra/auth.ex`, `lib/sigra/token.ex`, `lib/sigra/mailer.ex`, `lib/sigra/config.ex`, `priv/templates/sigra.install/auth.ex`, `priv/templates/sigra.install/user_token.ex`
- Phoenix 1.8.5 phx.gen.auth templates -- notifier.ex, context_functions.ex patterns

### Secondary (MEDIUM confidence)
- Phoenix 1.8 blog post -- https://www.phoenixframework.org/blog/phoenix-1-8-released
- Oban testing docs -- https://hexdocs.pm/oban/Oban.Testing.html
- Swoosh test assertions -- https://hexdocs.pm/swoosh/Swoosh.html

### Tertiary (LOW confidence)
- None -- all findings verified against official docs or existing codebase

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- all deps already locked in mix.exs, versions verified
- Architecture: HIGH -- existing codebase patterns well-understood, extending not rewriting
- Pitfalls: HIGH -- patterns verified against Oban/Swoosh docs and existing code structure
- Token security: HIGH -- HMAC + SHA-256 pattern matches OWASP and existing Plug.Crypto usage

**Research date:** 2026-04-06
**Valid until:** 2026-05-06 (stable libraries, no expected breaking changes)
