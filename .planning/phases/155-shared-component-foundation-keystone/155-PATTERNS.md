# Phase 155: Shared Component Foundation (KEYSTONE) - Pattern Map

**Mapped:** 2026-06-04
**Files analyzed:** 4 (2 new, 2 edits)
**Analogs found:** 4 / 4

> This is an extraction/characterization phase. The load-bearing pattern work is not
> "find an analog for a new file" but "capture the VERBATIM current markup for each of
> 10 components" so the goldens (D-11) are bootstrapped from the original output, not
> the new component. Those verbatim excerpts are reproduced below per component.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/sigra/admin/components.ex` (NEW) | component (Phoenix.Component module) | request-response (static render) | `test/example/lib/example_web/components/core_components.ex` (idiom) + the `defp` defs in `lib/sigra/admin/live/*.ex` (markup) | role-match (idiom) + exact (markup source) |
| `test/sigra/admin/components_test.exs` (NEW) | test | transform (render→byte-equality) | `test/sigra/admin/authorizer_test.exs` (harness) + `test/example/test/example_web/admin_shell_test.exs` (`render_component` usage) | role-match |
| `.github/workflows/ci.yml` (EDIT ~line 697) | config (CI) | event-driven (job DAG) | self (`needs:` lines elsewhere in same file) | exact |
| `guides/reference/admin-design-contract.md` (EDIT ~lines 111-113) | doc | n/a | self (existing notice entry) | exact |

---

## Pattern Assignments

### `lib/sigra/admin/components.ex` (component module)

**Idiom analog:** `test/example/lib/example_web/components/core_components.ex`
**Markup source-of-truth:** the `defp`/inline markup in `lib/sigra/admin/live/*.ex` (verbatim per component below)

**Module preamble idiom** (from `core_components.ex:1-29`, simplify — drop Gettext/Tailwind prose):
```elixir
defmodule Sigra.Admin.Components do
  @moduledoc """
  ... lib-owned canonical admin component set; points to admin-design-contract.md ...
  """
  use Phoenix.Component
end
```
Note D-01: `use Phoenix.Component` (NOT LiveComponent, NOT a `use Sigra.Admin.Components` macro). 10 flat public function components in contract order.

**attr / doc idiom** (from `core_components.ex:32-48`, the `flash/1` head):
```elixir
@doc """
Renders flash notices.

## Examples

    <.flash kind={:info} flash={@flash} />
"""
attr :id, :string, doc: "the optional id of flash container"
attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"
slot :inner_block, doc: "the optional inner block that renders the flash message"
```
Per D-02/D-04: each component gets `@doc` (one-line job + `## Examples`), explicit `attr`s with `required:`/`default:`/`doc:` (`values:` for the `notice` tone enum), `attr :class, :any, default: nil` merged `class={["sg-…", @class]}`, and `attr :rest, :global` spread on the OUTER element. `slot :inner_block` only for `notice` and `empty_state`.

**`attr :rest, :global` + `attr :class` merge idiom** (from `core_components.ex:89-90` button head):
```elixir
attr :rest, :global, include: ~w(href navigate patch method download name value disabled)
attr :class, :any
```

> WARNING (canonical_refs note): do NOT copy `core_components.ex`'s `flash/1` `role="alert"` (line 56) — that is the dynamic-inject case D-08 explicitly overrules for `notice`. Copy the *attr/doc/rest idiom* only, not the ARIA.

---

#### VERBATIM current markup per component (golden bootstrap source — D-11)

These are the exact bytes each new function component must reproduce. For the 7 strict
goldens, capture the original's `render_component`/render output, paste as `@golden`,
then repoint the test at the new component (Pitfall 1). `defp` vs inline noted per
component.

**1. `stat_link`** — current `defp metric_link/1`, `index_live.ex:114-125` (byte-identical duplicate at `organization_live.ex:165-176`). Rename `metric_link`→`stat_link`. Existing attrs: `label`/`value`/`href`.
```heex
<a href={@href} class="sg-metric-link">
  <span class="sg-metric-link__label">{@label}</span>
  <span class="sg-metric-link__value">{@value}</span>
</a>
```

**2. `stat`** — NO live analog. `.sg-stat` does not exist (D-03: do not invent). Build fresh per contract: read-only KPI, reuse `sg-metric*` utilities, NO `<a>`, NO `.sg-stat`. Proof is structural `=~`/`refute` (D-12): required `sg-metric*` classes present; `refute html =~ "<a"`; `refute html =~ "sg-stat"`. Closest shape reference is the `summary_chip` `sg-metric` markup below.

**3. `task_card`** — current `defp task_card/1`, `index_live.ex:127-144` (byte-identical duplicate at `organization_live.ex:178-195`). Attrs: `title`/`body`/`href`/`action`.
```heex
<article class="sg-card sg-card-hover sg-stack sg-stack--3">
  <div class="sg-stack sg-stack--2">
    <h2 class="sg-section-heading">{@title}</h2>
    <p class="sg-section-copy">{@body}</p>
  </div>
  <div class="sg-cluster">
    <a href={@href} class="sg-btn sg-btn--primary">{@action}</a>
  </div>
</article>
```

**4. `summary_chip`** — ALREADY a `defp summary_chip/1` AND already invoked as `<.summary_chip>` (def at `users_index_live.ex:336-343`, calls at `:78-83`). Attrs: `label`/`value` (`value` is `:integer`). Capture its `render_component` output directly for the golden.
```heex
<div class="sg-metric">
  <dt>{@label}</dt>
  <dd>{@value}</dd>
</div>
```

**5. `applied_chip`** — INLINE markup (NOT a `defp`), `users_index_live.ex:167-178` AND `audit_user_live.ex:137-152`. Capture the inner `<span class="sg-applied-chip">…</span>` block (NOT the outer `:for`/`sg-cluster` wrapper — that is a call-site concern). The chip `<span>` is byte-identical across both files; only the remove `href` builder differs (`remove_chip_path/3` vs `/5`) — supply the remove `href` + `label` as attrs (Pitfall 5).
```heex
<span class="sg-applied-chip">
  <span>{chip.label}</span>
  <a
    class="sg-applied-chip__remove"
    href={remove_chip_path(@admin_scope, @current_params, chip.key)}
    aria-label={"Remove filter " <> chip.label}
  >
    <span aria-hidden="true">&times;</span>
    <span class="sr-only">remove</span>
  </a>
</span>
```
Component shape: `label` attr → first `<span>`; remove `href` attr → the `<a href=…>`; `aria-label` is `"Remove filter " <> label`.

**6. `empty_state`** — INLINE markup (NOT a `defp`), `users_index_live.ex:285-302`. Has a conditional body (`if any_filter_active?`) → body is variable → `slot :inner_block` (D-02). Golden uses a FIXED `inner_block` literal. Capture the outer `sg-empty-state sg-stack sg-stack--3` wrapper + `sg-empty-state__title`.
```heex
<div class="sg-empty-state sg-stack sg-stack--3">
  <p class="sg-empty-state__title">No users match this view</p>
  <%= if any_filter_active?(@current_params) do %>
    <p class="sg-muted sg-text-sm">
      No users match the active filters. Clear them to widen the result set.
    </p>
    <div class="sg-cluster sg-cluster--center">
      <a href={index_path(@admin_scope)} class="sg-btn sg-btn--secondary sg-btn--sm">
        Clear all filters
      </a>
    </div>
  <% else %>
    <p class="sg-muted sg-text-sm">
      Users appear here as people register and sign in. Once accounts exist, you can search,
      filter, and open any user.
    </p>
  <% end %>
</div>
```
Component form: outer `<div class={["sg-empty-state sg-stack sg-stack--3", @class]}>` + `<p class="sg-empty-state__title">{title}</p>` (title as attr or slot per UI-SPEC row) + `{render_slot(@inner_block)}` for the variable body. Drive the golden with a fixed literal title + fixed inner_block.

**7. `page_back`** — INLINE `<a>` (NOT a `defp`), `user_show_live.ex:91-93` ("Back to users") AND `audit_user_live.ex:63-65` ("Back to user"). Markup identical except the label text → label is caller-supplied; `&larr;` `aria-hidden` glyph is fixed. Attr: `return_to`. Golden uses a fixed literal label.
```heex
<a class="sg-btn sg-btn--ghost sg-btn--sm" href={@return_to}>
  <span aria-hidden="true">&larr;</span> Back to users
</a>
```
NOTE: "Back to users" vs "Back to user" is caller copy (Pitfall 5) — make the trailing label a caller-supplied value (attr or slot); the `<span aria-hidden="true">&larr;</span> ` prefix is fixed.

**8. `scope_ribbon`** — INLINE `<span>`, `user_show_live.ex:94`, `audit_user_live.ex:66` (also `users_index_live.ex:75` exists as a DIFFERENT `<p class="sg-page-copy">` — that is NOT the ribbon). The ribbon form is the `<span class="sg-muted sg-text-sm">` one. `scope_copy/1` return is caller copy → supply as attr/scope assign. NO dedicated class (D-03: reuse `sg-muted sg-text-sm`). Golden uses a fixed literal.
```heex
<span class="sg-muted sg-text-sm">{scope_copy(@admin_scope)}</span>
```

**9. `notice`** — DELIBERATE FORK (D-07/D-12). Current call sites use `sg-list-row` (`user_show_live.ex:131-133`, `organization_live.ex:71-76`), but the component ships the TARGET `sg-notice` markup. Golden is the target, NOT the current call site. Pixel-neutral because `.sg-notice` (`app.css:971-993`) is a verified byte-clone of `.sg-list-row` (`app.css:945-967`).

Current `user_show_live.ex:131-133` (source of the toned single row — what gets replaced):
```heex
<div :if={summary_alert(@detail)} class="sg-list-row" data-tone={elem(summary_alert(@detail), 0)}>
  <p class="sg-text-sm">{elem(summary_alert(@detail), 1)}</p>
</div>
```
TARGET markup to ship (D-07, full golden):
```heex
<div class="sg-notice" data-tone={@tone} {@rest}>
  <p class="sg-text-sm">{render_slot(@inner_block)}</p>
</div>
```
Attrs: `attr :tone, :atom, values: [:ok, :warn, :risk, :info, nil], default: nil`; `attr :rest, :global`; `slot :inner_block, required: true`. **NO `role`/`aria-live` by default** (D-08).

> CRITICAL (Q1 / Pitfall 2): the original emits tone as a STRING. `summary_alert/1`
> (`user_show_live.ex:488-504`) returns `{"risk", msg}` / `{"warn", msg}`; the rendered
> attribute is `data-tone="risk"`. In HEEx attribute position an atom `:risk` ALSO
> renders as `risk`, so the byte output matches — but write the golden from the bytes
> the original produces (`data-tone="risk"`) and drive the test with whatever value
> reproduces those exact bytes. Do NOT assume the original passed an atom — it did not.

**10. `skeleton`** — NO live analog. `sg-skeleton` exists only in `app.css:1421-1443`; never rendered in any admin LiveView. Build fresh per contract. Proof is structural `=~` (D-12): assert `html =~ "sg-skeleton"`. Root class `sg-skeleton`; shimmer motion is owned by CSS and stripped by `prefers-reduced-motion` (`app.css:1463-1473`) — no inline motion.

---

### `test/sigra/admin/components_test.exs` (test)

**Harness analog:** `test/sigra/admin/authorizer_test.exs` (DB-free precedent in the SAME dir)
**`render_component` usage analog:** `test/example/test/example_web/admin_shell_test.exs:79-84`

**Harness pattern** (from `authorizer_test.exs:1-2` — DB-free `use ExUnit.Case, async: true` in this exact dir):
```elixir
defmodule Sigra.Admin.ComponentsTest do
  use ExUnit.Case, async: true
  # @endpoint nil ; import Phoenix.LiveViewTest  (D-10)
end
```
Per D-10: `use ExUnit.Case, async: true`, `@endpoint nil`, `import Phoenix.LiveViewTest`. NO ConnCase, NO endpoint, NO Postgres. This will be the first lib-side `render_component` test. `authorizer_test.exs:2` proves plain `ExUnit.Case, async: true` runs DB-free in `test/sigra/admin/`.

**`render_component` invocation pattern** (from `admin_shell_test.exs:79-84` — note it uses ConnCase only because `AdminShell` needs verified routes; the leaf components here do NOT, so plain `ExUnit.Case` suffices):
```elixir
html =
  render_component(&AdminShell.admin_shell/1,
    admin_scope: %{mode: :global, platform_admin?: true},
    current_scope: %Scope{...},
    inner_block: [%{inner_block: fn _, _ -> "Body" end}]
  )

assert html =~ "..."
```
For the 7 strict goldens use `==` instead of `=~`:
```elixir
@stat_link_golden "...captured original bytes..."
assert render_component(&Components.stat_link/1, label: "...", value: 0, href: "...") ==
         @stat_link_golden,
       "stat_link drifted — see admin-design-contract.md; do not re-record Playwright baselines"
```
Per D-13: literal `==` strings, NO `mneme`/snapshot lib. Each assertion carries a drift message naming the component + citing `admin-design-contract.md` + "do not re-record Playwright baselines". For `notice` slot-bearing components, pass `inner_block: [%{inner_block: fn _, _ -> "..." end}]` as in the analog. For `empty_state`/`notice` golden assigns use FIXED literals only.

Assertion tiers (D-11/D-12):
- Strict `==` (7): `stat_link`, `task_card`, `summary_chip`, `applied_chip`, `empty_state`, `page_back`, `scope_ribbon` — golden = captured ORIGINAL bytes.
- Full target golden (1): `notice` — golden = TARGET `sg-notice` markup.
- Structural `=~`/`refute` (2): `stat` (required `sg-metric*` present; `refute "<a"`; `refute "sg-stat"`), `skeleton` (`=~ "sg-skeleton"`).

---

### `.github/workflows/ci.yml` (config edit, ~line 697)

**Analog:** self — the `needs:` syntax already in use across this file.

Current (`ci.yml:697`, inside the `example_playwright_smoke` job at `:694`):
```yaml
    needs: release_ref_guard
```
Target (D-14): add `library_tests` so Playwright physically cannot start until byte-equality passes:
```yaml
    needs: [release_ref_guard, library_tests]
```
The component-equality test runs under `mix test` in the existing `library_tests` lane (`ci.yml:146-191`, runs plain `mix test`). The component test is DB-free, though the lane runs a `postgres:15` service (`ci.yml:150-160`) for other DB-dependent tests — the DB-free test rides the lane harmlessly. The admin checkpoints run inside `example_playwright_smoke` (steps ~`:806-822`, 5 specs × 3 projects). This is a one-line edit (Wave 0 gap).

---

### `guides/reference/admin-design-contract.md` (doc edit, ~lines 111-113)

**Analog:** self — the existing notice entry rows.

The committed notice entry (`admin-design-contract.md:111-115`, read verbatim) currently
MANDATES `role="alert"`/`role="status"` "applied in Phase 155 HEEx markup" — which
directly CONTRADICTS locked D-08. The D-09 amendment is a required correction-of-fact,
not optional polish (Pitfall 3).

Current "Winning markup / CSS" cell (line 112) target → change to:
```
<div class="sg-notice" data-tone={tone}><p class="sg-text-sm">…</p></div>
```
Current "ARIA role(s)" cell (line 113) → replace with the one-line correction (D-09):
> Load-present notices carry **no** live-region role; tone is conveyed visually via `data-tone` and textually via copy. A live-region role is added per-call-site (via `:rest`) only for genuinely post-load dynamic notices.

Rationale to fold in (D-08): `role="alert"` is inert on load-present content (WAI-ARIA APG); `role="status"` is for post-load updates (MDN) and risks duplicate announcements on LiveView re-render; Phoenix `flash/1` uses `role="alert"` only because it is dynamically injected with focus-management JS — not Sigra's render model.

---

## Shared Patterns

### Component module idiom (Phoenix 1.8)
**Source:** `test/example/lib/example_web/components/core_components.ex:29` (`use Phoenix.Component`), `:40-48` (attr/doc), `:89-90` (`attr :rest, :global` + `attr :class`)
**Apply to:** every one of the 10 functions in `components.ex`
- `use Phoenix.Component` at module top (D-01; NOT `use ...LiveComponent`, NOT a `use` macro).
- Per function: `@doc` (one-line job + `## Examples`), explicit `attr`s, `attr :class, :any, default: nil` merged `class={["sg-…", @class]}`, `attr :rest, :global` on the outer element (D-02/D-04).
- COPY the idiom, NOT the ARIA (`flash/1`'s `role="alert"` is the dynamic-inject case D-08 overrules).

### DB-free render-equality test
**Source:** `test/sigra/admin/authorizer_test.exs:1-2` (harness) + `test/example/test/example_web/admin_shell_test.exs:79-84` (`render_component` call shape)
**Apply to:** `components_test.exs`
- `use ExUnit.Case, async: true`, `@endpoint nil`, `import Phoenix.LiveViewTest` — no ConnCase, no DB, no endpoint (leaf function components need none).
- Pass slot bodies as `inner_block: [%{inner_block: fn _, _ -> "..." end}]`.
- Literal `@golden` module attrs + `==` with a component-naming drift message; NO snapshot lib (D-13).

### Golden bootstrap discipline (characterization)
**Source:** D-11 + the verbatim markup excerpts above
**Apply to:** the 7 strict-equality components
- Capture the ORIGINAL `defp`/inline output once during authoring, paste as `@golden`, THEN repoint at the new component. Never author the golden from the new code (Pitfall 1).
- Tone renders as a STRING (`data-tone="risk"`) — author from the original's bytes (Pitfall 2).

### `sg-*` class / CSS boundary (no invention)
**Source:** `guides/reference/admin-design-contract.md`; CSS at `test/example/priv/static/assets/css/app.css`
**Apply to:** all 10 components
- Emit only EXISTING `sg-*` classes (D-03). No `.sg-stat`, no new class. `stat`/`scope_ribbon`/`page_back` reuse utilities (`sg-metric*`, `sg-muted sg-text-sm`, `sg-btn--ghost`). `notice` ships `sg-notice` (NOT `sg-list-row`).

---

## No Analog Found

Components built fresh per contract (no live markup to byte-match — use structural asserts per D-12):

| Component | Role | Data Flow | Reason |
|-----------|------|-----------|--------|
| `stat` | component | render | No live analog; `.sg-stat` does not exist (do-not-invent). Reuse `sg-metric*`, no `<a>`. Structural `=~`/`refute` proof. |
| `skeleton` | component | render | No live analog; `sg-skeleton` only in `app.css`, never rendered in any admin LiveView. Structural `=~ "sg-skeleton"` proof. |

(The other 8 components DO have analogs — verbatim markup captured above. `notice` has an analog at the call site but deliberately forks to the `sg-notice` target.)

---

## Metadata

**Analog search scope:** `lib/sigra/admin/live/` (markup source), `test/sigra/admin/` (test harness), `test/example/lib/example_web/components/` (Phoenix idiom), `test/example/test/example_web/` (render_component usage), `.github/workflows/ci.yml`, `guides/reference/admin-design-contract.md`, `test/example/priv/static/assets/css/app.css` (CSS boundary).
**Files scanned:** 9 source/spec files read at cited line ranges.
**Pattern extraction date:** 2026-06-04
