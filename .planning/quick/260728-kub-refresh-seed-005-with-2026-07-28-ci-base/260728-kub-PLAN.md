---
phase: quick-260728-kub
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - .planning/seeds/SEED-005-ci-cd-pipeline-performance-audit.md
  - .planning/todos/pending/2026-07-28-admin-eval-render-burns-17m-per-pr-for-an-unread-red.md
  - .planning/todos/pending/2026-07-28-generated-host-parity-verified-on-no-pr-while-gate-reports-green.md
autonomous: true
requirements:
  - QUICK-260728-kub
user_setup: []

must_haves:
  truths:
    - "SEED-005 states, in-repo, that the CI/CD audit is already finished and its Phase 198-203 sequence was orphaned by v1.41 phase-number reuse, so the next reader executes the audit instead of re-running the playbook."
    - "SEED-005 carries the re-measured 2026-07-28 baseline table (40 runs), the example_playwright_smoke critical-path decomposition, the waste items absent from the 2026-06-20 audit, the locked 2026-07-28 decisions, and the <12m target."
    - "The verbatim companion playbook, Jon's verbatim framing, and the scope guardrails in SEED-005 are byte-identical after the edit."
    - "A pending todo records that admin_eval_render burns ~17m on every PR for an artifact nothing reads, names both root causes, and states that harness phases a2/b1-b6 have never executed in CI."
    - "A pending todo records that generated_admin_playwright_smoke is skipped on every real PR while ci-gate treats skipped as pass, so generated-host parity is verified on no PR at all."
  artifacts:
    - .planning/seeds/SEED-005-ci-cd-pipeline-performance-audit.md
    - .planning/todos/pending/2026-07-28-admin-eval-render-burns-17m-per-pr-for-an-unread-red.md
    - .planning/todos/pending/2026-07-28-generated-host-parity-verified-on-no-pr-while-gate-reports-green.md
  key_links:
    - "SEED-005 addendum points at .planning/research/SEED-005-CICD-AUDIT-2026-06-20.md as the already-derived backlog."
    - "Both new todos cross-reference the v1.47 CI-EFFICIENCY scope; the generated-host todo also cross-references 2026-07-28-gate-ci-green-timeout-too-tight-for-push-to-main.md."
---

<objective>
Refresh `SEED-005` with the 2026-07-28 re-measurement and file the two CI defect todos that
the same investigation surfaced.

Purpose: the single most valuable finding is that the CI/CD audit **was already executed** on
2026-06-20 and its prioritized Phase 198-203 plan was then **orphaned** by v1.41 reusing phase
numbers 199-204. Without this recorded in-repo, the next person to open SEED-005 re-runs a
"boil the ocean" playbook whose output already exists on disk.

Output: one edited seed, two new pending todos. **Planning artifacts only.**

Tracer-first decomposition does not apply here — this change has no layers to wire; it is three
independent documentation writes. Task 1 carries the load-bearing content and runs first.

HARD CONSTRAINTS for the executor:
- Do **not** modify any workflow file, script, spec, `mix.exs`, or any source file. This plan
  touches exactly the three files in `files_modified`.
- Do **not** push, do **not** open a PR, do **not** create a tag. Commit locally only.
- Task 1 targets a 1009-line file. Use **Edit**, never Write, on that file.
- Do not read, quote, reformat, or re-indent anything at or below the `---` separator that
  precedes the verbatim playbook. It is preserve-verbatim and consumes context for no benefit.
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/todos/pending/2026-07-28-gate-ci-green-timeout-too-tight-for-push-to-main.md
</context>

<tasks>

<task type="auto">
  <name>Task 1: Insert the 2026-07-28 addendum into SEED-005 above the verbatim playbook</name>
  <files>.planning/seeds/SEED-005-ci-cd-pipeline-performance-audit.md</files>
  <read_first>
Read ONLY lines 195-215 of the seed (Read with offset 195, limit 21) to load the anchor region.
The file is 1009 lines; lines 210+ are a verbatim audit playbook. Do not read past line 215.
  </read_first>
  <action>
Use the **Edit** tool (NOT Write) on `.planning/seeds/SEED-005-ci-cd-pipeline-performance-audit.md`.

The insertion point is unambiguous. `old_string` is exactly these four lines (verified unique,
one occurrence each):

the line `&gt; See the audit report for the full prioritized Phase 198→203 plan.`
then a blank line
then the line `---`
then a blank line
then the line `The full inflated companion prompt to use as the audit playbook:`

`new_string` is that same block with the new addendum spliced between the closing blockquote
line and the `---`. Net effect: the addendum lands AFTER the bracketed CORRECTION blockquote and
BEFORE the `---` separator, so the verbatim playbook remains the last thing in the file.

Preserve-verbatim, do not touch: the scope guardrails section, Jon's verbatim framing prompt,
the Addendum 2026-06-20 section, the CORRECTION blockquote, and everything from the `---`
separator to EOF. The edit must be purely additive — zero deleted lines.

The inserted content is exactly the following (blank line before the heading, blank line after
the final line, so the surrounding structure stays intact):

## Addendum 2026-07-28 — re-measured; the audit's plan was orphaned, not executed

**Headline: the audit is finished. Its plan was orphaned, not executed.**
`.planning/research/SEED-005-CICD-AUDIT-2026-06-20.md` is a completed multi-lens audit that
already contains a prioritized **Phase 198 → 203** sequence. Only **Phase 198 partially ran**
(the `mix ci` alias, the CONTRIBUTING documentation, and acceptance evidence). **Phases 199-203
were never built** — v1.41 ADMIN-UX-ELEVATION reused phase numbers 199-204 for unrelated admin
work, orphaning the audit's sequence. The backlog for this seed is therefore **already fully
derived and sitting on disk, unexecuted**. Whoever picks this up should **execute the audit**,
not re-run the playbook below.

### The audit is still accurate — verified 2026-07-28

Re-measurement confirms the 2026-06-20 findings rather than superseding them:

- It named `design_gallery` at ~700s; re-measured it is **734s**.
- `admin-design.spec.ts:250-255` still calls `registerUser()` in `beforeEach` with no
  `storageState`, so **P0-1** (−6 to −7.5 min, Low risk, **zero coverage loss**) remains
  unimplemented.
- Also still open from the audit: no `concurrency:` block in `ci.yml`; the `ci` alias at
  `mix.exs:143` lacks format and deps-lock checks; `release-please.yml:88` is unpinned;
  `.github/dependabot.yml` covers `github-actions` only.

### Re-measured baseline (last 40 runs, 2026-07-28)

| trigger | n | mean | p50 | max | outcomes |
| --- | --- | --- | --- | --- | --- |
| pull_request | 21 | 29.5m | 27.3m | 41.7m | 17 pass / 4 fail |
| push (main) | 7 | 30.5m | 27.6m | 42.3m | 6 pass / 1 fail |
| schedule (nightly) | 9 | 27.3m | 27.1m | 29.4m | 0 pass / 9 fail |

Plainly: **a PR burns ~56 runner-minutes for a 25.6m wall; a push ~92 runner-minutes for 35m.**
**The nightly has been 9-for-9 red.**

### Critical path

`example_playwright_smoke` (**23m on PR / 26m on push**), decomposed from run `30387042239`:

- design gallery boards — **734s (53% of the job)**
- admin behavior browser truth — 224s
- non-admin example smoke — 187s
- admin checkpoints — 130s
- Playwright browser install — 62s (**never cached**)
- everything else — ~50s

The example app compiles in **1s on a cache hit**, so setup is *not* the cost. This job is
dominated by test execution, which means **it responds to sharding**.

### Waste not covered by the 2026-06-20 audit

- **No `concurrency:` block**, so superseded PR runs complete anyway. Evidence: runs
  `30387042239` and `30387550888` — same branch, 7 minutes apart, both ran to completion.
- **No path filters**, so a docs-only PR runs the full 21-job matrix.
- **Playwright browsers are never cached** — 62s × 4-5 jobs, every run.
- **`admin_design_recapture` runs 18m per push and discards its output**, because its commit/PR
  step is gated on `workflow_dispatch`.
- **The example boot prelude is duplicated verbatim across 6 jobs.**

### Locked decisions (2026-07-28)

- **Design-gallery boards move off the PR gate**, kept on main + nightly. Move the *snapshots*;
  preserve the a11y assertions on PR.
- **`admin_eval_render` is demoted to nightly, then fixed** (see the dedicated todo).
- **Two-tier shape:** measured quick wins first, then execute the orphaned audit phases.
- **Tier-2 breadth is perf + hygiene.** Credo, Dialyzer, and mix_audit are **deferred as new
  gates** — this milestone does not add them.
- **The 9/9-red nightly is P0**, because a dead gate is worse than no gate.

### Target

v1.40 took PR wall-clock from 38.6m to 22.1m (−43%), but it disclosed its `&lt;12m` aspiration as
unmet and explicitly deferred Playwright sharding. The 2026-07-28 evidence shows **`&lt;12m` is
reachable**. Proposed phases **230-235**.
  </action>
  <verify>
    <automated>
node -e "const t=require('fs').readFileSync('.planning/seeds/SEED-005-ci-cd-pipeline-performance-audit.md','utf8').split('\n'); const h=t.findIndex(l=&gt;l.startsWith('## Addendum 2026-07-28')); const c=t.findIndex(l=&gt;l.includes('CORRECTION (audit executed 2026-06-20')); const p=t.findIndex(l=&gt;l.includes('The full inflated companion prompt')); if(!(c&gt;-1 &amp;&amp; h&gt;c &amp;&amp; p&gt;h)) throw new Error('addendum not between CORRECTION and playbook: c='+c+' h='+h+' p='+p); console.log('ORDER OK', c, h, p)"
test "$(git diff --numstat -- .planning/seeds/SEED-005-ci-cd-pipeline-performance-audit.md | awk '{print $2}')" = "0" &amp;&amp; echo "PURELY ADDITIVE OK"
grep -c 'Phase 198 → 203' .planning/seeds/SEED-005-ci-cd-pipeline-performance-audit.md
grep -c '30387550888' .planning/seeds/SEED-005-ci-cd-pipeline-performance-audit.md
grep -c '9-for-9 red' .planning/seeds/SEED-005-ci-cd-pipeline-performance-audit.md
grep -c 'Proposed phases' .planning/seeds/SEED-005-ci-cd-pipeline-performance-audit.md
    </automated>
  </verify>
  <done>
The addendum heading sits between the CORRECTION blockquote and the playbook line (order check
passes). `git diff --numstat` reports **0 deleted lines** for the seed, proving the playbook,
Jon's framing, and the scope guardrails are byte-identical. All four content greps return 1 or
more. No file other than the seed is modified by this task.
  </done>
</task>

<task type="auto">
  <name>Task 2: File the admin_eval_render unread-red todo</name>
  <files>.planning/todos/pending/2026-07-28-admin-eval-render-burns-17m-per-pr-for-an-unread-red.md</files>
  <action>
Create the file with the Write tool. Match the frontmatter shape of
`2026-07-28-gate-ci-green-timeout-too-tight-for-push-to-main.md` exactly (same keys, same
order): `created` (ISO `2026-07-28T00:00:00.000Z`), `status: pending`, a quoted `title`,
`area: ci`, a `files:` list, `severity: high`, `source:` naming the 2026-07-28 CI fan-out
investigation that scoped the v1.47 CI-EFFICIENCY milestone.

`files:` should list `.github/workflows/ci.yml`, `scripts/ci/admin-eval-harness.sh`, and the
admin-eval Playwright config/spec surface the job launches.

Body sections, mirroring the reference todo's rhythm (What / Evidence / Why this is structural /
Recommended fix (NOT implemented by this todo)):

**What.** `admin_eval_render` (`ci.yml:2102-2237`) runs on **every PR with no `if:` gate**,
takes **~17m**, and failed **6 of 6** sampled runs. Nothing consumes the result:
it is `continue-on-error: true`; it is **not** in `ci-gate.needs` (`ci.yml:1464-1473`); it is
**not** one of the 5 required contexts in ruleset `14941512`; and there is **no
`download-artifact` anywhere in the repo** that reads its bundles — they expire unread after 7
days. So the repo pays ~17m of runner time per PR for output no human and no job ever sees.

**Evidence — two root causes**, both from job log `90369119561` (`76 failed, 116 passed (16.1m)`):

1. **Configuration bug.** The `admin-eval-mobile` project uses the `iPhone 13` device preset,
   which is **WebKit**, but the job installs **chromium only** (`ci.yml:2179`, whose own comment
   asserts "admin-eval uses chromium" — factually wrong for one of the three projects it
   launches). All **64** `admin-eval-mobile` tests fail in ~2ms with
   `browserType.launch: Executable doesn't exist at /home/runner/.cache/ms-playwright/webkit-2272/pw_run.sh`,
   each retrying once, producing **128 failure lines**. Every other Playwright job in this repo
   installs `chromium webkit`.
2. **Probe bug.** `el.className.includes is not a function` — on an SVG element `className` is an
   `SVGAnimatedString`, not a string. It fires inside a `page.evaluate` on boards `board-mg-2`
   (all 4 states), `board-task_card`, `board-summary_chip`, `board-applied_chip`,
   `board-field_help`, `board-skeleton`, and `board-audit_row`.

**Why this is structural, not bad luck — the silent part.** State this explicitly: because
harness phase (a) fails under `set -euo pipefail`, `scripts/ci/admin-eval-harness.sh` **aborts
before phases (a2) and (b1)-(b6)**, so **those guards have never executed in CI** for as long as
this lane has been red. Four of them — `quality-findings-monotonic.sh`, `award-guard.mjs`,
`settled-findings-lint.sh`, `evidence-anchor-check.mjs` — are independently wired into
`fast_checks` and are green there, so the real exposure is narrow but not zero:
**`stale-render-guard.sh` runs nowhere else.**

**Recommended fix (NOT implemented by this todo).** Record the diagnosis only; change nothing in
`.github/` or `scripts/`. Recommend: demote the job to non-PR (nightly/main), then fix both bugs
— install `chromium webkit`, and read the class list via `getAttribute('class')` or
`el.classList` rather than `className` — and confirm that phases b1-b6 actually run afterward.
Cross-reference the v1.47 CI-EFFICIENCY scope, where this is a locked demote-then-fix decision,
and the SEED-005 2026-07-28 addendum.
  </action>
  <verify>
    <automated>
node -e "const f='.planning/todos/pending/2026-07-28-admin-eval-render-burns-17m-per-pr-for-an-unread-red.md';const t=require('fs').readFileSync(f,'utf8');const m=t.match(/^---\n([\s\S]*?)\n---\n/);if(!m)throw new Error('missing frontmatter');for(const k of ['created','status','title','area','files','severity','source'])if(!new RegExp('^'+k+':','m').test(m[1]))throw new Error('missing key '+k);if(!/^area: ci$/m.test(m[1]))throw new Error('area must be ci');if(!/^severity: high$/m.test(m[1]))throw new Error('severity must be high');console.log('FRONTMATTER OK')"
grep -c '90369119561' .planning/todos/pending/2026-07-28-admin-eval-render-burns-17m-per-pr-for-an-unread-red.md
grep -c 'SVGAnimatedString' .planning/todos/pending/2026-07-28-admin-eval-render-burns-17m-per-pr-for-an-unread-red.md
grep -c 'stale-render-guard.sh' .planning/todos/pending/2026-07-28-admin-eval-render-burns-17m-per-pr-for-an-unread-red.md
grep -c '14941512' .planning/todos/pending/2026-07-28-admin-eval-render-burns-17m-per-pr-for-an-unread-red.md
    </automated>
  </verify>
  <done>
The todo exists with valid frontmatter carrying `area: ci` and `severity: high`, in the same key
order as the reference todo. All four content greps return 1 or more. The body names both root
causes with their line/log citations, states that harness phases a2 and b1-b6 have never run in
CI, isolates `stale-render-guard.sh` as the sole uncovered guard, and recommends without
implementing. No workflow, script, or spec file was modified.
  </done>
</task>

<task type="auto">
  <name>Task 3: File the generated-host-parity skipped-passes-gate todo</name>
  <files>.planning/todos/pending/2026-07-28-generated-host-parity-verified-on-no-pr-while-gate-reports-green.md</files>
  <action>
Create the file with the Write tool, same frontmatter shape and key order as Task 2
(`created: 2026-07-28T00:00:00.000Z`, `status: pending`, quoted `title`, `area: ci`,
`files:` listing `.github/workflows/ci.yml` and `.github/workflows/release-please.yml`,
`severity: high`, `source:` naming the same 2026-07-28 CI fan-out investigation).

Body:

**What.** `generated_admin_playwright_smoke` (`ci.yml:1338`) is gated on
`github.event_name != 'pull_request'` **OR** `github.head_ref == 'ship/v1.42-ci-gate-remediation'`,
carrying a comment that calls it a "temporary integration-scoped relaxation ... remove after
merge". **That branch merged long ago.** On every real PR the expression is therefore false and
the job resolves to `skipped`. The job **is** in `ci-gate.needs`, and `ci-gate` treats `skipped`
as a pass (`ci.yml:1501-1505` — the check only fails when a result is neither `success` nor
`skipped`). Net effect, stated plainly: **generated-host parity is verified on no PR whatsoever,
while the gate reports green.**

**Blast radius.** The same skipped-is-pass semantics let `upgrade_smoke` pass unverified on PRs
too, so `ci-gate` on a pull request only ever asserts **7 of its 9 lanes**. Note also that
`ci-gate` is **itself not a required context** — ruleset `14941512` requires exactly 5 lane names
— so its assertions gate nothing directly; its only consumer is `gate-ci-green` in
`release-please.yml`. A rotted `if:` on a needed job is thus invisible twice over.

**Recommended fix (NOT implemented by this todo).** Record the diagnosis only; change nothing in
`.github/`. Recommend: (1) remove the stale `head_ref` clause now that its branch is merged, and
(2) decide deliberately whether `ci-gate` should distinguish **"skipped because correctly gated
for this event"** from **"skipped because its gate rotted"** — an allowlist of legitimately
event-gated lanes is one shape; failing on `skipped` for lanes not on that list is another.
Cross-reference the v1.47 CI-EFFICIENCY scope and
`.planning/todos/pending/2026-07-28-gate-ci-green-timeout-too-tight-for-push-to-main.md`, which
is the other half of the release-gate story.
  </action>
  <verify>
    <automated>
node -e "const f='.planning/todos/pending/2026-07-28-generated-host-parity-verified-on-no-pr-while-gate-reports-green.md';const t=require('fs').readFileSync(f,'utf8');const m=t.match(/^---\n([\s\S]*?)\n---\n/);if(!m)throw new Error('missing frontmatter');for(const k of ['created','status','title','area','files','severity','source'])if(!new RegExp('^'+k+':','m').test(m[1]))throw new Error('missing key '+k);if(!/^area: ci$/m.test(m[1]))throw new Error('area must be ci');if(!/^severity: high$/m.test(m[1]))throw new Error('severity must be high');console.log('FRONTMATTER OK')"
grep -c 'ship/v1.42-ci-gate-remediation' .planning/todos/pending/2026-07-28-generated-host-parity-verified-on-no-pr-while-gate-reports-green.md
grep -c '7 of its 9 lanes' .planning/todos/pending/2026-07-28-generated-host-parity-verified-on-no-pr-while-gate-reports-green.md
grep -c 'gate-ci-green-timeout-too-tight-for-push-to-main' .planning/todos/pending/2026-07-28-generated-host-parity-verified-on-no-pr-while-gate-reports-green.md
git status --porcelain -- .github scripts mix.exs test lib priv | head
    </automated>
  </verify>
  <done>
The todo exists with valid `area: ci` / `severity: high` frontmatter. All three content greps
return 1 or more. `git status --porcelain` over `.github`, `scripts`, `mix.exs`, `test`, `lib`,
and `priv` prints nothing, proving no code or workflow file was touched by this plan.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| (none crossed) | This plan writes only Markdown under `.planning/`. No code path, no request handler, no data store, and no CI-executed file is modified. |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-260728kub-01 | Tampering | `.planning/seeds/SEED-005-ci-cd-pipeline-performance-audit.md` (1009 lines, contains preserve-verbatim content) | medium | mitigate | Executor must use Edit with the unique 4-line anchor, never Write. Task 1 verify asserts `git diff --numstat` reports 0 deleted lines, which fails loudly if the playbook or guardrails are altered. |
| T-260728kub-02 | Information Disclosure | New todos quote CI run IDs, job log IDs, ruleset ID `14941512`, and internal file paths | low | accept | All values are already present in this repo's own history and workflow files; `.planning/` is asserted absent from published Hex tarballs by `hex-publish.yml`. |
| T-260728kub-03 | Tampering | Supply chain (npm/pip/cargo) | n/a | accept | No package-manager install occurs in this plan; no dependency is added or resolved. Package Legitimacy Gate not applicable. |
| T-260728kub-04 | Elevation of Privilege | Remote repo state (push / PR / tag) | medium | mitigate | Objective forbids push, PR, and tag. Commit is local-only. |
</threat_model>

<verification>
1. `git status --porcelain` lists exactly the three files in `files_modified` (one `M`, two `??`
   before commit) and nothing else.
2. `git diff --numstat -- .planning/seeds/SEED-005-ci-cd-pipeline-performance-audit.md` shows a
   deletions count of `0`.
3. `git log --oneline -1` shows a single local commit; `git status -sb` shows the branch is
   **not** pushed (ahead of origin, no PR created, no tag).
</verification>

<success_criteria>
- SEED-005 carries the `## Addendum 2026-07-28 — re-measured; the audit's plan was orphaned, not executed`
  section, positioned after the CORRECTION blockquote and before the `---` that precedes the
  verbatim playbook.
- The addendum contains all seven required elements: the orphaned-audit headline, the
  still-accurate verification, the 40-run baseline table reproduced verbatim, the
  `example_playwright_smoke` critical-path decomposition, the newly-found waste, the locked
  2026-07-28 decisions, and the `<12m` target with proposed phases 230-235.
- Zero lines deleted from SEED-005.
- Both todos exist under `.planning/todos/pending/` with the exact filenames in `files_modified`,
  `area: ci`, `severity: high`, and frontmatter matching the house style of
  `2026-07-28-gate-ci-green-timeout-too-tight-for-push-to-main.md`.
- Each todo states its recommendation as **not implemented** and cross-references the v1.47
  CI-EFFICIENCY scope.
- No workflow, script, spec, `mix.exs`, or source file changed.
- Work is committed locally with a `docs(quick):` message. Not pushed, no PR, no tag.
</success_criteria>

<output>
Create `.planning/quick/260728-kub-refresh-seed-005-with-2026-07-28-ci-base/260728-kub-SUMMARY.md` when done.
</output>
