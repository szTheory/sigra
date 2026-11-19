---
phase: 259-compatibility-policy-pinned-source-and-copy-contract
reviewed: 2026-11-15T14:30:38Z
depth: standard
files_reviewed: 21
files_reviewed_list:
  - README.md
  - guides/flows/password-reset.md
  - test/example/lib/example_web/live/confirmation_live.ex
  - test/example/lib/example_web/live/reset_password_live.ex
  - test/example/lib/example_web/router.ex
  - test/example/test/example_web/enumeration_parity_test.exs
  - test/example/test/example_web/live/confirmation_live_test.exs
  - test/example/test/example_web/live/reset_password_live_test.exs
  - test/fixtures/brand/copy-inventory/generated.tsv
  - test/fixtures/brand/copy-inventory/host.tsv
  - test/fixtures/brand/copy-inventory/library.tsv
  - test/fixtures/brand/public-surfaces.json
  - test/sigra/brand/claims_docs_test.exs
  - test/sigra/brand/copy_contract_test.exs
  - test/sigra/brand/copy_inventory_test.exs
  - test/sigra/brand/frozen_surface_test.exs
  - test/sigra/brand/legacy_profiles_test.exs
  - test/sigra/brand/regen_guard_test.exs
  - test/support/brand/copy_inventory.ex
  - test/support/brand/copy_scan.ex
  - test/support/brand/regen_guard.ex
findings:
  critical: 0
  warning: 6
  info: 2
  total: 8
  necessity: 0
status: issues_found
---

# Phase 259: Code Review Report (incremental re-review, plans 259-14..259-18)

**Reviewed:** 2026-11-15T14:30:38Z
**Depth:** standard
**Files Reviewed:** 21
**Status:** issues_found

## Summary

This pass covers what changed since the last review commit `124b84c14`: the gap-closure plans
259-14..259-18 (example-host repairs for the reset request page and the confirm page, the
reset and confirmation-resend parity rows, the named-surface rule, the generated-host todo,
README and password-reset guide alignment) and the post-review fixes (scanner blind spots,
RegenGuard, coverage headers, per-unit claim sweep).

Verification performed, not assumed:

- `mix test test/sigra/brand test/sigra/templates/installer_drift_test.exs`: 360 tests, 0 failures.
- `test/example`: `enumeration_parity_test.exs`, `confirmation_live_test.exs`,
  `reset_password_live_test.exs` with `--include example_app`: 48 tests, 0 failures.
- Forced recompile of the root project and the example app: no new warnings (the only warning is
  the pre-existing `/dev/mailbox` route warning).
- Privacy: no home path, personal email or personal name in any reviewed file or fixture, and none
  in the added lines of the whole `124b84c14..HEAD` diff (the only `/Users/` strings are the
  planted-control literal `/Users/someone/y` inside phase planning text).
- The example-host code changes are correct: `session_user/1` is nil-safe, the resend target comes
  from the session and never from the payload, `/users/confirm` and `/users/confirm/:token` do not
  collide in the router, and the reset view now passes the binary email the context requires.
- Working tree left clean (probes ran from the scratchpad directory only).

No finding reaches BLOCKER. The example-host runtime changes are sound. The defects are in what
the harness and the docs claim relative to what they prove, and in scanner scope. Three were
proven by running a probe against the real code (the example login page renders no flash; the
scanner is blind to `<>`-joined literals; the claim recogniser misses common wordings).

## Warnings

### WR-01: The password-reset guide still teaches the call its own new sentence says is wrong

**File:** `guides/flows/password-reset.md:20-35` and `:142`
**Issue:** Plan 259-18 added one sentence (line 35) saying the generated
`deliver_user_reset_password_instructions/2` takes a binary email and "pass the submitted email
rather than a looked-up user". The code block directly above it (lines 20-26) still shows
`if user = Accounts.get_user_by_email(email) do ... deliver_user_reset_password_instructions(user, ...)`,
and the Testing snippet at line 142 still calls `deliver_user_reset_password_instructions(user, ...)`.
A reader who copies either snippet reproduces the defect that the phase's own todo records as
`severity: major` (a `FunctionClauseError` for a registered address and a normal redirect for an
unknown one, which is itself an account-existence signal). The sentence tells the reader to
disregard the example it follows. No test looks at code samples (the claims sweep only judges
enumeration wording), so nothing keeps the sample and the correction consistent. The example host
was repaired in this phase (`reset_password_live.ex:168-176`), so the guide now contradicts the one
implementation Sigra's own tests exercise.
**Fix:** Correct both snippets to the shape the example host now uses and drop the `if user =`
precheck:

```elixir
def handle_event("send_instructions", %{"user" => %{"email" => email}}, socket) do
  _ = Accounts.deliver_user_reset_password_instructions(email, &url(~p"/users/reset-password/#{&1}"))
  {:noreply, socket |> put_flash(:info, "If your email is in our system, you will receive reset instructions shortly.") |> redirect(to: ~p"/users/log_in")}
end
```

and in the Testing block call `Accounts.deliver_user_reset_password_instructions(user.email, &"/reset/#{&1}")`.
Add a small claims-test assertion that no guide passes a bare `user` to that function.

### WR-02: "Show the same message" overstates a harness that compares the flash map, not what a visitor sees

**File:** `README.md:177` (extends the existing wording to password-reset requests); same premise in `test/fixtures/brand/public-surfaces.json` notes
**Issue:** The README says sign-in, magic-link and password-reset requests are tested "to show the
same message for an existing and an unknown address". Probed in the example host: after the reset
request redirect, and after a failed sign-in, the followed `/users/log_in` page body does NOT contain
the flash text (`"If your email is in our system"` and `"Invalid email or password"` both absent;
the Tasklane login template and root layout never render a flash group). So the example application
shows no message at all to either visitor. What the tests prove is that the same flash is stored
in the session for both requests and that the followed page is byte-identical after normalising CSRF
tokens, request ids and the echoed email. Because the page carries no flash, the `body` dimension
adds nothing about the message. The guide's scope paragraph ("same response status, redirect, flash
and page") is accurate; the README and the claims register ("shows one message") are looser than
that and are the text that Phase 263 is allowed to restate.
**Fix:** Reword to what is compared, for example "...are tested, in Sigra's example application, to
set the same flash message and redirect to the same page for an existing and an unknown address at a
single attempt." Or make the claim true by rendering the flash on the example login page and asserting
the rendered text in the parity probes.

### WR-03: A parity row's compared dimensions are not pinned, so "same message" can lose its only evidence silently

**File:** `test/example/test/example_web/enumeration_parity_test.exs:477-510` (non-vacuity rule), `:835-844` (`run_all/2` compares only `dimensions(row)`); `test/fixtures/brand/public-surfaces.json` (`compare` lists)
**Issue:** The non-vacuity rule only requires that a parity row lists at least one of `flash` or `body`
(`Enum.any?(listed, &(&1 in @content_dimensions))`). The flash text is asserted against
`expected_parity_flash/1` for both probes, but that assertion runs whether or not the row's `compare`
lists `"flash"`. `run_all/2` and the "leak" controls compare only the listed dimensions. Since WR-02 shows
the `body` never contains the message, a registry edit that changes a row to `"compare": ["body"]` (or
`["status", "redirect", "body"]`) keeps every test green: the non-vacuity rule is satisfied by `body`,
the flash assertion still passes, and the leak control still goes red because the leak is appended to
`body` too. Yet the README, the guide and the claims register keep saying the rows prove the same
flash. Nothing ties the published dimension list ("status, redirect, flash and page") to the registry.
This is the same class of gap as the earlier WR-05 (fixture editable without a tripwire), applied to
the rows that back the public claims.
**Fix:** Pin the required dimensions per named parity row in the test and assert them against the registry:

```elixir
@required_dimensions %{
  "password-signin" => ~w(status redirect flash body),
  "magic-link-request" => ~w(status redirect flash body),
  "password-reset-request" => ~w(status redirect flash body),
  "confirmation-resend" => ~w(status redirect flash body result),
  "mfa-challenge" => ~w(status redirect flash)
}

test "every named parity row compares at least the dimensions the docs claim" do
  for row <- surfaces(), required = @required_dimensions[row["id"]] do
    assert required -- row["compare"] == [], "#{row["id"]} dropped #{inspect(required -- row["compare"])}"
  end
end
```

### WR-04: A banned phrase split across `<>`-joined string literals escapes the copy scanner

**File:** `test/support/brand/copy_scan.ex:746-761` (`code/3` string clause and `literal/3`)
**Issue:** The previous review's WR-01 closed the line-break escape, but the same escape remains for
string concatenation. Every literal is judged on its own, so a long message built with `<>` is invisible.
Probed against the real scanner (scope `:generated`):

```
put_flash(:info, "Please log " <> "in to continue")          -> []
put_flash(:info,\n  "Please log " <>\n    "in to continue")   -> []
put_flash(:info, "Please log in to continue")                 -> one hit
```

`mix format` never breaks inside a string, so long copy is routinely written exactly this way. No scanned
file contains such a chain today (`git grep` for `"…" <> "…"` over `priv/templates` and `lib/sigra/admin`
is empty), so no hit is masked now. It is the shape Phases 262-263 are most likely to introduce when they
rewrite sentences, and the contract exists to stop those phases regressing.
**Fix:** In `code/3`, after reading a string literal, look ahead for `\s*<>\s*"` and fold the chained
literals into one segment before `copy_literal?/1` and `line_hits/4`:

```elixir
defp code(<<"\"", rest::binary>>, ctx, acc) do
  {raw, rest} = take_string(rest)
  {raw, rest} = join_concatenated(raw, rest)   # consumes `<> "..."` chains
  code(rest, ctx, literal(raw, ctx, acc))
end
```

Add a planted control for both the same-line and the wrapped form.

### WR-05: Generator template directories `sigra.gen.oauth` and `sigra.upgrade` are outside every scope and inventory lane, and they ship banned phrases

**File:** `test/support/brand/copy_scan.ex:83` (`@templates_dir "priv/templates/sigra.install"`), `:225-227` (`files_for(:generated)`); `test/support/brand/copy_inventory.ex:52` (`@templates_dir`)
**Issue:** The `:generated` copy scope and the `generated.tsv` lane read only `priv/templates/sigra.install/**`.
`priv/templates/` also holds `sigra.gen.oauth/` (12 files) and `sigra.upgrade/` (3 files). Both ship in the Hex
package (`mix.exs` `files:` includes `priv`) and `mix sigra.gen.oauth` writes the former into adopter apps.
They contain exactly the phrases the contract bans in generated copy:
`sigra.gen.oauth/oauth_controller.ex:96` ("An account with this email exists. Log in to link your ... account."),
`sigra.gen.oauth/oauth_settings_live.ex:86` and `oauth_settings.html.heex:34` ("You'll still be able to log in with:").
Because the baseline is the worklist Phases 262-263 use ("legacy wording such as 'Log in' in generated flashes
that Phases 262-263 rewrite"), these instances are not on it, and the contract cannot go red if they are
reintroduced or left behind. The scope name `generated` and requirement BCOPY-02 ("generated templates")
read as covering all generated output; the exclusion is stated in code but not tracked in the deferred
findings todo, which lists only JS, attribute values and helper literals.
**Fix:** Either add the two directories to `files_for(:generated)` and the inventory glob (one baseline
initialisation and one inventory regeneration, in a reviewed commit), or name the exclusion in the `:generated`
moduledoc and in `2026-11-14-brand-harness-review-deferred-findings.md` so Phase 262 includes the oauth templates
in its manual sweep.

### WR-06: The unbounded-claim recogniser misses ordinary wordings, so the sweep is narrower than its title

**File:** `test/sigra/brand/claims_docs_test.exs:137-164` (families A, B, C), `:527-545` (the sweep test)
**Issue:** The sweep is titled "no claim unit makes an unqualified enumeration claim" and the moduledoc says it
"flags any claim unit ... that makes an unbounded claim". It flags only what the three regex families match.
Probed with the exact regexes from the test, each of these returns not-flagged:

```
"Sigra blocks enumeration of accounts."         "It prevents username enumeration."
"Sigra stops user enumeration."                 "It prevents account-enumeration attacks."
"Sigra mitigates enumeration attacks."          "It protects from enumeration."
"The flow is enumeration-proof."                "It defends against enumeration."
"The flow is enumeration-free."                 "The response does not reveal which emails are registered."
```

All current docs pass, so nothing is hidden today. The gate exists for the Phase 263 copy rewrite, which will
produce new sentences, and "prevents username enumeration", "enumeration-proof" and "does not reveal which ..."
are direct, likely phrasings. Paraphrase space cannot be closed by adding regexes one at a time.
**Fix:** Invert the rule: any claim unit that mentions `enumerat\w*` and carries none of the qualifier phrases is
flagged, with an explicit allow pattern for threat descriptions that the existing "does not flag threat
descriptions" test already names ("a common enumeration vector"). Keep families B and C for the non-"enumerat"
wordings, and add the nine strings above as planted controls.

## Info

### IN-01: README says "Each flow guide on HexDocs states its own scope"; only three of eight do

**File:** `README.md:177`
**Issue:** `guides/flows/` has eight guides; only `registration.md`, `login-and-logout.md` and `password-reset.md`
carry a `**Scope of this claim:**` paragraph (`grep -c` shows 0 in `mfa.md`, `oauth.md`, `api-authentication.md`,
`account-lifecycle.md`, `audit-logging.md`). `claims_docs_test.exs` checks only those three, so the README sentence
is untested and wrong as written. Passkey sign-in, which the same row lists as not covered, has no scope statement
in any guide.
**Fix:** Reword to "The registration, sign-in and password-reset guides each state their own scope", or add scope
statements to the remaining guides and extend `@flow_guides`.

### IN-02: The scanner is narrower than the inventory in three small ways (entities, single lowercase words, visible attributes)

**File:** `test/support/brand/copy_scan.ex:766-769` (`copy_literal?/1`), `:87` (`@copy_attrs`), `:1082` (`attr_literal/3`); `test/support/brand/copy_inventory.ex:358-362`
**Issue:** Probed, all fail open and none hides a hit today (no scanned source uses them):

1. HTML entities are not decoded: `<p>Please log&nbsp;in</p>` yields no hit.
2. A lone lowercase word is never copy: `put_flash(:info, "login")` yields no hit, while
   `CopyInventory.visit/2` documents "A literal passed straight to put_flash is copy even when it is one word",
   so the two extractors disagree about the same literal.
3. `@copy_attrs` omits `data-confirm`, `phx-disable-with`, `aria-description` and `value`, all visible text.
   There are 26 real uses across `priv/templates` and `lib/sigra/admin`, for example `data-confirm="...You will be logged out."`
   (`sigra.install/core/session_live.ex:92`) and `phx-disable-with="Creating account..."`.
   The moduledoc lists the six covered attributes honestly and 259-08 records the gap, but the deferred
   findings todo only tracks it for the inventory, not for the banned-term scan.
**Fix:** Decode `&nbsp;`/`&#160;` before matching; treat a literal passed straight to `put_flash`/`dgettext` as
copy in `CopyScan` too; add `data-confirm`, `phx-disable-with` and `aria-description` to `@copy_attrs`
(one reviewed baseline refresh), or record the decision in the deferred todo.

---

_Reviewed: 2026-11-15T14:30:38Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
