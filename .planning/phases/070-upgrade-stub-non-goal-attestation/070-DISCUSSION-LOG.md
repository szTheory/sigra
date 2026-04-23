# Phase 70: Upgrade stub + non-goal attestation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.  
> Decisions are captured in **`070-CONTEXT.md`**.

**Date:** 2026-04-23  
**Phase:** 70 — Upgrade stub + non-goal attestation  
**Areas discussed:** (1) Upgrade doc narrative spine, (2) SemVer / pins, (3) Non-goal attestation surfaces, (4) ExDoc extras + See also mesh  
**Mode:** User selected **all** areas and requested **parallel subagent research** + **one-shot synthesis** (no per-question TUI).

---

## 1. Upgrade doc narrative spine

| Option | Description | Selected |
|--------|-------------|----------|
| A — Mirror v1.8 | Same headings / checklist / See also pattern; thinner body for docs milestone | ✓ |
| B — Minimal stub | Lowest maintenance; weak discoverability and lib+generator footguns |  |
| C — Heavy v1.9 inline | Duplicates CHANGELOG / `.planning/`; rots; security for scanning |  |

**User's choice:** **A hybrid:** mirror **v1.8** skeleton + **B's restraint** on length + **C as links only** (one archive pointer, no phase matrix paste).  
**Notes:** Subagent cited Hex ecosystem norm: **CHANGELOG = facts**, upgrade = **sequence**; Rails-like checklists beat npm semver-only for **generator** stacks.

---

## 2. SemVer vs planning milestone explanation

| Option | Description | Selected |
|--------|-------------|----------|
| Link-only | Single sentence + CHANGELOG anchor |  |
| Medium restate | Short paragraph (four facts) + mandatory CHANGELOG deep link | ✓ |
| Full essay inline | Duplicates CHANGELOG philosophy |  |

**User's choice:** **Medium restate** — matches existing **`upgrading-to-v1.8.md`** opening; minimizes drift while reducing skimmer ambiguity.  
**Notes:** Explicit **`mix deps.update` ≠ planning milestone** anti-footgun; **`~> 0.2` vs git** clause defers to CHANGELOG.

---

## 3. Non-goal attestation placement

| Option | Description | Selected |
|--------|-------------|----------|
| A — PROJECT + REQUIREMENTS only | Governance-complete; weak for ExDoc-only readers | Partial (authoritative) |
| B — + upgrade doc box | Meets upgraders; transparent scope boundary | ✓ |
| C — + long CHANGELOG tables | Drift / noise |  |

**User's choice:** **B + authoritative A:** tables stay in **PROJECT / REQUIREMENTS**; **upgrade page** short **“Out of scope for v1.10”** with **ADR 001** + **SEED-002** links + “tables win” guardrail; **optional** single **CHANGELOG** milestone pointer at release (pointer only).  
**Notes:** Tone = **deliberate product decision**, not apology (Kubernetes / mature OSS pattern).

---

## 4. ExDoc extras + See also

| Decision | Selected |
|----------|----------|
| `extras` insert point | Immediately **after** `upgrading-to-v1.8.md`, **before** `upgrading-to-v1.1.md` |
| See also (≤5) | **CHANGELOG**, **upgrading-to-v1.8**, **intermediate-production-path**, **deployment**, **generator-options** |
| Avoid | Multi-archive lists, upgrade-page rings, default **first-hour**, deep GA/Nyquist hubs unless on-topic |

**User's choice:** As table — Diátaxis handoff from **how-to (upgrade)** to **reference (changelog, generator-options)** + **how-to (deployment, production path)**.

---

## Claude's discretion

_None — user requested explicit research-backed recommendations; all four areas locked in **070-CONTEXT.md**._

## Deferred ideas

- Dedicated **`upgrading-to-v1.9.md`** ExDoc page — deferred unless maintainers split v1.9 narrative later; would reorder `extras` between v1.8 and v1.10.
