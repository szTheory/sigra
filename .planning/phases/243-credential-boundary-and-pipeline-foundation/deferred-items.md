# Deferred Items

## 2026-08-12 — Full CI formatting baseline failure

- **Discovered during:** 243-05 full `MIX_ENV=test mix ci` verification.
- **Out of scope:** `test/sigra/planning/phase_238_generated_auth_runtime_proof_test.exs` and `test/sigra/install/generated_rate_limit_contract_test.exs` fail `mix format --check-formatted` before the phase suite runs. Neither file is owned or modified by Plan 243-05.
- **Impact:** The phase-focused credential-boundary suite passed (42 tests, 0 failures), but the full CI gate remains unproven locally. The project-standard PostgreSQL service is also unavailable at `127.0.0.1:53988` for a later full-suite run.
