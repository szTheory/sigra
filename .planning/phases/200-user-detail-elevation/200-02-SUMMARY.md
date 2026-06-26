---
phase: 200-user-detail-elevation
plan: "02"
subsystem: admin-live
tags: [admin, liveview, user-detail, jtbd, bounded-preview, sessions-link-out, host-seam, glossary]
dependency_graph:
  requires:
    - "200-01 (UserSessionsLive + /admin/users/:id/sessions route)"
  provides:
    - "lib/sigra/admin/live/user_show_live.ex (JTBD-first recompose)"
  affects:
    - "Plan 03 (Playwright checkpoints for user-detail slug recapture + user-sessions slug)"
tech_stack:
  added: []
  patterns:
    - "calm identity bar: kicker + h1 + secondary identity + compact metrics strip + single priority alert + status pills"
    - "bounded preview (max 3 rows) with link-out CTA for unbounded sub-lists"
    - "sessions_path/3 scope-aware helper (mirrors full_audit_path/3 shape)"
    - "JTBD-first section ordering per UI-SPEC Page Composition Contract"
key_files:
  created: []
  modified:
    - lib/sigra/admin/live/user_show_live.ex
decisions:
  - "Danger Zone 'Revoke all sessions' button removed — session revocation deferred entirely to UserSessionsLive per D-04 (Claude's-discretion default: calm detail page)"
  - "Metrics strip reduced to 3 facts (Sessions count, MFA, Last seen) — passkeys dropped from strip (not top-3 scan-worthy); passkey_count/1 helper removed"
  - "Organizations 'View all organizations' link targets first org's pivot_path (opens org-scoped view) — scoped pivot is the correct 'view all' affordance when >3 orgs exist in global scope"
  - "Session table header column 'Action' removed from bounded preview (display-only, no revoke actions here)"
  - "@moduledoc updated to reflect JTBD-first purpose (session controls now on UserSessionsLive)"
metrics:
  duration: "304s (~5m)"
  completed: "2026-06-26"
  tasks_completed: 3
  tasks_total: 3
  files_created: 0
  files_modified: 1
status: complete
---

# Phase 200 Plan 02: UserShowLive JTBD-First Recompose Summary

**One-liner:** `user_show_live.ex` restructured into a calm JTBD-first identity bar + bounded Sessions/Organizations previews with link-outs, session revoke flow fully removed, host extra-section seam preserved in correct position before Danger Zone.

## What Was Built

### Task 1: Calm Identity Bar (DETAIL-01)

Recomposed the `sg-page-header` block from a stacked layout (status pills beside identity + separate 4-fact `<dl>` + notice) into a single calm identity bar:

- Page kicker changed from `Identity & Status` to `User` (Copywriting Contract)
- h1: `@detail.display_name || @detail.user.email` (wraps — no forced nowrap per State Matrix)
- Secondary line: muted email + `sg-code` UUID
- Compact metrics strip (`sg-summary-facts`): Sessions count + MFA status + Last seen — 3 most scan-worthy facts
- Single priority alert via existing `summary_alert/1` (locked > unconfirmed > no-MFA — unchanged)
- Status pills cluster at the bottom of the header

Removed `passkey_count/1` helper (now unused after metrics strip reduction — no new warning).
Reused existing helpers unchanged: `status_pills/1`, `mfa_value/1`, `last_activity/1`, `summary_alert/1`.
No new `sg-*` CSS class. No `transition: all`.

### Task 2: Bounded Previews + Remove Revoke Flow (DETAIL-02)

**Sessions card rewritten as bounded display-only preview:**
- Header cluster: "Sessions" heading + session count + "Manage sessions" link-out to `/admin/users/:id/sessions`
- Preview table: max 3 rows, Type / IP / Last activity columns — NO per-row revoke button, NO revoke-all button
- Empty state: title `No active sessions`, body `This user has no active sessions in the current scope.` (Copywriting Contract)
- Added `sessions_path/3` scope-aware helper (global: `/admin/users/:id/sessions`, org: `/admin/organizations/:slug/users/:id/sessions`)

**Removed from this file (moved to UserSessionsLive in Plan 01):**
- `handle_event("open_revoke_session", ...)` 
- `handle_event("open_revoke_all_sessions", ...)`
- `handle_event("cancel_confirm", ...)`
- `handle_event("confirm_action", ...)`
- Confirm overlay markup (`user-session-confirm-overlay` / `sg-confirm-dialog`)
- `reload_detail/2` helper
- `revoke_session_copy/1` helper
- `revoke_all_sessions_copy/1` helper
- `alias Sigra.Admin.Users.Actions` (now unused)
- `:confirm_action` assign from `mount/3` and `handle_params/3`
- "Revoke all sessions" danger button from Danger Zone

**Organizations converted to bounded preview:**
- Header cluster: "Organizations" heading + org count + "View all organizations" link when length > 3
- Preview: max 3 org rows (org name + role + optional per-org pivot link)
- Empty state: title `No organizations`, body `This user has not joined any organizations.` (Copywriting Contract)

**Danger Zone cleaned up:**
- Removed stale "Revoking a session signs the user out..." sentence (no longer relevant)
- "Danger Zone" heading casing aligned to "Danger zone" (Copywriting Contract)
- Impersonation start form preserved unchanged

**Section order fixed:**
- `extra_detail_sections` block moved BEFORE Danger Zone (was incorrectly AFTER — the original file had it in the wrong position)

### Task 3: Host Seam Verification + JTBD Composition Order (DETAIL-02 / D-07)

Confirmed and verified the final JTBD composition matches the UI-SPEC Page Composition Contract:
1. Identity bar (scope_ribbon + sg-page-header)
2. Sessions preview (sg-card sg-stack--3)
3. Security + Identities (sg-detail-grid)
4. Organizations preview (sg-card sg-stack--3)
5. Recent audit (sg-card sg-stack--3) + "View full audit" link-out preserved
6. Host extra-sections (extra_detail_sections loop) — BEFORE Danger Zone
7. Danger Zone (sg-danger-panel)

**Host-seam contract preserved byte-for-byte:**
- `Map.get(section, :title) || Map.get(section, "title")` dual-key read intact
- `Map.get(section, :body) || Map.get(section, "body")` dual-key read intact
- `lib/sigra/admin/users/hooks.ex` — UNCHANGED
- `lib/sigra/admin/users/default_hooks.ex` — UNCHANGED
- `lib/sigra/admin/users/detail.ex` — UNCHANGED

Updated `@moduledoc` to reflect the new JTBD-first purpose.

## Verification

- `mix compile --warnings-as-errors` (library): PASS (no unused-function warnings)
- `mix test test/sigra/admin/glossary_test.exs`: 2 tests, 0 failures
- `git diff --quiet hooks.ex default_hooks.ex detail.ex`: exit 0 (UNCHANGED)
- No new `sg-*` CSS class (CSS three-copy parity untouched)
- No `transition: all` introduced
- All revoke event handlers + confirm overlay removed from user_show_live.ex
- `grep -c 'open_revoke_session\|open_revoke_all_sessions\|user-session-confirm-overlay\|sg-confirm-dialog'` returns 0

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Removed unused passkey_count/1 helper**
- **Found during:** Task 1 verification (`mix compile --warnings-as-errors`)
- **Issue:** After reducing metrics strip to Sessions/MFA/Last-seen (3 facts), `passkey_count/1` was no longer called. Compiler emitted `function passkey_count/1 is unused` warning — blocks `--warnings-as-errors`.
- **Fix:** Removed the 2-clause `passkey_count/1` private function.
- **Files modified:** `lib/sigra/admin/live/user_show_live.ex`
- **Commit:** 2204dc49 (within the task 1 commit)

### Ordering Fix (pre-existing bug)

**Extra-section seam was in wrong position in original file**
- The original `user_show_live.ex` had `extra_detail_sections` rendered AFTER the Danger Zone (`:310-313`), not before it.
- The UI-SPEC and CONTEXT.md both specify: extra-sections render after lib sections AND before Danger Zone.
- This was a pre-existing ordering bug in the original file. Fixed as part of Task 2 restructuring.

### Copy Updates

**Empty state copy aligned to Copywriting Contract:**
- Sessions empty state: `"This user does not have a currently visible session in this scope."` (original) → `"This user has no active sessions in the current scope."` (Copywriting Contract verbatim)
- Organizations empty state title: `"No organization memberships"` (original) → `"No organizations"` (Copywriting Contract)
- Organizations empty state body: (original) → `"This user has not joined any organizations."` (Copywriting Contract)

**Danger Zone heading cased:**
- `"Danger Zone"` → `"Danger zone"` (Copywriting Contract)

## Known Stubs

None — all bounded previews render real data from `@detail.sessions` and `@detail.organizations`. The "Manage sessions" link-out goes to the real sessions route created in Plan 01. The `sessions_path/3` helper is wired to live routes.

## Threat Flags

None — this plan only shrinks the destructive surface on User Detail (T-200-07 accepted). The host-seam contract is preserved (T-200-05 mitigated by UNCHANGED diff on three contract files + grep on render position). No new network endpoints introduced.

## Self-Check: PASSED

- `lib/sigra/admin/live/user_show_live.ex` — FOUND (1 file modified)
- Commit 2204dc49 — FOUND (feat: recompose identity header)
- Commit 16a09e12 — FOUND (feat: bounded previews + remove revoke flow)
- Commit 4f4733e2 — FOUND (feat: JTBD order + host seam)
- `grep -c 'sg-summary-facts'` returns 3 (metrics strip present) with 1 `<dl class="sg-summary-facts">` block
- `grep -F 'summary_alert(@detail)'` matches
- `grep -F 'sg-page-kicker">User'` returns 1
- `grep -c 'transition: all'` returns 0
- `grep -c 'open_revoke_session\|...'` returns 0
- `grep -F 'Manage sessions'` returns 1
- `grep -F 'View all organizations'` returns 1
- `grep -F 'View full audit'` returns 1
- `grep -F 'Map.get(section, :title) || Map.get(section, "title")'` returns 1
- Host-seam contract files diff — exit 0 (UNCHANGED)
- `mix compile --warnings-as-errors` — PASS
- `mix test test/sigra/admin/glossary_test.exs` — 2 tests, 0 failures
