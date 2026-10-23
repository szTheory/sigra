---
phase: 236-flake-root-cause-reproduce-name-fix
plan: 02
subsystem: admin-ui
tags: [liveview, phoenix, push_patch, audit-explorer, admin]

requires:
  - phase: 236-01
    provides: "D-05 branch (a) confirmed — product race in AuditIndexLive's filter form, authorizing this fix shape exactly as written"
provides:
  - "Sigra.Admin.Live.AuditIndexLive owns every URL transition on the failing test's path: its own preset/sort/clear anchors and its filter form, via <.link patch> and push_patch/2"
  - "An ExUnit source contract (phase_236_audit_url_ownership_test.exs) encoding the fix shape so a later regression is caught, not silently reintroduced"
affects: [236-03, 236-04]

actuals:
  tokens: 42000
  tasks: 3
  commits: 2

tech-stack:
  added: []
  patterns:
    - "Server-side push_patch/2 in lib/sigra/admin/ — a first for this directory (0 hits before this plan); <.link patch> itself was already precedented in branding_live.ex"
    - "phx-submit + handle_event whitelist-then-push_patch shape mirrored from branding_live.ex's phx-change/phx-submit form"

key-files:
  created:
    - test/sigra/planning/phase_236_audit_url_ownership_test.exs
    - .planning/todos/pending/2026-09-15-phase-235-fast-01-contract-tests-stale-post-v148-rollover.md
  modified:
    - lib/sigra/admin/live/audit_index_live.ex

key-decisions:
  - "TDD RED/GREEN split into two commits (test(236-02) then feat(236-02)) instead of the plan's literal 'commit the two files as one atomic commit' instruction — the phase dispatch explicitly mandated the RED-before-implementation cycle from tdd.md, which takes precedence over the base plan's commit-granularity suggestion. The combined diff still touches exactly the two files this plan owns (verified via git diff origin/main...HEAD -- lib/ test/sigra/planning/)."
  - "@filter_param_keys and the new handle_event/3 clause were placed immediately after handle_params/3 (before render/1) rather than 'near @chip_keys' as the plan's action text suggested — @chip_keys is declared textually after render/1 in this file, and Elixir module attributes must be assigned before the point they're referenced at compile time. Placing @filter_param_keys after its first use in handle_event would fail to compile. Behavior and test assertions are unaffected — both tests only assert the attribute's presence in the source, not its position."
  - "Installed phx_new 1.8.8 locally (mix archive.install --force hex phx_new 1.8.8) to match ci.yml's pin (previously had 1.8.13) — required by ci.install_golden's byte-sensitive golden diff test; this is a legitimate maintenance action per CLAUDE.md's documented local dev prerequisite, not a new/unvetted package install."

requirements-completed: [GREEN-02]

coverage:
  - id: D1
    description: "The six named URL-transition anchors (Failures/Impersonation presets, Clear, Clear all, Occurred sort, Clear all filters) render as <.link patch>, and the filter form submits through phx-submit=\"apply_filters\" with method=\"get\"/action= kept as fallback"
    requirement: "GREEN-02"
    verification:
      - kind: unit
        ref: "test/sigra/planning/phase_236_audit_url_ownership_test.exs — all 10 tests"
        status: pass
      - kind: integration
        ref: "test/example/test/example_web/live/admin_audit_index_live_test.exs — 4/4 tests (dead-render href assertions byte-unchanged)"
        status: pass
    human_judgment: false
  - id: D2
    description: "The new handle_event(\"apply_filters\", params, socket) whitelists client-controlled params via Map.take/2 against @filter_param_keys before building the push_patch target through index_path/1 — closing T-236-05/06/07"
    requirement: "GREEN-02"
    verification:
      - kind: unit
        ref: "test/sigra/planning/phase_236_audit_url_ownership_test.exs — '@filter_param_keys' and 'Map.take(' assertions"
        status: pass
    human_judgment: false
  - id: D3
    description: "Rendered output is byte-identical: no PNG recapture lane opens on /admin/audit"
    verification:
      - kind: e2e
        ref: "scripts/ci/snapshot-canary-guard.sh --base origin/main"
        status: pass
    human_judgment: false
  - id: D4
    description: "mix ci is fully green for this plan's own surface (format, deps checks, compile --warnings-as-errors, the full ExUnit suite except a pre-existing unrelated staleness, ci.install_golden, sigra.dep_off)"
    verification:
      - kind: other
        ref: "MIX_ENV=test mix ci (see Known Pre-existing Failure below)"
        status: fail
    human_judgment: true
    rationale: "mix ci's aggregate exit code is non-zero solely because of 3 pre-existing, unrelated test failures in test/sigra/planning/phase_235_fast_01_*_contract_test.exs, which assert against REQUIREMENTS.md content from the now-closed v1.47 milestone. Verified via git log that both the REQUIREMENTS.md v1.48 rollover (cc6f17e4) and the last edit to those test files (cc4835c5) predate this plan and Phase 236 entirely. A human should confirm this diagnosis is accepted rather than the executor unilaterally judging its own gate green with a hand-picked test subset."

duration: 35min
completed: 2026-09-15
status: complete
---

# Phase 236 Plan 02: Convert Audit Filter Anchors to `<.link patch>` + `push_patch` Summary

**`Sigra.Admin.Live.AuditIndexLive` now owns every URL transition on the failing test's path — six anchors converted to `<.link patch>`, the filter form gained `phx-submit="apply_filters"`, and a new `handle_event/3` whitelists params before calling `push_patch/2` — eliminating the `unload()`/native-GET race named in 236-DIAGNOSIS.md, with zero rendered-output drift.**

## Performance

- **Duration:** ~35 min
- **Tasks:** 3 (2 committed as RED/GREEN, 1 verification-only)
- **Files created:** 2 (SC-2 contract test, a deferral todo)
- **Files modified:** 1 (`audit_index_live.ex`)

## Accomplishments

- Wrote `test/sigra/planning/phase_236_audit_url_ownership_test.exs`: a 10-test source contract asserting `phx-submit="apply_filters"`, at least one `handle_event(` clause, the six `<.link patch>` conversions by exact helper (`preset_path` ×2, `index_path(@admin_scope)` ×3, `sort_path` ×1), `export_path` staying on plain `<a href>`, the recorded scope exclusion (`remove_href=`/`prev_href=`/`next_href=` unconverted), the verbatim submit button, absence of `phx-change`, the `@filter_param_keys` whitelist + `Map.take(`, and the D-14 blank-equivalence contract (`param_value/3`'s default + `append_query/2`'s blank rejection). Confirmed RED against HEAD: 5/10 tests failed on exactly the target assertions.
- Converted the six named anchors (`Failures`, `Impersonation`, `Clear`, `Clear all`, `Occurred` sort header, `Clear all filters`) from `<a href>` to `<.link patch>`, carrying every `class`/`aria-current`/text verbatim. Added `phx-submit="apply_filters"` to the filter form, keeping `method="get"` and `action=` as the progressive-enhancement fallback (D-10). Added `@filter_param_keys` and one `handle_event("apply_filters", params, socket)` clause that whitelists via `Map.take/2`, builds the target through `index_path/1`, and calls `push_patch/2` — closing the T-236-05/06/07 tampering and cross-`live_session` threats. `handle_params/3` remains the sole loader.
- Confirmed GREEN: SC-2 contract 10/10 pass, `mix format --check-formatted` and `mix compile --warnings-as-errors` both exit 0.
- Ran the full local gate: `test/example`'s ExUnit suite (334 tests, 0 failures, including all 4 tests in `admin_audit_index_live_test.exs` unchanged) and `scripts/ci/snapshot-canary-guard.sh --base origin/main` (PASS, 0 changed slugs) — both prove the fix is render-neutral and no PNG recapture lane opened.
- `MIX_ENV=test mix ci` surfaced one pre-existing, unrelated failure cluster (3 tests in `test/sigra/planning/phase_235_fast_01_*_contract_test.exs`, stale since the v1.48 `REQUIREMENTS.md` rollover at `cc6f17e4`, predating Phase 236 entirely) — documented below and filed as a todo rather than fixed, per this plan's strict file-scope prohibition.

## Task Commits

1. **Task 1: Write the SC-2 source contract as a failing ExUnit test** — `6bbab6c8` (test) — RED confirmed, 5/10 failures on the target assertions.
2. **Task 2: Convert the six filter anchors + add the `apply_filters` handler** — `e3b61df6` (feat) — GREEN, 10/10 tests pass.
3. **Task 3: Prove render-neutrality — full local gate plus the snapshot canary** — no commit (verification-only; the two owned files were already committed in Tasks 1/2).

**Plan metadata:** committed alongside this SUMMARY (see below).

_TDD RED→GREEN split per the phase dispatch's explicit tdd.md instruction — see Deviations._

## Files Created/Modified

- `test/sigra/planning/phase_236_audit_url_ownership_test.exs` — SC-2 source contract, 10 tests
- `lib/sigra/admin/live/audit_index_live.ex` — six anchors → `<.link patch>`, `phx-submit` on the form, `@filter_param_keys` + `handle_event/3`
- `.planning/todos/pending/2026-09-15-phase-235-fast-01-contract-tests-stale-post-v148-rollover.md` — deferral for the pre-existing `mix ci` breakage found while running this plan's verification

## Decisions Made

See `key-decisions` in frontmatter. Most consequential: the TDD RED/GREEN commit split (mandated by the phase dispatch, not the base plan text) and the `@filter_param_keys`/`handle_event` placement (forced by Elixir's compile-order requirement for module attributes, not a stylistic choice).

## Deviations from Plan

### Auto-fixed / Process Deviations

**1. [Process — not a Rule 1-4 deviation] TDD RED/GREEN split into two commits instead of one.**
- **Found during:** Task 1/2 boundary.
- **Issue:** The plan's Task 3 action text says "Commit the two files as one atomic commit," but the phase dispatch's `<execution_context>` explicitly required following `tdd.md`'s RED-before-implementation cycle for this `tdd="true"` task, which mandates a `test(...)` commit before a `feat(...)` commit.
- **Fix:** Committed the RED test (`6bbab6c8`) and the GREEN implementation (`e3b61df6`) separately. The combined diff across both commits still touches exactly the two files this plan owns — verified with `git diff --name-only origin/main...HEAD -- lib/ test/sigra/planning/` returning only those two paths.
- **Impact:** None on scope or correctness. No scope creep.

**2. [Process — placement, not behavior] `@filter_param_keys` and `handle_event/3` placed after `handle_params/3` rather than "near `@chip_keys`".**
- **Found during:** Task 2.
- **Issue:** The plan's action text says to add `@filter_param_keys` "near the existing `@chip_keys` at `:222`" — but `@chip_keys` is declared textually AFTER `render/1` in the file, and the new `handle_event/3` (placed before `render/1` per the plan's own ordering instruction) references `@filter_param_keys` at compile time. Elixir raises a compile error if a module attribute is referenced before it is assigned in file order.
- **Fix:** Declared `@filter_param_keys` immediately before the `handle_event/3` clause, between `handle_params/3` and `render/1`.
- **Impact:** None — both the module ordering (`mount` → `handle_params` → `handle_event` → `render`, matching `branding_live.ex`) and every test assertion (which check for the attribute's presence, not its line position) are satisfied. `mix compile --warnings-as-errors` confirms it compiles clean.

**3. [Rule 3 — Blocking, environment] Installed `phx_new 1.8.8` locally (had `1.8.13`).**
- **Found during:** Task 3, before running `mix ci`.
- **Issue:** CLAUDE.md and `ci.yml` both pin `phx_new 1.8.8` for `ci.install_golden`'s byte-sensitive golden diff test; the local environment had `1.8.13` installed, which would have produced spurious byte-diffs unrelated to this plan.
- **Fix:** `mix archive.install --force hex phx_new 1.8.8`.
- **Impact:** None — this restores the documented local dev prerequisite; it is not a new or unvetted package (it is the project's own pinned generator archive), so it is not subject to the package-legitimacy checkpoint exclusion.

No Rule 1/2/4 deviations occurred in the owned files — the fix is exactly the shape 236-DIAGNOSIS.md's confirmed D-05 branch (a) authorized.

---

**Total deviations:** 2 process deviations (commit granularity, attribute placement), 1 Rule 3 environment fix (phx_new archive version), 0 Rule 1/2/4 deviations.
**Impact on plan:** None on scope or correctness — all task-level acceptance criteria were independently verified.

## Known Pre-existing Failure (out of scope, documented not fixed)

`MIX_ENV=test mix ci`'s aggregate exit code is non-zero because 3 tests in
`test/sigra/planning/phase_235_fast_01_source_complete_contract_test.exs` and
`phase_235_fast_01_gap_closure_contract_test.exs` fail — they assert `.planning/REQUIREMENTS.md`
marks `FAST-01`/`GATE-05` (v1.47 CI-EFFICIENCY requirement IDs) as `[x]` complete, but
`REQUIREMENTS.md` was replaced wholesale for the v1.48 CLEAN-BASELINE milestone (commit `cc6f17e4`,
"docs: define milestone v1.48 requirements") and has neither ID.

**Confirmed pre-existing and unrelated to this plan:**
- `git log --oneline -1 -- test/sigra/planning/phase_235_fast_01_source_complete_contract_test.exs`
  → `cc4835c5` ("chore: close out v1.47 CI-EFFICIENCY (#241)") — last touched BEFORE the v1.48
  requirements rollover.
- `git status --porcelain .planning/REQUIREMENTS.md` is clean under this plan's diff — this plan
  never touched it.
- `git diff --name-only origin/main...HEAD -- lib/ test/sigra/planning/` shows only this plan's two
  owned files.

**Every other step of `mix ci` passes:** `format --check-formatted`, `deps.get --check-locked`,
`deps.unlock --check-unused`, `compile --warnings-as-errors`, the full test suite except those 3
(2599 total, 3 failures, 12 skipped, 22 excluded — all 3 failures in the two named files above),
`ci.install_golden` (65 tests, 0 failures), and `sigra.dep_off` (verified standalone, exit 0).

**Not fixed here:** editing `phase_235_fast_01_*_contract_test.exs` or `.planning/REQUIREMENTS.md`
is outside this plan's file scope (`lib/sigra/admin/live/audit_index_live.ex` and
`test/sigra/planning/phase_236_audit_url_ownership_test.exs` only) and unrelated to GREEN-02.
Filed as `.planning/todos/pending/2026-09-15-phase-235-fast-01-contract-tests-stale-post-v148-rollover.md`.

A separate, transient stale-compile artifact was also observed and resolved before the final `mix
ci` run: on the first attempt, 9 tests in `test/sigra/audit/forwarders/threadline_test.exs` failed
with `UndefinedFunctionError` on `Sigra.Audit.Forwarders.Threadline.attach/1` because that
conditionally-compiled module (`Code.ensure_compiled(Threadline)`) had gone stale relative to the
`threadline` dependency in `_build/test`. `mix deps.compile threadline --force && mix compile
--force` resolved it (confirmed via an isolated `mix test test/sigra/audit/forwarders/threadline_test.exs`
run: 6/6 pass after the force-recompile). This is a local build-cache artifact, not a code or
dependency-version defect, and required no code change.

## Issues Encountered

See "Known Pre-existing Failure" above — the only unresolved issue, and it is explicitly out of
this plan's scope. No issues occurred within the owned files.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- GREEN-02's `lib/` clause is met: `AuditIndexLive` owns every URL transition on the failing test's
  path via `<.link patch>` + `push_patch/2`, closing the product race named in
  `236-DIAGNOSIS.md`.
- No PNG recapture lane opened; `scripts/ci/snapshot-canary-guard.sh` stays green.
- Plan 236-03 (the `p17` prohibition guard + dead `PLAYWRIGHT_RETRIES` env var deletion) is
  unblocked and independent of this plan's file scope.
- Plan 236-04 should fold in the new pending todo
  (`2026-09-15-phase-235-fast-01-contract-tests-stale-post-v148-rollover.md`) alongside its existing
  D-30 deferral bookkeeping, and should note the applied_chip/pagination-anchor scope exception is
  now live in `audit_index_live.ex` exactly as `<scope_line_recorded>` describes.
- **Open question for the human/orchestrator:** the pre-existing `phase_235_fast_01_*` contract
  test failures mean `main`'s literal `mix ci` gate is currently red for a reason Phase 236 does not
  own. This is worth surfacing before closing the milestone's GREEN objective, even though it did
  not block this plan's own deliverable.

## Self-Check: PASSED

- `test -f test/sigra/planning/phase_236_audit_url_ownership_test.exs` → FOUND
- `git log --oneline --all | grep -q 6bbab6c8` → FOUND
- `git log --oneline --all | grep -q e3b61df6` → FOUND
- `MIX_ENV=test mix test test/sigra/planning/phase_236_audit_url_ownership_test.exs` → 10 tests, 0 failures
- `grep -c 'patch=' lib/sigra/admin/live/audit_index_live.ex` → 6
- `(cd test/example && MIX_ENV=test mix test --include example_app)` → 334 tests, 0 failures
- `bash scripts/ci/snapshot-canary-guard.sh --base origin/main` → PASS (0 changed slugs)
- `git status --porcelain test/example/priv/playwright/` → clean
- `git diff --name-only origin/main...HEAD -- lib/ test/sigra/planning/` → exactly the two owned files

---
*Phase: 236-flake-root-cause-reproduce-name-fix*
*Completed: 2026-09-15*
