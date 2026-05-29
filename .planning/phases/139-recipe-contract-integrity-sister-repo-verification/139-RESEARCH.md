# Phase 139: Recipe-Contract Integrity & Sister-Repo Verification - Research

**Researched:** 2026-05-29
**Domain:** ExUnit markdown-contract fixtures + companion-lib recipe fixes (docs-only)
**Confidence:** HIGH — all claims verified against real source files in this session

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**RCT-01 — merge-blocking recipe-contract fixture**
- D-01: New pure-ExUnit test at `test/sigra/recipes/companion_lib_contract_test.exs`, `async: true`. Globs `guides/recipes/companion-libs/*.md`. Model on `guides_dx02_test.exs` and `phase_50_nyquist_docs_contract_test.exs`.
- D-02: Required assertions per recipe (exactly these five): `## Failure modes` section, `## Non-goals` section, "Sigra works fully standalone" banner, `validated_against:` frontmatter marker, `last_validated:` frontmatter marker.
- D-03: Do NOT assert `{:sigra, "~> 0.2"}` pin nor parse `last_validated:` as a date.
- D-04: Merge-blocking via plain `async: true` ExUnit in `test/` — no CI tag or separate job.
- D-05: Fixture must fail loudly if any marker is missing AND if the glob returns zero files.

**RCV-01 — Lockspire `resolve_account/2` contract**
- D-06: Verify against `/Users/jon/projects/lockspire` (v1.2.0, git `def616d`).
- D-07: Canonical contract: `@callback resolve_account(account_reference :: term(), context()) :: {:ok, account()} | {:error, :not_found | term()}` at `account_resolver.ex:17-18`.
- D-08: Recipe bug at `lockspire.md:93` returns bare `MyApp.Accounts.get_user(account_reference)` (user-or-nil) — confirmed MatchError risk. Fix to return `{:ok, account}` / `{:error, :not_found}`.
- D-09: Cite verified reference in recipe; update WR-02 in tracked todo.

**RCV-02 — Rulestead policy `@behaviour` contract**
- D-10: Verify against `/Users/jon/projects/rulestead/rulestead` (v0.1.3, git `0a18360`).
- D-11: Behaviour is `Rulestead.Admin.Policy` at `policy.ex:121`; `Authorizer` is the dispatch site at `authorizer.ex:149`.
- D-12: Fix recipe: add `@behaviour Rulestead.Admin.Policy` and `@impl true` on `can?/4`; correct prose referencing `authorizer.ex` as behaviour source.
- D-13 (THIS RESEARCH RESOLVES — see below): Confirm whether `change_request_required?/4` and `allow_self_approval?/4` are required or optional.
- D-14: Cite verified reference; correct WR-05 in tracked todo.
- D-15: Both sister repos resolve — neither contract uses the document-the-assumption fallback.
- D-16: `validated_against:` markers already accurate; refresh `last_validated:` to phase date when touching recipes.
- D-17: `2026-05-28-phase-134-recipe-residual-findings.md` is folded; close WR-02, WR-05, IN-01 on completion.

### Claude's Discretion
- Exact test file name/path and markdown-parsing approach (regex vs. line scan) — follow cited analog tests.
- Whether to fix prose line-references inside recipes beyond the two contract fixes.

### Deferred Ideas (OUT OF SCOPE)
- Strict drift tripwires: asserting `{:sigra, "~> 0.2"}` pin consistency and `last_validated:` date parsing.
- `2026-05-28-phase-135-review-deferred-findings.md` (Threadline demo polish).
- `2026-05-29-phase-138-doctor-info-findings.md` (Sigra.Doctor minor findings).
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| RCT-01 | Merge-blocking test fixture asserting every companion-lib recipe carries required sections and frontmatter markers | Analog tests confirmed; exact marker strings extracted; non-empty glob guard pattern identified |
| RCV-01 | Lockspire `resolve_account/2` return-shape contract verified against sister repo; recipe fixed where divergent | Bug confirmed at `lockspire.md:93`; canonical contract verified at `account_resolver.ex:17-18`; fix pattern defined |
| RCV-02 | Rulestead policy `@behaviour` contract verified; recipe fixed where divergent | Behaviour confirmed as `Rulestead.Admin.Policy`; `@optional_callbacks` found; all fixes specified |
</phase_requirements>

---

## Summary

Phase 139 has two independent tracks. Track 1 (RCT-01) is a new pure-ExUnit test file that globs all six companion-lib recipes and asserts five contract markers per file — this locks the current state (all six recipes already pass) and turns future recipe drift into a merge-blocking failure. Track 2 (RCV-01/RCV-02) fixes two concrete recipe bugs uncovered by verifying the sister-repo sources in-tree on 2026-05-29.

Both sister-repo contracts were verified directly against live source files. The Lockspire bug is confirmed and non-trivial: `lockspire.md:93` returns a bare user-or-nil from `get_user/1`, which crashes Lockspire's `with {:ok, account} <- resolver.resolve_account(...)` dispatch in both `token_exchange.ex:1223` and `userinfo.ex:147`. The Rulestead fix corrects a module-identity error: the recipe's policy example lacks `@behaviour Rulestead.Admin.Policy` / `@impl true`, and its prose incorrectly attributes the dispatch to `authorizer.ex` rather than the behaviour-defining `policy.ex`.

D-13 (the one genuine open question) is now resolved — see the Rulestead Callback Completeness section below.

**Primary recommendation:** Three small, self-contained implementation units — one new test file, two recipe patches — with no new dependencies, no library code changes, and no CI wiring. All changes are documentation or test layer only.

---

## D-13 RESOLVED: Rulestead Callback Completeness

**Question:** Are `change_request_required?/4` and `allow_self_approval?/4` required or optional in `Rulestead.Admin.Policy`?

**Answer: BOTH ARE OPTIONAL.**

Verified at `/Users/jon/projects/rulestead/rulestead/lib/rulestead/admin/policy.ex:142` (current line):

```elixir
@optional_callbacks change_request_required?: 4, allow_self_approval?: 4
```

The file declares three callbacks:
- `can?/4` at **line 121** — `@callback can?(actor, action, resource, environment_key) :: boolean()` — **REQUIRED** (not in `@optional_callbacks`)
- `change_request_required?/4` at **lines 128-133** — **OPTIONAL** (listed in `@optional_callbacks` at line 142)
- `allow_self_approval?/4` at **lines 135-140** — **OPTIONAL** (listed in `@optional_callbacks` at line 142)

**Implication for the recipe fix (D-12):** The recipe example only needs to implement `can?/4` — that is the sole required callback. The recipe SHOULD add a comment noting that `change_request_required?/4` and `allow_self_approval?/4` exist as optional callbacks for governance-action workflows (they gate change-request flows and self-approval), so host developers know the hooks exist without being obligated to implement them. The recipe must NOT imply they are required.

---

## Verified Facts vs. CONTEXT.md Citations

All CONTEXT.md citations confirmed against current file content:

### Lockspire AccountResolver Contract

**File:** `/Users/jon/projects/lockspire/lib/lockspire/host/account_resolver.ex`

Current content (lines 17-18):
```elixir
@callback resolve_account(account_reference :: term(), context()) ::
            {:ok, account()} | {:error, :not_found | term()}
```

**CONFIRMED.** Signature, arity, and return shape match D-07 exactly. Line numbers 17-18 are accurate as of this session. [VERIFIED: direct source read]

**The bug is real.** `lockspire.md:93` currently reads:
```elixir
def resolve_account(account_reference, _context) do
  MyApp.Accounts.get_user(account_reference)
end
```
`get_user/1` returns `nil | %User{}`. The dispatch at `token_exchange.ex:1223` is:
```elixir
with {:ok, account} <- resolver.resolve_account(authorization_code.account_id, context),
```
A `nil` return causes a MatchError; a `%User{}` return also causes a MatchError (no `{:ok, _}` wrapper). The `{:error, _reason}` else branch at line 1227 is never reached via this path.

Same pattern confirmed at `userinfo.ex:147`:
```elixir
with {:ok, account} <- resolver.resolve_account(access_token.account_id, context),
```

### Lockspire Consumer Line Numbers

- `token_exchange.ex:1223` — **CONFIRMED** (the `with {:ok, account} <-` line is exactly at 1223) [VERIFIED: direct source read]
- `userinfo.ex:147` — **CONFIRMED** (same `with {:ok, account} <-` pattern at line 147) [VERIFIED: direct source read]

### Rulestead Behaviour Source

**File:** `/Users/jon/projects/rulestead/rulestead/lib/rulestead/admin/policy.ex`

- `@callback can?/4` at **line 121** — **CONFIRMED** [VERIFIED: direct source read]
- `@optional_callbacks` at **line 142** — **CONFIRMED** (lists `change_request_required?: 4, allow_self_approval?: 4`)

**File:** `/Users/jon/projects/rulestead/rulestead/lib/rulestead/admin/authorizer.ex`

- Dispatch site at line 149: `policy.can?(actor, action, resource, environment_key)` — **CONFIRMED** (`allowed?/4` private function at line 146; `policy.can?/4` call at line 149) [VERIFIED: direct source read]

**CONTEXT.md line reference for authorizer.ex was cited as ~149 — actual dispatch is line 149. Accurate.**

---

## RCT-01 Fixture: Implementation Shape

### Analog Pattern Extraction

**From `test/sigra/planning/phase_50_nyquist_docs_contract_test.exs`** (the closer analog):

The path helper pattern:
```elixir
defp root do
  Path.expand("../../..", __DIR__)
end

defp read!(rel) do
  root() |> Path.join(rel) |> File.read!()
end
```

For the RCT-01 fixture at `test/sigra/recipes/companion_lib_contract_test.exs`, the path depth differs (one level shallower from `test/sigra/` vs `test/sigra/planning/`), so:

```elixir
defp root do
  Path.expand("../..", __DIR__)
end
```

**From `test/sigra/guides_dx02_test.exs`** (glob + per-file assertion pattern):

The `guides_dx02_test.exs` uses `Path.wildcard/1` for static file lists. The RCT-01 fixture uses a glob for dynamic discovery:

```elixir
@recipes_glob "guides/recipes/companion-libs/*.md"

defp recipe_files do
  root() |> Path.join(@recipes_glob) |> Path.wildcard()
end
```

**D-05 non-empty guard pattern** (to be placed as a standalone test or at the top of a describe block):

```elixir
test "companion-libs glob returns at least one recipe" do
  files = recipe_files()
  assert files != [], "guides/recipes/companion-libs/*.md matched no files — glob may be wrong"
end
```

### Exact Marker Strings (from accrue.md as reference)

All six recipes use the identical frontmatter and banner convention, confirmed by grep:

| Assertion | Exact string to match | Markdown location |
|-----------|----------------------|-------------------|
| `validated_against:` marker | `"validated_against:"` | Line 1: `<!-- validated_against: ... -->` |
| `last_validated:` marker | `"last_validated:"` | Line 2: `<!-- last_validated: ... -->` |
| Standalone banner | `"Sigra works fully standalone."` | Line 7: `> **Sigra works fully standalone.**` |
| Failure modes section | `"## Failure modes"` | Mid-document |
| Non-goals section | `"## Non-goals"` | Mid-document |

All five can be asserted with `String.contains?(content, marker)` or `=~` — no regex needed. The `last_validated:` and `validated_against:` markers appear on their own HTML-comment lines; `String.contains?` is sufficient and matches the phase-50 test's style.

### Recommended Test Structure

```elixir
defmodule Sigra.Recipes.CompanionLibContractTest do
  @moduledoc """
  Contract fixture for companion-lib recipes.
  Asserts every recipe under guides/recipes/companion-libs/ carries
  required sections and freshness frontmatter (RCT-01).
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

  describe "each companion-lib recipe carries required contract markers" do
    # One test per recipe; discovered dynamically so new recipes are covered automatically.
    for path <- Path.wildcard(Path.join([Path.expand("../../..", __ENV__.file),
                                          "guides/recipes/companion-libs/*.md"])) do
      @path path
      @name Path.basename(path)

      test "#{@name}: all five contract markers present" do
        content = File.read!(@path)

        for {marker, label} <- @required_markers do
          assert String.contains?(content, marker),
                 "#{@name}: missing #{label} (#{inspect(marker)})"
        end
      end
    end
  end
end
```

**Important:** The compile-time `for` over `Path.wildcard/1` in a `describe` block is the established Elixir pattern for dynamic test generation. The `root()` helper uses `__DIR__` at runtime; for the compile-time glob, use `__ENV__.file` to expand at compile time. The planner should verify the path arithmetic matches the actual depth of `test/sigra/recipes/companion_lib_contract_test.exs`.

**Alternative (simpler, always safe):** Use a single test that loops over `recipe_files()` at runtime:

```elixir
test "all companion-lib recipes carry required contract markers" do
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

This avoids compile-time glob complexity at the cost of all assertions running in one test. The phase-50 test uses this pattern (all assertions in a single `for` inside a `test` block). **Recommend this simpler form as the primary approach**, matching the phase-50 precedent more closely.

---

## RCV-01 Recipe Fix: Lockspire `resolve_account/2`

### Current Bug (lockspire.md:93-95)

```elixir
# WRONG — returns user-or-nil, not {:ok, user} | {:error, :not_found}
def resolve_account(account_reference, _context) do
  MyApp.Accounts.get_user(account_reference)
end
```

### Correct Implementation

```elixir
@impl Lockspire.Host.AccountResolver
def resolve_account(account_reference, _context) do
  case MyApp.Accounts.get_user(account_reference) do
    nil -> {:error, :not_found}
    user -> {:ok, user}
  end
end
```

### Citation to add to recipe

Update the `validated_against:` frontmatter marker's companion prose line to:
> Validated against: `lockspire ~> 1.2` (`def616d`) as of 2026-05-29

And update `<!-- last_validated: 2026-05-28 -->` to `<!-- last_validated: 2026-05-29 -->`.

The recipe prose referencing the contract (`account_resolver.ex:14-39`) is correct — the full behaviour IS at that range. The recipe's callback table listing `resolve_account/2` as required is also correct.

---

## RCV-02 Recipe Fix: Rulestead `@behaviour` and `@impl`

### Current Issues (rulestead.md:121-153)

1. **Wrong behaviour source cited in prose (line 124):** "The admin UI calls `policy.can?(actor, action, resource, environment_key)` at `authorizer.ex:146-150`." — This is the DISPATCH site, not the behaviour definition. The behaviour is defined at `policy.ex:121`.

2. **`RulesteadPolicy` example missing `@behaviour` and `@impl`** (lines 140-154): the example declares `def can?/4` with no `@behaviour Rulestead.Admin.Policy` declaration and no `@impl true`, so there is no compile-time callback verification.

3. **Optional callbacks not mentioned**: `change_request_required?/4` and `allow_self_approval?/4` exist as optional callbacks for governance-action workflows. Not mentioning them at all is a missed DX opportunity.

### Correct Implementation

```elixir
defmodule MyApp.RulesteadPolicy do
  @behaviour Rulestead.Admin.Policy

  @doc """
  Authorize Rulestead admin actions.
  actor.roles derives from current_scope.role via the admin session.
  Pin behaviour to `rulestead/lib/rulestead/admin/policy.ex:121`
  (verified against rulestead v0.1.3 `0a18360` on 2026-05-29).
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

  # Optional: implement change_request_required?/4 and allow_self_approval?/4
  # if you use Rulestead governance actions (publish_ruleset, advance_rollout,
  # engage_kill_switch, release_kill_switch, promote_environment).
  # If not implemented, Rulestead falls back to its internal default.
end
```

### Prose Fix

Replace "at `authorizer.ex:146-150`" with "defined at `policy.ex:121`" (verified reference). Optionally note the dispatch site for context: "called from `authorizer.ex:149`".

### Citation to add

Update `<!-- last_validated: 2026-05-28 -->` to `<!-- last_validated: 2026-05-29 -->` and prose validation line accordingly, citing `rulestead v0.1.3 (0a18360)`.

---

## Current Recipe State (pre-fix)

All six recipes already pass RCT-01's five assertions — confirmed by grep:

| Recipe | `validated_against:` | `last_validated:` | Standalone banner | `## Failure modes` | `## Non-goals` |
|--------|---------------------|------------------|------------------|--------------------|----------------|
| accrue.md | line 1 | line 2 | line 7 | line 170 | line 200 |
| lockspire.md | line 1 | line 2 | line 7 | line 124 | line 151 |
| mailglass.md | line 1 | line 2 | line 7 | line 88 | line 113 |
| relyra.md | line 1 | line 2 | line 7 | line 107 | line 135 |
| rulestead.md | line 1 | line 2 | line 7 | line 159 | line 186 |
| threadline.md | line 1 | line 2 | line 7 | line 91 | line 135 |

The fixture will pass green on first run. The negative-test obligation (Success Criteria #2) is satisfied by the fixture design itself — removing any marker from any recipe will produce a clear assertion failure.

---

## Architecture Patterns

### No New Infrastructure

Both tracks are purely additive within existing conventions:
- Test layer: plain `use ExUnit.Case, async: true`, no DB, no Oban, no HTTP. Runs in the standard suite automatically (CLAUDE.md: no tag exclusions).
- Recipe edits: documentation-only Markdown changes. Verify with `mix docs --warnings-as-errors` after edits.

### Recommended Project Structure (new file only)

```
test/sigra/
└── recipes/
    └── companion_lib_contract_test.exs   # RCT-01 (new)
```

The `test/sigra/recipes/` subdirectory is new; no existing test lives there. The path follows the namespace-mirrors-source convention used by `test/sigra/planning/` (which houses phase_50 test).

### Path Helper Arithmetic

From `test/sigra/recipes/companion_lib_contract_test.exs`:
```
__DIR__ = <repo_root>/test/sigra/recipes
Path.expand("../..", __DIR__) = <repo_root>
```

Then: `Path.join(root(), "guides/recipes/companion-libs/*.md")` → `<repo_root>/guides/recipes/companion-libs/*.md` — correct.

---

## Validation Architecture

### RCT-01 Fixture

**Behaviors validated:**
1. Each of the six companion-lib recipes contains all five required markers (exact string match).
2. The glob is non-empty — the contract cannot vacuously pass when the directory is empty or the path is wrong (D-05).
3. New recipes added to `guides/recipes/companion-libs/` are automatically covered because the fixture globs dynamically.

**Negative-test dimension (Success Criteria #2):** The fixture is self-proving. If any one of the five markers is removed from any recipe, the corresponding `assert String.contains?` fails with a clear message identifying the recipe and the missing marker. The planner should add a Wave 0 note that the executor MUST verify this by temporarily removing one marker from one recipe, confirming the test fails, and reverting before committing.

**Non-empty glob guard:** A standalone test asserts `recipe_files() != []`. If `guides/recipes/companion-libs/` is deleted or the path constant is wrong, this test fails independently, distinguishing "empty glob" from "marker missing."

**Test run commands:**
- Quick (fixture only): `mix test test/sigra/recipes/companion_lib_contract_test.exs`
- Full suite: `mix test`
- No DB required — `async: true`, pure filesystem reads.

### RCV-01 / RCV-02 Validation

Validation is: recipe reads correctly + `mix docs --warnings-as-errors` stays green.

- RCV-01: After fixing `lockspire.md:93-95`, confirm `mix docs --warnings-as-errors` exits 0.
- RCV-02: After adding `@behaviour` + `@impl` + prose correction to `rulestead.md`, confirm `mix docs --warnings-as-errors` exits 0.

No new tests are required for recipe fixes — the RCT-01 fixture already validates structural integrity; the contract correctness is validated by the cited sister-repo verification.

---

## Todo Disposition (Folded Phase)

**`2026-05-28-phase-134-recipe-residual-findings.md`** closes on phase completion:

| Finding | Resolution |
|---------|------------|
| WR-02 | Lockspire `resolve_account/2` return shape — **confirmed bug, fixed in RCV-01** |
| WR-05 | `RulesteadPolicy` missing `@behaviour` — **confirmed; module is `Admin.Policy` not `Admin.Authorizer`, fixed in RCV-02** |
| IN-01 | Sigra version pin — **already resolved** in quick task `260528-sbn`; all six recipes now pin `{:sigra, "~> 0.2"}`. Mark IN-01 done. |

---

## Environment Availability

Step 2.6: SKIPPED (no external dependencies — all changes are ExUnit tests and Markdown edits; `mix test` and `mix docs --warnings-as-errors` are already confirmed working in this project).

---

## Security Domain

Not applicable — this phase contains no auth logic, no token handling, no HTTP endpoints, and no data processing. ASVS categories do not apply to a test fixture and documentation-only recipe fixes.

---

## Open Questions

None. D-13 is resolved (see above). All CONTEXT.md citations confirmed accurate.

---

## Assumptions Log

No `[ASSUMED]` claims in this research. All claims verified directly against source files.

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| — | — | — | — |

**All claims in this research were verified against live source files. No user confirmation needed.**

---

## Sources

### PRIMARY (HIGH confidence — direct source reads)

- `/Users/jon/projects/lockspire/lib/lockspire/host/account_resolver.ex` — `resolve_account/2` callback at lines 17-18; `@optional_callbacks` at line 36
- `/Users/jon/projects/lockspire/lib/lockspire/protocol/token_exchange.ex:1223` — `with {:ok, account} <- resolver.resolve_account(...)` dispatch confirmed
- `/Users/jon/projects/lockspire/lib/lockspire/protocol/userinfo.ex:147` — same dispatch pattern confirmed
- `/Users/jon/projects/rulestead/rulestead/lib/rulestead/admin/policy.ex` — `@callback can?/4` at line 121; `@optional_callbacks change_request_required?: 4, allow_self_approval?: 4` at line 142
- `/Users/jon/projects/rulestead/rulestead/lib/rulestead/admin/authorizer.ex:149` — dispatch site `policy.can?(actor, action, resource, environment_key)` confirmed
- `/Users/jon/projects/sigra/test/sigra/guides_dx02_test.exs` — glob pattern, `Path.wildcard`, per-file assertion style
- `/Users/jon/projects/sigra/test/sigra/planning/phase_50_nyquist_docs_contract_test.exs` — `root()`/`read!()` helper pattern, `for` loop assertion style
- `/Users/jon/projects/sigra/guides/recipes/companion-libs/accrue.md` — canonical marker format (lines 1-2, 7, 170, 200)
- All six companion-lib recipes — grep-confirmed all five markers present in each

---

## RESEARCH COMPLETE
