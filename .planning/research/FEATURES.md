# Feature Landscape

**Domain:** Authentication library admin surface for Phoenix/LiveView
**Researched:** 2026-04-16
**Confidence:** HIGH for automation expectations and impersonation guardrails; MEDIUM-HIGH for admin-UI feature shape because vendor docs are clearer on capabilities than on UX tradeoffs

## Scope

This file covers only the new v1.2 admin capabilities:

- admin user-management UI
- secure impersonation
- expanded audit exploration
- automation-backed UI verification artifacts

It does **not** revisit v1.0 auth primitives or v1.1 organizations/passkeys except where they are direct dependencies.

The recommendation is framed for **Sigra as a library-owned built-in admin surface**, not a generic SaaS back office. That means the surface should stay centered on identity, access, security, support, and evidence, not drift into billing/content/CRM work.

## Highest-Value Jobs To Be Done

These are the jobs strong auth/admin products optimize first.

| Persona | Job To Be Done | Why It Matters In v1.2 | Priority |
|---------|----------------|------------------------|----------|
| Persona A: solo SaaS builder | Find a user fast, answer "why can't they sign in?", and fix the problem from a phone without SSH/iex | This is the highest-frequency support loop for a built-in auth admin | P1 |
| Persona B: mid-market team | Investigate security state across user, org, session, MFA, passkey, and audit history from one place | This is where Sigra becomes credible beyond "starter auth" | P1 |
| Persona B: org admin/operator | Manage only users in the active org without cross-tenant leakage or ambiguous scope | v1.1 org scope is only valuable if the admin UI respects it by construction | P1 |
| Persona D: migration adopter | Get a usable admin panel immediately after install instead of building custom support tooling | Default-on admin is a major migration accelerant | P1 |
| Persona A/B support operator | Reproduce a user problem safely via impersonation, then leave a clean evidence trail | Strong products treat this as a support workflow, not a hidden dev trick | P1 |
| Persona B security/compliance owner | Search audit events by actor, target, org, date, and impersonation context, then export evidence | Audit value is mostly in investigation, not in passive collection | P1 |
| Persona C: API-heavy builder | Inspect and revoke sessions, PATs, linked identities, and suspicious access without dropping to SQL | Keeps Sigra's API/auth story coherent inside the admin surface | P2 |

## Table Stakes

Features users now expect from a strong auth/admin surface. Missing these makes the product feel incomplete.

| Feature | Why Expected | Complexity | Sigra Dependency | Notes |
|---------|--------------|------------|------------------|-------|
| Searchable user list with filters and stable pagination | Auth0, Clerk, FusionAuth, Supabase, and WorkOS all anchor admin work on a list-first flow | MEDIUM | v1.0 users/audit; v1.1 org scope | Search by email, name, id. Filters should cover status, MFA/passkey state, lock state, provider mix, org membership, and recent activity. |
| User detail page with auth-specific tabs | Strong products separate overview from sessions/security/identities/audit instead of cramming everything into one long page | MEDIUM | v1.0 sessions, MFA, API keys, audit; v1.1 passkeys/orgs | Minimum tabs: Profile, Sessions, Security, Identities, API Keys, Organizations, Audit, Danger Zone. |
| Session inspection and revocation | Support teams expect to see active sessions, device clues, IP, last activity, and revoke actions | LOW-MEDIUM | v1.0 active session tracking + revocation | This is one of the highest-value support actions and belongs near the top of user detail. |
| Security state summary | Operators expect a single place to see confirmation state, MFA/passkeys, lockouts, password age/change, suspicious login signals | MEDIUM | v1.0 MFA/lockout/suspicious login; v1.1 passkeys | Use a compact status summary before any deep tabs. The question is usually "is this account healthy?" |
| Org-aware visibility and actions | Admin tools in multi-tenant products are expected to prevent accidental cross-org leakage | MEDIUM | v1.1 active organization + membership scope | Platform admins can cross orgs; org admins must be constrained by default. No secondary mental model. |
| Per-user audit timeline | Auth products usually let operators pivot from user to their security history immediately | LOW-MEDIUM | v1.0 audit log; v1.1 org-aware audit metadata | Show both actions by the user and actions taken on the user. |
| Global audit exploration with filters | Audit logs are table stakes for security tooling, but only if they are searchable | MEDIUM | v1.0 `Sigra.Audit.query/1` | Filters should cover action, outcome, actor, target, org, date range, and impersonation state. |
| CSV export of current audit slice | Mature products expose export once filters exist; this is a frequent "send me evidence" job | MEDIUM | v1.0 audit infra; likely Oban for large jobs | Export must respect the active filter, not dump the entire table. |
| Secure impersonation entry and exit flow | WorkOS, Clerk, and Descope treat impersonation as a first-class support action with tight controls | MEDIUM | v1.0 sudo/session infra; v1.1 org scope; v1.0 audit | Start from user detail. Require explicit confirm, visible state, timeout, and one-click end. |
| Always-visible impersonation banner | This is universal best practice because session confusion is the core impersonation failure mode | LOW | LiveView/layout integration | Must be layout-level and non-dismissible. |
| Forbidden sensitive operations during impersonation | Modern implementations explicitly block password/MFA/token/security changes while impersonating | MEDIUM | new impersonation plugs/policies over v1.0 contexts | Enforce server-side, not just by hiding buttons. |
| Dual-actor audit trail during impersonation | Without dual-actor attribution, impersonation corrupts the audit story | MEDIUM | new audit fields/metadata | Store real actor + effective user context for every impersonated action. |
| Mobile-usable user management | The user explicitly wants "manage users from phone"; modern internal tooling is expected to degrade cleanly to small screens | MEDIUM | LiveView UI work | Mobile should prioritize search, status summary, primary actions, and compact timelines over dense wide tables. |
| Light/dark support | This is expected even for internal tools now, especially on mobile/night use | LOW-MEDIUM | Phoenix/Tailwind implementation choice | Dark mode is not differentiation; broken dark mode is a tax. |
| HTML test report plus trace/video/screenshot artifacts for key flows | Playwright has made artifact-rich UI review a baseline expectation for serious UI work | MEDIUM | existing CI/browser smoke foundation from v1.1 | The admin UI should be reviewable asynchronously, not only by manual walkthrough. |

## Differentiators

These are the features that make Sigra's admin surface feel notably better than a typical generated/internal panel.

| Feature | Value Proposition | Complexity | Sigra Dependency | Notes |
|---------|-------------------|------------|------------------|-------|
| Auth-first information architecture | Keeps the panel focused on support/security jobs instead of becoming a generic CRUD backend | LOW | none beyond scope discipline | Lead with account status, sessions, factors, identities, orgs, audit. Do not lead with editable profile forms. |
| "Why can't this user sign in?" summary card | Compresses the most common support diagnosis into one glance | MEDIUM | v1.0 lockout/MFA/email/session/passkey signals | Surface likely blockers: unconfirmed email, locked account, MFA required/unenrolled, no valid factor, revoked sessions, org mismatch, deleted account. |
| User detail optimized for action locality | The best admin UIs put the next likely action next to the data that motivated it | MEDIUM | existing actions across v1.0/v1.1 | Example: session revoke beside session row, invite resend beside membership/invite state, impersonate in danger zone with guardrails. |
| Explicit org-scope framing in the chrome | Prevents "which tenant am I operating in?" mistakes before they happen | LOW | v1.1 active org scope | Show current admin scope prominently, especially for org admins. |
| Impersonation session return path to the original admin context | Removes the biggest operational annoyance in support impersonation flows | LOW-MEDIUM | session model addition | Ending impersonation should cleanly return the admin to the original place in the admin UI. |
| Impersonation-aware audit filters and dedicated feed | Saves operators from reconstructing impersonation activity manually from raw events | MEDIUM | audit DSL extension | Dedicated view: who impersonated whom, when, and what happened during the window. |
| Security-event quick views | Faster than forcing every operator to build custom filters repeatedly | LOW | audit taxonomy already exists | Prebuilt filters: failed logins, lockouts, suspicious logins, MFA changes, passkey changes, API key events, impersonation. |
| Basic branding hooks without runtime theming | Matches the "internal tool, but polished" need without creating design-system drag | LOW | config struct/generator wiring | App name, logo, accent color. No theme builder. |
| Library-shipped verification artifacts | Strong for a library: generated admin UI ships with tests that emit screenshots/reports, not just compile | MEDIUM | v1.1 CI/browser smoke groundwork | This helps downstream teams trust upgrades and inspect UX diffs quickly. |
| Mobile action sheets instead of horizontal-table hell | Most weak admin UIs simply squash desktop tables onto mobile | MEDIUM | LiveView responsive implementation | On mobile, list rows should collapse to stacked summaries with 1-3 primary actions and drill-in detail, not overflow-scroll as the only answer. |

## Anti-Features

Things to explicitly avoid in v1.2.

| Anti-Feature | Why Avoid | What To Do Instead |
|--------------|-----------|-------------------|
| Turning the admin into a generic business back office | Dilutes the product, increases surface area, and makes the auth jobs worse | Keep the surface strictly identity/access/support/audit focused |
| "First user is admin" magic | Common shortcut, dangerous in libraries, and hard to reason about in real deployments | Require host-app `is_admin?/1` or equivalent explicit admin bootstrap |
| Editable everything on one mega-form | This is the failure mode of many crude admin panels; it hurts scanability and makes risky actions too easy | Use task-oriented tabs and local actions |
| Bulk actions as a v1.2 centerpiece | Bulk lock/delete looks powerful but creates sharp edges, weak mobile UX, and verification complexity | Start with single-user actions; add limited bulk actions only where audit and preview are solid |
| Read/write impersonation without restrictions | This is how impersonation turns into a privilege-escalation hazard | Forbid password, MFA, passkey, PAT, and destructive account actions while impersonating |
| Dismissible or page-local impersonation banner | Easy to miss, easy to break, high risk of operator confusion | Render a layout-level persistent banner in every admin/user page |
| Audit UI as a vanity dashboard | Big charts are low value for support/security compared with table filters and export | Prefer dense searchable event views with saved/preset filters |
| Mobile strategy of "just horizontal scroll the desktop table" | Works technically, fails operationally | Use stacked list cards, compact summaries, and bottom-aligned primary actions on mobile |
| Runtime theming engine | High maintenance for a low-value internal-tool feature | Basic branding tokens only |
| Human-only UI verification | The user explicitly wants automation-first review ergonomics | Ship Playwright coverage with HTML report, trace, screenshot, and targeted video artifacts |
| Generic "activity feed" that mixes business and auth events | Makes support investigation slower and noisier | Keep audit focused on security and auth/admin actions |

## Mobile Expectations

Strong products do not replicate desktop density on phones. For Sigra:

| Expectation | Why | Complexity | Notes |
|-------------|-----|------------|-------|
| Search-first landing on mobile | Most phone workflows start with "find user X now" | LOW | Put search and key filters above the list. |
| Status summary before deep detail | Operators need account health quickly on a small screen | LOW | Show confirmation, lock state, MFA/passkey state, org count, session count. |
| Stacked row summaries for user list | More readable than a compressed data table | MEDIUM | Email/name/status/actions in one vertical block. |
| One-thumb primary actions | Revoking sessions or ending impersonation must not be hidden in dense menus | LOW-MEDIUM | Use sticky or bottom-grouped actions where needed. |
| Safe destructive flows on touch | Mobile increases accidental-action risk | LOW | Require confirm text or second-step confirm for destructive actions. |
| Audit filters that collapse cleanly | Filter-heavy UIs are hard on mobile if every filter is always open | MEDIUM | Drawer/sheet pattern is preferable to a permanently open sidebar. |

## Review-Artifact Expectations

For this milestone, "verification" should produce inspectable UX evidence, not just pass/fail output.

| Artifact | Why It Matters | Complexity | Notes |
|---------|----------------|------------|-------|
| Playwright HTML report | Baseline navigable evidence for reviewers | LOW | Make this the default artifact linked from CI/local runs. |
| Trace viewer for critical failures and sensitive flows | Best debugging artifact for LiveView/admin regressions | LOW-MEDIUM | Required for impersonation, destructive actions, and filter-heavy flows. |
| Screenshots at key checkpoints | Fast async UX review without replaying tests | LOW | Capture desktop and mobile for user list, user detail, audit index, impersonation banner state. |
| Video only where it adds value | Full video for everything is noisy and expensive | LOW | Keep for impersonation and multi-step audit/filter flows; screenshots are enough elsewhere. |
| Explicit mobile viewport coverage | Mobile is a stated product requirement, not a courtesy | LOW | At minimum: common phone width plus desktop. |
| Route/controller smoke outside browser happy path | Proves the admin stack is robust beyond Playwright | LOW-MEDIUM | Include authz failures, impersonation guards, CSV export endpoints, and audit query params. |
| Stable seeded demo data for review | Review artifacts are hard to compare if fixtures drift | MEDIUM | Seed users with varied states: locked, MFA, passkey-only, org-admin, invited, deleted. |

## Feature Dependencies

```text
Admin user list/detail
  -> requires v1.0 users, sessions, MFA, identities, API keys, audit log
  -> requires v1.1 organizations + active organization scope
  -> requires v1.1 passkeys for Security tab completeness

Impersonation
  -> requires v1.0 sudo/re-authentication
  -> requires v1.0 session infrastructure
  -> requires v1.0 audit logging
  -> requires v1.1 org-aware scope for org-admin restrictions

Audit exploration
  -> requires v1.0 audit query/list primitives
  -> benefits from v1.1 organization_id audit metadata
  -> should extend to effective_user_id / impersonation filters in v1.2

Automation-backed review
  -> builds on existing Playwright/browser smoke and CI from v1.1
  -> depends on stable seeded admin fixtures and deterministic auth states
```

## MVP Recommendation

Prioritize:

1. Searchable user list with strong filters and mobile-ready rows
2. User detail with status summary, Sessions, Security, Organizations, Audit, and Danger Zone
3. Secure impersonation with banner, timeout, dual-actor audit, and forbidden sensitive actions
4. Global/per-user/per-org audit exploration with export and security-event presets
5. Playwright-backed review artifacts for desktop and mobile critical paths

Defer:

- broad bulk actions: high risk, lower leverage than strong single-user workflows
- analytics-heavy dashboard widgets: nice to have, not core to auth support jobs
- advanced theming/runtime customization: low value for an internal auth admin
- approval workflows/read-only impersonation reasons mode: worth reconsidering later, not needed for v1.2 MVP

## Recommended v1.2 Feature Categories

Use these categories for requirement shaping.

| Category | What Belongs Here | Why |
|---------|-------------------|-----|
| User Operations | user list, search, filters, user detail, sessions, identities, API keys, delete/reactivate/reset actions | Core support/admin workflow |
| Security Operations | account health summary, MFA/passkeys, lockouts, suspicious login context, security-event presets | Makes Sigra feel like an auth product, not a CRUD panel |
| Organization Context | org-scoped visibility, memberships, invites context, active-org framing | Required because v1.1 added org-aware auth |
| Impersonation | start/end flows, banner, restrictions, session handling, audit attribution | High-value support capability with large risk surface |
| Audit Exploration | per-user, per-org, global, impersonation feed, export, saved presets | Turns existing audit infra into usable evidence |
| Review Artifacts | Playwright report, screenshots, trace/video, mobile coverage, smoke endpoints | Matches the user’s automation-first verification requirement |

## Sources

- Auth0 docs, "Manage Users Using the Dashboard" and related logs/search docs — MEDIUM/HIGH confidence for user-list and audit expectations: https://auth0.com/docs/manage-users/user-accounts/manage-users-using-the-dashboard
- WorkOS docs, impersonation and user-management docs — HIGH confidence for impersonation guardrails and support workflow framing: https://workos.com/docs/user-management/impersonation
- Clerk docs, dashboard/user-management and organization admin docs — MEDIUM confidence for modern auth admin information architecture: https://clerk.com/docs
- FusionAuth docs, user management / admin UX / recent-login and audit capabilities — MEDIUM confidence for mature auth detail-page expectations: https://fusionauth.io/docs/
- Supabase docs and Studio references for auth user management and audit/log exploration patterns — MEDIUM confidence for responsive internal-tool patterns: https://supabase.com/docs
- Playwright docs, HTML reporter / trace viewer / screenshots / videos / visual comparisons / mobile emulation — HIGH confidence for automation-backed review artifact recommendations: https://playwright.dev/docs/test-reporters , https://playwright.dev/docs/trace-viewer , https://playwright.dev/docs/videos , https://playwright.dev/docs/screenshots , https://playwright.dev/docs/test-snapshots , https://playwright.dev/docs/emulation

## Confidence Notes

- **HIGH:** automation artifact expectations, impersonation guardrails, audit-search/export expectations
- **MEDIUM-HIGH:** user-list and user-detail structure across auth products
- **MEDIUM:** mobile conventions inferred across admin products because vendors document capability more consistently than exact small-screen UX choices
