# Phase 38: Human GA UAT gate — Context

**Gathered:** 2026-04-17  
**Status:** Ready for planning  
**Source:** Roadmap + REQUIREMENTS (UAT-01–UAT-02) + SEED-001 + research synthesis (library GA / OSS / adjacent auth ecosystems)

<domain>

## Phase boundary

Close **UAT-01** and **UAT-02**: each **SEED-001** human-only item is **executed with dated, pinned evidence** or **explicitly waived** with owner, date, residual risk, compensating verification, and (for waivers) expiry; outcomes are consolidated into **one** milestone-visible artifact so GA posture is defensible without tribal knowledge. **No new product features** — process, evidence, and documentation only.

</domain>

<decisions>

## Implementation decisions

### Unified operating principles (all four policy areas)

- **D-38-P01 — Reproducibility:** Every row names **Hex version + git SHA**, **Elixir/OTP**, **Postgres**, and **host anchor** (`test/example` path dep vs fresh `mix phx.new` + install). If it cannot be reproduced from the doc, it is not “done.”
- **D-38-P02 — Waivers are decisions:** “Skipped” without fields is invalid. Waivers are **dated, owned, risk-stated, compensating, time-bounded** (expiry or next verification event).
- **D-38-P03 — Evidence for reviewers:** Optimize for a future maintainer or security reader **reconstructing** what was true that day — not checkbox theater.
- **D-38-P04 — PII / secrets:** Assume screenshots or notes may leak. Prefer **transcripts, diffs, redacted crops**; never raw magic links, live tokens, or `.env` in repo.
- **D-38-P05 — Library vs app:** Validate **generator + library contract** on representative hosts. Do not claim “any Phoenix app” unless the row explicitly scoped a greenfield run.
- **D-38-P06 — Single source of truth:** **`v1.3-HUMAN-UAT.md`** is the canonical index; evidence lives under **`.planning/uat-evidence/<release>/`** and is linked, not duplicated ad hoc across READMEs.
- **D-38-P07 — Fail closed on security-adjacent flows:** Session boundaries, mail token usability, OAuth redirect/state/PKCE surfaces default to **execute** unless waiver documents **infeasibility + compensation** (e.g. stand-in IdP for Google-specific UI).
- **D-38-P08 — Contributor least surprise:** Prefer **`scripts/uat/` + example app** for repeatability; document anything that still requires human judgment (mail client variance, real provider quirks).

### Area 1 — Execute vs waive policy

- **D-38-01 — Default posture:** **Execute-by-default** for all eight SEED-001 items; waivers are **exceptional**.
- **D-38-02 — Tiered criticality:** Treat items touching **install reproducibility, session/cookie boundaries, mail-delivered secrets, OAuth redirect wiring** as **must-pass or tightly waived** (no vague “later”). Cosmetic-only variance may use **representative substitution** (e.g. HTML source / second client) only if the waiver names **what risk remains** (e.g. Outlook CSS).
- **D-38-03 — Minimum waiver record (per item):** `item_id`, `date`, `owner`, `version_sha_anchor`, `reason`, `residual_risk`, `compensating_evidence`, `expiry_or_next_trigger`, `link` into evidence tree.
- **D-38-04 — Partial multi-client runs:** Allowed as **Pass** only if the row states **which clients ran**, **which waived**, and **compensation** (e.g. raw `.eml` + baseline HTML diff). Otherwise mark **Waived** or **Blocked**, not silent partial.

### Area 2 — Evidence format

- **D-38-05 — Repository layout:** Evidence under **`.planning/uat-evidence/v1.3.0/`** (or matching release tag), with **`INDEX.md`** listing all assets + waiver cross-links.
- **D-38-06 — Primary medium:** **Text-first** (`install-from-example.md`, command transcripts, generator diff summaries); **screenshots only** where they add density (OAuth consent, mail chrome) and **after redaction checklist** (crop, rotate secrets, shorten URLs, blur PII).
- **D-38-07 — Optional binaries:** Large video/binary sets may live in **GitHub Release assets** only if **`INDEX.md` retains stable description + checksum + link** — never sole copy on ephemeral drives.

### Area 3 — UAT-02 consolidated artifact

- **D-38-08 — Canonical file:** **`.planning/v1.3-HUMAN-UAT.md`** as the **single milestone-visible** UAT outcome (satisfies UAT-02 “new file” path). Milestone audit (when written) **references this file in ≤10 lines** instead of duplicating the table.
- **D-38-09 — Master table columns:** `SEED_item | Status (Executed / Waived / Blocked) | Date | Owner | Environment (Elixir/OTP, Postgres, sigra ref, host type) | Evidence_link | Expiry (waivers) | Notes`.
- **D-38-10 — Changelog relationship:** User-facing **CHANGELOG** may get a **one-line outcome** (“Human UAT: see `v1.3-HUMAN-UAT.md`”); waivers stay in the UAT artifact, not spammed into release notes tone.

### Area 4 — Environment & scope anchor

- **D-38-11 — Daily harness:** **`test/example`** (per `scripts/uat/RUNBOOK.md` + `scripts/uat/up.sh`) is the **default** host for rerunnable items and contributor alignment with CI smoke / Playwright baseline.
- **D-38-12 — Fresh Phoenix host (mandatory trigger):** Any release touching **installer / generator templates / OAuth wiring docs** requires a **fresh `mix phx.new` + `mix sigra.install`** run for SEED items **3** and **8** (and any row scoped “greenfield”). **Hotfix** that **does not** touch those surfaces may **waive** greenfield only by **re-anchoring** to a **prior pinned** greenfield evidence set and stating **unchanged risk**.
- **D-38-13 — OAuth / mail realism:** Prefer **local stand-ins** (e.g. Mailpit-class sink, OIDC/OAuth stand-in) for protocol and redirect behavior; **Google (or other public IdP)** only where provider-specific behavior matters — if waived, compensation must still cover **redirect URI, state/PKCE, error paths** on the stand-in.

### Claude's discretion

- Exact subdirectory naming under `uat-evidence/` (patch vs minor folder).
- Redaction tooling (image editor vs automated blur) — outcome must satisfy D-38-P04.
- Whether a one-line mirror summary is pasted into a future `v1.3-MILESTONE-AUDIT.md` body vs purely by reference — default is **by reference only**.

</decisions>

<canonical_refs>

## Canonical references

**Downstream agents MUST read these before planning or implementing Phase 38.**

### Requirements & scope

- `.planning/REQUIREMENTS.md` — UAT-01, UAT-02 (human GA gate)
- `.planning/ROADMAP.md` — Phase 38 row
- `.planning/seeds/SEED-001-v1.0-ga-human-uat-gate.md` — eight human-only items, breadcrumbs, time estimate

### Existing UAT / example harness

- `scripts/uat/RUNBOOK.md` — environment, mailbox preview, checkbox pattern
- `scripts/uat/up.sh` / `scripts/uat/down.sh` — stack lifecycle (referenced from RUNBOOK)
- `guides/introduction/getting-started.md` — SEED item 8 clean-machine target
- `test/example/` — default human + CI alignment host (exact paths per current repo layout)

### Historical audit context

- `.planning/v1.0-MILESTONE-AUDIT.md` — HUMAN-UAT backlog context (path per SEED; use archived copy under `.planning/milestones/` if v1.0 file moved)

### Automation baseline (contrast with human-only)

- `test/example/priv/playwright/tests/golden-path.spec.ts` — what CI already covers; informs waiver compensation text

</canonical_refs>

<code_context>

## Existing code insights

### Reusable assets

- **`scripts/uat/`** — Bring-up, mailbox URL, and checkbox-oriented runbook already match “evidence + least surprise” for maintainers.
- **`test/example`** — Deterministic app for most SEED flows without asking humans to invent project structure.

### Established patterns

- **Playwright + smoke** in CI — human gate should **cite** what automation already proves so waivers do not re-test the same surface without stating delta.

### Integration points

- Phase 38 **planning tasks** likely add **`v1.3-HUMAN-UAT.md`** at `.planning/` root and **`uat-evidence/`** tree; may tick **UAT-01/UAT-02** checkboxes in `REQUIREMENTS.md` when complete.

</code_context>

<specifics>

## Specific ideas

- Research synthesis emphasized patterns from **OWASP-style accepted-risk documentation**, **Hex/changelog credibility**, and **cross-ecosystem auth pain** (redirect URIs, proxy headers, mail token usability, “demo vs real app”) — captured as D-38-12 / D-38-13.
- User asked for **one-shot, cohesive** recommendations across all four gray areas; no per-option interactive log — see `38-DISCUSSION-LOG.md`.

</specifics>

<deferred>

## Deferred ideas

- **Expanding SEED-001 beyond eight rows** — new capability; belongs to a future milestone if product scope adds flows.
- **Full public video walkthroughs** — optional; not required for v1.3 gate if INDEX + text evidence suffice.

</deferred>

---

*Phase: 38-human-ga-uat-gate*  
*Context gathered: 2026-04-17*
