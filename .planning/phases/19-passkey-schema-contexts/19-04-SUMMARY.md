---
phase: 19-passkey-schema-contexts
plan: 04
subsystem: auth
tags: [passkeys, install, upgrade, cloak, vault, boot-check, generator]
provides:
  - Sigra.Passkeys rename/delete management API with user-scoped lookup and audit events
  - Sigra.Install.Features.Passkeys and passkey installer ownership for schema + migration templates
  - Cloak vault promotion for fresh installs and `mix sigra.upgrade` rewrites of the plaintext encrypted type
  - Boot-time guard that refuses passkey-enabled apps still using the plaintext encryption stub
  - Integration coverage for passkey installs, upgrade promotion, and installer feature ownership
affects: [phase-20-passkey-runtime, phase-21-passkey-ui, phase-22-passkeys-generator]
tech-stack:
  added:
    - cloak_ecto ~> 1.3
  patterns:
    - Installer encryption output is gated centrally in `Features.Core` and reuses a single vault child injection anchor
    - Upgrade promotion rewrites the existing encrypted type path in place instead of introducing a second runtime module path
    - Runtime vault safety is checked via explicit generated-module markers (`__sigra_encryption_mode__/0`)
key-files:
  created:
    - lib/sigra/install/features/passkeys.ex
    - priv/templates/sigra.install/core/vault.ex
    - priv/templates/sigra.install/core/encrypted_binary.ex
    - test/sigra/install/features/passkeys_test.exs
    - test/sigra/install/vault_promotion_test.exs
  modified:
    - lib/sigra/passkeys.ex
    - lib/sigra/install/features/core.ex
    - lib/sigra/install/injector.ex
    - lib/sigra/upgrade.ex
    - lib/mix/tasks/sigra.install.ex
    - lib/mix/tasks/sigra.upgrade.ex
    - lib/sigra/application.ex
    - priv/templates/sigra.install/passkeys/user_passkey.ex
    - test/sigra/passkeys_test.exs
    - test/sigra/upgrade_test.exs
key-decisions:
  - "rename/5 and delete/4 resolve credentials strictly by {user_id, credential_id} and collapse cross-user access to :not_found."
  - "Fresh installs and upgrades both keep the encrypted type at `accounts/encrypted.ex`, avoiding a second runtime path and compile-order drift."
  - "The vault-child injector now keys idempotency on the concrete `#{app_module}.Vault` module name instead of a broad `Vault` substring."
patterns-established:
  - "Generated encryption types declare a tiny `__sigra_encryption_mode__/0` marker so runtime safety checks can distinguish vault-backed code from the stub without source introspection."
  - "Install-feature coverage tests expand binding variants when a template is conditionally owned by a runtime-capability gate."
requirements-completed: [PK-01, PK-07, PK-08]
duration: 45min
completed: 2026-04-15
---

# Phase 19: passkey-schema-contexts Summary

**Wave 4 finished the passkey management/install/upgrade path and closed Phase 19**

## Performance

- **Duration:** 45 min
- **Tasks:** 3
- **Files modified:** 16

## Accomplishments

- Added `Sigra.Passkeys.rename/5` and `delete/4` with user-scoped ownership checks and `passkey.rename` / `passkey.delete` audit events.
- Introduced `Sigra.Install.Features.Passkeys`, registered the `--passkeys` installer feature, and wired passkey schema/migration ownership into the feature manifest.
- Promoted the Cloak vault into the core installer path, added upgrade-time vault promotion, and added a boot-time refusal when passkeys are enabled against the plaintext stub.
- Verified the full Wave 4 slice with installer, upgrade, feature-coverage, and passkey test runs.

## Verification

- `mix test test/sigra/passkeys/*.exs test/sigra/passkeys_test.exs test/sigra/install/features/core_test.exs test/sigra/install/features/coverage_test.exs test/sigra/install/features/passkeys_test.exs test/sigra/install/purely_additive_test.exs test/sigra/install/isolation_test.exs test/sigra/install/templates_layout_test.exs test/sigra/install/vault_promotion_test.exs test/sigra/upgrade_test.exs`
- Result: `92 tests, 0 failures`

## Next Phase Readiness

Phase 19 is complete. Phase 20 can now build on a finished passkey data/install base with the runtime challenge plug, session storage, and JS hook wiring.
