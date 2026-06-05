---
phase: 155-shared-component-foundation-keystone
reviewed: 2026-06-04T00:00:00Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - lib/sigra/admin/components.ex
  - test/sigra/admin/components_test.exs
  - .github/workflows/ci.yml
  - guides/reference/admin-design-contract.md
findings:
  critical: 0
  warning: 2
  info: 3
  total: 5
status: issues_found
---

# Phase 155: Code Review Report

**Reviewed:** 2026-06-04
**Depth:** standard
**Files Reviewed:** 4
**Status:** issues_found

## Summary

Phase 155 builds `Sigra.Admin.Components`, a lib-owned set of 10 flat, stateless
`Phoenix.Component` function components, plus a byte-equality characterization test
and a one-line CI dependency change. The keystone is intentionally unwired (no call
site consumes it until Phase 156), which is by design and not flagged.

I traced every "byte-faithful" golden back to its cited original markup in the live
views (`index_live.ex:118-144`, `users_index_live.ex:167-180/285-302/336-343`,
`user_show_live.ex:90-94/131`). All seven strict goldens accurately reproduce the
original `defp`/inline markup, the `notice` divergence to `sg-notice` is deliberate
and correct (atom `:risk` renders as `data-tone="risk"`, matching the original string
tone from `summary_alert/1`), and the `.sr-only` and `sg-*` classes the components
emit are all defined in the canonical CSS layer (`default.css`, `app.css`). The CI
`needs:` change is sound (fail fast on cheap lib tests before the expensive Playwright
job). The design-contract ARIA amendment is well-reasoned and consistent with the
WAI-ARIA APG / MDN rationale.

The notable defect is that `notice/1` is the only one of the 10 components that omits
the documented `attr :class` merge — contradicting D-02, the plan, and the phase
SUMMARY's own claim that "each component has `attr :class`". Because `notice` carries
`attr :rest, :global` and hardcodes `class="sg-notice"`, a Phase 156 call site passing
`class=...` would route it through `{@rest}` and emit a **duplicate `class` attribute**.
This is a latent bug planted into the keystone that will surface when wired.

## Warnings

### WR-01: `notice/1` omits the `attr :class` merge that every other component declares, creating a duplicate-`class` hazard when wired

**File:** `lib/sigra/admin/components.ex:290-305`
**Issue:**
`notice/1` declares only `attr :tone`, `attr :rest, :global`, and `slot :inner_block`.
It hardcodes `class="sg-notice"` and does **not** declare `attr :class, :any, default: nil`
nor merge `@class` into the root element. Every other component (`stat_link`, `stat`,
`task_card`, `summary_chip`, `applied_chip`, `empty_state`, `page_back`, `scope_ribbon`,
`skeleton`) declares `attr :class` and merges it as `class={["sg-…", @class]}`.

This deviates from:
- **D-02** (`155-CONTEXT.md:21`): "Every component declares ... `attr :class, :any, default: nil` merged as `class={["sg-…", @class]}`".
- **The plan** (`155-01-PLAN.md:126`): notice should get "`attr :class, :any, default: nil` merged `class={["sg-…", @class]}`".
- **The phase SUMMARY** (`155-01-SUMMARY.md:63`): "Each component has `attr :class, :any, default: nil` merged as `class={["sg-…", @class]}`" — this claim is false for `notice`.

Beyond the inconsistency, there is a concrete latent bug. Because `notice` has
`attr :rest, :global` and no explicit `attr :class`, a Phase 156 call site that does
`<.notice tone={:risk} class="sg-mt-3">…</.notice>` would route `class` through
`{@rest}` while the template also hardcodes `class="sg-notice"`, producing a `<div>`
with **two `class` attributes**. The other nine components avoid this precisely because
their explicit `attr :class` captures the caller's `class` before it can reach `{@rest}`.
Since the module is unwired this turn, it does not break today — but it is a defect
seeded into the keystone that the consolidation phase will inherit.

**Fix:**
```elixir
attr :tone, :atom,
  values: [:ok, :warn, :risk, :info, nil],
  default: nil,
  doc: "the visual tone applied via data-tone; renders as a string in the HTML attribute"

attr :class, :any, default: nil, doc: "additional CSS classes merged onto the root element"
attr :rest, :global, doc: "arbitrary HTML attributes (e.g., a live-region role for opt-in post-load notices)"

slot :inner_block, required: true, doc: "the notice message content"

def notice(assigns) do
  ~H"""
  <div class={["sg-notice", @class]} data-tone={@tone} {@rest}>
    <p class="sg-text-sm">{render_slot(@inner_block)}</p>
  </div>
  """
end
```
Note: this changes the `notice` golden bytes from `class="sg-notice"` to
`class="sg-notice "` (trailing space from the list merge, matching every other
golden). Update `@notice_golden` in `test/sigra/admin/components_test.exs:61`
accordingly. If the no-`@class` form is in fact intentional for `notice`, that
decision must be recorded in the contract and the SUMMARY's blanket "each component"
claim corrected — but the duplicate-`class` hazard still argues for the merge.

### WR-02: `notice/1` accepts caller-supplied `class` only via `:global` rest, so HEEx cannot warn on it and the duplicate-attribute emission is silent

**File:** `lib/sigra/admin/components.ex:295,301`
**Issue:**
This is the compile-time-safety facet of WR-01 and is worth calling out separately.
With no `attr :class` declared, `class` falls under the `:global` catch-all. Phoenix's
attr verifier therefore cannot detect a redundant/duplicate `class` at compile time,
and HEEx will happily render two `class` attributes. Browsers keep only the first
(`sg-notice`) and discard the caller's classes, so a Phase 156 author who passes
`class=` to position or space a notice will see it silently dropped with no warning
from `mix compile --warnings-as-errors` (which CI enforces at `ci.yml:251,290,551`).
The failure mode is a confusing "my class did nothing" rather than a hard error.

**Fix:** Same as WR-01 — declare `attr :class, :any, default: nil` and merge it into
the class list so `class` is a first-class, verifier-visible attribute rather than an
untracked global.

## Info

### IN-01: `@endpoint nil` in the test module is dead/misleading scaffolding

**File:** `test/sigra/admin/components_test.exs:3`
**Issue:**
`@endpoint nil` is set but `render_component/2` (the only render path used) does not
require an endpoint — it renders a function component in isolation. The attribute is
inert noise that suggests a `Phoenix.ConnTest`/`live/2` flow that this module never
uses. A future reader may assume an endpoint is wired.
**Fix:** Remove the `@endpoint nil` line; `import Phoenix.LiveViewTest` alone is
sufficient for `render_component/2`.

### IN-02: `empty_state` golden is a synthetic body, not a byte-clone of the original conditional markup

**File:** `test/sigra/admin/components_test.exs:42-45,114-123`
**Issue:**
The header comment frames the seven goldens as reproducing "bytes that the original
markup would produce." For `empty_state` this is only true for the outer wrapper
(`sg-empty-state ...` + `sg-empty-state__title`). The original body
(`users_index_live.ex:287-301`) is a conditional `<p class="sg-muted sg-text-sm">…</p>`
block, whereas the golden injects a raw string `"Try adjusting your filters."` through
`render_slot/1` and relies on HTML-escaping of a plain string. The test does document
this in the NOTE at line 44, so this is a clarity nit, not a correctness bug: the
"byte-equal to original" framing is slightly overstated for this one component since
the body is authored fresh, not characterized.
**Fix:** Tighten the section comment to note that `empty_state`'s golden characterizes
the wrapper bytes plus a representative slot body, not the original conditional body
verbatim (the per-test NOTE already says as much — promote it to the header so the
"7 strict byte-equal goldens" summary is not read too literally).

### IN-03: `summary_chip` emits `<dt>`/`<dd>` inside a `<div>` (not a `<dl>`), which is invalid HTML — carried over verbatim from the original

**File:** `lib/sigra/admin/components.ex:138-145`
**Issue:**
`summary_chip/1` renders `<dt>`/`<dd>` as direct children of `<div class="sg-metric">`.
`<dt>` and `<dd>` are only valid inside a `<dl>` (or a `<div>` that is itself a child of
`<dl>`). This is a faithful reproduction of the original `defp summary_chip/1`
(`users_index_live.ex:336-343`), and the design contract's "Winning markup" cell wraps
it in `<dl class="sg-metric-grid">` at the call site — so in production the `<dl>`
ancestor exists. In isolation, however, the component produces invalid HTML, and the
contract entry for `summary_chip` shows the `<dl>` as the *grid* wrapper around N chips,
not per-chip. The phase author already corrected the *new* `stat/1` to use a proper
`<dl>` root (per SUMMARY line 18) but deliberately left `summary_chip` verbatim. This is
acceptable behavior-preservation for the keystone, but the semantics gap is worth a note
for the Phase 156 consolidation, where the `sg-metric-grid` `<dl>` wrapper must be
preserved at the call site for the markup to be valid.
**Fix:** No change required this phase (behavior preservation is the goal). When wiring
in Phase 156, ensure each `summary_chip` is rendered inside the `<dl class="sg-metric-grid">`
wrapper documented in the contract; consider folding the `<dl>` into the component (or a
dedicated grid component) so a `summary_chip` is never emitted with orphaned `<dt>`/`<dd>`.

---

_Reviewed: 2026-06-04_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
