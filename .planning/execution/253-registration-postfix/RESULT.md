# Nine fresh registration runs passed

Candidate: `a87664733`. Evidence commit: `eb2e23a14cc079a6539d8c037810e543e97c4658`.

- Desktop Chromium:3/3 passed.
- Mobile WebKit:3/3 passed.
- Dark Chromium:3/3 passed.
- Zero retries/skips;226.5seconds from setup through cleanup,below1200seconds.
- Nine new databases/apps/contexts;all18owned containers removed.
- Each run saved registration,inserted one account and submitted the login POST. No original Ecto.Queryable error.
- No CI launch or GitHub request. The approved allowance is consumed;all earlier expired slots remain closed.

`RESULT.json` is the independent read-back of native browser reports and server flow. `runtime-output/result.json` is the unchanged actual driver result. Logs omit authentication values; `log-redaction.json` records original/retained hashes. Native reports are unchanged.

The fix and targeted validation are complete. Normal integration coverage on this fixed source,remaining deterministic-control review and whole-phase verification remain. CIREL-02 is already complete. These local x64-emulated runs do not reproduce the original hosted scheduling or database snapshot.

Next:`$gsd-debug continue phase253-registration-timeout` for offline review/preparation of the smallest missing integration check. No extra runtime action is authorized and no user action is needed for that preparation.
