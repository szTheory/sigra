---
phase: 147
slug: upgrade-and-migration-lanes
status: verified
threats_open: 0
asvs_level: 1
created: 2026-05-31
---

# Phase 147 - Security

Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| published Hex latest `0.3.x` -> tmp consumer app | Untrusted dependency resolution and generated app output cross into the proof harness. | Package metadata, generated code, migration/runtime behavior |
| tmp consumer app -> local candidate source | Upgrade proof must not assume fresh-install equivalence. | Local source dependency replacement, generated host changes |
| CI job -> release evidence | CI lane names and logs become release-decision evidence. | Job identity, run logs, pass/fail state |
| public docs -> adopter decisions | Users may change auth/session/token posture based on guide wording. | Migration instructions, risk framing, ownership boundaries |
| migration comparisons -> host implementation | Overstated equivalence could cause unsafe cutovers or misplaced ownership assumptions. | Auth/session/token/OAuth model mapping |
| README / CHANGELOG / HexDocs / AI index -> adopters | Discovery surfaces determine which docs users and AI systems treat as canonical. | Links, guide labels, release notes, AI index entries |
| source docs -> published extras | Missing ExDoc entries would hide the migration lanes from real users. | ExDoc extras and guide grouping |
| CI/release proof docs -> maintainer release decisions | Missing or overstated evidence rows could let release decisions rely on the wrong proof surface. | Release gate names, evidence checklist rows |
| migration guide publication -> evaluator trust | Readers may treat evidence-router links as claims of full migration equivalence if residual boundaries are vague. | Evidence router links, residual review wording |

---

## Threat Register

| Threat ID | Category | Component | Disposition | Mitigation | Status |
|-----------|----------|-----------|-------------|------------|--------|
| T-147-01 | Tampering | `scripts/ci/upgrade-smoke.sh` | mitigate | Script validates `SIGRA_UPGRADE_SOURCE_SERIES`, resolves the latest published matching Hex release, validates explicit overrides against both series and published Hex truth, logs the selected source, and switches the same tmp app to local source. Evidence: `scripts/ci/upgrade-smoke.sh:23`, `scripts/ci/upgrade-smoke.sh:38`, `scripts/ci/upgrade-smoke.sh:54`, `scripts/ci/upgrade-smoke.sh:71`, `scripts/ci/upgrade-smoke.sh:124`. | closed |
| T-147-02 | Repudiation | `.github/workflows/ci.yml` `upgrade_smoke` job | mitigate | CI has a distinct `upgrade_smoke` job name and release evidence docs require the named gate and run evidence. Evidence: `.github/workflows/ci.yml:347`, `docs/release-runbook-v1-0.md:13`, `docs/release-runbook-v1-0.md:35`. | closed |
| T-147-03 | Denial of service | tmp app boot/migration path | mitigate | Upgrade smoke proves published posture compile/migrate, then candidate compile/migrate and route boot check. Evidence: `scripts/ci/upgrade-smoke.sh:114`, `scripts/ci/upgrade-smoke.sh:149`, `scripts/ci/upgrade-smoke.sh:158`, `scripts/ci/upgrade-smoke.sh:163`. | closed |
| T-147-04 | Tampering | `guides/introduction/upgrading-to-v1.0.md` | mitigate | Upgrade guide includes exact commands, generated-file review, migration/schema impact, verification commands, no drop-in promise, and rollback notes. Evidence: `guides/introduction/upgrading-to-v1.0.md:29`, `guides/introduction/upgrading-to-v1.0.md:43`, `guides/introduction/upgrading-to-v1.0.md:55`, `guides/introduction/upgrading-to-v1.0.md:74`, `guides/introduction/upgrading-to-v1.0.md:96`. | closed |
| T-147-05 | Elevation of privilege | `guides/introduction/migrating-from-phx-gen-auth.md` | mitigate | Migration lane states non-drop-in/non-automated posture, includes `Who should not migrate yet`, and maps `current_scope`, sessions, tokens, magic links, sudo mode, generated-host review, and rollback. Evidence: `guides/introduction/migrating-from-phx-gen-auth.md:3`, `guides/introduction/migrating-from-phx-gen-auth.md:14`, `guides/introduction/migrating-from-phx-gen-auth.md:25`, `guides/introduction/migrating-from-phx-gen-auth.md:46`, `guides/introduction/migrating-from-phx-gen-auth.md:55`. | closed |
| T-147-06 | Elevation of privilege | `guides/introduction/migrating-from-pow-guardian-ueberauth.md` | mitigate | Migration lane separates Pow, Guardian, and Ueberauth boundaries, includes cutover patterns, non-goals, generated-host review, and rollback. Evidence: `guides/introduction/migrating-from-pow-guardian-ueberauth.md:3`, `guides/introduction/migrating-from-pow-guardian-ueberauth.md:26`, `guides/introduction/migrating-from-pow-guardian-ueberauth.md:38`, `guides/introduction/migrating-from-pow-guardian-ueberauth.md:53`, `guides/introduction/migrating-from-pow-guardian-ueberauth.md:61`, `guides/introduction/migrating-from-pow-guardian-ueberauth.md:71`. | closed |
| T-147-07 | Repudiation | `README.md` and `CHANGELOG.md` | mitigate | README has upgrade and migration routing rows; CHANGELOG has documentation bullets for the canonical v1.0 upgrade and migration guides. Evidence: `README.md:148`, `README.md:149`, `CHANGELOG.md:38`, `CHANGELOG.md:39`, `CHANGELOG.md:40`. | closed |
| T-147-08 | Information disclosure | `doc/llms.txt` | mitigate | AI index points to the same canonical guide filenames emitted for ExDoc. Evidence: `doc/llms.txt:25`, `doc/llms.txt:27`, `doc/llms.txt:28`. | closed |
| T-147-09 | Tampering | `mix.exs` docs extras | mitigate | ExDoc extras include all new upgrade/migration guides under the existing Introduction grouping. Evidence: `mix.exs:205`, `mix.exs:207`, `mix.exs:208`, `mix.exs:239`. | closed |
| T-147-10 | Repudiation | `docs/release-runbook-v1-0.md` | mitigate | Release runbook includes named `upgrade_smoke` gate and checklist row with required release evidence. Evidence: `docs/release-runbook-v1-0.md:13`, `docs/release-runbook-v1-0.md:35`. | closed |
| T-147-11 | Elevation of privilege | `docs/uat-ci-coverage.md` | mitigate | UAT/CI coverage separates machine-closed upgrade proof from published-doc truths and limits residual migration review to editorial judgment, not executable equivalence certification. Evidence: `docs/uat-ci-coverage.md:77`, `docs/uat-ci-coverage.md:78`, `docs/uat-ci-coverage.md:82`. | closed |
| T-147-12 | Tampering | `docs/ga-evidence.md` | mitigate | GA evidence stays router-only, links canonical guide pages, and points to the canonical `upgrade_smoke` proof instead of duplicating release claims. Evidence: `docs/ga-evidence.md:12`, `docs/ga-evidence.md:14`, `docs/ga-evidence.md:17`. | closed |
| T-147-SC | Tampering | package/dependency resolution | accept | Repeated plan-time accepted risk: Phase 147 introduced no new npm/pip/cargo packages and reused existing Elixir/Phoenix toolchain and docs surfaces. | closed |

*Status: open or closed.*
*Disposition: mitigate (implementation required), accept (documented risk), transfer (third-party).*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| R-147-01 | T-147-SC | The repeated supply-chain threat was accepted at plan time because Phase 147 did not add new npm, pip, or cargo packages; the work reused existing Elixir/Phoenix tooling and documentation surfaces. | Plan-time threat model | 2026-05-31 |

Accepted risks do not resurface in future audit runs.

---

## Security Audit 2026-05-31

| Metric | Count |
|--------|-------|
| Threats found | 13 |
| Closed | 13 |
| Open | 0 |

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-05-31 | 13 | 13 | 0 | Codex |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-05-31
