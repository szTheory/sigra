# SEED-4 — OAuth callback + strategy contracts (machine closure)

## Library tests (merge-blocking `library_tests`)

- `test/sigra/oauth/oauth_test.exs` — MockStrategy authorize URL, state, callback
  handling without live HTTP to Google.
- `test/sigra/oauth/callback_test.exs`, `auth_integration_test.exs`, etc. as wired
  in the suite.
- `test/sigra/oauth/assent_oidc_contract_test.exs` — `Assent.Strategy.OIDC`
  present for stand-in IdP configuration.

## Live Google UX

See `waiver.md` in this directory for the **residual** live-consent path and
**compensating** automation.
