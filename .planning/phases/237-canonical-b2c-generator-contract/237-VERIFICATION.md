---
phase: 237-canonical-b2c-generator-contract
verified: 2026-08-05T02:47:19Z
status: passed
score: 4/4 must-haves verified
behavior_unverified: 0
overrides_applied: 0
---

# Phase 237: Canonical B2C Generator Contract Verification Report

**Phase Goal:** Canonical B2C generator contract — prove the exact assets-enabled PostgreSQL B2C fresh-host lifecycle and Google OAuth output, while proving feature-owned admin, organization, and passkey residue absent.
**Verified:** 2026-08-05T02:47:19Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | B2C-01: the exact opt-out command produces an assets-enabled PostgreSQL host that compiles warning-free, deploys assets, migrates, boots, and returns a successful root response. | ✓ VERIFIED | `env -u PGPORT PGHOST=localhost PGUSER=postgres PGPASSWORD=postgres GITHUB_WORKSPACE="$PWD" scripts/ci/passkeys-opt-out-smoke.sh` exited 0. Its B2C leg invokes `mix sigra.install Accounts User users --no-admin --no-organizations --no-passkeys --yes`, then compile, assets deployment, database creation/migration, bounded server boot, and `curl -sf /`. |
| 2 | B2C-02: after adding direct `cloak_ecto`, Google OAuth generation emits the required identity, encrypted vault, controller/HTML/templates, migration, routes, provider configuration, and supervision child. | ✓ VERIFIED | The successful B2C smoke adds `{:cloak_ecto, "~> 1.3"}`, runs `mix deps.get` then `mix sigra.gen.oauth --providers google`, and asserts every required file, identity migration, router/config markers, Google variables, and `Vault` application child. The fast fixture’s B2C branch independently exercises the same generation and compile path. |
| 3 | B2C-03: generated B2C output has no feature-owned admin, organization, or passkey routes, files, migrations, assets/dependencies, or configuration markers. | ✓ VERIFIED | The successful generated-host smoke negatively asserts the feature-owned routes/markers, source files, migrations, admin assets/logo, passkey JS/npm/Mix/config surfaces. The fixture additionally scans generated `lib`, `config`, `assets`, `priv`, and dependency manifests for passkey residue. |
| 4 | Fixture-only or compile-only output is never substituted for PostgreSQL migration/boot proof. | ✓ VERIFIED | The Plan’s only lifecycle harness is the PostgreSQL smoke; it performed the live lifecycle above. The source-lock test (`mix test test/sigra/install/generator_passkeys_opt_out_test.exs:179`) passed and locks `ecto.migrate`, `assets.deploy`, `curl -sf`, OAuth assertions, and disabled-feature sentinels into that harness. |

**Score:** 4/4 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `scripts/ci/passkeys-opt-out-smoke.sh` | Authoritative assets-enabled fresh-host B2C lifecycle and generated-tree contract | ✓ VERIFIED | Exists, substantive (295 lines), has no debt/stub markers, is the CI job command, and completed successfully against PostgreSQL during this verification. `verify.artifacts` passed. |
| `test/sigra/install/generator_passkeys_opt_out_test.exs` | Fast fixture B2C generation and source-lock contract | ✓ VERIFIED | Exists, substantive (296 lines), creates the B2C fixture with exact flags, exercises OAuth generation/compile, and reads/locks the smoke source. The focused source-lock test passed. `verify.artifacts` passed. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- |
| `scripts/ci/passkeys-opt-out-smoke.sh` | `mix sigra.install` | Exact D-01 opt-out invocation | ✓ WIRED | `run_leg "--no-admin --no-organizations --no-passkeys" "sigra_b2c_alpha"` reaches `MIX_ENV=dev mix sigra.install Accounts User users ${flags} --yes`; the live smoke completed it. |
| `scripts/ci/passkeys-opt-out-smoke.sh` | `mix sigra.gen.oauth` | Add direct `cloak_ecto`, fetch dependencies, Google-only generator | ✓ WIRED | The B2C branch calls `add_cloak_ecto`, `mix deps.get`, then `MIX_ENV=dev mix sigra.gen.oauth --providers google`; subsequent assertions and lifecycle stages executed successfully. |
| `test/sigra/install/generator_passkeys_opt_out_test.exs` | `scripts/ci/passkeys-opt-out-smoke.sh` | Source lock prevents weakening CI-owned lifecycle/surface assertions | ✓ WIRED | The named test reads the script directly and asserts the canonical flags, OAuth setup/output, feature sentinels, warning-free compilation, assets, migration, and root probe; it passed. |

`gsd-tools` independently reported 2/2 artifacts passed and 3/3 key links verified.

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| `scripts/ci/passkeys-opt-out-smoke.sh` | Generated fresh Phoenix host | `mix phx.new` → installer → OAuth generator → PostgreSQL → `phx.server` | Yes — live generated apps, real PostgreSQL operations, and HTTP root response during the successful smoke | ✓ FLOWING |
| `generator_passkeys_opt_out_test.exs` | Temporary generated fixture host | `InstallFixture` subprocess generation/install/generator calls | Yes — fixture files are generated and inspected; its source-lock test passed | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Complete fresh-host B2C lifecycle | `env -u PGPORT PGHOST=localhost PGUSER=postgres PGPASSWORD=postgres GITHUB_WORKSPACE="$PWD" scripts/ci/passkeys-opt-out-smoke.sh` | Exit 0; all three legs passed, including `sigra_b2c_alpha` lifecycle and root HTTP response | ✓ PASS |
| Source lock for lifecycle and generated surface contract | `mix test test/sigra/install/generator_passkeys_opt_out_test.exs:179` | 1 test, 0 failures | ✓ PASS |
| Shell validity | `bash -n scripts/ci/passkeys-opt-out-smoke.sh` | Exit 0 | ✓ PASS |

### CI Corroboration

The historical GitHub Actions CI run [30969700524](https://github.com/szTheory/sigra/actions/runs/30969700524) recorded `Passkeys opt-out smoke` as **success** (job 92191159239) on SHA `b79ee6ae83e98a4bc638a9a1cbe8812efde3c471`. `git diff --quiet 103ad84..b79ee6a -- scripts/ci/passkeys-opt-out-smoke.sh test/sigra/install/generator_passkeys_opt_out_test.exs` confirmed the phase artifacts were identical at that CI SHA. This is corroborating machine-readable evidence; the local authoritative smoke above is the direct B2C-01 proof for the checked-out contract.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- |
| B2C-01 | 237-01 | Fresh Phoenix app installs the three opt-outs, builds assets, compiles warning-free, migrates, and boots | ✓ SATISFIED | Successful PostgreSQL-backed smoke exercised the exact B2C command through compile/assets/create/migrate/server/root HTTP response. |
| B2C-02 | 237-01 | Same app generates Google OAuth with required routes, controller, identity, vault, and migration | ✓ SATISFIED | Live B2C smoke generation and required-output assertions passed; fixture mirrors and compiles the contract. |
| B2C-03 | 237-01 | Profile emits no admin, organization, or passkey routes/assets/configuration | ✓ SATISFIED | Live smoke’s scoped absence assertions passed across routes, source, migrations, assets, dependencies, and config; fixture provides fast regression coverage. |

No orphaned Phase 237 requirements were found: `REQUIREMENTS.md` maps exactly B2C-01, B2C-02, and B2C-03 to this phase, and the plan declares all three.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `scripts/ci/passkeys-opt-out-smoke.sh` | 26 | `XXXXXX` in `mktemp` template | ℹ️ Info | Expected secure temporary-directory template; not a debt marker or stub. |

No `TBD`, `FIXME`, `XXX`, `TODO`, `HACK`, placeholder, empty implementation, or hollow-data pattern was found in either phase artifact.

### Disconfirmation Pass

- A compile-only fixture would not prove B2C-01’s database/boot invariant; the successful authoritative PostgreSQL smoke supplied that missing behavioral evidence.
- The fast source-lock test deliberately tests script structure rather than generated-host behavior; the separate live smoke was run and passed, so the two checks are not being conflated.
- The error path that would reject a missing OAuth surface or disabled-feature residue is exercised by fail-closed assertion helpers in the live smoke; no untested must-have error path remains relevant to this phase contract.

### Gaps Summary

None. The phase’s full fresh-host, PostgreSQL-backed contract was executed successfully and its fast regression lock passed. The phase goal is achieved.

---

_Verified: 2026-08-05T02:47:19Z_
_Verifier: the agent (gsd-verifier)_
