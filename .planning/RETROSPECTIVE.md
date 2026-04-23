# Project Retrospective

*Living document updated at milestone boundaries. v1.6 section added at ship (2026-04-23).*

## Milestone: v1.6 — Nyquist closure + OAuth audit depth

**Shipped:** 2026-04-23  
**Phases:** 3 (57–59) | **Plans:** 6 | **Sessions:** n/a (not instrumented)

### What was built

- **NYQ-01 / NYQ-02** — Canonical `.planning/nyquist-phases-41-44-matrix.md` plus `MAINTAINING.md` index; explicit disposition + reopen triggers for historical **41–44** rows; optional **`Phase57NyquistMatrixContractTest`** guard.
- **OA-01** — **`Sigra.OAuthCeremonyAuditTest`** (registration + `authorize_url` audit assertions on Postgres) and **`phase_58_oauth_oa01_ci_contract_test`** to keep `library_tests` honest about OAuth exclude drift.
- **OA-02** — **`docs/uat-ci-coverage.md`** hub for machine vs human OAuth proof; GA-03 / waiver / evidence **INDEX** / **`docs/ga-evidence.md`** / **PROJECT** alignment (Phase 59).

### What worked

- **Narrow verification milestone** closed planning truth gaps without shipping new end-user auth surface area.
- **Dedicated ceremony test module** separated merge-blocking OAuth audit proof from rollback-only atomicity tests.

### What was inefficient

- **`gsd-sdk query milestone.complete`** failed again (`version required for phases archive`); manual archival duplicated v1.3–v1.5 toil.
- No **`v1.6-MILESTONE-AUDIT.md`** artifact — acceptable given **4/4** reqs + summaries, but audits remain the gold standard when time allows.

### Patterns established

- **Two-tier maintainer docs:** short index in `MAINTAINING.md`, canonical matrix under `.planning/`.
- **Grep-first OA-02 maintenance:** subsection titles carry literal module / job names for quick CI↔docs consistency checks.

### Key lessons

1. When **v1.3** explicitly deferred OAuth ceremony audit assertions, schedule a **small follow-on milestone** rather than letting the waiver live forever without machine proof.
2. **Nyquist honesty** is mostly **disposition visibility** — matrices + triggers beat silent `nyquist_compliant: false` rows.

### Cost observations

- Model mix: n/a  
- Sessions: n/a  
- Notable: High leverage per line changed; mostly tests + maintainer-facing docs.

---

## Milestone: v1.5 — Public release narrative & community readiness

**Shipped:** 2026-04-22  
**Phases:** 4 (53–56) | **Plans:** 5 | **Sessions:** n/a (not instrumented)

### What was built

- **PUB-01** — `mix.exs` Hex description and `package[:links]` aligned with shipped **v1.0–v1.4** and honest optional-dep framing.
- **PUB-02** — `CHANGELOG.md` milestone glossary, roadmap traceability blocks (**v1.2–v1.4**), and compare URLs tied to `@source_url`.
- **DOC-01** / **DOC-02** — README **Production readiness & GA evidence**, **`SECURITY.md`**, **`docs/ga-evidence.md`**, ExDoc extras, and `mix docs --warnings-as-errors` hygiene.
- **MAINT-01** — **First public launch** checklist in **`MAINTAINING.md`** with owners, tag-scoped `.planning` pointers, and optional comms rows aligned with **v1.4** waivers.

### What worked

- **Narrative-only milestone** stayed bounded: no auth surface expansion while still shipping maintainer-critical artifacts.
- **Reuse of v1.4 evidence** as the canonical GA story avoided re-running the full human matrix in-docs.

### What was inefficient

- **`gsd-sdk query milestone.complete`** failed again (`version required for phases archive`); manual archival duplicated v1.3/v1.4 toil.
- **`roadmap.analyze`** still returned an incomplete phase list for this roadmap shape (only phase **56** in one probe).

### Patterns established

- **Tag-scoped GitHub URLs** for `.planning` evidence in README / maintainer docs where ExDoc cannot resolve local paths.
- **Ship vs announce** separation in maintainer checklist — execution of posts stays optional; the artifact is the ordered runbook.

### Key lessons

1. Close **public narrative** milestones with the same traceability table discipline as product milestones — small REQ sets still benefit from explicit phase mapping.
2. When automation regresses, **document the manual close path** in `MILESTONES.md` so the next ship does not wonder whether archival “counts.”

### Cost observations

- Model mix: n/a  
- Sessions: n/a  
- Notable: Very small code footprint; highest value was cross-doc consistency and link hygiene.

---

## Milestone: v1.4 — GA readiness & audit trail completeness

**Shipped:** 2026-04-22  
**Phases:** 12 (41–52) | **Plans:** 38 | **Sessions:** n/a (not instrumented)

### What was built

- **GA-01** backup-code rotation end-to-end in library, generator surfaces, and regression tests.
- **GA matrix** with explicit **Executed / Waived / Blocked** rows, dated evidence, and documented machine substitutes where human rows were waived.
- **AUD-04..AUD-08** inventory and prioritized **`log_safe/3` → `Ecto.Multi`** conversion batches with audit-aware tests; **43/44/45** merge-gated `*-VERIFICATION.md` artifacts and refreshed Phase 9 **C-1** matrices.
- **Nyquist + install golden** policy in `MAINTAINING.md`, **`mix ci.install_golden`**, **`install_golden_contract`**, and CI path coupling so installer receipts stay merge-blocking where intended.
- **Milestone honesty** guardrails: ROADMAP clarifies implementation vs verification phases; contract tests lock narrative drift.

### What worked

- **Gap-closure phases** (46–52) after an early **`gaps_found`** audit prevented “green plans / red matrix” drift at close.
- **Merge gates as documents** (`mix ci.audit_45`, install-golden contract tests) made deferred human rows legible without pretending they were executed.

### What was inefficient

- **`gsd-sdk query milestone.complete`** still failed in-repo; archival remained a manual, error-prone checklist (same theme as v1.3 retro).
- **`roadmap.analyze`** returned an empty phase list for Sigra’s roadmap shape — readiness checks had to be manual.

### Patterns established

- **Implementation vs verification** phase pairs (44 vs 48, 45 vs 49) called out explicitly in ROADMAP prose.
- **GA waiver ↔ CI attestation** cross-links enforced by structural tests, not only narrative docs.

### Key lessons

1. When a milestone audit goes **`gaps_found`**, either re-audit or schedule explicit **gap-closure phases** with the same REQ IDs — do not “hope” drift resolves.
2. **Installer golden** belongs in the same policy frame as library tests when GA rows cite it as substitute evidence.

### Cost observations

- Model mix: n/a
- Sessions: n/a
- Notable: Heavy verification + CI policy work; relatively small net-new product surface.

---

## Milestone: v1.3 — Cleanup & Hardening

**Shipped:** 2026-04-19  
**Phases:** 5 | **Plans:** 11 | **Sessions:** n/a (not instrumented)

### What was built

- Nyquist-style inventory and explicit waivers for historical planning validation debt, plus a cheap structural verifier script.
- SHA-pinned first-party GitHub Actions upgrades with Dependabot triage notes and contributor-facing pin policy.
- Shift-left GA UAT evidence: CI job map, Playwright GA slice, consolidated human-UAT tables under `.planning/`.
- `Sigra.Audit.Assertions`, atomic audited `api.token_create`, and example-app audit smoke for core login + MFA enrollment paths.
- Maintainer-facing `MAINTAINING.md` release guidance, optional isolated Hex publish workflow, and bash planning hygiene superseding broken JSON audit tooling paths.

### What worked

- Treating **999.x** seeds as milestone-scoped work prevented infinite “we’ll fix planning later” drift.
- Automation-first evidence for **SEED-001** reduced reliance on subjective screenshots for merge gates.
- Keeping v1.3 explicitly **non-product** avoided scope creep while still shipping library + CI improvements.

### What was inefficient

- `gsd-sdk query` / `milestone.complete` automation assumed by upstream workflow docs was unavailable here — archival steps were performed manually.
- `STATE.md` velocity metrics for v1.3 were not kept current mid-flight; recovery relied on per-phase `*-VERIFICATION.md`.

### Patterns established

- **Machine-readable UAT maps** (`docs/uat-ci-coverage.md`) as the canonical bridge from SEED rows to CI jobs.
- **Plain-function audit test helpers** with explicit `repo` argument — friendly to Sandbox and ordering-sensitive assertions.

### Key lessons

1. Close planning-debt loops with **inventory + waiver + verifier** rather than silent exceptions.
2. When hybrid audit writes exist, pick **one high-risk API path** for a reference `Ecto.Multi` implementation before boiling the ocean.
3. Deprecate broken maintainer tooling by **superseding docs + bash** instead of leaving stale JSON flags in READMEs.

### Cost observations

- Model mix: n/a
- Sessions: n/a
- Notable: Milestone was mostly planning + CI + tests; highest human cost was evidence consolidation and policy wording.

---

## Cross-Milestone Trends

### Process evolution

| Milestone | Sessions | Phases | Key change |
|-----------|----------|--------|--------------|
| v1.6 | n/a | 3 | Nyquist 41–44 posture matrix + OA-01 OAuth ceremony audit tests + OA-02 docs alignment |
| v1.5 | n/a | 4 | Public narrative + Hex/changelog/README/MAINTAINING alignment with v1.4 GA evidence |
| v1.4 | n/a | 12 | GA matrix honesty + audit Multi batches + merge-gated verification + install-golden CI coupling |
| v1.3 | n/a | 5 | Shift-left UAT + explicit planning archive at close |

### Cumulative quality

| Milestone | Tests | Coverage | Zero-dep additions |
|-----------|-------|----------|---------------------|
| v1.6 | `Sigra.OAuthCeremonyAuditTest` + planning/CI contract tests | n/a | None |
| v1.5 | Docs compile gates (`mix compile` / `mix docs --warnings-as-errors`) | n/a | None |
| v1.4 | Planning contract tests + `verify-phase36` path fix | n/a | None in this milestone close commit |
| v1.3 | Library + example suites extended via new audit tests / smoke | n/a | Optional workflow snippets only |

### Top lessons (verified across milestones)

1. **Automation-first verification** pays off again (v1.0 Playwright → v1.2 harness → v1.3 GA shift-left).
2. **Explicit waivers beat implicit debt** for planning artifacts (Nyquist inventory pattern).
