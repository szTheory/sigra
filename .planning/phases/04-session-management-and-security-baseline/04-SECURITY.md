# Phase 04 Security Verification

**Phase:** 04 -- session-management-and-security-baseline
**Auditor:** GSD Security Auditor
**Date:** 2026-04-07
**Threats Closed:** 23/23
**ASVS Level:** 2

## Threat Verification

### Mitigated Threats (18)

| Threat ID | Category | Disposition | Evidence |
|-----------|----------|-------------|----------|
| T-4-01 | Spoofing | mitigate | `lib/sigra/session_stores/ecto.ex:25` -- `Sigra.Token.generate_hashed_token()` called in create/3; raw token returned only on create, hashed stored |
| T-4-10 | Information Disclosure | mitigate | `lib/sigra/session_stores/ecto.ex:58` -- fetch/2 calls `to_session(record)` which never populates `:token` field (raw token nil after fetch) |
| T-4-11 | Tampering | mitigate | `lib/sigra/session_stores/ecto.ex:56` -- `repo.get_by(schema, hashed_token: hashed_token)` -- all lookups use hashed_token |
| T-4-02 | Spoofing | mitigate | `lib/sigra/plug/fetch_session.ex:125-145` -- `session_valid?/2` checks both idle_timeout (1800s) and absolute_timeout (86400s); remember_me skips idle, uses remember_me_max_age |
| T-4-03 | Tampering | mitigate | `lib/sigra/plug/fetch_session.ex:38-42` -- `@default_cookie_opts [http_only: true, same_site: "Lax", secure: true]`; `priv/templates/sigra.install/user_auth.ex:22-27` -- remember_me cookie also has `http_only: true, secure: Mix.env() == :prod, same_site: "Lax"` |
| T-4-04 | Elevation of Privilege | mitigate | `lib/sigra/plug/require_sudo.ex:69-77` -- `sudo_fresh?/2` reads `conn.private[:sigra_session]` and pattern matches `%Sigra.Session{sudo_at: %DateTime{} = sudo_at}` with server-time comparison |
| T-4-12 | Repudiation | mitigate | `lib/sigra/telemetry.ex:31-44` -- session span events (create/delete/sudo) and signals (revoke_all, security events) registered; `lib/sigra/auth.ex:671,686,730,765` -- telemetry spans on all session operations |
| T-4-05 | Tampering | mitigate | `lib/sigra/lockout.ex:56-68` -- `check/2` returns `{:error, :account_locked, remaining}` when `failed_login_attempts >= threshold` and within duration; `lib/sigra/lockout.ex:85-99` -- `increment!/3` sets `locked_at` at threshold |
| T-4-06 | Denial of Service | mitigate | `lib/sigra/plug/rate_limit.ex:57-81` -- POST/PUT/PATCH/DELETE rate limited by IP via `check_rate/3`; 429 with `retry-after` header; telemetry emitted |
| T-4-07 | Tampering | mitigate | `lib/sigra/lockout.ex:85-99` -- `increment!/3` atomically increments via `Ecto.Changeset.change` + `repo.update!`; `lib/sigra/lockout.ex:113-117` -- `reset!/2` sets to 0 only on successful login |
| T-4-08 | Information Disclosure | mitigate | `lib/sigra/error.ex:83-87` -- `:account_locked` returns "Too many attempts. Try again in a few minutes." (generic); `:account_locked_just_triggered` returns "Invalid email or password. Too many attempts." (generic, no email info) |
| T-4-09 | Spoofing | mitigate | `lib/sigra/suspicious_login.ex:50-86` -- `do_detect/4` compares login IP against MapSet of active session IPs; emits telemetry; `lib/sigra/auth.ex:873-876` -- detection triggers `maybe_deliver_suspicious_login_email` |
| T-4-16 | Tampering | mitigate | `lib/sigra/auth.ex:148-150` -- `Sigra.Lockout.check(user, lockout_opts)` called BEFORE `Crypto.verify_with_upgrade` in `authenticate_with_config/2` |
| T-4-17 | Denial of Service | mitigate | `lib/sigra/workers/token_cleanup.ex:83-108` -- `cleanup_expired_sessions/1` deletes standard sessions > absolute_timeout and remember_me sessions > remember_me_max_age |
| T-4-18 | Spoofing | mitigate | `priv/templates/sigra.install/sudo_controller.ex:26` -- `Sigra.Crypto.verify_password(password, user.hashed_password)` (Argon2id); form uses POST with CSRF via Phoenix default |
| T-4-19 | Tampering | mitigate | `priv/templates/sigra.install/sudo_controller.ex:33-37` -- `return_to` validated: `String.starts_with?(return_to, "/") && !String.starts_with?(return_to, "//")` prevents open redirect |
| T-4-21 | Elevation of Privilege | mitigate | `priv/templates/sigra.install/session_live.ex:20` -- `socket.assigns.current_scope.user` read from authenticated mount; all operations scoped to that user |
| T-4-22 | Tampering | mitigate | `priv/templates/sigra.install/session_live.ex:69,102,110` -- `Base.url_encode64(session.hashed_token)` for transport, `Base.url_decode64!/1` server-side; raw token never exposed |

### Accepted Risks (5)

| Threat ID | Category | Component | Rationale |
|-----------|----------|-----------|-----------|
| T-4-13 | Denial of Service | PubSub broadcast storm | Broadcast iterates over sessions for a single user (bounded by session count). "Log out everywhere" is infrequent. Acceptable residual risk. |
| T-4-14 | Denial of Service | Lockout as DoS vector | Lockout is temporary (15 min), auto-unlocks. IP rate limiting prevents mass lockout attacks. Acceptable residual risk. |
| T-4-15 | Spoofing | IP behind proxy | Documented that apps behind proxies must configure remote_ip or plug_cloudflare. Sigra reads conn.remote_ip as-is. `lib/sigra/plug/rate_limit.ex:27-29` documents this. |
| T-4-20 | Information Disclosure | Email content | Emails contain IP and approximate location intentionally for user awareness. Sent only to account owner's verified email. |
| T-4-23 | Information Disclosure | Session listing data | IP, location, and device info shown to account owner only via authenticated LiveView. Intended behavior. |

### Unregistered Flags

None. No `## Threat Flags` sections found in any SUMMARY.md file.

## Summary

All 18 mitigate-disposition threats verified with code evidence. All 5 accept-disposition threats documented. No open threats. No unregistered flags.
