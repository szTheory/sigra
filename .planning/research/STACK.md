# Technology Stack

**Project:** Sigra
**Researched:** 2026-05-07

## Recommended Stack

### Core Framework
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Phoenix + LiveView | 1.8+ | Generated auth UI and browser-first flows | Jetstream and Clerk both show that polished account/session UX matters; Sigra should generate editable Phoenix surfaces instead of hiding them. |
| Sigra library core | current | Canonical auth services, token/session logic, audits, policy seams | Fortify and allauth prove the value of a stable backend core beneath app-owned UI. |
| Mix generators | current | Install feature slices into host apps | Devise/Laravel win because auth feels “present in my app”, not remote. |

### Database
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| PostgreSQL | current | Canonical source for users, sessions, tokens, passkeys, audits | Jetstream browser sessions require database sessions; allauth usersessions and Supabase session introspection reinforce the value of durable server-side records. |

### Infrastructure
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Swoosh-compatible mail pipeline | current | Verification, login codes, recovery, security notifications | Supabase and Clerk both expose that email delivery details are product-critical, not an afterthought. |
| Oban-backed async delivery/cleanup | current | Mail delivery, token cleanup, audit cleanup, exports | Keeps auth flows fast while preserving traceability and retries. |

### Supporting Libraries
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `wax_` / WebAuthn support | current | Passkey registration and authentication | Only after email recovery and session UX are already solid. |
| Cloak or equivalent field encryption | current | Provider token / sensitive secret storage | Use when OAuth or external identity metadata is stored. |
| Flop or equivalent validated query layer | current | Admin/session index filters | Use for browser session and admin surfaces that need stable pagination and filtering. |

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| Auth ownership | Library + generators | Hosted auth product | Clerk/Supabase-level polish is attractive, but Sigra’s value is host-owned code and upgradeable core. |
| Session model | DB-backed canonical sessions | JWT-first default | Supabase and Auth.js show JWT/session timing and revocation surprises; Sigra should keep browser auth server-authoritative. |
| UI delivery | Generated host code | Library-hidden UI only | Devise/Fortify/Jetstream succeed because developers can inspect and edit the auth surface. |
| Passkey rollout | Additive feature slice | Primary onboarding primitive | allauth and Supabase both show passkeys come with prerequisites or experimental flags; recovery must exist first. |

## Installation

```bash
# Core
mix deps.get
mix sigra.install

# Optional slices
mix sigra.gen.oauth
mix sigra.install --no-passkeys   # keep passkeys opt-out or phased
```

## Sources

- Devise README: https://github.com/heartcombo/devise
- django-allauth account config: https://docs.allauth.org/en/dev/account/configuration.html
- django-allauth usersessions: https://docs.allauth.org/en/dev/usersessions/introduction.html
- django-allauth headless config: https://docs.allauth.org/en/dev/headless/configuration.html
- Laravel Fortify: https://laravel.com/docs/12.x/fortify
- Laravel starter kits: https://laravel.com/docs/12.x/starter-kits
- Laravel Jetstream browser sessions: https://jetstream.laravel.com/features/browser-sessions.html
- Auth.js repo README: https://github.com/nextauthjs/next-auth
- Clerk docs overview: https://clerk.com/docs
- Clerk session tasks: https://clerk.com/docs/guides/development/custom-flows/authentication/session-tasks
- Supabase sessions: https://supabase.com/docs/guides/auth/sessions
- Supabase email templates: https://supabase.com/docs/guides/auth/auth-email-templates

