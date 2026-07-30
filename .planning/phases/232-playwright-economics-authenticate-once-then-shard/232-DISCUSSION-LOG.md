# Phase 232 Discussion Log (assumptions mode)

**Date:** 2026-07-30
**Mode:** assumptions (`workflow.discuss_mode = "assumptions"`)
**Calibration tier:** standard (no `USER-PROFILE.md` present)
**Outcome:** All assumptions accepted as-is. User elected auto-advance; no
corrections were made.

## Methodology lenses applied

- **Decisive Defaulting** — every gray area resolved to a single recommended
  path rather than a preserved option matrix.
- **Escalation Threshold** — nothing here touches the security model, the
  public/semver API contract, the generated-host contract, or what Sigra can
  honestly claim, so nothing was escalated to the user.
- **Research Depth Calibration** — four unknowns had real behavioral risk
  (Playwright filter/dependency interaction, cross-engine storageState,
  matrix-aggregator required-check semantics, composite-action cache
  semantics). All four were researched to primary sources and, where possible,
  verified empirically.
- **Discuss-Phase Default (recommendation-first)** — assumptions presented as
  decisions with evidence, not as a question menu.
- **Prompt And Prior-Art Weighting** — shipped in-repo precedent
  (`library_tests_shard` → `library_tests`) outweighed generic guidance.
- **Phase Context Expectation** — Phase 230/231 CONTEXT files were read first so
  already-decided ground was not re-litigated.

## Assumptions presented

| # | Area | Confidence | Basis |
|---|------|-----------|-------|
| 1 | PW-01 shape: setup project + single shared storageState, seeded admin persona | **Confident** (upgraded from Likely by research topic 1 + 2) | `sigra_admin_policy.ex:19-24`, `personas.ex:58-71`, `adminFlows.ts:65-91`, seeds in every booting job, `.playwright/` already gitignored; `admin-design.spec.ts:108-109` element-scoped screenshots |
| 2 | SC-1 needs a new **step-level** measurement instrument | Confident | `ci-run-metrics.sh:94-124` jq never descends into `.steps[]`; step-level precedent exists but is purpose-bound at `ci-demotion-observer.sh:150,161-165` |
| 3 | Honest expected win is ~175s on PR, not SEED-005's −6/−7.5m | Likely | Phase 230 already moved 84/123 design tests off PR; post-230 critical path 989s (`230-EVIDENCE.md:168,176-178`) |
| 4 | PW-02 shape: matrix-shard with per-shard DB + app, all on port 4000 | Confident | `playwright.config.ts:11-13`; five documented collisions; `ci.yml:2553-2557` PORT compile_env; `config/dev.exs:4-12` PG* env |
| 5 | SC-3 via the shipped shard→aggregator rename template | Confident | `ci.yml:497-622` precedent, `:594-599` failure-mode comment, `MAINTAINING.md:102-113`, four name-keyed consumers |
| 6 | PW-03 via a local composite action, seven call sites | Likely | four `uses:` steps in the block make a shell script insufficient; `ci.yml:2008-2009` self-describes as a verbatim clone (and is stale) |
| 7 | Order PW-01 → measure → PW-03 → PW-02 → measure; 7 hard-fail boundaries | Confident | ROADMAP proof discipline; PW-02 multiplies prelude call sites |

## External research findings

**Topic 1 — do Playwright filters skip dependency projects? (highest leverage)**
Settled favorably. In 1.59.1, `--project=X` auto-pulls X's `dependencies`, and
positional args, `--grep`, `--grep-invert`, and `--shard` select **only primary
tests**; dependency-project tests always run in full. Verified empirically
against the pinned install with a throwaway config in `/tmp` (repo untouched,
`git status --porcelain` clean): both CI-shaped invocations showed the setup
running. Docs: playwright.dev/docs/test-projects. Unchanged 1.40→1.59
(microsoft/playwright#28296, #36120).
→ Decides D-01. Eliminates the tagging workaround; `ci.yml:1497-1503` and
`:1525-1530` need no change.
Hazard found: with fewer spec files than shards, `--shard=2/2` ran **zero
tests, skipped setup, and exited 0** silently → D-19.

**Topic 2 — is storageState portable across engines/emulation?**
Settled. Engine- and emulation-agnostic; schema in
`playwright-core/types/types.d.ts` (~L9417) has no engine or UA field; docs
confirm cross-browser reuse. Sigra records `user_agent`
(`session_stores/ecto.ex:123`) but never rejects on mismatch.
→ Decides D-03. Caveats → D-04 (exact origin matching) and D-05 (silent
failure ⇒ explicit assertion).

**Topic 3 — matrix job naming vs required status contexts**
Settled. A static `name:` on a matrix job gets ` (value)` appended;
interpolating the matrix value avoids it. The aggregator pattern works **only
with `if: always()`** — a job skipped because its `needs` failed reports
success, so without `always()` a failing shard lets the PR merge.
→ Decides D-21, D-22.

**Topic 4 — composite action capabilities and cache semantics**
Settled; prior belief confirmed. `actions/cache` post-save is correct one level
deep only (actions/runner#2030). Step ids are action-scoped, so `cache-hit`
must be re-exported via `outputs.<id>.value`. `shell:` required; inputs are
strings; `$GITHUB_ENV` leaks outward; `continue-on-error` unsupported on
composite steps; no `secrets:` block.
→ Decides D-28, D-29. Critical collision surfaced: `ci.yml:1333-1355` records
that `admin_eval_render` has **no** cache step as a deliberate guarantee →
D-27.

## Todos cross-referenced

29 matched the phase scan. Folded in: `2026-06-20-playwright-parallelization-per-shard-db.md`
(direct PW-02 match). All others reviewed and listed in the CONTEXT
`<deferred>` section as reviewed-not-folded — they are Phase 230/231 subject
matter already handled, or out of scope.

## Corrections made

None. Auto-advanced at the user's direction.
