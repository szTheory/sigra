---
phase: 24-repair-phase-16-17-organizations-generator-templates
plan: 01
type: execute
wave: 0
depends_on: []
files_modified:
  - priv/templates/sigra.install/organizations/live/invitation_accept_live.ex
  - priv/templates/sigra.install/core/organization_invitation_email.ex
  - priv/templates/sigra.install/organizations/organization_invitation_email.ex
  - priv/templates/sigra.install/core/emails.ex
  - lib/sigra/install/features/organizations.ex
  - test/sigra/install/features/organizations_test.exs
  - test/sigra/install/template_render_test.exs
  - test/sigra/install/template_syntax_test.exs
  - test/sigra/install/features/coverage_test.exs
  - test/fixtures/install_golden/tree/**
  - test/fixtures/install_golden/STDOUT.txt
autonomous: false
requirements: []
must_haves:
  truths:
    - "`mix sigra.install --yes` (default, Features.Organizations enabled) runs end-to-end without a template compile error."
    - "`mix test test/sigra/install/` returns to a clean baseline — specifically, the six pre-existing failures surfaced by Phase 18 Plan 18-01 Task 3 are eliminated with no new regressions."
    - "Phase 18 Plan 18-03 (install CI matrix `--yes` leg) is unblocked."
  artifacts:
    - path: "priv/templates/sigra.install/organizations/live/invitation_accept_live.ex"
      provides: "D-01 dispatcher refactor — no `<%= case @branch do %>` inside `~H` heredoc"
      contains: "defp render_branch"
    - path: "priv/templates/sigra.install/organizations/organization_invitation_email.ex"
      provides: "D-04.2 moved fragment — new canonical location under organizations/"
    - path: "lib/sigra/install/features/organizations.ex"
      provides: "D-04.1 registration of organization_invitation_email.ex in Features.Organizations.files/1"
      contains: "organizations/organization_invitation_email.ex"
    - path: "priv/templates/sigra.install/core/emails.ex"
      provides: "D-04.3 conditional EEx wrap of organization_invitation/4 + helpers; reworded comment"
      contains: "if organizations? do"
    - path: "test/sigra/install/template_render_test.exs"
      provides: "D-06.1 generator-render unit test — walks organizations/**/*.ex"
    - path: "test/sigra/install/template_syntax_test.exs"
      provides: "D-06.3 HEEx-inside-EEx guard"
    - path: "test/sigra/install/features/coverage_test.exs"
      provides: "D-06.2 per-feature coverage lint"
  key_links:
    - from: "priv/templates/sigra.install/organizations/live/invitation_accept_live.ex"
      to: "runner.ex EEx.eval_file"
      via: "{render_branch(assigns)} curly-brace HEEx interpolation"
      pattern: "\\{render_branch\\(assigns\\)\\}"
    - from: "priv/templates/sigra.install/core/emails.ex"
      to: "organizations? binding flag (sigra.install.ex:114)"
      via: "<% if organizations? do %> conditional block"
      pattern: "if organizations\\? do"
    - from: "lib/sigra/install/features/organizations.ex"
      to: "priv/templates/sigra.install/organizations/organization_invitation_email.ex"
      via: "files/1 tuple entry"
      pattern: "organizations/organization_invitation_email\\.ex"
---

<planner_notes>
**TDD-first wave ordering (Revision 1 — 2026-04-14, checker Blocker 1 fix):** The three regression-test-creation tasks (D-06.1/.2/.3) now land in Wave 0 BEFORE the fixes. Each Wave 0 task's `<automated>` verify is scoped to syntactic-only checks — file exists, `mix compile --warnings-as-errors` does not break, and grep confirms at least one `test "..."` / `describe "..."` macro. The Wave 0 tests are EXPECTED to be RED against the current buggy templates at Wave 0 execution time — that redness is the proof that the tests catch the DEF-18-01 / DEF-18-02 bug classes. The test pass/fail transition (RED → GREEN) is verified on the Wave 1 and Wave 2 fix tasks (24-01-04 and 24-01-07) via expanded acceptance criteria. This matches the Nyquist-8a + Nyquist-8d contract: no `<automated>` command references a test file that does not yet exist at its own wave's execution time.

**Task IDs (post-revision):**
- Wave 0 (TDD regression guards — test files land red-first):
  - 24-01-01 — D-06.1 template_render_test.exs (syntactic check; RED until 24-01-04)
  - 24-01-02 — D-06.2 features/coverage_test.exs (syntactic check; RED until 24-01-07)
  - 24-01-03 — D-06.3 template_syntax_test.exs (syntactic check; RED until 24-01-04)
- Wave 1 (fix the DEF-18-01 compile bug + verify already-on-disk injection templates):
  - 24-01-04 — D-01 dispatcher refactor of invitation_accept_live.ex — flips 24-01-01 + 24-01-03 RED → GREEN
  - 24-01-05 — D-02 verify organizations/router_injection.ex + organizations/user_auth_on_mount_assign_user_organizations.ex exist on disk (no creation)
- Wave 2 (fix the DEF-18-02 feature-ownership drift):
  - 24-01-06 — D-04.1/.2 move organization_invitation_email.ex from core/ to organizations/ + register in Features.Organizations.files/1
  - 24-01-07 — D-04.3 conditional-wrap organization_invitation/4 + helpers in core/emails.ex + reword # comment — flips 24-01-02 RED → GREEN
- Wave 3 (integration + CI):
  - 24-01-08 — D-05 regenerate golden fixture (CHECKPOINT — visual diff review)
  - 24-01-09 — D-06.4 install_matrix CI leg verification (CHECKPOINT — PR-based or act-based)

**Scope sanity (checker Warning 3):** 9 tasks in one plan exceeds the 2–3 target for a standard plan. Accepted per D-03 ("Plan shape — single repair plan") with checkpoint-based natural boundaries at Task 24-01-08 (golden rebless) and Task 24-01-09 (CI matrix verify). The single-plan constraint is load-bearing: DEF-18-01 and DEF-18-02 are interrelated (golden rebless is gated on the dispatcher fix), so splitting into 24-01/24-02 would force a dependency with no independent shipping value.

**XML entity hygiene (checker Note 5):** All `<automated>` commands in this revision use plain grep patterns — no `&lt;` / `&gt;` entity escaping that would break at execute-plan shell-out time. Tag-collision detection relies on keyword-only grep (e.g., `grep -c "case @branch do"` instead of `grep -c "<%= case @branch do %>"`).

Plan has checkpoints → `autonomous: false`.
</planner_notes>

<objective>
Execute the single repair plan for DEF-18-01 and DEF-18-02, restoring the `mix sigra.install` default leg and `mix test test/sigra/install/` baseline.

Purpose: Phase 18 Plan 18-03 (install CI matrix `--yes` leg) is blocked by two pre-existing bugs shipped in Phases 16/17 — neither caught before Phase 18 Wave 1 registered `Features.Organizations`. Phase 24 fixes them atomically, lands four regression tests that guard the bug *classes*, and regenerates the golden fixture.

Output:
- `invitation_accept_live.ex` refactored to dispatcher shape (D-01).
- `organization_invitation_email.ex` moved from `core/` to `organizations/` + registered in `Features.Organizations.files/1` (D-04.1/.2).
- `core/emails.ex` `organization_invitation/4` + helpers wrapped in `<% if organizations? do %>` + `#` comment reworded (D-04.3 + Finding 5).
- Three new tests: `template_render_test.exs`, `template_syntax_test.exs`, `features/coverage_test.exs` (D-06.1/.2/.3).
- Regenerated golden fixture (D-05).
- Full `mix test test/sigra/install/` green; `install_matrix` CI leg green on both `""` and `"--no-organizations"` (D-06.4).
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/24-repair-phase-16-17-organizations-generator-templates/24-CONTEXT.md
@.planning/phases/24-repair-phase-16-17-organizations-generator-templates/24-RESEARCH.md
@.planning/phases/24-repair-phase-16-17-organizations-generator-templates/24-VALIDATION.md
@.planning/phases/18-backfill-organizations-generator-wiring/deferred-items.md
@.planning/phases/11-generator-feature-system/11-01-SUMMARY.md

<interfaces>
<!-- Key contracts executor needs. Extracted from codebase. -->

From lib/sigra/install/runner.ex:80-82 (EEx entry point):
```elixir
template_path = find_template(source)
content = EEx.eval_file(template_path, binding)
Mix.Generator.create_file(target, content)
```

From lib/mix/tasks/sigra.install.ex:97-119 (binding construction — MUST be the fixture binding shape for template_render_test.exs):
```elixir
# The `organizations?` key (with trailing `?`) lives at line 114:
organizations?: Keyword.get(opts, :organizations, true),
```

From priv/templates/sigra.install/core/user.ex:4 (EEx conditional precedent — BARE key, no `@`):
```eex
<%= if binary_id do %>
  @primary_key {:id, :binary_id, autogenerate: true}
<% end %>
```

From lib/sigra/install/features/organizations.ex:40-97 (files/1 tuple shape):
```elixir
{:eex, "organizations/<source>.ex", Path.join(["lib", otp_app, "<target>.ex"])}
```

From lib/sigra/install/features/organizations.ex:155-167 (read_template! callsites for D-02 verification):
```elixir
defp router_injection(otp_app) do
  content = read_template!("organizations/router_injection.ex")
  ...
end

defp user_auth_on_mount_injection(otp_app, web) do
  content = read_template!("organizations/user_auth_on_mount_assign_user_organizations.ex")
  ...
end
```

From priv/templates/sigra.install/organizations/live/invitation_accept_live.ex:228-253 (the file being refactored — current state):
```elixir
@impl true
def render(assigns) do
  ~H"""
  <div id="invitation-accept-page">
    <.flash kind={:info} flash={@flash} />
    <.flash kind={:error} flash={@flash} />

    <%= case @branch do %>
      <% :signup -> %>
        {render_signup(assigns)}
      <% :accept -> %>
        {render_accept(assigns)}
      <% :mismatch -> %>
        {render_mismatch(assigns)}
      <% :invalid -> %>
        {render_invalid(assigns)}
      <% :expired -> %>
        {render_expired(assigns)}
      <% :revoked -> %>
        {render_revoked(assigns)}
      <% :already_accepted -> %>
        {render_already_accepted(assigns)}
    <% end %>
  </div>
  """
end
```

Per-branch helpers already exist at lines 255-412:
- render_signup/1 (line 255)
- render_accept/1 (line 299)
- render_mismatch/1 (line 337)  # Jetstream #907 invariant — ZERO accept controls
- render_invalid/1 (line 366)
- render_expired/1 (line 378)
- render_revoked/1 (line 390)
- render_already_accepted/1 (line 402)

From priv/templates/sigra.install/core/emails.ex:696-801 (the block to wrap — current state):
- Lines 696-700: `#` comment containing literal `OrganizationInvitationEmail` — MUST be reworded to remove that substring.
- Line 702-791: `@doc """..."""` + `def organization_invitation(invitation, org, inviter, accept_url) when is_binary(accept_url) do ... end`.
- Lines 793-799: `defp inviter_display_name(inviter) do ... end` — only used by `organization_invitation/4`.
- Line 801: `defp humanize_role(role), do: ...` — only used by `organization_invitation/4`.
- All three MUST be inside the same `<% if organizations? do %> ... <% end %>` block.
</interfaces>

<research_anchors>
- Finding 1 — `EEx.eval_file/2` with keyword binding uses BARE key (`organizations?`), NOT `@organizations?`. Precedent: `core/user.ex:4`.
- Finding 3 — `Features.Core.files/1` does NOT currently register `organization_invitation_email.ex`. D-04.4's "remove from Core" is a no-op. Do NOT edit `Features.Core.files/1`.
- Finding 5 — After the move, `core/` drops from 48 → 47, so `IsolationTest` `== 47` and `TemplatesLayoutTest` hardcoded manifest self-correct. Do NOT edit either test's count assertion.
- Finding 5 (secondary) — `IsolationTest.strip_docstrings/1` strips `@doc`/`@moduledoc` heredocs but NOT `#` comments. Line 698's `# Canonical inline copy of the OrganizationInvitationEmail fragment` MUST be reworded to remove the literal `OrganizationInvitation` substring — the conditional EEx wrap alone is insufficient.
- Finding 8 — `install_matrix` CI leg already exists at `.github/workflows/ci.yml:151-223` with `matrix.flags` = `["", "--no-organizations"]`. No YAML edits needed.
- Finding 10 — Golden fixture rebless is manual per `.planning/phases/11-generator-feature-system/11-01-SUMMARY.md`. No `mix sigra.install.golden` task exists.
</research_anchors>
</context>

<tasks>

<task type="auto" tdd="false">
  <name>Task 24-01-01 (Wave 0): D-06.1 — Create template_render_test.exs (generator-render unit test for organizations/**/*.ex)</name>
  <files>test/sigra/install/template_render_test.exs</files>
  <read_first>
    - lib/mix/tasks/sigra.install.ex (lines 97-119 — `build_binding/4` — canonical binding shape)
    - lib/sigra/install/runner.ex (line 60 — `migration_timestamps: %{}` added per feature)
    - test/sigra/install/features/core_test.exs (lines 20-41 — existing `@binding` module attribute shape to mirror)
    - 24-RESEARCH.md Finding 6 (minimal render binding definition)
    - test/sigra/install/isolation_test.exs (for conventions: `use ExUnit.Case, async: true`, flat module name under `Sigra.Install.*`)
  </read_first>
  <action>
    **TDD-first (Wave 0):** This task lands the regression test BEFORE the fix (Task 24-01-04). The test file will be RED against the current buggy `invitation_accept_live.ex` — that redness is the proof that the test catches the DEF-18-01 bug class. This Wave 0 task ONLY asserts the test file exists, compiles, and defines at least one `test`/`describe` macro. The test pass/fail transition is verified on Task 24-01-04 (Wave 1).

    Create the new file `test/sigra/install/template_render_test.exs` with the following contents:

    ```elixir
    defmodule Sigra.Install.TemplateRenderTest do
      @moduledoc """
      D-06.1 regression guard for Phase 24.

      Walks every `.ex` template under
      `priv/templates/sigra.install/organizations/` and verifies:

      1. `EEx.eval_file/2` renders the file without raising.
      2. The rendered content parses as valid Elixir via
         `Code.string_to_quoted/1`.

      This catches the DEF-18-01 bug class (HEEx inside EEx causing
      `CompileError: undefined variable "assigns"`) in a fast, narrow
      unit test that does NOT require the full `InstallFixture` harness.
      """
      use ExUnit.Case, async: true

      @moduletag :install

      # Fixture binding matches `lib/mix/tasks/sigra.install.ex:97-119` plus
      # `migration_timestamps: %{}` added by `lib/sigra/install/runner.ex:60`.
      @render_binding [
        web_module: "FixtureAppWeb",
        app_module: "FixtureApp",
        context_module: "FixtureApp.Accounts",
        context_alias: "Accounts",
        schema_module: "FixtureApp.Accounts.User",
        schema_alias: "User",
        table_name: "users",
        app_name: "FixtureApp",
        otp_app: :fixture_app,
        from_email: "noreply@example.com",
        log_in_url: "/users/log_in",
        repo_module: "FixtureApp.Repo",
        binary_id: true,
        live: true,
        api: false,
        jwt: false,
        organizations?: true,
        adapter: :postgres,
        reset_password_url: "http://localhost:4000/users/reset-password",
        settings_url: "http://localhost:4000/users/settings",
        opts: [live: true, api: false, jwt: false, binary_id: true, organizations: true],
        migration_timestamps: %{}
      ]

      describe "organizations/**/*.ex templates" do
        for path <- Path.wildcard("priv/templates/sigra.install/organizations/**/*.ex") do
          @path path

          test "renders and parses: #{@path}" do
            content =
              try do
                EEx.eval_file(@path, @render_binding)
              rescue
                e ->
                  flunk(
                    "EEx.eval_file raised for #{@path}: #{inspect(e)}\\n" <>
                      "Usual cause: HEEx `<%= ... %>` inside a `~H\\\"\\\"\\\"` heredoc where EEx sees `@assigns` first. " <>
                      "Fix by lifting the case into Elixir and using `{...}` curly-brace HEEx interpolation."
                  )
              end

            assert is_binary(content), "expected binary, got #{inspect(content)}"

            assert {:ok, _ast} = Code.string_to_quoted(content, file: @path),
                   "rendered content of #{@path} is not valid Elixir"
          end
        end
      end
    end
    ```

    Notes:
    - Module name: `Sigra.Install.TemplateRenderTest` (flat, matches `Sigra.Install.IsolationTest` / `Sigra.Install.TemplatesLayoutTest` conventions per 24-RESEARCH.md Finding 7).
    - `async: true` — pure function calls, no filesystem writes.
    - `for path <- Path.wildcard(...)` is evaluated AT COMPILE TIME, so each template gets its own test case with its own descriptive name. When a new template is added under `organizations/`, it is picked up automatically on next compile.
    - Scope intentionally limited to `organizations/**/*.ex` per D-06.1 (24-CONTEXT.md Deferred Ideas explicitly defers extending to `core/`).
    - `Path.wildcard` with `**/*.ex` does NOT match `.exs` migration files — matches 24-RESEARCH.md Finding 6.

    DO NOT:
    - Add any `core/` path to the wildcard (deferred per CONTEXT.md).
    - Replace `try/rescue` with `assert_raise` — we want the test to FAIL on exception, not pass.
    - Use `Code.compile_string/1` — it pollutes the runtime ETS table. `Code.string_to_quoted/1` is the right tool.
  </action>
  <verify>
    <automated>test -f test/sigra/install/template_render_test.exs && mix compile --warnings-as-errors 2>&1 | tail -5 && grep -cE '^[[:space:]]*(test|describe) "' test/sigra/install/template_render_test.exs</automated>
  </verify>
  <acceptance_criteria>
    - File `test/sigra/install/template_render_test.exs` exists.
    - `grep -c "defmodule Sigra.Install.TemplateRenderTest" test/sigra/install/template_render_test.exs` returns `1`.
    - `grep -c "Path.wildcard" test/sigra/install/template_render_test.exs` returns at least `1`.
    - `grep -c "organizations?" test/sigra/install/template_render_test.exs` returns at least `1` (fixture binding uses bare key).
    - `mix test test/sigra/install/template_render_test.exs` exits 0 AND the output shows at least 10 individual test cases passing (one per organizations template — the current tree has 10+ .ex files under `organizations/`).
    - The test for `invitation_accept_live.ex` specifically appears in the pass list: `mix test test/sigra/install/template_render_test.exs 2>&1 | grep "invitation_accept_live"` returns a passing line.
    - The test for the moved fragment appears: `mix test test/sigra/install/template_render_test.exs 2>&1 | grep "organization_invitation_email"` returns a passing line.
    - Regression validation (one-shot, deferred until after Task 24-01-04 lands): revert Task 24-01-04 locally in a scratch branch, run `mix test test/sigra/install/template_render_test.exs`, confirm the `invitation_accept_live` test FAILS with an `EEx.eval_file raised` message, then restore. (This is a post-Wave-1 spot-check, not a Wave 0 acceptance. Document the result in the Wave 1 commit message for Task 24-01-04.)
  </acceptance_criteria>
  <done>
    `test/sigra/install/template_render_test.exs` exists, runs one test per `organizations/**/*.ex` template, renders via `EEx.eval_file/2` with the full binding, parses the output via `Code.string_to_quoted/1`. All tests pass. Regression spot-check confirms the test catches the DEF-18-01 bug class.
  </done>
</task>

<task type="auto" tdd="false">
  <name>Task 24-01-02 (Wave 0): D-06.2 — Create features/coverage_test.exs (per-feature file-coverage lint)</name>
  <files>test/sigra/install/features/coverage_test.exs</files>
  <read_first>
    - lib/sigra/install/features/core.ex (full file — especially `files/1` + `migrations/1` shape)
    - lib/sigra/install/features/organizations.ex (full file — especially `files/1` + `migrations/1` + `injections/1` with `read_template!` callsites at 156/167)
    - 24-RESEARCH.md Finding 9 (tuple shape + source-path extraction)
    - 24-RESEARCH.md Open Question 3 (how coverage lint handles injection templates — use whitelist approach)
  </read_first>
  <action>
    **TDD-first (Wave 0):** This task lands the regression test BEFORE the fix (Task 24-01-07). The test file will be RED against the current tree because `organization_invitation_email.ex` is orphaned under `core/` with no feature owner. This Wave 0 task ONLY asserts the test file exists, compiles, and defines at least one `test`/`describe` macro. The test pass/fail transition is verified on Task 24-01-07 (Wave 2, after the file move).

    Create `test/sigra/install/features/coverage_test.exs` with a data-driven test that walks each feature's subdir and asserts every on-disk `.ex`/`.exs` file is either registered in `feat.files/1`, referenced by `feat.migrations/1`, or on an explicit injection-template whitelist.

    ```elixir
    defmodule Sigra.Install.Features.CoverageTest do
      @moduledoc """
      D-06.2 regression guard for Phase 24.

      For each `Sigra.Install.Feature` module, walks the on-disk subtree
      under `priv/templates/sigra.install/<subdir>/` and asserts every
      file is "owned" — meaning it is either:

      1. Referenced by `feat.files/1` as `{:eex, source_path, _}` / `{:text, source_path, _}`, OR
      2. Referenced by `feat.migrations/1` as `{_key, source_path, _}`, OR
      3. On the explicit `@injection_whitelist` for that feature (templates
         read via `read_template!/1` from inside `feat.injections/1`).

      Prevents the drift class that caused DEF-18-02 (template orphaned
      on disk with no feature owner) and DEF-18-01 Failures 2 & 3
      (injection templates missing on disk).
      """
      use ExUnit.Case, async: true

      @moduletag :install

      @template_root "priv/templates/sigra.install"

      # Fixture binding — matches `Features.*.files/1` argument contract.
      @binding [
        otp_app: :fixture_app,
        web_module: "FixtureAppWeb",
        app_module: "FixtureApp",
        context_module: "FixtureApp.Accounts",
        context_alias: "Accounts",
        schema_module: "FixtureApp.Accounts.User",
        schema_alias: "User",
        table_name: "users",
        app_name: "FixtureApp",
        from_email: "noreply@example.com",
        log_in_url: "/users/log_in",
        repo_module: "FixtureApp.Repo",
        binary_id: true,
        live: true,
        api: false,
        jwt: false,
        organizations?: true,
        adapter: :postgres,
        reset_password_url: "http://localhost:4000/users/reset-password",
        settings_url: "http://localhost:4000/users/settings",
        opts: [],
        migration_timestamps: %{}
      ]

      # Templates read by Features.*.injections/1 via read_template!/1.
      # Whitelisted here because they are NOT returned by files/1 — they
      # become injection *content*, not standalone generated files.
      @injection_whitelist %{
        Sigra.Install.Features.Core => [],
        Sigra.Install.Features.Organizations => [
          "organizations/router_injection.ex",
          "organizations/user_auth_on_mount_assign_user_organizations.ex"
        ]
      }

      @features [
        {Sigra.Install.Features.Core, "core"},
        {Sigra.Install.Features.Organizations, "organizations"}
      ]

      for {feature, subdir} <- @features do
        @feature feature
        @subdir subdir

        test "every file under #{@subdir}/ is owned by #{inspect(@feature)}" do
          on_disk =
            Path.wildcard(Path.join([@template_root, @subdir, "**", "*.{ex,exs}"]))
            |> Enum.map(&Path.relative_to(&1, @template_root))
            |> MapSet.new()

          from_files =
            @feature.files(@binding)
            |> Enum.map(fn
              {:eex, source, _target} -> source
              {:text, source, _target} -> source
            end)
            |> MapSet.new()

          from_migrations =
            @feature.migrations(@binding)
            |> Enum.map(fn {_key, source, _target} -> Path.join(@subdir, source) |> normalize() end)
            |> MapSet.new()

          from_whitelist = MapSet.new(Map.fetch!(@injection_whitelist, @feature))

          owned = from_files |> MapSet.union(from_migrations) |> MapSet.union(from_whitelist)

          orphans = MapSet.difference(on_disk, owned) |> MapSet.to_list() |> Enum.sort()

          assert orphans == [],
                 "#{inspect(@feature)} has orphan templates under #{@subdir}/:\\n" <>
                   Enum.map_join(orphans, "\\n", &"  - #{&1}") <>
                   "\\n\\nEither register them in files/1, migrations/1, or add them to " <>
                   "@injection_whitelist in this test if they are read via read_template!/1."
        end
      end

      # Migrations return tuples like `{:organizations, "organizations/migration.exs", "create_organizations.exs"}`
      # where the middle element is already relative to @template_root. Normalize defensively.
      defp normalize(path), do: Path.relative_to(path, ".")
    end
    ```

    Critical implementation details:
    - `@injection_whitelist` for `Features.Organizations` MUST contain `router_injection.ex` and `user_auth_on_mount_assign_user_organizations.ex` — these are read via `read_template!/1` inside `Features.Organizations.injections/1` at lines 156 and 167. Without the whitelist, they would show as orphans.
    - `Features.Core` has no injection whitelist today (its injections use inline strings).
    - `Path.wildcard` with `{ex,exs}` picks up both `.ex` templates AND `.exs` migration files. The migrations whitelist path construction must match the on-disk shape.
    - Test module name: `Sigra.Install.Features.CoverageTest` at `test/sigra/install/features/coverage_test.exs` (mirrors `Sigra.Install.Features.CoreTest` / `Sigra.Install.Features.OrganizationsTest` convention).

    DO NOT:
    - Hand-enumerate each file (defeats the purpose — it should auto-discover).
    - Extend the whitelist beyond the two injection templates. If a template shows up as orphan, the fix is to register it in `files/1` — not to whitelist it.
  </action>
  <verify>
    <automated>test -f test/sigra/install/features/coverage_test.exs && mix compile --warnings-as-errors 2>&1 | tail -5 && grep -cE '^[[:space:]]*(test|describe) "' test/sigra/install/features/coverage_test.exs</automated>
  </verify>
  <acceptance_criteria>
    - File `test/sigra/install/features/coverage_test.exs` exists.
    - `grep -c "defmodule Sigra.Install.Features.CoverageTest" test/sigra/install/features/coverage_test.exs` returns `1`.
    - `grep -c "organizations/router_injection.ex" test/sigra/install/features/coverage_test.exs` returns `1` (whitelist entry).
    - `grep -c "organizations/user_auth_on_mount_assign_user_organizations.ex" test/sigra/install/features/coverage_test.exs` returns `1` (whitelist entry).
    - `mix test test/sigra/install/features/coverage_test.exs` exits 0.
    - Both feature tests appear in the pass list: `mix test test/sigra/install/features/coverage_test.exs 2>&1 | grep -cE "every file under (core|organizations)/ is owned"` returns `2`.
    - Regression spot-check: introduce a dummy `priv/templates/sigra.install/organizations/orphan_test.ex` file on a scratch branch, run `mix test test/sigra/install/features/coverage_test.exs`, confirm the organizations test FAILS with the orphan listed, then delete the dummy and confirm the test passes again.
  </acceptance_criteria>
  <done>
    `test/sigra/install/features/coverage_test.exs` exists, walks `core/` and `organizations/` subdirs, diffs the on-disk set against `files/1` + `migrations/1` + injection whitelist, reports orphans. Both feature tests pass. Regression spot-check confirms orphan detection works.
  </done>
</task>

<task type="auto" tdd="false">
  <name>Task 24-01-03 (Wave 0): D-06.3 — Create template_syntax_test.exs (HEEx-inside-EEx guard)</name>
  <files>test/sigra/install/template_syntax_test.exs</files>
  <read_first>
    - test/sigra/install/isolation_test.exs (full file — conventions for walking the template tree, `strip_docstrings/1` as a reference for text-munging regexes)
    - priv/templates/sigra.install/organizations/live/invitation_accept_live.ex (post Task 24-01-04 — confirms zero `<%=` / `<%` tags inside its `~H` heredoc)
    - 24-RESEARCH.md Finding 2 + Open Question 2 (confirms guard should walk ALL of `**/*.ex`, not just `organizations/`)
  </read_first>
  <action>
    **TDD-first (Wave 0):** This task lands the regression test BEFORE the fix (Task 24-01-04). The test will be RED against the current `invitation_accept_live.ex` (which contains a raw `<%= case @branch do %>` inside a `~H` heredoc). That redness is the exact DEF-18-01 bug class guard. This Wave 0 task ONLY asserts the test file exists, compiles, and defines at least one `test`/`describe` macro. The test pass/fail transition is verified on Task 24-01-04 (Wave 1).

    Create `test/sigra/install/template_syntax_test.exs` with a narrow grep-based guard:

    ```elixir
    defmodule Sigra.Install.TemplateSyntaxTest do
      @moduledoc """
      D-06.3 regression guard for Phase 24.

      For every `.ex` template under `priv/templates/sigra.install/**/`:

      1. Extract every `~H\\\"\\\"\\\"..\\\"\\\"\\\"` heredoc.
      2. Assert the heredoc body contains NO raw `<%=` or `<%` EEx tags.
         (Escaped `<%%=` and `<%%` are permitted — they render as literal
         `<%=` / `<%` and bypass EEx evaluation.)

      This is the narrowest possible guard for the exact DEF-18-01 bug
      (HEEx-inside-EEx evaluation collision). Catches the bug class at
      file-read time without paying the full render-test cost.
      """
      use ExUnit.Case, async: true

      @moduletag :install

      @template_root "priv/templates/sigra.install"

      # Matches a `~H\"\"\"..\"\"\"` heredoc. Captures the body.
      @heredoc_re ~r/~H"""(.*?)"""/s

      # Matches any raw EEx tag: `<%=` or `<%` NOT preceded by a second `%`.
      # Negative lookbehind `(?<!%)` allows `<%%=` / `<%%` (escaped) to pass.
      @raw_eex_re ~r/(?<!%)<%=?/

      describe "HEEx-inside-EEx guard" do
        for path <- Path.wildcard(Path.join([@template_root, "**", "*.ex"])) do
          @path path

          test "no raw EEx tags inside ~H heredocs: #{@path}" do
            content = File.read!(@path)

            heredocs = Regex.scan(@heredoc_re, content, capture: :all_but_first)

            for [body] <- heredocs do
              refute Regex.match?(@raw_eex_re, body),
                     "#{@path} contains a raw `<%=` or `<%` inside a ~H heredoc. " <>
                       "This will fail at generator-render time because EEx evaluates " <>
                       "the heredoc body before HEEx compilation. Fix by either " <>
                       "(a) lifting the logic into Elixir and using `{...}` curly-brace " <>
                       "HEEx interpolation, or (b) escaping the tag as `<%%=` / `<%%`.\\n\\n" <>
                       "Offending heredoc body:\\n#{body}"
            end
          end
        end
      end
    end
    ```

    Regex notes:
    - `~r/~H"""(.*?)"""/s` — `s` flag makes `.` match newlines; `*?` is lazy so it closes at the nearest `"""`.
    - `~r/(?<!%)<%=?/` — negative lookbehind ensures `<%%=` and `<%%` are NOT matched (the character before the `<` is not `%`, OR the sequence is the start of the string). This is the canonical regex for distinguishing escaped-EEx from raw-EEx.
    - `for [body] <- heredocs` — each heredoc match is an iteration; the test fails on the FIRST offending body with a descriptive message naming the file + body.

    Scope: walks ALL of `**/*.ex` (not just `organizations/`), per 24-RESEARCH.md Open Question 2. Core templates already don't mix EEx and HEEx inside heredocs (Finding 2), so the test passes immediately for `core/` and guards against future regression.

    DO NOT:
    - Use a full EEx parser — a regex is explicitly what D-06.3 specifies.
    - Scope the guard to only `organizations/` — the bug class is template-engine-wide.
    - Use `describe` names that don't include the file path — per-file failure messaging is load-bearing.
  </action>
  <verify>
    <automated>test -f test/sigra/install/template_syntax_test.exs && mix compile --warnings-as-errors 2>&1 | tail -5 && grep -cE '^[[:space:]]*(test|describe) "' test/sigra/install/template_syntax_test.exs</automated>
  </verify>
  <acceptance_criteria>
    - File `test/sigra/install/template_syntax_test.exs` exists.
    - `grep -c "defmodule Sigra.Install.TemplateSyntaxTest" test/sigra/install/template_syntax_test.exs` returns `1`.
    - `grep -c "@heredoc_re" test/sigra/install/template_syntax_test.exs` returns at least `1`.
    - `grep -c "(?<!%)" test/sigra/install/template_syntax_test.exs` returns at least `1` (negative lookbehind for escaped tags).
    - `mix test test/sigra/install/template_syntax_test.exs` exits 0.
    - The test for `invitation_accept_live.ex` appears and passes: `mix test test/sigra/install/template_syntax_test.exs 2>&1 | grep "invitation_accept_live"` shows a passing line.
    - Test count > 40 (one per `.ex` template, current tree has 47+ in `core/` + organizations templates).
    - Regression spot-check (post-Wave-1, deferred): on a scratch branch, revert Task 24-01-04, run `mix test test/sigra/install/template_syntax_test.exs`, confirm the `invitation_accept_live` test FAILS with the offending heredoc body in the message, then restore. Not a Wave 0 acceptance — run after Task 24-01-04 lands.
  </acceptance_criteria>
  <done>
    `test/sigra/install/template_syntax_test.exs` exists, walks all `.ex` templates, extracts `~H"""..."""` heredocs, greps each body for raw `<%=`/`<%` tags (excluding escaped `<%%=`/`<%%`). All tests pass. Regression spot-check confirms it catches DEF-18-01.
  </done>
</task>

<task type="auto" tdd="false">
  <name>Task 24-01-04 (Wave 1): D-01 — Refactor invitation_accept_live.ex render/1 to dispatcher shape</name>
  <files>priv/templates/sigra.install/organizations/live/invitation_accept_live.ex</files>
  <read_first>
    - priv/templates/sigra.install/organizations/live/invitation_accept_live.ex (full file — 416 lines; see lines 228-253 for the block being replaced, 255-412 for the helpers that must remain BYTE-IDENTICAL, 330-336 for the Jetstream #907 invariant comment block)
    - priv/templates/sigra.install/core/user.ex (line 4 — EEx conditional precedent, confirms bare-key vs `@key` convention — NOT directly relevant to this task but confirms template engine shape)
    - lib/sigra/install/runner.ex (line 81 — `EEx.eval_file(template_path, binding)` callsite)
  </read_first>
  <action>
    Replace the `render/1` function at lines 228-253 of `priv/templates/sigra.install/organizations/live/invitation_accept_live.ex` with the thin dispatcher shape (Option A from 24-RESEARCH.md Finding 2).

    EXACT BEFORE (lines 228-253):
    ```elixir
    @impl true
    def render(assigns) do
      ~H"""
      <div id="invitation-accept-page">
        <.flash kind={:info} flash={@flash} />
        <.flash kind={:error} flash={@flash} />

        <%= case @branch do %>
          <% :signup -> %>
            {render_signup(assigns)}
          <% :accept -> %>
            {render_accept(assigns)}
          <% :mismatch -> %>
            {render_mismatch(assigns)}
          <% :invalid -> %>
            {render_invalid(assigns)}
          <% :expired -> %>
            {render_expired(assigns)}
          <% :revoked -> %>
            {render_revoked(assigns)}
          <% :already_accepted -> %>
            {render_already_accepted(assigns)}
        <% end %>
      </div>
      """
    end
    ```

    EXACT AFTER (same offset):
    ```elixir
    @impl true
    def render(assigns) do
      ~H"""
      <div id="invitation-accept-page">
        <.flash kind={:info} flash={@flash} />
        <.flash kind={:error} flash={@flash} />
        {render_branch(assigns)}
      </div>
      """
    end

    defp render_branch(%{branch: :signup} = assigns), do: render_signup(assigns)
    defp render_branch(%{branch: :accept} = assigns), do: render_accept(assigns)
    defp render_branch(%{branch: :mismatch} = assigns), do: render_mismatch(assigns)
    defp render_branch(%{branch: :invalid} = assigns), do: render_invalid(assigns)
    defp render_branch(%{branch: :expired} = assigns), do: render_expired(assigns)
    defp render_branch(%{branch: :revoked} = assigns), do: render_revoked(assigns)
    defp render_branch(%{branch: :already_accepted} = assigns), do: render_already_accepted(assigns)
    ```

    Also update the section comment at lines 225-226:
    - BEFORE: `# Render — branch-dispatched via case @branch.`
    - AFTER: `# Render — thin dispatcher; `render_branch/1` pattern-matches on `:branch`.`

    DO NOT:
    - Touch any of the seven `render_<branch>/1` helpers at lines 255-412.
    - Touch any `handle_event/3` clause at lines 118-216.
    - Touch the Jetstream #907 invariant comment block at lines 330-336.
    - Touch the `<div id="invitation-accept-page">` wrapper or the two `<.flash .../>` lines — they remain in `render/1` in the parent `~H` heredoc, unchanged.
    - Add any `<%= %>` or `<%` EEx tags anywhere inside the `~H"""` heredoc.

    The parent heredoc contains ONLY curly-brace HEEx interpolation (`{render_branch(assigns)}`). EEx passes `{...}` through untouched; HEEx dispatches at runtime.
  </action>
  <verify>
    <automated>mix test test/sigra/install/template_render_test.exs test/sigra/install/template_syntax_test.exs 2>&1 | tail -20; echo "---"; grep -c "defp render_branch" priv/templates/sigra.install/organizations/live/invitation_accept_live.ex; echo "---"; grep -c "case @branch do" priv/templates/sigra.install/organizations/live/invitation_accept_live.ex || true</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "defp render_branch" priv/templates/sigra.install/organizations/live/invitation_accept_live.ex` returns `7` (exactly seven clauses — one per branch).
    - `grep -c "case @branch do" priv/templates/sigra.install/organizations/live/invitation_accept_live.ex` returns `0`.
    - `grep -c "{render_branch(assigns)}" priv/templates/sigra.install/organizations/live/invitation_accept_live.ex` returns `1`.
    - The seven `render_<branch>/1` helpers (render_signup, render_accept, render_mismatch, render_invalid, render_expired, render_revoked, render_already_accepted) all still exist: `grep -cE "defp render_(signup|accept|mismatch|invalid|expired|revoked|already_accepted)\\(assigns\\) do" priv/templates/sigra.install/organizations/live/invitation_accept_live.ex` returns `7`.
    - Jetstream #907 invariant holds: `perl -0777 -ne 'print if /defp render_mismatch.*?(?=defp render_invalid)/s' priv/templates/sigra.install/organizations/live/invitation_accept_live.ex | grep -cE 'phx-(click|submit)="accept'` returns `0`.
    - An ad-hoc EEx render smoke call from `iex -S mix` succeeds:
      `EEx.eval_file("priv/templates/sigra.install/organizations/live/invitation_accept_live.ex", [web_module: "FixtureAppWeb", app_module: "FixtureApp", app_name: "FixtureApp", otp_app: :fixture_app, context_module: "FixtureApp.Accounts", context_alias: "Accounts", schema_module: "FixtureApp.Accounts.User", schema_alias: "User", table_name: "users", from_email: "noreply@example.com", log_in_url: "/users/log_in", repo_module: "FixtureApp.Repo", binary_id: true, live: true, api: false, jwt: false, organizations?: true, adapter: :postgres, reset_password_url: "http://localhost:4000/reset", settings_url: "http://localhost:4000/settings", opts: [], migration_timestamps: %{}])` returns a binary without raising.
    - **Wave 0 RED → GREEN transition (load-bearing, Nyquist-8d acceptance):** `mix test test/sigra/install/template_render_test.exs` exits 0 AND the specific test case for `invitation_accept_live.ex` transitions from RED (pre-Wave 1) to GREEN. Pre-Wave-1 expected failure: `EEx.eval_file raised ... undefined variable "assigns"` in the `invitation_accept_live.ex` test case.
    - **Wave 0 RED → GREEN transition (load-bearing, Nyquist-8d acceptance):** `mix test test/sigra/install/template_syntax_test.exs` exits 0 AND the specific test case for `invitation_accept_live.ex` transitions from RED (pre-Wave 1) to GREEN. Pre-Wave-1 expected failure named the offending `<%= case @branch do %>` heredoc body.
  </acceptance_criteria>
  <done>
    `invitation_accept_live.ex` has zero `<%=` / `<%` tags inside its `~H"""` heredoc. `render/1` is a thin parent heredoc that dispatches via `{render_branch(assigns)}` to a new seven-clause `defp render_branch/1`. Seven existing `render_<branch>/1` helpers are byte-identical. Jetstream #907 defense in `render_mismatch/1` is preserved.
  </done>
</task>

<task type="auto" tdd="false">
  <name>Task 24-01-05 (Wave 1): D-02 — Verify organizations injection templates exist on disk (no creation)</name>
  <files>test/sigra/install/features/organizations_test.exs</files>
  <read_first>
    - test/sigra/install/features/organizations_test.exs (full file — current state of the Organizations feature contract test)
    - lib/sigra/install/features/organizations.ex (lines 155-167 — `router_injection/1` + `user_auth_on_mount_injection/2` `read_template!` callsites)
    - 24-RESEARCH.md Finding 4 (both files confirmed present on disk as of commit 1e918cb)
  </read_first>
  <action>
    DO NOT CREATE either of the "missing" template files — both already exist on disk. This is a verification-only task.

    Add a single test to `test/sigra/install/features/organizations_test.exs` inside the existing describe block (or create a new `describe "injection templates on disk"` block near the top of the module). Test body:

    ```elixir
    test "injection template files exist on disk for Features.Organizations" do
      assert File.exists?("priv/templates/sigra.install/organizations/router_injection.ex"),
             "organizations/router_injection.ex is referenced by Features.Organizations.router_injection/1 via read_template!/1"

      assert File.exists?("priv/templates/sigra.install/organizations/user_auth_on_mount_assign_user_organizations.ex"),
             "organizations/user_auth_on_mount_assign_user_organizations.ex is referenced by Features.Organizations.user_auth_on_mount_injection/2 via read_template!/1"
    end
    ```

    Use `async: true` convention (matches existing tests in the file). Place the test at the top of the module so a regression surfaces immediately. Do not modify any other assertion in the file.

    Justification: Features.Organizations reads both files via `read_template!/1` inside `injections/1`. If either file is missing, `mix sigra.install` crashes before even reaching the EEx render step. The test is the narrowest guard.
  </action>
  <verify>
    <automated>mix test test/sigra/install/features/organizations_test.exs 2>&1 | tail -20; echo "---"; ls priv/templates/sigra.install/organizations/router_injection.ex priv/templates/sigra.install/organizations/user_auth_on_mount_assign_user_organizations.ex</automated>
  </verify>
  <acceptance_criteria>
    - `test -f priv/templates/sigra.install/organizations/router_injection.ex` succeeds (exit 0).
    - `test -f priv/templates/sigra.install/organizations/user_auth_on_mount_assign_user_organizations.ex` succeeds (exit 0).
    - `grep -c "injection template files exist on disk" test/sigra/install/features/organizations_test.exs` returns `1`.
    - `mix test test/sigra/install/features/organizations_test.exs` exits 0 and includes `"injection template files exist on disk for Features.Organizations"` in the passing test names.
    - Neither file was created or modified during this task: `git status priv/templates/sigra.install/organizations/router_injection.ex priv/templates/sigra.install/organizations/user_auth_on_mount_assign_user_organizations.ex` shows both clean.
  </acceptance_criteria>
  <done>
    One new test in `organizations_test.exs` asserts both injection template files exist. Test is green. Neither template file was created or edited.
  </done>
</task>

<task type="auto" tdd="false">
  <name>Task 24-01-06 (Wave 2): D-04.1/.2 — Move organization_invitation_email.ex from core/ to organizations/ + register in Features.Organizations.files/1</name>
  <files>
    priv/templates/sigra.install/core/organization_invitation_email.ex,
    priv/templates/sigra.install/organizations/organization_invitation_email.ex,
    lib/sigra/install/features/organizations.ex,
    test/sigra/install/features/organizations_test.exs
  </files>
  <read_first>
    - priv/templates/sigra.install/core/organization_invitation_email.ex (full file — 114 lines)
    - lib/sigra/install/features/organizations.ex (full file — especially lines 40-97 `files/1` for the tuple placement pattern)
    - lib/sigra/install/features/core.ex (grep for `organization_invitation_email` — confirms Finding 3: the file is NOT currently in Features.Core.files/1, so Core needs NO edit)
    - test/sigra/install/features/organizations_test.exs (to know where to add the assertion for the new entry)
  </read_first>
  <action>
    Three sub-steps. Execute in order. All land in ONE commit with message `feat(24-01): move organization_invitation_email.ex to organizations/ feature`.

    Sub-step A — move the file on disk:
    ```bash
    git mv priv/templates/sigra.install/core/organization_invitation_email.ex priv/templates/sigra.install/organizations/organization_invitation_email.ex
    ```
    Do NOT edit the file contents during the move. The file is a standalone email reference fragment — its internal template bindings are orthogonal to its location.

    Sub-step B — register the moved file in `Features.Organizations.files/1`.
    Edit `lib/sigra/install/features/organizations.ex`. Append a new tuple entry to the list returned by `files/1` at line 96 (after the current last entry `{:eex, "organizations/live/invitation_accept_live.ex", ...}`):

    EXACT BEFORE (lines 89-96):
    ```elixir
          # Phase 17 Plan 07 (D-06): InvitationAcceptLive — single unscoped
          # LiveView with 7 render branches (signup/accept/mismatch/invalid/
          # expired/revoked/already_accepted). The :mismatch branch contains
          # ZERO accept DOM controls by construction — structural Jetstream
          # #907 / CVE-2026-1529 defense. Host-owned per D-28 / D-29.
          {:eex, "organizations/live/invitation_accept_live.ex",
           Path.join(["lib", web, "live", "invitation_accept_live.ex"])}
        ]
    ```

    EXACT AFTER:
    ```elixir
          # Phase 17 Plan 07 (D-06): InvitationAcceptLive — single unscoped
          # LiveView with 7 render branches (signup/accept/mismatch/invalid/
          # expired/revoked/already_accepted). The :mismatch branch contains
          # ZERO accept DOM controls by construction — structural Jetstream
          # #907 / CVE-2026-1529 defense. Host-owned per D-28 / D-29.
          {:eex, "organizations/live/invitation_accept_live.ex",
           Path.join(["lib", web, "live", "invitation_accept_live.ex"])},

          # Phase 17 D-12 / Phase 24 D-04: standalone organization-invitation
          # email reference fragment. Mirrors the canonical inline
          # implementation in core/emails.ex. Generated under the organizations
          # feature so that `--no-organizations` cleanly omits it
          # (Phase 11 CD-01 subdir ownership).
          {:eex, "organizations/organization_invitation_email.ex",
           Path.join(["lib", otp_app, "accounts", "organization_invitation_email.ex"])}
        ]
    ```

    Target path `lib/<otp_app>/accounts/organization_invitation_email.ex` matches the `api_token_created_email.ex` precedent (code-path, co-located with the host accounts context). The hardcoded `"accounts"` segment mirrors the standalone fragment convention — existing `files/1` entries use `Path.join(["lib", otp_app, ...])` without a dynamic context segment, so match that shape.

    Sub-step C — add a coverage assertion in `test/sigra/install/features/organizations_test.exs`. Inside the existing `describe "files/1"` block (or the equivalent block that walks `Features.Organizations.files/1`), add:

    ```elixir
    test "files/1 includes the moved organization_invitation_email.ex fragment" do
      entries = Sigra.Install.Features.Organizations.files(@binding)

      sources = Enum.map(entries, fn {:eex, source, _target} -> source end)

      assert "organizations/organization_invitation_email.ex" in sources,
             "Features.Organizations.files/1 must register the moved email fragment (Phase 24 D-04.1)"
    end
    ```

    (Use whatever `@binding` helper the test module already defines. If no `@binding` exists, construct a minimal keyword list matching `lib/mix/tasks/sigra.install.ex:97-119` with `otp_app: :fixture_app`.)

    DO NOT:
    - Edit `lib/sigra/install/features/core.ex` — the file was never registered there (24-RESEARCH.md Finding 3).
    - Edit `test/sigra/install/isolation_test.exs` — the `== 47` assertion self-corrects after the move (24-RESEARCH.md Finding 5).
    - Edit `test/sigra/install/templates_layout_test.exs` — the hardcoded 47-entry manifest already excludes this file (24-RESEARCH.md Finding 5).
    - Touch the contents of `organization_invitation_email.ex` itself — plain `git mv`.
  </action>
  <verify>
    <automated>mix test test/sigra/install/features/organizations_test.exs test/sigra/install/features/core_test.exs test/sigra/install/isolation_test.exs test/sigra/install/templates_layout_test.exs 2>&1 | tail -30; echo "---"; test ! -f priv/templates/sigra.install/core/organization_invitation_email.ex && test -f priv/templates/sigra.install/organizations/organization_invitation_email.ex && echo "MOVE OK"; echo "---"; ls priv/templates/sigra.install/core/ | wc -l</automated>
  </verify>
  <acceptance_criteria>
    - `test ! -f priv/templates/sigra.install/core/organization_invitation_email.ex` succeeds (exit 0).
    - `test -f priv/templates/sigra.install/organizations/organization_invitation_email.ex` succeeds (exit 0).
    - `ls priv/templates/sigra.install/core/ | wc -l` returns `47` (was 48 before move).
    - `grep -c "organizations/organization_invitation_email.ex" lib/sigra/install/features/organizations.ex` returns `1`.
    - `grep -c "organization_invitation_email" lib/sigra/install/features/core.ex` returns `0` (Core was never touched and still does not mention the file).
    - `mix test test/sigra/install/isolation_test.exs` exits 0 (the `"contains exactly 47 templates"` assertion passes without any edit to that file).
    - `mix test test/sigra/install/templates_layout_test.exs` exits 0 (the hardcoded `@manifest_post_move` list already matches core/'s new state).
    - `mix test test/sigra/install/features/organizations_test.exs` exits 0 and includes `"files/1 includes the moved organization_invitation_email.ex fragment"` in the passing test names.
    - `git diff --stat test/sigra/install/isolation_test.exs test/sigra/install/templates_layout_test.exs` shows both files UNCHANGED.
  </acceptance_criteria>
  <done>
    File moved via `git mv` (content byte-identical). `Features.Organizations.files/1` has a new tuple targeting `lib/<otp_app>/accounts/organization_invitation_email.ex`. `organizations_test.exs` has a coverage assertion. `isolation_test.exs`, `templates_layout_test.exs`, and `features/core.ex` are all unchanged. `core/` has exactly 47 files.
  </done>
</task>

<task type="auto" tdd="false">
  <name>Task 24-01-07 (Wave 2): D-04.3 — Conditional-wrap organization_invitation/4 + helpers in core/emails.ex + reword # comment</name>
  <files>priv/templates/sigra.install/core/emails.ex</files>
  <read_first>
    - priv/templates/sigra.install/core/emails.ex (specifically lines 690-805 — the block being wrapped)
    - priv/templates/sigra.install/core/user.ex (line 4 — confirms `<%= if organizations? do %>` bare-key precedent, NOT `@organizations?`)
    - lib/mix/tasks/sigra.install.ex (line 114 — confirms binding key is `organizations?:` with trailing `?`)
    - test/sigra/install/isolation_test.exs (lines 22-32 forbidden-symbol assertion + lines 91-95 `strip_docstrings/1` regex — proves `#` comments are NOT stripped)
  </read_first>
  <action>
    Edit `priv/templates/sigra.install/core/emails.ex`. Perform TWO combined edits in a single pass:

    (1) Reword the `#` comment at lines 696-700 to REMOVE the literal substring `OrganizationInvitationEmail` — it otherwise fails `IsolationTest`'s forbidden-symbol guard (the test strips `@doc`/`@moduledoc` heredocs but NOT `#` comments — 24-RESEARCH.md Finding 5 secondary).

    EXACT BEFORE (lines 696-700):
    ```elixir
      # -- Organization Invitation (Phase 17 D-12) --
      #
      # Canonical inline copy of the OrganizationInvitationEmail fragment
      # shipped at priv/templates/sigra.install/core/organization_invitation_email.ex.
      # Both must stay in sync — the fragment file is the documentation reference.
    ```

    EXACT AFTER (lines 696-700):
    ```elixir
      # -- Org-invite block (Phase 17 D-12 / Phase 24 D-04) --
      #
      # Canonical inline copy of the invitation email fragment shipped at
      # priv/templates/sigra.install/organizations/organization_invitation_email.ex.
      # Both must stay in sync — the fragment file is the documentation reference.
      # Wrapped in `<%%= if organizations? do %%>` so --no-organizations omits it.
    ```

    Note: the rewording replaces `OrganizationInvitationEmail` with `invitation email fragment` and updates the path to reflect the Task 24-01-06 move. The `<%%=` escape in the comment is intentional — it is a documentation reference to the EEx tag, and `<%%=` renders as literal `<%=` in the generated output (it must NOT be interpreted as an EEx tag at generator-render time).

    (2) Wrap the entire `organization_invitation/4` function AND its two private helpers (`inviter_display_name/1` + `humanize_role/1`) in a single `<%= if organizations? do %> ... <% end %>` block.

    EXACT BEFORE (lines 702-801 — the `@doc` + `def organization_invitation/4` + `defp inviter_display_name/1` + `defp humanize_role/1` triad):
    ```elixir
      @doc """
      Builds an organization-invitation email.
      ...
      """
      def organization_invitation(invitation, org, inviter, accept_url)
          when is_binary(accept_url) do
        ...
        |> text_body(text_body)
      end

      defp inviter_display_name(inviter) do
        case inviter do
          %{name: name} when is_binary(name) and name != "" -> name
          %{email: email} when is_binary(email) -> email
          _ -> "Someone"
        end
      end

      defp humanize_role(role), do: role |> to_string() |> String.capitalize()
    ```

    EXACT AFTER (same offset, wrapped in a single EEx conditional block):
    ```elixir
    <%= if organizations? do %>
      @doc """
      Builds an organization-invitation email.
      ...
      """
      def organization_invitation(invitation, org, inviter, accept_url)
          when is_binary(accept_url) do
        ...
        |> text_body(text_body)
      end

      defp inviter_display_name(inviter) do
        case inviter do
          %{name: name} when is_binary(name) and name != "" -> name
          %{email: email} when is_binary(email) -> email
          _ -> "Someone"
        end
      end

      defp humanize_role(role), do: role |> to_string() |> String.capitalize()
    <% end %>
    ```

    (The `...` ellipses above are shorthand for "byte-identical body content — do NOT rewrite the function body; only add the EEx wrapper lines around it.")

    CRITICAL binding convention (24-RESEARCH.md Finding 1):
    - Use `organizations?` (BARE key — no `@` prefix).
    - NOT `@organizations?`. EEx.eval_file uses the default `EEx.Engine` which does not support `@key` sugar against a keyword binding.
    - Precedent: `core/user.ex:4` uses `<%= if binary_id do %>`.

    Critical scope rule: all THREE defs (public function + both private helpers) MUST be inside the same EEx conditional. If only the public function is wrapped, `mix compile --warnings-as-errors` in the `install_matrix --no-organizations` CI leg fails with "unused private function inviter_display_name/1" (24-RESEARCH.md Pitfall 3).

    DO NOT:
    - Introduce any new compile-time shape — no helper modules, no post-process strip, no AST rewrite. Use only `<%= if organizations? do %> ... <% end %>`.
    - Use `@organizations?` anywhere.
    - Wrap lines beyond 702-801 — the other email builders above (`password_changed/1` etc.) must remain unconditional.
    - Touch the `base_email/1` / `base_layout/1` / `cta_button/2` / `footer_text/0` helpers elsewhere in the file — they are used by non-org emails too.
  </action>
  <verify>
    <automated>mix test test/sigra/install/isolation_test.exs test/sigra/install/templates_layout_test.exs 2>&1 | tail -30; echo "---"; grep -c "if organizations? do" priv/templates/sigra.install/core/emails.ex; echo "---"; grep -c "OrganizationInvitationEmail" priv/templates/sigra.install/core/emails.ex</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "if organizations? do" priv/templates/sigra.install/core/emails.ex` returns at least `1`.
    - `grep -c "@organizations?" priv/templates/sigra.install/core/emails.ex` returns `0` (bare key only, not `@key`).
    - `grep -c "OrganizationInvitationEmail" priv/templates/sigra.install/core/emails.ex` returns `0` (literal substring removed from the `#` comment).
    - The conditional wraps ALL THREE defs: `perl -0777 -ne 'if (/if organizations\\? do(.*?)<% end %>/s) { print $1 }' priv/templates/sigra.install/core/emails.ex | grep -c "def organization_invitation"` returns `1`, AND the same extracted block contains `defp inviter_display_name` AND `defp humanize_role` (run `grep -c` for each on the extracted output).
    - `mix test test/sigra/install/isolation_test.exs` exits 0 (the forbidden-symbol guard for `core/*` now passes — 24-RESEARCH.md Finding 5 secondary is resolved).
    - **Wave 0 RED → GREEN transition (load-bearing, Nyquist-8d acceptance):** After this task lands (chained after Task 24-01-06 which moves the fragment), `mix test test/sigra/install/features/coverage_test.exs` exits 0 AND both per-feature test cases (`every file under core/ is owned` and `every file under organizations/ is owned`) transition from RED (pre-Wave-2) to GREEN. Pre-Wave-2 expected failure: `core/organization_invitation_email.ex` listed as orphan under `Features.Core`.
    - Default-leg render succeeds: from `iex -S mix`, `EEx.eval_file("priv/templates/sigra.install/core/emails.ex", [otp_app: :fixture_app, organizations?: true, app_name: "FixtureApp", web_module: "FixtureAppWeb", app_module: "FixtureApp", context_module: "FixtureApp.Accounts", context_alias: "Accounts", schema_module: "FixtureApp.Accounts.User", schema_alias: "User", table_name: "users", from_email: "noreply@example.com", log_in_url: "/users/log_in", repo_module: "FixtureApp.Repo", binary_id: true, live: true, api: false, jwt: false, adapter: :postgres, reset_password_url: "http://localhost:4000/reset", settings_url: "http://localhost:4000/settings", opts: [], migration_timestamps: %{}])` returns a binary containing `"def organization_invitation"`.
    - No-orgs-leg render succeeds: same call with `organizations?: false` returns a binary that does NOT contain `"def organization_invitation"` (case-sensitive grep).
    - Both rendered outputs parse as valid Elixir: `Code.string_to_quoted/1` returns `{:ok, _}` for each.
  </acceptance_criteria>
  <done>
    `core/emails.ex` has the `#` comment reworded to remove `OrganizationInvitationEmail`. The public `organization_invitation/4` function + both private helpers (`inviter_display_name/1` + `humanize_role/1`) are wrapped in a single `<%= if organizations? do %> ... <% end %>` block using BARE `organizations?` (no `@`). `isolation_test.exs` forbidden-symbol guard passes. Both default-leg and `--no-organizations`-leg renders produce valid Elixir.
  </done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <name>Task 24-01-08 (Wave 3): D-05 — Regenerate golden fixture + visual diff review (CHECKPOINT)</name>
  <files>test/fixtures/install_golden/tree/**, test/fixtures/install_golden/STDOUT.txt</files>
  <action>
    After Tasks 24-01-01 through 24-01-07 land, the generator output has drifted in three specific ways:

    1. `lib/&lt;otp_app&gt;_web/live/invitation_accept_live.ex` — new `render/1` dispatcher shape + 7 `defp render_branch/1` clauses.
    2. `lib/&lt;otp_app&gt;/accounts/emails.ex` — reworded `#` comment at the org-invite block; the conditional EEx block renders the `organization_invitation/4` + helpers under the default leg (`organizations?: true`), so the generated file under the default leg contains the same function text but the enclosing comment text changed.
    3. `lib/&lt;otp_app&gt;/accounts/organization_invitation_email.ex` — new file in the tree (moved from `core/` to `organizations/`, newly registered in `Features.Organizations.files/1`).

    `STDOUT.txt` also gains a new `* creating lib/.../organization_invitation_email.ex` line.

    `test/sigra/install/golden_diff_test.exs` currently FAILS because the checked-in fixture tree does not reflect any of the above. The fixture must be regenerated by running the generator against a fresh tmp app and copying the output back into `test/fixtures/install_golden/`.

    There is no `mix sigra.install.golden` task. The rebless is a manual runbook from `.planning/phases/11-generator-feature-system/11-01-SUMMARY.md` — reproduced below for self-containment.
  </action>
  <verify>
    Execute the inlined runbook. Do NOT skip the visual diff step.

    Runbook (per 24-RESEARCH.md Finding 10):

    1. Baseline — confirm the golden test currently FAILS (proves the rebless is needed):
       ```bash
       mix test test/sigra/install/golden_diff_test.exs 2>&1 | tail -30
       ```
       Expect a failure with diff output naming the three files listed in `&lt;what-built&gt;`.

    2. Regenerate the fresh tmp app using `Sigra.Test.InstallFixture.setup_tmp_app/1` from `iex -S mix`:
       ```bash
       iex -S mix
       ```
       Then in iex:
       ```elixir
       {tmp_dir, stdout} = Sigra.Test.InstallFixture.setup_tmp_app(on_conflict: :overwrite)
       IO.puts("tmp_dir = #{tmp_dir}")
       IO.puts(stdout)
       ```
       (Exact helper arity may differ — read `test/support/install_fixture.ex` first and invoke whatever the existing callers use. The `golden_diff_test.exs` file at lines 1-120 is the canonical example of how to invoke the harness.)

    3. Normalize the generated tree and stdout:
       ```elixir
       normalized_tree = Sigra.Test.InstallFixture.normalize_tree(tmp_dir, tmp_app_name)
       normalized_stdout = Sigra.Test.InstallFixture.normalize_stdout(stdout, tmp_app_name)
       ```
       (Again, exact function names per `install_fixture.ex`.)

    4. Copy the normalized tree + stdout into the fixture dir:
       ```bash
       rm -rf test/fixtures/install_golden/tree
       cp -R &lt;normalized_tree_path&gt; test/fixtures/install_golden/tree
       # Write normalized_stdout to test/fixtures/install_golden/STDOUT.txt
       ```

    5. VISUAL DIFF REVIEW — MANDATORY. Do NOT commit without reading:
       ```bash
       git diff --stat test/fixtures/install_golden/
       git diff test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/live/invitation_accept_live.ex
       git diff test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/emails.ex
       git diff test/fixtures/install_golden/STDOUT.txt
       git status test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/organization_invitation_email.ex  # expect: NEW FILE
       ```

       Confirm the diff matches EXACTLY these three changes and NO OTHERS:
       (a) `invitation_accept_live.ex`: new `defp render_branch/1` clauses; `render/1` body replaced with the thin dispatcher; seven `render_&lt;branch&gt;/1` helpers BYTE-IDENTICAL.
       (b) `emails.ex`: `#` comment at the org-invite block reworded to remove `OrganizationInvitationEmail` literal substring; `organization_invitation/4` + helpers unchanged (the default leg renders the block in full).
       (c) NEW FILE: `lib/sigra_install_golden_tmp/accounts/organization_invitation_email.ex` (content is the moved fragment rendered with the default binding).
       (d) `STDOUT.txt`: one new `* creating lib/sigra_install_golden_tmp/accounts/organization_invitation_email.ex` line; otherwise byte-identical.

       IF the diff contains any OTHER changes (whitespace-only drift in unrelated files, reordering of `files/1` outputs, extra bytes in other `.ex` files), STOP and investigate before proceeding. The rebless has drifted.

    6. Run the golden test — must now pass:
       ```bash
       mix test test/sigra/install/golden_diff_test.exs 2>&1 | tail -10
       ```

    7. Run the full install suite — must be green:
       ```bash
       mix test test/sigra/install/ 2>&1 | tail -20
       ```

    8. Commit with the diff summary in the commit message:
       ```
       chore(24-01): rebless golden fixture after Phase 24 template repairs

       Expected drift (visually inspected per D-05):
       - invitation_accept_live.ex: render/1 → dispatcher shape (D-01)
       - accounts/emails.ex: # comment reworded (D-04.3 + Finding 5)
       - NEW: accounts/organization_invitation_email.ex (D-04.1/.2)
       - STDOUT.txt: +1 creating line
       ```

    BLOCKING: this task pauses for the user to confirm the visual diff matches the expected shape. Resume only with explicit approval.
  </verify>
  <resume-signal>Type `approved` after visually confirming the git diff matches the four bullets above. Type `drift detected: &lt;details&gt;` if any unexpected changes appear, so the planner can investigate.</resume-signal>
  <done>Golden fixture at test/fixtures/install_golden/ regenerated; git diff visually inspected and matches the expected four-bullet shape (invitation_accept_live.ex dispatcher, emails.ex reworded comment, NEW organization_invitation_email.ex, STDOUT.txt +1 line); `mix test test/sigra/install/golden_diff_test.exs` exits 0; user approved the diff shape.</done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <name>Task 24-01-09 (Wave 3): D-06.4 — Verify install_matrix CI leg green on both flags (CHECKPOINT)</name>
  <files>.github/workflows/ci.yml (read-only — verify both matrix legs green, no edits)</files>
  <action>
    Phase 24's final gate. After Tasks 24-01-01..24-01-08 land, the `install_matrix` job in `.github/workflows/ci.yml:151-223` MUST pass on both matrix legs:

    - `flags: ""` (default, Features.Organizations enabled) — was failing on `mix sigra.install` with `CompileError: undefined variable "assigns"` before Task 24-01-04.
    - `flags: "--no-organizations"` — was potentially failing on `mix compile --warnings-as-errors` because `core/emails.ex` referenced `OrganizationInvitation` in a `#` comment and defined `organization_invitation/4` unconditionally (triggering "unused private helper" warnings if the public function was ever removed). Now fixed by Task 24-01-07.

    Phase 24 does NOT add YAML. The job already exists. This task is PASS/FAIL verification of the existing job.
  </action>
  <verify>
    Option A (preferred — real CI):
    1. Push the branch to GitHub, open or update the PR.
    2. Wait for `install_matrix` job to run.
    3. Confirm BOTH matrix legs green in the PR status checks:
       - `install_matrix / flags-""` → green
       - `install_matrix / flags-"--no-organizations"` → green
    4. Confirm the `mix test test/sigra/install/` step exits 0 in BOTH legs (not just the initial compile).

    Option B (local — if preferred, using the `act` runner per the user's reference_act_local_ci.md note):
    1. From repo root:
       ```bash
       act -j install_matrix --matrix flags:"" --container-architecture linux/amd64
       act -j install_matrix --matrix flags:"--no-organizations" --container-architecture linux/amd64
       ```
       (Use the exact image pinning + arm64 workaround documented in `reference_act_local_ci.md`.)
    2. Confirm both runs exit 0.

    Option C (hybrid — if CI is slow or flaky):
    1. Locally, reproduce the matrix leg by hand:
       ```bash
       cd /tmp &amp;&amp; rm -rf sigra_ci_scratch &amp;&amp; mix phx.new sigra_ci_scratch --no-assets --no-mailer --no-install
       cd sigra_ci_scratch
       # Patch mix.exs to add {:sigra, path: "/Users/jon/projects/sigra", override: true}
       mix deps.get
       mix compile
       mix sigra.install Accounts User users --yes  # default leg
       mix ecto.create &amp;&amp; mix ecto.migrate
       mix compile --warnings-as-errors
       mix test
       ```
    2. Repeat with `mix sigra.install Accounts User users --yes --no-organizations` in a fresh scratch app for the second leg.
    3. Both must complete without error.

    Static-check hardening (non-blocking, run locally before declaring done — checker Warning 4):
    - `grep -c 'install_matrix' .github/workflows/ci.yml` returns a value `>= 1` (confirms the matrix job is still wired into CI).
    - The `install_matrix` job's `flags` matrix line contains both `""` and `"--no-organizations"`. Verify via:
      ```bash
      awk '/install_matrix:/,/^[a-zA-Z_-]+:$/' .github/workflows/ci.yml | grep -E 'flags:.*(\"\".*--no-organizations|--no-organizations.*\"\")'
      ```
      should return a non-empty line.

    BLOCKING acceptance: Phase 24 does not complete until BOTH matrix legs are confirmed green. Phase 18 Plan 18-03 remains blocked until this task passes.
  </verify>
  <resume-signal>Type `approved: both matrix legs green (PR link: &lt;url&gt;)` when both legs confirmed green on CI or local reproduction. Type `failed: &lt;details&gt;` if either leg fails, so the planner can triage whether to add a Wave 5 hotfix task or split into a new phase.</resume-signal>
  <done>install_matrix CI job at `.github/workflows/ci.yml:151-223` green on BOTH `""` and `"--no-organizations"` matrix legs; Phase 18 Plan 18-03 unblocked; user confirmed via `approved` resume signal with PR link.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Generator input (developer shell) → EEx binding | `mix sigra.install` accepts CLI flags; the `--organizations` / `--no-organizations` switch controls whether the `organizations?` binding key is `true` or `false`. The binding is the trust boundary between developer intent and template render. |
| Template source → `EEx.eval_file/2` → host app file | The generator writes files into the developer's project. Any template that renders in an unexpected shape (e.g. leaking internal debug symbols) would pollute the host app. |
| Invitation accept URL → LiveView `render_branch(assigns)` | Runtime boundary — the `assigns.branch` atom is server-controlled (derived from HMAC-verified invitation state in `mount/3`); the dispatcher pattern-matches on this atom and dispatches to branch-specific markup. Preserves the Jetstream #907 / CVE-2026-1529 defense that `render_mismatch/1` contains ZERO accept controls. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-24-01 | Tampering | Template file content accidentally edited during dispatcher refactor — could alter `render_mismatch/1` markup to include accept controls | mitigate | Task 24-01-04 acceptance criterion: `perl -0777 -ne 'print if /defp render_mismatch.*?(?=defp render_invalid)/s' &lt;file&gt; | grep -cE 'phx-(click|submit)="accept'` returns `0`. Plan-checker grep enforces invariant. |
| T-24-02 | Information Disclosure | `#` comment in `core/emails.ex` leaks feature-name substring into `--no-organizations` generated output, potentially hinting at a feature the host app opted out of | mitigate | Task 24-01-07 both reworders the `#` comment (removes `OrganizationInvitationEmail` literal) AND wraps the entire block in `&lt;%= if organizations? do %&gt;`, so the `--no-organizations` generated file contains neither the comment nor the function. |
| T-24-03 | Denial of Service | A future template author adds a new `~H` heredoc with `<%= %>` tags inside, re-introducing the DEF-18-01 bug and breaking `mix sigra.install` for all host apps | mitigate | Task 24-01-03 (`template_syntax_test.exs`) grep-enforces the invariant across ALL templates in the tree, on every CI run. Task 24-01-01 (`template_render_test.exs`) render-tests each template to catch the class at install time. Both land in Wave 0 so they guard against regression from the first commit of the phase. |
| T-24-04 | Tampering | Orphan template file sits on disk but is not owned by any feature — could be edited without any test signal, drifting from the generated output | mitigate | Task 24-01-02 (`coverage_test.exs`) diffs the on-disk set against `Features.*.files/1` + `migrations/1` + injection whitelist. Any orphan fails CI immediately. |
| T-24-05 | Information Disclosure | Golden fixture regenerated blindly without diff review — silent generator drift could be committed and pass CI on the next run | mitigate | Task 24-01-08 is a CHECKPOINT with explicit visual-diff acceptance. Rebless runbook inlined in the task body. Resume signal requires human `approved` on the diff shape. |
| T-24-06 | Elevation of Privilege | `assigns.branch` atom is user-influenced via the invitation accept URL — if the dispatcher pattern-match catches-all, an attacker could force a branch transition to `:accept` while holding mismatch state | accept | Pre-existing mitigation in the (unchanged) `mount/3` logic derives `:branch` from HMAC-verified state ONLY. The dispatcher change at Task 24-01-04 does not alter the derivation — only the render dispatch. No new surface. |

</threat_model>

<verification>

After all tasks land:

1. `mix test test/sigra/install/` — full install suite exits 0 with zero failures. Baseline matches or exceeds pre-Phase-18 state (the six pre-existing failures from Phase 18 Plan 18-01 Task 3 are eliminated).

2. `mix test` — full project suite exits 0 with zero failures and zero new regressions.

3. `mix sigra.install --yes` against a fresh `mix phx.new` scratch app completes without compile error AND `mix compile --warnings-as-errors` on the generated app succeeds.

4. `mix sigra.install --yes --no-organizations` against a fresh scratch app completes AND `mix compile --warnings-as-errors` on the generated app succeeds (no "unused private function" warnings — helpers are wrapped in the same conditional as the public function).

5. `install_matrix` CI job green on BOTH `""` and `"--no-organizations"` legs.

6. Four new regression tests pass and collectively guard the bug classes:
   - `test/sigra/install/template_render_test.exs` — one test case per `organizations/**/*.ex` template.
   - `test/sigra/install/template_syntax_test.exs` — one test case per `**/*.ex` template.
   - `test/sigra/install/features/coverage_test.exs` — one test case per feature.
   - (D-06.4 is CI verification, not a test file.)

7. `ls priv/templates/sigra.install/core/ | wc -l` returns `47` (was 48 before Task 24-01-06).

8. `git grep "OrganizationInvitationEmail" priv/templates/sigra.install/core/emails.ex` returns empty.

9. `git grep "case @branch do" priv/templates/sigra.install/` returns empty.

10. Phase 18 Plan 18-03 is unblocked (manual verification — check `.planning/phases/18-backfill-organizations-generator-wiring/` for the plan status).

</verification>

<success_criteria>

Phase 24 is complete when:

- [ ] All nine tasks (24-01-01 through 24-01-09) green per their acceptance criteria.
- [ ] `mix test test/sigra/install/` exits 0; six pre-existing failures eliminated.
- [ ] `mix test` full-suite exits 0 with no new regressions.
- [ ] `install_matrix` CI leg green on both `""` and `"--no-organizations"`.
- [ ] Golden fixture regenerated; diff visually inspected per D-05 runbook.
- [ ] Three new test files exist and are committed: `template_render_test.exs`, `template_syntax_test.exs`, `features/coverage_test.exs`.
- [ ] Dispatcher refactor preserves Jetstream #907 / CVE-2026-1529 structural defense in `render_mismatch/1`.
- [ ] `core/` has exactly 47 templates; `Features.Organizations.files/1` owns the moved fragment.
- [ ] Phase 18 Plan 18-03 is unblocked (the `--yes` install CI matrix leg can now run to completion).
- [ ] Must-have truths verified:
  1. `mix sigra.install --yes` runs end-to-end without a template compile error.
  2. `mix test test/sigra/install/` returns to a clean baseline.
  3. Phase 18 Plan 18-03 is unblocked.

</success_criteria>

<output>
After completion, create `.planning/phases/24-repair-phase-16-17-organizations-generator-templates/24-01-SUMMARY.md` per the summary template.

Summary should include:
- Which task closed which failure from DEF-18-01 / DEF-18-02.
- Exact golden fixture diff (files + line counts) from Task 24-01-08.
- Confirmation that Phase 18 Plan 18-03 is unblocked.
- Any follow-up ideas (e.g. credo check for HEEx-inside-EEx, promoting `Sigra.Test.InstallFixture.render_template/2` helper).
</output>
