---
phase: 225-secure-first-admin-generated-host-security-parity
plan: 01
subsystem: installer-security
tags: [ecto, mix-tasks, policy, impersonation, audit]
requirements-completed: [BOOT-01, BOOT-02, BOOT-03, SEC-01]
completed: 2026-07-19
status: complete
---

# Phase 225 Plan 01 Summary

Delivered an explicit, persisted, host-owned first-admin workflow and brought generated-host impersonation protections to parity with the example application.

## Delivered

- Admin-enabled installs generate a platform-admin grant migration/schema, access boundary, default policy delegation, allow/deny policy tests, and grant/revoke/list/check Mix tasks; `--no-admin` emits none of them.
- Grants require an existing confirmed, non-deleted user. Mutations are repeat-safe and atomic with audit evidence; no password, first-user, or email-domain inference is used.
- Customized policies are preserved and documented through an additive delegation/migration recipe.
- Password, MFA, backup-code, passkey, deletion, export, and API-token operations receive the current scope and deny impersonated mutation with typed, user-safe handling.

## Verification

- A fresh Phoenix host compiled with warnings as errors, migrated, ran its generated policy test, granted/checked/listed/revoked access, and denied the next browser request after revocation.
- Focused installer and impersonation parity contracts pass.

