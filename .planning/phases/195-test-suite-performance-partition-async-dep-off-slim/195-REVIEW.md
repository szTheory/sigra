---
phase: 195-test-suite-performance-partition-async-dep-off-slim
reviewed: 2026-06-20T09:35:00Z
depth: standard
files_reviewed: 14
files_reviewed_list:
  - .github/workflows/ci.yml
  - mix.exs
  - test/sigra/application_forwarders_test.exs
  - test/sigra/audit/forwarders/noop_test.exs
  - test/sigra/auth_plain_map_regression_test.exs
  - test/sigra/config_forwarders_test.exs
  - test/sigra/doctor_test.exs
  - test/sigra/mix/tasks/doctor_task_test.exs
  - test/sigra/optional_deps_test.exs
  - test/sigra/passkeys/rate_limit_test.exs
  - test/sigra/workers/audit_forward_test.exs
  - test/sigra/planning/phase_58_oauth_oa01_ci_contract_test.exs
  - guides/recipes/local-development.md
  - guides/recipes/testing.md
findings:
  critical: 0
  warning: 1
  info: 3
  total: 4
status: issues
---

# Phase 195: Code Review Report

**Reviewed:** 2026-06-20T09:35:00Z
**Depth:** standard
**Files Reviewed:** 14
**Status:** issues_found

## Summary

Phase 195 is a CI/test-performance change: it partitions `library_tests` into a 2-leg
`library_tests_shard` matrix worker plus a byte-identical `library_tests` aggregator
(preserving the protected required check), relocates `mix docs` onto
`library_tests_dep_off`, slims the dep-off lane to the `:threadline_guard` subset, adds a
`sigra.dep_off` mix alias, flips 2 test modules to `async: true`, and updates the OA-01
contract test anchor.

I verified the four high-risk areas called out in scope:

1. **ci.yml topology — sound.** YAML parses (16 jobs). The aggregator's
   `name: "Library tests"` is byte-identical to the ruleset 14941512 required check (verified
   programmatically). `fail-fast: false` and `matrix.partition: [1, 2]` are correct. The
   aggregator correctly fails on any non-`success` shard result (`needs.library_tests_shard.result`).
   `ci-gate` still references the aggregator `library_tests` (not the shard) — no orphaned
   `needs:`. `mix docs --warnings-as-errors` appears exactly once. No OAuth exclude in the
   worker body.
2. **Async-flip safety — verified safe.** Both `auth_plain_map_regression_test.exs` (StubRepo)
   and `passkeys/rate_limit_test.exs` (RecordingLimiter) confine all mutable state to the
   process dictionary (`Process.put`/`Process.get`) and process-local message passing
   (`send(self(), …)` + `assert_received`). No Application/System env, named ETS,
   `:persistent_term`, telemetry, `set_mox_global`, or non-sandboxed DB writes. Safe for
   `async: true`. `application_forwarders_test.exs` correctly remained `async: false`.
3. **`sigra.dep_off` alias — correct but env-fragile** (see IN-01, IN-02).
4. **OA-01 contract test — security intent preserved.** The lock now anchors on
   `library_tests_shard:` (split boundary `\n  library_tests:`, both verified to appear exactly
   once), asserts the run is `mix test --partitions 2`, and keeps the
   `refute job =~ ~r/--exclude.*oauth/i` no-OAuth-exclude guard. Test runs green.

One WARNING about the relocated `mix docs` step running in a dep-removed, dev-env context;
three INFO items about alias ergonomics and a coverage-narrowing tradeoff.

## Warnings

### WR-01: Relocated `mix docs` runs in `dev` env *after* `:threadline` is cleaned from the dep graph

**File:** `.github/workflows/ci.yml:348-373`
**Issue:** In `library_tests_dep_off`, the steps run in this order:
`deps.compile` (MIX_ENV=test) → `deps.unlock threadline` + `deps.clean threadline --build`
(removes threadline from lock and from **all** build envs) → `mix compile --no-deps-check`
(MIX_ENV=test) → `mix test … --no-deps-check` (test) → **`mix docs --warnings-as-errors`
(no `MIX_ENV` set → defaults to `dev`)**.

Two compounding concerns the SUMMARY's "zero added cost" claim (195-02 lines 86-88) does not
capture:

1. **Fresh dev-env compile-from-scratch.** Every prior step populated only `_build/test`.
   `mix docs` triggers a default `mix compile` in `dev`, where `_build/dev` is empty, so it
   recompiles all deps + the library from scratch in dev — not "zero added cost." (The same
   was true at the old location, so this part is pre-existing, not a regression.)
2. **Docs now build with `:threadline` absent (new in this phase).** `mix docs` previously
   ran on the full-deps `library_tests` job; it now runs after `deps.clean threadline --build`.
   Because `:threadline` is `optional: true` and the lib compiles without it (proven by the
   D-09 compile-proof step in test env), this most likely succeeds. But it is unverified that
   a *dev-env* compile of an *unlocked* optional dep does not trip Mix's unchecked-dependency
   handling, and ex_doc will silently omit any `@doc`/`@spec` content that only exists when
   `Threadline` is loaded. The inline comment at lines 339-343 explicitly warns that
   `--no-deps-check` does not build deps and that cache misses need `deps.compile` first — that
   same robustness reasoning is not applied to the dev-env `mix docs` step.

**Fix:** Pin the docs step to the env that was actually compiled and document the
dep-absent build explicitly:
```yaml
- name: Check docs build cleanly
  env:
    MIX_ENV: test            # reuse the already-compiled _build/test; avoids a dev recompile
  run: mix docs --warnings-as-errors --no-deps-check
```
If docs must build in `dev`, add a dev `deps.get`/`deps.compile` before it (mirroring the
test-env robustness comment) and assert that running docs with `:threadline` removed is the
intended contract — otherwise relocate `mix docs` to a job where the dep is still present.

## Info

### IN-01: `sigra.dep_off` alias silently splits its MIX_ENV between compile and test steps

**File:** `mix.exs:151-156`
**Issue:** The alias runs `compile --warnings-as-errors --no-deps-check` in whatever env the
alias was invoked with, but `test --only threadline_guard --no-deps-check` always forces
`MIX_ENV=test`. If a developer runs `mix sigra.dep_off` without the documented `MIX_ENV=test`
prefix, the compile-proof runs in `dev` while the test step runs in `test` — so the
compile-proof does not actually validate the artifacts the test step uses, and the test step
(with `--no-deps-check`) may fail on a missing test-env compile. The usage comment (line 150)
documents `MIX_ENV=test mix sigra.dep_off`, but nothing enforces it.
**Fix:** Make the compile env explicit so the alias is correct regardless of invocation, e.g.
prefix the compile step `"cmd MIX_ENV=test mix compile --warnings-as-errors --no-deps-check"`
(or document that the leading `MIX_ENV=test` is mandatory and not merely recommended).

### IN-02: `sigra.dep_off` mutates the developer's local lockfile and `_build` destructively

**File:** `mix.exs:152-153`
**Issue:** `deps.unlock threadline` rewrites `mix.lock` and `deps.clean threadline --build`
deletes threadline build artifacts in the developer's working tree. The recovery step
(`mix deps.get`) lives only in the docs (`guides/recipes/local-development.md`), not in the
alias, so an interrupted or forgotten run leaves the repo in a dep-off state that can confuse
a subsequent normal `mix test`.
**Fix:** Add a note in the alias comment that it is destructive and requires `mix deps.get`
afterward (the doc already covers this; mirroring it at the call site reduces foot-guns). A
restore step cannot be appended to the alias without defeating the dep-off purpose, so a
comment is the pragmatic fix.

### IN-03: Dep-off lane coverage narrowed from "whole suite minus requires_threadline" to "65 tagged tests"

**File:** `.github/workflows/ci.yml:362-368`
**Issue:** The previous command `mix test --exclude requires_threadline --no-deps-check` ran
nearly the entire suite in dep-off mode; the new `mix test --only threadline_guard
--no-deps-check` runs only the 65 `:threadline_guard`-tagged tests. Any future runtime
regression that manifests only under dep-off but lives in an untagged module is no longer
exercised by this lane. This is the deliberate TEST-02 slim (the compile-proof step still
covers compilation, and `--only` fails RED on a dropped tag, which `--exclude` did not), so it
is an intentional tradeoff rather than a defect — flagged so the coverage boundary is recorded.
**Fix:** None required. Keep the `:threadline_guard` tag set authoritative: when adding new
dep-off-sensitive runtime paths, tag the covering test `@moduletag :threadline_guard` so this
lane continues to catch them.

---

_Reviewed: 2026-06-20T09:35:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_

---

## Orchestrator remediation (execute-phase, 2026-06-20)

**WR-01 (relocated `mix docs` step) — suggested fix REJECTED after empirical verification; no code change.**

The reviewer's proposed fix was to pin the docs step to `MIX_ENV: test --no-deps-check`
to reuse `_build/test`. Verified locally that this would **break CI**:

- `ex_doc` is declared `{:ex_doc, "~> 0.40", only: :dev, runtime: false}` (mix.exs:124).
- `MIX_ENV=test mix docs` → `** (Mix) The task "docs" could not be found`.
- `MIX_ENV=dev mix help docs` → available; `MIX_ENV=test mix help docs` → not available.

So the step's dev-env default (no `MIX_ENV`) is **required** for the `docs` task to exist.
The dev-env from-scratch compile is inherent (ex_doc is dev-only and no CI job pre-compiles
the dev build) and is **not new** — the pre-relocation `Check docs build cleanly` step ran
the same `mix docs --warnings-as-errors` in dev. The relocation's D-07 win (run **once**
instead of N× per shard) stands. The threadline-absent docs build is harmless: `:threadline`
is `optional: true`, ex_doc documents Sigra's own modules, and Sigra does not doc-link the
optional external dep. **Disposition: working as intended.**

**IN-01 / IN-02 (alias env-split + local destructiveness) — ACCEPTED, no change.** Documented
ergonomics of the `sigra.dep_off` local-repro alias; the canonical invocation is
`MIX_ENV=test mix sigra.dep_off` (recorded in guides). **IN-03** (dep-off lane narrowed to the
65 `:threadline_guard` tagged tests) is the intentional TEST-02 design, recorded not flagged.

Net: 0 actionable findings. The one regression caught by the post-merge gate
(Phase58 OA-01 contract) was fixed in `ca9ac843`.
