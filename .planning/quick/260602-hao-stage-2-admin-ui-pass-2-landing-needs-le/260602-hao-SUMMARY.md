---
status: complete
phase: 260602-hao
plan: 01
subsystem: admin-ui
tags: [admin, liveview, landing, needs-led-ia, design-system]
requires: [Sigra.Admin.Users.Query.summary_counts/2]
provides: [jobs-first-landing, posture-strip, capability-surface]
affects: [lib/sigra/admin/live/index_live.ex, lib/sigra/admin/live/organization_live.ex, test/example app.css]
key-files:
  modified:
    - lib/sigra/admin/live/index_live.ex
    - lib/sigra/admin/live/organization_live.ex
    - test/example/priv/static/assets/css/app.css
decisions:
  - "Task 3 added CSS (NOT a no-op): existing primitives did not cover the demoted-secondary posture strip, compact metric links, or subordinate capability cards."
metrics:
  duration: ~12 min
  completed: 2026-06-02
commit: 2e5999ee
---

# Phase 260602 Plan hao: Stage 2 — Landing Needs-Led Launcher Summary

Reshaped both admin landing surfaces into a needs-led launcher: job cards lead, metrics demote to a compact posture strip with a foregrounded "N accounts need review" risk line, and the global landing gains an evaluator capability surface ("What Sigra can do").

## What Changed

### `lib/sigra/admin/live/index_live.ex` (GLOBAL landing)
- Header unchanged (h1 "What do you need to do?" preserved verbatim); copy lightly tightened, still describes starting from the job and live counts.
- JOBS FIRST: the three `task_card` cells (`sg-grid sg-grid--3`) now render directly under the header, above the metrics. Relabeled to needs-led verbs ordered Sam → Riley → triage: "Find a user" → "Investigate an event" → "Review risky accounts".
- POSTURE STRIP: new `<section class="sg-card sg-posture-strip ...">` below the jobs. First row is a foregrounded risk line — `needs_review = locked + deleted` rendered as a linked `sg-status-pill` (tone `risk` when >0 else `ok`) reading "N accounts need review" / "All clear", linking to `/admin/users?locked=true`. Below it, six counts as compact `metric_link` entry points. **Newly surfaced the passkeys count** (`?passkeys=true`) which was not previously shown. All six filter hrefs preserved (Total, Confirmed, MFA, Passkeys, Locked, Deleted).
- CAPABILITY SURFACE: new bottom section "What Sigra can do" with seven static `capability` items (Sessions, MFA (TOTP), Passkeys, OAuth identities, Audit evidence, Impersonation, Organization scoping). Static text only, subordinate styling.
- Removed now-unused `tile/1` and `status_label/1`. Added local components `metric_link/1`, `capability/1`, and helper `needs_review/1`.

### `lib/sigra/admin/live/organization_live.ex` (ORG landing)
- Header unchanged (pinned substring "Work inside this organization scope" preserved verbatim in the copy paragraph).
- JOBS FIRST: the two `task_card` cells (`sg-grid sg-grid--2`) moved to lead, above metrics and the Scoped attention card. Relabeled to "Support members" / "Investigate org events".
- Scoped attention card retained and tightened (copy trimmed); posture pill (Healthy/Needs review driven by locked>0) and the two `sg-list` rows kept.
- POSTURE STRIP: replaced the 4-tile `sg-metric-grid` with the same `sg-posture-strip` grammar — org-scoped risk line (`needs_review = locked + deleted`) linking to `users_path <> "?locked=true"`, plus five compact `metric_link`s (Users, Confirmed, MFA, **Passkeys (newly surfaced)**, Locked) all via the existing `users_path/1` helper. Added one short org-bounded capability line.
- Removed now-unused `tile/1` and `status_label/1`. Added `metric_link/1` and `needs_review/1`. Kept `organization_name/1`, `users_path/1`, `audit_path/1`, `locked_summary/1`, `runtime_config!/0`.

### `test/example/priv/static/assets/css/app.css`
- **Task 3 added CSS (not a no-op).** Three additive primitive groups inside `@layer sg-components`, after the tile rules:
  - `.sg-posture-strip` (+`__risk`): secondary surface (`--sg-color-panel-alt`, reduced `--sg-space-3` padding, `--sg-elev-inset` instead of full elevation) so it reads below the job cards; focusable risk link.
  - `.sg-metric-link` (+`__label`/`__value`): compact column entry point smaller than `sg-tile` (muted uppercase label, `--sg-text-sm` tabular value, hover `--sg-elev-1`, focus-visible ring).
  - `.sg-capability__item` (+`__label`/`__desc`): subordinate inset card for the evaluator surface.
- Token-driven, BEM, mobile-first, dark-mode-safe (all referenced tokens have dark overrides). No new `!important` (count unchanged at 7). Lives only in `test/example`; no install-template counterpart for landing CSS to keep in sync.

## Deviations from Plan

None — plan executed as written. Task 3 was the conditional ("only if reuse insufficient") path; reuse was insufficient for the secondary/compact/subordinate treatments, so the three primitive groups were added as specified.

## Verification

- `mix compile --warnings-as-errors`: **clean** (no unused private fns — `tile/1` and `status_label/1` removed from both files).
- Pinned substrings (grep-confirmed):
  - GLOBAL `lib/sigra/admin/live/index_live.ex` contains `What do you need to do?` — **OK**
  - ORG `lib/sigra/admin/live/organization_live.ex` contains `Work inside this organization scope` — **OK**
- All metric/job hrefs preserved (global: `confirmed/mfa/passkeys/locked/deleted=true` + `/admin/audit`; org via `users_path`/`audit_path`). Risk line (`accounts need review`) present on both. Capability surface (`What Sigra can do`) present on global.
- `test/example_web/admin_shell_test.exs`: **6 tests, 0 failures**.
- New CSS classes all referenced by the reshaped LiveViews; `!important` count unchanged (7).

## Flags

1. **Library-owned LiveViews** — `lib/sigra/admin/live/*` are consumed by the example app via a non-hot-reloaded path dep. The reshape is **invisible until the server restarts**. The orchestrator handles the restart.
2. **Screenshots** — landing screenshots/baselines are NOT captured here; Stage 8 refreshes any landing baselines (landing baselines are not pinned).
3. **Task 3 CSS** — added (not a no-op): `sg-posture-strip`, `sg-metric-link`, `sg-capability` primitives.

## Self-Check: PASSED

- `lib/sigra/admin/live/index_live.ex` — modified, compiles, pinned substring present.
- `lib/sigra/admin/live/organization_live.ex` — modified, compiles, pinned substring present.
- `test/example/priv/static/assets/css/app.css` — modified, no new `!important`.
- Commit `2e5999ee` exists and `git show --stat HEAD` lists exactly the three files.
