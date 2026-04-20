---
status: complete
phase: 21-passkey-liveviews-post-auth-controller
source:
  - 21-02-SUMMARY.md
  - 21-03-SUMMARY.md
  - 21-04-SUMMARY.md
  - 21-05-SUMMARY.md
  - 21-12-SUMMARY.md
  - 21-14-SUMMARY.md
started: 2026-04-16T01:43:14Z
updated: 2026-04-16T01:55:32Z
---

## Current Test

[testing complete]

## Tests

### 1. Passkey-Primary Login Surface
expected: On the sign-in page, entering an email should leave one primary action labeled "Continue with passkey" and keep visible fallback actions for password and magic-link recovery. The page should not force a separate chooser flow.
result: pass

### 2. Passkey-Primary Login Start
expected: Clicking "Continue with passkey" on the sign-in page should start the browser passkey flow without a server error or dead end, and unsuccessful attempts should keep the page usable with recovery options still visible.
result: pass

### 3. MFA Settings Passkeys Section
expected: On /users/settings/mfa, there should be a Passkeys section with helper copy, an "Add passkey" action, and either an empty state or a compact list of passkeys with friendly labels rather than raw credential metadata.
result: pass

### 4. Passkey Enrollment From Settings
expected: After sudo revalidation, starting passkey enrollment from MFA settings should begin the browser ceremony and return to a usable state with success or friendly recovery messaging rather than raw browser errors.
result: pass

### 5. Passkey Row Rename
expected: For an existing passkey, choosing Rename should allow an inline name edit in the row and saving should update the visible label without navigating away.
result: pass

### 6. Passkey Row Delete
expected: Deleting a passkey should stay behind the sudo-protected flow, use an inline confirmation, and if it is the last passkey, show stronger warning copy about keeping another sign-in method available.
result: pass

### 7. Passkey-First MFA Challenge
expected: On the MFA challenge for a user with passkeys, the screen should lead with "Continue with passkey" while still showing immediate fallback actions for authenticator code and backup code.
result: pass

### 8. Passkey Recovery Messaging
expected: If a passkey attempt is canceled, times out, or runs in an unsupported browser, the UI should show friendly recovery copy and retry or fallback actions, never raw browser exception names such as AbortError or NotAllowedError.
result: pass

## Summary

total: 8
passed: 8
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps
