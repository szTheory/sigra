# Plan 252-05 Deferred Items

- `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix ci` exits 2 after six existing `Sigra.Audit.Forwarders.ThreadlineTest` cases fail because `Sigra.Audit.Forwarders.Threadline.attach/1` is unavailable during the main suite. The separate dependency-off group passes (65 tests, 0 failures). See `252-05-MIX-CI-DIAGNOSTIC.json`. These failures are outside Plan 252-05's owned workflow measurement and replay code.
- Hosted producing-PR artifact proof is pending Plan 252-06. This plan did not dispatch duplicate hosted CI or claim browser selections passed.
