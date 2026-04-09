---
status: partial
phase: 08-account-lifecycle
source: [08-VERIFICATION.md]
started: 2026-04-08T22:45:00Z
updated: 2026-04-08T22:45:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. Settings LiveView visual correctness
expected: 3 sections render properly — email with pending status, password with OAuth-only variant, deletion with danger zone red border styling
result: [pending]

### 2. Sudo mode gates sensitive operations
expected: Re-auth prompt appears after sudo window expiry when accessing email change, password change, or deletion
result: [pending]

### 3. Reactivation flow during grace period
expected: Deleted user sees reactivation page on login with cancel deletion and sign-out options
result: [pending]

### 4. Email template rendering
expected: 7 new emails match UI-SPEC copywriting contract (subjects, body text, CTA buttons, security footers)
result: [pending]

## Summary

total: 4
passed: 0
issues: 0
pending: 4
skipped: 0
blocked: 0

## Gaps
