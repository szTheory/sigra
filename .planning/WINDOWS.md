---
schema_version: 1
open_count: 9
waived_count: 0
fixed_count: 0
total_count: 9
last_updated: 2026-08-12T03:03:08.571Z
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
| 4 | 240 | deviation | lib/sigra/install/injector.ex |  | Added a generated rate-limit child injection anchor required to place the Hammer process before Endpoint. | open |  | 2026-08-10T21:59:33.048Z |  |
| 5 | 240 | deviation | test/sigra/install/features/core_test.exs |  | Updated Core invariant counts and supported anchors for the generated rate-limit output. | open |  | 2026-08-10T21:59:33.113Z |  |
| 6 | 240 | deviation | guides/recipes/deployment.md |  | Documentation link target corrected from source .md reference to rendered HTML link for warnings-as-errors docs build. | open |  | 2026-08-10T22:14:21.001Z |  |
| 7 | 240.3 | deviation | scripts/ci/hosted-session-interop-proof.sh |  | First receipt attempt reached all proof layers but did not write evidence because the scoped-path guard was inside the Python heredoc; corrected before an explicitly approved fresh attempt. | open |  | 2026-08-11T17:48:03.145Z |  |
| 8 | 240.3 | unrun-verify | test/example/lib/example_web/live/settings_live.ex | 133 | Example mix precommit remains blocked by the pre-existing /dev/mailbox verified-route warning under warnings-as-errors. | open |  | 2026-08-11T17:48:03.211Z |  |
| 9 | 242 | deviation | test/example/accounts/crosswake_continuations_test.exs | 224 | Pre-existing residual terminal continuation rows prevent the aggregate cleanup-count assertion from passing in the shared local test database. | open |  | 2026-08-12T03:03:08.571Z |  |

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
  },
  {
    "id": 4,
    "kind": "deviation",
    "phase": "240",
    "file": "lib/sigra/install/injector.ex",
    "line": null,
    "description": "Added a generated rate-limit child injection anchor required to place the Hammer process before Endpoint.",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-10T21:59:33.048Z",
    "resolved_at": null
  },
  {
    "id": 5,
    "kind": "deviation",
    "phase": "240",
    "file": "test/sigra/install/features/core_test.exs",
    "line": null,
    "description": "Updated Core invariant counts and supported anchors for the generated rate-limit output.",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-10T21:59:33.113Z",
    "resolved_at": null
  },
  {
    "id": 6,
    "kind": "deviation",
    "phase": "240",
    "file": "guides/recipes/deployment.md",
    "line": null,
    "description": "Documentation link target corrected from source .md reference to rendered HTML link for warnings-as-errors docs build.",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-10T22:14:21.001Z",
    "resolved_at": null
  },
  {
    "id": 7,
    "kind": "deviation",
    "phase": "240.3",
    "file": "scripts/ci/hosted-session-interop-proof.sh",
    "line": null,
    "description": "First receipt attempt reached all proof layers but did not write evidence because the scoped-path guard was inside the Python heredoc; corrected before an explicitly approved fresh attempt.",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-11T17:48:03.145Z",
    "resolved_at": null
  },
  {
    "id": 8,
    "kind": "unrun-verify",
    "phase": "240.3",
    "file": "test/example/lib/example_web/live/settings_live.ex",
    "line": 133,
    "description": "Example mix precommit remains blocked by the pre-existing /dev/mailbox verified-route warning under warnings-as-errors.",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-11T17:48:03.211Z",
    "resolved_at": null
  },
  {
    "id": 9,
    "kind": "deviation",
    "phase": "242",
    "file": "test/example/accounts/crosswake_continuations_test.exs",
    "line": 224,
    "description": "Pre-existing residual terminal continuation rows prevent the aggregate cleanup-count assertion from passing in the shared local test database.",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-12T03:03:08.571Z",
    "resolved_at": null
  }
]
````
