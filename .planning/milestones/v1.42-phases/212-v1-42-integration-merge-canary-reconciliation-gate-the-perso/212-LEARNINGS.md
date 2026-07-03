---
phase: 212
phase_name: "v1-42-integration-merge-canary-reconciliation-gate-the-perso"
project: "Sigra"
generated: "2026-07-02"
counts:
  decisions: 8
  lessons: 6
  patterns: 6
  surprises: 6
missing_artifacts:
  - "VERIFICATION.md"
  - "UAT.md"
---

# Phase 212 Learnings: v1.42 Integration-Merge / Canary-Reconciliation / CI-Gate

## Decisions

### Reconcile a non-allowlistable canary via a byte-only prerequisite PR (D-13 superseded)
The `impersonation-banner` mobile canary could not be allowlisted (a canary is never waivable) and could not be re-designated in-PR (proven no-op). The plan mandated the sanctioned `admin_checkpoint_recapture` CI job, but that was mechanically infeasible against the real topology. Resolution (human-ratified): a byte-only prerequisite PR (#64) off origin/main setting the canary baseline to the reviewed WCAG bytes (`1f7aba5b`, from `c96749fa`), admin-merged, so PR #63's canary diff reads byte-green.

**Rationale:** Honors D-13's intent — canary stays armed, WCAG fix preserved, no waiver/revert/allowlist — only the plumbing changed. The sanctioned job only triggers on push-to-main / nightly / v-tag, and origin/main was 396 commits behind the WCAG appearance, so a self-consistent recapture PR was impossible.
**Source:** 212-01-SUMMARY.md, 212-04-SUMMARY.md

### Append flow specs to the existing booted-app step, not a new CI job (D-05)
The 3 persona-flow Playwright specs were appended to the existing `example_playwright_smoke` `admin_behavior` chromium run block rather than given a dedicated new job.

**Rationale:** Reuses the already-booted example app + seeded demo personas (alice/dave/frank/morgan) at near-zero marginal cost. A dedicated job would duplicate the expensive boot+seed; a written waiver would contradict the milestone's "proven in Playwright" acceptance clause.
**Source:** 212-02-PLAN.md, 212-02-SUMMARY.md

### Route flow specs to chromium only (D-06)
The flow specs stay on `--project=chromium` and are deliberately kept off any mobile project.

**Rationale:** They match `ADMIN_BEHAVIOR_SPECS` (playwright.config.ts:24-25) and the mobile project's `testIgnore` already excludes that pattern — adding them to a mobile list would silently skip them ("wired but running nowhere").
**Source:** 212-02-PLAN.md, 212-02-SUMMARY.md

### Branch-scope the generated-host smoke `if:` rather than un-skip all PRs (D-08)
`generated_admin_playwright_smoke` was changed from `if: github.event_name != 'pull_request'` to `... || github.head_ref == 'ship/v1.42-ci-gate-remediation'` so it RUNS on PR #63 only.

**Rationale:** Proves generated-host runtime parity in CI on the integration PR now, without adding the ~30-60m cold phx.new+compile+Playwright wall-clock to every future PR (a known CI-PERF pole). A two-line comment marks it temporary/removable so it does not read as dead config.
**Source:** 212-03-PLAN.md, 212-03-SUMMARY.md

### Grow the merge vehicle to the full backlog (D-12)
PR #63's `ship/v1.42-ci-gate-remediation` branch (stopped at Phase 208.1) was advanced to local main's tip so PR #63 carries the full 388-commit v1.42 backlog, base still origin/main.

**Rationale:** ship ⊊ local main — the un-updated PR #63 did NOT contain the gate-closing 209/210/211 work, so merging it would not deliver the gates. The single reviewed PR must grow rather than merging a stale vehicle.
**Source:** 212-04-PLAN.md, 212-04-SUMMARY.md

### Do not re-flip the shipped flag; let it land atomically (D-16)
The `v1.42 → shipped` flag was already committed in the backlog (`4a5dd5f7`, Phase 211-05). It was NOT re-flipped; it rode into origin/main atomically with the PR #63 merge.

**Rationale:** Because the full backlog merges atomically, the flag lands exactly when the merge lands — origin/main reflects "shipped" only as-of-the-merge, which is honest. This is the guard against the audit's premature-flag finding (§81/§158).
**Source:** 212-04-PLAN.md, 212-04-SUMMARY.md

### Declare intended drift in-diff, reset allowlists post-merge (D-02/D-14/D-03)
Both allowlists (`snapshot-allowlist`: 5 checkpoint slugs; `snapshot-allowlist-design`: 15 board slugs) carried the legit v1.41-backlog drift slugs in the PR #63 diff, then were reset to comment-only AFTER merge.

**Rationale:** The merged diff must contain the slugs so the drift was reviewable; resetting to empty afterward restores the tripwire so a later PR's real drift on those slugs cannot pass silently. The resets are intentionally NOT part of the merged PR diff.
**Source:** 212-01-SUMMARY.md, 212-04-SUMMARY.md

### Include user-sessions as a 5th checkpoint slug after clean-checkout verification (D-15)
`user-sessions` was verified on a clean checkout, surfaced as an `added` drift (3 net-new PNGs absent from origin/main), and was therefore included as the 5th allowlist slug.

**Rationale:** D-15 required empirically determining the classification rather than assuming it; it drifted, so it was declared.
**Source:** 212-01-PLAN.md, 212-01-SUMMARY.md

---

## Lessons

### A canary cannot be reconciled in-PR — the guard diffs working-tree vs base and ignores the index
`snapshot-canary-guard.sh` runs `git diff --name-status origin/main`, which ignores the index. So `git rm --cached` + `git add` (re-designating the canary as `added`) is a proven no-op: the canary stays `modified` and the guard hard-fails. Only a merged change on origin/main truly turns the canary byte-green.

**Context:** Discovered while attempting to reconcile the impersonation-banner canary within PR #63; forced the byte-only prerequisite-PR approach.
**Source:** 212-01-PLAN.md, 212-01-SUMMARY.md

### The sanctioned recapture job is infeasible when origin/main is far behind the appearance it must render
The `admin_checkpoint_recapture` job only fires on push-to-main (the gated merge), nightly schedule (runs on origin/main, which lacks the job), or a v-tag dispatch (fires the whole non-PR suite and forks a 396-commit PR). And origin/main was 396 commits behind the CSS/brand state the WCAG canary depends on, so a self-consistent recapture PR was impossible until the backlog landed.

**Context:** The "sanctioned mechanism" assumed in planning did not survive contact with the real branch topology; a byte-only baseline PR was the workable substitute.
**Source:** 212-01-SUMMARY.md

### New integration gates surface real stale-test regressions that HEAD-only verification hid
Turning on FLOW-01 wiring + running the full suite on the integration PR exposed 6 stale example-app tests (1 ExUnit + 5 Playwright, including 4 never-run FLOW-01 specs) left behind by Phase 209's admin-UI copy/IA polish. All 6 were confirmed stale (not runtime bugs) and reconciled to the current UI over CI cycles 2–3.

**Context:** "Every phase verified vs HEAD" is weaker than "the milestone runs green as an integrated whole" — the gates only earn their keep when actually executed on the merge vehicle.
**Source:** 212-04-SUMMARY.md

### Verify branch topology before assuming a force-push is required
The plan assumed a mandatory force-update of the ship branch. In reality ship's tip (`cbe0b928`) was an ancestor of local main, so advancing PR #63 to the full backlog was a clean fast-forward — no `--force-with-lease` needed.

**Context:** `git merge-base --is-ancestor` should gate force-push decisions; the planning premise of "force required" did not hold.
**Source:** 212-04-SUMMARY.md

### A genuine contract fork needs a human ruling, not an auto-fix
One of the 6 stale tests (org-admin `/admin` denial) was a real 403-vs-graceful-redirect contract fork, not stale drift. It was resolved by human ruling — keep the example's redirect UX, reconcile the spec, preserve anti-enumeration.

**Context:** Distinguishing "stale spec to update" from "genuine behavior-contract decision" matters; the latter is escalated, not silently reconciled.
**Source:** 212-04-SUMMARY.md

### A skipped CI need reads as false-green in ci-gate
`generated_admin_playwright_smoke` was skipping on PRs, and ci-gate treats a skipped need as not-failed → false-green. The runtime-parity proof existed only on the maintainer's machine. Forcing the job to RUN on the integration PR turned the gate from a silent pass into a real success/failure result.

**Context:** Gate aggregators that sum job outcomes must be checked for skipped-as-passed semantics; "green" only attests to what actually ran.
**Source:** 212-03-PLAN.md, 212-03-SUMMARY.md

---

## Patterns

### Steady-state-empty allowlist
Keep visual-regression allowlists empty by default; declare intended drift slugs in the SAME PR diff (reviewable intent), then reset to empty after merge as a follow-up on origin/main.

**When to use:** Any tripwire-style manifest (snapshot allowlists, waiver lists) where a temporary exception must be reviewable but must not become a permanent hole.
**Source:** 212-01-SUMMARY.md, 212-04-PLAN.md

### Byte-only prerequisite baseline PR to reconcile a non-waivable canary
When a canary baseline legitimately changed but the canary can never be allowlisted, land a small byte-only PR that advances the baseline on the base branch FIRST (gated by human visual review), so the feature PR's canary diff reads byte-green with the tripwire still armed.

**When to use:** A protected snapshot/baseline changed for a legitimate reason and the sanctioned recapture mechanism is unavailable or infeasible.
**Source:** 212-01-SUMMARY.md

### Append specs to an already-booted CI step for near-zero marginal cost
Rather than spinning up a new job, append test specs to an existing step that has already paid the expensive boot/seed cost, relying on the step's existing outcome aggregator to fail-closed.

**When to use:** New tests need a gate but share the fixture/environment of an existing expensive job.
**Source:** 212-02-PLAN.md, 212-02-SUMMARY.md

### Branch-scoped CI job condition
Gate an expensive job on `github.event_name != 'pull_request' || github.head_ref == '<integration-branch>'` to prove something on one specific PR without imposing the cost on every future PR. Mark it removable with a comment.

**When to use:** A costly proof (cold generated-host build, full E2E) is needed on an integration PR now but should not be permanent per-PR overhead.
**Source:** 212-03-PLAN.md, 212-03-SUMMARY.md

### Full-backlog merge vehicle — grow the PR, don't merge a stale one
When the review PR branch is a strict subset of the work that actually closes the milestone, advance the PR branch to the full backlog (fast-forward if ancestry allows) so the single reviewed vehicle delivers everything, rather than merging a stale branch.

**When to use:** The open PR predates later phases whose commits are the ones that close the gates.
**Source:** 212-04-PLAN.md, 212-04-SUMMARY.md

### Atomic shipped-flag landing for honest status
Commit the "shipped" status flag inside the backlog and let it land atomically with the integration merge — never flip it ahead of the merge. Verify base branch reflects "shipped" only as-of-the-merge.

**When to use:** Any milestone-completion flag where premature flipping would misrepresent status before the work is actually integrated.
**Source:** 212-04-PLAN.md, 212-04-SUMMARY.md

---

## Surprises

### The mandatory force-update turned out to be a fast-forward
The plan (and threat model T-212-12) built extensive `--force-with-lease` safeguards around advancing the ship branch, but ship was an ancestor of local main, so a normal push sufficed. The planning premise of a mandatory force-update did not hold against the real topology.

**Impact:** Simpler, safer merge-vehicle growth than planned; the ancestry pre-check (`git merge-base --is-ancestor`) is what revealed it.
**Source:** 212-04-SUMMARY.md

### The sanctioned recapture job would fork a 396-commit PR
The canonical D-13 mechanism, on inspection, could only run in ways that either were blocked (push-to-main) or forked a 396-commit non-focused PR — nothing resembling a clean, focused canary recapture.

**Impact:** Forced the human-ratified deviation to a byte-only prerequisite PR (#64); the "blessed path" was a dead end here.
**Source:** 212-01-SUMMARY.md

### Six example tests were silently stale until the gates ran
The FLOW-01 wiring + full-suite-on-integration-PR surfaced 6 stale tests (4 of them never-run FLOW-01 specs) left by Phase 209's UI polish — invisible to per-phase HEAD verification.

**Impact:** Three CI cycles (not one) to drive PR #63 green; each stale test had to be reconciled to the current UI and confirmed as drift, not a bug.
**Source:** 212-04-SUMMARY.md

### One allowlisted design slug (board-mg-3) was byte-stable
14 of the 15 allowlisted design slugs actually drifted; `board-mg-3` was byte-stable. Allowlisting an unchanged slug is harmless (the guard just reports fewer changed slugs than allowlisted).

**Impact:** Confirms over-declaring an allowlist slug is safe, but the count mismatch (14 changed vs 15 allowlisted) is expected and not a failure.
**Source:** 212-01-SUMMARY.md

### user-sessions presented as net-new (added) drift, not modified
On a clean checkout, `user-sessions` surfaced as an `added` drift — 3 net-new PNGs absent from origin/main — rather than a modification, which is why it was includable as an allowlist slug (added is first-establishment; modified would be forbidden for a canary).

**Impact:** Validated the D-15 "verify on clean checkout before deciding" discipline; the classification determined whether it could be allowlisted at all.
**Source:** 212-01-SUMMARY.md

### PR #64 was intentionally merged with a red required check
The byte-only baseline PR (#64) was admin-merged while its `Example Playwright smoke` check was red — the baseline is intentionally ahead of the code and self-heals ~1 CI cycle later when PR #63 lands the CSS.

**Impact:** Required an admin-merge (main ruleset override) and a documented rationale in the PR body; a normal merge would have been blocked, and the red check is expected, not a defect.
**Source:** 212-01-SUMMARY.md
