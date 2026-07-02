---
created: 2026-06-26T00:00:00.000Z
status: pending
title: lock per-user audit pagination nav + desktop code-disclosure with deterministic tests
area: admin-ui
files:
  - test/example/test/example_web/live/admin_audit_user_live_test.exs
  - test/example/test/example_web/live/admin_audit_index_live_test.exs
  - test/example/priv/playwright/tests/admin-design.spec.ts
source: 202-REVIEW.md (WR-01, WR-02) — Phase 202 code-review gate
resolves_phase: 204
---

> **Re-tagged 2026-06-26 (Phase 203 close):** originally tagged `resolves_phase: 203`,
> but Phase 203's chartered scope was consistency propagation (Overviews, Branding
> workbench, ledger) and none of its five plans touched the per-user audit tests — so it
> was NOT resolved by 203. Moved to **Phase 204 (Terminal Ratification)**, which already
> owns the remaining downstream audit work (mobile baseline recapture). Still genuinely
> open: `admin_audit_user_live_test.exs` has zero pagination coverage. (The global-index
> leg referenced below was already closed by Phase 202's D-10 boundary test.)


## Why deferred

Phase 202 (audit-surfaces-elevation) collapsed the two audit LiveViews onto shared
components and added a deterministic ExUnit pagination boundary test — but only for the
**global** audit index. The code-review gate surfaced two test-coverage gaps that are
worth hardening but are out of scope for 202's elevation goal:

- **WR-02 (warning):** `audit_pagination_nav/1` is shared by both audit LiveViews, yet
  the new ExUnit boundary test covers only `audit_index_live`. The per-user
  `page_path/4` (which threads `user_id` + `return_to` into the nav href) has no ExUnit
  coverage, and the Playwright per-user pagination assertions are wrapped in a
  `count() > 0` guard that silently no-ops on low-event seeds. A deterministic per-user
  boundary test (≥26 events → nav present with correct user-scoped hrefs; ≤25 → absent)
  would close this.

- **WR-01 (warning, by-design but unlocked):** the extracted `audit_table_row/1`
  intentionally relocates **both** raw codes (event id + action code) into a collapsed
  `<details>` on the desktop table — this is the ratified Phase 202 design (202-01 plan +
  202-UI-SPEC + the 202-05 design-contract "inline code disclosure" archetype). It is
  **not** a regression, but the reviewer's point stands: the desktop default-collapsed
  state is currently implicit. The Playwright `code.sg-code` count guard can't catch a
  future regression here because `<details>` keeps children attached. Add an explicit
  assertion that the desktop Event cell's codes live inside a `<details>` (and that the
  `<summary>` is the visible-by-default affordance) so the intended collapse is locked.

## How to apply

Add the two deterministic ExUnit cases to the per-user audit test and one structural
Playwright/LiveView assertion for the desktop `<details>` code disclosure. Neither
requires product changes — both lock existing, intended behavior. INFO findings from
202-REVIEW.md (one-directional equivalence guard, pre-existing duplicate GET input
names, format_date/1 vs format_timestamp/1 nil handling) can be evaluated at the same
time but are lower priority.
