# Deferred Items

## 2026-08-12 — Repository-wide test suite historical planning fixtures

`source tmp/db.env && MIX_ENV=test mix test` fails outside Plan 245-05 because
historical Phase 235/236/240/240.3 planning-contract fixtures and evidence files
are absent, and unrelated generated-template/architecture contract assertions no
longer match their sources. The Plan 245 app-session lifecycle, audit, and
concurrency suites pass; no files outside this plan were changed to mask these
pre-existing failures.
