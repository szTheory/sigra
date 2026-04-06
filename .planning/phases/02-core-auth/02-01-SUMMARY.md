---
phase: 02-core-auth
plan: 01
subsystem: auth
tags: [argon2, bcrypt, email, password-policy, nist, nfkc, hibp, nimble-options]

# Dependency graph
requires:
  - phase: 01-foundation
    provides: "Sigra.Crypto, Sigra.Hasher behaviour, Sigra.Config with NimbleOptions, Sigra.Hashers.Argon2"
provides:
  - "Sigra.Email with normalize/1 and validate_format/1"
  - "Sigra.PasswordPolicy with validate/2, check_strength/1, check_breached/1"
  - "Sigra.PasswordPolicy.CommonPasswords with compile-time 10k password list"
  - "Sigra.Hashers.Bcrypt with Code.ensure_loaded? gate for optional bcrypt"
  - "Sigra.Crypto.verify_with_upgrade/2,3 with three-way return"
  - "Sigra.Crypto.needs_rehash?/2 for Argon2id parameter drift detection"
  - "Config extensions: password_policy, magic_link, require_confirmation, session_ttl"
affects: [02-core-auth, 03-oauth, 05-session-management]

# Tech tracking
tech-stack:
  added: [bcrypt_elixir (optional)]
  patterns: [three-way-verify-return, compile-time-mapset-embedding, optional-dep-guard]

key-files:
  created:
    - lib/sigra/email.ex
    - lib/sigra/password_policy.ex
    - lib/sigra/password_policy/common_passwords.ex
    - lib/sigra/hashers/bcrypt.ex
    - priv/data/common_passwords.txt
    - test/sigra/email_test.exs
    - test/sigra/password_policy_test.exs
  modified:
    - lib/sigra/crypto.ex
    - lib/sigra/config.ex
    - mix.exs
    - test/sigra/crypto_test.exs
    - test/sigra/config_test.exs

key-decisions:
  - "Strength threshold lowered from 5 to 4 so long passphrase-style passwords score as strong"
  - "password.min_length default changed from 12 to 8 to align with NIST SP 800-63B and PasswordPolicy authority"
  - "bcrypt_hash? and argon2_hash? made public for external consumers needing hash type detection"

patterns-established:
  - "Optional dep gate: Code.ensure_loaded?(Module) before delegating to optional dependency"
  - "Three-way verify return: {:ok, :valid} | {:ok, :valid, new_hash} | {:error, :invalid}"
  - "Compile-time resource embedding: @external_resource + MapSet.new for O(1) lookup"
  - "Changeset policy validation: get_change then pipeline of validators returning changeset"

requirements-completed: [AUTH-02, AUTH-03, AUTH-07]

# Metrics
duration: 9min
completed: 2026-04-06
---

# Phase 2 Plan 01: Core Library Modules Summary

**Email normalization with NFKC, NIST-compliant password policy with 10k common password rejection, bcrypt-to-Argon2id transparent hash migration via three-way verify_with_upgrade**

## Performance

- **Duration:** 9 min
- **Started:** 2026-04-06T17:03:58Z
- **Completed:** 2026-04-06T17:12:57Z
- **Tasks:** 2
- **Files modified:** 12

## Accomplishments
- Email.normalize/1 applies trim + downcase + NFKC; validate_format/1 uses permissive regex with 160-char limit
- PasswordPolicy.validate/2 enforces NIST-compliant rules on Ecto changesets with configurable composition requirements
- PasswordPolicy.check_strength/1 provides scoring-based strength assessment for UI feedback
- CommonPasswords embeds 10,000 common passwords as compile-time MapSet for O(1) rejection
- Crypto.verify_with_upgrade/2,3 returns three-way result enabling transparent bcrypt-to-Argon2id migration
- Crypto.needs_rehash?/2 detects stale Argon2id parameters by parsing hash string
- Config extended with password_policy, magic_link, require_confirmation, session_ttl sections

## Task Commits

Each task was committed atomically (TDD: RED then GREEN):

1. **Task 1: Email, PasswordPolicy, CommonPasswords, Config** - `7bf3ad9` (test: RED) + `5cc25fb` (feat: GREEN)
2. **Task 2: Bcrypt hasher, verify_with_upgrade, needs_rehash** - `9668f52` (test: RED) + `ff051d4` (feat: GREEN)

## Files Created/Modified
- `lib/sigra/email.ex` - Email normalization (trim+downcase+NFKC) and format validation
- `lib/sigra/password_policy.ex` - NIST-compliant password validation, strength assessment, HIBP check
- `lib/sigra/password_policy/common_passwords.ex` - Compile-time 10k common password MapSet
- `priv/data/common_passwords.txt` - 10,000 most common passwords (one per line, lowercase)
- `lib/sigra/hashers/bcrypt.ex` - Bcrypt hasher with Code.ensure_loaded? gate
- `lib/sigra/crypto.ex` - Extended with verify_with_upgrade/2,3, needs_rehash?/2, hash detection
- `lib/sigra/config.ex` - Added password_policy, magic_link, require_confirmation, session_ttl
- `mix.exs` - Added bcrypt_elixir as optional dependency
- `test/sigra/email_test.exs` - 11 tests for normalize and validate_format
- `test/sigra/password_policy_test.exs` - 22 tests for validate, check_strength, CommonPasswords
- `test/sigra/crypto_test.exs` - 24 tests including verify_with_upgrade and needs_rehash
- `test/sigra/config_test.exs` - 7 new tests for new config fields

## Decisions Made
- Strength scoring threshold lowered from 5 to 4 so that long passphrase-style passwords (e.g., "correcthorsebatterystaple") score as :strong even without mixed case/digits/special chars. This aligns with NIST guidance favoring length over complexity.
- password.min_length default changed from 12 to 8 to align with NIST SP 800-63B. PasswordPolicy is now the authority for password validation rules.
- bcrypt_hash?/1 and argon2_hash?/1 made public (not private) so external consumers can detect hash types for migration reporting.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed strength threshold for passphrase-style passwords**
- **Found during:** Task 1 (check_strength tests)
- **Issue:** "correcthorsebatterystaple" scored as :fair (4 points) with threshold of 5 for :strong. Plan specified this should be :strong.
- **Fix:** Lowered :strong threshold from 5 to 4 points, matching NIST preference for length over complexity.
- **Files modified:** lib/sigra/password_policy.ex
- **Verification:** check_strength("correcthorsebatterystaple") returns {:strong, []}
- **Committed in:** 5cc25fb (Task 1 GREEN commit)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Threshold adjustment necessary for correctness. No scope creep.

## Issues Encountered
None.

## Known Stubs
None - all modules are fully functional with real implementations.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Email normalization, password policy, and crypto upgrade detection are ready for the Auth orchestrator in Plan 02
- verify_with_upgrade enables the login flow to transparently upgrade bcrypt hashes
- Config extensions provide the schema for magic link, confirmation, and session TTL settings
- 182 tests pass across full suite with zero warnings

## Self-Check: PASSED

All 12 files verified present. All 4 commit hashes verified in git log.

---
*Phase: 02-core-auth*
*Completed: 2026-04-06*
