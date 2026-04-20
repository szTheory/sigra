# Phase 40: Tooling & release ergonomics — Discussion log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.  
> Decisions are captured in `40-CONTEXT.md`.

**Date:** 2026-04-18  
**Phase:** 40 — Tooling & release ergonomics  
**Mode:** User selected **all** gray areas and requested **one-shot** research-backed recommendations via parallel subagents; facilitator synthesized into a single coherent strategy (no interactive per-area Q&A in chat).

**Areas covered:** (1) TOOL-01 fix vs deprecate, (2) REL-01 doc placement & depth, (3) REL-01 optional Hex publish workflow, (4) Semver for v1.3 / next Hex publish.

---

## 1) TOOL-01 — `gsd-tools audit-open --json`

| Option | Description | Selected |
|--------|-------------|----------|
| A | Upstream fix only (block on gsd-tools release) | |
| B | Deprecate in Sigra + documented checklist (+ optional tiny repo script) | ✓ |
| C | Fork / pin gsd-tools | |
| D | Waiver / “known broken” only | |

**User's choice:** **B** (synthesized from research + project gates): deprecate canonical reliance; repo-owned supported path; upstream fix encouraged but non-blocking.  
**Notes:** Elixir Hex libs rarely require Node CLIs for contribution; CONTRIBUTING must stay Elixir-first. Historical `.planning/` gets supersession pointers, not wholesale rewrites.

---

## 2) REL-01 — Maintainer checklist location & depth

| Option | Description | Selected |
|--------|-------------|----------|
| Root `MAINTAINING.md` + pointers | GitHub-first; CONTRIBUTING stays contributor-pure | ✓ |
| Everything in CONTRIBUTING | | |
| `docs/releasing.md` only | | |

**User's choice:** **Root `MAINTAINING.md`** with minimal ordered checklist + deep links; README + CONTRIBUTING one-liners.  
**Notes:** Matches `MILESTONES.md`; separates “prove correctness” vs “ship reproducibly” (Phoenix-style split).

---

## 3) REL-01 — Optional `HEX_API_KEY` workflow

| Option | Description | Selected |
|--------|-------------|----------|
| Dedicated `workflow_dispatch` workflow, secret isolated | Teaches REL-01 pattern; no auto-publish on merge | ✓ |
| No workflow; docs only | | |
| Tag-trigger auto-publish on every tag | | (rejected: higher surprise; optional dispatch preferred) |

**User's choice:** **Yes** to `.github/workflows/hex-publish.yml` (or equivalent), **`workflow_dispatch` only**, SHA-pinned actions, `mix test` before `mix hex.publish --yes`.  
**Notes:** OIDC for Hex not available as primary path; document API key scoped per Hex docs.

---

## 4) Versioning — next Hex publish

| Option | Description | Selected |
|--------|-------------|----------|
| Patch only (`0.1.1`) | | (only if no new public `lib/` since last publish) |
| Minor (`0.2.0`) when new supported `lib/` API ships | Matches `Sigra.Audit.Assertions` on main vs `0.1.0` Hex | ✓ |
| Jump to `1.0.0` | | (rejected for this milestone without explicit stability program) |

**User's choice:** **Rule-based:** patch for doc-only / no new `lib/` API; **minor `0.2.0`** for next publish including Phase 39 Assertions and v1.3 stack if last Hex was `0.1.0`.  
**Notes:** Coheres with semver trust before 1.0 and with `MAINTAINING.md` atomic version/changelog/tag sequence.

---

## Claude's discretion

- Script vs Mix task for optional audit helper naming and implementation detail.
- ExDoc `extras` timing for `MAINTAINING.md`.

## Deferred ideas

- Upstream gsd-tools JSON fix; Hex OIDC; optional dry-run job without secrets.
