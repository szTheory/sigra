---
phase: 239-priv-templates-sweep-one-batched-re-bless
reviewed: 2026-09-17T00:00:00Z
depth: standard
files_reviewed: 81
files_reviewed_list:
  - lib/sigra/install/features/core.ex
  - priv/templates/sigra.gen.oauth/oauth_settings_live.ex
  - priv/templates/sigra.install/admin/admin_hooks.js
  - priv/templates/sigra.install/core/api_token_created_email.ex
  - priv/templates/sigra.install/core/audit_event.ex
  - priv/templates/sigra.install/core/auth.ex
  - priv/templates/sigra.install/core/auth_fixtures.ex
  - priv/templates/sigra.install/core/confirmation_live.ex
  - priv/templates/sigra.install/core/emails.ex
  - priv/templates/sigra.install/core/error_handler.ex
  - priv/templates/sigra.install/core/login_html.ex
  - priv/templates/sigra.install/core/mfa_challenge_controller.ex
  - priv/templates/sigra.install/core/mfa_challenge_html.ex
  - priv/templates/sigra.install/core/mfa_challenge_live.ex
  - priv/templates/sigra.install/core/mfa_settings_html.ex
  - priv/templates/sigra.install/core/mfa_settings_live.ex
  - priv/templates/sigra.install/core/migration.exs
  - priv/templates/sigra.install/core/registration_live.ex
  - priv/templates/sigra.install/core/reset_password_controller.ex
  - priv/templates/sigra.install/core/reset_password_html.ex
  - priv/templates/sigra.install/core/reset_password_live.ex
  - priv/templates/sigra.install/core/scope.ex
  - priv/templates/sigra.install/core/settings_live.ex
  - priv/templates/sigra.install/core/sigra_auth.css
  - priv/templates/sigra.install/core/sudo_controller.ex
  - priv/templates/sigra.install/core/sudo_html.ex
  - priv/templates/sigra.install/core/token_controller.ex
  - priv/templates/sigra.install/core/user.ex
  - priv/templates/sigra.install/core/user_auth.ex
  - priv/templates/sigra.install/core/user_token.ex
  - priv/templates/sigra.install/organizations/components/org_switcher.ex
  - priv/templates/sigra.install/organizations/controllers/organization_switch_controller.ex
  - priv/templates/sigra.install/organizations/live/invitation_accept_live.ex
  - priv/templates/sigra.install/organizations/live/organization_members_live.ex
  - priv/templates/sigra.install/organizations/live/organization_settings_live.ex
  - priv/templates/sigra.install/organizations/live/organizations_live/index.ex
  - priv/templates/sigra.install/organizations/live/organizations_live/new.ex
  - priv/templates/sigra.install/organizations/migration.exs
  - priv/templates/sigra.install/organizations/organization.ex
  - priv/templates/sigra.install/organizations/organization_invitation.ex
  - priv/templates/sigra.install/organizations/organization_invitation_email.ex
  - priv/templates/sigra.install/organizations/organizations.ex
  - priv/templates/sigra.install/organizations/router_injection.ex
  - priv/templates/sigra.install/organizations/user_auth_on_mount_assign_user_organizations.ex
  - priv/templates/sigra.upgrade/alter_add_owner_user_id.exs
  - priv/templates/sigra.upgrade/alter_add_personal.exs
  - priv/templates/sigra.upgrade/data_migration.exs
  - test/example/assets/js/admin_hooks.js
  - test/example/lib/example/accounts.ex
  - test/example/lib/example/accounts/audit_event.ex
  - test/example/lib/example/accounts/emails.ex
  - test/example/lib/example/accounts/organization.ex
  - test/example/lib/example/accounts/scope.ex
  - test/example/lib/example/accounts/user.ex
  - test/example/lib/example/accounts/user_token.ex
  - test/example/lib/example/organizations.ex
  - test/example/lib/example_web/components/org_switcher.ex
  - test/example/lib/example_web/controllers/auth/sudo_controller.ex
  - test/example/lib/example_web/controllers/auth/sudo_html.ex
  - test/example/lib/example_web/controllers/organization_switch_controller.ex
  - test/example/lib/example_web/controllers/reset_password_controller.ex
  - test/example/lib/example_web/controllers/reset_password_html.ex
  - test/example/lib/example_web/controllers/session_html.ex
  - test/example/lib/example_web/live/confirmation_live.ex
  - test/example/lib/example_web/live/invitation_accept_live.ex
  - test/example/lib/example_web/live/mfa_challenge_live.ex
  - test/example/lib/example_web/live/mfa_settings_live.ex
  - test/example/lib/example_web/live/organization_members_live.ex
  - test/example/lib/example_web/live/organization_settings_live.ex
  - test/example/lib/example_web/live/organizations_live/index.ex
  - test/example/lib/example_web/live/organizations_live/new.ex
  - test/example/lib/example_web/live/registration_live.ex
  - test/example/lib/example_web/live/reset_password_live.ex
  - test/example/lib/example_web/user_auth.ex
  - test/example/priv/repo/migrations/20260410125242_create_sigra_auth_tables.exs
  - test/example/priv/static/assets/sigra_auth.css
  - test/example/test/support/fixtures/auth_fixtures.ex
  - test/fixtures/install_golden/tree/** (re-blessed golden fixture, 35 files)
  - test/example/lib/example_web/router.ex (cross-checked, not edited by phase)
  - test/example/lib/example_web/components/layouts.ex (cross-checked, not edited by phase)
  - lib/sigra/install/features/organizations.ex (cross-checked injection builders)
findings:
  critical: 1
  warning: 7
  info: 5
  total: 13
status: issues_found
---

# Phase 239: Code Review Report

**Reviewed:** 2026-09-17
**Depth:** standard
**Files Reviewed:** 81 (78 phase-edited + 3 cross-checked)
**Status:** issues_found

## Summary

Reviewed the full `git diff 4272a274..HEAD` for `lib/sigra`, `priv/templates`, `test/example`,
and the re-blessed `test/fixtures/install_golden` tree.

**Class 1 (escaped semantic change) — CLEAN.** I mechanically extracted every `+`/`-` line in the
combined diff and filtered out lines beginning with a comment token (`#`, `//`, `/*`, `*`,
`<%#`, `<%%= #`, `{#`). Every surviving line is `@doc`/`@moduledoc` prose, HEEx-comment removal,
or a trailing CSS `/* … */` comment on an otherwise-identical declaration. No executable code,
no string literal, no EEx binding, no CSS property/value, and no heredoc-injected route or plug
was altered. The `settings_live.ex` / `mfa_*_html.ex` / `mfa_settings_live.ex` /
`organization_settings_live.ex` deletions remove inert `<%%= # … %>` / `{# … }` comment
expressions only; their surrounding markup is untouched.

**Capitalization side effect (class 6) — CLEAN.** `lib/sigra/install/features/core.ex` contains
no bare `Organization` token, and the invariant asserted at
`test/sigra/install/features/core_test.exs:309` is actually `refute code =~ "Features.Organizations"`
(plus `Features.Passkeys` / `Features.Admin`), none of which the reword could reintroduce.

**Primary goal — substantially met, with one real leak.** Positive-controlled greps below show
`priv/templates/` is clean against the frozen union regex, and the entire re-blessed
`test/fixtures/install_golden/tree` (the literal bytes an adopter generates) is clean too. But the
frozen regex is narrower than the stated goal, and one adopter-shipped file still carries several
paragraphs of Sigra CI/plan bookkeeping that the regex simply cannot match (CR-01).

Remaining findings are concentrated in two places: the mirror sweep never reached
`test/example/lib/example_web/router.ex` and `…/components/layouts.ex` (WR-01/WR-02), and a handful
of rewrites left sentences whose subject or antecedent went out with the token (WR-03 … WR-07).

### Grep evidence (with positive control)

```
$ grep -rnE '<frozen union regex>' priv/templates
(none)
$ grep -rnE '<frozen union regex>' test/fixtures/install_golden
(none)
```

Positive control proving the grep is live and the regex matches real content:

```
$ grep -rc 'defmodule' priv/templates | head
…/auth.ex:1  …/user.ex:1  …/scope.ex:1  (non-zero everywhere)
$ grep -rc 'defmodule' test/fixtures/install_golden/tree/lib | head -3
…/auth_error_handler.ex:1
…/router.ex:1
…/user_auth.ex:2
$ grep -rnE '<frozen union regex>' test/example/lib test/example/assets test/example/priv test/example/mix.exs
test/example/lib/example_web/router.ex:36,77,103,209,226
test/example/lib/example_web/components/layouts.ex:9,52
test/example/lib/example/demo/seeds.ex (many)
test/example/lib/example/sigra_admin_policy.ex:5
test/example/lib/example_web/live/admin/design_gallery_live.ex (many)
…
```

The `test/example` hits are the same regex run over a tree where it *does* fire — so the zero
result on `priv/templates` is a real negative, not a dead grep.

## Structural Findings (fallow)

No `<structural_findings>` block was supplied with this review request.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: Adopter-shipped CSS still contains Sigra CI-run IDs, plan IDs, and "round N" iteration bookkeeping

**File:** `priv/templates/sigra.install/core/sigra_auth.css:513-533` and `:689-698`
**Issue:** This file is copied verbatim into every adopter app (`priv/static/assets/sigra_auth.css`),
so it is squarely inside the phase's stated goal: *"Nothing an adopter generates or downloads
contains Sigra's internal planning bookkeeping."* After the sweep it still reads:

```css
/* Live multi-run CI evidence showed H2/P sharing one
   identical right edge (321.4375px) as the last remaining offenders after rounds
   1-2. …
   … so an
   initial round-3 draft that used `overflow-wrap: break-word` here silently
   … observed on live CI
   runs 30518012012 and 30518015684 immediately after the round-3 commit, never
   before it). … */
```

and at line 696:

```css
   automatic minimum width (min-content) even though 231-02's min-width: 0 already
   reached the leaf input/button.
```

`rounds 1-2`, `round-3 draft`, `the round-3 commit`, GitHub Actions run IDs `30518012012` /
`30518015684`, and the plan identifier `231-02` are all Sigra-internal planning/CI bookkeeping with
zero meaning to an adopter. The sweep removed the adjacent `231-GAP-GATE02-SUMMARY.md` and `GATE-02`
tokens — which the frozen union regex *does* match — and left the surrounding bookkeeping prose that
it does not. This is simultaneously a content miss and a **gate-coverage gap**: the phase's own
verification grep is structurally incapable of catching plan IDs of the form `NNN-NN`, bare
`round N`, or CI run IDs, so a green grep does not prove the stated goal.

Note this is *not* the already-dispositioned `sigra_auth.css:698` line-break awkwardness; that
disposition covers the enforced line wrapping, not residual bookkeeping content.

**Fix:** Rewrite both comment blocks to state the mechanism without Sigra's iteration history —
e.g.:

```css
  /* H2 and P shared one identical right edge with the surrounding stack.
     Neither had min-width: 0, so as grid items of a single-implicit-column
     .sigra-auth-stack both stretch to the shared column track, which is floored
     by whichever sibling's min-content is largest (here the <p> copy's longest
     unbreakable word). min-width: 0 lets each item shrink.

     Use `overflow-wrap: anywhere`, NOT `break-word`: per the CSS Text spec only
     `anywhere` participates in a flex/grid item's automatic-minimum-size
     calculation. `.sigra-auth p` (0,1,1) outranks `.sigra-auth__product` (0,1,0)
     and appears later, so `break-word` here would silently override the
     wordmark's `anywhere` and reintroduce an un-contained min-content floor. */
```

and at :696 replace `231-02's min-width: 0` with `the earlier leaf-level min-width: 0`.

Then widen the sweep's grep to also reject `\b[0-9]{3}-[0-9]{2}\b`, `\bround[- ][0-9]\b`, and bare
10-digit CI run IDs before re-blessing.

## Warnings

### WR-01: `test/example` router mirror was never swept — 5 divergent sites vs the golden fixture

**File:** `test/example/lib/example_web/router.ex:36, 77, 103, 209, 226`
**Issue:** The router sweep landed late, in `lib/sigra/install/features/core.ex` (heredoc) and
`priv/templates/sigra.install/organizations/router_injection.ex`, in commits `6fa3ead2` / `e4e03980`
— after the `test/example` mirror plan (`e69f4d9b`, plan 03) had already completed. The mirror was
never re-run, so the example app's router still carries every token that was removed from the
generator. Side-by-side:

| golden fixture (swept) | `test/example` (not swept) |
|---|---|
| `# MFA challenge (accessible with mfa_pending sessions)` | `# MFA challenge (accessible with mfa_pending sessions, D-24)` |
| `# Single unscoped InvitationAcceptLive at` | `# Phase 17 D-06: single unscoped InvitationAcceptLive at` |
| `# Sigra organizations` | `# Sigra organizations (Phase 16)` |
| `# "switch" as a slug.` | `# "switch" as a slug (D-06).` |
| *(controller comment swept)* | `# Phase 10.1.1 B9: login page is a plain controller + HEEx render,` |

This is exactly the divergence class the phase's own SURF-03 mirror requirement exists to prevent,
and it is the highest-signal instance because `router.ex` is generated content whose golden fixture
now disagrees with the demo app.

**Fix:** Apply the same five edits to `test/example/lib/example_web/router.ex`, copying the swept
wording from `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/router.ex:86, 137,
151, 169` (and the `session_html`/login-controller comment from `core.ex`). Re-run the residual grep
over `test/example/lib` afterward.

### WR-02: `layouts.ex` mirror missed, including a user-visible `attr … doc:` string

**File:** `test/example/lib/example_web/components/layouts.ex:9, 52`
**Issue:**

```elixir
9:  # Phase 16 D-27: organization switcher function component.
52:    doc: "list of {organization, role} tuples for the current user (Phase 16 D-26)"
```

Line 52 is **not a comment** — it is the `:doc` option on a `Phoenix.Component` `attr/3`, which is
rendered into ExDoc output and surfaced by LSP hover. Wherever this component wiring is reproduced
in an adopter app (it is described in the Organizations feature's `post_instructions`), the token
travels with it. Both sites were swept nowhere.

**Fix:**

```elixir
  # Organization switcher function component.
…
    doc: "list of {organization, role} tuples for the current user"
```

### WR-03: Broken doc pointer — "Look for the `this section` HEEx comment"

**File:** `priv/templates/sigra.install/organizations/live/organization_members_live.ex:31-32`
and `test/example/lib/example_web/live/organization_members_live.ex:29-30`
**Issue:** The rewrite stripped the token *out of a backticked code reference*, leaving:

```
  action above the table. Look for the `this section` HEEx
  comment to find the fill-in point.
```

`` `this section` `` is not a string that appears anywhere in either file — the instruction is now
unfollowable. (The original pointer `` `Phase 17 fills this section` `` was already stale at base:
no such HEEx comment exists in either tree, confirmed by
`git show 4272a274:… | grep "fills this section"` matching only the moduledoc itself. The sweep
turned a stale pointer into an ungrammatical one.)

**Fix:** Delete the pointer sentence, and correct the now-false claim two paragraphs above that the
seam is "an empty-state card with a HEEx comment marker":

```
  The `pending-invitations-section` `<section>` below the members table renders
  a populated `@streams.pending_invitations` table, or an empty-state card when
  `@pending_count == 0`.
```

### WR-04: Sentence subject lost — "This section will replace the card body"

**File:** `priv/templates/sigra.install/organizations/live/organization_members_live.ex:29-31`
**Issue:** The original read *"Phase 17 will replace the card body …"*. Removing the token left the
section as its own grammatical subject — the section cannot replace its own card body. The claim is
also factually wrong now: the surrounding code already implements the invite/revoke flows and
`@pending_count`, so nothing is pending. Compounding it, this is a **template/example divergence**:

- template: `currently renders an empty-state card. This section will replace the card body`
- example: `currently renders an empty-state card. This section will later gain`

Two different rewrites of the same swept sentence in the two trees that are supposed to correspond.

**Fix:** Converge both trees on a present-tense description of what the code actually does (see
WR-03 fix), and drop the forward-looking clause entirely.

### WR-05: Branch B description is subjectless with a dangling "until then"

**File:** `priv/templates/sigra.install/organizations/live/organizations_live/index.ex:10-11`
and `test/example/lib/example_web/live/organizations_live/index.ex:10-11`
**Issue:** Original: `Branch B: pending invitations list (Phase 17 wires Accept; Phase 16 renders
Accept disabled)`. Both subjects were removed, yielding:

```
    * `([], [_|_])` — Branch B: pending invitations list (wires Accept;
      renders Accept disabled until then)
```

"wires Accept" now has no actor, and "until then" refers to a point in time that no longer appears
in the sentence. Reads as self-contradictory: it both wires and disables Accept.

**Fix:**

```
    * `([], [_|_])` — Branch B: pending invitations list with an Accept action
      for each invitation
```

(or, if the example's Accept really is still disabled, say so unconditionally).

### WR-06: Library behavior mis-attributed to the schema module

**File:** `priv/templates/sigra.install/organizations/organization_invitation.ex:13-15`
**Issue:** The original read *"Phase 17 implements the full invitation flow (generation, email
delivery, accept/reject)."* Dropping the subject leaves a sentence whose implied subject is the
preceding one — `The hashed_token field` / this schema module:

```
  The `hashed_token` field stores the HMAC-signed invitation token.
  Implements the full invitation flow (generation, email
  delivery, accept/reject).
```

An adopter reading this moduledoc is told the generated schema owns invitation generation and
delivery. It does not — `Sigra.Organizations` / `Sigra.Token.generate_invite_envelope/2` do.
The same pattern recurs at `:47-50` (`managed by the library's invitation flow logic.` is fine
there, because the subject survived).

**Fix:**

```
  The `hashed_token` field stores the HMAC-signed invitation token. The
  library implements the full invitation flow (generation, email delivery,
  accept/reject); this schema only persists the state.
```

### WR-07: `mfa_settings_live.ex` — template and example got different rewrites, template's is degraded

**File:** `priv/templates/sigra.install/core/mfa_settings_live.ex:606` vs
`test/example/lib/example_web/live/mfa_settings_live.ex:631`
**Issue:**

```elixir
# template
    # Auto-submit when 6 digits entered:
    # call the confirm path directly instead of dispatching via

# example
    # Auto-submit when 6 digits entered. Calls the confirm path
    # directly instead of dispatching via
```

The template's trailing bare colon is the residue of the removed `(D-36). 10.1 IN-06 follow-up:`
clause; the example's version is the clean rewrite. Same swept line, two different results —
divergence, with the adopter-facing tree holding the worse text.

**Fix:** Adopt the example's wording in the template:
`# Auto-submit when 6 digits entered. Calls the confirm path`.

## Info

### IN-01: Awkward `Generated by` wrap in the template only

**File:** `priv/templates/sigra.install/organizations/live/organization_members_live.ex:8-9`
**Issue:** Template wraps as `Generated by\n  \`mix sigra.install --live\`; …`; the example collapsed
it onto one line. Cosmetic divergence introduced by the same edit.
**Fix:** Join the template line unless the golden fixture pins the wrap.

### IN-02: `only.` reads as a stray adverb

**File:** `priv/templates/.../organization_members_live.ex:23`,
`test/example/.../organization_members_live.ex:22`
**Issue:** `Pagination is \`LIMIT 100\` + "Load more" via \`stream_insert(..., at: -1)\`
only. Flop / sortable columns are a v1.2 concern.` — `only.` was dropped in to replace `(D-22).`
and attaches to nothing.
**Fix:** Delete `only.`; the following sentence already carries the "nothing fancier" meaning.

### IN-03: Security rationale slightly weakened in two places

**Files:** `priv/templates/.../organizations/organization_invitation_email.ex:14`;
`priv/templates/.../organizations/live/invitation_accept_live.ex:18` (and example mirror)
**Issue:** (a) `(phishing defense — spoofing)` now parses as though spoofing *is* the defense; the
original `T-17-10 spoofing` made the threat explicit. (b) The `:mismatch` structural invariant lost
`and enforced by plan-checker grep` — a future editor no longer learns that "zero accept controls
in the `:mismatch` branch" is machine-checked rather than merely conventional. The controls
themselves are intact in both files; only the rationale thinned.
**Fix:** (a) `(phishing defense — prevents inviter/org spoofing)`. (b) Either restore a
tool-agnostic note (`this absence is asserted by a test — do not add accept controls here`) or add
that assertion to the example's test suite so the claim stays true.

### IN-04: Pre-existing `LiveView's / LiveView` duplication left in place next to a swept line

**File:** `priv/templates/sigra.install/core/login_html.ex:5-6` and
`test/example/lib/example_web/controllers/session_html.ex:5-6`
**Issue:** `… installs. LiveView's / LiveView form submission attributes were swallowing …`. Both
lines are diff *context*, so the duplication is pre-existing, not introduced by this phase — but it
sits one line below a swept line in an adopter-facing moduledoc.
**Fix:** `… installs. LiveView's form-submission attributes were swallowing …`.

### IN-05: Residual tokens remain in example-only files (out of this phase's declared scope)

**Files:** `test/example/lib/example/demo/seeds.ex` (many), `test/example/lib/example/sigra_admin_policy.ex:5`,
`test/example/lib/example_web/live/admin/design_gallery_live.ex` (many), plus most of
`test/example/test/**`
**Issue:** These carry `D-NN`, `Phase NN`, `IN-NN`, `SC-N`, `FIXT-02` etc. They have no
`priv/templates` counterpart (demo seeds, admin design gallery, example tests), so they are not
adopter-generated content and are correctly outside SURF-01/SURF-03. Recording them so a future
sweep does not mistake them for a regression, and so the scope boundary is explicit rather than
assumed.
**Fix:** None required. If a future phase widens the goal to "the public repo carries no
bookkeeping", file these as that phase's inventory.

---

_Reviewed: 2026-09-17_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
