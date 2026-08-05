---
schema_version: 1
open_count: 3
waived_count: 0
fixed_count: 0
total_count: 3
last_updated: 2026-08-05T14:57:01.781Z
---

# Broken Windows Ledger

> Cross-phase defect register. `/gsd-ship` blocks while `open_count > 0`.
> Waive with `gsd-tools windows waive <id> "<reason>"` (reason required).
> Mark fixed with `gsd-tools windows fixed <id>`.

| id | phase | kind | file | line | description | status | reason | recorded_at | resolved_at |
|----|-------|------|------|------|-------------|--------|--------|-------------|-------------|
| 1 | 234 | unrun-verify | test/sigra/install/golden_diff_test.exs | 54 | Golden/idempotency verifier exits 1: generated config/dev.exs differs from committed fixture | open |  | 2026-08-02T01:35:01.034Z |  |
| 2 | 234 | deviation | .planning/phases/234-hygiene-supply-chain-and-contributor-dx/234-EVIDENCE.json |  | Dependabot job-log evidence remains failed because authenticated browser capture is unavailable | open |  | 2026-08-02T01:35:01.099Z |  |
| 3 | 238 | unrun-verify | scripts/ci/generated-auth-runtime-proof.sh |  | Exact --probe-oauth runtime verification requires CI PostgreSQL and Chromium | open |  | 2026-08-05T14:57:01.781Z |  |

````json
[
  {
    "id": 1,
    "kind": "unrun-verify",
    "phase": "234",
    "file": "test/sigra/install/golden_diff_test.exs",
    "line": 54,
    "description": "Golden/idempotency verifier exits 1: generated config/dev.exs differs from committed fixture",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-02T01:35:01.034Z",
    "resolved_at": null
  },
  {
    "id": 2,
    "kind": "deviation",
    "phase": "234",
    "file": ".planning/phases/234-hygiene-supply-chain-and-contributor-dx/234-EVIDENCE.json",
    "line": null,
    "description": "Dependabot job-log evidence remains failed because authenticated browser capture is unavailable",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-02T01:35:01.099Z",
    "resolved_at": null
  },
  {
    "id": 3,
    "kind": "unrun-verify",
    "phase": "238",
    "file": "scripts/ci/generated-auth-runtime-proof.sh",
    "line": null,
    "description": "Exact --probe-oauth runtime verification requires CI PostgreSQL and Chromium",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-05T14:57:01.781Z",
    "resolved_at": null
  }
]
````
