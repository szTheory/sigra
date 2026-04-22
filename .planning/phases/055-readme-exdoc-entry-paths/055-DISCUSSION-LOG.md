# Phase 55: README & ExDoc entry paths — Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.  
> Decisions are captured in `055-CONTEXT.md` — this log preserves alternatives considered.

**Date:** 2026-04-22  
**Phase:** 55 — README & ExDoc entry paths  
**Areas discussed:** README GA block placement; Evidence URL strategy; ExDoc landing path; Executed vs Waived depth  
**Mode:** User requested **all** areas + parallel **research subagents** + one-shot cohesive recommendations (synthesized below).

---

## 1. README layout — GA block vs “Security posture (headlines)”

| Option | Description | Selected |
|--------|-------------|----------|
| A — New dedicated section after security headlines | Product defaults vs assurance pointers stay semantically separate; matches DOC-01; low complexity | ✓ |
| B — Merge into “Security posture” | One heading fewer; high risk of conflating runtime defaults with waivers | |
| C — Maintainer docs only | Fails DOC-01 discoverability for evaluators | |

**User's choice:** **A** (research + synthesis default).  
**Notes:** Aligns with Elixir ecosystem pattern (README = map + links; deep assurance in guides/docs). Cross-language: Rails security **guide** IA, not gem README paste; OWASP ASVS as external artifact, not README duplicate.

---

## 2. Evidence URLs — GitHub vs relative vs in-package hub

| Option | Description | Selected |
|--------|-------------|----------|
| Relative `.planning/` from README on HexDocs | Fails — not in tarball | |
| Tag-scoped GitHub for out-of-tarball evidence | Immutable reader view; matches `source_ref` | ✓ |
| Thin `docs/*.md` hub in package | Self-contained HexDocs; navigational duplicate avoided | ✓ |
| `main` URLs for GA evidence | Drift risk vs installed version | |

**User's choice:** **Tag-scoped GitHub + packaged `docs/ga-evidence.md` hub** + relative links among shipped extras.  
**Notes:** Coherent with **053** (no `.planning` in `package[:links]`) and **054** (link hygiene). Repo had **no `SECURITY.md`** at context time — **055-CONTEXT** D-14: add it in phase 55 if still absent.

---

## 3. ExDoc path — DOC-02 from default landing

| Option | Description | Selected |
|--------|-------------|----------|
| Keep `main: "getting-started"` + reading map + hub extra | Integrator-first; ≤2 hops; Phoenix/LiveView idioms | ✓ |
| `main: "readme"` | Surprising for library hexdocs; duplicates GitHub | |
| `main: "Sigra"` module | Reference-first; poor generator onboarding without huge moduledoc | |
| Overview guide + `main: "overview"` | Valid later; deferred | |

**User's choice:** **Keep `main`** + **`docs/ga-evidence.md`** + **top-of-getting-started reading map**.

---

## 4. Executed vs Waived — README depth

| Option | Description | Selected |
|--------|-------------|----------|
| Paragraph + 3–5 bullets + links | Honest, low duplication, low warranty tone | ✓ |
| Small navigational table | Acceptable variant; higher scan noise | |
| Link-only | Fails DOC-01 “short paragraph” spirit | |
| Full matrix in README | Warranty misread + drift — rejected | |

**User's choice:** **Paragraph + bullets**; matrix stays in `.planning/v1.4-GA-UAT.md` only.

---

## Claude's Discretion

- Exact filenames (`ga-evidence.md` vs synonym), exact README heading string, callout placement inside Getting Started — see **055-CONTEXT.md** D-17.

## Deferred Ideas

- `overview.md` + `main: "overview"` migration — see CONTEXT `<deferred>`.
