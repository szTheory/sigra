---
phase: 17-invitation-flow-email
plan: 02
subsystem: token, organizations-config, migration-template
tags: [sigra, token, hmac, nimble-options, migration, invite-envelope]
requires: ["17-01"]
provides:
  - "Sigra.Token.generate_invite_envelope/2"
  - "Sigra.Token.verify_invite_envelope/3"
  - "@org_config_schema Phase 17 keys (invitation_ttl, invitation_rate_limit_per_user, invitation_rate_limit_per_org, invitation_cleanup_retention_days, emails_module, secret_key_base, url_builder)"
  - "Sigra.Organizations.__warn_long_invitation_ttl__/1"
  - "unique_index on organization_invitations.hashed_token (both postgres and mysql/sqlite branches)"
affects:
  - lib/sigra/token.ex
  - lib/sigra/organizations.ex
  - priv/templates/sigra.install/organizations/migration.exs
  - test/sigra/token_test.exs
  - test/sigra/organizations/config_test.exs
tech-stack:
  added: []
  patterns:
    - "String-keyed HMAC payload map (atom-flood defense)"
    - "Plug.Crypto.sign with per-purpose salt binding non-token identity into envelope"
    - "NimbleOptions tuple-or-infinity rate limit spec type"
key-files:
  created:
    - test/sigra/organizations/config_test.exs
  modified:
    - lib/sigra/token.ex
    - lib/sigra/organizations.ex
    - priv/templates/sigra.install/organizations/migration.exs
    - test/sigra/token_test.exs
decisions:
  - "Re-hash base64 raw token inside generate_invite_envelope/2 rather than reuse generate_hashed_token/0's raw-bytes hash, so hash_token(raw) at verify time matches the stored hash"
  - "Config tests live in a new test/sigra/organizations/config_test.exs (not extended organizations_test.exs which does not exist — continues Plan 17-01 deviation pattern)"
  - "Apply unique_index on hashed_token to BOTH postgres and mysql/sqlite branches (plan text only explicitly called out the postgres branch via line 57, but the mysql/sqlite branch had an identical non-unique index at line 134; defense-in-depth must hold on all adapters)"
metrics:
  duration: "~15 minutes"
  completed: "2026-04-14"
  tasks: 3
  commits: 4
  tests_added: 11
  tests_total: 1645
---

# Phase 17 Plan 02: Invite Envelope + Config Schema + Unique Index Summary

**One-liner:** Shipped the email-into-HMAC invite envelope primitive (closes Jetstream #907 / Keycloak CVE-2026-1529 class by construction), extended `@org_config_schema` with 7 Phase 17 keys + a long-TTL dev warning helper, and tightened `organization_invitations.hashed_token` to a unique index on both adapter branches.

## Function signatures shipped

```elixir
# lib/sigra/token.ex

@spec generate_invite_envelope(String.t(), String.t()) :: {String.t(), binary()}
def generate_invite_envelope(secret_key_base, email)
# Returns {encoded_signed_token, hashed_token_for_storage}
# Signs %{"t" => raw_base64_token, "e" => String.downcase(email)} with
# purpose "sigra-org-invite-token" via Plug.Crypto.sign/3.
# Stored `hashed` == :crypto.hash(:sha256, raw_base64_token).

@spec verify_invite_envelope(String.t(), String.t(), pos_integer()) ::
        {:ok, %{raw_token: binary(), bound_email: String.t(), hashed_token: binary()}}
        | {:error, :invalid | :expired}
def verify_invite_envelope(secret_key_base, encoded, max_age_seconds)
# base64 decode fail → {:error, :invalid}
# HMAC verify fail → {:error, :invalid}
# Payload shape mismatch (not %{"t" => _, "e" => _}) → {:error, :invalid}
# Plug.Crypto.verify returns :expired → {:error, :expired}
# Success → {:ok, %{raw_token, bound_email, hashed_token}} — all binaries
```

## Config keys added (for Plan 17-03+)

| Key | Default | Type |
|---|---|---|
| `invitation_ttl` | `:timer.hours(24 * 7)` (7 days) | `:pos_integer` |
| `invitation_rate_limit_per_user` | `{20, :timer.hours(24)}` | `{:pos_integer, :pos_integer} \| :infinity` |
| `invitation_rate_limit_per_org` | `{50, :timer.hours(24)}` | `{:pos_integer, :pos_integer} \| :infinity` |
| `invitation_cleanup_retention_days` | `30` | `:pos_integer` |
| `emails_module` | `nil` | `:atom \| nil` |
| `secret_key_base` | `nil` | `:string \| nil` |
| `url_builder` | `nil` | `(String.t() -> String.t()) \| nil` |

`Sigra.Organizations.__warn_long_invitation_ttl__/1` logs a
`Logger.warning` with day-count and phishing-window guidance when
`config.invitation_ttl > :timer.hours(24 * 30)`. Returns `:ok` unconditionally
(never blocks runtime). To be called from `Invitations.create/2` in Plan 17-03.

## Migration template change

`priv/templates/sigra.install/organizations/migration.exs`:

- **Line 57 (postgres branch):** `create index(:organization_invitations, [:hashed_token])` → `create unique_index(...)`
- **Line 134 (mysql/sqlite branch):** same change applied to the non-postgres `def up`

**Partial-unique pending index preserved:** `organization_invitations_pending_index` at lines 52–55 is untouched — the `IS NULL` predicate stays IMMUTABLE-safe (D-03).

**No `now()` in any predicate introduced.** `grep -n "now()" priv/templates/sigra.install/organizations/migration.exs` still only matches the pre-existing Phase 16 slug-alias partial index at line 76, which is intentional (and not touched by this plan).

## Test additions

**`test/sigra/token_test.exs` (+8 tests in new describe block):**
1. round-trip to `{:ok, %{raw_token, bound_email, hashed_token}}`
2. downcases bound email on generate
3. rejects tampered payload with `:invalid` (flip one byte inside signed blob)
4. rejects wrong purpose with `:invalid`
5. returns `:expired` past `max_age` (sleep 1.1s + `max_age: 1`)
6. returns `:invalid` for base64 garbage
7. returns `:invalid` for wrong payload shape (raw binary vs map)
8. decoded payload uses only string keys (atom-flood defense)

**`test/sigra/organizations/config_test.exs` (NEW file, +11 tests):**
- 7 tests for per-key defaults (`invitation_ttl` through `url_builder`)
- 3 `__warn_long_invitation_ttl__/1` tests (warns >30d, silent at 30d, silent at default 7d)
- Uses `ExUnit.CaptureLog.capture_log/1` for warning assertion

## Deviations from Plan

**1. [Rule 1 - Bug] Hash mismatch between generate and verify**

- **Found during:** Task 1 GREEN first test run
- **Issue:** `Sigra.Token.generate_hashed_token/0` returns `{Base.url_encode64(raw_bytes), :crypto.hash(:sha256, raw_bytes)}` — the hash is over the RAW BYTES, but the envelope stores `raw = the base64 string` in the payload and `verify_invite_envelope/3` computes `hash_token(raw)` which is `sha256(base64_string)`. First test failed with `got_hashed == hashed` assertion mismatch.
- **Fix:** In `generate_invite_envelope/2`, ignore the second element of `generate_hashed_token/0` and recompute `hashed = hash_token(raw)` so the stored hash is consistent with what `verify_invite_envelope/3` and downstream accept lookups will compute. Added explicit comment explaining the divergence.
- **Files modified:** `lib/sigra/token.ex`
- **Commit:** `ca745c8`

**2. [Rule 3 - Blocking] `Bitwise.bxor` module path**

- **Found during:** Task 1 RED compile
- **Issue:** Test tamper helper used bare `bxor/2` which is not auto-imported in test modules. Compile failed with "undefined function bxor/2".
- **Fix:** Replaced with fully qualified `Bitwise.bxor/2` inline.
- **Files modified:** `test/sigra/token_test.exs` (during RED iteration — in the same commit as the other test additions)
- **Commit:** `7ea40e3`

**3. [Rule 2 - Critical] Unique index applied to BOTH adapter branches**

- **Found during:** Task 3
- **Issue:** Plan prose in Task 3 only called out the postgres branch (line ~57). The migration template has a second `create index(:organization_invitations, [:hashed_token])` at line 134 in the MySQL/SQLite `def up`. Leaving the mysql/sqlite branch non-unique would break the "hashed_token → invitation is a function" load-bearing invariant on half the supported adapters.
- **Fix:** Applied `unique_index` to both occurrences. The plan's acceptance criterion `grep -c "create index(:organization_invitations, \[:hashed_token\])" = 0` only passes after both are replaced.
- **Files modified:** `priv/templates/sigra.install/organizations/migration.exs`
- **Commit:** `b90a27a`

**4. Config tests placed in new `config_test.exs` file**

- **Found during:** Task 2
- **Issue:** Plan referenced `test/sigra/organizations_test.exs` which does not exist (same pattern hit by Plan 17-01 deviation 3). `context_test.exs` is already busy with Mox-based `add_member_multi` etc. and doesn't need unrelated config-schema tests appended.
- **Fix:** Created `test/sigra/organizations/config_test.exs` as a new focused test file. Consistent with the library convention of splitting by topic.
- **Files modified:** `test/sigra/organizations/config_test.exs` (new)
- **Commit:** `17beb69`

**5. Worktree rebase to 9b8be0d base**

- **Found during:** Pre-execution worktree branch check
- **Issue:** Worktree branch `worktree-agent-a78c40ec` was based on `4efb4a5` (Phase 11) per `git log HEAD`, but filesystem contained a stale mix of files from some later state. Soft-reset to `9b8be0d1f5c598cff7cd5e336ab7ff62774a4146` showed 217 staged delete markers — the filesystem was not coherent with any single commit.
- **Fix:** `git reset --soft 9b8be0d`, then `git reset HEAD`, `git checkout -- .`, `git clean -fd` to materialize a working tree that exactly matches `9b8be0d` (Phase 17 Plan 01 landed state). No library code was modified as part of the rebase.

## Auth Gates

None — fully autonomous, no external verification needed.

## Commits (in order)

| Commit    | Type | Summary                                                                |
| --------- | ---- | ---------------------------------------------------------------------- |
| `7ea40e3` | test | RED — 8 failing tests for generate/verify_invite_envelope              |
| `ca745c8` | feat | GREEN — implement invite envelope helpers with string-keyed payload    |
| `17beb69` | feat | Extend @org_config_schema with 7 Phase 17 keys + __warn_long_ttl__ helper |
| `b90a27a` | chore| Make organization_invitations.hashed_token index unique (both adapters) |

## Verification Results

```
mix compile --warnings-as-errors                          → clean
mix test test/sigra/token_test.exs                        → 23/23 passing (+8 new)
mix test test/sigra/organizations/config_test.exs         → 11/11 passing
mix test test/sigra/organizations/context_test.exs        → 50/50 passing (untouched)
mix test                                                  → 33 doctests, 3 properties, 1645 tests, 0 failures
```

Acceptance criteria per task:

| Check | Result |
|---|---|
| `grep -n "def generate_invite_envelope" lib/sigra/token.ex` | 1 match (line 139) |
| `grep -n "def verify_invite_envelope" lib/sigra/token.ex` | 1 match (line 167) |
| `grep -n "sigra-org-invite-token" lib/sigra/token.ex` | 1 match (module attribute) |
| `grep -n "\"t\" => raw, \"e\" =>" lib/sigra/token.ex` | 1 match (string-keyed payload) |
| `grep -c "verify_invite_envelope" test/sigra/token_test.exs` | ≥ 8 |
| `grep -n ":expired" test/sigra/token_test.exs` | 2 matches (expiry test) |
| `grep -n "invitation_ttl:" lib/sigra/organizations.ex` | 1 match |
| `grep -n "invitation_rate_limit_per_user:" lib/sigra/organizations.ex` | 1 match |
| `grep -n "invitation_rate_limit_per_org:" lib/sigra/organizations.ex` | 1 match |
| `grep -n "invitation_cleanup_retention_days:" lib/sigra/organizations.ex` | 1 match |
| `grep -n "emails_module:" lib/sigra/organizations.ex` | 1 match |
| `grep -n "secret_key_base:" lib/sigra/organizations.ex` | 1 match |
| `grep -n "url_builder:" lib/sigra/organizations.ex` | 1 match |
| `grep -n "def __warn_long_invitation_ttl__" lib/sigra/organizations.ex` | 1 match |
| `grep -n ":timer.hours(24 \\* 7)" lib/sigra/organizations.ex` | 1 match (7-day default) |
| `grep -n "unique_index(:organization_invitations, \[:hashed_token\])" migration.exs` | 2 matches (both adapter branches) |
| `grep -n "create index(:organization_invitations, \[:hashed_token\])" migration.exs` | 0 matches |
| `grep -n "organization_invitations_pending_index" migration.exs` | 1 match (preserved) |

## Known Stubs

None. Both helpers are the real implementation — `generate_invite_envelope/2` and `verify_invite_envelope/3` will be consumed directly by `Sigra.Organizations.Invitations.create/2` in Plan 17-03 and `accept/3` + `accept_with_signup/3` in Plan 17-05. The config keys land with working defaults and the `__warn_long_invitation_ttl__/1` helper is exported (via `@doc false`) for Plan 17-03's `create/2` to invoke on first-use.

## Self-Check: PASSED

**Modified files verified via grep:**

- FOUND: `def generate_invite_envelope` in lib/sigra/token.ex
- FOUND: `def verify_invite_envelope` in lib/sigra/token.ex
- FOUND: `sigra-org-invite-token` in lib/sigra/token.ex
- FOUND: `"t" => raw, "e" =>` in lib/sigra/token.ex
- FOUND: `invitation_ttl:` in lib/sigra/organizations.ex
- FOUND: `__warn_long_invitation_ttl__` in lib/sigra/organizations.ex
- FOUND: 2× `unique_index(:organization_invitations, [:hashed_token])` in migration.exs
- FOUND: 0× non-unique `create index(:organization_invitations, [:hashed_token])` in migration.exs

**Created files:**

- FOUND: test/sigra/organizations/config_test.exs

**Commits:**

- FOUND: 7ea40e3 (test RED — invite envelope tests)
- FOUND: ca745c8 (feat GREEN — envelope helpers)
- FOUND: 17beb69 (feat — @org_config_schema + warn helper)
- FOUND: b90a27a (chore — unique_index on hashed_token)
