---
phase: 220-terminal-ratification
verified: 2026-07-09T22:45:00Z
status: passed
score: 4/4 must-haves verified (scoped to this phase's design: land on-branch artifacts + document the deferred ship, per D-13)
behavior_unverified: 0
overrides_applied: 0
re_verification: false
---

# Phase 220: Terminal Ratification Verification Report

**Phase Goal:** The award sub-score cells are locked forward under the monotonic guard, a harness
runbook is committed, and the milestone ships via a PR gated on the five required CI checks — with
the LLM panel advisory and off-CI throughout.

**Verified:** 2026-07-09
**Status:** passed
**Re-verification:** No — initial verification

## Scope Note (read before the truths table)

This is a terminal-ratification phase whose own goal statement (D-13, 215 precedent) is explicitly
scoped to **landing on-branch artifacts and documenting a deferred ship sequence** — Phase 220 must
NOT self-merge any PR or archive the milestone. The actual PR merges are `/gsd-ship` actions executed
later. Three items are deliberately recorded by the plans themselves as PENDING-on-PR (216 SC-5
discipline: a local/self-test green run is a preview, not the authoritative committed-HEAD proof):

1. **SC-1's authoritative CI-observed guard run** — the local preview (below) is genuine and
   reproducible; the binding proof is `fast_checks` on the terminal PR.
2. **SC-3's actual ship** — the milestone has not shipped; `220-CLOSE-READINESS.md` documents the
   exact six-step deferred sequence (quarantine PR → PR #66 → terminal PR → `/gsd-ship` → v1.3.0 →
   `/gsd-complete-milestone`).
3. **SC-4's cheerio-fix CI proof** — the crash is a CI step-ordering artifact not locally
   reproducible (PI-2); the fix is landed and statically/functionally proven locally.

These are **not gaps** — they are the correct, designed shape of a phase whose job is to prepare a
caveat-free ship, not to execute it. All four truths below are graded on what the phase actually
owns: real, wired, honest on-branch artifacts.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | SC-1: Award sub-score cells locked forward under `quality-ledger-monotonic.sh`; guard exits 0 vs merge-base and would exit non-zero on any decrease | ✓ VERIFIED (on-branch preview; authoritative CI proof deferred by design) | Independently re-ran (not trusting SUMMARY): `bash scripts/ci/quality-ledger-monotonic.sh --base f2e54612350d96b73eda945eb3c228a1b596ec4a` → `PASS (36 cells checked...)`, exit 0. Self-test `quality-ledger-monotonic.test.sh` proves the guard actually catches a 2→1 decrease (Test A) — not a trivially-passing check. `award-guard.mjs` exits 0 via a documented SKIP path (main predates the award ledger); its 14/14 self-test independently confirms detection logic for all 5 violation classes. `ci.yml:120/122/133/135` wires both guards + self-tests into the `fast_checks` job exactly as claimed. |
| 2 | SC-2: Committed harness runbook orients a zero-context agent (loop, sign-off locus, dossier map) | ✓ VERIFIED (fully on-branch, no CI dependency) | `guides/reference/admin-eval-runbook.md` commit `77c9195c`, 33 insertions / 0 deletions (`git show --stat` confirmed). All three D-04 notes independently grepped and present: "you are here" preamble + CI-native/ubuntu/amd64/never-darwin phrasing; `impersonation-banner` + "never allowlist" co-located; `recapture_branch` + `release_ref_guard` cross-ref. |
| 3 | SC-3: Milestone ships via a PR gated on the 5 required CI checks (mechanism prepared this phase; execution deferred by design) | ✓ VERIFIED (mechanism landed + documented; actual ship correctly NOT performed, per D-13) | `220-QUARANTINE-PR-BODY.md` is a complete, ready-to-paste draft (title/body/branch-cut commands/PAT footgun/operator checklist). Re-verified independently: current PNG drift is still exactly the 3 `impersonation-banner` PNGs (`git diff --name-status origin/main...HEAD -- '*.png'`), matching the record. `220-CLOSE-READINESS.md` documents the exact 6-step deferred sequence and explicitly states "Phase 220 does NOT self-merge any PR and does NOT archive the milestone" — confirmed true: `gh pr list` shows no new PR opened by this phase; `git status` clean; branch is 207 commits ahead of `origin/main`, unmerged. |
| 4 | SC-4: LLM panel advisory/off-CI in the final shipped state; no panel invocation in any required-check job | ✓ VERIFIED — panel-absence half fully evidenced now; cheerio-fix half landed on-branch with CI proof correctly deferred (PI-2, not locally reproducible) | Panel absence independently re-verified (not trusting the record): `bash scripts/ci/panel-ci-isolation.test.sh` → 3 passed, 0 failed, exit 0 (Test 3 proves the assertion has teeth via a synthetic violation fixture). Direct grep `grep -cE "run:.*admin-panel.sh|run:.*admin-autofix-loop.sh" .github/workflows/ci.yml` → `0` matches. Cheerio fix independently re-verified in source: `_require('cheerio')` is now at line 107, strictly after the `bundleDirs.length === 0` guard at line 99; empty-bundles-dir run exits 0; real-bundles run still completes (gate stays armed). |

**Score:** 4/4 truths verified (0 present-behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `scripts/ci/evidence-anchor-check.mjs` | cheerio require relocated below no-bundles guard | ✓ VERIFIED | Require line 107 > guard line 99 (independently confirmed via script, not just SUMMARY claim). Wired into `fast_checks` at `ci.yml:145`. |
| `.planning/todos/done/2026-07-09-fastchecks-cheerio-missing-dep.md` | TODO closed with `status: done` + D-10 resolution note | ✓ VERIFIED | File exists under `done/`; `pending/` copy removed; `status: done` present. |
| `guides/reference/admin-eval-runbook.md` | 3 additive D-04 notes | ✓ VERIFIED | All 3 notes grepped present; diff is purely additive (33/+0). |
| `.planning/phases/220-terminal-ratification/220-LIVE-GUARD-CONFIRMATION.md` | SC-1 evidence record | ✓ VERIFIED | Exists; all 4 captured commands independently reproduced with matching output at the same merge-base (`f2e54612350d96b73eda945eb3c228a1b596ec4a`, confirmed still current via `git merge-base origin/main HEAD`). |
| `.planning/phases/220-terminal-ratification/220-QUARANTINE-PR-BODY.md` | SC-3 quarantine-PR draft | ✓ VERIFIED | Complete draft: PR title/body, branch-cut commands, PAT/`GITHUB_TOKEN` footgun note, green/red explanation, operator scope-check + merge-order checklist, non-default fallback. No PR opened (confirmed via `gh pr list`). |
| `.planning/phases/220-terminal-ratification/220-CLOSE-READINESS.md` | D-13 handoff record | ✓ VERIFIED | 4 landed commits cross-referenced with real commit hashes (all independently confirmed to exist via `git cat-file -t`); exact 6-step deferred ship sequence; SC-1..SC-4 status map; pre-ship re-verify checklist; explicit no-self-merge/no-archive statement. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `scripts/ci/quality-ledger-monotonic.sh` / `award-guard.mjs` | `fast_checks` job | `run:` steps | ✓ WIRED | `ci.yml:120,122,133,135` — line numbers match exactly what the plans/records claim. |
| `scripts/ci/evidence-anchor-check.mjs` | `fast_checks` job | `run:` step | ✓ WIRED | `ci.yml:145`, running after the relocated cheerio require, order-independent of the later `npm ci` (per code inspection). |
| `scripts/ci/panel-ci-isolation.test.sh` | `fast_checks` job | `run:` step | ✓ WIRED | `ci.yml:162`; independently re-run, PASS 3/3, including the teeth-proving synthetic-violation Test 3. |
| Required-check job names (`Library tests`, `Example unit smoke`, `Install smoke`, `Example HTTP smoke`, `Example Playwright smoke`) | ruleset 14941512 wording in ROADMAP SC-3 | job `name:` fields | ✓ VERIFIED MATCH | `ci.yml` job names at lines 404/510/570/915/990 exactly match the 5 required-check names cited by SC-3; `fast_checks` (line 68, "Fast checks...") is confirmed non-required — consistent with the panel/cheerio/guard checks living in a non-blocking lane. |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Guard forward-lock proof reproduces independently | `bash scripts/ci/quality-ledger-monotonic.sh --base $(git merge-base origin/main HEAD)` | `PASS (36 cells checked vs f2e54612...)`, exit 0 | ✓ PASS |
| Guard self-test proves decrease-detection has teeth | `bash scripts/ci/quality-ledger-monotonic.test.sh` | `6 passed, 0 failed` | ✓ PASS |
| award-guard self-test proves all 5 violation classes caught | `node scripts/ci/award-guard.test.mjs` | `14 passed, 0 failed` | ✓ PASS |
| Panel-absence self-test has teeth (synthetic violation caught) | `bash scripts/ci/panel-ci-isolation.test.sh` | `3 passed, 0 failed` | ✓ PASS |
| Zero-match panel/loop grep over the real workflow | `grep -cE "run:.*admin-panel.sh\|run:.*admin-autofix-loop.sh" .github/workflows/ci.yml` | `0` | ✓ PASS |
| Cheerio relocation is real (not just claimed) | `node -e` static line-order check | require line 107 > guard line 99 | ✓ PASS |
| Bundle-free checkout still exits 0 | `node scripts/ci/evidence-anchor-check.mjs --bundles-dir <empty>` | `INFO: no bundles found... exit 0` | ✓ PASS |
| PNG drift claim in close-readiness/quarantine records is still current | `git diff --name-status origin/main...HEAD -- '*.png'` | exactly 3 `M` impersonation-banner files | ✓ PASS |
| PR #66 claim ("still OPEN") is still current | `gh pr view 66 --json state` | `"state":"OPEN"` | ✓ PASS |
| Phase did not self-merge/open any PR (D-13) | `gh pr list --state open` | Only pre-existing PRs (#69, #66, #61, #57) — no new quarantine/terminal PR | ✓ PASS |
| Phase did not touch `snapshot-canary-guard.sh` (must stay unweakened) | `git diff f2e54612..HEAD -- scripts/ci/snapshot-canary-guard.sh` | Only change is from Phase 219 commit `0d2e5fc4` (D-06 never-allowlistable), not Phase 220 | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|--------------|--------|----------|
| RATIFY-01 | 220-01, 220-02, 220-03, 220-04 | Award sub-score cells locked forward, runbook committed, milestone ships via 5-required-check-gated PR, LLM panel advisory/off-CI | ✓ SATISFIED (scoped to this phase's design) | Sub-parts distributed exactly across the 4 plans (cheerio/SC-4, runbook/SC-2, live-guard/SC-1, quarantine+close-readiness/SC-3) as declared in each plan's `requirements:` frontmatter; matches REQUIREMENTS.md's Phase 220 mapping (only RATIFY-01, no orphans). |

No orphaned requirements — REQUIREMENTS.md maps exactly RATIFY-01 to Phase 220, and it is the only requirement declared across all 4 plans.

### Anti-Patterns Found

None. Scanned all files modified by this phase (`evidence-anchor-check.mjs`, `admin-eval-runbook.md`,
`220-LIVE-GUARD-CONFIRMATION.md`, `220-CLOSE-READINESS.md`, `220-QUARANTINE-PR-BODY.md`, the moved
TODO) for `TBD|FIXME|XXX|TODO|HACK|PLACEHOLDER` and "coming soon / not yet implemented" phrasing. The
two `TBD` grep hits in the runbook are false positives (substring match inside "persona-**JTBD**"),
not debt markers. No stub returns, no empty handlers, no hardcoded-empty data flowing to rendered
output — these are docs/CI-script artifacts, not UI components.

### Human Verification Required

None blocking THIS phase's verification. `220-VALIDATION.md`'s two Manual-Only Verifications
("Quarantine-PR scope check" and "Terminal-PR human sign-off") are correctly scoped to the **later
ship-execution sequence** (operator / `/gsd-ship`), not to this phase's on-branch deliverables — the
phase's own plans explicitly state these steps are NOT performed here (D-13). `220-VALIDATION.md`
correctly stays `status: draft` / `nyquist_compliant: false` until that live CI proof lands on the
terminal PR; flipping it now would be the exact overclaim the phase's own design (216 SC-5 discipline)
is built to prevent.

### Gaps Summary

No gaps found. All four Phase 220 plans landed real, wired, independently-reproducible artifacts:
the cheerio lazy-require fix (statically and functionally proven locally, CI-proof correctly deferred
per PI-2), the runbook's three additive freshness notes (purely additive, zero deletions), the SC-1
live-guard confirmation record (all four guard/self-test invocations independently re-run here with
matching output), and the quarantine-PR draft + D-13 close-readiness record (both re-verified as
still-current against the live repo state: PNG drift unchanged, PR #66 still open, no PR opened by
this phase, `snapshot-canary-guard.sh` untouched by this phase). The phase correctly did NOT self-merge
any PR or archive the milestone, and REQUIREMENTS.md/ROADMAP.md's "Complete" marking for Phase
220/RATIFY-01 follows the same convention already used for Phases 216-219 (plans-executed, not
milestone-shipped) — the milestone itself remains correctly marked "active" (not shipped) in
ROADMAP.md line 8.

---

_Verified: 2026-07-09_
_Verifier: Claude (gsd-verifier)_
