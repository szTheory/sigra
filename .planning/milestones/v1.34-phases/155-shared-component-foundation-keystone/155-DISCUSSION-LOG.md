# Phase 155: Shared Component Foundation (KEYSTONE) - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-06-03
**Phase:** 155-shared-component-foundation-keystone
**Mode:** assumptions + user-requested deep research (3 parallel subagents)
**Areas analyzed:** Module architecture & DX; the `notice` markup/ARIA fork; behavior-preserving proof harness

## Assumptions Presented (gsd-assumptions-analyzer)

### Area 1 — Module skeleton & ownership
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `lib/sigra/admin/components.ex` = `use Phoenix.Component`, purely lib-owned, no generated counterpart; consumed via `import` in 156 | Confident | no `use Phoenix.Component` in lib today; admin LiveViews lib-owned in `lib/sigra/admin/live/`; `admin_shell.ex` is the host seam |

### Area 2 — 9-of-10 verbatim extractions
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| 7 components reproduce current markup byte-for-byte; `stat`/`skeleton` asserted against contract (no live analog); no `.sg-stat` invented | Confident | design-contract source lines; "Do NOT invent `.sg-stat`" (contract:28,31) |

### Area 3 — Proof harness & todo scope
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `render_component` markup-equality at `test/sigra/admin/components_test.exs`, run before Playwright; sg-notice drift-guard todo out of scope | Confident | `test/sigra/admin/` precedent; todo text "non-blocking", CSS-only |

### Flagged tension (the one genuine fork)
The `notice` component: contract (`admin-design-contract.md:112`) says ship `sg-notice` + ARIA in Phase 155, but current call sites render `sg-list-row data-tone` with no ARIA — strict byte-equality and "ship ARIA now" cannot both hold.

## Deep Research (user-requested; 3 parallel general-purpose subagents)

User directive: research pros/cons/tradeoffs, idiomatic Elixir/Phoenix/ecosystem norms, cross-language lessons, DX/least-surprise; mine `prompts/`; one-shot a coherent recommendation set ("you pick, I follow").

**Agent A — Component-lib architecture & DX:** Verdict — 10 flat `use Phoenix.Component` functions, `attr :class` + `attr :rest, :global` on all, contract-exact classes, `@doc`+`## Examples`. Lib-owned is correct and not a "own your code" violation (admin chrome = commodity; override via `sg-*` tokens + `admin_shell.ex`; mirrors Backpex/LiveDashboard/Oban Web). Consume via `import` in 156.

**Agent B — `notice` fork:** Two reframing findings — (1) `.sg-notice` is a byte-clone of `.sg-list-row` (`app.css:971-993` vs `945-967`), so the class swap is **pixel-neutral** and ARIA is non-visual ⇒ no re-records under any option; (2) the contract's prescribed ARIA (`role="alert"`/`role="status" aria-live="polite"`) is the **textbook load-present anti-pattern** (WAI-ARIA APG: alert inert on load; MDN: status is for post-load; GOV.UK uses alert only with focus-JS; Phoenix flash uses alert only because injected). Verdict — **Option A′**: ship `sg-notice` final form with **no** live-region ARIA by default; opt-in via `:rest` for future dynamic notices; amend the contract's wrong ARIA cell. Rejected Option C (opt-in bridging attr) as a transitional-config smell.

**Agent C — Proof harness (empirically verified vs `phoenix_live_view 1.1.31`):** `render_component` is endpoint-free for function components, byte-stable, source-ordered, whitespace-preserving ⇒ `==` byte-equality is the documented idiom. Verdict — `test/sigra/admin/components_test.exs` (`use ExUnit.Case`, `@endpoint nil`); 7 strict goldens bootstrapped from originals then defs deleted; `notice` golden vs `sg-notice` target; `stat`/`skeleton` structural asserts; literal strings, **NO** `mneme auto_assert` (inverts the keystone rule — Jest-snapshot footgun); CI gate via Playwright job `needs: [library_tests]`.

## Decision

User confirmed: **lock the full synthesized recommendation set**, including Option A′ for `notice` and the one-line design-contract ARIA amendment. Mapped to D-01..D-14 in CONTEXT.md.

## Corrections Made

The synthesized research **refined** the analyzer's Area 2 assumption for `notice`: instead of strict byte-equal reproduction of `sg-list-row`, `notice` ships the final `sg-notice` class with corrected (no) ARIA — justified by the byte-clone CSS (pixel-neutral) and the load-present ARIA anti-pattern. All other analyzer assumptions confirmed as-is.

## External Research
- WAI-ARIA APG alert pattern — alert role is inert for content present before page load. (https://www.w3.org/WAI/ARIA/apg/patterns/alert/)
- MDN status role — for post-load dynamic updates, not static load-present content. (https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/status_role)
- GOV.UK notification banner — alert role used only with focus-management JS. (https://design-system.service.gov.uk/components/notification-banner/)
- Phoenix.LiveViewTest / Phoenix.Component docs — `render_component` `==` idiom; class-list flattening; boolean-attr collapsing. (https://hexdocs.pm/phoenix_live_view/)
- Backpex / SaladUI / Petal / LiveAdmin — lib-owned admin UI precedent + theme-override seam.
