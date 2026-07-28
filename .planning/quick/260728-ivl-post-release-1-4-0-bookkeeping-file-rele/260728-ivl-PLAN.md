---
phase: quick-260728-ivl
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - .planning/todos/pending/2026-07-28-gate-ci-green-timeout-too-tight-for-push-to-main.md
  - .planning/todos/pending/2026-07-28-release-lane-rot-label-missing-breaks-hard-02-signal.md
  - .planning/STATE.md
autonomous: true
requirements: [QUICK-260728-ivl]
must_haves:
  truths:
    - "Whoever picks up the gate-ci-green timeout defect can go straight to the fix: the todo carries the release SHA, both run IDs, the timestamps that prove the poller gave up ~1 minute before the green CI run finished, and the structural reason a push-to-main run outlasts a 30-minute ceiling."
    - "Whoever picks up the release-lane-rot defect learns that HARD-02's loud signal was silent on its first real firing, that the label has already been created as an immediate mitigation, and that the durable fix is to make the shared notify script self-healing."
    - "The release-lane-rot todo records that the blast radius includes ci.yml's red-ci-gate notifier, not just the release lane, because both call the same shared script."
    - "The working hex-publish recovery dispatch is recorded verbatim so a future operator does not have to re-derive it."
    - "STATE.md's Quick Tasks Completed table carries a 260728-glj row in the existing 4-column shape, and preserves why the row was deliberately written late."
    - "STATE.md's last-activity signal reads 2026-07-28 and names the 1.4.0 Hex release."
    - "No workflow file, script, mix.exs, CHANGELOG.md, or source file is modified — this is a planning-artifact-only change."
  artifacts:
    - .planning/todos/pending/2026-07-28-gate-ci-green-timeout-too-tight-for-push-to-main.md
    - .planning/todos/pending/2026-07-28-release-lane-rot-label-missing-breaks-hard-02-signal.md
    - .planning/STATE.md
  key_links:
    - "scripts/ci/notify-failure-issue.sh is invoked by BOTH .github/workflows/release-please.yml (notify-release-failure) and .github/workflows/ci.yml (Notify on red ci-gate) — one missing label broke the signal on both lanes (Phase 222 HARD-02)."
    - "gate-ci-green gates publish-hex via `needs`; its timeout skipped the publish job, leaving tag v1.4.0 and a GitHub Release with nothing on Hex until the manual dispatch."
    - "STATE.md `## Quick Tasks Completed` has columns Quick ID | Task | Status | Date — no Commit and no Directory column."
---

<objective>
Post-release bookkeeping for the Sigra 1.4.0 Hex publish: file two pending todos capturing the two
release-lane defects diagnosed during the recovery, and record quick task `260728-glj` in
`.planning/STATE.md`.

Purpose: 1.4.0 was published today (2026-07-28T17:31:35Z, tag v1.4.0 at cfc5e6b8) but NOT through
the automated path — the release-please auto-publish chain failed and was recovered by manually
dispatching `.github/workflows/hex-publish.yml` (run 30382271344, all 23 steps green). Both defects
behind that failure are already root-caused. This plan captures the diagnosis so the next person goes
straight to the fix instead of re-investigating from run logs that will age out. The `260728-glj`
STATE row was deliberately skipped at the time for a merge-safety reason that is now resolved.

Output: two new files under `.planning/todos/pending/` and a scoped edit to `.planning/STATE.md`.

Scope guard — this plan is planning-artifact-only. It does NOT edit any workflow, any script,
`mix.exs`, `CHANGELOG.md`, or any source file. It does NOT push, does NOT open, edit, or merge a PR,
and does NOT create or move a tag. The orchestrator owns the PR.
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@CLAUDE.md

Verified facts from planning discovery — do not re-derive these:

- Branch is `post-release-1.4.0-bookkeeping`, based on post-release `origin/main` (cfc5e6b8), tree clean.
- Todo front-matter house keys (from a survey of the 22 pending todos): `created`, `status`, `title`,
  `area`, `files`, `source` are near-universal; `severity` appears in 11 of 22 and IS established
  house style — use it, do not invent new keys.
- `.planning/STATE.md` is 571 lines. `## Quick Tasks Completed` is at line 343, its header row
  `| Quick ID | Task | Status | Date |` at line 345, its LAST existing data row is `260727-v15` at
  line 382, and `## Deferred Items` follows at line 384. There is NO Commit column and NO Directory
  column — do not add one.
- The body `Last activity:` line is line 36, inside `## Current Position`.
- Front-matter mirrors of the same fact are `last_updated` (line 9), `last_activity` (line 10), and
  `last_activity_desc` (line 11).
- `.planning/todos/pending/2026-07-28-release-please-orphans-unreleased-block.md` already exists and
  is a DIFFERENT defect (release-please orphaning the hand-written `## Unreleased` block). Do not
  duplicate it and do not cross-reference it — the failure modes are unrelated.
</context>

<tasks>

<task type="tracer">
  <name>Task 1: File both release-lane defect todos</name>
  <files>.planning/todos/pending/2026-07-28-gate-ci-green-timeout-too-tight-for-push-to-main.md, .planning/todos/pending/2026-07-28-release-lane-rot-label-missing-breaks-hard-02-signal.md</files>
  <precondition>Working tree is clean on branch `post-release-1.4.0-bookkeeping` before editing; confirm with `git status --porcelain` and `git branch --show-current`.</precondition>
  <read_first>
    Read `.planning/todos/pending/2026-07-27-playwright-github-pages-publisher-red.md` ONCE to copy the
    front-matter shape (it carries `severity`) and the What / evidence / options body rhythm.

    Then confirm the two code references you are about to cite, read-only, so the todos do not record
    stale line numbers:
    - `grep -n 'LABEL\|gh issue create' scripts/ci/notify-failure-issue.sh`
    - `grep -n 'max_attempts\|wait_seconds\|gate-ci-green\|Timed out waiting' .github/workflows/release-please.yml`
    - `grep -n 'release-lane-rot' .github/workflows/ci.yml .github/workflows/release-please.yml`
    If an observed value differs from the value stated in this plan, record the OBSERVED value in the
    todo and note the discrepancy in the summary. Reading these files is expected; editing any of them
    is out of scope for this entire plan.
  </read_first>
  <action>
Create exactly two new files under `.planning/todos/pending/`. Write nothing else.

FILE A — `2026-07-28-gate-ci-green-timeout-too-tight-for-push-to-main.md`

Front matter: `created: 2026-07-28T00:00:00.000Z`, `status: pending`, a `title` naming the defect (the
`gate-ci-green` polling ceiling is shorter than the push-to-main CI run it waits for, which blocks the
automated Hex publish), `area: release`, a `files` list naming `.github/workflows/release-please.yml`
(and `.github/workflows/ci.yml` as the run being waited on), `severity: high`, and a `source` line
attributing this to the 2026-07-28 quick task and the 1.4.0 publish recovery.

Body must record, in this order:

1. WHAT — the `gate-ci-green` job in `.github/workflows/release-please.yml` polls for a successful
   `ci-gate` on the release SHA with max_attempts 60 at wait_seconds 30, i.e. a hard 30-minute ceiling.
   On 1.4.0 it timed out on a release that was actually green, blocking the automated Hex publish for
   no good reason.

2. EVIDENCE — state each of these as a checkable fact:
   - Release SHA `cfc5e6b88e1e95403c488fc518fd6f5469a9b015` (tag v1.4.0).
   - ci.yml run 30379435985 (event push, branch main) started 2026-07-28T16:41:34Z and concluded
     success; its `ci-gate` job also concluded success.
   - gate-ci-green in release-please run 30379435970 logged that it gave up waiting for `ci-gate` on
     that SHA at 2026-07-28T17:16:37Z and exited 1 — roughly one minute BEFORE the very run it was
     waiting on finished.
   - Consequence: `publish-hex` was skipped because its `needs` were unmet, so the tag and the GitHub
     Release existed with nothing on Hex.

3. WHY IT IS STRUCTURAL, NOT BAD LUCK — this is the key insight, so state it plainly and give it its
   own section. A push-to-`main` ci.yml run is strictly heavier than the `pull_request` run that gates
   the Release PR, because jobs such as the in-CI admin-design baseline recapture are skipped on
   `pull_request` but run on `push`. Observed on the same content: the pull_request run (30376746574)
   took about 25 minutes; the push-to-main run took about 35 minutes (16:41:34 to roughly 17:16),
   including about 4 minutes of queue time before any job started. The 30-minute ceiling is therefore
   below the expected duration of the run it waits for, so every future release hits this until the
   ceiling changes.

4. RECOMMENDED FIX — label it clearly as a recommendation that is NOT implemented by this todo. Raise
   max_attempts so the ceiling lands at 45 to 60 minutes (roughly 90 to 120 attempts at the existing
   30-second interval), and consider having the give-up message name the run URL it abandoned. Note
   that the workflow already dispatches ci.yml on the tag at attempt 3 when no run exists, so the
   retry scaffolding itself is sound — only the ceiling is wrong.

5. WORKING RECOVERY — record the exact dispatch that shipped 1.4.0 so it need not be re-derived:
   `gh workflow run hex-publish.yml -f tag=v1.4.0 -f release_version=1.4.0 -f dry_run=false`
   (run 30382271344, all 23 steps green). Note what that workflow independently re-verifies before it
   writes to Hex: tag/version match, tag-commit provenance, the `@version` in mix.exs, agreement with
   `.release-please-manifest.json`, `source_ref`, a full unsharded `mix test`, `mix docs` with
   warnings-as-errors, and tarball contents (asserting `.planning` is absent) — and that it dry-runs
   before publishing and is idempotent, skipping if the version is already on Hex.

FILE B — `2026-07-28-release-lane-rot-label-missing-breaks-hard-02-signal.md`

Front matter: `created: 2026-07-28T00:00:00.000Z`, `status: pending`, a `title` naming the defect (the
HARD-02 loud-failure signal never worked because the GitHub label it depends on did not exist),
`area: release`, a `files` list naming `scripts/ci/notify-failure-issue.sh`,
`.github/workflows/release-please.yml`, and `.github/workflows/ci.yml`, `severity: high`, and a
`source` line attributing this to the 2026-07-28 quick task and the 1.4.0 publish recovery.

Body must record, in this order:

1. WHAT — the Phase 222 HARD-02 "fail loudly, no silent rot" mechanism has never actually worked,
   because the GitHub label it depends on did not exist in the repository.

2. EVIDENCE:
   - `scripts/ci/notify-failure-issue.sh` (around line 33) creates the tracking issue with a
     `--label "$LABEL"` argument, where LABEL is set to the release-lane rot label name.
   - On the 1.4.0 release the `notify-release-failure` job in run 30379435970 fired CORRECTLY — it
     detected the gate-ci-green failure and emitted a workflow error annotation naming the failed
     publish/gate for v1.4.0 — and then died because the label could not be added (label not found),
     exiting 1.
   - Net effect: ZERO tracking issues were created; `gh issue list --state open` returned empty. The
     loud signal was silent, which is exactly the failure mode Phase 222 built this to prevent. This
     was HARD-02's first real firing.
   - Blast radius is wider than the release lane: `.github/workflows/ci.yml` has a notify job for a red
     `ci-gate` on main that calls the same shared script, so any red ci-gate on main has also been
     failing to raise an issue.

3. MITIGATION ALREADY APPLIED (record as DONE, dated 2026-07-28) — the label was created with
   `gh label create release-lane-rot --description "Release/CI lane failed to complete (HARD-02 loud signal from notify-failure-issue.sh)" --color b60205`.
   That unblocks the mechanism immediately but does not prevent recurrence, which is why this todo is
   about the durable fix.

4. RECOMMENDED DURABLE FIX — label it clearly as a recommendation that is NOT implemented by this
   todo. Preferred: make `scripts/ci/notify-failure-issue.sh` self-healing by creating the label when
   `gh label list` shows it is absent, before creating the issue, so a fresh clone or a deleted label
   cannot re-break the signal. Second option worth noting: drop the label argument from the create call
   and apply the label afterwards via `gh issue edit` allowed to fail soft, so a label problem can
   never suppress the issue itself.

5. LESSON — include a line stating the deeper point: a fail-loudly mechanism that has never been
   exercised is not known to work. Phase 222 verified this path with a dry-run / red-probe but
   evidently not against a real issue creation.

Both files are new; use the Write tool for each. Do not touch any existing file in this task. Do not
modify `.planning/todos/pending/2026-07-28-release-please-orphans-unreleased-block.md` and do not
cross-reference it — it is a separate, unrelated defect.
  </action>
  <verify>
    <automated>
# 1. Both files exist
test -f .planning/todos/pending/2026-07-28-gate-ci-green-timeout-too-tight-for-push-to-main.md && echo "A: OK"
test -f .planning/todos/pending/2026-07-28-release-lane-rot-label-missing-breaks-hard-02-signal.md && echo "B: OK"

# 2. House front matter present on both (created/status/title/area/files/severity/source)
for f in .planning/todos/pending/2026-07-28-gate-ci-green-timeout-too-tight-for-push-to-main.md \
         .planning/todos/pending/2026-07-28-release-lane-rot-label-missing-breaks-hard-02-signal.md; do
  echo "== $f"
  awk 'BEGIN{n=0} /^---$/{n++; if(n==2) exit; next} n==1 && /^[a-z_]+:/{print $1}' "$f"
done
# EXPECT each block to list: created: status: title: area: files: severity: source:

# 3. Todo A carries the load-bearing evidence
A=.planning/todos/pending/2026-07-28-gate-ci-green-timeout-too-tight-for-push-to-main.md
grep -cF 'cfc5e6b88e1e95403c488fc518fd6f5469a9b015' "$A"   # EXPECT >= 1
grep -cF '30379435985' "$A"                                 # EXPECT >= 1  (green ci.yml run)
grep -cF '30379435970' "$A"                                 # EXPECT >= 1  (release-please run that gave up)
grep -cF '30376746574' "$A"                                 # EXPECT >= 1  (25-min pull_request comparator)
grep -cF '2026-07-28T17:16:37Z' "$A"                        # EXPECT >= 1
grep -cF '2026-07-28T16:41:34Z' "$A"                        # EXPECT >= 1
grep -cF 'gh workflow run hex-publish.yml -f tag=v1.4.0 -f release_version=1.4.0 -f dry_run=false' "$A"  # EXPECT 1
grep -ci 'pull_request' "$A"                                # EXPECT >= 1  (structural, not bad luck)

# 4. Todo B carries the load-bearing evidence
B=.planning/todos/pending/2026-07-28-release-lane-rot-label-missing-breaks-hard-02-signal.md
grep -cF 'notify-failure-issue.sh' "$B"                     # EXPECT >= 1
grep -cF '30379435970' "$B"                                 # EXPECT >= 1
grep -cF 'gh label create release-lane-rot' "$B"            # EXPECT 1  (mitigation recorded as done)
grep -cF 'ci.yml' "$B"                                      # EXPECT >= 1  (blast radius beyond release lane)
grep -ci 'HARD-02' "$B"                                     # EXPECT >= 1

# 5. The pre-existing sibling todo is untouched and not referenced
git diff --quiet -- .planning/todos/pending/2026-07-28-release-please-orphans-unreleased-block.md && echo "sibling untouched: OK"

# 6. Blast radius: nothing outside .planning/ has been touched
git status --porcelain | awk '{print $NF}' | grep -v '^\.planning/' | wc -l   # EXPECT 0
    </automated>
  </verify>
  <done>
    Both todo files exist with house front matter including `severity: high`, each records its defect
    with the run IDs and timestamps that make it re-checkable, each labels its fix as a recommendation
    rather than an applied change, the hex-publish recovery dispatch is captured verbatim in todo A,
    the already-applied label creation is captured as done in todo B, and no file outside `.planning/`
    has been modified.
  </done>
  <reversibility rating="reversible">Two new planning-artifact files on a local branch; deleting them restores the prior state exactly.</reversibility>
</task>

<task type="auto">
  <name>Task 2: Record quick task 260728-glj and refresh the last-activity signal in STATE.md</name>
  <files>.planning/STATE.md</files>
  <precondition>`.planning/STATE.md` is at its committed state (`git diff --quiet -- .planning/STATE.md` exits 0) before editing, so the append anchor and line references below still hold.</precondition>
  <read_first>
    `.planning/STATE.md` is 571 lines — read only what you need with offsets, and edit it with the Edit
    tool ONLY. Never rewrite this file with Write; a whole-file write would destroy the ~500 lines of
    accumulated context you did not read.

    Read lines 1-40 (front matter plus `## Current Position`) and lines 343-386 (the
    `## Quick Tasks Completed` header, its final rows, and the `## Deferred Items` boundary). That is
    enough — do not read the middle of the file.
  </read_first>
  <action>
Make exactly two scoped edits to `.planning/STATE.md`, both with the Edit tool.

EDIT 1 — append one row to the `## Quick Tasks Completed` table.

Insert it immediately AFTER the existing `260727-v15` row (the current last data row, near line 382)
and BEFORE the `## Deferred Items` heading. Match the existing 4-column shape exactly:
Quick ID, Task, Status, Date. There is no Commit column and no Directory column — do not add one, and
do not alter the header row or any existing row.

The new row's cells:
- Quick ID: `260728-glj`
- Task: prose recording that it folded the hand-written Unreleased block in CHANGELOG.md into the
  release-please-generated 1.4.0 section, so the v1.46 adopter-experience content shipped INSIDE the
  1.4.0 Hex release instead of remaining under a heading reading Unreleased inside a released package;
  that it added a maintainer warning comment against recurrence; AND — this part must be preserved —
  why the row is being written late: the work ran on the release-please branch, which forked from
  743864c0, before the v1.46 close-out commit e6f7a413, so that branch's STATE.md was 47 lines behind
  main and editing it there risked reverting close-out content at merge. Main now contains both, so
  the row can be added safely here.
- Status: `complete ✓`
- Date: `2026-07-28`

Write the Task cell as a single line with no literal pipe characters inside it (a pipe would split the
cell and corrupt the table).

EDIT 2 — refresh the last-activity signal to today.

Replace the body `Last activity:` line in `## Current Position` (line 36) so it reads 2026-07-28 and
names the 1.4.0 Hex release: Sigra 1.4.0 published to Hex from tag v1.4.0 at cfc5e6b8 via a manual
hex-publish dispatch after the release-please auto-publish chain failed, with two release-lane defect
todos filed. Update the three front-matter mirrors of that same fact to agree: `last_updated` to the
2026-07-28 ISO timestamp in the existing quoted format, `last_activity` to `2026-07-28`, and
`last_activity_desc` to a one-line version of the same statement. Leaving the mirrors stale would
contradict the body line they exist to mirror.

Change nothing else in the file. In particular leave `milestone`, `milestone_name`, `current_phase`,
`current_phase_name`, `status`, `stopped_at`, and the whole `progress` block exactly as they are —
the project is still between milestones and this bookkeeping does not change that. Do not touch
`## Accumulated Context`, `## Deferred Items`, `## Session Continuity`, `## Operator Next Steps`, or
`## Performance Metrics`.
  </action>
  <verify>
    <automated>
S=.planning/STATE.md

# 1. Exactly one new row, with the right status and date cells
grep -c '^| 260728-glj |' "$S"                                      # EXPECT 1
grep -c '^| 260728-glj |.*| complete ✓ | 2026-07-28 |$' "$S"        # EXPECT 1

# 2. Column count matches the table header (no invented Commit/Directory column)
awk -F'|' '/^\| Quick ID \| Task \| Status \| Date \|$/{h=NF} /^\| 260728-glj \|/{r=NF} END{print "header="h" row="r}' "$S"
# EXPECT header and row to be the SAME number

# 3. Row is positioned after the last existing row and before the Deferred Items heading
grep -n '^| 260727-v15 |\|^| 260728-glj |\|^## Deferred Items' "$S"
# EXPECT three lines in exactly that order, ascending

# 4. No existing quick-task row was lost: row count grew by exactly 1
git show HEAD:.planning/STATE.md | grep -c '^| 260[0-9]\{3\}-' > /tmp/ivl-rows-before.txt
grep -c '^| 260[0-9]\{3\}-' "$S" > /tmp/ivl-rows-after.txt
echo "before=$(cat /tmp/ivl-rows-before.txt) after=$(cat /tmp/ivl-rows-after.txt)"   # EXPECT after = before + 1

# 5. The deferral rationale survived into the row
grep -c '^| 260728-glj |.*743864c0' "$S"    # EXPECT 1
grep -c '^| 260728-glj |.*e6f7a413' "$S"    # EXPECT 1

# 6. Last-activity signal refreshed in body and front matter
grep -n '^Last activity:' "$S"              # EXPECT one line, containing 2026-07-28 and 1.4.0
grep -n '^last_activity:\|^last_activity_desc:\|^last_updated:' "$S"   # EXPECT all three showing 2026-07-28

# 7. Front-matter position/progress keys untouched
git diff -U0 -- "$S" | grep -E '^[+-](milestone|milestone_name|current_phase|current_phase_name|status|stopped_at|  total_phases|  completed_phases|  total_plans|  completed_plans|  percent):' | wc -l   # EXPECT 0

# 8. Edit stayed scoped — a small diff, not a rewrite
git diff --numstat -- "$S"
# EXPECT roughly 5 insertions / 4 deletions; more than ~8 deletions means content was dropped, STOP

# 9. Blast radius: still nothing outside .planning/
git status --porcelain | awk '{print $NF}' | grep -v '^\.planning/' | wc -l   # EXPECT 0
    </automated>
  </verify>
  <done>
    STATE.md carries exactly one `260728-glj` row in the existing 4-column shape, correctly positioned
    at the end of the Quick Tasks Completed table, preserving the 743864c0 / e6f7a413 deferral
    rationale; the quick-task row count grew by exactly one; the body `Last activity:` line and its
    three front-matter mirrors all read 2026-07-28 and name the 1.4.0 release; the position and
    progress keys are unchanged; and the diff is a handful of lines, not a rewrite.
  </done>
  <reversibility rating="reversible">Scoped edit to a planning artifact on a local branch; `git checkout -- .planning/STATE.md` restores it.</reversibility>
</task>

<task type="auto">
  <name>Task 3: Commit locally — no push, no PR, no tag</name>
  <files>.planning/todos/pending/2026-07-28-gate-ci-green-timeout-too-tight-for-push-to-main.md, .planning/todos/pending/2026-07-28-release-lane-rot-label-missing-breaks-hard-02-signal.md, .planning/STATE.md</files>
  <action>
Stage and commit the three files locally, as two commits, in this order:

1. `chore(planning): file gate-ci-green timeout and release-lane-rot label todos from the 1.4.0 recovery`
   — the two new todo files only.
2. `chore(planning): record quick 260728-glj and refresh last-activity for the 1.4.0 Hex release`
   — `.planning/STATE.md` only.

Stage by explicit path. Do not use `git add -A` or `git add .`, which would sweep the quick-task
planning directory for this task into the code commits; the orchestrator owns that.

Both commits use the `chore(` prefix deliberately: the repo's release-please configuration sets no
`changelog-sections` override, so only `feat` and `fix` surface in generated release notes — this
housekeeping will not pollute the next release's changelog.

HARD STOP after committing. Do NOT run `git push`. Do NOT run any `gh pr` command — no create, no
edit, no merge. Do NOT create, move, or delete any git tag. Do NOT run any `gh workflow run` or
`gh release` command. The orchestrator opens the PR.
  </action>
  <verify>
    <automated>
git log --oneline -2                  # EXPECT the two chore(planning) commits above, newest first

# Each commit touched only its intended paths
git show --stat --oneline HEAD~1 | tail -n +2   # EXPECT only the two .planning/todos/pending/ files
git show --stat --oneline HEAD   | tail -n +2   # EXPECT only .planning/STATE.md

# Nothing outside .planning/ in either commit
git diff --name-only HEAD~2..HEAD | grep -v '^\.planning/' | wc -l   # EXPECT 0

# Explicit negative: release-lane and source files carry zero changes
git diff --stat HEAD~2..HEAD -- .github scripts mix.exs CHANGELOG.md lib test priv   # EXPECT empty output

# Unpushed and untagged
git log origin/main..HEAD --oneline | wc -l   # EXPECT 2 (local-only commits ahead of main)
git tag --points-at HEAD                      # EXPECT empty
git status --porcelain | awk '{print $NF}' | grep -v '^\.planning/quick/260728-ivl' | wc -l   # EXPECT 0
    </automated>
  </verify>
  <done>
    Two local commits exist with the stated messages and scoped file lists, no path outside
    `.planning/` appears in either commit, `.github` / `scripts` / `mix.exs` / `CHANGELOG.md` and all
    source trees show zero changes, the commits are ahead of `origin/main` and unpushed, no tag points
    at HEAD, and the only remaining untracked path is this quick task's own planning directory.
  </done>
  <reversibility rating="reversible">Local commits on a topic branch, unpushed; `git reset --hard origin/main` discards them.</reversibility>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| executor → release lane files (`.github/workflows/*`, `scripts/ci/*`) | These files are the subject of both todos and are read during Task 1. Any write across this boundary silently changes release behavior under the cover of a bookkeeping task. |
| executor → `.planning/STATE.md` | A 571-line shared state artifact where a whole-file write or a wide edit would destroy accumulated context that was never read. |
| local branch → `origin` / GitHub (push, PR, tag, workflow dispatch) | Crossing this boundary publishes or triggers real release machinery; the orchestrator holds sole authority here. |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-ivl-01 | Tampering | `.github/workflows/release-please.yml`, `.github/workflows/ci.yml`, `scripts/ci/notify-failure-issue.sh` | high | mitigate | Task 1 permits read-only grep of these paths and forbids edits; Tasks 1, 2, and 3 each assert that nothing outside `.planning/` changed, and Task 3 adds an explicit `git diff --stat` over `.github`, `scripts`, `mix.exs`, `CHANGELOG.md`, `lib`, `test`, and `priv` expecting empty output. |
| T-ivl-02 | Tampering | `.planning/STATE.md` accumulated context (~500 unread lines) | high | mitigate | Task 2 mandates Edit-only with bounded offset reads and forbids Write; verify checks 4, 7, and 8 assert quick-task row count grew by exactly one, position/progress keys are unchanged, and the diff is a handful of lines rather than a rewrite. |
| T-ivl-03 | Elevation of Privilege | git remote, GitHub PR/tag/workflow-dispatch surface | critical | mitigate | Task 3 forbids push, `gh pr`, `gh release`, `gh workflow run`, and tagging; verify asserts commits are unpushed relative to `origin/main` and that no tag points at HEAD. |
| T-ivl-04 | Repudiation | fidelity of the recorded diagnosis (wrong SHA, run ID, or line reference makes the todo unactionable) | medium | mitigate | Task 1 re-confirms the cited code references with read-only greps before writing and requires recording the observed value plus a discrepancy note if it differs; verify greps each load-bearing identifier by fixed string. |
| T-ivl-05 | Information Disclosure | contents of the two todos | low | accept | All recorded material is public repo state and public GitHub Actions run metadata for an already-published Hex release; no credentials, tokens, or private endpoints are recorded. |
| T-ivl-SC | Tampering | npm/pip/cargo/hex installs | low | accept | No package-manager install occurs in this plan; it writes two Markdown files and edits one Markdown file. No legitimacy audit required. |
</threat_model>

<verification>
1. Both new todo files exist under `.planning/todos/pending/` with house front matter including
   `severity: high`, and each records its defect, its evidence, and a clearly-labelled recommended fix
   that was NOT implemented.
2. Todo A carries the release SHA, both run IDs, the comparator pull_request run, both timestamps that
   prove the poller gave up before the green run finished, the structural push-versus-pull_request
   explanation, and the verbatim hex-publish recovery dispatch.
3. Todo B carries the shared-script reference, the failing run ID, the already-applied
   `gh label create` mitigation marked done, the ci.yml blast-radius note, and the
   never-exercised-mechanism lesson.
4. The pre-existing release-please orphaning todo is byte-unchanged and is not cross-referenced.
5. STATE.md has exactly one new `260728-glj` row in the existing 4-column shape, correctly positioned,
   preserving the deferral rationale; every prior row survives.
6. STATE.md's body `Last activity:` line and its three front-matter mirrors read 2026-07-28 and name
   the 1.4.0 Hex release; milestone/phase/status/progress keys are untouched.
7. `git diff --stat HEAD~2..HEAD -- .github scripts mix.exs CHANGELOG.md lib test priv` is empty —
   this is a planning-artifact-only change.
8. Two local commits, unpushed, no tag at HEAD, no PR created or edited.
</verification>

<success_criteria>
- Both release-lane defects are captured with enough fidelity that the next person starts at the fix,
  not at a run-log archaeology session.
- The immediate mitigation (label created) and the durable fix (self-healing script) are clearly
  separated in todo B, so nobody mistakes the label creation for a closed issue.
- `260728-glj` is on the STATE ledger with its deliberate-deferral reason intact, and the last-activity
  signal reflects the 1.4.0 release.
- Zero changes outside `.planning/`; working tree clean apart from this quick task's own planning
  directory; nothing pushed, tagged, or opened as a PR.
</success_criteria>

<output>
Create `.planning/quick/260728-ivl-post-release-1-4-0-bookkeeping-file-rele/260728-ivl-SUMMARY.md` when done.

The summary MUST state explicitly whether the read-only confirmation greps in Task 1 matched the
values asserted in this plan (the LABEL line in `scripts/ci/notify-failure-issue.sh`, and
max_attempts/wait_seconds in `.github/workflows/release-please.yml`). If any observed value differed,
name the observed value and confirm the todo records that value rather than the planned one.
</output>
