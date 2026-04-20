# Project Retrospective

*Living document updated at milestone boundaries. v1.3 section added at ship (2026-04-19).*

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
| v1.3 | n/a | 5 | Shift-left UAT + explicit planning archive at close |

### Cumulative quality

| Milestone | Tests | Coverage | Zero-dep additions |
|-----------|-------|----------|---------------------|
| v1.3 | Library + example suites extended via new audit tests / smoke | n/a | Optional workflow snippets only |

### Top lessons (verified across milestones)

1. **Automation-first verification** pays off again (v1.0 Playwright → v1.2 harness → v1.3 GA shift-left).
2. **Explicit waivers beat implicit debt** for planning artifacts (Nyquist inventory pattern).
