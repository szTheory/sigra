# Phase 2: Core Auth - Research

**Researched:** 2026-04-06
**Domain:** Email/password authentication, password hashing, bcrypt migration, magic links, password policy
**Confidence:** HIGH

## Summary

Phase 2 builds the core authentication operations on top of the Phase 1 foundation. The existing codebase provides `Sigra.Crypto` (hash/verify), `Sigra.Token` (signed + hashed tokens), `Sigra.Hasher` behaviour, `Sigra.Config`, `Sigra.Telemetry`, and the full install generator with EEx templates for User, UserToken, Auth context, SessionController, LiveViews, and UserAuth.

The work splits into three areas: (1) library modules -- `Sigra.Auth`, `Sigra.PasswordPolicy`, `Sigra.Email`, `Sigra.Hashers.Bcrypt`, and extensions to `Sigra.Crypto` and `Sigra.Config`; (2) updated generator templates -- migration columns, dual-mode login form, password strength feedback, controller templates, enumeration-safe registration; (3) comprehensive tests covering unit (library modules) and integration (Ecto Sandbox + Postgres).

**Primary recommendation:** Build library modules first (they have no Ecto/DB dependency for unit tests), then update generator templates, then integration tests. Keep `Sigra.Auth` as the orchestrator that accepts `repo` as an explicit argument per D-48.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Dual-mode auth: both password login and magic link always available on the same login page. Email link section at top, divider ("or"), email+password form below. Matches Phoenix 1.8 layout.
- **D-02:** Magic links work for login (existing users) AND confirmation (new registrations). Clicking confirms account + creates session.
- **D-03:** Token TTL: 10 minutes, single-use. Token in URL path: `/users/log-in/{token}`.
- **D-04:** Email delivery is stubbed in Phase 2 (generate token + URL, return to caller). Phase 3 adds Swoosh/Oban delivery.
- **D-05:** Rate limit magic link requests: max 3 per email per 15 minutes via RateLimiter behaviour.
- **D-06:** Prefix detection (`$2b$`/`$2a$`) to identify bcrypt hashes. Verify with bcrypt, re-hash with Argon2id on success.
- **D-07:** bcrypt_elixir is an optional dependency. `Code.ensure_loaded?` gate. Ship `Sigra.Hashers.Bcrypt` thin wrapper implementing Hasher behaviour.
- **D-08:** Stale bcrypt hashes left as-is indefinitely. Active users naturally upgrade on login.
- **D-09:** Three-way return from verify: `{:ok, :valid}` | `{:ok, :valid, new_hash}` | `{:error, :invalid}`. New hash signals caller should update DB.
- **D-10:** Hash upgrade logic lives in `Sigra.Crypto`. Generated context calls `Repo.update` when new hash returned.
- **D-11:** Also support Argon2id parameter upgrades: use `Argon2.needs_rehash?/2` to detect stale cost params, re-hash via same mechanism.
- **D-12:** Emit `[:sigra, :auth, :hash_upgraded]` telemetry event with `%{user_id: id, from: :bcrypt | :argon2id, to: :argon2id}`.
- **D-13:** Ship only Argon2id + bcrypt implementations. Hasher behaviour exists for testability (Mox), not algorithm plugins.
- **D-14:** Test bcrypt migration with pre-computed fixture hashes. No bcrypt_elixir dep needed in test.
- **D-15:** Library module: `Sigra.PasswordPolicy` in the library. Generated User schema's changeset calls `Sigra.PasswordPolicy.validate/2`.
- **D-16:** NIST defaults: min 8 chars, max 72 bytes. No composition rules by default, but configurable.
- **D-17:** HIBP breached password check: optional, off by default.
- **D-18:** Built-in strength analysis: `Sigra.PasswordPolicy.check_strength/1` returns `{:weak | :fair | :strong, suggestions}`.
- **D-19:** Separate function for strength (not in changeset). Apps call `check_strength/1` directly for UI hints.
- **D-20:** Optional password expiry: `:password_max_age` config (default nil = no expiry).
- **D-21:** No password history/reuse prevention.
- **D-22:** Same policy everywhere (no per-operation differentiation).
- **D-23:** Auto-login after registration.
- **D-24:** Email + password only in generated form. Clear extension points with comments.
- **D-25:** Phase 2 adds `:require_confirmation` config and check in login flow.
- **D-26:** Registration emits `[:sigra, :auth, :register, :stop]` telemetry event.
- **D-27:** Real-time password strength feedback via phx-change in generated registration LiveView.
- **D-28:** Email uniqueness validated on submit only (not real-time) to prevent enumeration.
- **D-29:** Duplicate email registration returns generic message. Enumeration-safe.
- **D-30:** Add `failed_login_attempts` (integer, default 0) and `locked_at` columns to users table. Also add `password_changed_at`.
- **D-31:** Phase 2 increments `failed_login_attempts` on failed login, resets to 0 on successful login.
- **D-32:** Per-account tracking only in DB. Per-IP rate limiting deferred to Phase 4.
- **D-33:** No increment for non-existent emails (dummy hash timing is sufficient).
- **D-34:** Successful login telemetry includes `failed_attempts_before` count.
- **D-35:** 32 bytes random via `:crypto.strong_rand_bytes(32)`, URL-safe base64 encoded.
- **D-36:** Cookie name: `_{otp_app}_user_session`. Matches phx.gen.auth convention.
- **D-37:** Minimal metadata in Phase 2: hashed_token, user_id, context, inserted_at.
- **D-38:** Default session TTL: 60 days, configurable via `:session_ttl`.
- **D-39:** Both layers: normalize in changeset AND use citext/collation at DB level.
- **D-40:** Unicode NFKC normalization via `String.normalize(:nfkc)`.
- **D-41:** No Gmail dot/plus-addressing stripping.
- **D-42:** Basic email format validation: `~r/^[^\s]+@[^\s]+$/`, max 160 chars.
- **D-43:** Normalization lives in library: `Sigra.Email.normalize/1`.
- **D-44:** Login failures always generic: "Invalid email or password".
- **D-45:** Registration: generic for email errors, specific for password errors.
- **D-46:** Error atoms are public documented API.
- **D-47:** Introduce `Sigra.Auth` as the orchestrator. Functions: `register/2`, `authenticate/2`, `create_session/2`, `verify_session/1`.
- **D-48:** Repo passed as argument: `Sigra.Auth.register(repo, attrs)`.
- **D-49:** User schema module derived from `Sigra.Config`.
- **D-50:** Unit tests for library modules + integration tests with Ecto Sandbox + Postgres.
- **D-51:** Ship `Sigra.Test.Support` module.
- **D-52:** Postgres in CI (primary). MySQL/SQLite as optional CI jobs.
- **D-53:** Controllers primary, LiveView optional.
- **D-54:** LiveView login uses `trigger_submit` to HTTP POST.
- **D-55:** Phase 2 adds missing controller templates.
- **D-56:** Modify Phase 1 migration template to include Phase 2 columns.
- **D-57:** Password policy config defaults specified.
- **D-58:** Magic link config defaults specified.
- **D-59:** Logout invalidates current session only.

### Claude's Discretion
- Internal implementation details of `Sigra.PasswordPolicy.check_strength/1` (exact scoring algorithm, suggestion text)
- Common password list source (SecLists or similar)
- HEEx template styling details for controller-mode auth pages
- Test helper API design in `Sigra.Test.Support`
- Exact Argon2id cost parameters within OWASP range

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| AUTH-01 | User can register with email and password | `Sigra.Auth.register/2` orchestrator + updated User schema template with `Sigra.PasswordPolicy.validate/2` and `Sigra.Email.normalize/1` calls. Registration changeset in generated code. |
| AUTH-02 | Passwords hashed with Argon2id (OWASP standard, 200-500ms target) | Existing `Sigra.Hashers.Argon2` already works. Default params: t_cost=3, m_cost=16 (64MB), parallelism=4. Test config: t_cost=1, m_cost=8. |
| AUTH-03 | Transparent password hash migration from bcrypt to Argon2id on login | New `Sigra.Hashers.Bcrypt` wrapper + `Sigra.Crypto.verify_with_upgrade/3` with three-way return. Prefix detection (`$2b$`/`$2a$`). bcrypt_elixir as optional dep. |
| AUTH-04 | User can log in with email and password | `Sigra.Auth.authenticate/2` + updated SessionController + updated LoginLive with dual-mode form. Failed attempt tracking. |
| AUTH-05 | User can log out from any page | Existing `UserAuth.log_out_user/1` + `SessionController.delete/2` already work. Add telemetry emission. |
| AUTH-06 | Magic link / passwordless email authentication | New magic link token type in UserToken, `Sigra.Auth.request_magic_link/2` + `Sigra.Auth.verify_magic_link/2`. Stubbed email delivery. Rate limiting via RateLimiter behaviour. |
| AUTH-07 | NIST-compliant password policies | New `Sigra.PasswordPolicy` module with `validate/2` (changeset), `check_strength/1` (standalone), `check_breached/1` (optional HIBP). Common password list embedded at compile time. |
</phase_requirements>

## Standard Stack

### Core (already in mix.exs)
| Library | Version | Purpose | Status |
|---------|---------|---------|--------|
| argon2_elixir | ~> 4.1 (4.1.3) | Argon2id password hashing | Already a dependency |
| comeonin | ~> 5.3 | Password hashing behaviour spec | Already a dependency |
| phoenix | ~> 1.8 (1.8.5) | Web framework | Already a dependency |
| ecto | ~> 3.12 (3.13.5) | Database interaction | Already a dependency |
| ecto_sql | ~> 3.12 | SQL adapter + migrations | Already a dependency |
| nimble_options | ~> 1.1 | Config validation | Already a dependency |

### New for Phase 2
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| bcrypt_elixir | ~> 3.3 (3.3.2) | Bcrypt verification for migration | Optional dep. Only loaded when host app has bcrypt users. |

**Installation change:**
```elixir
# Add to mix.exs deps
{:bcrypt_elixir, "~> 3.3", optional: true}
```

## Architecture Patterns

### New Library Modules
```
lib/sigra/
|-- auth.ex                    # Orchestrator: register/2, authenticate/2, create_session/2, verify_session/1
|-- email.ex                   # Email normalization: normalize/1 (trim + downcase + NFKC)
|-- password_policy.ex         # validate/2 (changeset), check_strength/1, check_breached/1
|-- password_policy/
|   |-- common_passwords.ex    # Compile-time embedded top 10k list
|-- crypto.ex                  # EXTEND: verify_with_upgrade/3, needs_rehash?/2
|-- config.ex                  # EXTEND: password_policy, magic_link, require_confirmation sections
|-- hashers/
|   |-- argon2.ex              # EXISTS
|   |-- bcrypt.ex              # NEW: optional bcrypt wrapper
```

### Updated Generator Templates
```
priv/templates/sigra.install/
|-- migration.exs              # UPDATE: add failed_login_attempts, locked_at, password_changed_at
|-- user.ex                    # UPDATE: call Sigra.PasswordPolicy.validate/2, Sigra.Email.normalize/1
|-- auth.ex                    # UPDATE: delegate security-critical ops to Sigra.Auth
|-- login_live.ex              # UPDATE: dual-mode form (magic link + password)
|-- registration_live.ex       # UPDATE: password strength feedback, enumeration-safe errors
|-- session_controller.ex      # UPDATE: handle magic link POST, hash upgrade on login
|-- login_html.ex              # NEW: controller-mode login HEEx template
|-- registration_html.ex       # NEW: controller-mode registration HEEx template
```

### Pattern 1: Sigra.Auth Orchestrator
**What:** Central library module that orchestrates auth operations, receiving repo as explicit argument.
**When to use:** All security-critical auth operations (register, authenticate, session creation/verification).
**Example:**
```elixir
defmodule Sigra.Auth do
  @doc "Registers a user with validated attrs. Returns {:ok, user} | {:error, changeset}."
  def register(repo, attrs, opts \\ []) do
    user_schema = Keyword.fetch!(opts, :user_schema)
    
    %user_schema{}
    |> user_schema.registration_changeset(attrs)
    |> repo.insert()
  end

  @doc "Authenticates by email+password. Returns {:ok, user} | {:error, :invalid_credentials}."
  def authenticate(repo, %{"email" => email, "password" => password}, opts \\ []) do
    user_schema = Keyword.fetch!(opts, :user_schema)
    user = repo.get_by(user_schema, email: email)

    case Sigra.Crypto.verify_with_upgrade(password, user && user.hashed_password) do
      {:ok, :valid} ->
        reset_failed_attempts(repo, user)
        {:ok, user}

      {:ok, :valid, new_hash} ->
        upgrade_hash(repo, user, new_hash)
        reset_failed_attempts(repo, user)
        {:ok, user}

      {:error, :invalid} ->
        increment_failed_attempts(repo, user)
        {:error, :invalid_credentials}
    end
  end
end
```

### Pattern 2: Three-Way Verify With Upgrade
**What:** `Sigra.Crypto.verify_with_upgrade/3` detects hash algorithm and parameter staleness, returns upgrade signal.
**When to use:** Every login attempt.
**Example:**
```elixir
defmodule Sigra.Crypto do
  @spec verify_with_upgrade(String.t(), String.t() | nil, keyword()) ::
          {:ok, :valid} | {:ok, :valid, String.t()} | {:error, :invalid}
  def verify_with_upgrade(password, nil, _opts) do
    no_user_verify()
    {:error, :invalid}
  end

  def verify_with_upgrade(password, hashed_password, opts \\ []) do
    cond do
      bcrypt_hash?(hashed_password) ->
        if bcrypt_verify(password, hashed_password) do
          new_hash = hash_password(password, opts)
          {:ok, :valid, new_hash}
        else
          {:error, :invalid}
        end

      argon2_hash?(hashed_password) ->
        if verify_password(password, hashed_password, opts) do
          if needs_rehash?(hashed_password, opts) do
            new_hash = hash_password(password, opts)
            {:ok, :valid, new_hash}
          else
            {:ok, :valid}
          end
        else
          {:error, :invalid}
        end

      true ->
        {:error, :invalid}
    end
  end

  defp bcrypt_hash?(hash), do: String.starts_with?(hash, "$2b$") or String.starts_with?(hash, "$2a$")
  defp argon2_hash?(hash), do: String.starts_with?(hash, "$argon2")
end
```

### Pattern 3: Password Policy as Changeset Validator
**What:** `Sigra.PasswordPolicy.validate/2` adds changeset errors; `check_strength/1` returns standalone assessment.
**When to use:** Registration and password change changesets call `validate/2`. LiveView phx-change handler calls `check_strength/1`.
**Example:**
```elixir
defmodule Sigra.PasswordPolicy do
  @default_opts [
    min_length: 8,
    max_bytes: 72,
    require_uppercase: false,
    require_digit: false,
    require_special: false,
    check_common: true,
    check_breached: false,
    password_max_age: nil
  ]

  @spec validate(Ecto.Changeset.t(), keyword()) :: Ecto.Changeset.t()
  def validate(changeset, opts \\ []) do
    opts = Keyword.merge(@default_opts, opts)
    password = Ecto.Changeset.get_change(changeset, :password)

    if password do
      changeset
      |> validate_length(password, opts)
      |> validate_composition(password, opts)
      |> validate_common(password, opts)
    else
      changeset
    end
  end

  @spec check_strength(String.t()) :: {:weak | :fair | :strong, [String.t()]}
  def check_strength(password) when is_binary(password) do
    # Analyze: length, repeated chars, sequential chars, common passwords
    {score, suggestions} = analyze(password)
    {strength_level(score), suggestions}
  end
end
```

### Pattern 4: Email Normalization
**What:** `Sigra.Email.normalize/1` applies trim + downcase + NFKC normalization.
**When to use:** In generated User changeset before validation.
**Example:**
```elixir
defmodule Sigra.Email do
  @spec normalize(String.t()) :: String.t()
  def normalize(email) when is_binary(email) do
    email
    |> String.trim()
    |> String.downcase()
    |> String.normalize(:nfkc)
  end
end
```

### Anti-Patterns to Avoid
- **Leaking precise errors to users:** Internal code uses `:invalid_credentials`, `:account_locked`, etc. but user-facing messages must always be generic via `Sigra.Error.safe_message/1`.
- **Real-time email uniqueness checks:** D-28 explicitly forbids this. Email uniqueness is validated on submit only to prevent enumeration.
- **Global state for config:** D-48 requires repo passed as argument. No `Application.get_env` for runtime config in library modules.
- **Raising on auth failures:** Auth operations return `{:ok, result}` | `{:error, reason}` tuples per D-19. Never raise on expected failures.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Password hashing | Custom hash functions | argon2_elixir + comeonin | Memory-hard, GPU/ASIC resistant, reference C implementation |
| Bcrypt verification | Custom bcrypt | bcrypt_elixir (optional dep) | Constant-time comparison, well-tested C NIF |
| Token signing | Custom HMAC | `Plug.Crypto.sign/4` and `Plug.Crypto.verify/4` | Battle-tested, Phoenix standard |
| Random bytes | `:rand` or Erlang `:random` | `:crypto.strong_rand_bytes/1` | Cryptographically secure PRNG |
| Constant-time compare | Manual byte comparison | `Plug.Crypto.secure_compare/2` | Prevents timing attacks |
| Email format validation | Complex RFC 5322 regex | Simple `~r/^[^\s]+@[^\s]+$/` + max 160 chars | Per D-42, no MX checks needed |
| HIBP breach check | Full database download | k-Anonymity API (range endpoint) | Only sends first 5 chars of SHA-1, preserves privacy |
| Common password list | Runtime file loading | Compile-time `@external_resource` + Module attribute | Zero runtime cost, embedded in BEAM |

## Common Pitfalls

### Pitfall 1: Argon2.needs_rehash? Does Not Exist
**What goes wrong:** D-11 references `Argon2.needs_rehash?/2` but argon2_elixir 4.1.3 does not provide this function.
**Why it happens:** The function exists in some other language implementations (e.g., PHP's `password_needs_rehash`) but not in Elixir's argon2_elixir.
**How to avoid:** Implement `Sigra.Crypto.needs_rehash?/2` manually by parsing the Argon2 hash string format: `$argon2id$v=19$m=65536,t=3,p=4$salt$hash`. Extract `m`, `t`, `p` values and compare against current configured parameters.
**Warning signs:** Compilation failure on `Argon2.needs_rehash?/2` call.

### Pitfall 2: Double Base64 Encoding in Token Generation
**What goes wrong:** The existing `UserToken.build_hashed_token/3` calls `Sigra.Token.generate_hashed_token/0` which returns a base64-encoded raw token, then wraps it in another `Base.url_encode64/2`. This produces a double-encoded token.
**Why it happens:** `generate_hashed_token/0` already base64-encodes the raw bytes. The template then re-encodes the result.
**How to avoid:** When adding magic link token generation, use the same pattern as existing `build_email_token/2` but be aware of the double-encoding. The double encoding is technically fine (token is opaque) but makes URLs longer. Keep consistent with existing pattern for now.
**Warning signs:** Unusually long token strings in URLs.

### Pitfall 3: Timing Side Channel on Failed Login Tracking
**What goes wrong:** D-33 says no increment for non-existent emails, but the DB update for `failed_login_attempts` on existing users takes measurable time.
**Why it happens:** `no_user_verify/0` takes the same time as a real hash check, but the subsequent DB write for failed_attempts creates a timing difference.
**How to avoid:** The dummy hash from `no_user_verify/0` already dominates the timing (200-500ms). The DB write (~1-5ms) is within noise. This is acceptable per OWASP guidelines. Do not add artificial delays.
**Warning signs:** If someone explicitly removes the `no_user_verify/0` call.

### Pitfall 4: NFKC Normalization Breaking Passwords
**What goes wrong:** Applying NFKC normalization to passwords could change the actual password value.
**Why it happens:** NFKC normalizes Unicode characters, which could transform a user's intended password.
**How to avoid:** D-39/D-40 specify NFKC normalization for **emails only**, never passwords. Passwords are byte strings -- validate byte length but never normalize content.
**Warning signs:** Password validation failing for Unicode passwords.

### Pitfall 5: Config Defaults Mismatch Between Config.ex and PasswordPolicy
**What goes wrong:** Phase 1's `Sigra.Config` has `min_length: 12` but D-16 specifies `min_length: 8` for the NIST-compliant password policy.
**Why it happens:** Phase 1 set a stricter default (12) following OWASP. Phase 2 context explicitly says NIST defaults are min 8.
**How to avoid:** The Config module's `:password` section controls hasher config. `Sigra.PasswordPolicy` has its own defaults per D-57. These are separate concerns: Config.password.min_length is the schema-level constraint, PasswordPolicy.validate/2 has its own opts. Reconcile by having the generated changeset use PasswordPolicy defaults (min 8), and remove or align the Config min_length accordingly.
**Warning signs:** Conflicting validation errors from two sources.

### Pitfall 6: Magic Link Token Context Collision
**What goes wrong:** Magic link tokens stored with context "magic_link" could collide with existing "confirm" or "reset_password" contexts if not properly scoped.
**Why it happens:** UserToken already has contexts for "session", "confirm", "reset_password", "change:*".
**How to avoid:** Use `"magic_link"` as the context string. The unique index is on `[:context, :token]`, so different contexts with same token value are fine. Add `days_for_context("magic_link")` clause to UserToken template.
**Warning signs:** Magic link verification returning wrong user or failing unexpectedly.

### Pitfall 7: Registration Enumeration via Changeset Errors
**What goes wrong:** If registration returns specific email uniqueness errors, attackers can enumerate registered emails.
**Why it happens:** Ecto's unique constraint violation returns a changeset error on the email field.
**How to avoid:** Per D-29, registration with duplicate email should return a generic success message. Two approaches: (1) catch the unique constraint error and return `{:ok, nil}` with generic flash, or (2) attempt insert and handle `{:error, changeset}` by checking for email uniqueness error and masking it. The generated Auth context should handle this.
**Warning signs:** "Email has already been taken" message visible to users.

## Code Examples

### Existing Code to Extend

#### Sigra.Crypto -- Add verify_with_upgrade/3 and needs_rehash?/2
```elixir
# Source: Existing lib/sigra/crypto.ex + D-09, D-11
# The hash format is: $argon2id$v=19$m=65536,t=3,p=4$salt$hash
# Parse m, t, p from the encoded hash to compare against current config.

def needs_rehash?(hashed_password, opts \\ []) do
  case parse_argon2_params(hashed_password) do
    {:ok, %{m: m, t: t, p: p}} ->
      current_m = Keyword.get(opts, :m_cost, Application.get_env(:argon2_elixir, :m_cost, 16))
      current_t = Keyword.get(opts, :t_cost, Application.get_env(:argon2_elixir, :t_cost, 3))
      current_p = Keyword.get(opts, :parallelism, Application.get_env(:argon2_elixir, :parallelism, 4))
      
      # m_cost is log2 in config but raw bytes in hash
      # Config m_cost=16 means 2^16 = 65536 bytes
      configured_m = :math.pow(2, current_m) |> round()
      
      m != configured_m or t != current_t or p != current_p

    :error ->
      true  # Can't parse = needs rehash
  end
end

defp parse_argon2_params(hash) do
  case Regex.run(~r/\$argon2\w+\$v=\d+\$m=(\d+),t=(\d+),p=(\d+)\$/, hash) do
    [_, m, t, p] ->
      {:ok, %{m: String.to_integer(m), t: String.to_integer(t), p: String.to_integer(p)}}
    _ ->
      :error
  end
end
```

#### Sigra.Config -- Extended Schema for Phase 2
```elixir
# Source: Existing lib/sigra/config.ex + D-57, D-58
# Add to @schema:
password_policy: [
  type: :keyword_list,
  default: [],
  keys: [
    min_length: [type: :pos_integer, default: 8],
    max_bytes: [type: :pos_integer, default: 72],
    require_uppercase: [type: :boolean, default: false],
    require_digit: [type: :boolean, default: false],
    require_special: [type: :boolean, default: false],
    check_common: [type: :boolean, default: true],
    check_breached: [type: :boolean, default: false],
    password_max_age: [type: {:or, [:pos_integer, nil]}, default: nil]
  ]
],
magic_link: [
  type: :keyword_list,
  default: [],
  keys: [
    ttl: [type: :pos_integer, default: 600],       # 10 minutes
    rate_limit: [type: {:tuple, [:pos_integer, :pos_integer]}, default: {3, 900_000}]  # 3 per 15 min
  ]
],
require_confirmation: [type: :boolean, default: false],
session_ttl: [type: :pos_integer, default: 60 * 24 * 60 * 60]  # 60 days
```

#### Migration Template -- New Columns
```elixir
# Source: D-30, D-56
# Add to users table in migration template:
add :failed_login_attempts, :integer, default: 0, null: false
add :locked_at, :utc_datetime
add :password_changed_at, :utc_datetime
```

#### Common Password List
```elixir
# Source: Claude's discretion
# Use SecLists top 10k or similar, embedded at compile time
defmodule Sigra.PasswordPolicy.CommonPasswords do
  @external_resource Path.join(__DIR__, "common_passwords.txt")
  
  @passwords File.read!(Path.join(__DIR__, "common_passwords.txt"))
             |> String.split("\n", trim: true)
             |> MapSet.new()
  
  def common?(password), do: MapSet.member?(@passwords, String.downcase(password))
end
```

#### Generated Auth Context -- Enumeration-Safe Registration
```elixir
# Source: D-29
def register_user(attrs) do
  %User{}
  |> User.registration_changeset(attrs)
  |> Repo.insert()
  |> case do
    {:ok, user} -> {:ok, user}
    {:error, %Ecto.Changeset{} = changeset} ->
      # If the only error is email uniqueness, mask it
      if email_taken?(changeset) do
        {:error, :email_taken}  # Caller shows generic message
      else
        {:error, changeset}  # Password errors are safe to show
      end
  end
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| bcrypt default | Argon2id default | OWASP 2023+ | Memory-hard, GPU/ASIC resistant. bcrypt still acceptable for migration. |
| Composition rules (uppercase + digit + special) | No composition rules (NIST 800-63B) | NIST 2017, reinforced 2024 | Users create memorable passwords. Check against breach lists instead. |
| Forced password rotation | No forced rotation unless breached | NIST 2017 | Rotation leads to weaker passwords (password1, password2, ...) |
| Password max 128+ chars | Max 72 bytes (bcrypt compat) | Practical limit | 72-byte max ensures bcrypt migration compatibility. Argon2 supports longer but consistency matters. |
| Session cookies only | DB-backed sessions with cookie reference | Phoenix 1.7+ | Enables session invalidation, tracking, "log out everywhere" |
| phx.gen.auth passwords only | Magic link + password dual-mode | Phoenix 1.8 (2025) | Phoenix 1.8 generates magic link auth by default |

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (built-in) |
| Config file | `test/test_helper.exs` (exists) |
| Quick run command | `mix test --only unit` |
| Full suite command | `mix test` |

### Phase Requirements --> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| AUTH-01 | Register with email/password, Argon2id hash stored | unit + integration | `mix test test/sigra/auth_test.exs --only register -x` | Wave 0 |
| AUTH-02 | Password hashed with Argon2id, 200-500ms target | unit | `mix test test/sigra/crypto_test.exs -x` | Exists (extend) |
| AUTH-03 | Bcrypt hash detected, verified, re-hashed to Argon2id | unit | `mix test test/sigra/crypto_test.exs --only upgrade -x` | Wave 0 |
| AUTH-04 | Login with email/password, session returned | unit + integration | `mix test test/sigra/auth_test.exs --only authenticate -x` | Wave 0 |
| AUTH-05 | Logout invalidates current session | integration | `mix test test/sigra/auth_test.exs --only logout -x` | Wave 0 |
| AUTH-06 | Magic link token generated, verified, single-use | unit | `mix test test/sigra/auth_test.exs --only magic_link -x` | Wave 0 |
| AUTH-07 | NIST password policy: min 8, no composition, common check | unit | `mix test test/sigra/password_policy_test.exs -x` | Wave 0 |

### Sampling Rate
- **Per task commit:** `mix test --only unit`
- **Per wave merge:** `mix test`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `test/sigra/auth_test.exs` -- covers AUTH-01, AUTH-04, AUTH-05, AUTH-06
- [ ] `test/sigra/password_policy_test.exs` -- covers AUTH-07
- [ ] `test/sigra/email_test.exs` -- covers email normalization
- [ ] `test/sigra/crypto_test.exs` -- extend existing with verify_with_upgrade tests (AUTH-02, AUTH-03)
- [ ] `priv/data/common_passwords.txt` -- top 10k common passwords file for compile-time embedding

## Open Questions

1. **Config.password.min_length (12) vs D-16 min_length (8)**
   - What we know: Phase 1 set min_length to 12 in Config. Phase 2 D-16 says NIST default is 8.
   - What's unclear: Should Config.password.min_length change to 8, or should PasswordPolicy be the sole source of truth for password length?
   - Recommendation: Make PasswordPolicy the authoritative source for password validation rules. Config.password section governs hasher selection only. Update the generated User changeset to call `Sigra.PasswordPolicy.validate/2` with the policy defaults, replacing the hardcoded `validate_length(:password, min: 12, max: 72)`. Config.password.min_length can be removed or reduced to 8 for alignment.

2. **Sigra.Auth function signatures -- config vs opts**
   - What we know: D-48 says repo passed as argument. D-49 says user_schema from Config.
   - What's unclear: Does `Sigra.Auth.authenticate/2` take `(repo, params)` with user_schema from Config, or `(repo, params, opts)` with user_schema in opts?
   - Recommendation: Use `Sigra.Auth.authenticate(repo, params, opts)` where `opts` includes `:user_schema`. The generated Auth context knows both repo and user_schema, so it passes them. This keeps the library free of global state.

3. **Common password list size and source**
   - What we know: D-18 says "top 10k, embedded at compile time". SecLists has several lists.
   - What's unclear: Exact source file and whether 10k is sufficient.
   - Recommendation: Use SecLists `10k-most-common.txt` (Daniel Miessler's list). 10k entries at ~8 bytes average = ~80KB compiled into BEAM. Acceptable size. Use MapSet for O(1) lookup.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir | All | Yes | 1.19.5 | -- |
| Erlang/OTP | All | Yes | 28 | -- |
| PostgreSQL | Integration tests | Verify at test time | -- | SQLite for local dev |
| argon2_elixir | AUTH-02 | Yes | 4.1.3 | -- |
| bcrypt_elixir | AUTH-03 | Not installed (optional) | -- | Pre-computed fixture hashes for testing per D-14 |

**Missing dependencies with no fallback:** None.

**Missing dependencies with fallback:**
- bcrypt_elixir: Not needed in test suite per D-14. Pre-computed bcrypt hashes used for testing migration path. Optional dep only needed at runtime in host apps with bcrypt users.

## Sources

### Primary (HIGH confidence)
- Existing codebase: `lib/sigra/crypto.ex`, `lib/sigra/hasher.ex`, `lib/sigra/hashers/argon2.ex`, `lib/sigra/token.ex`, `lib/sigra/config.ex`, `lib/sigra/error.ex`, `lib/sigra/telemetry.ex`, `lib/sigra/rate_limiter.ex`
- Existing templates: `priv/templates/sigra.install/*.ex`
- argon2_elixir 4.1.3 source: verified `needs_rehash?` does NOT exist; hash format verified as `$argon2id$v=19$m=65536,t=3,p=4$salt$hash`
- Phase 1 summaries: `01-01-SUMMARY.md`, `01-02-SUMMARY.md`, `01-03-SUMMARY.md`
- Phase 2 CONTEXT.md: all 59 decisions (D-01 through D-59)

### Secondary (MEDIUM confidence)
- bcrypt_elixir 3.3.2 on hex.pm: verified version via `mix hex.info`
- NIST SP 800-63B password guidelines: established standard, well-documented

### Tertiary (LOW confidence)
- SecLists common password list size estimate (~80KB for 10k entries): needs verification when file is downloaded

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- all dependencies already in mix.exs except bcrypt_elixir (verified on hex.pm)
- Architecture: HIGH -- extends well-understood existing patterns from Phase 1, clear module boundaries from CONTEXT decisions
- Pitfalls: HIGH -- verified `Argon2.needs_rehash?` absence directly against source code; timing analysis based on known Argon2 hash times

**Research date:** 2026-04-06
**Valid until:** 2026-05-06 (stable domain, unlikely to change)
