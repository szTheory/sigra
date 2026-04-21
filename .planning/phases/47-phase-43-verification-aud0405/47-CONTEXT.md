# Phase 47: Phase 43 verification & AUD-04/05 closure — Context

**Gathered:** 2026-04-21  
**Status:** Ready for planning

**Source:** `/gsd-discuss-phase 47` with **all** gray areas selected; four parallel research passes (Nyquist policy, verification doc shape, CI gate depth, REQUIREMENTS PR hygiene) synthesized into one policy set aligned to `43-CONTEXT.md`, ROADMAP phase **47**, and phase **50** Nyquist ownership.

<domain>

## Phase boundary

Publish **`43-VERIFICATION.md`** (outcome snapshot + receipts), reconcile **AUD-04** and **AUD-05** in `.planning/REQUIREMENTS.md` (and ROADMAP narrative if needed) with **phase 43** inventories and plan summaries, and define honest **project gate** language—**without** re-executing AUD implementation work or expanding scope into MFA/API/OAuth batches (**44–45**) or their verification phases (**48–49**).

Formal **Nyquist** sign-off for phases **41–44** remains **phase 50** unless an explicit exception is recorded; phase **47** closes bookkeeping and falsifiable evidence for **43** only.

</domain>

<decisions>

## Implementation decisions

### D-47-01 — Nyquist vs `43-VALIDATION.md` (“if required”)

- **Do not** flip `nyquist_compliant` to `true` or claim full Nyquist compliance in phase **47** unless a deliberate project decision moves that work forward from phase **50**.
- **Default policy:** **Evidence-first, Nyquist-deferred** — update `43-VALIDATION.md` to reflect **actual** task status, sampling notes, and links to tests/docs; treat ROADMAP criterion (3) “Nyquist run if required” as satisfied for phase **47** by **explicit cross-reference to phase 50** plus **scoped, falsifiable** verification content—not by checkbox theater.
- **Optional bridge only if needed:** a **versioned, named partial** subset of Nyquist-style checks, clearly labeled **partial** (never silent substitute for full Nyquist). Prefer skipping unless compliance demands it.
- **Rationale:** Mature Elixir OSS gates truth with **reproducible CI + CONTRIBUTING commands**; ornate compliance labels that outrun automation undermine Sigra’s honest GA posture. Phase **50** already owns “Nyquist **41–44** if required”—duplicating that in **47** risks scope creep and dual truth.

### D-47-02 — `43-VERIFICATION.md` vs `43-VALIDATION.md` (document architecture)

- **Adopt two-file pattern:** **`43-VERIFICATION.md`** = **frozen outcome** in the same **family** as `46-VERIFICATION.md` (YAML frontmatter `status` / `verified` date, **Must-haves** table with **evidence paths** into inventory + summaries + tests, **Automated checks run** with **verbatim commands**, short **Notes**).
- **Keep `43-VALIDATION.md`** as the **validation contract / per-task map** (Nyquist-style intent, sampling policy, row-level status). During execution it may evolve; at close it must **cross-link** to verification and must not **duplicate** canonical command strings without an owner rule.
- **Authority rule:** During active work, **commands may be canonical in `43-VALIDATION.md`**; at sign-off, **copy verbatim** into `43-VERIFICATION.md` so the verification file is a **dated snapshot** (intentional duplication only snapshot ↔ living map boundary).
- **Rationale:** Kubernetes-style ecosystems separate **conformance evidence** from **long maps**; folding everything into one file produces unmaintainable gate docs. Inventory (`43-AUD-04-INVENTORY.md`) stays scope truth; summaries (`43-0x-SUMMARY.md`) stay narrative; validation explains **how** slices are provable; verification records **what passed** with receipts.

### D-47-03 — “Passes project gate” / CI depth

- **Define two labeled blocks** in `43-VERIFICATION.md` (vocabulary from tiered gating):
  1. **Merge gate** — fast, deterministic (target: contributor-friendly wall-clock): at minimum `mix compile` with project-standard warnings policy **if** the repo already treats that as non-negotiable; plus **explicit** `mix test` **paths and/or tag policy** that **enumerate every AUD-05 conversion boundary** claimed complete (and any inventory grep checks already used in phase 43). Scoped list must be **substantive**—not format-only checks for atomicity claims.
  2. **Release attestation** (optional but recommended before flipping REQ checkboxes): **full** root `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` **or** a named CI workflow/job at a **pinned commit SHA** (record URL / job id in verification). Phase **46** legitimately avoided full suite as **sole** gate for doc-only GA posture; phase **43** is **not** doc-only—atomic audit claims need **DB-backed** proof in the merge gate list, with full suite as attestation when maintainers run it.
- **Prefer stable entry points** where practical: Mix **aliases** (e.g. `mix ci.audit_43`) over drifting raw one-liners—document the alias in verification when introduced.
- **Footgun to avoid:** “Gate passed” without commands tied to **invariants** (inventory row IDs, test module names)—that reads as process theater to auditors.

### D-47-04 — REQUIREMENTS / ROADMAP reconciliation & PR hygiene

- **Single atomic PR** for phase **47** closure when marking **AUD-04** / **AUD-05** satisfied: **`43-VERIFICATION.md`** (new) + updates to **`REQUIREMENTS.md`** (checkboxes + traceability table) + **`ROADMAP.md`** only if narrative drift—so `main` **never** shows requirements complete **without** the verification artifact merged **first** in the same change-set (same PR, ordered commits acceptable if bisect-clean).
- **Split PRs** allowed only under strict rule: PR1 adds verification and leaves AUD rows **Pending**; PR2 flips checkboxes **immediately after merge**, same day, cross-linked—**never** the reverse order (forbidden footgun per `43-CONTEXT` guardrail on AUD-04).
- **Table vs narrative:** When editing `REQUIREMENTS.md` body (e.g. phase mapping **47–49**), **refresh the traceability table in the same edit** so checkboxes, table rows, and prose stay one source of truth for auditors.

### Claude's discretion

- Exact YAML keys on `43-VERIFICATION.md` frontmatter (mirror **46** closely but minor field differences acceptable).
- Whether to introduce a Mix alias vs only path-scoped `mix test` lines in v1.4 (prefer alias if it reduces drift).
- Wording of the phase **50** deferral paragraph (tone: factual, not evasive).

</decisions>

<canonical_refs>

## Canonical references

**Downstream agents MUST read these before planning or implementing.**

### Requirements & roadmap

- `.planning/ROADMAP.md` — Phase **43** (done), **47** (this closure), **50** (Nyquist 41–44 ownership)
- `.planning/REQUIREMENTS.md` — **AUD-04**, **AUD-05**, traceability table, exclusion rules

### Phase 43 artifacts (evidence sources)

- `.planning/phases/43-audit-inventory-auth-atomic-batch/43-CONTEXT.md` — Locked decisions for inventory, AUD-05 stack, tests, waves
- `.planning/phases/43-audit-inventory-auth-atomic-batch/43-AUD-04-INVENTORY.md` — AUD-04 scope and row IDs
- `.planning/phases/43-audit-inventory-auth-atomic-batch/43-VALIDATION.md` — Validation map (update honestly; see D-47-01/02)
- `.planning/phases/43-audit-inventory-auth-atomic-batch/43-01-SUMMARY.md` through `43-04-SUMMARY.md` — Plan narratives

### Verification template precedent

- `.planning/phases/46-human-ga-matrix-gap-closure/46-VERIFICATION.md` — Structure to mirror for `43-VERIFICATION.md`

### Audit implementation references

- `lib/sigra/audit.ex` — `log_safe/3`, `log_multi_safe/3`, `__log_internal__/3`
- `lib/sigra/auth.ex` — Atomic vs hybrid dispatch comments
- `guides/recipes/testing.md` — Audit testing recipe (if present)
- `.planning/phases/39-audit-trail-completeness/39-CONTEXT.md` — Audit assertion patterns

</canonical_refs>

<code_context>

## Existing code insights

### Reusable assets

- **Phase 46 verification template** — Frontmatter + tables + command transcript pattern for new `43-VERIFICATION.md`.
- **Phase 43 deliverables** — Inventory + summaries + validation scaffold; phase **47** wires them into a **single sign-off surface**.

### Established patterns

- **Honest scoped CI evidence** — Phase **46** documented explicit `mix test` paths and noted when full root suite was not the sole gate; phase **47** adopts **tiered** language but requires **stronger** scoped DB proof for atomic audit claims (D-47-03).

### Integration points

- **`REQUIREMENTS.md` checkboxes** — Flip only when `43-VERIFICATION.md` merge gate + attestation policy in D-47-03 are satisfied and documented.
- **Phase 50** — Nyquist batch work; `43-VALIDATION.md` `nyquist_compliant` and any full Nyquist runs should align with that phase unless explicitly escalated.

</code_context>

<specifics>

## Specific ideas

- User requested **all** gray areas in one pass with **subagent research**; recommendations favor **least surprise**, **maintainer DX**, **defensible audit evidence**, and **cohesion** with roadmap division of labor (**47** = 43 closure, **50** = cross-phase Nyquist hygiene).

</specifics>

<deferred>

## Deferred ideas

- **Full Nyquist compliance** for phase **43** — belongs to **phase 50** (or explicit out-of-band decision), not implied by phase **47** closure alone.
- **AUD-06..AUD-08** verification and C-1 narrative — phases **48–49** per ROADMAP.

</deferred>

---

*Phase: 47-phase-43-verification-aud0405*  
*Context gathered: 2026-04-21*
