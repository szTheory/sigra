---
phase: 95
slug: optional-dep-boot-validation-mix-sigra-doctor-hard-02
status: complete
created: 2026-04-30
updated: 2026-04-30
requirement: HARD-02
roadmap_criterion: 5
---

# Phase 95 Verification

## Merge-Gate Outcome

- Local merge gate: PASS
- GitHub Actions workflow contract: updated on `main` branch via `.github/workflows/ci.yml`
- Human-only verification: not required for Phase 95

## Commands Run

```bash
MIX_ENV=test mix test test/sigra/workers/optional_deps_test.exs
rg -n "oban|bcrypt|eqrcode|sigra.doctor|delivery_test|crypto_test|mfa_test" .github/workflows/ci.yml
python3 - <<'PY'
import yaml
with open('.github/workflows/ci.yml', 'r', encoding='utf-8') as f:
    yaml.safe_load(f)
print('YAML OK')
PY
rg -n "mix sigra.doctor|optional deps|async|warnings-as-errors|95-VERIFICATION" README.md MAINTAINING.md guides/introduction/troubleshooting-install.md guides/recipes/deployment.md .planning/phases/95-optional-dep-boot-validation-mix-sigra-doctor-hard-02/95-VALIDATION.md .planning/phases/95-optional-dep-boot-validation-mix-sigra-doctor-hard-02/95-VERIFICATION.md
```

## Maintainer Pointer

- `MAINTAINING.md` now includes a **Diagnosing first-run issues** section that starts with `mix sigra.doctor`.
- The maintainer guidance states that enforced optional-dep failures are blocking only when the host actually enabled the related feature.

## Roadmap Criterion 5 Evidence

### CI dep-off proof

- `.github/workflows/ci.yml` defines dedicated lanes for:
  - `optional_dep_oban_absent`
  - `optional_dep_bcrypt_absent`
  - `optional_dep_eqrcode_absent`
- The Oban-off lane runs `mix sigra.doctor --delivery-mode=async`, targeted `delivery_test` / worker coverage, and a real worker entrypoint assertion.
- The bcrypt-off lane runs `crypto_test` coverage and a real `Sigra.Crypto.verify_with_upgrade/2` missing-dep assertion.
- The EQRCode-off lane runs `mfa_test` coverage and a real `Sigra.MFA.enroll/1` missing-dep assertion.
- No mandatory Joken-off lane was added.

### Registry single source of truth

`lib/sigra/optional_deps.ex` remains the single source of truth for Phase 95 feature-to-dependency policy.

Grep evidence:

```bash
rg -n "^if Code.ensure_loaded\\?\\(Oban.Worker\\) do" \
  lib/sigra/workers/account_deletion.ex \
  lib/sigra/workers/audit_cleanup.ex \
  lib/sigra/workers/token_cleanup.ex \
  lib/sigra/workers/cleanup_expired_invitations.ex
# => no matches
```

```bash
rg -n "ensure_available!\\(:async_email|ensure_available!\\(:lifecycle_jobs|ensure_available!\\(:bcrypt_migration|ensure_available!\\(:totp_qr|ensure_available!\\(:jwt" lib test
```

The remaining Phase 95 enforcement paths route through `Sigra.OptionalDeps.ensure_available!/2` instead of scattered worker-disappearance guards.

## Docs Alignment

- `README.md` states that optional deps stay optional until the related capability is enabled and points readers to `mix sigra.doctor`.
- `guides/introduction/troubleshooting-install.md` now routes optional-dep diagnosis through `mix sigra.doctor`.
- `guides/recipes/deployment.md` now states that `delivery_mode: :auto` may stay synchronous, while explicit async or queue-backed delivery requires Oban.
- `95-VALIDATION.md` now matches the actual `95-01` through `95-04` plan/task map, includes all nine rows, and closes without a human-only verification loop.

## Verdict

Phase 95 closes with worker visibility preserved, targeted dep-off CI proof added, maintainer/adopter docs aligned to `mix sigra.doctor`, and verification evidence recorded against roadmap criterion 5.
