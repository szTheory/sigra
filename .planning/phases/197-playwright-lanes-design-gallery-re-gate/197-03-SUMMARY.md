---
phase: 197-playwright-lanes-design-gallery-re-gate
plan: "03"
subsystem: testing
tags: [playwright, woff2, font-determinism, admin-design, visual-regression]

requires:
  - phase: 197-02
    provides: expect.poll mailbox readiness rewrites (D-06) for organizations + ga-uat specs

provides:
  - Self-hosted Space Grotesk variable woff2 at test/example/priv/static/assets/fonts/
  - app.css @font-face declaration and :root --font-sans brand-font override (D-08)
  - admin-design.spec.ts waitForLiveViewReady extended with fonts.ready + hard font-check guard
  - MG-5/6 test.fail() removed; replaced with test.skip and recorded todo reason (D-11b)

affects:
  - 197-04 (baseline recapture — requires render to be deterministic first)
  - 197-05 (re-gate continue-on-error removal — requires deterministic baselines)

tech-stack:
  added: []
  patterns:
    - "Self-hosted woff2 from in-repo TTF with fontTools — commit asset, CI consumes committed file (no fonttools in CI)"
    - "document.fonts.ready + fonts.check hard guard in waitForLiveViewReady pattern (Pitfall 7)"
    - "D-11b test.skip with recorded todo reference replaces test.fail() spurious-pass masking"

key-files:
  created:
    - test/example/priv/static/assets/fonts/space-grotesk-var.woff2
  modified:
    - test/example/priv/static/assets/css/app.css
    - test/example/priv/playwright/tests/admin-design.spec.ts

key-decisions:
  - "D-11b chosen as default: no seeded user reaches >=25 per-user audit events; test.fail() removed and replaced with test.skip referencing the tracked todo"
  - "fonts.check('16px Space Grotesk') hard guard added (not optional) — fails loudly if woff2 404s or --font-sans did not apply, preventing a silently-pre-font capture from establishing wrong baselines (T-197-06)"
  - "woff2 generated once locally from in-repo OFL SpaceGrotesk[wght].ttf via fontTools 4.62.1; committed to repo so CI recapture job needs no fonttools (supply-chain provenance T-197-07)"

patterns-established:
  - "waitForLiveViewReady pattern: phx-connected wait → fonts.ready → fonts.check hard guard before any snapshot"
  - "D-11 test.skip with .planning/todos reference: documents data-dependent test disposition honestly"

requirements-completed: [PW-03]

duration: 2min
completed: "2026-06-20"
status: complete
---

# Phase 197 Plan 03: Font Determinism Foundation Summary

**Self-hosted Space Grotesk woff2 committed and wired into app.css + admin-design spec with fonts.ready guard and fonts.check hard assertion; MG-5/6 test.fail() replaced with documented test.skip (D-08, D-11b)**

## Performance

- **Duration:** 2 min
- **Started:** 2026-06-20T19:09:12Z
- **Completed:** 2026-06-20T19:11:00Z
- **Tasks:** 4
- **Files modified:** 3 (+ 1 created)

## Accomplishments

- Generated `space-grotesk-var.woff2` (49 KB, preserves variable wght axis 300-700) from the in-repo OFL SpaceGrotesk TTF via fontTools 4.62.1; verified `wOF2` magic bytes; committed to repo so CI consumes the asset without any fonttools dependency (T-197-07 supply chain satisfied)
- Added `@font-face` + `:root { --font-sans: 'Space Grotesk', ... }` override to `app.css` (loads last per root.html.heex, wins cascade); default.css, sigra_admin.css, and all priv/templates/sigra.install/** files are untouched
- Extended `waitForLiveViewReady` in admin-design.spec.ts: after `phx-connected` wait, awaits `document.fonts.ready` then asserts `document.fonts.check('16px "Space Grotesk"')` is true — fails loudly if woff2 404s or --font-sans did not apply (T-197-06 capture timing threat mitigated)
- Replaced `test.fail()` on MG-5/6 with `test.skip(...)` referencing the tracked todo (D-11b DEFAULT): no seeded user reaches the `@default_limit 25` per-user audit threshold; `test.fail()` was a spurious-pass path (T-197-08)

## Task Commits

Each task was committed atomically:

1. **Task 1: Generate + commit Space Grotesk woff2 (D-08, T-197-07)** - `88216828` (feat)
2. **Task 2: Add @font-face + --font-sans override to app.css (D-08)** - `2914d46e` (feat)
3. **Task 3: Extend waitForLiveViewReady with fonts.ready + hard guard (D-08, Pitfall 7)** - `680baae6` (feat)
4. **Task 4: Replace MG-5/6 test.fail() with test.skip (D-11b, T-197-08)** - `f174d84d` (fix)

## Files Created/Modified

- `test/example/priv/static/assets/fonts/space-grotesk-var.woff2` — self-hosted variable woff2 (49 KB, converted from scripts/brand/fonts/SpaceGrotesk[wght].ttf, OFL-licensed, wOF2 magic verified)
- `test/example/priv/static/assets/css/app.css` — appended @font-face + :root --font-sans override (17 lines added at end)
- `test/example/priv/playwright/tests/admin-design.spec.ts` — extended waitForLiveViewReady with fonts.ready + fonts.check guard; replaced test.fail() with test.skip on MG-5/6

## Decisions Made

- **D-11b (not D-11a):** Read seeds.ex ground truth confirmed: admin has 18 per-user audit events (via `effective_user_id: admin.id`), each persona has ≤4 events. No single user reaches `@default_limit 25`. The MG-5/6 test asserts `Previous page` on global `/admin/audit` page-1 (where it cannot exist) and on the first-listed non-admin user's audit page. D-11a (empirical booted-app confirmation) was not pursued because the data-dependent condition is definitively unmet; D-11b is the honest disposition.
- **Hard guard (not optional):** The plan marks the `fonts.check` assertion as a hard requirement in Task 3 ("HARD guard"), not the optional form shown in RESEARCH Code Examples §3. This mitigates T-197-06 (capture timing threat) and fails the spec loudly if any misconfiguration silently prevents the font from loading.

## Deviations from Plan

None — plan executed exactly as written. D-11b was the pre-designated DEFAULT path; empirical D-11a confirmation was not required and was correctly bypassed given the seed ground truth.

## Issues Encountered

None. fontTools 4.62.1 converted the TTF to woff2 in one pass without requiring `pip install brotli` (brotli was already available). The woff2 is 49 KB (smaller than the 136 KB source TTF, expected for woff2 format).

## Known Stubs

None. The font is served from the committed static asset path, the CSS override is wired, and the spec guard is non-optional.

## Threat Flags

No new threat surface beyond what the plan's threat_model already covers:

| Flag | File | Description |
|------|------|-------------|
| Covered — T-197-06 | admin-design.spec.ts | fonts.check hard guard prevents silent pre-font capture |
| Covered — T-197-07 | priv/static/assets/fonts/space-grotesk-var.woff2 | Generated from in-repo OFL TTF; no network fetch |
| Covered — T-197-08 | admin-design.spec.ts | test.fail() removed; spurious-pass path eliminated |

## Next Phase Readiness

- Plan 04 (baseline recapture) can now proceed: the font loads in both local and CI environments, making render OS-independent. All 72 admin-design PNG baselines need recapture because element heights will shift once `--font-sans: 'Space Grotesk'` takes effect.
- The `fonts.check` hard guard in the spec means any misconfigured recapture environment will fail loudly before snapshotting, preventing wrong baselines from being established.
- Plan 05 (re-gate `continue-on-error`) unblocks once Plan 04 recaptures green baselines.

## Self-Check: PASSED

---
*Phase: 197-playwright-lanes-design-gallery-re-gate*
*Completed: 2026-06-20*
