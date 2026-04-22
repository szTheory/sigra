# Phase 52 — Technical research

**Question:** What do we need to know to plan **ROADMAP / Nyquist milestone presentation honesty** well?

## RESEARCH COMPLETE

### 1. The ROADMAP-44-45-vs-48-49 tension

- **Rows 44–45** (as of pre–phase-52) describe *implementation* goals (MFA/account API; OAuth/C-1) without completion checkmarks, while **47–49** are marked complete and explicitly publish **`*-VERIFICATION.md`** for phases **43–45** and close **AUD-04..AUD-08** in **REQUIREMENTS.md**.
- **Risk:** Readers infer phases **44–45** are unfinished work even though **48–49** already delivered the formal verification and REQ reconciliation narrative promised in those rows’ success criteria footnotes (“full Nyquist batch **41–44** stays **phase 50**”).
- **Resolution pattern:** Treat **44–45** as historical *batch labels* superseded for “done / verified” signals by **47–49**, while **50** remains the owner of **41–44** Nyquist posture (`nyquist_compliant: false` until elevated) per **MAINTAINING.md** §**Nyquist policy (phases 41-44)**.

### 2. Nyquist and VALIDATION.md honesty (41–44)

- **41–44 `*-VALIDATION.md`** already carry **Nyquist deferral** prose pointing at **MAINTAINING.md**, scoped **`*-VERIFICATION.md`**, and **`mix ci.install_golden` / `install_golden_contract`** (see e.g. **43-VALIDATION.md**, **44-VALIDATION.md** “Nyquist deferral” sections).
- **Phase 50** verification (**50-VERIFICATION.md**) is **status: complete** and defines CI-as-truth for the installer golden contract.
- **Phase 52** should avoid duplicating phase **50** content; it adds **reader-facing ROADMAP honesty** + **audit YAML disposition** so **v1.4-MILESTONE-AUDIT.md** `tech_debt` bullets do not contradict current repo state (verification files now exist for **43–45**).

### 3. Audit `tech_debt` block (stale items)

- **v1.4-MILESTONE-AUDIT.md** `tech_debt` still lists “Missing *-VERIFICATION.md” for **43–45** and Nyquist false for **41–44** as if nothing moved — partially stale after **47–49** and **50**.
- **Disposition:** Add an explicit **“superseded / dispositioned (phase 52)”** subsection or YAML sibling documenting which bullets are historical vs still open (e.g. **golden_diff** timeout class remains a *policy* note, not a missing-file note).

### 4. Automated guardrails

- **Existing:** `test/sigra/planning/phase_50_nyquist_docs_contract_test.exs` encodes **50-VALIDATION** map rows for **41–44** markers and **MAINTAINING** / CI wiring.
- **Gap:** No test asserts **ROADMAP** row **44–45** completion markers align with **48–49** supersession story.
- **Recommendation:** Add **`phase_52_milestone_honesty_contract_test.exs`** (or equivalent) with small, stable string/regex checks on **`.planning/ROADMAP.md`** plus file-existence checks for **43/44/45 `*-VERIFICATION.md`**.

### 5. Security / threat surface

- **Doc-only phase:** No new runtime auth paths. Residual risk is **misinformation** (readers ship or waive based on wrong “phase incomplete” signals) — address with accurate ROADMAP + audit text and a contract test.

---

## Validation Architecture

**Goal:** Encode phase **52** honesty checks as **fast, deterministic ExUnit** tests plus grep-friendly doc edits so `/gsd-validate-phase` style review can re-run without human re-diffing the whole milestone.

| Dimension | Strategy |
|-----------|----------|
| **Feedback sampling** | After each doc commit: `mix test test/sigra/planning/phase_52_milestone_honesty_contract_test.exs` |
| **Full planning gate** | `mix test test/sigra/planning/phase_50_nyquist_docs_contract_test.exs test/sigra/planning/phase_52_milestone_honesty_contract_test.exs` (ensures no regression to **50** contracts) |
| **Manual** | One maintainer read of ROADMAP supersession note for tone/clarity (not automated) |
| **Nyquist** | Phase **52** `VALIDATION.md` maps automated rows; **`nyquist_compliant` stays `false`** until team explicitly elevates (same posture as **50** for process-only doc waves) |

**Contract test responsibilities (52):**

1. **`.planning/ROADMAP.md`** — Phases **44** and **45** show the same completion convention as **48–49** (checkmark + date) **or** an explicit adjacent note references **48/49** verification supersession (test encodes one chosen pattern — see **52-VALIDATION.md**).
2. **File existence** — `43-VERIFICATION.md`, `44-VERIFICATION.md`, `45-VERIFICATION.md` under `.planning/phases/.../`.
3. **Audit disposition** — **v1.4-MILESTONE-AUDIT.md** contains a **phase 52** / **disposition** anchor string after edits (exact substring in **52-VALIDATION.md** table).

---

*Phase 52 — research for planning*
