# Phase 155: Shared Component Foundation (KEYSTONE) - Research

**Researched:** 2026-06-04
**Domain:** Phoenix function-component extraction + behavior-preservation proof harness (`render_component/2` byte-equality gating Playwright)
**Confidence:** HIGH (every claim below verified against repo source at cited file:line)

## Summary

CONTEXT.md (D-01..D-14) is already empirically grounded and correct. This research is **pure verification** of the open implementation questions the CONTEXT flagged for the planner, plus confirmation of the test-harness and CI-gate facts. No alternative architecture is proposed; the decisions are locked.

The three load-bearing open questions are all resolved in CONTEXT's favor:

1. **Tone is a STRING, not an atom, at every relevant call site.** `summary_alert/1` (the notice's data source) returns `{"risk", msg}` / `{"warn", msg}` tuples; `organization_live.ex` toned rows emit `"risk"`/`nil`. So a rendered `data-tone="risk"` is the existing truth, and the `.sg-notice[data-tone="risk"]` CSS selector (string-keyed) matches. The notice `attr :tone, :atom, values: [...]` from D-07 would render `:risk` as `risk` in HEEx (atoms stringify in attribute position) — but the **golden must be written from the string the original emits**, and the planner should drive the notice golden test with the value the original produces.
2. **`.sg-notice` is a verified byte-for-byte property clone of `.sg-list-row`** (`app.css:971-993` vs `945-967`). Option A′ is pixel-neutral by construction.
3. **`skeleton` and `stat` genuinely have no live analog**, and `.sg-stat` does not exist anywhere — D-12's structural-assertion approach and D-03's "do not invent `.sg-stat`" are both correct.

Two facts the planner must act on that are NOT yet reflected in committed sources:
- The committed `admin-design-contract.md` notice entry still **mandates `role="alert"`/`role="status"` "applied in Phase 155 HEEx markup"** — this directly contradicts locked D-08. The D-09 amendment is a substantive correction, not cosmetic; without it, the contract and the shipped component disagree.
- `render_component/2` is **not yet used anywhere in `test/sigra/`** (only in `test/example/.../admin_shell_test.exs`, which uses ConnCase). The new `components_test.exs` will be the first lib-side `render_component` test — but `test/sigra/admin/authorizer_test.exs` proves `use ExUnit.Case, async: true` runs with no DB in this exact directory, so the harness claim holds.

**Primary recommendation:** Execute D-01..D-14 as written. Bootstrap the 7 strict goldens from the captured original `defp`/inline bytes documented below; write the `notice` golden from the string-tone the original emits; wire the CI gate by changing exactly one line (`ci.yml:697`).

## User Constraints (from CONTEXT.md)

### Locked Decisions
All 14 decisions D-01..D-14 are locked verbatim in `155-CONTEXT.md` and `155-UI-SPEC.md`. Summary of the load-bearing ones this research verifies:
- **D-01:** `Sigra.Admin.Components` `use Phoenix.Component`; 10 flat stateless public function components in contract order. NOT LiveComponent, NOT a `use` macro.
- **D-02:** explicit `attr`s (`required:`/`default:`/`doc:`, `values:` for enums) + `attr :class, :any, default: nil` merged `class={["sg-…", @class]}` + `attr :rest, :global` on outer element; `slot :inner_block` only for `notice` and `empty_state`.
- **D-03:** emit exact `sg-*` class strings from the design contract; reuse utilities for `stat`/`scope_ribbon`/`page_back`; **never invent `.sg-stat`** or any new class.
- **D-07/D-08/D-09:** notice ships `sg-notice` + `data-tone`, NO live-region role by default; amend contract notice ARIA cell.
- **D-10..D-14:** proof harness (`render_component/2`, `@endpoint nil`, no DB), 7 strict byte goldens bootstrapped from originals, full `notice` target golden, structural asserts for `stat`/`skeleton`, literal `==` (no `mneme`), CI `needs: [library_tests]` gate.

### Claude's Discretion
- Exact `@doc`/`## Examples` prose, attr `doc:` wording, fixed literal golden assign values, internal private helpers shared between siblings, single-file vs `components/` dir (single preferred).

### Deferred Ideas (OUT OF SCOPE)
- Migrating LiveView call sites to `import Sigra.Admin.Components` + deleting private defs → Phase 156 (COHR-01..06).
- `role="note"`/landmark + live-region ARIA for dynamic notices → Phase 157 / LAND-01 (opt-in via `:rest`).
- Phoenix Storybook / per-component previews → future.
- `sg-notice`/`sg-list-row` tone-rule duplication drift guard → revisit when CSS boundary reopens (todo NOT folded; non-blocking).

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| COMP-01 | `Sigra.Admin.Components` exists with all 10 canonical components, documented `attr`/`slot` contracts | All 10 current implementations located and confirmed at the cited line ranges (table in "Runtime State / Extraction Inventory" below). 8 exist as `defp`/inline markup ready for byte capture; `summary_chip` is already a `defp` AND already called as `<.summary_chip>`; `applied_chip`/`empty_state` are inline (not yet defs). `stat`/`skeleton` have no live analog (build fresh per contract). |
| COMP-02 | Behavior-preserving: 5×3 Playwright baselines green, zero re-records, proven by `render_component` equality before Playwright | Harness verified runnable with no DB/endpoint (`authorizer_test.exs` precedent + `phoenix_live_view 1.1.31` in `mix.lock`). CI gate is a one-line edit at `ci.yml:697`. `.sg-notice`==`.sg-list-row` clone verified → notice swap is pixel-neutral. Tone is a string at all call sites → `data-tone` bytes are stable. |

## Project Constraints (from CLAUDE.md)

- **No new Hex deps.** `render_component/2` ships in `phoenix_live_view` (already a dep). No `mneme`, no snapshot lib (D-13). Verified.
- **No Tailwind, no Alpine, no `assign_async`.** Components are static leaf renderers emitting `sg-*` classes; none use any of these.
- **CSS boundary locked inside `@layer sg-components`; no new CSS this phase.** Verified: `.sg-notice` already exists (Phase 154); no component below requires a new class.
- **OWASP / security:** N/A — admin chrome is commodity presentation, zero security surface (D-05 rationale).
- **Testing:** AAA, flat, self-contained — matches `test/sigra/admin/authorizer_test.exs` style and D-10's `components_test.exs` plan.
- **GSD workflow enforcement:** all edits go through the GSD execute-phase flow.

## Standard Stack

No new packages. The phase uses only what is already locked in `mix.lock`:

| Library | Version (verified in mix.lock) | Purpose | Notes |
|---------|-------------------------------|---------|-------|
| phoenix_live_view | **1.1.31** | `Phoenix.Component`, `Phoenix.LiveViewTest.render_component/2` | D-10 empirical verification target — matches exactly. `render_component` for function components needs no endpoint/conn. |
| ex_unit | (stdlib) | `use ExUnit.Case, async: true` | `authorizer_test.exs:2` proves this runs DB-free in `test/sigra/admin/`. |

**No `## Package Legitimacy Audit` needed** — this phase installs nothing.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| 10 admin function components | Library (`lib/sigra/admin/components.ex`) | — | D-05: lib-owned commodity presentation; fixes propagate via `mix deps.update`. |
| Byte-equality proof | Library test (`test/sigra/admin/components_test.exs`, `library_tests` CI lane) | — | D-10/D-14: endpoint-free `render_component`; runs in the no-DB library lane. |
| Playwright baseline guard | Example app E2E (`example_playwright_smoke` job) | gated by `library_tests` | D-14: `needs:` makes Playwright physically wait on byte-equality. |
| Notice ARIA spec | Doc (`guides/reference/admin-design-contract.md`) | — | D-09: one-line correction-of-fact amendment. |

## Runtime State / Extraction Inventory

> This is a refactor/extraction phase. Below is the verified current state of every component the goldens must be bootstrapped from. **No external runtime state** (no DB, no OS registration, no env vars, no build artifacts) is touched — verified: components are pure markup, the proof test is endpoint-free, and Phase 155 wires no call site.

| Component | Current form & exact location | Tone/value type | Capture-then-delete note (D-11) |
|-----------|-------------------------------|-----------------|----------------------------------|
| `stat_link` | `defp metric_link/1`, `index_live.ex:114-125` AND **byte-identical** `organization_live.ex:165-176` | n/a (`value` is `:integer`, `href`/`label` strings) | Both copies identical char-for-char — capture once, delete both in Phase 156. Renamed `metric_link`→`stat_link`. |
| `stat` | **No live analog.** `.sg-stat` does not exist anywhere (verified grep). Only `metric_link` (`<a>`) exists. | n/a | Build fresh per contract (read-only KPI, reuse `sg-metric*`, no `<a>`, no `.sg-stat`). Structural `=~`/`refute` only (D-12). |
| `task_card` | `defp task_card/1`, `index_live.ex:127-144` AND **byte-identical** `organization_live.ex:178-195` | strings | Identical duplicates. Capture once. |
| `summary_chip` | `defp summary_chip/1`, `users_index_live.ex:333-343` — **already invoked as `<.summary_chip>`** at `:78-83` | `value` `:integer` | Already a private component; capture its `render_component` output for the golden. |
| `applied_chip` | **Inline markup** (no defp), `users_index_live.ex:167-178` AND `audit_user_live.ex:137-152`. Chip `<span>` markup byte-identical; only the remove `href` builder differs (`remove_chip_path/3` vs `/5`). | strings | Component takes `label` + remove `href` as attrs; the differing path is a call-site concern (Phase 156). Capture from the inline `<span class="sg-applied-chip">…</span>` block. |
| `empty_state` | **Inline markup** (no defp), `users_index_live.ex:285-302` — has a conditional body (`if any_filter_active?`) | n/a | Body is variable → `slot :inner_block` (D-02). Golden must use a fixed `inner_block` literal; capture the outer `sg-empty-state sg-stack sg-stack--3` + `sg-empty-state__title` wrapper bytes. |
| `page_back` | Inline `<a class="sg-btn sg-btn--ghost sg-btn--sm" href={@return_to}>` — `user_show_live.ex:91-93` ("Back to users") AND `audit_user_live.ex:63-65` ("Back to user") | n/a | Markup identical except label text → label is caller-supplied; the `&larr;` `aria-hidden` glyph is fixed. Capture wrapper bytes with a fixed literal label. |
| `scope_ribbon` | Inline `<span class="sg-muted sg-text-sm">{scope_copy(@admin_scope)}</span>` — `user_show_live.ex:94`, `audit_user_live.ex:66`, `users_index_live.ex:75` (as `<p class="sg-page-copy">`) | n/a | The `<span class="sg-muted sg-text-sm">…</span>` form is the ribbon (NOT the `sg-page-copy` paragraph). `scope_copy/1` returns differ per file ("Global user operations" vs "Global audit explorer") — that's caller copy, supplied as an attr; golden uses a fixed literal. |
| `notice` | `<div class="sg-list-row" data-tone={...}>` — `user_show_live.ex:131-133` (source: `summary_alert/1` → **string** tone) AND `organization_live.ex:70-81` (toned `sg-list-row` at `:71`, `data-tone={if(... "risk", else: nil)}`) | **STRING** (`"risk"`, `"warn"`, or `nil`) | **DELIBERATE FORK (D-07):** golden is the **target** `sg-notice` markup, NOT current `sg-list-row`. The `.sg-notice` clone makes this pixel-neutral. |
| `skeleton` | **No live analog.** `sg-skeleton` exists only in `app.css` (verified); never rendered in any admin LiveView. | n/a | Build fresh; structural `=~` assert (`sg-skeleton` present) only (D-12). |

## Open Implementation Questions — RESOLVED

### Q1 — Is `tone` passed as string `"risk"` or atom `:risk`? → STRING. (HIGH confidence)

`user_show_live.ex:488-504`:
```elixir
defp summary_alert(detail) do
  cond do
    identity.locked?           -> {"risk", "Locked — revoke active logins and unlock below."}
    not identity.confirmed?    -> {"warn", "Email unconfirmed — the user cannot complete sign-in."}
    not mfa_enabled?(...)      -> {"warn", "No MFA configured — recommend enabling a second factor."}
    true                       -> nil
  end
end
```
The notice's `data-tone` at `user_show_live.ex:131` is `{elem(summary_alert(@detail), 0)}` → a **string**. Likewise `organization_live.ex:71` emits `data-tone={if(... "risk", else: nil)}` (string or `nil`), and `status_pills/1` (`:420-429`) uses string tones (`"ok"`, `"warn"`, `"risk"`).

**Planner implication:** the rendered attribute is `data-tone="risk"` (or `data-tone="warn"`, or absent for `nil`). The `.sg-notice[data-tone="risk"]` CSS selector (`app.css:986`) is string-keyed and matches exactly. D-07 declares `attr :tone, :atom`. In HEEx attribute position an atom `:risk` renders as `risk`, so an atom-typed attr still produces byte-identical output **as long as the golden test is written from the bytes the original `sg-list-row` produced with its string tone** (which is `data-tone="risk"`). Drive the notice golden with the value that reproduces the original's exact bytes; do not assume the original passed an atom — it did not.

### Q2 — Exact current bytes for each of the 10 components? → Documented in the inventory table above. (HIGH confidence)

All 8 with a live analog are located at exact line ranges (verified by reading each). `metric_link` and `task_card` are byte-identical across `index_live.ex` and `organization_live.ex` (compared char-for-char — same attr order `label/value/href`, same markup, same whitespace). `applied_chip` and `empty_state` are **inline** (not yet `defp`s) — the capture target is the inline markup block, not a function. `stat` and `skeleton` have **no** analog and are built fresh.

### Q3 — Is `.sg-notice` a byte-clone of `.sg-list-row`? → YES. (HIGH confidence)

`app.css:945-967` (`.sg-list-row` + 4 `[data-tone]` rules) vs `app.css:971-993` (`.sg-notice` + 4 `[data-tone]` rules): identical property sets (`border-radius`, `background`, `box-shadow`, `padding`, `transition` on base; identical `color-mix` + inset-shadow values per tone). The only differences are the selector name and the comment header. The class swap is pixel-neutral by construction — Phase 154's stated intent (comment at `app.css:969-970`).

## CONTEXT Fact-Check: One Genuine Conflict, Rest Confirmed

### CONFLICT — committed design contract contradicts locked D-08 (planner MUST resolve via D-09)

`guides/reference/admin-design-contract.md` notice entry (lines ~107-115, read verbatim) currently states:

> **ARIA role(s):** `risk` tone: `role="alert"` (implicit assertive live region). `warn`/`ok`/`info` tones: `role="status" aria-live="polite"`. No-tone: `role="region"`. ARIA attributes **are applied in Phase 155 HEEx markup**, not via CSS.

This is the spec D-08/D-09 explicitly overrule. The contract is the authoritative markup source the goldens cite in their drift messages, so **shipping the component without amending the contract leaves the canonical spec instructing the exact behavior the component deliberately omits.** D-09's amendment (load-present notices carry NO live-region role; live-region opt-in via `:rest` for post-load dynamic only; markup-cell target → `<div class="sg-notice" data-tone={tone}>…`) is therefore a required, in-scope edit — not optional polish. The contract preamble anticipates correction-of-fact amendments.

### Confirmed facts
- `.sg-stat` does not exist (D-03 "do not invent" verified by grep returning nothing).
- `skeleton` has no live analog (`sg-skeleton` only in `app.css`).
- `summary_chip` already exists as a `defp` AND is already called via `<.summary_chip>` — slightly ahead of the others; the inventory notes this.
- `phoenix_live_view 1.1.31` matches D-10's empirical-verification version exactly.

## Validation Architecture

> nyquist_validation is enabled (no `false` in config). This is the REQUIRED Dimension-8 section; the proof harness is already designed in D-10..D-14 and formalized here.

### What is sampled, at what fidelity
The rendered HEEx markup of **each** of the 10 components is the sampled signal. Three fidelity tiers (D-11/D-12):

| Tier | Components | Assertion | Source of truth |
|------|-----------|-----------|-----------------|
| Strict byte-equal (7) | `stat_link`, `task_card`, `summary_chip`, `applied_chip`, `empty_state`, `page_back`, `scope_ribbon` | `render_component(&Components.name/1, <fixed literal assigns>) == @name_golden` | Golden = bytes captured from the **original** `defp`/inline markup (characterization fidelity, not self-tautology) |
| Full target golden (1) | `notice` | `== @notice_golden` where golden is the **target** `sg-notice` markup (deliberately ≠ current `sg-list-row`) | Hand-written `sg-notice` target; pixel-neutral via the verified CSS clone |
| Structural (2) | `stat`, `skeleton` | `=~` / `refute` on contract-load-bearing facts: required classes present; `stat` has no `<a>` and no `.sg-stat`; `skeleton` has `sg-skeleton` | Design contract (no live analog to byte-match) |

### Test harness
| Property | Value |
|----------|-------|
| Framework | ExUnit (`use ExUnit.Case, async: true`) — phoenix_live_view 1.1.31 |
| File | `test/sigra/admin/components_test.exs` |
| Config | `@endpoint nil`, `import Phoenix.LiveViewTest`; **no** ConnCase, **no** endpoint, **no** Postgres |
| Precedent | `test/sigra/admin/authorizer_test.exs:2` (`use ExUnit.Case, async: true`, DB-free in this exact dir); `render_component` usage precedent: `test/example/.../admin_shell_test.exs:80,110` (note: that file uses ConnCase only because `AdminShell` needs verified routes — the leaf components here do not, so plain `ExUnit.Case` suffices). This will be the first lib-side `render_component` test. |
| Snapshot lib | **None.** Literal `==` strings only; `mneme auto_assert` explicitly rejected (D-13) — its "bless the new value" affordance inverts the keystone "re-record is a bug" rule. |
| Drift message | Each assertion names the component + cites `admin-design-contract.md` + "do not re-record Playwright baselines" (D-13). |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| COMP-01 | 10 components exist with documented attr/slot contracts | unit (compile + `==`) | `mix test test/sigra/admin/components_test.exs` | ❌ Wave 0 |
| COMP-02 | each component is a byte/pixel-faithful drop-in | unit byte-equality | `mix test test/sigra/admin/components_test.exs` | ❌ Wave 0 |
| COMP-02 | Playwright 5×3 baselines green, zero re-records | E2E (gated) | `npx playwright test tests/admin-checkpoints.spec.ts --project=admin-checkpoints-{chromium,mobile,dark}` (`ci.yml:806-822`) | ✅ exists, gated by `needs:` |

### Sampling Rate
- **Per task commit:** `mix test test/sigra/admin/components_test.exs`
- **Per wave merge:** `mix test` (full `library_tests` lane)
- **Phase gate:** full suite green; admin-checkpoint Playwright green with zero re-records; `admin-generated` parity lane green; axe WCAG A/AA green.

### CI Gate Wiring (D-14) — verified, one-line edit
- Component-equality test runs under `mix test` in the existing **`library_tests`** job (`ci.yml:146-191`, runs plain `mix test` at `:191`). The new component test is itself DB-free, but the lane **does run a `postgres:15` service** (`ci.yml:150-160`) because the full `mix test` includes DB-dependent tests — the DB-free component test rides this lane harmlessly.
- The admin checkpoints run inside **`example_playwright_smoke`** (`ci.yml:694`, has its own Postgres service `:698-703`), at steps `:806-822` (5 specs × 3 projects: chromium/mobile/dark).
- **The gate edit:** `ci.yml:697` currently reads `needs: release_ref_guard`. Change to `needs: [release_ref_guard, library_tests]`. This makes Playwright physically unable to start until byte-equality passes — stronger and less bypassable than in-script step ordering (D-14).
- Baselines that must NOT re-record: `test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/` (slugs `global-user-index`, `user-detail`, `audit-explorer`, `org-scoped-admin`, `impersonation-banner`).
- Parity lane unaffected (no call-site change): `scripts/ci/admin-acceptance-smoke.sh` + `admin-generated.spec.ts`.

### Wave 0 Gaps
- [ ] `test/sigra/admin/components_test.exs` — covers COMP-01/COMP-02 (does not exist; first lib-side `render_component` test).
- [ ] `lib/sigra/admin/components.ex` — the module under test (does not exist).
- [ ] `ci.yml:697` `needs:` edit — wires the gate (one line).
- [ ] `guides/reference/admin-design-contract.md` notice ARIA cell — D-09 amendment (required; currently contradicts D-08).
- Framework install: none — ExUnit + phoenix_live_view already present.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Markup snapshot | A custom file-write/diff snapshot helper, or `mneme` | Literal `@golden = "…"` module attribute + `==` | D-13: any "bless/update" affordance reintroduces the Jest-snapshot footgun the keystone forbids. |
| Rendering a function component in a test | A LiveView, a ConnCase, a router | `Phoenix.LiveViewTest.render_component/2` | D-10: leaf function components need no endpoint/conn/DB; output is byte-stable and source-ordered. |
| New alert CSS | A new `.sg-notice`-variant class | The existing `.sg-notice` (Phase 154) | CSS boundary locked; clone already exists and is verified pixel-neutral. |
| Tone styling | An atom→class map or inline styles | `data-tone={@tone}` + existing `[data-tone]` CSS selectors | CSS already keys on string `data-tone`; rendering the string is the whole mechanism. |

## Common Pitfalls

### Pitfall 1: Writing the golden from the new component
**What goes wrong:** golden becomes a tautology ("new code tests new code"); a behavior change passes silently.
**How to avoid (D-11):** capture the **original** `defp`/inline markup's `render_component`/render output once during authoring, paste those bytes as the golden, then repoint the test at the new component. For inline-only components (`applied_chip`, `empty_state`), capture the inline markup block, not a function.

### Pitfall 2: Assuming the notice tone is an atom
**What goes wrong:** writing the notice golden as `data-tone="risk"` derived from passing `:risk` may or may not match; if the test passes a string but the golden was authored from a mistaken atom assumption, drift can hide.
**How to avoid:** the original emits a **string** (`summary_alert/1` returns `{"risk", …}`). Author the golden from the original's actual output (`data-tone="risk"`), and drive the test with whatever value reproduces those exact bytes.

### Pitfall 3: Shipping the component but not amending the contract
**What goes wrong:** `admin-design-contract.md` still mandates `role="alert"`/`role="status"` "in Phase 155 HEEx markup", contradicting the shipped no-role component; the drift message cites a contract that disagrees with the code.
**How to avoid:** the D-09 amendment is in-scope and required, not optional.

### Pitfall 4: Putting the component test in the DB lane or behind ConnCase
**What goes wrong:** needless coupling to Postgres/endpoint; `async` false; slower gate.
**How to avoid:** `use ExUnit.Case, async: true`, `@endpoint nil` — mirror `authorizer_test.exs`. The test is DB-free and lands in `library_tests` (the lane runs Postgres for other tests, but this test needs none), which is exactly where the gate `needs:` points.

### Pitfall 5: Forgetting `page_back`/`scope_ribbon`/notice differ only by caller copy across files
**What goes wrong:** treating "Back to users" vs "Back to user", or differing `scope_copy/1` returns, or `remove_chip_path/3` vs `/5`, as component differences.
**How to avoid:** these are caller-supplied attrs/copy (Phase 156). The component markup wrapper is identical; goldens use fixed literal assigns (Claude's discretion per D-11).

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| phoenix_live_view | `render_component/2`, `Phoenix.Component` | ✓ | 1.1.31 (mix.lock) | — |
| ExUnit | component test | ✓ | stdlib | — |
| Postgres | NOT required by the component test | — | — | n/a (gate test is DB-free) |
| Playwright | baseline guard (existing, unchanged) | ✓ | existing `example_playwright_smoke` job | — |

**No missing dependencies.** The proof test introduces zero new external dependency.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| — | (none) | — | All claims in this research are verified against repo source at cited file:line, or against `mix.lock`. No `[ASSUMED]` claims. |

## Sources

### Primary (HIGH confidence — read directly this session)
- `lib/sigra/admin/live/index_live.ex:114-156` — `metric_link`/`task_card` defs
- `lib/sigra/admin/live/organization_live.ex:60-81, 165-195` — toned `sg-list-row` rows; byte-identical `metric_link`/`task_card`
- `lib/sigra/admin/live/user_show_live.ex:85-133, 413-504` — page_back/scope_ribbon/notice markup; `summary_alert/1` (string tone), `status_pills/1`, `scope_copy/1`
- `lib/sigra/admin/live/users_index_live.ex:74-84, 160-180, 280-302, 333-343` — summary_chip def + call sites; applied_chip inline; empty_state inline
- `lib/sigra/admin/live/audit_user_live.ex:55-67, 130-152` — page_back ("Back to user"); applied_chip inline with `remove_chip_path/5`
- `test/example/priv/static/assets/css/app.css:945-993` — `.sg-list-row` vs `.sg-notice` byte-clone proof
- `test/sigra/admin/authorizer_test.exs:2` — `use ExUnit.Case, async: true` DB-free precedent
- `test/example/test/example_web/admin_shell_test.exs:80,110` — existing `render_component` usage (ConnCase, route-dependent)
- `guides/reference/admin-design-contract.md:107-115` — current notice ARIA spec (conflicts with D-08; D-09 amends)
- `.github/workflows/ci.yml:146-191 (library_tests), 694-822 (example_playwright_smoke + admin checkpoints)` — gate wiring; `:697` is the one-line `needs:` edit
- `mix.lock` — `phoenix_live_view 1.1.31` (matches D-10 verification)
- `.planning/phases/155-shared-component-foundation-keystone/155-CONTEXT.md`, `155-UI-SPEC.md`

### Secondary / Tertiary
- None needed; no WebSearch used (all questions answerable from repo source).

## Metadata

**Confidence breakdown:**
- Tone string-vs-atom resolution: HIGH — read `summary_alert/1` and all call sites directly.
- CSS clone (notice pixel-neutrality): HIGH — compared `app.css:945-967` vs `971-993` line by line.
- Test harness DB-free: HIGH — `authorizer_test.exs` precedent + version match.
- CI gate one-line edit: HIGH — read both jobs; `library_tests` is DB-free, `:697` is the `needs:` line.
- Contract conflict (D-09 required): HIGH — contract text read verbatim, directly contradicts D-08.

**Research date:** 2026-06-04
**Valid until:** 2026-07-04 (stable; repo-internal facts, no external fast-moving deps)
