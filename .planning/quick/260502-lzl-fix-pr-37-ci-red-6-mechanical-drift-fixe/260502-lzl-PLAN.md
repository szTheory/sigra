---
phase: 260502-lzl
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - test/sigra/install/templates_layout_test.exs
  - test/sigra/workers/token_cleanup_test.exs
  - test/sigra/install/features/core_post_instructions_test.exs
  - test/mix/tasks/sigra.install_test.exs
  - lib/sigra/optional_deps.ex
  - mix.exs
  - lib/sigra/install/features/core.ex
autonomous: true
requirements: []
must_haves:
  truths:
    - "templates_layout_test asserts the actual current core template count"
    - "token_cleanup_test asserts the queue name the worker actually uses"
    - "core_post_instructions_test asserts the Oban-absent copy the implementation actually emits"
    - "sigra.install_test :undetectable_adapter assertion matches the raise restored by commit a6fbf63"
    - "OptionalDeps jwt → joken row passes the OptionalDeps validator"
    - "Generator-emitted router compiles cleanly because pipeline :auth_rate_limit is defined alongside the pipe_through reference that uses it"
    - "Full mix test suite green (or near-zero residual) on chore/phase-88-uat-evidence"
  artifacts:
    - path: "test/sigra/install/templates_layout_test.exs"
      provides: "core_files length assertion matching reality"
    - path: "test/sigra/workers/token_cleanup_test.exs"
      provides: "queue assertion matching :sigra_lifecycle (the impl)"
    - path: "test/sigra/install/features/core_post_instructions_test.exs"
      provides: "Oban-absent assertions matching current post_instructions/2 output"
    - path: "lib/sigra/install/features/core.ex"
      provides: "router template with pipeline :auth_rate_limit defined alongside :require_sudo"
  key_links:
    - from: "lib/sigra/install/features/core.ex (pipe_through :auth_rate_limit)"
      to: "lib/sigra/install/features/core.ex (pipeline :auth_rate_limit do ... end)"
      via: "same router template injection block"
      pattern: "pipeline :auth_rate_limit do"
---

<objective>
Close out the 6 mechanical drift fixes that PR #37 CI surfaced after the phantom-`lib/sigra_web/` root cause was already resolved by commit a6fbf63. Each task is its own atomic commit. Five of the six are pure assertion/metadata edits; only task 6 touches generator template logic.

Purpose: Get PR #37 CI green so the v1.21 batch (Phase 93 ship) can land on `main`.
Output: 6 atomic commits on `chore/phase-88-uat-evidence`, full local `mix test` near-zero failures.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
</execution_context>

<context>
@.planning/STATE.md
@.planning/debug/pr37-phantom-sigra-web.md

# Local test prerequisites are documented in CLAUDE.md (Postgres at localhost:5432, postgres/postgres).
# Each task ends with an atomic commit; do NOT batch multiple fixes into one commit.
</context>

<tasks>

<task type="auto">
  <name>Task 1: Update stale core template count assertion (50 → 51)</name>
  <files>test/sigra/install/templates_layout_test.exs</files>
  <action>
Open `test/sigra/install/templates_layout_test.exs` at line 70.

Read the test body once. The current assertion on line 75 reads:

```elixir
assert length(core_files) == 50
```

The `@manifest_post_move` list above (the static expected manifest) is the source of truth — count its entries, and confirm the directory listing now matches it. Per the orchestrator briefing the count grew by one to 51. Verify by counting `@manifest_post_move` entries in the source (do not run the test as a substitute for reading); the assertion below it (`assert core_files == Enum.sort(@manifest_post_move)`) already encodes the manifest.

Edit line 75 to:

```elixir
assert length(core_files) == 51
```

Do NOT touch `@manifest_post_move` itself — if the directory genuinely contains 51 files matching the manifest, the second assertion proves it; this task only updates the redundant cardinality check.

If the manifest count is anything other than 51, surface the discrepancy as a finding (do not silently match whatever the directory has — the manifest is the contract).

Run the focused test:

```bash
PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/install/templates_layout_test.exs
```

Commit:

```
test(install): update core template count assertion 50 → 51
```
  </action>
  <verify>
    <automated>PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/install/templates_layout_test.exs</automated>
  </verify>
  <done>templates_layout_test.exs passes; one atomic commit landed on the branch.</done>
</task>

<task type="auto">
  <name>Task 2: Align token_cleanup_test queue assertion with impl (sigra_mailer → sigra_lifecycle)</name>
  <files>test/sigra/workers/token_cleanup_test.exs</files>
  <action>
**Direction-check FIRST.** Read `lib/sigra/workers/token_cleanup.ex` lines 1–30. The `use Oban.Worker` declaration shows the actual queue. If the implementation says `queue: :sigra_lifecycle`, update the test. If the implementation still says `queue: :sigra_mailer`, STOP — surface as a different bug (the orchestrator's working assumption was wrong) and do not commit anything.

Implementation reference (`lib/sigra/workers/token_cleanup.ex` line ~22):

```elixir
use Oban.Worker,
  queue: :sigra_lifecycle,
  max_attempts: 1
```

Open `test/sigra/workers/token_cleanup_test.exs` at line 61. Update the test name and assertion to the new queue. Current:

```elixir
test "uses sigra_mailer queue" do
  changeset = TokenCleanup.new(%{})
  assert changeset.changes[:queue] == "sigra_mailer"
end
```

After:

```elixir
test "uses sigra_lifecycle queue" do
  changeset = TokenCleanup.new(%{})
  assert changeset.changes[:queue] == "sigra_lifecycle"
end
```

Both the test name and the asserted string must change. The Oban changeset stores the queue as a string ("sigra_lifecycle"), not the atom — confirm by reading the test scaffolding above (line 50) where `Code.ensure_loaded!(TokenCleanup)` runs.

Run focused test:

```bash
PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/workers/token_cleanup_test.exs
```

Commit:

```
test(workers): align token_cleanup queue assertion with :sigra_lifecycle impl
```
  </action>
  <verify>
    <automated>PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/workers/token_cleanup_test.exs</automated>
  </verify>
  <done>token_cleanup_test.exs passes; one atomic commit landed.</done>
</task>

<task type="auto">
  <name>Task 3: Update core_post_instructions Oban-absent copy assertions to match impl</name>
  <files>test/sigra/install/features/core_post_instructions_test.exs</files>
  <action>
The post-install copy emitted by `Sigra.Install.Features.Core.post_instructions/2` for the Oban-absent branch was edited; the test's expected strings drifted.

**Step 1 — Read the impl.** Find the function that emits the "Oban not detected / synchronous mode / To enable async delivery" lines. It lives in `lib/sigra/install/features/core.ex` (or a helper module it calls). Grep for the unique strings:

```bash
grep -n 'Oban not detected\|synchronous mode\|To enable async delivery' lib/sigra/install/features/core.ex
```

If those strings still match the test, the test should already pass — run it to confirm:

```bash
PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/install/features/core_post_instructions_test.exs:116
```

If it fails, capture the actual current output. The test renders `Core.post_instructions(@binding, Report.new()) |> render()` — at the failure site, the actual rendered text is in the assertion error; copy the literal lines.

**Step 2 — Update the assertions at lines 116–124** so each `assert out =~ "..."` matches an actual substring of the current rendered output. Preserve the test's intent: it is checking that when no Oban config is present, the user is told (a) Oban was not detected, (b) the system is in synchronous mode, (c) how to enable async. If any of those three semantic anchors is gone from the impl, surface it as a different bug — do NOT delete an assertion just to make the test pass.

If the test at line 116 passes already but the test at line 126 ("neither config/config.exs nor config/runtime.exs present") fails, fix that one too — it shares the Oban-absent branch and asserts the same copy.

Run focused test:

```bash
PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/install/features/core_post_instructions_test.exs
```

Commit:

```
test(install): align Oban-absent post-instructions assertions with current copy
```

If the test was already green (impl strings match), commit nothing for this task and note "no-op — assertions already match" in your task summary.
  </action>
  <verify>
    <automated>PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/install/features/core_post_instructions_test.exs</automated>
  </verify>
  <done>core_post_instructions_test.exs passes; either an atomic commit landed, or task is a documented no-op.</done>
</task>

<task type="auto">
  <name>Task 4: Verify :undetectable_adapter test (likely no-op after a6fbf63)</name>
  <files>test/mix/tasks/sigra.install_test.exs</files>
  <action>
**Verify-then-no-op-if-passes.** Commit a6fbf63 split `validate_supported_adapter!/1` into three cond arms, restoring the raise for the loaded-no-adapter case. The `:undetectable_adapter` test at line 97 exercises exactly that case.

**Step 1 — Run the focused test FIRST:**

```bash
PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/mix/tasks/sigra.install_test.exs:97
```

Then immediately:

```bash
git status --short
```

The status check is mandatory. If the test creates phantom `lib/sigra_web/` or any other untracked installer output in the sigra repo root, the validation guard is NOT actually back; that would re-open the phantom-directory regression. In that case, surface as a different bug (do not edit the test).

**Step 2 — Decide:**
- If the test PASSES and `git status` is clean → this task is a NO-OP. Do not edit the file. Do not commit. Note "no-op — test passes after a6fbf63" in your task summary.
- If the test FAILS, read it (lines 97–105). Confirm the assertion regex matches the impl's `Mix.raise` message. Current assertion regex:
  ```
  ~r/Sigra supports PostgreSQL only\. Detected an unknown adapter\. mix sigra\.install cannot continue\. See guides\/introduction\/installation\.md/
  ```
  If the regex matches the actual raise text in `lib/mix/tasks/sigra.install.ex` `validate_supported_adapter!/1` (loaded-no-adapter branch) verbatim, the failure is something else — surface it. If the regex drifted, update it to match the impl's literal raise message.

If a real edit is required, commit:

```
test(install): align :undetectable_adapter raise regex with current Mix.raise text
```
  </action>
  <verify>
    <automated>PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/mix/tasks/sigra.install_test.exs && git status --porcelain | grep -v '^M  test/mix/tasks/sigra.install_test.exs' | grep -v '^$' | wc -l | tr -d ' ' | grep -qx 0</automated>
  </verify>
  <done>Test passes AND working tree contains no phantom installer artifacts. Either zero edits (no-op) or one atomic commit.</done>
</task>

<task type="auto">
  <name>Task 5: Align jwt → joken OptionalDeps row with mix.exs declaration</name>
  <files>lib/sigra/optional_deps.ex, mix.exs</files>
  <action>
The CI signal was: "1 enforced optional dependency row(s) currently invalid" from the OptionalDeps validator, naming the jwt → joken row.

**Step 1 — Read both sides:**

```bash
grep -n 'joken' mix.exs
grep -n -A 12 'jwt: %{' lib/sigra/optional_deps.ex
```

`mix.exs` line ~101 declares `{:joken, "~> 2.6", optional: true}`.
`lib/sigra/optional_deps.ex` jwt spec (around line 155) declares `dependency: :joken, dependency_spec: "~> 2.6", dependency_modules: [Joken]`.

These appear to align on first read, so the "invalid" signal must be something else. Likely candidates:
1. The OptionalDeps validator itself (a doctor/test that walks `feature_specs_map`) is reporting an invalid row — find the validator and read what it actually checks. Search:
   ```bash
   grep -rn 'enforced optional dependency\|enforced.*invalid' lib/ test/
   ```
2. `dependency_modules: [Joken]` may not match what the validator expects (e.g., it might want a specific submodule or the module may not be loadable in the test env without the optional dep).
3. The `dependency_spec` may need to align with a tighter constraint (e.g., the actual installed version vs. declared range).

**Step 2 — Locate the validator and its failure mode.** Run the doctor or whatever test surfaces "1 enforced optional dependency row(s) currently invalid":

```bash
PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test --include doctor 2>&1 | grep -i -A 5 'invalid\|joken\|jwt'
```

or check for a dedicated test:

```bash
grep -rn 'enforced optional dependency\|optional_deps.*valid\|validate.*optional' test/
```

**Step 3 — Decide canonical side and align.** mix.exs is the ground truth for what dependencies are declared; `optional_deps.ex` metadata describes them for the doctor and remediation surface. If the version spec drifted, update one to match the other (prefer keeping mix.exs as canonical and updating optional_deps.ex). If it's a `dependency_modules` mismatch, fix the metadata to name the module the validator can actually `Code.ensure_loaded?/1`.

Surface findings explicitly in the commit body — do not just change a string and call it done.

Commit:

```
fix(optional_deps): align jwt → joken enforcement metadata with mix.exs

[brief explanation of which side was canonical and what changed]
```
  </action>
  <verify>
    <automated>PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test --include doctor 2>&1 | tee /tmp/sigra_optional_deps_check.log; ! grep -qi 'enforced optional dependency row(s) currently invalid\|jwt.*invalid' /tmp/sigra_optional_deps_check.log</automated>
  </verify>
  <done>OptionalDeps validator reports zero invalid enforced rows for jwt → joken; one atomic commit landed with canonical-side rationale in the message.</done>
</task>

<task type="auto">
  <name>Task 6: Add missing pipeline :auth_rate_limit definition to router template</name>
  <files>lib/sigra/install/features/core.ex</files>
  <action>
**This is the only task that touches generator template logic.** Commit 3accda8 (2026-05-01) added `pipe_through [:browser, :redirect_if_user_is_authenticated, :auth_rate_limit]` at `lib/sigra/install/features/core.ex:525` but did NOT add the matching `pipeline :auth_rate_limit do ... end` block to the same template's pipelines section.

**Canonical reference** — the manually-edited `test/example/lib/example_web/router.ex:65–67`:

```elixir
pipeline :auth_rate_limit do
  plug Sigra.Plug.RateLimit, error_handler: ExampleWeb.AuthErrorHandler
end
```

**Edit target** — `lib/sigra/install/features/core.ex` around lines 502–516 inside the `content = """ ... """` heredoc that defines the injected router content. The existing pipelines block (already in the template) looks like:

```elixir
      pipeline :require_authenticated do
        plug :require_authenticated_user
        plug :require_mfa
      end

      pipeline :require_sudo do
        plug Sigra.Plug.RequireSudo, error_handler: #{web_module}.AuthErrorHandler
      end

      # Phase 14 Plan 03 / Phase 92 (CR-01): organization-aware pipeline (opt-in).
      ...
      pipeline :require_org do
        plug Sigra.Plug.RequireMembership, error_handler: #{web_module}.AuthErrorHandler
      end
```

Add the new pipeline alongside `:require_sudo` (between `:require_sudo` and the `:require_org` comment block), so the order matches the canonical example router (`:require_authenticated` → `:require_sudo` → `:auth_rate_limit` → admin/org pipelines). Use the `#{web_module}` interpolation that the surrounding pipelines use — NOT a hardcoded module name:

```elixir
      pipeline :auth_rate_limit do
        plug Sigra.Plug.RateLimit, error_handler: #{web_module}.AuthErrorHandler
      end
```

Indentation: match the existing pipelines in the heredoc — the heredoc uses 6-space indentation for the `pipeline` lines.

**Validation flow:**

1. Re-read the edited block to confirm indentation and `#{web_module}` interpolation.
2. Run install_fixture-backed tests that previously failed with `undefined function auth_rate_limit/2`:
   ```bash
   PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test \
     test/sigra/install/golden_diff_test.exs:53 \
     test/sigra/install/golden_diff_test.exs:66 \
     test/sigra/install/vault_promotion_test.exs:9 \
     test/sigra/install/generator_passkeys_opt_out_test.exs:33
   ```
   These should now compile the generated router cleanly. If `golden_diff_test` reports a snapshot mismatch (because the golden file was captured before the pipeline existed), update the golden snapshot — that is part of the same generator-drift fix and belongs in this commit. The other three tests should pass without snapshot changes.

3. After all four pass, do a `git status` and confirm only the expected files changed (`lib/sigra/install/features/core.ex` plus possibly a golden snapshot file under `test/sigra/install/`).

Commit:

```
fix(install): add pipeline :auth_rate_limit to generated router template

Commit 3accda8 added pipe_through :auth_rate_limit to the generated router
but missed defining the matching pipeline block. Every fresh `mix sigra.install`
emitted a router that failed compile with undefined function auth_rate_limit/2.
Restores parity with test/example/lib/example_web/router.ex.
```

If a golden snapshot was updated, mention it in the commit body.
  </action>
  <verify>
    <automated>PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/install/golden_diff_test.exs test/sigra/install/vault_promotion_test.exs test/sigra/install/generator_passkeys_opt_out_test.exs</automated>
  </verify>
  <done>Generated router compiles cleanly; the 5 install_fixture-backed failures from the debug session are resolved; one atomic commit landed (golden snapshot update included if needed).</done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <name>Task 7: Full-suite verification + push</name>
  <what-built>All 6 mechanical drift fixes shipped as atomic commits on chore/phase-88-uat-evidence.</what-built>
  <how-to-verify>
1. Run the full suite locally:

   ```bash
   PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test
   ```

   Expected: 0 failures, or near-zero with any residuals being unrelated to the 6 fixes (flag those explicitly).

2. Sanity-check working tree is clean (no phantom installer outputs):

   ```bash
   git status --porcelain | grep -E '^\?\?' | grep -v '\.planning/' | grep -v '\.cache/'
   ```

   Expected: empty output. Any `??  lib/sigra_web/` or `??  lib/sigra/sigra_admin_policy.ex` would indicate the phantom-directory regression returned and one of the earlier task verifications missed it.

3. Review the 6 commits:

   ```bash
   git log --oneline -7
   ```

   Expect 6 atomic commits (or 5 if task 4 was a no-op). Each subject line names one fix.

4. Push and confirm CI:

   ```bash
   git push origin chore/phase-88-uat-evidence
   gh pr checks 37 --watch
   ```

5. Report back: number of commits, any residual local failures, and CI status.
  </how-to-verify>
  <resume-signal>Type "approved" once full suite is green and PR #37 CI is green or near-green; otherwise describe the residuals.</resume-signal>
</task>

</tasks>

<verification>
- All 6 fixes are atomic commits (or 5 if task 4 was a no-op).
- `mix test` full suite reports 0 failures (or only documented unrelated residuals).
- `git status` clean — no phantom `lib/sigra_web/` or installer-output untracked files in the sigra repo.
- PR #37 CI green or substantially recovered (the phantom-directory job class was 14/16 of the failures; this batch closes the remaining drift-class failures).
</verification>

<success_criteria>
- Local full `mix test` passes (or near-zero, with residuals flagged as out-of-scope).
- 6 atomic commits land on `chore/phase-88-uat-evidence` (5 if task 4 no-op).
- Working tree stays clean throughout — no installer artifact contamination.
- PR #37 CI follows green on push.
</success_criteria>

<output>
After completion, no SUMMARY file is required for /gsd-quick mode — the orchestrator's checkpoint return is sufficient. If the user wants a debrief, append it to `.planning/debug/pr37-phantom-sigra-web.md` under a new `## Followup: 6 mechanical drift fixes` section.
</output>
