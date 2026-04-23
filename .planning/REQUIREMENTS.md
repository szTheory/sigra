# Requirements: Sigra v1.10

**Defined:** 2026-04-23  
**Core value (from PROJECT.md):** Authentication that works out of the box with great DX on the happy path **and** on the rough edges — including a **credible solo production path** from install through intermediate real-host usage.

**Milestone framing:** **Adopter confidence for solo production** — shorten the gap between “golden path in dev” and “my production Phoenix host behaves predictably with Sigra,” using the assumed bundle in [`.planning/v1.10-ADOPTER-SCOPE.md`](v1.10-ADOPTER-SCOPE.md). **SemVer:** planning label **v1.10** (library Hex version remains on its own cadence). **Research:** skipped — see [`.planning/v1.10-RESEARCH-DECISION.md`](v1.10-RESEARCH-DECISION.md).

---

## Adopter confidence (ACF)

### Production host and mail

- [ ] **ACF-01**: Maintainer-facing documentation (guide and/or `MAINTAINING.md` section) gives a **checklist** for HTTPS, reverse-proxy, and **session cookie** settings (`Secure`, `SameSite`, host/scheme) for Sigra session plugs on a public Phoenix deployment.

- [ ] **ACF-04**: Maintainer-facing documentation explains **Oban-backed vs inline** Swoosh delivery for production, with pointers to install flags and the example app’s chosen default, so hosts do not discover mail semantics only under load.

### Intermediate journey and optional features

- [ ] **ACF-02**: A single documented **intermediate dogfood path** (install → email confirmation → session login → at least one sensitive flow such as password change or MFA enrollment) states which generator options are assumed; it links to **`.planning/v1.10-ADOPTER-SCOPE.md`** for customization.

- [ ] **ACF-03**: A single **index** (new or existing intro doc) summarizes **generator optional features** (`--no-admin`, `--no-organizations`, `--no-passkeys`, API/JWT flags) and links from **getting-started** / **first-hour** so intermediate hosts do not reverse-engineer the matrix from scattered guides.

### Release boundary and explicit non-goals

- [ ] **ACF-05**: **`guides/introduction/upgrading-to-v1.10.md`** exists, is listed in ExDoc extras after **`upgrading-to-v1.8.md`**, and explains planning **v1.10** vs Hex SemVer / pin expectations for adopters coming from **v1.9** (and pointers back to **v1.8** / **v1.7** upgrade pages as needed).

- [ ] **ACF-06**: **`REQUIREMENTS.md`** Out of Scope table (below) and **`PROJECT.md`** Current Milestone section explicitly defer **`sigra_lockspire`** / mandatory Lockspire coupling and **full SEED-002** conversion, with pointers to [`.planning/decisions/001-defer-sigra-lockspire-glue-package.md`](decisions/001-defer-sigra-lockspire-glue-package.md) and [`.planning/seeds/SEED-002-phase-9-log-safe-atomicity-followup.md`](seeds/SEED-002-phase-9-log-safe-atomicity-followup.md). **ACF-06** is satisfied when those cross-links are present and accurate at milestone close.

---

## Future (not v1.10)

- **SEED-001** human GA matrix — schedule with a **public launch** milestone, not adopter-confidence.
- Further **bounded SEED-002** batches — when a subsystem you ship touches hybrid `log_safe/3` sites or compliance triggers fire.
- Optional **`sigra_lockspire`** package — per ADR **001** revisit triggers (Lockspire release maturity, stable `AccountResolver`, public reference app under CI).

---

## Out of scope (v1.10)

| Item | Reason |
|------|--------|
| **`sigra_lockspire` / Lockspire glue package** | ADR **001** — separate packages; host-generated seams only until Lockspire **Phase 6** + stable APIs + reference CI. |
| **Full SEED-002** hybrid → `Multi` conversion | Large blast radius; not required for intermediate production confidence. |
| **SEED-001** loud-launch human matrix | Marketing / GA milestone, not solo dogfood. |
| **Net-new auth features** | Out of scope unless a doc task discovers a **bug-level** gap opened as a separate tracked item. |

---

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| ACF-01 | 68 | Pending |
| ACF-04 | 68 | Pending |
| ACF-02 | 69 | Pending |
| ACF-03 | 69 | Pending |
| ACF-05 | 70 | Pending |
| ACF-06 | 70 | Pending |

**Coverage:** v1.10 requirements **6** total · mapped **6** · unmapped **0**

---

*Requirements defined: 2026-04-23 after `/gsd-new-milestone` (v1.10 Adopter confidence).*
