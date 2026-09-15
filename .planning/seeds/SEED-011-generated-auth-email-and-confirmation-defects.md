---
id: SEED-011
created: 2026-09-15
status: planted
disposition: fast-follow after v1.48
title: Generated auth email + confirmation flow defect cluster (7 findings)
area: installer templates / generated auth / transactional email
source: downstream adopter field report, 2026-09-15 (relayed); 3 of 7 verified locally at 160de093
severity: mixed (1 blocker, 1 high, 3 medium, 2 low)
related:
  - .planning/todos/pending/2026-09-15-generated-confirm-routes-unreachable-both-session-states.md
  - .planning/todos/pending/2026-07-28-w3-generated-auth-runtime-coverage-is-login-only.md
  - .planning/todos/pending/2026-06-22-white-label-auth-email-theming.md
---

# Generated auth email + confirmation defect cluster

A production adopter reported seven defects in the generated auth email and confirmation
flow. **All seven are in the generator templates, not in the adopter's copies of them** —
any host running `mix sigra.install --live` today gets every one. The adopter fixed all
seven locally and is not blocked; no action is owed to them.

I verified **A, B and E** myself against HEAD `160de093`. C, D, F and G are recorded as
reported and still need confirmation.

## Disposition — FAST FOLLOW (decided 2026-09-15)

This cluster was **deliberately not pulled into v1.48 (CLEAN-BASELINE)**. v1.48 is a
flake/green-baseline milestone and restructuring it mid-flight was rejected. Instead:

> **Schedule A (and D with it) in the FIRST phase batch of the next milestone.**
> This is a committed fast-follow, not a generic "someday" trigger. A is shipping-broken
> for every adopter running `mix sigra.install --live` right now, and each day it sits is
> another day of confirmation emails that cannot confirm.

Do not let this seed fall through to the trigger conditions below — they are the
*fallback* for the remaining findings (C, E, F, G), not for A and D.

## Trigger conditions (for the REMAINDER — C, E, F, G)

Plan a phase when any of these hold:

- the next milestone touches installer templates, generated auth, or transactional email
- the W-3 generated-auth coverage gap is picked up (two of these findings want generated
  tests, and W-3 is where they belong)
- the Mailglass ownership question below is settled (gates C and G)

## The findings

| Ref | Sev | One line | Verified |
|-----|-----|----------|----------|
| A | blocker | Confirm route cannot confirm in either session state | ✓ at 160de093 |
| B | high | A code copied from the email cannot be pasted into the form | ✓ at 160de093 |
| C | medium | Generated emails render thousands of px wide | reported |
| D | medium | `sigra_auth_page` renders no flash region — every `put_flash/3` is invisible | reported |
| E | low | `sigra-auth-copy--error` does not exist; modifier is `--danger` | ✗ not reproduced |
| F | medium | A spent confirmation link reports the *code* as invalid | reported |
| G | low | Apple Mail strips CTA anchor styling (underline + square corners) | reported |

### A — confirm route unreachable (blocker) — VERIFIED

Split out to its own todo; see `related`. Routes injected into a
`redirect_if_user_is_authenticated` scope with no `live_session`/`on_mount`, while
`confirmation_live.ex` reads `current_scope` at `:100`, `:148`, `:163`. Anonymous → 500;
signed-in → silent no-op with `confirmed_at` still `nil`.

### B — spaced code cannot be pasted (high) — VERIFIED

`priv/templates/sigra.install/core/emails.ex:21` does:

```elixir
code_display = code |> String.graphemes() |> Enum.join(" ")
```

while `:31` **already** carries `letter-spacing: 0.25em`. The CSS alone produces the
visual; the literal spaces only change what lands on the clipboard. Copying yields
`5 2 3 7 7 4`.

Then `confirmation_live.ex:44-45` carries `maxlength="6"` + `pattern="[0-9]{6}"`. The
11-character paste is truncated to `5 2 3 ` **at paste time, before `phx-change` fires** —
so no amount of server-side normalisation can ever see it, and `pattern` rejects it with
the *browser's* native message in the *browser's* locale, which need not match the page's.

Fix: drop the `Enum.join(" ")` (keep the CSS), raise/remove `maxlength`, and normalise
whitespace server-side. The same `maxlength`/`pattern` pair appears at
`mfa_challenge_live.ex:227-228` — lower severity for authenticator codes, but backup codes
are the same shape.

### C — emails render thousands of px wide (medium)

`emails.ex:39-40` and 7 more like it (8 × `word-break: break-all` in that file) emit the
URL as bare text. Clients autolink it with *their* anchor styles, which do not inherit the
paragraph's `word-break`; a table grows past its stated width for unbreakable content, so
the 600px cap is advisory. Needs an explicit anchor plus `table-layout: fixed` on the
wrapper.

### D — no flash region (medium)

`sigra_auth_page` renders no flash region, and the generated screens render it directly
rather than through the host app layout. Every `put_flash/3` in the generated LiveViews
writes to a map nothing displays — including "Invalid confirmation code", "Too many
attempts", and registration's enumeration-safe "If this email is available…". On screen
that is a submit that clears the field and says nothing, which is **indistinguishable from
A's silent failure**. That is why A was hard to name from the outside, and it is why D
should be fixed in the same phase as A rather than after it.

### E — wrong BEM modifier (low) — NOT REPRODUCED

Reported as `sigra-auth-copy--error` where the defined modifier is `--danger`. At
`160de093` the token `sigra-auth-copy--error` appears nowhere in `priv/templates/` or
`lib/` — only `--center` and `--muted` are in use. Either it is against a local copy or a
surface not swept here. **Confirm before acting.** The general trap is real regardless: a
missing CSS class has no failure mode and renders unstyled silently, and `--danger` sits
awkwardly against the `:error`/`:warning` vocabulary the flash API uses.

### F — spent link blames the code (medium)

`confirmation_live.ex:115` handles `:token_invalid` by flashing "invalid or has expired"
and falling through to the code form. But `Sigra.Auth.confirm_user/1` deletes every confirm
token on success — so a **second visit to a link that already worked** is `:token_invalid`,
not `:already_confirmed`, and the `:already_confirmed` branch at `:109` is only reachable
while the token is still live. The visitor most likely to revisit a confirmation link is
the one who already used it.

Combined with D's invisible flash, the link appears to have been ignored outright; a
visitor then pastes the code from the same email and is told *that* is invalid, and
reasonably concludes the code expired.

Fix: ask the **account**, not the token, when the token comes back unusable, and word it
"invalid or has already been used".

### G — Apple Mail strips CTA styling (low)

`emails.ex:965` styles the CTA anchor inline with `text-decoration: none` and
`border-radius: 8px`. Apple Mail overrides link styling on the `<a>` and drops **both** —
underlined text on square corners. A nested `<span>` survives. Affects every generated
transactional email.

## Two findings want generated TESTS, not just fixes

1. **The confirm route confirms from both session states** — assert on `confirmed_at`,
   **never** on the response status. A status-only assertion passes while confirming
   nothing, which is exactly A's signed-in failure mode.
2. **A spaced paste is accepted.**

Both belong with the W-3 generated-auth runtime-coverage gap rather than as standalone
tests.

## Open question — ownership boundary

B, C and G are email-*rendering* concerns that arguably belong to Mailglass rather than
Sigra. Sigra currently has no supported integration story beyond
`guides/recipes/companion-libs/mailglass.md`. Adopting Mailglass properly would mean Sigra
growing a rendering seam; not adopting it means these rendering bugs stay Sigra's to fix
in raw inline styles, one client quirk at a time.

**This is a product-direction decision, not an implementation detail** — it should be
settled before a phase is planned around C and G, because it determines whether the fix is
"patch the inline styles" or "introduce the seam". A parallel field report on the same
findings went to the Mailglass side, so both projects are aware.
