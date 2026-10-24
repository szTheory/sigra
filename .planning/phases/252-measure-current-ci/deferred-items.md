# Plan 252-05 Deferred Items

- `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix ci` exits 2 after six existing `Sigra.Audit.Forwarders.ThreadlineTest` cases fail because `Sigra.Audit.Forwarders.Threadline.attach/1` is unavailable during the main suite. The separate dependency-off group passes (65 tests, 0 failures). See `252-05-MIX-CI-DIAGNOSTIC.json`. These failures are outside Plan 252-05's owned workflow measurement and replay code.
- Hosted producing-PR artifact proof is pending Plan 252-06. This plan did not dispatch duplicate hosted CI or claim browser selections passed.

## Automated resolution

- The six Threadline failures were resolved on 2026-10-12 by force recompiling the local library after the dependency-off build had omitted its optional forwarder. No source changes were needed. The six focused tests passed and the full `mix ci` command exited 0. The original failed diagnostic remains unchanged; see `252-05-INTEGRATION-RECHECK.json`.
- Hosted proof is still pending Plan 252-06.
