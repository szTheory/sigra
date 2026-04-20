# Technology Stack

**Project:** Sigra v1.2 Admin Dashboard
**Researched:** 2026-04-16

## Recommended Stack

### Core Framework
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Phoenix | `~> 1.8` (current: 1.8.5) | Web/runtime foundation | Reuse. v1.2 does not need a framework change. Sigra already targets Phoenix 1.8, and the example app is already on 1.8.5. |
| Phoenix LiveView | `~> 1.1` (current: 1.1.28) | Default-on admin UI | Reuse and lean in harder. `live_session`, `on_mount`, `handle_params/3`, `stream/4`, and `start_async/3` cover the admin dashboard without adding a JS SPA layer. |
| Phoenix.Component / HEEx | bundled with Phoenix/LiveView | Admin pages, tables, filter forms, banners | Keep the existing component model. The admin surface should be generated HEEx plus a small set of reusable admin components, not a second frontend stack. |

### Database
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Ecto / Ecto SQL | `~> 3.12` in library, `~> 3.13` in example app | Queries, transactions, admin/audit data access | Reuse. Impersonation, admin user management, and audit exploration fit the existing context + query-module pattern. No ORM or query-builder addition is warranted. |
| PostgreSQL | existing primary target | Audit exploration and admin search/filter workloads | Reuse. Rich audit exploration should continue to use Postgres indexes + cursor-style query shapes, not a search engine or analytics store. |

### Infrastructure
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Bandit | keep adapter; current latest: 1.10.4 | HTTP/WebSocket serving for example app and smoke envs | Reuse. No adapter swap is needed for v1.2. A routine bump from the example app's `~> 1.5` to a current `~> 1.10` is reasonable when touching dependency maintenance, but it is not a gating change for the milestone. |
| Oban | existing `~> 2.17` optional dep | Background cleanup / export jobs if needed | Reuse only where already justified. Do not introduce new workers unless v1.2 actually ships async admin exports or cleanup tasks. |
| Swoosh | existing `~> 1.5` optional dep | Existing email flows | Reuse. v1.2 does not need new mail infrastructure. |

### Supporting Libraries
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `lazy_html` | `>= 0.1.11` test-only | Required by `Phoenix.LiveViewTest` in the example app | Keep exactly as the LiveView test helper dependency. Needed for admin LiveView tests; do not promote it beyond test scope. |
| `@playwright/test` | current: 1.59.1 | Browser automation, screenshots, video, traces, HTML report | Keep the existing Playwright harness and extend it for admin flows. This is the right stack for automation-first UX review artifacts. |
| Playwright built-in HTML reporter | bundled with Playwright | Human-reviewable artifacts in CI | Required. Sigra already uses HTML reporting; keep it and make it the default review artifact. |
| Playwright trace viewer | bundled with Playwright | Failure debugging | Required. Keep `trace: "on-first-retry"` or tighten to `retain-on-failure` only if retries are removed. |
| Playwright screenshots | bundled with Playwright | Quick visual review of failed admin flows | Add `screenshot: "only-on-failure"` to the existing config. Low cost, directly useful in review. |
| Playwright video | bundled with Playwright | Asynchronous UX inspection for failures/flaky browser-only issues | Add `video: "retain-on-failure"` in CI-oriented runs. This matches the milestone's review-artifact goal without extra tooling. |

## Required Stack Changes For v1.2

### 1. Keep the admin UI in LiveView; do not add a frontend framework

Use the existing Phoenix 1.8 + LiveView stack for the whole admin surface:

- Route admin screens behind dedicated `live_session` boundaries.
- Reuse `on_mount` for admin scope hydration, impersonation state, and org-aware gating.
- Use `handle_params/3` for filter/sort/tab state so audit exploration is URL-addressable.
- Use `stream/4` for user lists and audit feeds where rows change over time.
- Use `start_async/3` only for expensive secondary loads, such as loading side panels or aggregate counts, not for baseline page correctness.

This fits Sigra's existing architecture. The example app already uses `live_session`, `on_mount`, and `stream/3`, so v1.2 should extend that pattern instead of introducing React, Alpine, Surface, or a datagrid framework.

### 2. No new impersonation library; implement impersonation inside Sigra's session/scope model

Impersonation is not a library problem. It is a session, audit, and authorization problem.

Required stack-level choice:

- Reuse Sigra's database-backed session model.
- Reuse `Sigra.Scope` hydration and add impersonation metadata there.
- Reuse existing sudo boundaries and audit metadata flow.
- Keep impersonation state server-side in the session row / scope hydration path, not in signed browser-only state and not in a separate token system.

That means:

- no `Phoenix.Token`-based impersonation mode,
- no separate JWT just for impersonation,
- no third-party masquerade package.

The only v1.2 change here is schema/config/code in Sigra itself, not a dependency addition.

### 3. Rich audit exploration should stay on Ecto + existing audit modules

Sigra already has `Sigra.Audit`, `Sigra.Audit.Query`, and `Sigra.Audit.Cursor`. Build on those.

Recommended pattern:

- keep filtering and pagination in query modules,
- use cursor-based exploration for audit feeds,
- use URL params to drive filters,
- add the necessary DB indexes and denormalized columns in Sigra's own tables,
- render results in LiveView.

Do not add:

- Elasticsearch / Meilisearch / Typesense,
- a BI/reporting tool,
- a general-purpose table/query DSL just for admin pages.

That would be a disproportionate stack jump for v1.2.

### 4. Expand the existing Playwright stack instead of adding browser-test/reporting products

The current harness is already close to the target. Keep it in `test/example/priv/playwright` and extend it.

Recommended baseline config changes:

```ts
reporter: [['list'], ['html', { open: 'never' }]],
use: {
  trace: 'on-first-retry',
  screenshot: 'only-on-failure',
  video: process.env.CI ? 'retain-on-failure' : 'off',
}
```

Keep:

- one Chromium project for smoke and review flows,
- serial execution where DB state is intentionally shared,
- HTML report upload in CI,
- trace artifacts for retried failures.

Optional only if CI consumers need machine-readable summaries:

- add Playwright's built-in `junit` reporter.

Do not add Allure, Cypress, Wallaby, Hound, or another screenshot/video service. Playwright already covers the requirement.

### 5. Reuse the example-app stack for verification, not a second demo app

The existing `test/example` app already exercises generated Sigra behavior under Phoenix + LiveView + Bandit. Extend that app for:

- admin user list/detail flows,
- impersonation banner and exit flow,
- audit exploration filters,
- curl/HTTP smoke coverage for non-LiveView endpoints around impersonation and exports.

That preserves one blessed integration target instead of fragmenting verification across multiple apps.

## Optional Nice-to-Haves

| Addition | Recommendation | Why it is optional |
|----------|----------------|--------------------|
| Bandit bump in example app | Move from `~> 1.5` to a current `~> 1.10` during routine dependency maintenance | Good hygiene, but not required to unlock admin/dashboard work. |
| Playwright JUnit reporter | Add only if CI or external tooling wants XML summaries | Useful for CI dashboards, not needed for review artifacts themselves. |
| Playwright blob reporter | Add only if Sigra later shards tests across CI jobs | Helpful for report merging, unnecessary for the current single-project harness. |

## Reuse From Existing Stack

These should be treated as fixed points, not reopened decisions:

| Existing piece | Reuse in v1.2 |
|----------------|---------------|
| `Sigra.Scope` + hydration pipeline | Carry admin role/org/impersonation state through the same mechanism. |
| `Sigra.Plug.RequireSudo` | Gate impersonation start/stop and sensitive admin actions. |
| Existing audit schema/query modules | Extend for dual-actor and richer filters; do not replace. |
| Phoenix router + `live_session` | Separate public, authenticated, org-scoped, and admin-scoped surfaces cleanly. |
| Example app Playwright harness | Add admin specs and richer artifacts there. |
| `lazy_html` test dependency | Keep for LiveView test coverage on new admin LiveViews. |
| Bandit example adapter | Keep the same serving model for local and CI smoke runs. |

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| Admin UI | Phoenix LiveView | React/Vue SPA | Adds a second frontend architecture, more generated code complexity, and more asset/test surface without solving a real v1.2 problem. |
| Admin toolkit | Hand-rolled LiveView components | Backpex / Phoenix LiveDashboard / generic admin packages | Sigra needs shipped generator-owned auth/admin UX, not a runtime dev dashboard or a heavyweight admin abstraction. |
| Impersonation | First-class Sigra session/scope mode | Token-only masquerade library | Wrong trust boundary; weakens auditability and session control. |
| Audit exploration | Ecto queries + LiveView + indexes | Search engine / analytics store | Operationally expensive and unnecessary for v1.2 scale. |
| Browser automation | Playwright | Wallaby / Hound / Cypress | Playwright already exists in-repo and natively provides HTML report, traces, screenshots, and video. |
| UI interactions | `Phoenix.LiveView.JS` + small hooks | Alpine.js / extra client framework | LiveView already covers the needed interaction model; extra client state is more surface area to maintain. |

## Explicitly Do Not Add

1. A JS SPA framework for the admin dashboard.
2. A third-party impersonation or masquerade library.
3. A new search/reporting backend for audit exploration.
4. Wallaby, Hound, Cypress, Allure, Percy, or any separate browser-artifact vendor.
5. A generic admin framework as a core dependency.
6. A second example/demo app just for admin verification.

## Installation

```bash
# No new Elixir dependency is required for the admin dashboard itself.
# Keep the existing Phoenix/LiveView/Ecto stack.

# Browser review artifacts: extend the existing Playwright workspace
cd test/example/priv/playwright
npm install

# Optional only if you add CI XML summaries
# npm install remains enough; use Playwright's built-in junit reporter in config
```

## Version-Sensitive Cautions

- **Phoenix / LiveView:** Phoenix is currently `1.8.5` and Phoenix LiveView is currently `1.1.28`. Sigra should stay within those lines for v1.2; do not turn this milestone into a framework migration.
- **Bandit:** latest is `1.10.4`, but the example app is still on `~> 1.5`. That is a maintenance bump, not a new-capability requirement.
- **Playwright:** current `@playwright/test` is `1.59.1`, which matches the checked-in lockfile. Keep the harness current, but do not add parallel browser matrices until the admin flows are stable.
- **`lazy_html`:** current `0.1.11`. Keep it test-only. It is there to support LiveView tests, not to solve any runtime concern.

## Sources

- https://hex.pm/packages/phoenix
- https://hex.pm/packages/phoenix_live_view
- https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html
- https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.Router.html
- https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.JS.html
- https://hex.pm/packages/bandit
- https://hex.pm/packages/lazy_html
- https://playwright.dev/docs/test-use-options
- https://playwright.dev/docs/test-reporters
- https://playwright.dev/docs/trace-viewer
- https://www.npmjs.com/package/@playwright/test
