---
phase: 10
plan: 04
subsystem: docs
tags: [dx, docs, ex_doc, guides]
dependency-graph:
  requires:
    - 10-03 (cookie_domain config for subdomain-auth recipe reference)
  provides:
    - guides/ directory scaffold (15 stubs + 1 full recipe)
    - mix.exs :extras + :groups_for_extras wiring
  affects:
    - Plan 10-05 (content fill-in for 14 stubs)
tech-stack:
  added: []
  patterns:
    - ex_doc grouped sidebar (Introduction / Flows / Recipes)
    - Stub-first docs scaffolding so content fill-ins do not touch mix.exs
key-files:
  created:
    - guides/introduction/installation.md
    - guides/introduction/getting-started.md
    - guides/flows/registration.md
    - guides/flows/login-and-logout.md
    - guides/flows/password-reset.md
    - guides/flows/mfa.md
    - guides/flows/oauth.md
    - guides/flows/api-authentication.md
    - guides/flows/account-lifecycle.md
    - guides/flows/audit-logging.md
    - guides/recipes/testing.md
    - guides/recipes/subdomain-auth.md
    - guides/recipes/custom-user-fields.md
    - guides/recipes/multi-tenant.md
    - guides/recipes/deployment.md
    - guides/upgrading/.keep
  modified:
    - mix.exs
    - .planning/phases/10-developer-experience/deferred-items.md
decisions:
  - Kept `main: "readme"` at this stage; plan 05 flips to `"getting-started"` once the landing guide has real content (avoids ex_doc warnings on a stub landing page).
  - Only the subdomain-auth recipe is fully written now because it is the single doc artifact that depends on plan 03's `cookie_domain` config. Every other guide is a minimal stub deferred to plan 05.
  - Did not add `before_closing_head_tag`, custom CSS, or hand-written `llms.txt`; ex_doc >= 0.40 auto-generates `llms.txt` per CLAUDE.md.
metrics:
  completed: "2026-04-10"
  tasks_completed: 2
---

# Phase 10 Plan 04: Docs Scaffold Summary

One-liner: Scaffolded the ex_doc guide tree (15 stubs + 1 full subdomain-auth recipe) and wired it into `mix.exs` with a grouped sidebar, so plan 05 can fill content without touching build config.

## What Was Built

- Created `guides/` tree with four top-level directories — `introduction/`, `flows/`, `recipes/`, `upgrading/` — exactly matching the DX-02 structure from 10-RESEARCH `§Recommended Project Structure`.
- Wrote 14 stub markdown files, each with an H1 title, a one-line "Stub — full content lands in Phase 10 plan 05" note, and a one-paragraph description of what the guide will cover. Stubs intentionally link to `getting-started.html` and the `Sigra` module docs so they compile clean under ex_doc's internal link checker.
- Wrote the full `guides/recipes/subdomain-auth.md` recipe (68 lines): covers the `:cookie_domain` config key, leading-dot rule, why there is no auto-detection, the Phoenix session cookie twin-config pattern, the `Sigra.Application` prod boot warning, local testing via `localtest.me`, and three common pitfalls. All code examples use `System.get_env("COOKIE_DOMAIN")` — no hardcoded secrets (T-10-04 mitigation).
- Added an empty `guides/upgrading/.keep` placeholder so the directory is tracked in git for D-12's future version-migration guides.
- Replaced the stub `defp docs/0` in `mix.exs` with the full config: `main: "readme"`, `source_url: @source_url`, `:extras` listing README + CHANGELOG + all 15 guide paths, `:groups_for_extras` with `Introduction`/`Flows`/`Recipes` regex entries, and `:groups_for_modules` grouping `Core`/`Plugs`/`MFA`/`Audit`/`Testing`.
- Verified the build: `mix docs` (non-strict) exits 0, generates `doc/index.html`, emits a `doc/{guide}.html` file for every one of the 15 guides, and the sidebar JS (`doc/dist/sidebar_items-*.js`) contains all three expected groups (`Introduction`, `Flows`, `Recipes`).

## Must-Haves Audit

- ✅ `mix.exs docs/0` includes all 15 guide files in `:extras` and three `:groups_for_extras` entries (`grep -c 'guides/' mix.exs` = 18 counting the regex entries; `grep -c 'groups_for_extras' mix.exs` = 1).
- ✅ All 15 guide markdown files exist as stubs with H1 title and one-paragraph intro. `rg -c '^# ' guides/introduction/installation.md` = 1; stubs are 5 lines each.
- ✅ `subdomain-auth.md` documents the cookie_domain config: 12 matches for `cookie_domain`, 68 lines, covers leading-dot rule, env-var pattern, and public-suffix warning.
- ⚠️  `mix docs --warnings-as-errors` does NOT exit 0, BUT every failure is a pre-existing `@doc` reference warning from unrelated modules (`lib/sigra/oauth/strategies/{github,google,facebook,apple}.ex`, `lib/sigra/session.ex`, `lib/sigra/audit/changeset.ex`, `lib/sigra/rate_limiters/hammer.ex`). Confirmed pre-existing via `git stash` + rerun on the baseline — same warnings present before this plan. Logged to `deferred-items.md`. Non-strict `mix docs` succeeds and all guides render correctly. Per Phase 10 scope boundary, pre-existing warnings in unrelated files are out of scope for the docs-scaffolding plan.

## Deviations from Plan

### Scope boundary decisions

**1. [Scope] Pre-existing `mix docs --warnings-as-errors` failures not fixed**
- **Found during:** Task 2 verification
- **Issue:** `mix docs --warnings-as-errors` fails due to 11 pre-existing `@doc` reference warnings in OAuth strategy wrappers, Sigra.Session, Sigra.Audit.Changeset, and Sigra.RateLimiters.Hammer.
- **Decision:** Logged to `.planning/phases/10-developer-experience/deferred-items.md` (2026-04-10 entry) with full list and bisect proof. Not fixed because (a) the warnings are 100% unrelated to guide scaffolding (zero warnings reference `guides/`), and (b) touching OAuth/Audit/Session/RateLimiter module docs is outside the plan's `files_modified` list and would balloon scope into a doc cleanup plan of its own.
- **Files modified:** `.planning/phases/10-developer-experience/deferred-items.md`
- **Commit:** c7b8caf

No other deviations — plan 10-04 executed as written.

## Verification

| Check | Result |
|-------|--------|
| 15 guide files + `.keep` exist | ✅ All 16 files present |
| H1 count on each stub | ✅ 1 (single H1) |
| subdomain-auth.md has >= 60 lines | ✅ 68 lines |
| subdomain-auth.md `cookie_domain` mentions >= 5 | ✅ 12 matches |
| mix.exs `:groups_for_extras` present | ✅ 1 match |
| mix.exs `guides/` lines in :extras | ✅ 15 paths (18 grep matches incl. regex entries) |
| `mix docs` (non-strict) builds cleanly | ✅ exits 0, `doc/index.html` generated |
| All 15 guide HTML files rendered | ✅ `doc/subdomain-auth.html` etc. all present |
| Sidebar groups rendered | ✅ `sidebar_items-*.js` lists Introduction, Flows, Recipes |
| `mix docs --warnings-as-errors` | ⚠️  Fails on pre-existing module doc warnings (see Deviations); deferred |

## Known Stubs

14 of the 15 guides are intentional stubs targeted for content fill-in in plan 10-05:

| Guide | File | Reason |
|-------|------|--------|
| Installation | `guides/introduction/installation.md` | Content in 10-05 |
| Getting Started | `guides/introduction/getting-started.md` | Content in 10-05 |
| User Registration | `guides/flows/registration.md` | Content in 10-05 |
| Login and Logout | `guides/flows/login-and-logout.md` | Content in 10-05 |
| Password Reset | `guides/flows/password-reset.md` | Content in 10-05 |
| MFA | `guides/flows/mfa.md` | Content in 10-05 |
| OAuth | `guides/flows/oauth.md` | Content in 10-05 |
| API Authentication | `guides/flows/api-authentication.md` | Content in 10-05 |
| Account Lifecycle | `guides/flows/account-lifecycle.md` | Content in 10-05 |
| Audit Logging | `guides/flows/audit-logging.md` | Content in 10-05 |
| Testing Auth Flows | `guides/recipes/testing.md` | Content in 10-05 |
| Custom User Fields | `guides/recipes/custom-user-fields.md` | Content in 10-05 |
| Multi-Tenant Apps | `guides/recipes/multi-tenant.md` | Content in 10-05 |
| Deployment | `guides/recipes/deployment.md` | Content in 10-05 |

These stubs are expected and explicitly called out in the plan frontmatter and objective. `subdomain-auth.md` is the one fully-written recipe because it depends on plan 10-03's `cookie_domain` work.

## Deferred Issues

- `mix docs --warnings-as-errors` cleanup for pre-existing `@doc` references in OAuth strategy wrappers, Sigra.Session, Sigra.Audit.Changeset, Sigra.RateLimiters.Hammer — logged in `deferred-items.md` (2026-04-10 entry). Schedule in a follow-up doc-polish plan.

## Commits

| Hash | Subject |
|------|---------|
| 985f2b1 | docs(10-04): scaffold guides tree with stubs and subdomain-auth recipe |
| c7b8caf | docs(10-04): wire 15 guides into mix.exs with grouped sidebar |

## Self-Check: PASSED

All claimed files and commits verified present:
- All 16 guide files created and on disk (verified by `ls`).
- mix.exs modified with full docs/0 config (verified by `grep` counts).
- Both commits in `git log` (985f2b1, c7b8caf).
- `doc/index.html` generated and all 15 guide HTML files rendered.
- Sidebar groups (Introduction, Flows, Recipes) present in generated `sidebar_items-*.js`.
- Pre-existing warning deferral logged in `deferred-items.md`.
