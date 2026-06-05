---
phase: 160-regression-hardening-baseline-ratification
verified: 2026-06-05T15:00:00Z
status: passed
score: 9/9 must-haves verified
overrides_applied: 0
---

# Phase 160: Regression Hardening + Baseline Ratification Verification Report

**Phase Goal:** All new and re-recorded baselines are ratified on a clean DB, all verification gates are formally closed, and the milestone is proven complete.
**Verified:** 2026-06-05T15:00:00Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | All 3 new checkpoint slugs (global-overview, org-overview, user-audit) ratified across chromium/mobile/dark with axe green — on a clean DB (self-seeding ephemeral fixtures) | ✓ VERIFIED | All 9 PNGs exist in admin-checkpoints.spec.ts-snapshots/. Spec calls assertNoAxeViolations before each capture (line 133). Self-seeding fixture pattern confirmed in spec (registerUser/createOrganization ephemeral). 160-04 Task 1 ran 3-project compare-mode exit 0. |
| 2 | The admin-generated installer-parity lane is green across all phases that changed admin HEEx | ✓ VERIFIED | 160-02-SUMMARY.md records smoke run: 6 passed (11.2s), exit 0. HTTP parity probes all OK. Commit c0e294cd exists. admin-generated lane confirmed no drift because admin LiveViews are library-owned (not generated). |
| 3 | admin-checkpoints-{chromium,mobile,dark} passes cleanly; demo-showcase is green; no unintended baseline re-records | ✓ VERIFIED | snapshot-allowlist is empty (0 non-comment lines confirmed). 7 dark PNGs present matching plan list. impersonation-banner dark PNG present (canary byte-green, never re-recorded per plan execution). 160 chromium + 16 mobile baselines unchanged. Commits e3cacd1b (re-record) + 4e028d90 (reset) exist. |
| 4 | The component governance contract (Job→Component mapping, archetype compositions, when-NOT-to-use, ARIA specs) is committed and referenced from the repo | ✓ VERIFIED | guides/reference/admin-design-contract.md contains ratification stamp at line 255. 0 stale "deferred to Phase 155" references (grep confirmed wc=0). role=status adjudication at line 173. Dark WCAG-AA resolution at line 174. |
| 5 | Dark admin pages pass WCAG-AA contrast — no brand-soft+brand-strong AA violation (D-06) | ✓ VERIFIED | app.css line 173: --sg-color-brand-strong: #fdba74 in dark :root block. Gate exit 0 from compare-mode run (axe embedded in spec via assertNoAxeViolations). |
| 6 | The needs-review deep-link reaches both locked AND deletion-scheduled accounts (D-07 — genuinely functional after post-execution remediation) | ✓ VERIFIED | query.ex: needs_review in @allowed_params (line 24), @filter_fields (line 38), Params filterable (line 59), embedded_schema field (line 83). apply_filter clause uses where with internal OR disjunction (not or_where) at line 317 — scope-safe. Regression tests assert global union (bob+carol) and org-scoped safety (org1 sees only carol). Commit 8231f840. |
| 7 | GATE-01 and GATE-02 are marked [x] Complete in REQUIREMENTS.md checkbox list and traceability table | ✓ VERIFIED | REQUIREMENTS.md line 50: [x] GATE-01. Line 51: [x] GATE-02. Traceability table lines 104-105: both marked Complete. Last updated 2026-06-05. |
| 8 | v1.34-MILESTONE-AUDIT.md exists with status: passed and evidence for all 4 criteria | ✓ VERIFIED | File exists at .planning/milestones/v1.34-MILESTONE-AUDIT.md. Frontmatter: status: passed, scores: 25/25 requirements, 7/7 phases, 4/4 integration, 2/2 flows, gaps: all empty. All 9 sections present. |
| 9 | STATE.md advanced to milestone-complete; ROADMAP.md Phase 160 complete with 4 plans [x] | ✓ VERIFIED | STATE.md line 5: status: milestone-complete. ROADMAP.md: Phase 160 [x] complete, 4 plans listed with [x] checkboxes (lines 241-250). |

**Score:** 9/9 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/sigra/admin.ex` | Shared needs_review/1 helper | ✓ VERIFIED | 13 lines. defmodule Sigra.Admin with @moduledoc, public needs_review/1 returning locked+deleted sum. |
| `test/example/priv/static/assets/css/app.css` | Dark :root block with --sg-color-brand-strong override | ✓ VERIFIED | Line 173: --sg-color-brand-strong: #fdba74 inside dark @media :root block. |
| `lib/sigra/admin/users/query.ex` | needs_review filter clause (OR: locked OR deleted) | ✓ VERIFIED | Lines 317-323: apply_filter for needs_review using where with internal disjunction. Registered in @allowed_params, @filter_fields, Params filterable, embedded_schema. |
| `test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/` | 3 new checkpoint slugs × 3 projects = 9 PNGs; 7 dark PNGs updated | ✓ VERIFIED | All 9 files for global-overview/org-overview/user-audit (chromium/mobile/dark) confirmed. All 7 dark PNGs re-recorded. impersonation-banner dark canary present and untouched. |
| `test/example/priv/playwright/snapshot-allowlist` | Steady-state empty (comment block only) | ✓ VERIFIED | 0 non-comment lines confirmed. |
| `.planning/milestones/v1.34-MILESTONE-AUDIT.md` | Milestone proof bundle with status: passed | ✓ VERIFIED | Exists. status: passed. 25/25 requirements. 7/7 phases. All 9 sections. |
| `guides/reference/admin-design-contract.md` | Ratified governance contract | ✓ VERIFIED | Ratification stamp at line 255. 0 stale "deferred to Phase 155" notes. role=status and dark-AA adjudications added. |
| `.planning/REQUIREMENTS.md` | GATE-01 and GATE-02 marked Complete | ✓ VERIFIED | [x] checkboxes at lines 50-51. Traceability table Complete at lines 104-105. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| lib/sigra/admin/live/index_live.ex | Sigra.Admin.needs_review/1 | module call at line 36 | ✓ WIRED | assigns :needs_review from Sigra.Admin.needs_review(assigns.summary_counts); no local defp remains |
| lib/sigra/admin/live/organization_live.ex | Sigra.Admin.needs_review/1 | module call at line 45 | ✓ WIRED | Same pattern as index_live.ex; no local defp remains |
| index_live.ex alarm notice | ?needs_review=true URL | href at lines 56, 78, 115 | ✓ WIRED | 3 occurrences confirmed |
| organization_live.ex alarm notice | ?needs_review=true URL | href at lines 67, 114 | ✓ WIRED | 2 occurrences confirmed |
| lib/sigra/admin/users/query.ex needs_review filter | Flop param pipeline | @allowed_params + @filter_fields + filterable + embedded_schema | ✓ WIRED | All 4 registration sites present after commit 8231f840 |
| .planning/milestones/v1.34-MILESTONE-AUDIT.md | REQUIREMENTS.md GATE-01/GATE-02 | Requirements Coverage table | ✓ WIRED | Table rows at lines 82-83 cite Phase 160 with evidence |

### Data-Flow Trace (Level 4)

Not applicable — this phase primarily modifies admin LiveViews (static rendering, no new dynamic data sources), Playwright baselines (binary PNG artifacts), and planning documentation. The needs_review filter is covered by regression tests (ExUnit) rather than data-flow trace.

### Behavioral Spot-Checks

| Behavior | Check | Result | Status |
|----------|-------|--------|--------|
| needs_review filter is wired into Flop pipeline | grep @allowed_params, @filter_fields, filterable, embedded_schema in query.ex | All 4 sites contain :needs_review | ✓ PASS |
| needs_review uses scope-safe where (not or_where) | grep apply_filter needs_review in query.ex | where with internal OR disjunction, comment explaining WR-01 fix | ✓ PASS |
| Regression tests cover needs_review union + org-scope safety | grep needs_review in users_query_test.exs | Lines 332 (global union bob+carol) and 399-403 (org-scope safety assert) | ✓ PASS |
| No local defp needs_review/1 remains in LiveViews | grep defp needs_review in lib/sigra/admin/live/ | 0 results | ✓ PASS |
| snapshot-allowlist in steady state | grep -v comment lines | 0 non-comment lines | ✓ PASS |
| D-08 notice/1 wraps slot in div.sg-text-sm | grep def notice + sg-text-sm in components.ex | Line 306: <div class="sg-text-sm">{render_slot(@inner_block)}</div> | ✓ PASS |
| D-08 NaiveDateTime head in organization_live.ex format_date/1 | grep NaiveDateTime in organization_live.ex | Line 194: defp format_date(%NaiveDateTime{} = ndt) | ✓ PASS |

### Probe Execution

Probes cannot be run in this verification context (requires a running Phoenix dev server on port 4011 for Playwright and a live Postgres for ExUnit). The execution summaries provide direct evidence:

| Probe | Claimed Result | Git Evidence | Status |
|-------|---------------|--------------|--------|
| mix test test/sigra/admin/ | 74 tests, 0 failures (160-01) | Commit e0df0f3c | PASS (evidence) |
| mix test test/sigra/admin/ after CR-01/WR-01 fix | 74 tests, 0 failures (160-REVIEW.md remediation note) | Commit 8231f840 (+10 lines in users_query_test.exs) | PASS (evidence) |
| mix test test/sigra/admin/components_test.exs | 19 tests, 0 failures (160-01 + 160-04) | Commit 36bc1cf7 | PASS (evidence) |
| admin-acceptance-smoke.sh | 6 passed, exit 0 (160-02-SUMMARY.md with full output) | Commit c0e294cd | PASS (evidence) |
| snapshot-recapture-gate.sh 7 dark slugs | PASS (7 changed slugs, all within allowlist) (160-03-SUMMARY.md) | Commits e3cacd1b + 4e028d90 | PASS (evidence) |
| Playwright compare-mode 3-project | 28.9s, exit 0, 0 unintended re-records (160-04-SUMMARY.md) | Commit 2abe5915 | PASS (evidence) |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| GATE-01 | 160-01, 160-03, 160-04 | New checkpoints (global-overview, org-overview, user-audit) across chromium/mobile/dark with axe green | ✓ SATISFIED | 9 PNGs present; axe embedded in spec; compare-mode exit 0; dark WCAG-AA fix committed |
| GATE-02 | 160-02 | Admin-generated parity lane green on every phase that changes admin HEEx | ✓ SATISFIED | Smoke run 6 passed, exit 0; no template drift confirmed (lib LiveViews are not generated) |

### Anti-Patterns Found

| File | Pattern | Severity | Notes |
|------|---------|----------|-------|
| test/example/priv/static/assets/css/app.css lines 893-896 | Empty CSS rule: `.sg-filter-chip:has(input:checked) {}` inside dark @media block | ℹ️ Info | Deferred in 160-REVIEW.md as WR-04. Not a blocker — dead code kept intentionally per plan (block structure preserved with comment). Tracked in .planning/todos/pending/2026-06-05-admin-160-review-deferred.md. Has formal tracking reference; does not meet the TBD/FIXME/XXX unresolved debt marker gate. |

No TBD, FIXME, or XXX markers in any modified files (confirmed by grep returning 0 results).

### Human Verification Required

None. All success criteria for this phase are verified by automated gates (Playwright compare-mode, axe, ExUnit, snapshot-canary-guard, admin-acceptance-smoke.sh). Per standing zero-human-UAT preference confirmed in REQUIREMENTS.md out-of-scope table.

### Gaps Summary

No gaps. All 9 must-have truths verified. The post-execution code-review remediation (commit 8231f840) resolved the two verified findings from 160-REVIEW.md (CR-01 dead-code filter + WR-01 scope-unsafe or_where), and added regression coverage. The 4 remaining deferred review items (WR-02, WR-04, IN-01, IN-02) are non-blocking and formally tracked.

---

_Verified: 2026-06-05T15:00:00Z_
_Verifier: Claude (gsd-verifier)_
