# Phase 70 — Technical research: Upgrade stub + non-goal attestation

**Question:** What do we need to know to plan **ACF-05** and **ACF-06** well?

## Summary

Phase 70 is **documentation + requirements traceability only**: (1) add **`guides/introduction/upgrading-to-v1.10.md`** in the same voice and structure as **`upgrading-to-v1.8.md`**, clarifying **planning milestone v1.10** vs **Hex SemVer** (`mix.exs` / `CHANGELOG.md`) and linking backward through **v1.9** → **v1.8** → **v1.7** upgrade extras; register the file in **`mix.exs`** `extras` **immediately after** **`upgrading-to-v1.8.md`**. (2) Ensure **`.planning/REQUIREMENTS.md`** Out of Scope rows and **`.planning/PROJECT.md`** Current Milestone prose **explicitly** defer **`sigra_lockspire`** / mandatory Lockspire coupling and **full SEED-002** conversion with **resolvable markdown links** to **ADR 001** and **SEED-002** seed paths as stated in ROADMAP success criteria.

## Findings

### Upgrade stub pattern (v1.7 / v1.8)

- **`guides/introduction/upgrading-to-v1.8.md`**: H1 “Upgrading notes — toward v1.8”; opening paragraph separates **library SemVer on Hex** from **`.planning/` milestone labels**; “After v1.7” section points to prior upgrade page; “Library / host upgrade checklist” is numbered deps bump + compile + test; “See also” lists sibling intro HTML links (`first-hour.html`, etc.).
- **`mix.exs` `extras`**: Intro upgrade files appear in a block after `troubleshooting-install.md` and before `upgrading-to-v1.1.md` / flows — **v1.10** must sit **after** `upgrading-to-v1.8.md` per **ACF-05** (ROADMAP + REQUIREMENTS).

### v1.9 narrative anchor

- **v1.9** shipped audit-atomicity work (phases **66–67**); adopters on **`0.2.x`** may associate “v1.9” with planning docs, not a second Hex version axis — reuse the **“planning vs SemVer”** framing from v1.8 and point to **`.planning/milestones/v1.9-ROADMAP.md`** for archive context.

### ACF-06 attestation targets

- **`.planning/decisions/001-defer-sigra-lockspire-glue-package.md`**: accepted ADR — no `sigra_lockspire` glue package near term; revisit triggers listed.
- **`.planning/seeds/SEED-002-phase-9-log-safe-atomicity-followup.md`**: deferred full hybrid → `Multi` conversion; triggers for when to schedule.
- **`.planning/PROJECT.md`** “Current Milestone” already names **ADR 001**, **SEED-002**, and phase **70** — executor should verify **clickable** relative links where the success criteria expect “cite” + “pointers.”
- **`.planning/REQUIREMENTS.md`** Out of Scope **table** currently names ADR **001** and **SEED-002** in prose but **without** markdown links on the table rows — **ACF-06** wants paths “present and accurate”; adding `[ADR 001](decisions/…)` / `[SEED-002](seeds/…)` from REQUIREMENTS.md’s directory satisfies the contract.

### ExDoc verification

- **`MIX_ENV=dev mix docs --warnings-as-errors`** after `extras` change and new guide — standard for intro doc phases (**068**/**069** pattern).

## Risks / pitfalls

- **Ordering drift:** If `upgrading-to-v1.10.md` is appended at end of `extras` instead of after `upgrading-to-v1.8.md`, **ACF-05** fails the stated ordering requirement.
- **Link targets:** Links from REQUIREMENTS to decisions/seeds must use paths **relative to `.planning/REQUIREMENTS.md`** (`decisions/…`, `seeds/…`) — same as other REQUIREMENTS links in the file.

## Validation Architecture

Phase deliverables are **Markdown + optional `mix.exs` list edit**. Automated verification: **grep** for file existence, ordering substrings in `mix.exs`, and link substrings in REQUIREMENTS/PROJECT; **`mix docs --warnings-as-errors`** after doc changes.

| Dimension | Approach |
|-----------|----------|
| Correctness | New guide exists; `extras` order; ACF-06 links grep-verifiable |
| Security doc posture | Upgrade stub must not imply a security guarantee beyond what CHANGELOG / semver policy states |
| Traceability | Plan frontmatter lists **ACF-05** and/or **ACF-06** |

## RESEARCH COMPLETE
