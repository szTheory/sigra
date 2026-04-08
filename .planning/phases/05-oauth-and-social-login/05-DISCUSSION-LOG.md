# Phase 5: OAuth and Social Login - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-08
**Phase:** 05-oauth-and-social-login
**Areas discussed:** Account linking policy, Provider architecture, Token storage & identity schema, OAuth flow UX, Error handling & edge cases, OAuth for headless/API mode, Generator design details, Config surface & defaults

---

## Account Linking Policy

| Option | Description | Selected |
|--------|-------------|----------|
| Always require confirmation | Show confirmation step requiring password login to link provider | ✓ |
| Auto-link with config override | Default auto-link, configurable strategy | |
| Configurable per-provider | Auto-link for trusted providers, confirm for others | |

**User's choice:** Always require confirmation
**Notes:** Security-first approach. Prevents account takeover if attacker controls a provider account with victim's email.

| Option | Description | Selected |
|--------|-------------|----------|
| Block until password set | Refuse to unlink last provider | ✓ |
| Block + offer password setup inline | Block with inline password setup flow | |
| Allow with strong warning | Allow with confirmation dialog | |

**User's choice:** Block until password set

| Option | Description | Selected |
|--------|-------------|----------|
| Fail with clear error | Require email permission | ✓ |
| Prompt for email manually | Show form for email entry | |

**User's choice:** Fail with clear error — don't create user without email

| Option | Description | Selected |
|--------|-------------|----------|
| Require sudo mode | Linking is sensitive operation | ✓ |
| No re-auth needed | User already logged in | |

**User's choice:** Require sudo mode for linking

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, sudo for both | Link and unlink both require sudo | ✓ |
| No, unlink is less sensitive | Only link requires sudo | |

**User's choice:** Sudo for both — consistent security posture

| Option | Description | Selected |
|--------|-------------|----------|
| Treat as new link request | Same confirmation flow as confirmed accounts | ✓ |
| Auto-link and confirm | Auto-confirm + link since provider verified email | |

**User's choice:** Treat as new link request for unconfirmed accounts

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, always notify on link | Security signal email | ✓ |
| No notification | Sudo mode sufficient | |

**User's choice:** Always notify on link

| Option | Description | Selected |
|--------|-------------|----------|
| No, one per provider | Unique constraint (user_id, provider) | ✓ |
| Yes, allow multiple | Support personal + work accounts | |

**User's choice:** One per provider

| Option | Description | Selected |
|--------|-------------|----------|
| Re-auth via existing provider | Redirect to linked provider | ✓ |
| Send email confirmation link | Async email confirmation | |

**User's choice:** Re-auth via existing provider for OAuth-only users

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, notify on unlink too | Full audit trail | ✓ |
| No, only on link | Reduce email noise | |

**User's choice:** Notify on unlink too

---

## Provider Architecture

| Option | Description | Selected |
|--------|-------------|----------|
| Config.exs with provider list | Keyword list, runtime.exs for secrets | ✓ |
| Separate provider modules | Generated per-provider module | |

**User's choice:** Config.exs with provider list

| Option | Description | Selected |
|--------|-------------|----------|
| Thin wrapper per provider | Sigra.OAuth.Strategies.* wraps Assent | ✓ |
| Use Assent directly | Generated code calls Assent | |

**User's choice:** Thin wrapper per provider

| Option | Description | Selected |
|--------|-------------|----------|
| Same code, different docs | All use same wrapper pattern | ✓ |
| Tier 1 built-in, tier 2 generators | Different code paths per tier | |

**User's choice:** Same code, different docs

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, via Assent strategy module | Any Assent strategy works via config | ✓ |
| Yes, via behaviour | Sigra-specific strategy behaviour | |

**User's choice:** Via Assent strategy module

| Option | Description | Selected |
|--------|-------------|----------|
| Runtime with startup check | NimbleOptions at startup | ✓ |
| Compile-time via NimbleOptions | Compilation failure on missing config | |

**User's choice:** Runtime with startup check

| Option | Description | Selected |
|--------|-------------|----------|
| Sigra generates, Assent verifies | HMAC-signed state, session stored | ✓ |
| Fully delegate to Assent | Assent handles state end-to-end | |

**User's choice:** Sigra generates and verifies state

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, PKCE always when supported | S256 by default | ✓ |
| PKCE opt-in per provider | Developers enable per provider | |

**User's choice:** PKCE always when supported

| Option | Description | Selected |
|--------|-------------|----------|
| Incremental generator | mix sigra.gen.oauth | ✓ |
| Part of base install | OAuth in mix sigra.install | |

**User's choice:** Incremental generator

| Option | Description | Selected |
|--------|-------------|----------|
| Both: named + generic | Wrappers for tier 1-2, generic fallback | ✓ |
| Named wrappers only | Only supported providers | |

**User's choice:** Both approaches

| Option | Description | Selected |
|--------|-------------|----------|
| Optional dep | Code.ensure_loaded? gate | ✓ |
| Required dep | Always include Assent | |

**User's choice:** Optional dep

| Option | Description | Selected |
|--------|-------------|----------|
| Controller only | HTTP redirects | ✓ |
| LiveView with controller | Mixed approach | |

**User's choice:** Controller only for OAuth routes

| Option | Description | Selected |
|--------|-------------|----------|
| OIDC discovery when available | Auto-discover from .well-known | ✓ |
| Always manual config | Explicit URLs | |

**User's choice:** OIDC discovery when available

| Option | Description | Selected |
|--------|-------------|----------|
| Split by concern | Sigra.OAuth, Callback, Strategies.* | ✓ |
| Single module | Everything in Sigra.OAuth | |

**User's choice:** Split by concern

---

## Token Storage & Identity Schema

| Option | Description | Selected |
|--------|-------------|----------|
| cloak_ecto | AES-256-GCM encrypted columns | ✓ |
| :crypto directly | Manual encryption | |
| Don't store tokens | Only store UID | |

**User's choice:** cloak_ecto

| Option | Description | Selected |
|--------|-------------|----------|
| Full identity record | All columns explicit | ✓ |
| Minimal + JSONB blob | Fewer columns, data in JSONB | |

**User's choice:** Full identity record

| Option | Description | Selected |
|--------|-------------|----------|
| Required for OAuth | cloak_ecto required with gen.oauth | ✓ |
| Optional with plaintext fallback | Warning if not installed | |

**User's choice:** Required for OAuth
**Notes:** User doesn't want to compromise on token encryption.

| Option | Description | Selected |
|--------|-------------|----------|
| Auto-refresh on access | Transparent token refresh | ✓ |
| Provide helper only | Developer calls refresh manually | |

**User's choice:** Auto-refresh on access
**Notes:** User emphasized "pit of success" DX — "make it easy for devs to win here." Expired tokens cause confusing failures; auto-refresh is the secure-by-default approach.

| Option | Description | Selected |
|--------|-------------|----------|
| Library struct + generated schema | Sigra.Identity + UserIdentity | ✓ |
| Generated schema only | No library struct | |

**User's choice:** Library struct + generated schema

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, store provider_avatar_url | Explicit column | ✓ |
| Keep in metadata JSONB | Less prominent | |

**User's choice:** Store avatar URL

| Option | Description | Selected |
|--------|-------------|----------|
| Update on every login | Keep provider data fresh | ✓ |
| Only update tokens | Profile frozen at first link | |

**User's choice:** Update on every login

| Option | Description | Selected |
|--------|-------------|----------|
| Regular string, normalize in code | Works across all DBs | ✓ |
| citext | PostgreSQL-specific | |

**User's choice:** Regular string

| Option | Description | Selected |
|--------|-------------|----------|
| Generated into host app | MyApp.Vault + encrypted type | ✓ |
| Library provides vault | Sigra.Vault | |

**User's choice:** Generated into host app (Claude's recommendation after user feedback)
**Notes:** User wanted "easy to win by default" without generating unnecessary boilerplate. Vault is ~10 lines + env var. Consistent with hybrid architecture.

| Option | Description | Selected |
|--------|-------------|----------|
| Normalized subset | Useful fields extracted | ✓ |
| Raw provider response | Full response stored | |

**User's choice:** Normalized subset

| Option | Description | Selected |
|--------|-------------|----------|
| Both unique indexes | (user_id, provider) + (provider, provider_uid) | ✓ |
| Only (provider, provider_uid) | Single unique constraint | |

**User's choice:** Both unique indexes

| Option | Description | Selected |
|--------|-------------|----------|
| Track last_used_at | Throttled writes | ✓ |
| No tracking | Only timestamps | |

**User's choice:** Track last_used_at

| Option | Description | Selected |
|--------|-------------|----------|
| Protocol/function mapping | from_schema/1, to_params/1 | ✓ |
| Shared @fields | Implicit matching | |

**User's choice:** Protocol/function mapping

| Option | Description | Selected |
|--------|-------------|----------|
| No behaviour, Ecto-only | YAGNI | ✓ |
| IdentityStore behaviour | Consistency with SessionStore | |

**User's choice:** No behaviour — Ecto-only

| Option | Description | Selected |
|--------|-------------|----------|
| Generate custom encrypted types | MyApp.Encrypted.Binary | ✓ |
| Use cloak_ecto built-in | Cloak.Ecto.Binary directly | |

**User's choice:** Generate custom types

| Option | Description | Selected |
|--------|-------------|----------|
| Separate migration via gen.oauth | OAuth is opt-in | ✓ |
| Add to Phase 1 migration | Part of base schema | |

**User's choice:** Separate migration

---

## OAuth Flow UX

| Option | Description | Selected |
|--------|-------------|----------|
| Above password form with divider | Easiest path first | ✓ |
| Below password form | Password prioritized | |

**User's choice:** Above password form

| Option | Description | Selected |
|--------|-------------|----------|
| Redirect to login with flash | No dead-end pages | ✓ |
| Dedicated error page | Styled error page | |

**User's choice:** Redirect with flash

| Option | Description | Selected |
|--------|-------------|----------|
| Redirect to login with banner | Link intent in session | ✓ |
| Dedicated linking page | Separate /auth/link-account | |

**User's choice:** Redirect to login with linking prompt

| Option | Description | Selected |
|--------|-------------|----------|
| SVG icons inline | No external deps | ✓ |
| Text-only buttons | Plain text | |

**User's choice:** SVG icons inline

| Option | Description | Selected |
|--------|-------------|----------|
| Same as password registration | Auto-login + redirect | ✓ |
| Welcome/onboarding page | Special first-time page | |

**User's choice:** Same as password registration

| Option | Description | Selected |
|--------|-------------|----------|
| Expire after 15 minutes | Explicit TTL | ✓ |
| Expire with browser session | Cookie-scoped | |

**User's choice:** 15-minute TTL on link intent

| Option | Description | Selected |
|--------|-------------|----------|
| Same IP rate limiting | Reuse RateLimit plug | ✓ |
| No rate limiting on OAuth init | Redirects are cheap | |

**User's choice:** Same IP rate limiting

| Option | Description | Selected |
|--------|-------------|----------|
| Both LiveView + controller | --live flag on generator | ✓ |
| Generated LiveView component | LiveView only | |
| Controller-based HTML | Controller only | |

**User's choice:** Both variants (custom response after user feedback)
**Notes:** User pointed out we shouldn't force WebSocket connections. Generator creates both variants, --live flag controls which is installed.

| Option | Description | Selected |
|--------|-------------|----------|
| Dynamic from config | Buttons render from providers list | ✓ |
| Static in generated template | Hard-coded at generation time | |

**User's choice:** Dynamic from config

| Option | Description | Selected |
|--------|-------------|----------|
| OAuth-specific events | Dedicated event namespace | ✓ |
| Reuse existing auth events | Metadata-only distinction | |

**User's choice:** OAuth-specific telemetry events

| Option | Description | Selected |
|--------|-------------|----------|
| Full OAuth test helpers | mock_oauth_callback, create_identity, oauth_user_fixture | ✓ |
| Minimal helpers | Just create_identity | |

**User's choice:** Full test helpers

| Option | Description | Selected |
|--------|-------------|----------|
| Configurable scopes per provider | scopes: [...] in provider config | ✓ |
| Fixed scopes | Always email + profile | |

**User's choice:** Configurable scopes

| Option | Description | Selected |
|--------|-------------|----------|
| /auth/:provider | Separate namespace | ✓ |
| /users/auth/:provider | Nested under /users | |

**User's choice:** /auth/:provider

| Option | Description | Selected |
|--------|-------------|----------|
| Plug session with prefixed keys | sigra_oauth_* keys | ✓ |
| Separate encrypted cookie | Dedicated cookie | |

**User's choice:** Plug session with prefixed keys

| Option | Description | Selected |
|--------|-------------|----------|
| Same session, metadata notes OAuth | auth_method: :oauth | ✓ |
| Distinct :oauth session type | New session type | |

**User's choice:** Same session with metadata

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, auto-confirm | Provider verified email | ✓ |
| Still require confirmation | Belt and suspenders | |
| Configurable | trust_provider_email config | |

**User's choice:** Auto-confirm

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, same as password login | return_to in session | ✓ |
| Always redirect to root | Simpler | |

**User's choice:** Same return_to pattern

| Option | Description | Selected |
|--------|-------------|----------|
| Telemetry only | [:sigra, :oauth, :callback, :stop] | ✓ |
| Callback behaviour | Sigra.OAuth.CallbackHandler | |

**User's choice:** Telemetry only

| Option | Description | Selected |
|--------|-------------|----------|
| OAuth sessions remember-me by default | Users expect persistent sessions | ✓ |
| No remember-me for OAuth | Standard session only | |
| Configurable | :oauth_session_type config | |

**User's choice:** Remember-me by default (user feedback: "users expect to stay logged in")

| Option | Description | Selected |
|--------|-------------|----------|
| Show remaining methods | Clear consequences on unlink | ✓ |
| Simple confirm dialog | Just "are you sure?" | |

**User's choice:** Show remaining methods

---

## Error Handling & Edge Cases

| Option | Description | Selected |
|--------|-------------|----------|
| Generic with internal logging | No information leakage | ✓ |
| Provider-specific messages | More helpful but leaky | |

**User's choice:** Generic with internal logging

| Option | Description | Selected |
|--------|-------------|----------|
| Redirect to login, generic message | Don't mention CSRF | ✓ |
| Specific session expiry message | More informative | |

**User's choice:** Redirect with generic message

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, structured errors | Sigra.Error.OAuthError | ✓ |
| Reuse existing error atoms | Simpler | |

**User's choice:** Structured OAuth error types

| Option | Description | Selected |
|--------|-------------|----------|
| Match by provider_uid, update email | Don't change user's primary email | ✓ |
| Flag for manual review | Block on email mismatch | |

**User's choice:** Match by provider_uid, update email on identity

| Option | Description | Selected |
|--------|-------------|----------|
| Block with clear error | Never auto-merge accounts | ✓ |
| Ignore email, trust provider_uid | Login proceeds | |

**User's choice:** Block when provider_uid maps to one user but email matches another

| Option | Description | Selected |
|--------|-------------|----------|
| No special cooldown | IP rate limit covers it | ✓ |
| Session-level cooldown | Anti-double-click | |

**User's choice:** No special cooldown

---

## OAuth for Headless/API Mode

| Option | Description | Selected |
|--------|-------------|----------|
| Defer to Phase 7 | Server-rendered only in Phase 5 | ✓ |
| Include basic headless now | JSON endpoint for code exchange | |

**User's choice:** Defer to Phase 7

| Option | Description | Selected |
|--------|-------------|----------|
| Client handles redirect | RFC 8252 pattern | ✓ |
| Server-side redirect always | Requires browser/webview | |

**User's choice:** Client handles redirect (for when Phase 7 implements it)

---

## Generator Design Details

| Option | Description | Selected |
|--------|-------------|----------|
| Full set | ~8-10 files | ✓ |
| Minimal set | Migration, schema, controller only | |

**User's choice:** Full file set

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, detect and skip | Safe to re-run | ✓ |
| Overwrite with backup | .bak copies | |

**User's choice:** Idempotent with skip

| Option | Description | Selected |
|--------|-------------|----------|
| Optional provider args | --providers google github | ✓ |
| No arguments | Always full tier 1-2 setup | |

**User's choice:** Optional provider args

---

## Config Surface & Defaults

| Option | Description | Selected |
|--------|-------------|----------|
| Flat with providers list | Simple top-level keys | ✓ |
| Grouped by concern | Deeper nesting | |

**User's choice:** Flat with providers list

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, enabled: false | Global kill switch | ✓ |
| No kill switch | Remove providers to disable | |

**User's choice:** Kill switch via enabled: false

---

## OAuth + MFA Interaction

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, MFA still required | App policy not bypassed by OAuth | ✓ |
| OAuth bypasses MFA | OAuth is already multi-factor | |
| Configurable | Per-deployment choice | |

**User's choice:** MFA required after OAuth

| Option | Description | Selected |
|--------|-------------|----------|
| Minimal prep now | Shared session creation code path | ✓ |
| No prep, Phase 6 handles it | Clean phase boundaries | |

**User's choice:** Minimal prep — ensure same code path

---

## Claude's Discretion

- Exact Assent API surface used in strategy wrappers
- OAuth state HMAC implementation details
- SVG icon markup and brand compliance
- Session cleanup for stale link intents
- NimbleOptions schema for per-provider config
- Controller template structure
- Test mock implementation for Assent HTTP layer

## Deferred Ideas

- Headless/API OAuth for SPA/mobile (Phase 7)
- MFA session states on OAuth login (Phase 6)
- Email change with re-verification (Phase 8)
- SAML/enterprise SSO (out of scope v1)
