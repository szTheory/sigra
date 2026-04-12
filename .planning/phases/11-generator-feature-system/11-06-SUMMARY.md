---
phase: 11
plan: 06
subsystem: installer-generator
tags:
  - generator
  - guardrails
  - validation
  - wave-5
  - nyquist
requires:
  - lib/sigra/install/feature.ex (Wave 1 behaviour)
  - lib/sigra/install/injection.ex (Wave 1 struct)
  - lib/sigra/install/runner.ex (Wave 4 walker)
  - lib/sigra/install/features/core.ex (Wave 3 feature impl)
  - priv/templates/sigra.install/core/ (Wave 2 relocated tree)
  - lib/mix/tasks/sigra.install.ex (Wave 4 thin caller)
provides:
  - test/sigra/install/purely_additive_test.exs (V-PA-01 — 3 tests)
  - test/sigra/install/isolation_test.exs (V-ISOLATION-01 — 3 tests)
  - .planning/phases/11-generator-feature-system/11-VALIDATION.md (finalized; nyquist_compliant: true)
affects: []
tech-stack:
  added: []
  patterns:
    - docstring-stripping grep assertions (strip @moduledoc/@doc heredocs before scanning, so invariants can be documented without the docs tripping the test)
key-files:
  created:
    - test/sigra/install/purely_additive_test.exs
    - test/sigra/install/isolation_test.exs
  modified:
    - .planning/phases/11-generator-feature-system/11-VALIDATION.md
decisions:
  - Strip @moduledoc/@doc heredocs before the grep-based isolation scan so Features.Core's moduledoc can explicitly name the forbidden symbols while explaining the Pitfall X-1 invariant. The scan targets executable code only, which is the actual contract.
  - FakeFeature inlines its migration into files/1 (with the timestamp resolved via binding[:migration_timestamps]) rather than relying on a separate migration-write path. This mirrors how Features.Core does it and keeps the Runner unchanged.
  - Runner.run/3 returns {:ok, report} (single element), not {:ok, report, instrs} as the plan draft suggested — test updated to match the existing Wave 4 contract.
  - The info-level plan-checker observations (Report.render_rows off-by-one + column padding) are left as-is. Any change to Report rendering would break the golden STDOUT.txt byte barrier; these are candidates for a Phase 23 polish pass, not Wave 5.
metrics:
  duration_minutes: 12
  completed_date: 2026-04-11
  tasks_committed: 2
  tests_added: 6
  lines_added: ~300 (tests) + 49 (validation doc edits)
---

# Phase 11 Plan 06: Validation Guardrails Summary

Mechanical CI-enforced proof that Phase 11 achieved its structural goal: the walker is feature-agnostic (V-PA-01) and `Features.Core` does not leak future-feature symbols (V-ISOLATION-01). VALIDATION.md is finalized with `nyquist_compliant: true` and a per-task map covering all 12 tasks across Plans 11-01..11-06.

## What Shipped

### `test/sigra/install/purely_additive_test.exs` (V-PA-01, 3 tests)

- `FakeFeature` — an inline-defined `Sigra.Install.Feature` implementation (one trivial file, one trivial injection, one trivial migration, one post-instruction chunk) exercised through `Runner.run([FakeFeature], binding, [])` against a tmp dir. The template is written under `tmp/priv/templates/sigra.install/fake/` so `Runner.find_template/1`'s host-app override path resolves it.
- Assertions: generated file exists, injection applied to `router.ex`, migration written with a 14-digit timestamp prefix.
- **Second test:** grep assertion that `lib/mix/tasks/sigra.install.ex` never mentions `Features.Organizations|Passkeys|Admin`, always declares `@features`, and never case-matches on feature modules.
- **Third test:** grep assertion that `lib/sigra/install/runner.ex` executable code never references any feature module by name (docstrings are stripped before scanning so the module's moduledoc can document the invariant).

### `test/sigra/install/isolation_test.exs` (V-ISOLATION-01, 3 tests)

- `@forbidden_symbols` list: `Features.Organizations`, `Features.Passkeys`, `Features.Admin`, `OrganizationMembership`, `OrganizationInvitation`, `UserPasskey`, `AdminUser`, `Sigra.Passkeys`, `Sigra.Organizations`. Phase 18/22 planners can extend this list when those features ship; the test's error message points at the correct file.
- **Test 1:** strips `@moduledoc`/`@doc` heredocs from `lib/sigra/install/features/core.ex` and asserts every forbidden symbol is absent from the remaining executable code.
- **Test 2:** walks every file under `priv/templates/sigra.install/core/` and asserts no forbidden symbol appears — enforcing Pitfall X-3 at the template level.
- **Test 3:** asserts exactly 45 templates are present under `core/` (cross-check against the Wave 2 layout).

### `.planning/phases/11-generator-feature-system/11-VALIDATION.md` (finalized)

- Frontmatter: `status: draft` → `approved`, `nyquist_compliant: false` → `true`, `wave_0_complete: false` → `true`.
- Per-task verification map: skeleton replaced with 12 real rows (one per task in Plans 11-01..11-06). Every `Automated Command` cell matches the task's `<verify><automated>` block verbatim — spot-checked against 11-01-02, 11-03-01, and 11-05-01.
- Wave 0 requirements checklist: all boxes ticked.
- Validation sign-off: all 6 boxes ticked; approval flipped from `pending` to `approved by planner (2026-04-11, Wave 5 completion)`.

## Invariants Now CI-Enforced

| Invariant | Enforced By | What It Catches |
|-----------|-------------|-----------------|
| Walker is feature-agnostic | `purely_additive_test.exs` — FakeFeature round-trip | Any future commit that adds `case feature do` / `if feature == Features.Core` to the walker |
| Mix task declares `@features` only | `purely_additive_test.exs` — grep test 2 | A PR that case-matches on feature modules in `sigra.install.ex` |
| `Features.Core` has no future-feature references | `isolation_test.exs` — test 1 | A copy-paste refactor that drops an `Organizations` reference into Core |
| `core/` templates have no future-feature references | `isolation_test.exs` — test 2 | Pitfall X-3 — a template referencing a schema that `--no-organizations` would not generate |
| Exactly 45 `core/` templates | `isolation_test.exs` — test 3 | Drift in the canonical template manifest |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] `runner.ex` / `feature.ex` / `features/core.ex` moduledocs reference forbidden symbols**

- **Found during:** Task 1 pre-flight grep scan.
- **Issue:** The plan draft of `purely_additive_test.exs` and `isolation_test.exs` used bare `refute source =~ "Features.Organizations"` assertions. But all three production modules (`runner.ex`, `feature.ex`, `features/core.ex`) explicitly name `Features.Organizations` / `Features.Passkeys` / `Features.Admin` *inside their `@moduledoc`* — that's literally where the isolation invariant is documented. A bare grep would fail on documentation that is correct and desirable.
- **Fix:** Added a `strip_docstrings/1` helper to both test files that removes `@moduledoc`/`@doc` heredoc content before scanning. The scan targets executable code only, which is the actual contract the tests enforce. Documentation is free to explain the invariant by name.
- **Files modified:** `test/sigra/install/purely_additive_test.exs`, `test/sigra/install/isolation_test.exs`
- **Commit:** `b5d1678`

**2. [Rule 1 - Bug] Plan draft expected `{:ok, _report, _instrs}` from `Runner.run/3`**

- **Found during:** Task 1 test run.
- **Issue:** The plan's test sketch destructured `Runner.run/3`'s return as a 3-tuple, but Wave 4's `runner.ex` returns `{:ok, report}` (2-tuple).
- **Fix:** Test updated to `{:ok, _report} = Runner.run(...)`.
- **Files modified:** `test/sigra/install/purely_additive_test.exs`
- **Commit:** `b5d1678`

**3. [Rule 2 - Missing critical functionality] FakeFeature needed to inline its migration into `files/1`**

- **Found during:** Task 1 test design.
- **Issue:** The Runner writes migrations by walking `feature.files/1` entries (Core inlines migration tuples with pre-resolved timestamps). A FakeFeature that only listed the migration in `migrations/1` but not in `files/1` would never actually write the migration file, breaking the "migration was written" assertion.
- **Fix:** FakeFeature's `files/1` now resolves its migration target via `binding[:migration_timestamps][:fake_slot]` and includes the `{:eex, source, target}` tuple alongside the `hello.txt` entry — mirroring how Features.Core does it.
- **Files modified:** `test/sigra/install/purely_additive_test.exs`
- **Commit:** `b5d1678`

**4. [Rule 2 - Missing critical functionality] `Mix.shell().info` noise swamps test output**

- **Found during:** Task 1 test run.
- **Issue:** Runner.run/3 calls `Mix.shell().info` on every file/injection, which polluted the test output.
- **Fix:** Wrapped the `Runner.run/3` call in `ExUnit.CaptureIO.capture_io/1`. The test still asserts on file system side effects, which is the real contract.
- **Files modified:** `test/sigra/install/purely_additive_test.exs`
- **Commit:** `b5d1678`

No architectural (Rule 4) changes were required.

## Verification

```bash
$ mix test test/sigra/install/purely_additive_test.exs test/sigra/install/isolation_test.exs
Running ExUnit with seed: 335803, max_cases: 16

......
Finished in 0.05 seconds (0.04s async, 0.01s sync)
6 tests, 0 failures

$ mix test test/sigra/install/
Finished in 62.8 seconds (0.2s async, 62.6s sync)
330 tests, 0 failures

$ mix format --check-formatted test/sigra/install/purely_additive_test.exs test/sigra/install/isolation_test.exs
# (clean)

$ git diff ebee9269d6200d7a343e62985fb8c30ee5045e6c -- lib/sigra/install/runner.ex lib/mix/tasks/sigra.install.ex
# (empty — walker files unmodified, as required by V-PA-01)

$ grep -c "^| 11-" .planning/phases/11-generator-feature-system/11-VALIDATION.md
12

$ grep -c "nyquist_compliant: false" .planning/phases/11-generator-feature-system/11-VALIDATION.md
0
```

- **Full `mix test test/sigra/install/`:** 330 tests, 0 failures in 62.8s (under the 120s Nyquist budget from VALIDATION.md).
- **Walker byte-identity:** `git diff` vs Wave 4 base is empty for both `runner.ex` and `sigra.install.ex` — V-PA-01 is satisfied by construction, not by convention.
- **Test files present:** `test/sigra/install/` now contains 15 test files plus the `features/` subdirectory — matching the Wave 0 manifest in VALIDATION.md.

## Task IDs That Differed From Skeleton

The VALIDATION.md skeleton referenced phantom plans `11-07` and `11-08` (the original multi-plan split). The actual Phase 11 shipped as six plans, each with two tasks:

| Skeleton Row (OLD) | Actual Row (NEW) |
|--------------------|------------------|
| `11-07-01` (walker refactor) | `11-05-01` |
| `11-07-02` (idempotency) | `11-05-02` |
| `11-08-01` (V-PA-01) | `11-06-01` |
| `11-08-02` (V-ISOLATION-01) | `11-06-01` (merged into one task) |
| `11-06-01` (Features.Core) | `11-04-01` |
| `11-06-02-postinstr` (Features.Core post_instructions) | `11-04-02` |
| `11-04-01` / `11-05-01` (Report / MigrationTimestamps) | `11-02-02` (merged) |

All phantom plan IDs removed. Final row count: exactly 12, matching `6 plans × 2 tasks`.

## Forbidden Symbol List (for Phase 18/22 planners)

Current `@forbidden_symbols`:

```elixir
[
  "Features.Organizations",
  "Features.Passkeys",
  "Features.Admin",
  "OrganizationMembership",
  "OrganizationInvitation",
  "UserPasskey",
  "AdminUser",
  "Sigra.Passkeys",
  "Sigra.Organizations"
]
```

When Phase 18 (Passkeys) ships, this list needs one edit: remove `Features.Passkeys`, `UserPasskey`, `Sigra.Passkeys` from the list and add a new `features/passkeys/` template isolation test. Same for Phase 22 (Organizations/Admin).

## Threat Flags

None. This plan added tests only — no new network, auth, file access, or schema surface.

## Known Stubs

None. Both tests exercise real code paths against real file system operations.

## Deferred Issues

- **Report.render_rows off-by-one and column padding (plan-checker info-level observations):** left as-is because any change to `Report` rendering would break the `STDOUT.txt` byte-identity barrier. Candidates for Phase 23 polish, not Wave 5.

## Self-Check: PASSED

- `test/sigra/install/purely_additive_test.exs` — FOUND
- `test/sigra/install/isolation_test.exs` — FOUND
- `.planning/phases/11-generator-feature-system/11-VALIDATION.md` — FOUND (nyquist_compliant: true verified)
- Commit `b5d1678` (test) — FOUND
- Commit `dd80fe4` (docs) — FOUND
- Walker files unmodified since Wave 4 base — VERIFIED (git diff empty)
- `mix test test/sigra/install/` — 330/330 green
