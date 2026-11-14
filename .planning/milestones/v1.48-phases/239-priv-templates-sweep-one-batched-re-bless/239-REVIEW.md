---
phase: 239-priv-templates-sweep-one-batched-re-bless
review_cycle: gap-closure (plans 239-05 … 239-08)
diff_range: aa1372cb..HEAD
reviewed: 2026-09-18T04:04:52Z
depth: standard
files_reviewed: 21
files_reviewed_list:
  - priv/templates/sigra.install/core/login_html.ex
  - priv/templates/sigra.install/core/mfa_settings_live.ex
  - priv/templates/sigra.install/core/sigra_auth.css
  - priv/templates/sigra.install/organizations/live/invitation_accept_live.ex
  - priv/templates/sigra.install/organizations/live/organization_members_live.ex
  - priv/templates/sigra.install/organizations/live/organizations_live/index.ex
  - priv/templates/sigra.install/organizations/organization_invitation.ex
  - priv/templates/sigra.install/organizations/organization_invitation_email.ex
  - test/example/lib/example_web/components/layouts.ex
  - test/example/lib/example_web/controllers/session_html.ex
  - test/example/lib/example_web/live/invitation_accept_live.ex
  - test/example/lib/example_web/live/organization_members_live.ex
  - test/example/lib/example_web/live/organizations_live/index.ex
  - test/example/lib/example_web/router.ex
  - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/organization_invitation.ex
  - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/controllers/session_html.ex
  - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/live/invitation_accept_live.ex
  - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/live/mfa_settings_live.ex
  - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/live/organization_members_live.ex
  - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/live/organizations_live/index.ex
  - test/fixtures/install_golden/tree/priv/static/assets/sigra_auth.css
findings:
  critical: 0
  warning: 4
  info: 6
  total: 10
status: issues_found
---

# Phase 239 Gap Closure: Code Review Report

**Reviewed:** 2026-09-18T04:04:52Z
**Depth:** standard
**Diff range:** `aa1372cb..HEAD` (plans **239-05 … 239-08** only)
**Files Reviewed:** 21 (non-`.planning/` source files)
**Status:** issues_found (0 Critical, 4 Warning, 6 Info)

> **This review replaces the earlier `239-REVIEW.md`,** which covered the round-1 sweep
> (plans 239-01 … 239-04). Nothing in this document re-reviews that range. The subject here
> is exclusively the gap-closure range `aa1372cb..HEAD`.

## Summary

**The load-bearing claim holds: no executable behavior changed.** I attempted to falsify it three
ways and failed:

1. **CSS declaration integrity (the highest-risk surface).** Stripping every `/* … */` comment and
   all whitespace from `priv/templates/sigra.install/core/sigra_auth.css` and from
   `test/fixtures/install_golden/tree/priv/static/assets/sigra_auth.css`, both before (`aa1372cb`)
   and at HEAD, yields **one identical md5 (`bd9f0bdf521903ef51d954d871929c2c`) for all four
   streams.** No selector, declaration, value, or rule ordering moved, and the template and the
   generated fixture are declaration-identical to each other.
2. **Elixir diff composition.** Every `+`/`-` line across the nine `.ex` files is inside a
   `@moduledoc """…"""` body, a `#` line comment, or the `doc:` string of an `attr/3` call. No
   function head, guard, pattern, pipeline, route, plug, `attr` name, or `default:` is touched.
   `mix format --check-formatted` is clean on the six changed `test/example` files.
3. **Three-tier agreement.** `MIX_ENV=test mix sigra.fixture.rebless_golden --check` returns
   `OK: fixture is up-to-date (check mode).` at HEAD, so the golden tree is byte-faithful to a
   fresh generation. Every reworded sentence is present in each tier that has a counterpart, and
   the two claimed no-counterpart dispositions are real: `test/example/lib/example/accounts/
   organization_invitation.ex:2` is `@moduledoc false`, and no `test/example` counterpart of
   `organization_invitation_email.ex` exists.

Re-running the widened V2 bookkeeping regex over all 21 files returns **0**.

**What it did not get right.** The findings below are all in the *second* category the brief names:
prose that is now factually wrong about the code it documents, bookkeeping the sweep missed inside a
file it was already editing, and one place where rationale that guarded an auth-critical routing
constraint was deleted rather than de-bookkept. Two of the four Warnings (`WR-01`, `WR-02`) sit in
the same file and directly contradict each other.

## Warnings

### WR-01: Adopter-shipped moduledoc claims a regression test that adopters never receive

**File:** `priv/templates/sigra.install/organizations/live/invitation_accept_live.ex:19-20`
(mirrored to `test/example/lib/example_web/live/invitation_accept_live.ex:19-20` and
`test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/live/invitation_accept_live.ex:19-20`)

**Issue:** Plan 239-06 appended to the security-invariant moduledoc:

```
  "by construction, not by convention" defense. That absence is asserted by a
  test, not merely conventional — do not add accept controls to this branch.
```

The test in question is `test/example/test/example_web/live/invitation_accept_live_test.exs:582`
(`T19`). It is a **Sigra-repo test** whose subject is the *template file itself*:

```elixir
Path.join([File.cwd!(), "..", "..", "priv", "templates", "sigra.install",
           "organizations", "live", "invitation_accept_live.ex"])
```

`mix sigra.install` generates **no tests at all** — the golden tree's entire `test/` directory is
three support files (`conn_case.ex`, `conn_case_helpers.ex`, `fixtures/auth_fixtures.ex`) and zero
`_test.exs`. So in the adopter's project the sentence is false twice over: no such test exists, and
the test that does exist never reads the adopter's copy — the very copy the file's own header tells
them is "host-owned, customize freely." This is worse than the `plan-checker` bookkeeping it
replaced, because it tells an adopter they have a structural regression guard on an
authorization-bypass defense (`Jetstream #907 / CVE-2026-1529`) that they do not have.

**Fix:** State the invariant without claiming the adopter owns a guard for it, e.g.:

```elixir
  "by construction, not by convention" defense — do not add accept controls to
  this branch. Sigra's own suite asserts this absence in the shipped template;
  if you customize this file, add an equivalent assertion to your test suite.
```

---

### WR-02: Sigra-internal `plan-checker` bookkeeping still ships to adopters, in a file the sweep edited

**File:** `priv/templates/sigra.install/organizations/live/invitation_accept_live.ex:326`
(mirrored at `test/example/lib/example_web/live/invitation_accept_live.ex:332` and
`test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/live/invitation_accept_live.ex:326`)

**Issue:**

```elixir
  # The plan-checker greps this function body and asserts zero matches.
```

`plan-checker` is GSD planning machinery — precisely the class of internal bookkeeping this phase
exists to strip, and it is shipped verbatim into every adopter's project. It survives because the
widened V2 regex matches plan *IDs*, not plan *vocabulary*; re-running V2 over this file returns 0
while this line sits in it. The miss is sharpened by the fact that 239-06 edited this same file 307
lines above, and its own SUMMARY states the added sentence "names no plan-checker, plan id, or
grep" — the goal was applied to the new sentence and not to the existing one 300 lines below it.

It also creates a direct contradiction with WR-01: line 19 says the invariant is enforced by *a
test*, line 326 says it is enforced by *the plan-checker*. An adopter cannot act on both.

**Fix:** Collapse to the mechanism-free statement and let WR-01's repair carry the enforcement
claim:

```elixir
  # STRUCTURAL INVARIANT (Jetstream #907 / CVE-2026-1529):
  # This function MUST NOT contain any phx-click="accept..." or
  # phx-submit="accept..." or form action targeting an accept endpoint.
  # DO NOT add an accept button here even "for convenience" — the entire
  # point of this branch is that the accept action does not exist in the
  # rendered DOM for a mismatched visitor.
```

Note the existing `DO NOT add an accept button here` lines already carry the full warning, so the
`plan-checker` line can be deleted outright with zero information loss.

---

### WR-03: Prose repair fused two sentences with no terminator, in three tiers

**File:** `priv/templates/sigra.install/organizations/live/organization_members_live.ex:23-24`
(identical at `test/example/lib/example_web/live/organization_members_live.ex:24-25` and
`test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/live/organization_members_live.ex:23-24`)

**Issue:** IN-02 deleted the stray `only.` and left the sentence unterminated:

```
    * Pagination is `LIMIT 100` + "Load more" via `stream_insert(..., at: -1)`
      Flop / sortable columns are a v1.2 concern.
```

ExDoc renders a moduledoc bullet as flowed text, so an adopter reads the single run-on string
``Pagination is `LIMIT 100` + "Load more" via `stream_insert(..., at: -1)` Flop / sortable columns
are a v1.2 concern.`` The phase's stated purpose is repairing prose the earlier sweep damaged; this
repair introduces new damage into an adopter-visible HexDoc surface and was then propagated to
`test/example` and blessed into the golden fixture, so all three tiers now carry it.

**Fix:**

```
    * Pagination is `LIMIT 100` + "Load more" via `stream_insert(..., at: -1)`.
      Flop / sortable columns are a v1.2 concern.
```

Apply to all three tiers and re-bless.

---

### WR-04: Login-route rationale deleted, leaving the constraint unguarded

**File:** `test/example/lib/example_web/router.ex:103` (was `:103-106`)

**Issue:** The four-line comment was collapsed to a single fact:

```diff
-    # Phase 10.1.1 B9: login page is a plain controller + HEEx render,
-    # NOT a LiveView. Keeping it outside the live_session ensures
-    # `Phoenix.Component.form/1` renders a plain `<form action=... method="post">`
-    # with no phx-submit interception.
+    # Login page is a plain controller, not a LiveView.
     get "/log_in", SessionController, :new
```

Only `Phase 10.1.1 B9:` was bookkeeping. The three surviving lines were the *reason the route must
stay where it is* — and `CLAUDE.md` states this as a project constraint ("Login/logout via HTTP POST
(not LiveView events)"). What remains describes the current state but no longer tells a maintainer
that moving `get "/log_in"` inside the adjacent `live_session :redirect_if_user_is_authenticated`
block (three lines below) would silently reintroduce `phx-submit` interception on the login form —
the exact defect `login_html.ex`'s own moduledoc, edited in this same range, still documents. The
comment and its neighbouring moduledoc now disagree about how much the reader needs to know.

Scope note: the authoritative wording lives at `lib/sigra/install/features/core.ex:503`, which is
outside this diff range and already collapsed; plan 239-07 mirrored that collapse into the example
(correctly, per the mirror rule). The fix therefore belongs at the `core.ex` source, with the
example and golden re-mirrored.

**Fix:** Keep the bookkeeping removal, restore the rationale:

```elixir
    # Login page is a plain controller + HEEx render, NOT a LiveView. Keeping it
    # outside the live_session ensures `Phoenix.Component.form/1` renders a plain
    # `<form action=... method="post">` with no phx-submit interception.
    get "/log_in", SessionController, :new
```

## Info

### IN-01: `## Pending invitations seam` heading is now stale

**File:** `priv/templates/sigra.install/organizations/live/organization_members_live.ex:26`
(and both mirrors)

**Issue:** 239-06 correctly rewrote the body from "will replace the card body … Look for the
`this section` HEEx comment" to present tense — the section genuinely renders
`@streams.pending_invitations` (`:60`, `:421`, `:433`) with an `@pending_count == 0` fallback
(`:426`). But the heading still calls it a *seam*, i.e. an unfilled extension point. Verified
against the body: there is no seam left.

**Fix:** Rename the heading to `## Pending invitations`.

---

### IN-02: CSS comment says `.sigra-auth__product` is "below" when it is 33 lines above

**File:** `priv/templates/sigra.install/core/sigra_auth.css:521-522` (and the golden mirror at the
same lines)

**Issue:**

```
     `.sigra-auth p`, has higher specificity (0,1,1) than the pre-existing
     `.sigra-auth__product` rule (0,1,0) below and appears later in the file, so
```

`.sigra-auth__product` is defined at `:478`; the `.sigra-auth h1, h2, h3, p` rule this comment
annotates is at `:531`. The `__product` rule is **above**, not below. The directional word is
pre-existing (it is present in the removed text too), but 239-06 rewrote this block in full and
re-stated the error rather than correcting it, so it now reads as freshly asserted.

**Fix:** `…than the pre-existing `.sigra-auth__product` rule (0,1,0) defined earlier in the file;
this rule wins on both specificity and source order, so …`

---

### IN-03: Stale hard-coded line-number cross-reference, pushed further out of date by this sweep

**File:** `priv/templates/sigra.install/core/sigra_auth.css:708` (and the golden mirror at `:708`)

**Issue:**

```
     already applied to .sigra-auth-action button text below (this file, ~line 821). */
```

The referenced `white-space: normal` on the action-button rule is at **`:869`** at HEAD (it was
`:875` at `aa1372cb`). The pointer was already ~54 lines off before this sweep and the sweep's
6-line net reduction moved it again without correcting it. A hard-coded line number in a file that
is copied verbatim into adopter projects will keep rotting.

**Fix:** Drop the number and name the selector: `…already applied to the `.sigra-auth-action button`
rule later in this file.`

---

### IN-04: CSS rewrite added a relational claim the original observation did not support

**File:** `priv/templates/sigra.install/core/sigra_auth.css:511` (and golden mirror)

**Issue:** The original read `H2/P sharing one identical right edge (321.4375px) as the last
remaining offenders`. The rewrite reads:

```
  /* H2 and P shared one identical right edge with the surrounding stack.
```

The measured observation was that H2 and P shared an edge **with each other** — which is exactly
what identifies the shared implicit column track named in the next sentence. "with the surrounding
stack" asserts something different (and not what was measured). Removing the `321.4375px` figure is
correct bookkeeping hygiene; re-attributing the edge is a prose change with meaning attached.

**Fix:** `H2 and P shared one identical right edge with each other.`

---

### IN-05: The strengthened MFA comment now reads as an indictment of an unfixed sibling (pre-existing)

**Files:** `priv/templates/sigra.install/core/mfa_settings_live.ex:606-610` vs
`priv/templates/sigra.install/core/mfa_challenge_live.ex:358-360`

**Issue:** 239-06 sharpened the settings-screen comment to:

```elixir
    # Auto-submit when 6 digits entered. Calls the confirm path
    # directly instead of dispatching via
    # `send(self(), …)`. The mailbox round-trip allowed a stale 6-digit
    # prefix to fire after the user typed a 7th character, wasting an
    # attempt against the MFA lockout counter.
```

`mfa_challenge_live.ex` does exactly what that comment names as the defect:

```elixir
    # Auto-submit when 6 digits entered
    if String.length(code) == 6 and Regex.match?(~r/^\d{6}$/, code) do
      send(self(), {:auto_verify_totp, code})
    end
```

— and the *challenge* screen is the one guarded by the lockout counter the comment cites.

**Explicitly not introduced by 239-05…08** (both sites predate `aa1372cb`, and this is outside the
review scope as a code change). Raised here only because the rewritten comment turns a latent
inconsistency into a documented one. Recommend a tracked todo rather than an in-phase fix.

---

### IN-06: Residual internal bookkeeping in the example tree, outside the swept file set

**File:** `test/example/priv/playwright/tests/golden-path.spec.ts:59`

**Issue:** `// The login page is a plain controller (post plan 04). If we are already …` — a plan
reference the sweep did not reach. Not adopter-shipped (example-only, test tooling), so severity is
low, but it is the same token class SURF-01 targets and would fail a widened repo-wide ratchet.

**Fix:** `// The login page is a plain controller. If we are already …`

---

## Verification performed

| Check | Result |
|---|---|
| CSS comment-stripped md5, template `aa1372cb` vs HEAD | identical (`bd9f0bdf…`) |
| CSS comment-stripped md5, golden `aa1372cb` vs HEAD | identical (`bd9f0bdf…`) |
| CSS comment-stripped md5, template vs golden at HEAD | identical |
| `MIX_ENV=test mix sigra.fixture.rebless_golden --check` | `OK: fixture is up-to-date (check mode).` exit 0 |
| `mix format --check-formatted` on the 6 changed `test/example` files | exit 0 |
| V2 widened bookkeeping regex over all 21 reviewed files | **0** matches |
| Every `+`/`-` line is comment / moduledoc / `doc:` | confirmed by line-by-line diff read |
| Factual check: `@pending_count`, `@streams.pending_invitations`, `<section id="pending-invitations-section">`, "Invite member" action | all present (`:47`, `:60-61`, `:363`, `:421-433`) — moduledoc claim true |
| Factual check: Branch B Accept action | `organizations_live/index.ex:148` renders `Accept`, not disabled — moduledoc claim true |
| Factual check: invitation-email subject includes inviter + `org.name` | `organization_invitation_email.ex:96-100` — comment claim true |
| Factual check: `mfa_settings_live` calls `do_confirm_enrollment/2` directly | `:612` — comment claim true |
| Claimed no-counterpart dispositions (`organization_invitation.ex`, `organization_invitation_email.ex`) | confirmed (`@moduledoc false`; no example file) |

---

_Reviewed: 2026-09-18T04:04:52Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
_Range: `aa1372cb..HEAD` (plans 239-05 … 239-08)_
