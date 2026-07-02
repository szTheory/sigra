---
phase: 209-judgment-level-page-pass
plan: "04"
subsystem: admin-ui
status: complete
tags:
  - admin
  - copy-remediation
  - ux-tighten
  - user-detail
  - user-sessions
  - branding
dependency_graph:
  requires:
    - 209-02
  provides:
    - user-detail-verdicts-resolved
    - user-sessions-verdicts-resolved
    - branding-verdicts-resolved
  affects:
    - lib/sigra/admin/live/user_show_live.ex
    - lib/sigra/admin/live/user_sessions_live.ex
    - lib/sigra/admin/live/branding_live.ex
tech_stack:
  added: []
  patterns:
    - scope_copy/1 per-page private helper (branding now consistent with all sibling pages)
    - entity-name H1 pattern (user_sessions_live now matches user_show_live and audit_user_live siblings)
key_files:
  created: []
  modified:
    - lib/sigra/admin/live/user_show_live.ex
    - lib/sigra/admin/live/user_sessions_live.ex
    - lib/sigra/admin/live/branding_live.ex
    - .planning/uat-evidence/v1.42-persona-jtbd/user-show-live.md
    - .planning/uat-evidence/v1.42-persona-jtbd/user-sessions.md
    - .planning/uat-evidence/v1.42-persona-jtbd/branding-live.md
decisions:
  - Remove sessions count from header dl (keep in Sessions card sub-heading only — single canonical location per design contract)
  - Raise Manage sessions to sg-btn--primary (measurable floor: non-secondary, non-small variant); no confirm overlay added to detail page (stays on UserSessionsLive per UI-SPEC)
  - Empty-state bodies harmonized to noun-phrase register — "No {noun} are associated with this user [in the current scope]."
  - Kicker sharpened from terse "User" to "User detail" matching sibling descriptiveness pattern
  - User Sessions kicker changed from "User" to "Sessions"; H1 now interpolates entity name/email (matches user_show_live and audit_user_live)
  - Revoke copy: "They can sign in again." reassurance clause removed; replaced with security-remediation framing (consequence + reversibility without minimizing the action per T-209-04-01)
  - scope_copy/1 added to branding_live as a single-clause always-global helper; branding is platform-admin-only — one clause is correct (not a bug); the function form preserves the architectural pattern
  - No shared components.ex helper for scope_copy (per-page defp is deliberate design per RESEARCH: divergent copy per page)
metrics:
  duration: "~5 minutes"
  completed: "2026-07-01"
  tasks: 3
  files_modified: 6
  commits: 3
---

# Phase 209 Plan 04: User Detail / User Sessions / Branding Remediation Summary

**One-liner:** Copy/IA remediation for user-detail (de-dup sessions count, Manage sessions prominence, unified empty-states, kicker), user-sessions (entity-name H1 + security-preserving revoke copy), and branding (scope_copy/1 helper replacing hardcoded literal).

---

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | user_show_live — de-dup sessions count, raise Manage sessions, unify empty-states, sharpen kicker | b28da2dc | user_show_live.ex, user-show-live.md |
| 2 | user_sessions_live — entity-name H1 + revoke-confirm copy (copy/IA only, no tier ratchet) | 869f1997 | user_sessions_live.ex, user-sessions.md |
| 3 | branding_live — replace hardcoded scope_ribbon literal with scope_copy/1 | 44dc4ee2 | branding_live.ex, branding-live.md |

---

## What Was Built

### Task 1: user_show_live.ex

Four actionable verdicts resolved in `lib/sigra/admin/live/user_show_live.ex`:

1. **Sessions count de-duplication:** The `<dt>Sessions</dt><dd>` row removed from `<dl class="sg-summary-facts">` header. Count now appears only in the Sessions card sub-heading (`sg-section-copy`), where it contextually belongs. The header `dl` retains MFA and Last seen — both earn their place as quick-scan identity facts.

2. **"Manage sessions" prominence raised:** `sg-btn--secondary sg-btn--sm` demotion pair removed. The affordance is now `sg-btn sg-btn--primary` — a standard primary button in the Sessions card header cluster. Meets measurable floor (variant a: non-secondary, non-small). No confirm overlay added (stays on UserSessionsLive per UI-SPEC).

3. **Kicker sharpened:** `"User"` → `"User detail"` (matches descriptiveness pattern of "User audit evidence" / "User operations" on siblings).

4. **Empty-state copies harmonized:** All 4 bodies rewritten to consistent noun-phrase register:
   - Sessions: "No sessions are associated with this user in the current scope."
   - Identities: "No external identities are associated with this user."
   - Organizations: "No organizations are associated with this user."
   - Recent audit: "No audit events are associated with this user in the current scope."

### Task 2: user_sessions_live.ex

Two actionable verdicts resolved in `lib/sigra/admin/live/user_sessions_live.ex` (copy/IA only — no Tier-2 ratchet per D-08):

1. **Entity-name H1 pattern:** `<h1 class="sg-page-title">Sessions</h1>` replaced with `<h1 class="sg-page-title">{@detail.display_name || @detail.user.email}</h1>`. Kicker changed from `"User"` to `"Sessions"`. Now matches `user_show_live.ex:48` and `audit_user_live.ex:71` sibling convention exactly.

2. **Revoke-confirm copy:** Both `revoke_session_copy/1` and `revoke_all_sessions_copy/1` rewritten. The reassurance clause "They can sign in again." was removed. Replacement: "must sign in again with verified credentials to re-establish access" — preserves the security-remediation posture (consequence + reversibility without minimizing the action per T-209-04-01 threat model). ConfirmDialog hook, `data-sg-confirm-cancel` focus, and 7 APG gates are byte-unchanged.

### Task 3: branding_live.ex

One actionable verdict resolved in `lib/sigra/admin/live/branding_live.ex`:

1. **scope_copy/1 helper added:** New `defp scope_copy/1` returning `"Global auth/email profile"` — branding-context appropriate. The hardcoded `copy="Global auth/email profile"` literal at line 106 replaced with `copy={scope_copy(@admin_scope)}`. Architecturally consistent with all 5 sibling pages now. Single-clause helper (branding is platform-admin-only; no org-scoped variant). No shared components.ex helper (per-page defp is deliberate — each page uses divergent copy per RESEARCH).

---

## Verification Results

| Gate | Result |
|------|--------|
| `mix test test/sigra/admin/glossary_test.exs` | 2/2 PASS |
| `bash scripts/ci/quality-ledger-monotonic.sh --base origin/main` | PASS (36 cells) |
| `! grep -A2 -B2 'Manage sessions' user_show_live.ex \| grep 'sg-btn--secondary sg-btn--sm'` | PASS (demotion pair gone) |
| `! grep '<h1 class="sg-page-title">Sessions</h1>' user_sessions_live.ex` | PASS (literal H1 gone) |
| `grep 'sg-page-kicker">Sessions' user_sessions_live.ex` | PASS (kicker present) |
| `grep '<h1 class="sg-page-title">{' user_sessions_live.ex` | PASS (H1 interpolates entity) |
| `grep 'defp scope_copy' branding_live.ex` | PASS (helper present) |
| `! grep 'scope_ribbon copy="Global auth/email profile"' branding_live.ex` | PASS (literal gone) |
| user-sessions ledger tier NOT ratcheted (still Tier-1) | PASS (monotonic guard) |

---

## Deviations from Plan

None — plan executed exactly as written.

---

## Known Stubs

None — all 3 LiveViews render real data; no placeholder or stub copy introduced.

---

## Threat Flags

No new security-relevant surface introduced. All changes are display copy and a private helper function.

---

## Self-Check: PASSED

**Files exist:**
- lib/sigra/admin/live/user_show_live.ex: present, modified
- lib/sigra/admin/live/user_sessions_live.ex: present, modified
- lib/sigra/admin/live/branding_live.ex: present, modified

**Commits exist:**
- b28da2dc: fix(209-04): user_show_live — de-dup sessions count, raise Manage sessions, unify empty-states, sharpen kicker
- 869f1997: fix(209-04): user_sessions_live — entity-name H1 + security-preserving revoke copy (copy/IA only, no tier ratchet)
- 44dc4ee2: fix(209-04): branding_live — replace hardcoded scope_ribbon literal with context-appropriate scope_copy/1 helper
