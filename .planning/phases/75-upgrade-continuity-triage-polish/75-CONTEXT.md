# Phase 75: Upgrade continuity + triage polish - Context

**Gathered:** 2026-04-23  
**Status:** Ready for planning

`[--all]` Auto-selected all gray areas: upgrade stub shape; intro/maintainer surfaces; triage/issue outcome; ExDoc/link hygiene.

User requested one-shot, research-backed recommendations (parallel subagent research on ecosystem patterns, then synthesis here — no per-area interactive Q&A).

<domain>
## Phase Boundary

**TRN-01:** Add **`guides/introduction/upgrading-to-v1.12.md`**, register it in **`mix.exs`** ExDoc **`extras`** immediately after **`upgrading-to-v1.11.md`**, align **`skip_undefined_reference_warnings_on`** only if needed.

**TRN-02:** **Getting-started** (or agreed intro surface) links **v1.12** upgrade + trust-bundle discovery; **`MAINTAINING.md`** and/or **`CHANGELOG.md`** mention the **v1.12** trust bundle (bounded audit work + UAT evidence index) for operators/integrators.

**TRN-03:** At least one **concrete** triage- or issue-linked outcome **or** explicit **“no triage deltas”** with date and pointer (per **REQUIREMENTS.md**).

**Explicitly in scope:** Documentation and planning artifacts consistent with **v1.12** milestone narrative; no **`lib/`** feature work unless a contradiction forces it.

</domain>

<decisions>
## Implementation Decisions

### TRN-01 — Upgrade guide shape (`upgrading-to-v1.12.md`)

- **D-75-01 (thin pointer + trust framing):** Match the **skeleton and tone** of **`guides/introduction/upgrading-to-v1.11.md`**: opening clarifies **planning milestone v1.12** vs **Hex SemVer**; point to **`CHANGELOG.md`** → *Planning milestones vs Hex releases*; one tight paragraph defining the **v1.12 trust bundle** (bounded **SEED-002** audit batch, **UAT evidence index**, **`docs/uat-ci-coverage.md`** alignment).

- **D-75-02 (single source of truth for eight rows):** State explicitly that the **eight-row SEED outcome table** lives **only** in **`.planning/v1.12-UAT-EVIDENCE.md`** — do **not** paste, paraphrase row-by-row, or maintain a second matrix in the upgrade guide.

- **D-75-03 (prerequisite chain):** “After **v1.11**” (or “if you have not read **v1.11** yet”) → link **`upgrading-to-v1.11.html`**, mirroring **v1.11** → **v1.10** chaining.

- **D-75-04 (integrator checklist):** Reuse the **three-step library checklist** pattern from **v1.11**: bump **`{:sigra, ...}`** from **`CHANGELOG.md`**, **`mix deps.get`**, **`mix compile` / `mix test`** (or CI equivalent); add **conditional** bullets **only** if **`CHANGELOG.md`** documents **breaking** or **host-app** steps for the release in question.

- **D-75-05 (See also):** Include **prior upgrade guide**, **`CHANGELOG.md`**, **UAT evidence** (link per **D-75-16**), **`docs/uat-ci-coverage.md`** (machine vs human catalog / **v1.12** subsection anchor), and **bounded-batch planning truth** pointer (**`09-03-SUMMARY.md`**) where it helps integrators without duplicating **09-03** body.

- **D-75-06 (reject heavier shapes):** Do **not** ship essay-length narrative (**full trust story** belongs in **`.planning/`** + **09-03**), checklist-heavy duplication of UAT rows, or a **CHANGELOG companion** that repeats release facts.

### TRN-02 — Where the trust bundle is discovered

- **D-75-07 (getting-started):** Extend the **Faster path** line to add **[Upgrading notes — v1.12](upgrading-to-v1.12.html)** next to existing upgrade links. Optionally add **one short clause** on the **Reading map** line (or immediately below) pointing integrators at **v1.12 trust bundle** discovery: **upgrade page** + **`docs/uat-ci-coverage.md`** (**v1.12 launch evidence** subsection) + evidence file (**URL per D-75-16**). Keep **first-hour** free of v1.12-specific prose unless a **single** generic “see Reading map / Getting started for GA·UAT posture” sentence is needed — default **skip**.

- **D-75-08 (MAINTAINING):** Add a **short** subsection or bullet block (title e.g. **v1.12 trust bundle (audit + UAT evidence)**): what shipped at a high level, **canonical URLs** ( **`docs/uat-ci-coverage.md`**, **`.planning/v1.12-UAT-EVIDENCE.md`** via **D-75-16** ), and **release ritual** (“when cutting a minor/major, confirm evidence + doc pointers stay aligned”). This is the **maintainer** front door; do not paste matrices.

- **D-75-09 (CHANGELOG):** Under **`[Unreleased]`** or the next release section, add **one bullet** for the **v1.12** trust bundle that links the **same** canonical surfaces (**upgrade guide**, **`docs/uat-ci-coverage.md`**, evidence **URL**) — **no** eight-row table in **CHANGELOG**.

- **D-75-10 (README):** **No** new README sentence for phase **75** — **README** already routes integrators to **Getting started** and maintainers to **MAINTAINING**; avoids **GitHub vs HexDocs** duplication drift.

- **D-75-11 (information architecture rule):** **One sentence + stable links** per surface; **`docs/uat-ci-coverage.md`** remains the **machine vs residual catalog**; **`.planning/v1.12-UAT-EVIDENCE.md`** remains the **milestone outcome index** (eight rows); **`upgrading-to-v1.12.md`** is the **version-specific orientation** — same separation as **Rails/Django** “release notes vs upgrade guide” maturity (avoid **Devise-wiki**-style contradictions).

### TRN-03 — Triage accountability

- **D-75-14 (append-only reconciliation):** Append **`## v1.12 reconciliation (Phase 75)`** (or equivalent) to **`.planning/v1.11-TRIAGE.md`** with **ISO date**, scope line (“reviewed **v1.11** triage follow-ups for **v1.12** closure”), and bullets that are either **(a)** a **concrete doc/outcome** delivered in this phase, **(b)** **“no triage deltas”** with **why** (e.g. gaps already closed in **71–72** / **73–74**), plus pointers (**PR**, **issue**, **phase verification**). This is the **primary** auditable artifact for **TRN-03** (Kubernetes/RFC-style **explicit state next to the debt list**).

- **D-75-15 (phase summary echo):** **`75-VERIFICATION.md`** / phase summary carries a **one-line** echo pointing at that triage subsection — **not** the sole record.

- **D-75-20 (GitHub issue path):** Use **issue-linked** resolution **only** if a real open item exists; do **not** create **issue theater**. Prefer explicit **no triage deltas** when work is genuinely empty.

### ExDoc, Hex package surface, and `.planning/` links

- **D-75-16 (hexdocs-safe links to planning):** In **`upgrading-to-v1.12.md`** (and any **same-phase** edits to other **extras** that link to **`.planning/`** artifacts not shipped in the Hex **`files`** list), use **absolute GitHub `blob`** URLs rooted at **`https://github.com/sztheory/sigra/blob/`** + **ref** + path. **Default ref for authoring:** `main` **until** a release tag exists; **at Hex publish time**, prefer the **tag** that matches the published version so links stay stable (principle of least surprise for **hexdocs.pm** readers — avoids **relative `.planning/`** links that 404 on HexDocs).

- **D-75-17 (`skip_undefined_reference_warnings_on`):** **Do not** add **`upgrading-to-v1.12.md`** to the skip list **solely** for `.planning` links if those links use **https** (ExDoc does not treat them as extra-relative paths — no spurious “file does not exist” for that class). **Do** add the new guide to the skip list **if** the guide retains **relative** `.md` links to non-extras (same pattern as **v1.10** / **v1.11**) **or** if **`mix docs --warnings-as-errors`** surfaces other intentional unresolved refs from that file. **Re-audit** after first **`mix docs`** run.

- **D-75-18 (footgun — coarse skip):** If the file **is** on the skip list, treat it as **technical debt**: the skip suppresses **all** undefined-ref warnings **from that file** — keep prose short and run **occasional** manual link review. **Deferred (not phase 75):** migrate **v1.10** / **v1.11** guides off relative `.planning/` links to **blob URLs** and **narrow** skips.

### Cross-cutting — research synthesis (cohesion)

- **D-75-19:** Decisions above align **CHANGELOG** (facts), **upgrade stub** (orientation + pointers), **`.planning/`** (evidence + triage reconciliation), and **`docs/uat-ci-coverage.md`** (machine catalog) — the same **separation of concerns** **74-CONTEXT** called for, extended to **hexdocs-working** links (**ExDoc `autolink` / extras resolution** lesson from codebase deps).

### Claude's Discretion

- Exact **subsection title strings** in **MAINTAINING** / **CHANGELOG** bullet wording; whether **`09-VERIFICATION.md`** receives an optional **one-line** pointer (only if it reduces confusion without duplicating **09-03**).

### Folded Todos

- None (**todo.match-phase** returned no matches).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements and roadmap

- `.planning/REQUIREMENTS.md` — **TRN-01**, **TRN-02**, **TRN-03**
- `.planning/ROADMAP.md` — Phase **75** goal and success criteria
- `.planning/PROJECT.md` — North star: production trust, integration path, honest machine vs human boundaries

### Prior phase context (continuity)

- `.planning/phases/74-planning-truth-launch-evidence/74-CONTEXT.md` — **UAT-01** / **UAT-02**; canonical paths; no duplication of eight rows into **`docs/uat-ci-coverage.md`**
- `.planning/phases/73-bounded-audit-atomicity-batch/73-CONTEXT.md` — **AUD-11** bounded batch narrative pointers

### Doc templates and targets

- `guides/introduction/upgrading-to-v1.11.md` — structural template for **v1.12** stub
- `guides/introduction/getting-started.md` — Faster path + Reading map
- `mix.exs` (`docs/0` / `package/0`) — **`extras`**, **`skip_undefined_reference_warnings_on`**, **`@source_url`**
- `CHANGELOG.md` — *Planning milestones vs Hex releases*; release bullet hook
- `MAINTAINING.md` — maintainer cadence + release hygiene
- `.planning/v1.11-TRIAGE.md` — **TRN-03** append-only reconciliation target
- `.planning/v1.12-UAT-EVIDENCE.md` — eight-row outcome index (canonical)
- `docs/uat-ci-coverage.md` — **v1.12 launch evidence** subsection + SEED catalog
- `.planning/phases/09-audit-logging/09-03-SUMMARY.md` — bounded batch / planning truth pointer

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable assets

- **`guides/introduction/upgrading-to-v1.11.md`** — copy structure, SemVer vs planning framing, checklist density, See also.
- **`mix.exs` `docs/0`** — pattern for **`extras`** ordering and **`skip_undefined_reference_warnings_on`** (v1.10 / v1.11 entries and comment on autolink-by-basename).
- **`CHANGELOG.md` [Unreleased]`** — milestone traceability bullet pattern (**v1.11** precedent).

### Established patterns

- **ExDoc** (see **`deps/ex_doc`**: `autolink.ex` / `ex_doc.ex`) — relative `*.md` links without host are resolved against **extras** by **basename**; **https** links bypass that path and suit **hexdocs** consumers reading **`.planning/`** artifacts.

### Integration points

- **`docs/uat-ci-coverage.md`** — already contains **v1.12 launch evidence** attestation from phase **74**; phase **75** links must stay **consistent** with that story.
- **Hex `package :files`** — **`.planning/`** not shipped; published guides must not rely on relative `.planning/` paths for **reader-facing** hexdocs.

### Creative constraint

- Phase **75** is **docs + planning edits** only unless verification discovers a hard contradiction.

</code_context>

<specifics>
## Specific Ideas

- Subagent research drew analogies: **Rails/Next/Django** upgrade docs → canonical **facts** in release notes + **thin** orientation guides; **Devise wiki** footgun → **avoid duplicate matrices**; **Kubernetes/RFC** closure → **explicit state** next to the original triage debt.
- User asked for **cohesive one-shot** recommendations moving toward **Sigra** vision — captured as locked decisions above.

</specifics>

<deferred>
## Deferred Ideas

- Migrate **`upgrading-to-v1.10.md`** / **`upgrading-to-v1.11.md`** from relative **`.planning/`** links to **tag-stable blob URLs** and **narrow** **`skip_undefined_reference_warnings_on`** — not required to close **TRN-01** for **v1.12** alone.

**None** — discussion stayed within phase scope for net-new capabilities.

</deferred>

---

*Phase: 75-upgrade-continuity-triage-polish*  
*Context gathered: 2026-04-23*
