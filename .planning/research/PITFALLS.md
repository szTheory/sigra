# Pitfalls Research — v1.34 ADMIN-UI-COHERENCE

**Domain:** Coherence/consolidation pass on a maturing Phoenix LiveView component system with screenshot-baseline contracts, lib/generated boundary, and axe a11y gate
**Researched:** 2026-06-03
**Confidence:** HIGH — grounded in the actual codebase (admin-checkpoints.spec.ts, seeds.ex, app.css, kickoff brief), confirmed against the existing project knowledge base (IA-JOURNEY-SYNTHESIS.md, MEMORY.md, PROJECT.md). No speculation about hypothetical systems.

---

## Critical Pitfalls

### Pitfall 1: Baseline Thrash — Non-Intentional Delta Triggering Re-Record Cascades

**What goes wrong:**
A component extraction intended to be markup-identical produces a pixel diff because a whitespace node, attribute order, inline style, or slot structure changed in the HEEx render output — even though the visual result looks identical to a human. Playwright's `toHaveScreenshot` fires on the diff, the developer re-records, and the committed PNG no longer reflects the old design intent. This can cascade: one re-record across 3 projects (chromium/mobile/dark) x 5 checkpoints = 15 baseline PNGs in one commit, making visual review of the HTML report meaningless because every PNG changed.

**Why it happens:**
HEEx component extraction is not byte-identical by default. Wrapping an inline block in a function component adds a wrapper element, changes attribute order, or changes whitespace normalization. The baseline was captured against the unwrapped version. Even correct extractions produce diffs from: (1) `<.component>` adds an enclosing `<div>` or `<span>` where there was none; (2) Phoenix assigns attrs in insertion order, which can differ between a direct call-site and a component def; (3) slot content wrapping.

**How to avoid:**
- Before Phase 1 lands any code, run the full baseline suite against `main` and confirm all 15 PNGs pass. This establishes a known-clean reference point.
- For each new shared component, render a fixture page side-by-side against the old inline block using Playwright snapshot comparison. Diff must be zero pixels before replacing any call site.
- Use `render_component/2` in ExUnit for targeted markup equality: assert the rendered string matches exactly what the old inline block produced. Catches attribute-order and whitespace differences before Playwright runs.
- Decide up front which Phase 1 components are "behavior-preserving" (zero permitted baseline diff) vs. "intended visual delta" (deliberate re-record). Document this in the phase plan — not in hindsight.
- Commit Phase 1 with the explicit success criterion: "all 5x3 baselines stay green, no re-record." If any baseline fires, treat it as a bug in the extraction, not permission to re-record.

**Warning signs:**
- PR adds a new shared component module AND updated PNGs in the same commit without a documented "intended delta" justification.
- `toHaveScreenshot` diffs showing only sub-5px changes in spacing — these are almost always whitespace/wrapper diffs from extraction, not visual intent.
- Multiple baselines firing on a phase described as behavior-preserving.

**Phase to address:** Phase 1 (shared component foundation). The invariant must be stated before code is written: Phase 1 = zero baseline diff.

---

### Pitfall 2: Installer Parity Drift — lib-owned `Sigra.Admin.Components` Has No Counterpart in `priv/templates/`

**What goes wrong:**
After Phase 1 lands `lib/sigra/admin/components.ex` and the 6 LiveViews are migrated to call it, the `admin-generated` Playwright lane silently fails or drifts. The `priv/templates/sigra.install/admin/` tree does NOT have a `components.ex` equivalent — it only has `components/admin_shell.ex`. Generated host apps call into `Sigra.Admin.Components` via the lib dep, but the template files (which are copied into the host) may reference old inline private defs that no longer exist, or may not have been updated to call the new shared component.

The `admin-generated` lane verifies that a host app generated from `priv/templates/` renders identically to `test/example/`. If the templates lag the lib-side refactor, the lane either fails (template compile error) or passes for the wrong reason (the template still has the old inline defs, so it renders the old markup, but only passes because the baseline was re-recorded against the old markup).

**Why it happens:**
The lib/template boundary is asymmetric: lib-owned code updates automatically when the host runs `mix deps.update sigra`; template code is a one-time-copy. When lib-owned component logic changes its render output, any template that previously inlined the same logic silently diverges. This failure mode is documented in MEMORY.md (`reference_installer_template_drift.md`): "when generated-host checks fail but example passes, diff template vs example."

The specific topology: `lib/sigra/admin/live/*.ex` are lib-owned LiveViews. Their counterparts in `priv/templates/sigra.install/admin/*.ex` are generated copies. Both exist. Any HEEx change in the lib LiveViews must be mirrored into the templates. The new `Sigra.Admin.Components` module itself lives only in the lib and is never generated — but every LiveView call site that switches from inline private defs to `Sigra.Admin.Components.*` must have that call-site change reflected in the template.

**How to avoid:**
- Maintain a running "template parity checklist" for each phase that touches lib-owned admin components. For every call site removed from a LiveView, verify the corresponding template file has been updated.
- The `admin-generated` lane is the machine contract. Run it before committing any Phase 1-4 change that modifies HEEx markup in a LiveView. Do not treat it as a Phase 6 gate only.
- Use a parity diff as a sanity check: `diff lib/sigra/admin/live/users_index_live.ex priv/templates/sigra.install/admin/users_index_live.ex` — any diff that is not a module-name prefix or host-app namespace substitution is a parity gap.
- If a new shared component is added to the lib but the LiveViews calling it are lib-owned (not generated), templates don't need updating for that component itself. But any LiveView whose template counterpart exists must be kept in sync.

**Warning signs:**
- `admin-generated` lane passes but has not been run since the component refactor began.
- Template files have a different number of component call sites than the live lib files.
- Phase 6 "baseline ratification" discovers template parity gaps that should have been caught in Phase 1.

**Phase to address:** Phase 1 (must run `admin-generated` as a gating check, not just chromium/mobile/dark lanes). Enforced again at Phase 6 final ratification.

---

### Pitfall 3: Axe Gate Regression from Markup Changes — Silent WCAG Failures on New Checkpoints

**What goes wrong:**
Markup changes during consolidation introduce WCAG A/AA violations not present in the original inline components. Common causes: (1) a shared component wraps content in a new container element that breaks landmark structure; (2) an icon inside a shared `stat_link` component loses its `aria-hidden="true"` or its visible text fallback; (3) a new `notice` component uses `<div role="alert">` with no accessible name; (4) a scope ribbon or skeleton adds an `aria-live` region that duplicates an existing one.

New checkpoints (`global-overview`, `org-overview`, `user-audit`) added in Phases 3-4 have never run axe before. Their first run may surface pre-existing violations that were always present but untested. These are not regressions from v1.34 work, but they fail the gate and block the phase.

**Why it happens:**
- Shared components expose semantics through a single interface. If a call site relied on implicit semantics (e.g., the enclosing `<section>` provided the landmark), moving to a function component may break that assumption.
- `assertNoAxeViolations` runs `wcag2a` and `wcag2aa` tags. Adding new checkpoint coverage surfaces previously untested pages.
- LiveView async mounts (skeletons) can produce transiently incomplete DOM during the axe scan if `waitForLiveViewReady` resolves before hydration settles on a slow data fetch.

**How to avoid:**
- Run axe against each new shared component in isolation using a dedicated fixture page before wiring it into real LiveViews. Catch semantic issues at the component boundary, not at the page level.
- When adding new checkpoints (Phases 3-4), run axe on the current `main` snapshot of those pages first. File any pre-existing violations as a separate tracked todo so they don't block the phase and aren't attributed to the v1.34 refactor.
- For new async-loaded sections (skeletons), add a settled-state selector check (e.g., `waitForSelector('[data-loaded="true"]')`) before `assertNoAxeViolations` fires — axe on a skeleton DOM flags missing text content.
- For `<.notice>` and `<.scope_ribbon>` components: specify ARIA semantics in Phase 0's component signatures document. For notice: `role="status"` (informational) or `role="alert"` (error) with a visible heading always. For scope ribbon: decorative, no role.
- The `wcag2a`/`wcag2aa` scope in `assertNoAxeViolations` intentionally excludes `region`. Keep that scope — do not widen it to resolve new violations.

**Warning signs:**
- Axe passes on old checkpoints but fires on new checkpoints — investigate as pre-existing violation, not regression.
- A new shared component renders icon-only buttons (`<.page_back />`) without visible text — needs `aria-label` on the component signature.
- `role="alert"` added to a notice component without an `aria-label` or visible heading text.

**Phase to address:** Phase 0 (component signatures must include ARIA spec). Enforcement in Phase 1 (component extraction), Phase 3-4 (new checkpoint axe runs).

---

## High-Priority Pitfalls

### Pitfall 4: Churn-for-Churn — Consolidating Components Without Proving "Same Job"

**What goes wrong:**
Consolidation proceeds under the assumption that `metric_link` in `index_live` and `summary_chip` in `users_index_live` are doing the same job — but they may not be. `metric_link` is a deep-link launcher; `summary_chip` is a count label with a filter action. Forcing them into one `stat_link` component with a variant system produces a component with 4 booleans (`:linked`, `:action`, `:count`, `:label_only`) that is harder to use than two focused originals.

**Why it happens:**
The consolidation is driven by "these look similar" rather than "these do the same job." Similar visual appearance does not mean semantic identity. The kickoff brief identifies "3 stat variants" as a dup target, but consolidation without a written Job-to-Component mapping can merge semantically distinct things.

**How to avoid:**
- Phase 0 must produce the written Job-to-Component table before any Phase 1 code. Each job description must be expressed as a verb ("launches a filtered list view," "shows a count with an inline filter action") — not a visual description ("a rounded box with a number").
- For the stat family specifically: verify whether `metric_link`, `summary_chip`, and any third variant require the same props and interaction model. If they differ, they are not the same job and should not share one component.
- The anti-churn list in the kickoff brief is the authority: "Metric-as-entry-point deep links" is explicitly in the keep-not-touch column. A `stat_link` consolidation that breaks the deep-link behavior violates this.
- Each consolidated component in Phase 1-2 should have a "jobs served" comment in the def: `# Job: display posture metric as a deep-link launcher to a filtered user list`.

**Warning signs:**
- The new shared component has more than 3 optional assigns.
- A consolidation PR leaves a `# TODO: handle the filter variant` comment in the component.
- Behavior specs (`admin-user-operations`, `admin-audit`) begin failing after Phase 2 consolidation.

**Phase to address:** Phase 0 (written Job-to-Component mapping). Phase 1 (enforce one component per job, not one component per visual family).

---

### Pitfall 5: Over-Animation on Keyboard-Frequent Actions

**What goes wrong:**
Adding shared components creates an opportunity to apply the `sg-*` motion system uniformly — but uniform application means filter operations, row selections, and list navigation (actions done dozens of times per session) receive the same `--sg-transition-enter` treatment as first-arrival panels. This makes the admin console feel sluggish to an operator doing rapid triage.

Specific risks: (1) the new `filter_chip` / `applied_chip` components given `sg-transition-enter` on toggle; (2) the list re-rendering after a filter change animating individual rows with `translateY + opacity` at 140ms each; (3) skeleton-to-content transitions animating on every keyboard-tab navigation.

**Why it happens:**
The `sg-*` motion token layer is well-designed (Emil Kowalski compliant, sub-300ms, ease-out, transform/opacity only). The problem is application scope, not token design. Developers apply tokens to everything because the tokens exist and the CSS is already there. The kickoff brief and IA-JOURNEY-SYNTHESIS.md both state this explicitly: "filter apply = near-instant (no re-stagger); cmd-K result filtering un-animated."

**How to avoid:**
- Phase 0 component signatures must include a motion spec for each component: "no transition on filter chip toggle; transition only on initial mount."
- When writing `filter_chip` and `applied_chip` components, default to `transition: none` on state changes. Only add motion for the first-appearance case (phx-mounted hook).
- For list row reveals: apply motion only on the `phx-mounted` callback (new rows), not on every LiveView patch that updates existing rows.
- Motion audit is explicitly Phase 6 scope. Make Phase 6 include a checklist: run a keyboard-only session through the admin console, verify no action triggered more than twice per minute has visible animation.

**Warning signs:**
- Any CSS rule in a new component that applies `var(--sg-transition-enter)` to a pseudo-class other than `:hover` or `[phx-mounted]`.
- Filter chip toggle has a CSS transition on `background-color` — this fires on every filter apply.
- The audit list re-render triggers a stagger animation on rows that were already visible.

**Phase to address:** Phase 0 (motion spec per component). Phase 5 (cross-journey sweep includes keyboard-only session). Phase 6 (motion usage audit checklist).

---

### Pitfall 6: CSS Specificity Trap When Adding Components Outside the `@layer sg-components` Block

**What goes wrong:**
New shared component CSS lands outside the `@layer sg-components` block — either at the top level or in a separate file loaded after the layer declaration. Because cascade layers make `@layer sg-components` rules uniformly lower specificity than unlayered rules, any new component CSS that escapes the layer declaration immediately outranks ALL `sg-components` rules for those selectors, causing unexpected overrides in both light and dark mode.

**Why it happens:**
The `app.css` architecture uses `@layer sg-base, sg-components, sg-overrides;` (line 15 of app.css). This is the correct discipline for a build-free `sg-*` token system to beat daisyUI's default.css without `!important`. But a new contributor or agent adding a component CSS block outside a layer declaration will silently break this — unlayered rules have higher precedence than any layered rule regardless of specificity.

The single documented exception is the `prefers-reduced-motion` block, which uses `!important`. This is the only permitted `!important` in the file per the file header comment.

**How to avoid:**
- All new `sg-*` component styles must land inside `@layer sg-components { }`. No exceptions.
- Any override of an existing component's default appearance must land in `@layer sg-overrides { }`.
- No new `!important` declarations except inside the documented `prefers-reduced-motion` block.
- If a new shared component needs styles not currently in `app.css`, add them inside the existing `@layer sg-components` block at the relevant position, not in a separate file or at the top level.
- The `sg-overrides` layer is the correct place for scope-specific tweaks (e.g., "stat links inside the overview landing use wider padding"). This is not `!important` territory — it is the designed override path.

**Warning signs:**
- A PR adds a new `.sg-notice { }` block that is not wrapped in `@layer sg-components { }`.
- An existing token value appears to stop applying to a new component even though the token is set in `:root`.
- Dark-mode overrides on a new component are not firing — often caused by the component's base rule escaping the layer and gaining higher precedence than the `@media (prefers-color-scheme: dark) { :root { } }` token override.

**Phase to address:** Phase 1 (enforce layer discipline when adding component CSS). Code review checklist item throughout all phases.

---

### Pitfall 7: Needs-Led Landing "Hardening" Breaking the Existing Behavior Contract

**What goes wrong:**
Phase 3 refactors `IndexLive` to move from "posture metrics first" to "verbs-first task cards + one alarm." During this refactor, one of the following breaks silently: (1) the `admin-user-operations` behavior spec that asserts Global scope label presence; (2) `assertCheckpointScreenshot` for `global-user-index` (already baselined) fires because the overview page changed; (3) the deep-link behavior (`?locked=true`, `?needs_review=true`) from task cards routes to the wrong query params.

**Why it happens:**
The behavior specs and the existing `global-user-index` baseline are contracts written against the CURRENT `IndexLive` structure. Phase 3 makes intentional changes to that structure. The correct procedure is: (1) run specs first to establish what contracts exist; (2) change only what is necessary; (3) re-record baselines deliberately as "intended delta"; (4) verify deep-link routing still works. The typical failure is skipping step 1 — making the visual change, running Playwright, and treating a passing screenshot as proof of correctness without verifying deep-link behavior or behavior specs.

**How to avoid:**
- Before Phase 3 touches `IndexLive`, run `admin-user-operations` ExUnit tests and the `global-user-index` checkpoint. Document which assertions exist and what they protect.
- The needs-led landing changes are in IA-JOURNEY-SYNTHESIS.md: "verbs-first task cards primary, single needs-review alarm prominent, posture metrics demoted, capability matrix demoted." None of this requires removing existing deep-link query params or scope selectors. Verify this remains true in Phase 0.
- Baselines re-recorded in Phase 3 must be visually reviewed in the Playwright HTML report before the phase closes. The HTML report diff view is the explicit quality gate for intentional visual deltas.
- The `admin-checkpoints` spec tests the admin scope selector (`header.first()` contains `'Global'`). This assertion must survive Phase 3. If the scope ribbon moves to a different DOM position, update the test assertion to match the new position — do not delete it.

**Warning signs:**
- Phase 3 PR closes with "baselines updated" and no HTML report review documented.
- `?locked=true` deep link from the task card navigates to `/admin/users` without applying the filter.
- `admin-user-operations` spec count changes unexpectedly after Phase 3.

**Phase to address:** Phase 0 (inventory existing behavior contracts before touching Overview). Phase 3 (deliberate delta approach: run, change, verify, re-record with documented review).

---

### Pitfall 8: Mobile Layout Gaps on New Checkpoints — The Audit Index Has No Mobile Layout Today

**What goes wrong:**
Phase 4 adds the mobile card fallback to `AuditIndexLive` and adds `user-audit` checkpoint x3. If the mobile layout work is incomplete — for example, the card component renders but the table CSS still applies at mobile breakpoints — the `admin-checkpoints-mobile` project fires on `audit-explorer` (which may have been passing before because the existing mobile baseline was captured against the table-only layout). This invalidates the baseline on a screen that was previously "passing."

**Why it happens:**
The existing `audit-explorer` mobile baseline was captured against the current table-only layout (kickoff brief line 63: `audit_index_live.ex:129 table-only`). If Phase 4 adds a card fallback, the mobile baseline legitimately changes. But if the card fallback CSS is incomplete (e.g., the `sg-*` responsive breakpoint condition is wrong), the mobile checkpoint shows a broken layout rather than either the old table or the new card.

**How to avoid:**
- Before Phase 4 ships any mobile layout changes to `AuditIndexLive`, explicitly record what the current `audit-explorer` mobile baseline shows. Accept that it will be re-recorded as an "intended delta" when the card fallback lands.
- The `sg-grid` component in `app.css` already handles `grid-template-columns: 1fr` as the mobile default. New mobile card fallbacks should use `sg-grid` + `sg-stack` compositions, not new layout CSS.
- The mobile breakpoint is `--sg-breakpoint-lg: 1024px`. Use `@media (max-width: calc(var(--sg-breakpoint-lg) - 1px))` consistently. Do not hardcode `768px` or `375px`.
- `admin-checkpoints-mobile` uses an iPhone 13 device profile. Test locally against that exact profile before committing the mobile baseline.
- The `maxDiffPixelRatio` for mobile is `0.08` (stricter than dark's `0.1`). Mobile baselines are more fragile. Get the mobile layout right before recording.

**Warning signs:**
- Mobile card fallback renders but has `overflow: hidden` cutting off content — the table's overflow CSS is bleeding through.
- `admin-checkpoints-mobile` fires on `audit-explorer` after Phase 4 but the diff shows no card layout at all — the responsive breakpoint condition is not applying.
- New `user-audit` mobile checkpoint fires on first run with violations — a pre-existing mobile layout gap discovered, not a Phase 4 regression.

**Phase to address:** Phase 4 (mobile fallback is the primary deliverable). Baseline re-record for `audit-explorer` mobile is an expected "intended delta."

---

## Moderate Pitfalls

### Pitfall 9: Seed Data Enrichment — Count-Threshold Guard Erosion

**What goes wrong:**
Phase 5 enriches `seeds.ex` to add more audit variety, OAuth provider data, and varied session/MFA/passkey states. If the enrichment adds new audit events without updating the count-threshold guard in `seed_audit_events/2`, the idempotency contract breaks: on a re-run, the threshold check passes (count is low), and the full batch inserts again, creating duplicate audit rows. Over multiple re-runs, the audit explorer shows hundreds of duplicate events, breaking the demo experience and the `demo-showcase` Playwright lane.

**Why it happens:**
The count-threshold guard (`demo_tied_count < length(@audit_actions) + length(@persona_audit_events)`) is computed from the compile-time list lengths. If Phase 5 adds rows to `@persona_audit_events`, it must also update the threshold. A common mistake is adding rows to the list without considering that existing dev databases already have the old row count but not the new ones — the threshold fires correctly on a fresh DB but silently no-ops on an existing DB with the old row count.

**How to avoid:**
- Before Phase 5 modifies `@audit_actions` or `@persona_audit_events`, document the new expected total count and verify the guard formula still reflects it.
- Prefer adding new audit event types that use the same `allow_reserved: true` pattern. New rows must use a new `offset` value — never reuse offsets, as the `@seed_reference_ts` anchor is pinned and deterministic.
- The `MIX_ENV == :test` raise-guard in `priv/repo/seeds.exs` is the safety net against CI contamination. Do not move seed logic into a path callable from the test suite without verifying this guard is in effect.
- If Phase 5 adds new seed categories (e.g., more OAuth identities per user), use `on_conflict: :nothing` + unique-index pattern where a unique index exists. For tables with no unique index (audit_events), the count-threshold guard must be updated.
- The whole audit batch is wrapped in `Repo.transaction/1`. This is correct — a mid-batch crash would otherwise leave fewer rows than the threshold expects, causing re-runs to accumulate duplicates. Keep this transaction.

**Warning signs:**
- `Seeds.run/0` called twice on a dev database produces a different audit row count than the first call.
- `demo-showcase` Playwright lane starts showing pagination on the audit explorer where there was none — duplicate rows pushed the count above the page size.
- Seeds smoke test fails with an audit row count mismatch after Phase 5.

**Phase to address:** Phase 5 (seed enrichment). Count-threshold guard update must be in the same commit as any `@audit_actions` or `@persona_audit_events` list changes.

---

### Pitfall 10: Seed Data Leaking into the CI Test Database

**What goes wrong:**
Phase 5 enriches seeds. If any test helper or fixture in `test/example/` accidentally calls `Example.Demo.Seeds.run/0` outside the `seeds.exs` guard, or if the UAT stack (`scripts/uat/up.sh` on port 4011) is running while `mix test` executes, seed data from the demo DB contaminates test assertions about user counts, audit row counts, or organization membership queries.

**Why it happens:**
The `priv/repo/seeds.exs` guard raises on `MIX_ENV == "test"`. But `test/example/` ExUnit tests run against the SQL Sandbox. If `SIGRA_TEST_PG_*` env vars are set to the UAT port instead of the test port, `mix test` connects to the seeded demo DB. Additionally, if a fixture helper imports or calls `Seeds.run/0` without the guard, seed data bleeds into test assertions.

**How to avoid:**
- Confirm no `test/` file calls `Seeds.run/0` directly. The seeds orchestrator is for dev/demo only.
- Explicitly document in the phase plan that `SIGRA_TEST_PG_*` vars must not be set to the UAT port during `mix test`. The test env uses its own Postgres connection from `Sigra.Test.PostgresCase`.
- When enriching seeds with new personas, verify no test assertion uses `Repo.aggregate(User, :count) == N` (a fragile absolute count that seeds would break) rather than asserting properties of specific test-created users.
- Phase 6 proof run must be on a clean DB, not a dev DB with accumulated seed history.

**Warning signs:**
- `mix test` passes locally but `admin-generated` lane fails in CI — CI uses a clean DB, local has leftover seed data.
- An ExUnit test asserts `Repo.aggregate(AuditEvent, :count) == 18` — this will fail after Phase 5 adds more events.

**Phase to address:** Phase 5 (seed enrichment must not change the test DB contract). Phase 6 (final proof run on a clean DB).

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Re-recording baselines instead of fixing the extraction diff | Unblocks phase progress | Lost visual contract integrity; baselines no longer represent design intent | Never in Phase 1. Only in Phases 2-4 after an explicit "intended delta" review in the HTML report |
| Skipping `admin-generated` lane until Phase 6 | Faster per-phase iteration | Template parity gaps accumulate and are expensive to fix at the end | Never — `admin-generated` must gate every phase that touches lib-owned HEEx |
| Adding `!important` to resolve a cascade specificity conflict | Fixes the visual quickly | Breaks the `@layer` discipline; future token overrides silently lose | Never — use `@layer sg-overrides` instead |
| Hardcoding `rgba(21,21,21,0.1)` instead of `var(--sg-color-line)` | One fewer variable dependency | Dark-mode override on `--sg-color-line` no longer applies | Never — tokens are the single source of truth |
| Merging two semantically distinct components into one with many opts | Reduces component count | A component with more than 3 boolean opts is harder to use than two focused ones | Never for this milestone — one component per job |
| Using `DateTime.utc_now()` in seed timestamps | Simple to write | Seeds are non-deterministic; CI diffs and "occurred_at" ordering changes each run | Never — always use the pinned `@seed_reference_ts` anchor |

---

## "Looks Done But Isn't" Checklist

- [ ] **Phase 1 component extraction:** `admin-generated` lane ran AND passed (not just chromium/mobile/dark).
- [ ] **Phase 1 behavior-preserving claim:** All 5x3 baselines green with zero re-records. Confirmed in CI output, not just local.
- [ ] **Phase 2 consolidation:** Every old private component def removed from individual LiveView files after the shared component is adopted. No dead private defs left behind.
- [ ] **Phase 3 needs-led landing:** Deep-link query params still route correctly from task cards. `?locked=true`, `?needs_review=true` tested by ExUnit or Playwright assertion, not assumed.
- [ ] **Phase 4 mobile audit:** The `audit-explorer` mobile baseline was deliberately re-recorded (not accidentally). The Playwright HTML diff was reviewed before merging.
- [ ] **Phase 5 seeds:** `Seeds.run/0` called twice on a fresh dev DB produces identical audit row counts both times. Count-threshold guard reflects the new total.
- [ ] **Phase 6 ratification:** Proof run on a clean DB (not a dev DB with accumulated seed history). CI passes, not just local.
- [ ] **a11y:** Every new checkpoint has its own `axe` label in `assertNoAxeViolations`. No pre-existing violations deferred by narrowing the axe tag scope.
- [ ] **Motion:** No `var(--sg-transition-enter)` on a state-change (filter toggle, row update). Motion only on `phx-mounted` first-appearance cases.
- [ ] **Template parity:** `diff lib/sigra/admin/live/*.ex priv/templates/sigra.install/admin/*.ex` shows only expected namespace substitutions. No markup differences.

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Baseline thrash from non-identical extraction | Phase 1 | All 5x3 baselines green, zero re-records in Phase 1 commit |
| Installer parity drift | Phase 1 + every phase touching HEEx | `admin-generated` lane passes on each phase PR |
| Axe regression from markup changes | Phase 0 (ARIA spec) + Phase 1 + Phase 3-4 | `assertNoAxeViolations` passes on all new + existing checkpoints |
| Churn-for-churn consolidation | Phase 0 (written Job-to-Component table) | Phase 0 artifact exists; each component has a "jobs served" comment |
| Over-animation on keyboard-frequent actions | Phase 0 (motion spec per component) + Phase 6 (usage audit) | Keyboard-only session test in Phase 6; no `sg-transition-enter` on state changes |
| CSS layer escape | Phase 1 (code review checklist) | No unlayered `sg-*` rules in any PR; no new `!important` outside reduced-motion block |
| Needs-led landing breaking behavior contracts | Phase 0 (contract inventory) + Phase 3 (deliberate delta) | `admin-user-operations` spec unchanged; deep-link routing verified |
| Mobile layout gaps on new checkpoints | Phase 4 (mobile fallback primary deliverable) | `admin-checkpoints-mobile` passes; HTML diff reviewed |
| Seed count-threshold guard erosion | Phase 5 (guard update in same commit) | `Seeds.run/0` twice = same count; `demo-showcase` lane passes |
| Seed data leaking into CI test DB | Phase 5 (no test helpers call Seeds) + Phase 6 (clean-DB proof) | Full suite on clean DB in Phase 6 proof run |

---

## Sources

- `~/.claude/plans/recap-sigra-v1-0-0-ga-cached-puppy.md` — approved kickoff brief; anti-churn list, phase structure, verification contract (HIGH confidence)
- `.planning/research/IA-JOURNEY-SYNTHESIS.md` — animation "when NOT to animate," token-governance antipatterns, GOV.UK needs-led IA model (HIGH confidence)
- `test/example/priv/playwright/tests/admin-checkpoints.spec.ts` — the baseline/axe/parity contract as implemented; `captureAndVerify`, `assertCheckpointScreenshot`, `assertNoAxeViolations`, `maxDiffPixels`/`maxDiffPixelRatio` thresholds (HIGH confidence, direct code)
- `test/example/lib/example/demo/seeds.ex` — count-threshold guard, `@seed_reference_ts` determinism, `on_conflict: :nothing` idempotency patterns, `allow_reserved: true` (HIGH confidence, direct code)
- `test/example/priv/static/assets/css/app.css` — `@layer sg-base, sg-components, sg-overrides` discipline, single `!important` rule location, `--sg-ease-out`/motion token system (HIGH confidence, direct code)
- `MEMORY.md` / `reference_installer_template_drift.md` — documented prior installer parity failure mode (HIGH confidence, team experience)
- `.planning/PROJECT.md` — v1.34 scope lock, anti-churn list, phase structure reference (HIGH confidence)

---
*Pitfalls research for: v1.34 ADMIN-UI-COHERENCE coherence/consolidation pass on a Phoenix LiveView admin system with screenshot-baseline contracts and lib/generated boundary*
*Researched: 2026-06-03*
