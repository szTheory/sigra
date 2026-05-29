---
phase: 139-recipe-contract-integrity-sister-repo-verification
reviewed: 2026-05-29T00:00:00Z
depth: standard
files_reviewed: 3
files_reviewed_list:
  - test/sigra/recipes/companion_lib_contract_test.exs
  - guides/recipes/companion-libs/lockspire.md
  - guides/recipes/companion-libs/rulestead.md
findings:
  critical: 1
  warning: 2
  info: 2
  total: 5
status: issues_found
---

# Phase 139: Code Review Report

**Reviewed:** 2026-05-29T00:00:00Z
**Depth:** standard
**Files Reviewed:** 3
**Status:** issues_found

## Summary

Reviewed the new ExUnit contract fixture (`companion_lib_contract_test.exs`) and the
two documentation recipes it guards (`lockspire.md`, `rulestead.md`).

The test fixture is correct and robust: path arithmetic resolves to project root,
the empty-glob guard (D-05) is real and effective, and the marker assertion is not
vacuous. I ran the suite — both tests pass — and verified all six companion-lib
recipes (not just the two touched this phase) carry all five markers, so the
all-files assertion will not false-fail on the untouched recipes.

The `lockspire.md` fix is correct: `resolve_account/2` now returns the
`{:ok, user} | {:error, :not_found}` tuple contract, the example implements exactly
the 4 required callbacks declared in the contract table, and citations are accurate.

The one BLOCKER is in `rulestead.md`: the corrected `RulesteadPolicy.can?/4` example —
the very code this phase touched to add `@behaviour`/`@impl` — uses the `in` operator
against a runtime variable inside `when` guards. That form does not compile in Elixir
(`ArgumentError`: the right side of `in` in a guard must be a compile-time list/range).
A developer copy-pasting this "validated" example gets a compile error. The intended
authorization logic is correct (verified independently), only the guard form is invalid.

## Critical Issues

### CR-01: `RulesteadPolicy.can?/4` example uses `in` against a runtime variable inside a guard — does not compile

**File:** `guides/recipes/companion-libs/rulestead.md:149-156`
**Issue:** The policy example uses `:admin in roles` (and `:editor in roles`,
`:viewer in roles`) inside `when` guard clauses:

```elixir
def can?(%{roles: roles}, action, _resource, _environment_key) do
  case {action, roles} do
    {_, roles} when :admin in roles -> true
    {:read, roles} when :editor in roles or :viewer in roles -> true
    {:write, roles} when :editor in roles -> true
    _ -> false
  end
end
```

In Elixir, the right-hand side of `in` **inside a guard** must be a compile-time
proper list or range. With `roles` a runtime variable, this raises at compile time:

```
** (ArgumentError) invalid right argument for operator "in", it expects a
compile-time proper list or compile-time range on the right side when used in
guard expressions, got: roles
```

Reproduced on Elixir 1.19.5. The recipe is presented as a validated, copy-pasteable
contract example (`@behaviour` + `@impl` were added this phase specifically to make it
a faithful implementation), so a host developer pasting it gets a non-compiling module —
directly undermining the phase's stated goal of recipe contract integrity. The
authorization *logic* is correct; only the construct is invalid.

**Fix:** Move the membership tests out of guards into the function/`cond` body (the
`in` operator is valid against a runtime list outside of guards):

```elixir
@impl Rulestead.Admin.Policy
def can?(%{roles: roles}, action, _resource, _environment_key) do
  cond do
    :admin in roles -> true
    action == :read and (:editor in roles or :viewer in roles) -> true
    action == :write and :editor in roles -> true
    true -> false
  end
end
```

This compiles and preserves the exact semantics (verified: admin→any true,
viewer→read true / write false, editor→read+write true, empty roles→false).

## Warnings

### WR-01: `rulestead.md` example reads `%Scope{}` fields not set by `Sigra.Scope.build/3` without flagging the dependency

**File:** `guides/recipes/companion-libs/rulestead.md:67-69` (and field-bus prose at 88-91)
**Issue:** The controller example reads `scope.active_organization_id` and `scope.role`:

```elixir
context = %{
  user_id: scope.user.id,
  organization_id: scope.active_organization_id,
  role: scope.role
}
```

`Sigra.Scope.build/3` (`lib/sigra/scope.ex:19-24`) only populates `:user`,
`:active_organization`, `:membership`, and `:impersonating_from`. `active_organization_id`
and `role` are never set by the library constructor — they exist only if the host-generated
`%Scope{}` struct defines them AND a host code path assigns them. The recipe's prose at
lines 88-91 does acknowledge these are "host-generated `%Scope{}`" fields, so this is
architecturally defensible, but the example silently assumes the host populates
`active_organization_id`/`role`. If a host built the scope solely via `Sigra.Scope.build/3`,
both fields are `nil` and the Rulestead context is degraded with no error.
**Fix:** Add a one-line note near the example that `active_organization_id` and `role`
must be populated by the host scope-building path (they are not set by
`Sigra.Scope.build/3`), or show the fields being set so the contract is self-contained.

### WR-02: `last_validated:` / `validated_against:` markers are not format-validated, only presence-checked

**File:** `test/sigra/recipes/companion_lib_contract_test.exs:18-19,38-41`
**Issue:** The fixture asserts only that the substrings `validated_against:` and
`last_validated:` appear somewhere in each file. A stale or malformed freshness stamp
(e.g. `last_validated: TBD`, a year-old date, or the marker appearing only in prose)
passes the contract. Since the whole point of the freshness frontmatter is to catch
drift against sister repos, presence-only checking lets the guarantee rot silently —
the test would stay green while the recipes go stale.
**Fix:** Tighten to a regex on the frontmatter line, e.g. assert each file matches
`~r/<!-- last_validated: \d{4}-\d{2}-\d{2} -->/` and
`~r/<!-- validated_against: \S+ ~> [\d.]+ -->/`. This keeps the guard meaningful as
recipes age. (Optional hardening — not a correctness bug today.)

## Info

### IN-01: Redundant re-binding of `roles` in the policy `case` clauses

**File:** `guides/recipes/companion-libs/rulestead.md:149-153`
**Issue:** `roles` is bound in the function head, then the `case {action, roles}`
clauses re-destructure the identical value with `{_, roles}` / `{:read, roles}` etc.
The re-binding is redundant (the matched value is the same `roles`). Harmless, but it
reads as if `roles` might differ per clause. The CR-01 `cond` rewrite removes this
entirely.
**Fix:** Folded into the CR-01 fix.

### IN-02: Marker tuple `label` field is partially redundant with `marker`

**File:** `test/sigra/recipes/companion_lib_contract_test.exs:14-20,38-41`
**Issue:** `@required_markers` stores both a `marker` substring and a human `label`,
then the failure message prints both: `"missing #{label} (#{inspect(marker)})"`. For
the section markers (`"## Failure modes"` / `"## Failure modes section"`) the two are
near-duplicates. Minor; the dual form does aid the frontmatter messages
(`validated_against: frontmatter` reads better than the bare token). No change required —
noted only for awareness.
**Fix:** None required; acceptable as-is.

---

_Reviewed: 2026-05-29T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
