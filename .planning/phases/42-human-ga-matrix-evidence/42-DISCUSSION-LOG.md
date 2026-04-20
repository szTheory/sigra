# Phase 42: Human GA matrix & evidence — Discussion log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.  
> Decisions are captured in `42-CONTEXT.md`.

**Date:** 2026-04-20  
**Phase:** 42 — Human GA matrix & evidence  
**Mode:** `[--all]` Auto-selected all gray areas; user requested one-shot subagent research synthesis (non-interactive Q&A).  
**Areas discussed:** GA-05 artifact & evidence tree; GA-02/GA-03 execution vs waiver; GA-04 clean-machine protocol; `docs/uat-ci-coverage.md` edit policy

---

## Research inputs

Parallel `generalPurpose` subagents produced structured tradeoffs for each area (Elixir/Hex OSS norms, OWASP/NIST framing, Rails/Swoosh/Django/Stripe analogues, SSOT / CI drift footguns). Orchestrator synthesized into **D-42-01..D-42-05** in `42-CONTEXT.md`.

---

## Area 1 — GA-05 artifact & evidence tree

| Option | Description | Selected |
|--------|-------------|----------|
| Single monolith file only | Matrix + long inline dumps |  |
| **Matrix + `uat-evidence/v1.4/`** | Canonical `v1.4-GA-UAT.md` + per-GA evidence folders | ✓ |
| Many peer matrix files | GA-02.md … split |  |
| Evidence mostly external | CI URLs only | Partial — external links allowed as **supplements** only |

**User's choice:** Two-layer model (matrix + versioned evidence tree); optional INDEX under evidence if navigation needed; extend columns minimally (`CI_substitute`, `Surface`).  
**Notes:** Aligns with v1.3 `HUMAN-UAT` + `uat-evidence/v1.3.0/` precedent; avoids unmaintainable monolith.

---

## Area 2 — GA-02 / GA-03 human bar vs waivers

| Option | Description | Selected |
|--------|-------------|----------|
| Strict triple-client + live Google every PR | Maximum signal, unsustainable |  |
| **Automation-first + sampled human + strict waivers** | CI/HTML + contract tests default; human on triggers; waivers with compensation + expiry | ✓ |
| Waiver-heavy without expiry | Low cost, checkbox theater |  |

**User's choice:** Automation-first; human for MUA sample + live IdP on release/trigger paths; waivers must satisfy D-38-style fields + compensation artifacts.  
**Notes:** Separates protocol correctness (CI) from trust/IdP UX (human).

---

## Area 3 — GA-04 clean-machine protocol

| Option | Description | Selected |
|--------|-------------|----------|
| **Synchronous witness (default)** | 30 min, one lane, friction table | ✓ |
| Async self-serve | Meeting-free; higher cheating risk | Allowed only with transcript + first-failure-wins |

**User's choice:** Default synchronous witness + structured friction log; async mitigated per CONTEXT.  
**Notes:** Phoenix-guide-style command-first flow assumed as the doc under test.

---

## Area 4 — `docs/uat-ci-coverage.md` churn policy

| Option | Description | Selected |
|--------|-------------|----------|
| **Edit on CI boundary change + milestone drift audit** | Factual machine moves + close-the-tag rename pass | ✓ |
| Edit on every GA-05 cell edit | Over-churn, wrong SSOT |  |
| Calendar-only audit | Can lag | Secondary only |

**User's choice:** Primary trigger = machine substitute / policy change; secondary = milestone hygiene pass; GA-05 owns attestation.  
**Notes:** Keeps `ci.yml` as enforcement spine.

---

## Claude's discretion

- Reviewer cooling window numeric choice (30 vs 60 vs 90 days).
- Evidence subtree naming variants within `v1.4/`.
- Optional recording tooling for async GA-04.

## Deferred ideas

- Public deployment checklist page — noted in CONTEXT `<deferred>`.
