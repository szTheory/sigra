# Phase 155: Shared Component Foundation (KEYSTONE) - Context

**Gathered:** 2026-06-03 (assumptions mode + deep research)
**Status:** Ready for planning

<domain>
## Phase Boundary

Build `lib/sigra/admin/components.ex` — a lib-owned `Sigra.Admin.Components` module exposing all 10 canonical admin function components (`stat_link`, `stat`, `task_card`, `summary_chip`, `applied_chip`, `empty_state`, `page_back`, `scope_ribbon`, `notice`, `skeleton`), each with documented `attr`/`slot` contracts (COMP-01). The extraction must be **behavior-preserving** (COMP-02): the 5 existing Playwright admin checkpoints ×3 projects (15 baselines) stay green with **zero re-records**, proven by `render_component/2` markup-equality checks that run **before** Playwright.

**This phase BUILDS the module only.** It does NOT migrate any LiveView call site to consume it (that is Phase 156 / COHR-*). In Phase 155 the new components are defined but unwired, so Playwright renders the unchanged LiveViews and stays green trivially; the `render_component` equality test is the real proof that each component is a faithful drop-in.

**Hard constraints (locked):** No new Hex deps, no Tailwind, no Alpine, no `assign_async/3`. No new CSS (Phase 154 already added `sg-notice`); CSS boundary stays inside `@layer sg-components`. No invented CSS classes (notably no `.sg-stat`). A baseline re-record in this phase is a bug, not permission to proceed. `admin-generated` parity lane stays green (no call-site changes). axe WCAG A/AA stays green.
</domain>

<decisions>
## Implementation Decisions

### Module architecture & API (COMP-01)
- **D-01:** `defmodule Sigra.Admin.Components do use Phoenix.Component` — 10 **flat, stateless** public function components in contract order. NOT `Phoenix.LiveComponent`, NOT a `use Sigra.Admin.Components` macro. Composition stays in the page archetypes / call sites, never in wrapper components. (Idiom confirmed vs Phoenix `core_components.ex`, Petal, SaladUI; repo research bans `use` where `import` suffices — `elixir-opensource-libs-best-practices-deep-research.md:232`.)
- **D-02:** Every component declares explicit semantic `attr`s with `required:` / `default:` / `doc:` (and `values:` for enums, e.g. `notice` tone), plus `attr :class, :any, default: nil` merged as `class={["sg-…", @class]}`, plus `attr :rest, :global` spread on the outermost element. Slots: `slot :inner_block` for `notice` and `empty_state` (variable body markup); scalar attrs for the other 8. No `:let` needed (all are leaf renderers, not collection wrappers).
- **D-03:** Components emit the **exact** `sg-*` class strings pinned by `guides/reference/admin-design-contract.md`. For components with no dedicated CSS class (`stat`, `scope_ribbon`, `page_back`) reuse the contract's named utility classes (`sg-metric*`, `sg-muted`, `sg-btn--ghost`); **do NOT invent `.sg-stat`** or any new class (CSS boundary locked).
- **D-04:** Docs: `@moduledoc` states the module is the lib-owned canonical admin component set and points to `admin-design-contract.md`; each function gets a `@doc` (one-line job statement + `## Examples` HEEx snippet); `attr` docs auto-append. (core_components convention.)

### Library-owned, not generated-into-host
- **D-05:** The module ships **in the library** (`lib/sigra/admin/`), with NO generated/template counterpart. This does NOT violate "own your code": admin chrome is commodity presentation with zero security surface, and lib-ownership lets design/a11y fixes propagate via `mix deps.update` instead of freezing at install time (avoiding the template-drift problem in [[reference_installer_template_drift]]). The host override seam is the already-generated `admin_shell.ex` + the host-owned `sg-*` CSS token layer (mirrors Backpex / LiveDashboard / Oban Web). `attr :rest, :global` is the host's per-call extension seam since they can't fork the components.
- **D-06:** Phase 156 LiveViews will consume the module via `import Sigra.Admin.Components` (not `use`) and delete the now-duplicated private `defp` defs. (Out of scope for 155; recorded so the planner builds toward it.)

### The `notice` component — Option A′ (ship final form, corrected ARIA)
- **D-07:** `<.notice>` ships in its **final form using the purpose-built `sg-notice` class** — NOT the legacy `sg-list-row`. This is safe for the keystone because `.sg-notice` (`app.css:971-993`) is a byte-for-byte property clone of `.sg-list-row` (`app.css:945-967`) — the class swap is **pixel-neutral by construction** (Phase 154's explicit intent), so it forces zero Playwright re-records now or in Phase 156. Markup to ship:
  ```heex
  <div class="sg-notice" data-tone={@tone} {@rest}>
    <p class="sg-text-sm">{render_slot(@inner_block)}</p>
  </div>
  ```
  `attr :tone, :atom, values: [:ok, :warn, :risk, :info, nil], default: nil`; `attr :rest, :global`; `slot :inner_block, required: true`.
- **D-08:** **No live-region ARIA role by default** (`role`/`aria-live` omitted). The design contract's prescribed `role="alert"` / `role="status" aria-live="polite"` is **incorrect for content present at initial page load**: `role="alert"` is inert on load-present content (WAI-ARIA APG), `role="status"` is for post-load dynamic updates (MDN) and risks duplicate announcements on LiveView re-render. Phoenix's `flash/1` uses `role="alert"` only because it is injected dynamically with focus-management JS — not Sigra's render model. A live-region role is opt-in per-call-site via `:rest` only where a notice genuinely updates post-load (future Phase 157 / LAND-01 concern).
- **D-09:** Amend `guides/reference/admin-design-contract.md` (notice entry, ~lines 112-113) with a one-line ARIA correction: load-present notices carry **no** live-region role; tone is conveyed visually via `data-tone` and textually via copy; a live-region role is added per-call-site (via `:rest`) only for post-load dynamic notices. Update the markup cell target to `<div class="sg-notice" data-tone={tone}><p class="sg-text-sm">…</p></div>`. This is a correction-of-fact the contract's own preamble anticipates, in scope because the component implements that spec.

### Proof harness & gate (COMP-02) — empirically verified against `phoenix_live_view 1.1.31`
- **D-10:** Tests live in `test/sigra/admin/components_test.exs` — `use ExUnit.Case, async: true`, `@endpoint nil`, `import Phoenix.LiveViewTest`. Function-component `render_component/2` needs **no** ConnCase / endpoint / Postgres. Output is byte-stable, source-ordered, and preserves HEEx source whitespace — so byte-equality via `==` is the documented, idiomatic, verified assertion.
- **D-11:** **7 strict byte-equal extractions** (`stat_link`, `task_card`, `summary_chip`, `applied_chip`, `empty_state`, `page_back`, `scope_ribbon`): assert `render_component(&Components.name/1, <fixed literal assigns>) == @name_golden`. Bootstrap each golden by capturing the **original** `defp`/inline markup output once during authoring, paste the captured bytes, then repoint at the new component — guarantees the golden is the original's output (characterization fidelity), not a self-tautology. Use fixed literal assigns only (no live query results / volatile values).
- **D-12:** **3 contract-specified components**: `notice` ships `sg-notice` (deliberately ≠ current `sg-list-row`), so its proof is a **full golden against the target `sg-notice` markup** (not the current call site). `stat` and `skeleton` have no live analog, so use **structural `=~` / `refute` assertions** pinning only contract-load-bearing facts (required classes present; `stat` has no `<a>` and no `.sg-stat`; `skeleton` has `sg-skeleton`) — avoid over-fitting to incidental formatting.
- **D-13:** **Literal `==` strings, NO snapshot library.** Explicitly reject `mneme` `auto_assert` for the committed gate — its "bless the new value" affordance inverts the keystone "re-record is a bug" rule (the classic Jest-snapshot footgun). Each assertion carries a drift message naming the component and citing `admin-design-contract.md` + "do not re-record Playwright baselines."
- **D-14:** **Gate wiring:** the component-equality test runs under `mix test` in the existing `library_tests` lane. The admin-checkpoint Playwright job declares `needs: [library_tests]` (hard CI job dependency) so it physically cannot start until byte-equality passes — stronger and less bypassable than in-script step ordering.

### Claude's Discretion
- Exact `@doc`/`## Examples` prose and attr `doc:` wording per component (within the contract's job statements).
- Internal private helpers shared between sibling components (`stat`/`stat_link`, the chips) — allowed, as long as no shared *public* name (contract forbids merging the jobs).
- Exact fixed literal assign values used to drive each golden test.
- Module file layout (single `components.ex` vs a `components/` dir) — single file preferred unless size warrants splitting.

### Folded Todos
None folded.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- **Authoritative markup spec:** `guides/reference/admin-design-contract.md` — per-component winning markup, CSS classes, ARIA, motion, "when NOT to use" (rows ~11-127); notice entry ~107-115 (ARIA cell amended per D-09); page archetypes (Overview/List/Detail).
- **Extraction sources (lib-owned LiveViews):** `lib/sigra/admin/live/index_live.ex:118-144` (`metric_link`→`stat_link`, `task_card`), `organization_live.ex:165-195` (verbatim-duplicated `metric_link`/`task_card`; `:70-81` two-row `sg-list` where only the toned row migrates to notice), `users_index_live.ex:78-84` + `:167-180` (`applied_chip`) + `:285` (`empty_state`) + `:336-343` (`summary_chip`), `user_show_live.ex:90-95` (`page_back` + `scope_ribbon`) + `:131-133` (current notice = `sg-list-row data-tone`), `audit_user_live.ex:62-67` + `:137-152`.
- **CSS (proves notice pixel-neutrality; boundary):** `test/example/priv/static/assets/css/app.css` — `.sg-list-row[data-tone]` (945-967), `.sg-notice` byte-clone (971-993), `.sg-empty-state` (1016-1025), `.sg-metric-link` (1202-1228), `.sg-skeleton` (1421-1443), `prefers-reduced-motion` universal rule (~1463-1473), `@layer` order (line 15).
- **Phoenix component idiom (reference, do not copy host-shell simplicity):** `test/example/lib/example_web/components/core_components.ex` (`flash/1` `role="alert"` is dynamic-inject case @48-77; `attr :rest, :global` + `attr :class` idiom). Host-owned shell seam: `priv/templates/sigra.install/admin/components/admin_shell.ex`.
- **Test precedent + verified `render_component`:** `test/sigra/admin/` (flat `*_test.exs` pattern — `authorizer_test.exs`, `users_query_test.exs`); `test/example/test/example_web/admin_shell_test.exs` (existing `render_component` usage). `Phoenix.LiveViewTest` moduledoc uses `==` with `render_component`.
- **Keystone baselines (must NOT re-record):** `test/example/priv/playwright/tests/admin-checkpoints.spec.ts` + `admin-checkpoints.spec.ts-snapshots/` (5 slugs ×3 projects: `global-user-index`, `user-detail`, `audit-explorer`, `org-scoped-admin`, `impersonation-banner`).
- **Parity lane (unaffected — no call-site change):** `scripts/ci/admin-acceptance-smoke.sh` + `test/example/priv/playwright/tests/admin-generated.spec.ts`.
- **Repo research mined:** `prompts/phoenix-live-view-best-practices-deep-research.md` (function-components default; lean into attr/slot — lines ~42-50,259), `prompts/phoenix-best-practices-deep-research.md` (~73-75,191), `prompts/elixir-opensource-libs-best-practices-deep-research.md` (`import` over `use` — ~232-234).
- **Planning sources:** `.planning/ROADMAP.md` (phase 155, COMP-01/02), `.planning/REQUIREMENTS.md` (COMP-* lines 13-16), `.planning/STATE.md` (keystone + CSS-boundary locks), `.planning/phases/154-design-contract-sg-notice/154-CONTEXT.md`.
- **External a11y authorities (notice ARIA):** WAI-ARIA APG alert pattern (https://www.w3.org/WAI/ARIA/apg/patterns/alert/); MDN status role (https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/status_role); GOV.UK notification banner (https://design-system.service.gov.uk/components/notification-banner/).
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- All 10 components already exist as private `defp ...~H` defs / inline markup in `lib/sigra/admin/live/*.ex`; `metric_link/1` and `task_card/1` are **byte-identical duplicates** across `index_live.ex` and `organization_live.ex` — direct proof consolidation is correct and low-risk.
- `.sg-notice` CSS is a byte-clone of `.sg-list-row`, pre-built in Phase 154 to make the class swap visually invisible — the linchpin enabling Option A′ with zero re-records.
- `render_component/2` runs endpoint-free for function components — no new test harness, no DB, no ConnCase needed.

### Established Patterns
- `core_components.ex` is the Phoenix 1.8 idiom: `attr :rest, :global`, `attr :class, :any`, `@doc` + `## Examples`. Sigra's admin components follow it (the generated host shell deliberately stays simpler).
- All component styles live inside `@layer sg-components`; the only `!important` is the `prefers-reduced-motion` exception. No new CSS this phase.
- `stat`/`scope_ribbon`/`page_back` are markup patterns over existing utility classes, not dedicated CSS classes — components must reuse, not invent.

### Integration Points
- The module is consumed only in Phase 156 (`import` + delete private defs); in 155 it is built and tested but unwired, so the `admin-generated` parity lane and all Playwright baselines are unaffected.
- The proof gate plugs into the existing `library_tests` CI lane; the admin-checkpoint Playwright job gains a `needs: [library_tests]` dependency.
- The notice ARIA correction plugs into the existing `guides/reference/admin-design-contract.md` (one-line amendment).
</code_context>

<specifics>
## Specific Ideas

- `<.notice>` ships `sg-notice` + minimal (no) ARIA so it is correct once, Phase 156 adoption is a pixel-zero swap, and there is no transitional config cruft (the opt-in-attr "Option C" was rejected as a dead-config smell — no external consumers exist; every call site flips in the same milestone).
- Goldens must be bootstrapped from the *original* markup (capture-then-delete the private defs), never written from the new component, to avoid a tautological "new code tests new code" gate.
- Implementation note for the planner: verify whether current call sites pass `tone` as a string (`"risk"`) or atom before locking goldens, so the rendered `data-tone` bytes match.
</specifics>

<deferred>
## Deferred Ideas

- Migrating LiveView call sites to `import Sigra.Admin.Components` and deleting duplicate private defs → Phase 156 (COHR-01..06).
- A `role="note"` / labelled-region landmark for standalone notices, and live-region ARIA for genuinely-dynamic notices → Phase 157 / LAND-01 (opt-in via `:rest`).
- Phoenix Storybook / per-component previews → optional, future, not this milestone.

### Reviewed Todos (not folded)
- `.planning/todos/pending/2026-06-03-sg-notice-tone-rule-duplication.md` (sg-notice / sg-list-row tone-rule duplication drift guard) — NOT folded. It is a CSS-drift concern; the CSS boundary is locked for Phase 155 and the todo's own text says it is non-blocking. Revisit when the CSS boundary reopens.
</deferred>
