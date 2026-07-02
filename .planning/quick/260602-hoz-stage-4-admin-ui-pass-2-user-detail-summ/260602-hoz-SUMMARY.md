---
status: complete
phase: quick-260602-hoz
plan: 01
subsystem: admin-ui
tags: [admin, liveview, user-detail, summary-first, sg-tokens]
requires: [Detail.load!/3 (@detail.security/@detail.sessions/@detail.identity)]
provides: [security-summary facts strip, headline risk callout, session relative-recency cue, .sg-summary-facts CSS]
affects: [lib/sigra/admin/live/user_show_live.ex, test/example/priv/static/assets/css/app.css]
tech-stack:
  added: []
  patterns: [in-render computation (no new queries), reuse sg-kv/sg-list-row primitives, token-driven BEM additive CSS]
key-files:
  created: []
  modified:
    - lib/sigra/admin/live/user_show_live.ex
    - test/example/priv/static/assets/css/app.css
decisions:
  - "summary_alert/1 re-called inside the :if (pure + cheap) rather than a HEEX binding, per plan guidance."
  - "Risk callout defaults to nil for a healthy account (no calm 'All clear' line) for restraint."
metrics:
  duration: ~15 min
  completed: 2026-06-02
---

# Phase quick-260602-hoz Plan 01: Stage 4 — User Detail Summary-First

Made the admin user-detail screen summary-first for support: the top "Identity & Status" card now carries a scannable security facts strip (MFA / Passkeys / Active / Last seen) plus a single foregrounded risk callout (locked > unconfirmed > no-MFA), and the Sessions table gained a muted relative "x ago" recency cue beside each absolute timestamp.

## What Changed

- **Top card (Identity & Status):** Added `<dl class="sg-summary-facts">` below the existing identity/pills cluster with four term/value pairs — MFA state (`mfa_value/1`), passkey count (`passkey_count/1`, nil→0), active-session count (`length(@detail.sessions)`), and last activity (`last_activity/1`, max over non-nil session timestamps). Counts use `sg-summary-facts__num` for tabular-nums. Added a single tone callout (`sg-list-row` + `data-tone`) guarded by `:if={summary_alert(@detail)}`, surfacing only the highest-priority issue with pre-vetted needle-safe copy.
- **Sessions table:** "Last activity" cell now stacks the unchanged absolute timestamp (wrapped in a tabular-nums span) above a muted `sg-text-xs` relative cue from `relative_activity/1` (just now / Nm / Nh / Nd ago), rendered only when a timestamp exists.
- **New private helpers:** `passkey_count/1`, `last_activity/1`, `summary_alert/1`, `relative_activity/1` — all referenced in render (no unused fns). Reused existing `mfa_value/1`, `mfa_enabled?/1`, `activity_value/1`.
- **CSS:** Added `.sg-summary-facts` (flex/wrap/gap layout + top margin), `.sg-summary-facts > div` (column stack), and `.sg-summary-facts__num` (tabular-nums) inside `@layer sg-components`. Token-driven, BEM, mobile-first, no new `!important`, no existing primitives touched.

## Verification

- **Reserved-needle grep-proof** (each of the six occurs exactly once, at its real section heading, all below the top card):
  - `Sessions` → 1 (line 139)
  - `Security` → 1 (line 196)
  - `Identities` → 1 (line 210)
  - `Organizations` → 1 (line 231)
  - `Recent Audit` → 1 (line 262)
  - `Danger Zone` → 1 (line 291)
  The new top-card block uses only `MFA` / `Passkeys` / `Active` / `Last seen` and pre-vetted callout copy ("active logins", "second factor") — no reserved needle introduced above its real section.
- **Show test:** `admin_user_show_live_test.exs` → 8 tests, 0 failures (section-order test green; all pinned strings intact).
- **Compile:** `mix compile --warnings-as-errors` clean.
- **CSS present:** `.sg-summary-facts`, `.sg-summary-facts > div`, `.sg-summary-facts__num` confirmed in `@layer sg-components`.

## Deviations from Plan

None — plan executed exactly as written.

## Flags

- **Library-owned LiveView:** `lib/sigra/admin/**` is a path dep and is NOT hot-reloaded — a running server must be restarted to view the top-card / sessions changes. `app.css` is static and reloads immediately.
- **Baselines:** Screenshot baselines are refreshed in Stage 8, not this stage.

## Self-Check: PASSED
