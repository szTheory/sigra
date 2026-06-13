# Phase 178: Brand v2 Pressure-Test Audit — Pattern Map

**Mapped:** 2026-06-12
**Files analyzed:** 2 new files
**Analogs found:** 2 / 2

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `brandbook/pressure-test-audit-v2.md` | audit document | transform (evidence → verdicts) | `brandbook/pressure-test-audit.md` | exact — same 14-section structure, same verdict framework |
| `brandbook/logo-v2-design-brief.md` | design brief | transform (constraints → spec) | `brandbook/logo-options/rail-accent/README.md` + `brandbook/logo-options/round-2/README.md` | role-match — brief format with criteria table + variation rows |

---

## Pattern Assignments

### `brandbook/pressure-test-audit-v2.md` (audit document, evidence → verdicts)

**Analog:** `brandbook/pressure-test-audit.md`

---

**Document header pattern** (lines 1–6):

```markdown
# Sigra Brand System Pressure-Test Audit

**Source material:** [evidence sources cited here]

**Audit stance:** [one paragraph — current state + what the audit treats as inherited system + what it identifies]
```

The header is plain — no badges, no frontmatter, no YAML block. Source and stance are bold-label paragraphs, not a table. This is the established document-open convention.

---

**Section heading scheme** (lines 7, 17, 33, 53, 84, 104, 123, 141, 158, 172, 207, 235, 257, 281):

```markdown
## Section 1 - Executive Judgment

## Section 2 - Brand DNA Extraction

## Section 3 - Pressure-Test Scorecard

## Section 4 - Stress Tests

## Section 5 - Gaps And Risks

## Section 6 - Recommended Brand Book Upgrades

## Section 7 - Design Token Specification

## Section 8 - Logo And Mark System

## Section 9 - Visual Examples And Screenshot Guidance

## Section 10 - Brand Voice And Microcopy

## Section 11 - Landing Page And Docs Blueprint

## Section 12 - Repo-Ready Artifact Plan

## Section 13 - Prioritized Action Plan

## Section 14 - Final Quality Gate
```

Rules extracted from the analog:
- Heading level is always `##` (H2) — no H3 subsections at the section level itself.
- Format is `## Section N - Title Case Heading` with a space-hyphen-space separator and Title Case for every word.
- Sections are numbered 1–14 with no zero-padding.
- Subsections within a section use `###` and are freeform (e.g., `### Critical`, `### Important`, `### Nice-To-Have` in Section 5).

---

**Brand DNA table pattern** (Section 2, lines 18–31):

```markdown
| Dimension | Decision |
| --- | --- |
| Brand essence | [one sentence] |
| Audience | [specific list, not generic] |
| Emotional tone | [three adjectives max] |
| Technical promise | [architecture-specific statement] |
| Visual metaphor | [grounded in actual product architecture] |
| Personality traits | [comma-separated adjectives] |
| Anti-traits | [comma-separated negatives — what the brand explicitly is not] |
| Design principles | [semicolon-separated principles] |
| Voice principles | [semicolon-separated rules] |
| This should feel like | [one concrete comparison] |
| This should never feel like | [one anti-example] |
```

The table is always two columns (`Dimension` / `Decision`). Column separator uses ` --- ` (space-dash-dash-dash-space) not `---` flush. Rows have no bold emphasis inside cells.

---

**Scorecard table pattern** (Section 3, lines 34–52):

```markdown
| Area | Score | Why | Risk | Recommended fix |
| --- | ---: | --- | --- | --- |
| [Area name] | [integer 1–10] | [one sentence grounding score in evidence] | [one sentence naming specific risk] | [one action sentence] |
```

Rules:
- Score column is right-aligned (`---:`).
- Score is a bare integer — no `/10`, no decimal.
- Why/Risk/Recommended fix are plain prose cells, not sub-bullets.
- 15 rows total (15 scored dimensions).
- Area names are noun phrases, not questions.

---

**Stress-test table pattern** (Section 4, lines 54–83):

```markdown
| Surface | Current guidance before this milestone | Needed addition |
| --- | --- | --- |
| [surface name] | [what existed before] | [what was/is missing and should be added] |
```

Rules:
- Three columns: Surface / Current guidance / Needed addition.
- The v2 audit changes this to a four-column table with a "Verdict" column per RESEARCH.md — see the REWORK note below.
- Surface names are concrete nouns (e.g., "GitHub repo header", "Admin topbar logo slot") not abstract categories.
- ~26–30 rows expected; v2 adds 4 new surfaces on top of v1's 26.

**v2 upgrade for Section 4 — add a Verdict column:**

Per RESEARCH.md (Architecture Patterns > Audit Structure Map), Section 4 in v2 must include verdict verdicts (KEEP/TIGHTEN/REWORK). The four-column pattern to use:

```markdown
| Surface | v1 Status | v2 Status / Evidence | Verdict |
| --- | --- | --- | --- |
| [surface name] | [what existed at v1] | [current state + evidence cite] | KEEP / TIGHTEN / REWORK |
```

---

**Gaps and risks subsection pattern** (Section 5, lines 84–101):

```markdown
### Critical

- [gap description — one sentence, naming the exact missing thing]
- [second critical gap]

### Important

- [important gap description]

### Nice-To-Have

- [low-priority gap]
```

Rules:
- Three subsection tiers only: Critical / Important / Nice-To-Have.
- Bullet list under each subsection.
- No numbered lists, no tables.
- Each bullet is a self-contained sentence naming the gap and its consequence.

---

**Recommended upgrades pattern** (Section 6, lines 104–122):

```markdown
Add, not redesign:

- [item]: [short expansion]

Remove or avoid:

- [item].
```

Rules:
- Two subsections: "Add, not redesign:" and "Remove or avoid:" — plain bold-colon header on its own line (not a `###`).
- Bullet lists under each.
- Add-items use `[topic]: [detail]` colon-separated format.
- Remove-items are short noun phrases.

---

**Verdict framework inline usage:**

The decision framework `KEEP / TIGHTEN / REWORK / ADD / REMOVE` is applied per-section. The v1 audit did not use these inline labels (it predates the framework). The v2 must embed them as follows:

```markdown
**Verdict: KEEP** — [one sentence evidence for why KEEP is warranted]

**Verdict: TIGHTEN** — [specific tightening action with file or surface reference]

**Verdict: REWORK** — [evidence for REWORK: specific surface, specific failure mode, specific evidence citation (file path / CSS line / token value)]
```

Every REWORK must name a specific surface, a failure mode, and an evidence citation. KEEP is the default — state "Verdict: KEEP" without qualification when nothing warrants change. Per CONTEXT.md: "Do not flatter the existing brand book unless it earns it. Prefer fewer, stronger recommendations."

---

**Final quality gate pattern** (Section 14, lines 281–290):

```markdown
- Could a [stakeholder] [do X]? Yes/No: [one sentence rationale].
- Could a [stakeholder] [do Y]? Yes/No: [one sentence rationale].
```

Rules:
- Seven to eight bullet points, each a "Could [X] [do Y]?" question with a plain Yes/No answer followed by a colon and one sentence.
- No tables in Section 14.
- The questions test designer, engineer, maintainer, contributor, and end-user readiness.

---

### `brandbook/logo-v2-design-brief.md` (design brief, constraints → spec)

**Primary analog:** `brandbook/logo-options/rail-accent/README.md`
**Secondary analog:** `brandbook/logo-options/round-2/README.md`
**Tertiary analog:** `brandbook/logo-options/README.md` (selection criteria pattern)

---

**Document header pattern** (rail-accent/README.md lines 1–3):

```markdown
# Sigra [Logo Name/System Name]

[One paragraph — what this folder/brief is for; what the active source set is]
```

---

**Criteria / constraint list pattern** (logo-options/README.md lines 9–15):

```markdown
## [Criteria Section Heading]

- Does it [criterion 1]?
- Does it [criterion 2 — name the specific anti-pattern to avoid]?
- Does it [criterion 3 — scale/size test]?
- Does it [criterion 4 — ecosystem surface test]?
- Does it [criterion 5 — design constraint test]?
```

For the design brief, the 7 hard constraints from CONTEXT.md are cast as this bullet-question format with an explicit "Required:" prefix to distinguish them from selection criteria:

```markdown
## Hard Constraints (Non-Negotiable)

1. **No rectangular background.** [One sentence from user brief]
2. **Logotype proximity.** [One sentence]
3. **Primary lockup has no subtitle/slogan.** [One sentence; note that with-subtitle variant is a separate deliverable]
4. **Integrated typemark variants required.** [One sentence definition]
5. **Not mark-beside-text.** [One sentence describing the anti-pattern]
6. **Font and color are tweakable.** [One sentence scope boundary]
7. **Options must be shown for human selection.** [One sentence — no implicit ratification]
```

---

**Variation/option table pattern** (round-2/README.md lines 8–16, rail-accent/README.md lines 16–23):

```markdown
| Option | File | [Purpose Column] |
| --- | --- | --- |
| [ID + Name] | [`filename.svg`](filename.svg) | [What it tests / its purpose] |
```

Rules:
- Three columns: Option / File / Purpose or "What it tests."
- Option column uses a short ID prefix (e.g., "2A", "RA-01") then a name.
- File column wraps the filename in a Markdown link using relative path.
- The brief itself does not list files (Phase 179 produces those) but the table format applies when listing candidate directions or required deliverables.

---

**Active source set block pattern** (logo-options/README.md lines 28–34):

```markdown
## Active Source Set

- Primary light lockup: [`logo-primary.svg`](logo-primary.svg)
- Primary dark lockup: [`logo-primary-dark.svg`](logo-primary-dark.svg)
- Free-standing mark: [`logo-mark.svg`](logo-mark.svg)
- Favicon source: [`favicon.svg`](favicon.svg)
- Monochrome mark: [`logo-monochrome.svg`](logo-monochrome.svg)
```

The brief uses this pattern for its "Required Deliverables" section, listing the lockup variants Phase 179 must produce:

```markdown
## Required Lockup Deliverables (Phase 179)

- Primary lockup (light): `logo-primary-v2.svg`
- Primary lockup (dark): `logo-primary-dark-v2.svg`
- Free-standing mark: `logo-mark-v2.svg` (if mark is retained or redesigned)
- Favicon source: `favicon-v2.svg`
- Monochrome: `logo-monochrome-v2.svg`
- With-subtitle variant: `logo-with-subtitle-v2.svg`
- Integrated typemark (no separate mark): `logo-typemark-v2.svg` (new variant class)
```

---

## Shared Patterns

### Verdict inline citation (apply to every REWORK in both files)

**Source:** CONTEXT.md decision framework + RESEARCH.md Common Pitfalls section
**Apply to:** Every REWORK verdict in `pressure-test-audit-v2.md`

```markdown
**Verdict: REWORK** — Evidence: [specific surface name], failure mode: [what fails and why], citation: [`path/to/file.ext` line N or token value].
```

No REWORK without all three fields. KEEP is always valid as a verdict with no evidence requirement.

---

### Assumption inline marking

**Source:** RESEARCH.md Assumptions Log (uses `[ASSUMED:` and `[VERIFIED:` labels throughout)
**Apply to:** Any claim in `pressure-test-audit-v2.md` that has not been verified by direct codebase inspection

```markdown
[ASSUMED: claim text — requires render verification in Phase 179]
[VERIFIED: direct inspection of path/to/file.ext]
[CITED: source URL or document path]
```

These bracket labels appear inline in sentence text, not as footnotes.

---

### Evidence citation format

**Source:** RESEARCH.md Sources section + `pressure-test-audit.md` source material header
**Apply to:** All evidence claims in both output files

File citations: `path/to/file.ext` (backtick-wrapped relative path from repo root)
Line number citations: `path/to/file.ext` line N
Token value citations: `` `--token-name: #hexvalue` ``
URL citations: `[text](url)` Markdown link inline or bare URL in Sources section

---

### Table column separator style

**Source:** `brandbook/pressure-test-audit.md` (every table), `brandbook/brand-book.md`
**Apply to:** All tables in both output files

```markdown
| Col 1 | Col 2 | Col 3 |
| --- | --- | --- |
```

Use ` --- ` (space-dash-dash-dash-space) as the separator pattern, not `---` flush to pipes. Right-align numeric columns with `---:`. No other alignment variants used in the existing brandbook documents.

---

### Subsection heading style within sections

**Source:** `brandbook/pressure-test-audit.md` Section 5 (lines 85–101)
**Apply to:** Any multi-part section in `pressure-test-audit-v2.md`

```markdown
### Subsection Name

[content]
```

H3 (`###`) for subsections within an H2 section. Title Case. No bold-heading alternative at H3 level inside audit documents (bold-colon headers are used in Section 6 only, for "Add, not redesign:" and "Remove or avoid:").

---

## No Analog Found

Neither output file lacks a close analog. Both are directly modeled on existing committed brandbook documents.

| File | Notes |
|---|---|
| Suite architecture section (BRAND2-02) | New content within Section 8 or between Sections 12–13; closest analog is the competitor-table format from RESEARCH.md. Use the `| Suite | Shared | Unique | Model |` table format already established in the research document. No committed brandbook analog exists for this specific sub-section — use RESEARCH.md section "szTheory Suite Brand Architecture" as the content model. |

---

## Metadata

**Analog search scope:** `brandbook/`, `brandbook/logo-options/`, `.planning/phases/178-*/178-RESEARCH.md`
**Files scanned:** 7 analog files read in full
**Pattern extraction date:** 2026-06-12
