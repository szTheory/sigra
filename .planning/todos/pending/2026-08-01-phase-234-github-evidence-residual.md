# Phase 234 GitHub evidence residual

**Status:** Open — DX-03 is not complete.

## Dependabot job-log authentication boundary

The exact Phase 234 Dependabot configuration was confirmed on immutable main SHA
`fe33154088053ce9ccc0e9301348a2841c87745c` (decoded-content SHA-256
`a6894c6df4edc32b84883c7c9ffab761266c4078a1383ca813f6286c3fbf44e0`). The
`gh` account has repository admin permission, but the deterministic isolated browser
has no authenticated GitHub session. GitHub therefore presented the sign-in surface at
the Dependabot job-log route, rather than exposing `Recent update jobs` for the three
configured tuples:

- `github-actions:/`
- `mix:/`
- `npm:/test/example/priv/playwright`

No successful job log, job ID, timestamp, associated PR, error summary, or full-log
URL was observed. The absence of a Dependabot PR is not evidence of processing.

**Owner:** repository maintainer with a GitHub browser session that has write access.

## Revalidation attempt — 2026-08-02T02:29:42Z

`gh auth status` confirmed the `szTheory` account is active with repository access, and the
single pre-collection `gh api rate_limit` check reported REST core `remaining: 4121` of
`5000` (above the 250-request floor). The bounded deterministic browser then navigated once
to the job-log surface and reached GitHub's sign-in form. No session state, cookies, page
content, or logs were saved. This is an authentication boundary, not successful service
processing; the three failed evidence rows remain authoritative until a maintainer-provided
authenticated browser session exposes the exact job receipts.

**Recheck:** Open <https://github.com/szTheory/sigra/network/updates>, use Insights →
Dependency graph → Dependabot, and record `Recent update jobs` plus full-log URLs for
each tuple in `234-EVIDENCE.json`. Then run:

```bash
mix test test/sigra/planning/phase_234_dependabot_contract_test.exs test/sigra/planning/phase_234_evidence_contract_test.exs --only dependabot
```

## Authenticated revalidation — 2026-08-02T02:40:44Z

The persistent deterministic GitHub session was authenticated and the single required
pre-collection REST core check reported `4988/5000`, so authentication and rate limits
no longer block collection. The latest `github-actions:/` version-update job,
`1499842989`, was successfully processed with no PRs affected. Collection then halted on
the latest `mix:/` version-update job, `1499842991`: GitHub reported
`Dependabot cannot open any more pull requests` because the configured open-PR limit of
five was exceeded. Its sanitized diagnostic receipt hash is
`4ffa5797fc16b54bea8dd69d9905dd0d8c879f2c300e0f76014a81f0ba1eb3a0`.

This is a deterministic service processing error, not a transport failure; it was not
retried. No raw job logs, authenticated HTML, cookies, credentials, or browser state were
persisted. Dependabot evidence remains failed and DX-03 remains open because the required
three successful exact-tuple receipts cannot be validated. After Dependabot can process
the Mix update, re-run the bounded browser collection from the root Dependabot page and
validate all three receipts with the command above.
