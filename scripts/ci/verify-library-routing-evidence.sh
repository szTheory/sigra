#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PHASE_DIR="$ROOT/.planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test"
PR="${1:-$PHASE_DIR/235.1-PR-EVIDENCE.json}"
SCAFFOLD="${2:-$PHASE_DIR/235.1-SCAFFOLD-EVIDENCE.json}"

python3 - "$PR" "$SCAFFOLD" <<'PY'
import json, re, sys

def fail(message):
    raise SystemExit("verify-library-routing-evidence: FAIL: " + message)

def load(path):
    try:
        def unique(pairs):
            value = {}
            for key, item in pairs:
                if key in value:
                    fail(f"duplicate key {key!r} in {path}")
                value[key] = item
            return value
        with open(path, "r", encoding="utf-8") as handle:
            return json.load(handle, object_pairs_hook=unique)
    except (OSError, json.JSONDecodeError) as error:
        fail(f"could not read {path}: {error}")

def keys(value, expected, label):
    if not isinstance(value, dict) or set(value) != set(expected):
        fail(f"{label} exact keys")

def integer(value):
    return isinstance(value, int) and not isinstance(value, bool)

def digest(value, length):
    return isinstance(value, str) and re.fullmatch(f"[0-9a-f]{{{length}}}", value) is not None

def forbid_authority(value):
    if isinstance(value, dict):
        for key, item in value.items():
            # The retired names may appear only as values in the required negative ledger.
            if key in {"install_not_dominant", "comparable", "verdict", "pass", "passed"}:
                fail(f"forbidden producer-owned authority key: {key}")
            forbid_authority(item)
    elif isinstance(value, list):
        for item in value:
            forbid_authority(item)

rate = "gh api rate_limit --jq '.resources.core | {remaining,reset}'"
summary_fields = "databaseId,event,headSha,conclusion,attempt,url,jobs"
aggregate_sha = "04308ef8fb56acc65c5730630e1fd3e926da6804068db07f6f15636c2a0890cb"
pr = load(sys.argv[1])
scaffold = load(sys.argv[2])
forbid_authority(pr)
forbid_authority(scaffold)

keys(pr, ["schema_version", "repository", "pr", "run", "owner", "aggregate", "artifacts", "partitions", "protected_invariants", "commands", "supersession"], "PR")
if pr["schema_version"] != "sigra.library-partitions-evidence/v1" or pr["repository"] != "szTheory/sigra": fail("PR identity")
keys(pr["pr"], ["number"], "PR number")
if pr["pr"]["number"] != 234: fail("PR number")
keys(pr["run"], ["id", "url", "event", "attempt", "head_sha", "conclusion"], "PR run")
run = pr["run"]
if not integer(run["id"]) or run["id"] <= 0 or run["event"] != "pull_request" or run["attempt"] != 1 or run["conclusion"] != "success" or not digest(run["head_sha"], 40): fail("PR run provenance")
if run["url"] != f"https://github.com/szTheory/sigra/actions/runs/{run['id']}": fail("PR run URL")
for label, job, name in [("owner", pr["owner"], "Library tests shard"), ("aggregate", pr["aggregate"], "Library tests")]:
    keys(job, ["id", "name", "status", "conclusion", "skipped"], f"PR {label}")
    if not integer(job["id"]) or job["id"] <= 0 or job["name"] != name or job["status"] != "completed" or job["conclusion"] != "success" or job["skipped"] is not False: fail(f"PR {label} state")
if pr["owner"]["id"] == pr["aggregate"]["id"]: fail("PR job IDs")

expected_pr_artifacts = [
    (f"library-partitions-{run['id']}-1", "sigra-library-partitions.json"),
    (f"library-partition-1-timings-{run['id']}-1", "sigra-library-1-timings.json"),
    (f"library-partition-2-timings-{run['id']}-1", "sigra-library-2-timings.json"),
]
if not isinstance(pr["artifacts"], list) or len(pr["artifacts"]) != 3: fail("PR artifact count")
ids = []
for artifact, (name, filename) in zip(pr["artifacts"], expected_pr_artifacts):
    keys(artifact, ["id", "name", "file", "sha256"], "PR artifact")
    if not integer(artifact["id"]) or artifact["id"] <= 0 or artifact["name"] != name or artifact["file"] != filename or not digest(artifact["sha256"], 64): fail("PR artifact identity")
    ids.append(artifact["id"])
if len(set(ids)) != 3: fail("PR artifact ID uniqueness")

parts = pr["partitions"]
keys(parts, ["execution_mode", "ordinary_universe_count", "manifest_counts", "test_counts", "durations_ms", "conclusions", "exit_statuses"], "partitions")
if parts["execution_mode"] != "sequential": fail("partition execution mode")
for label in ["manifest_counts", "test_counts", "durations_ms"]:
    if not isinstance(parts[label], list) or len(parts[label]) != 2 or not all(integer(v) and v > 0 for v in parts[label]): fail(f"partition {label}")
if not integer(parts["ordinary_universe_count"]) or sum(parts["manifest_counts"]) != parts["ordinary_universe_count"]: fail("partition coverage")
minimum, maximum = min(parts["durations_ms"]), max(parts["durations_ms"])
# Admission arithmetic: max * 1000 <= min * 2000.
if maximum * 1000 > minimum * 2000: fail("partition comparability")
if parts["conclusions"] != ["success", "success"] or parts["exit_statuses"] != [0, 0]: fail("partition outcomes")

expected_protected = {"library_tests_aggregate_sha256": aggregate_sha, "sole_pr_owner": "MIX_ENV=test mix ci", "fast_01_verifier": "source_complete_offline_attestation_verified", "gate_05_verifier": "offline_attestation_verified"}
if pr["protected_invariants"] != expected_protected: fail("PR protected invariants")
keys(pr["commands"], ["rate_limit", "watch", "summary", "artifacts"], "PR commands")
expected_commands = [f"gh run download {run['id']} --repo szTheory/sigra --name {name}" for name, _ in expected_pr_artifacts]
if pr["commands"] != {"rate_limit": rate, "watch": f"gh run watch {run['id']} --repo szTheory/sigra --compact --interval 60 --exit-status", "summary": f"gh run view {run['id']} --repo szTheory/sigra --json {summary_fields}", "artifacts": expected_commands}: fail("PR commands")
if pr["supersession"] != {"plan04_status": "empirically superseded (failed evidence retained)", "forbidden_predicates": ["install_not_dominant", "ordinary-vs-scaffold comparable"]}: fail("PR supersession ledger")

keys(scaffold, ["schema_version", "repository", "run", "job", "artifacts", "receivers", "diagnostics", "protected_invariants", "commands", "supersession"], "scaffold")
if scaffold["schema_version"] != "sigra.library-install-golden-evidence/v1" or scaffold["repository"] != "szTheory/sigra": fail("scaffold identity")
keys(scaffold["run"], ["id", "url", "event", "attempt", "head_sha", "conclusion"], "scaffold run")
srun = scaffold["run"]
if not integer(srun["id"]) or srun["id"] <= 0 or srun["event"] != "workflow_dispatch" or srun["attempt"] != 1 or srun["conclusion"] not in {"success", "failure"} or not digest(srun["head_sha"], 40): fail("scaffold run provenance")
if srun["url"] != f"https://github.com/szTheory/sigra/actions/runs/{srun['id']}": fail("scaffold run URL")
job = scaffold["job"]
keys(job, ["id", "name", "status", "conclusion", "skipped"], "scaffold job")
if not integer(job["id"]) or job["id"] <= 0 or job["name"] != "Library install golden (non-PR)" or job["status"] != "completed" or job["conclusion"] != "success" or job["skipped"] is not False: fail("scaffold job state")

expected_scaffold_artifacts = [(f"library-install-golden-{srun['id']}-1", "sigra-library-install-golden.json"), (f"library-install-diagnostics-{srun['id']}-1", "sigra-install-golden-diagnostics.json")]
if not isinstance(scaffold["artifacts"], list) or len(scaffold["artifacts"]) != 2: fail("scaffold artifact count")
ids = []
for artifact, (name, filename) in zip(scaffold["artifacts"], expected_scaffold_artifacts):
    keys(artifact, ["id", "name", "file", "sha256"], "scaffold artifact")
    if not integer(artifact["id"]) or artifact["id"] <= 0 or artifact["name"] != name or artifact["file"] != filename or not digest(artifact["sha256"], 64): fail("scaffold artifact identity")
    ids.append(artifact["id"])
if len(set(ids)) != 2: fail("scaffold artifact ID uniqueness")

receiver_paths = ["test/sigra/install/features/passkeys_js_test.exs", "test/sigra/install/generator_passkeys_opt_out_test.exs", "test/sigra/install/golden_diff_test.exs", "test/sigra/install/idempotency_test.exs", "test/sigra/install/vault_promotion_test.exs", "test/upgrade_test.exs"]
receivers = scaffold["receivers"]
keys(receivers, ["paths", "count", "duration_ms", "exit_status", "conclusion", "prepared_fixture", "worker_ceiling"], "receivers")
if receivers["paths"] != receiver_paths or receivers["count"] != 6 or len(set(receivers["paths"])) != 6 or not integer(receivers["duration_ms"]) or receivers["duration_ms"] <= 0 or receivers["exit_status"] != 0 or receivers["conclusion"] != "success" or receivers["prepared_fixture"] is not True or receivers["worker_ceiling"] != 2: fail("receiver facts")
diagnostics = scaffold["diagnostics"]
if diagnostics != {"schema_version": "sigra.install-fixture-diagnostics/v1", "variant_count": 6, "worker_count": 2, "failed_paths": [], "raw_install_duration_ms": receivers["duration_ms"]}: fail("diagnostic facts")
if scaffold["protected_invariants"] != {"non_pr_events": ["schedule", "workflow_dispatch"], "pr_execution": False, "hard_signal": True}: fail("scaffold protected invariants")
keys(scaffold["commands"], ["rate_limit", "watch", "summary", "artifacts"], "scaffold commands")
expected_commands = [f"gh run download {srun['id']} --repo szTheory/sigra --name {name}" for name, _ in expected_scaffold_artifacts]
if scaffold["commands"] != {"rate_limit": rate, "watch": f"gh run watch {srun['id']} --repo szTheory/sigra --compact --interval 60 --exit-status", "summary": f"gh run view {srun['id']} --repo szTheory/sigra --json {summary_fields}", "artifacts": expected_commands}: fail("scaffold commands")
expected_history = {"failed_run_id": 34435818106, "ordinary_duration_ms": 28671, "install_duration_ms": 79614, "safe_optimization_commits": ["1fa788fc", "488f4fa1"], "bounded_clean_local_range_ms": [56000, 78000], "final_hard_stop_ms": 57389, "status": "failed evidence retained"}
if scaffold["supersession"] != expected_history: fail("failed-history supersession ledger")
if run["head_sha"] != srun["head_sha"]: fail("capture routes do not share one implementation SHA")
if run["id"] == srun["id"]: fail("capture run IDs must be distinct")
print("verify-library-routing-evidence: PASS")
PY
