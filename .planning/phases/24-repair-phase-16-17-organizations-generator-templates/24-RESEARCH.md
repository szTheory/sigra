# Phase 24: Repair Phase 16/17 organizations generator templates — Research

**Researched:** 2026-04-14
**Domain:** Elixir/Phoenix generator templates — EEx vs HEEx dual-layer evaluation, Features manifest drift repair
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**D-01 — `invitation_accept_live.ex` render/1 refactor:** Refactor `render/1` to do an Elixir-side `case assigns.branch` that returns a per-branch `~H` sigil. Remove `<%= case @branch do %>` from inside the `~H"""` heredoc. Per-branch `render_<branch>/1` helpers already exist. The top-level `<div id="invitation-accept-page">` + flashes wrapper must be preserved — either lift into each branch's sigil or wrap the `case` result in a parent `~H` that interpolates `{render_branch(assigns)}` via a thin dispatcher. Planner picks concrete shape.

**D-02 — DEF-18-01 Failures 2 & 3 (missing templates):** Verify-only, no creation. `priv/templates/sigra.install/organizations/router_injection.ex` and `organizations/user_auth_on_mount_assign_user_organizations.ex` already exist on disk (verified — see Finding 4 below). Planner adds a single verification step; no creation work.

**D-03 — Single repair plan:** One plan: `24-01-repair-phase-16-17-org-templates-PLAN.md`. All of DEF-18-01 and DEF-18-02 fold into the same plan. Granular tasks within that plan keep commits small.

**D-04 — DEF-18-02 emails.ex + organization_invitation_email.ex resolution:**
1. Register `organization_invitation_email.ex` under `Features.Organizations`, not `Features.Core`.
2. Move the file from `priv/templates/sigra.install/core/` to `priv/templates/sigra.install/organizations/` on disk.
3. Keep the inline `organization_invitation/4` function in `core/emails.ex` intact, BUT wrap it in conditional EEx keyed on the `organizations?` binding flag so `--no-organizations` omits it.
4. Update `Features.Core.files/1` — no change needed (the file is not currently registered in Core; see Finding 3). Update `Features.Organizations.files/1` to pick it up.
5. Update `Sigra.Install.IsolationTest` "contains exactly 47 templates" — in fact the test already asserts `== 47`, and core/ currently has 48 files. Moving the file makes core/ = 47 and the test passes without edit (see Finding 5).

**D-05 — Golden fixture regeneration:** After D-01 + D-04 land, regenerate golden fixtures. Planner must visually inspect the diff in a self-verification step before blessing. Expected diff shape: new `organizations/live/invitation_accept_live.ex` content, new `organizations/organization_invitation_email.ex` entry in file list, updated `lib/.../auth/emails.ex` content in the default leg, updated STDOUT.txt.

**D-06 — Four regression tests to land with this phase:**
1. Generator-render unit test for every `organizations/**/*.ex` template (EEx.eval_file + Code.string_to_quoted).
2. Features.Core / Features.Organizations file-coverage lint.
3. HEEx-inside-EEx guard test.
4. Unblock the `mix sigra.install --yes` CI matrix leg — the leg already exists in `.github/workflows/ci.yml` (see Finding 8); Phase 24 simply removes the blocker by landing D-01 + D-04.

### Claude's Discretion

- Concrete file naming for new test modules (planner picks paths under `test/sigra/install/`).
- Fixture binding shape for the generator-render unit test (planner picks minimal binding).
- Conditional-generation mechanism for `organization_invitation/4` in `core/emails.ex` (EEx `<%= if @organizations? do %>` block vs. compile-time helper vs. post-process removal). Planner picks whichever keeps the template readable.
- Whether to lift the `invitation_accept_live` wrapper `<div>` + flashes into each branch's sigil or into a thin dispatcher wrapper.
- Exact fixture app paths for golden regeneration.
- Acceptance thresholds for the per-feature coverage lint.

### Deferred Ideas (OUT OF SCOPE)

- Re-architecting `core/emails.ex` into feature-injected blocks.
- Merging DEF-18-01 and DEF-18-02 into a Plan 18-01b under Phase 18.
- Any redesign of the invitation_accept_live 7-branch UX.
- Enforcement of template render tests for `core/` templates in addition to `organizations/`.
- Promoting the HEEx-inside-EEx guard into a credo check.
</user_constraints>

## Project Constraints (from CLAUDE.md)

- Phoenix 1.8+ / Ecto 3.x blessed path; hybrid lib+generator architecture — security-critical code in library, customizable app code in generated templates.
- Minimal transitive deps. Copy-paste over deps when code is small and stable.
- OWASP throughout. All tokens HMAC-protected. The invitation flow's Jetstream #907 / CVE-2026-1529 structural defense must be preserved byte-for-byte — the `:mismatch` branch must contain ZERO `phx-click`/`phx-submit` accept controls (enforced by plan-checker grep; see `invitation_accept_live.ex:330-336` comment block).
- LiveView supported but optional. Login/logout via HTTP POST, not LiveView events.
- Tests AAA-style, flat, self-contained.

## Summary

Phase 24 is a pure repair phase that unblocks Phase 18 Plan 18-03's CI matrix leg by fixing two pre-existing bugs shipped in Phases 16/17 — neither caught before Phase 18 Wave 1 registered `Features.Organizations` into the `@features` list in `lib/mix/tasks/sigra.install.ex:35`.

**DEF-18-01** is a single EEx/HEEx evaluation-order collision at `priv/templates/sigra.install/organizations/live/invitation_accept_live.ex:235`. The file uses `<%= case @branch do %>` inside a `~H"""` heredoc. At generator time, `EEx.eval_file/2` (runner.ex:81) parses `<%= %>` tags FIRST, sees `@branch`, expands it to `Kernel.var!(assigns).branch`, and fails because `assigns` is not in the generator binding. The fix per D-01 is to lift the case into Elixir-side dispatch — per-branch `render_<branch>/1` helpers already exist (lines 255–412). The "Failures 2 & 3" in the deferred-items doc (missing `router_injection.ex` + `user_auth_on_mount_assign_user_organizations.ex`) are **already fixed on disk** as of commit `1e918cb` — both files exist (Finding 4) and `read_template!` succeeds. D-02 makes them a single verification line, not a creation task.

**DEF-18-02** is Features.Core / `core/` subtree drift. Phase 17 shipped `priv/templates/sigra.install/core/organization_invitation_email.ex` (a standalone fragment) plus an inline canonical copy of `organization_invitation/4` inside `core/emails.ex:718`. Neither was registered in `Features.Core.files/1` (Finding 3). This causes: (a) `core/` holds 48 files but `IsolationTest` asserts 47; (b) `IsolationTest` separately asserts `core/emails.ex` contains no forbidden `OrganizationInvitation` symbol — and line 698 of emails.ex has a `#`-comment referencing `OrganizationInvitationEmail` that the test's `strip_docstrings` regex does NOT strip (only `@doc`/`@moduledoc` heredocs); (c) `TemplatesLayoutTest` asserts the `core/` file list matches a hardcoded 47-entry manifest; (d) `Features.CoreTest` coverage invariant fails. All four follow from Phase 11 CD-01 (subdir mirrors feature). Moving the file to `organizations/` and wrapping the inline function in `<%= if @organizations? do %>` fixes the entire cluster.

**Primary recommendation:** Execute D-01..D-06 as a single plan with roughly 9 tasks (enumerated in the Planner Checklist below). Golden regeneration is the final task and must be gated on visual diff inspection.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Generator template evaluation (EEx pass) | Build-time (lib/sigra/install/runner.ex) | — | `EEx.eval_file/2` runs at `mix sigra.install` time; operates on template source text before any HEEx compilation. |
| Runtime component rendering (HEEx pass) | Phoenix LiveView runtime | — | `~H"""..."""` heredocs are compiled by Phoenix.LiveView.HTMLEngine at the host app's compile time (after EEx has already run). |
| Feature manifest (which files ship with which feature) | Library — `Sigra.Install.Features.{Core,Organizations}` | — | Per Phase 11 GEN-01, every feature implements the `Sigra.Install.Feature` behaviour. `files/1` is the single source of truth for which templates belong to a feature. |
| Conditional generation (feature flag gates) | EEx conditional blocks in core templates | — | `<%= if @flag do %>` inside a template is the only mechanism that survives both the generator pass and the subsequent HEEx compile pass cleanly. Precedent: `core/user.ex:4` uses `<%= if binary_id do %>`. |
| Install-time subtree layout enforcement | Test harness (`TemplatesLayoutTest`, `IsolationTest`, `Features.CoreTest`) | — | Phase 11 CD-01: subdir location mirrors feature ownership. Enforced via static assertion on `File.ls!`. |
| Golden fixture byte-identity | Test harness (`GoldenDiffTest` + `InstallFixture`) | — | Last-line-of-defense against silent generator drift. Regenerated only with explicit human review. |

## Standard Stack

No new libraries — this is a repair phase operating within the existing `Sigra.Install.*` namespace and `ExUnit` test suite. Inventory of touched modules:

| Module / File | Purpose | Why Touched |
|---------------|---------|-------------|
| `priv/templates/sigra.install/organizations/live/invitation_accept_live.ex` | LiveView template (org feature) | D-01: refactor `render/1` to Elixir-side case |
| `priv/templates/sigra.install/core/emails.ex` | Email builders template (core feature) | D-04.3: wrap `organization_invitation/4` in `<%= if @organizations? do %>` |
| `priv/templates/sigra.install/core/organization_invitation_email.ex` | Standalone email fragment | D-04.2: move to `organizations/` |
| `priv/templates/sigra.install/organizations/organization_invitation_email.ex` | (new location) | D-04.2 destination |
| `lib/sigra/install/features/organizations.ex` | Organizations feature manifest | D-04.1: add the moved file to `files/1` |
| `lib/sigra/install/features/core.ex` | Core feature manifest | D-04.4: no change (file not currently registered) |
| `test/sigra/install/isolation_test.exs` | Template count + forbidden-symbol guards | Passive — the `== 47` test self-corrects after the move; the `OrganizationInvitation`-in-emails.ex regression requires the conditional EEx to strip the `#` comment, OR the comment itself must be removed/reworded |
| `test/sigra/install/templates_layout_test.exs` | `core/` manifest list | Passive — the hardcoded 47-entry `@manifest_post_move` list does NOT include `organization_invitation_email.ex` (Finding 5); no edit required |
| `test/sigra/install/features/core_test.exs` | Features.Core contract tests | May require count assertion bump (38 → 38 likely unchanged; see Finding 3) |
| `test/sigra/install/features/organizations_test.exs` | Features.Organizations contract tests | Add assertion for the new `organizations/organization_invitation_email.ex` entry |
| `test/sigra/install/template_render_test.exs` *(new)* | D-06 item 1 — generator-render unit test | Walk `organizations/**/*.ex`, call `EEx.eval_file/2`, assert `Code.string_to_quoted/1` succeeds |
| `test/sigra/install/template_syntax_test.exs` *(new)* | D-06 item 3 — HEEx-inside-EEx guard | Grep every `~H"""..."""` body for `<%=`/`<%` and fail if found |
| `test/sigra/install/features/coverage_test.exs` *(new, name discretionary)* | D-06 item 2 — per-feature coverage lint | Walk each feature's subdir and assert every on-disk file appears in `feat.files/1` or `feat.migrations/1` |
| `test/fixtures/install_golden/tree/**` + `STDOUT.txt` | Golden fixtures | D-05: regenerate after D-01+D-04 land |

## Concrete Findings (1–10)

### Finding 1 — EEx evaluation order at `lib/sigra/install/runner.ex:81`

```elixir
# runner.ex:80-82
template_path = find_template(source)
content = EEx.eval_file(template_path, binding)
Mix.Generator.create_file(target, content)
```

`EEx.eval_file/2` is called with the binding built in `lib/mix/tasks/sigra.install.ex:89-120` (`build_binding/4`). The binding is a keyword list — it does NOT contain `assigns`. EEx parses the ENTIRE file contents including any `~H"""..."""` heredoc body, because from EEx's standpoint the heredoc is just text with embedded `<%= %>` tags. `@branch` inside a `<%= case @branch do %>` tag expands via the `@` macro to `Kernel.var!(assigns).branch`. With no `assigns` binding, EEx raises `CompileError: undefined variable "assigns"` before the generator even writes the file.

**Why `{...}` HEEx interpolation is safe but `<%= ... %>` is not inside `~H`:** Curly-brace interpolation is not EEx syntax; EEx treats `{@organization.name}` as opaque text and passes it through to runtime HEEx compilation where `@organization` correctly resolves against LiveView `assigns`. The entire Phase 16/17 core template corpus uses only `{...}` inside `~H` (Finding 2). `invitation_accept_live.ex` is the sole outlier.

**The `organizations?` binding flag:** Confirmed present in `lib/mix/tasks/sigra.install.ex:114`:
```elixir
organizations?: Keyword.get(opts, :organizations, true),
```
The key is `:organizations?` with the trailing `?`. D-04.3's conditional block must use `<%= if @organizations? do %>` (EEx supports `@key` sugar against the keyword binding through `EEx.SmartEngine`, but to be safe with `EEx.eval_file/2`'s default options, use `<%= if organizations? do %>` without the `@` — see Finding 6 for precedent).

**Precedent from `core/user.ex:4`:**
```eex
<%= if binary_id do %>
  @primary_key {:id, :binary_id, autogenerate: true}
<% end %>
```
Uses the bare keyword key (no `@` prefix). The `@<key>` form is HEEx-only; EEx templates rendered via `EEx.eval_file/2` with a keyword binding access keys by their atom name directly. **The planner MUST use `<%= if organizations? do %>`, NOT `<%= if @organizations? do %>`.**

### Finding 2 — `invitation_accept_live.ex` line 235 area + 7-branch structure

Full file read. Observations:

- The file is 416 lines.
- `render/1` is at line 228-253. Line 235 is the offending `<%= case @branch do %>` inside the `~H"""` heredoc that starts at line 230.
- The wrapper is `<div id="invitation-accept-page">` with `<.flash kind={:info} flash={@flash} />` + `<.flash kind={:error} flash={@flash} />` immediately inside (lines 231-233).
- Per-branch helpers already exist and already return `~H` sigils: `render_signup/1` (255), `render_accept/1` (299), `render_mismatch/1` (337), `render_invalid/1` (366), `render_expired/1` (378), `render_revoked/1` (390), `render_already_accepted/1` (402).
- **Critical invariant to preserve:** `render_mismatch/1` at line 337-364 MUST contain zero `phx-click="accept..."`/`phx-submit="accept..."` — enforced by plan-checker grep per comments at lines 330-336. The refactor MUST NOT accidentally add flash markup to this branch that references an accept action.
- Event handlers `handle_event("accept_invitation", ...)` + `handle_event("accept_with_signup", ...)` at lines 118-216 have defensive raising fallback clauses for non-accept branches (Jetstream #907 structural defense). These stay untouched.

**Recommended refactor shape (per D-01, planner discretion on wrapper placement):**

**Option A — Thin dispatcher with parent `~H` wrapper (preferred, preserves the `<div>` wrapper + flash markup in one place):**

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

The parent `~H"""` contains only curly-brace `{render_branch(assigns)}` interpolation — no `<%= ... %>` tags. EEx passes the entire heredoc through untouched. At runtime, HEEx compiles the `{...}` and dispatches to the per-branch helper. This keeps the `<div id="invitation-accept-page">` + flashes in exactly one place (unchanged from current behavior) and requires no changes to the 7 `render_<branch>/1` helpers.

**Option B — Elixir-side `case` with wrapper lifted into each branch:** Matches D-01's code example literally but duplicates the wrapper seven times. Not recommended unless the planner wants each branch to fully own its top-level markup.

The planner should pick Option A and cite D-01's "Planner picks concrete shape" discretion.

### Finding 3 — `Features.Core.files/1` does NOT currently register `organization_invitation_email.ex`

Grep confirmed: `lib/sigra/install/features/core.ex:191-193` shows the email block registers only `core/emails.ex` and `core/auth_mailer.ex`. There is NO entry for `core/organization_invitation_email.ex`. The file sits on disk as an orphan.

**Consequence for D-04.4:** The "update `Features.Core.files/1` so core drops `organization_invitation_email.ex` from its manifest" task is a no-op — there's nothing to drop. The CONTEXT.md wording is slightly misleading here; the planner should phrase the task as "verify `Features.Core.files/1` has no reference to `organization_invitation_email.ex`" instead of "remove".

**The real fix is additive:** add the (moved) file to `Features.Organizations.files/1` at the appropriate spot. Suggested placement is after the Phase 17 `invitation_accept_live.ex` entry at `lib/sigra/install/features/organizations.ex:89-95`:

```elixir
# Phase 17 D-12 / Phase 24: organization-invitation email fragment.
# Standalone reference copy mirroring the canonical inline implementation
# in core/emails.ex. Generated under the organizations feature so that
# --no-organizations cleanly omits it (Phase 11 CD-01 subdir ownership).
{:eex, "organizations/organization_invitation_email.ex",
 Path.join(["lib", otp_app, ctx, "organization_invitation_email.ex"])},
```

Note: the existing fragment currently uses `<%= app_name %>` but has no `context_module` / `web_module` anchoring. The planner must decide the target path. A reasonable target mirrors `api_token_created_email.ex` (another standalone fragment under `core/` — also an email reference, also unwired). Alternatively, it may be appropriate to target a `priv/` or `docs/` location since it's documentation, not code. **Planner call.**

### Finding 4 — `organizations/router_injection.ex` + `user_auth_on_mount_assign_user_organizations.ex` both EXIST on disk

`ls priv/templates/sigra.install/organizations/` confirms:
- `router_injection.ex` — present
- `user_auth_on_mount_assign_user_organizations.ex` — present

Both are read by `Sigra.Install.Features.Organizations.read_template!/1` at lines 156 and 167 respectively. DEF-18-01 Failures 2 & 3 are already resolved on disk as of commit `1e918cb`. The planner should add a single verification task:

```elixir
test "Organizations injection template files exist" do
  assert File.exists?("priv/templates/sigra.install/organizations/router_injection.ex")
  assert File.exists?("priv/templates/sigra.install/organizations/user_auth_on_mount_assign_user_organizations.ex")
end
```

Or fold the assertion into the D-06 item 2 coverage lint, which will catch the same regression class automatically.

### Finding 5 — `core/` file count + `TemplatesLayoutTest` manifest alignment

- `priv/templates/sigra.install/core/` currently has 48 files (`ls | wc -l` = 48).
- `IsolationTest.contains exactly 47 templates` asserts `length(files) == 47` at `test/sigra/install/isolation_test.exs:82-84`.
- `TemplatesLayoutTest.@manifest_post_move` at `test/sigra/install/templates_layout_test.exs:14-62` lists exactly 47 basenames, and `organization_invitation_email.ex` is NOT in that list.
- After moving `organization_invitation_email.ex` out of `core/`, `core/` drops to 47 files. BOTH tests pass without edit.

**Critical:** No test file needs editing for the count. The planner should NOT add an edit task to either test. If the planner finds themselves editing `@manifest_post_move` or the `== 47` assertion, that's a sign the move went wrong.

**Secondary finding — the `OrganizationInvitation` forbidden-symbol check:** `IsolationTest` at lines 22-32 forbids the exact symbol `"OrganizationInvitation"` in every `core/*.ex` file. After the move, `core/emails.ex` still contains:

- Line 698 (a `#` comment): `# Canonical inline copy of the OrganizationInvitationEmail fragment` — MATCHES `"OrganizationInvitation"`.
- Line 707 (inside `@doc """..."""`): `invitation` — `%OrganizationInvitation{email, role, expires_at}` — MATCHES.

`strip_docstrings/1` at lines 91-95 uses regexes `~r/@moduledoc\s+"""[\s\S]*?"""/m` and `~r/@doc\s+"""[\s\S]*?"""/m`. These strip `@doc """..."""` heredocs but NOT plain `#` comments. So line 707's `@doc` reference IS stripped; line 698's `#` comment is NOT.

**Planner fix options (pick one):**

1. **Reword the line 696-700 comment** to avoid the literal symbol: e.g., "Canonical inline copy of the invitation email fragment shipped at organizations/organization_invitation_email.ex" — no `OrganizationInvitation` substring.
2. **Move the comment inside an `@moduledoc`-style attribute** — too invasive for a repair phase.
3. **Wrap the entire `organization_invitation/4` block (lines 696-801) in `<%= if organizations? do %>` ... `<% end %>`.** With `organizations?: true` in the binding by default, the block renders under the default install leg. With `--no-organizations`, the block is elided, and the compiled `emails.ex` in the host app contains neither the comment nor the function. For the IsolationTest, which reads the TEMPLATE (not the compiled output), the comment still exists on disk — so **this alone does not fix the isolation failure.** Option 3 only fixes the runtime compile-time reference leak in the generated app, not the on-disk-template-scanning test.

**Recommended combination:** Do BOTH (1) and (3). Reword the comment for IsolationTest, AND add the conditional EEx block so `--no-organizations` produces an `emails.ex` that does not define `organization_invitation/4` (which would otherwise reference `invitation.email` at runtime — fine — but the whole point per D-04.3 is to match the `--no-organizations` leg's expectation of an org-free template).

Also check the function's helper usage: `organization_invitation/4` calls `inviter_display_name/1` and `humanize_role/1`, defined at lines 793-801. If the function is conditional, those helpers may become unused warnings under `--no-organizations`. The planner must also wrap those helper defs in the same conditional, OR mark them with a `# _org` suffix and keep them always-defined (Elixir will not warn on unused private functions under some configurations, but `mix compile --warnings-as-errors` will). **Recommended:** wrap helpers + function together in a single `<%= if organizations? do %>` block to avoid compiled-but-unused private functions.

### Finding 6 — Fixture binding for the D-06 item 1 render test

The full binding built at `lib/mix/tasks/sigra.install.ex:97-119`:

```elixir
[
  context_module: "MyApp.Accounts",          # inspect form
  context_alias: "Accounts",
  schema_module: "MyApp.Accounts.User",       # inspect form
  schema_alias: "User",
  table_name: "users",
  web_module: "MyAppWeb",                     # inspect form (Module.concat then inspect)
  app_module: "MyApp",                        # inspect form
  app_name: "MyApp",
  from_email: "noreply@example.com",
  log_in_url: "/users/log_in",
  otp_app: :my_app,                           # atom
  repo_module: "MyApp.Repo",                  # inspect form
  binary_id: true,
  live: true,
  api: false,
  jwt: false,
  organizations?: true,
  adapter: :postgres,
  reset_password_url: "#{MyAppWeb.Endpoint.url()}/users/reset-password",  # string with interpolation
  settings_url: "#{MyAppWeb.Endpoint.url()}/users/settings",
  opts: [live: true, api: false, jwt: false, binary_id: true, organizations: true],
  migration_timestamps: %{}                    # added by Runner per-feature at runner.ex:60
]
```

The existing `Features.CoreTest` uses `@binding` at `test/sigra/install/features/core_test.exs:20-41` which is a minimal shape matching this. The new `template_render_test.exs` should reuse it or lift it into a shared helper.

**Templates that need extra binding keys beyond the base set:** Scan of `priv/templates/sigra.install/organizations/` found the binding keys used are `web_module`, `app_module`, `otp_app` (implied via paths), and the contents don't interpolate `migration_timestamps` or `opts`. The minimal render-test binding is:

```elixir
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
```

For each template under `priv/templates/sigra.install/organizations/` (recursively), the test body should do:

```elixir
for path <- Path.wildcard("priv/templates/sigra.install/organizations/**/*.ex") do
  content = EEx.eval_file(path, @render_binding)

  assert {:ok, _ast} = Code.string_to_quoted(content),
         "template #{path} rendered content is not valid Elixir"
end
```

Path wildcard skips `.exs` migration files naturally (it globs `.ex`). Note: the wildcard captures `organizations/live/organizations_live/index.ex` and `new.ex`, both of which exist.

### Finding 7 — Existing install-test conventions to match

Scanned `test/sigra/install/` structure and observed:

- `use ExUnit.Case, async: true` for unit tests; `async: false` when touching tmp filesystem (GoldenDiff, Idempotency).
- `@moduletag` for suite categorization: `:isolation`, `:golden`, `:integration`.
- Flat module names: `Sigra.Install.<TestName>` — no extra nesting under `Features/` unless feature-specific (e.g., `Sigra.Install.Features.CoreTest`).
- Descriptive `describe` blocks per feature area; test bodies short and assertion-heavy.
- Binding shape reuses `@binding` at the top of the module.
- `File.ls!` + `Enum.each` for per-file iteration with assertion inside a `refute content =~ symbol` error message that names the file and what went wrong.

The new `template_render_test.exs`, `template_syntax_test.exs`, and `features/coverage_test.exs` should all follow these conventions.

**Suggested module names (planner discretion per D-06 Claude's Discretion):**
- `Sigra.Install.TemplateRenderTest` — test/sigra/install/template_render_test.exs
- `Sigra.Install.TemplateSyntaxTest` — test/sigra/install/template_syntax_test.exs
- `Sigra.Install.Features.CoverageTest` — test/sigra/install/features/coverage_test.exs

### Finding 8 — CI matrix leg already scaffolded in `.github/workflows/ci.yml:151-223`

The `install_matrix` job already exists and runs both `""` (default) and `"--no-organizations"`. It is NOT skipped. Phase 24 does not add the job — Phase 24 simply makes the default leg pass by shipping D-01 + D-04.

```yaml
# lines 154-162
strategy:
  fail-fast: false
  matrix:
    flags:
      - ""
      - "--no-organizations"
```

The job compiles, migrates, and runs `mix test` against a fresh tmp app. Currently, the `""` leg fails at `mix sigra.install` time because of DEF-18-01. After D-01 lands, the leg reaches `mix compile --warnings-as-errors` (line 220), at which point D-04 matters because the generated `emails.ex` must compile under `--no-organizations` without referencing `OrganizationInvitation`.

**D-06 item 4 reduces to:** "Verify `install_matrix` job is green after D-01 + D-04 land." No CI YAML edits required unless a new assertion step is added.

### Finding 9 — Features behaviour contract shape

From `lib/sigra/install/features/organizations.ex:40-97`, `files/1` returns a list of `{:eex, source_path, target_path}` tuples. Keys are derived from the binding:

```elixir
otp_app = Keyword.fetch!(binding, :otp_app) |> to_string()
web = "#{otp_app}_web"
```

Targets are constructed via `Path.join/1` to ensure project-relative, OS-neutral paths. The edit to add `organization_invitation_email.ex` follows this pattern (see Finding 3 for the suggested tuple).

No schema-level edit to `@behaviour Sigra.Install.Feature` required. The behaviour contract is stable.

### Finding 10 — Golden fixture regeneration mechanics

From `test/sigra/install/golden_diff_test.exs` and `test/support/install_fixture.ex`:

- The fixture dir is `test/fixtures/install_golden/` with `STDOUT.txt` + `tree/` subdir.
- `InstallFixture.setup_tmp_app/1` runs `mix phx.new sigra_install_golden_tmp --no-assets --no-mailer --no-install`, patches the generated `mix.exs` with `{:sigra, path: "..", override: true}`, runs `mix deps.get`, `mix compile`, then `mix sigra.install Accounts User users --yes`.
- The runbook reference is `.planning/phases/11-generator-feature-system/11-01-SUMMARY.md` (cited at lines 122-131 in golden_diff_test.exs).
- There is no `mix sigra.install.golden` task or `mix test --only snapshot` tag as of today — the runbook for regeneration is manual. The planner must document the exact steps in the fixture-rebless task:
  1. Run `mix test test/sigra/install/golden_diff_test.exs` to confirm failure (baseline).
  2. Manually invoke `Sigra.Test.InstallFixture.setup_tmp_app/1` in `iex -S mix` to produce a fresh tmp app + capture the output tree.
  3. Normalize: `InstallFixture.normalize_tree/2` + `normalize_stdout/2`.
  4. Copy normalized tree + stdout into `test/fixtures/install_golden/`.
  5. `git diff test/fixtures/install_golden/` and **visually inspect** per D-05.
  6. `mix test test/sigra/install/golden_diff_test.exs` — must now pass.
  7. Commit in the dedicated fixture-rebless task with the diff summary in the commit message.

The expected diff shape after Phase 24:
- `tree/lib/sigra_install_golden_tmp_web/live/invitation_accept_live.ex` — content updated (new Elixir-side case + `render_branch/1` dispatcher).
- `tree/lib/sigra_install_golden_tmp/accounts/emails.ex` — content updated (the `# Canonical inline copy ...` comment is reworded; the block may be wrapped in conditional EEx which under the default leg renders identically except for any whitespace drift — planner must check).
- `tree/lib/sigra_install_golden_tmp/accounts/organization_invitation_email.ex` — **new file** in the tree (if the planner's target path is `lib/<otp>/<ctx>/organization_invitation_email.ex`).
- `STDOUT.txt` — new `* creating ...organization_invitation_email.ex` line + possibly reordering.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Conditional template generation | Custom AST post-processor or regex strip | `<%= if organizations? do %> ... <% end %>` | Already precedent at `core/user.ex:4`; EEx handles it natively; no need to invent a new mechanism. |
| Template AST verification | Regex matching balanced braces | `Code.string_to_quoted/1` on the rendered output | Built-in, handles every valid Elixir construct, returns `{:ok, ast}` / `{:error, reason}`. |
| Golden fixture rebless tooling | Custom mix task `sigra.install.golden` | Manual runbook (Finding 10) | The existing helpers in `InstallFixture` are already sufficient; a dedicated mix task is nice-to-have but out of scope for a repair phase. |
| HEEx-inside-EEx detection | Parser-level HEEx inspection | Narrow regex on `~H"""..."""` bodies searching for `<%` / `<%=` (not `<%%` / `<%%=`) | D-06 item 3 explicitly specifies the narrowest possible check. |
| Per-feature file coverage | Hand-list every file in a test fixture | `File.ls!` walk on the feature's subdir vs. `feature.files/1` + `feature.migrations/1` set difference | Automatic; survives future additions without test edits. |

**Key insight:** Every bug in DEF-18-01 and DEF-18-02 is a CLASS of bug that current tests don't catch. The four tests in D-06 are each the narrowest possible guard for that class. Do not generalize.

## Common Pitfalls

### Pitfall 1: `@foo` vs `foo` in EEx templates
**What goes wrong:** Writing `<%= if @organizations? do %>` in an EEx template rendered via `EEx.eval_file/2` with a keyword binding.
**Why it happens:** HEEx's `@foo` sugar is `Kernel.var!(assigns).foo`. EEx SmartEngine supports `@foo` too, but `EEx.eval_file/2` uses `EEx.Engine` by default, which treats `@` as Elixir module attribute syntax — compile error.
**How to avoid:** Use the bare key: `<%= if organizations? do %>`. Verify by testing against `core/user.ex:4`'s precedent (`<%= if binary_id do %>`).

### Pitfall 2: Accidentally removing the Jetstream #907 structural defense
**What goes wrong:** Refactoring `render/1` and accidentally moving markup between branches, causing `render_mismatch/1` to inherit accept-button markup from another branch.
**Why it happens:** The `<div id="invitation-accept-page">` wrapper + flashes are not branch-specific, but individual branches ARE responsible for their own markup. If the refactor lifts per-branch markup, it's easy to accidentally move the wrong section.
**How to avoid:** Use the Option A "thin dispatcher" shape (Finding 2). The seven `render_<branch>/1` helpers remain byte-identical — only `render/1` changes. Run the plan-checker grep explicitly as a task acceptance criterion: `refute File.read!("...invitation_accept_live.ex") =~ ~r/render_mismatch.*?phx-(click|submit)=\"accept/s`.

### Pitfall 3: Forgetting `mix compile --warnings-as-errors` when conditionally elided
**What goes wrong:** Wrapping `organization_invitation/4` in `<%= if organizations? do %>` without also wrapping its helper functions (`inviter_display_name/1`, `humanize_role/1`, and any other private helper used only by that function), resulting in "unused private function" warnings under `--no-organizations` that fail `mix compile --warnings-as-errors` in the CI matrix leg.
**Why it happens:** Helpers are defined at module scope and not branch-specific.
**How to avoid:** Wrap the helpers in the same conditional block. Double-check by grepping the helper names in the whole file to make sure they are NOT called outside the conditional block.

### Pitfall 4: Golden fixture rebless without visual diff inspection
**What goes wrong:** Running the rebless mechanically and committing the resulting diff without reading it, allowing silent drift to slip through.
**Why it happens:** The rebless is tedious, and the diff is large.
**How to avoid:** Per D-05, the planner's task acceptance criterion MUST include "diff visually inspected; matches expected shape from Finding 10". Attach the diff (or a summary) to the commit message.

### Pitfall 5: EEx comment vs `@doc` docstring stripping in IsolationTest
**What goes wrong:** Moving `#`-comment content referencing `OrganizationInvitation` around in `core/emails.ex` and expecting `IsolationTest.strip_docstrings/1` to strip it. It only strips `@doc` and `@moduledoc` heredocs.
**Why it happens:** Regex at `isolation_test.exs:91-94` is narrow by design.
**How to avoid:** Reword any `#` comments referencing the forbidden symbol, OR move them into an `@moduledoc`/`@doc` attribute. See Finding 5 "Secondary finding".

## Runtime State Inventory

Not applicable — this is a code-only repair phase. No database, live service config, OS registration, secrets, or build artifacts are affected.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — repair is purely template/test code | none |
| Live service config | None | none |
| OS-registered state | None | none |
| Secrets/env vars | None | none |
| Build artifacts | `test/fixtures/install_golden/tree/` + `STDOUT.txt` — not runtime state, but treated as fixture artifacts that must be regenerated per D-05 | regenerate via manual runbook (Finding 10) |

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir | All work | presumed | matches `.tool-versions` | — |
| Erlang/OTP | All work | presumed | matches `.tool-versions` | — |
| mix | All work | presumed | bundled | — |
| phx_new archive | `GoldenDiffTest` / `InstallFixture.setup_tmp_app/1` | presumed in CI via `mix archive.install --force hex phx_new` at ci.yml:190 | latest | — |
| PostgreSQL | `install_matrix` CI job | CI service (postgres:15) | 15 | — |

No new dependencies introduced. Phase 24 operates entirely within the existing toolchain.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir built-in) |
| Config file | `test/test_helper.exs` |
| Quick run command | `mix test test/sigra/install/` |
| Full suite command | `mix test` |

### Phase Requirements → Test Map

Phase 24 has no REQ-IDs from REQUIREMENTS.md (it's a defect-driven repair phase). The must-haves derive from CONTEXT.md D-01..D-06 and the four failing tests from Phase 18 Plan 18-02 SUMMARY. Map:

| Req (derived) | Behavior | Test Type | Automated Command | File Exists? |
|---|---|---|---|---|
| D-01 fix | `mix sigra.install` renders `invitation_accept_live.ex` without EEx CompileError | unit | `mix test test/sigra/install/template_render_test.exs` | Wave 0 |
| D-01 narrow regression guard | No `~H"""..."""` heredoc anywhere in `priv/templates/sigra.install/**/*.ex` contains raw `<%=`/`<%` | unit | `mix test test/sigra/install/template_syntax_test.exs` | Wave 0 |
| D-01 Jetstream #907 preservation | `render_mismatch/1` contains zero `phx-(click|submit)=\"accept` | unit (existing plan-checker test) | `mix test` (grep baked in) | pre-existing |
| D-02 existence verification | `router_injection.ex` + `user_auth_on_mount_assign_user_organizations.ex` both exist under `organizations/` | unit | covered by D-06 item 2 coverage test | Wave 0 |
| D-04.1-2 feature registration | `organization_invitation_email.ex` registered under Features.Organizations | unit | `mix test test/sigra/install/features/organizations_test.exs` | edit existing |
| D-04.3 conditional EEx | `--no-organizations` leg generates `emails.ex` with no `organization_invitation/4` + compiles clean | integration | `mix test test/sigra/install/features/coverage_test.exs` + CI `install_matrix` job | Wave 0 |
| D-04 count baselines | `core/` has 47 files; `emails.ex` has no `OrganizationInvitation` symbol in non-docstring code | unit | `mix test test/sigra/install/isolation_test.exs test/sigra/install/templates_layout_test.exs` | pre-existing |
| D-05 fixture identity | Golden fixture byte-for-byte matches | integration | `mix test test/sigra/install/golden_diff_test.exs` | pre-existing |
| D-06 item 1 | Every `organizations/**/*.ex` renders and parses as Elixir | unit | `mix test test/sigra/install/template_render_test.exs` | Wave 0 |
| D-06 item 2 | Every on-disk file in a feature's subdir is referenced by `files/1` or `migrations/1` | unit | `mix test test/sigra/install/features/coverage_test.exs` | Wave 0 |
| D-06 item 3 | HEEx-inside-EEx guard | unit | `mix test test/sigra/install/template_syntax_test.exs` | Wave 0 |
| D-06 item 4 | `install_matrix` CI leg green | integration (GHA) | `.github/workflows/ci.yml install_matrix` job on PR | pre-existing — pass after D-01+D-04 |

### Sampling Rate

- **Per task commit:** `mix test test/sigra/install/` (the install test suite — fast, unit-only, scoped).
- **Per wave merge:** `mix test` (full suite including golden fixture integration).
- **Phase gate:** Full `mix test` green + `install_matrix` CI leg green on the PR.

### Wave 0 Gaps

- [ ] `test/sigra/install/template_render_test.exs` — new file, covers D-06 item 1
- [ ] `test/sigra/install/template_syntax_test.exs` — new file, covers D-06 item 3
- [ ] `test/sigra/install/features/coverage_test.exs` — new file, covers D-06 item 2 (name discretionary)
- [ ] (no framework install needed — ExUnit is built-in, test infrastructure is already in place)

## Planner Checklist

The planner should author `24-01-repair-phase-16-17-org-templates-PLAN.md` with the following tasks (suggested order — dependencies noted):

1. **Task 1 — Fix `invitation_accept_live.ex` render/1** (D-01)
   - Edit `priv/templates/sigra.install/organizations/live/invitation_accept_live.ex` lines 228-253.
   - Apply Option A (Finding 2): add `defp render_branch/1` dispatcher with 7 clauses, replace the `<%= case ... %>` block in `render/1` with `{render_branch(assigns)}`.
   - DO NOT touch the 7 `render_<branch>/1` helpers or the event handlers.
   - Acceptance: `EEx.eval_file("priv/templates/sigra.install/organizations/live/invitation_accept_live.ex", binding)` succeeds; `render_mismatch/1` body still has zero accept controls.

2. **Task 2 — Add D-06 item 3 HEEx-inside-EEx guard test** (Wave 0 / before Task 3)
   - Create `test/sigra/install/template_syntax_test.exs`.
   - Walk `priv/templates/sigra.install/**/*.ex`, for each file extract every `~H"""..."""` heredoc and assert it contains neither `<%=` nor `<%` (unescaped). Matches `<%%=` and `<%%` are fine.
   - Acceptance: test green after Task 1; regresses the file back and confirm failure, then reapply Task 1 fix.

3. **Task 3 — Add D-06 item 1 generator-render unit test** (after Task 1)
   - Create `test/sigra/install/template_render_test.exs`.
   - Define `@render_binding` per Finding 6. Walk `Path.wildcard("priv/templates/sigra.install/organizations/**/*.ex")`, call `EEx.eval_file/2` with the binding, assert `{:ok, _} = Code.string_to_quoted(content)`.
   - Acceptance: test green.

4. **Task 4 — Move `organization_invitation_email.ex` from `core/` to `organizations/`** (D-04.2)
   - `git mv priv/templates/sigra.install/core/organization_invitation_email.ex priv/templates/sigra.install/organizations/organization_invitation_email.ex`.
   - Acceptance: file exists only under `organizations/`; `core/` has exactly 47 files; `IsolationTest.contains exactly 47 templates` passes; `TemplatesLayoutTest` passes without any test edit.

5. **Task 5 — Register the moved file in `Features.Organizations.files/1`** (D-04.1)
   - Edit `lib/sigra/install/features/organizations.ex`, append a tuple per Finding 3 (planner picks exact target path — recommended `lib/<otp>/<ctx>/organization_invitation_email.ex` or similar).
   - Update `test/sigra/install/features/organizations_test.exs` to assert the new entry is present.
   - Acceptance: both tests green.

6. **Task 6 — Wrap `organization_invitation/4` (+ its helpers) in `<%= if organizations? do %> ... <% end %>`** (D-04.3)
   - Edit `priv/templates/sigra.install/core/emails.ex` lines 696-801 (includes the function, `inviter_display_name/1`, and `humanize_role/1`).
   - ALSO reword the `#` comment at lines 696-700 to remove the `OrganizationInvitationEmail` substring (Finding 5 secondary).
   - Use bare `organizations?` (no `@` prefix) per Finding 1 precedent.
   - Acceptance: `IsolationTest.priv/templates/sigra.install/core/*` forbidden-symbol test passes; the conditional renders under default leg (via golden fixture); `--no-organizations` leg compiles without warnings.

7. **Task 7 — Add D-06 item 2 feature coverage lint test** (after Task 5)
   - Create `test/sigra/install/features/coverage_test.exs` (or name of planner's choice).
   - For each `feat` in `[Features.Core, Features.Organizations]`, walk `priv/templates/sigra.install/<subdir>/**/*.{ex,exs}`, build the on-disk set, build `feat.files/1 ++ feat.migrations/1` source-path set, assert disk ⊆ manifest.
   - Acceptance: test green; also catches DEF-18-01 Failures 2 & 3 regression (router_injection.ex + user_auth_on_mount_assign_user_organizations.ex must be referenced by Organizations manifest via `read_template!` OR be in the `files/1` list — planner decides coverage semantics).

8. **Task 8 — Regenerate golden fixtures** (D-05; runs after Tasks 1-7 land)
   - Manually rebless per Finding 10 runbook.
   - Inspect diff against expected shape (Finding 10 last bullets). Attach diff summary to commit message.
   - Acceptance: `mix test test/sigra/install/golden_diff_test.exs` green; diff visually inspected.

9. **Task 9 — Verify full install suite baseline + CI matrix leg** (phase gate)
   - Run `mix test test/sigra/install/` — expect 0 failures.
   - Push PR, watch `install_matrix` GHA job green on both `""` and `"--no-organizations"`.
   - Acceptance: full suite green; both matrix legs green; Phase 18 Plan 18-03 no longer blocked.

**Optional polish task (planner discretion):** Add a `Sigra.Test.InstallFixture.render_template/2` helper that exposes the render-and-parse pipeline used by Task 3, so future phases can reuse it.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `EEx.eval_file/2` with a keyword binding does NOT support the `@key` sugar (only bare `key`) | Finding 1 | LOW — verified against existing precedent `core/user.ex:4`; if wrong, the conditional block falls back to bare key anyway |
| A2 | `mix compile --warnings-as-errors` in the `install_matrix` CI step will flag unused private helper functions | Pitfall 3 | LOW — standard Elixir compile behavior; worst case the helpers don't warn and the wrap-in-conditional is a no-op safety measure |
| A3 | The target path for the moved `organization_invitation_email.ex` can be any path under `lib/<otp>/<ctx>/` | Finding 3 / Planner Task 5 | MEDIUM — planner picks; if the chosen path conflicts with a future reference, a follow-up phase renames it |
| A4 | Reworded `#` comment in `emails.ex` will not cause the conditional EEx block's renderered output to drift the golden fixture in unexpected ways | Finding 10 | LOW — all drift is visible in the Task 8 diff inspection step |

All other claims are VERIFIED via file read or CITED from the CONTEXT.md / existing source.

## Open Questions

1. **Target path for the moved `organization_invitation_email.ex`**
   - What we know: The current file is an email fragment reference (a doc/comment-heavy copy of `organization_invitation/4`). Under `core/` it was orphaned.
   - What's unclear: Should it land in `lib/<otp>/<ctx>/organization_invitation_email.ex` (code path), or `priv/static/sigra/organization_invitation_email.ex.reference` (doc path), or nowhere at all (and instead just let the inline copy be the canonical)?
   - Recommendation: Keep it as a code-path file at `lib/<otp>/<ctx>/organization_invitation_email.ex` — matches the `api_token_created_email.ex` pattern. The file is short and harmless; having it under the org feature's ownership satisfies D-04.1 and makes the move mechanical. Planner decides in Task 5.

2. **Should the HEEx-inside-EEx guard (Task 2) scan `core/` too, or only `organizations/`?**
   - D-06 item 3 wording says "walk `priv/templates/sigra.install/**/*.ex`" — all files. The planner should follow the literal wording. Core templates already don't mix EEx and HEEx inside heredocs (Finding 2 scan); the test should pass immediately for core/ and would catch any future regression.

3. **Does Task 7's coverage lint catch the `router_injection.ex` / `user_auth_on_mount_assign_user_organizations.ex` injection templates?**
   - Those two files are not in `Features.Organizations.files/1` — they are read via `read_template!/1` from within `injections/1`. The coverage lint must therefore either (a) inspect the `injections/1` return value and extract referenced paths from content, or (b) maintain a whitelist of "files read via injections". Option (b) is simpler; planner decides.

## Sources

### Primary (HIGH confidence — direct file reads)
- `priv/templates/sigra.install/organizations/live/invitation_accept_live.ex` — full file, 416 lines
- `priv/templates/sigra.install/core/emails.ex` — offsets 1-120 and 690-906
- `priv/templates/sigra.install/core/organization_invitation_email.ex` — full file, 114 lines
- `priv/templates/sigra.install/core/user.ex` — line 4 (conditional EEx precedent)
- `lib/mix/tasks/sigra.install.ex` — full file, 141 lines
- `lib/sigra/install/features/organizations.ex` — full file, 181 lines
- `lib/sigra/install/features/core.ex` — grep for `organization_invitation` + `emails.ex` references
- `lib/sigra/install/runner.ex` — EEx.eval_file callsite at line 81
- `test/sigra/install/isolation_test.exs` — full file, 96 lines
- `test/sigra/install/templates_layout_test.exs` — full file, 82 lines
- `test/sigra/install/features/core_test.exs` — offsets 1-280
- `test/sigra/install/features/organizations_test.exs` — first 50 lines
- `test/sigra/install/golden_diff_test.exs` — full file, 199 lines
- `test/support/install_fixture.ex` — first 80 lines
- `.github/workflows/ci.yml` — install_matrix job at lines 151-223
- `.planning/phases/18-backfill-organizations-generator-wiring/deferred-items.md` — full file
- `.planning/phases/24-repair-phase-16-17-organizations-generator-templates/24-CONTEXT.md` — full file
- `.planning/REQUIREMENTS.md` — full file
- `.planning/STATE.md` — full file
- `bash ls` on `priv/templates/sigra.install/organizations/` + `core/` — file presence verified

### Secondary (MEDIUM confidence — cited without re-verification in this session)
- Phase 11 CD-01 "subdir mirrors feature ownership" — cited from CONTEXT.md canonical_refs; not re-read
- Phase 16/17 CONTEXT.md decisions — cited from CONTEXT.md canonical_refs; not re-read
- `.planning/phases/18-backfill-organizations-generator-wiring/18-02-upgrade-task-and-backfill-SUMMARY.md` — referenced for "5 pre-existing failures" count, not re-read

### Tertiary (LOW confidence)
- None. All load-bearing claims are VERIFIED.

## Metadata

**Confidence breakdown:**
- EEx/HEEx evaluation order (Finding 1): HIGH — directly verified against `runner.ex:81` + `core/user.ex:4` precedent + file contents.
- `invitation_accept_live.ex` refactor shape (Finding 2): HIGH — full file read, all 7 render helpers located, invariant comments found.
- Features.Core / emails.ex drift (Finding 3, 5): HIGH — grep + file content verified.
- File existence on disk (Finding 4): HIGH — `ls` output captured.
- Fixture binding shape (Finding 6): HIGH — direct read of `sigra.install.ex:89-120` + `features/core_test.exs:20-41` binding.
- Test conventions (Finding 7): HIGH — multiple test files read.
- CI workflow state (Finding 8): HIGH — direct read of ci.yml:151-223.
- Features behaviour contract (Finding 9): HIGH — direct read of `features/organizations.ex:40-97`.
- Golden fixture mechanics (Finding 10): MEDIUM — helper file partially read; runbook is in a phase SUMMARY.md not read in full; acceptable since D-05 allows planner discretion on the rebless procedure.

**Research date:** 2026-04-14
**Valid until:** 2026-05-14 (30 days — targets are stable template + test files with no external dependency churn)

## RESEARCH COMPLETE
