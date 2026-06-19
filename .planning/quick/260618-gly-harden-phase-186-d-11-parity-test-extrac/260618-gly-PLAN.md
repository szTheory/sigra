---
phase: 260618-gly
plan: "01"
type: execute
wave: 1
depends_on: []
files_modified:
  - test/sigra/install/features/admin_test.exs
autonomous: true
requirements:
  - WR-02
  - WR-03

must_haves:
  truths:
    - "auth dark-block extraction anchors on the .sigra-auth[data-theme=\"dark\"] selector and reads to its closing brace"
    - "extract_token_value/2 scopes its search to the :root block so light parity cannot silently match a dark override"
    - "all existing D-11 parity assertions continue to pass unchanged"
  artifacts:
    - path: "test/sigra/install/features/admin_test.exs"
      provides: "hardened extractors — structural auth dark block + root-scoped token lookup"
  key_links:
    - from: "test/sigra/install/features/admin_test.exs (extract_auth_dark_block/1)"
      to: "priv/templates/sigra.install/core/sigra_auth.css"
      via: "extract_css_block/2 anchored on .sigra-auth[data-theme=\"dark\"] selector"
    - from: "test/sigra/install/features/admin_test.exs (extract_token_value/2)"
      to: "priv/templates/sigra.install/admin/sigra_admin.css :root"
      via: "extract_css_blocks/2 restricted to :root block content"
---

<objective>
Remove two latent brittleness issues from the D-11 parity tests in admin_test.exs
(phase 186 review findings WR-02 and WR-03). No assertions are weakened.

Purpose: WR-02's fixed 30-line window can silently pass against the wrong dark block
if selectors shift; WR-03's first-match token lookup can return a dark override value
when light parity is expected if declaration order changes.

Output: admin_test.exs with structural auth dark block extraction (reusing the existing
extract_css_block/2 + take_balanced_block/1 helpers) and a root-scoped
extract_token_value/2.

Note on already-resolved items:
- WR-01 (hardcoded line ranges): already fixed — structural extract_css_block/2 is
  in place; no action needed.
- IN-02 (duplicated readNoticeStyles closure): already fixed — readNoticeStyles/1 is
  a top-level helper at line 196 in admin-theme.spec.ts; no action needed.
- IN-03 (token-reference completeness CI guard): left for a separate pass per scope
  constraints; this plan does not include it.
</objective>

<execution_context>
@/Users/jon/projects/sigra/.claude/gsd-core/workflows/execute-plan.md
@/Users/jon/projects/sigra/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@/Users/jon/projects/sigra/.planning/PROJECT.md
@/Users/jon/projects/sigra/.planning/ROADMAP.md
@/Users/jon/projects/sigra/.planning/STATE.md
@/Users/jon/projects/sigra/test/sigra/install/features/admin_test.exs
</context>

<tasks>

<task type="auto">
  <name>Task 1: Fix WR-02 — replace fixed 30-line auth dark window with structural block extraction</name>
  <files>test/sigra/install/features/admin_test.exs</files>
  <action>
In the "auth ember-family values match admin equivalents in light and dark" test
(around line 374), replace the brittle `auth_dark_lines` binding that uses
`Enum.drop_while/2 |> Enum.take(30)` with a structural extraction.

The auth CSS dark block uses a multi-selector:

  .sigra-auth[data-theme="dark"],
  .sigra-auth-email-preview[data-theme="dark"] {
    ...declarations...
  }

The existing `extract_css_block/2` helper already handles this correctly: it uses
`:binary.match/2` to find the selector string, then `take_balanced_block/1` to read
to the matching `}`. The first `data-theme="dark"` occurrence in the file is the
`.sigra-auth[data-theme="dark"],` line (line 56 in sigra_auth.css); the
`.sigra-auth-email-preview[data-theme="dark"]` selector on the next line is inside
the same block match, so a single `extract_css_block/2` call captures the full block.

Replace the three lines:

  auth_dark_lines =
    auth_css
    |> String.split("\n")
    |> Enum.drop_while(&(not String.contains?(&1, "data-theme=\"dark\"")))
    |> Enum.take(30)
    |> Enum.join("\n")

with:

  auth_dark_block =
    auth_css
    |> extract_css_block(~s(.sigra-auth[data-theme="dark"]))

Then update both downstream assertions (the two `String.contains?` checks) to use
`auth_dark_block` in place of `auth_dark_lines`. The assertions themselves do not
change — only the binding name changes.

Do not add a new private function. The existing extract_css_block/2 is sufficient.
  </action>
  <verify>
    <automated>cd /Users/jon/projects/sigra && mix test test/sigra/install/features/admin_test.exs --no-deps-check 2>&1 | tail -20</automated>
  </verify>
  <done>mix test for admin_test.exs passes with 0 failures; the Enum.take(30) pattern is gone; auth_dark_block is bound via extract_css_block/2.</done>
</task>

<task type="auto">
  <name>Task 2: Fix WR-03 — scope extract_token_value/2 to the :root block</name>
  <files>test/sigra/install/features/admin_test.exs</files>
  <action>
The current `extract_token_value/2` scans all lines in the full CSS string and
returns the first line that starts with `token_name <> ":"`. If a dark override
for the same token name were moved above the `:root` light definition, light parity
checks would silently compare the dark value.

Fix: change `extract_token_value/2` to scope its search to the concatenated content
of all `:root` blocks. The existing `extract_css_blocks/2` helper (plural) already
returns all `:root` block bodies (as strings). Use it to build the search domain.

Replace the current implementation:

  defp extract_token_value(css, token_name) do
    css
    |> String.split("\n")
    |> Enum.find_value(fn line ->
      trimmed = String.trim(line)

      if String.starts_with?(trimmed, token_name <> ":") do
        trimmed
        |> String.replace_prefix(token_name <> ":", "")
        |> String.trim()
        |> String.trim_trailing(";")
      end
    end)
  end

with:

  defp extract_token_value(css, token_name) do
    root_content =
      css
      |> extract_css_blocks(":root")
      |> Enum.join("\n")

    root_content
    |> String.split("\n")
    |> Enum.find_value(fn line ->
      trimmed = String.trim(line)

      if String.starts_with?(trimmed, token_name <> ":") do
        trimmed
        |> String.replace_prefix(token_name <> ":", "")
        |> String.trim()
        |> String.trim_trailing(";")
      end
    end)
  end

The sigra_auth.css token names used in the light ember parity loop
(--sigra-auth-risk, --sigra-auth-warn, --sigra-auth-ok) are NOT in a `:root`
block in sigra_auth.css — they live in a `.sigra-auth { ... }` rule block.
Check sigra_auth.css: the file opens with `.sigra-auth { ... }` containing light
values, and has no `:root` block. This means `extract_css_blocks(auth_css, ":root")`
returns `[]`, making `root_content` an empty string, and `extract_token_value`
returns `nil` for auth tokens.

Resolution: add an optional selector parameter. The function signature becomes
`extract_token_value(css, token_name, context_selector \\ ":root")`. When the
caller passes a different selector (e.g., ".sigra-auth") the search is scoped to
that block. The admin CSS uses `:root` (light tokens in `:root`); the auth CSS uses
`.sigra-auth` (light tokens in the base `.sigra-auth` block).

Verify the actual selectors before writing by checking both CSS files:
- `priv/templates/sigra.install/admin/sigra_admin.css`: confirm light --sg-color-risk
  etc. are inside `:root { ... }`.
- `priv/templates/sigra.install/core/sigra_auth.css`: confirm light --sigra-auth-risk
  etc. are inside `.sigra-auth { ... }` (NOT :root).

Then update the call sites in the test:
- For admin tokens: `extract_token_value(admin_css, admin_token)` — default `:root`
  selector works, no change needed at call site.
- For auth tokens: `extract_token_value(auth_css, auth_token, ".sigra-auth")` — pass
  the explicit selector at the call sites in the light ember parity loop.

If the grep confirms auth light tokens are in `.sigra-auth` and admin light tokens
are in `:root`, proceed with the three-argument variant. If the structure differs
from what is described here, adapt accordingly using the same principle: scope to
the correct block via the existing extract_css_blocks/2 helper.
  </action>
  <verify>
    <automated>cd /Users/jon/projects/sigra && mix test test/sigra/install/features/admin_test.exs --no-deps-check 2>&1 | tail -20</automated>
  </verify>
  <done>
    mix test for admin_test.exs passes with 0 failures.
    extract_token_value/2 (or /3) no longer searches the full CSS string — it operates on content extracted from the correct block via extract_css_blocks/2.
    The Enum.take(30) pattern no longer exists anywhere in admin_test.exs.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| test code → fixture CSS files | Tests read priv/templates CSS files from disk; no untrusted input |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-gly-01 | Tampering | test/sigra/install/features/admin_test.exs | accept | Test-only refactor; no production code touched; CI catches regressions |
</threat_model>

<verification>
Run the full D-11 describe block:

  cd /Users/jon/projects/sigra && mix test test/sigra/install/features/admin_test.exs --no-deps-check

Expected: all tests pass, 0 failures.

Also confirm the two removed patterns are gone:

  grep -n "Enum.take(30)" test/sigra/install/features/admin_test.exs
  # should return nothing

  grep -n "String.split.*Enum.find_value" test/sigra/install/features/admin_test.exs
  # should find only the scoped version inside root_content
</verification>

<success_criteria>
- mix test test/sigra/install/features/admin_test.exs passes with 0 failures
- Enum.take(30) is gone from admin_test.exs
- extract_token_value searches only the relevant CSS block (not full file)
- No assertions weakened, no behavior changes to the parity checks
- IN-03 deferred to a separate pass (noted in objective)
</success_criteria>

<output>
Create `.planning/quick/260618-gly-harden-phase-186-d-11-parity-test-extrac/260618-gly-01-SUMMARY.md` when done.
</output>
