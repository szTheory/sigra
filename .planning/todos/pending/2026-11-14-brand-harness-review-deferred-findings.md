---
created: 2026-11-14T00:00:00.000Z
status: pending
title: Brand harness code review (Phase 259) - deferred findings needing an owner or scope decision
area: testing
severity: minor
source: Phase 259 code review (259-REVIEW.md) and fix report (259-REVIEW-FIX.md)
files:
  - test/support/brand/copy_scan.ex
  - test/support/brand/copy_inventory.ex
  - test/sigra/brand/copy_contract_test.exs
  - test/sigra/brand/claims_docs_test.exs
  - test/sigra/brand/frozen_surface_test.exs
  - test/example/test/example_web/enumeration_parity_test.exs
  - test/sigra/brand/source_pin_test.exs
---

Phase 259's code review found 0 critical and 8 warnings. WR-01, WR-02, WR-06, WR-07, WR-08 and the wording-only part of WR-03 were fixed (see `259-REVIEW-FIX.md`). The items below were deliberately NOT changed because they are scope or owner decisions, not mechanical fixes. Evidence and suggested fixes are in `259-REVIEW.md` under the same ids.

## Decisions needed

- **WR-03 (scope part):** the copy inventory does not extract JS hook copy (`passkey_browser.js`, `admin_hooks.js`), HEEx attribute values (`label=`, `placeholder=`, `aria-label=`, `title=`, `phx-disable-with=`, `data-confirm=`), or raw Elixir literals outside dgettext / put_flash / HEEx / email builders (about 200 multi-word generated strings). The headers now say so. Decide whether a Phase 262-263 task adds `literal` and `heex_attr` kinds (one regeneration plus a reviewed diff) before copy edits begin; until then a copy edit to those forms passes the inventory unseen.
- **WR-04:** the admin copy contract is pinned to nine files. `lib/sigra/error.ex` (27 `safe_message` strings), `lib/sigra/admin/audit/presenter.ex` (7) and a few other strings under `lib/sigra/admin/` sit outside every scope although the inventory lists them. Decide whether to widen the scope (this changes baselines in the growing direction, so it needs review).
- **WR-05:** the add-only and shrink-only ratchets (frozen-surface, copy-baseline) can be loosened by editing the JSON in the same commit as the breaking change; there is no base-branch diff gate or CODEOWNERS file, and an unknown scope name in a baseline entry is ignored. Decide on a CI diff-against-base check and/or CODEOWNERS for `test/fixtures/brand/`.
## Info findings (optional cleanup)

- IN-01: the privacy scan models fewer metadata containers than its claim (UTF-16 font records, JPEG XMP/COM, PNG `iCCP`/`tIME`, PDF XMP). The real `brand/` tree is clean today.
- IN-02: `markup_classes` in `frozen_surface_test.exs` truncates `class={...}` at the first `}`; latent.
- IN-03: duplicated helpers across the brand tests (`pretty/2`, `section_slice`, `cells`, `read!`).
- IN-04 (necessity): the `extend_only` refusal inside `extend_baseline!` is unreachable.
- IN-05 (necessity): the sweep allow-list machinery supports a list the policy says must stay empty.

## Resolved

- **WR-08 (residual), resolved by Plan 259-16:** the `mfa-challenge` row varies by code kind, not account existence, so it is kept as a parity probe and counted separately. The named-surface rule in `enumeration_parity_test.exs` now requires the three account-existence surfaces (`password-signin`, `magic-link-request`, `password-reset-request`) to be parity on their own, with `confirmation-resend` (payload ignored) and `mfa-challenge` (code kind) in separate classes that can never satisfy or stand in for them; the "at least three of five" floor and the parity-or-not_proven tolerance are deleted. The classification is test-only and reversible with a one-line edit; the owner may revisit it.

## Housekeeping noticed by the fixer

`mix format` run inside `test/example` reformats seven pre-existing unformatted files under `test/example/lib/`; the drift is already at HEAD and was left alone.

## Re-review after gap closure (2026-11-15)

The incremental re-review of the gap-closure plans 259-14..259-18 and the post-review fixes (`259-REVIEW.md`, reviewed range `124b84c14..HEAD`) found 0 critical, 6 warnings and 2 info findings. WR-01, WR-02, WR-03 and IN-01 were fixed (see `259-REVIEW-FIX.md`). The four below were deliberately not changed: two are scanner and recogniser design work, one is an owner decision about scope, and one is a small set of scanner gaps that need a reviewed baseline refresh. None hides a hit today; each is a regression gap for the Phase 262-263 copy rewrite. Probes were run against the real code, not read off the source.

### WR-04: a banned phrase split across `<>`-joined string literals escapes the copy scanner

**File:** `test/support/brand/copy_scan.ex:746-761` (`code/3` string clause and `literal/3`)

The earlier review's WR-01 closed the line-break escape, but the same escape remains for string concatenation. Every string literal is judged on its own, so a long message built with `<>` is invisible. Probed against the real scanner with scope `:generated`:

```
put_flash(:info, "Please log " <> "in to continue")          -> []
put_flash(:info,\n  "Please log " <>\n    "in to continue")   -> []
put_flash(:info, "Please log in to continue")                 -> one hit
```

`mix format` never breaks inside a string, so long copy is routinely written exactly this way. No scanned file contains such a chain today (`git grep` for `"..." <> "..."` over `priv/templates` and `lib/sigra/admin` is empty), so no hit is masked now. It is the shape Phases 262-263 are most likely to introduce when they rewrite sentences, and the contract exists to stop those phases regressing.

**Suggested fix:** in `code/3`, after reading a string literal, look ahead for `\s*<>\s*"` and fold the chained literals into one segment before `copy_literal?/1` and `line_hits/4`:

```elixir
defp code(<<"\"", rest::binary>>, ctx, acc) do
  {raw, rest} = take_string(rest)
  {raw, rest} = join_concatenated(raw, rest)   # consumes `<> "..."` chains
  code(rest, ctx, literal(raw, ctx, acc))
end
```

Add a planted control for both the same-line and the wrapped form, and an inventory-side equivalent so `CopyInventory` and `CopyScan` agree about a concatenated literal.

### WR-05: the `sigra.gen.oauth` and `sigra.upgrade` template directories are outside every scope and inventory lane, and they ship banned phrases (owner decision)

**File:** `test/support/brand/copy_scan.ex:83` (`@templates_dir "priv/templates/sigra.install"`) and `:225-227` (`files_for(:generated)`); `test/support/brand/copy_inventory.ex:52` (`@templates_dir`)

The `:generated` copy scope and the `generated.tsv` lane read only `priv/templates/sigra.install/**`. `priv/templates/` also holds `sigra.gen.oauth/` (12 files) and `sigra.upgrade/` (3 files). Both ship in the Hex package (`mix.exs` `files:` includes `priv`) and `mix sigra.gen.oauth` writes the former into adopter applications. They contain exactly the phrases the contract bans in generated copy:

- `sigra.gen.oauth/oauth_controller.ex:96` ("An account with this email exists. Log in to link your ... account.")
- `sigra.gen.oauth/oauth_settings_live.ex:86` and `oauth_settings.html.heex:34` ("You'll still be able to log in with:")

Because the baseline is the worklist Phases 262-263 use ("legacy wording such as 'Log in' in generated flashes that Phases 262-263 rewrite"), these instances are not on it, and the contract cannot go red if they are reintroduced or left behind. The scope name `generated` and requirement BCOPY-02 ("generated templates") read as covering all generated output; the exclusion is stated in code but was not tracked here.

**Decision needed (owner):** either add the two directories to `files_for(:generated)` and the inventory glob (one baseline initialisation and one inventory regeneration, in a reviewed commit, which grows the baseline), or name the exclusion in the `:generated` moduledoc and keep it on this todo so Phase 262 includes the oauth templates in its manual sweep. Until decided, Phase 262 must sweep `priv/templates/sigra.gen.oauth/` and `priv/templates/sigra.upgrade/` by hand.

### WR-06: the unbounded-claim recogniser misses ordinary wordings, so the sweep is narrower than its title

**File:** `test/sigra/brand/claims_docs_test.exs:137-164` (families A, B and C) and `:527-545` (the sweep test)

The sweep is titled "no claim unit makes an unqualified enumeration claim" and the moduledoc says it "flags any claim unit ... that makes an unbounded claim". It flags only what the three regex families match. Probed with the exact regexes from the test, each of these returns not-flagged:

```
"Sigra blocks enumeration of accounts."         "It prevents username enumeration."
"Sigra stops user enumeration."                 "It prevents account-enumeration attacks."
"Sigra mitigates enumeration attacks."          "It protects from enumeration."
"The flow is enumeration-proof."                "It defends against enumeration."
"The flow is enumeration-free."                 "The response does not reveal which emails are registered."
```

All current docs pass, so nothing is hidden today. The gate exists for the Phase 263 copy rewrite, which will produce new sentences, and "prevents username enumeration", "enumeration-proof" and "does not reveal which ..." are direct, likely phrasings. The paraphrase space cannot be closed by adding regexes one at a time.

**Suggested fix:** invert the rule. Any claim unit that mentions `enumerat\w*` and carries none of the qualifier phrases is flagged, with an explicit allow pattern for threat descriptions that the existing "does not flag threat descriptions" test already names ("a common enumeration vector"). Keep families B and C for the wordings that do not contain "enumerat", and add the nine strings above as planted controls.

### IN-02: the scanner is narrower than the inventory in three small ways

**File:** `test/support/brand/copy_scan.ex:766-769` (`copy_literal?/1`), `:87` (`@copy_attrs`) and `:1082` (`attr_literal/3`); `test/support/brand/copy_inventory.ex:358-362`

Probed; all fail open and none hides a hit today (no scanned source uses them):

1. HTML entities are not decoded: `<p>Please log&nbsp;in</p>` yields no hit.
2. A lone lowercase word is never copy: `put_flash(:info, "login")` yields no hit, while `CopyInventory.visit/2` documents "A literal passed straight to put_flash is copy even when it is one word", so the two extractors disagree about the same literal.
3. `@copy_attrs` omits `data-confirm`, `phx-disable-with`, `aria-description` and `value`, all visible text. There are 26 real uses across `priv/templates` and `lib/sigra/admin`, for example `data-confirm="...You will be logged out."` (`sigra.install/core/session_live.ex:92`) and `phx-disable-with="Creating account..."`. The moduledoc lists the six covered attributes honestly and Plan 259-08 records the gap, but the earlier WR-03 entry above only tracks it for the inventory, not for the banned-term scan.

**Suggested fix:** decode `&nbsp;` and `&#160;` before matching; treat a literal passed straight to `put_flash` or `dgettext` as copy in `CopyScan` too; add `data-confirm`, `phx-disable-with` and `aria-description` to `@copy_attrs` (one reviewed baseline refresh), or record the decision here.
