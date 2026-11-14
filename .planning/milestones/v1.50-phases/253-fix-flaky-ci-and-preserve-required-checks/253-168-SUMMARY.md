---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "168"
status: complete
gap_closure: true
requirements: [CIREL-02]
requirements-completed: []
key-files:
  created:
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-PUBLICATION-R13.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-FREEZE-R13.json
  modified: []
---

# Plan168: local R13 publication and freeze completed

Both exact automated task blocks ended VERIFY-EXIT0. Both offline gates passed on the committed freeze with r8-r12 seeded and unchanged; preflight7 and the3-page check_runs read in the expected mode form. The independent audit suite passed66 tests in44.154seconds. No GitHub request, publication, browser launch,179 replay or renewed budget. CIREL-01 remains partial_not_reproduced; CIREL-02 unaccepted; phase verification not_started.

The source is c17ae6a0b1dbcd4f53362407c1f1d1e1128da519; server parent09df342a82e03c3d5d40173c912b70e827f7eadc equals the preserved MAIN-FETCH-R12 and current local origin/main. The1-day deadline control passed at4/10 pages; the20-day negative control failed at15/10. V3 verified the original179 receipt without replaying its acceptance. Shared inputs retained their exact starting bytes throughout both tasks.

Task commits:1b8c4a2d3(manifest alone),eeb06f8a5(freeze alone). Projection17/22 requests,0/10 binary blobs, largest tree body2093852/2097152bytes(3300bytes left). All tree bodies: [2093852, 2090083, 1528292, 17686]. Product tree parity is unchanged. Candidate is a direct child of the recorded main and merge preflight is clean. Both new identities and section digests passed the full earlier-value controls; the old approvals were refused against R13 and the positive old-freeze approval control passed. No committed HTTP ledger names an R13 ref.

## Identities and measurements

```json
{
  "source_commit": "c17ae6a0b1dbcd4f53362407c1f1d1e1128da519",
  "shared_start": {
    ".planning/config.json": {
      "sha256": "225737694e79b502993ffa4a64a8e437d758711432aca20da8caa18ef3e52f7c",
      "bytes": 1821
    },
    ".planning/state.json": {
      "sha256": "78ca518d97f69c9fa8299fb44053ef362c9f510622a0f757e7dc3a0237517975",
      "bytes": 112610
    },
    ".planning/STATE.md": {
      "sha256": "540ede4b8d6d3f65b3d3557e3933ca4bfa92d0fc235f94067c64fcf085c50925",
      "bytes": 32829
    },
    ".planning/HANDOFF.json": {
      "sha256": "b8bd1c6d54415a296b3e30e7df474ef383cb5504ad8a684dc91df93e178689e7",
      "bytes": 182286
    }
  },
  "publication_sha256": "139d933ab9351b1827a8c69fbd49bd44fd17d41e5e48f22a209cf63a31640f83",
  "freeze_sha256": "2a9b2415e4c9545252817ec3b299a66b76247ef4774b087be97faa4e0a578629",
  "product_tree_parity": {
    "candidate_product_files": 1480,
    "candidate_product_tree": "5b754d0dbc773fb564fd26008e2f31fde94615ca",
    "parent_product_tree": "817de2441c7b03dff93cfff89296c9c2f345d289",
    "same_paths_modes_blobs": true,
    "source_product_files": 1480,
    "source_product_tree": "5b754d0dbc773fb564fd26008e2f31fde94615ca"
  },
  "identity": {
    "candidate_helper_commit": "d38f647ce573653a242fb42d0c5826aab92e5ed0",
    "candidate_ref": "refs/heads/gsd/253-replan-r13-candidate",
    "candidate_tree_sha": "b5dbdac1ebe21637865c2156116503b4f84bf58a",
    "docs_base_commit": "ac2aa18645607635032741118a8d4a9d074ed948",
    "docs_head_commit": "afcbe210af6b2773e395e54c018070fce8cbadbb",
    "fixture_ref": "refs/heads/gsd/253-replan-r13-fixture",
    "fixture_tree_sha": "6f2198146ef5cc684775f08244001ee5132f0710",
    "fixture_workflow_blob": "f4c9e2f23be6af58af3ae257579ca6d935251b56",
    "fixture_workflow_commit": "212a52365a6d0d413f9026678718610782ff50a9",
    "old_failed_epoch": 1791909792,
    "old_failed_halt_seconds": 34,
    "old_failed_run_id": "38347679431",
    "old_known_commands": 3,
    "server_parent_sha": "09df342a82e03c3d5d40173c912b70e827f7eadc",
    "workflow_path": ".github/workflows/ci.yml"
  },
  "section_sha256": {
    "canary": "df4ae86dcfd18d58a6fe9e172349edc7c299cbffddf1514a28f5a59fe45ddcd9",
    "docs_and_prs": "7a059033966da717d7c4b8e635610bf1cca532558bc6a02abbd196880b1c16a9"
  },
  "outward_actions": {
    "canary": {
      "actions": [
        {
          "action": "publish_git_objects",
          "candidate_commit": "d38f647ce573653a242fb42d0c5826aab92e5ed0",
          "category": "publication",
          "fixture_commit": "212a52365a6d0d413f9026678718610782ff50a9",
          "manifest": "bound_documents.publication_manifest",
          "max_requests": 24
        },
        {
          "action": "create_ref",
          "ref": "refs/heads/gsd/253-replan-r13-candidate",
          "sha": "d38f647ce573653a242fb42d0c5826aab92e5ed0"
        },
        {
          "action": "create_ref",
          "ref": "refs/heads/gsd/253-replan-r13-fixture",
          "sha": "212a52365a6d0d413f9026678718610782ff50a9"
        },
        {
          "action": "workflow_dispatch",
          "inputs": {
            "candidate_sha": "d38f647ce573653a242fb42d0c5826aab92e5ed0",
            "fixture_blob": "f4c9e2f23be6af58af3ae257579ca6d935251b56",
            "fixture_sha": "212a52365a6d0d413f9026678718610782ff50a9",
            "scenario": "full-pass"
          },
          "ref": "gsd/253-replan-r13-fixture",
          "workflow_id": 259268962
        },
        {
          "action": "workflow_dispatch",
          "inputs": {
            "candidate_sha": "d38f647ce573653a242fb42d0c5826aab92e5ed0",
            "fixture_blob": "f4c9e2f23be6af58af3ae257579ca6d935251b56",
            "fixture_sha": "212a52365a6d0d413f9026678718610782ff50a9",
            "scenario": "docs-only"
          },
          "ref": "gsd/253-replan-r13-fixture",
          "workflow_id": 259268962
        },
        {
          "action": "workflow_dispatch",
          "inputs": {
            "candidate_sha": "d38f647ce573653a242fb42d0c5826aab92e5ed0",
            "fixture_blob": "f4c9e2f23be6af58af3ae257579ca6d935251b56",
            "fixture_sha": "212a52365a6d0d413f9026678718610782ff50a9",
            "scenario": "actual-failure"
          },
          "ref": "gsd/253-replan-r13-fixture",
          "workflow_id": 259268962
        },
        {
          "action": "workflow_dispatch",
          "inputs": {
            "candidate_sha": "d38f647ce573653a242fb42d0c5826aab92e5ed0",
            "fixture_blob": "f4c9e2f23be6af58af3ae257579ca6d935251b56",
            "fixture_sha": "212a52365a6d0d413f9026678718610782ff50a9",
            "scenario": "missing-seam"
          },
          "ref": "gsd/253-replan-r13-fixture",
          "workflow_id": 259268962
        },
        {
          "action": "workflow_dispatch",
          "inputs": {
            "candidate_sha": "d38f647ce573653a242fb42d0c5826aab92e5ed0",
            "fixture_blob": "f4c9e2f23be6af58af3ae257579ca6d935251b56",
            "fixture_sha": "212a52365a6d0d413f9026678718610782ff50a9",
            "scenario": "unexpected-skip"
          },
          "ref": "gsd/253-replan-r13-fixture",
          "workflow_id": 259268962
        },
        {
          "action": "workflow_dispatch",
          "inputs": {
            "candidate_sha": "d38f647ce573653a242fb42d0c5826aab92e5ed0",
            "fixture_blob": "f4c9e2f23be6af58af3ae257579ca6d935251b56",
            "fixture_sha": "212a52365a6d0d413f9026678718610782ff50a9",
            "scenario": "cancelled"
          },
          "ref": "gsd/253-replan-r13-fixture",
          "workflow_id": 259268962
        },
        {
          "action": "cancel_run",
          "max": 1,
          "run_identity": {
            "display_title_prefix": "Phase 253 Gate Canary / cancelled /",
            "event": "workflow_dispatch",
            "head_branch": "gsd/253-replan-r13-fixture",
            "head_sha": "212a52365a6d0d413f9026678718610782ff50a9",
            "workflow_id": 259268962
          },
          "scenario": "cancelled"
        },
        {
          "action": "workflow_dispatch",
          "inputs": {
            "candidate_sha": "d38f647ce573653a242fb42d0c5826aab92e5ed0",
            "fixture_blob": "f4c9e2f23be6af58af3ae257579ca6d935251b56",
            "fixture_sha": "212a52365a6d0d413f9026678718610782ff50a9",
            "matrix_evidence": "compact gzip+base64 receipts of the six verified sources; digest recorded at dispatch",
            "scenario": "verifier"
          },
          "ref": "gsd/253-replan-r13-fixture",
          "workflow_id": 259268962
        }
      ],
      "max_requests": 117,
      "prohibited": [
        "rerun",
        "merge",
        "auto_merge",
        "push",
        "force_update",
        "delete_ref",
        "rule_change",
        "release",
        "tag"
      ],
      "reruns": 0
    },
    "docs_and_prs": {
      "actions": [
        {
          "action": "publish_docs_objects",
          "category": "docs_publication",
          "docs_base_commit": "ac2aa18645607635032741118a8d4a9d074ed948",
          "docs_head_commit": "afcbe210af6b2773e395e54c018070fce8cbadbb",
          "max_requests": 14,
          "refs": [
            {
              "ref": "refs/heads/gsd/253-replan-docs-base",
              "sha": "ac2aa18645607635032741118a8d4a9d074ed948"
            },
            {
              "ref": "refs/heads/gsd/253-replan-docs-head",
              "sha": "afcbe210af6b2773e395e54c018070fce8cbadbb"
            }
          ]
        },
        {
          "action": "pr_create",
          "base": "main",
          "draft": true,
          "family": "normal",
          "head": "gsd/253-replan-r13-candidate"
        },
        {
          "action": "pr_create",
          "base": "gsd/253-replan-docs-base",
          "draft": true,
          "family": "docs-only",
          "head": "gsd/253-replan-docs-head"
        }
      ],
      "max_requests": 120,
      "prohibited": [
        "rerun",
        "merge",
        "auto_merge",
        "push",
        "force_update",
        "delete_ref",
        "rule_change",
        "release",
        "tag"
      ],
      "reruns": 0
    }
  },
  "gate_reports": {
    "hermetic": {
      "status": "passed",
      "mode": "hermetic",
      "synthetic": true,
      "requests_by_category": {
        "artifact_downloads": 10,
        "artifact_metadata": 6,
        "attempt_jobs": 7,
        "cancellation": 1,
        "dispatch": 7,
        "failure_logs": 6,
        "pre_watch_rate": 7,
        "preflight": 7,
        "publication": 19,
        "run_discovery": 7,
        "terminal_polls": 18
      },
      "total_requests": null,
      "paginated_reads": [
        {
          "next_link_forms": [
            "repos"
          ],
          "pages": 3,
          "route": "check_runs"
        }
      ],
      "live_hops": [
        {
          "category": "artifact_downloads",
          "hop_ordinal": 1,
          "host": "localhost",
          "route": "artifact_zip",
          "status": 200
        },
        {
          "category": "artifact_downloads",
          "hop_ordinal": 1,
          "host": "localhost",
          "route": "artifact_zip",
          "status": 200
        },
        {
          "category": "failure_logs",
          "hop_ordinal": 1,
          "host": "localhost",
          "route": "run_logs",
          "status": 200
        },
        {
          "category": "artifact_downloads",
          "hop_ordinal": 1,
          "host": "localhost",
          "route": "artifact_zip",
          "status": 200
        },
        {
          "category": "failure_logs",
          "hop_ordinal": 1,
          "host": "localhost",
          "route": "run_logs",
          "status": 200
        },
        {
          "category": "artifact_downloads",
          "hop_ordinal": 1,
          "host": "localhost",
          "route": "artifact_zip",
          "status": 200
        },
        {
          "category": "failure_logs",
          "hop_ordinal": 1,
          "host": "localhost",
          "route": "run_logs",
          "status": 200
        },
        {
          "category": "artifact_downloads",
          "hop_ordinal": 1,
          "host": "localhost",
          "route": "artifact_zip",
          "status": 200
        }
      ],
      "response_shape": {
        "artifacts_checked": 33,
        "cancelled_reference": {
          ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-PROBE-EVIDENCE-R11-PROBE.json": "6980e6e58cf086d77bc1b7583d93ae1c46703e523baeb6c01a341046572a82de",
          ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-PROBE-HTTP-LEDGER-R11-PROBE.json": "79e8b4d320c410e9179aa610a614b8c4fa97d4aada692e004484134b59e10018"
        },
        "cancelled_run_checked": true,
        "jobs_checked": 45,
        "log_reference": {
          ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-HTTP-LEDGER-R10.json": "3b0dd91e85612a973012bbcdadcc925afa3b1dc5cbe4b95a1c5349c6ed226c33",
          ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-PROBE-BODIES-R11-PROBE.json": "3b8d5bf4cc0af7fcf302fe3897eaeef3e2219de0822a98d871032c9f4b6c9523",
          ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-PROBE-EVIDENCE-R11-PROBE.json": "6980e6e58cf086d77bc1b7583d93ae1c46703e523baeb6c01a341046572a82de",
          ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-PROBE-HTTP-LEDGER-R11-PROBE.json": "79e8b4d320c410e9179aa610a614b8c4fa97d4aada692e004484134b59e10018"
        },
        "mismatch_count": 0,
        "mismatches": [],
        "ok": true,
        "reference": {
          "path": ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-HTTP-LEDGER-R9.json",
          "sequences": {
            "artifacts": 29,
            "jobs": 28,
            "listing": 25,
            "run": 27
          },
          "sha256": "9c3d7659981a3be0e2592d09d670e4ab0dfc8084771a8ce51d8d1075a5f34e01"
        },
        "run_logs_chains_checked": 3,
        "run_logs_checked": true,
        "runs_checked": 46,
        "scenarios_checked": [
          "actual-failure",
          "cancelled",
          "docs-only",
          "full-pass",
          "missing-seam",
          "unexpected-skip",
          "verifier"
        ],
        "steps_checked": 177,
        "verifier_run_checked": true
      },
      "authorization": {
        "api_with": 0,
        "api_without": 0,
        "blob_with": 0,
        "results_receiver_with": 0
      }
    },
    "live-policy": {
      "status": "passed",
      "mode": "live-policy",
      "synthetic": true,
      "requests_by_category": {
        "artifact_downloads": 10,
        "artifact_metadata": 6,
        "attempt_jobs": 7,
        "cancellation": 1,
        "dispatch": 7,
        "failure_logs": 6,
        "pre_watch_rate": 7,
        "preflight": 7,
        "publication": 19,
        "run_discovery": 7,
        "terminal_polls": 18
      },
      "total_requests": null,
      "paginated_reads": [
        {
          "next_link_forms": [
            "repositories-id"
          ],
          "pages": 3,
          "route": "check_runs"
        }
      ],
      "live_hops": [
        {
          "category": "artifact_downloads",
          "hop_ordinal": 1,
          "host": "productionresultssa17.blob.core.windows.net",
          "route": "artifact_zip",
          "status": 200
        },
        {
          "category": "artifact_downloads",
          "hop_ordinal": 1,
          "host": "productionresultssa17.blob.core.windows.net",
          "route": "artifact_zip",
          "status": 200
        },
        {
          "category": "failure_logs",
          "hop_ordinal": 1,
          "host": "results-receiver.actions.githubusercontent.com",
          "route": "run_logs",
          "status": 200
        },
        {
          "category": "artifact_downloads",
          "hop_ordinal": 1,
          "host": "productionresultssa17.blob.core.windows.net",
          "route": "artifact_zip",
          "status": 200
        },
        {
          "category": "failure_logs",
          "hop_ordinal": 1,
          "host": "results-receiver.actions.githubusercontent.com",
          "route": "run_logs",
          "status": 200
        },
        {
          "category": "artifact_downloads",
          "hop_ordinal": 1,
          "host": "productionresultssa17.blob.core.windows.net",
          "route": "artifact_zip",
          "status": 200
        },
        {
          "category": "failure_logs",
          "hop_ordinal": 1,
          "host": "results-receiver.actions.githubusercontent.com",
          "route": "run_logs",
          "status": 200
        },
        {
          "category": "artifact_downloads",
          "hop_ordinal": 1,
          "host": "productionresultssa17.blob.core.windows.net",
          "route": "artifact_zip",
          "status": 200
        }
      ],
      "response_shape": {
        "artifacts_checked": 33,
        "cancelled_reference": {
          ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-PROBE-EVIDENCE-R11-PROBE.json": "6980e6e58cf086d77bc1b7583d93ae1c46703e523baeb6c01a341046572a82de",
          ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-PROBE-HTTP-LEDGER-R11-PROBE.json": "79e8b4d320c410e9179aa610a614b8c4fa97d4aada692e004484134b59e10018"
        },
        "cancelled_run_checked": true,
        "jobs_checked": 45,
        "log_reference": {
          ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-HTTP-LEDGER-R10.json": "3b0dd91e85612a973012bbcdadcc925afa3b1dc5cbe4b95a1c5349c6ed226c33",
          ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-PROBE-BODIES-R11-PROBE.json": "3b8d5bf4cc0af7fcf302fe3897eaeef3e2219de0822a98d871032c9f4b6c9523",
          ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-PROBE-EVIDENCE-R11-PROBE.json": "6980e6e58cf086d77bc1b7583d93ae1c46703e523baeb6c01a341046572a82de",
          ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-PROBE-HTTP-LEDGER-R11-PROBE.json": "79e8b4d320c410e9179aa610a614b8c4fa97d4aada692e004484134b59e10018"
        },
        "mismatch_count": 0,
        "mismatches": [],
        "ok": true,
        "reference": {
          "path": ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-HTTP-LEDGER-R9.json",
          "sequences": {
            "artifacts": 29,
            "jobs": 28,
            "listing": 25,
            "run": 27
          },
          "sha256": "9c3d7659981a3be0e2592d09d670e4ab0dfc8084771a8ce51d8d1075a5f34e01"
        },
        "run_logs_chains_checked": 3,
        "run_logs_checked": true,
        "runs_checked": 46,
        "scenarios_checked": [
          "actual-failure",
          "cancelled",
          "docs-only",
          "full-pass",
          "missing-seam",
          "unexpected-skip",
          "verifier"
        ],
        "steps_checked": 177,
        "verifier_run_checked": true
      },
      "authorization": {
        "api_with": 87,
        "api_without": 0,
        "blob_with": 0,
        "results_receiver_with": 0
      }
    }
  },
  "task2_start": "2026-10-21T16:55:19Z",
  "task2_end": "2026-10-21T17:01:47Z",
  "power": "Now drawing from 'AC Power'"
}
```

## Evidence and deviations

Exact commands, stdout/stderr, reports and inputs are retained in refs/gsd/phase253-168-local-execution at a85f1e19f34b13d5ca7fd4eb7dffc0aeea282a7c under evidence/phase253/plan168/. All17 files were read back exactly before this summary. Task2's runner copied the two direct reports immediately before the original rm deleted its temporary outputs; the original automated body and every original rm still ran. Manifest preparation first wrote an external temporary file, checked its limits, then copied its exact bytes into the canonical path before its separate commit. No acceptance condition was relaxed.

## Next work

Continue directly to existing Plan169, local reconciliation implementation. Do not route a completed repair back to a status command when authorized work is ready. Keep r8-r12 refs and draft PR337 untouched. Hosted Plans170/171 remain prohibited by the user's no-CI instruction. Next scoped command: $gsd-execute-phase253 --gaps-only --wave5 (normal spaced spelling in current handoff). Whole-phase verification remains not_started.
