# Phase 139: Recipe-Contract Integrity & Sister-Repo Verification - Context

**Gathered:** 2026-05-29 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Two independent tracks, both about **keeping companion-lib recipes honest**:

1. **RCT-01** — a merge-blocking test fixture that asserts every recipe under
   `guides/recipes/companion-libs/` carries its required sections and freshness
   frontmatter, so recipe docs cannot silently drift.
2. **RCV-01 / RCV-02** — verify the two sister-repo contracts the recipes assert
   (Lockspire `resolve_account/2`, Rulestead policy `@behaviour`) against the real
   sister-repo source, fixing the recipes where they diverge.

In scope: the fixture, the two contract verifications + recipe fixes, citing the
verified refs, and closing the Phase-134 recipe-residual todo honestly.

Out of scope: new library code, new recipes, the deprecation-removal/proof/docs
work (that is Phase 140), and broad recipe rewrites beyond the contract fixes.
</domain>

<decisions>
## Implementation Decisions

### RCT-01 — merge-blocking recipe-contract fixture
- **D-01:** Add a new pure-ExUnit test (suggested
  `test/sigra/recipes/companion_lib_contract_test.exs`, `async: true`) that globs
  `guides/recipes/companion-libs/*.md` and asserts, per recipe, the presence of the
  three required sections and both frontmatter markers. Model it on the existing
  markdown-contract tests `test/sigra/guides_dx02_test.exs` and
  `test/sigra/planning/phase_50_nyquist_docs_contract_test.exs`.
- **D-02:** Required assertions per recipe (and ONLY these — requirement-exact scope,
  user-confirmed):
  - `## Failure modes` section present
  - `## Non-goals` section present
  - the "Sigra works fully standalone" banner present
  - `validated_against:` frontmatter marker present
  - `last_validated:` frontmatter marker present
- **D-03:** The fixture does NOT assert the `{:sigra, "~> 0.2"}` version pin nor
  parse `last_validated:` as a date. Those drift-tripwire enhancements were
  explicitly declined to keep scope matched to RCT-01's letter. (Note for a future
  phase if desired — see Deferred Ideas.)
- **D-04:** "Merge-blocking" is satisfied by running in the standard suite. CLAUDE.md
  confirms there are no tag exclusions — every test that runs in CI runs locally —
  so a plain `async: true` ExUnit test in `test/` is merge-blocking with no extra
  CI wiring. Do NOT gate it behind a tag or a separate optional job.
- **D-05:** The fixture must fail loudly (not vacuously) if a recipe file is missing
  a marker AND if the companion-libs glob returns zero files — assert the recipe set
  is non-empty so the contract can't pass by matching nothing.

### RCV-01 — Lockspire `resolve_account/2` contract (VERIFY; confirmed real bug)
- **D-06:** Verification path, not the document-the-assumption fallback — the
  Lockspire sister repo resolves in-tree at `/Users/jon/projects/lockspire`
  (v1.2.0, git `def616d`).
- **D-07:** The canonical contract is
  `@callback resolve_account(account_reference :: term(), context()) :: {:ok, account()} | {:error, :not_found | term()}`
  (`lib/lockspire/host/account_resolver.ex:17-18`), consumed via
  `with {:ok, account} <- resolver.resolve_account(...)` at
  `lib/lockspire/protocol/token_exchange.ex:1223` and
  `lib/lockspire/protocol/userinfo.ex:147`.
- **D-08:** The recipe at `guides/recipes/companion-libs/lockspire.md:93` returns a
  bare `MyApp.Accounts.get_user(account_reference)` (user-or-nil) — this is the
  MatchError the Phase-134 reviewer (WR-02) suspected, now **confirmed**. Fix the
  recipe's `resolve_account/2` example to return `{:ok, account}` / `{:error, :not_found}`.
- **D-09:** Cite the verified reference in the recipe (e.g. "verified against
  `lockspire` v1.2.0 (`def616d`) on 2026-05-29") and update WR-02 in the tracked
  todo honestly to reflect the verified contract + fix.

### RCV-02 — Rulestead policy `@behaviour` contract (VERIFY; todo named wrong module)
- **D-10:** Verification path — the Rulestead sister repo resolves in-tree at
  `/Users/jon/projects/rulestead/rulestead` (v0.1.3, git `0a18360`).
- **D-11:** The host-owned policy behaviour is **`Rulestead.Admin.Policy`**, which
  declares `@callback can?(actor, action, resource, environment_key) :: boolean()`
  at `lib/rulestead/admin/policy.ex:121`. It is NOT `Rulestead.Admin.Authorizer` as
  WR-05 guessed — `Authorizer` is the internal gate that *dispatches* to
  `policy.can?/4` (`lib/rulestead/admin/authorizer.ex:149`).
- **D-12:** Fix the recipe at `guides/recipes/companion-libs/rulestead.md` so the host
  policy module declares `@behaviour Rulestead.Admin.Policy` and `@impl true` on
  `can?/4`. Also correct any prose/line-refs that point at `authorizer.ex` as the
  behaviour source.
- **D-13:** Planner must confirm during implementation whether the sibling callbacks
  `change_request_required?/4` and `allow_self_approval?/4` (also declared in
  `Rulestead.Admin.Policy`) are required or optional, and reflect that accurately in
  the recipe (either implement them or note they default/are optional). Do not
  silently imply `can?/4` is the only callback if the behaviour requires more.
- **D-14:** Cite the verified reference in the recipe and correct WR-05 in the tracked
  todo (note the corrected module name).

### Verification posture & todo disposition
- **D-15:** Because both sister repos resolve, NEITHER contract uses the
  "document-the-assumption" fallback — both are hard-verified and the recipes cite
  the exact verified version + ref + date.
- **D-16:** The recipes' existing `validated_against:` markers are already accurate
  (`lockspire ~> 1.2` vs actual 1.2.0; `rulestead ~> 0.1` vs actual 0.1.3) — leave
  them as-is; refresh `last_validated:` to the phase date when the recipes are touched.

### Folded Todos
- **D-17:** `2026-05-28-phase-134-recipe-residual-findings.md` is folded into this
  phase and closed on completion:
  - WR-02 → resolved by D-06..D-09 (Lockspire fix)
  - WR-05 → resolved by D-10..D-14 (Rulestead behaviour correction)
  - IN-01 (sigra version pin `~> 1.29`) → **already resolved**: all six recipes now
    pin `{:sigra, "~> 0.2"}` (resolves against current hex `0.3.0`), and intro guides
    already match. No version-pin sweep needed; mark IN-01 done in the todo.

### Claude's Discretion
- Exact test file name/path and the markdown-parsing approach (regex vs. line scan)
  are the planner's call, following the cited analog tests.
- Whether to fix the prose line-references inside the recipes beyond the two contract
  fixes, where touching them anyway.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

Requirements / roadmap:
- `.planning/REQUIREMENTS.md` (RCT-01, RCV-01, RCV-02)
- `.planning/ROADMAP.md` (Phase 139 line)

Recipes under test / to fix:
- `guides/recipes/companion-libs/lockspire.md` (RCV-01 fix at :93)
- `guides/recipes/companion-libs/rulestead.md` (RCV-02 fix; behaviour + can?/4)
- `guides/recipes/companion-libs/accrue.md`
- `guides/recipes/companion-libs/relyra.md`
- `guides/recipes/companion-libs/mailglass.md`
- `guides/recipes/companion-libs/threadline.md`

Analog test patterns for the fixture (RCT-01):
- `test/sigra/guides_dx02_test.exs`
- `test/sigra/planning/phase_50_nyquist_docs_contract_test.exs`

Sister-repo contract sources (in-tree, verified 2026-05-29):
- `/Users/jon/projects/lockspire/lib/lockspire/host/account_resolver.ex:17-18` (resolve_account/2 contract; lockspire v1.2.0, `def616d`)
- `/Users/jon/projects/lockspire/lib/lockspire/protocol/token_exchange.ex:1223` (consumer)
- `/Users/jon/projects/lockspire/lib/lockspire/protocol/userinfo.ex:147` (consumer)
- `/Users/jon/projects/rulestead/rulestead/lib/rulestead/admin/policy.ex:121` (@callback can?/4 behaviour; rulestead v0.1.3, `0a18360`)
- `/Users/jon/projects/rulestead/rulestead/lib/rulestead/admin/authorizer.ex:149` (dispatch site — NOT the behaviour)

Tracked todo (folded):
- `.planning/todos/pending/2026-05-28-phase-134-recipe-residual-findings.md`
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Markdown-contract test pattern is established twice: `guides_dx02_test.exs`
  (structural + accuracy sweep over guides) and
  `phase_50_nyquist_docs_contract_test.exs` (grep/structure assertions over files
  with a `read!/1` helper). The RCT-01 fixture is a direct restyling of these — no
  new infrastructure needed.
- All six companion-lib recipes already carry the required sections and frontmatter
  markers, so the fixture locks current state rather than forcing recipe edits.

### Established Patterns
- CLAUDE.md: no tag exclusions in the suite — a plain `async: true` ExUnit test is
  automatically merge-blocking (no separate CI job needed).
- Recipe frontmatter convention: HTML-comment markers at the top
  (`<!-- validated_against: ... -->`, `<!-- last_validated: ... -->`) plus a prose
  "Validated against:" line and the "Sigra works fully standalone." banner.

### Integration Points
- The fixture reads files from `guides/recipes/companion-libs/` relative to repo root
  (mirror the `root()`/`read!()` path helper from the phase-50 test).
- Recipe fixes are documentation-only edits; verify `mix docs --warnings-as-errors`
  stays clean after editing (per the folded todo's solution note).
</code_context>

<specifics>
## Specific Ideas

- Lockspire fix is a contract bug fix, not cosmetic: the recipe currently teaches a
  pattern that crashes Lockspire's token-exchange `with {:ok, account} <- ...`.
- Rulestead fix corrects a module-identity error inherited from the Phase-134 review's
  own assumption (WR-05 named `Authorizer`; the real behaviour is `Admin.Policy`).
</specifics>

<deferred>
## Deferred Ideas

- **Strict drift tripwires for the RCT-01 fixture** (declined this phase): also
  asserting `{:sigra, "~> 0.2"}` pin consistency and that `last_validated:` parses as
  a date. Would turn the IN-01 stale-pin class into a permanent tripwire. Out of
  RCT-01's letter; revisit if recipe-pin drift recurs.

### Reviewed Todos (not folded)
- `2026-05-28-phase-135-review-deferred-findings.md` — Threadline demo polish +
  upstream generated-DDL note. Out of recipe-contract scope; belongs to demo/upstream
  follow-up, not Phase 139.
- `2026-05-29-phase-138-doctor-info-findings.md` — Sigra.Doctor minor (Info)
  code-review findings. Belongs to the doctor track (Phase 138 follow-up), not the
  recipe-contract track.
</deferred>
