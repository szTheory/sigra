# All 108 post-fix integration tests passed

Candidate: `a87664733`. Actual evidence: `b42a8ad89816a8f81c21d067fa8c66a0ddc26c34`.

| Browser group | Passed |
| --- | ---: |
| Admin behavior | 43 |
| Admin checkpoints | 3 |
| Design gallery PR behavior, including setup | 42 |
| Non-admin smoke | 16 |
| Demo showcase | 4 |
| Total | 108 |

Zero retries or skips. Setup through cleanup took 640.7 seconds (10m41s), below the 3600-second total limit. Each group used a fresh seeded app and PostgreSQL 15.19 database. All 10 owned containers were removed. The original Ecto.Queryable error did not recur. No CI launch or GitHub request.

`RESULT.json` independently checks the browser reports, source, tools, server logs and cleanup. `runtime-output/result.json` is the unchanged driver result. All 27 attachments referenced by the browser reports are retained. Authentication values were redacted from ten server/setup logs; browser reports and registration-flow counts are unchanged. Original and retained hashes are in `log-redaction.json`; the review before redaction is retained separately.

Approval `55324020c` and reservation `26ed7517c` are consumed. No extra runtime invocation is authorized. Earlier spent and expired allowances remain unchanged. These local x64-emulated runs used fresh seeded databases; they do not reconstruct the historical hosted schedule or database snapshot.

The fix, nine targeted repeats and ordinary browser integration are complete. CIREL-01 and Phase 253 still need checks for delayed/missing connections, account isolation and failure traces, followed by whole-phase verification. CIREL-02 stays complete.

Next: `$gsd-debug continue phase253-registration-timeout` to review and prepare those remaining checks offline. No user action is needed for preparation. Do not rerun this completed bundle.
