# Phase 34 — Research

**Phase:** 34 — Generated-Host E2E Coverage and Phase 28 Retroactive Verification  
**Question:** What do we need to know to plan this phase well?

## Summary

Phase 34 closes **VFY-01** on the **generated-host** path by (1) extending `admin-generated.spec.ts` with three narrow, grep-addressable flows aligned with `34-CONTEXT.md` D-06–D-12, (2) extending `scripts/ci/admin-acceptance-smoke.sh` with `--test audit-export` and `--test impersonation-controller` while preserving mandatory bash parity probes before Playwright (`34-CONTEXT.md` D-13–D-16), and (3) authoring **`28-VERIFICATION.md`** using the same audit-grade skeleton as `30-VERIFICATION.md` / `32-VERIFICATION.md` with three evidence lanes (`34-CONTEXT.md` D-01–D-05).

The smoke script’s deterministic seed currently creates **only** platform and org admins. **Authenticated impersonation** against a **non–platform-admin** target requires a **third confirmed user** in the embedded seed snippet (new env var e.g. `SIGRA_IMPERSONATION_TARGET_EMAIL`, registered + confirmed like the two admins).

Playwright patterns should mirror **`impersonation.spec.ts`** (sudo gate → start → observable outcome) and **`admin-audit.spec.ts`** (CSV header / content-type) but stay **shallow** on the generated host—no duplication of ExUnit negative matrices.

CI job **`generated_admin_playwright_smoke`** should keep a single `scripts/ci/admin-acceptance-smoke.sh --test all` entrypoint; optional **`timeout-minutes: 60`** and **`PLAYWRIGHT_RETRIES`** (or config `retries`) address flake without re-scaffolding (`34-CONTEXT.md` D-17–D-18).

## Technical Notes

| Topic | Finding |
|--------|---------|
| Bash vs browser | Unauthenticated POST probe stays bash-only (proves controller load); authenticated impersonation success is Playwright-only per existing script comments (`admin-acceptance-smoke.sh` ~278–287). |
| CSV assertions | Assert HTTP 200, `content-type` includes `csv` (case-insensitive), body contains stable header substring from library/export contract—avoid full body snapshot. |
| `--test all` | Must remain bash probes + full `admin-generated.spec.ts` (union of slices); new `--test` values run the same bash block then a filtered Playwright invocation (`-g` regex on `test.describe` / test titles). |
| Phase 28 doc | Minimum **5** must-have rows tied to ROADMAP Phase 28 success criteria; cite `28-VALIDATION.md` spot-check commands where applicable (`34-CONTEXT.md` D-03, D-04). |

## Risks

- **Flake:** LiveView + sudo timing—reuse `waitForLiveViewReady` / web-first assertions from example specs; prefer Playwright project `retries` in CI over sleeps.
- **Order coupling:** `--test` grep strings must match stable test/describe titles—document exact strings in smoke script header.

## Validation Architecture

This phase is **verification-heavy** (Playwright + bash + documentation). Nyquist sampling applies per plan wave:

| Dimension | Strategy |
|-----------|----------|
| Automated proof | `GITHUB_WORKSPACE=$(pwd) scripts/ci/admin-acceptance-smoke.sh --test all` is the integration gate; slice runs `--test audit-export` / `--test impersonation-controller` reproduce CI semantics locally. |
| Library correctness | Unchanged Phase 28/30/32 ExUnit matrices remain authoritative; generated-host tests prove **wiring + session + export HTTP**, not full CSV row semantics. |
| Documentation | `28-VERIFICATION.md` rows must cite file paths + commands; generated-host lane shows ✓ after Plan 01–02 green, or honest `? SKIP` with exact command before automation lands. |

Executor sampling: after tasks touching Playwright, run `cd test/example/priv/playwright && npx playwright test tests/admin-generated.spec.ts --list`; after smoke edits, `bash -n scripts/ci/admin-acceptance-smoke.sh`.

---

## RESEARCH COMPLETE
