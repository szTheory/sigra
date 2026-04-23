# Phase 59: UAT + GA narrative alignment — Context

**Gathered:** 2026-04-23  
**Status:** Ready for planning

Research for this context used parallel maintainer-facing agents (library docs, GA matrices, milestone narrative, pointer IA). Decisions below are **one coherent package** for **OA-02** and roadmap success criteria (GA-03 / AUD-03 wording + pointers).

<domain>
## Phase boundary

Deliver **OA-02** (`.planning/REQUIREMENTS.md`): **`docs/uat-ci-coverage.md`** names **OA-01** test module(s) and states **machine** proof vs **human / live-provider** residual; **GA-03 / AUD-03** (and related maintainer surfaces) **do not over-claim** vs what **`Sigra.OAuthCeremonyAuditTest`** and **`Sigra.OAuthTest`** actually prove; add **pointer(s)** from **`.planning/v1.4-GA-UAT.md`** and/or **`.planning/uat-evidence/v1.4/INDEX.md`** when needed so humans reach the coverage doc without spelunking.

**Out of scope:** Changing OA-01 test code (phase **58**); live-provider CI; broad OAuth link/unlink matrices; rewriting archived milestone files beyond **additive** “as of v1.6” closure lines where a living doc must reference history.

</domain>

<decisions>
## Implementation decisions

### `docs/uat-ci-coverage.md` — OA-02 structure (hub for machine vs human)

- **D-59-01 (locked — hybrid table + subsection):** Keep the **SEED table** as the **single index**. Add a **grep-friendly subsection** immediately after the SEED block (or under a clear “OAuth / OA” heading), titled so it contains literals **`OA-01`**, **`OA-02`**, **`library_tests`**, and **`oauth_ceremony`**. In that subsection:
  - **Machine (merge-blocking):** Bullets naming **`Sigra.OAuthCeremonyAuditTest`** and path **`test/sigra/oauth/oauth_ceremony_audit_test.exs`** — state **exactly** what OA-01 proves today: **persisted** `audit_events` for **`oauth.register_via_oauth`** (registration ceremony) and **`oauth.authorize`** (successful **`Sigra.OAuth.authorize_url/3`**), **Postgres + Sandbox**, **in-process mock strategy**, **no live IdP HTTP**. Second bullet: **`Sigra.Planning.Phase58OauthOa01CiContractTest`** in **`test/sigra/planning/phase_58_oauth_oa01_ci_contract_test.exs`** — **structural** CI honesty (**`library_tests` → `Run library tests` → plain `mix test`**, D-58-11); clarify it does **not** replace integration assertions.
  - **Human / live-provider residual:** Explicit bullets: live Google (consent UX, refresh, tenant policy), anything not asserted by those modules — **must not** read as “OAuth fully E2E in CI.”
  - **Cross-link from SEED-4 / v1.4 GA-03 bullet:** One **short** line in the existing **SEED-4** row (and the **GA-03** line under “v1.4 GA”) pointing readers to the new subsection (“see § …”). **Keep** **`Sigra.OAuthTest`** + **`MockStrategy`** language for **contract / round-trip** coverage; **add** **`Sigra.OAuthCeremonyAuditTest`** so the index row is scannable without duplicating the full OA narrative (subsection owns depth — aligns with ExDoc / Oban pattern: **index + depth**, single authoritative expansion).

### `.planning/v1.4-GA-UAT.md` — GA-03 row + waiver coherence

- **D-59-02 (locked — layered machine substitute, scoped claims):** Update **GA-03** **CI_substitute** to a **layered** form (one line or two comma-separated clauses): (1) **`Sigra.OAuthTest`** — authorize/callback **contract**, in-process mock, **no HTTP to a real IdP**; (2) **`Sigra.OAuthCeremonyAuditTest`** — **OA-01**: **persisted audit rows** on **successful** registration + **authorize** paths. **Do not** imply a single shared `MockStrategy` module drives both files unless code is refactored — doc phrasing: “in-process mock strategy” / “Assent-shaped contract” is enough.
- **D-59-03 (locked — Notes / residual):** **Notes** keep **live Google waived**; add **one** precise machine clause mirroring OA-01 scope; **retain** residual (consent, refresh, provider-specific) — either in **Notes** or by pointer to **`GA-03/waiver.md`**. **Never** use phrasing like “OAuth fully verified in CI.”
- **D-59-04 (locked — waiver.md):** Update **`.planning/uat-evidence/v1.4/GA-03/waiver.md`** **compensating_controls** to cite **`oauth_ceremony_audit_test.exs`** / **`Sigra.OAuthCeremonyAuditTest`** in addition to **`Sigra.OAuthTest`**, framed as **contract + OA-01 audit persistence**, still **not** live Google. **SHA hygiene:** Prefer **one** pinned SHA location or soften to “modules listed in `docs/uat-ci-coverage.md` as of &lt;date&gt;” to avoid **triple drift** (matrix header + Notes + waiver) — executor picks least brittle option consistent with existing GA style.

### “AUD-03” / milestone narrative — honesty without ID collision

- **D-59-05 (locked — forward IDs):** For **all living maintainer docs** touched in this phase (at minimum **`.planning/PROJECT.md`**, and **`.planning/MILESTONES.md`** where it still forward-claims OAuth audit gap): **retire** ambiguous shorthand **“AUD-03 / OAuth ceremony not claimed”** as the **v1.6** story hook. Replace with **OA-01 / OA-02** vocabulary and explicit **v1.3** qualifier when referring to archived scope, e.g. **“v1.3 AUD-03 integration smoke — OAuth ceremony audit assertions explicitly deferred per archived `milestones/v1.3-REQUIREMENTS.md`.”**
- **D-59-06 (locked — ID disambiguation):** **Never** use bare **`AUD-03`** for OAuth narrative — **AUD-03** means **different things** in **v1.2 admin** vs **v1.3 integration smoke**. Use **`OA-01`** / **`v1.3 AUD-03 (OAuth deferred)`** as appropriate.
- **D-59-07 (locked — archived vs living):** **Do not** rewrite frozen **archived** milestone bodies to pretend v1.3 shipped OA-01. Where a **living** file embeds historical text, use **time-versioning** or a single **“As of v1.6 (OA-01): …”** addendum line that **closes** the debt by pointer to **`docs/uat-ci-coverage.md`** — same pattern as Rust RFC vs guide: **history stays true**, **current truth** is explicit.

### Pointer placement — hub-and-spoke IA

- **D-59-08 (locked — minimal high-signal set):**
  1. **`.planning/v1.4-GA-UAT.md`:** Add or extend a **tight pointer** (paragraph or “Phase 51-style” block) that satisfies roadmap criterion (3): names **OA-01** modules + paths and states **`docs/uat-ci-coverage.md`** is the **machine baseline** for expanded narrative — **mirror + pointer**, not a second SEED table.
  2. **`.planning/uat-evidence/v1.4/INDEX.md`:** Add **one bullet** (optional but **recommended** — cheap second entry path) linking **GA-03** row + **`docs/uat-ci-coverage.md`** OA subsection — **no** duplicated requirement tables.
  3. **`docs/ga-evidence.md`:** Add **one “Where to read next” bullet** with **absolute GitHub URLs** (tag or path consistent with existing `v0.2.0` style) to **`docs/uat-ci-coverage.md`** and the **matrix** — so **Hex-only** readers reach the same story (packaged docs do not ship `.planning/`).

### Canonical one-liner (reuse for coherence)

Use the **same** machine-proof sentence (or trivial variants) in matrix pointer, INDEX, and anywhere else a short repeat helps grep:

> **OA-01** is merge-blocked under **`library_tests`** by **`Sigra.OAuthCeremonyAuditTest`** (`test/sigra/oauth/oauth_ceremony_audit_test.exs`) asserting persisted **`oauth.register_via_oauth`** and **`oauth.authorize`** on success paths with in-process mock strategy (no live IdP); structural gate: **`Sigra.Planning.Phase58OauthOa01CiContractTest`** (`test/sigra/planning/phase_58_oauth_oa01_ci_contract_test.exs`). **Human / live-provider gaps:** **`docs/uat-ci-coverage.md`** + GA-03 waiver.

### Claude's Discretion

- Exact subsection title string and placement (after SEED table vs under “v1.4 GA”) as long as **OA-01** / **OA-02** tokens and paths are present.
- Whether **INDEX** bullet labels the pointer **“OA-01 pointer”** vs a **`GA-OA01-pointer/`** folder — **folder only** if another artifact is required for symmetry with GA-01; default is **INDEX line only** (least surface area).
- **SHA** handling in **waiver** vs matrix: pick **one** authoritative pin per **D-59-04** footgun mitigation.

### Folded Todos

_None._

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & roadmap

- `.planning/REQUIREMENTS.md` — **OA-02** (authoritative acceptance wording).
- `.planning/ROADMAP.md` — Phase **59** success criteria and canonical refs.

### Prior phase (machine proof)

- `.planning/phases/58-oauth-ceremony-audit-smoke/58-CONTEXT.md` — D-58-01–D-58-11, test layout, CI gate.
- `.planning/phases/58-oauth-ceremony-audit-smoke/58-VERIFICATION.md` — OA-01 row-level mapping.

### Docs & matrix (edit targets)

- `docs/uat-ci-coverage.md` — primary **OA-02** deliverable.
- `.planning/v1.4-GA-UAT.md` — GA-03 matrix row + pointer.
- `.planning/uat-evidence/v1.4/GA-03/waiver.md` — compensating controls refresh.
- `.planning/uat-evidence/v1.4/INDEX.md` — optional INDEX bullet.
- `docs/ga-evidence.md` — Hex-facing router links.

### Historical scope (wording only)

- `.planning/milestones/v1.3-REQUIREMENTS.md` — AUD-03 / OAuth deferral **fact** for accurate time-versioned sentences.
- `.planning/MILESTONES.md` — v1.3 “AUD-03 boundary” line if addendum applied.

### Implementation (fact check)

- `test/sigra/oauth/oauth_ceremony_audit_test.exs` — **`Sigra.OAuthCeremonyAuditTest`**
- `test/sigra/planning/phase_58_oauth_oa01_ci_contract_test.exs` — **`Sigra.Planning.Phase58OauthOa01CiContractTest`**
- `test/sigra/oauth/oauth_test.exs` — **`Sigra.OAuthTest`** (contract / MockStrategy patterns)
- `.github/workflows/ci.yml` — **`library_tests`** job

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable assets

- **Phase 58 tests** above — stable **module names and paths** for every doc pointer.
- **Existing doc structure** in `docs/uat-ci-coverage.md`: SEED table + “v1.4 GA” cross-links + “Where to run” + Policy — extend without inventing a competing table.

### Established patterns

- **`v1.4-GA-UAT.md` header** already states **`docs/uat-ci-coverage.md`** is the **machine baseline** — phase **59** reinforces that **D-38-08** pattern (matrix = human/waived index; coverage doc = CI map).
- **Tag snapshot links** in `docs/ga-evidence.md` — follow same style for new OA-01 pointers.

### Integration points

- **OA-02 checkbox** in `.planning/REQUIREMENTS.md` flips to complete when **`docs/uat-ci-coverage.md`** meets wording; **PROJECT.md** / **MILESTONES.md** align in the same milestone closure pass if in scope for the executor’s PR.

</code_context>

<specifics>
## Specific ideas

- **Subagent consensus:** **Hub-and-spoke** (coverage doc = depth, matrix = decision + short pointer, ExDoc = router); **Rails/NextAuth lesson** = honest residual risk + avoid duplicate authoritative CI lists; **Kubernetes / Rust lesson** = KEP/RFC-style **OA-01** as acceptance ID, tests as proof, docs as narrative + links.
- **DX:** **Grep-first** tokens (`OA-01`, `OA-02`, `library_tests`, file paths) over prose-only claims.

</specifics>

<deferred>
## Deferred ideas

- **Unify** duplicate `MockStrategy` modules across `oauth_test.exs` and `oauth_ceremony_audit_test.exs` — product/code refactor, not required for honest docs (**D-59-02** explicitly allows “separate test modules” wording).
- **Automated** doc generation from test tags — nice future; out of scope for **59**.

### Reviewed Todos (not folded)

_None._

</deferred>

---

*Phase: 59-uat-ga-narrative-alignment*  
*Context gathered: 2026-04-23*
