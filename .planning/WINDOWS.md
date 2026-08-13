---
schema_version: 1
open_count: 17
waived_count: 0
fixed_count: 0
total_count: 17
last_updated: 2026-08-13T15:34:54.990Z
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
| 10 | 242 | deviation | scripts/db/up.sh |  | Restored the repository-managed isolated local test database before the focused Crosswake verification.  | open |  | 2026-08-12T15:18:32.959Z |  |
| 11 | 243 | unrun-verify | .planning/phases/243-credential-boundary-and-pipeline-foundation/243-02-SUMMARY.md |  | Full MIX_ENV=test mix ci phase gate was not run because local PostgreSQL is unavailable. | open |  | 2026-08-12T19:42:07.759Z |  |
| 12 | 243 | unrun-verify | test/sigra/planning/phase_238_generated_auth_runtime_proof_test.exs |  | Full MIX_ENV=test mix ci halted before tests on pre-existing mix format violation. | open |  | 2026-08-12T19:55:26.807Z |  |
| 13 | 243 | unrun-verify | test/sigra/install/generated_rate_limit_contract_test.exs |  | Full MIX_ENV=test mix ci halted before tests on pre-existing mix format violation. | open |  | 2026-08-12T19:55:26.902Z |  |
| 14 | 244 | unrun-verify | .planning/phases/244-pat-and-advanced-jwt-truth-repair/244-06-SUMMARY.md |  | mix ci remains blocked by six historical Phase 235/236/239 planning-artifact assertions outside Plan 244-06 | open |  | 2026-08-12T23:48:58.301Z |  |
| 15 | 245 | deviation | lib/sigra/app_session.ex |  | Normalized public revoke audit-constraint failures to a bounded aborted result after rollback. | open |  | 2026-08-13T00:55:47.944Z |  |
| 16 | 246 | deviation | .planning/STATE.md |  | state.advance-plan could not parse the pre-existing plan-position fields | open |  | 2026-08-13T01:46:15.081Z |  |
| 17 | 246 | unrun-verify | test/sigra/install/app_sessions_mfa_session_upgrade_test.exs |  | PostgreSQL-backed generated-host MFA transition evidence remains unrun because 127.0.0.1:53988 refused connections. | open |  | 2026-08-13T15:34:54.990Z |  |

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
  },
  {
    "id": 10,
    "kind": "deviation",
    "phase": "242",
    "file": "scripts/db/up.sh",
    "line": null,
    "description": "Restored the repository-managed isolated local test database before the focused Crosswake verification. ",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-12T15:18:32.959Z",
    "resolved_at": null
  },
  {
    "id": 11,
    "kind": "unrun-verify",
    "phase": "243",
    "file": ".planning/phases/243-credential-boundary-and-pipeline-foundation/243-02-SUMMARY.md",
    "line": null,
    "description": "Full MIX_ENV=test mix ci phase gate was not run because local PostgreSQL is unavailable.",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-12T19:42:07.759Z",
    "resolved_at": null
  },
  {
    "id": 12,
    "kind": "unrun-verify",
    "phase": "243",
    "file": "test/sigra/planning/phase_238_generated_auth_runtime_proof_test.exs",
    "line": null,
    "description": "Full MIX_ENV=test mix ci halted before tests on pre-existing mix format violation.",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-12T19:55:26.807Z",
    "resolved_at": null
  },
  {
    "id": 13,
    "kind": "unrun-verify",
    "phase": "243",
    "file": "test/sigra/install/generated_rate_limit_contract_test.exs",
    "line": null,
    "description": "Full MIX_ENV=test mix ci halted before tests on pre-existing mix format violation.",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-12T19:55:26.902Z",
    "resolved_at": null
  },
  {
    "id": 14,
    "kind": "unrun-verify",
    "phase": "244",
    "file": ".planning/phases/244-pat-and-advanced-jwt-truth-repair/244-06-SUMMARY.md",
    "line": null,
    "description": "mix ci remains blocked by six historical Phase 235/236/239 planning-artifact assertions outside Plan 244-06",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-12T23:48:58.301Z",
    "resolved_at": null
  },
  {
    "id": 15,
    "kind": "deviation",
    "phase": "245",
    "file": "lib/sigra/app_session.ex",
    "line": null,
    "description": "Normalized public revoke audit-constraint failures to a bounded aborted result after rollback.",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-13T00:55:47.944Z",
    "resolved_at": null
  },
  {
    "id": 16,
    "kind": "deviation",
    "phase": "246",
    "file": ".planning/STATE.md",
    "line": null,
    "description": "state.advance-plan could not parse the pre-existing plan-position fields",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-13T01:46:15.081Z",
    "resolved_at": null
  },
  {
    "id": 17,
    "kind": "unrun-verify",
    "phase": "246",
    "file": "test/sigra/install/app_sessions_mfa_session_upgrade_test.exs",
    "line": null,
    "description": "PostgreSQL-backed generated-host MFA transition evidence remains unrun because 127.0.0.1:53988 refused connections.",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-13T15:34:54.990Z",
    "resolved_at": null
  }
]
````
