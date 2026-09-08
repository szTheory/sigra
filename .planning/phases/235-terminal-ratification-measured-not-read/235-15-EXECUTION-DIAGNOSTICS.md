---
phase: 235-terminal-ratification-measured-not-read
plan: 15
status: continued
blocked_at: null
updated: 2026-09-08T20:12:00Z
---

# Plan 235-15 execution diagnostics

The one permitted readiness refresh completed successfully and is retained in
`235-FAST-01-GAP-CLOSURE-READINESS.json` at commit `196cabe4`.

- Status: `ready`
- Eligible terminal PR runs: `43`
- Endpoint: `2026-09-08T20:00:31Z`
- Pagination: `[1, 2, 3]`, exhausted
- Diagnostics: none
- REST core remaining: `5000`

The hermetic collector contract passed:

```text
capture-fast-01-gap-closure.test: PASS
```

The required Phase 233 ExUnit command initially did not start because the
configured Erlang version is unavailable locally:

```text
MIX_ENV=test mix test test/sigra/planning/phase_233_library_economics_contract_test.exs
erlang 29.0.5
erlang 28.4.1
No version is set for command erl
Consider adding one of the following versions in your config file at /Users/jon/projects/sigra/.tool-versions
```

The repository requests Erlang `28.5`; this machine currently has `28.4.1` and
`29.0.5`. Execution continued with the compatible installed Erlang `28.4.1`
through a process-local `ASDF_ERLANG_VERSION` override. The required contract
then ran 6 tests with 0 failures. The unrelated user edit adding Node.js
`22.14.0` to `.tool-versions` was not changed.

## Dispatch correlation deviation

The pre-dispatch command used `/usr/bin/date`, which is absent on this host, and
the local `origin/main` projection was stale at `10904571ec65baf42e5fc3bae4170eeb87b109fe`.
The one permitted workflow dispatch nevertheless succeeded. Both bounded
pre/post projections contained no matching run, so the production set-difference
selector could not bind the run without weakening its protected-main SHA rule.
No second dispatch occurred.

The run was instead bound to the single dispatch response and its one permitted
post-completion structured summary:

- Run: `34272746647`
- URL: `https://github.com/szTheory/sigra/actions/runs/34272746647`
- Workflow/event/ref: `FAST-01 post-remediation evidence` / `workflow_dispatch` / `main`
- Protected head SHA: `c6580d793710aaeef01a1f34d7000ead9ebcdcd2`
- Created: `2026-09-08T20:05:24Z`
- Conclusion: `success`
- Capture job: `102218162682`, `success`

Before the only watcher, REST core remaining was `5000`. The watcher used the
required 60-second interval, the structured summary was fetched exactly once,
and no failed logs were fetched. The exact artifact, attestation bundle, and
trusted root were then retained. Their offline verification binds the workflow
SHA above and subject digest
`6186f17eae61373f714fda0dd98d4318362de62d7d571d6f05e2e015b26a75ee`.
