---
created: 2026-05-28T00:00:00.000Z
resolved: 2026-05-29
status: resolved
title: Phase 134 companion-lib recipe residual findings (sister-repo + version pin)
area: docs/recipes
resolves_phase: 139
files:
  - guides/recipes/companion-libs/lockspire.md
  - guides/recipes/companion-libs/rulestead.md
  - guides/recipes/companion-libs/accrue.md
  - guides/recipes/companion-libs/relyra.md
  - guides/recipes/companion-libs/mailglass.md
  - guides/recipes/companion-libs/threadline.md
---

## Problem

Phase 134 code review (134-REVIEW.md) raised three findings that could NOT be confidently
resolved in-phase because they depend on companion sister-repo source (NOT checked out in
this tree) or are project-wide conventions. They were deliberately deferred (decision:
fix-clean-ones, flag-rest). The 7 clean Sigra-side findings were fixed in commit `826e5a0`.

1. **WR-02 — Lockspire `resolve_account/2` return shape** (`lockspire.md:93`):
   recipe returns bare `MyApp.Accounts.get_user(account_reference)` (user-or-nil) while sibling
   callbacks return `{:ok, _}`. Reviewer suspects a `MatchError` in Lockspire's dispatch.
   134-RESEARCH.md confirms the callback name/arity (`account_resolver.ex:17`) but NOT the
   return contract. Verify against the Lockspire AccountResolver source before changing —
   guess-fixing risks a new bug.

2. **WR-05 — `RulesteadPolicy` missing `@behaviour`** (`rulestead.md:140`):
   the policy module implements `can?/4` with no `@behaviour Rulestead.Admin.Authorizer` /
   `@impl`, so there's no compile-time callback verification. Confirm `Admin.Authorizer` is a
   declarable behaviour (defines `@callback can?/4`) before adding it.

3. **IN-01 — companion-libs version pins `{:sigra, "~> 1.29"}`** (all six recipes):
   hex `@version` is `0.3.0`; the intro guides pin `~> 0.2`. A `~> 1.29` pin will not resolve
   on hex. This is a PROJECT-WIDE convention issue — `mailglass.md` and `threadline.md` (shipped
   earlier) use the same `~> 1.29` milestone-style pin, and the Phase 132 LOCKED template
   mandated matching them. Fixing only the four new recipes would break sibling consistency.
   Decide the convention once (real hex range vs. milestone label) and apply across all six
   recipes + the LOCKED template, ideally in the Phase 136 corrigendum. (Related: the historical
   `2026-05-08-cross-repo-mailglass-sigra-constraint` todo notes the same stale-constraint class.)

## Solution

- WR-02 / WR-05: check out the Lockspire + Rulestead sister repos, verify the contracts, then
  fix the two recipes (and confirm `mix docs --warnings-as-errors` stays clean).
- IN-01: make a single convention decision and sweep all six `guides/recipes/companion-libs/*.md`
  recipes + the LOCKED template; coordinate with the intro-guide `~> 0.2` pins.

## Resolution (Phase 139, 2026-05-29)

All three findings resolved in Phase 139 plan 02 (139-02):

- **WR-02: RESOLVED** — Lockspire `resolve_account/2` contract confirmed against v1.2.0 `def616d`
  at `account_resolver.ex:17-18`. The canonical contract is
  `{:ok, account()} | {:error, :not_found | term()}`. Recipe bug at `lockspire.md:93` (bare
  `get_user/1` call returning user-or-nil) caused MatchError in Lockspire's `with {:ok, account}`
  dispatch at `token_exchange.ex:1223` and `userinfo.ex:147`. Fixed: wrapped in `case` expression
  returning `{:ok, user}` / `{:error, :not_found}`. Verified ref cited in recipe. (RCV-01)

- **WR-05: RESOLVED** — Rulestead behaviour is `Rulestead.Admin.Policy` at `policy.ex:121`
  (NOT `Admin.Authorizer` as the finding initially named). `authorizer.ex:149` is the dispatch
  site, not the behaviour definition. Recipe fixed: added `@behaviour Rulestead.Admin.Policy`
  and `@impl Rulestead.Admin.Policy` before `can?/4`; prose corrected to attribute behaviour to
  `policy.ex:121`; optional callbacks (`change_request_required?/4`, `allow_self_approval?/4` at
  `policy.ex:142`) documented in a comment block. Verified against rulestead v0.1.3 `0a18360`.
  (RCV-02)

- **IN-01: ALREADY RESOLVED** — All six `guides/recipes/companion-libs/*.md` recipes already pin
  `{:sigra, "~> 0.2"}` (fixed in quick task `260528-sbn`, commit `81b8a65`). No further sweep
  needed. Marked done.
