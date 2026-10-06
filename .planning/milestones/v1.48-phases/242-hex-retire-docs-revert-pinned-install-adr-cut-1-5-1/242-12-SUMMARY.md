---
phase: 242-hex-retire-docs-revert-pinned-install-adr-cut-1-5-1
plan: "12"
status: halted
requirements-completed: []
completed: 2026-09-22
---

# Phase 242 Plan 12 Summary

**Halted after the one explicitly authorized workflow dispatch failed during HexDocs root
classification. No redispatch, repair, evidence promotion, todo move, or downstream plan execution
was performed.**

## Immutable preflight record

- Freshly fetched `origin/main`: `b9f67c65a2fe9425baac28e265c678f1cca74cea`.
- The workflow export from that exact SHA passed p22, including the fixed `--message` retire command
  and the credential-free `mix deps.get --check-locked` step before both mutations.
- No prior matching `workflow_dispatch` run existed at that SHA when the zero-count control receipt
  was created.

## One invocation record

- Run [`35714147650`](https://github.com/szTheory/sigra/actions/runs/35714147650), event
  `workflow_dispatch`, branch `main`, SHA `b9f67c65a2fe9425baac28e265c678f1cca74cea`.
- Exactly one invocation and one watcher were used after REST core budget 5,000.
- One structured summary was fetched; no success logs or artifacts were accessed.

## Sanitized failure classification

- Job: `Retire invalid release and revert its docs`.
- Failed step: `HEXDOCS_ROOT classification`.
- The deterministic verifier reported `HexDocs root is unavailable_or_ambiguous, not current_1_5`.
- The one permitted public Hex package observation after completion listed no retirement for version
  `1.20.0`; therefore no validated public remediation receipt exists.

## Boundary respected

Plan 12's dispatch is consumed. Any source repair, registry mutation, or further workflow invocation
requires a newly scoped plan and explicit authorization. Historical Plan 03 and Plan 10 halt records
remain unchanged; `242-HEX-REMEDIATION-EVIDENCE.json` was not promoted and the retirement todo remains
pending.
