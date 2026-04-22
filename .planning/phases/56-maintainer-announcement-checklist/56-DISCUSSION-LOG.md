# Phase 56: Maintainer announcement checklist — Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.  
> Decisions are captured in **56-CONTEXT.md** — this log preserves alternatives considered.

**Date:** 2026-04-22  
**Phase:** 56 — Maintainer announcement checklist  
**Areas discussed:** Section placement & narrative split; HexDocs-safe evidence links; Owner semantics; Mandatory vs optional announcement steps  
**Mode:** User selected **all** areas + requested parallel **subagent research** synthesis → decisions recorded without per-turn conversational menus.

---

## Section placement & narrative split

| Option | Description | Selected |
|--------|-------------|----------|
| A — Top of file (after intro) | Maximum visibility; pushes operational sections down | |
| B — Nested under Release automation | Single mechanical spine; weaker discoverability for “announcement” | |
| C — After Release automation, before Manual checklist | Happy path → comms → break-glass; minimal TOC creep | ✓ |
| D — Separate maintainer doc | Room for narrative; worse single-file Ctrl+F | |

**User's choice:** **Option C** (+ **intro pointer** for skimmers), per research + coherence with existing `MAINTAINING.md` H2 structure.  
**Notes:** Avoid three competing ship stories; announcement section stays **thin** and **links** to installer golden, Nyquist, Actions, Release Please, manual checklist.

---

## HexDocs-safe evidence links

| Option | Description | Selected |
|--------|-------------|----------|
| Relative `.planning/` links | Simple in GitHub preview | |
| Tag-scoped GitHub blob URLs | Reproducible; forum-copy safe; matches phase 55 | ✓ |
| `main` branch URLs | Low maintenance | |
| Release-time token substitution | Theoretically unified; tooling burden | |

**User's choice:** **Tag-scoped GitHub** for out-of-tarball evidence; **relative** only among shipped HexDocs targets.  
**Notes:** ExDoc tarball boundary (e.g. ex_doc #889 discussion) — do not assume relative deep-repo links work on hexdocs.pm.

---

## Owner column semantics

| Option | Description | Selected |
|--------|-------------|----------|
| A — Stable roles + roster elsewhere | Low staleness; K8s/CNCF-like | ✓ |
| B — `@handles` in runbook | Immediate ping; high staleness | |
| C — Generic “Maintainers” only | Low noise; fuzzy accountability | |
| D — CODEOWNERS only | Merge path; misses comms | |

**User's choice:** **Option A** — roles in `MAINTAINING.md`; names per-run in **tracking issue roster** (exact template = executor discretion).  
**Notes:** Copy-ready “Assignment” block suggested in research folded into **56-CONTEXT** D-10.

---

## Mandatory vs optional announcement steps

| Option | Description | Selected |
|--------|-------------|----------|
| Ship vs Announce split | Artifact truth vs attention budget | ✓ |
| All channels mandatory | High support load; discouraged for auth libs | |
| Silent ship only | Underserves discoverability; out of scope for MAINT-01 | |

**User's choice:** **Ship** rows = link to existing release + CI + evidence policy; **Announce** rows = **default optional** with honest substitutes and bandwidth guardrails (HN/forums).  
**Notes:** Auth-adjacent footguns (over-claim, comparative snark, implied warranty) → tone constraints in CONTEXT D-16.

---

## Claude's Discretion

- Exact prose, optional micro “incident comms” stub, tracking-issue template location — within **56-CONTEXT** discretion notes.

## Deferred Ideas

_None._
