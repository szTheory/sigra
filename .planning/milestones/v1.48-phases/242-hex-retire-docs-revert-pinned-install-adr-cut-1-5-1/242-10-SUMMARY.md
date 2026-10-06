---
phase: 242-hex-retire-docs-revert-pinned-install-adr-cut-1-5-1
plan: "10"
subsystem: release-automation
tags: [github-actions, hex, remediation, ci]
requirements-completed: []
status: halted
completed: 2026-09-22
---

# Phase 242 Plan 10 Summary

**Halted after the one explicitly authorized corrected remediation dispatch failed. No retry, source repair, evidence promotion, todo move, or downstream-plan execution was performed.**

## Readiness and historical preservation

- Restored `242-03-SUMMARY.md` byte-for-byte from `ee61cfb3`; its SHA-256 is `f9659699640d7f145a46289b17da6313d6c30158eb47424e40609bd5febaab97` and its historical `status: halted` remains unchanged.
- Fetched `origin/main` at `0826a06d48b638c84af5db8984a1e8739f89cfaa` before dispatch.
- Exported the workflow and p22 contract from that exact SHA. The corrected fixed-target `--message` command was present and p22 passed.
- No pre-existing `workflow_dispatch` run existed at that SHA; the prior failed run `35554955828` targeted `154dd679…` and was retained only as historical evidence.

## Single invocation record

- Invoked exactly once: run [`35709493996`](https://github.com/szTheory/sigra/actions/runs/35709493996), event `workflow_dispatch`, branch `main`, SHA `0826a06d48b638c84af5db8984a1e8739f89cfaa`.
- REST core budget was 5,000 before the sole 60-second watcher.
- The one watcher reported completed failure. One structured summary was fetched; no success logs or artifact were accessed.

## Sanitized failure classification

- Job: `Retire invalid release and revert its docs`.
- Failed step: `Revert only sigra 1.20.0 docs after observed state`.
- The failed step could not continue because project dependencies were unavailable, then classified the HexDocs root as `unavailable_or_ambiguous` rather than `current_1_5`.
- One allowed public Hex observation after completion showed no `1.20.0` retirement entry. The run therefore did not yield the required public remediation receipt or proof that the intended retirement/docs state landed.

## Boundary respected

This addendum consumed its one workflow invocation. A repair, any further registry mutation, or another dispatch requires a new explicit plan and authorization. `242-HEX-REMEDIATION-EVIDENCE.json` was not created or promoted; the retirement todo remains pending; Plans 04–09 were not started.
