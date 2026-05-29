# Phase 139: Recipe-Contract Integrity & Sister-Repo Verification - Pattern Map

**Mapped:** 2026-05-29
**Files analyzed:** 3 (1 new, 2 existing edits)
**Analogs found:** 2 / 1 (both analogs serve the one new file; edit targets need no analog)

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `test/sigra/recipes/companion_lib_contract_test.exs` | test (contract fixture) | file-I/O | `test/sigra/planning/phase_50_nyquist_docs_contract_test.exs` | exact (same role, same data flow — `root()`/`read!()` helper + `for` loop assertion) |
| `guides/recipes/companion-libs/lockspire.md` (edit ~line 93-95) | documentation | n/a | n/a — targeted fix, no analog needed |
| `guides/recipes/companion-libs/rulestead.md` (edit ~lines 123-153) | documentation | n/a | n/a — targeted fix, no analog needed |

---

## Pattern Assignments

### `test/sigra/recipes/companion_lib_contract_test.exs` (test, file-I/O)

**Primary analog:** `test/sigra/planning/phase_50_nyquist_docs_contract_test.exs`
**Secondary reference:** `test/sigra/guides_dx02_test.exs` (glob + per-file `File.read!` idiom)

---

#### Module header pattern (from `phase_50_nyquist_docs_contract_test.exs`, lines 1-9)

```elixir
defmodule Sigra.Planning.Phase50NyquistDocsContractTest do
  @moduledoc """
  Nyquist validation for phase 50 documentation + CI wiring (no subprocess harness).
  ...
  """

  use ExUnit.Case, async: true
```

Copy this shape exactly: module name mirrors file path, `@moduledoc` states the purpose, `use ExUnit.Case, async: true` — no DB, no tags, no special setup.

---

#### `root()` / `read!()` path helper pattern (from `phase_50_nyquist_docs_contract_test.exs`, lines 14-20)

```elixir
defp root do
  Path.expand("../../..", __DIR__)
end

defp read!(rel) do
  root() |> Path.join(rel) |> File.read!()
end
```

**Path arithmetic for the new file** — the new fixture lives at
`test/sigra/recipes/companion_lib_contract_test.exs`, which is two levels deep from
`test/sigra/` (not three like the phase-50 test). Use:

```elixir
defp root do
  Path.expand("../..", __DIR__)
  # __DIR__ = <repo_root>/test/sigra/recipes
  # two ".." → <repo_root>
end
```

Do NOT add `read!` unless you need it — the fixture calls `File.read!(path)` on glob
results directly. The `root()` helper is still required to anchor the glob.

---

#### Glob + dynamic file discovery pattern (from `guides_dx02_test.exs`, lines 429-440, adapted)

`guides_dx02_test.exs` uses `Path.wildcard/1` directly on assembled paths:

```elixir
@templates_root
|> Path.join("*.ex")
|> Path.wildcard()
|> Enum.any?(fn file ->
  case File.read(file) do
    {:ok, contents} -> String.contains?(contents, pattern)
    _ -> false
  end
end)
```

For RCT-01, adapt this into a module attribute + private helper:

```elixir
@recipes_glob "guides/recipes/companion-libs/*.md"

defp recipe_files do
  root() |> Path.join(@recipes_glob) |> Path.wildcard()
end
```

`Path.join/2` + `Path.wildcard/1` is the project-standard glob idiom. Use it, not
`File.ls/1` or `Path.wildcard/1` with a hardcoded absolute path.

---

#### `@required_markers` module attribute pattern

The phase-50 analog uses a module-level regex attribute (`@re_validation ~r/.../`).
For RCT-01, use a keyword list so each entry carries both the match string and a
human-readable label for assertion messages:

```elixir
@required_markers [
  {"## Failure modes", "## Failure modes section"},
  {"## Non-goals", "## Non-goals section"},
  {"Sigra works fully standalone.", "standalone banner"},
  {"validated_against:", "validated_against: frontmatter"},
  {"last_validated:", "last_validated: frontmatter"}
]
```

All five markers are plain substring checks — `String.contains?(content, marker)` is
sufficient. No regex needed (confirmed by grep: the markers appear verbatim in all six
recipes).

---

#### Non-empty glob guard (D-05) + assertions-in-one-test pattern (from `phase_50_nyquist_docs_contract_test.exs`)

The phase-50 test puts all assertions inside a single `test` block with a `for` loop —
this is the preferred style for this codebase:

```elixir
test "50-01-01 .. 50-01-04: ..." do
  for rel <- ~w(...) do
    body = read!(rel)
    assert Regex.match?(@re_validation, body), "expected #{rel} to match ..."
  end
end
```

Apply the same shape to RCT-01 — two tests total, both in a flat (non-nested) structure:

```elixir
test "companion-libs glob is non-empty (D-05 guard)" do
  assert recipe_files() != [],
         "#{@recipes_glob} matched no files — directory missing or glob wrong"
end

test "each companion-lib recipe carries all five required contract markers" do
  files = recipe_files()
  assert files != [], "glob returned no files"

  for path <- files do
    name = Path.basename(path)
    content = File.read!(path)

    for {marker, label} <- @required_markers do
      assert String.contains?(content, marker),
             "#{name}: missing #{label} (#{inspect(marker)})"
    end
  end
end
```

The non-empty guard is also checked inside the main test (second `assert files != []`)
so both tests are independently load-bearing: the guard test catches "empty glob" as a
distinct failure mode from "marker missing".

---

#### Complete recommended shape for the new file

```elixir
defmodule Sigra.Recipes.CompanionLibContractTest do
  @moduledoc """
  Contract fixture for companion-lib recipes (RCT-01).

  Asserts every recipe under guides/recipes/companion-libs/ carries
  required sections and freshness frontmatter.
  Fails loudly on missing markers AND on empty glob (D-05).
  """

  use ExUnit.Case, async: true

  @recipes_glob "guides/recipes/companion-libs/*.md"

  @required_markers [
    {"## Failure modes", "## Failure modes section"},
    {"## Non-goals", "## Non-goals section"},
    {"Sigra works fully standalone.", "standalone banner"},
    {"validated_against:", "validated_against: frontmatter"},
    {"last_validated:", "last_validated: frontmatter"}
  ]

  defp root, do: Path.expand("../..", __DIR__)
  defp recipe_files, do: root() |> Path.join(@recipes_glob) |> Path.wildcard()

  test "companion-libs glob is non-empty (D-05 guard)" do
    assert recipe_files() != [],
           "#{@recipes_glob} matched no files — directory missing or glob wrong"
  end

  test "each companion-lib recipe carries all five required contract markers" do
    files = recipe_files()
    assert files != [], "glob returned no files"

    for path <- files do
      name = Path.basename(path)
      content = File.read!(path)

      for {marker, label} <- @required_markers do
        assert String.contains?(content, marker),
               "#{name}: missing #{label} (#{inspect(marker)})"
      end
    end
  end
end
```

---

### `guides/recipes/companion-libs/lockspire.md` (edit, documentation)

**No analog needed — targeted replacement of lines 93-95.**

**Current content at lines 92-95:**

```elixir
  @impl Lockspire.Host.AccountResolver
  def resolve_account(account_reference, _context) do
    MyApp.Accounts.get_user(account_reference)
  end
```

**Replace with:**

```elixir
  @impl Lockspire.Host.AccountResolver
  def resolve_account(account_reference, _context) do
    case MyApp.Accounts.get_user(account_reference) do
      nil -> {:error, :not_found}
      user -> {:ok, user}
    end
  end
```

**Why:** `MyApp.Accounts.get_user/1` returns `nil | %User{}`. Lockspire's dispatch at
`token_exchange.ex:1223` and `userinfo.ex:147` both use
`with {:ok, account} <- resolver.resolve_account(...)`. A bare `nil` or `%User{}`
return causes a MatchError — both arms need the `{:ok, _}` / `{:error, _}` tuple shape
to match the `@callback resolve_account/2` contract at `account_resolver.ex:17-18`.

**Also update:**
- Line 2: `<!-- last_validated: 2026-05-28 -->` → `<!-- last_validated: 2026-05-29 -->`
- Line 5: `Validated against: \`lockspire ~> 1.2\` as of 2026-05-28` → `Validated against: \`lockspire ~> 1.2\` (\`def616d\`) as of 2026-05-29`

---

### `guides/recipes/companion-libs/rulestead.md` (edit, documentation)

**No analog needed — targeted replacement of lines 123-153 (the policy section).**

**Current prose at line 123-124 (wrong behaviour attribution):**

```
The admin UI calls `policy.can?(actor, action, resource, environment_key)` at
`authorizer.ex:146-150`. The host module implements `can?/4` returning a boolean:
```

**Replace prose with:**

```
The host module implements the `Rulestead.Admin.Policy` behaviour
(defined at `policy.ex:121`, verified against rulestead v0.1.3 `0a18360` on 2026-05-29;
dispatched from `authorizer.ex:149`). Implement the one required callback `can?/4`,
which returns a boolean:
```

**Current example module at lines 140-153 (missing `@behaviour` and `@impl`):**

```elixir
defmodule MyApp.RulesteadPolicy do
  @doc """
  Authorize Rulestead admin actions.
  actor.roles derives from current_scope.role via the admin session.
  """
  def can?(%{roles: roles}, action, _resource, _environment_key) do
    case {action, roles} do
      {_, roles} when :admin in roles -> true
      {:read, roles} when :editor in roles or :viewer in roles -> true
      {:write, roles} when :editor in roles -> true
      _ -> false
    end
  end
end
```

**Replace with:**

```elixir
defmodule MyApp.RulesteadPolicy do
  @behaviour Rulestead.Admin.Policy

  @doc """
  Authorize Rulestead admin actions.
  actor.roles derives from current_scope.role via the admin session.
  """
  @impl Rulestead.Admin.Policy
  def can?(%{roles: roles}, action, _resource, _environment_key) do
    case {action, roles} do
      {_, roles} when :admin in roles -> true
      {:read, roles} when :editor in roles or :viewer in roles -> true
      {:write, roles} when :editor in roles -> true
      _ -> false
    end
  end

  # Optional callbacks — implement only if you use Rulestead governance actions
  # (publish_ruleset, advance_rollout, engage_kill_switch, release_kill_switch,
  # promote_environment). If omitted, Rulestead falls back to its internal defaults.
  #
  #   @impl Rulestead.Admin.Policy
  #   def change_request_required?(actor, action, resource, environment_key), do: ...
  #
  #   @impl Rulestead.Admin.Policy
  #   def allow_self_approval?(actor, action, resource, environment_key), do: ...
end
```

**Why:** `Rulestead.Admin.Policy` (at `policy.ex:121`) is the host-facing behaviour.
`@behaviour` + `@impl` adds compile-time callback verification. `Authorizer` is the
internal dispatch module, not the behaviour. `change_request_required?/4` and
`allow_self_approval?/4` are declared `@optional_callbacks` at `policy.ex:142`, so
they must not be implied as required.

**Also update:**
- Line 2: `<!-- last_validated: 2026-05-28 -->` → `<!-- last_validated: 2026-05-29 -->`
- Line 5: `Validated against: \`rulestead ~> 0.1\` as of 2026-05-28` → `Validated against: \`rulestead ~> 0.1\` (\`0a18360\`) as of 2026-05-29`

---

## Shared Patterns

### `use ExUnit.Case, async: true` (no DB, no tags)

**Source:** both analog tests (line 8 of each)
**Apply to:** `companion_lib_contract_test.exs`

Plain `async: true` ExUnit with no DB setup, no Oban, no HTTP. CLAUDE.md confirms no
tag exclusions — this is automatically merge-blocking with no additional CI wiring.

### `Path.expand("../..", __DIR__)` root helper

**Source:** `phase_50_nyquist_docs_contract_test.exs` lines 14-16 (uses `"../../.."` for
three-level depth; new file is two levels deep so use `"../.."`)
**Apply to:** `companion_lib_contract_test.exs`

All file path resolution goes through `root()` so the test is location-independent.
Never hardcode absolute paths or use `File.cwd!/0`.

### `String.contains?/2` for marker presence

**Source:** `phase_50_nyquist_docs_contract_test.exs` uses `=~` and `Regex.match?/2`;
`guides_dx02_test.exs` uses `raw =~ "string"` (which calls `String.contains?/2` for
binaries).
**Apply to:** `companion_lib_contract_test.exs`

For the five recipe markers, plain `String.contains?/2` is simpler and sufficient — all
markers are literal strings with no regex meta-characters.

---

## No Analog Found

All three files have sufficient analog coverage. No files require falling back to
RESEARCH.md patterns exclusively.

---

## Metadata

**Analog search scope:** `test/sigra/`, `test/sigra/planning/`
**Files scanned:** 2 analog test files, 2 recipe edit targets (frontmatter + edit sections)
**Pattern extraction date:** 2026-05-29

---

## PATTERN MAPPING COMPLETE

**Phase:** 139 - Recipe-Contract Integrity & Sister-Repo Verification
**Files classified:** 3 (1 new, 2 existing edits)
**Analogs found:** 2 / 1 (both analogs serve the one new file)

### Coverage
- Files with exact analog: 1 (`companion_lib_contract_test.exs` — phase-50 nyquist test is an exact role+data-flow match)
- Files with role-match analog: 0
- Files with no analog (edit targets): 2 (recipe edits — concrete replacement excerpts provided directly)

### Key Patterns Identified
- All contract fixture tests use `use ExUnit.Case, async: true` with `root()`/`Path.expand` for repo-relative paths and `Path.wildcard/1` for glob discovery
- Assertion style is a flat `for` loop inside a single `test` block with descriptive failure messages that name the file and missing marker
- Non-empty glob guard is a standalone test that fails independently from marker assertions, disambiguating "empty glob" from "marker missing"
- Recipe fixes follow a replace-in-place pattern: swap the buggy function body, add `@behaviour` + `@impl`, update `last_validated:` on lines 2 and 5 of each recipe

### File Created
`/Users/jon/projects/sigra/.planning/phases/139-recipe-contract-integrity-sister-repo-verification/139-PATTERNS.md`

### Ready for Planning
Pattern mapping complete. Planner can reference analog patterns and replacement excerpts directly in PLAN.md action steps.
