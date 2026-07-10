# Phase 220: Terminal Ratification - Research

**Researched:** 2026-07-09
**Domain:** CI ratchet-guard reverification + milestone-ship mechanics (verify-then-confirm ship phase)
**Confidence:** HIGH

## Summary

This is the TERMINAL / SHIP phase of milestone v1.44 ADMIN-UX-RATCHET. The CONTEXT.md is
exceptionally complete: 13 LOCKED decisions (D-01…D-13) already embed a deep multi-lens research
pass. This research does NOT re-derive those decisions. It **re-verifies the load-bearing factual
claims against the live repo HEAD** and surfaces drift, then supplies the Nyquist Validation
Architecture section.

**Bottom line: NO load-bearing drift found.** Every guard script exists, every ci.yml line number
CONTEXT cites is still exact (award-guard:133, quality-ledger:120, merge-base:81, evidence-anchor:145,
self-tests 122/135), the PNG drift is exactly the 3 `impersonation-banner` PNGs (all `M`), the ruleset
required checks match CONTEXT's 5 verbatim, PR #66 is still open, and the folded TODO exists. The
`cheerio` lazy-require fix site (D-10) is precisely as described — a genuinely clean 2-line relocation.

Two **non-drift nuances** emerged from live guard execution that sharpen (not change) the plan:
(1) `award-guard.mjs` against the origin/main merge-base exits 0 via its *skip* path (the award ledger
is net-new in v1.44 — no base ledger on main to compare), so the SC-1 live-lock proof rests on
`quality-ledger-monotonic.sh` (which DID compare 36 cells and PASS) plus both self-tests; (2) the
`fast_checks` cheerio crash is a CI **step-ordering** artifact and is not locally reproducible.

**Primary recommendation:** Proceed exactly along CONTEXT's locked D-01…D-13 sequence. Attach the
Validation Architecture below so the D-02 "prove the live committed-HEAD path" obligation (closing the
216 SC-5 trap) and the D-10 cheerio-fix proof are observable in CI, not asserted.

## Situational Reverification Table

| # | Fact (from CONTEXT) | Status | Current evidence (verified NOW) |
|---|---------------------|--------|----------------------------------|
| 1 | Branch is `gsd/phase-219-baseline-recapture-canary-reconciliation`, ~189 ahead / 0 behind origin/main | ✅ VERIFIED (minor) | `git branch --show-current` = that branch. `git rev-list --left-right --count origin/main...HEAD` = **0 behind / 191 ahead**. CONTEXT said 189 — grew by 2 (the 220-context capture commits `ded3f797`, `a2135231`). Expected growth, not drift. Merge-base = `f2e54612` (v1.43 close-out, matches CONTEXT). |
| 2 | PNG drift vs origin/main = exactly 3 `impersonation-banner` PNGs, all `M` | ✅ VERIFIED | `git fetch origin main` then `git diff --name-status origin/main...HEAD -- '*.png'` → exactly 3 rows, all `M`, all `impersonation-banner-admin-checkpoints-{chromium,dark,mobile}.png`. `board-notice` = 0 diff. Count/set/status match CONTEXT exactly. |
| 3 | Both ratchet guards + self-tests exist | ✅ VERIFIED | `scripts/ci/{award-guard.mjs, quality-ledger-monotonic.sh, quality-ledger-monotonic.test.sh, award-guard.test.mjs}` all present on disk. |
| 4 | `award-guard.mjs` wired into fast_checks at `ci.yml:133`, diffs merge-base | ✅ VERIFIED | ci.yml:133 = `run: node scripts/ci/award-guard.mjs --base "${{ steps.base.outputs.ref }}"`. Self-test at :135. **Exact line match.** |
| 5 | `quality-ledger-monotonic.sh` wired at `ci.yml:120` | ✅ VERIFIED | ci.yml:120 = `run: bash scripts/ci/quality-ledger-monotonic.sh --base "${{ steps.base.outputs.ref }}"`. Self-test at :122. **Exact line match.** |
| 6 | Base ref resolved via `git merge-base origin/<base> HEAD` at `ci.yml:79–85` | ✅ VERIFIED | ci.yml:81 = `MB=$(git merge-base "origin/${{ github.base_ref }}" HEAD)` inside the `pull_request` branch of the `Resolve base ref` step (74–85). **Within cited range.** |
| 7 | `evidence-anchor-check.mjs` loads cheerio via runtime `createRequire` at line ~47 | ✅ VERIFIED | line 34 `import { createRequire }`; line 46 `const _require = createRequire(path.join(PW, 'package.json'))`; **line 47** `const { load: cheerioLoad } = _require('cheerio');`. **Exact line match.** Not a static ESM import. |
| 8 | No-bundles → exit 0 guard at ~lines 100–103; require not referenced before it | ✅ VERIFIED | lines 100–102: `if (bundleDirs.length === 0) { console.log(...); process.exit(0); }`. First use of `cheerioLoad` is **line 129** (`const $ = cheerioLoad(html)`), inside the post-guard loop starting line 108. The require (47) sits *above* the guard (100) but the *use* (129) is *below* it → moving the require past the guard is a clean ~2-line relocation, exactly as D-10 states. |
| 9 | `snapshot-canary-guard.sh` forbids a canary *modify* and is never-allowlistable | ✅ VERIFIED | Never-allowlistable tripwire at lines 53–59 (`fail "canary '${CANARY}' must never be allowlisted ..."`). Modify/delete-forbid at line 113 (`fail "canary snapshot ${kind}: ... modify/delete of an established canary is forbidden"`). Pure-`added` birth tolerated at 110. Matches D-05/D-06. |
| 10 | Ruleset 14941512 requires EXACTLY 5 checks; `fast_checks`/`ci-gate` NOT required | ✅ VERIFIED | `gh api repos/szTheory/sigra/rulesets/14941512` → required contexts: `Library tests`, `Example unit smoke (ExUnit + ConnTest)`, `Install smoke (fresh phx.new + sigra.install)`, `Example HTTP smoke (boot + curl critical routes)`, `Example Playwright smoke (full lifecycle)`. `fast_checks` and `ci-gate` absent. **Exact match to CONTEXT's list.** |
| 11 | PR #66 `chore(main): release 1.2.0` still open (D-12) | ✅ VERIFIED | `gh pr view 66` → state `OPEN`, title `chore(main): release 1.2.0`, head `release-please--branches--main`. |
| 12 | Folded TODO exists | ✅ VERIFIED | `.planning/todos/pending/2026-07-09-fastchecks-cheerio-missing-dep.md` present (1947 bytes). |
| 13 | SC-2 runbook `guides/reference/admin-eval-runbook.md` exists (D-03) | ✅ VERIFIED | Present, 379 lines. (Content-quality claim from D-03 not re-audited — CONTEXT's D-03 is a locked judgment; D-04 adds only additive notes.) |
| 14 | PR #70 closed (D-11 residual) | ✅ VERIFIED | Not in `gh pr list --state open` (open PRs: #66, #69, #61, #57). Consistent with 219-VERIFICATION (PR #70 CLOSED). |
| 15 | `nyquist_validation` enabled | ✅ VERIFIED | `.planning/config.json` → `"nyquist_validation": true` → Validation Architecture section required (below). |

### Live guard execution preview (against real merge-base `f2e54612`)

| Guard | Command | Result | exit |
|-------|---------|--------|------|
| quality-ledger-monotonic | `bash scripts/ci/quality-ledger-monotonic.sh --base f2e54612` | `PASS (36 cells checked vs f2e54612…)` | 0 |
| award-guard | `node scripts/ci/award-guard.mjs --base f2e54612` | `INFO: no base ledger … skipping comparison (initial commit)` | 0 |
| award-guard self-test | `node scripts/ci/award-guard.test.mjs` | `14 passed, 0 failed` | 0 |
| evidence-anchor (local) | `node scripts/ci/evidence-anchor-check.mjs` | `PASS (132 bundle(s), 3808 finding(s))` | 0 |

## Planning Implications

Only nuances that affect *how* the plan frames its evidence — the locked decisions are NOT restated.

### PI-1 — SC-1 live-lock proof rests on quality-ledger-monotonic, not award-guard (nuance, not drift)

Against the terminal PR's real merge-base (`origin/main` = `f2e54612`, the v1.43 close-out),
`award-guard.mjs` exits 0 via its **skip path**: `admin-award-ledger.json` does not exist on main
(the award sub-score gradient is net-new in v1.44 / phase 216), so there is no base ledger to compare
and the guard logs `no base ledger … skipping comparison (initial commit)`. This is correct guard
behavior, not a failure.

Consequence for the D-02 close-readiness record: the phrase "both guards exit 0 against the real
merge-base" is literally true, but the **substantive** forward-lock comparison for SC-1 comes from
`quality-ledger-monotonic.sh`, which DID diff **36 cells** vs `f2e54612` and passed. SC-1 in ROADMAP
is worded against `quality-ledger-monotonic.sh` specifically ("Every award sub-score cell in the
quality ledger is locked forward under `quality-ledger-monotonic.sh`"), so this aligns. The plan's
evidence record should:
- Cite `quality-ledger-monotonic` (36 cells compared + PASS) as the primary SC-1 lock proof.
- Cite `award-guard` as exit-0 + `14/14` self-test green, noting its merge-base comparison is a
  skip-path because main predates the award ledger — its *substantive* forward-lock is proven
  intra-branch (216–218) and by the self-test, not by the terminal-PR merge-base diff.

This is exactly the kind of "green via skip vs green via compared-and-held" distinction the 216 SC-5
trap warns about — surface it explicitly so the record is honest.

### PI-2 — The cheerio crash is a CI step-ordering artifact; not locally reproducible

The `fast_checks` job installs the Playwright subproject deps (which include cheerio) via
`npm ci --ignore-scripts` at **ci.yml:206**, but the `Evidence anchor integrity check` step runs at
**ci.yml:145** — i.e. **cheerio is required (module-top, line 47) ~60 lines of workflow BEFORE it is
installed**. That is the real mechanism behind the CI log `Error: Cannot find module 'cheerio'`.

Locally the crash does NOT reproduce: cheerio is already present in
`test/example/priv/playwright/node_modules`, so the local run found 132 bundles and PASSed. Two
implications for the plan:
- The D-10 lazy-require fix is correct and even more clearly justified: after moving the require below
  the no-bundles guard, `fast_checks` (where `eval/` bundles are gitignored → `bundleDirs` empty →
  `exit(0)` at line 102) never touches cheerio regardless of install ordering. The gate stays armed in
  `admin_eval_render`, where bundles exist and cheerio is installed.
- **The fix cannot be validated on darwin/local** (cheerio is installed there and bundles are present).
  Its proof must be observed in CI — a bundle-free `fast_checks` checkout going green — see
  Validation Architecture (b). Do NOT accept a local `node evidence-anchor-check.mjs` exit-0 as proof
  of the fix.
- CONTEXT's D-10 already REJECTED the "reorder the npm-ci step earlier" alternative as fragile/positional
  — this ordering discovery is precisely why: any future step insertion could re-break it. Lazy-require
  is order-independent. No conflict with the locked decision; it reinforces it.

### PI-3 — Ahead-count grew 189 → 191 (expected)

Two commits landed after CONTEXT was written (the 220-context capture). Any plan step that quotes
"189 commits" should say "~191 (grows with each ratification commit)" — the exact number is not
load-bearing; the load-bearing fact ("0 behind, sole integration branch") holds.

## Validation Architecture

**nyquist_validation = true.** Map each success criterion to its observable, automatable signal. For
this ship phase the validation surface is CI-observed guard execution + PR check status, not new unit
tests.

### Test / signal framework

| Property | Value |
|----------|-------|
| Framework | Bash/Node CI guard scripts + GitHub Actions checks + `gh` PR status queries |
| Config | `.github/workflows/ci.yml` (`fast_checks` job 67–210; required lanes elsewhere) |
| Quick local run | `MB=$(git merge-base origin/main HEAD); bash scripts/ci/quality-ledger-monotonic.sh --base "$MB"; node scripts/ci/award-guard.mjs --base "$MB"` |
| Full signal | The five ruleset-required checks green on the terminal PR (`gh pr checks <n>`) |

### SC → observable validation signal

| SC | Requirement | Test type | Observable signal (automatable command) | Notes |
|----|-------------|-----------|------------------------------------------|-------|
| SC-1 | Award sub-score cells locked forward under monotonic guard | live-guard | `quality-ledger-monotonic.sh --base <merge-base>` → `PASS (N cells checked)` exit 0 **in CI on the terminal PR's fast_checks**, AND `quality-ledger-monotonic.test.sh` green in the same job. Supplement: `award-guard.mjs --base <mb>` exit 0 + `award-guard.test.mjs` 14/14. | **D-02 live-committed-HEAD proof** (closes 216 SC-5). Record must note award-guard merge-base path is skip (PI-1); substantive lock = quality-ledger's 36 compared cells. |
| SC-2 | Harness runbook committed, re-runnable by zero-context agent | doc-contract | Presence + git-tracked state of `guides/reference/admin-eval-runbook.md` after the D-04 additive-notes commit; manual smoke-read that the 3 orientation notes exist. No automated assertion available — this is the one legitimately manual check. | D-03 keeps the file; D-04 adds 3 notes in one commit. |
| SC-3 | Milestone ships via PR gated on 5 required checks; canary reconciled without weakening guard | integration / positive-byte-proof | (a) Quarantine 3-PNG PR: the **required** `Example Playwright smoke (full lifecycle)` goes **green** (fresh amd64 render == fresh baselines = positive byte-correctness proof) while non-required `fast_checks` reds on the intended canary-modify (D-06, expected). Observe via `gh pr checks <quarantine-pr>`. (b) After merge, terminal PR sees zero PNG diff → all 5 required + fast_checks green. | Push quarantine PR via PAT/manual (D-08) so the 5 required checks actually run (GITHUB_TOKEN authorship suppresses reruns). |
| SC-4 | LLM panel advisory/off-CI; cheerio deterministic gate fixed | ci-observed | After D-10 lazy-require: a bundle-free `fast_checks` checkout runs `evidence-anchor-check.mjs` to `exit 0` **without cheerio installed at step 145** (no `Cannot find module` crash), while `admin_eval_render` (bundles present) keeps the gate armed and PASSing. Confirm no LLM-panel invocation appears in any required-check job (grep ci.yml for panel scripts in required lanes → none). | Must be validated **in CI**, not locally (PI-2). |

### Wave 0 gaps
- None. No new test files required — all four SC signals are existing guard scripts + CI check
  status. The only net-new artifacts are the D-04 runbook notes and the D-02/D-13 close-readiness
  records, which are documentation, not test code.

## Environment Availability

| Dependency | Required by | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `gh` CLI (authed) | Ruleset query, PR #66/#70 state, quarantine PR checks | ✓ | present | none needed |
| `git` (fetch origin) | merge-base drift diff | ✓ | present | — |
| `node` | award-guard.mjs, evidence-anchor-check.mjs | ✓ | (local) | — |
| PAT or push access | D-08 quarantine PR must trigger the 5 required checks | assumed avail | — | Fallback: ship terminal PR with fast_checks red directly (D-06-compliant, worse DX) |

**No blocking gaps.** The one dependency to confirm at execution time is the PAT/manual-push path for
the quarantine PR (D-08) — without it, GITHUB_TOKEN authorship suppresses the required-check reruns and
the green-proof cannot be observed.

## Security Domain

Not applicable as a net-new surface. This is a CI/ship phase: no auth code, schema, endpoint, or crypto
change. The relevant invariant is a **process** control, not an ASVS category: the merge-blocking signal
must stay 100% deterministic and the LLM panel must remain off every required-check job (SC-4 /
JUDGE-CI-01). Verified above that the 5 required checks contain no panel invocation and `fast_checks`
(which hosts the deterministic guards) is intentionally non-required — a PR is mergeable with
`fast_checks` red, which is exactly what makes the D-06 quarantine strategy safe.

## Phase Requirements

| ID | Description | Research support |
|----|-------------|-------------------|
| RATIFY-01 | Award sub-score cells locked forward under monotonic guard; harness runbook committed (how to run one iteration + where human sign-off sits); milestone ships via PR gated on the 5 required CI checks; LLM panel advisory/off-CI throughout | SC-1 lock proven live (quality-ledger-monotonic PASS 36 cells + self-test); runbook exists (D-03) + D-04 notes; 5 required ruleset checks verified verbatim; LLM panel confirmed absent from all required lanes. All load-bearing facts VERIFIED — see Situational Reverification Table. |

## Assumptions Log

| # | Claim | Section | Risk if wrong |
|---|-------|---------|---------------|
| A1 | A PAT or manual-push path is available for the D-08 quarantine PR | Environment Availability | If unavailable, the 5 required checks won't rerun on the quarantine PR; fall back to shipping terminal PR with fast_checks red (D-06-compliant). Low risk — documented fallback. |
| A2 | `admin-eval-runbook.md` content still satisfies the SRE-runbook hallmarks D-03 asserts | Reverification #13 | Not re-audited (D-03 is a locked judgment). If stale, D-04's additive notes may need to be slightly larger. Low risk. |

## Sources

### Primary (HIGH confidence — verified this session via tool)
- `git` (branch, fetch origin main, rev-list left-right, diff --name-status) — branch posture + PNG drift
- `.github/workflows/ci.yml` lines 67–210 (direct read) — guard wiring + step ordering
- `scripts/ci/evidence-anchor-check.mjs` (direct read + grep) — cheerio lazy-require structure
- `scripts/ci/snapshot-canary-guard.sh` (grep) — modify-forbid + never-allowlistable
- `gh api repos/szTheory/sigra/rulesets/14941512` — required status checks
- `gh pr view 66` / `gh pr list --state open` — release-please + PR states
- Live guard execution against merge-base `f2e54612` — quality-ledger-monotonic PASS, award-guard skip-exit-0, self-test 14/14
- `.planning/config.json` — nyquist_validation true

### Secondary (project artifacts, HIGH confidence)
- `.planning/phases/220-terminal-ratification/220-CONTEXT.md` — locked D-01…D-13
- `.planning/phases/219-.../219-VERIFICATION.md` — the two Phase-220 handoffs + 3-PNG proof
- `.planning/REQUIREMENTS.md` (RATIFY-01, line 46), `.planning/ROADMAP.md` (Phase 220 block, SC-1…SC-4)

## Metadata

**Confidence breakdown:**
- Reverification of load-bearing facts: HIGH — every fact re-executed against live HEAD, exact line numbers confirmed.
- Validation architecture: HIGH — signals map to existing guards + CI checks; no new test infra.
- Planning nuances (PI-1/PI-2): HIGH — reproduced directly via live guard runs and ci.yml step-order inspection.

**Research date:** 2026-07-09
**Valid until:** 7 days (fast-moving ship phase — merge-base, PR states, and ahead-count shift as ratification commits land and the quarantine/release-please PRs merge; re-verify the PNG drift and PR #66 state immediately before executing the ship sequence).

## Bottom line

**NO drift found on any load-bearing fact.** All 15 reverification rows are VERIFIED (one with a
benign +2 ahead-count delta). The only findings are two non-drift nuances that sharpen the evidence
framing — PI-1 (SC-1 live-lock proof rests on quality-ledger-monotonic's 36-cell compare, not
award-guard's skip-path exit-0) and PI-2 (the cheerio crash is a CI step-ordering artifact that must
be validated in CI, not locally). The plan should proceed exactly along CONTEXT's locked D-01…D-13
sequence, with the D-02 close-readiness record and the D-10 cheerio-fix proof framed per PI-1/PI-2.
