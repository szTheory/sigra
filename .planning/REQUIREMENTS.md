# Requirements: Sigra v1.45 RELEASE-CURRENCY

**Defined:** 2026-07-10
**Core Value:** Authentication that works out of the box with great DX on the happy path and on the rough edges — so developers can ship SaaS apps fast and grow with confidence.

**Milestone goal:** Get Sigra current and trustworthy on Hex — fix the upgrade-smoke blocker, publish v1.2.0 + v1.3.0, retire the stray 1.20.0, and harden the release lane so a red gate can't silently strand a release again — so adopters can `mix deps.update` and actually receive three milestones (v1.42/43/44) of shipped work.

## v1.45 Requirements (this milestone)

Requirements for the v1.45 RELEASE-CURRENCY milestone. Each maps to exactly one roadmap phase.

### Publish Unblock & Hex Currency (PUB)

- [ ] **PUB-01**: The generated-host `<.button type>` upgrade-smoke warning-as-error is resolved so the `Upgrade smoke (published source → local candidate)` job compiles the upgrade harness clean under `--warnings-as-errors`, taking `ci-gate` green on push-to-`main` (lib + installer template + example in parity; install golden fixture re-blessed).
- [ ] **PUB-02**: Sigra `v1.2.0` is published to Hex.pm (dry-run verified first), keeping the release series contiguous after `v1.1.0`.
- [ ] **PUB-03**: Sigra `v1.3.0` is published to Hex.pm after `v1.2.0`, making the current shipped code (through v1.44) available to adopters.
- [ ] **PUB-04**: The stray Hex `1.20.0` is retired so `latest_stable_version` resolves to the real GA (`1.3.0`). *(Operator-gated: requires interactive Hex write-auth.)*
- [ ] **PUB-05**: A clean adopter resolution is proven — `{:sigra, "~> 1.0"}` / `mix deps.update` resolves to the current published version (`1.3.0`), not the stray `1.20.0` nor the stale `1.1.0`.

### Release-Lane Hardening — no silent rot (HARD)

- [ ] **HARD-01**: The `Upgrade smoke` gate can no longer rot unnoticed — it is made PR-visible (runs/reports on `pull_request`) **or** a red result on `main` raises a loud, discoverable signal (alert/annotation/failing required aggregate) instead of failing silently.
- [ ] **HARD-02**: release-please auto-publish is verified to fire end-to-end when a release is cut on a green `ci-gate` — **or** to fail loudly (not silently) when blocked — with the recovery/manual-dispatch runbook documented.

### Ship-Honest Generated-Host Debt (SHIP)

- [ ] **SHIP-01**: The security-adjacent installer `scope:` omission on `save_passkey_name` (WR-01) is fixed — the generated `mfa_settings_live.ex` passes `scope:` (restoring the library-level impersonation defense-in-depth) and handles the `{:error, :impersonation_forbidden}` clause, mirrored from the example twin, with the install golden fixture re-blessed.
- [ ] **SHIP-02**: The generated-host copy/DX nits are fixed — WR-02 delete-passkey confirmation copy drift (template mirrored to example + golden re-bless) and the `up.sh --help` `--print-env` usage truncation (IN-02).
- [ ] **SHIP-03**: The `app.css` corruption-guard false-negative is fixed — `scripts/ci/app-css-corruption-check.sh` catches an orphaned bare value placed immediately after a `;`-terminated declaration (resets the `last_was_prop` flag), proven by a regression case.

### Release-Currency Proof (PROOF)

- [ ] **PROOF-01**: A release-currency proof bundle records the end state — `ci-gate` green on `main`, Hex `latest_stable_version` = `1.3.0`, adopter `~> 1.0` resolution verified, and full library + example suites green — as the milestone's trust artifact.

## Future Requirements (deferred, tracked — not in this roadmap)

### Config / Installer Features (FEAT — v2 feature milestone)

- **FEAT-01**: Runtime auth-prefix override (`2026-06-20-runtime-auth-prefix-override`).
- **FEAT-02**: `mix sigra.migrate` schema helper (`2026-06-20-mix-sigra-migrate-schema-helper`).
- **FEAT-03**: White-label auth/email theming (`2026-06-22-white-label-auth-email-theming`).

### CI Performance (SEED-005)

- **PERF-01**: Playwright per-shard DB parallelization for the sub-12m fast-path stretch v1.40 did not reach (`example_playwright_smoke` ~22m floor).

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| New auth features / capability work | Maintenance-first / post-1.0 posture — this is a release-hygiene lane, no net-new features |
| Admin/operator UI polish (11th UI pass) | v1.34–v1.44 already elevated + ratcheted the admin UI; polish is not default roadmap |
| Fresh `v1.4.0` cut + GA re-attestation | Not needed to get current — v1.2.0/v1.3.0 already cut; re-attestation overlaps prior GA work |
| CI-perf sub-12m stretch (SEED-005 / PERF-01) | Deferred CI/DX bet, not a currency blocker |
| Config/installer features (FEAT-01/02/03) | Thesis-driven feature milestone, tracked separately as v2 |
| Automating the Hex write-auth steps | `mix hex.retire` / publish dispatch inherently prompt for interactive Hex write-auth; operator-gated by design |

## Traceability

Which phases cover which requirements. Populated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| PUB-01 | TBD | Pending |
| PUB-02 | TBD | Pending |
| PUB-03 | TBD | Pending |
| PUB-04 | TBD | Pending |
| PUB-05 | TBD | Pending |
| HARD-01 | TBD | Pending |
| HARD-02 | TBD | Pending |
| SHIP-01 | TBD | Pending |
| SHIP-02 | TBD | Pending |
| SHIP-03 | TBD | Pending |
| PROOF-01 | TBD | Pending |

**Coverage:**
- v1.45 requirements: 11 total
- Mapped to phases: 0 (roadmap pending)
- Unmapped: 11 ⚠️

---
*Requirements defined: 2026-07-10 after `/gsd-new-milestone` (v1.45 RELEASE-CURRENCY)*
*Last updated: 2026-07-10 after initial definition*
