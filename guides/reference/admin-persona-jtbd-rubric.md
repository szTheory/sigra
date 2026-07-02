# Admin Persona-JTBD Rubric

This file is the adversarial persona/JTBD judge instrument for Sigra admin surfaces. It
formalizes the 3 admin-operator lenses (platform admin / support investigator / org admin)
already implicit in the fractal scorecard and quality ledger, making them explicit with
entry-point bindings, refutation-prompt verdict questions, and a fixed machine-rollup-able
output schema.

The rubric is **complementary to `admin-fractal-scorecard.md`**, not a competing tier system.
The scorecard grades visual and technical quality (dimensions D1–D11, per-level add-ons,
Tier 0/1/2). The rubric grades **UX fitness-for-purpose**: does each surface do the right job,
for the right operator, without noise, confusion, or redundancy? Both instruments must pass
for a surface to warrant Tier-2 ratification in Phase 211.

The rubric is **not** a new persona set and does not invent new tiers. It is a measuring
instrument: the same fixed questions, applied identically to every surface by every reviewer.

Cross-reference: `admin-fractal-scorecard.md` → _L4 Flow Add-ons_ and _Persona-JTBD Rubric
(Cross-Reference)_; `admin-quality-ledger.md` → _Persona-JTBD Rubric (Cross-Reference)_ and
_flow-*_ ledger rows.

---

## IMPORTANT DISAMBIGUATION

The 3 admin lenses below are **admin UI operator lenses** — they describe how a logged-in
operator uses the Sigra admin console. They are **not** the integrator personas (A–E) from
`prompts/Phoenix Auth Library — Jobs to Be Done, Personas & User Flows.md`.

| Lens | Bound to | Entry point | Posture | Integrator comparison |
|------|----------|-------------|---------|----------------------|
| Platform admin | `admin` persona | `/admin` | triage | unrelated to integrator personas A–E |
| Support investigator | `admin` acting on a target | `/admin/users/:id` | investigate | unrelated to integrator personas A–E |
| Org admin | `morgan` (`org_admin: :acme`) | `/admin/organizations/:slug` | bound | unrelated to integrator personas A–E |

Integrator personas (A–E) describe the library _adopter_ (the Elixir developer wiring Sigra
into their Phoenix application). Admin lenses describe the _operator_ (the SaaS team member
managing users through the deployed admin console). **Do not conflate them.**

---

## Lens Definitions

The 3 lenses are bound 1:1 by **entry point + intent**, not by login credentials. The
platform admin and support investigator share the same `admin` login; they differ in where
they start and what goal drives the session.

| Lens | Persona | Entry point | Posture | Primary intent | Ledger cell |
|------|---------|-------------|---------|----------------|-------------|
| Platform admin | `admin@demo.tasklane.test` | `/admin` | triage | "What needs attention now? Where do I go next?" — scans overview KPIs, drills into task cards, pivots to org scope | `flow-platform-admin` |
| Support investigator | `admin@demo.tasklane.test` acting on a target (`dave`, `frank`, `grace`, `carol`) | `/admin/users/:id` | investigate | "Find → audit → impersonate → return with banner" — full investigator JTBD flow with scope continuity | `flow-support-investigator` |
| Org admin | `morgan@demo.tasklane.test` (`org_admin: :acme`, non-platform) | `/admin/organizations/:slug` | bound | "Tenant-only; clean 403 on overreach" — org member posture, no global scope, expects a refusal at every out-of-bound path | `flow-org-admin` |

**Why entry-point binding matters:** The same user (admin) has two distinct lenses depending
on whether the session starts at `/admin` (triage) or arrives directly at a user detail page
(investigation). Scoring by intent prevents false-pass verdicts that arise from testing only
the happy triage path.

---

## Verdict Scale

The ordinal scale is `keep` / `tighten` / `kill` (3-point). Three points maximize inter-rater
agreement: a 4-or-5-point scale introduces a noisy middle; a binary scale loses gradation needed
for actionable output.

| Verdict | Anchor | Worked example |
|---------|--------|----------------|
| `keep` | Element earns its place for this lens; no change warranted | A confirmation count summary chip on the Overview is useful for the platform admin triage posture — keeps eyes on the KPI without hunting deeper |
| `tighten` | Element has a purpose but is verbose, poorly placed, or partially muddy; worth editing, not removing | A 5-column audit table on a mobile view that collapses only 2 columns — the job is right, but the responsive contract needs tightening |
| `kill` | Element does not earn its place for this lens, or actively harms the flow through confusion, redundancy, or hierarchy violation | A "Confirmed" status pill always-visible on every user row adds noise without scan value — the absence of "Unconfirmed" already signals confirmed; kill the positive-confirmation pill |

**Disposition rollup rule:** The element's final disposition equals the **worst verdict across
the 3 lenses**. A `kill` from any single lens is a kill for the element, regardless of `keep`
verdicts from the other two. A `tighten` and no `kill` → tighten. All three `keep` → keep.

**Application-level disposition:** After rolling up all elements for a surface:
- Any `kill` element → surface disposition `blocked`
- Any `tighten` element and no `kill` → surface disposition `actionable`
- All elements `keep` → surface disposition `clean`

---

## Three Verdict Questions

Each question is phrased as a **refutation prompt** — the reviewer is asked to find the
strongest case *against* the surface, not to confirm that it looks fine. Each question maps
1:1 to one of the milestone's named failure modes.

### Question 1: Earning its place?

**Target failure mode:** verbosity / info-dump — elements present that are not doing a job
for this lens.

**Refutation probe:** Name one element on this surface that is NOT earning its place for
this lens. If none, say so explicitly, including what you searched for.

**What counts as an answer:**
- A specific DOM element or section heading that could be removed without loss of function
  for this lens (e.g. a "Confirmed" pill on every row when the platform admin posture only
  needs to see the exception states)
- An empty placeholder widget that provides no value at current data volumes
- A label or metric that duplicates information shown two scroll-lengths away

**NONE path:** `NONE — searched for: <description of what was reviewed, e.g. "duplicate
metrics between the stat strip and the detail dl" or "elements present only for a different
lens posture">`

### Question 2: Is the IA muddy?

**Target failure mode:** IA hierarchy — general-to-specific principle broken; next action
not obvious.

**Refutation probe:** Where does the general→specific hierarchy break for this lens, or where
is the next action not obvious? Point to the exact element (a heading, a navigation link, a
section order, a call-to-action placement).

**What counts as an answer:**
- A detail-level data point appearing above a summary, reversing the expected hierarchy
- A primary action buried below secondary evidence without a visual anchor
- A breadcrumb or scope ribbon that does not match where the operator is
- Navigation links that share weight with content (observer bias: the operator must scan
  the whole page to locate the next step)

**NONE path:** `NONE — searched for: <description, e.g. "inverted hierarchy between the
scope ribbon and the stat strip" or "primary action placement relative to secondary evidence">`

### Question 3: Redundant / coherent / least-surprising?

**Target failure mode:** redundancy and coherence — same information shown twice; divergence
from sibling surfaces doing the same job; vocabulary or layout that would surprise the operator.

**Refutation probe:** Name one place where this surface says the same thing twice, diverges
from a sibling surface doing the same job, or would surprise the operator given what they
have seen on adjacent pages.

**What counts as an answer:**
- The same count or status rendered in two different components on one page
- A label that uses a synonym not used on any other admin surface (e.g. "Deactivated" on
  one page, "Deletion scheduled" on another, for the same state)
- A component used differently from its canonical role in `admin-design-contract.md`
  (e.g. a `summary_chip` used for a non-metric value)
- A layout pattern that matches no established archetype from the design contract

**NONE path:** `NONE — searched for: <description, e.g. "duplicate count between the stat
strip and the filter panel" or "vocabulary drift between this surface and the audit pages">`

---

## Adversarial Framing and Forced-Finding Floor

The following instruction applies to every persona-panel review. It is the standing rubric
instruction and **must be followed verbatim**. Partial compliance invalidates the review.

> **Standing rubric instruction:**
>
> For each (lens × question) cell, find the **strongest case against this surface for this
> lens**. Do not anchor on what looks fine. Start by assuming something is wrong and search
> for evidence to support that assumption.
>
> A verdict of `keep` with zero findings is valid ONLY after you have:
> (a) actively tried to find a fault for this (lens × question) cell, and
> (b) stated what you searched for in the `NONE — searched for: <what>` token.
>
> **Forced-finding floor:** every (lens × question) cell in the output holds either:
> - A cited element with a concrete DOM/section anchor (heading text, component name,
>   CSS class, route path, or line-level reference), OR
> - The literal token `NONE — searched for: <what>` where `<what>` is a description
>   of the specific hypothesis that was tested and found to not hold.
>
> A cell is **never** left blank. A cell is **never** filled with a vague positive
> ("looks good", "no issues found") without the explicit `NONE — searched for:` token.
>
> Every finding must cite a **concrete DOM/section anchor**. Vibe-level assertions
> ("the page feels cluttered") without a cited element fail the forced-finding floor
> and must be replaced with a specific, locatable reference.

**Why adversarial framing?** The heuristic-evaluation and LLM-judge literature shows that
non-adversarial prompts produce rubber-stamped outputs at high rates. The `keep` with zero
`NONE` tokens is the canonical false-pass pattern. The forced-finding floor and explicit
`NONE — searched for:` token are the specific device that makes verdict distributions
low-variance across both human and LLM reviewers.

---

## Output Schema

Every persona-panel review produces a document with this exact structure. Phase 209 authors
8 per-surface documents instantiating this schema.

### YAML Frontmatter (machine-rollup-able)

```yaml
---
surface: <surface-id matching ledger row, e.g. "users-index-live">
ledger_cell: <L3 or L4 cell matching quality ledger, e.g. "users-index-live">
rubric_version: "1.0"
disposition: clean | actionable | blocked
verdicts:
  platform_admin:
    earning_its_place: keep | tighten | kill
    ia_muddy: keep | tighten | kill
    redundant_coherent_surprising: keep | tighten | kill
  support_investigator:
    earning_its_place: keep | tighten | kill
    ia_muddy: keep | tighten | kill
    redundant_coherent_surprising: keep | tighten | kill
  org_admin:
    earning_its_place: keep | tighten | kill
    ia_muddy: keep | tighten | kill
    redundant_coherent_surprising: keep | tighten | kill
findings:
  - element: "<DOM anchor or section reference>"
    lens: platform_admin | support_investigator | org_admin
    question: earning_its_place | ia_muddy | redundant_coherent_surprising
    refutation: "<one-line description of the failure>"
    disposition_action: tighten | kill
---
```

**Frontmatter field rules:**

- `surface` — matches the row key in `admin-quality-ledger.md` exactly (e.g. `users-index-live`,
  not `UsersIndexLive` or `admin/users`)
- `ledger_cell` — same value as `surface` for L3 surfaces; for L4 flows use the flow cell
  (`flow-platform-admin`, `flow-support-investigator`, `flow-org-admin`)
- `rubric_version` — static string `"1.0"` until a breaking schema change is ratified
- `disposition` — computed from worst verdict across all 9 cells: any `kill` → `blocked`;
  any `tighten` and no `kill` → `actionable`; all `keep` → `clean`
- `verdicts` — all 9 (3 lenses × 3 questions) keys present, never omitted
- `findings` — list of actionable rows; only non-`keep` verdicts generate a finding row;
  a `clean` disposition produces an empty list `findings: []`

### Markdown Body (human-auditable refutation log)

The document body contains one section per lens, ordered:
1. `## Platform Admin Lens`
2. `## Support Investigator Lens`
3. `## Org Admin Lens`

Each section contains the 3 verdict question subsections with full refutation prose. The
forced-finding floor applies to the body: every (lens × question) subsection ends with either
a cited finding or a `NONE — searched for:` token.

### Example per-lens section structure

```markdown
## Platform Admin Lens

Entry: `/admin` | Posture: triage | Persona: `admin@demo.tasklane.test`

### Earning its place?

[Finding or NONE token]

### Is the IA muddy?

[Finding or NONE token]

### Redundant / coherent / least-surprising?

[Finding or NONE token]
```

---

## Relationship to Quality Ledger

This section defines the **anti-collision contract** between the persona-JTBD rubric and the
`admin-quality-ledger.md` monotonic guard.

### Column-4 integer prohibition (D-07)

The quality ledger's `awk -F'|'` monotonic guard parses the tier value from column 4 of
every `| [a-z]`-prefixed table row using the pattern `tier ~ /^[012]$/`. Any bare integer
(`0`, `1`, or `2`) in column 4 of a rubric or panel document will be false-matched by the
guard.

**The rubric and all documents it governs (per-surface panel docs, roll-up index) MUST NEVER
place a bare `0`, `1`, or `2` in the 4th pipe-delimited column of any markdown table.**

Compliant column-4 values in rubric documents: `keep`, `tighten`, `kill`, `clean`,
`actionable`, `blocked`, `platform_admin`, `support_investigator`, `org_admin`, or any
non-integer string. These are structurally distinct from the ledger's `[012]` parse target.

### Roll-up index format

The Phase 209 roll-up index (`v1.42-PERSONA-JTBD-PANEL.md`) is a plain summary table:

| surface | disposition | kill-count | tighten-count | links |
|---------|-------------|------------|---------------|-------|

This table does NOT use the ledger's integer-parse format. The `disposition` column contains
`clean`, `actionable`, or `blocked` — never `0`, `1`, or `2`.

### What feeds the ledger vs what feeds the rubric

The quality ledger records **scorecard tier** (Tier 0/1/2): visual, technical, and semantic
quality graded against the fractal scorecard dimensions (D1–D11 + per-level add-ons). The
ledger's monotonic guard protects against quality regression.

The persona-JTBD panel records **UX fitness-for-purpose** (keep/tighten/kill per lens):
whether each surface serves its operator's job without verbosity, IA muddiness, or
redundancy. The panel's roll-up index is a separate artifact.

A surface must earn both: a `clean` disposition in the panel AND Tier 2 in the ledger for
the Phase 211 terminal ratification gate.

### Cross-references

- `admin-fractal-scorecard.md` → _L4 Flow Add-ons_: the three flow cells
  (`flow-platform-admin`, `flow-support-investigator`, `flow-org-admin`) that the lenses test
- `admin-fractal-scorecard.md` → _Persona-JTBD Rubric (Cross-Reference)_: the cross-reference
  block added near the L4 add-on section
- `admin-quality-ledger.md` → _flow-*_ rows: the L4 ledger cells where per-lens findings
  map back
- `admin-quality-ledger.md` → _Persona-JTBD Rubric (Cross-Reference)_: the cross-reference
  block added near the flow-* rows
- Phase 209 per-surface docs: the 8 instantiations of this output schema
- `v1.42-PERSONA-JTBD-PANEL.md` (Phase 209 artifact): the roll-up index aggregating all
  8 per-surface dispositions

---

Cross-reference: `admin-fractal-scorecard.md`, `admin-quality-ledger.md`
