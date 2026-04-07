# Phase 3: Email Flows and Transactional Email - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md -- this log preserves the alternatives considered.

**Date:** 2026-04-06
**Phase:** 03-email-flows-and-transactional-email
**Areas discussed:** Confirmation flow design, Email template approach, Oban/async delivery, Password reset UX, Generated routes/controllers, Testing strategy, Token security model, Sudo/re-auth interaction, Enumeration prevention, Config surface, LiveView specifics, Generator template organization, Error handling, Telemetry, Library vs generated boundary, Edge cases, Naming conventions, Migration changes, Swoosh integration, Rate limiting, Documentation

---

## Confirmation Flow Design

| Option | Description | Selected |
|--------|-------------|----------|
| Link-first, code as fallback | Email contains clickable link (primary) AND 6-digit code. Link auto-confirms; code for users who can't click. | ✓ |
| Code-only | Email contains only 6-digit code. User enters on confirmation page. | |
| Link-only | Email contains only clickable link. No fallback. | |

**User's choice:** Link-first, code as fallback
**Notes:** Recommended approach selected.

| Option | Description | Selected |
|--------|-------------|----------|
| Allow login with banner | Unconfirmed users can log in with persistent banner nudge. | |
| Block login until confirmed | Unconfirmed users cannot access the app. | |
| Configurable (both modes) | Ship both, controlled by :unconfirmed_access config. Default: allow_with_banner. | ✓ |

**User's choice:** Configurable (both modes)

| Option | Description | Selected |
|--------|-------------|----------|
| 48 hours | Matches REQUIREMENTS.md. Single-use, HMAC-protected. | ✓ |
| 24 hours | Tighter window, same-day confirmation. | |
| 72 hours | Extra generous for weekend signups. | |

**User's choice:** 48 hours by default but configurable
**Notes:** User emphasized configurability.

| Option | Description | Selected |
|--------|-------------|----------|
| Rate-limited resend button | Banner has resend button. 3/email/15min. | |
| Automatic resend on login attempt | Auto-resend on blocked login. No explicit button. | |
| Both -- button + auto-resend | Resend button AND auto-resend on blocked login. | ✓ |

**User's choice:** Both -- button + auto-resend

| Option | Description | Selected |
|--------|-------------|----------|
| Random numeric, stored hashed | 6 random digits, SHA-256 hash in DB. Separate from link token. | ✓ |
| Derived from link token | 6-digit code derived deterministically from link token. | |
| You decide | | |

**User's choice:** Random numeric, stored hashed

| Option | Description | Selected |
|--------|-------------|----------|
| Separate paths | Link click: /users/confirm/{token}. Code entry: /users/confirm form. | ✓ |
| Unified form | Single page, paste URL or type code. | |

**User's choice:** Separate paths

| Option | Description | Selected |
|--------|-------------|----------|
| Error page with resend button | Expired page with "Send new confirmation email" button. | ✓ |
| Redirect to login with flash | Redirect with flash, requires login to resend. | |

**User's choice:** Error page with resend button

| Option | Description | Selected |
|--------|-------------|----------|
| Explicit feedback | "Account not yet confirmed. We've sent a new confirmation email." | ✓ |
| Silent resend | Generic "check your email" with behind-the-scenes resend. | |

**User's choice:** Explicit feedback

| Option | Description | Selected |
|--------|-------------|----------|
| Magic link counts as confirmation | Already implemented in Phase 2. Just document behavior. | ✓ |
| Separate concerns | Always send confirmation regardless of auth method. | |
| Skip confirmation for magic link users | Don't send confirmation for magic link registrations. | |

**User's choice:** Magic link counts as confirmation

| Option | Description | Selected |
|--------|-------------|----------|
| First click confirms, second shows "already confirmed" | Token deleted after first use. Second click: friendly acknowledgment. | ✓ |
| Idempotent -- both clicks succeed | Mark token used but don't delete. Grace window. | |

**User's choice:** First click confirms, second shows "already confirmed"

| Option | Description | Selected |
|--------|-------------|----------|
| All valid -- any token works | All resend tokens remain valid. Clicking any confirms. | ✓ |
| Latest only -- invalidate previous | Each resend invalidates prior tokens. | |

**User's choice:** All valid -- any token works

| Option | Description | Selected |
|--------|-------------|----------|
| Separate phase | Email change is ACCT-01, Account Lifecycle. | ✓ |
| Include basic email change | Add email change now since confirmation infra is here. | |

**User's choice:** Separate phase

---

## Email Template Approach

| Option | Description | Selected |
|--------|-------------|----------|
| Clean minimal with inline CSS | Professional templates, inline CSS, cross-client compatible. | ✓ |
| Swoosh + Phoenix component-based | Use Swoosh/Phoenix helpers for layout. | |
| Plain text only | Text-only emails. | |

**User's choice:** Clean minimal with inline CSS

| Option | Description | Selected |
|--------|-------------|----------|
| Generated EEx templates in host app | Developer owns and edits templates directly. | ✓ |
| Library templates with overrides | Defaults in Sigra, overridable by host app. | |

**User's choice:** Generated EEx templates in host app

| Option | Description | Selected |
|--------|-------------|----------|
| Confirmation + password reset + magic link | Three flows in Phase 3 scope. | ✓ |
| All auth emails upfront | Generate all types including Phase 4 emails. | |

**User's choice:** Confirmation + password reset + magic link

| Option | Description | Selected |
|--------|-------------|----------|
| Shared layout function | base_layout/2 wrapper for consistent header/footer. | ✓ |
| Self-contained templates | Each template fully independent. | |

**User's choice:** Shared layout function

| Option | Description | Selected |
|--------|-------------|----------|
| Evolve body to structured map | deliver/3 body becomes %{html: ..., text: ...}. Backward compatible. | ✓ |
| New callback signature | Change to deliver(email) struct. | |
| Add second callback | Keep deliver/3, add deliver_multipart/3. | |

**User's choice:** Evolve body to structured map

| Option | Description | Selected |
|--------|-------------|----------|
| Config-driven with smart default | :from_email in config. Default: noreply@{app_domain}. | ✓ |
| Per-email from address | Each email type has own from. | |

**User's choice:** Config-driven with smart default

| Option | Description | Selected |
|--------|-------------|----------|
| Single module with functions | MyApp.Auth.Emails with per-email functions. | ✓ |
| Module per email type | Separate modules per email. | |

**User's choice:** Single module with functions

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, configure in generator | Generator adds Swoosh dev mailbox route. | ✓ |
| Document only | Just document how to set up dev preview. | |

**User's choice:** Yes, configure in generator

---

## Oban/Async Delivery

| Option | Description | Selected |
|--------|-------------|----------|
| Single generic email worker | One Sigra.Workers.EmailDelivery. Queue: configurable. | ✓ |
| Per-type workers | Separate workers per email type. | |

**User's choice:** Single generic email worker

| Option | Description | Selected |
|--------|-------------|----------|
| Library worker, host app configures | Worker in Sigra lib. Host adds to Oban config. | ✓ |
| Generated into host app | Worker generated into host app. | |

**User's choice:** Library worker, host app configures

| Option | Description | Selected |
|--------|-------------|----------|
| Synchronous in calling process | When Oban absent, deliver inline. | |
| Task.async fire-and-forget | Spawn Task for delivery. | |
| You decide | | ✓ |

**User's choice:** You decide (Claude's discretion)

| Option | Description | Selected |
|--------|-------------|----------|
| Explicit choice by caller | deliver_async/2 and deliver_sync/2. Context picks based on config. | ✓ |
| Unified deliver function | Auto-detects Oban presence. | |

**User's choice:** Explicit choice by caller

| Option | Description | Selected |
|--------|-------------|----------|
| 3 attempts, exponential backoff | ~15s, ~60s delays. Discarded on third failure. | ✓ |
| 5 attempts, longer backoff | More resilient but delays error visibility. | |

**User's choice:** 3 attempts, exponential backoff

| Option | Description | Selected |
|--------|-------------|----------|
| Telemetry events | [:sigra, :email, :deliver, :*] span. Consistent with Phase 1 pattern. | ✓ |
| Callback on failure | Second mailer callback for failure handling. | |

**User's choice:** Telemetry events

| Option | Description | Selected |
|--------|-------------|----------|
| Dedicated "sigra_mailer" queue | Own queue, configurable concurrency. | |
| Use host app's default queue | No special queue. | |
| Configurable queue name | Default to "sigra_mailer", override via config. | ✓ |

**User's choice:** Configurable queue name

---

## Password Reset UX

| Option | Description | Selected |
|--------|-------------|----------|
| 60 minutes, configurable | Matches REQUIREMENTS.md. :reset_token_ttl config. | ✓ |
| 30 minutes | Tighter window. | |

**User's choice:** 60 minutes, configurable

| Option | Description | Selected |
|--------|-------------|----------|
| All sessions except newly created one | Invalidate all, create new. User stays logged in. | ✓ |
| All sessions including current | Invalidate everything, force re-login. | |

**User's choice:** All sessions except newly created one

| Option | Description | Selected |
|--------|-------------|----------|
| Error page with new request link | Actionable error page with re-request button. | ✓ |
| Redirect to forgot password page | Redirect with flash. | |

**User's choice:** Error page with new request link

| Option | Description | Selected |
|--------|-------------|----------|
| Link only for reset | No code option. Link -> new password form. | ✓ |
| Link + code | Include 6-digit code option for reset too. | |

**User's choice:** Link only for reset

| Option | Description | Selected |
|--------|-------------|----------|
| Rate limited, same as magic link | 3/email/15min. Enumeration-safe. | ✓ |
| No rate limit | Rely on mailer provider limits. | |

**User's choice:** Rate limited, same as magic link

| Option | Description | Selected |
|--------|-------------|----------|
| Same policy everywhere | Same Sigra.PasswordPolicy.validate/2 for registration and reset. | ✓ |
| Stricter on reset | Additional checks on reset. | |

**User's choice:** Same policy everywhere (matches Phase 2 D-22)

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, reuse same component | Same phx-change strength indicator. | ✓ |
| No strength feedback on reset | Just password field + submit. | |

**User's choice:** Yes, reuse same component

| Option | Description | Selected |
|--------|-------------|----------|
| Both -- cron + cleanup on read | Oban cron for bulk + opportunistic on verification. | ✓ |
| Oban cron job only | Daily cleanup job. | |
| Cleanup on read only | Lazy cleanup on token verification. | |

**User's choice:** Both -- cron + cleanup on read

| Option | Description | Selected |
|--------|-------------|----------|
| Send email suggesting OAuth login | Helpful guidance, enumeration-safe. | ✓ |
| Generic response, no email | Same message, no email sent. | |

**User's choice:** Send email suggesting OAuth login

---

## Generated Routes/Controllers

| Option | Description | Selected |
|--------|-------------|----------|
| Single install with everything core | mix sigra.install generates all core features including email flows. | ✓ |
| Single install + feature flags | --no-oauth, --no-mfa flags to exclude. | |
| Keep incremental generators | Separate generators per feature. | |

**User's choice:** Single install with everything core
**Notes:** User reconsidered incremental generators (Phase 1 D-08) and decided single install is better DX for the finished product.

| Option | Description | Selected |
|--------|-------------|----------|
| Same pattern as login: controllers primary, LiveView optional | --live flag. Matches Phase 2 D-53. | ✓ |
| Controllers only for these flows | No LiveView option for confirmation/reset. | |

**User's choice:** Same pattern as login

| Option | Description | Selected |
|--------|-------------|----------|
| Phoenix 1.8 conventions | /users/confirm/{token}, /users/reset-password/{token}. | ✓ |
| Nested under /auth | /auth/confirm/{token}, /auth/reset-password/{token}. | |

**User's choice:** Phoenix 1.8 conventions

---

## Testing Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Swoosh test adapter + assertion helpers | assert_email_sent/1, extract_confirmation_token/1. | ✓ |
| Mock mailer via Mox | Mox mock of Sigra.Mailer. | |

**User's choice:** Swoosh test adapter + assertion helpers

| Option | Description | Selected |
|--------|-------------|----------|
| Oban.Testing helpers | assert_enqueued with inline execution. | ✓ |
| Direct worker unit tests | Test perform/1 directly. | |

**User's choice:** Oban.Testing helpers

---

## Token Security Model

| Option | Description | Selected |
|--------|-------------|----------|
| SHA-256 hash + signed URL | Double protection: DB + HMAC signature. | ✓ |
| SHA-256 hash only | Hash only, no URL signing. phx.gen.auth approach. | |

**User's choice:** SHA-256 hash + signed URL

| Option | Description | Selected |
|--------|-------------|----------|
| SHA-256 hashed, rate-limited entry | Hash + rate limiting for brute force protection. | ✓ |
| Same as link tokens | Full HMAC + hash. | |

**User's choice:** SHA-256 hashed, rate-limited entry

---

## Sudo/Re-auth Interaction

| Option | Description | Selected |
|--------|-------------|----------|
| Phase 4 only -- no sudo in Phase 3 | Password reset proves identity via email token, not session. | ✓ |
| Add sudo check for password change | Require re-auth for logged-in password change. | |

**User's choice:** Phase 4 only

---

## Enumeration Prevention

| Option | Description | Selected |
|--------|-------------|----------|
| Generic response + dummy work | Always generic message + dummy hash for timing. | ✓ |
| Generic response only | No timing protection. | |

**User's choice:** Generic response + dummy work

| Option | Description | Selected |
|--------|-------------|----------|
| Descriptive subjects | "Confirm your email", "Reset your password". | ✓ |
| Generic subjects | "Action required for your account". | |

**User's choice:** Descriptive subjects

---

## Config Surface

| Option | Description | Selected |
|--------|-------------|----------|
| Nested under existing + new email section | confirmation:, reset:, email: sections. D-06 pattern. | ✓ |
| Flat top-level keys | :confirmation_ttl, :reset_ttl, etc. | |

**User's choice:** Nested sections

| Option | Description | Selected |
|--------|-------------|----------|
| Auto-detect with explicit override | :delivery_mode (:async/:sync/:auto). Default: :auto. | ✓ |
| Always explicit | Must set :delivery_mode. | |

**User's choice:** Auto-detect with override

---

## LiveView Specifics

| Option | Description | Selected |
|--------|-------------|----------|
| Simple form with auto-submit on 6 digits | phx-change validates, auto-submits at 6 digits. | ✓ |
| Standard form with submit button | No auto-submit. | |

**User's choice:** Simple form with auto-submit

| Option | Description | Selected |
|--------|-------------|----------|
| New password + confirm + strength meter | Two fields, real-time feedback. | ✓ |
| New password only, no confirm | Single field, show/hide toggle. | |

**User's choice:** New password + confirm + strength meter

| Option | Description | Selected |
|--------|-------------|----------|
| Auto-login after reset | Create session, redirect to app. | ✓ |
| Redirect to login page | Success flash, redirect to login. | |

**User's choice:** Auto-login after reset

---

## Generator Template Organization

| Option | Description | Selected |
|--------|-------------|----------|
| Add to existing sigra.install templates | Flat structure alongside existing templates. | ✓ |
| Subdirectory per feature | priv/templates/sigra.install/emails/, etc. | |

**User's choice:** Add to existing templates

| Option | Description | Selected |
|--------|-------------|----------|
| Elixir module with string interpolation | Functions returning HTML strings. | |
| EEx template files | Separate .html.eex and .text.eex files. | |
| Swoosh.Email struct builders | Build Swoosh structs directly. | |
| You decide | | ✓ |

**User's choice:** You decide (Claude's discretion)

---

## Error Handling

| Option | Description | Selected |
|--------|-------------|----------|
| Flash + inline (controller + LiveView) | Flash for redirects, inline for forms. | ✓ |
| Always inline | No flash, all inline. | |

**User's choice:** Flash + inline

| Option | Description | Selected |
|--------|-------------|----------|
| Gettext-ready strings | All strings wrapped in gettext. Translatable. | ✓ |
| Hardcoded English | Plain strings. | |

**User's choice:** Gettext-ready strings

---

## Telemetry

| Option | Description | Selected |
|--------|-------------|----------|
| Comprehensive email + token events | Full span + event catalog. | ✓ |
| Minimal -- just delivery events | Only deliver span. | |

**User's choice:** Comprehensive events

---

## Security Considerations

| Option | Description | Selected |
|--------|-------------|----------|
| No CSRF on link click, CSRF on forms | Token is proof for GET. CSRF on POST. | ✓ |
| Signed tokens serve as CSRF | HMAC serves dual purpose. | |

**User's choice:** No CSRF on GET, CSRF on POST

| Option | Description | Selected |
|--------|-------------|----------|
| Hash comparison already constant-time | SHA-256 hash in DB query. secure_compare for user values. | ✓ |
| Add explicit timing padding | Artificial delay. | |

**User's choice:** Already constant-time

---

## Rate Limiting

| Option | Description | Selected |
|--------|-------------|----------|
| Consistent per-email limits | 3/15min for resend + reset. 5/15min for code entry. Configurable. | ✓ |
| Tighter limits | 2/30min. | |

**User's choice:** Consistent per-email limits

| Option | Description | Selected |
|--------|-------------|----------|
| Per-email only in Phase 3 | Per-IP is Phase 4. | ✓ |
| Both email and IP now | Pull Phase 4 scope. | |

**User's choice:** Per-email only

---

## Library vs Generated Boundary

| Option | Description | Selected |
|--------|-------------|----------|
| Library: token + delivery. Generated: templates + routes + context | Security in lib, customizable UX generated. | ✓ |
| More in library | Also put orchestration in lib. | |
| More generated | Also generate workers. | |

**User's choice:** Library: token + delivery. Generated: templates + routes + context

---

## Naming Conventions

| Option | Description | Selected |
|--------|-------------|----------|
| Follow D-43 exactly | confirm_user, request_password_reset, deliver_*. phx.gen.auth conventions. | ✓ |
| New modules for email flows | Sigra.Confirmation, Sigra.PasswordReset. | |

**User's choice:** Follow D-43 -- extend Sigra.Auth

---

## Migration Changes

| Option | Description | Selected |
|--------|-------------|----------|
| No new migration | Existing user_tokens table sufficient. | ✓ |
| Add expires_at column | Explicit expiry column. | |

**User's choice:** No new migration

---

## Swoosh Integration

| Option | Description | Selected |
|--------|-------------|----------|
| Thin wrapper implementing Sigra.Mailer | Generated MyApp.Auth.Mailer builds Swoosh.Email from body map. | ✓ |
| Direct Swoosh usage | Skip behaviour wrapper. | |

**User's choice:** Thin wrapper

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, standard Phoenix setup | Generator configures adapters per env. Detects existing config. | ✓ |
| Don't touch adapter config | Assume host already has Swoosh. | |

**User's choice:** Yes, configure adapters

---

## Documentation

| Option | Description | Selected |
|--------|-------------|----------|
| Guide pages + updated API docs | New guides + updated @moduledoc. ExDoc. | ✓ |
| API docs only | Only @moduledoc updates. | |

**User's choice:** Guide pages + API docs

---

## Claude's Discretion

- Email template visual design details
- Inline fallback implementation (sync vs Task.async)
- Generated email template format (string interpolation vs EEx vs Swoosh structs)
- Token cleanup cron schedule details
- Auto-submit JS behavior for 6-digit code
- ExDoc guide structure and depth

## Deferred Ideas

- Email change with re-verification -- ACCT-01, Account Lifecycle
- Lockout notification emails -- Phase 4
- Suspicious login emails -- Phase 4
- Per-IP rate limiting -- Phase 4
- Sudo/re-auth mode -- Phase 4
