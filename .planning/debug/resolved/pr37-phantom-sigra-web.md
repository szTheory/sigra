---
slug: pr37-phantom-sigra-web
status: resolved
trigger: PR #37 CI red — Library tests job creates phantom lib/sigra_web/ in sigra repo via in-process Install.run from a test that lost its raise guard, polluting downstream install_fixture tests
created: 2026-05-02
updated: 2026-05-02
---

# Debug Session: pr37-phantom-sigra-web

## Trigger

<DATA_START>
PR #37 (v1.21 batch including phase 93 ship) ran CI for the first time after the merge of origin/main and turned out 16/23 jobs red.

14 of 16 fails trace to a single root cause: a phantom `lib/sigra_web/` directory that appears in sigra-as-path-dep at compile time on a fresh CI clone, even though `lib/sigra_web/` is not in git, no source defines `SigraWeb.*`, and no `test/support/` references it.

Plan 08 SUMMARY (9a1bbdf, 2026-05-02) explicitly flagged it: "untracked lib/sigra_web/ directory exists in the worktree…pre-existing WIP cruft…prevents running the full test suite with mix test." It was knowingly left behind because targeted tests weren't affected.

CI failure signature:
  pre-install mix compile failed:
  lib/sigra_web/components/org_switcher.ex:20 cannot expand Kernel.use/2 while compiling sigra-as-path-dep in test fixture

Goal: find what creates `lib/sigra_web/` in sigra's repo root on a fresh CI clone and remove the source — or if it's a side-effect of running tests, isolate it.
<DATA_END>

## Symptoms

- **Expected behavior:** `MIX_ENV=test mix test` on a fresh clone (no untracked files) compiles and runs the full suite without phantom modules.
- **Actual behavior:** A `lib/sigra_web/` directory appears in the sigra repo root and is picked up by `sigra-as-path-dep` in test fixtures, breaking compilation of 14/23 CI jobs.
- **Error message:** `lib/sigra_web/components/org_switcher.ex:20 cannot expand Kernel.use/2 while compiling sigra-as-path-dep in test fixture`
- **Timeline:** Surfaced after the v1.21 batch / origin/main merge into chore/phase-88-uat-evidence (commit a93f195). Plan 08 SUMMARY (9a1bbdf, 2026-05-02) flagged the cruft as pre-existing.
- **Reproduction:** Push to `chore/phase-88-uat-evidence` → PR #37 CI; or fresh clone + `MIX_ENV=test mix test test/mix/tasks/sigra.install_test.exs:97` reproduces locally.

## Critical files to inspect first

- `test/support/install_fixture.ex` — esp. `setup_tmp_app/1` and `setup_tmp_app_without_install/1` (lines ~42–168) which `phx.new` and `mix compile` the path-dep
- `mix.exs` — `elixirc_paths/1` (currently `["lib"]` for non-test, `["lib", "test/support"]` for test)
- `priv/templates/sigra.install/organizations/components/org_switcher.ex` — the template that gets emitted as `lib/<app>_web/components/org_switcher.ex` after install
- `priv/templates/sigra.install/admin/components/admin_shell.ex` — same shape, second file in the cascade
- `lib/mix/tasks/sigra.install.ex` — to understand whether anything resolves the host web module name as `SigraWeb` instead of `<HostApp>Web`
- `.planning/phases/93-m2m-service-account-tokens-b2b-03/93-08-SUMMARY.md` — has the original "out of scope" admission and may hint at where the cruft came from (look at "Rule 1 - Bug" entries)

## Current Focus

- hypothesis (resolved): The 93-08 fix to `validate_supported_adapter!/1` collapsed two distinct cases into one fallback — "Repo not yet compiled" AND "Repo loaded but has no `__adapter__/0`" both returned `:postgres` instead of raising. This let the `:undetectable_adapter` test in `test/mix/tasks/sigra.install_test.exs:97` slip past the raise guard and run the full installer pipeline against the sigra repo as the current Mix project, generating `lib/sigra_web/...` files there.
- test: `MIX_ENV=test mix test test/mix/tasks/sigra.install_test.exs:97` produced the phantom directory deterministically before the fix; passes (and leaves the repo clean) after the fix.
- expecting: After splitting the two cases — fallback only when `Code.ensure_loaded?` is false, raise when the module is loaded but lacks `__adapter__/0` — both the assertion and the directory contamination are gone.
- next_action: (none — resolved)

## Evidence

- timestamp: 2026-05-02T~14:35Z
  command: `gh run view 25258893126 --log-failed --job 74062762072` (Library tests)
  finding: Library tests job error trace shows `module SigraWeb is not loaded ... lib/sigra_web/components/org_switcher.ex:20 ... lib/sigra_web/components/admin_shell.ex:6 ... lib/sigra_web/auth_error_handler.ex:15`. Module name is fully resolved (`SigraWeb.Components.OrgSwitcher`, NOT literal `<%= web_module %>`), so the file was rendered through EEx with `Mix.Phoenix.base() == "Sigra"` — i.e. the installer ran inside the sigra Mix project.

- timestamp: 2026-05-02T~14:38Z
  command: `gh run view 25258893126 --log-failed --job 74062762053` (Install matrix)
  finding: install_matrix CI failures are NOT the phantom directory. They are `error: undefined function auth_rate_limit/2 (expected TmpAppWeb.Router to define such a function or for it to be imported, but none are available)` from `mix compile --warnings-as-errors` after `mix sigra.install`. Separate generator drift bug — see "Out of session scope" below.

- timestamp: 2026-05-02T~14:42Z
  command: read `lib/mix/tasks/sigra.install.ex:156-174`
  finding: Plan 08 (commit 9a1bbdf, 2026-05-02) changed `validate_supported_adapter!/1` to fall back to `:postgres` "when Repo not loaded". The change collapsed two cases into one: (a) `Code.ensure_loaded?(repo) == false` (Repo not yet compiled), AND (b) Repo loaded but `function_exported?(repo, :__adapter__, 0) == false` (genuinely unknown adapter). The `:undetectable_adapter` test feeds case (b) and now no longer raises.

- timestamp: 2026-05-02T~14:44Z
  command: `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/mix/tasks/sigra.install_test.exs:97`
  finding: Test run produces the cascade `* creating lib/sigra/sigra_admin_policy.ex / * creating lib/sigra_web/components/admin_shell.ex / ...` and fails the `assert_raise Mix.Error` because no raise occurs. Confirms reproduction. After test, `git status` shows `??  lib/sigra_web/` and 9 other untracked installer outputs in the sigra repo root.

- timestamp: 2026-05-02T~14:50Z
  command: edit `lib/mix/tasks/sigra.install.ex` — split `validate_supported_adapter!/1` into a `cond` with three arms: not-loaded → `:postgres` (preserves Plan 08 intent), loaded-no-adapter → `Mix.raise("...Detected an unknown adapter...")`, loaded-with-adapter → only allow `Ecto.Adapters.Postgres`.
  finding: After re-running `mix test test/mix/tasks/sigra.install_test.exs`: 21 tests, 0 failures. Repo working tree shows only `M lib/mix/tasks/sigra.install.ex` — no phantom `lib/sigra_web/`, no other untracked installer outputs.

- timestamp: 2026-05-02T~14:55Z
  command: `mix test test/sigra/install/ test/mix/tasks/`
  finding: 618 tests, 7 failures. Working tree stays clean (no phantom directory). The 7 failures decompose as:
    1. `templates_layout_test:70` — manifest count 50 vs 51 (orchestrator-flagged stale assertion, OUT OF SCOPE)
    2. `core_post_instructions_test:116` — Oban warning copy drift (orchestrator-flagged stale assertion, OUT OF SCOPE)
    3-5. `golden_diff_test:53/66` and `vault_promotion_test:9` — install_fixture tests that fail at `mix compile --warnings-as-errors` inside the generated tmp_app due to the `auth_rate_limit/2` generator-drift bug (NOT in orchestrator's stale-assertion list)
    6-7. `generator_passkeys_opt_out_test:33` (×2) — same `auth_rate_limit/2` failure path
  The phantom-directory bug is fully resolved. The remaining 5 (3-7) failures share a single distinct root cause documented under "Out of session scope" below.

## Eliminated

- The install fixtures (`setup_tmp_app/1`, `setup_tmp_app_without_install/1`) themselves do not contaminate the sigra repo — every `System.cmd` is correctly scoped to a tmp dir under `System.tmp_dir!()`.
- The `purely_additive_test.exs` walker test uses absolute tmp paths for both files and migrations and changes cwd into tmp before invoking `Runner.run` — also clean.
- The various `*_test.exs` files that call `Features.X.files(otp_app: :my_app)` etc. are read-only inspections and never write anywhere.
- The `test/example/` subproject has its own `mix.exs` and never escapes its directory tree.
- The error message about literal `<%= web_module %>` in earlier writeups was a misread — the CI logs show the module name is fully expanded (`SigraWeb.Components.OrgSwitcher`), so the template DID get EEx-evaluated. The bug is not unrendered-template-leakage; it is the installer running with the wrong host (sigra itself).

## Resolution

**Root cause:** Phase 93 Plan 08 (commit 9a1bbdf, 2026-05-02) changed `validate_supported_adapter!/1` in `lib/mix/tasks/sigra.install.ex` to fall back to `:postgres` whenever the repo module's `__adapter__/0` could not be invoked. This collapsed two structurally distinct cases — "Repo not yet compiled" and "Repo loaded but malformed" — into a single permissive branch. The `:undetectable_adapter` unit test in `test/mix/tasks/sigra.install_test.exs:97` exercises the second case via a stub module with no `__adapter__/0`. With the old raise gone, the test's `Install.run(["Accounts", "User", "users"])` invocation proceeded past validation, computed `Mix.Phoenix.otp_app() == :sigra` and `Mix.Phoenix.base() == "Sigra"`, and ran the full feature walker, generating `lib/sigra_web/components/org_switcher.ex`, `lib/sigra_web/components/admin_shell.ex`, `lib/sigra_web/auth_error_handler.ex`, etc. into the sigra repo root.

Once those files existed, every downstream `setup_tmp_app/1` test failed at the post-`deps.get` `mix compile` step because the tmp_app's path-dep view of sigra now contained Phoenix-shape modules referencing an undefined `SigraWeb` namespace.

**Fix:** `lib/mix/tasks/sigra.install.ex` — split `validate_supported_adapter!/1` into three explicit cases:

```elixir
defp validate_supported_adapter!(repo_module) do
  cond do
    not Code.ensure_loaded?(repo_module) ->
      :postgres                                       # Plan 08 case: Repo not yet compiled
    not function_exported?(repo_module, :__adapter__, 0) ->
      Mix.raise("Sigra supports PostgreSQL only. Detected an unknown adapter. ...")
    true ->
      case repo_module.__adapter__() do
        Ecto.Adapters.Postgres -> :postgres
        adapter -> Mix.raise("Sigra supports PostgreSQL only. Detected #{inspect(adapter)}. ...")
      end
  end
end
```

This preserves Plan 08's intent (don't reject a host whose Repo simply hasn't been compiled yet) while restoring the raise guard for the case the test was written to enforce — and which is the actual safety net against running a generator pass with the sigra project as the cwd target.

**Verification:**

- `mix test test/mix/tasks/sigra.install_test.exs` → 21 tests, 0 failures (was 1 failure)
- `git status` after the run → only `M lib/mix/tasks/sigra.install.ex`, no phantom `lib/sigra_web/`, no other untracked installer artifacts
- `mix test test/sigra/install/ test/mix/tasks/` → working tree stays clean throughout; only the 7 unrelated failures (4 stale assertions + 3 from a separate generator drift bug, see below) remain

**Out of session scope (reported up to orchestrator):**

5 install-related test failures (`golden_diff_test:53/66`, `vault_promotion_test:9`, `generator_passkeys_opt_out_test:33` ×2) and the 4 install_matrix CI jobs share a separate generator-drift root cause that the orchestrator's briefing did not flag:

`lib/sigra/install/features/core.ex:525` injects `pipe_through [:browser, :redirect_if_user_is_authenticated, :auth_rate_limit]` into the generated host router, but the corresponding `pipeline :auth_rate_limit do plug Sigra.Plug.RateLimit, ... end` block was never added to the same template's `pipelines` section. Commit 3accda8 (2026-05-01, "feat(api): 96-04 wire rate limit and oauth refresh into active seams") added the `pipe_through` reference and the matching pipeline block to `test/example/lib/example_web/router.ex` but missed updating the generator template at `core.ex` line ~494-516. Every fresh `mix sigra.install` therefore emits a router that fails compile with `undefined function auth_rate_limit/2`.

This is not the phantom-directory bug and is structurally distinct: it ships an invalid generator output rather than polluting the library repo. Recommend a separate `/gsd-quick` (or atomic commit alongside the existing 5 mechanical fixes the orchestrator already enumerated) that adds the missing `pipeline :auth_rate_limit do plug Sigra.Plug.RateLimit, error_handler: #{web_module}.AuthErrorHandler end` block to the `# Sigra authentication` injection content in `core.ex`.
