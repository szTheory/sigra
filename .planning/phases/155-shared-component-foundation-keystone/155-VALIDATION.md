---
phase: 155
slug: shared-component-foundation-keystone
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-04
---

# Phase 155 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> The signal sampled is **rendered HEEx markup** of each extracted component.
> Behavior-preservation (COMP-02) is enforced by `render_component/2` byte/structural
> equality that runs in CI **before** the Playwright baseline guard.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (`use ExUnit.Case, async: true`) — phoenix_live_view 1.1.31 (verified in `mix.lock`) |
| **Config file** | none — ExUnit + `Phoenix.LiveViewTest` already present; `@endpoint nil`, no ConnCase, no Postgres |
| **Quick run command** | `mix test test/sigra/admin/components_test.exs` |
| **Full suite command** | `mix test` (the `library_tests` CI lane; no Postgres service) |
| **Estimated runtime** | ~2–5 seconds (DB-free, async) |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/sigra/admin/components_test.exs`
- **After every plan wave:** Run `mix test` (full `library_tests` lane)
- **Before phase gate / `/gsd:verify-work`:** Full suite green; admin-checkpoint Playwright green with **zero re-records**; `admin-generated` parity lane green; axe WCAG A/AA green.
- **Max feedback latency:** ~5 seconds (component test is DB-free and async)

---

## Per-Task Verification Map

> Task IDs are provisional until plans are written; the test file and commands are fixed by D-10..D-14. Three fidelity tiers (D-11/D-12).

| Component | Req | Tier | Assertion | Source of truth | Test Type | Automated Command | File Exists | Status |
|-----------|-----|------|-----------|-----------------|-----------|-------------------|-------------|--------|
| `stat_link` | COMP-01/02 | strict byte-equal | `render_component(&Components.stat_link/1, <lit>) == @golden` | bytes captured from **original** `defp` | unit | `mix test test/sigra/admin/components_test.exs` | ❌ W0 | ⬜ pending |
| `task_card` | COMP-01/02 | strict byte-equal | `== @golden` | original `defp` (byte-identical across index/org) | unit | same | ❌ W0 | ⬜ pending |
| `summary_chip` | COMP-01/02 | strict byte-equal | `== @golden` | original `defp` (already a `defp` + called) | unit | same | ❌ W0 | ⬜ pending |
| `applied_chip` | COMP-01/02 | strict byte-equal | `== @golden` | original **inline** markup block | unit | same | ❌ W0 | ⬜ pending |
| `empty_state` | COMP-01/02 | strict byte-equal | `== @golden` | original **inline** markup block | unit | same | ❌ W0 | ⬜ pending |
| `page_back` | COMP-01/02 | strict byte-equal | `== @golden` | original markup (caller copy is Phase-156 concern) | unit | same | ❌ W0 | ⬜ pending |
| `scope_ribbon` | COMP-01/02 | strict byte-equal | `== @golden` | original markup | unit | same | ❌ W0 | ⬜ pending |
| `notice` | COMP-01/02 | full target golden | `== @notice_golden` (target `sg-notice`, ≠ current `sg-list-row`) | hand-written `sg-notice` target; pixel-neutral via verified CSS clone; `data-tone` is a **string** | unit | same | ❌ W0 | ⬜ pending |
| `stat` | COMP-01/02 | structural | `=~` required classes; `refute` `<a>`; `refute` `.sg-stat` | design contract (no live analog) | unit | same | ❌ W0 | ⬜ pending |
| `skeleton` | COMP-01/02 | structural | `=~` `sg-skeleton` | design contract (no live analog) | unit | same | ❌ W0 | ⬜ pending |
| 5×3 baselines | COMP-02 | E2E (gated) | zero re-records | existing snapshots | E2E | `npx playwright test tests/admin-checkpoints.spec.ts --project=admin-checkpoints-{chromium,mobile,dark}` | ✅ gated by `needs:` | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/sigra/admin/components_test.exs` — covers COMP-01/COMP-02 (does not exist; first lib-side `render_component` test). `use ExUnit.Case, async: true`, `@endpoint nil`, `import Phoenix.LiveViewTest`. Mirror `test/sigra/admin/authorizer_test.exs:2` (DB-free precedent in this exact dir).
- [ ] `lib/sigra/admin/components.ex` — the module under test (does not exist).
- [ ] `.github/workflows/ci.yml:697` — change `needs: release_ref_guard` → `needs: [release_ref_guard, library_tests]` (wires the gate so Playwright cannot start until byte-equality passes — D-14).
- [ ] `guides/reference/admin-design-contract.md` notice ARIA cell (~lines 107–115) — D-09 amendment (**required**, currently contradicts D-08; the goldens' drift messages cite this contract).
- Framework install: none — ExUnit + phoenix_live_view 1.1.31 already present.

*Goldens are bootstrapped from the **original** markup (capture-then-repoint, D-11), never authored from the new component — avoids the tautological "new code tests new code" gate.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| — | — | — | All phase behaviors have automated verification. The component test (`==` / `=~`) proves markup fidelity; the gated Playwright baselines prove pixel fidelity; axe runs in the existing Playwright job. |

*No manual UAT — verification is fully shifted-left into the component-equality gate + existing baseline guard.*

---

## Don't Hand-Roll (from RESEARCH.md)

- **No snapshot library.** Literal `@golden = "…"` module attribute + `==`; `mneme auto_assert` is explicitly rejected (D-13) — any "bless/update the new value" affordance reintroduces the Jest-snapshot footgun the keystone forbids.
- **No ConnCase/router/LiveView** to render a leaf function component — use `Phoenix.LiveViewTest.render_component/2` (D-10); output is byte-stable and source-ordered.
- **No new alert CSS** — reuse the existing `.sg-notice` (Phase 154 byte-clone of `.sg-list-row`).
- **No atom→class tone map** — emit `data-tone={@tone}` and let the existing `[data-tone]` CSS selectors key on the **string** the original already emits.

---

## Validation Sign-Off

- [ ] All component assertions have an automated `mix test` command (no manual gaps)
- [ ] Sampling continuity: every component is covered by `components_test.exs` (no 3-component gap)
- [ ] Wave 0 covers the 4 MISSING references (module, test, ci.yml `needs:`, contract amendment)
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s (DB-free async test)
- [ ] `nyquist_compliant: true` set in frontmatter once plans wire every component assertion

**Approval:** pending
