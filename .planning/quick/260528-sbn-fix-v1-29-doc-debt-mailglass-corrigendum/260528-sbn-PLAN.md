---
phase: quick-260528-sbn
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - guides/recipes/companion-libs/mailglass.md
  - guides/recipes/companion-libs/accrue.md
  - guides/recipes/companion-libs/lockspire.md
  - guides/recipes/companion-libs/relyra.md
  - guides/recipes/companion-libs/rulestead.md
  - guides/recipes/companion-libs/threadline.md
autonomous: true
requirements: [DOC-DEBT-v1.29]
must_haves:
  truths:
    - "mailglass.md non-goals bullet states the v1.25 corrigendum HAS landed and points to CHANGELOG.md (not a planned suite-integration.html location)"
    - "No companion-lib recipe pins {:sigra, \"~> 1.29\"} — all 7 occurrences read {:sigra, \"~> 0.2\"}"
    - "test/example/AGENTS.md contains no residual two-migration claim (already correct: 'Three committed migrations')"
    - "mix docs --warnings-as-errors exits 0 after edits"
    - "No banned marketing phrases in edited files"
  artifacts:
    - path: "guides/recipes/companion-libs/mailglass.md"
      provides: "Corrected corrigendum pointer + ~> 0.2 self-pin"
      contains: "{:sigra, \"~> 0.2\"}"
  key_links:
    - from: "guides/recipes/companion-libs/mailglass.md non-goals"
      to: "CHANGELOG.md v1.25 corrigendum"
      via: "prose reference"
      pattern: "CHANGELOG"
---

<objective>
Fix three v1.29 SUITE-INTEGRATION doc-debt items surfaced by the milestone audit
(`.planning/v1.29-MILESTONE-AUDIT.md`): a stale corrigendum pointer in mailglass.md,
a version-pin mismatch across 6 companion-lib recipes, and a verification-only
migration-count nit in AGENTS.md.

Purpose: Restore doc accuracy so adopters can `mix deps.get` against resolvable
version pins and find the v1.25 Mailglass corrigendum where it actually lives.
Output: Edited recipe files; no library code, tests, or mix.exs touched.

All three items are LOCKED decisions resolved by the orchestrator — no re-litigation.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@./CLAUDE.md
@.planning/v1.29-MILESTONE-AUDIT.md

# Verified facts (do not re-investigate):
# - CHANGELOG.md:37 [Unreleased] holds the v1.25 Mailglass corrigendum text (DOC-01 COMPLETE).
# - guides/introduction/suite-integration.md contains NO corrigendum text (grep exit 1).
# - test/example/AGENTS.md:208 ALREADY reads "Three committed migrations" — NO-OP, verify only.
# - 7 occurrences of {:sigra, "~> 1.29"}: mailglass.md:35, lockspire.md:37, threadline.md:49,
#   accrue.md:30, rulestead.md:36 AND :100, relyra.md:46.
# - Canonical install guides already pin {:sigra, "~> 0.2"} (installation.md:27 etc.).
# - Banned marketing phrases (CLAUDE.md): "seamlessly", "just works",
#   "production-ready out of the box", "the recommended way".

<interfaces>
mailglass.md Non-goals bullet (lines 115-118), current stale text to replace:

> - Sigra does **not** ship a library-resident Mailglass adapter. The orphaned Phase 111/114
>   adapter code does not re-land in v1.29 (see STATE.md deferred items and STACK.md:14-23). A
>   corrigendum correcting the v1.25 EMAIL-RAILS narrative is planned for Phase 136 DOC-01; until
>   it lands, see the planned location: `../introduction/suite-integration.html`.

Preserve the first two sentences (the no-re-land point + STATE/STACK refs). Only the third
sentence (the "planned"/"until it lands"/suite-integration.html framing) is wrong and must be
rewritten to present/past tense pointing at CHANGELOG.md (and MILESTONES.md / PROJECT.md v1.25 entry).
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Rewrite mailglass.md corrigendum pointer (Item 1)</name>
  <files>guides/recipes/companion-libs/mailglass.md</files>
  <action>In the Non-goals section (first bullet, lines 115-118), rewrite ONLY the third sentence — the one beginning "A corrigendum correcting the v1.25 EMAIL-RAILS narrative is planned for Phase 136 DOC-01; until it lands, see the planned location: `../introduction/suite-integration.html`." DOC-01 is COMPLETE: the corrigendum landed. Replace with present/past-tense factual prose stating the v1.25 EMAIL-RAILS Mailglass-narrative correction HAS landed and lives in `CHANGELOG.md` (the v1.25 entry), with the MILESTONES.md and PROJECT.md v1.25 entries carrying the same correction. Drop the "planned" / "until it lands" framing and the `../introduction/suite-integration.html` pointer entirely (that page has no corrigendum text — verified). Keep the first two sentences of the bullet unchanged (no library-resident adapter re-lands in v1.29; STATE.md/STACK.md refs). No marketing voice — none of the banned phrases. Do NOT touch the {:sigra, "~> 1.29"} line at :35 in this task (Task 2 handles all version pins including this file).</action>
  <verify>
    <automated>grep -q 'CHANGELOG' guides/recipes/companion-libs/mailglass.md && ! grep -qi 'until it lands\|is planned for Phase 136' guides/recipes/companion-libs/mailglass.md && ! grep -q 'suite-integration.html`' guides/recipes/companion-libs/mailglass.md; echo "exit=$?"</automated>
  </verify>
  <done>Non-goals first bullet states the corrigendum HAS landed and points to CHANGELOG.md; no "planned"/"until it lands" framing remains; no `suite-integration.html` pointer in the corrigendum sentence; first two sentences preserved.</done>
</task>

<task type="auto">
  <name>Task 2: Align sigra self-pin to ~> 0.2 across 6 recipes; verify AGENTS.md (Items 2 + 3)</name>
  <files>guides/recipes/companion-libs/mailglass.md, guides/recipes/companion-libs/accrue.md, guides/recipes/companion-libs/lockspire.md, guides/recipes/companion-libs/relyra.md, guides/recipes/companion-libs/rulestead.md, guides/recipes/companion-libs/threadline.md</files>
  <action>Per LOCKED Item 3: change every `{:sigra, "~> 1.29"}` to `{:sigra, "~> 0.2"}` in the 6 companion-lib recipe files. The 7 occurrences (verified via grep): accrue.md:30, lockspire.md:37, relyra.md:46, rulestead.md:36 AND :100 (two in this file), mailglass.md:35, threadline.md:49. Rationale: hex published line is 0.3.0; there is no sigra 1.29 on hex, so `~> 1.29` breaks `mix deps.get` for adopters. `~> 0.2` resolves to 0.3.0 and matches the canonical install guides. Do NOT touch any `validated_against:` frontmatter or sister-lib version pins (e.g. `mailglass ~> 1.2`, `threadline ~> 0.5`) — ONLY the `{:sigra, "~> 1.29"}` → `{:sigra, "~> 0.2"}` self-pin lines change. Then verify Item 2 (NO-OP): grep `test/example/AGENTS.md` for any residual two-migration claim; AGENTS.md:208 already reads "Three committed migrations" — confirm no edit is needed and make none.</action>
  <verify>
    <automated>test "$(grep -rc '{:sigra, "~> 1.29"}' guides/recipes/companion-libs/ | grep -v ':0$' | wc -l | tr -d ' ')" = "0" && test "$(grep -rl '{:sigra, "~> 0.2"}' guides/recipes/companion-libs/ | wc -l | tr -d ' ')" = "6" && ! grep -Eqi 'two (committed )?migration|2 migration' test/example/AGENTS.md; echo "exit=$?"</automated>
  </verify>
  <done>Zero `{:sigra, "~> 1.29"}` remain in guides/recipes/companion-libs/; all 6 recipe files contain `{:sigra, "~> 0.2"}`; no `validated_against` or sister-lib pins changed; AGENTS.md confirmed to have no residual two-migration claim (no edit made).</done>
</task>

<task type="auto">
  <name>Task 3: ExDoc build + banned-phrase gate</name>
  <files>guides/recipes/companion-libs/mailglass.md, guides/recipes/companion-libs/accrue.md, guides/recipes/companion-libs/lockspire.md, guides/recipes/companion-libs/relyra.md, guides/recipes/companion-libs/rulestead.md, guides/recipes/companion-libs/threadline.md</files>
  <action>Run the docs build with warnings-as-errors to confirm the prose/version-string edits did not break any ExDoc autolinks in the recipe extras. Then run the banned-phrase grep gate against all 6 edited recipe files to confirm none of the banned marketing phrases were introduced. If either gate fails, fix the offending edit before completing.</action>
  <verify>
    <automated>mix docs --warnings-as-errors && ! grep -rEi 'seamlessly|just works|production-ready out of the box|the recommended way' guides/recipes/companion-libs/mailglass.md guides/recipes/companion-libs/accrue.md guides/recipes/companion-libs/lockspire.md guides/recipes/companion-libs/relyra.md guides/recipes/companion-libs/rulestead.md guides/recipes/companion-libs/threadline.md; echo "exit=$?"</automated>
  </verify>
  <done>`mix docs --warnings-as-errors` exits 0; no banned marketing phrase present in any of the 6 edited recipe files.</done>
</task>

</tasks>

<verification>
- `mix docs --warnings-as-errors` exits 0 (no broken autolinks introduced).
- `grep -rc '{:sigra, "~> 1.29"}' guides/recipes/companion-libs/` reports 0 matches everywhere.
- mailglass.md non-goals bullet references CHANGELOG.md, not the planned suite-integration.html.
- test/example/AGENTS.md still reads "Three committed migrations" (unchanged).
- No banned marketing phrases in edited files.
</verification>

<success_criteria>
- Item 1: mailglass.md corrigendum pointer rewritten to present/past tense → CHANGELOG.md.
- Item 2: AGENTS.md migration count verified correct (no edit).
- Item 3: all 7 `~> 1.29` self-pins changed to `~> 0.2`; sister-lib + frontmatter pins untouched.
- Docs build and banned-phrase gates pass.
- No library code, tests, or mix.exs changed.
</success_criteria>

<output>
Create `.planning/quick/260528-sbn-fix-v1-29-doc-debt-mailglass-corrigendum/260528-sbn-SUMMARY.md` when done.
</output>
