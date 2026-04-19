# Requirements — v1.3 Cleanup & Hardening

Milestone focus: **close deferred validation, supply-chain, human UAT, audit completeness, and tooling gaps** — no new user-facing product features.

Traceability: each REQ maps to exactly one phase in `.planning/ROADMAP.md` (v1.3 section).

---

## Verification & documentation debt

- [x] **VAL-01**: Inventory phase directories under `.planning/phases/` that lack an acceptable `*-VALIDATION.md` (draft, missing, or superseded) per the **999.1** Nyquist retro scope.
- [x] **VAL-02**: For each gap, either (a) bring the artifact to a Nyquist-compliant state, or (b) record an explicit **waived** decision with owner, date, and pointer to superseding verification (no silent gaps).
- [x] **VAL-03**: Update this file’s traceability table when VAL items close so the milestone audit can prove coverage.

**Phase 36 artifacts (traceability / VAL-03):**

- [36-INVENTORY.md](.planning/phases/36-retroactive-nyquist-validation/36-INVENTORY.md) — directory × `*-VALIDATION.md` classification (VAL-01).
- [36-WAIVERS.md](.planning/phases/36-retroactive-nyquist-validation/36-WAIVERS.md) — explicit waivers for draft-status historical phases (VAL-02b).

**Phase:** 36

---

## CI & supply-chain hygiene

- [x] **CI-01**: Triage open **Dependabot** / Actions upgrade PRs called out in **999.2** (e.g. `setup-node`, `upload-artifact`, `checkout` majors behind SHA-pinned equivalents).
- [x] **CI-02**: For each adopted bump, run or observe **full CI** (library + example + install + Playwright lanes relevant to touched workflows) and retain green main before merging.
- [x] **CI-03**: Document any pins that must stay behind upstream (with reason and revisit trigger) in `.planning/` or `CONTRIBUTING.md` as appropriate.

**Phase:** 37

---

## Human GA gate (SEED-001)

- [x] **UAT-01**: Close each **SEED-001** row with **Executed**, **Waived**, or **Blocked** (per `.planning/v1.3-HUMAN-UAT.md` / phase 38 plan). **Machine path:** merge-blocking coverage in **`docs/uat-ci-coverage.md`** (ExUnit mail HTML, `install_smoke` → `mix sigra.gen.oauth`, OAuth/OIDC library contracts, Playwright `ga-uat-shift-left.spec.ts`, `getting_started_contract` job) satisfies the **non-residual** intent for most rows — link workflow run URLs + SHA in `INDEX.md` when using CI-as-evidence. **Residual path:** real mail clients, live Google OAuth UX, clean-machine wall-clock, and backup-code **rotation** proof until `mfa_regenerate_backup_codes` ships — human or waiver with compensation per D-38.
- [x] **UAT-02**: Consolidate outcomes into a single milestone-visible artifact (appendix to milestone audit or new `v1.3-HUMAN-UAT.md`) so GA posture is defensible without tribal knowledge. **Machine path:** the artifact + `INDEX.md` may reference **`docs/uat-ci-coverage.md`** and CI job names as the canonical map from SEED rows to automation.

**Phase:** 38

---

## Audit trail completeness (SEED-002 / Phase 9 C-1)

- [x] **AUD-01**: **Implemented** — `Sigra.Audit.Assertions` (`lib/sigra/audit/assertions.ex`) provides plain-function `latest_audit_event/3` and `assert_audit_fields/3` with explicit `repo`, plus `guides/recipes/testing.md` coverage for Sandbox / ordering.
- [x] **AUD-02**: **Implemented (v1.3 scope)** — `Sigra.APIToken.do_create/4` uses `Ecto.Multi` + `Sigra.Audit.log_multi_safe/3` + `emit_telemetry_from_changes/1` for atomic `api.token_create` when `audit_schema` is configured; Postgres-backed proof in `test/sigra/api_token_audit_atomic_test.exs`.
- [x] **AUD-03**: **Implemented** — example-app smoke asserts `auth.login.success` / `auth.login.failure` (`register_login_logout_test.exs`) and `mfa.enroll.success` (`mfa_totp_test.exs` via `mfa_confirm_enrollment`); **OAuth** path not claimed (no OAuth smoke assertion in this milestone).

**Phase:** 39

---

## Tooling & release ergonomics

- [x] **TOOL-01**: Fix or formally **deprecate** `gsd-tools audit-open --json` (per `PROJECT.md` known limitation); if deprecated, document the supported path and remove broken references from scripts/docs.
- [x] **REL-01**: Add a **maintainer checklist** for Hex + GitHub release (optional: sample workflow snippet showing `HEX_API_KEY` only in an explicit publish job, not assumed by compile/test CI).

**Phase:** 40

---

## Future (explicitly not v1.3)

_Deferred product work stays out of this milestone; reopen under a later `/gsd-new-milestone` when scope changes._

---

## Out of scope (v1.3)

- New auth features, new installer features, new admin surfaces, or net-new public APIs.
- Greenfield research spikes unless they unblock a requirement above.

---

## Traceability (REQ → Phase)

| REQ ID   | Phase |
|----------|-------|
| VAL-01–03 | 36 |
| CI-01–03  | 37 |
| UAT-01–02 | 38 |
| AUD-01–03 | 39 |
| TOOL-01, REL-01 | 40 |
