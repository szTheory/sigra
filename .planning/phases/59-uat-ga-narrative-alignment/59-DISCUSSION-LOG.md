# Phase 59: UAT + GA narrative alignment — Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.  
> Decisions are captured in **59-CONTEXT.md** — this log preserves the alternatives considered.

**Date:** 2026-04-23  
**Phase:** 59 — UAT + GA narrative alignment  
**Areas discussed:** (1) `docs/uat-ci-coverage.md` OA-02 structure, (2) GA-03 matrix + waiver, (3) AUD-03 / milestone wording, (4) pointer placement (matrix / INDEX / ExDoc)

**Method:** User requested **all** areas with **parallel subagent research** (pros/cons, ecosystem patterns, cross-language lessons); parent synthesized into **59-CONTEXT.md**.

---

## 1. `docs/uat-ci-coverage.md` structure (OA-02)

| Option | Description | Selected |
|--------|-------------|----------|
| A | Extend SEED-4 row only | Partial — thin cross-link only |
| B | Dedicated OA-01/OA-02 subsection + machine vs human blocks | ✓ (primary) |
| C | New table row for OA-01 | Deferred — optional; subsection + pointer preferred to avoid duplicate OAuth narratives |
| D | Callout-only | ✗ — weak grep, easy to orphan |

**User's choice:** **B + thin A** — table stays index; subsection owns depth; SEED-4 / GA-03 lines get one pointer + module names.

**Notes:** Aligns with ExDoc/Oban-style “index + detail”; avoids three sources of truth for CI job lists.

---

## 2. GA-03 matrix + `waiver.md`

| Option | Description | Selected |
|--------|-------------|----------|
| A | Minimal append to CI_substitute | Partial |
| B | Layered CI_substitute (OAuthTest + OAuthCeremonyAuditTest) + scoped Notes | ✓ |
| C | Full Notes rewrite + SHA consolidation | Partial — executor discretion on SHA placement |

**User's choice:** **B** with **D-59-04** SHA hygiene; **update waiver** compensating controls to include ceremony audit module.

**Notes:** Scoped language avoids “OAuth fully in CI”; separate mock modules acknowledged in wording.

---

## 3. AUD-03 / living vs archived narrative

| Option | Description | Selected |
|--------|-------------|----------|
| Time-version | “v1.3 … deferred; v1.6 OA-01 …” | ✓ for historical surfaces |
| Global rewrite | Replace all “not claimed” | ✓ for **living** docs only |
| Addendum only | Two sentences adjacent | Partial — blend with time-version |

**User's choice:** **OA-01 / OA-02** as forward IDs; **no bare AUD-03** for OAuth; **v1.3 AUD-03 (OAuth deferred)** when citing archive.

---

## 4. Pointer placement (IA)

| Option | Description | Selected |
|--------|-------------|----------|
| Matrix only | `v1.4-GA-UAT.md` | ✓ (required minimum) |
| INDEX only | `uat-evidence/.../INDEX.md` | Optional |
| Both | Matrix + INDEX | ✓ **recommended** |
| ExDoc router | `docs/ga-evidence.md` GitHub URLs | ✓ |

**User's choice:** **Matrix + INDEX (recommended) + ga-evidence.md**; hub-and-spoke; canonical one-liner reused.

---

## Claude's Discretion

- Subsection title, INDEX folder vs bullet, single SHA authority — per **59-CONTEXT.md** Claude's Discretion.

## Deferred ideas

- Unify MockStrategy across test files; auto-generate coverage doc from tests.
