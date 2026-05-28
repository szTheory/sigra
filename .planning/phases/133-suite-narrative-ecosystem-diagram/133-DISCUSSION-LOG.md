# Phase 133: Suite Narrative + Ecosystem Diagram - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in `133-CONTEXT.md` — this log preserves the analysis.

**Date:** 2026-05-27
**Phase:** 133-suite-narrative-ecosystem-diagram
**Mode:** assumptions (`minimal_decisive` calibration — user profile: opinionated)
**Areas analyzed:** Diagram format, Fan-out matrix shape, Cross-link strategy for not-yet-shipped recipes, ExDoc group placement, README pointer shape, Page length / sectioning, Diminishing Returns Wall framing, Standalone-banner placement, `mix.exs` surgical edit shape

## Assumptions Presented

### A. Diagram format

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| ASCII-only (no Mermaid), Unicode box glyphs (`┌─┐│└─┘`), fenced code block, ship tightened version of the ARCHITECTURE.md:204-222 prototype | Confident | REQUIREMENTS.md:40 says "ASCII"; ARCHITECTURE.md:202 already chose ASCII for ExDoc compat; README's Mermaid (lines 39-54, 63-69) renders as raw `graph TD` source in `mix docs --formatters markdown` + llms.txt; ASCII survives all renderers identically |

### B. Fan-out matrix shape

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Rows = curated 5-action audit subset + 1 host-emitted row; Columns = Sigra audit DB / `[:sigra,:audit,:log]` telemetry / webhooks / Threadline forwarder / Mailglass; cells ✓/—/`(host)`/`n/a` | Confident | `guides/flows/audit-logging.md:36-51` publishes the canonical action list; columns mirror REQUIREMENTS.md:40 sink enumeration; `(host)` cell for Mailglass × `auth.password_reset.success` captures the email-side-effect-vs-audit-event distinction |

### C. Cross-link strategy for the 4 not-yet-shipped recipes

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Ship live cross-links to all 6 recipes; add 4 basenames to `skip_undefined_reference_warnings_on:` for 133→134 window; Phase 134 executor removes them | Likely | ROADMAP.md:161 explicitly permits 133‖134 parallelism; `mix.exs:160-174` already carries Phase 131 + Phase 132 transitional entries (same precedent); rejected alternatives (planning-vocab placeholders / defer 133 / ship stub files) all have higher cost |

### D. ExDoc group placement

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| File at `guides/introduction/suite-integration.md`; slots into existing `Introduction` group via unchanged `mix.exs:223` regex; zero `groups_for_extras:` edits | Confident | REQUIREMENTS.md:40 fixes the path; `mix.exs:223` regex `~r{guides/introduction/.?}` already absorbs new files in the introduction tree; single-page "Suite Integration" group would read as broken nav |

### E. README pointer shape

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| ONE new row in existing `## Topic map → guides` table at `README.md:139-160`, inserted as row 2 (below `First happy path`); no new H2 section | Likely | README already 5 H2s deep at natural insertion point; new H2 would dilute existing TL;DR funnel; Topic map table is the README's existing "everything else" surface; position-2 signals "read early" |

### F. Page length / sectioning

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Target 180–260 lines; section order: H1 → validated-against metadata → top banner → "What this is" → ASCII diagram → role table → fan-out matrix → DRW → "Where to next" → end-echo banner | Likely | Phase 132 D-02 set recipe lengths at 80-220 lines; narrative needs to fit diagram + matrix + DRW + 6 cross-links in one read; role-table is load-bearing for "no orphans" success criterion (ROADMAP.md:109) |

### G. Diminishing Returns Wall framing

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Verbatim quote of `MILESTONE-ARC.md:215-220` as a 3-bullet blockquote, sandwiched by 2 prose sentences; NO link into `.planning/` | Confident | MILESTONE-ARC.md:215-220 is canonical and small (3 bullets, ~5 lines); paraphrasing risks drift; linking into `.planning/` from adopter docs exposes maintainer artifacts to Hex readers; Phase 132 followed identical no-`.planning/`-from-adopter-docs discipline |

### H. Standalone-banner placement

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Full banner at top (mirroring `threadline.md:7` / `mailglass.md:7` exactly per Phase 132 lock) + one-sentence echo at end; NOT two full banners | Likely | Phase 132 LOCKED top-of-page banner shape in both shipped recipes; without end-echo, 200 lines describing 6 integrations risks reading as "you need all six"; end-echo is the cognitive bookend that inoculates without adding redundant full banner |

### I. `mix.exs` surgical edit shape

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Three edits: (1) new `extras:` entry after line 198; (2) four new `skip_undefined_reference_warnings_on:` entries (per C); (3) zero `groups_for_extras:` changes. Final pre-commit gate: `mix docs --warnings-as-errors` | Confident | mix.exs:180-228 line-read confirmed: Phase 132 already established `extras:` ordering convention (introduction cluster lines 187-198); `skip_undefined_reference_warnings_on:` precedent at lines 165-174; `Introduction:` regex line 223 absorbs new file with zero pattern edits |

## Corrections Made

No corrections — all 9 assumptions confirmed by the user via the "Yes, proceed" pathway. The `minimal_decisive` calibration produced a coherent recommendation set that did not surface dispute-worthy options.

## Auto-Resolved

Not applicable — no `--auto` flag; no Unclear-confidence assumptions to auto-resolve.

## External Research

Not performed — Phase 133 is fully repo-internal (codebase + planning artifacts: ROADMAP, REQUIREMENTS, MILESTONE-ARC, STACK, ARCHITECTURE, Phase 131 + 132 CONTEXTs, the two shipped Phase 132 recipes, README, mix.exs current state, audit-logging flow doc). The analyzer's `needs_research` field returned empty, and no ExDoc/Earmark behavioral question surfaced that would require external research (the YAML-frontmatter gotcha was already characterized and locked in Phase 132 D-04; the `Introduction:` regex is line-readable in the current mix.exs).
