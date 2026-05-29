# Requirements: Sigra — v1.30 TRUST-HARDENING

**Defined:** 2026-05-28
**Milestone:** v1.30 TRUST-HARDENING (Operator Confidence & Debt Closure)
**Core Value:** Authentication that works out of the box with great DX on the happy path AND on the rough edges — so developers can ship SaaS apps fast and grow with confidence.

**Milestone goal:** Turn Sigra's accumulated maturity into legible operator trust — ship the long-promised `mix sigra.doctor` diagnostic, consolidate optional-dependency handling into one source of truth, lock companion-recipe contracts against drift, and resolve standing API-coherence debt — without crossing the Diminishing Returns Wall. Phases continue from **Phase 137**.

## v1 Requirements

Requirements for the v1.30 milestone. Each maps to exactly one roadmap phase.

### Optional-Dependency Source of Truth

- [ ] **OD-01**: A `Sigra.OptionalDeps` module exposes a per-dependency `available?/0` (or equivalent) for every optional dependency Sigra guards today (Oban, Bcrypt, EQRCode, Threadline, Assent, Swoosh, Joken, cloak/encryption), as a single canonical source of truth.
- [ ] **OD-02**: The scattered `Code.ensure_loaded?` guards across library call sites delegate to `Sigra.OptionalDeps`, with no runtime behavior change — proven by the existing dep-off CI lanes staying green.

### Operator Diagnostics

- [x] **DR-01**: `mix sigra.doctor` reports a per-feature optional-dependency matrix (loaded / available / configured-but-missing / missing) with actionable remediation hints for each row.
- [x] **DR-02**: `mix sigra.doctor` validates boot-time wiring for configured features (e.g. audit forwarder, async email/audit workers, encryption vault) and exits non-zero when a configured feature is misconfigured.

### Recipe Contract Integrity

- [ ] **RCT-01**: A merge-blocking test fixture asserts every companion-lib recipe under `guides/recipes/companion-libs/` carries its required sections ("Failure modes", "Non-goals", "Sigra works fully standalone" banner) and `validated_against:`/`last_validated:` frontmatter, so recipe docs cannot silently drift.
- [ ] **RCV-01**: The Lockspire `resolve_account/2` return-shape contract is verified against the sister repo where it resolves, otherwise the assumed contract is documented explicitly in the recipe and the tracked todo is updated honestly.
- [ ] **RCV-02**: The Rulestead policy `@behaviour` contract is verified against the sister repo where it resolves, otherwise documented explicitly in the recipe and the tracked todo.

### Deprecation Hygiene

- [ ] **DEPR-01**: `Sigra.Account.audit_forced_password_change/2` carries a documented removal target version and migration note (resolving the open-ended `@deprecated` with no timeline).
- [ ] **DEPR-02**: `Sigra.MFA.Trust.cookie_opts/0` carries a documented removal target version and migration note.

### Verification & Docs

- [ ] **PROOF-01**: Full test suite + dep-off CI lane + `mix docs --warnings-as-errors` all green; `mix sigra.doctor` exercised against the `test/example/` app; per-phase verification artifacts filed.
- [ ] **DOC-01**: Guides/docs updated — `mix sigra.doctor` usage, a `Sigra.OptionalDeps` maintainer note, the deprecation-removal-timeline notes, and a recipe-contract-testing note.

## Future Requirements

Acknowledged but deferred; not in the v1.30 roadmap. Promotion requires a roadmap update.

### Enterprise

- **SCIM-01**: SCIM 2.0 directory provisioning (IdP → Sigra user/group lifecycle). Trigger (ENT-SSO login+JIT wedge) has fired; ranked the strongest greenfield candidate for v1.31.

### Observability

- **CORR-01**: Threadline correlation-ID propagation through `Sigra.Audit.Forwarders.Threadline`. Blocked on a stable Threadline correlation-ID injection seam.

### Suite Glue

- **GLUE-01**: `sigra_lockspire` optional glue package (ADR 001). Blocked until both libraries stabilize and a real companion-app trigger fires; recipe-only posture stands until then.

## Out of Scope

Explicitly excluded for v1.30. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Clearing the ~506 credo `--strict` advisory issues | Non-CI-enforced, pre-existing, low-value churn. Keep the "no new strict regressions" posture instead; the 2 custom enforced checks already pass. |
| SCIM / full directory sync | Greenfield enterprise primitive; ranked v1.31+. v1.30 deepens shipped substrate, not new wedges. |
| Threadline correlation-ID propagation | Blocked on a stable upstream Threadline seam. |
| `sigra_lockspire` glue package | ADR 001 triggers (both libraries stable + real companion-app + CI reference app) have not fired. |
| Re-landing the orphaned Phase 111/114 Mailglass adapter | Closed decision — recipe-only host-owned wiring is the supported posture (v1.29 DOC-01 corrigendum). |
| Converting remaining `log_safe/3` sites to atomic `Ecto.Multi` (SEED-002) | Trigger (customer-reported missing row OR scheduled subsystem test conversion) has not fired. |
| Any runtime behavior change in optional-dep handling | OD-01/OD-02 are a refactor + single-source-of-truth consolidation only — semantics must be preserved. |

## Traceability

Which phases cover which requirements. Populated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| OD-01 | Phase 137 | Pending |
| OD-02 | Phase 137 | Pending |
| DR-01 | Phase 138 | Complete |
| DR-02 | Phase 138 | Complete |
| RCT-01 | Phase 139 | Pending |
| RCV-01 | Phase 139 | Pending |
| RCV-02 | Phase 139 | Pending |
| DEPR-01 | Phase 140 | Pending |
| DEPR-02 | Phase 140 | Pending |
| PROOF-01 | Phase 140 | Pending |
| DOC-01 | Phase 140 | Pending |

**Coverage:**
- v1 requirements: 11 total
- Mapped to phases: 11 ✓ (Phases 137–140)
- Unmapped: 0

---
*Requirements defined: 2026-05-28*
*Last updated: 2026-05-28 after roadmap creation (v1.30 TRUST-HARDENING; Phases 137–140 mapped)*
