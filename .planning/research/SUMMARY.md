# Research Summary: Sigra Auth Ecosystem Benchmark

**Domain:** batteries-included authentication libraries and products
**Researched:** 2026-05-07
**Overall confidence:** HIGH

## Executive Summary

The strongest auth products split into two camps. Devise, django-allauth, and Laravel Fortify/Jetstream win by giving developers normal application code plus a well-defined auth core. Clerk and Supabase win by shipping polished hosted UX, session controls, and admin affordances fast. Auth.js sits between those camps: flexible and portable, but easier to misconfigure because more behavior lives in callbacks, adapters, and session strategy choices.

Across the benchmark set, the most durable success pattern is not “support every auth method”. It is “make the default journey legible”: sign in, verify email, recover access, inspect sessions, complete required post-auth tasks, and only then layer passkeys, organizations, or impersonation. Jetstream’s browser session UX, allauth’s session tracking, Clerk’s session tasks, and Supabase’s explicit email-delivery guidance all point the same way: the boring auth surface matters more than novel factors.

The biggest recurring footguns are hidden coupling and surprising defaults. Devise exposes module toggles that require matching migration edits. allauth’s headless and passkey modes have prerequisite settings that are easy to miss. Auth.js has real power, but session strategy and credentials behavior are still a common source of confusion, and even the upstream repo now recommends Better Auth for many new projects. Supabase and Clerk reduce setup friction, but some of their “works by default” behavior is product-shaped rather than library-shaped, especially around JWT/session lifecycle, redirect handling, multi-session behavior, and admin affordances.

For Sigra, the best transferable lesson is Laravel’s and allauth’s shape: keep the backend/auth core opinionated, keep the generated app surface editable, and keep feature slices additive. The wrong lesson to copy is the hosted-product habit of hiding critical flows behind dashboards or opaque remote state. Sigra should stay host-owned, but borrow the polished defaults: browser session management, post-auth task routing, email code flows, export history, and impersonation-safe admin signals.

## Key Findings

**Stack:** Prefer a Fortify/allauth-style library core plus generated Phoenix controllers/LiveViews/templates, not a Clerk/Supabase-style hosted control plane.
**Architecture:** Treat sessions, email delivery, passkeys, and admin actions as separate installable slices over one canonical account/session model.
**Critical pitfall:** Shipping passkeys before email recovery, session management, and export/audit surfaces creates a polished demo but a weak real-world auth system.

## Implications for Roadmap

Based on research, suggested phase structure:

1. **Session UX First** - durable baseline before new factors
   - Addresses: session listing, revoke-other-sessions, sudo/reauth, post-auth tasks, account context switching
   - Avoids: JWT-first drift, invisible session state, weak admin ergonomics

2. **Email Stack Hardening** - every benchmark product depends on this more than marketing admits
   - Addresses: verification, login-by-code, invite/reset/change-email, template contracts, redirect shaping, scanner-safe flows
   - Avoids: broken magic links, enumeration leaks, provider-specific delivery surprises

3. **Passkeys as Additive UX** - strong feature, weak foundation if shipped too early
   - Addresses: enrollment, sign-in, rename/revoke, fallback/recovery, RP/origin guidance
   - Avoids: passkey-only dead ends, origin/subdomain confusion, weak recovery story

4. **Exports and Compliance Surface** - needed for trust and migration, not just enterprise checklists
   - Addresses: user export, audit export, identity-link/unlink notifications, export history, deletion evidence
   - Avoids: lock-in optics, poor incident response, migration pain

5. **Release/Admin Polish** - support operations and “feels complete” finish
   - Addresses: impersonation banners/signals, organization chooser, browser session UI polish, admin safety rails
   - Avoids: support-only hacks, unsafe admin actions, unclear pending-task states

**Phase ordering rationale:**
- Sessions and email are prerequisites for almost every recovery, compliance, and passkey story in the benchmark set.
- Passkeys transfer well only after Sigra has canonical recovery and session semantics.
- Export/admin polish is easier once the core auth objects and events are stable.

**Research flags for phases:**
- Phase Passkeys: needs deeper RP ID, subdomain, and recovery fallback research
- Phase Email: needs provider-level testing around link scanners, redirect flows, and codes vs links
- Phase Sessions/Admin: standard patterns, low research risk

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Verified against official Devise, allauth, Laravel, Clerk, Supabase, and Auth.js sources |
| Features | HIGH | Cross-product agreement on sessions, email, MFA, browser sessions, and post-auth tasks |
| Architecture | HIGH | Strong convergence around modular auth backends plus editable app-facing UI |
| Pitfalls | HIGH | Verified by official docs plus issue/discussion evidence for confusing defaults |

## Gaps to Address

- Auth.js official docs were less useful than the GitHub README plus discussion history for identifying present-day footguns.
- Clerk and Supabase export/compliance behavior is product-specific; Sigra should copy the UX ideas, not the hosted assumptions.
- Passkey UX still needs Sigra-specific guidance for Phoenix subdomain deployments and LiveView ceremony boundaries.

