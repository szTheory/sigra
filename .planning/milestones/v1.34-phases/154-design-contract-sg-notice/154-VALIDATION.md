---
phase: 154
slug: design-contract-sg-notice
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-06-03
---

# Phase 154 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> This is an **artifacts-only** phase (governance doc + ~15 lines of CSS). There is
> no new functional behavior to unit-test — every validation is a file-existence
> check, a `git diff` boundary assertion, or a docs/test build that must stay green.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | N/A — artifacts-only; no new functional behavior. Existing `mix test` (ExUnit) must stay green. |
| **Config file** | none — no new test files added this phase |
| **Quick run command** | `git diff --name-only` (verify only expected files changed) |
| **Full suite command** | `mix test` (existing suite must stay green) + `mix docs` (verifies ExDoc registration) |
| **Estimated runtime** | ~60s (`mix test`) + ~10s (`mix docs`) |

---

## Sampling Rate

- **After every task commit:** Run `git diff --stat` — verify only expected files appear in the diff (scope boundary).
- **After every plan wave:** Run `mix docs` (doc wave) / `git diff` boundary checks (CSS wave).
- **Before `/gsd:verify-work`:** `mix test` green AND `mix docs` succeeds AND all 7 boundary checks below pass.
- **Max feedback latency:** ~70 seconds.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 154-01-01 | 01 | 1 | COMP-03 | — | N/A (governance doc only) | file-exists | `test -f guides/reference/admin-design-contract.md` | ❌ W0 | ⬜ pending |
| 154-01-02 | 01 | 1 | COMP-03 | — | doc covers all 10 components + 3 archetypes | grep | `grep -c "## " guides/reference/admin-design-contract.md` (≥13 sections) | ❌ W0 | ⬜ pending |
| 154-01-03 | 01 | 1 | COMP-03 | — | doc registered in ExDoc extras | config | `grep "admin-design-contract" mix.exs` | ❌ W0 | ⬜ pending |
| 154-01-04 | 01 | 1 | COMP-03 | — | ExDoc build still valid | build | `mix docs` exits 0 | ❌ W0 | ⬜ pending |
| 154-02-01 | 02 | 1 | COMP-04 | — | `sg-notice` CSS present in single tracked app.css | grep | `grep -c "sg-notice" test/example/priv/static/assets/css/app.css` (≥1) | ❌ W0 | ⬜ pending |
| 154-02-02 | 02 | 1 | COMP-04 | — | CSS inside `@layer sg-components` (no unlayered rules) | source assertion | `sg-notice` block sits between `@layer sg-components {` and its close (adjacent to `.sg-list-row[data-tone]`, ~L945–967) | ❌ W0 | ⬜ pending |
| 154-02-03 | 02 | 1 | COMP-04 | — | no new `!important` introduced | diff check | `git diff -- test/example/priv/static/assets/css/app.css \| grep "^+" \| grep "!important"` — expect empty | ❌ W0 | ⬜ pending |
| 154-02-04 | 02 | 1 | COMP-04 | — | uses existing tokens only (no new `--sg-*` token defs) | diff check | `git diff -- test/example/priv/static/assets/css/app.css \| grep "^+.*--sg-.*:.*;" \| grep -v "var("` — expect empty | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Phase Scope-Boundary Gate (SC#4 — "no behavior change")

These are not per-task; they are whole-phase invariants checked before verify-work. All must hold:

| # | Invariant | Command | Expected |
|---|-----------|---------|----------|
| 1 | No LiveView files modified | `git diff --name-only -- lib/sigra/admin/live/` | empty |
| 2 | No Playwright baselines changed | `git diff --name-only -- 'test/example/priv/playwright/tests/**-snapshots/'` | empty |
| 3 | `admin-generated` parity lane green | `scripts/ci/admin-acceptance-smoke.sh` (CSS-agnostic — must still pass) | exit 0 |
| 4 | Only expected files in phase diff | `git diff --name-only main...HEAD` | ⊆ {`guides/reference/admin-design-contract.md`, `mix.exs`, `test/example/priv/static/assets/css/app.css`, `.planning/**`} |

---

## Wave 0 Requirements

- No test files needed — all validations are file-existence checks and `git diff` boundary inspections.
- `mix docs` must succeed (verifies the ExDoc `extras:` registration is valid config and the new doc renders).
- Existing `mix test` suite is the baseline; it must remain green (this phase touches no Elixir source under `lib/`).

*Existing infrastructure covers all phase requirements — no Wave 0 framework install.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Governance doc content is accurate to current reality (documents real markup/CSS/ARIA, names locked winners, no invented design) | COMP-03 | Prose/semantic accuracy can't be asserted by grep — requires reading against the LiveViews | Spot-check each of the 10 component rows against its cited LiveView source; confirm 3 archetypes map to `index_live.ex` (Overview), `users_index_live.ex` (List), `user_show_live.ex` (Detail) |
| `sg-notice` is behavior-preserving vs current `.sg-list-row[data-tone]` alert rendering | COMP-04 | No call site renders `<.notice>` yet (adoption is Phase 156) — visual equivalence is a design judgment, not yet a baseline | Compare the `sg-notice` rule's tokens/treatment against `.sg-list-row[data-tone]` (app.css ~L945–967); confirm same tone tokens, inset bar, radius, transition |

---

## Validation Sign-Off

- [ ] All tasks have an `<automated>` verify command or are file-existence/diff checks
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify (all tasks here are automated)
- [ ] Wave 0 covers all MISSING references (none — existing infra)
- [ ] No watch-mode flags
- [ ] Feedback latency < 70s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-06-03
