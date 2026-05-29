# Phase 137: Optional-Dependency Source of Truth - Pattern Map

**Mapped:** 2026-05-29
**Files analyzed:** 13 (1 new lib module + 1 new test + ~11 modified call sites across 12 files)
**Analogs found:** 13 / 13 (all in-repo)

> Scope note: the design is LOCKED (D-01..D-10). This map hands the planner
> ready-to-cite house-style excerpts and exact before/after call-site text.
> It does NOT redesign. Library code (not generated) per CLAUDE.md lib-vs-gen split.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/sigra/optional_deps.ex` (NEW) | utility (flat predicate module) | transform (config/load → boolean) | `lib/sigra/rate_limiter.ex` (style+location) | role-match (location/style only — NOT a behaviour triad) |
| `test/sigra/optional_deps_test.exs` (NEW) | test | request-response | `test/sigra/audit/forwarders/noop_test.exs` (thin-module unit test) + `test/sigra/upgrade_test.exs:229-260` (encryption fixture) | exact |
| `lib/sigra/crypto.ex:244` (MOD) | utility | transform | self (in-place load-half swap) | exact |
| `lib/sigra/hashers/bcrypt.ex:39,48` (MOD) | utility | transform | `lib/sigra/crypto.ex:244` | exact |
| `lib/sigra/mfa.ex:1059` (MOD) | service | transform | `lib/sigra/crypto.ex:244` | exact |
| `lib/sigra/jwt/signer.ex:18` (MOD) | utility (raise-guard) | request-response | `lib/sigra/oauth/strategies/apple.ex:76` | exact |
| `lib/sigra/plug/rate_limit.ex:85` (MOD) | middleware | request-response | `lib/sigra/crypto.ex:244` | role-match |
| `lib/sigra/oauth/strategies/{apple,facebook,github,generic,google}.ex` (MOD) | service (raise-guard) | request-response | `lib/sigra/oauth/strategies/apple.ex:76` | exact (5 identical sites) |
| `lib/sigra/delivery.ex:114` (MOD, compound) | service | event-driven | self (load-half only) | exact |
| `lib/sigra/audit/forwarders.ex:99` (MOD, compound) | service | event-driven | `lib/sigra/delivery.ex:114` | exact |
| `lib/sigra/enterprise_connections/validation.ex:91` (MOD, compound) | service | request-response | `lib/sigra/delivery.ex:114` (compound pattern) | role-match |
| `lib/sigra/account/deletion.ex:307` (MOD, compound `with`) | service | event-driven | `lib/sigra/delivery.ex:114` | role-match (leg 308 NOT touched) |

Bucket B/C/D files (workers/*.ex:1, threadline.ex:1, credo/*.ex, testing.ex, dynamic-module guards) are **NOT modified** — fenced out below.

## Pattern Assignments

---

### `lib/sigra/optional_deps.ex` (NEW — utility, flat predicate module)

**Analog (style + location ONLY):** `lib/sigra/rate_limiter.ex` — top-level `Sigra.` sibling.
**IMPORTANT:** `Sigra.OptionalDeps` is a SINGLE FLAT module, NOT a behaviour+impl+Noop
triad. The triad is the precedent for *where a new top-level `Sigra.` module lives* and
*the `@moduledoc` voice* — do not generate a behaviour or Noop sibling.

**House-style `@moduledoc` + module shape to mirror** (`lib/sigra/rate_limiter.ex:1-26`):
```elixir
defmodule Sigra.RateLimiter do
  @moduledoc """
  Behaviour for rate limiting implementations.

  Sigra supports both IP-based and account-based rate limiting. When
  Hammer is available, `Sigra.RateLimiters.Hammer` provides the
  implementation. When Hammer is absent, `Sigra.RateLimiters.Noop`
  is used as a fail-open fallback with a logged warning.
  ...
  """

  @doc "Checks whether a request identified by `key` should be allowed."
  @doc since: "0.1.0"
  @callback check_rate(...) :: ...
end
```
Note the conventions to copy: prose `@moduledoc` with usage context, `@doc since: "0.1.0"`,
explicit `@spec`/`@callback` on every public function. For the flat predicate module use
`@spec name() :: boolean()` + `def name, do: Code.ensure_loaded?(Mod)`.

**Predicate body shape (D-01/D-03, from RESEARCH.md Code Examples):**
```elixir
@spec oban_available?() :: boolean()
def oban_available?, do: Code.ensure_loaded?(Oban)
```
Nine flat predicates: `oban_available?` (`Oban`), `bcrypt_available?` (`Bcrypt`),
`eqrcode_available?` (`EQRCode`), `threadline_available?` (`Threadline`),
`assent_available?` (`Assent`), `swoosh_available?` (`Swoosh`),
`joken_available?` (`Joken`), `hammer_available?` (`Hammer`), `req_available?` (`Req`).

**`@moduledoc` MUST carry the D-05 scope note** (these strings are load-bearing for the
Phase 140 verifier): scope is RUNTIME call-site guards only; compile-time `defmodule`
wrappers (`workers/*.ex`, `audit/forwarders/threadline.ex`) stay literal and do NOT
delegate (D-04); encryption is config-driven not load-driven (D-07).

---

### Encryption predicate (D-07) — MIRROR the config check, do NOT load-check

**Analog (source of truth to mirror):** `lib/sigra/application.ex:184-230` `verify_vault!/1`
+ `encrypted_binary_module/1`. The SOT predicate must reproduce this exact logic, NOT
`Code.ensure_loaded?(Cloak)`.

**The operative stub-vs-real check** (`lib/sigra/application.ex:191-205`):
```elixir
module ->
  Code.ensure_loaded?(module)   # side-effecting load attempt on host's Encrypted.Binary

  if function_exported?(module, :__sigra_encryption_mode__, 0) and
       module.__sigra_encryption_mode__() == :stub do
    raise """
    [Sigra] passkeys are enabled but #{inspect(module)} is still the plaintext stub.
    ...
    """
  end
```

**The module-derivation helper to replicate** (`lib/sigra/application.ex:218-230`):
```elixir
defp encrypted_binary_module(host_sigra) do
  case Keyword.get(host_sigra, :user_schema) do
    module when is_atom(module) and not is_nil(module) ->
      module
      |> Module.split()
      |> Enum.drop(-1)
      |> Kernel.++(["Encrypted", "Binary"])
      |> Module.concat()

    _ ->
      nil
  end
end
```

**Predicate to write** (name `encryption_active?/1` is planner discretion per D-07):
```elixir
@spec encryption_active?(keyword()) :: boolean()
def encryption_active?(host_sigra) when is_list(host_sigra) do
  case encrypted_binary_module(host_sigra) do   # same derivation as application.ex:218
    nil -> false
    module ->
      function_exported?(module, :__sigra_encryption_mode__, 0) and
        module.__sigra_encryption_mode__() != :stub
  end
end
```
**Critical truth-value note:** the predicate returns `true` for ACTIVE (real vault),
`false` for STUB/absent. The mirror is `!= :stub` (NOT `== :real`). The live code's
non-stub value is `:vault` — see `application.ex:194` checks `== :stub` only, and the
existing test fixture (`upgrade_test.exs:235`) uses `def __sigra_encryption_mode__, do: :vault`.
A bare `cloak_available?/0` load check is FORBIDDEN (D-07 — silent security regression).

---

### `lib/sigra/crypto.ex:244` (controller of bcrypt fallback — Bcrypt)

**Self-analog (in-place load-half swap).** Current (`crypto.ex:243-252`):
```elixir
defp bcrypt_verify(password, hashed_password) do
  if Code.ensure_loaded?(Bcrypt) do
    Sigra.Hashers.Bcrypt.verify_password(password, hashed_password)
  else
    # bcrypt_elixir not available -- cannot verify bcrypt hashes
    no_user_verify()
    false
  end
end
```
After: replace `if Code.ensure_loaded?(Bcrypt) do` → `if Sigra.OptionalDeps.bcrypt_available?() do`.
The else-branch (`no_user_verify(); false`) stays BYTE-EQUIVALENT (timing-protection
security control — Security Domain V2/timing).

---

### `lib/sigra/hashers/bcrypt.ex:39,48` (Bcrypt — DRIFT, not in CONTEXT.md but in scope)

**Analog:** `crypto.ex:244`. Two sites:
- `:39` — `if Code.ensure_loaded?(Bcrypt) do` (in `no_user_verify/0`, else falls back to Argon2 timing) → `if Sigra.OptionalDeps.bcrypt_available?() do`
- `:48` — `unless Code.ensure_loaded?(Bcrypt) do` (in `ensure_loaded!/0` raise guard) → `unless Sigra.OptionalDeps.bcrypt_available?() do`

---

### `lib/sigra/mfa.ex:1059` (EQRCode)

`if Code.ensure_loaded?(EQRCode) do` (in `generate_qr_svg/1`, else returns `nil`)
→ `if Sigra.OptionalDeps.eqrcode_available?() do`. Else-branch (`nil`) unchanged.

---

### Raise-guard pattern (jwt/signer + 5 oauth strategies)

**Analog (canonical raise-guard shape):** `lib/sigra/oauth/strategies/apple.ex:74-81`:
```elixir
@spec ensure_assent!() :: :ok
def ensure_assent! do
  unless Code.ensure_loaded?(Assent) do
    raise "Assent is required for OAuth. Add {:assent, \"~> 0.3\"} to mix.exs and run: mix deps.get"
  end
  :ok
end
```
- `jwt/signer.ex:18` — `unless Code.ensure_loaded?(Joken) do` → `unless Sigra.OptionalDeps.joken_available?() do`. Raise block preserved (Security V/Tampering: must still raise on absence).
- `oauth/strategies/{apple:76, facebook:80, github:77, generic:83, google:74}.ex` — all identical `unless Code.ensure_loaded?(Assent) do` → `unless Sigra.OptionalDeps.assent_available?() do`. Raise block preserved.

---

### `lib/sigra/plug/rate_limit.ex:85` (Hammer)

`if Code.ensure_loaded?(Hammer) do` (in `resolve_limiter(nil)`, else → `Sigra.RateLimiters.Noop` + warn)
→ `if Sigra.OptionalDeps.hammer_available?() do`. Else-branch (Noop fallback) unchanged.

---

### Compound-guard split (D-06) — DELEGATE LOAD HALF ONLY

**Analog:** `lib/sigra/delivery.ex:110-115` (the canonical compound pattern with its
explanatory comment):
```elixir
# :auto must only route to :async when Oban is actually supervised in the
# host app — not merely compiled/loadable. Apps that add `{:oban, ...}` to
# mix.exs without wiring the supervisor would otherwise crash on insert.
defp oban_running? do
  Code.ensure_loaded?(Oban) and Process.whereis(Oban) != nil
end
```
After: `Sigra.OptionalDeps.oban_available?() and Process.whereis(Oban) != nil`.
The `and Process.whereis(Oban) != nil` liveness half STAYS at the call site (D-06 / Pitfall 4)
— and KEEP the explanatory comment.

- `delivery.ex:114` — delegate `Code.ensure_loaded?(Oban)` leg only.
- `audit/forwarders.ex:90-101` — `oban_running?/1` is a `case`. Delegate ONLY the `:error`
  (production) branch at line 99:
  ```elixir
  :error ->
    # Production path: mirrors lib/sigra/delivery.ex:113-115 byte-for-byte
    Code.ensure_loaded?(Oban) and Process.whereis(Oban) != nil
  ```
  → `Sigra.OptionalDeps.oban_available?() and Process.whereis(Oban) != nil`.
  **DO NOT touch the `{:ok, oban_override}` branch (line 94)** — it has no `Code.ensure_loaded?`
  (override is a named process, not a module) — Pitfall 2. Update the byte-for-byte mirror
  comment (97-98) since it now references the delegated form.
- `enterprise_connections/validation.ex:91` — `Code.ensure_loaded?(Req) and function_exported?(Req, :get, 1)`
  → `Sigra.OptionalDeps.req_available?() and function_exported?(Req, :get, 1)`. Keep `function_exported?` half.
- `account/deletion.ex:307` — `with true <- Code.ensure_loaded?(Oban),`
  → `with true <- Sigra.OptionalDeps.oban_available?(),`. **Leave line 308 LITERAL**
  (`Code.ensure_loaded?(Sigra.Workers.AccountDeletion)` is an internal conditionally-compiled
  worker, Bucket C — Pitfall 3 / Open Question 2). The `with` structure stays.

---

## Shared Patterns

### Delegation rewrite (applies to ALL Bucket A sites)
**Mechanical:** replace the literal `Code.ensure_loaded?(NamedMod)` token with
`Sigra.OptionalDeps.<dep>_available?()`. Nothing else on the line changes. Branch bodies,
raise blocks, else-clauses, and liveness halves are byte-preserved. This one-to-one swap
IS the OD-02 no-behavior-change proof.

### `@doc since:` + `@spec` discipline
**Source:** `lib/sigra/rate_limiter.ex:22-25`. Every public predicate gets `@spec name() :: boolean()`.

### Compile-coupling avoidance (DO NOT replicate into the SOT, but be aware)
**Source:** `lib/sigra/audit/forwarders.ex:133-137` (`@worker_module` + `apply/3` + `no_warn_undefined`).
This is why D-04 fences the `defmodule` wrappers out — the SOT references the very modules
those wrappers gate, so routing a compile-time guard through the SOT risks compile-ordering
circularity. The SOT itself needs NO such apply/3 indirection (its `Code.ensure_loaded?/1`
takes a module atom → no compile warning, D-10, no new `mix.exs:65-91` whitelist entries).

---

### `test/sigra/optional_deps_test.exs` (NEW — test)

**Analog 1 (thin-module unit-test voice):** `test/sigra/audit/forwarders/noop_test.exs:1-50`:
```elixir
defmodule Sigra.Audit.Forwarders.NoopTest do
  use ExUnit.Case, async: true

  describe "Sigra.Audit.Forwarders.Noop.attach/1" do
    test "returns :ok — D-22" do
      assert Sigra.Audit.Forwarders.Noop.attach([]) == :ok
    end
  end
end
```
Copy: `use ExUnit.Case, async: true`, AAA voice, `describe` per public function, decision-ID
references in test names. No DB needed (SOT unit tests are pure).

**Predicate test strategy (RESEARCH.md Validation Architecture):** assert each predicate
EQUALS a freshly-evaluated `Code.ensure_loaded?(Mod)` (drift-catching tautology that stays
valid in dep-off env), NOT a hardcoded `true`. All deps present in `library_tests` lane →
truthy branch; Threadline dep-off lane (`ci.yml:170`) exercises the one falsy branch.

**Analog 2 (encryption-mode fixture):** `test/sigra/upgrade_test.exs:229-260` — copy the
in-test fixture-module pattern exactly:
```elixir
describe "encryption_active?/1" do
  defmodule StubVault.Encrypted.Binary do
    def __sigra_encryption_mode__, do: :stub
  end
  defmodule RealVault.Encrypted.Binary do
    def __sigra_encryption_mode__, do: :vault
  end
  defmodule StubVault.User, do: nil   # only the *.Encrypted.Binary sibling matters
  defmodule RealVault.User, do: nil

  test "returns false for stub mode" do
    refute Sigra.OptionalDeps.encryption_active?(user_schema: StubVault.User)
  end
  test "returns true for real vault mode" do
    assert Sigra.OptionalDeps.encryption_active?(user_schema: RealVault.User)
  end
end
```
Note: derivation drops the last segment of `user_schema` and appends `Encrypted.Binary`
(application.ex:218-225) — so the fixture's `*.User` schema yields `*.Encrypted.Binary`.
Use `:vault` (not `:real`) for the active fixture to match live convention.

---

## No Analog Found

None. Every new/modified file maps to an in-repo precedent.

## DO-NOT-TOUCH Set (fenced out — Buckets B/C/D, D-04/D-08)

| File:line | Guard | Bucket | Why fenced |
|-----------|-------|--------|------------|
| `lib/sigra/workers/account_deletion.ex:1` | `if Code.ensure_loaded?(Oban.Worker) do` | B | compile-time `defmodule` wrapper (D-04) |
| `lib/sigra/workers/audit_cleanup.ex:1` | `if Code.ensure_loaded?(Oban.Worker) do` | B | same |
| `lib/sigra/workers/audit_forward.ex:1` | `if Code.ensure_loaded?(Oban.Worker) do` | B | same |
| `lib/sigra/workers/cleanup_expired_invitations.ex:1` | `if Code.ensure_loaded?(Oban.Worker) do` | B | same |
| `lib/sigra/workers/email_delivery.ex:1` | `if Code.ensure_loaded?(Oban.Worker) do` | B | same |
| `lib/sigra/workers/token_cleanup.ex:1` | `if Code.ensure_loaded?(Oban.Worker) do` | B | same |
| `lib/sigra/audit/forwarders/threadline.ex:1` | `if Code.ensure_loaded?(Threadline) do` | B | same |
| `lib/sigra/account/deletion.ex:308` | `Code.ensure_loaded?(Sigra.Workers.AccountDeletion)` | C | internal conditionally-compiled worker, not a named dep (Pitfall 3) |
| `lib/sigra/audit/forwarders.ex:94` (`{:ok, override}` branch) | (no ensure_loaded?) | — | test-override branch; must not change (Pitfall 2) |
| `lib/sigra/admin/{audit/export.ex:169, users/detail.ex:270, users/query.ex:718}` | `Code.ensure_loaded?(schema)` | C | dynamic variable (host schema) |
| `lib/sigra/application.ex:108,154` | `Code.ensure_loaded?(module)` | C | dynamic variable |
| `lib/sigra/application.ex:192` | `Code.ensure_loaded?(module)` | C | part of D-07 encryption check; dynamic host module, NOT a load gate |
| `lib/sigra/application.ex:77` | `Code.ensure_loaded?(Oban) ->` | C (judgment) | boot-warning `cond`. **Open Question 1 — DEFAULT: leave literal** (minimal phase). Planner decides; note in `@moduledoc` if left literal. |
| `lib/sigra/workers/audit_forward.ex:174` | `if Code.ensure_loaded?(module) do` | C | dynamic variable |
| `lib/mix/tasks/sigra.install.ex:153` | `Code.ensure_loaded?(repo_module)` | C | dynamic variable (host repo) |
| `lib/sigra/credo/no_log_safe2_in_lib.ex:1` | `if Code.ensure_loaded?(Credo.Check) do` | D | tooling wrapper |
| `lib/sigra/credo/no_unscoped_org_query_in_lib.ex:1` | `if Code.ensure_loaded?(Credo.Check) do` | D | tooling wrapper |
| `lib/mix/tasks/sigra.fixture.rebless_golden.ex:86` | `unless Code.ensure_loaded?(InstallFixture) do` | D | test-helper guard |
| `lib/sigra/testing.ex:98` | `if Code.ensure_loaded?(Swoosh.TestAssertions) do` | D | test-helper guard (only Swoosh ensure_loaded? in lib/; `swoosh_available?/0` is SOT-completeness only) |

## Metadata

**Analog search scope:** `lib/sigra/` (rate_limiter triad, application.ex, all Bucket A call sites), `test/sigra/` (noop_test, upgrade_test verify_vault fixtures).
**Files scanned:** rate_limiter.ex, rate_limiters/noop.ex, application.ex (180-231), delivery.ex (105-116), audit/forwarders.ex (78-137), crypto.ex (240-254), jwt/signer.ex (12-26), oauth/strategies/apple.ex (72-85), test/sigra/audit/forwarders/noop_test.exs, test/sigra/upgrade_test.exs (229-261).
**Pattern extraction date:** 2026-05-29
