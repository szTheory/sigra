---
phase: 226-auth-entry-recovery
plan: 01
subsystem: generated-auth-ui
tags: [phoenix, heex, css, recovery, microcopy]
requirements-completed: [AUTHUI-01, AUTHUI-02]
completed: 2026-07-19
status: complete
---

# Phase 226 Plan 01 Summary

Recomposed generated entry and recovery flows around a bounded semantic auth vocabulary and configuration-derived action hierarchy.

## Delivered

- Login, registration, confirmation, reset, reactivation, sudo, and invitation templates use semantic `sigra-auth-*` structures and a host-owned auth button component.
- Broad styling inference was removed. DaisyUI-shaped selectors survive only as scoped compatibility bridges, and neither `sg-*` nor `vt-*` crosses into generated auth.
- Primary actions, progressive disclosure, native form semantics, and success/error/pending/expired/mismatch/recovery copy are explicit and user-centered.

## Verification

- Contract tests reject CoreComponents button leakage and ownership-lane crossings.
- Fresh generated-host compilation and browser interaction pass against current Phoenix.

