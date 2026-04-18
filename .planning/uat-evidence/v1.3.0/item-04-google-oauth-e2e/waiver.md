# Waiver — live Google OAuth consent UX (SEED-4 residual)

| Field | Value |
| --- | --- |
| item_id | SEED-4 |
| date | 2026-04-18 |
| owner | Sigra maintainers |
| version_sha_anchor | See `.planning/uat-evidence/v1.3.0/INDEX.md` |
| reason | Live Google developer credentials and consent UX are not available in CI; token refresh against Google is out of scope for merge-blocking automation. |
| residual_risk | Google-specific consent chrome and refresh semantics not exercised end-to-end. |
| compensating_evidence | `test/sigra/oauth/oauth_test.exs` (MockStrategy round-trip), `assent_oidc_contract_test.exs` (OIDC strategy surface), plus `install_smoke` generator wiring for OAuth routes/controllers. |
| compensating | yes — library + install contracts above |
| expiry_or_next_trigger | Revisit before major Assent / OAuth template changes; optional quarterly spot check. |
| link | `./steps.md` |
