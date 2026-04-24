# Phase 74 — Planning truth + launch evidence — Research

**Question:** What do we need to know to plan **AUD-12**, **UAT-01**, and **UAT-02** well?

## Sources of truth (no fork)

| Concern | Canonical artifact | Role |
|--------|-------------------|------|
| C-1 mechanism / tier / verdict | `.planning/phases/09-audit-logging/09-VERIFICATION.md` | Normative matrix rows |
| SEED ↔ CI / residual catalog | `docs/uat-ci-coverage.md` | Machine vs human map; Policy paragraph |
| Milestone UAT outcomes (v1.12) | `.planning/v1.12-UAT-EVIDENCE.md` (create) | Eight-row **outcome index** only — not a second matrix |
| Bounded batch narrative | `.planning/phases/09-audit-logging/09-03-SUMMARY.md` | Executive orientation + **Recent bounded batches** |

Narrative files **point**; they do not duplicate verdict columns (**D-74-09**).

## Phase 73 batch (AUD-12 narrative input)

- **Plans:** `73-01-PLAN` (C-1 + inventory), `73-02-PLAN` (Postgres CHECK fault-injection tests).
- **Artifacts touched in 73:** `09-VERIFICATION.md` (rows **AUD-04-023..032** + **033–034** wording), `44-AUD-04-INVENTORY.md`, `test/sigra/mfa_audit_atomicity_test.exs`.
- **Summary commits (from phase summaries):** `aed7a9a` (09-VERIFICATION / inventory), `b5500a7` (atomicity tests) — verify with `git log` at execution time if SHAs advanced.
- **09-03 gap today:** Document status still says **v1.9** / trace ends at **67**; **Recent bounded batches** ends at **66** with no **73** paragraph — **AUD-12** is explicitly to extend **09-03** for the **023..032** band and refresh trace / “Last materially updated for” to **v1.12** / **73–74**.

## D-06 vs mandatory `09-VERIFICATION` edit

- **Phase 73** already performed a **material** C-1 update for **023..032** — not a silent “no edit” batch.
- **Phase 74** planning work may still conclude **no further** `09-VERIFICATION.md` body change is required **if** reconciliation on merge day shows matrix already matches `lib/` + tests (expected). In that case the **primary** D-06-class attestation is still written in **`09-03-SUMMARY.md`** (ids reconciled, why no **additional** row churn, links to **73** artifacts).
- **Optional** one-line pointer from `09-VERIFICATION.md` preamble into `09-03` is **merge-noise tradeoff** — defer to executor only if it reduces ambiguity; **not** required for plan acceptance if **09-03** paragraph is complete (**74-CONTEXT**).

## UAT-01 — `v1.12-UAT-EVIDENCE.md` shape

- **Precedent:** `.planning/v1.4-GA-UAT.md` — preamble + table with status/date/owner/evidence/CI substitute columns; tone **execute-by-default** (**D-38-01**).
- **v1.12 constraint:** **Exactly eight data rows** in **SEED 1..8** order matching the main table in `docs/uat-ci-coverage.md` (lines 7–14) for mental 1:1 mapping.
- **Columns (locked in 74-CONTEXT):** SEED · Machine substitute pointer · Residual human note · Outcome · Owner · Date · Deferred trigger (and waiver expiry when used).
- **Outcomes:** Prefer **Executed** or **Waived with substitute** where Policy marks machine-closed rows; **Deferred** only with owner + date + re-open trigger.
- **Anti-pattern:** Pasting the full SEED×CI table again — use `→ docs/uat-ci-coverage.md` anchors and short test/job paths only.

## UAT-02 — `docs/uat-ci-coverage.md`

- Add stable section **`## v1.12 launch evidence (attestation)`** (or equivalent — **74-CONTEXT** allows minor title variation; plan fixes string for grep).
- **3–6 sentences + bullets:** link **`.planning/v1.12-UAT-EVIDENCE.md`**, restate division of labor (this doc = catalog; planning file = v1.12 outcome index).
- **Do not** duplicate eight outcome rows in ExDoc — avoids fork with `.planning/`.
- **v1.4 GA** subsection: extend only to remove ambiguity with v1.12; no contradictory Policy claims.

## Risk notes

- **Contradiction:** If v1.12 evidence outcomes disagree with **Policy** in `docs/uat-ci-coverage.md`, fix **evidence file first** (**D-74-07**).
- **Scope creep:** `upgrading-to-v1.12.md`, **MAINTAINING** trust-bundle refresh — **phase 75** unless one trivial sentence is folded in.

## Validation Architecture

| Dimension | Strategy |
|-----------|----------|
| **1 — Correctness** | Markdown + relative links resolve; eight SEED rows present in order **1..8** in `v1.12-UAT-EVIDENCE.md`; `09-03-SUMMARY.md` mentions **phase 73** and **AUD-04-023..032** (or equivalent id band). |
| **2 — Regression** | `MIX_ENV=test mix compile --warnings-as-errors` (no code change expected; confirms repo still builds). |
| **3 — Security / audit** | No false **T1** claims in new text; C-1 edits in **74** only if reconciliation proves a cell mismatch (unlikely) — otherwise D-06 narrative only. |
| **4 — Performance** | N/A (docs). |
| **5 — DX** | One evidence file path stable for **phase 75** `upgrading-to-v1.12.md` link (**TRN-01**). |
| **6 — Compatibility** | Path **`.planning/v1.12-UAT-EVIDENCE.md`** canonical — do not rename (**D-74-03**). |
| **7 — Observability** | N/A. |
| **8 — Nyquist / feedback** | Per **74-VALIDATION.md** — grep/link checks per task; wave close re-runs compile + headline greps. |

---

## RESEARCH COMPLETE

Findings support **74-01-PLAN** (**AUD-12** / **09-03**) and **74-02-PLAN** (**UAT-01** + **UAT-02** / evidence file + `docs/uat-ci-coverage.md`).
