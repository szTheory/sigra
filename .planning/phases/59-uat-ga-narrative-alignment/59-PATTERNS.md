# Phase 59 — Pattern map (documentation)

Analogs for executors — **read before editing**.

## Hub coverage doc

| Target | Analog | Pattern |
|--------|--------|---------|
| `docs/uat-ci-coverage.md` | Current file | **SEED table** is the single index; **v1.4 GA** subsection cross-links to **`.planning/v1.4-GA-UAT.md`** without duplicating the matrix (**lines 16–24** today). Extend with **one** new grep-dense subsection — do not add a second SEED table. |

## GA matrix row

| Target | Analog | Pattern |
|--------|--------|---------|
| `.planning/v1.4-GA-UAT.md` | GA-03 row (pipe table) | **Waived** row: `CI_substitute` column lists machine modules; **Notes** / pointer columns stay short; evidence folder link preserved. |

## Waiver

| Target | Analog | Pattern |
|--------|--------|---------|
| `.planning/uat-evidence/v1.4/GA-03/waiver.md` | Formal waiver table | **compensating_controls** row cites **`mix test`** path + SHA or softens per **D-59-04**; **residual risk** stays explicit. |

## Hex-facing router

| Target | Analog | Pattern |
|--------|--------|---------|
| `docs/ga-evidence.md` | “Where to read next” list | Uses **absolute GitHub URLs** with **tag** prefix (e.g. `v0.2.0`) like existing matrix link (**lines 11–12**). |

## Milestone narrative

| Target | Analog | Pattern |
|--------|--------|---------|
| `.planning/PROJECT.md` | “Current Milestone” bullets | Short goal statements; versioned “shipped” summaries — replace ambiguous **AUD-03** shorthand with **OA-01** / **v1.3** qualified phrasing (**59-CONTEXT D-59-05**). |

---

## PATTERN MAPPING COMPLETE
