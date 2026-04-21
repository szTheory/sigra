# Phase 50 — Technical Research

**Question:** What do we need to know to **plan** Nyquist closure and CI gate hygiene for phases **41–44** plus long-budget installer work?

**Sources read:** `50-CONTEXT.md`, `.planning/v1.4-MILESTONE-AUDIT.md`, `.planning/ROADMAP.md`, `mix.exs`, `.github/workflows/ci.yml`, `test/test_helper.exs`, `test/sigra/install/golden_diff_test.exs`, `41-VALIDATION.md`, path inventory under `test/fixtures/install_golden/`.

---

## Findings

### 1. Nyquist posture today (41–44)

- **`v1.4-MILESTONE-AUDIT.md`** lists **`nyquist_compliant: false`** for phases **41–44** (partial); **45** is the only compliant entry in that table snapshot.
- Phases **47–49** already established the **split model**: scoped **`*-VERIFICATION.md`** + honest **`nyquist_compliant: false`** on living **`*-VALIDATION.md`** where full batch **41–44** is explicitly deferred to **phase 50** — see **`43-VERIFICATION.md`**, **`44-VERIFICATION.md`**, **`45-VERIFICATION.md`** and matching VALIDATION deferral paragraphs.
- **Phase 50** must **either** complete honest **`nyquist_compliant: true`** where per-row commands are CI-stable **or** add **grep-able waiver rows** (owner, date, pointer, reopen trigger) per **D-50-01** — not blanket `true` while text still says “deferred to 50” for rows being closed.

### 2. Root `mix test` vs nested fixtures

- **`mix.exs`** uses **`test_load_filters`** / **`test_ignore_filters`** so root **`mix test`** does **not** load **`test/example/**`** or **`test/fixtures/install_golden/**`** — intentional; nested contracts need **explicit** aliases or CI jobs (**D-50-02**).
- **`test/test_helper.exs`** calls **`ExUnit.start()`** with **no default tag excludes** — aligns with **D-50-02** (“no silent skipped blind spot” vs primary CI step). The **`mix.exs`** comment mentioning **`:postgres` exclude** is **stale** relative to current **`test_helper`** (worth a micro-doc fix if touched).
- **`mix ci.audit_45`** exists as a **flat** string-key alias: **`"ci.audit_45": ["test", "path1", ...]`** — precedent for **`mix ci.install_golden`**.

### 3. `golden_diff_test.exs` (long budget)

- Module tags: **`:golden`**, **`:integration`**, **`timeout: 300_000`** (5 minutes). Runs **`InstallFixture`** → **`mix phx.new`** + **`mix sigra.install`** in temp dirs; **CI already installs `phx_new`** in **`library_tests`** before **`mix test`**.
- Risk class from audit: **timeout / flake under broad suite re-runs** — mitigations are **timeouts**, **deterministic env**, **CI layering** (scheduled / path-filtered **additional** jobs), **docs** — **not** default **`ExUnit.configure(exclude: …)`** without explicit project decision (**D-50-02**).

### 4. `test/fixtures/install_golden/` shape (critical for D-50-03)

- Fixture is **`STDOUT.txt` + `tree/`** where **`tree/`** holds **`config/`**, **`lib/`**, **`priv/`**, **`test/`** — **no `mix.exs` at fixture root**.
- **`golden_diff_test.exs`** compares **normalized generated output** to the committed tree; it does **not** run **`mix test` inside `tree/`**.
- **Implication:** A literal **`cd test/fixtures/install_golden/tree && mix test`** contract **cannot** ship without **new** hosting scaffolding (add Mix project files — **large scope**). Pragmatic reading of **D-50-03**: the **named command** should be the **single cited merge-gate** for “installer golden stays green” — implement as **`mix ci.install_golden`** mapping to **documented Postgres env + scoped `mix test`** paths that **exercise golden/install** (e.g. **`test/sigra/install/golden_diff_test.exs`** plus any sibling install tests cited in **`mix.exs`**), **or** a **`bash scripts/ci/install-golden-contract.sh`** wrapper if the command sequence is multi-step. **Executor** must record the **exact** chosen mapping in **`50-VERIFICATION.md`** merge gate lines.

### 5. CI jobs already related

- **`library_tests`**: Postgres service, **`mix archive.install phx_new`**, **`mix test`**, **`mix docs --warnings-as-errors`**.
- **`installer_milestone_audit`**: path filter on **`priv/templates/sigra.install/`** + **`lib/sigra/install/`**; always on non-PR; PRs conditional.
- **`install_smoke`**: full fresh **`phx.new` + sigra.install`** script — good **drift** signal; separate from golden byte-diff.

### 6. Index docs

- **`MAINTAINING.md`** and **`docs/uat-ci-coverage.md`** should carry **links** to phase **50** artifacts and policy table — avoid triplicating full command strings (**D-50-04**).

---

## Recommendations (for planner)

1. **Wave A — Nyquist / VALIDATION honesty:** For **41–44**, edit **`NN-VALIDATION.md`** per **D-50-01**: align **`nyquist_compliant`**, per-row statuses, and deferral/waiver text with **`47–49`** precedent; add **one policy table** ( **`MAINTAINING.md`** subsection preferred).
2. **Wave B — Named CI contract:** Add **`mix ci.install_golden`** + **CI job** (path filter family aligned with **`installer_milestone_audit`**, **always on `main`**, optional **`schedule`**) — command body must match **§4** reality (compound `mix test` / script, **not** fictional **`cd tree`** unless plan explicitly adds Mix host).
3. **Wave C — Receipts:** Create **`.planning/phases/50-nyquist-ci-gate-hygiene/50-VERIFICATION.md`** with merge gate lines, SHA, PASS/FAIL, links to updated **41–44** VALIDATION files; micro-edit **ROADMAP** / **REQUIREMENTS** only if success criteria demand explicit bookkeeping.

---

## Validation Architecture

> Nyquist **Dimension 8** — how automated verification binds to phase **50** tasks.

| Dimension | Approach |
|-----------|----------|
| **1. Requirement trace** | ROADMAP phase **50** success criteria + **`50-CONTEXT.md` D-50-01..04** — no discrete REQ-IDs in init JSON (`phase_req_ids: null`). |
| **2. Command literals** | Every plan task that claims CI behavior must cite **verbatim** `mix …` or **`bash scripts/…`** strings also repeated in **`50-VERIFICATION.md` → Merge gate**. |
| **3. Postgres coupling** | Library-scoped tests use **`PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost`** — match **`library_tests`** env block. |
| **4. Honest Nyquist flags** | Do not set **`nyquist_compliant: true`** on **41–44** `*-VALIDATION.md` until waiver text / per-row receipts match the hybrid policy; **`50-VALIDATION.md`** may stay **`false`** until **`50-VERIFICATION.md`** is green. |
| **5. Flake class** | **`golden_diff_test.exs`** — verification records **timeout tags** and whether a **scheduled** job was added; acceptance uses **grep** for **`timeout:`** or doc section header. |
| **6. Grep-able waivers** | Rows deferring work reference **`NN-VERIFICATION.md`**, CI job name, date, owner — pattern from **phase 36** / **47–49**. |

**Sampling strategy:** After each wave merge: run the **narrowest** command from the plan’s `<verify>` block; before phase close: run **`50-VERIFICATION.md`** merge gate bundle once on a clean tree.

---

## RESEARCH COMPLETE

Phase **50** planning can proceed with **D-50-01..04** as locked decisions; **§4** narrows how **`mix ci.install_golden`** must be specified so plans stay executable.
