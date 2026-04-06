# Phase 2: Core Auth - Context

**Gathered:** 2026-04-06
**Status:** Ready for planning

<domain>
## Phase Boundary

Email/password registration, login, logout, Argon2id hashing, bcrypt migration, magic link authentication, and NIST-compliant password policies. A developer's users can register, log in (with password or magic link), and log out, with passwords hashed using Argon2id and enumeration prevention on by default.

</domain>

<decisions>
## Implementation Decisions

### Magic Link Strategy
- **D-01:** Dual-mode auth: both password login and magic link always available on the same login page. Email link section at top, divider ("or"), email+password form below. Matches Phoenix 1.8 layout.
- **D-02:** Magic links work for login (existing users) AND confirmation (new registrations). Clicking confirms account + creates session.
- **D-03:** Token TTL: 10 minutes, single-use. Token in URL path: `/users/log-in/{token}`.
- **D-04:** Email delivery is stubbed in Phase 2 (generate token + URL, return to caller). Phase 3 adds Swoosh/Oban delivery.
- **D-05:** Rate limit magic link requests: max 3 per email per 15 minutes via RateLimiter behaviour.

### Bcrypt Migration
- **D-06:** Prefix detection (`$2b$`/`$2a$`) to identify bcrypt hashes. Verify with bcrypt, re-hash with Argon2id on success.
- **D-07:** bcrypt_elixir is an optional dependency. `Code.ensure_loaded?` gate. Ship `Sigra.Hashers.Bcrypt` thin wrapper implementing Hasher behaviour.
- **D-08:** Stale bcrypt hashes left as-is indefinitely. Active users naturally upgrade on login.
- **D-09:** Three-way return from verify: `{:ok, :valid}` | `{:ok, :valid, new_hash}` | `{:error, :invalid}`. New hash signals caller should update DB.
- **D-10:** Hash upgrade logic lives in `Sigra.Crypto`. Generated context calls `Repo.update` when new hash returned. Best-effort, non-transactional.
- **D-11:** Also support Argon2id parameter upgrades: use `Argon2.needs_rehash?/2` to detect stale cost params, re-hash via same mechanism.
- **D-12:** Emit `[:sigra, :auth, :hash_upgraded]` telemetry event with `%{user_id: id, from: :bcrypt | :argon2id, to: :argon2id}`.
- **D-13:** Ship only Argon2id + bcrypt implementations. Hasher behaviour exists for testability (Mox), not algorithm plugins.
- **D-14:** Test bcrypt migration with pre-computed fixture hashes. No bcrypt_elixir dep needed in test.

### Password Policy
- **D-15:** Library module: `Sigra.PasswordPolicy` in the library. Generated User schema's changeset calls `Sigra.PasswordPolicy.validate/2`.
- **D-16:** NIST defaults: min 8 chars, max 72 bytes. No composition rules by default, but configurable (`require_uppercase`, `require_digit`, `require_special` all false by default).
- **D-17:** HIBP breached password check: optional, off by default. `Sigra.PasswordPolicy.check_breached/1` calls k-Anonymity API.
- **D-18:** Built-in strength analysis: `Sigra.PasswordPolicy.check_strength/1` returns `{:weak | :fair | :strong, suggestions}`. Checks: length, repeated chars, sequential chars, common passwords (top 10k, embedded at compile time).
- **D-19:** Separate function for strength (not in changeset). Apps call `check_strength/1` directly for UI hints.
- **D-20:** Optional password expiry: `:password_max_age` config (default nil = no expiry). Flag stale passwords on login when set.
- **D-21:** No password history/reuse prevention.
- **D-22:** Same policy everywhere (no per-operation differentiation).

### Registration Flow
- **D-23:** Auto-login after registration. Session created, redirect to signed-in path. Confirmation email sent in background (Phase 3).
- **D-24:** Email + password only in generated form. Clear extension points with comments showing how to add custom fields (name, company, etc.) to changeset and form.
- **D-25:** Phase 2 adds `:require_confirmation` config and check in login flow. When true + unconfirmed, login returns `{:error, :unconfirmed}`. Phase 3 adds email delivery and confirmation endpoint.
- **D-26:** Registration emits `[:sigra, :auth, :register, :stop]` telemetry event with `%{user_id: id}`.
- **D-27:** Real-time password strength feedback via phx-change in generated registration LiveView. Uses `Sigra.PasswordPolicy.check_strength/1` on server.
- **D-28:** Email uniqueness validated on submit only (not real-time) to prevent enumeration.
- **D-29:** Duplicate email registration returns generic message: "If this email is available, your account has been created." Enumeration-safe.

### Login Attempt Tracking
- **D-30:** Add `failed_login_attempts` (integer, default 0) and `locked_at` columns to users table in Phase 1 migration template. Also add `password_changed_at` (utc_datetime, nullable).
- **D-31:** Phase 2 increments `failed_login_attempts` on failed login, resets to 0 on successful login. Phase 4 adds lockout threshold check.
- **D-32:** Per-account tracking only in DB. Per-IP rate limiting deferred to Phase 4 (Hammer).
- **D-33:** No increment for non-existent emails (dummy hash timing is sufficient for enumeration prevention).
- **D-34:** Successful login telemetry includes `failed_attempts_before` count in metadata.

### Session Token Format
- **D-35:** 32 bytes random via `:crypto.strong_rand_bytes(32)`, URL-safe base64 encoded (43 chars).
- **D-36:** Cookie name: `_{otp_app}_user_session`. Matches phx.gen.auth convention.
- **D-37:** Minimal metadata in Phase 2: hashed_token, user_id, context, inserted_at. Phase 4 adds IP, user_agent, last_active.
- **D-38:** Default session TTL: 60 days, configurable via `:session_ttl`.

### Email Normalization
- **D-39:** Both layers: normalize in changeset (trim + downcase + NFKC) AND use citext/collation at DB level. Belt and suspenders.
- **D-40:** Unicode NFKC normalization via `String.normalize(:nfkc)`. Prevents lookalike character attacks.
- **D-41:** No Gmail dot/plus-addressing stripping. Intentional use preserved.
- **D-42:** Basic email format validation: `~r/^[^\s]+@[^\s]+$/`, max 160 chars. No MX record checks.
- **D-43:** Normalization lives in library: `Sigra.Email.normalize/1`. Generated changeset calls it.

### Error Message Strategy
- **D-44:** Login failures always generic: "Invalid email or password" for all cases (wrong email, wrong password, locked). Internal error atoms are precise.
- **D-45:** Registration: generic for email errors, specific for password errors. Password feedback doesn't leak information.
- **D-46:** Error atoms are public documented API: `:invalid_credentials`, `:account_locked`, `:token_expired`, `:unconfirmed`, `:rate_limited`. Apps can pattern match.

### Sigra.Auth Library Module
- **D-47:** Introduce `Sigra.Auth` in the library as the orchestrator. Functions: `register/2`, `authenticate/2`, `create_session/2`, `verify_session/1`. Generated `MyApp.Auth` delegates to it for security-critical logic.
- **D-48:** Repo passed as argument: `Sigra.Auth.register(repo, attrs)`. Explicit, no global state.
- **D-49:** User schema module derived from `Sigra.Config` (set in config.exs by generator). Not passed on every call.

### Testing Strategy
- **D-50:** Unit tests for library modules (Crypto, PasswordPolicy, Email) + integration tests with Ecto Sandbox + Postgres.
- **D-51:** Ship `Sigra.Test.Support` module for library's own integration tests.
- **D-52:** Postgres in CI (primary). MySQL/SQLite as optional CI jobs.

### LiveView vs Controller Auth
- **D-53:** Controllers primary, LiveView optional. `--live` generates LiveView pages, `--no-live` generates controllers + HEEx templates.
- **D-54:** LiveView login uses `trigger_submit` to HTTP POST to SessionController. Session cookie set via HTTP response.
- **D-55:** Phase 2 adds missing controller templates: registration_controller.ex, login/registration HEEx templates.

### Migration Strategy
- **D-56:** Modify Phase 1 migration template to include Phase 2 columns (failed_login_attempts, locked_at, password_changed_at). No users yet — we're building the library. New installs get one clean migration.

### Config Defaults
- **D-57:** Password policy: min_length: 8, max_bytes: 72, require_uppercase: false, require_digit: false, require_special: false, check_common: true, check_breached: false, password_max_age: nil.
- **D-58:** Magic link: magic_link_ttl: 600 (10min), magic_link_rate_limit: {3, 15 minutes}, require_confirmation: false.

### Logout
- **D-59:** Logout invalidates current session only. "Log out everywhere" is Phase 4.

### Claude's Discretion
- Internal implementation details of `Sigra.PasswordPolicy.check_strength/1` (exact scoring algorithm, suggestion text)
- Common password list source (SecLists or similar)
- HEEx template styling details for controller-mode auth pages
- Test helper API design in `Sigra.Test.Support`
- Exact Argon2id cost parameters within OWASP range

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project specifications
- `.planning/PROJECT.md` -- Vision, architecture philosophy, hybrid lib+generator rationale
- `.planning/REQUIREMENTS.md` -- AUTH-01 through AUTH-07 requirements
- `.planning/ROADMAP.md` SS Phase 2 -- Goal, success criteria, requirement mapping

### Phase 1 context
- `.planning/phases/01-foundation/01-CONTEXT.md` -- All Phase 1 decisions (D-01 through D-53). Critical: D-12 (Hasher behaviour), D-19 (error patterns), D-43 (naming conventions), D-49 (token strategies), D-50 (security defaults)
- `.planning/phases/01-foundation/01-01-SUMMARY.md` -- Core library modules built
- `.planning/phases/01-foundation/01-02-SUMMARY.md` -- Telemetry + plugs built
- `.planning/phases/01-foundation/01-03-SUMMARY.md` -- Generator built

### Existing code to extend
- `lib/sigra/crypto.ex` -- Password hashing (add verify_with_upgrade, bcrypt detection)
- `lib/sigra/hasher.ex` -- Hasher behaviour (implement Bcrypt wrapper)
- `lib/sigra/token.ex` -- Token operations (magic link tokens)
- `lib/sigra/config.ex` -- Config system (add password policy, magic link, session config)
- `priv/templates/sigra.install/` -- Generator templates (update migration, add controller templates)
- `lib/mix/tasks/sigra.install.ex` -- Generator task (update for new templates)

### Research documents
- `prompts/Building the gold-standard Elixir:Phoenix authentication library.md` -- Ecosystem analysis, prior art
- `CLAUDE.md` SS Technology Stack -- Dependency versions, compatibility matrix

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Sigra.Crypto` -- Already has hash_password/1, verify_password/2, no_user_verify/0. Extend with upgrade detection.
- `Sigra.Token` -- Has generate_hashed_token/0, sign/verify. Use for session and magic link tokens.
- `Sigra.Hasher` behaviour -- 3 callbacks ready. Add Bcrypt implementation.
- `Sigra.Telemetry` -- Event catalog + span/3, event/3. Use for auth operation events.
- `Sigra.Config` -- NimbleOptions validated. Extend schema with password/session/magic_link sections.
- `Sigra.Error` -- 5 exception types with safe_message/1. Add auth-specific errors.
- Generated `auth.ex` template -- Already has register_user, get_user_by_email_and_password, session token functions. Refactor to delegate to Sigra.Auth.

### Established Patterns
- `{:ok, result}` | `{:error, reason}` everywhere (D-19)
- Behaviours for extensibility, default implementations (D-12, D-13)
- Telemetry span for sync ops, events for signals (D-15, D-18)
- NimbleOptions for all config validation (D-05)
- EEx templates with host app override support (D-09)

### Integration Points
- Generated `auth.ex` context delegates to new `Sigra.Auth` library module
- Generated `user.ex` changeset calls `Sigra.PasswordPolicy.validate/2` and `Sigra.Email.normalize/1`
- Generated `session_controller.ex` handles both password and magic link POST
- Login LiveView / HEEx shows dual-mode form (magic link + password)
- Migration template updated with new columns

</code_context>

<specifics>
## Specific Ideas

- Phoenix 1.8 gen.auth layout for login page: email link section at top, divider, password form below
- Real-time password strength feedback in registration LiveView via phx-change
- Generated code should have clear "# Add custom fields here" comments for easy extension
- NIST SP 800-63B compliance as the default stance (no composition rules, no rotation)

</specifics>

<deferred>
## Deferred Ideas

None -- discussion stayed within phase scope.

</deferred>

---

*Phase: 02-core-auth*
*Context gathered: 2026-04-06*
