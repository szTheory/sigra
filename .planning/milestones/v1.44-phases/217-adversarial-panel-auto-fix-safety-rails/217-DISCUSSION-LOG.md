# Phase 217: Adversarial Panel + Auto-Fix Safety Rails - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in 217-CONTEXT.md — this log preserves the analysis.

**Date:** 2026-07-04
**Phase:** 217-adversarial-panel-auto-fix-safety-rails
**Mode:** assumptions (+ deep 4-cluster subagent research at operator request)
**Areas analyzed:** panel runtime/home, panel I/O contract, finding_id reconciliation, k=3 consensus +
content-hash cache, fix queue + auto-fix safety rails, graphic-design lens

## Assumptions Presented (initial gate)

| Area | Assumption | Confidence | Evidence |
|------|-----------|-----------|----------|
| LLM invocation | Thin Node `@anthropic-ai/sdk` script, browser-free, reads bundles, opus-4-8, output_config.format, off-CI | Confident | no LLM infra in repo; `panel-schema-check.sh` RETIRED; runbook "217 will add panel step" |
| I/O contract | Rendered evidence only; parallel `panel-findings.json`; forced-floor lint | Confident | persona rubric schema; `admin-eval.spec.ts` finding shape; monotonic guard invariant |
| finding_id | `class="<lens>:<question>"` → byte-identical `sha256(surface\0class\0anchor)` | Confident | `admin-eval-schema.md` UNRESOLVED SEAM path #1; 216 D-22 |
| k=3 + cache | 3 samples, ≥2/3 quorum on finding_id, cache keyed render_sha256 | Confident (post-research) | render_sha256 canonical hash; self-consistency lit |
| Fix queue + rails | committed JSON keyed finding_id; bash/git loop; per-surface baseline; injected test | Likely | `quality-findings-monotonic.sh`; award ledger; 216-08 seeded defects |
| Graphic-design lens | judgment-of-taste only; new sibling file; picks up probe #9 salience | Likely | 216 D-15/D-16; D-19 sibling precedent; brand v2 |

## Corrections Made

### k=3 consensus — model contract (BLOCKER surfaced by research, verified against claude-api skill)
- **Original assumption:** "k=3 samples at temperature 0.7 on claude-opus-4-8 … opus-4-8 chosen to keep the
  sampling knob."
- **Correction:** `claude-opus-4-8` **400s on `temperature`/`top_p`/`top_k`** (sampling params removed on
  Opus 4.7/4.8) — the "keep the knob" premise is void. Verified authoritatively via the bundled `claude-api`
  skill (`shared/model-migration.md` → Migrating to Opus 4.8; `shared/error-codes.md`). The k=3 architecture
  HOLDS — sample diversity comes from the model's inherent non-greedy sampling + adaptive thinking across
  independent requests (free, undialable). If pilot samples are too agreeable: raise k or vary prompt/effort
  per sample — never reach for temperature. Folded into D-08.
- **Reason:** proof/truth-relevant model contract; the whole consensus design rested on the false premise.

### Auto-fix autonomy scope (operator decision at the initial gate)
- **Original assumption (AUTOFIX-02 literal):** auto-apply copy / token-swap / component-swap.
- **User correction:** **copy + token-swap ONLY**; component-swap → human queue.
- **Reason:** OpenRewrite "do-no-harm" + research that component substitution can change layout/behavior
  (not byte-scoped/semantics-preserving). Folded into D-13.

### CSS auto-apply scope (research-surfaced footgun)
- **Refinement:** `sigra_admin.css` lives in 3 lockstep copies (template / example / golden fixture); a
  token swap there is a fragile multi-file atomic op that trips `golden_diff_test` + the drift guard.
  217 confines auto-apply to admin LiveView `.heex` attributes / inline-`style=` + the example; CSS-token
  fixes route to human until a later phase folds installer/golden regen into the loop. Folded into D-13.

## Deep Research (operator requested: "research deeply, one-shot a coherent rec set")

Four parallel research subagents (gsd-phase-researcher × 3 + gsd-ui-researcher) each carried the operator's
lens set (software architecture / SWE / DevOps / SRE, ecosystem-idiomatic, prior-art lessons, DX, and — for
the design lens — creative direction / UX / brand / JTBD). All four returned mutually-coherent designs; the
one load-bearing correction (temperature/opus-4-8) was verified against the `claude-api` skill before
locking. Every Likely assumption was firmed to a decisive recommendation (D-01..D-18). No open questions
remained above the escalation threshold.

## External Research Applied

- **Anthropic SDK:** `output_config.format` schema-constrained JSON (enum/const/anyOf OK; no numeric/length
  constraints; `additionalProperties:false`); base64 image input; adaptive thinking default; no assistant
  prefill; `claude-opus-4-8` rejects sampling params. (Sources: bundled `claude-api` skill.)
- **Self-consistency / LLM-as-judge:** temp≈0.7 is the classic knob but unavailable here; quorum on a
  deterministic key is the churn-guard; judges noisier on magnitude than existence → admit on existence,
  worst-verdict on magnitude. (arXiv 2510.17472; Wang et al. 2022; Zheng et al. 2023.)
- **Auto-fix prior art:** OpenRewrite (semantics-preserving edit classes), ESLint `--fix` vs suggestions,
  Betterer (per-file baseline floor beyond a count guard), Renovate automerge (endless-loop → poison-set),
  SonarQube new-code reference-branch (diff-scoping), codemod safety.
- **Design-critique prior art:** Nielsen heuristics / Material design review — adopt the vocabulary, reject
  the generic scope; anchor every finding to a named Sigra brand pillar.
