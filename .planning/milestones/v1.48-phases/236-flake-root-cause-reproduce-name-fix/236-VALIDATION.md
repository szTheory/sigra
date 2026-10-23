---
phase: "236"
slug: "flake-root-cause-reproduce-name-fix"
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-09-15"
---

# Phase 236 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Derived from `236-RESEARCH.md` § Validation Architecture.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework (library)** | ExUnit via `mix ci` alias (`mix.exs:149-157`) |
| **Framework (example app)** | ExUnit, separate working directory (`ci.yml:704,710`) |
| **Framework (browser)** | `@playwright/test` 1.59.1, `admin-generated` project (`playwright.config.ts:160-167`) |
| **Framework (guards)** | `node --test --test-reporter=tap` (`ci.yml:393` glob) |
| **Config file** | `test/example/priv/playwright/playwright.config.ts`; `mix.exs` aliases; no config for `node:test` |
| **Quick run command** | `node --test scripts/ci/prohibitions/p17-no-playwright-retry-wrapper.test.mjs` |
| **Full suite command** | `MIX_ENV=test mix ci` **and** `(cd test/example && MIX_ENV=test mix test --include example_app)` |
| **Estimated runtime** | quick < 1s; full ~6-10 min |

**C-9 correction (from RESEARCH.md):** `mix ci` alone does NOT cover
`test/example/test/example_web/live/admin_audit_index_live_test.exs` — that suite runs in its own
job with its own working directory. The local gate is BOTH commands, not just `mix ci`.

---

## Sampling Rate

- **After every task commit:** `node --test scripts/ci/prohibitions/*.test.mjs` + `mix format --check-formatted`
- **After every plan wave:** `MIX_ENV=test mix ci` **and** `(cd test/example && MIX_ENV=test mix test --include example_app)` **and** `bash scripts/ci/snapshot-canary-guard.sh --base origin/main`
- **Before `/gsd-verify-work`:** full CI green on the PR, plus the SC-3 run-id list captured at the final committed HEAD on a clean tree (standing constraint 2)
- **Max feedback latency:** ~1s per task commit; ~10 min per wave

---

## Per-Task Verification Map

> Task IDs are filled in by the planner. Rows below are the requirement→evidence contract
> each task must attach itself to.

| Task ID | Plan | Wave | Requirement | SC | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|----|-----------------|-----------|-------------------|-------------|--------|
| TBD | TBD | 0 | GREEN-01 | SC-1 | A RED is captured for `toHaveURL` at `admin-generated.spec.ts:459` with a trace and the verbatim received URL | manual-repro (a stochastic flake cannot be a deterministic test) | `npx playwright test tests/admin-generated.spec.ts -g "…" --repeat-each=30 --trace=on` | ❌ W0 — evidence artifact | ⬜ pending |
| TBD | TBD | 0 | GREEN-02 | SC-2 | `audit_index_live.ex` has ≥1 `handle_event/3`, the filter form carries `phx-submit`, filter anchors are `<.link patch>`, `Export CSV` stays a plain `<a href>` | unit (source-contract, `test/sigra/planning/*.exs` idiom) | `mix test test/sigra/planning/phase_236_audit_url_ownership_test.exs` | ❌ W0 | ⬜ pending |
| TBD | TBD | — | GREEN-02 | SC-2 | Dead render still emits byte-identical `href` strings (no DOM drift) | unit | `(cd test/example && MIX_ENV=test mix test test/example_web/live/admin_audit_index_live_test.exs)` | ✅ exists (4 tests) | ⬜ pending |
| TBD | TBD | — | GREEN-02 | SC-2 | Rendered classes/layout unchanged → canary guard green, no PNG recapture lane opens | integration | `bash scripts/ci/snapshot-canary-guard.sh --base origin/main` | ✅ exists (`ci.yml:205`) | ⬜ pending |
| TBD | TBD | — | GREEN-02 | SC-2 | Connected LiveView applies the filter and updates the URL with no document navigation (D-22: wait for `phx:connected` first) | browser | new assertion in `admin-generated.spec.ts` after `waitForLiveViewReady` | ❌ W0 (optional if SC-3 repeated-green suffices) | ⬜ pending |
| TBD | TBD | — | GREEN-01/02 | SC-3 | The job passes on every repeat at a **stated n**, and the SC-1 repro no longer reproduces | live-external observation | `gh run list --workflow CI --branch <fix-branch> --event pull_request --json databaseId,headSha,conclusion,createdAt` + `gh run view <id> --json jobs --jq '.jobs[] \| select(.name=="Generated admin Playwright smoke")'` | ❌ W0 | ⬜ pending |
| TBD | TBD | 0 | GREEN-02 | SC-4 | A retry wrapper fails `p17`, observed RED against a committed known-bad fixture | node:test, RED/GREEN pair | RED: `GSD_PROHIB_SUBJECT=test/fixtures/prohibitions/p17-playwright-retry-wrapper.ts node --test … p17-*.test.mjs` (non-zero) · GREEN: same without the env var (zero) | ❌ W0 | ⬜ pending |
| TBD | TBD | — | GREEN-02 | SC-4 | `PLAYWRIGHT_RETRIES` is gone from `ci.yml` | unit (contract test with a non-vacuity floor, not a bare grep) | fold into `phase_236_*_test.exs`: zero `PLAYWRIGHT_RETRIES` occurrences **and** the `generated_admin_playwright_smoke` block still parses with ≥1 `env:` key | ❌ W0 | ⬜ pending |
| TBD | TBD | — | GREEN-02 | SC-5 | (contingency only) quarantine row lands without breaking the manifest parity guards | node:test + shell | `node --test scripts/ci/prohibitions/p10-no-undocumented-demotion.test.mjs`, `bash scripts/ci/ci-demotion-observer.test.sh`, `bash scripts/ci/honest-skip-verdict.test.sh` | ✅ exist | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/sigra/planning/phase_236_audit_url_ownership_test.exs` — SC-2 source contract, with a non-vacuity floor on the anchor count
- [ ] `scripts/ci/prohibitions/p17-no-playwright-retry-wrapper.test.mjs` — SC-4 guard (auto-discovered by the `ci.yml:393` glob; zero workflow edits)
- [ ] `test/fixtures/prohibitions/p17-playwright-retry-wrapper.ts` — committed known-bad carrying all three violations in one file (D-26)
- [ ] Phase EVIDENCE ledger with `BEFORE-FLAKE-RED` / `AFTER-FIX-GREEN` slots — `_lib.mjs:254` `SLOT_HEADING_RE` requires `## BEFORE-*` / `## AFTER-*` headings with a `Status:` line and run ids as 8-12 digit tokens (`_lib.mjs:282`); read generically by `p12-run-id-provenance.test.mjs`
- [ ] *(conditional, SC-5 contingency branch only)* `.github/ci-skip-manifest.tsv` schema amendment + `p10` `kind=spec` exemption + matching `MAINTAINING.md` entry

*Framework install: none needed.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| SC-1 captured RED | GREEN-01 | Reproducing a stochastic flake is inherently non-deterministic; no assertion can encode "this raced" | Run the Path-A `--repeat-each=30 --trace=on` sequence from RESEARCH.md against a locally booted generated host; record the absolute `trace.zip` path **and the verbatim received URL string** (it is what discriminates D-05's three branches) |
| SC-3 repeated green | GREEN-01/02 | Evidence lives in the GitHub Actions API, outside any test runner; `concurrency.cancel-in-progress: true` forces the pushes to be sequential | Push to the fix PR n times (n stated in the plan), letting each run conclude; harvest the run-id list with per-job conclusions via `gh run list` / `gh run view` |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s for the per-commit sample
- [ ] SC-1 evidence recorded with artifact path + received URL before any `lib/` fix is accepted
- [ ] SC-3's **n** is stated explicitly in the plan (an unstated n is count-only acceptance)
- [ ] SC-4's RED and GREEN exit codes both pasted into the evidence ledger
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
