# Project Retrospective

*Living document updated at milestone boundaries. v1.16 section added at milestone archive (2026-04-24).*

## Milestone: v1.16 — API verify failure audit atomicity

**Shipped:** 2026-04-24  
**Phases:** 1 (79) | **Plans (on-disk):** 0 | **Sessions:** n/a (not instrumented)

### What was built

- **AUD-16-01 / AUD-16-02** — **`verify/2`** invalid / revoked / expired paths emit **`api.token_verify.failure`** inside **`Repo.transaction/1`** with **`Ecto.Multi`** + **`log_multi_safe`** when `:audit_schema` is set.
- **AUD-16-03** — **44** inventory + **09-VERIFICATION** C-1 **044–046** → **T1**; **09-03-SUMMARY** + **`CHANGELOG` [Unreleased]** trace **v1.16** / **79** / **AUD-16**.
- **AUD-16-04** — **D-27** preserved: no success-path **`api.token_verify`** audit rows.
- **`api_token_audit_atomic_test.exs`** — Postgres-backed failure + fault-injection coverage alongside **`api_token_test.exs`**.

### What worked

- **Verification-first single phase** — **`79-VERIFICATION.md`** checklist mapped cleanly to code + docs.
- **`audit-open` all clear** — no deferred artifact debt at close.

### What was inefficient

- **`gsd-sdk query milestone.complete`** not used; manual **`milestones/v1.16-*`** writes (same as **v1.12**–**v1.15**).
- **No on-disk `79-SUMMARY.md`** — closure relied on **VERIFICATION** + requirements traceability (same shape as **v1.15**).

### Patterns established

- **Failure-only API token verify audits** co-fated with the **`{:error, reason}`** return path without widening **D-27** success noise.

### Key lessons

1. Retire **EX-44-01** appendix honesty when code moves **`044–046`** to **T1** — keep appendix row for archaeology.
2. Keep **`log_safe_error`** telemetry explicit when audit insert fails but the caller still gets the domain error.

### Cost observations

- Model mix: n/a  
- Sessions: n/a  
- Notable: Single commit since **`v1.15`** tag; highest leverage was **`api_token.ex`** + one atomic test module + planning matrix rows.

---

## Milestone: v1.15 — Account + API C-1 planning truth

**Shipped:** 2026-04-24  
**Phases:** 1 (78) | **Plans (on-disk):** 0 | **Sessions:** n/a (not instrumented)

### What was built

- **AUD-14-01 / AUD-14-02** — **44-AUD-04-INVENTORY** rows **035–042** and **047** aligned to **`lib/sigra/account.ex`** / **`lib/sigra/api_token.ex`**; hybrid **044–046** and **043** deferrals preserved (**EX-44-01**, **EX-44-05**).
- **AUD-14-03** — **09-VERIFICATION** C-1 table honesty for the same row IDs.
- **AUD-14-04 / AUD-14-05** — **09-03-SUMMARY** bounded-batch note; **CHANGELOG [Unreleased]** trace; **`account_audit_atomicity_test.exs`** **`change_password`** success + CHECK-guard rollback.

### What worked

- **Verification-first single phase** — **`78-VERIFICATION.md`** gave a tight checklist against inventory + matrix + tests.
- **`audit-open` all clear** — no deferred artifact debt at close.

### What was inefficient

- **`gsd-sdk query milestone.complete`** still failed (`version required for phases archive`); manual **`milestones/v1.15-*`** writes repeated the established pattern.
- **No on-disk `78-SUMMARY.md`** — closure relied on **VERIFICATION** + requirements traceability (same shape as other micro-ships).

### Patterns established

- **Planning truth before the next SEED-002 batch** — when code already matched **Multi**, the milestone was mostly honest **C-1** labeling + test evidence.

### Key lessons

1. Keep **EX-44-01** / **EX-44-05** explicit whenever **Account**/**API** rows mix **`log_safe`** and **`log_multi_safe`**.
2. **`change_password`** audit atomicity belongs in **`account_audit_atomicity_test.exs`** alongside **`set_password`** for symmetric confidence.

### Cost observations

- Model mix: n/a  
- Sessions: n/a  
- Notable: Small diff since **`v1.14`** tag; highest leverage was matrix + inventory alignment + one focused test file.

---

## Milestone: v1.14 — Bounded audit trust closure

**Shipped:** 2026-04-24  
**Phases:** 1 (77) | **Plans (on-disk):** 1 | **Sessions:** n/a (not instrumented)

### What was built

- **AUD-13-01 / AUD-13-02** — **`audit_backup_codes_regenerate/3`** and **`audit_trust_browser/2`** routed through **`commit_ad_hoc_mfa_audit/5`** (**`Repo.transaction/1`** + **`Ecto.Multi`** + **`log_multi_safe`**).
- **AUD-13-03** — **`mfa_audit_atomicity_test.exs`** success, audit-disabled no-op, and CHECK-guard rollback coverage on Postgres.
- **AUD-13-04** — **09-VERIFICATION** / **09-03-SUMMARY** / **44-AUD-04-INVENTORY** / **CHANGELOG [Unreleased]** aligned to **T1** for **033**/**034** with **phase 77** pointer.

### What worked

- **Single-phase bounded batch** — closed a discrete **C-1** pair without scope bleed into **Account**/**API** or **SEED-001**.
- **`audit-open` all clear** — no deferred artifact debt at close.

### What was inefficient

- **`gsd-sdk query milestone.complete`** still failed (`version required for phases archive`); manual **`milestones/v1.14-*`** writes repeated the established pattern.
- **No `v1.14-MILESTONE-AUDIT.md`** — optional; honesty gate was **77-VERIFICATION.md** + requirements traceability.

### Patterns established

- **Shared `commit_ad_hoc_mfa_audit/5`** — one helper for ad-hoc MFA audit inserts preserves telemetry parity with legacy **`log_safe/3`** swallowing.

### Key lessons

1. Add an on-disk **`*-SUMMARY.md`** for single-phase ships so milestone close and **MILESTONES** extraction stay uniform (**77-01-SUMMARY** added at archive).
2. Keep **AUD-04-022** explicitly out of hybrid **Multi** batches when there is no durable business row to co-fate (**EX-44-02**).

### Cost observations

- Model mix: n/a  
- Sessions: n/a  
- Notable: Tight **SEED-002** slice; highest leverage was Postgres rollback tests + inventory row honesty.

---

## Milestone: v1.12 — Trust, evidence, and adoption polish

**Shipped:** 2026-04-24  
**Phases:** 3 (73–75) | **Plans (on-disk):** 7 | **Sessions:** n/a (not instrumented)

### What was built

- **AUD-11 (Phase 73)** — Bounded **`mfa.ex`** **`Ecto.Multi`** + **`log_multi_safe`**; **`mfa_audit_atomicity_test.exs`** rollback coverage; inventory / **09-VERIFICATION** row reconciliation.
- **AUD-12 / UAT-01 / UAT-02 (Phase 74)** — **`09-03-SUMMARY.md`** carries post–**73** truth; **`.planning/v1.12-UAT-EVIDENCE.md`**; **`docs/uat-ci-coverage.md`** aligned with evidence story.
- **TRN-01..TRN-03 (Phase 75)** — **`upgrading-to-v1.12.md`** + ExDoc extras; trust bundle on getting-started / **MAINTAINING** / **CHANGELOG**; **`v1.11-TRIAGE.md`** § v1.12 reconciliation + **`75-VERIFICATION.md`**.

### What worked

- **Same tranche shape as v1.9–v1.11** — one code batch + evidence/planning closure + doc polish without scope explosion.
- **`audit-open` all clear** — no deferred artifact debt at close.

### What was inefficient

- **`gsd-sdk query milestone.complete`** still failed; manual **`milestones/v1.12-*`** writes repeated the established pattern.
- **No `v1.12-MILESTONE-AUDIT.md`** — honesty gate was phase **`*-VERIFICATION.md`** + requirements; consider a short audit file next ship if comparing to **v1.10**.

### Patterns established

- **Planning-label evidence file** — **`v1.12-UAT-EVIDENCE.md`** as the single auditable index before a loud launch.

### Key lessons

1. Reconcile **`.planning/REQUIREMENTS.md`** traceability at close so **Pending** rows never lag **`*-VERIFICATION.md` passed** (fixed at archive for **v1.12**).
2. Keep **`roadmap.analyze`** limitations in mind; **ROADMAP + filesystem** remained source of truth.

### Cost observations

- Model mix: n/a  
- Sessions: n/a  
- Notable: Small phase count; highest leverage was evidence packaging + one more bounded **SEED-002** batch.

---

## Milestone: v1.10 — Adopter confidence for solo production

**Shipped:** 2026-04-23  
**Phases:** 3 (68–70) | **Plans (on-disk):** 5 | **Sessions:** n/a (not instrumented)

### What was built

- **ACF-01 / ACF-04 (Phase 68)** — **`guides/recipes/deployment.md`** production checklist hub + mail inline vs Oban TL;DR; cross-links from README, intro guides, **MAINTAINING**, and install flag anchors.
- **ACF-02 / ACF-03 (Phase 69)** — **`intermediate-production-path.md`**, canonical **`generator-options.md`**, ExDoc **Reference** group, **`Mix.Tasks.Sigra.Install`** `@moduledoc` bullet, intro mesh.
- **ACF-05 / ACF-06 (Phase 70)** — **`upgrading-to-v1.10.md`** + ExDoc extras; explicit **ADR 001** / **SEED-002** deferrals in planning surfaces.

### What worked

- **Verification-first closure** — **`068-VERIFICATION.md`** **passed** gave a clean signal for **ACF-01** / **ACF-04** even when live requirement rows briefly lagged.
- **Same-day phases** — three small doc phases shipped without scope creep into new auth primitives.

### What was inefficient

- **`gsd-sdk query milestone.complete`** unavailable; manual archival repeated the **v1.3**–**v1.9** pattern.
- **`roadmap.analyze`** empty JSON for this roadmap shape; relied on filesystem + **VERIFICATION** artifacts.

### Patterns established

- **Planning-label upgrade stubs** — **`upgrading-to-v1.x.md`** files disambiguate GSD / planning milestones from Hex SemVer for adopters.

### Key lessons

1. Reconcile **`.planning/REQUIREMENTS.md`** traceability at ship so **Pending** rows never contradict **`*-VERIFICATION.md` passed**.
2. Keep **adopter-confidence** milestones doc-only but still milestone-audited when the prior ship window used the same honesty gate.

### Cost observations

- Model mix: n/a  
- Sessions: n/a  
- Notable: **28** commits since **`v1.9`** tag on the measured range; **47** files in **`git diff --stat v1.9..HEAD`** summary.

---

## Milestone: v1.9 — Audit atomicity (bounded SEED-002)

**Shipped:** 2026-04-23  
**Phases:** 2 (66–67) | **Plans (on-disk):** 3 | **Sessions:** n/a (not instrumented)

### What was built

- **AUD-09 (Phase 66)** — **`confirm_enrollment/5`** **AUD-04-020..021** on **`Ecto.Multi`** with **`log_multi_safe`**; **`mfa_audit_atomicity_test.exs`** for success + rollback/failure signals.
- **AUD-10 (Phase 67)** — **`09-03-SUMMARY.md`** post–phase-66 narrative; **D-06** inventory cross-check; explicit **no `09-VERIFICATION.md` edit** where rows already matched intent.

### What worked

- **Mirror v1.7 pattern** — one bounded code batch plus honest planning closure closed the milestone without boiling the ocean.
- **Merge-gated audit tests** — kept **T1** semantics provable in CI for the touched subsystem.

### What was inefficient

- **`gsd-sdk query milestone.complete`** failed again; manual archival repeated the v1.3–v1.8 pattern.
- **`roadmap.analyze`** returned empty JSON for this roadmap shape; closure relied on **REQUIREMENTS.md** + on-disk **`*-SUMMARY.md`** checks.

### Patterns established

- **Failure-path `Multi`** for enrollment audit parity with success-path co-fated writes where **C-1** demands it.

### Key lessons

1. Keep **bounded SEED-002** milestones to **one production batch + one planning closure** per ship window when possible.
2. File a short **milestone audit** at close when prior milestones used the same honesty gate.

### Cost observations

- Model mix: n/a  
- Sessions: n/a  
- Notable: Very small phase count; highest leverage was MFA audit atomicity + **C-1** narrative alignment.

---

## Milestone: v1.8 — Adopter polish (diminishing returns)

**Shipped:** 2026-04-23  
**Phases:** 3 (63–65) | **Plans (on-disk):** 0 | **Sessions:** n/a (not instrumented)

### What was built

- **ADOPT-04 (Phase 63)** — **`upgrading-to-v1.8.md`** with honest **planning vs SemVer** framing, **`mix.exs`** extras ordering, and pointers back to **v1.7** maintainer context.
- **ADOPT-05 (Phase 64)** — Cross-links so **getting-started → first-hour → troubleshooting → upgrades** reads as one mesh.
- **INTG-02 (Phase 65)** — **`companion-oauth-provider.md`** prerequisites, explicit **B2C-only / no third-party API clients** anti-pattern, and **See also** navigation to **v1.8** upgrades.

### What worked

- **Doc-only milestone with full traceability** — three requirements mapped to three phases without inventing fake execution packs.
- **Small diff, high leverage** — most churn was prose + navigation, not security-sensitive code paths.

### What was inefficient

- **`gsd-sdk query milestone.complete`** failed again; manual archival repeated the v1.3–v1.7 pattern.
- **No `063-*` / `064-*` / `065-*` phase directories** — harder to grep execution history; prefer lightweight doc phase dirs if Nyquist strictness matters later.

### Patterns established

- **Upgrade guide per planning focus** — when “v1.x” is planning language, ship a dedicated upgrade page that does not pretend SemVer is the same thing.

### Key lessons

1. Ship **adopter polish** milestones with the same **REQUIREMENTS.md** traceability discipline as code-heavy milestones.
2. When **`roadmap.analyze`** returns empty JSON for this roadmap shape, rely on **`.planning/REQUIREMENTS.md`** + filesystem checks before close.

### Cost observations

- Model mix: n/a  
- Sessions: n/a  
- Notable: Single-day closure; git range since **`v1.7`** was intentionally tiny.

---

## Milestone: v1.7 — Adoption readiness & audit durability

**Shipped:** 2026-04-23  
**Phases:** 3 (60–62) | **Plans (with on-disk summaries):** 3 (**061**–**062**) | **Sessions:** n/a (not instrumented)

### What was built

- **ADOPT / INTG (Phase 60)** — First-hour, upgrade, troubleshooting guides plus **`companion-oauth-provider`** recipe with explicit non-coupling (no IdP in Sigra core).
- **AUD-01 (Phase 61)** — `verify_backup/4` failure path on **`Ecto.Multi`** with **`mfa_audit_atomicity_test.exs`**; **AUD-04-067** + C-1 / inventory alignment.
- **AUD-02 (Phase 62)** — **`09-03-SUMMARY.md`** carries honest post-batch narrative; **D-06** confirmed **`09-VERIFICATION.md`** unchanged.

### What worked

- **Tiny code + heavy truth** — one subsystem batch plus doc alignment closed a real audit durability gap without boiling the ocean.
- **D-06 discipline** — avoided churning verification files when the matrix already matched the summary.

### What was inefficient

- **`gsd-sdk query milestone.complete`** failed again; manual archival repeated v1.3–v1.6 toil.
- **No `060-*` phase directory** — Phase **60** is harder to grep as execution history; prefer creating doc phases on disk up front.

### Patterns established

- **Document status blocks** on planning-facing audit summaries for time-bounded narrative patches.
- **Companion recipe** as architecture doc, not a new core dependency surface.

### Key lessons

1. Ship **adoption** milestones with the same traceability table discipline as code milestones — even when most work is prose.
2. When **`roadmap.analyze`** returns empty for this roadmap shape, rely on **`REQUIREMENTS.md`** + filesystem checks before close.

### Cost observations

- Model mix: n/a  
- Sessions: n/a  
- Notable: Very small product diff; highest leverage was MFA audit atomicity + C-1 honesty.

---

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
- Milestone audit file landed **after** the **`v1.6`** tag (retroactive **`v1.6-MILESTONE-AUDIT.md`**); prefer **`/gsd-audit-milestone`** pre-close next time so the tag and audit commit align.

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
| v1.16 | n/a | 1 | **`APIToken.verify/2`** failure **`api.token_verify.failure`** → **`Multi` + `log_multi_safe`** + **`api_token_audit_atomic_test.exs`** (**044–046** **T1**) |
| v1.14 | n/a | 1 | MFA ad-hoc **`log_safe`** closure (**033**/**034**) → **`Multi` + `log_multi_safe`** + **`mfa_audit_atomicity_test.exs`** |
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
