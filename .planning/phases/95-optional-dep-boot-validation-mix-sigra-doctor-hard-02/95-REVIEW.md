---
phase: 95-optional-dep-boot-validation-mix-sigra-doctor-hard-02
reviewed: 2026-04-30T21:51:49Z
depth: standard
files_reviewed: 30
files_reviewed_list:
  - lib/sigra/optional_deps.ex
  - lib/sigra/optional_deps/missing_dependency_error.ex
  - lib/sigra/jwt/signer.ex
  - test/sigra/optional_deps_test.exs
  - test/sigra/jwt/signer_test.exs
  - lib/sigra/delivery.ex
  - lib/sigra/workers/email_delivery.ex
  - lib/sigra/hashers/bcrypt.ex
  - lib/sigra/crypto.ex
  - lib/sigra/mfa.ex
  - test/sigra/delivery_test.exs
  - test/sigra/crypto_test.exs
  - test/sigra/mfa_test.exs
  - lib/mix/tasks/sigra.doctor.ex
  - lib/sigra/application.ex
  - lib/sigra/install/features/core.ex
  - mix.exs
  - test/mix/tasks/sigra.doctor_test.exs
  - test/sigra/application_optional_deps_test.exs
  - test/example/test/example_web/smoke/install_compile_test.exs
  - lib/sigra/workers/account_deletion.ex
  - lib/sigra/workers/audit_cleanup.ex
  - lib/sigra/workers/token_cleanup.ex
  - lib/sigra/workers/cleanup_expired_invitations.ex
  - .github/workflows/ci.yml
  - README.md
  - MAINTAINING.md
  - guides/introduction/troubleshooting-install.md
  - guides/recipes/deployment.md
  - test/sigra/workers/optional_deps_test.exs
findings:
  critical: 0
  warning: 1
  info: 0
  total: 1
status: issues_found
---

# Phase 95: Code Review Report

**Reviewed:** 2026-04-30T21:51:49Z
**Depth:** standard
**Files Reviewed:** 30
**Status:** issues_found

## Summary

Re-reviewed the unchanged Phase 95 scope after the CI expectation correction. The `optional_dep_oban_absent` lane now asserts `:lifecycle_jobs` correctly, so that false-failure is gone. The only remaining issue in scope is that the compile-warning support for enabled optional dependencies is still tested synthetically rather than through a generated host file.

## Warnings

### WR-01: Generated-host compile-warning coverage is still synthetic, not integrated

**File:** `lib/sigra/application.ex:106-124`, `lib/sigra/install/features/core.ex:136-160`, `test/example/test/example_web/smoke/install_compile_test.exs:79-100`
**Issue:** `Sigra.Application.warn_for_enabled_optional_deps!/1` exists and the smoke test proves it emits a JWT/Joken warning when invoked manually, but no generated host file in the reviewed scope actually calls that macro. A repository-wide search finds the macro referenced only in `lib/sigra/application.ex` and the smoke test itself. The example host already enables JWT in `test/example/lib/example/accounts.ex:575-592`, yet compilation of generated host code does not exercise the warning path. That leaves the Phase 95 compile-warning contract unproven in the real installer output: it validates `Code.compile_string/1`, not the generated host integration.
**Fix:**
```elixir
# Inject the warning into a generated compile-time site, for example in the
# generated auth/config module after the JWT-enabled config is known:
require Sigra.Application

Sigra.Application.warn_for_enabled_optional_deps!(
  jwt: [enabled: true]
)
```

Then update the example-host smoke to compile the generated file itself under a missing-`joken` scenario and assert the warning originates from that file, not from `Code.compile_string/1`.

---

_Reviewed: 2026-04-30T21:51:49Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
