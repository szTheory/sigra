# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Planning milestones vs Hex releases

This changelog uses **[Semantic Versioning](https://semver.org/spec/v2.0.0.html)** headings like **`[0.2.0]`** for **published Hex releases**. Separately, maintainers track **planning milestones** labeled **v1.0–v1.4** in **`.planning/MILESTONES.md`** — those **v1.x** labels describe shipped *tranches* of work, **not** a second installable version axis on Hex (this repo remains **0.x** on Hex until a real **1.0.0**). Each dated release below may include a **Roadmap traceability** subsection (H3) linking back to the milestone narrative. When in doubt, treat **`MILESTONES.md`** as canonical for dates and archive paths.

## [0.3.0](https://github.com/szTheory/sigra/compare/v0.2.5...v0.3.0) (2026-05-25)

### Added

* **passkeys:** Added `Sigra.Passkeys.delete_with_posture/4` and `Sigra.Passkeys.DeleteResult` so hosts can distinguish ordinary passkey deletion from last-passkey recovery posture without re-querying state.

### Changed

* **passkeys:** Generated-host settings and controller flows now encode passkey credential IDs in forms and routes, decode them on the server side, and surface clearer last-passkey deletion guidance after the delete completes.
* **auth:** Confirmation-link issuance now stores the hash of the transported confirmation token string, so `confirm_user/3` can successfully look up valid emailed confirmation links after HMAC verification.
* **passkeys:** Generated confirmation and MFA recovery flows now redirect and message users more honestly when bootstrapping a first passkey or recovering from a canceled, timed-out, or unsupported browser ceremony.

### Fixed

* **generator:** `--no-passkeys` installs no longer leak passkey bootstrap helpers or warning-cleanliness regressions into generated apps.
* **ci:** Release-gate coverage and generator fixtures now align with the encoded passkey-id and delete-posture behavior shipped in the library and templates.

### Roadmap traceability

* Planning milestone **v1.26 PK-LIFECYCLE** (phases **115–121**) shipped on **2026-05-25**; see [`.planning/milestones/v1.26-ROADMAP.md`](https://github.com/szTheory/sigra/blob/main/.planning/milestones/v1.26-ROADMAP.md), [`.planning/milestones/v1.26-REQUIREMENTS.md`](https://github.com/szTheory/sigra/blob/main/.planning/milestones/v1.26-REQUIREMENTS.md), and [`.planning/milestones/v1.26-MILESTONE-AUDIT.md`](https://github.com/szTheory/sigra/blob/main/.planning/milestones/v1.26-MILESTONE-AUDIT.md).

## [Unreleased]

### Documentation

- **Mailglass integration posture (v1.29 DOC-01):** Sigra ships no library-resident Mailglass adapter and no `--with-mailglass` installer flag. The supported integration posture is recipe-only host-owned wiring: the host implements `Sigra.Mailer` and delegates to a Mailglass-backed module. See `guides/recipes/companion-libs/mailglass.md` for the current supported configuration.

## [0.2.5](https://github.com/szTheory/sigra/compare/v0.2.4...v0.2.5) (2026-04-25)

### Changed

* **mfa:** When `:audit_schema` is configured, `Sigra.MFA.confirm_enrollment/5` writes `mfa.enroll.failure` for invalid TOTP (pre-enrollment DB work) inside `Repo.transaction/1` via `Ecto.Multi` + `Sigra.Audit.log_multi_safe/3`, using the same `commit_ad_hoc_mfa_audit/5` shell as other MFA ad-hoc audits (**AUD-20-01** / **AUD-04-022**). The caller still receives `{:error, :invalid_code}` regardless of audit insert outcome; audit failures emit `[:sigra, :audit, :log_safe_error]`. Evidence: `test/sigra/mfa_audit_atomicity_test.exs`.
* **jwt:** When `:audit_schema` is configured, `Sigra.JWT.refresh/3` (and `Sigra.Auth.refresh_jwt/2`) runs refresh-token **`user_tokens`** persistence and `api.jwt_refresh` / `api.jwt_refresh_reuse` audit inserts in a single `Repo.transaction/1` via `Ecto.Multi` + `Sigra.Audit.log_multi_safe/3` (persistence + audit co-fate / **AUD-08** for the guided path). Any step failure in that transaction returns `{:error, :jwt_refresh_aborted}` instead of issuing new tokens without a matching audit row. Evidence: `test/sigra/jwt_refresh_audit_cofate_test.exs`.
* **jwt:** Refresh-token classify/revoke paths now base64url-decode the raw refresh token before hashing, so malformed or non-decodable inputs return `{:error, :invalid_token}` instead of hashing the encoded wrapper bytes.
* **audit:** When `:audit_schema` is configured, `Sigra.APIToken.audit_jwt_refresh/2` and `audit_jwt_refresh_reuse/2` write `api.jwt_refresh` / `api.jwt_refresh_reuse` inside `Repo.transaction/1` via audit-only `Ecto.Multi` + `Sigra.Audit.log_multi_safe/3` (audit-row atomicity only — standalone helpers; prefer `JWT.refresh/3` for co-fate so audit is not double-emitted).
* **audit:** When `:audit_schema` is configured, `Sigra.Account.clear_password_change_requirement/3` clears `must_change_password` and writes `account.password_change` (`metadata: %{forced: true}`) in one `Repo.transaction/1` via `Ecto.Multi` + `Sigra.Audit.log_multi_safe/3`. `Sigra.Account.audit_forced_password_change/2` is deprecated for that path — do not call both or you may duplicate audit rows.
* **audit:** When `:audit_schema` is configured, `Sigra.APIToken.verify/2` now writes `api.token_verify.failure` audit rows inside `Repo.transaction/1` via `Ecto.Multi` + `Sigra.Audit.log_multi_safe/3` (invalid, revoked, and expired branches). Success remains telemetry-only (**D-27**). Insert failures emit `[:sigra, :audit, :log_safe_error]` (`:invalid_changeset` or `:constraint_violation`) while the caller still receives `{:error, reason}`.

### Documentation

* **planning:** Milestone **v1.19** (phase **83**, **AUD-20**) — **AUD-04-022** + **EX-44-02** appendix, **09-VERIFICATION** C-1 row **022**, **09-03-SUMMARY**, **44-AUD-04-INVENTORY** for **`Sigra.MFA.confirm_enrollment/5`** invalid-code transactional audit. See [`.planning/phases/83-mfa-confirm-enrollment-022/83-VERIFICATION.md`](https://github.com/szTheory/sigra/blob/main/.planning/phases/83-mfa-confirm-enrollment-022/83-VERIFICATION.md).
* **planning:** Milestone **v1.19** (phase **82**, **AUD-19**) — **AUD-04-048** / **049** + **09-VERIFICATION** C-1 rows, **44**/**45** inventories, **09-03-SUMMARY** for **`Sigra.JWT.refresh/3`** persistence + audit co-fate; **AUD-08** closure for guided **`JWT.refresh`** path. See [`.planning/phases/82-jwt-refresh-persistence-audit-cofate/82-VERIFICATION.md`](https://github.com/szTheory/sigra/blob/main/.planning/phases/82-jwt-refresh-persistence-audit-cofate/82-VERIFICATION.md).
* **planning:** Milestone **v1.18** (phase **81**, **AUD-18**) — **AUD-04-048** / **049** + **09-VERIFICATION** C-1 rows, **44**/**45** inventories, **09-03-SUMMARY** note for transactional JWT refresh/reuse audit in **`lib/sigra/api_token.ex`**; **AUD-08** explicitly out of scope. See [`.planning/phases/81-jwt-refresh-audit-atomicity/81-VERIFICATION.md`](https://github.com/szTheory/sigra/blob/main/.planning/phases/81-jwt-refresh-audit-atomicity/81-VERIFICATION.md).
* **planning:** Milestone **v1.17** (phase **80**, **AUD-17**) — **AUD-04-043** / **EX-44-05** closure: **44-AUD-04-INVENTORY**, **09-VERIFICATION** C-1 row **043**, **09-03-SUMMARY** note; forced-clear audit atomicity in **`lib/sigra/account.ex`**. See [`.planning/REQUIREMENTS.md`](https://github.com/szTheory/sigra/blob/main/.planning/REQUIREMENTS.md).
* **planning:** Milestone **v1.16** (phase **79**, **AUD-16**) — **44-AUD-04-INVENTORY** + **09-VERIFICATION** C-1 rows **AUD-04-044..046** aligned to transactional **`verify/2`** in **`lib/sigra/api_token.ex`**; **09-03-SUMMARY** bounded-batch note; **EX-44-01** verify slice retired. See [`.planning/REQUIREMENTS.md`](https://github.com/szTheory/sigra/blob/main/.planning/REQUIREMENTS.md) and [`.planning/phases/79-api-token-verify-failure-audit/79-VERIFICATION.md`](https://github.com/szTheory/sigra/blob/main/.planning/phases/79-api-token-verify-failure-audit/79-VERIFICATION.md).
* **planning:** Milestone **v1.15** (phase **78**, **AUD-14**) — **44-AUD-04-INVENTORY** + **09-VERIFICATION** C-1 rows for **AUD-04-035..042** and **047** aligned to **`lib/sigra/account.ex`** / **`lib/sigra/api_token.ex`**; **09-03-SUMMARY** bounded-batch note. See [`.planning/phases/78-account-api-c1-planning-truth/78-VERIFICATION.md`](https://github.com/szTheory/sigra/blob/main/.planning/phases/78-account-api-c1-planning-truth/78-VERIFICATION.md).

### Added

* **tests:** `test/sigra/jwt_refresh_audit_cofate_test.exs` covers **`Sigra.JWT.refresh/3`** persistence + audit co-fate (happy path, audit-off, reuse + audit, **`CHECK`** fault injection on happy and reuse branches).
* **tests:** `test/sigra/api_token_audit_atomic_test.exs` covers **`api.jwt_refresh`** / **`api.jwt_refresh_reuse`** (happy path, audit-off, **`CHECK`** fault injection + **`log_safe_error`** telemetry).
* **tests:** `test/sigra/api_token_audit_atomic_test.exs` covers **`api.token_verify.failure`** for invalid / revoked / expired paths plus audit-table fault injection (constraint / telemetry parity).
* **tests:** `test/sigra/account_audit_atomicity_test.exs` exercises **`Sigra.Account.request_email_change/4`**, **`confirm_email_change/3`**, and **`cancel_email_change/3`** with Postgres `CHECK` fault injection so domain mutations roll back when the paired **`account.email_change_*`** audit insert is rejected — complements **AUD-04-035..037** C-1 evidence alongside **`change_password`**.
* **tests:** `test/sigra/account_audit_atomicity_test.exs` covers **`Sigra.Account.clear_password_change_requirement/3`** (happy path, audit-off branch, and **`account.password_change`** `CHECK` rollback) for **AUD-04-043** / **AUD-17**.

## [0.2.4](https://github.com/szTheory/sigra/compare/v0.2.3...v0.2.4) (2026-04-24)

### Changed

* **audit:** `Sigra.MFA.audit_backup_codes_regenerate/3` and `Sigra.MFA.audit_trust_browser/2` now emit audit rows via `Ecto.Multi` + `Sigra.Audit.log_multi_safe/3` inside `Repo.transaction/1` when `:audit_schema` is configured (bounded **SEED-002** closure for **AUD-04-033** / **AUD-04-034**; **`regenerate_backup_codes/4`** remains the authoritative rotation path).

### Fixed

* **audit:** `commit_ad_hoc_mfa_audit/5` rescues `Ecto.ConstraintError` (and related DB constraint failures) when the audit insert is rejected at the database layer without a matching changeset constraint, preserving `log_safe/3`-class behavior: emit `[:sigra, :audit, :log_safe_error]` with `reason: :constraint_violation` and return `:ok`.

### Documentation

* **planning:** **v1.11** adoption stabilization — triage notes (`.planning/v1.11-TRIAGE.md`), **`upgrading-to-v1.11.md`**, ExDoc extras, intro upgrade cross-links, and **`MAINTAINING.md`** milestone pause guidance (**STAB-01**..**STAB-04**).
* **planning:** **v1.12** trust bundle — [upgrading-to-v1.12.md](guides/introduction/upgrading-to-v1.12.md) (ExDoc extra), [docs/uat-ci-coverage.md](docs/uat-ci-coverage.md) (**v1.12 launch evidence** subsection), and [milestone UAT index](https://github.com/sztheory/sigra/blob/main/.planning/v1.12-UAT-EVIDENCE.md) on GitHub (**TRN-01**..**TRN-03** doc polish).

### Roadmap traceability

* Planning milestone **v1.14** (phase **77**, **AUD-13**) — operator-trust slice for MFA ad-hoc audit atomicity; see [`.planning/milestones/v1.14-ROADMAP.md`](https://github.com/szTheory/sigra/blob/main/.planning/milestones/v1.14-ROADMAP.md).

## [0.2.3](https://github.com/szTheory/sigra/compare/v0.2.2...v0.2.3) (2026-04-23)


### Bug Fixes

* **ci:** document RELEASE_PLEASE_TOKEN for downstream CI on release PRs ([#24](https://github.com/szTheory/sigra/issues/24)) ([324b036](https://github.com/szTheory/sigra/commit/324b03652a9da5c8c0332ddc4193a716acf5e175))

## [0.2.2](https://github.com/szTheory/sigra/compare/v0.2.1...v0.2.2) (2026-04-23)


### Bug Fixes

* **hex:** shorten Hex package description (300 char limit) ([#22](https://github.com/szTheory/sigra/issues/22)) ([3d8acfe](https://github.com/szTheory/sigra/commit/3d8acfed1d0cf7530454a8ef151f91e12ebbbe4c))

## [0.2.1](https://github.com/szTheory/sigra/compare/v0.2.0...v0.2.1) (2026-04-23)


### Features

* **053-01:** add Hex docs link and ExDoc publish reminder ([3362bf0](https://github.com/szTheory/sigra/commit/3362bf00ffdb7d3b0b3ee97398343ee3a025ae57))
* **053-01:** refresh Hex description for PUB-01 ([acd275e](https://github.com/szTheory/sigra/commit/acd275e8668d8159558efe87a80715de2f53ebea))
* **06-01:** add MFA deps, config, error types, and Credential struct ([52a25f4](https://github.com/szTheory/sigra/commit/52a25f481cca702865d1c59a48612725da2cc541))
* **06-01:** implement MFA orchestrator, BackupCodes, Trust, and Lockout modules ([e913806](https://github.com/szTheory/sigra/commit/e91380623f7e30fd0d10f866c30d0f6ca847b349))
* **06-02:** add MFA-aware authenticate flow and complete_mfa_verification ([db192a1](https://github.com/szTheory/sigra/commit/db192a12a75f5071cad1a75d9676b4ac211bbaff))
* **06-02:** add RequireMFA and RequireMFAEnrolled plugs with mfa_pending session type ([d3bb45b](https://github.com/szTheory/sigra/commit/d3bb45b204f5249e6e29c9b9071d28b1e5c4fb26))
* **06-03:** add MFA telemetry event catalog and integration ([826945c](https://github.com/szTheory/sigra/commit/826945c89965086cf727d6099f312b7670271040))
* **06-03:** add MFA testing helpers and TokenCleanup mfa_pending extension ([bf17b7c](https://github.com/szTheory/sigra/commit/bf17b7cc6d4565b9a5850bd820d26e58dd0577d9))
* **06-04:** add MFA email templates, Auth context delegation, and test fixtures ([8a93edb](https://github.com/szTheory/sigra/commit/8a93edb8efc898a3c6101bede287195a9a893f35))
* **06-04:** add MFA migration tables and generated Ecto schemas ([e66b8f4](https://github.com/szTheory/sigra/commit/e66b8f4f8910f9f77c0a46fbf20333e4624b994d))
* **06-05:** add MFA challenge page templates (controller + HTML + LiveView) ([8efd59d](https://github.com/szTheory/sigra/commit/8efd59d8702053f86538888d7099ffc64895630c))
* **06-05:** add MFA settings templates, require_mfa plug, and generator wiring ([89cc608](https://github.com/szTheory/sigra/commit/89cc608abd24ff95c48df73e94bc52d7353184ea))
* **07-01:** APIToken module and RequireScopes plug with full test coverage ([953adbe](https://github.com/szTheory/sigra/commit/953adbeccb6da292ce3563459a780d7e47b02d96))
* **07-01:** config extensions, StringList type, ScopeRegistry, error types, telemetry events ([e1e0e39](https://github.com/szTheory/sigra/commit/e1e0e39d2624a9aadd5d92f2023219bd29602a0e))
* **07-02:** add Joken dependency, ClaimsBuilder behaviour, and Signer module ([8c79f0c](https://github.com/szTheory/sigra/commit/8c79f0cdbd509216ae3b09a709e02ae68e25209d))
* **07-02:** add JWT module and RefreshToken with family-based reuse detection ([2d00c6e](https://github.com/szTheory/sigra/commit/2d00c6ec26c93415225f7316794d4cdb9c592486))
* **07-03:** add Auth delegation, TokenCleanup extension, Testing helpers, Email notification ([611e5f6](https://github.com/szTheory/sigra/commit/611e5f64c3656ce1230f3973c39400bdc2a8e1e8))
* **07-03:** rewrite FetchBearer with auto-detection and scope assignment ([425527a](https://github.com/szTheory/sigra/commit/425527ab56af1c6a631201d33e08801660f7af25))
* **07-04:** add API controllers, email template, injector, and install task ([86f9be4](https://github.com/szTheory/sigra/commit/86f9be436ce28faa624f1dd88c417785c8b2f3be))
* **07-04:** add API token migration and schema templates ([9b13525](https://github.com/szTheory/sigra/commit/9b13525e81639e54afa9e40c5e6678d671b4761f))
* **08-01:** add config extensions, email templates, and data export behaviour ([cd3ef15](https://github.com/szTheory/sigra/commit/cd3ef15aa504e82044ba3520d486779d8133df91))
* **08-01:** implement hooks engine with Ecto.Multi integration and tests ([b635995](https://github.com/szTheory/sigra/commit/b6359959ef0b62092d1ca2281159e24af8a1e24d))
* **08-02:** add Account orchestrator with unified delegation API ([44ea30a](https://github.com/szTheory/sigra/commit/44ea30a145fe27ead2399d2acaeca4770e5e0a80))
* **08-02:** implement Account Deletion module with 3 strategies ([cd31c37](https://github.com/szTheory/sigra/commit/cd31c3791fa1e9c6cd3ee5555ccd26d45a5d759b))
* **08-02:** implement EmailChange and PasswordChange modules ([601d35f](https://github.com/szTheory/sigra/commit/601d35f685f62fc84997359ee96976b78bc395b9))
* **08-03:** add telemetry events and Auth module lifecycle delegation ([34e6f2b](https://github.com/szTheory/sigra/commit/34e6f2bca6d1d940a0e170dc460f7cf2227cacbf))
* **08-03:** implement RequirePasswordChange plug and AccountDeletion Oban worker ([6c26dce](https://github.com/szTheory/sigra/commit/6c26dce53b1d6579db9d5d1c5cec29f3bfc467d0))
* **08-04:** add 7 account lifecycle email templates ([36363df](https://github.com/szTheory/sigra/commit/36363df8cbe1f32cf65dec2b89ef6dbd5f307b04))
* **08-04:** auth context lifecycle delegation and hooks stub module ([ada92fb](https://github.com/szTheory/sigra/commit/ada92fb0835d9485a032420a2e823f88aae90efe))
* **08-04:** migration template, user schema, and token TTL for account lifecycle ([21332d3](https://github.com/szTheory/sigra/commit/21332d317ead108dbc8509fd0437e8f82b9c5ef1))
* **08-05:** add generator injector for lifecycle routes, plugs, and tests ([ba5d3c5](https://github.com/szTheory/sigra/commit/ba5d3c5ffd52916a015b6db9902016eed2233e09))
* **08-05:** add settings LiveView, reactivation page, and lifecycle testing helpers ([61112c9](https://github.com/szTheory/sigra/commit/61112c9a6ea5b28791a3dd9500bbcf8433c8c900))
* **09-01:** add audit_events migration template ([02ae340](https://github.com/szTheory/sigra/commit/02ae34012c30d0aabc216edd8c5be2589c84a35a))
* **09-01:** add AuditEvent schema template and wire install task ([bd3f69f](https://github.com/szTheory/sigra/commit/bd3f69fca23b00dcff6a64fcbf835e6073ad1297))
* **09-02:** add Sigra.Audit changeset, cursor, query submodules ([01f75de](https://github.com/szTheory/sigra/commit/01f75deb86d1986c10c4c21f9097a8acf792abec))
* **09-02:** add Sigra.Audit public API ([ce6dc7c](https://github.com/szTheory/sigra/commit/ce6dc7cfc8f11d95d709cf26ac8497730ad1853a))
* **09-03:** integrate audit logging into auth + session + security subsystems ([0724d96](https://github.com/szTheory/sigra/commit/0724d96f2d4cc3250b4358c3f7ae598dd951fabb))
* **09-03:** integrate audit logging into mfa + oauth + api_token + account ([68e222c](https://github.com/szTheory/sigra/commit/68e222cf2eabdbf30d02eea78167a810dc7ac709))
* **09-04:** add Sigra.Workers.AuditCleanup Oban worker and startup warning ([a01a25c](https://github.com/szTheory/sigra/commit/a01a25c451ed5f8512cf9607ab0628e556cd3514))
* **10-01:** add audit test helpers and section headers to Sigra.Testing ([d891e2b](https://github.com/szTheory/sigra/commit/d891e2beb442d19d77522f9fdf0b3958465eba8b))
* **10-02:** add scenario fixtures to AuthFixtures template ([24ecd7c](https://github.com/szTheory/sigra/commit/24ecd7ce73c340641419d984f4506f02ad5bbe69))
* **10-03:** add :cookie_domain config + Sigra.MFA.Trust.cookie_opts/1 ([080fd4f](https://github.com/szTheory/sigra/commit/080fd4f277a833213904a36ac8501bcd571d9fea))
* **10-03:** runtime remember_me_options in UserAuth + MFA trust cookie + boot warning ([4aa7030](https://github.com/szTheory/sigra/commit/4aa703073f8c2d5de480eff8f4eab54a8412e1aa))
* **10-05:** add pure helpers + doctests to Config/Auth/Testing ([fa57f1e](https://github.com/szTheory/sigra/commit/fa57f1efa0c5cdc117f839a52a0eabe3362da773))
* **10-06:** scaffold test/example Phoenix app with Sigra installed ([2f1790e](https://github.com/szTheory/sigra/commit/2f1790e8f95a0c0e9330714a65cb812f8912c532))
* **10.1.1-03:** unify example app on Sigra canonical user_sessions store (B6, D-06/D-07) ([ddf7b94](https://github.com/szTheory/sigra/commit/ddf7b94ebed5063bb1d5cddaed0b85e01bbd57b8))
* **10.1.1-05:** flip installer default to binary_id (uuid) PKs (D-10) ([d1d2c40](https://github.com/szTheory/sigra/commit/d1d2c4047562f7e6a5049bfa79b80de57fe4644a))
* **10.1.1-06:** add --yes non-interactive flag to sigra.install ([2b15e81](https://github.com/szTheory/sigra/commit/2b15e81aef87fa7de3fcd0b5773ae2d0c3876cce))
* **10.1.1-06:** add install_smoke + example_http_smoke CI jobs ([ae37e78](https://github.com/szTheory/sigra/commit/ae37e787c1ab48fa0b4b652dab6af477b7db1157))
* **10.1.1-06:** add install-smoke.sh and http-smoke.sh CI drivers ([c082ab3](https://github.com/szTheory/sigra/commit/c082ab38301d3957e2ed15d056d051011e60f085))
* **10.1.1-07:** add data-testid hook to MFA TOTP secret ([7dd8e25](https://github.com/szTheory/sigra/commit/7dd8e25961b16bf25a1b2608646f39c29a77a4f7))
* **10.1.1-07:** scaffold Playwright golden-path browser smoke harness ([24e8c7c](https://github.com/szTheory/sigra/commit/24e8c7c9524ee89b20308b7820da6cc9d0fa113b))
* **41:** TOTP-gated backup code rotation and GA-01 regression ([e5f399e](https://github.com/szTheory/sigra/commit/e5f399e2d2600c61d5b956ea8fc49d7372e05efc))
* **43-02:** atomic auth.register.success audit via register_user_multi ([d2e6efb](https://github.com/szTheory/sigra/commit/d2e6efbe2f247d7ccb8403ff2415340ed4290a4c))
* **43-03:** atomic magic-link and password-reset request audits via Multi ([149ab89](https://github.com/szTheory/sigra/commit/149ab89c934f8ea8f26540cf338ab0a293d2ac8f))
* **43-04:** atomic auth.login.success audit with lockout Multi ([3bc7811](https://github.com/szTheory/sigra/commit/3bc7811aa444d4b6e9cfc0aa9826a03753521263))
* **49-01:** add mix ci.audit_45 alias for AUD-08 merge gate ([3adb5fe](https://github.com/szTheory/sigra/commit/3adb5fe122fc03136f210e89d818de893102999e))
* **50-01:** add mix ci.install_golden alias for install golden tests ([ba8ca30](https://github.com/szTheory/sigra/commit/ba8ca3065f590213a3adf587c3d7d303290e353e))
* **audit:** add audit_multi_step for multi-row Multi audits ([a642496](https://github.com/szTheory/sigra/commit/a642496d1990e77ed558e22b8257b97ac802ab07))
* **mfa:** atomic audit Multis for AUD-06 (MFA) ([3d5abf1](https://github.com/szTheory/sigra/commit/3d5abf112403cd71f2236c53538633ef0165e58c))
* **uat:** add Docker UAT environment + runbook for milestone v1.0 manual gates ([812eca0](https://github.com/szTheory/sigra/commit/812eca0734787484669cd3ce9fad18c39932741d))


### Bug Fixes

* **05:** enforce sudo mode on link_provider and unlink_provider (T-05-12) ([802b2da](https://github.com/szTheory/sigra/commit/802b2daf269812c069db6c989c4d89e2c38c7801))
* **05:** WR-04 remove dead code branch in detect_context_name ([77f61b5](https://github.com/szTheory/sigra/commit/77f61b5dee3b5da1cd347677eee91d3b8a413e14))
* **05:** WR-05 document encrypted_* field naming convention in get_tokens ([fa53680](https://github.com/szTheory/sigra/commit/fa5368071cfb8f834710eab00590e9eb59ed18bc))
* **06:** add Code.ensure_loaded! to function_exported? tests for isolation safety ([61826f8](https://github.com/szTheory/sigra/commit/61826f8b9702ace1d1658d107ac22efd5a644110))
* **06:** add settings_url binding to email template test for MFA emails ([86f9759](https://github.com/szTheory/sigra/commit/86f9759eb424b129ee8cd362c71bda90e90105b0))
* **06:** correct struct syntax for Ecto.Changeset.cast in MFA enrollment ([b968a86](https://github.com/szTheory/sigra/commit/b968a8672802cb2bb408f83fc0bbbbd04cb69def))
* **06:** CR-01 use Ecto cast to trigger cloak_ecto encryption for TOTP secrets ([3c74dc8](https://github.com/szTheory/sigra/commit/3c74dc83c52c523de572caa2da3ae2d216d33af8))
* **06:** CR-02 eliminate modulo bias in backup code and confirmation code generation ([66f1d3b](https://github.com/szTheory/sigra/commit/66f1d3b53e1758a29c256aa672de620be6e525d8))
* **06:** WR-01 wrap MFA enrollment and cleanup in Ecto.Multi transactions ([41b3899](https://github.com/szTheory/sigra/commit/41b3899434f479f3627cba9389a036e5e021e81a))
* **06:** WR-02 combine lockout increment and lock into single atomic query ([59f6d78](https://github.com/szTheory/sigra/commit/59f6d78440d2f96c64666f7a5cc34c9cf692647d))
* **06:** WR-03 align MFA pending state checks between controller, LiveView, and library plugs ([84fd485](https://github.com/szTheory/sigra/commit/84fd4856a006ae071551a9aae4ef9a95a7738e74))
* **06:** WR-04 add missing settings_url binding for mfa_disabled_email template ([a73c46a](https://github.com/szTheory/sigra/commit/a73c46a9ef0aabc5d68655be6e1d3252d49decc0))
* **06:** WR-05 pass required options to setup_totp and simulate_mfa_lockout in fixtures ([d8bf183](https://github.com/szTheory/sigra/commit/d8bf183bb1dc7120915d33d41953e6f59ebed56a))
* **06:** WR-06 handle trailing slashes in RequireMFA path comparison ([c1f5e89](https://github.com/szTheory/sigra/commit/c1f5e89b24248e2d124219617296587e9ba73b6e))
* **07:** revise plans based on checker feedback ([2fd57a5](https://github.com/szTheory/sigra/commit/2fd57a502c18ace9d4dcdaf0de20593917c7cdad))
* **08-05:** update migration test to match partial unique index from Plan 04 ([6037d26](https://github.com/szTheory/sigra/commit/6037d26437d4dfcbafb2f106f9586e584a1113bb))
* **08:** CR-01 add missing callback fns to email change request and cancel flows ([befa404](https://github.com/szTheory/sigra/commit/befa4046fb52b63658aa5c494a5205abadf5c824))
* **08:** CR-02 add missing callback fns to email change confirm flow ([d8f7d08](https://github.com/szTheory/sigra/commit/d8f7d08a632b0f78aac76e7d6701d21595d75b4c))
* **08:** CR-03 add missing validate_password_fn to password change flow ([9903b78](https://github.com/szTheory/sigra/commit/9903b783f5190fb6a7b7e21f6c492637be10b913))
* **08:** WR-01 execute hook multi instead of discarding it ([4152725](https://github.com/szTheory/sigra/commit/4152725b822dd861f08fdf1b6db1f1b224da3c25))
* **08:** WR-02 document TTL-based cleanup for orphaned email change tokens ([5285e68](https://github.com/szTheory/sigra/commit/5285e6867a7f276bc2e81ada4a9807be5aa0767e))
* **08:** WR-03 include email and hashed_password in deletion_changeset for anonymize strategy ([6b775d0](https://github.com/szTheory/sigra/commit/6b775d0039293b6d64c61b9f4ed0b1c3e4ba55ea))
* **08:** WR-04 validate deletion strategy against known values with safe default ([debe7fc](https://github.com/szTheory/sigra/commit/debe7fc525d76c999d9d19b88a2af38e977e23d1))
* **09:** CR-01 harden validate_metadata_size against non-map and unencodable metadata ([58120a9](https://github.com/szTheory/sigra/commit/58120a91ed72177efe4f4840f164634e8d429a10))
* **09:** WR-02 raise in Sigra.Audit.stream/2 when repo.stream/1 is unavailable ([78a3474](https://github.com/szTheory/sigra/commit/78a3474545b20d4482419b41d6eee5b76bcb18ea))
* **09:** WR-06 WR-07 honor configured retention and batch cleanup deletes ([065076f](https://github.com/szTheory/sigra/commit/065076f04802409b32d82f8d8a19ca4a977e382c))
* **09:** WR-08 WR-01 sanitize log_safe error telemetry + surface missing repo ([41ec4a0](https://github.com/szTheory/sigra/commit/41ec4a084aae93dc01a0978d9e3feb46dd6e0123))
* **10-review:** CR-01 guard Mix.env() in generated UserAuth remember_me_options ([7a922e7](https://github.com/szTheory/sigra/commit/7a922e728a9151da8b23713080394efb4a412151))
* **10-review:** WR-01 correct MFA guide function references ([fc43f52](https://github.com/szTheory/sigra/commit/fc43f527277b79cc187ca1c7a54f3e10ee9625a2))
* **10-review:** WR-02 preserve false/nil in assert_audit_event metadata lookup ([138777c](https://github.com/szTheory/sigra/commit/138777cfde7cd41fbc6a72011e2a53dec923ea1e))
* **10-review:** WR-03 make Sigra.MFA.Trust.cookie_opts/0 raise to prevent silent cookie_domain drop ([009d424](https://github.com/szTheory/sigra/commit/009d4240fdb5d55d9f7d81da8ee5244e3a9212d0))
* **10-review:** WR-04 oauth_enabled? requires at least one configured provider ([1aae029](https://github.com/szTheory/sigra/commit/1aae029d4b93e014e080885d4937486be71e9efd))
* **10.1 IN-01,IN-02:** robust migration timestamp offsets and pad/1 cleanup ([8d031be](https://github.com/szTheory/sigra/commit/8d031be142e4e26ce47c07a4e5e920e44e0b1071))
* **10.1 IN-03:** route password reset through Sigra.Auth.reset_password/4 ([90d7adb](https://github.com/szTheory/sigra/commit/90d7adbc8de4a5c438c6a4dae934b8ded92194ab))
* **10.1 IN-05:** stop passing :secret_key_base to verify_confirmation_code/3 ([7eef6d8](https://github.com/szTheory/sigra/commit/7eef6d88567a2e2894069e033eeaefbc0663d417))
* **10.1 IN-06 follow-up:** move helper after handle_event clauses to satisfy --warnings-as-errors ([d64177f](https://github.com/szTheory/sigra/commit/d64177f163b2f867fe786d1b4872e84d58b8075a))
* **10.1-01:** build proper UserToken structs in request_password_reset and request_magic_link ([10c7cf9](https://github.com/szTheory/sigra/commit/10c7cf9be31d28e50d42a37a17091a7fef771788))
* **10.1-02:** backport installer template fixes [#1](https://github.com/szTheory/sigra/issues/1)-8 ([0ab0d04](https://github.com/szTheory/sigra/commit/0ab0d043b573a13a9f5cfdb03c242a202a6c94e8))
* **10.1-02:** backport installer template fixes [#9](https://github.com/szTheory/sigra/issues/9)-16 ([b19bdf3](https://github.com/szTheory/sigra/commit/b19bdf3c58cbac2920427bcd14f51ece152210fa))
* **10.1-03:** eliminate mix docs --warnings-as-errors [@doc](https://github.com/doc) reference warnings ([b1f49d3](https://github.com/szTheory/sigra/commit/b1f49d39d0bd7bd76c6cecf077a678243b0f2478))
* **10.1-05:** scenario/2 raises ArgumentError with valid atoms on unknown scenarios ([95987e2](https://github.com/szTheory/sigra/commit/95987e239f6b544af2ac39b6549ae82f90995a16))
* **10.1-06:** delete aspirational cursor_portability_test ([182edbf](https://github.com/szTheory/sigra/commit/182edbfc87eee7acb6d7534607ef365cf0e929aa))
* **10.1-06:** generator_reset_test stale alias assertion ([81d66fd](https://github.com/szTheory/sigra/commit/81d66fd5354de24fa048ddb9e14081c681735a64))
* **10.1-06:** sigra.install_test bindings — stale after plan 10.1-02 ([32dbae1](https://github.com/szTheory/sigra/commit/32dbae1175107ba8dee7c7253dba4e73d17cfc08))
* **10.1.1-02:** fix /users/sudo KeyError on render (B7, D-08) ([388856f](https://github.com/szTheory/sigra/commit/388856fe1e7810fa1b231ad30de97065280a2caa))
* **10.1.1-02:** wire confirmation email in RegistrationLive (B5, D-05) ([fbdc743](https://github.com/szTheory/sigra/commit/fbdc743bb31360afb8c6601296506a346ec6a75b))
* **10.1.1-04:** replace LoginLive with plain SessionController + SessionHTML (B9/D-12) ([ba66d76](https://github.com/szTheory/sigra/commit/ba66d76a094d361f874b502c0e37dd310f8896dd))
* **10.1.1-05:** flip test/example to uuid PKs end-to-end (B8 root fix) ([949f182](https://github.com/szTheory/sigra/commit/949f1829bc1e5c2ccdfcac75447c36924f592fa3))
* **10:** revise plans per checker iteration 1 feedback ([c70ec28](https://github.com/szTheory/sigra/commit/c70ec28eb22ba699306043b9cda4220c166a84bc))
* **44:** document APIToken.revoke/2 changeset error in typespec ([8df3957](https://github.com/szTheory/sigra/commit/8df395749ef8380dba20d23bd806fac2594cc8da))
* **49-01:** scope ci.audit_45 to one multi-path mix test ([c658a74](https://github.com/szTheory/sigra/commit/c658a745826623e79ce1c3eef8e90cc5ff8a8647))
* **docs:** include Nyquist matrix extra for ExDoc link validation ([cac5a01](https://github.com/szTheory/sigra/commit/cac5a01188943f2e6ab864edfce6cf58bacbf0b4))
* **example:** JS bundle + endpoint socket + router auth pipeline ([58b7122](https://github.com/szTheory/sigra/commit/58b7122df97529a9604e06ea1b18071fb021785e))
* **mfa:** correct Ecto.Multi.merge arity for lockout audit Multis ([09e2263](https://github.com/szTheory/sigra/commit/09e22637898512404ac7c81d1e488685d8215699))
* **MFA:** handle cleanup Multi errors in disable flows ([2e1d309](https://github.com/szTheory/sigra/commit/2e1d30936b7ab4d40f458eb49d4b91ae7d438d67))

- **Chore:** Root `.formatter.exs` no longer scans `test/example/_build` (and
  other generated trees) where Hex-copied `*.ex` install templates are not
  valid Elixir — restores reliable `mix format --check-formatted` for contributors.
- Human GA (v1.4): see .planning/v1.4-GA-UAT.md
- **AUD-04:** Auth `log_safe` → `Ecto.Multi` migration inventory for `Sigra.Auth`
  (prioritized `AUD-05` batches **B1–B3**, exclusions, grep evidence) in
  [`43-AUD-04-INVENTORY.md` (tag snapshot)](https://github.com/sztheory/sigra/blob/v0.2.0/.planning/phases/43-audit-inventory-auth-atomic-batch/43-AUD-04-INVENTORY.md).
- **AUD-04 (continuation):** MFA + Account + API token inventory (**AUD-04-020+**,
  `AUD-06` / `AUD-07` batches) in
  [`44-AUD-04-INVENTORY.md` (tag snapshot)](https://github.com/sztheory/sigra/blob/v0.2.0/.planning/phases/44-mfa-account-api-atomic-batches/44-AUD-04-INVENTORY.md).
- **AUD-08 / Phase 45:** OAuth + ops + worker **AUD-04** slice (**AUD-04-050+**) in
  [`45-AUD-04-INVENTORY.md` (tag snapshot)](https://github.com/sztheory/sigra/blob/v0.2.0/.planning/phases/45-oauth-ops-c1-signoff/45-AUD-04-INVENTORY.md).
- **AUD-05 (Auth):** When `:audit_schema` is configured, success audits for
  `auth.register.success`, magic-link and password-reset request/verify flows,
  and confirmed-password `auth.login.success` (including lockout reset and
  optional hash upgrade) are written in the same `Repo` transaction as the
  associated data changes via `Ecto.Multi` and `Sigra.Audit.log_multi_safe/3`.

### Roadmap traceability

Planning milestone **v1.4** (GA readiness & audit trail completeness; **not** a Hex version): shipped **2026-04-22** per `.planning/MILESTONES.md` — see `.planning/milestones/v1.4-ROADMAP.md`, `.planning/milestones/v1.4-REQUIREMENTS.md`, `.planning/milestones/v1.4-MILESTONE-AUDIT.md`, and the GA matrix framing in `.planning/v1.4-GA-UAT.md` (Executed / Waived language; do not duplicate the matrix here).

## [0.2.0] - 2026-04-19

### Roadmap traceability

Planning milestone **v1.3** (cleanup & hardening tranche; **not** a Hex version): shipped **2026-04-19** per `.planning/MILESTONES.md` — see `.planning/milestones/v1.3-ROADMAP.md`, `.planning/milestones/v1.3-REQUIREMENTS.md`, and `.planning/milestones/v1.3-MILESTONE-AUDIT.md`.

### Added

- `docs/NEXT-STEPS-MANUAL.md` — short post-merge checklist (PR merge, Hex,
  GitHub Release) for maintainers.
- `docs/audit-semantics.md` — public note on `log` / `log_multi` / `log_safe`, C-1
  hybrid status, and pointers to testing helpers (linked from README).
- `Sigra.Audit.Assertions` — ordered `latest_audit_event/3` + `assert_audit_fields/3`
  for tests; see `guides/recipes/testing.md`.
- Atomic `api.token_create` audit via `Ecto.Multi` / `Sigra.Audit.log_multi_safe/3` in
  `Sigra.APIToken` (telemetry from `emit_telemetry_from_changes/1` on successful
  commit only).
- Example app smoke tests assert login and MFA enrollment audit rows; host
  `get_user_by_email_and_password/2` now delegates to `Sigra.Auth.authenticate/2`
  with full `Sigra.Config` so `auth.login.*` audit runs.
- Human GA matrix in `v1.3-HUMAN-UAT.md` closed via machine substitutes; see
  `.planning/uat-evidence/v1.3.0/INDEX.md` for CI anchors and per-item evidence.
- **GA UAT shift-left:** `docs/uat-ci-coverage.md` maps SEED-001 items to CI and
  documents residual human checks; `test/example/priv/playwright/tests/ga-uat-shift-left.spec.ts`
  covers invitation email-lock and MFA regenerate UI reachability; example app
  gains `EmailsLifecycleHtmlTest`; `scripts/ci/getting-started-contract.sh` plus
  `getting_started_uat_contract` CI job validate getting-started links/commands.
- Generated and example `MFASettingsLive` regenerate form uses an explicit
  `type="submit"` on the regenerate button so LiveView `phx-submit` fires reliably.
- Published to [Hex.pm](https://hex.pm/packages/sigra) as **0.2.0** (initial package listing).

## [0.1.0] - 2026-04-17

First library version line with Hex-oriented `mix.exs` packaging; upgrade to **0.2.0** for the Hex listing and additions above.

### Roadmap traceability

Planning milestone **v1.2** (admin dashboard tranche; **not** a Hex version): shipped **2026-04-17** per `.planning/MILESTONES.md` — see `.planning/milestones/v1.2-ROADMAP.md`, `.planning/milestones/v1.2-REQUIREMENTS.md`, and `.planning/milestones/v1.2-MILESTONE-AUDIT.md`.

### Changed

- **BREAKING (behavior):** `session.create` audit now fires AFTER
  `select_active_organization` during login, so the very first audit event
  of a successful login carries the real `organization_id` rather than a
  `nil` one. Previously, `session.create` fired before the active-org
  selection step and always had a null org, meaning the v1.2 impersonation
  anchor would have no tenant to pin against. If you were relying on the
  old ordering (e.g. a log scraper keyed on null-org events for login
  detection), update your consumers to match the new ordering.
- **BREAKING (API):** `Sigra.Audit.Query.build/2` now raises
  `ArgumentError` on unknown filter keys instead of silently ignoring them.
  If your host app was passing an unknown key (e.g. `actor:` instead of
  `actor_id:`) the query previously returned unfiltered results — now it
  fails loudly. Rationale: silent-ignore on an audit query is a
  security-adjacent bug; audit systems must be loud about
  misconfiguration.
- **BREAKING (installer):** `Sigra.Workers.AccountDeletion` job args now
  require five additional stringified keys at enqueue time:
  `"organization_id"`, `"actor_id"`, `"scope_module"`, `"organization_schema"`,
  and `"audit_schema"`. Host apps that use the Sigra installer to generate
  the account-deletion Oban enqueue site should regenerate that site (or
  manually add the new args). The worker validates presence of all five
  via `fetch_arg!/2` up front BEFORE any `Module.safe_concat` call so the
  `KeyError` surfaces with the actual missing key.

### Fixed

- Hex package `files` list includes `priv/` (installer, upgrade, and OAuth generator templates) so `mix sigra.install` / `mix sigra.upgrade` work when the dependency is pulled from Hex.

### Added

- `Sigra.Audit.log_safe/3` accepts a scope as the second positional argument.
  The scope is duck-typed on `%{user, active_organization, impersonating_from}`;
  pass `nil` explicitly for pre-authentication or truly anonymous call sites.
  `log_safe/2` remains as a thin shim that delegates to `log_safe/3` with a
  `nil` scope.
- `Sigra.Audit.Query` supports `:organization_id`, `:effective_user_id`, and
  `:organization_scope` filters. `:organization_scope` accepts `{:only, org_id}`
  or `{:including_global, org_id}` tagged tuples. The composite index
  `(organization_id, inserted_at)` is created on `audit_events` by the new
  alter migration to keep org-scoped queries off seq-scan plans at scale.
- `Sigra.Scope.build/3` library constructor for the host-app `%Scope{}` struct,
  used by login-time scope synthesis and by Sigra-aware workers. Also adds
  `Sigra.Scope.from_opts/2` and `Sigra.Scope.from_config/2` convenience
  constructors.
- `Sigra.Workers` behaviour — single `@callback perform(scope, args)` contract
  for Oban workers requiring tenant context. `Sigra.Workers.new/3` fails fast
  when required `"organization_id"` / `"actor_id"` arg keys are absent;
  `Sigra.Workers.fetch_arg!/2` is a belt+suspenders helper for worker
  `perform/1` implementations. `Sigra.Workers.AccountDeletion` is the
  reference implementation — it reconstructs the scope inside `perform/1`
  and delegates to `perform/2` with a real `%Scope{}`.
- `Sigra.Testing.assert_audit_logged/2` helper — a thin alias for
  `assert_audit_event/2` with the REQ DX-02 naming convention. Signature is
  `(map, keyword)` to match `assert_audit_event/2` exactly.
- Custom Credo check `Sigra.Credo.NoLogSafe2InLib` that forbids arity-2
  `Sigra.Audit.log_safe` calls in `lib/sigra/**` (with an exception for the
  shim definition itself and for `test/**`). Registered in `.credo.exs` via
  the `requires:` field so host apps pulling Sigra as a dep are not forced
  to take a Credo dependency.
- New migration `alter_audit_events_add_org_columns.exs` adds
  `organization_id :binary_id` (nullable, FK with
  `on_delete: :nilify_all` so historical rows survive organization deletion)
  and `effective_user_id :binary_id` (nullable, v1.2 impersonation anchor)
  columns to `audit_events`, plus the composite index
  `(organization_id, inserted_at)`. On Postgres, the migration uses
  `@disable_ddl_transaction true` + `create index(..., concurrently: true)`
  for zero-downtime deploy on production audit tables. On SQLite/MySQL, a
  plain `change/0` migration emits the same shape non-concurrently.

[Unreleased]: https://github.com/sztheory/sigra/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/sztheory/sigra/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/sztheory/sigra/releases/tag/v0.1.0
