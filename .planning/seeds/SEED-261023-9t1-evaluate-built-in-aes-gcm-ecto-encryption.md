---
id: SEED-261023-9t1
status: dormant
planted: 2026-10-23
planted_during: "v1.50 CI-SPEED-AND-RELIABILITY / Phase 254; downstream request capture only"
trigger_when: "After the optional-cloak dependency fix ships, when planning at-rest encryption ownership, removing Cloak audit findings for encryption hosts, or an encryption-format migration"
scope: "Medium design investigation; implementation size depends on ciphertext compatibility and key rotation"
related:
  - .planning/seeds/SEED-261023-opm-make-cloak-ecto-optional-for-downstream-consumers.md
---

# SEED-261023-9t1: Evaluate built-in AES-256-GCM Ecto encryption

## Why This Matters

Making cloak_ecto optional removes Cloak from consumers that do not use encryption. Hosts using the generated vault still install Cloak and retain package audit findings, even though the current generated code uses AES-GCM rather than the vulnerable AES-CTR or PBKDF2 paths.

The downstream request suggests considering a small built-in AES-256-GCM Ecto type. Investigate whether owning this behavior is preferable to continuing with Cloak or choosing a maintained alternative. The request describes Cloak as unmaintained; maintainer status was not independently established during capture and must be rechecked before using it as a decision premise.

## When to Surface

**Trigger:** After the optional-dependency change has shipped, during an encryption/dependency-security milestone or when encryption hosts need a path that removes these package findings.

This is a separate design decision. It is not a prerequisite for the optional-dependency fix and must not expand that release into a cryptography rewrite.

## Investigation and Decision

- Compare keeping the existing adapter, adopting a maintained implementation, and a small Ecto type using OTP's authenticated encryption API. Account for maintenance responsibility and review cost, not just line count.
- Define a versioned authenticated ciphertext format, fresh nonce generation, key validation/loading, key identifiers and rotation, associated data, and explicit failure behavior. Never fall back to plaintext on a decrypt/authentication error.
- Determine how existing Cloak AES-GCM ciphertext and configured key tags are read and migrated without data loss. Decide whether a compatibility reader or a deliberate re-encryption migration is necessary. Do not assume two AES-GCM implementations share a storage format.
- Cover host-owned generated modules, install/OAuth/upgrade compatibility, doctor encryption detection, MFA/TOTP secrets, OAuth tokens, and passkey data. Preserve the real-vault versus plaintext-stub distinction.
- Require meaningful tests for round trips, tampered/truncated/malformed ciphertext, wrong keys, nonce handling, key rotation, and old-format migration. Include rollback/recovery and secret-safe errors.
- Record a design decision and migration estimate before implementation. If there is no practical advantage over a supported adapter, close this seed with the reason.

## Breadcrumbs

- Primary request and advisory/source findings: `SEED-261023-opm-make-cloak-ecto-optional-for-downstream-consumers.md` in this directory.
- `priv/templates/sigra.install/core/vault.ex`, `priv/templates/sigra.install/core/encrypted_binary.ex`
- `priv/templates/sigra.gen.oauth/vault.ex`, `priv/templates/sigra.gen.oauth/encrypted_binary.ex`
- `lib/sigra/upgrade.ex`, `lib/sigra/optional_deps.ex`, `lib/sigra/application.ex`, `lib/sigra/doctor.ex`

## Notes

Captured for OpenGSD's `$gsd-new-milestone` seed scan. No replacement encryption code or migration has been implemented or verified.
