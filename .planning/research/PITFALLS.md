# Domain Pitfalls

**Domain:** authentication library + generator
**Researched:** 2026-05-07

## Critical Pitfalls

### Pitfall 1: Session Semantics That Differ From UX Expectations
**What goes wrong:** Users think “log out everywhere” or timeout settings are immediate, but actual session invalidation is delayed or strategy-dependent.
**Why it happens:** JWT-heavy or mixed session models hide revocation timing.
**Consequences:** Security confusion, bug reports, weak admin confidence.
**Prevention:** Default to DB-backed browser sessions, expose current/other sessions visibly, document timeout semantics.
**Detection:** Support tickets about “I revoked it but it still works” or inconsistent current-user state across tabs/devices.

### Pitfall 2: Email Links Break in Real Mailboxes
**What goes wrong:** Verification or magic links are consumed by scanners, tracking rewrites, or SSR redirect assumptions.
**Why it happens:** Teams test only the happy path inbox flow.
**Consequences:** Random login failures and poor trust in auth.
**Prevention:** Make code-based verification/login first-class, support custom redirect endpoints, document email-tracking hazards.
**Detection:** “Token expired immediately” reports, provider-specific failures, high resend usage.

### Pitfall 3: Passkeys Without Recovery and Origin Guidance
**What goes wrong:** Passkey auth works in demos but fails in staging/subdomain setups or leaves users stranded.
**Why it happens:** RP ID/origin rules and recovery planning are deferred.
**Consequences:** Lockouts, support debt, poor adoption.
**Prevention:** Ship passkeys after verified email/recovery; document RP/subdomain rules; provide rename/revoke/fallback flows.
**Detection:** Environment-specific failures, support requests after device loss, broken sibling-subdomain behavior.

## Moderate Pitfalls

### Pitfall 1: Feature Flags That Require Schema or Route Edits
**What goes wrong:** Developers enable a module but forget the matching migration, route, or middleware changes.
**Prevention:** Generators should emit complete slices atomically and validate prerequisites up front.

### Pitfall 2: Over-Abstracted Callback Surfaces
**What goes wrong:** Too much auth behavior is hidden behind hooks or adapters that are powerful but hard to reason about.
**Prevention:** Prefer explicit service APIs and documented extension points over callback-heavy orchestration.

### Pitfall 3: Compliance Claims Without Export History
**What goes wrong:** The library advertises deletion/export/compliance readiness without giving hosts usable export surfaces or evidence trails.
**Prevention:** Add export jobs, downloadable artifacts, and audit/history rows before making that story prominent.

## Minor Pitfalls

### Pitfall 1: Test Environments Trip Security Defaults
**What goes wrong:** Rate limits or verification guards cause flaky tests.
**Prevention:** Provide documented test helpers and safe test config overrides.

### Pitfall 2: Multi-Session UX Has Surprising Redirects
**What goes wrong:** Sign-out lands on unexpected chooser/task screens.
**Prevention:** Make redirect behavior explicit and generated, not implicit.

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Session UX | revocation appears inconsistent across tabs/devices | keep canonical session rows and immediate disconnect hooks |
| Email stack | link scanners consume tokens | ship code fallback and server-side verify endpoint patterns |
| Passkeys | subdomain/RP mismatch | add install-time docs and config validation |
| Exports/compliance | export exists but no audit trail for export actions | log export actor, scope, time, and artifact status |
| Admin polish | impersonation without user-visible signaling | add actor claims, banners, and audit events |

## Sources

- Devise README: https://github.com/heartcombo/devise
- django-allauth rate limits: https://django-allauth.readthedocs.io/en/latest/account/rate_limits.html
- django-allauth account config: https://docs.allauth.org/en/dev/account/configuration.html
- django-allauth MFA config: https://docs.allauth.org/en/dev/mfa/configuration.html
- django-allauth headless config: https://docs.allauth.org/en/dev/headless/configuration.html
- Laravel Fortify: https://laravel.com/docs/12.x/fortify
- Laravel Jetstream browser sessions: https://jetstream.laravel.com/features/browser-sessions.html
- Auth.js repo README: https://github.com/nextauthjs/next-auth
- Auth.js credentials/database session discussion: https://github.com/nextauthjs/next-auth/discussions/12848
- Clerk session options: https://clerk.com/docs/guides/secure/session-options
- Clerk session tasks: https://clerk.com/docs/guides/development/custom-flows/authentication/session-tasks
- Clerk passkeys: https://clerk.com/docs/guides/development/custom-flows/authentication/passkeys
- Clerk exporting users: https://clerk.com/docs/deployments/exporting-users
- Supabase sessions: https://supabase.com/docs/guides/auth/sessions
- Supabase email templates: https://supabase.com/docs/guides/auth/auth-email-templates
- Supabase passkey API: https://supabase.com/docs/reference/javascript/auth-passkey-api
