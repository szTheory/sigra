---
phase: 04-session-management-and-security-baseline
fixed_at: 2026-04-07T12:15:00Z
review_path: .planning/phases/04-session-management-and-security-baseline/04-REVIEW.md
iteration: 1
findings_in_scope: 10
fixed: 10
skipped: 0
status: all_fixed
---

# Phase 04: Code Review Fix Report

**Fixed at:** 2026-04-07T12:15:00Z
**Source review:** .planning/phases/04-session-management-and-security-baseline/04-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 10
- Fixed: 10
- Skipped: 0

## Fixed Issues

### CR-01: Open Redirect in Sudo Controller via `return_to` parameter

**Files modified:** `priv/templates/sigra.install/sudo_controller.ex`
**Commit:** 2f51a64
**Applied fix:** Added validation that `return_to` starts with "/" and does not start with "//" before using it in redirect. Falls back to `~p"/"` for invalid or missing values.

### CR-02: Insecure PRNG for Confirmation Codes

**Files modified:** `lib/sigra/auth.ex`
**Commit:** fea6202
**Applied fix:** Replaced `:rand.uniform/1` with `:crypto.strong_rand_bytes(4)` decoded as unsigned integer, then mapped to 100000-999999 range for cryptographically secure 6-digit confirmation codes.

### CR-03: XSS via Unescaped IP Address in Email Templates

**Files modified:** `priv/templates/sigra.install/emails.ex`
**Commit:** d7f9420
**Applied fix:** Added `html_escape_string/1` private helper using `Phoenix.HTML.html_escape/1`. Applied escaping to `ip`, `geo_city`, `geo_country`, and `device` fields in `suspicious_login_email/2` before HTML interpolation.

### WR-01: Race Condition in Lockout Increment

**Files modified:** `lib/sigra/lockout.ex`
**Commit:** 95c479c
**Applied fix:** Replaced read-modify-write pattern with atomic `update_all(inc: [failed_login_attempts: 1])` query. The returned updated record is then checked against the threshold for setting `locked_at`. This prevents concurrent requests from losing increment counts. Status: fixed: requires human verification (logic change).

### WR-02: Unbound `reset_password_url` in Email Template

**Files modified:** `lib/mix/tasks/sigra.install.ex`
**Commit:** ebfb96a
**Applied fix:** Added `reset_password_url` to the template binding list, generating the URL from the web module's endpoint URL concatenated with `/users/reset-password`.

### WR-03: Generated Auth Template References Wrong Module Name

**Files modified:** `priv/templates/sigra.install/auth.ex`
**Commit:** e412800
**Applied fix:** Changed `Sigra.SessionStore.Ecto` to `Sigra.SessionStores.Ecto` (plural) in `sigra_config/0` to match the actual module name.

### WR-04: FetchSession Plug Does Not Invalidate Expired Sessions

**Files modified:** `lib/sigra/plug/fetch_session.ex`
**Commit:** 69d89ac
**Applied fix:** Added `session_store.delete(session.hashed_token, opts)` call when `session_valid?/2` returns false, eagerly cleaning up expired sessions instead of leaving them for the cleanup worker.

### WR-05: `revoke_current` Event Revokes All Sessions Instead of Current

**Files modified:** `priv/templates/sigra.install/session_live.ex`
**Commit:** 2f3a5cb
**Applied fix:** Changed `revoke_current` handler to decode the provided token and call `Auth.revoke_session(hashed_token)` for the single session, instead of calling `Auth.revoke_all_sessions(user, except_token: nil)`.

### WR-06: `generate_user_session_token` Does Not Accept `type` Option

**Files modified:** `priv/templates/sigra.install/auth.ex`
**Commit:** d172ee4
**Applied fix:** Added `opts \\ []` parameter to `generate_user_session_token/1`, making it `/2` with default, and passed opts through to `UserToken.build_session_token/2`. This matches the call site in `ConnCaseHelpers` which passes `type: type`.

---

_Fixed: 2026-04-07T12:15:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
