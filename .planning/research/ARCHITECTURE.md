# Architecture Patterns

**Domain:** Phoenix authentication library + generator
**Researched:** 2026-05-07

## Recommended Architecture

Use a two-layer model:

```text
Sigra library core
  -> accounts, sessions, tokens, passkeys, audit, policy hooks

Generated host surface
  -> Phoenix controllers, LiveViews, templates, routes, mailer wrappers, admin pages
```

That is the best synthesis of Fortify, allauth, and Jetstream. The library owns sensitive invariants; the host app owns visible UX and policy customization.

### Component Boundaries

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| `Sigra.Auth` core | Sign-in/out, session lifecycle, reauth, lockout, audit emission | DB, mail pipeline, passkey subsystem |
| `Sigra.Email` contract | Build and send verification/reset/code/security emails | host mailer, token services |
| `Sigra.Passkeys` | Registration/authentication ceremonies and credential records | WebAuthn lib, accounts, sessions |
| `Sigra.Tasks` | Compute pending post-auth requirements | sessions, accounts, org/member state |
| Generated web layer | Forms, browser session pages, settings pages, task pages | Sigra core modules |
| Generated admin layer | Impersonation-safe actions, session revocation, export UI | Sigra core modules, audit/export services |
| Export/compliance services | User/account/audit exports and history | DB, job queue, audit |

### Data Flow

1. User completes a browser flow in generated controller/LiveView.
2. Generated code calls one canonical Sigra service.
3. Service writes session/token/passkey/audit state transactionally.
4. Service returns explicit next-step state:
   - authenticated
   - pending task
   - reauth required
   - verification required
5. Web layer renders or redirects based on that explicit state, not by recomputing auth logic ad hoc.

## Patterns to Follow

### Pattern 1: Fortify Split
**What:** Headless/auth-core backend with app-owned UI.
**When:** Always, for every primary flow.
**Example:**
```elixir
case Sigra.Auth.sign_in(config, params, scope: conn) do
  {:ok, session, tasks: []} -> redirect(conn, to: ~p"/settings/sessions")
  {:ok, _session, tasks: tasks} -> redirect(conn, to: task_path(tasks))
  {:error, changeset} -> render(conn, :new, changeset: changeset)
end
```

### Pattern 2: Post-Auth Tasks
**What:** Model incomplete requirements explicitly after authentication.
**When:** Email verification, MFA setup, org selection, compromised-password reset.
**Example:**
```elixir
tasks = Sigra.Tasks.pending_for_user(config, user, session: session)

if tasks == [] do
  {:ok, session}
else
  {:ok, session, tasks: tasks}
end
```

### Pattern 3: Session-First UX
**What:** Treat sessions as first-class rows with user-visible management.
**When:** Browser auth by default.
**Example:**
```elixir
sessions = Sigra.Auth.list_sessions(config, user)
Sigra.Auth.revoke_other_sessions(config, user, current_session_id)
```

### Pattern 4: Email Codes Over Fragile Links
**What:** Make code-based flows a first-class option alongside links.
**When:** Sign-in codes, verification, scanner-prone environments.
**Example:**
```elixir
Sigra.Email.deliver_login_code(config, user, code)
Sigra.Auth.verify_login_code(config, user, code)
```

## Anti-Patterns to Avoid

### Anti-Pattern 1: Hidden Remote State
**What:** Critical auth behavior configured only in hosted dashboards.
**Why bad:** Hard to diff, test, or review; breaks Sigra’s ownership model.
**Instead:** Keep canonical policy in code/config, with generators exposing local settings.

### Anti-Pattern 2: Callback-Driven Core Semantics
**What:** Requiring many callbacks to understand how sessions really work.
**Why bad:** Auth.js shows flexibility can become cognitive debt.
**Instead:** Prefer explicit modules, return tuples, and generated seams.

### Anti-Pattern 3: Passkeys Before Recovery
**What:** Shipping WebAuthn first and account recovery later.
**Why bad:** Support burden and lockout risk.
**Instead:** Gate passkey rollouts behind verified email plus recovery and session tooling.

## Scalability Considerations

| Concern | At 100 users | At 10K users | At 1M users |
|---------|--------------|--------------|-------------|
| Sessions | Simple DB rows + list/revoke UI | Add indexed queries and cleanup jobs | Partition/retention strategy, batched revocation, export pipelines |
| Email flows | Inline or queued send | Queue + delivery retries + template testing | Provider failover, tracking-safe templates, code-first fallback |
| Passkeys | Basic enrollment/auth | Better admin/debug metadata | Strong ceremony observability and RP/origin tooling |
| Admin actions | Direct mutation + audit | Actor-aware audit + safeguards | Dedicated export jobs, impersonation controls, tighter policy seams |

## Sources

- Devise README: https://github.com/heartcombo/devise
- django-allauth headless config: https://docs.allauth.org/en/dev/headless/configuration.html
- django-allauth usersessions config: https://docs.allauth.org/en/dev/usersessions/configuration.html
- Laravel Fortify: https://laravel.com/docs/12.x/fortify
- Laravel starter kits: https://laravel.com/docs/12.x/starter-kits
- Laravel Jetstream browser sessions: https://jetstream.laravel.com/features/browser-sessions.html
- Clerk session tasks: https://clerk.com/docs/guides/development/custom-flows/authentication/session-tasks
- Clerk session options: https://clerk.com/docs/guides/secure/session-options
- Clerk impersonation: https://clerk.com/docs/guides/users/impersonation
- Supabase sessions: https://supabase.com/docs/guides/auth/sessions
- Supabase email templates: https://supabase.com/docs/guides/auth/auth-email-templates
- Auth.js repo README: https://github.com/nextauthjs/next-auth

