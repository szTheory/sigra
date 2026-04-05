# Pitfalls Research

**Domain:** Elixir/Phoenix authentication library (Sigra)
**Researched:** 2026-04-04
**Confidence:** HIGH (grounded in prior art post-mortems, security documentation, and ecosystem analysis)

---

## Critical Pitfalls

### Pitfall 1: Macro-Driven Schema Hiding (The Pow Trap)

**What goes wrong:**
A library uses `use MyLib.Schema` or similar macros to inject fields and behaviour into user schemas behind the scenes. The developer cannot see what columns exist without reading library internals. Schema introspection breaks. IDE tooling fails. Ecto changesets cannot be reasoned about without understanding library source. When the library diverges from the framework (as Pow did with Phoenix 1.8), users are locked in and cannot escape.

**Why it happens:**
Macros feel elegant at design time — one line of user code, many features unlocked. The temptation is to hide complexity behind a macro invocation. Devise inspired this pattern in the Rails world and it propagated into Elixir via Pow.

**How to avoid:**
All schema fields must appear directly in generated code. The library provides functions that operate on schemas (not macros that modify schemas). Generators write readable Ecto schemas to the developer's codebase. The user can read the full schema in their own file. Behaviours (not macros) define the contract. This is the explicit design stated in PROJECT.md: "No macro magic hiding schema fields."

**Warning signs:**
- Any `use Sigra.Schema` or `use Sigra.User` call that injects fields
- Schema files that don't list all columns explicitly
- Tests that fail when the user adds a field to their own schema
- Ecto query builders that reference fields the schema file doesn't show

**Phase to address:**
Phase 1 (core data layer) — the schema design is a foundation decision; changing it later requires a full rewrite.

---

### Pitfall 2: Pure Generator with No Security Patch Path (The phx.gen.auth Trap)

**What goes wrong:**
All security-critical code lives in generated files that the developer owns and modifies. When a vulnerability is found in token verification, password hashing parameters, or session handling, there is no way to ship a fix that users receive automatically. The developer must manually read the changelog, find the diff, and apply it to code they may have already customized. In practice, most developers never do this.

**Why it happens:**
Generators feel philosophically clean in the Elixir community ("own your code"). The fatal flaw is invisible at design time — it only manifests when the first CVE arrives 18 months after launch.

**How to avoid:**
Security-critical logic lives in the library (updated via `mix deps.update`): token generation/verification, HMAC operations, password hashing, TOTP validation, WebAuthn ceremonies, rate limiting. Customizable UX code lives in generated files: routes, LiveViews, controllers, mailer templates. The generated code calls into library functions for all security-sensitive operations. Security patches flow through dep updates; UI customizations stay in user code. This is the core hybrid architecture of Sigra.

**Warning signs:**
- Any cryptographic operation (hash, hmac, random token generation) that appears in generated files rather than library code
- Token validation logic duplicated in user-owned files
- A changelog entry that says "update your generated files to fix X" instead of "update your dep version"

**Phase to address:**
Phase 1 (architecture) — the boundary between library and generated code must be decided once and held. Adding library-side logic later means breaking changes for users who have already customized generated code that called ad-hoc implementations.

---

### Pitfall 3: JWT for Web Sessions (The Guardian Trap)

**What goes wrong:**
JWTs are used as the primary session mechanism for browser-based web apps. Logout becomes impossible without a server-side blocklist — which defeats the only advantage of JWTs (statelessness). When a password is changed or an admin force-logs-out a user, active sessions cannot be invalidated without either a full blocklist (same cost as opaque tokens) or waiting for token expiry. "Log out all devices" cannot be implemented correctly.

**Why it happens:**
JWT is widely talked about, Guardian is the well-known Elixir auth library, and developers copy patterns from SPA/API contexts into web app contexts without understanding the tradeoff. JWTs genuinely have merit in stateless API and microservice contexts — the mistake is using them for stateful web sessions.

**How to avoid:**
Opaque database-backed tokens for all browser sessions. JWTs for API authentication only, and only when the consumer is a stateless service where instant revocation is not required. For web sessions: random token in cookie, lookup record in `user_tokens` table. Deletion of the database record = instant revocation. "Log out everywhere" = `DELETE FROM user_tokens WHERE user_id = $1`. This is the `phx.gen.auth` pattern and it is correct.

**Warning signs:**
- `Guardian` as a dependency for session management (as opposed to API token verification)
- Session cookies containing encoded user data rather than an opaque reference
- Any flow where password change doesn't immediately invalidate all other sessions
- "Log out all devices" that requires waiting for token expiry

**Phase to address:**
Phase 1 (session architecture) — this cannot be retrofitted without a breaking schema change.

---

### Pitfall 4: Database Adapter Abstraction (The Lucia Trap)

**What goes wrong:**
The library tries to be database-agnostic by introducing an adapter abstraction layer (Ecto adapter, raw SQL adapter, etc.). The adapter API becomes the bottleneck for every new feature. Adding a new query capability requires updating all adapters. Edge cases in each adapter diverge silently. The adapter API ends up being too rigid to express what the library actually needs, and the entire design is constrained by what the lowest-common-denominator adapter can do. Lucia's maintainer explicitly cited this as the primary reason for deprecation: "database adapters were a significant complexity tax... adapters limit the API... everything felt clunky and fragile."

**How to avoid:**
Target Ecto as the only supported data layer. Ecto is the standard for Phoenix applications; there is no meaningful market in Phoenix projects that don't use Ecto. Provide PostgreSQL as the primary target with conditional migration generation for MySQL/SQLite where Ecto's adapter handles the differences naturally — do not build a Sigra-level adapter on top of Ecto. Ecto is already the adapter.

**Warning signs:**
- Any `@callback` or `@behaviour` on a module named `Repo`, `Store`, `Adapter`, or `Backend` that users would implement
- More than two distinct code paths for database operations (one per supported DB)
- Test helpers that require a "mock store" rather than using Ecto sandbox

**Phase to address:**
Phase 1 (data layer) — the Ecto-first decision must be locked in before any schema or query code is written.

---

### Pitfall 5: MFA as an Add-On, Not an Integrated Flow (The NimbleTOTP Trap)

**What goes wrong:**
TOTP validation is implemented as a standalone function (check the code, return valid/invalid), but the complete MFA lifecycle is left to the developer: enrollment UI, "pending MFA" session state, redirect to challenge page, backup code generation and storage, trust-this-browser cookie, enforcement policies, rate limiting on code attempts, and recovery flows. The developer must wire all of this together without guidance. Most developers get it wrong — particularly the "mfa_pending" session state, which gets skipped or forgotten.

**Why it happens:**
Libraries add "TOTP support" by wrapping an RFC 6238 implementation. This checks a box but solves maybe 10% of the problem. The other 90% is orchestration.

**How to avoid:**
MFA is a complete login state machine, not a function call. Model the states explicitly: `authenticated`, `mfa_pending`, `unauthenticated`. The `mfa_pending` state must block access to protected routes — not just redirect to the MFA page, but actually block. Rate limit MFA code attempts independently from password attempts (5 attempts, then 15-minute lockout). Backup codes are hashed before storage (SHA-256 or Argon2) and consumed atomically to prevent race conditions. Implement "trust this browser" as an encrypted cookie with user-specific HMAC so compromise of one user's trust cookie cannot be replayed for another user.

**Warning signs:**
- Routes that check `current_user` without checking `current_user.mfa_fully_authenticated`
- Backup codes stored in plaintext or with reversible encoding
- No rate limiting on the `/auth/mfa/verify` endpoint specifically
- MFA enrollment flow that doesn't require the user to confirm with a valid code before enabling (allows enabling with a misconfigured authenticator)
- TOTP window accepting more than ±1 step (the AuthQuake vulnerability — Microsoft's extended window gave 3% brute-force success per attempt)

**Phase to address:**
Phase of MFA implementation — design the session state machine before building any MFA feature.

---

### Pitfall 6: Email Enumeration via Inconsistent Responses

**What goes wrong:**
Password reset says "we sent an email" for known addresses but "no account with that email" for unknown addresses. Registration says "email already taken." Login failure distinguishes "wrong password" from "no such user." Together, these reveal the entire user database to any attacker willing to submit automated requests. For apps with paid plans or sensitive information, the user list itself is valuable.

**Why it happens:**
Helpful error messages feel like good UX. "Did you mean to register?" is well-intentioned. The security implication is easy to miss during development because you're testing with known accounts.

**How to avoid:**
All endpoints that accept an email address must return identical responses for "known email" and "unknown email" cases, measured by both HTTP status code and response body. For password reset: "if that address is registered, you'll receive an email" regardless of whether it exists. For registration: send a "you already have an account" email to existing addresses rather than showing an error. For login: "invalid email or password" never distinguishes which is wrong. Dummy hash computation for nonexistent users on login (to prevent timing-based enumeration). This must be implemented by default, not opt-in.

**Warning signs:**
- Login failure messages that differ based on whether the email exists
- Password reset page that shows different UI for existing vs. nonexistent email
- Registration that returns a validation error (rather than sending an email) for duplicate email
- Login endpoint with measurably different response times for existing vs. nonexistent users

**Phase to address:**
Phase 1 (core auth flows) — enumeration prevention must be baked in from the first implementation, not retrofitted.

---

### Pitfall 7: OAuth Account Linking Without Explicit Confirmation

**What goes wrong:**
A new OAuth login arrives with email `alice@example.com`. The library finds an existing user with that email and automatically links the OAuth identity, logging the user in. An attacker who controls an OAuth provider (or can register an email at that provider) can take over any account whose email they know. This is an account takeover via automatic identity merging.

**Why it happens:**
Auto-linking "just works" and is the simpler implementation. Most OAuth email claims are trustworthy (Google, GitHub), so developers trust them unconditionally.

**How to avoid:**
When an OAuth callback matches an existing email-based account, require explicit user confirmation before linking: send an email to the address saying "a new login method is being added to your account — click to confirm or deny." Never auto-link silently. Make the "confirm-required" vs "auto-link" behavior a configurable default, but default to confirmation-required. Additionally, some providers (GitHub with private email) return no email — define the explicit fallback behavior rather than silently failing or creating a user with a null email.

**Warning signs:**
- OAuth callback handler that does `find_or_create_user(email)` without prompting for confirmation when the user exists
- No email notification when a new OAuth provider is linked to an existing account
- No way for a user to review which OAuth providers are connected to their account

**Phase to address:**
Phase of OAuth implementation — the account linking strategy is an architectural decision for the OAuth callback.

---

### Pitfall 8: Scope Creep Causing Abandonment (The Devise Curse, Part 2)

**What goes wrong:**
Every reasonable feature request gets added. Organizations, RBAC, billing integration, SCIM, SAML, admin UI, impersonation, phone SMS OTP — one by one they all seem justified. The library becomes a monolith that's impossible to maintain. The original author burns out. Breaking changes in any one feature block upgrades for users who don't even use that feature. The library accumulates 40 configuration options and a 300-page wiki. New developers can't get started. Maintenance becomes full-time work.

**Why it happens:**
Auth touches everything in a web app. Every persona has a different definition of "complete." Saying no is harder than saying yes, especially when the requester proposes to implement the feature themselves.

**How to avoid:**
Draw hard lines at the design stage. Sigra's scope is defined in PROJECT.md and the "Out of Scope" list is explicit: no SAML, no OAuth IdP, no organizations (v1), no SCIM, no admin impersonation. Features that logically extend auth (authorization, billing, SCIM) must be separate libraries or explicit v2 milestones. Use the plugin architecture (behaviours + callbacks) to let community extensions exist without merging them into core. Every new feature proposal must pass: "is this authentication, or something built on top of authentication?"

**Warning signs:**
- PRs adding authorization logic (RBAC, permissions) to the auth library
- Configuration files growing beyond ~20 keys
- Features that only make sense given knowledge of the application's domain (i.e., not generic)
- Requests to add organization/tenant management before core auth flows are fully stable

**Phase to address:**
Ongoing — scope discipline is a process, not a phase. Establish it in Phase 1 and enforce it in every phase transition.

---

### Pitfall 9: Config Surface Designed for the Library Author, Not the Developer

**What goes wrong:**
Configuration is scattered across multiple `config.exs` keys, module-level options, environment variables, and runtime callbacks. To customize a token TTL, the developer must find it in three possible locations and understand override precedence. Devise's multi-layer configuration (initializer, model declaration, controller override, route configuration) is the cautionary example. When something doesn't work, there's no way to reason about what value is actually in effect.

**Why it happens:**
Libraries grow their config surface organically. Each new feature adds new config keys. Over time, no single developer holds the full mental model.

**How to avoid:**
Single, flat config module per application. Every option has a documented default. Config is validated at application startup with helpful errors (not runtime KeyErrors). Static options are defined at compile time; per-request dynamic behavior is expressed as callbacks in the config module, not separate config keys. Keep the total number of top-level config keys below 25 for the entire library. Follow the pattern shown in the JTBD doc's `AuthConfig` example: `use Sigra.Config` in one module, everything in one place.

**Warning signs:**
- Multiple different ways to set the same option (env var AND config.exs AND module option)
- Config values that shadow each other without documentation of precedence
- Error messages like "invalid configuration" with no indication of which key or valid values
- Startup succeeds with an invalid config that only fails at runtime

**Phase to address:**
Phase 1 (foundation) — validate the config API design before building any feature that depends on it.

---

### Pitfall 10: LiveView Session Mutation via LiveView Events

**What goes wrong:**
Login, logout, or email confirmation is implemented as a LiveView event handler (`handle_event`). Because `put_session/3` is only available on `Plug.Conn`, not on `Phoenix.LiveView.Socket`, this either silently fails to persist the session, requires a hack, or causes the user to appear logged in until the page refreshes (when the real session state is read). This is one of the most common mistakes for developers building LiveView auth from scratch.

**Why it happens:**
LiveView events feel like the natural place to handle form submissions in a LiveView form. The constraint about `put_session` is non-obvious and not prominently documented.

**How to avoid:**
All session-mutating actions (login, logout, email confirmation, MFA verify) must go through HTTP POST to a controller action that uses `put_session`. The pattern is: LiveView form with `phx-trigger-action` pointing to an HTTP controller action, controller handles the state mutation, then redirects back to a LiveView with the updated session. The library must provide ready-made controller modules for all session-mutating flows so developers don't have to implement this pattern themselves. Generated code must demonstrate the correct pattern.

**Warning signs:**
- `handle_event` for `"login"` or `"logout"` that calls `put_session`
- `handle_event` for session operations that uses `redirect` without going through a controller
- Tests for login that pass with a LiveView event but fail with a real browser

**Phase to address:**
Phase 1 (core auth flows) — all session-mutation patterns must be established correctly before MFA, OAuth, and other flows that compound the same pattern.

---

### Pitfall 11: Permanent Account Lockout as DoS Vector

**What goes wrong:**
Account lockout after N failed attempts is permanent (or requires admin intervention to unlock). An attacker who knows valid email addresses can lock out all accounts in an application by submitting N+1 failed login attempts per account. This is a denial-of-service attack that requires only knowledge of email addresses (which are often public).

**Why it happens:**
"Lock the account permanently" feels more secure. Developers model the threat as the attacker, not considering the attacker can turn lockout into a weapon against users.

**How to avoid:**
Lockout must be time-based and automatically self-releasing (default: 15 minutes). Never require admin intervention to unlock (except as an optional additional control for high-security apps). IP-based rate limiting provides the attacker-facing protection; account lockout provides the account-specific brute-force protection. These are two different controls. Implement both: IP rate limit blocks the attack vector, account lockout is a second layer for distributed attacks. Failed login counter resets on successful login, not on lockout expiry.

**Warning signs:**
- `locked_at` column with no corresponding "auto-unlock after duration" logic
- Account lockout that requires a support ticket or admin action to reverse
- No IP-based rate limiting separate from account-based lockout
- Error messages that distinguish "account locked" from "wrong password" (reveals enumeration of locked accounts)

**Phase to address:**
Phase of brute-force protection implementation.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| bcrypt-only password hashing | Simpler dependency list | No path to Argon2id; migration requires all users to log in | Never — start with Argon2id and a migration path |
| Plaintext token storage | No hashing step needed | Database breach exposes all active sessions | Never for any token |
| Skipping HMAC on email tokens | Simpler token generation | Leaked DB gives attacker valid reset/confirm tokens | Never — all email tokens must be HMAC-protected |
| Using process dictionary for current_user | Fast lookup without passing conn | Invisible state, untestable, breaks with async processes | Never |
| Hardcoded TOTP window of ±3 steps | "Works better" for clock drift | 3x larger attack surface; violates RFC recommendation | Never — use ±1 step, fix clock synchronization instead |
| Storing OAuth access tokens unencrypted | No encryption library dependency | Provider tokens exposed in database breach | Never for production; acceptable in dev/test only |
| Generating backup codes at login check time (not enrollment) | Simpler code | Race condition allows multiple code redemptions | Never — generate and store at enrollment, atomic consumption |
| Deferring telemetry to v2 | Ships faster | Impossible to diagnose production auth issues without it | Acceptable as a very early stub, but must ship before v1 |
| Single `user_tokens` table for all token types | Simple schema | Token type confusion attacks; hard to query/expire | Acceptable initially with strong `context` column indexing |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Oban for email delivery | Fire-and-forget without tracking job outcome | Use Oban's built-in error handling, retry with exponential backoff, and distinguish transient vs. permanent failures (bounce vs. timeout) |
| Assent (OAuth) | Trusting provider email claims unconditionally for account linking | Treat email claims as hints only; require explicit confirmation before linking to existing accounts |
| Swoosh mailer | Hardcoding the mailer module in library code | Accept mailer as config (behaviour pattern), allow developer to swap for test/production |
| Phoenix PubSub (socket disconnect) | Broadcasting on a topic the LiveView doesn't subscribe to | Library `on_mount` hook must subscribe to the correct topic; document the exact topic format |
| Wax (WebAuthn) | Storing the challenge in session without expiry | Challenges must be single-use and expire (60-second window); never reuse a challenge |
| NimbleTOTP | Using `NimbleTOTP.valid?/3` without rate limiting | TOTP validation must be wrapped in rate limiting — the cryptographic check alone is insufficient |
| Hammer (rate limiting) | Using only IP-based limiting | Run both IP-based and account-based limiters independently; a distributed attack from many IPs bypasses IP-only limiting |
| Ecto (email case sensitivity) | Storing and comparing emails without normalizing case | Use `citext` on PostgreSQL for case-insensitive email columns; lowercase before storage on other DBs |
| Phoenix Router (OAuth callbacks) | Registering all OAuth provider routes statically | Generate routes dynamically from configured providers, or provide a single catch-all route with provider as a path segment |
| Cloak/Vault (field encryption) | Encrypting fields that need to be queried | Only encrypt fields that are never queried directly (TOTP secrets, OAuth tokens); use hashing for queryable fields (API keys, session tokens) |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Unbounded `user_tokens` table growth | Slow login queries as token table grows | Background job (Oban) to purge expired tokens nightly; add `inserted_at` index | ~100K users with 30-day sessions = millions of rows without cleanup |
| Argon2id with default parameters too expensive | Login latency spikes under concurrent load | Tune memory/time parameters for 200-500ms on target hardware; benchmark during Phase 1 | ~50 concurrent logins saturating CPU on underpowered servers |
| N+1 on session listing | Session management UI loads slowly | Eager-load token metadata; paginate the session list | Users with 10+ active sessions |
| Loading full user struct on every request | Unnecessary DB queries for auth-only checks | Cache user in session or request assigns; distinguish "auth check" from "load user" | High-traffic apps with frequent unauthenticated requests |
| Audit log table as primary analytics store | Slow audit log queries degrade auth performance | Separate audit log writes to async Oban jobs; add heavy indexes to audit log; consider archiving old entries | ~1M events/month without proper indexing or async writes |
| Hammer ETS-based rate limiter in multi-node deployments | Rate limits not enforced across nodes | Use Hammer with a distributed backend (Redis via Hammer-Redis) or Cachex; document single-node vs. multi-node behavior | Any multi-node deployment relying on ETS-only rate limiting |

---

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Non-constant-time token comparison | Timing attack reveals valid tokens byte-by-byte | Use `:crypto.hash_equals/2` or equivalent for all token comparisons; never use `==` on security tokens |
| Missing `secure` flag on auth cookies in production | Session cookie readable over HTTP; MITM attack | Set `secure: true` by default; only disable in test environment |
| Missing `SameSite` on cookies | CSRF via cross-site form submission | Default `SameSite=Lax`; document when `Strict` or `None` is appropriate |
| TOTP secret stored without encryption | Database breach exposes all TOTP seeds | Encrypt TOTP secrets at rest with application-level encryption (Cloak); the encryption key is the real secret to protect |
| Reset token that doesn't expire (or has a long TTL) | Long window for attacker to use intercepted email | Default 60 minutes for password reset; 48 hours for email confirmation; enforce at query time, not just at token creation time |
| Treating the JWT `sub` claim as trusted without signature verification | Token forgery | Always verify the full JWT signature before trusting any claim; never decode-without-verify |
| Session fixation | Attacker pre-sets a session ID, user logs in, attacker hijacks session | Always regenerate session token on login (create a new token, invalidate the old one) |
| Missing CSRF protection on logout | CSRF logout attack (trivial but disruptive) | Logout must be a POST, not a GET; validate CSRF token |
| API key prefix collision | Multiple users' keys begin with same prefix, confusing lookup | Use cryptographically random suffixes of sufficient length (32+ bytes); prefix is for human recognition only, not uniqueness |
| Backup codes stored as-is or with weak hash | Single stolen backup code compromises account recovery permanently | Hash backup codes with SHA-256 or Argon2 before storage; display them exactly once |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Requiring email confirmation before any access | New users can't try the product; high drop-off on broken email flows | Allow limited access immediately; show persistent banner; block only sensitive operations |
| MFA enrollment with no recovery path shown | Users get locked out when they lose their phone | Display backup codes immediately at enrollment; require acknowledgment; offer recovery via email or admin |
| Password reset that logs out all devices silently | User reset their password, suddenly disconnected from mobile app mid-session | Invalidate all sessions on password change, but notify the user that other devices will be disconnected; allow the current session to persist if desired |
| "Trust this browser" with no user visibility | Users accumulate trusted devices with no way to review or revoke | Show trusted devices in security settings; allow per-device revocation |
| Generic "invalid credentials" with no guidance | Legitimate users who can't log in have no path forward | Keep message generic for security, but offer obvious "forgot password" and "resend confirmation" links in context |
| OAuth "link account" with confusing UX | Users create duplicate accounts, then can't link them | Detect email match at OAuth callback; guide through linking rather than creating a second account |
| No "something wrong? cancel this change" link in security emails | Legitimate users can't stop unauthorized changes | Every security notification email (email change, new OAuth linked, etc.) must include a cancel/revert link |
| Login redirect after auth that points to a dead URL | Users get 404 after successful login | Validate the `return_to` parameter against a safe-redirect allowlist; default to `/` if invalid |

---

## "Looks Done But Isn't" Checklist

- [ ] **Email confirmation:** Often missing resend rate limiting — verify that repeated resend requests are throttled (not a free email flooding vector)
- [ ] **Password reset:** Often missing single-use enforcement — verify that the same token cannot be used twice (token is deleted on first use, not on expiry)
- [ ] **OAuth callback:** Often missing CSRF state validation — verify that the `state` parameter is checked against the session on every callback
- [ ] **MFA verify:** Often missing rate limiting on code attempts — verify that 6+ wrong codes trigger a lockout on the MFA endpoint specifically
- [ ] **Session invalidation on password change:** Often only invalidates the session table record but not connected LiveView sockets — verify that PubSub broadcast triggers socket disconnect
- [ ] **API key issuance:** Often shows the key in the response but doesn't confirm it's shown only once — verify that the unhashed key is never stored and cannot be retrieved again
- [ ] **Account lockout:** Often missing the self-release mechanism — verify that locked accounts automatically release after the configured duration without admin intervention
- [ ] **Remember-me:** Often uses the same token table as sessions without distinguishing TTL — verify that remember-me tokens have their own `context` and their own longer TTL
- [ ] **Sudo mode:** Often checks `sudo_at` but doesn't re-check on sensitive route access within the window — verify that each sensitive route independently checks the sudo window
- [ ] **Email change:** Often sends confirmation to new email but doesn't notify old email — verify that both addresses receive notifications, and old address gets a cancel link
- [ ] **WebAuthn challenge:** Often generates a challenge but doesn't expire it — verify challenges are single-use and expire within 60 seconds
- [ ] **Backup codes at regeneration:** Often generates new codes but doesn't invalidate old codes atomically — verify old codes are deleted in the same transaction that creates new ones

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Macro schema hiding discovered after adoption | HIGH | Major version bump with migration guide; generator to convert existing schemas; long deprecation period |
| Pure generator architecture (no security patch path) | HIGH | Cannot be fixed without asking all users to adopt hybrid model; must be a major version break |
| JWT for web sessions baked into initial release | HIGH | Requires all users to migrate to opaque tokens; session format change; full release cycle |
| Ecto adapter abstraction added | MEDIUM | Remove adapter layer in next major version; users on non-Ecto adapters must migrate |
| Email enumeration shipped without prevention | MEDIUM | Fix in a point release; document what changed in UX (some users may notice different error messages) |
| Auto-linking OAuth without confirmation | HIGH | Security patch; notify users; any auto-linked accounts should be flagged for re-confirmation |
| MFA "pending" state bypass discovered | HIGH | Security patch with urgency; rotate sessions; audit whether any accounts bypassed MFA in logs |
| Permanent lockout as DoS discovered | MEDIUM | Point release changing lockout to time-based; no user data migration required |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Macro schema hiding | Phase 1 (foundation/schema design) | Schema files in user project show all columns explicitly |
| Pure generator / no security patch path | Phase 1 (architecture) | All cryptographic operations call into library modules, not generated code |
| JWT for web sessions | Phase 1 (session architecture) | Session tokens are opaque, database-backed; no JWT in session cookies |
| Database adapter abstraction | Phase 1 (data layer) | Only Ecto used; no `@behaviour` for storage adapters |
| MFA as bolted-on function | Phase of MFA (before any MFA feature) | Session state machine has explicit `mfa_pending` state; routes block it |
| Email enumeration | Phase 1 (core auth flows) | Identical HTTP response for existing and non-existing email on all endpoints |
| OAuth auto-linking | Phase of OAuth implementation | Account linking requires email confirmation; no silent merge |
| Scope creep | All phases | "Out of Scope" list reviewed at every phase transition |
| Config surface complexity | Phase 1 (config design) | Single `use Sigra.Config` module; validated at startup |
| LiveView session mutation | Phase 1 (core auth flows) | All session-mutating flows go through HTTP controllers; zero `put_session` in LiveView handlers |
| Permanent lockout DoS | Phase of brute-force protection | Lockout has self-release timer; IP rate limiting is independent |
| TOTP timing window too wide | Phase of MFA implementation | ±1 step window enforced; rate limiting on MFA verify endpoint |

---

## Sources

- Lucia auth deprecation discussion (maintainer): https://github.com/lucia-auth/lucia/discussions/1707 and https://github.com/lucia-auth/lucia/discussions/1714 — adapter complexity as primary failure mode
- Pow changelog and version constraints — explicit `phoenix < 1.8.0` dependency block
- Rodauth design documentation — encapsulated auth object, per-feature tables, HMAC tokens, feature self-containment
- Django Allauth source and documentation — account linking with confirmation, email notification patterns
- OWASP Authentication Cheat Sheet: https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html
- AuthQuake (Microsoft MFA brute force via extended TOTP window): https://workos.com/blog/authquake-microsofts-mfa-system-vulnerable-to-totp-brute-force-attack
- Common TOTP mistakes guide: https://www.authgear.com/post/5-common-totp-mistakes
- Paragon Initiative (password reset token security): https://paragonie.com/blog/2016/09/untangling-forget-me-knot-secure-account-recovery-made-simple
- Paragon Initiative (timing attacks in HMAC): https://paragonie.com/blog/2015/11/preventing-timing-attacks-on-string-comparison-with-double-hmac-strategy
- OAuth common vulnerabilities (Doyensec, 2025): https://blog.doyensec.com/2025/01/30/oauth-common-vulnerabilities.html
- RFC 9700 (OAuth 2.0 security best current practice): https://www.rfc-editor.org/rfc/rfc9700.html
- Phoenix LiveView security model: https://hexdocs.pm/phoenix_live_view/security-model.html
- phx-trigger-action guide: https://fly.io/phoenix-files/phx-trigger-action/
- SuperTokens JWT session mistakes: https://supertokens.com/blog/are-you-using-jwts-for-user-sessions-in-the-correct-way
- Prompts directory: `Building the gold-standard Elixir/Phoenix authentication library.md`, `Phoenix Auth Library — Jobs to Be Done, Personas & User Flows.md`, `biggest-gaps-elixir-auth.md`, `Auth Domain Language — A Field Guide.md`
- PROJECT.md: `Sigra` project requirements, constraints, and key decisions

---
*Pitfalls research for: Elixir/Phoenix authentication library (Sigra)*
*Researched: 2026-04-04*
