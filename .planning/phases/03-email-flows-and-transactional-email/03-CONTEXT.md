# Phase 3: Email Flows and Transactional Email - Context

**Gathered:** 2026-04-06
**Status:** Ready for planning

<domain>
## Phase Boundary

All email-based auth flows work end to end -- confirmation, password reset, and transactional delivery -- with HMAC-protected single-use tokens, async delivery, and customizable templates. A developer's users can confirm their email (via link or code), reset their password via email, and all emails are delivered asynchronously via Oban (or inline when Oban absent).

</domain>

<decisions>
## Implementation Decisions

### Confirmation Flow
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

### Email Template Approach
- **D-12:** Clean minimal HTML with inline CSS. No framework deps. Works across all email clients (Gmail, Outlook, Apple Mail). Logo placeholder, consistent header/footer.
- **D-13:** Generated EEx templates in host app. Generator creates email module and templates that developer owns and can modify directly. Same "own your code" pattern as phx.gen.auth.
- **D-14:** Phase 3 generates templates for: confirmation, password reset, and magic link emails. Lockout notification and suspicious login are Phase 4 scope.
- **D-15:** Shared layout function: `base_layout/2` in generated email module wraps content with consistent header (app name) and footer. Each email calls it. DRY.
- **D-16:** Mailer behaviour body evolves from plain map to structured: `%{html: html_string, text: text_string}` for multipart. String body still works (treated as text-only). Backward compatible.
- **D-17:** Config-driven from address: `:from_email` in Sigra config. Default: `"noreply@{app_domain}"` from endpoint config. Generator sets it in config.exs.
- **D-18:** Single email module: `MyApp.Auth.Emails` with `confirmation_email/2`, `reset_password_email/2`, `magic_link_email/2`. Each returns a Swoosh.Email struct.
- **D-19:** Generator configures Swoosh local mailbox adapter for dev email preview. Phoenix 1.8 apps likely already have this -- generator detects and skips if present.
- **D-20:** Descriptive email subjects: "Confirm your email", "Reset your password". These go to the requester's own inbox -- no enumeration concern.

### Oban/Async Delivery
- **D-21:** Single generic email worker: `Sigra.Workers.EmailDelivery` in the library. Takes email type + args. Queue: configurable via `:oban_queue` config (default: `"sigra_mailer"`). Concurrency: configurable (default: 10).
- **D-22:** Worker lives in library, host app configures. Generator injects Oban queue config into host app's Oban setup. Worker code updatable via `mix deps.update`.
- **D-23:** Explicit delivery API: `deliver_async/2` and `deliver_sync/2`. Generated context picks which to call based on config. No unified magic function.
- **D-24:** Inline fallback when Oban absent: Claude's discretion on implementation (synchronous in calling process vs Task.async).
- **D-25:** Retry: max_attempts 3, exponential backoff (~15s, ~60s). If all fail, Oban marks as discarded.
- **D-26:** Delivery mode: auto-detect Oban presence via `Code.ensure_loaded?` with explicit override via `:delivery_mode` config (`:async` | `:sync` | `:auto`). Default: `:auto`.
- **D-27:** Token cleanup: both Oban cron job (`Sigra.Workers.TokenCleanup`, runs daily, deletes tokens older than max TTL) AND opportunistic cleanup on token verification. Belt and suspenders.

### Password Reset Flow
- **D-28:** Reset token TTL: 60 minutes by default, configurable via `:reset_token_ttl`.
- **D-29:** After password reset, invalidate all sessions except newly created one. Auto-login after reset -- user lands in the app, not the login page.
- **D-30:** Expired/used reset link shows dedicated error page: "This reset link has expired (or was already used)." with "Request new reset email" button. Same pattern as confirmation expired.
- **D-31:** Password reset is link-only (no code entry option). Link goes to form for new password entry.
- **D-32:** Rate limited: 3 requests per email per 15 minutes (same as magic link and confirmation resend).
- **D-33:** Same password policy for reset as registration (Phase 2 D-22). No password history/reuse prevention.
- **D-34:** Real-time password strength feedback on reset form via phx-change (reuses same component from registration).
- **D-35:** OAuth-only accounts requesting reset: send email suggesting OAuth login ("You signed up with [Provider]. Log in with [Provider] instead, or set a password from your settings."). Enumeration-safe since email is still sent.

### Token Security
- **D-36:** SHA-256 hash for DB storage + HMAC-signed URL via Plug.Crypto.sign with purpose-specific salt. Double protection: token must exist in DB AND signature must be valid.
- **D-37:** 6-digit confirmation codes: SHA-256 hashed, rate-limited entry (5/15min). No HMAC signing -- brute force protection from rate limiting + short TTL.
- **D-38:** Enumeration prevention: always return "If that email exists, we've sent instructions." Dummy hash operation for non-existent emails to match timing. No DB write for non-existent emails.
- **D-39:** No CSRF on link click (GET). CSRF on form submissions (POST for code entry, password reset). Token itself is proof of authorization for GET.
- **D-40:** Token lookups already constant-time: SHA-256 hash comparison in DB query. Plug.Crypto.secure_compare for user-supplied values.

### Generator Strategy
- **D-41:** Single `mix sigra.install` generates everything core, including confirmation, password reset, and email templates. No separate `mix sigra.gen.email`. Separate generators only for truly optional features (OAuth, MFA, API tokens).
- **D-42:** Phase 3 templates added alongside existing ones in `priv/templates/sigra.install/`. Flat structure.
- **D-43:** Controllers primary, LiveView optional (same pattern as Phase 2 D-53). `--live` flag for LiveView pages.
- **D-44:** URL structure follows Phoenix 1.8 conventions: `/users/confirm/{token}`, `/users/confirm`, `/users/reset-password`, `/users/reset-password/{token}`.

### Testing Strategy
- **D-45:** Swoosh test adapter + assertion helpers in `Sigra.Testing`: `assert_email_sent/1`, `extract_confirmation_token/1`, `extract_reset_token/1`.
- **D-46:** Oban.Testing helpers for worker tests: `assert_enqueued worker: Sigra.Workers.EmailDelivery`. When Oban absent, tests use sync path. Both paths covered.

### Rate Limiting
- **D-47:** Consistent per-email rate limits: confirmation resend 3/15min, password reset 3/15min, code entry 5/user/15min. All configurable via NimbleOptions.
- **D-48:** Per-email only in Phase 3. Per-IP rate limiting is Phase 4 scope (SEC-02).

### LiveView Specifics
- **D-49:** Confirmation code entry: simple form, auto-submit on 6 digits via phx-change. Error flash on invalid/expired. Resend link below.
- **D-50:** Password reset form: new password + confirm password + strength meter via phx-change. Submit validates match + policy.

### Library/Generated Code Boundary
- **D-51:** Library (Sigra): token generation/verification, HMAC signing, delivery orchestration (deliver_async/deliver_sync), Oban worker, email telemetry, token cleanup worker. Generated into host: email module with templates, routes, controllers/LiveViews, auth context functions (confirm_user, reset_password).

### API Naming
- **D-52:** Extend Sigra.Auth with: `confirm_user/3`, `request_password_reset/3`, `reset_password/4`, `verify_confirmation_token/3`, `verify_confirmation_code/3`. Generated context: `deliver_confirmation_email/2`, `deliver_reset_password_email/2`. Follows Phase 2 D-43 conventions exactly.

### Config Surface
- **D-53:** Nested under existing sections + new email section. `confirmation:` (ttl, code_length, unconfirmed_access), `reset:` (ttl, rate_limit), `email:` (from_address, oban_queue, delivery_mode). Follows Phase 1 D-06 pattern.

### Swoosh Integration
- **D-54:** Generated `MyApp.Auth.Mailer` implements `Sigra.Mailer` behaviour. Builds Swoosh.Email struct from body map, calls `MyApp.Mailer.deliver/1`.
- **D-55:** Generator configures Swoosh adapters: dev -> Local, test -> Test, prod -> TODO with common adapter examples. Detects existing config and skips if present.

### Error Handling
- **D-56:** Flash messages for controller redirects, inline errors for LiveView forms. Expired token pages use dedicated error template with action button.
- **D-57:** All user-facing strings gettext-ready. Works in English out of the box, translatable via standard Phoenix i18n.

### Telemetry
- **D-58:** New spans: `[:sigra, :email, :deliver, :start/:stop/:exception]`, `[:sigra, :confirmation, :verify, :start/:stop]`. New events: `[:sigra, :confirmation, :sent]`, `[:sigra, :reset, :requested]`, `[:sigra, :reset, :completed]`, `[:sigra, :token, :expired]`. Metadata: email_type, delivery_method, user_id (no email addresses).

### Documentation
- **D-59:** New guides: "Email Confirmation", "Password Reset", "Customizing Email Templates". Update: Sigra.Auth @moduledoc, Sigra.Mailer @moduledoc with body map format, Sigra.Telemetry event catalog.

### Migration
- **D-60:** No new migration needed. Existing user_tokens table (token, context, sent_to, user_id, inserted_at) is sufficient. TTL computed from inserted_at + duration. New token contexts: "confirm", "confirm_code", "reset_password".

### Sudo/Re-auth
- **D-61:** Sudo mode is Phase 4 only. Password reset doesn't need sudo (user proves identity via email token).

### Claude's Discretion
- Email template visual design details (colors, spacing, typography within "clean minimal" constraint)
- Inline fallback implementation choice (synchronous vs Task.async)
- Generated email template format (Elixir module with string interpolation vs EEx files vs Swoosh struct builders)
- Token cleanup cron schedule details
- Exact auto-submit JS behavior for 6-digit code input
- ExDoc guide page structure and content depth

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project specifications
- `.planning/PROJECT.md` -- Vision, architecture philosophy, hybrid lib+generator rationale
- `.planning/REQUIREMENTS.md` -- CONF-01 through CONF-06, RESET-01 through RESET-05, EMAIL-01 through EMAIL-05 requirements
- `.planning/ROADMAP.md` SS Phase 3 -- Goal, success criteria, requirement mapping

### Phase 1 context (foundation)
- `.planning/phases/01-foundation/01-CONTEXT.md` -- D-05 (NimbleOptions config), D-06 (feature-domain config grouping), D-08 (generator scope -- now superseded by D-41 single install), D-09 (EEx templates in priv/templates/), D-12 (Mailer behaviour), D-13 (Swoosh default), D-15-18 (telemetry patterns), D-35-37 (optional dep handling), D-43 (naming conventions), D-48-49 (token strategies, security defaults)

### Phase 2 context (core auth)
- `.planning/phases/02-core-auth/02-CONTEXT.md` -- D-04 (email delivery stubbed), D-23 (auto-login after registration), D-25 (require_confirmation config), D-43 (API naming conventions), D-53 (controllers primary, LiveView optional)

### Existing code to extend
- `lib/sigra/auth.ex` -- Add confirm_user, request_password_reset, reset_password, verify_confirmation_token, verify_confirmation_code
- `lib/sigra/mailer.ex` -- Evolve deliver/3 callback body type to accept %{html: ..., text: ...}
- `lib/sigra/token.ex` -- Token generation/hashing (already sufficient, no changes needed)
- `lib/sigra/config.ex` -- Add confirmation:, reset:, email: NimbleOptions sections
- `lib/sigra/telemetry.ex` -- Add email and confirmation event catalog entries
- `lib/sigra/testing.ex` -- Add email assertion helpers
- `priv/templates/sigra.install/` -- Add email module, confirmation/reset LiveViews, controller templates

### Research documents
- `prompts/Building the gold-standard Elixir:Phoenix authentication library.md` -- Ecosystem analysis, prior art
- `CLAUDE.md` SS Technology Stack -- Swoosh, Oban, dependency versions

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Sigra.Auth` -- Already has register/3, authenticate/3, request_magic_link/3, verify_magic_link/3. Extend with confirmation and reset functions.
- `Sigra.Token` -- Has generate_hashed_token/0, hash_token/1, secure_compare/2, generate/4, verify/4. All token primitives ready.
- `Sigra.Mailer` -- Behaviour with deliver/3 callback. Evolve body type for multipart.
- `Sigra.Config` -- NimbleOptions-validated config struct. Extend with confirmation/reset/email sections.
- `Sigra.Telemetry` -- span/3, event/3, attach_default_logger/1. Add new event types.
- `Sigra.Error` -- Exception types with safe_message/1. Add confirmation/reset-specific errors.
- `Sigra.RateLimiter` -- Behaviour with check_rate callback + Noop fallback. Reuse for all rate limiting.
- `Sigra.Email` -- normalize/1 and validate_format/1. Reuse in all email flows.

### Established Patterns
- `{:ok, result}` | `{:error, reason}` everywhere (Phase 1 D-19)
- Behaviours for extensibility, default implementations (Phase 1 D-12/13)
- Telemetry span for sync ops, events for signals (Phase 1 D-15/18)
- NimbleOptions for all config (Phase 1 D-05)
- `Code.ensure_loaded?` for optional deps (Phase 1 D-35)
- Enumeration-safe responses with dummy hash timing (Phase 2 D-44)
- phx.gen.auth naming conventions (Phase 2 D-43)

### Integration Points
- Generated `auth.ex` context gets new functions: deliver_confirmation_email/2, deliver_reset_password_email/2, confirm_user/1, reset_password/2
- Generated email module (new): MyApp.Auth.Emails with base_layout/2 and per-email functions
- Generated mailer wrapper (new): MyApp.Auth.Mailer implementing Sigra.Mailer
- New templates in priv/templates/sigra.install/: email module, confirmation LiveView, reset LiveView, controller templates
- Router: new routes for /users/confirm/{token}, /users/confirm, /users/reset-password, /users/reset-password/{token}
- Config: new NimbleOptions sections for confirmation, reset, email
- Oban config: inject sigra_mailer queue into host app's Oban setup

</code_context>

<specifics>
## Specific Ideas

- Expired token pages should be actionable (resend/re-request button), not dead ends
- Auto-submit on 6-digit code entry for smooth UX
- Real-time password strength meter reused from registration on reset form
- OAuth-only users requesting reset get helpful guidance email, not silence
- "Already confirmed" page for double-click is friendly acknowledgment, not an error
- Swoosh dev mailbox (/dev/mailbox) configured by generator for local development
- Single `mix sigra.install` for everything core -- no generator fragmentation for baseline auth

</specifics>

<deferred>
## Deferred Ideas

- Email change with re-verification (ACCT-01) -- separate Account Lifecycle phase
- Lockout notification emails -- Phase 4 (Security Baseline)
- Suspicious login notification emails -- Phase 4 (Security Baseline)
- Per-IP rate limiting -- Phase 4 (SEC-02)
- Sudo/re-auth mode -- Phase 4 (SESS-09)

</deferred>

---

*Phase: 03-email-flows-and-transactional-email*
*Context gathered: 2026-04-06*
