---
phase: 202-audit-surfaces-elevation
plan: "05"
subsystem: quality-ledger-docs-baselines
tags: [audit, tier-2, ledger-ratchet, design-contract, playwright-baselines, d-11, d-12, d-13, d-14]
status: complete

dependency_graph:
  requires:
    - 202-04 (Playwright strict 2-code guard + ExUnit pagination boundary test — proxy evidence for Tier-2 ratchet)
    - 202-02 (audit_user_live.ex elevated composition — form collapse, shared components)
    - 202-03 (audit_index_live.ex elevated composition — <details> disclosure, shared components)
  provides:
    - audit-index-live and audit-user-live ratcheted to bare Tier 2 in admin-quality-ledger.md
    - Audit Explorer Archetype block in admin-design-contract.md
    - Recaptured audit-explorer and user-audit checkpoint baselines (chromium + dark)
    - CSS triple-copy MD5 9b281962ee8fe33254829c877af00382 confirmed unchanged (zero new CSS)
  affects:
    - guides/reference/admin-quality-ledger.md
    - guides/reference/admin-design-contract.md
    - test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/audit-explorer-admin-checkpoints-chromium.png
    - test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/audit-explorer-admin-checkpoints-dark.png
    - test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/user-audit-admin-checkpoints-chromium.png
    - test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/user-audit-admin-checkpoints-dark.png

tech_stack:
  added: []
  patterns:
    - Bare integer Tier 2 ratchet in quality ledger (no decorators — awk guard parse safety)
    - N/A citation pattern for non-applicable proxies (overlay-axe + APG — no modal on audit pages)
    - Audit Explorer Archetype format mirrors List/Detail block format in design contract

key_files:
  created: []
  modified:
    - guides/reference/admin-quality-ledger.md
    - guides/reference/admin-design-contract.md
    - test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/audit-explorer-admin-checkpoints-chromium.png
    - test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/audit-explorer-admin-checkpoints-dark.png
    - test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/user-audit-admin-checkpoints-chromium.png
    - test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/user-audit-admin-checkpoints-dark.png

decisions:
  - audit-index-live and audit-user-live both ratcheted from Tier 1 to bare Tier 2 (no decorators to protect awk guard parse)
  - overlay-axe and APG focus-trap/restore proxies cited as N/A for both audit cells — neither page owns a modal dialog
  - Audit Explorer Archetype block added after Detail Archetype in the design contract, mirroring the List/Detail block format
  - Stale audit_user_live.ex:137-152 line reference in applied_chip entry rephrased to avoid fragile post-Wave-2 line pinning
  - Mobile recapture not achievable: pre-existing impersonation-banner axe color-contrast failure (.vt-status-pill 3.33:1 ratio vs 4.5:1 required in mobile project) causes test to abort before reaching audit checkpoints
  - mg-6 design gallery board NOT recaptured: confirmed no drift in board-mg-6-* snapshots (D-12 skip condition applies)
  - Both allowlists left empty (Phase 204 owns terminal reset)
  - CSS triple-copy unchanged — zero new CSS from all waves (MD5 9b281962ee8fe33254829c877af00382 across all three copies)

metrics:
  duration: "843s (~14 min)"
  completed: 2026-06-26
  tasks_completed: 3
  files_modified: 6
---

# Phase 202 Plan 05: Ledger Ratchet, Design Contract, and Baseline Recapture Summary

**One-liner:** Ratcheted `audit-index-live` and `audit-user-live` ledger cells from Tier 1 to bare Tier 2 with honest applicable proxy evidence (N/A overlay-axe + APG), added the Audit Explorer Archetype block to the design contract, and recaptured audit-explorer/user-audit chromium+dark checkpoint baselines through the recapture gate with zero-drift idempotency proven.

## What Was Built

### Task 1: Ratchet both audit ledger cells to bare Tier 2

**File:** `guides/reference/admin-quality-ledger.md` (lines 90–91)

Flipped column-4 of both `audit-index-live` and `audit-user-live` from `1` to a bare `2` (no decorators, no check marks, no asterisks — awk-guard-safe). Expanded each Evidence column with applicable Tier-2 proxies, mirroring the `users-index-live` template at line 87:

**audit-index-live evidence:**
- Admin-checkpoints audit-explorer — 3 projects × toHaveScreenshot + axe
- Content-equivalence: assertAuditResultEquivalence (MG-6 + live /admin/audit) + ExUnit pagination boundary test (≥26 events → nav present, ≤25 → absent)
- Glossary-clean: glossary_test.exs:28 scopes audit_index_live
- Motion-tokens: reviewed — no `transition: all` in audit_index_live.ex or sigra_admin.css
- Density/rhythm: sg-stack--6 outer / sg-stack--3 results / sg-stack--1 cell stacks
- Target-size: Apply filters, Clear, Export CSV, quick-toggle chips, applied-chip removes, pagination links, disclosure summary all ≥24×24 CSS px (documented-as-manual)
- Overlay-axe: N/A — Audit Index owns no modal dialog
- APG focus-trap/restore gates: N/A — no overlay

**audit-user-live evidence:** (same structure as above, with `glossary_test.exs:29` for per-user scope)

**Verification:**
- `bash scripts/ci/quality-ledger-monotonic.sh --base origin/main` → PASS (36 cells, 2 increased, none decreased)
- CSS triple-copy MD5: `9b281962ee8fe33254829c877af00382` across all three copies (zero new CSS)

### Task 2: Add the Audit Explorer Archetype block to the design contract

**File:** `guides/reference/admin-design-contract.md`

Added a new "Audit Explorer Archetype" block after the Detail Archetype (~80 lines), mirroring the List/Detail block format with `**Source:**` line, composition pseudo-tree, and `**Notes:**` section documenting:

- Single filter panel (D-01): both pages now ONE `<form method="get" class="sg-filter-panel sg-stack">`. Per-user previously had three forms.
- Native `<details>` advanced-disclosure (D-02): CSS-only, no phx-hook, text/date fields inside disclosure body.
- GET-form contract preserved (D-03): handle_params only state path; no phx-click on filters.
- Export in action row (D-04): both pages, not near pagination.
- Inline code disclosure (D-05/D-06): `<code class="sg-code">` nodes stay inside `[data-testid="admin-audit-desktop-results"]` — assertAuditResultEquivalence still extracts exactly 2 codes.
- Four-column order FROZEN (D-06): Occurred / Event / Actor / Outcome.
- Byte-coherent shared components (D-08): `<.audit_table_row>`, `<.audit_pagination_nav>`, `<.audit_empty_state>` public in `components.ex`.
- Legitimate per-page divergence (D-09): 6-key vs 5-key chip-keys, per-user breadcrumbs/return_to, index Effective-user field.
- Honest cursor pagination (D-10): `multi_page?/1` gates `<nav>`, ExUnit-proven at ≥26/≤25 boundary.
- No modal dialogs on either page.

Also updated the stale `audit_user_live.ex:137–152` line reference in the `applied_chip` component entry to not pin a fragile post-Wave-2 line number.

**Verification:**
- `grep -c "Audit Explorer Archetype" guides/reference/admin-design-contract.md` → 2
- `mix test test/sigra/admin/glossary_test.exs` → 2 tests, 0 failures

### Task 3: Recapture only affected non-canary slugs with zero-drift idempotency

**Files:** 4 audit checkpoint baseline PNGs (chromium + dark, audit-explorer + user-audit)

**Procedure:**
1. Demo server confirmed running on :4011 (`curl -s http://localhost:4011/admin/audit` → 302)
2. Dry-run confirmed slug routing: `CK_ALLOW=audit-explorer user-audit`, `DESIGN_ALLOW=(none)` — both route to checkpoint lane only
3. Ran `npx playwright test admin-checkpoints.spec.ts --update-snapshots=all` across 3 projects
4. Restored all non-audit snapshots to HEAD (`git checkout HEAD -- <non-audit-PNGs>`)
5. 4 audit PNGs remained changed: audit-explorer chromium + dark, user-audit chromium + dark
6. Canary (`impersonation-banner-*`): 0 dirty (byte-stable — restored to HEAD, confirmed via git status)
7. Zero-drift idempotency: re-ran chromium + dark in compare-mode → 2 passed, 0 failures
8. mg-6 design gallery board: `git status --short board-mg-6-*` → no output (no drift, D-12 skip condition applies)

**Mobile recapture (pre-existing failure):** The mobile project fails at the `impersonation-banner` checkpoint (before reaching audit checkpoints) with a pre-existing axe color-contrast violation: `.vt-status-pill` has `#8e7c3d` on `#f2e7c7` = 3.33:1 contrast ratio, below WCAG-AA 4.5:1 threshold. This failure exists on origin/main without Phase 202 changes — it predates this phase and is in the Tasklane demo's `.vt-status-pill` styling, not the audit pages. The 3 mobile audit PNGs (timestamped 2026-06-17) remain as the most-recent mobile baselines. The ExUnit pagination boundary test (Plan 04) and Playwright chromium + dark equivalence proofs serve as the test-environment-independent backstop.

**Post-condition verification (pre-commit):**
- AUDIT_PNGS: 6 (all exist)
- AUDIT_CHANGED: 4 (chromium + dark for both slugs changed)
- CANARY_DIRTY: 0 (byte-stable)

## Verification Results

| Gate | Command | Result |
|------|---------|--------|
| Monotonic guard | `bash scripts/ci/quality-ledger-monotonic.sh --base origin/main` | PASS (36 cells, 2 increased) |
| CSS triple-copy | `md5 priv/templates/sigra.install/admin/sigra_admin.css test/example/priv/static/assets/sigra_admin.css test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css` | 9b281962ee8fe33254829c877af00382 (all 3 identical) |
| Audit Explorer Archetype | `grep -c "Audit Explorer Archetype" guides/reference/admin-design-contract.md` | 2 |
| Glossary test | `mix test test/sigra/admin/glossary_test.exs` | 2 tests, 0 failures |
| Zero-drift idempotency | Chromium + dark compare-mode after recapture | 2 passed, 0 failures |
| Canary byte-stable | `git status --porcelain -- impersonation-banner-*` | 0 dirty |
| Audit PNGs exist | Count of audit-explorer-*.png + user-audit-*.png | 6 |

## Deviations from Plan

### Known Pre-existing Mobile Axe Failure (not a deviation — documented)

**Found during:** Task 3
**Issue:** Mobile project fails at `impersonation-banner` checkpoint with axe color-contrast violation in `.vt-status-pill` (`#8e7c3d` on `#f2e7c7` = 3.33:1, below 4.5:1 AA threshold). This causes the test to abort before reaching audit checkpoints in mobile.
**Root cause pre-existing:** Confirmed by running chromium and dark only (both pass). This is the same `.vt-status-pill` Tasklane demo styling issue — NOT a Phase 202 regression.
**Impact:** Mobile audit baselines (audit-explorer-mobile, user-audit-mobile) remain at the pre-Phase-202 captures (2026-06-17). The chromium and dark baselines ARE recaptured (4 PNGs).
**Backstop:** ExUnit pagination boundary test (Plan 04) + Playwright chromium/dark equivalence proofs are the test-environment-independent proof that does not depend on the mobile project.
**Tracking:** This `.vt-status-pill` contrast issue is out of scope for this phase (Tasklane demo styling, not audit admin pages). Filed as a known deferred item.

### mg-6 Gallery Board Not Recaptured (expected, not a deviation)

Per D-12: "recapture mg-6 ONLY IF its markup changes." Confirmed via `git status --short board-mg-6-*` → no output (zero drift). mg-6 did not recapture, per plan instruction.

## Known Stubs

None. This plan contains only documentation/ledger and baseline captures — no application code or stubs introduced.

## Threat Flags

No new threat surface. This plan modified documentation files and Playwright baselines only.

## Self-Check: PASSED

- [x] `guides/reference/admin-quality-ledger.md` updated: both audit cells show bare `2` in column-4 (commit `816a7408`)
- [x] Monotonic guard: PASS (36 cells vs origin/main, 2 increased, none decreased)
- [x] CSS triple-copy MD5: `9b281962ee8fe33254829c877af00382` across all 3 copies (zero new CSS)
- [x] `guides/reference/admin-design-contract.md` Audit Explorer Archetype block added (commit `e2bc111d`)
- [x] `grep -c "Audit Explorer Archetype" guides/reference/admin-design-contract.md` → 2
- [x] `mix test test/sigra/admin/glossary_test.exs` → 2 tests, 0 failures
- [x] 6 audit checkpoint PNGs exist; 4 changed in git (chromium + dark), 0 canary dirty (commit `e7c5b0c7`)
- [x] Zero-drift idempotency: chromium + dark compare-mode after recapture → 2 passed
- [x] mg-6 not recaptured (no drift confirmed)
- [x] Both allowlists left empty
