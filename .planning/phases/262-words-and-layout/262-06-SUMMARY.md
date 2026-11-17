---
phase: 262-words-and-layout
plan: 06
subsystem: ui
tags: [phoenix-liveview, admin-ui, css-tokens, playwright, accessibility, catalog]

requires:
  - phase: 262-05
    provides: Overview and audit index plan completion; shared 4b wording and catalog baseline
provides:
  - Updated Organizations copy with truthful scoped language and catalog evidence
  - Branding preview named “Sign-in preview” and current-navigation ARIA semantics in shipped and example shells
  - Tokenized selected-row/current-tab styling with byte-identical shipped/example CSS and computed checks
affects: [262-07, admin-ui, brand-catalog]

actuals:
  tokens: 6253
  tasks: 3
  commits: 3

tech-stack:
  added: []
  patterns: [existing sg-* layers and --sg-* tokens, aria-current page semantics]

key-files:
  created: [.planning/phases/262-words-and-layout/deferred-items.md]
  modified:
    - lib/sigra/admin/live/organization_live.ex
    - priv/templates/sigra.install/admin/components/admin_shell.ex
    - priv/templates/sigra.install/admin/sigra_admin.css
    - test/example/lib/example_web/components/admin_shell.ex
    - test/example/priv/static/assets/css/app.css
    - test/example/priv/static/assets/sigra_admin.css
    - test/example/priv/playwright/tests/admin-design.spec.ts
    - test/example/priv/playwright/tests/admin-flow-platform-admin.spec.ts
    - test/example/test/example_web/admin_shell_test.exs
    - test/example/test/example_web/catalog_test.exs
    - test/example/test/example_web/live/admin_branding_live_test.exs
    - test/sigra/brand/catalog_test.exs
    - test/sigra/brand/css_contract_test.exs

key-decisions:
  - “Members, audit events, and invitations stay within this organization.” describes the existing organization scope without implying global access.
  - Keep the example catalog on reachable authenticated organization state; capture the pure empty state in the library catalog because the example route requires membership.
  - Keep the unrelated stale “Review risky users” assertion and existing Dark branding contrast findings open for their owning scope.

patterns-established:
  - Current navigation exposes aria-current="page" in both desktop and mobile shell links.
  - Current-tab square and selected-row edge use existing Phase 261 tokens in existing sg-* layers.

requirements-completed: [BOPS-07, BOPS-08]
coverage:
  - id: D1
    description: Organizations, branding workbench, and shell retain existing routes and scope while using approved copy and current-navigation semantics.
    requirement: BOPS-07
    verification:
      - kind: unit
        ref: test/example/test/example_web/catalog_test.exs and test/sigra/brand/catalog_test.exs
        status: pass
      - kind: integration
        ref: focused shell, connected organization, and branding LiveView tests (9 tests)
        status: pass
      - kind: automated_ui
        ref: admin-flow-platform-admin.spec.ts current navigation check
        status: pass
    human_judgment: false
  - id: D2
    description: Selected rows and current tabs use existing tokens in Light, Dark, and System modes.
    requirement: BOPS-08
    verification:
      - kind: unit
        ref: test/sigra/brand/css_contract_test.exs and CSS conformance/token completeness checks
        status: pass
      - kind: automated_ui
        ref: admin-design.spec.ts computed-style checks across Light, Dark, System
        status: pass
      - kind: automated_ui
        ref: admin-design.spec.ts axe checks in Light and Dark design-gallery contexts
        status: pass
    human_judgment: false
  - id: D3
    description: Branding editor contrast in Dark mode has an unresolved axe finding on existing controls.
    verification:
      - kind: automated_ui
        ref: exploratory axe scan of the branding editor in Dark mode
        status: fail
    human_judgment: true
    rationale: The active Branding sidebar link and Save profile button each measure 2.83:1; they use unchanged existing styling and require a separate contrast remediation.

duration: 31min
completed: 2026-11-16
status: complete
plan_head_before: 78228846ce32165366daf299982abc1b303a72e7
plan_head_after: d95a542d40c13c877e76a8d2e8f7ab227911b279
commits: 3
---

# Phase 262 Plan 06: Organizations, Branding, and Selected States Summary

**Organizations, branding preview, and admin navigation now follow the approved copy and token rules, with catalog and computed-style evidence across themes.**

## Performance

- **Duration:** 31 minutes
- **Started:** 2026-11-16T22:50:34-05:00 (first available plan-base timestamp)
- **Completed:** 2026-11-17T04:21:34Z
- **Tasks:** 3
- **Files modified:** 14 in the task commits

## Accomplishments

- Clarified organization scope and captured reachable populated example state plus populated/empty library states.
- Named the branding preview “Sign-in preview” and added `aria-current="page"` to active sidebar and mobile navigation links in both shipped and example shells.
- Added current-tab square and selected-row edge using existing tokens, removed only the stale example CSS overrides masking these states, and synchronized the CSS copies byte-for-byte.
- Captured after catalogs for the 4b surfaces; normalized diff reports 34 changed entries, 0 added, and 0 removed against the committed before catalog.

## Task Commits

1. **Task 1: Update Organizations in the existing list archetype** - `0333e08ee` (`feat`)
2. **Task 2: Update the branding workbench and generated admin shell** - `ac4c96ba2` (`feat`)
3. **Task 3: Add selected-row and current-tab tokens and verify all 4b screen diffs** - `d95a542d4` (`feat`)

## Verification Evidence

- Organization catalogs: example catalog 23/23 and library catalog 65/65 passed; library covers the empty organization state that the authenticated example route cannot render.
- Focused shell, connected organization, and branding LiveView tests: 9 tests, 0 failures. Library catalog: 65/65 passed.
- Complete `admin_shell_test.exs` follow-up after correcting its stale Overview phrase: 14 tests, 0 failures. The original combined Plan 06 command was not rerun as a bundle.
- CSS contract/catalog ExUnit: 87/87 passed. CSS conformance and token completeness passed (112 tokens); shipped/example CSS `cmp` passed; `git diff --check` passed.
- Computed browser checks passed 2/2 for the selected row/current-tab styles across Light, Dark, and System. Platform-admin flow with current-link semantics passed 1/1.
- Required design-gallery axe checks passed in both Light and Dark contexts (2/2 each).
- The exploratory Dark-mode axe scan of the branding editor did **not** pass: the active “Branding” sidebar link and “Save profile” button each measure **2.83:1** (`#504d4a` on `#e57843`). These existing selectors and brand/ink tokens were not changed in this plan. This is an unresolved accessibility finding, recorded separately from the passing design-gallery axe gate.
- `scripts/brand/catalog-diff.sh test/fixtures/brand/before tmp/catalog-after`: 34 changed, 0 added, 0 removed. The before catalog was not modified.

## Deviations from Plan

### Scoped implementation adjustments

1. **Synced current-navigation semantics into the maintained example shell.** The example shell is maintained separately from the generated template, so updating only the planned template would leave the browser-visible example without the required `aria-current` contract. Added `test/example/lib/example_web/components/admin_shell.ex` to the declared Plan 06 files before editing; focused shell and browser-flow checks passed. Committed in `ac4c96ba2`.
2. **Removed stale example selected-state overrides.** Unlayered tab and command-palette declarations in `test/example/priv/static/assets/css/app.css` masked the new token rules in computed browser output. Added that file to the declared Plan 06 files before editing and removed only those conflicting declarations. Computed checks then passed across all three theme modes. Committed in `d95a542d4`.

**Total deviations:** 2 scoped implementation adjustments. No route, authorization, model-state, or token contract changed.

## Issues Encountered

- The initial combined branding/shell command exposed a stale Overview assertion at `test/example/test/example_web/admin_shell_test.exs:381` expecting “Review risky users”. A follow-up changed only the assertion to the approved “Review users” copy; the complete shell test file then passed 14/14. The combined command was not rerun as a bundle.
- The example organization route requires membership, so an empty-members runtime state is not reachable there. The example catalog captures the reachable populated state; the library catalog covers the pure empty render.
- Chromium required the authorized narrowly scoped permission after sandbox denial; browser checks completed successfully.

## User Setup Required

None. No external service configuration is required.

## Next Phase Readiness

Plan 06 is complete and Plan 07 may proceed when dispatched. Keep the Dark branding contrast finding and unrelated stale shell assertion visible as open items; neither was caused by this plan.

## Self-Check: PASSED

- Summary and deferred-items files exist.
- All three task commits are ancestors of the current plan branch head.
- Protected `.planning/STATE.md`, `.planning/state.json`, and `.planning/research/.cache/` remain unstaged and uncommitted.

---
*Phase: 262-words-and-layout*
*Completed: 2026-11-16*
