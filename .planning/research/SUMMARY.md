# Project Research Summary

**Project:** Sigra v1.34 ADMIN-UI-COHERENCE
**Domain:** Phoenix LiveView admin console — coherence/polish pass on an existing 6-screen surface
**Researched:** 2026-06-03
**Confidence:** HIGH

---

## Executive Summary

Sigra v1.0.0 shipped with a functional, individually-polished 6-screen admin console but without deliberate cross-screen threading. Each screen received craft in isolation; the result feels disjoint because the same job is handled by different components on different screens, several surfaces were never iterated to baseline, and the needs-led IA instinct (present in `IndexLive`'s "What do you need to do?" H1) is not yet followed through to the downstream screens. This milestone is a coherence and needs-led journey pass — no net-new surfaces, no new dependencies, no nav restructure.

The recommended approach is a strict linear phase sequence with one non-negotiable keystone: Phase 1 (behavior-preserving component extraction into a new lib-owned `Sigra.Admin.Components` module) must produce zero Playwright baseline diffs. Its success criterion — all 5x3 existing checkpoints stay green with zero re-records — is the proof that consolidation did not mutate rendering. Every subsequent phase (adopt on baselined screens, iterate the under-iterated Overview landings, fill the audit mobile gap, cross-journey sweep, seed enrichment, and final ratification) depends on this invariant holding. The highest-effort work is in Phases 3 and 4 because the two Overview landings and per-user audit have no committed checkpoint baselines today.

The two dominant risks are baseline thrash (non-intentional pixel diffs from extraction whitespace/wrapper changes triggering re-record cascades that destroy visual contract integrity) and installer parity drift (lib-owned LiveViews diverging from their `priv/templates/sigra.install/` counterparts after call-site refactors). Both are prevented by the same discipline: run the `admin-generated` parity lane as a gate on every phase that touches HEEx, not only at final ratification. The CSS token layer is deliberately frozen for this milestone — the one minor permitted addition is ~15 lines of `sg-notice` component styles inside the existing `@layer sg-components` block, required because that class does not yet exist in `app.css`.

---

## Key Findings

### Recommended Stack

No new runtime dependencies are warranted. Everything needed already exists: `Phoenix.Component` (bundled in `phoenix_live_view ~> 1.1`, locked at 1.1.31), the complete `sg-*` BEM CSS token layer in `test/example/priv/static/assets/css/app.css`, plain-JS hooks already wired in the admin shell, and the existing Playwright `admin-checkpoints-{chromium,mobile,dark}` project partition. The only new source file this milestone produces is `lib/sigra/admin/components.ex`.

**Core technologies (unchanged):**
- `Phoenix.Component` (phoenix_live_view 1.1.31) — correct host for a lib-owned HEEx component module; `use Phoenix.Component` (not `use Phoenix.LiveView`) since the module renders markup but owns no socket
- `Phoenix 1.8.7` — already the project target; `~H"""` HEEx sigil fully supported
- `@playwright/test ^1.48.0` + `@axe-core/playwright ^4.10.0` — already installed; new checkpoints added inside the existing single spec, not new projects or config entries

**What NOT to add:**
- No new Hex dependencies
- No Tailwind (the admin surface is explicitly `--no-tailwind`; mixing utility classes breaks the `sg-*` responsive and dark-mode system)
- No Alpine.js, Stimulus, or any JS framework (all interactive patterns in scope are pure CSS conditionals or existing `phx-click` events)
- No `assign_async/3` / `Phoenix.LiveView.Async` (current mounts are synchronous; async introduces Playwright await complexity and is out of scope for a coherence pass)
- No new Playwright config projects (add checkpoints inside the existing spec's single test body)
- No new `sg-*` CSS tokens or motion primitives (the token layer is mature at ~89 properties; this milestone audits motion USAGE — it does not add primitives)
- The one permitted CSS addition: ~15 lines of `sg-notice` styles inside `@layer sg-components` in `app.css`

### Expected Features

This milestone is scoped to polish and coherence of the existing 6-screen surface. Feature work is component consolidation, needs-led IA alignment, coverage gap closure, and seed enrichment.

**The 10-component canonical inventory — all land in `Sigra.Admin.Components`:**

| Component | Job | Current State |
|-----------|-----|---------------|
| `stat_link/1` | Scalar stat with a deep-link entry point | `metric_link` duplicated byte-for-byte in `IndexLive` + `OrganizationLive` |
| `stat/1` | Scalar stat without a link | Non-linking `summary_chip` variant in `UsersIndexLive` |
| `task_card/1` | Verb-first task card with primary CTA | `task_card` duplicated byte-for-byte in `IndexLive` + `OrganizationLive` |
| `summary_chip/1` | Count label for page-header strip | Private `defp` in `UsersIndexLive` |
| `applied_chip/1` | Applied filter chip with per-key remove | Private HEEx in 3 screens (`UsersIndexLive`, `AuditIndexLive`, `AuditUserLive`) |
| `empty_state/1` | Empty state (no data or filtered-no-match) | Private `sg-empty-state` blocks in 3 screens |
| `page_back/1` | Back navigation consuming `return_to` | Bespoke inline button in `UserShowLive` + `AuditUserLive`; absent elsewhere |
| `scope_ribbon/1` | In-body scope indicator (persistent org-scope signal) | Plain `sg-muted sg-text-sm` span in 2 screens; absent from 4 screens |
| `notice/1` | Contextual in-page alert/warning (tone + title + body) | Ad-hoc `sg-list-row` with `data-tone` in `UserShowLive` only |
| `skeleton/1` | Loading skeleton for async mount feedback | `.sg-skeleton` CSS class exists (app.css:1395) but is used by zero LiveViews |

The `sg-status-pill` tone system is already consistent across all screens — it is NOT extracted. Document tone assignment rules in a governance artifact instead.

**Must-have (table stakes) — coherence obligations:**
- Single needs-review alarm above the task grid (loud if >0, "all clear" if 0) — currently buried inside the posture-strip card
- Master-detail spine with identical `sg-page-header` anatomy (open, not boxed) across all 6 screens; `UserShowLive` currently uses `sg-card` wrapper
- Shared `Sigra.Admin.Components` module covering all 10 jobs above
- Audit mobile card layout (currently table-only and unusable on mobile; mirrors the proven `UsersIndexLive` dual-layout pattern using existing `sg-show-desktop`/`sg-show-mobile` classes)
- Playwright checkpoint coverage for the three unbaselined surfaces: `global-overview`, `org-overview`, `user-audit`

**Should-have (differentiators — elevate coherence for evaluators):**
- OrganizationLive: expired invitation seed (makes the `data-tone="risk"` "Expired" pill render in demo)
- OrganizationLive: frank (deletion-scheduled) added to Acme membership seed (shows deletion-scheduled member in org roster)
- Passkey-only persona — alice or morgan gets `passkey: true`, `totp: false` (fixes `UsersIndexLive` passkeys-pill-solo gap and `UserShowLive` passkeys-panel-solo gap)
- Global audit seed: additional action types (`account.password.change`, `auth.magic_link`, API token events) — richer evaluator vocabulary
- OrganizationLive: per-member "Open user" pivot link in the roster
- `IndexLive`: capability matrix demoted below posture strip

**Defer (Phase 5 enrichment or later, not blocking earlier phases):**
- Carol: second OAuth identity (Google) for multi-row Identities panel
- Skeleton component wired to async mount (pattern decision: sync vs async mount)
- Confirm modal extracted as a shared component (only one screen uses confirms today)
- Pagination demonstration (add personas to exceed 25 per page)

**What NOT to build:**
- Net-new admin surfaces (API-token / service-account management UI)
- Top-level nav restructure (adding or removing nav rungs)
- New `sg-*` CSS token additions beyond `sg-notice`
- New motion primitives (audit USAGE of existing ones — do not add new ones)
- Role-based admin forking (separate dashboards per persona)
- Broad Playwright behavior-matrix expansion (add only the 3 coverage-gap checkpoint slugs)

### Architecture Approach

The architecture boundary is strict and must not be violated: `Sigra.Admin.Components` is a pure lib-owned module at `lib/sigra/admin/components.ex` — same ownership as the 6 LiveViews in `lib/sigra/admin/live/`. It propagates via `mix deps.update sigra`, not installer re-runs. The 6 LiveViews add `import Sigra.Admin.Components` to replace their private duplicate `defp` components. The generated `AdminShell` (host-side) is NOT touched by this milestone — it is the template-vs-example seam and must remain stable.

**Major components and responsibilities:**

1. `Sigra.Admin.Components` (new, lib-owned, `lib/sigra/admin/components.ex`) — canonical shared HEEx function components using `use Phoenix.Component`; every public `def` declares full `attr`/`slot` contracts for compile-time caller warnings; no socket ownership, no LiveView lifecycle; `attr :rest, :global` only on components whose root element may receive HTML event attributes from callers (`page_back`, `empty_state`, `scope_ribbon`)
2. `lib/sigra/admin/live/*.ex` (6 existing LiveViews, modified in Phases 2-4) — import shared components, remove private `defp` duplicates; screen data logic and event handling unchanged
3. `test/example/priv/playwright/tests/admin-checkpoints.spec.ts` (extended in Phases 3-4) — 3 new checkpoint slugs added inside the existing single-test body using the existing `captureAndVerify` + `assertCheckpointScreenshot` + `assertNoAxeViolations` helpers; no new spec files, no new `playwright.config.ts` projects
4. `test/example/lib/example/demo/{personas.ex,seeds.ex}` (Phase 5 enrichment) — seed gaps closed with strict count-threshold guard updates and `@seed_reference_ts` determinism preserved
5. `test/example/priv/static/assets/css/app.css` (one minor CSS addition) — ~15 lines of `sg-notice` inside `@layer sg-components`; all 9 other new components use existing `sg-*` classes

**Page archetypes (3, mapped to existing modules — no new modules):**
- Overview: `IndexLive` (Global) + `OrganizationLive` (Org) — task card grid, single alarm, posture-strip, `scope_ribbon`
- List: `UsersIndexLive` + `AuditIndexLive` — `summary_chip` header strip, filter chips, table+card dual layout, pagination
- Detail: `UserShowLive` + `AuditUserLive` — `page_back`, open `sg-page-header`, `scope_ribbon`, sub-resource cards

**Critical boundary rules:**
- `Sigra.Admin.Components` is lib-owned, never generated — no `priv/templates/` counterpart needed or wanted
- `AdminShell` is generated and must not be modified in this milestone
- All new component CSS must land inside `@layer sg-components { }` — no unlayered rules, no new `!important` outside the `prefers-reduced-motion` block
- Skeleton: implement as a render-phase conditional on a nil-assign guard, not via `assign_async/3`
- Template parity: after every phase that modifies a lib LiveView's HEEx, run `diff lib/sigra/admin/live/*.ex priv/templates/sigra.install/admin/*.ex` — any diff beyond namespace substitution is a parity gap

### Critical Pitfalls

1. **Baseline thrash from non-identical HEEx extraction** (Critical, Phase 1) — wrapping inline blocks in function components can change attribute order, whitespace normalization, or add wrapper elements, producing pixel diffs even when visually identical. Cascade: one diff across 3 projects x 5 checkpoints = 15 PNG re-records in one commit, destroying visual contract integrity. Prevention: use `render_component/2` in ExUnit for markup equality checks before Playwright runs; Phase 1 success criterion = zero re-records; a baseline firing is a bug in the extraction, never a permission to re-record.

2. **Installer parity drift** (Critical, Phase 1 through Phase 6) — after lib LiveViews swap private `defp` call sites to `Sigra.Admin.Components`, the `priv/templates/sigra.install/` counterparts may diverge silently. The `admin-generated` lane catches this only if run on every phase that touches HEEx. Prevention: run `admin-generated` as a gating check per phase, not a Phase 6 afterthought; maintain a template parity checklist per phase; the prior documented failure mode (MEMORY.md `reference_installer_template_drift.md`) confirms this risk is real.

3. **Axe gate regression from markup changes** (Critical, Phases 1, 3-4) — new shared components may introduce WCAG A/AA violations; new checkpoints may surface pre-existing violations on never-tested pages, blocking the phase. Prevention: define ARIA semantics in Phase 0 component signatures (`role="status"` or `role="alert"` on `notice`; `aria-hidden="true"` on `skeleton`; visible text on `page_back`); run axe against each new component in isolation before wiring into real LiveViews; pre-audit new checkpoint pages against current `main` to distinguish regressions from pre-existing issues.

4. **CSS layer escape** (High priority, all phases) — new component CSS landing outside `@layer sg-components` outranks all layered rules, silently breaking dark-mode token overrides. Prevention: all new styles inside `@layer sg-components { }`; no new `!important` outside the documented `prefers-reduced-motion` block; code review checklist item for every phase touching `app.css`.

5. **Seed count-threshold guard erosion** (Moderate, Phase 5) — Phase 5 adds audit rows; if the `@audit_actions`/`@persona_audit_events` list lengths change without updating the idempotency guard, `Seeds.run/0` called twice produces duplicate rows breaking the demo. Prevention: count-threshold guard update must be in the same commit as any list changes; verify `Seeds.run/0` twice on a fresh DB produces identical counts before shipping Phase 5.

---

## Implications for Roadmap

The approved kickoff brief (`~/.claude/plans/recap-sigra-v1-0-0-ga-cached-puppy.md`) defines the authoritative Phase 0–6 structure. The roadmap maps directly to it. The implications below align with and annotate that structure for the roadmapper.

### Phase 0 — Journey Map + Component Inventory (design contract, no code)
**Rationale:** Component signatures and archetype layouts are architectural decisions. Wrong signatures in Phase 0 means re-extracting in Phase 2. The written Job→Component mapping and ARIA spec per component are prerequisites that prevent scope creep and baseline thrash downstream.
**Delivers:** Committed artifact: persona→JTBD→touchpoint matrix; canonical 10-component set with full `attr`/`slot` signatures; Job→Component mapping table; motion spec per component (filter-chip toggle = no transition; row reveal = opacity+translateY ~140ms on `phx-mounted` only; ⌘K result filtering = un-animated); 3 page archetype compositions; anti-churn list.
**Avoids:** Pitfall 4 (churn-for-churn consolidation — `metric_link` vs `summary_chip` differ in job; must verify before merging); Pitfall 5 (over-animation — motion spec defined before any code).

### Phase 1 — Shared Component Foundation (behavior-preserving, KEYSTONE)
**Rationale:** This is the keystone phase. Its success criterion — all 5x3 existing Playwright baselines green with zero re-records — is the proof that extraction preserved rendering. No existing LiveView file is touched in this phase. A baseline firing in Phase 1 is a bug, not permission to re-record.
**Delivers:** `lib/sigra/admin/components.ex` with all 10 canonical components. `sg-notice` ~15-line CSS addition inside `@layer sg-components` (the only CSS change in this phase).
**Success criterion:** `admin-generated` parity lane green AND all 5x3 chromium/mobile/dark baselines pass with ZERO re-records.
**Avoids:** Pitfall 1 (baseline thrash — `render_component/2` equality check before Playwright); Pitfall 2 (installer parity — `admin-generated` is a gate here, not Phase 6); Pitfall 3 (axe — ARIA semantics from Phase 0 verified on fixture pages); Pitfall 6 (CSS layer discipline enforced at PR review).

### Phase 2 — Adopt Shared Components on Baselined Screens (reconcile, not redesign)
**Rationale:** The 5 baselined screens import `Sigra.Admin.Components` and remove private duplicate `defp` defs. Visual deltas are intentional and deliberate — re-record baselines only after HTML report review.
**Delivers:** No more private duplicate components in any LiveView; `UserShowLive` adopts open `sg-page-header` (removes `sg-card` wrapper); consistent `<.page_back>` across detail screens; `<.scope_ribbon>` on all 5 screens; `AuditIndexLive` gets filter-chip parity with `UsersIndexLive`.
**Avoids:** Pitfall 2 (`admin-generated` lane run after each screen modified); Pitfall 7 (behavior contracts — `admin-user-operations` ExUnit spec run before any `IndexLive` change; deep-link query params verified to still route correctly).

### Phase 3 — Under-iterated: Two Overview Landings (HIGHEST EFFORT)
**Rationale:** `IndexLive` and `OrganizationLive` have no committed checkpoint baselines today. They are the front door for both operator personas. The needs-led instinct is correct but not executed: alarm is buried, capability matrix competes with task cards, posture strip is at equal visual weight. Throwaway HTML sketches reviewed before any LiveView edits.
**Delivers:** Both overview screens fully needs-led: single alarm above task grid; posture strip demoted to secondary; capability matrix demoted to lowest priority; skeletons on initial mount; reconciled Global-vs-Org visual rhythm. NEW checkpoints `global-overview` + `org-overview` across all 3 Playwright projects.
**Addresses:** needs-review alarm prominence (P1), scope ribbon on overview screens (P1), capability matrix demotion (P2).
**Avoids:** Pitfall 7 (behavior contracts — document existing assertions before touching `IndexLive`; verify `?locked=true` and `?needs_review=true` deep-link routing still works after restructure; re-record `global-user-index` baseline deliberately if the overview page layout shifts it).

### Phase 4 — Under-iterated: Audit Mobile + Per-User Audit (HIGH EFFORT)
**Rationale:** `AuditIndexLive` is table-only on mobile (unusable by the Org Admin persona working from a phone during an incident). `AuditUserLive` has no committed baseline. The mobile card fallback pattern is proven on `UsersIndexLive` and uses only existing `sg-show-desktop`/`sg-show-mobile` CSS utilities — no new CSS needed.
**Delivers:** Mobile card fallback for `AuditIndexLive` and `AuditUserLive`; `AuditUserLive` adopts shared `<.page_back>`, `<.scope_ribbon>`, `<.notice>`, `<.empty_state>`; unified audit-row component shared with `UserShowLive` "Recent audit" panel. NEW checkpoint `user-audit` x3 Playwright projects.
**Avoids:** Pitfall 8 (mobile layout gaps — `audit-explorer` mobile baseline deliberately re-recorded as intended delta; breakpoint uses `--sg-breakpoint-lg` token, not hardcoded pixel value; `maxDiffPixelRatio: 0.08` mobile threshold respected; layout verified on iPhone 13 device profile before committing baseline).

### Phase 5 — Cross-Journey Coherence Sweep + Seed Enrichment
**Rationale:** Walk the full Platform Operator and Org Admin journeys end-to-end in both scopes. Fix remaining seams. Close the seed gaps that prevent screens from being self-demonstrating.
**Delivers:**
- Full journey traversal: empty-state spacing parity; notice/flash unification; focus/hover parity; back-nav round-trips verified; `scope_ribbon` confirmed on all 6 screens.
- Seed gaps closed (in priority order):
  1. Expired invitation for Acme — makes `data-tone="risk"` "Expired" pill render on org overview
  2. Frank added to Acme membership — deletion-scheduled member in org roster
  3. Passkey-only persona (alice or morgan, `passkey: true`, `totp: false`) — fixes passkeys-pill-solo gap in `UsersIndexLive` and passkeys-panel-solo gap in `UserShowLive`
  4. Additional audit action types: `account.password.change`, `auth.magic_link`, API token events (3-4 seed rows)
  5. Carol: second OAuth identity (Google) for multi-row Identities panel
- Scripted Playwright journey filmstrip reviewed for least-surprise violations.
**Avoids:** Pitfall 9 (seed guard erosion — guard update in same commit as list changes; `Seeds.run/0` twice = identical counts on fresh DB); Pitfall 10 (seed data leaking into CI — no test helpers call `Seeds.run/0`; clean-DB proof run).

### Phase 6 — Regression Hardening + Baseline Ratification
**Rationale:** Ratify all re-recorded and new baselines. Confirm dark/mobile thresholds fit new checkpoints. Final clean run across all lanes. Document the component governance contract.
**Delivers:** All committed PNGs ratified; `admin-checkpoints-{chromium,mobile,dark}` clean; `admin-generated` parity lane clean; `demo-showcase` clean. Motion usage audit checklist: keyboard-only session through the admin console; verify no action triggered more than twice per minute has visible animation.
**Success criterion:** Proof run on a clean DB (not a dev DB with accumulated seed history). CI passes, not just local.

### Phase Ordering Rationale

- Phase 0 before all code: component signatures are design decisions; wrong signatures in Phase 0 means re-extracting in Phase 2 under time pressure.
- Phase 1 before Phase 2: behavior-preserving extraction must be independently verified (zero baseline diffs) before intentional visual changes land — merging them makes failures ambiguous.
- Phases 3-4 after Phase 2: the Overview and audit screens adopt the shared components built in Phase 1; they cannot be iterated to their final forms before the component foundation is stable.
- Phase 5 after Phases 3-4: coherence sweep and seed enrichment require all 6 screens in their target states before the end-to-end journey can be honestly evaluated.
- Phase 6 last: baseline ratification is meaningless if any screen is still changing.

### Research Flags

Phases with well-documented patterns (skip additional research):
- **Phase 0:** Component signature format follows standard Phoenix.Component `attr`/`slot` idioms; the IA-JOURNEY-SYNTHESIS.md and kickoff brief fully specify the design contract content.
- **Phase 1:** `Phoenix.Component` extraction patterns are standard; `render_component/2` equality testing is documented in Phoenix LiveView test helpers.
- **Phase 6:** Playwright baseline ratification procedure is fully defined in the kickoff brief.

Phases that may surface decisions requiring targeted research during planning:
- **Phase 3:** The exact visual treatment for the needs-review alarm (above task grid as a standalone `<.notice>` vs integrated as a `<.notice>` subhead vs a dedicated alert band) requires throwaway HTML sketches before LiveView edits. Recommend 2-3 layout candidates reviewed with screenshot analysis before the phase plan finalizes.
- **Phase 4:** The audit mobile card layout must be spec'd against the iPhone 13 device profile (`maxDiffPixelRatio: 0.08`) before committing the baseline. Run locally against that device profile to verify breakpoint behavior before finalizing the phase plan.
- **Phase 5 (passkey-only persona selection):** alice and morgan are both candidates. The choice depends on which persona's existing ExUnit test coverage is thinner. Check `test/example/` fixtures before committing to a specific persona.

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All findings from direct file inspection (`mix.lock`, `package.json`, `playwright.config.ts`). No new deps required — confirmed by inspecting what already exists in the locked versions. |
| Features | HIGH | All 10 component jobs identified from direct inspection of the 6 LiveView source files; duplication confirmed at specific line numbers. Seed gaps confirmed against `personas.ex` and `seeds.ex`. |
| Architecture | HIGH | Component boundary decisions grounded in the existing module namespace (`lib/sigra/admin/live/`), the hybrid lib+generator constraint from CLAUDE.md, and the `AdminShell` template-vs-example seam documented in MEMORY.md. |
| Pitfalls | HIGH | Baseline thrash and installer parity pitfalls grounded in the project's prior documented failure mode (`reference_installer_template_drift.md`) and actual Playwright spec threshold values (`maxDiffPixelRatio`). Seed guard erosion grounded in `seeds.ex` count-threshold pattern. |

**Overall confidence:** HIGH — research grounded entirely in direct codebase inspection and prior project experience. No hypothetical or speculative findings.

### Gaps to Address

- **Alarm placement (Phase 3):** The exact DOM position and visual treatment for the single needs-review alarm has two plausible candidates (standalone `<.notice tone="risk">` above the task grid vs integrated as the primary H1 subhead). Resolve with throwaway HTML sketches in Phase 3 planning before writing LiveView code.
- **Passkey-only persona selection (Phase 5):** alice and morgan are both valid candidates. The correct choice depends on which persona's existing test coverage is thinner. Check `test/example/` ExUnit test fixtures before committing.
- **`sg-notice` CSS scope:** The ~15 lines of `sg-notice` CSS need to be written and reviewed for dark-mode correctness before Phase 1 lands. This is the only new CSS class; all 9 other components use existing `sg-*` classes. Write it in Phase 0 as part of the component signatures artifact so it is ready for Phase 1.

---

## Sources

### Primary (HIGH confidence)
- `lib/sigra/admin/live/index_live.ex` — `metric_link`/`task_card` private defs (lines 118-125, 132-144); needs-review alarm position inside posture strip
- `lib/sigra/admin/live/organization_live.ex` — byte-identical `metric_link`/`task_card` duplication (lines 165-195)
- `lib/sigra/admin/live/users_index_live.ex` — `summary_chip`/`applied_chip`/`empty_state` private defs; filter chip pattern; mobile dual-layout
- `lib/sigra/admin/live/user_show_live.ex` — `sg-card` boxed header (line 97); bespoke back-nav (lines 91-95); ad-hoc `sg-list-row` alert (line 131)
- `lib/sigra/admin/live/audit_index_live.ex` — table-only layout, no mobile fallback (line 129)
- `lib/sigra/admin/live/audit_user_live.ex` — per-user audit; return-to round-tripping; no committed baseline
- `test/example/priv/static/assets/css/app.css` — `.sg-skeleton` at line 1395 (unused); `@layer sg-base, sg-components, sg-overrides` (line 15); `sg-notice` absent
- `test/example/priv/playwright/playwright.config.ts` — 3-project partition; `ADMIN_CHECKPOINTS_SPEC` regex; single-test design
- `test/example/priv/playwright/tests/admin-checkpoints.spec.ts` — 5 existing checkpoints; `captureAndVerify`/`assertCheckpointScreenshot`/`assertNoAxeViolations` contract; `maxDiffPixelRatio: 0.08` (mobile)
- `test/example/lib/example/demo/personas.ex` + `seeds.ex` — no expired invitation; frank not in Acme; no passkey-only persona; limited audit action types
- `priv/templates/sigra.install/admin/components/admin_shell.ex` — byte-identical to `test/example/` counterpart modulo EEx substitution
- `mix.lock` — `phoenix_live_view: 1.1.31`, `phoenix: 1.8.7`
- `~/.claude/plans/recap-sigra-v1-0-0-ga-cached-puppy.md` — approved kickoff brief; Phase 0-6 structure; anti-churn list; verification contract (canonical authority for this milestone)
- `.planning/research/IA-JOURNEY-SYNTHESIS.md` — GOV.UK needs-led model; Emil Kowalski animation principles; admin console IA patterns; milestone priority order
- `MEMORY.md` / `reference_installer_template_drift.md` — documented prior installer parity failure mode

### Secondary (MEDIUM confidence)
- Phoenix LiveView 1.1 docs: `Phoenix.Component`, `attr/3`, `slot/3`, `render_component/2`
- GOV.UK Design Principles (gds.blog.gov.uk) — needs-led IA model; task-over-org-structure navigation
- Emil Kowalski: Great Animations; 7 Practical Animation Tips — motion usage governance; when NOT to animate

---

*Research completed: 2026-06-03*
*Ready for roadmap: yes*
