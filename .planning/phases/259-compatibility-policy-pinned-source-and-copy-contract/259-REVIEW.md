---
phase: 259-compatibility-policy-pinned-source-and-copy-contract
reviewed: 2026-11-15T00:28:28Z
depth: standard
files_reviewed: 22
files_reviewed_list:
  - test/example/priv/playwright/helpers/adminFlows.ts
  - test/example/priv/playwright/helpers/loginSubmit.ts
  - test/example/priv/playwright/tests/demo-showcase.spec.ts
  - test/example/priv/playwright/tests/ga-uat-shift-left.spec.ts
  - test/example/priv/playwright/tests/golden-path.spec.ts
  - test/example/priv/playwright/tests/organizations.spec.ts
  - test/example/priv/playwright/tests/passkey-options.spec.ts
  - test/example/test/example_web/enumeration_parity_test.exs
  - test/example/test/example_web/login_submit_selector_test.exs
  - test/sigra/brand/claims_docs_test.exs
  - test/sigra/brand/copy_contract_test.exs
  - test/sigra/brand/copy_inventory_test.exs
  - test/sigra/brand/frozen_surface_test.exs
  - test/sigra/brand/install_snippet_test.exs
  - test/sigra/brand/instruction_pointers_test.exs
  - test/sigra/brand/legacy_profiles_test.exs
  - test/sigra/brand/name_clearance_test.exs
  - test/sigra/brand/policy_docs_test.exs
  - test/sigra/brand/source_pin_test.exs
  - test/sigra/brand/vocabulary_docs_test.exs
  - test/support/brand/copy_inventory.ex
  - test/support/brand/copy_scan.ex
findings:
  critical: 0
  warning: 8
  info: 5
  total: 13
  necessity: 2
status: issues_found
---

# Phase 259: Code Review Report

**Reviewed:** 2026-11-15T00:28:28Z
**Depth:** standard
**Files Reviewed:** 22
**Status:** issues_found

## Summary

Phase 259 is a test and doc harness (pinned-source manifest, frozen-surface ratchet, copy
scanner and inventory, enumeration-parity registry, doc-contract tests, and a
copy-independent Playwright login selector). It ships no runtime code, so no finding is a
runtime defect and none is a security vulnerability.

Verification performed, not assumed:

- `mix test test/sigra/brand` passes (290 tests, 0 failures, no compile warnings on OTP 28.5 / Elixir 1.19.5).
- The two example-host tests (`enumeration_parity_test.exs`, `login_submit_selector_test.exs`) pass (29 tests).
- All 11 `#login_form button:has-text("Log in")` call sites at the base commit are replaced
  (`git grep` at HEAD returns none). The new selector `#login_form button:not([type="button"])`
  matches exactly one element on the example host login page, and the passkey control sits in a
  different form. The Playwright changes are sound.
- No home path, personal email or personal name appears in any reviewed file or fixture. The only
  literal in that family is `/private/var/folders/xx/logo.png` as a planted control
  (`source_pin_test.exs:189`), which is not a home path. The vendored `brand/` binaries were
  also checked for UTF-16 font name records, JPEG XMP/COM segments and PDF XMP: all clean.
- No workflow under `.github/` or `scripts/` sets any `SIGRA_BRAND_*` variable.

No finding reaches BLOCKER: every scanner blind spot below was probed with a real input and
confirmed, but I also grepped the scanned sources and confirmed that none of them currently
hides real content, and the baselines are accurate today. The concern is that the harness,
whose whole purpose is to stop later phases (262-263) from regressing, has fail-open paths
and some overstated claims that those phases will hit.

## Warnings

### WR-01: A banned multi-word phrase escapes when it is split across a line break

**File:** `test/support/brand/copy_scan.ex:735-737` (HEEx text), `:240-246` and `:452-456` (Markdown)
**Issue:** HEEx text is flushed per source line (`scan_markup(<<"\n", ...>>)` calls `flush/2`),
and the Markdown scope matches line by line. Every phrase-level term, "log in", "log out",
"sign off", "end user", "parent app", "sudo mode", "access level" and the lexicon entries
"zero trust", "bank-grade", is therefore invisible once an author breaks the line inside it.
Confirmed with a probe:

```
~H"""            ->  segments ["Please log", "in to continue"]  ->  hits []
<p>
  Please log
  in to continue
</p>
"""
```

The same probe over `["Our approach is not zero", "trust and not bank-", "grade either."]`
returns `[]`, while the one-line form returns one hit. `.formatter.exs` has no HEEx plugin, so
line breaks inside text are hand-placed and nothing normalises them. A grep of the scanned
sources finds zero occurrences today, so this is latent, but "log in" is the exact phrase
Phases 262-263 are meant to keep out.
**Fix:** Keep consecutive text lines of one element together, and flush only on tag or
expression boundaries. In `scan_markup/5`, treat `"\n"` as a space:

```elixir
defp scan_markup(<<"\n", rest::binary>>, mode, ctx, text, acc),
  do: scan_markup(rest, mode, ctx, [text, " "], acc)
```

For Markdown, match paragraph by paragraph (split on blank lines, collapse whitespace) instead
of per line. Joining changes segment text, so the committed `copy-baseline.json` must be
re-initialised once, in a reviewed commit.

### WR-02: Copy-segment extractor has several heuristics that fail open (and one that over-reads)

**File:** `test/support/brand/copy_scan.ex:557-559`, `:848`, `:566-576`, `:547`, `:869-886`
**Issue:** The scanner is documented as the single enforcement point for BCOPY-02, but each of
these was probed and behaves contrary to the module doc:

1. `code(<<"doc:", rest>>)` matches `doc:` at ANY byte offset, so a keyword ending in `doc`
   swallows the next literal. `[my_doc: "Please log in now"]` yields `[]`; the same line with
   `mydesc:` yields one hit.
2. `attr_value(<<"'", ...>>)` skips every single-quoted attribute value even for the
   documented copy attributes. `<a title='Log in here'>` yields `[]`; the double-quoted form
   yields a hit. HEEx accepts single-quoted values.
3. The generic sigil clause skips `~H(...)`, `~H[...]` and `~H{...}`: only `~H"` and `~H"""`
   are treated as markup. `~H(<p>Please log in now</p>)` yields `[]`.
4. `code(<<"#", ...>>)` treats any `#` as a comment, including the char literal `?#`:
   `x = ?# ; put_flash(:info, "Please log in")` yields `[]`.
5. `remove_preview_block/2` finds the last `<div` before the marker, then balances `</div>`
   from the marker's closing `>`. If the marker element is not a `<div>` (say a `<section>`),
   the enclosing `<div>` and everything in it, banned text included, is silently exempted. Probe:
   `<div class="outer"><h2>Login preview</h2><section class="sigra-auth sigra-auth--preview">...</section><p>Org settings</p></div>`
   yields `[]`. Today the marker element is a `<div` (`lib/sigra/admin/components.ex:1079`), so
   it works.
6. The opposite error: `doc:` followed by a newline is not skipped, so developer docs are
   scanned as copy. `lib/sigra/admin/components.ex:692-693` (`doc:\n "renders the Actor and ..."`)
   is currently emitted as a segment. A banned word there would force a baseline entry for text
   that is not shipped copy.

No scanned file currently exercises 1-4 (grepped), so no hit is masked today.
**Fix:** Make the scanner fail closed. For 1, anchor to attribute-keyword shape: `defp code(<<"doc:", ...>>)`
only when the previous byte is not an identifier character (track `prev` or pre-tokenize on
`\bdoc:`). For 2, handle `'` values with `take_string`-style quote-aware scanning. For 3,
accept `~H` with any delimiter via the existing `skip_sigil`/`closing/1` helpers and route
the body through `markup/4`. For 4, special-case `?`-prefixed char literals before the `#`
clause. For 5, assert the marker element name and `raise ArgumentError` when it is not a
`div`. For 6, trim leading whitespace including newlines before `skip_doc_value/1`.

### WR-03: Inventory and scanner claim completeness they do not have (JS copy, attribute values, helper literals)

**File:** `test/support/brand/copy_inventory.ex:171-188` (written into every TSV), `:12-17`, `:68`; `test/support/brand/copy_scan.ex:190-198`
**Issue:** `render/2` stamps every committed inventory with "Every user-visible string Sigra ships
in this ownership lane. A copy change shows up as a reviewed diff of this file instead of
passing silently." The module doc admits the extractor omits browser-side `.js` copy, HEEx
attribute values and string literals returned from helpers, but the committed files carry the
unqualified claim. It is false. Probing `CopyScan.copy_segments/3` over the generated templates
and diffing against `generated.tsv` finds about 200 multi-word segments with no inventory row
(a minority are CSS class lists). Real examples: `Open command palette`, `Admin navigation`,
`Invalid audit export filters` (`admin/audit_export_controller.ex`), and
`title: "Passkey sign-in was canceled."` (`core/mfa_settings_live.ex:671`).

Separately, `CopyScan.files_for/1` documents "CSS, SVG, JS and JSON files carry no scanned
copy" (`copy_scan.ex:196-197`). That is wrong for JS: `priv/templates/sigra.install/passkeys/passkey_browser.js:41-80`
ships five user-visible status messages ("Enter your email to continue with a passkey.",
"Passkeys aren't available in this browser.", "Passkey sign-in was canceled.", "That passkey
request timed out.", "We couldn't finish passkey sign-in..."). Neither the copy contract nor the
inventory sees them, and no test asserts the claim. BCOPY-04 is marked Complete with the text
"so every copy change is a reviewable diff".
**Fix:** Either narrow the stamped header and the `files_for` doc to what is extracted
("covers dgettext msgids, put_flash literals, HEEx text nodes and email literals; excludes JS,
attribute values and helper-returned literals"), or close the gap: add a `.js` extractor for
quoted multi-word strings and include copy attributes (`aria-label`, `title`, `placeholder`,
`alt`) in the HEEx rows. If the gap is accepted for now, add a test that pins the exclusion list
so it cannot grow silently, and soften the BCOPY-04 wording.

### WR-04: The `:admin` copy contract omits shipped library copy that the inventory proves exists

**File:** `test/support/brand/copy_scan.ex:66-76`, `test/sigra/brand/copy_contract_test.exs:567-582`
**Issue:** The `:admin` scope is pinned to nine files (`Enum.count(... "lib/sigra/admin/") == 9`)
to mirror the older glossary guard. `library.tsv` inventories the whole of `lib/sigra/admin/**`
plus `lib/sigra/error.ex`. The following contain shipped copy and sit outside every contract
scope: `lib/sigra/error.ex` (27 `safe_message/1` strings, the text hosts render to end users,
for example "Could not complete sign in."), `lib/sigra/admin/audit/presenter.ex` (7 strings),
`lib/sigra/admin/users/detail.ex` and `users/query.ex` (1 each). A banned term or lexicon word added
to any of them passes the copy contract. The test also hard-codes `== 9`, so adding a tenth
chrome file fails the test instead of extending the scan.
**Fix:** Derive the admin scope from the same glob the inventory uses
(`lib/sigra/admin/**/*.ex`) and add `lib/sigra/error.ex` as its own scope, or document in the
moduledoc that the contract intentionally excludes library-returned strings. If the narrow
scope is intentional, assert it explicitly with a named exclusion list so that a new file under
`lib/sigra/admin/` must be classified.

### WR-05: Add-only and shrink-only ratchets can be loosened by editing the fixture, with nothing to catch it

**File:** `test/sigra/brand/frozen_surface_test.exs:205-232`, `test/sigra/brand/copy_contract_test.exs:664-668`, fixtures `test/fixtures/brand/frozen-surface.json`, `test/fixtures/brand/copy-baseline.json`
**Issue:** `baseline SUBSET-OF current` only protects a name while it is in the committed JSON.
Deleting the name from `frozen-surface.json` in the same commit that removes the surface turns
the failing test green: the non-empty check only asserts `!= []`, and `profile_defaults` is the
only category with values pinned in test source. The inverse holds for `copy-baseline.json`:
adding an entry by hand for a new violation makes `diff_baseline/2` report neither new nor
stale, so "never baseline a new violation" is a convention. The extension helpers
(`extend_only/2`, `init_baseline/3`) are only guards on the opt-in writer, not on a human edit.
There is no CI step comparing the fixtures against the base branch and no CODEOWNERS file
(searched `.github/`, `scripts/`, repo root, `docs/`).

Related integrity gap: `assert_scope_matches_baseline/1` filters entries by `&1.scope == name`
for the three known scopes, so an entry with a mistyped or unknown scope (or one for a scope
missing from `initialized_scopes`) is never compared and never fails.
**Fix:** Add a CI check that compares the committed fixture to the merge-base version
(`git show origin/main:test/fixtures/brand/frozen-surface.json`) and fails on any removed name or
on any added `copy-baseline.json` entry. In-repo, pin a floor/ceiling per category (for example
`@min_names %{"routes" => 60, ...}` bumped upward only) and add:

```elixir
test "every baseline entry belongs to an initialized, implemented scope" do
  %{initialized_scopes: init, entries: entries} = CopyScan.load_baseline()
  known = Enum.map(CopyScan.scopes(), &Atom.to_string/1)
  assert Enum.all?(entries, &(&1.scope in init and &1.scope in known))
end
```

### WR-06: The unbounded-claim sweep can be laundered by neighbouring text in the same paragraph

**File:** `test/sigra/brand/claims_docs_test.exs:48-54`, `:112-117`, `:159-171`
**Issue:** A paragraph is exempt if it contains any of five generic substrings ("single attempt",
"not covered", ...), and a "paragraph" is whatever lies between blank lines. A Markdown table or
bullet list is one paragraph, so one properly scoped row exempts every other row. Probed
against the real README: inserting `| **Registration** | Registration is enumeration-safe. |`
directly under the scoped `| **Enumeration** |` row (line 177) yields zero offenders. A single
unrelated sentence also launders a claim: "Sigra is enumeration-safe. Windows is not covered."
passes. The BCOPY-07 contract ("docs do not claim enumeration safety beyond what is proven") is
therefore only enforced for claims in a paragraph of their own. Family B also only matches four
verbs (`reveal|disclos|leak|expos`), so "regardless of whether" or "indistinguishable" phrasing is not seen.
**Fix:** Evaluate claims per table row and per list item, not per blank-line paragraph, and
require the qualifier to sit in the same row or item. Tighten the qualifiers to phrases that
tie to the harness ("same message for the compared case", "Scope of this claim"), and drop the
generic "not covered". Add a planted-control test that a claim in a sibling table row of a
scoped row is still flagged.

### WR-07: `SIGRA_BRAND_COPY=regen` overwrites all three inventories with no CI guard and makes the equality test vacuous

**File:** `test/support/brand/copy_inventory.ex:96`, `:254-258`, `test/sigra/brand/copy_inventory_test.exs:22-28`
**Issue:** When the variable equals `regen`, `setup_all` writes every lane's TSV from a fresh
extraction before any test reads it, so `assert_inventory_current/1` then compares the file with
itself and passes whatever the sources say. Nothing refuses this under `CI=true`, and the project
auto-loads env files via direnv (`tmp/db.env`), so a stray export is plausible. No workflow
sets it today. The other two opt-in writers are safe: `SIGRA_BRAND_LEGACY=write` never overwrites an existing
file and `SIGRA_BRAND_COPY_BASELINE=init` only fills uninitialised scopes.
**Fix:** Refuse the write in CI and fail the run so it cannot go green:

```elixir
def regenerate? do
  if System.get_env(@regen_env) == "regen" do
    if System.get_env("CI") in ["true", "1"],
      do: raise("#{@regen_env}=regen is a local maintainer action and must not run in CI")
    true
  else
    false
  end
end
```

### WR-08: Parity rows can be green on empty-versus-empty, and the positive control never exercises the probes

**File:** `test/example/test/example_web/enumeration_parity_test.exs:64`, `:458-493`, `:528-556`, `:605-628`, `:797-804`
**Issue:** The "leak" control mutates the unknown-identity response after `probe_pair/1` has
captured it, so it proves only that `compare/3` detects a string difference. It does not prove
that a probe observes the real response. For `mfa-challenge` the compared dimensions are
`status`, `redirect` and `flash`, but `capture_live/3` hard-codes `status: @live_render_status`
(200) and `location: nil`; the only live signal is `:sys.get_state(view.pid).socket.assigns.flash`.
If that assign moves (for example the view starts rendering the error inline), both sides
capture `%{}`, the row compares `:same`, and the suite stays green while the DOM differs, since
`body` is excluded by design. Nothing asserts the captured flash is non-empty. The row's identity
axis is also "code kind, not account existence" (its own note), yet it supplies one of the three
parity rows required by the "at least three of the five named surfaces must be parity" assertion
(`:158-179`); the claims register labels it honestly as bounded, but it does not test enumeration.
**Fix:** Add a per-row non-vacuity assertion in `run_all/2` or a dedicated test: for every parity row, at
least one compared dimension must be non-constant and non-empty on the existing-identity
response, for example

```elixir
for %{"state" => "parity"} = row <- surfaces(), {existing, _} = probe_pair(row["id"]) do
  assert Enum.any?(dimensions(row), &(Map.fetch!(existing, &1) not in [nil, %{}, ""]))
  assert existing.flash != %{} or existing.body != ""
end
```

For the control, plant the leak inside the app-facing request (for example a flash-bearing
param the controller echoes in a test-only plug) or assert each probe's captured flash text
against the known expected string ("Invalid verification code. N attempts remaining.").

## Info

### IN-01: Privacy scan claims "author metadata" but models a narrower set of containers

**File:** `test/sigra/brand/source_pin_test.exs:412-416`, `:450-459`, `:490-518`, `:137`
**Issue:** Binary files are scanned only through ASCII printable runs of length 6 or more, so
UTF-16 name-table records in fonts are invisible. JPEG is checked only for `Exif\0\0` (not XMP APP1
or COM segments), PNG only for four text chunk types (not `iCCP` or `tIME`), and PDF only for
`/Author` plus Creator and Producer values (not XMP streams). I verified the real `brand/` tree
is clean on all of these (UTF-16 strings in all fonts, JPEG segment list, PDF Info/XMP), so
nothing leaks today.
**Fix:** Either reword the test title and moduledoc to "the author-metadata forms listed here",
or add UTF-16LE/BE run extraction for `.ttf/.otf` and APP1/COM parsing for JPEG.

### IN-02: `markup_classes` lazily truncates `class={...}` at the first `}`

**File:** `test/sigra/brand/frozen_surface_test.exs:411-420`
**Issue:** The pattern `class=(?:"([^"]*)"|\{(.*?)\})` stops at the first `}`, which is the closing
brace of an interpolation. `class={["sg-card", "sg-metric-#{kind}", "sg-card--hot"]}` captures
`sg-card` and the dropped fragment `sg-metric-`, and loses `sg-card--hot`. A class listed after
the first interpolation is therefore never frozen. I compared this extractor against a
balanced-brace version over the real admin sources: both yield 153 `sg-` names, so nothing is lost
today. The extractor is the sole definition of the frozen set, so the gap would be silent.
**Fix:** Replace the lazy group with a balanced-brace scan (a small `take_balanced` like the one
in `copy_scan.ex`), and add the planted input above to the "extractors" tests.

### IN-03: Test-helper duplication across the brand suite

**File:** `test/sigra/brand/frozen_surface_test.exs:626-652` and `legacy_profiles_test.exs:264-290` (identical `pretty/2`), `copy_scan.ex:397-418` (a third renderer); `policy_docs_test.exs:58-78`, `name_clearance_test.exs:91-111`, `vocabulary_docs_test.exs:108-121` (`section_slice`, `cells`, `table_rows`)
**Issue:** `pretty/2` is copied verbatim in two tests, and the markdown helpers (`cells/1` three
times, `section_slice/2` three times with slightly different terminators, `root/0` + `read!/1`
in seven modules) have already diverged: `vocabulary_docs_test.exs` also stops a section at a
`---` rule, the other two do not. A fix to one will not reach the others.
**Fix:** Move them into `test/support/brand/` (for example `Sigra.Test.Brand.Doc` and
`Sigra.Test.Brand.PrettyJSON`) and import them.

### IN-04: Impossible-state guard: `extend_only/2` check inside `extend_baseline!/0`

**File:** `test/sigra/brand/frozen_surface_test.exs:540-547`, `:588-602`
**Category:** necessity
**Issue:** `extend_baseline!/0` computes `proposed = union(committed, current)` and then calls
`extend_only(committed, proposed)`. `union/2` (`:549-553`) merges with `old ++ new` and never
drops a name, so the `{:error, removed}` branch and the `raise "refusing to shrink..."` are
unreachable. The pure unit test at `:120-128` already asserts the exact property the runtime
guard re-checks (`union` never shrinks). Defence in depth does not apply: this is a local,
opt-in dev tool, not a trust boundary.
**Fix:** Drop the runtime branch (keep `extend_only/2` and its unit tests if it is wanted as a
documented invariant), or move the check to compare the file against the merge-base version,
which is the check that could actually fail (see WR-05).

### IN-05: Generality without instantiation: the sweep allow-list machinery for a list that must stay empty

**File:** `test/sigra/brand/claims_docs_test.exs:66`, `:173-195`, `:523-551`
**Category:** necessity
**Issue:** `@sweep_allow_list` is `[]`, and both the moduledoc and the failure message forbid
adding to it ("every hit is fixed by rewording the doc, never by adding an entry"). The
`apply_sweep_allow_list/3` and `stale_sweep_entries/2` helpers, the stale-entry test, and
three planted-control tests exist to support a list the policy says can never be populated, and
the staleness test over `[]` is vacuous. This is judgment, not provable lapse, so it stays Info.
**Fix:** Delete the allow-list plumbing and its tests, keeping the "fix the doc" failure message.
If an escape hatch is wanted later, add it with its first real entry.

---

_Reviewed: 2026-11-15T00:28:28Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
