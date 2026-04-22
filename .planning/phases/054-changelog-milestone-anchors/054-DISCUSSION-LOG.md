# Phase 54: Changelog & milestone anchors — Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.  
> Decisions are captured in `054-CONTEXT.md`.

**Date:** 2026-04-22  
**Phase:** 54 — Changelog & milestone anchors  
**Areas discussed:** Milestone vs semver; Density (hybrid); `[Unreleased]` hygiene; Ordering & audience  
**Mode:** User selected **`all`** gray areas and requested **parallel subagent research** + **one-shot cohesive recommendations** (no per-question interactive passes).

---

## Milestone labels vs Hex semver

| Option | Description | Selected |
|--------|-------------|----------|
| A | Semver-only headings + separate glossary / map doc | ✓ (merged with C) |
| B | Dual milestone + semver in each heading | |
| C | Milestone as subsection under semver release | ✓ |
| D | Split files (CHANGELOG vs release map) | Partially (MILESTONES stays canonical; no second file required) |
| E | Narrative only in Hex/docs | |

**User's choice:** **Semver-only top-level headings** + **`### Roadmap traceability`** under releases + **short glossary** at top of `CHANGELOG.md` (research consensus: least surprise, Hex honesty, PUB-02 anchors).

**Notes:** Subagent research emphasized footgun of **v1.x-looking headings** implying publishable versions; Elixir ecosystem norm is **package version as changelog spine**.

---

## Density — narrative vs pointers

| Option | Description | Selected |
|--------|-------------|----------|
| A | Full milestone narrative in CHANGELOG | |
| B | Minimal bullets + pointers only | Partially |
| C | Hybrid (operational changelog + canonical MILESTONES) | ✓ |
| D | GitHub Releases as primary narrative | |

**User's choice:** **Hybrid (C)** — substantive bullets for breaks/security/migrations; **long narrative + GA matrix** stay in `.planning/` with **stable links**; avoid duplicate GA claims in changelog.

**Notes:** Elixir integrator norm: changelog answers **“what breaks when I bump?”**; auditors need **bounded facts + links**, not marketing duplication.

---

## `[Unreleased]` hygiene

| Option | Description | Selected |
|--------|-------------|----------|
| A | Canonical single `[Unreleased]` (KAC) | ✓ |
| B | Next-version-dev heading | |
| C | Thematic subheads under Unreleased | Optional / constrained |
| D | Periodic grooming + release train | ✓ |
| E | Freeze / branch near tag | As needed (embargo) |
| F | Split security detail to advisories | ✓ (mirror one line + link) |

**User's choice:** **KAC `[Unreleased]`**, **same-PR security bullet rule**, **move block on tag with version bump**, **groom before release**, **omit empty sections**.

---

## Ordering & audience

| Option | Description | Selected |
|--------|-------------|----------|
| A | Strict KAC example type order | |
| B | Risk-weighted KAC type order + BREAKING first in Changed | ✓ |
| C | Custom thematic sections (GA, Audit) | |
| D | Preamble + KAC | ✓ |

**User's choice:** **Security → Deprecated → Removed → Changed (BREAKING first) → Fixed → Added**; optional **≤6 line** preamble; **no non-KAC `###` sections**.

---

## Claude's Discretion

- Exact wording during `CHANGELOG.md` edit pass and minor classification judgment when moving existing bullets (**D-20**), bounded by `MILESTONES.md` truth.

## Deferred Ideas

- Changelog generation automation; GitHub Releases mirroring — deferred (see `054-CONTEXT.md`).
