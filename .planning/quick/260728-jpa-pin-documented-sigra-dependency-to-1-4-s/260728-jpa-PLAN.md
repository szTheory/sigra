---
phase: quick-260728-jpa
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - README.md
  - guides/introduction/installation.md
  - guides/introduction/getting-started.md
  - guides/introduction/first-hour.md
  - guides/recipes/companion-libs/lockspire.md
  - guides/recipes/companion-libs/threadline.md
  - guides/recipes/companion-libs/rulestead.md
  - guides/recipes/companion-libs/mailglass.md
  - guides/recipes/companion-libs/relyra.md
  - guides/recipes/companion-libs/accrue.md
autonomous: true
requirements: [QUICK-260728-jpa]

must_haves:
  truths:
    - "Every documented Sigra install line in README.md and guides/ carries a version requirement that EXCLUDES the stray Hex 1.20.0."
    - "An adopter copy-pasting the documented dependency resolves to the 1.4.x line, not 1.20.0."
    - "The obsolete pre-1.0.0 'until the release PR lands' caveat no longer appears in the intro guides."
    - "Exactly one place (guides/introduction/installation.md) explains why the requirement is narrower than the usual two-segment convention."
    - "README.md no longer instructs readers to prefer whatever Hex advertises as newest, which would steer them back to 1.20.0."
    - "No file outside README.md and guides/ is modified."
  artifacts:
    - README.md
    - guides/introduction/installation.md
    - guides/introduction/getting-started.md
    - guides/introduction/first-hour.md
    - guides/recipes/companion-libs/*.md
  key_links:
    - "Documented requirement string -> Hex resolver behavior: the requirement must be three-segment so the admitted range terminates below 1.5.0."
    - "installation.md explanatory note -> the requirement string it justifies (both must say 1.4.0)."
---

<objective>
Change the documented Sigra dependency requirement in README.md and guides/ from the
two-segment `~> 1.0` form to the three-segment `~> 1.4.0` form, so that an adopter who
copy-pastes from our docs cannot resolve the erroneous stray Hex release `1.20.0`.

Purpose: `1.20.0` was published to Hex in error on 2026-04-28 and is still
`latest_stable` there, outranking every real release (current real release: `1.4.0`).
`mix hex.retire` is the correct fix but is blocked by an OAuth-scope limitation in
Hex 2.5.1 and has been deferred across multiple milestones (see ADR 003 and the standing
retire todo). Narrowing the DOCUMENTED requirement sidesteps the stray with zero auth
and zero release work.

Output: documentation-only diff across 10 files. No library, installer, or config change.
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@CLAUDE.md
@.planning/decisions/003-hex-release-versioning-no-tag-derived-publish.md
@.planning/todos/pending/2026-07-03-hex-retire-stray-1-20-0.md
</context>

<operator_determination>
## The version operator was determined empirically. Do NOT re-derive it. Do NOT substitute a different form.

Elixir's `~>` operator behaves differently with two vs three version segments:

- `~> 1.4`   means `>= 1.4.0 and < 2.0.0`  -> **ADMITS 1.20.0**. Does NOT fix the problem.
- `~> 1.4.0` means `>= 1.4.0 and < 1.5.0`  -> **EXCLUDES 1.20.0**. Fixes the problem.

Verified by running `Version.match?/2` against the real Elixir version matcher during
planning. Result table (`YES` = requirement admits that version):

| requirement            | 1.0.0 | 1.4.0 | 1.5.0 | 1.19.9 | 1.20.0 | 2.0.0 |
|------------------------|-------|-------|-------|--------|--------|-------|
| `~> 1.0`               | YES   | YES   | YES   | YES    | **YES**| no    |
| `~> 1.4`               | no    | YES   | YES   | YES    | **YES**| no    |
| `~> 1.4.0`             | no    | YES   | no    | no     | **no** | no    |
| `>= 1.4.0 and < 1.5.0` | no    | YES   | no    | no     | **no** | no    |

The task brief flagged this correctly as a trap: `~> 1.4` looks like a fix and is not one.
Because Hex resolves to the HIGHEST version satisfying the requirement, `~> 1.4` would
resolve to `1.20.0` — exactly the current broken behavior, just with a different-looking
string. Shipping `~> 1.4` would produce docs that appear fixed but are not.

**THE REQUIREMENT TO WRITE EVERYWHERE IS `~> 1.4.0`** (three segments).

`>= 1.4.0 and < 1.5.0` is semantically identical but is not idiomatic in Elixir install
docs; use the `~> 1.4.0` form.

Accepted consequence: `~> 1.4.0` pins the documented line to 1.4.x patch releases, so the
docs must be bumped when a 1.5.0 ships. That is intentional and is the cost of routing
around the stray without a retire. The explanatory note in Task 2 tells readers to raise it.
</operator_determination>

<tasks>

<task type="tracer">
  <name>Task 1: Pin every documented install line to the three-segment requirement</name>
  <files>README.md, guides/introduction/installation.md, guides/introduction/getting-started.md, guides/introduction/first-hour.md, guides/recipes/companion-libs/lockspire.md, guides/recipes/companion-libs/threadline.md, guides/recipes/companion-libs/rulestead.md, guides/recipes/companion-libs/mailglass.md, guides/recipes/companion-libs/relyra.md, guides/recipes/companion-libs/accrue.md</files>
  <read_first>
Re-run the discovery grep FIRST and confirm the occurrence set before editing:

    grep -rn ':sigra, "~>' README.md guides/

Expected at planning time: exactly 11 hits across 10 files —
README.md:76; guides/introduction/getting-started.md:15;
guides/introduction/first-hour.md:24; guides/introduction/installation.md:27;
guides/recipes/companion-libs/{mailglass:35, accrue:30, lockspire:37,
rulestead:36, rulestead:102, threadline:49, relyra:46}.

If the count or file set differs, pin whatever the live grep actually returns and record
the discrepancy in the summary. Do not skip a hit because it was not in the expected list.
  </read_first>
  <action>
Replace the version requirement in every one of those install lines with the three-segment
form `~> 1.4.0`, determined in `<operator_determination>` above.

Change ONLY the version string. Preserve each line's surrounding syntax exactly as found —
some occurrences end with a trailing comma inside a deps list, some do not; some sit inside
fenced code blocks, some inside indented code blocks, and two sit inline inside prose
bullets. Do not reflow, reindent, or reformat any surrounding line.

`rulestead.md` carries TWO occurrences (two separate deps blocks). Pin both.

<!-- planner-discipline-allow: ~> 1.0 -->
The literal being replaced is the two-segment `~> 1.0` inside a `{:sigra, ...}` tuple.
Do not touch `~> 1.0` requirements belonging to OTHER packages — `telemetry_metrics`,
`telemetry_poller`, `gettext`, `phoenix_live_view`, and others legitimately use that
requirement. Scope every edit to the `:sigra` tuple.

Do not modify any file outside README.md and guides/. In particular: mix.exs,
.release-please-manifest.json, CHANGELOG.md, anything under priv/, anything under lib/,
and test/example/mix.exs are all OUT OF SCOPE. The library's own @version is 1.4.0 and is
already correct.
  </action>
  <verify>
    <automated>! grep -rn ':sigra, "~> 1\.0"' README.md guides/ &amp;&amp; [ "$(grep -rn ':sigra, "~> 1\.4\.0"' README.md guides/ | wc -l | tr -d ' ')" = "11" ]</automated>
  </verify>
  <done>Zero `:sigra` install lines in README.md or guides/ carry the two-segment requirement, and the three-segment count matches the live occurrence count found in read_first (11 at planning time).</done>
</task>

<task type="auto">
  <name>Task 2: Correct the stale pre-1.0.0 caveats and add the single explanatory note</name>
  <files>guides/introduction/getting-started.md, guides/introduction/first-hour.md, guides/introduction/installation.md, README.md</files>
  <read_first>
Read the four target regions before editing:
- guides/introduction/getting-started.md line 15 (prerequisites bullet)
- guides/introduction/first-hour.md line 24 (checklist bullet)
- guides/introduction/installation.md line 31 (prose under the deps block)
- README.md line 79 (prose under the deps block)
  </read_first>
  <action>
Four scoped prose edits. Keep the version strings already pinned in Task 1 intact.

**(a) getting-started.md, prerequisites bullet.** The bullet currently ends with an
obsolete caveat telling readers that if they are on `main` before Hex shows 1.0.0 they
should use the latest published package or a source checkout until the release PR lands.
That is false — 1.0.0 shipped 2026-06-03 and 1.4.0 is current. Delete the caveat sentence
entirely; nothing in it is still useful. Leave the bullet as just the dependency
requirement plus the `mix deps.get` prerequisite.

**(b) first-hour.md, checklist bullet.** Same obsolete caveat, same treatment: delete the
caveat sentence, leave the checklist item as the dependency requirement plus `mix deps.get`.

**(c) installation.md, prose under the deps block.** This line currently has two sentences:
a governing reference to the Sigra 1.0 contract, and the same obsolete pre-1.0.0 caveat.
Keep the contract sentence verbatim. Delete the caveat sentence. Then add the explanatory
note — this is the ONE place in the repo that explains the narrower requirement. Add it as
a new paragraph immediately after the contract sentence, using this text:

    The three-segment requirement is deliberate. An erroneous `1.20.0` was published to
    Hex and, by SemVer ordering, sorts above the current `1.4.x` releases, so a
    two-segment `~> 1.4` would still admit it. `~> 1.4.0` means `>= 1.4.0 and < 1.5.0`,
    which keeps resolution on the supported line — raise it when you move to a newer minor.

Factual and unalarmed by design. Do not add a retire date, do not promise a fix, and do
not characterize the situation as broken. Do not add this note anywhere else — README.md
and the companion-lib recipes get the corrected requirement with no commentary.

**(d) README.md, prose under the deps block.** The paragraph currently opens by calling
this the selected 1.0 contract line and then tells the reader that if Hex advertises a
newer installable line they should treat Hex as the current package truth and use the
constraint appropriate for their target. That second sentence steers a reader straight
back to the stray `1.20.0` and would make the pin self-defeating. Delete both of those
leading sentences. Keep the final sentence — the one pointing at the Sigra 1.0 contract
for version, stack, ownership, and non-goal boundaries — verbatim, including its existing
link text and target. Add no explanation here; README is the shop window and stays clean.
  </action>
  <verify>
    <automated>! grep -rn 'release PR lands' README.md guides/introduction/getting-started.md guides/introduction/first-hour.md guides/introduction/installation.md &amp;&amp; ! grep -n 'current package truth' README.md &amp;&amp; [ "$(grep -rc 'erroneous `1.20.0`' guides/introduction/installation.md)" = "1" ] &amp;&amp; [ "$(grep -rln 'erroneous `1.20.0`' README.md guides/ | wc -l | tr -d ' ')" = "1" ]</automated>
  </verify>
  <done>The obsolete pre-1.0.0 caveat is gone from all three intro guides; README no longer directs readers to whatever Hex advertises as newest; the explanatory note exists in exactly one file (guides/introduction/installation.md) and nowhere else.</done>
</task>

<task type="auto">
  <name>Task 3: Prove docs-only scope, run the doc-contract tests, and commit</name>
  <files>(no new files — verification and commit only)</files>
  <precondition>`mix test` boots a live Postgres via test/test_helper.exs (`Sigra.Test.PostgresRepo.start_link` runs unconditionally at helper load), so even a single doc-contract file needs a reachable DB. Per CLAUDE.md, `scripts/db/up.sh` then `source tmp/db.env` provides one; a Homebrew Postgres on localhost:5432 with postgres/postgres also satisfies it.</precondition>
  <action>
Three verification sweeps, then one commit.

**1. Scope proof — no non-documentation file changed.** Confirm the working diff touches
only README.md and paths under guides/. If anything else appears — mix.exs, priv/, lib/,
test/, CHANGELOG.md, .release-please-manifest.json — revert that file and re-check before
proceeding.

**2. Requirement sweep.** Re-run the Task 1 and Task 2 automated gates together and
confirm both still pass after all edits are in place.

**3. Doc-contract tests.** These read README.md and guides/ and are the real regression
guard for this change. Run at minimum:

    test/sigra/guides_dx02_test.exs
    test/sigra/architecture_guides_contract_test.exs
    test/sigra/recipes/companion_lib_contract_test.exs
    test/sigra/planning/phase_147_upgrade_migration_lanes_test.exs
    test/sigra/planning/phase_148_evaluator_funnel_and_first_run_dx_test.exs
    test/sigra/planning/phase_149_launch_evidence_and_announcement_pack_test.exs

Planning confirmed none of these assert on the two-segment requirement string, so they are
expected to pass unchanged. `companion_lib_contract_test.exs` asserts the five contract
markers on every companion-lib recipe — those markers are untouched by this change. All
six files are `use ExUnit.Case, async: true` with no DataCase, so they exercise no DB
themselves; only the helper boot needs one.

If the database is unavailable and cannot be brought up, run what you can and say so
plainly in the summary — state exactly which test files ran and which did not. Do NOT
claim a full-suite pass. A partial, honestly-labeled run is the acceptable outcome here;
an overclaimed green is not.

**4. Commit.** Stage only README.md and the guides/ files. Use a conventional docs commit,
for example: `docs: pin documented sigra dependency to ~> 1.4.0`. In the commit body,
state that the three-segment form is required because `~> 1.4` still admits the stray
`1.20.0`, and reference ADR 003.

Do NOT push. Do NOT open or merge a PR. Do NOT create a tag. The orchestrator owns the PR.

**Out of scope, but report in the summary as observed follow-ups (do not fix here):**
`guides/introduction/contract.md:9` still states the current published package truth is
`1.1.0`, and `guides/introduction/upgrading-to-v1.0.md:8` carries the same
"treat Hex package metadata as the current package truth" framing that was removed from
README. Both are stale relative to 1.4.0 but sit outside this task's stated scope.
  </action>
  <verify>
    <automated>test -z "$(git diff --name-only | grep -vE '^(README\.md|guides/)')" &amp;&amp; ! grep -rn ':sigra, "~> 1\.0"' README.md guides/ &amp;&amp; mix test test/sigra/guides_dx02_test.exs test/sigra/architecture_guides_contract_test.exs test/sigra/recipes/companion_lib_contract_test.exs test/sigra/planning/phase_147_upgrade_migration_lanes_test.exs test/sigra/planning/phase_148_evaluator_funnel_and_first_run_dx_test.exs test/sigra/planning/phase_149_launch_evidence_and_announcement_pack_test.exs</automated>
  </verify>
  <done>Working diff contains only README.md and guides/ files; the listed doc-contract tests pass (or the exact subset that ran is named in the summary with the DB-unavailability reason); one docs commit exists locally; nothing pushed, no PR, no tag.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| published docs -> adopter dependency resolution | A copy-pasted requirement string in our docs directly determines which Hex artifact an adopter's build fetches and compiles. |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-QUICK-01 | Tampering | Documented `{:sigra, ...}` requirement in README.md and guides/ | medium | mitigate | Pin to `~> 1.4.0` so the admitted range terminates below 1.5.0 and cannot resolve the unvetted stray `1.20.0` artifact. Verified by the Task 1 negative grep plus the exact-count positive grep. |
| T-QUICK-02 | Tampering | README prose directing readers to "treat Hex as the current package truth" | medium | mitigate | Remove that sentence in Task 2(d) — left in place it re-authorizes resolution to the stray and defeats the pin. |
| T-QUICK-03 | Information disclosure | Explanatory note in installation.md | low | accept | The note names the stray version publicly. Accepted: the stray is already public on Hex, and a reader hitting an unexpected resolution needs the explanation more than the version number is worth concealing. Note is factual, carries no retire commitment, and lands in exactly one file. |

No package-manager installs occur in this plan, so no Package Legitimacy Gate applies.
</threat_model>

<verification>
- `grep -rn ':sigra, "~> 1\.0"' README.md guides/` returns nothing.
- `grep -rn ':sigra, "~> 1\.4\.0"' README.md guides/` returns the full occurrence count (11 at planning time).
- `grep -rn 'release PR lands'` returns nothing in getting-started.md, first-hour.md, or installation.md.
- The explanatory note appears in exactly one file under README.md + guides/.
- `git diff --name-only` lists only README.md and guides/ paths.
- The six listed doc-contract test files pass, or the summary names precisely which ran and why the rest did not.
</verification>

<success_criteria>
- All documented Sigra install lines carry `~> 1.4.0`, a requirement that provably excludes 1.20.0.
- No documented line carries `~> 1.4`, which would look fixed while still resolving to the stray.
- Obsolete pre-1.0.0 caveats removed from the three intro guides.
- Exactly one explanatory note, in guides/introduction/installation.md.
- Zero non-documentation files modified.
- One local docs commit. Nothing pushed, no PR opened, no tag created.
</success_criteria>

<output>
Create `.planning/quick/260728-jpa-pin-documented-sigra-dependency-to-1-4-s/260728-jpa-SUMMARY.md` when done.
</output>
