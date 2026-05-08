# Feature Landscape

**Domain:** authentication library + generator for Phoenix
**Researched:** 2026-05-07

## Table Stakes

Features users expect. Missing = product feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Browser sessions list + revoke | Jetstream, allauth usersessions, Clerk, Supabase all treat session control as baseline | Med | Ship visible session records, current-session labeling, revoke-other-sessions |
| Email verification / reset / change-email | Present everywhere | Med | Must support links and codes; code flows are increasingly important |
| Rate limiting + lockout | Devise lockable, Fortify rate limits, allauth default rate limits | Low | Should be on by default and documented |
| Password confirmation / sudo | Fortify and Jetstream make sensitive-action reauth explicit | Low | Transfer directly to Phoenix plugs/LiveViews |
| Security notifications | Supabase templates cover password/email/identity/MFA events | Med | Strong trust win for low implementation risk |
| Admin-safe session/account actions | Clerk impersonation and Jetstream browser sessions show support needs this | Med | Include actor/audit signals |

## Differentiators

Features that set product apart. Not expected, but valued.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Post-auth task router | Clerk’s pending session tasks pattern is excellent | Med | Use for “verify email”, “set up MFA”, “choose org”, “reset compromised password” |
| Email login by code | allauth supports it cleanly; safer against scanner issues than raw magic links | Med | Strong fit for Sigra’s browser-first flows |
| Passkey management with fallback-first UX | Better than just “supports WebAuthn” | High | Enrollment, rename, revoke, recovery, RP guidance |
| Export history + downloadable account/auth data | Clerk makes migration/export traceable | Med | Important for trust, deletion, and migration stories |
| Generated browser/admin surfaces | More valuable than raw APIs | Med | Jetstream proves opinionated UI helps adoption |

## Anti-Features

Features to explicitly NOT build.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Hosted dashboard dependency for core auth behavior | Breaks Sigra’s host-owned promise | Keep all critical policy and auth behavior in repo-owned code/config |
| JWT-first browser auth default | Revocation and timeout semantics get surprising fast | Keep DB-backed browser sessions as default; JWT for explicit API cases |
| Passkey-only onboarding | Recovery and support burden become unacceptable | Require strong fallback paths and progressive enrollment |
| Opaque callback labyrinth | Auth.js shows this becomes hard to reason about | Prefer explicit generator seams, modules, and documented hooks |
| Giant B2B suite before core UX is polished | Dilutes the product | Finish sessions, email, passkeys, and exports first |

## Feature Dependencies

```text
Canonical session model -> Browser session UI -> Admin session tools
Email template/delivery stack -> Verification/reset/invite/code login -> Security notifications
Email verification + recovery -> Passkey enrollment/sign-in
Audit/event model -> Export history -> Compliance/admin polish
Organization context -> Post-auth task router -> Org chooser UX
```

## MVP Recommendation

Prioritize:
1. Browser sessions + revoke flows
2. Email verification/reset/login-by-code stack
3. Post-auth task routing for pending requirements

Defer: Passkey-primary signup
Reason: benchmark products either gate it behind prerequisites, call it experimental, or rely on stronger surrounding account UX first.

## Sources

- Devise README: https://github.com/heartcombo/devise
- django-allauth account config: https://docs.allauth.org/en/dev/account/configuration.html
- django-allauth MFA config: https://docs.allauth.org/en/dev/mfa/configuration.html
- django-allauth usersessions: https://docs.allauth.org/en/dev/usersessions/introduction.html
- Laravel starter kits: https://laravel.com/docs/12.x/starter-kits
- Laravel Jetstream browser sessions: https://jetstream.laravel.com/features/browser-sessions.html
- Clerk session tasks: https://clerk.com/docs/guides/development/custom-flows/authentication/session-tasks
- Clerk impersonation: https://clerk.com/docs/guides/users/impersonation
- Clerk migration/exporting users: https://clerk.com/docs/deployments/exporting-users
- Supabase sessions: https://supabase.com/docs/guides/auth/sessions
- Supabase passwordless email: https://supabase.com/docs/guides/auth/auth-email-passwordless
- Supabase passkey API: https://supabase.com/docs/reference/javascript/auth-passkey-api
- Auth.js repo README: https://github.com/nextauthjs/next-auth
- Auth.js discussion on credentials/database sessions: https://github.com/nextauthjs/next-auth/discussions/12848

