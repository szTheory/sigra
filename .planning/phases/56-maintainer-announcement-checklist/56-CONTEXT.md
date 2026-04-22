# Phase 56: Maintainer announcement checklist — Context

**Gathered:** 2026-04-22  
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver **MAINT-01** (`.planning/REQUIREMENTS.md`): add a concise **“First public launch / announcement”** checklist to **`MAINTAINING.md`** — ordered steps with **owners expressed as durable roles**, pointers to **install-golden** and **GA / audit evidence** where relevant, and **explicit optional** rows when v1.4 **human** matrix items remain waived. The artifact is the **checklist + cross-links**, not mandatory blog/HN/forum posts.

**Out of scope:** New auth features; re-running full human GA matrix; duplicating README / `docs/ga-evidence.md` narrative (phase **55** owns integrator-facing GA entry); rewriting Release Please or manual release mechanics beyond **cross-links**.

</domain>

<decisions>
## Implementation Decisions

### Section placement & narrative split (one mechanical spine + thin comms layer)

- **D-01 (canonical placement):** Add a new top-level section **`## First public launch (announcement checklist)`** **immediately after** **`## Release automation (default)`** and **immediately before** **`## Manual release checklist (emergency or pre-automation)`**. Ordering reads: **default ship path → first-time public comms → break-glass** — avoids a third competing “how to bump version” story.
- **D-02 (intro pointer — discoverability):** In the opening maintainer-facing paragraph(s) under `# Maintaining Sigra`, add **one short sentence**: on the **first public Hex release** (or first “loud” public push), see **First public launch** after **Release automation**. Optimizes stressed **Ctrl+F** / TOC scans without promoting announcement above installer golden or Actions runbook.
- **D-03 (no duplication of ship mechanics):** The announcement section **must not** re-list version bump, tag, `CHANGELOG`, `mix hex.publish`, or Postgres test bars — **link** to **Release automation**, **Manual release checklist**, and the existing **Installer golden CI contract** subsection. Announcement rows cover **attention, comms prep, evidence honesty, and support bandwidth** only.
- **D-04 (optional separate doc):** Do **not** split into a new `docs/maintainers/*.md` file in this phase — keep **one file** (`MAINTAINING.md`) for maintainer **Ctrl+F** unless a later phase explicitly promotes a split.

### HexDocs-safe & forum-copy evidence links (coherent with phase 55)

- **D-05 (two-layer link contract):** **`MAINTAINING.md` is an ExDoc extra** (`mix.exs` `extras`) — same constraint as phase **55**: paths **outside** `package[:files]` (notably **`.planning/`**) **do not exist on hexdocs.pm** as relative link targets.
- **D-06 (hard rule):** Use **tag-scoped GitHub URLs** (`…/blob/v<released-version>/…` matching the published Hex version / `source_ref`) for **`.planning/v1.4-GA-UAT.md`**, **`.planning/milestones/v1.4-REQUIREMENTS.md`**, and other planning-only evidence. Use **relative links only** to targets **known shipped** on HexDocs (`docs/**`, `guides/**`, other listed extras such as **`docs/uat-ci-coverage.md`**).
- **D-07 (never for evidence):** Do **not** use **`main`** blob URLs for GA / waiver / matrix “proof” — violates reproducibility under stress (matches mature OSS + internal **054** link hygiene intent).
- **D-08 (one policy line in checklist):** Include a single explicit sentence maintainers can paste when explaining links: *relative = in-docs navigation only; evidence outside the tarball = pinned tag URL.*

### Owner column semantics (stable process, rotating people)

- **D-09 (roles in the runbook):** Checklist steps use **durable role names** — e.g. **Release captain**, **Comms DRI**, **Security / evidence reviewer** (trim if team is tiny). **Do not** embed **`@github-handle`** strings in `MAINTAINING.md` checklist rows (staleness + wrong-ping risk under launch load).
- **D-10 (assignment at run time):** At the **top** of the new section, include a short **Assignment** block: the **Release captain** opens the **tracking issue** (or equivalent single roster surface) and fills a **Roster** table for **this run only**; step lines may say **“DRI: see roster”** instead of names. Executor picks the concrete template (issue label, `MAINTAINERS.md` table, or link to org process) — **one** roster location, not scattered handles.
- **D-11 (`CODEOWNERS`):** Do **not** conflate merge ownership with comms DRIs — no requirement to duplicate `CODEOWNERS` in prose; optional pointer only if it reduces confusion.

### Mandatory vs optional rows (ship truth vs announce attention)

- **D-12 (two-phase framing in-doc):** Structure the checklist with explicit **Ship (artifact truth)** vs **Announce (attention budget)** subsections (or clearly labeled row groups). **Ship** = reproducible without maintainer calendar; **Announce** = voluntary widening of concurrent skeptics.
- **D-13 (Ship group — link, don’t restate):** Rows must **point** to existing **Release automation** / **Manual release** paths, **installer golden** job + local `mix ci.install_golden`, branch-protection check name, and **tag-scoped** GA matrix / milestone evidence per **D-06**. Treat “public Hex with honest claims” as **blocked** until those links and bars are satisfied (wording left to executor — avoid warranty language per **055** tone).
- **D-14 (Announce group — default optional):** **Elixir Forum**, **Slack/Discord**, **blog**, **HN**, **short social** = **optional** rows. Each optional row gets **user-respectful** copy: e.g. skip if prefer smaller feedback batches; **CHANGELOG + upgrade path + `docs/ga-evidence`** acceptable substitute for long-form blog; **HN / forums only if half-day careful reply bandwidth** (or single sticky response plan).
- **D-15 (GA waiver honesty):** Where v1.4 **human** rows remain waived, optional rows must **not** imply those humans re-ran — point to **`v1.4-GA-UAT.md`** Executed/Waived + **CI substitute** docs (`docs/uat-ci-coverage.md`, install golden) per **D-06**.
- **D-16 (comms footguns — tone constraints):** Checklist includes **brief “do not”** bullets: security-theater phrasing, comparative trash-talk of other libs, implied warranty / “we certify your deployment,” heated real-time debate — align with Sigra’s **precision over slogan** posture (**053–055**).

### Coherence across v1.5 narrative work

- **D-17:** Cross-link **README** GA block and **`docs/ga-evidence.md`** (integrator path) once from the announcement section — **do not** duplicate matrix or milestone bodies.
- **D-18:** If a recommended **stability dogfood** window appears (e.g. quiet week before HN), phrase as **guidance**, not a new requirement ID — keeps MAINT-01 scope tight.

### Claude's Discretion

- **Exact checklist row text**, optional **tracking-issue template** location, and **minimal** table columns — constrained by **D-01–D-18**.
- **Whether** to add a tiny **“Launch day incident comms”** stub (acknowledge → link to artifact) — optional micro-section if it fits without scope creep.

### Folded Todos

_None._

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & roadmap

- `.planning/REQUIREMENTS.md` — **MAINT-01** (authoritative acceptance text).
- `.planning/ROADMAP.md` — Phase **56** row + success criteria + **Canonical refs** line.
- `.planning/PROJECT.md` — v1.5 public narrative vs shipped reality; announcement readiness framing.

### Evidence & CI (content targets — apply **56-CONTEXT** D-06 when emitting URLs from `MAINTAINING.md`)

- `.planning/v1.4-GA-UAT.md` — GA matrix, Executed vs Waived.
- `.planning/milestones/v1.4-REQUIREMENTS.md` — v1.4 requirement closure narrative.
- `.planning/MILESTONES.md` — Milestone index / archives.
- `docs/uat-ci-coverage.md` — CI substitution semantics (packaged — HexDocs-safe relative target).
- `.github/workflows/ci.yml` — `install_golden_contract` job id + human-readable `name:` for branch protection copy/paste.

### Prior phase coordination (link & narrative policy)

- `.planning/phases/055-readme-exdoc-entry-paths/055-CONTEXT.md` — **D-04–D-07** (Hex tarball boundary; tag-scoped GitHub for out-of-tarball evidence; README vs hub split).
- `.planning/phases/054-changelog-milestone-anchors/054-CONTEXT.md` — Changelog vs planning; tag-scoped evidence links.
- `.planning/phases/053-package-hex-metadata/053-CONTEXT.md` — Hex metadata tone; transparency locus.

### Implementation surface

- `MAINTAINING.md` — primary edit target.
- `mix.exs` — `docs/0` `extras` (confirms `MAINTAINING.md` ships on HexDocs).

### External patterns (illustrative — verify if cited in commits)

- https://github.com/elixir-lang/ex_doc/issues/889 — ExDoc / relative links to non-shipped paths (background for D-05).
- Kubernetes sig-release **role handbooks + per-release roster** pattern (conceptual model for D-09–D-10).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **`MAINTAINING.md`:** Already documents **`mix ci.install_golden`**, **`install_golden_contract`** path classes, Nyquist table with **`v1.4-GA-UAT.md`** pointers, Release Please flow, manual release numbered steps, semver pre-1.0 guidance — the announcement checklist **extends** this file rather than inventing parallel release docs.

### Established Patterns

- **Single maintainer runbook file** with heavy use of **anchors**, **code fences**, and **GitHub Settings** deep links — new content should match **tone, heading depth, and cross-link style**.

### Integration Points

- **`mix.exs` `docs/0`** — `MAINTAINING.md` is already an **extra**; any new relative links must resolve on **hexdocs.pm** or use **D-06** tag URLs.
- **README / `docs/ga-evidence.md`** (phase **55**) — integrator entry; announcement section should **point back** without duplicating GA prose.

</code_context>

<specifics>
## Specific Ideas

- Subagent research consensus: **K8s-style** split of **stable role definitions** vs **per-release roster** in a tracking issue; **Rust/CNCF** emphasis on **repeatable procedure** over frozen identities; **cross-ecosystem** lesson of **release mechanics vs launch comms** as separate checklists to prevent drift.
- User intent: **one-shot coherent recommendations** — captured as locked **D-01–D-18**; planner should implement **literally** unless verification finds a conflict with `MAINTAINING.md` structure.

</specifics>

<deferred>
## Deferred Ideas

_None — discussion stayed within phase scope._

</deferred>

---

*Phase: 56-maintainer-announcement-checklist*  
*Context gathered: 2026-04-22*
