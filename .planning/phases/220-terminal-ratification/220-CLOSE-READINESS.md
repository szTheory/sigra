# Phase 220 Close-Readiness Record (D-13)

**Captured:** 2026-07-10
**Branch:** `gsd/phase-219-baseline-recapture-canary-reconciliation`
**HEAD at capture:** `9f08c9a6` (after 220-04 Task 1)

This is the D-13 handoff record. **Phase 220 does NOT self-merge any PR and does NOT archive
the milestone** (D-13, 215 precedent — the same posture used at v1.43 close). The actual PR
merges are `/gsd-ship` and the milestone archival is `/gsd-complete-milestone`; this record
exists so the operator (or a future zero-context agent invoking those commands) can execute the
deferred ship sequence without re-deriving anything.

## (a) The four landed ratification commits on this branch

| # | Decision | Plan | Commit(s) | Status | Artifact |
|---|----------|------|-----------|--------|----------|
| 1 | D-10 cheerio lazy-require fix + closed TODO | `220-01-PLAN.md` | `46e7b005` (fix: relocate `_require('cheerio')` below the no-bundles guard), `ba9760a2` (docs: close folded TODO) | LANDED on-branch. Static + local proof green; **authoritative CI-observed proof deferred to the terminal PR's `fast_checks` job** (PI-2 — the crash is a CI step-ordering artifact, not locally reproducible since cheerio is already installed locally). | `scripts/ci/evidence-anchor-check.mjs`; `.planning/todos/done/2026-07-09-fastchecks-cheerio-missing-dep.md`; `220-01-SUMMARY.md` |
| 2 | D-04 runbook freshness notes (you-are-here preamble, expected-canary-red note, recapture_branch cross-ref) | `220-02-PLAN.md` | `77c9195c` (docs) | LANDED on-branch. Purely additive (33 insertions, 0 deletions) — verified via `git diff --stat`. | `guides/reference/admin-eval-runbook.md`; `220-02-SUMMARY.md` |
| 3 | D-02 live-guard confirmation record (SC-1 forward-lock proof) | `220-03-PLAN.md` | `c0cb8657` (docs: record), `52d5c51e` (docs: complete plan) | LANDED on-branch as a local PREVIEW (216 SC-5 discipline — a pre-PR local run is not the binding proof). **Authoritative committed-HEAD proof deferred to the terminal PR's `fast_checks` job**, confirmed via `gh pr checks <terminal-pr>`. | `220-LIVE-GUARD-CONFIRMATION.md` |
| 4 | D-13 close-readiness record (this document) + quarantine-PR body draft | `220-04-PLAN.md` (this plan) | `9f08c9a6` (docs: quarantine-PR body, Task 1), plus this record's own commit (Task 2) | LANDED on-branch. Both are DRAFTS/records only — no PR opened/merged, no milestone archived. | `220-QUARANTINE-PR-BODY.md`; `220-CLOSE-READINESS.md` (this file) |

## (b) The exact deferred ship sequence — execute OUTSIDE this phase, IN ORDER

Phase 220 itself performs steps **0 only** (the four commits above, already landed). Steps
**1–6** below are operator / `/gsd-ship` / `/gsd-complete-milestone` actions, deferred by design
(D-13):

1. **Quarantine PR** — open `ci/quarantine-impersonation-banner-canary-recapture` (3-PNG diff
   only) **pushed via a PAT or manual user push** (D-08 — a `GITHUB_TOKEN`-authored push does
   NOT retrigger the 5 required checks). Confirm the 5 required checks actually ran, the
   required `Example Playwright smoke (full lifecycle)` is **green** (positive amd64 byte-proof),
   and the non-required `fast_checks` is **red-as-expected** on the canary-modify tripwire
   (D-06 — never-allowlistable by design, not suppressed). Run the operator scope-check
   (diff is exactly those 3 files, nothing else). **Merge this PR FIRST**, before the terminal
   PR, so the terminal PR sees zero PNG diff (D-07). Full body/checklist:
   `220-QUARANTINE-PR-BODY.md`.
2. **Merge release-please PR #66** (`chore(main): release 1.2.0` — verified OPEN at plan
   execution time, head `release-please--branches--main`) to cut v1.2.0 for the already-landed
   pre-v1.44 milestones (D-12). **Steps 1 and 2 are order-independent** (Claude's Discretion per
   CONTEXT.md) — the 3-PNG PR is a non-version-bumping `ci:` change with no `feat`/`fix` commits,
   so it does not interact with release-please's version cut. Sequence whichever produces the
   cleanest terminal-PR rebase at execution time.
3. **Open the terminal v1.44 milestone PR** as **ONE full-branch merge-commit PR**
   (`gsd/phase-219-baseline-recapture-canary-reconciliation` → `main`, all commits, `.planning/`
   included) — **NOT squash-merge and NOT `/gsd-pr-branch` filtered** (D-11 explicitly rejected
   both: squash would flatten ~76 conventional `feat`/`fix` commits and gut release-please's
   granular changelog; `/gsd-pr-branch` filtering was already tried this wave and closed as PR
   #70 — `.planning/` is a first-class tracked citizen on `main`, ~1002 files already there).
   Rebase on the new `main` (post steps 1–2) so the PNG diff is zero and release-please's
   version state is current.
4. **6/6 green + human sign-off.** Confirm all 5 ruleset-14941512-required checks
   (`Library tests`, `Example unit smoke (ExUnit + ConnTest)`, `Install smoke (fresh phx.new +
   sigra.install)`, `Example HTTP smoke (boot + curl critical routes)`, `Example Playwright smoke
   (full lifecycle)`) plus `fast_checks` are green via `gh pr checks <terminal-pr>` — this is also
   the point where the SC-1 authoritative guard proof and the SC-4 cheerio-fix CI proof are
   confirmed for real (see the SC map below). This is also the gate for flipping
   `220-VALIDATION.md`'s `nyquist_compliant: true` (see the execution-time note below).
5. **`/gsd-ship`** merges the terminal PR to `main`.
6. **release-please regenerates a fresh release PR** (expected minor bump → v1.3.0, from the
   ~48 `feat` commits in the v1.44 wave) — merge it to publish to Hex. Then run
   **`/gsd-complete-milestone`** to archive v1.44 ADMIN-UX-RATCHET.

**Phase 220 does NOT self-merge any of steps 1–6 and does NOT archive the milestone.** This
record is the handoff; the mechanical execution is `/gsd-ship` (steps 1–5) and
`/gsd-complete-milestone` (step 6), per the 215/v1.43 precedent (PR #67 full-branch merge-commit
ship).

## (c) SC-1..SC-4 → observable-signal status map

| SC | Requirement (ROADMAP wording) | Observable signal | Evidence artifact | Status |
|----|-------------------------------|--------------------|--------------------|--------|
| SC-1 | Every award sub-score cell in the quality ledger is locked forward under `quality-ledger-monotonic.sh` | `quality-ledger-monotonic.sh --base <merge-base>` → `PASS (36 cells checked...)` exit 0, plus both self-tests green | `220-LIVE-GUARD-CONFIRMATION.md` — 4 commands captured verbatim vs real `origin/main` merge-base `f2e54612`. Honest PI-1 framing: `quality-ledger-monotonic` is the SUBSTANTIVE 36-cell compare; `award-guard.mjs` exits 0 via a SKIP path (main predates the net-new award ledger), corroborated by intra-branch enforcement + 14/14 self-test, not a merge-base compare. | **LANDED on-branch as a local PREVIEW.** Authoritative committed-HEAD proof (216 SC-5 discipline) is **PENDING** — confirm via `gh pr checks <terminal-pr>` once the terminal PR runs `fast_checks` (ci.yml:120/122/133/135). |
| SC-2 | A committed harness runbook documents the one-iteration loop, human sign-off locus, and dossier-reading map for a zero-context future agent | Presence + content of `guides/reference/admin-eval-runbook.md` with the 3 D-04 additive notes | `220-02-SUMMARY.md` — you-are-here preamble, expected-canary-red note, `recapture_branch`/`release_ref_guard` cross-ref; purely additive (0 deletions) | **LANDED on-branch** (commit `77c9195c`). No further action needed — this SC does not depend on the terminal PR. |
| SC-3 | The milestone ships via a PR gated on all five required CI checks; canary reconciled without weakening the guard | Quarantine PR: required `Example Playwright smoke` green (positive byte-proof) + non-required `fast_checks` red-as-expected; then terminal PR sees zero PNG diff + 5/5 required green | `220-QUARANTINE-PR-BODY.md` — the full mechanism, ready-to-paste PR body, D-08 PAT footgun note, operator checklist | **Mechanism LANDED on-branch as a DRAFT** (commit `9f08c9a6`). The quarantine PR itself, its merge, the terminal PR, and its green checks are all **PENDING** — steps 1–4 of the ship sequence above. |
| SC-4 | The LLM panel is advisory and off-CI in the final shipped state; no panel invocation appears in any required-check job | (i) cheerio deterministic-gate fix so `fast_checks` no longer crashes on a bundle-free checkout; (ii) an AFFIRMATIVE panel-absence proof across the 5 required lanes | (i) `220-01-SUMMARY.md`, commit `46e7b005` — LANDED, CI-proof pending (PI-2). (ii) See evidence below — captured in THIS record. | **(i) LANDED on-branch, CI-proof PENDING on terminal PR. (ii) LANDED — see below, fully evidenced now.** |

### SC-4 panel-absence affirmative evidence (both halves, not merely prohibited)

Per the plan's requirement that SC-4's "LLM panel off every required-check job" half be
EVIDENCED, not merely prohibited, both proofs were re-run at Phase 220 Plan 04 execution time
and are captured verbatim below:

**Proof 1 — `panel-ci-isolation.test.sh` (negative-assertion CI-isolation self-test):**

```
$ bash scripts/ci/panel-ci-isolation.test.sh

Test 1: Real workflows do not invoke panel/loop orchestrators
  PASS: No run: step invokes admin-panel.sh or admin-autofix-loop.sh in any workflow

Test 2: 5 required-check jobs exclude panel/loop dependencies
  PASS: All 5 required-check job names present and none invoke panel/loop orchestrators

Test 3: Synthetic fixture with panel wiring is correctly detected as a violation
  PASS: Synthetic fixture correctly detected as wired: 9:        run: bash scripts/admin-panel.sh

panel-ci-isolation self-test: 3 passed, 0 failed
```

**Result: PASS 3/3, exit 0.** Test 3 proves the assertion has teeth (a synthetic fixture that
DOES wire the panel is correctly flagged as a violation) — this is not a trivially-passing
no-op check.

**Proof 2 — direct zero-match grep over `.github/workflows/ci.yml` `run:` lines** for the
panel/loop orchestrator basenames (assembled at runtime for grep hygiene, matching the pattern
`panel-ci-isolation.test.sh` itself uses):

```
$ P="admin-"; grep -cE "run:.*${P}panel.sh|run:.*${P}autofix-loop.sh" .github/workflows/ci.yml
0
```

**Result: 0 matches.** No `run:` line in `.github/workflows/ci.yml` invokes `admin-panel.sh` or
`admin-autofix-loop.sh` anywhere — not just in the 5 required lanes, but in the entire workflow
file (a stricter proof than the requirement demands).

Together, Proof 1 (the hermetic self-test, with its teeth-proving Test 3) and Proof 2 (the raw
direct grep against the real committed workflow file) give an AFFIRMATIVE, doubly-corroborated
panel-absence proof for the 5 required-check lanes — SC-4's panel half is evidenced, not merely
asserted as a prohibition. The off-CI prohibition itself (JUDGE-CI-01: `admin-panel.sh` degrades
to exit 0 on missing `ANTHROPIC_API_KEY`; `admin-autofix-loop.sh` is never wired into CI) stays
in force as documented in Phase 217/218 SUMMARYs.

## (d) Pre-ship RE-VERIFY checklist

Research validity for this phase is scoped to 7 days (fast-moving ship phase — merge-base, PR
states, and ahead-count shift as ratification commits land and the quarantine/release-please
PRs merge). **Re-run these three checks immediately before executing the ship sequence above**,
not just once at plan-execution time:

- [ ] **PNG drift is still exactly 3 `impersonation-banner` PNGs, all `M`:**
      `git fetch origin main && git diff --name-status origin/main...HEAD -- '*.png'` — must
      show exactly the 3 chromium/dark/mobile files and nothing else. (Re-confirmed at this
      record's capture time: exactly 3, all `M` — see `220-QUARANTINE-PR-BODY.md` pre-flight
      section.)
- [ ] **PR #66 (`chore(main): release 1.2.0`) is still OPEN:** `gh pr view 66 --json state` —
      must report `"state":"OPEN"`. (Re-confirmed at this record's capture time: OPEN, head
      `release-please--branches--main`.)
- [ ] **Merge-base is still `origin/main` HEAD as expected:**
      `git merge-base origin/main HEAD` — confirm it still resolves to the same commit cited in
      `220-LIVE-GUARD-CONFIRMATION.md` (`f2e54612350d96b73eda945eb3c228a1b596ec4a`) before relying
      on that record's guard output as still-current. If `origin/main` has moved (e.g. PR #66 or
      the quarantine PR merged since this record was written), re-run the 4 guard/self-test
      invocations in `220-LIVE-GUARD-CONFIRMATION.md` against the new merge-base before trusting
      the SC-1 evidence as current.

### Execution-time-only step (NOT performed in this phase)

**`220-VALIDATION.md`'s `nyquist_compliant: true` flip and its sign-off checklist completion is
an EXECUTION-TIME step, gated on the live required-check greens landing on the terminal PR — it
is explicitly NOT performed by this plan.** `220-VALIDATION.md` stays `status: draft` /
`nyquist_compliant: false` until step 4 of the ship sequence above (6/6 green + human sign-off)
actually happens; flipping it now, before that live CI proof exists, would be dishonest (the
same 216 SC-5 discipline this whole phase is built around — a doc assertion is not a substitute
for the live signal). Whoever executes step 4 should also flip `220-VALIDATION.md`'s frontmatter
and complete its sign-off checklist at that time.

## Summary

Phase 220 has landed all four ratification artifacts it owns (cheerio fix, runbook notes,
live-guard preview, this close-readiness record + the quarantine-PR draft) as commits on
`gsd/phase-219-baseline-recapture-canary-reconciliation`. SC-2 is fully satisfied on-branch. SC-1
and SC-4's cheerio half have on-branch previews with their authoritative proof deferred to the
terminal PR's `fast_checks` job (216 SC-5 discipline). SC-4's panel-absence half is fully
evidenced now (Proof 1 + Proof 2 above). SC-3's mechanism is fully documented as a draft; its
actual execution (quarantine PR → merge → terminal PR → 6/6 green) is deferred, along with PR
#66 and the terminal milestone PR merge, to the six-step ship sequence in section (b) — executed
by the operator via `/gsd-ship` and, for archival, `/gsd-complete-milestone`. **Phase 220 does
not self-merge any PR and does not archive the milestone (D-13).**
