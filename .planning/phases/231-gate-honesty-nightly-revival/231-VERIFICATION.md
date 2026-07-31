---
phase: 231-gate-honesty-nightly-revival
verified: 2026-07-31T14:53:40Z
status: passed
score: 5/5 requirement-level truths verified; GATE-01 closed by the first post-merge scheduled nightly
behavior_unverified: 0
overrides_applied: 0
human_verification: []
---

# Phase 231: Gate Honesty + Nightly Revival Verification Report

**Phase Goal:** Every gate that reports green is asserting something on a lane that actually ran, and a red lane produces a signal a human sees.
**Verified:** 2026-07-31
**Status:** passed
**Re-verification:** Yes — post-merge scheduled-nightly receipt

## Method

The initial verification did not trust `231-EVIDENCE.md`, the eleven SUMMARYs, or `REQUIREMENTS.md`'s own checkbox states at face value. For every claim checked below, it independently re-ran the cited command against the live repository and/or the real GitHub API. The 2026-07-31 re-verification additionally queried the first post-merge scheduled run directly: run `30607570671`, event `schedule`, merge SHA `4bba9c71ae95a51bc2c3586010518a1c3439ab5f`, overall `success`, with 25 successful jobs and only the correctly gated red-notification job skipped.

## Goal Achievement

### Observable Truths (ROADMAP.md Success Criteria 1-5)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | GATE-01 — nightly scheduled run concludes green, or every remaining red is a filed/diagnosed/owned defect | ✓ VERIFIED | The first scheduled run after PR #125 merged is run `30607570671` (`event: schedule`, merge SHA `4bba9c71ae95a51bc2c3586010518a1c3439ab5f`, `conclusion: success`). All 25 executing jobs succeeded. The only skipped job was `Notify on red ci-gate (release-lane-rot)`, correctly gated off because `ci-gate` succeeded. Both formerly-red lanes—`Generated admin Playwright smoke` and `Admin eval render + probe`—executed and passed. |
| 2 | GATE-02 — generated-host parity verified on a lane that executes on a real PR | ✓ VERIFIED | `ci.yml:1702-1722` independently read: no `if:` clause on `generated_admin_playwright_smoke` (the stale `head_ref == 'ship/v1.42-ci-gate-remediation'` condition is gone, confirmed absent repo-wide via `grep -n head_ref ci.yml` — only a historical comment referencing it remains). Confirmed present in `ci-gate.needs` (`ci.yml:1858`), so it is merge-blocking. Independently re-queried `gh run view 30521272305` / `30523049209` — both `conclusion: success`, non-`skipped`, real durations. Independently re-checked the phase's **final PR run** `30534368644` (sha `60452d20`) myself: `Generated admin Playwright smoke: success`, `ci-gate: success`, zero failed jobs across all 24 jobs. A later HEAD run (`30536366413`, sha `94e44dee`) was still in-flight at verification time but had already reported `Generated admin Playwright smoke: success` with zero failures on any completed job — a 13th+ consecutive green. The two genuine cross-run intermittents 231-05/231-06 found and reported (not hidden) both independently confirmed, via `git log --format=iso-strict`, to predate the round-4 corrected commit `70bed477` (landed 2026-07-30T02:10:47-04:00; the two flakes were on commits `18c2720a`/`be970b50`, both 2026-07-29T22:45–23:26-04:00, i.e. hours before the fix landed) — the ledger's "predates round-4" claim is not a post-hoc rationalization, it is chronologically accurate. |
| 3 | GATE-03 — `ci-gate` fails on a rotted skip, passes on a correctly event-gated skip, both on real runs | ✓ VERIFIED | Independently read `ci.yml:1836-1900`: `ci-gate` checks out the repo and runs `bash scripts/ci/honest-skip-verdict.sh` as a step ahead of the legacy loop, fed from `needs.*.result` for all nine `ci-gate.needs` lanes. Independently ran `bash scripts/ci/honest-skip-verdict.test.sh` myself: 20/20 passed, including Test T confirming the wiring order and Test R confirming the script's lane list agrees with the live `ci-gate.needs`. Independently re-queried the three cited runs (`30526744204` clean control, `30526771018` rot probe, `30526727106` live PR run) via `gh run view --json jobs` — conclusions match the ledger exactly (`success`, `failure`, `success`). |
| 4 | GATE-04 — `admin_eval_render` concludes success on its lane, and `stale-render-guard.sh`/fix-queue/anchor checks demonstrably execute | ✓ VERIFIED (literal text) | Independently read `ci.yml:2547-2560`: no job-level `continue-on-error` remains on `admin_eval_render` (confirmed via `grep -n continue-on-error ci.yml` — only the step-level one at `:2650`, correctly retained per D-13, and one unrelated design-lane occurrence at `:2207`). Independently ran the p05 prohibition test: it now asserts the job-level mask is **absent** (forward-only ratchet, `assert.doesNotMatch`), not present — confirming 231-06's inversion actually landed, not merely claimed. Independently re-queried both cited runs (`30512523387` job `90775422130`, `30514238789` job `90780471290`) — both `conclusion: success`. See "GATE-04 disposition" below for the ci-gate.needs question this row's status note addresses. |
| 5 | DX-05 — `gate-ci-green` completes inside its polling ceiling; a red-probe creates a tracking issue | ✓ VERIFIED | Independently read `release-please.yml`: `timeout-minutes: 75` on the `gate-ci-green` job (`:99`) and `bash scripts/ci/wait-for-ci-gate.sh --max-attempts 120` (`:126`) — both match the claimed D-20 fix exactly. Independently ran `bash scripts/ci/wait-for-ci-gate.test.sh`: 11/11 passed. Independently ran `bash scripts/ci/notify-failure-issue.test.sh`: 7/7 passed, including the self-heal label-creation branches (D, E, G). Independently queried `gh issue view 118` — `state: OPEN`, label `release-lane-rot` present on the repo (`gh label list`), 47 comments (more than the ledger's cited 3, consistent with the extensive rot-probe and gap-closure dispatch activity this phase itself generated — not a discrepancy). |

**Score:** 5/5 fully closed on live codebase and GitHub Actions evidence.

### GATE-04 disposition — the verifier's independent call, as requested

At initial verification, `REQUIREMENTS.md` and `ROADMAP.md` left GATE-04 unchecked, citing that `admin_eval_render` is absent from `ci-gate.needs` and does not run on `pull_request`. The verifier independently checked both the literal requirement text and the actual architecture:

- **GATE-04's literal text** ("`admin_eval_render` runs green on its new lane, and the harness guards downstream of its Playwright phase demonstrably execute") does not mention `ci-gate.needs` or merge-blocking status anywhere.
- **`admin_eval_render` was never intended to be merge-blocking.** The job's own in-repo comment predates this phase (Phase 216 / JUDGE-CI-01): "NOT in `ci-gate.needs` — this is the expensive render evidence job, not the merge gate. The merge-blocking forward-only signals are the committed-ledger guards in `fast_checks`." Requiring `ci-gate.needs` inclusion would be a new requirement invented at verification time, not a restatement of GATE-04's actual text.
- **The evidence is concrete and independently reproduced twice**, on two different commits, the second with the job-level mask already removed (a genuine hard signal, not `continue-on-error`-cushioned): banners `(b1)` through `(b6)` plus `PASS — all phases green`, `conclusion: success` both times.

**Verdict: GATE-04's literal text is satisfied.** Its requirement is recorded Complete. This is not a gap in the phase—deliberately leaving the bookkeeping to verification, as 231-06's own key-decisions state, was a reasonable division of labor.

### GATE-01 disposition — the verifier's independent call

GATE-01 is **closed** by run `30607570671`, the first `schedule`-triggered `ci.yml` run after PR #125 merged. It used the merge commit, completed green, exercised both previously-red jobs successfully, and produced no new red lanes requiring the fallback defect-disposition branch. The owner accepted this live run as the human UAT receipt on 2026-07-31.

The related Pages-source backstop did not self-heal. Scheduled publisher run `30613728531` succeeded on the same merge SHA and executed both the `gh-pages` publish and REST configuration steps, but the ensure-script log recorded `Pages API PUT returned 403`. The live API still reports `main` / `/` with status `errored`. That outcome is already filed, diagnosed, and owned at `.planning/todos/pending/2026-07-29-github-pages-source-builds-main-root-not-gh-pages.md`; it remains a deferred repo-admin action and does not contradict the green `ci.yml` nightly.

### Required Artifacts (spot-checked, not exhaustive — full list in 231-EVIDENCE.md)

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `scripts/ci/honest-skip-verdict.sh` + `.test.sh` | GATE-03 verdict logic, hermetic | ✓ VERIFIED | Exists, 20/20 self-test passing (re-run), wired into `ci.yml:1877-1900` |
| `scripts/ci/wait-for-ci-gate.sh` + `.test.sh` | Extracted DX-05 polling loop | ✓ VERIFIED | Exists, 11/11 self-test passing (re-run), invoked at `release-please.yml:126` |
| `scripts/ci/quality-findings-monotonic.sh` (floor-rebase mechanism) | Sanctioned, bounded, fail-closed re-baseline path | ✓ VERIFIED | See dedicated section below — independently exercised, not just read |
| `scripts/ci/fix-queue-lint.sh` (proxy exemption) | Bounded exemption, clauses (a)/(b) still apply | ✓ VERIFIED | 7/7 self-test passing (re-run), including Test 6 (two real surfaces still fail) and Test 7 (proxy exempt) |
| `.github/ci-skip-manifest.tsv` | 16 rows post-GATE-02 (was 17; `generated_admin_playwright_smoke` row removed since it no longer skips) | ✓ VERIFIED | Independently counted: 16 data rows |
| `guides/reference/floor-rebase-declarations.json` | One declaration, bounded to the 231-05 rebase | ✓ VERIFIED | Parses; independently validated against real git history (see below) |

### Independent exercise of the floor-rebase mechanism (item flagged for special scrutiny)

This was checked by running the actual guard against actual git history, not by reading the SUMMARY's description of it:

```
$ bash scripts/ci/quality-findings-monotonic.sh --base be970b50^   # the true pre-rebase parent
quality-findings-monotonic: INFO: declaration 30509363963 verified and authorizes 114 cell(s)
quality-findings-monotonic: PASS (checked vs be970b50^)

$ git show be970b50^:guides/reference/admin-render-sha.json | <sum open_findings>
33642   # matches the declaration's prior_totals sum exactly

$ node -e "<sum current guides/reference/admin-render-sha.json open_findings>"
38016   # matches the declaration's new_totals sum exactly, and matches the "truth is 38,016" figure
        # given in this verification's task brief

$ bash scripts/ci/quality-findings-monotonic.sh --base be970b50   # a base that ALREADY contains the rebase
quality-findings-monotonic: INFO: declaration ... does not match the actual base/head ledger content — ignored
quality-findings-monotonic: PASS (checked vs be970b50)   # trivially passes: base==head, no increase to authorize
```

**Independently confirmed fail-closed and bounded:**
- Comparing across the *actual* pre-rebase→post-rebase git boundary, the declaration validates and authorizes exactly the claimed 114 cells — not fabricated, not approximate.
- The hermetic self-test suite's negative controls (Tests E, F, H) were independently re-run: absent-declaration still fails (E), a mismatched declaration is rejected (F), and drift beyond the declared floor still fails (H) — all 11/11 passing on independent re-run.
- The mechanism verifies **both** `prior_totals` and `new_totals` against actual ledger content before authorizing anything (read directly from the script source, not inferred) — a declaration cannot be used to launder an unrelated increase, and a stale declaration goes inert the moment `BASE` moves past the commit it describes (independently confirmed: comparing at `be970b50` itself, where the transition is no longer visible, correctly reports the declaration as non-matching and falls through to the trivial base==head pass).

**Conclusion: this is a genuinely bounded, auditable, one-time escape hatch, not a hole.** It cannot be reused for a second, different increase (the exact-match requirement on both sides ties it to one specific transition), and its absence-is-fail-closed default means a future phase that adds no declaration gets today's exact strict behavior.

### Probe reconciliations (item flagged for special scrutiny)

Independently read the actual diffs, not just the SUMMARY's narrative:

- **Pill/code sub-scale tokens** (`probes.ts`): independently confirmed the allowance is scoped to `PILL_CLASSES = ['sg-scope-pill', 'sg-status-pill', 'sg-badge']` and a `.sg-code` classlist check — not a global scale-array widening. The SUMMARY itself documents that the first attempt *was* global and was corrected on review; this verification independently confirms the corrected, scoped version is what's actually in the tree.
- **Gallery-frame card nesting**: independently confirmed exactly 2 occurrences of `data-sg-card-nesting-audit-only` in `design_gallery_live.ex` (lines 98, 393) — matching "the two gallery board wrapper divs" claim precisely, not a broader suppression.
- **`fix-queue-lint.sh` proxy exemption**: independently confirmed the exemption is scoped to the cross-surface agreement check only (clauses (a) non-negative and (b) `<= totalUncollapsed` are unconditional, per direct source read) and independently re-ran its fail-first negative control (Test 6: two real surfaces disagreeing still fails).

**Conclusion: none of the three reconciliations lets a real defect pass.** Each is scoped to the exact selector/surface the cited design decision covers, with a fail-first regression test proving the narrower case is still caught.

### Deferred/filed items — independently confirmed discoverable

| Item | Filed at | Confirmed |
|------|----------|-----------|
| D-18 Pages source, post-merge backstop | `.planning/todos/pending/2026-07-29-github-pages-source-builds-main-root-not-gh-pages.md` | ✓ exists |
| D-25 `example_unit_smoke` absent from `ci-gate.needs` | `.planning/todos/pending/2026-07-29-example-unit-smoke-required-but-absent-from-ci-gate-needs.md` | ✓ exists |
| `Upgrade smoke` pre-existing `<.button type>` debt | `.planning/todos/pending/2026-07-10-upgrade-smoke-button-type-hex-publish.md` (pre-existing, cross-referenced) | ✓ exists |
| Recapture-job transient hex.pm mirror flake | `.planning/todos/pending/2026-07-30-recapture-job-transient-hexpm-mirror-failure.md` | ✓ exists |
| Audit-presets Actor-filter race | `.planning/todos/pending/2026-07-30-admin-generated-audit-presets-actor-filter-race.md` | ✓ exists |
| `sigra_auth.css` mirror drift (~412 vs ~1134 lines) | `.planning/todos/pending/2026-07-28-w2-example-sigra-auth-css-stale-no-parity-gate.md` (pre-existing, still accurate post-fix) | ✓ exists |

All six items are filed, discoverable, and none is silently absorbed into a "complete" claim anywhere in this phase's artifacts.

### Anti-Patterns Found

Scanned every `.sh`/`.mjs`/`.yml`/`.ts`/`.ex` file touched by this phase (`git diff --name-only origin/main...HEAD`) for `TBD`/`FIXME`/`XXX` without a tracking reference: **zero unreferenced debt markers found.**

One minor, non-blocking documentation staleness found during initial verification was corrected during close-out: `ci-observe.yml:78` no longer describes the removed schedule-lane leniency branch.

### Requirements Coverage

| Requirement | Status per REQUIREMENTS.md | Verifier's independent assessment |
|---|---|---|
| GATE-01 | Complete | ✓ Confirmed — scheduled run `30607570671` succeeded on the PR #125 merge SHA |
| GATE-02 | Complete | ✓ Confirmed — independently re-verified on live `ci.yml`, live runs, and this verification's own re-check of the final PR run |
| GATE-03 | Complete | ✓ Confirmed — independently re-verified wiring, tests, and live runs |
| GATE-04 | Complete | ✓ Confirmed — literal text is satisfied (see disposition above) |
| DX-05 | Complete | ✓ Confirmed — independently re-verified script extraction, wiring, tests, and issue #118 |

No orphaned requirements found — all five requirement IDs declared in phase plans map to entries in `.planning/REQUIREMENTS.md`'s Phase 231 rows, and there are no additional `Phase 231` rows the plans didn't claim.

## Gaps Summary

No blocking gaps found. Every piece of code this phase claims to have shipped was independently confirmed present, substantive, and wired—not merely read from a SUMMARY. The floor-rebase mechanism and the three probe reconciliations were independently re-exercised and found genuinely bounded. GATE-01's post-merge observation is now complete via scheduled run `30607570671`. D-18's Pages-source self-heal remains a filed, diagnosed, owned deferred repo-admin action and is not a blocking phase gap.

---
*Verified: 2026-07-31*
*Verifier: Claude (initial gsd-verifier) + Codex (post-merge receipt)*
