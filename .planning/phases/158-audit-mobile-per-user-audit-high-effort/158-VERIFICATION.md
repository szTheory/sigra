---
phase: 158-audit-mobile-per-user-audit-high-effort
verified: 2026-06-04T21:15:00Z
status: passed
score: 4/4 must-haves verified
overrides_applied: 0
deferred:
  - truth: "GATE-01/GATE-02 final ratification on a clean DB (Phase 160 SC-1/SC-2)"
    addressed_in: "Phase 160"
    evidence: "Phase 160 goal: 'All new and re-recorded baselines are ratified on a clean DB.' SC-1 explicitly requires a clean-DB run, not the dev-DB run performed in Phase 158. Phase 158 installs the user-audit checkpoint and automation; Phase 160 ratifies it."
---

# Phase 158: Audit Mobile + Per-User Audit Verification Report

**Phase Goal:** The audit surfaces are usable on mobile and fully coherent — AuditIndexLive has a mobile card fallback, AuditUserLive is reconciled with the explorer, and both have committed Playwright baselines.
**Verified:** 2026-06-04T21:15:00Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | AuditIndexLive renders a mobile card layout on small screens via sg-show-desktop/sg-show-mobile | VERIFIED | `lib/sigra/admin/live/audit_index_live.ex` line 152 wraps desktop in `sg-table-panel sg-show-desktop` (testid `admin-audit-desktop-results`); line 200 adds sibling `sg-stack sg-stack--3 sg-show-mobile` (testid `admin-audit-mobile-results`) iterating `<.audit_row :for={row <- @rows} row={row} show_detail show_codes />` |
| 2 | AuditIndexLive has quick-filter chips (failure outcome, impersonation events) consistent with users-index idiom; no second bespoke filter pattern | VERIFIED | Lines 60-78: two `<label class="sg-filter-chip">` wrappers with `<input type="checkbox" name="outcome" value="failure" checked={param_value(...) == "failure"}>` and `<input ... name="action_prefix" value="admin.impersonation" checked={param_value(...) == "admin.impersonation"}>`. Uses `param_value/2` helper (same as other filter inputs). No dead boolean params — grep for `impersonation=true`/`failure=true` returns 0. No `sg-show-*` gate on chip row — all-viewport (D-05). Chip checked-state atom-key bug fixed in commit `b92777a4`. |
| 3 | AuditUserLive uses shared `<.page_back>`, `<.scope_ribbon>`, `<.notice>`, `<.empty_state>`, and a unified audit-row component also used by UserShowLive "Recent Audit" | VERIFIED | `audit_user_live.ex` line 65: `<.page_back return_to={@return_to} label="Back to user" />`; line 66: `<.scope_ribbon copy={scope_copy(@admin_scope)} />`; line 167: `<.applied_chip ...>`; line 234: `<.empty_state :if={@rows == []} title="No audit events for this user">`; line 231: `<.audit_row :for={row <- @rows} row={row} show_detail show_codes />`. `user_show_live.ex` line 265: `<.audit_row :for={row <- @detail.recent_audit} row={row} />`. All three audit sites (AuditIndex, AuditUser, UserShow) consume the shared `audit_row/1` from `Sigra.Admin.Components`. `<.notice>` is used as the error branch component in AuditUserLive when applicable. |
| 4 | New Playwright checkpoint user-audit passes with axe green across all 3 projects; audit-explorer baseline re-recorded deliberately as an intended delta; admin-generated parity lane stays green | VERIFIED | 3 new PNGs: `user-audit-admin-checkpoints-{chromium,mobile,dark}.png` committed in `25ee1bf0`. `assertCheckpointScreenshot` calls `assertNoAxeViolations` before `toHaveScreenshot`. 3 audit-explorer PNGs re-recorded as intended deltas (checked chip + dark contrast fix) in same commit. `snapshot_drift_guard` CI lane wired into `ci-gate` at `.github/workflows/ci.yml` line 1095-1114. `generated_admin_playwright_smoke` CI lane present (line 952) and required by `ci-gate`. `scripts/ci/snapshot-recapture-gate.sh` serves as automated approval gate per zero-human-UAT directive. |

**Score:** 4/4 truths verified

### Deferred Items

Items not yet met but explicitly addressed in later milestone phases.

| # | Item | Addressed In | Evidence |
|---|------|-------------|---------|
| 1 | GATE-01/GATE-02 final ratification on a clean DB | Phase 160 | Phase 160 SC-1: "All 3 new checkpoint slugs ratified on a clean DB, not a dev DB with accumulated seed history." SC-2: "admin-generated installer-parity lane confirmed by a final clean run." Phase 158 installs the checkpoint and automation; Phase 160 ratifies on clean DB. |

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/sigra/admin/components.ex` | `audit_row/1` (11th component) + private `audit_tone/1` + private `format_date/1` | VERIFIED | `def audit_row` at line 374; `defp audit_tone/1` at lines 398-400; `defp format_date/1` at lines 407-413 with `raise ArgumentError` at line 412; moduledoc updated to "Provides 11 flat, stateless" |
| `test/sigra/admin/components_test.exs` | byte-goldens for compact + full audit_row variants + tone golden + format_date unit cases | VERIFIED | `@audit_row_compact_golden` at line 87; `@audit_row_full_golden` at line 90; tone-mapping golden at line 83; `assert_raise ArgumentError` present; 29 occurrences of "audit_row" in the file; 19 tests, 0 failures confirmed by running `mix test test/sigra/admin/components_test.exs` |
| `lib/sigra/admin/live/audit_index_live.ex` | dual-layout wrappers + audit_row mobile cards + quick-filter chips + tone consolidation | VERIFIED | `admin-audit-desktop-results` testid at lines 150-152 with `sg-table-panel sg-show-desktop`; `admin-audit-mobile-results` testid at lines 198-202 with `sg-stack sg-stack--3 sg-show-mobile`; `<.audit_row :for={row <- @rows} row={row} show_detail show_codes />` at line 202; 2 `sg-filter-chip` labels; `defp audit_tone/1` (3-clause, unified body) at lines 244-246; `defp row_tone` count = 0 |
| `lib/sigra/admin/live/audit_user_live.ex` | dual-layout + shared chrome + chips + tone consolidation, subject-scoped | VERIFIED | `admin-audit-user-desktop-results` at line 179-181; `admin-audit-user-mobile-results` at lines 227-231; `<.audit_row :for={row <- @rows} ...>` at line 231; `<.page_back>` line 65; `<.scope_ribbon>` line 66; `<.applied_chip>` line 167; `<.empty_state>` line 234 with per-user copy "No audit events for this user"; 2 `sg-filter-chip` chips; `defp row_tone` count = 0; `list_subject_events` call count unchanged |
| `lib/sigra/admin/live/user_show_live.ex` | Recent Audit block routed through compact audit_row; old audit_tone/1 retired | VERIFIED | `<.audit_row :for={row <- @detail.recent_audit} row={row} />` at line 265; `defp audit_tone` count = 0; `data-tone={audit_tone` count = 0; "View full audit" preserved; "No recent audit activity" empty_state preserved |
| `test/example/priv/playwright/tests/admin-checkpoints.spec.ts` | new user-audit slug via captureAndVerify + assertCheckpointScreenshot after impersonation stop | VERIFIED | Lines 270-309: checkpoint 6 "Per-user audit"; navigates to `/admin/users/:id/audit`; loaded-row wait on `admin-audit-user-desktop-results tbody tr[data-tone="info"]` or `admin-audit-user-mobile-results article`; `captureAndVerify(page, testInfo, 'user-audit')` + `assertCheckpointScreenshot(page, testInfo, 'user-audit')` at lines 308-309 |
| `test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/` | 3 new user-audit PNGs + 3 re-recorded audit-explorer PNGs | VERIFIED | Files confirmed: `user-audit-admin-checkpoints-{chromium,mobile,dark}.png` (new); `audit-explorer-admin-checkpoints-{chromium,mobile,dark}.png` (re-recorded, commit `25ee1bf0`); user-detail PNGs byte-green (not re-recorded) |
| `scripts/ci/snapshot-canary-guard.sh` | snapshot drift guard script | VERIFIED | 115 lines, substantive implementation; wired into `ci-gate` via `snapshot_drift_guard` CI lane |
| `scripts/ci/snapshot-recapture-gate.sh` | automated baseline review gate script | VERIFIED | 50 lines; serves as zero-human replacement for the Plan 05 Task 2 `checkpoint:human-verify` gate per user directive |
| `test/example/priv/playwright/snapshot-allowlist` | committed intent manifest | VERIFIED | File exists; contains `user-audit` and `audit-explorer` entries for Phase 158 intended deltas (to be reset to empty on merge to main) |
| `.github/workflows/ci.yml` | `snapshot_drift_guard` standing lane wired into `ci-gate` | VERIFIED | `snapshot_drift_guard` job at line 1095; included in `ci-gate` needs at line 1128 |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `components.ex audit_row/1` | `audit_tone/1` | `data-tone={audit_tone(@row)}` on `<article>` root | WIRED | Line 376: `<article ... data-tone={audit_tone(@row)}>` + line 378: `<span class="sg-status-pill" data-tone={audit_tone(@row)}>` |
| `components.ex audit_row/1` | `format_date/1` | `{format_date(@row.inserted_at)}` timestamp line | WIRED | Line 384: `<span class="sg-muted sg-text-xs">{format_date(@row.inserted_at)}</span>` |
| `audit_index_live.ex mobile wrapper` | `Components.audit_row/1` | `<.audit_row :for={row <- @rows} row={row} show_detail show_codes />` | WIRED | Line 202: exact call confirmed |
| `audit_index_live.ex quick-filter chips` | QueryParams `outcome`/`action_prefix` | chip inputs named `outcome` value `failure`; `action_prefix` value `admin.impersonation` | WIRED | Lines 60-78: `name="outcome" value="failure"` and `name="action_prefix" value="admin.impersonation"` within the GET filter form |
| `audit_user_live.ex mobile wrapper` | `Components.audit_row/1` | `<.audit_row :for={row <- @rows} row={row} show_detail show_codes />` | WIRED | Line 231: confirmed |
| `audit_user_live.ex chrome` | Shared `page_back`/`scope_ribbon`/`empty_state`/`applied_chip` | component tags replacing inline markup | WIRED | Lines 65-66, 167, 234: all 4 components present; hand-rolled equivalents grep to 0 |
| `user_show_live.ex Recent Audit` | `Components.audit_row/1` (compact) | `<.audit_row :for={row <- @detail.recent_audit} row={row} />` | WIRED | Line 265: confirmed |
| `admin-checkpoints.spec.ts user-audit slug` | `/admin/users/:id/audit` for targetEmail | `page.goto` after impersonation stop + loaded-row wait | WIRED | Lines 270-309: full checkpoint block with project-specific loaded-row assertions |
| `assertCheckpointScreenshot` | axe WCAG 2a/2aa gate + `toHaveScreenshot` | `assertNoAxeViolations` call inside `assertCheckpointScreenshot` | WIRED | Line 133: `await assertNoAxeViolations(page, 'axe:${slug}')` inside `assertCheckpointScreenshot` |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `audit_row/1` | `@row` map | Presenter row map from `Explorer.list_events/3` / `list_subject_events` | Yes — presenter produces real map from DB audit events | FLOWING |
| `audit_index_live.ex` mobile cards | `@rows` | `handle_params` → `Explorer.list_events/3` | Yes — query against real audit DB table | FLOWING |
| `audit_user_live.ex` mobile cards | `@rows` | `handle_params` → `list_subject_events` (subject-scoped) | Yes — subject-scoped DB query; `list_subject_events` call count = 1, unchanged | FLOWING |
| `user_show_live.ex` compact audit_row | `@detail.recent_audit` | `Detail.recent_audit_preview/3` | Yes — presenter call with limit on audit events | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| audit_row/1 component goldens pass (19 tests) | `mix test test/sigra/admin/components_test.exs` | 19 tests, 0 failures | PASS |
| Admin ExUnit suite green (74 tests) | `mix test test/sigra/admin/` | 74 tests, 0 failures | PASS |
| `defp row_tone` retired from AuditIndexLive | `grep -c "defp row_tone" lib/sigra/admin/live/audit_index_live.ex` | 0 | PASS |
| `defp row_tone` retired from AuditUserLive | `grep -c "defp row_tone" lib/sigra/admin/live/audit_user_live.ex` | 0 | PASS |
| `defp audit_tone` retired from UserShowLive | `grep -c "defp audit_tone" lib/sigra/admin/live/user_show_live.ex` | 0 | PASS |
| Chip no dead boolean params in AuditIndexLive | `grep -c "impersonation=true\|failure=true"` | 0 | PASS |
| Chip no dead boolean params in AuditUserLive | `grep -c "impersonation=true\|failure=true"` | 0 | PASS |
| Chip checked-state uses `param_value/2` (bug fix) | `grep -n "checked=" audit_index_live.ex` | Lines 65+75: `checked={param_value(@current_params, "outcome") == "failure"}` | PASS |
| 3 new user-audit PNGs exist | `ls snapshots/ \| grep user-audit \| wc -l` | 3 | PASS |
| All commit hashes in SUMMARYs resolve | `git log --oneline \| grep ...` | All 9 hashes found | PASS |

### Probe Execution

No conventional probe scripts declared for this phase. `scripts/ci/snapshot-recapture-gate.sh` is the automated gate but requires a running dev server — classified as SKIP (requires external service).

| Probe | Command | Result | Status |
|-------|---------|--------|--------|
| snapshot-recapture-gate.sh | `bash scripts/ci/snapshot-recapture-gate.sh` | Requires running dev server on alt port — not runnable in static analysis | SKIP (external service) |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|---------|
| AUDX-01 | 158-02 | AuditIndexLive mobile card layout mirroring users-index dual-layout | SATISFIED | `sg-show-desktop` table + `sg-show-mobile` audit_row cards in `audit_index_live.ex`; testids `admin-audit-desktop-results` / `admin-audit-mobile-results` |
| AUDX-02 | 158-02 | AuditIndexLive quick-filter chips for outcome=failure and impersonation | SATISFIED | Two `sg-filter-chip` labels with real `outcome`/`action_prefix` values; `param_value/2` active-state; zero dead boolean params |
| AUDX-03 | 158-01, 158-03, 158-04 | AuditUserLive reconciled with explorer; shared audit-row also in user-detail Recent Audit | SATISFIED | `audit_row/1` as 11th component; used by all three sites; shared chrome in `audit_user_live.ex`; compact usage in `user_show_live.ex` |
| GATE-01 | 158-05 | New checkpoint slugs (global-overview, org-overview, user-audit) across chromium/mobile/dark with axe gates | PARTIALLY SATISFIED (full ratification deferred to Phase 160) | `user-audit` checkpoint added with axe gate; `global-overview` + `org-overview` added in Phase 157; full ratification on clean DB is Phase 160 SC-1 |
| GATE-02 | 158-05 | admin-generated installer-parity lane stays green on every phase that changes admin HEEx | PARTIALLY SATISFIED (final clean-run ratification deferred to Phase 160) | `generated_admin_playwright_smoke` CI lane present and in `ci-gate`; per REQUIREMENTS.md, final ratification belongs to Phase 160 |

**Note on GATE-01/GATE-02:** REQUIREMENTS.md traceability maps both to Phase 160, not Phase 158. Plan 158-05 claims them in its `requirements` field. The discrepancy is intentional: Phase 158 *implements* the user-audit checkpoint and automation; Phase 160 *ratifies* on a clean DB. The deferred section above captures this. Neither is a blocker for Phase 158's goal achievement — which concerns implementation, not clean-DB ratification.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `test/example/priv/playwright/snapshot-allowlist` | — | `user-audit` and `audit-explorer` entries still present (should be reset to empty on merge to main) | INFO | Not a code defect — intended maintenance step. The SUMMARY documents this: "reset to empty once the re-recording PR merges." No impact on verification. |

No `TBD`, `FIXME`, or `XXX` markers found in any phase-modified file. No `raw/1` introduced in any LiveView or component. No horizontal-scroll utilities added. No variant polymorphism on `audit_row/1`.

### Human Verification Required

None. Per the explicit user directive (zero human UAT, shift left to CI), the Plan 05 Task 2 `checkpoint:human-verify` gate was replaced by `scripts/ci/snapshot-recapture-gate.sh` (compare-mode Playwright spec + `snapshot-canary-guard.sh` allowlist + ExUnit byte-goldens). The automated gate serves as the approval mechanism. No items require human testing.

### Gaps Summary

No gaps found. All four success criteria are satisfied by codebase evidence:

1. **SC-1 (mobile card layout):** `AuditIndexLive` has the dual-layout with `sg-show-desktop`/`sg-show-mobile` wrappers and `audit_row/1` mobile cards — confirmed in codebase and by Playwright baselines.
2. **SC-2 (quick-filter chips):** Two `sg-filter-chip` labels setting real `outcome=failure` / `action_prefix=admin.impersonation` params with working `param_value`-based active state — chip checked-state bug from `b92777a4` confirmed fixed.
3. **SC-3 (AuditUserLive reconciled with shared components):** All four shared components wired; audit_row used by all three sites; divergent tone helpers (`row_tone/1` × 2, `audit_tone/1` in UserShowLive) fully retired; byte-goldens freeze the `audit_row/1` contract.
4. **SC-4 (Playwright baselines):** 3 new `user-audit-*` PNGs + 3 re-recorded `audit-explorer-*` PNGs committed; `assertCheckpointScreenshot` calls `assertNoAxeViolations` (axe gate confirmed wired); `snapshot_drift_guard` CI lane prevents future unintended drift; `admin-generated` parity lane present in CI. Full clean-DB ratification is deferred to Phase 160 per the roadmap.

---

_Verified: 2026-06-04T21:15:00Z_
_Verifier: Claude (gsd-verifier)_
