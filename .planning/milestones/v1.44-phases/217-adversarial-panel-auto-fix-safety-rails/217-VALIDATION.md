---
phase: 217
slug: adversarial-panel-auto-fix-safety-rails
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-04
---

# Phase 217 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Derived from `217-RESEARCH.md` § Validation Architecture. Through-line: **every
> Success Criterion is provable by a committed-ledger diff or a hermetic
> `.test.sh`/`.test.mjs` EXCEPT SC-2's "zero LLM calls" reality and SC-4's live
> companion — those follow 216-09 SC-5 discipline (hermetic test proves wiring;
> one off-CI live run at final committed HEAD proves reality).**

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Existing 216 tri-modal harness: Bash `*.test.sh` (mktemp-hermetic) + Node `*.test.mjs` + Playwright TS `.test.ts` |
| **Config file** | none for guard self-tests (each `.test.sh`/`.test.mjs` is standalone, browser-free); Playwright config in `test/example/priv/playwright/` |
| **Quick run command** | `bash scripts/ci/<guard>.test.sh` / `node scripts/ci/<guard>.test.mjs` (each < a few seconds) |
| **Full suite command** | the `fast_checks` job's self-test steps (each guard self-test is a named `fast_checks` step) |
| **Estimated runtime** | ~seconds per guard self-test; full `fast_checks` self-test list ~1–2 min |

---

## Sampling Rate

- **After every task commit:** Run the relevant `<guard>.test.sh` / `.test.mjs` (browser-free, seconds).
- **After every plan wave:** Run the full `fast_checks` self-test list + `fix-queue-lint.sh` + `panel-forced-floor-check.mjs` + `panel-verdicts-lint.sh`.
- **Before `/gsd-verify-work`:** Full `fast_checks` green + SC-2 call-counter test green + SC-4 hermetic test green + ONE off-CI live run (SC-2 zero-calls reality + SC-4 `board-autofix-seed` companion) captured on a **clean tree at final committed HEAD**.
- **Max feedback latency:** < 120 seconds for the deterministic (hermetic/committed-ledger) half of every SC.

---

## Per-Task Verification Map

> SC = Success Criterion (ROADMAP Phase 217). `File Exists` = ❌ W0 means the guard/fixture is a Wave 0 build.

| SC | Requirement | Secure Behavior | Test Type | Automated Command | Committed-ledger provable? | File Exists |
|----|-------------|-----------------|-----------|-------------------|----------------------------|-------------|
| SC-1 | PANEL-01 | Forced-finding floor holds on clean surfaces; every lens×question cell carries a cited structural anchor OR literal `NONE — searched for: <what>` | at-rest lint over `panel-findings.json` | `node scripts/ci/panel-forced-floor-check.mjs` (12-cell grid complete, rejects empty/vague NONE, validates anchors via shared `isStructuralAnchor`) | YES — committed `admin-panel-verdicts.json` grid + forced-floor lint prove shape with zero LLM call | ❌ W0 |
| SC-2 | PANEL-02 | k=3 ≥2/3 quorum; unchanged surface → **zero new LLM calls + zero finding churn** | hermetic call-counter + committed-verdicts diff | (a) `node scripts/panel/judge.test.mjs` asserts `callCount === 0` on a `render_sha256` cache hit (SDK test-double); (b) `git diff admin-panel-verdicts.json` empty on unchanged tree | PARTIAL — quorum + carry-forward provable by committed diff (`sample_key_sets` audit); zero-calls needs call-counter test; live reality needs one off-CI run w/ `ANTHROPIC_API_KEY` | ❌ W0 |
| SC-3 | PANEL-02 / AUTOFIX-01 | All findings dedup into one `finding_id`-keyed fix queue; cross-surface recurring anchors collapse into high-priority systemic parents at top | committed-ledger diff + lint | `node scripts/ci/fix-queue-build.mjs && bash scripts/ci/fix-queue-lint.sh` (recomputes `auto_eligible`/`priority`/`systemic_group`; asserts `open = built − settled`) | YES — `fix-queue.json` committed + derived; lint recomputes every field + systemic collapse deterministically | ❌ W0 |
| SC-4 | AUTOFIX-01 / AUTOFIX-02 | Injected clunky change (off-token spacing / ember misuse / misalignment) → auto-revert FIRES + `quality-findings-monotonic.sh` exits non-zero | hermetic mktemp injected-regression test + live companion | (a) `bash scripts/ci/admin-autofix-loop.test.sh` (mktemp repo, seed count-delta, assert `git log` shows `Revert "autofix...`, reflog clean, ledger restored, finding in `settled-findings.tsv`, `quality-findings-monotonic.sh` non-zero on pre-revert commit); (b) `board-autofix-seed` live board run OFF-CI once | PARTIAL — hermetic `.test.sh` proves WIRING (committed-ledger + git-log); live companion proves REALITY on clean tree at final committed HEAD | ❌ W0 |
| SC-5 | JUDGE-CI-01 (milestone) | Panel NOT in `fast_checks`, NOT in any merge-blocking gate; only deterministic derivatives gate | negative-assertion CI-wiring test | `.test.sh` grep-asserts no workflow `run:` line invokes `admin-panel.sh`/`admin-autofix-loop.sh`; the 5 required checks exclude the panel; `admin-panel.sh` `exit 0`s on missing `ANTHROPIC_API_KEY` | YES — fully static: filesystem split (`scripts/panel/`), Hammer no-op, grep over `ci.yml` | ❌ W0 |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky — filled at execution time per task.*

---

## Wave 0 Requirements

- [ ] `scripts/ci/panel-forced-floor-check.mjs` (+ `.test`) — SC-1 (clone retired `panel-schema-check.sh` shape; read JSON)
- [ ] Extract `scripts/ci/lib/anchor.mjs` exposing `isStructuralAnchor` + resolution helper from `evidence-anchor-check.mjs` (keep that file's byte-behavior identical) — unblocks SC-1 shared-anchor reuse (Pitfall 1)
- [ ] `scripts/panel/panel-schema.mjs` `finding_id` helper (+ `.test` asserting byte-identity with the 216 formula for `(surface, "lens:question", anchor)`, hashing into the `probe_class` slot) — SC-3 seam guard (Pitfall 2)
- [ ] `scripts/panel/judge.test.mjs` call-counter test (SDK test-double, `callCount === 0` on cache hit) — SC-2 zero-calls wiring
- [ ] `scripts/ci/fix-queue-build.mjs` + `scripts/ci/fix-queue-lint.sh` (+ `.test`) — SC-3; also the `open_findings` sole-writer refactor (Pitfall 3 ordering)
- [ ] `scripts/ci/admin-autofix-loop.test.sh` — SC-4 hermetic (clone `quality-findings-monotonic.test.sh`)
- [ ] `board-autofix-seed` board in `design_gallery_live.ex` — SC-4 live companion fixture
- [ ] `.test.sh` grepping `.github/workflows/*.yml` asserting no `admin-panel.sh`/`admin-autofix-loop.sh` `run:` step + `admin-panel.sh` no-op — SC-5
- [ ] Framework install: `npm install --save-dev @anthropic-ai/sdk` (+ `ajv` or `zod`) in the Playwright subproject **after** the legitimacy gate (exact package name/version verified via `npm view`)

*No new global test framework needed — the existing tri-modal 216 harness covers all phase requirements.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| SC-2 "unchanged surface → zero LLM calls" **reality** | PANEL-02 | The call-counter test proves the code path with a test-double; only a real run against the live model proves the cache actually skips. Needs `ANTHROPIC_API_KEY` (off-CI, one-time). | Set `ANTHROPIC_API_KEY`; run `admin-panel.sh` twice on an unchanged tree; assert 2nd run makes 0 API calls (report/log) and `admin-panel-verdicts.json` diff is empty. |
| SC-4 `board-autofix-seed` live companion | AUTOFIX-02 | Hermetic test proves rails fire; live run proves an end-to-end injected regression is caught + reverted at final committed HEAD (216-09 SC-5 discipline). | On a **clean tree at final committed HEAD**, run the auto-fix loop against the seeded board through the real harness; confirm a `Revert "autofix…"` commit + restored ledger. |

*These two are the only non-hermetic verifications; both are off-CI and never gate a merge (JUDGE-CI-01).*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (guards + fixtures above)
- [ ] No watch-mode flags
- [ ] Feedback latency < 120s for the deterministic half of every SC
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
