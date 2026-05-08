# Plan 101-01 Summary

## Outcome

Completed the library-side Phase 101 query truth fix.

- `Sigra.Admin.Webhooks.Query` now normalizes legacy `status` input into canonical `delivery_state`, joins the latest delivery row in SQL, filters before pagination, and exposes subscription summary counts from the same persisted truth model.
- `Sigra.Admin.Webhooks.Failures` now treats `retrying` as `retry_scheduled` only, keeps `dead_lettered` isolated, and exposes delivery-row backlog counts for the failures surface.
- `test/sigra/admin/webhooks_test.exs` now locks filter-before-pagination, latest-delivery-wins behavior, canonical param normalization, and aligned count semantics across both query modules.

## Verification

- `mix compile --warnings-as-errors`
- `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/admin/webhooks_test.exs --no-color`
