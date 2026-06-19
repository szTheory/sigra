---
phase: 260618-grh
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - test/sigra/admin/glossary_test.exs
autonomous: true
requirements:
  - TEST-ROBUSTNESS
must_haves:
  truths:
    - "action=\"<copy>\" component attribute lines (human copy) are NOT stripped and ARE scanned for banned terms"
    - "action={expr} Elixir-expression form actions (URL calls) ARE stripped from scanning"
    - "href=, phx-*=, name=, and input-name attrs remain stripped as before"
    - "A banned term inside an action=\"...\" value causes a test failure (regression guard)"
    - "mix test test/sigra/admin/glossary_test.exs passes with 0 failures after the change"
  artifacts:
    - path: "test/sigra/admin/glossary_test.exs"
      provides: "Narrowed @strip_patterns line 173 + regression describe block"
      contains: "action=\\{"
  key_links:
    - from: "test/sigra/admin/glossary_test.exs @strip_patterns"
      to: "lib/sigra/admin/live/index_live.ex action=\"Review users\""
      via: "strip_non_copy_lines/1 — must NOT strip action=\"...\" lines"
      pattern: "action=\"[^\"]+\""
---

<objective>
Narrow the glossary drift guard's action= strip pattern so component attribute lines carrying
human copy (action="Open members", action="Review users", etc.) are no longer suppressed,
while URL-bearing Elixir-expression form actions (action={index_path(...)}) and real technical
attrs (href=, phx-*=, name=) remain stripped. Add a regression test that catches a banned
term inside an action="..." value, closing the false-negative gap from phase 191 WR-01.

Purpose: TEST-ROBUSTNESS hardening. No current defect — this prevents a silent false-negative
from reopening if a banned term is ever introduced into an action= component attribute value.

Output: One file changed (test/sigra/admin/glossary_test.exs), 0 test failures.
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
</context>

<tasks>

<task type="auto">
  <name>Task 1: Narrow @strip_patterns line 173 and add regression describe block</name>
  <files>test/sigra/admin/glossary_test.exs</files>
  <action>
Read the file before editing. The current line 173 pattern is:

    ~r/(href|action|phx-\w+|name=|input\s+.*name)=/,

Replace this single combined pattern with two narrower patterns:

    ~r/(href=|action=\{|phx-\w+=)/,
    ~r/(name=|input\s+.*name)=/,

Rationale: Every URL-bearing form action in the 8 scanned source files uses
action={<Elixir expression>} (e.g. action={index_path(@admin_scope)} in
audit_index_live.ex, users_index_live.ex, audit_user_live.ex), not a bare
action="/" string literal. All human-copy component attrs use action="<copy>"
(e.g. action="Review users" in index_live.ex, action="Open members" in
organization_live.ex, action="Send invitations" in components.ex). The `{` vs
`"` distinction is the clean separator. By matching action=\{ we strip Elixir
expressions only, leaving action="..." lines live for scanning.

The href= and phx-\w+= patterns are split out explicitly rather than remaining
in a group — functionally identical but reads more clearly per pattern.

After the @strip_patterns block, add a second describe block for the regression
guard. The test must:
1. Build a synthetic indexed_lines list in memory — do NOT write a temp file.
   The regression test calls the PRIVATE helpers directly within the same module
   (tests in ExUnit have access to the module's defp functions because the test
   is defined in the same module). Specifically, feed the line through
   strip_non_copy_lines/1 and then through the banned_terms scan inline — mirror
   the pipeline from check_file/1 without the File.read!/1 step.

   Implementation approach for the regression test (mirror check_file/1 pipeline):
   - Construct `indexed_lines = [{"          action=\"Review logins\"", 99}]`
     (leading spaces mimic real indentation; "logins" is banned, canonical "sessions")
   - Call `strip_non_copy_lines(indexed_lines)` to get surviving lines
   - Assert the result is non-empty (i.e., the line was NOT stripped)
   - Then run the banned_terms scan over surviving lines and assert at least one
     violation is returned matching "logins"

   The describe block title: "strip_non_copy_lines regression — action= human copy"
   The test name: "action=\"...\" lines with human copy survive stripping and are scanned"

   Do NOT write to the filesystem. Do NOT call check_file/1 from the regression test
   (it calls File.read! and expects a real path). Call strip_non_copy_lines/1 directly
   since both the test and the helpers share the same module scope.

   Note: strip_non_copy_lines/1 calls strip_doc_and_heex_comment_blocks/1 internally,
   which is fine — the synthetic line contains no doc/comment markers.

Do not modify any other part of the test file (the main describe block, @in_scope_files,
check_file/1, or banned_terms/0). Do not touch any scanned LiveView source files.
  </action>
  <verify>
    <automated>mix test test/sigra/admin/glossary_test.exs</automated>
  </verify>
  <done>
    - mix test test/sigra/admin/glossary_test.exs passes with 2 tests, 0 failures
    - The main drift-guard test still passes (8 real files, no false positives introduced)
    - The new regression test fails if action=\{ pattern is reverted to action= (manually verifiable by temporarily reverting the pattern and confirming the new test catches the gap)
    - grep confirms action=\{ is present in @strip_patterns and the old combined pattern ~r/(href|action|phx is gone
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| test code → module private functions | Same-module access in ExUnit; no external trust boundary |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-grh-01 | Tampering | @strip_patterns | accept | Test-only change; no production attack surface. Pattern narrowing verified by full test run. |
</threat_model>

<verification>
Run after editing:

```
mix test test/sigra/admin/glossary_test.exs
```

Expected: 2 tests, 0 failures.

Confirm both describe blocks are present and both tests pass:
1. "no banned synonyms in admin chrome source files" — existing guard, verifies no regressions in 8 scanned files
2. "action=\"...\" lines with human copy survive stripping and are scanned" — new regression guard

Also confirm the narrowed pattern is in place:
```
grep -n 'action=' test/sigra/admin/glossary_test.exs
```
Should show `action=\{` (Elixir-expression strip) NOT `action=` (bare strip).
</verification>

<success_criteria>
- mix test test/sigra/admin/glossary_test.exs → 2 tests, 0 failures
- @strip_patterns line 173 no longer contains bare `action=`; contains `action=\{` instead
- A second describe block exists with a regression test for action="..." human-copy scanning
- No scanned LiveView source files were modified
</success_criteria>

<output>
Create `.planning/quick/260618-grh-narrow-glossary-drift-guard-action-strip/260618-grh-01-SUMMARY.md` when done
</output>
