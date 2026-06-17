# Phase 191: Microcopy & IA Sweep - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in 191-CONTEXT.md — this log preserves the analysis.

**Date:** 2026-06-17
**Phase:** 191-microcopy-ia-sweep
**Mode:** assumptions (+ deep multi-subagent prior-art research at maintainer's direction)
**Areas analyzed:** copy provenance/parity · current-copy compliance & drift · snapshot/assertion
blast radius (191↔192 sequencing) · glossary artifact + enforcement · "ledger raised" realization ·
surface scope + auth-preview carve-out

## Assumptions Presented (round 1 — gsd-assumptions-analyzer)

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Admin copy is single-source library-owned; no three-surface byte-parity duty | Confident | `router_injection.ex:35-40`; 190-CONTEXT D-06; no `*_live.ex` mirrors under `priv/templates` |
| Real synonym drift exists → 191 rewrites, not just ratifies | Confident | `users_index_live.ex:108/135/355` (sign in/sign-in), `organization_live.ex:77` (org), member/teammate/user mix |
| Visible-string edits break both text assertions AND screenshot baselines → 191↔192 sequencing | Confident (mechanism) | `admin-checkpoints.spec.ts` getByText/toContainText + 2 `toHaveScreenshot`; `snapshot-canary-guard.sh` |
| Glossary at `guides/reference/admin-glossary.md` + enforcement guard | Likely | reference-doc siblings; existing `scripts/ci/*.sh` guard patterns |
| "Ledger raised" = +1 branding L3 row + D9/D10 re-score (monotonic) | Likely | per-surface ledger schema; folded maintainer-pinned todo |
| Scope = 7 admin LiveViews + components; carve out `branding_live` auth preview | Confident (escalation flag) | `branding_live.ex:601` `sigra-auth--preview` `<h1>Log in</h1>` |

## Maintainer Direction

Maintainer twice answered the framed confirmation with a standing directive (not a selection):
"research deeply with subagents — pros/cons/tradeoffs, idiomatic Elixir/Phoenix, lessons from
successful auth/admin products in any ecosystem, DX/UX, design-system/microcopy/persona-psychology
lenses, mine the `prompts/` corpus (brand book v2 is current source of truth) — then one-shot a
perfect *coherent* set so I don't have to think." → resolved all forks from evidence; no menus preserved.

## Deep Research (4 parallel subagents)

1. **Terminology-governance tooling** (gsd-advisor-researcher) — compared ExUnit test vs bash CI
   guard vs Vale vs Credo for glossary enforcement. **Verdict: ExUnit test** (Vale is markup-only,
   can't parse `.ex`/`.heex` to isolate visible strings or honor the carve-out; FP-tolerant culture
   vs merge-blocking need). Bash guard = runner-up. Sources: Vale docs, GOV.UK A–Z, Polaris/Carbon.
2. **Multi-tenant auth vocabulary/IA** (gsd-advisor-researcher) — WorkOS/GitHub/Clerk/Auth0/Slack/
   Linear converge on user(global)≠member(org-scoped); Polaris remove-vs-delete; GOV.UK/MS "sign in".
   Produced the full canonical term table (D-02). Confirmed member≠user is schema-backed, not drift.
3. **Operator microcopy rubric** (gsd-advisor-researcher) — NN/g + GOV.UK + Polaris + Carbon →
   concrete pass/fail rubric (plain-language gate + error/empty/success/warning), decisive
   enumeration-boundary branch, before/after rewrites. Register = maintainer-grade technical.
4. **prompts/ corpus + repo mechanism** (general-purpose) — confirmed brand book v2 is source of
   truth (no competing prompt voice guidance); mined Field Guide glossary + JTBD persona mapping;
   documented the exact Phase-183 self-contained recapture sequence to mirror (D-10).

## Corrections / Refinements vs round-1 assumptions

- **Glossary enforcement:** moved from bash guard (assumed) → **ExUnit test** (research-decisive).
- **Vocabulary:** "member vs user" elevated from "Likely document the distinction" → **Confident,
  load-bearing, full canonical table** (schema + universal prior-art backed).
- **Sequencing:** confirmed **191 self-contained per Phase 183**, 192 stays terminal.
- All other round-1 assumptions confirmed.

## External Research

GOV.UK A–Z / tone-of-voice; Microsoft Style Guide (sign in/out); NN/g error guidelines + scoring
rubric; Shopify Polaris content (remove vs delete); IBM Carbon notification + empty-state; Vale
checks (rejected option). URLs captured in 191-CONTEXT.md canonical_refs.
