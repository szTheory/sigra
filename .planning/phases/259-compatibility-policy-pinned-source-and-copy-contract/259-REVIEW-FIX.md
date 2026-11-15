---
phase: 259-compatibility-policy-pinned-source-and-copy-contract
fixed_at: 2026-11-15T00:46:17Z
review_path: .planning/phases/259-compatibility-policy-pinned-source-and-copy-contract/259-REVIEW.md
iteration: 1
findings_in_scope: 6
fixed: 6
skipped: 0
status: all_fixed
---

# Phase 259: Code Review Fix Report

**Fixed at:** 2026-11-15T00:46:17Z
**Source review:** .planning/phases/259-compatibility-policy-pinned-source-and-copy-contract/259-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 6 (WR-01, WR-02, WR-03 wording only, WR-06, WR-07, WR-08)
- Fixed: 6
- Skipped: 0

The scope was a selected subset chosen by the orchestrator. Out of scope and
untouched: the scope-expansion part of WR-03 (new extraction kinds or rows), WR-04,
WR-05 and IN-01 through IN-05. They stay open in 259-REVIEW.md.

Every fix landed as its own commit on the main tree (no worktree, as instructed),
with hooks on. Nothing was pushed. No file under `lib/`, `priv/`, `brand/`,
`brandbook/`, `.github/` or `scripts/` changed, and neither
`test/fixtures/brand/copy-baseline.json` nor `test/fixtures/brand/frozen-surface.json`
was touched, so no baseline entry was added, moved or hidden.

## Fixed Issues

### WR-07: `SIGRA_BRAND_COPY=regen` overwrites all three inventories with no CI guard

**Status:** fixed
**Files modified:** `test/support/brand/regen_guard.ex` (new), `test/support/brand/copy_inventory.ex`,
`test/support/brand/copy_scan.ex`, `test/sigra/brand/frozen_surface_test.exs`,
`test/sigra/brand/legacy_profiles_test.exs`, `test/sigra/brand/regen_guard_test.exs` (new)
**Commit:** 8a6744b69
**Applied fix:** The other three flags share the same hole (each writer runs in `setup_all`
before the test that compares the fixture with the sources), so all four are guarded:
`SIGRA_BRAND_COPY=regen`, `SIGRA_BRAND_COPY_BASELINE=init`, `SIGRA_BRAND_BASELINE=extend`
and `SIGRA_BRAND_LEGACY=write`. Every opt-in read now goes through
`Sigra.Test.Brand.RegenGuard.requested?/3`, which raises a clear message when the writer is
requested while `CI` is `true` or `1` (case-insensitive). The new test plants environments for
each writer (allowed locally, raises under CI), and a source scan fails when any brand test or
helper reads the environment directly, so a future writer cannot skip the guard.
End-to-end check: `CI=true SIGRA_BRAND_COPY=regen mix test test/sigra/brand/copy_inventory_test.exs`
fails in `setup_all` with the refusal message and rewrites no TSV.

### WR-03 (wording only): inventory and scanner claim completeness they do not have

**Status:** fixed (wording part only, as scoped)
**Files modified:** `test/support/brand/copy_inventory.ex`, `test/support/brand/copy_scan.ex`,
`test/sigra/brand/copy_inventory_test.exs`, `test/fixtures/brand/copy-inventory/generated.tsv`,
`test/fixtures/brand/copy-inventory/host.tsv`, `test/fixtures/brand/copy-inventory/library.tsv`
**Commit:** be8faf8aa
**Applied fix:** The stamped header no longer says "Every user-visible string Sigra ships".
Each lane header now has a COVERAGE section: what the extractor covers, and what it does not
(for the generated lane: browser-side copy in `.js` hooks, HEEx attribute values, and raw
string literals outside dgettext, put_flash, `~H` text and the email builders). The
`CopyScan.files_for/1` doc and the scanner moduledoc now say JS files carry copy that no scope
reads, replacing the false "JS files carry no scanned copy". The three TSVs were regenerated
only through `SIGRA_BRAND_COPY=regen`; a diff check shows header lines as the only change (zero
row lines added or removed). Two new tests pin the header text and assert each committed TSV
carries exactly the header `render/2` writes, which the row-only equality test did not cover.
No extraction kind and no row was added.

### WR-01: A banned multi-word phrase escapes when it is split across a line break

**Status:** fixed: requires human verification (new matching heuristic; verified by planted
tests with negative controls, not by a semantic proof)
**Files modified:** `test/support/brand/copy_scan.ex`, `test/sigra/brand/copy_contract_test.exs`
**Commit:** 77f4ae63b
**Applied fix:** The reviewer's suggested fix (treat a newline as a space, match per paragraph)
would rewrite the text of every committed baseline entry, which is a baseline change this task
forbade. The fix is additive instead: every match inside one line is the same hit as before, and
consecutive lines of one text are additionally matched joined by a space. A match that crosses a
line break is a hit whose text is the lines it spans.
- Markdown: a run is a paragraph or a list item with its continuation lines. A blank line,
  heading, table row, thematic break, HTML line, reference definition or a new list item ends the
  run. List and block-quote markers are stripped for the join.
- HEEx and heredoc text: a hard-wrapped sentence carries on when the current line has copy and
  the next line opens with plain text (not a tag, and not an expression opener for that mode).
  Per-line segments are unchanged, so `copy_segments/3` output is identical.

The real scan surfaces no new hit and `copy-baseline.json` is untouched. Planted tests cover
wrapped Markdown, list items, block quotes, HEEx, heredoc text, the hyphen case ("bank-" /
"grade") and the cases that must stay separate; 7 of them go red against the previous scanner.
Known limit, documented in the `scan_lines/3` doc: a phrase split around an inline tag at a line
start (`log` then `<b>in</b>`) is still not joined, because treating every tag line as a
continuation would join across block elements.

### WR-02: Copy-segment extractor has several heuristics that fail open

**Status:** fixed: requires human verification (scanner heuristics; verified by planted tests
with negative controls)
**Files modified:** `test/support/brand/copy_scan.ex`, `test/sigra/brand/copy_contract_test.exs`
**Commit:** 3c829010c
**Applied fix:** All six listed behaviours:
1. `doc:` at any byte offset: identifiers are now consumed whole, so `my_doc: "..."` is copy and
   only a bare `doc` keyword is a documentation option.
2. Single-quoted attribute values: now read like double-quoted ones, so a copy attribute
   (`title='Log in here'`) is scanned and any other single-quoted value is still ignored. An
   unterminated value raises naming the file.
3. `~H(...)`, `~H[...]`, `~H{...}`, `~H|...|` and `~H'''` are now markup. Delimiter handling follows
   Elixir (the sigil ends at the first unescaped closing delimiter; delimiters do not nest).
   `~H/.../` and `~H<...>` are accepted by the scanner but cannot hold a tag in real Elixir, so the
   tests do not plant them.
4. `?#` and `?"` character literals no longer read as a comment or string opener.
5. The preview carve-out now checks the marker's element is a `<div>` and raises
   `ArgumentError` (with the file prefix) otherwise, instead of exempting the enclosing `<div>`.
6. `doc:` followed by a newline is now skipped. This is the one change to the real extraction: the
   developer doc string at `lib/sigra/admin/components.ex:692` leaves the segment list. I diffed
   all 1,500-odd real segments before and after: that line is the only difference. It had no
   baseline entry, so `copy-baseline.json` is unchanged and nothing was baselined.

Six planted tests (one per behaviour plus the unterminated cases) go red against the previous
scanner. The baseline stop condition did not trigger: no fix changed a baseline in the
non-shrinking direction.

### WR-06: The unbounded-claim sweep can be laundered by neighbouring text in the same paragraph

**Status:** fixed: requires human verification (claim-unit splitting heuristic; verified by
planted controls including a mutation of the real README)
**Files modified:** `test/sigra/brand/claims_docs_test.exs`
**Commit:** 18cb6494c
**Applied fix:** The sweep now evaluates claim units: prose paragraphs, with each table row and
each list item (plus its continuation lines) a unit of its own, and the qualifier must sit in the
same unit. The generic "not covered" qualifier is dropped from the list. Family B gains the verbs
"indicate" and "confirm", and a new family C catches "indistinguishable" and "regardless of
whether". The real docs pass unchanged under the stricter rules, so no doc was reworded.
New controls: a claim in a sibling table row of a scoped row, the same insertion into the real
README under its Enumeration row (the reviewer's probe, now a test), a sibling list item, a list
item whose qualifier is in its own continuation line, a row carrying its own qualifier, and
"not covered" no longer bounding a claim. Four of them go red against the paragraph-level logic.

### WR-08: Parity rows can be green on empty-versus-empty

**Status:** fixed
**Files modified:** `test/example/test/example_web/enumeration_parity_test.exs`
**Commit:** 82e8821a1
**Applied fix:** I reproduced the finding first: dropping the flash in `capture_live/3` left every
existing test green, including the leak control. A parity row must now capture real content: for
the existing and the unknown side of every parity row, each content dimension (flash, body) the
row lists must be non-empty, and the captured flash is asserted against the message the surface
really shows (password sign-in "Invalid email or password", magic-link request "If your email is
registered ...", mfa challenge "Invalid verification code. N attempts remaining."). A table in
the test forces a new parity row to state its expected flash, and a pure control proves
the check reports a response that observed nothing. With the flash assign dropped again, only the
new test goes red. I used the reviewer's second suggestion (assert the captured text) rather than
planting a leak inside an app-facing request, which would add a leak switch the module says must
not exist in app code.
Not changed: `mfa-challenge` still varies by code kind rather than account existence and still
counts toward the "at least three of five" parity assertion. The registry and claims register
already label it as bounded, and excluding it would fail that BCOPY-03 count, so this is an owner
decision, not a fix.

## Skipped Issues

None. No in-scope finding was skipped. The baseline stop condition (a fix that would change
`copy-baseline.json` in the non-shrinking direction) did not trigger for any item.

## Verification

Run in the main checkout (no worktree), against the test Postgres from `tmp/db.env`, after the
last commit:

- `mix test test/sigra/brand`: 331 tests, 0 failures (290 before the fixes).
- `cd test/example && mix test test/example_web/enumeration_parity_test.exs test/example_web/login_submit_selector_test.exs --include example_app`:
  32 tests, 0 failures.
- `mix format --check-formatted` at the repo root: clean.
- Zero shipped bytes: `git diff --name-only 124b84c14..HEAD` lists nothing under `lib/`, `priv/`,
  `brand/`, `brandbook/`, `.github/` or `scripts/`.

Note for whoever runs `mix format` inside `test/example`: seven files under `test/example/lib/`
are already unformatted at HEAD and get reformatted as a side effect. I reverted that
(`git checkout -- test/example/lib`) so it is not part of any fix commit.

---

_Fixed: 2026-11-15T00:46:17Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
