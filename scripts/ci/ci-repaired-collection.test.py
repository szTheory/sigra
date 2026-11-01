#!/usr/bin/env python3
"""Synthetic full collector -> independent origin verifier -> evaluator regression.

All GETs are served from a local route table; archived payloads are fixture seeds,
not new hosted evidence. The valid path deliberately uses different PRs and keys.
"""
import base64
import datetime as dt
import hashlib
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[2]
CI = ROOT / "scripts/ci/ci-run-metrics.sh"
REPOSITORY = "/repos/szTheory/sigra"
OWNERS = ("admin_behavior", "admin_checkpoints", "design_gallery", "non_admin_smoke", "demo_showcase")
SEED_RUN = 38317383419
SEED_ARCHIVE = ROOT / ".planning/phases/252-measure-current-ci/252-CI-SOURCE-BUNDLE.tar.gz"
PHASE = ROOT / ".planning/phases/254-speed-up-the-measured-slow-jobs"


def write(path, value):
    path.write_text(json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n")


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def image_proof(metadata):
    """Build explicit synthetic native-file bytes, bound to this metadata identity."""
    actual = {"image_os": "ubuntu24", "image_version": "20261012.334.1"}
    retained = {}
    for field, data in (
        ("image_file", json.dumps([{"group": "Runner Image", "detail": "Image: ubuntu-24.04\nVersion: 20261012.334.1"}]).encode()),
        ("os_release_file", b'ID=ubuntu\nVERSION_ID="24.04"\n'),
    ):
        retained[field] = {"base64": base64.b64encode(data).decode(), "sha256": hashlib.sha256(data).hexdigest()}
    identity = {field: metadata.get(field) for field in ("repository", "run_id", "run_attempt", "source_sha", "matrix_seam")}
    proof = {"schema_version": "sigra.ci-runner-image/v2", "status": "verified", **retained,
             "file_image": actual, "runner_image": actual, "environment_image": actual,
             "identity_authority": "runner_native_image_file", "environment_agrees": True,
             "identity": identity, "machine": "x86_64"}
    verification = {"status": "verified", "runner_image": actual, "identity": identity, "machine": "x86_64",
                    "image_file_sha256": retained["image_file"]["sha256"],
                    "os_release_sha256": retained["os_release_file"]["sha256"],
                    "identity_authority": "runner_native_image_file", "early_environment_image": actual, "environment_image": actual,
                    "environment_agrees": True, "environment_changed": False}
    metadata.update(runner_os="Linux", runner_arch="X64", runner_image={**actual, "source_proof": proof, "verification": verification})


class RepairedCollection(unittest.TestCase):
    maxDiff = None

    def command(self, args, environment, timeout=180):
        result = subprocess.run(["bash", str(CI), *args], cwd=ROOT, env=environment,
                                text=True, capture_output=True, timeout=timeout)
        self.assertEqual(0, result.returncode, result.stderr[-8000:] + result.stdout[-3000:])
        return result

    def test_valid_collected_pair_and_mutated_origin(self):
        with tempfile.TemporaryDirectory(prefix="sigra-repaired-collection-") as tmp:
            root = Path(tmp)
            project = root / "fixture-project"
            (project / "scripts/ci").mkdir(parents=True)
            generator = (ROOT / "scripts/ci/ci-run-metrics-comparison.test.sh").read_text().split(
                'python3 - "$TMP" "$ROOT" <<\'PY\'\n', 1)[1].split("\nPY\n", 1)[0]
            subprocess.run([sys.executable, "-B", "-", str(root), str(project)], input=generator,
                           text=True, check=True)
            contract = json.loads((root / "contract.json").read_text())
            baseline = json.loads((ROOT / ".planning/phases/252-measure-current-ci/252-COMPARISON-CONTRACT.json").read_text())
            head = baseline["baseline_application_sha"]
            producer = baseline["baseline_identity"]["producer_source_sha"]
            now = dt.datetime.now(dt.timezone.utc).replace(microsecond=0)
            contract.update(comparison_kind="repaired_control_pr", baseline_application_sha=head,
                            baseline_identity=baseline["baseline_identity"],
                            baseline_workflow_sha256=baseline["baseline_workflow_sha256"],
                            baseline_workload_revision_sha256=baseline["baseline_workload_revision_sha256"],
                            instrumentation_identity={"exunit": "exunit-v1", "playwright": "playwright-v1"},
                            required_check_apps={name: 15368 for name in contract["required_contexts"]},
                            window={"start_utc": (now - dt.timedelta(minutes=1)).isoformat().replace("+00:00", "Z"),
                                    "end_utc": (now - dt.timedelta(minutes=1) + dt.timedelta(hours=48)).isoformat().replace("+00:00", "Z")})
            contract.pop("sample_identity", None)
            contract["candidate_identity"].update(application_sha=head, workflow_revision=head, producer_source_sha=producer,
                workflow_file_sha256=baseline["baseline_workflow_sha256"],
                workload_revision_sha256=baseline["baseline_workload_revision_sha256"])
            contract["baseline_identity"].pop("run_id", None)
            mapping = json.loads((PHASE / "254-WORKLOAD-MAP.json").read_text())
            for row in mapping["rows"]:
                row["after"] = row["before"]
            map_path = ROOT / "scripts/ci/.repaired-collection-map.json"
            parity_path = ROOT / "scripts/ci/.repaired-collection-parity.json"
            self.assertFalse(map_path.exists())
            self.assertFalse(parity_path.exists())
            try:
                write(map_path, {"schema_version": "sigra.browser-coverage-map/v1", "rows": mapping["rows"]})
                # Distinct workload revisions remain independently authorized by native mapping.
                contract["candidate_identity"]["workload_revision_sha256"] = digest(map_path)
                write(parity_path, {"schema_version": "sigra.browser-parity-receipt/v1", "status": "passed",
                    "owner_integration_status": "profiled", "mapping_sha256": digest(map_path),
                    "baseline_source_sha": head, "candidate_source_sha": head, "event": "pull_request",
                    "owners": [{"owner": owner, "status": "passed"} for owner in OWNERS]})
                inventories = {}
                for owner in OWNERS:
                    directory = PHASE / "254-BASELINE-NATIVE-VERIFIED" / owner
                    descriptor = directory / "coverage-source.json"
                    payload = json.loads(descriptor.read_text())
                    selection = directory / payload["reports"][0]["selection_path"]
                    inventories[owner] = {"descriptor_path": str(descriptor.relative_to(ROOT)), "descriptor_sha256": digest(descriptor),
                        "selection_path": str(selection.relative_to(ROOT)), "selection_sha256": digest(selection), "inventory_source_sha": head}
                contract["native_coverage_comparison"] = {"mapping_path": str(map_path.relative_to(ROOT)), "mapping_sha256": digest(map_path),
                    "parity_receipt_path": str(parity_path.relative_to(ROOT)), "parity_receipt_sha256": digest(parity_path),
                    "inventories": {"before": inventories, "after": inventories}}
                with tarfile.open(SEED_ARCHIVE) as archive:
                    read = lambda name: archive.extractfile(f"./raw/families/{SEED_RUN}/" + name).read()
                    seed_run, seed_jobs, seed_checks, seed_metadata, seed_detail = [json.loads(read(name)) for name in (
                        "run.json", "jobs-attempt-1.json", "check-runs.json", "artifacts-metadata.json", "manifest.json")]
                    ref = seed_detail["producer_commits"][producer]
                    source = {"commit": json.load(archive.extractfile("./" + ref["commit_path"])),
                              "tree": json.load(archive.extractfile("./" + ref["tree_path"])),
                              "workflow": {"encoding": "base64", "content": base64.b64encode(archive.extractfile("./" + ref["workflow_path"]).read()).decode()}}
                    payloads = {str(row["id"]): read(f"artifacts/{row['id']}.zip") for row in seed_metadata["artifacts"]
                                if any(member.name == f"./raw/families/{SEED_RUN}/artifacts/{row['id']}.zip" for member in archive.getmembers())}
                contract["baseline_identity"].update(branch=seed_run["pull_requests"][0]["head"]["ref"],
                    parent_main_sha=seed_run["pull_requests"][0]["base"]["sha"])
                contract["cache_eligibility"] = {"default_branch_ref": "refs/heads/main", "expected_keys": {}}
                datasets = {}
                for offset, role in enumerate(("before", "after")):
                    run_id, pr_number = 71001 + offset, 731 + offset
                    origin = now + dt.timedelta(seconds=offset * 10)
                    delta = origin - dt.datetime.fromisoformat(seed_run["created_at"].replace("Z", "+00:00"))
                    def shifted(value):
                        if isinstance(value, dict):
                            return {key: shifted(item) for key, item in value.items()}
                        if isinstance(value, list):
                            return [shifted(item) for item in value]
                        if isinstance(value, str):
                            if len(value) > 19 and value.endswith("Z") and "T" in value:
                                try:
                                    return (dt.datetime.fromisoformat(value.replace("Z", "+00:00")) + delta).isoformat().replace("+00:00", "Z")
                                except ValueError:
                                    pass
                            return value.replace(str(SEED_RUN), str(run_id))
                        return run_id if value == SEED_RUN else value
                    run, jobs, checks = [shifted(item) for item in (seed_run, seed_jobs, seed_checks)]
                    minimal = run["pull_requests"][0]
                    minimal["number"] = pr_number
                    minimal["head"]["ref"] = f"fixture-{role}"
                    minimal["url"] = f"https://api.github.com/repos/szTheory/sigra/pulls/{pr_number}"
                    run.update(run_attempt=1, status="completed", conclusion="success", head_branch=minimal["head"]["ref"])
                    run["check_suite_id"] += offset * 1000
                    self.assertNotIn("merge_commit_sha", minimal)
                    full_pr = {**minimal, "merge_commit_sha": producer, "state": "open"}
                    merge = {"sha": producer, "tree": source["commit"]["commit"]["tree"], "parents": source["commit"]["parents"]}
                    for job in jobs["jobs"]:
                        job["run_attempt"] = 1
                        job["head_branch"] = minimal["head"]["ref"]
                        # This new synthetic experiment has no execution times
                        # for jobs that never acquired a runner. The archived
                        # historical API fixture itself remains unchanged.
                        if job["conclusion"] == "skipped" and not job.get("runner_id") and not job.get("steps"):
                            job["started_at"] = job["completed_at"] = None
                    jobs["total_count"] = len(jobs["jobs"])
                    for check in checks["check_runs"]:
                        check["check_suite"]["id"] = run["check_suite_id"]
                        check["pull_requests"] = [minimal]
                    directory = root / ("transport-" + role)
                    directory.mkdir()
                    retained = []
                    expected_keys = {}
                    for item in seed_metadata["artifacts"]:
                        old_id = str(item["id"])
                        if old_id not in payloads or not any(word in item["name"] for word in ("timing", "playwright", "measurement-metadata")):
                            continue
                        artifact = shifted(item)
                        artifact["id"] += (offset + 1) * 1000000000000
                        artifact["workflow_run"].update(id=run_id, run_attempt=1, head_sha=head, repository_id=1207487684)
                        artifact["expired"] = False
                        output = io.BytesIO()
                        with zipfile.ZipFile(io.BytesIO(payloads[old_id])) as original, zipfile.ZipFile(output, "w") as zipped:
                            for member in original.infolist():
                                if member.is_dir() or not member.filename.endswith(".json"):
                                    continue
                                data = shifted(json.loads(original.read(member)))
                                if member.filename.endswith("ci-measurement-metadata.json"):
                                    if data.get("job_name") in ("Library tests shard", "Example Playwright shard"):
                                        owner = data.get("matrix_seam") or "library"
                                        data["cache_outcome"] = {component: {"matched_cache_key": f"exact-{role}-{owner}-{component}",
                                            "scope": "refs/heads/main", "ref": f"refs/pull/{pr_number}/merge", "exact_key": True,
                                            "cache_hit": True, "conditions": ["Linux", "X64", owner]}
                                            for component in data["cache_outcome"]}
                                        expected_keys[owner] = {component: row["matched_cache_key"] for component, row in data["cache_outcome"].items()}
                                        image_proof(data)
                                zipped.writestr(member.filename, json.dumps(data, separators=(",", ":")).encode())
                        target = directory / f"{artifact['id']}.zip"
                        target.write_bytes(output.getvalue())
                        artifact["digest"] = "sha256:" + digest(target)
                        retained.append(artifact)
                    contract["cache_eligibility"]["expected_keys"][role] = expected_keys
                    datasets[role] = (run, full_pr, merge, jobs, checks, retained, directory)
                contract_path, ledger_path, budget = root / "repaired-contract.json", root / "registrations.json", root / "budget.json"
                ledger_path.unlink()  # Generated historical fixture ledger is not this experiment.
                for reservation in contract["family_reservations"]:
                    reservation.pop("run_id", None)
                    reservation.pop("created_at", None)
                write(contract_path, contract)
                binary = root / "bin"
                binary.mkdir()
                stub = '''#!/usr/bin/env python3
import json,os,pathlib,sys
root=pathlib.Path(os.environ['REPAIRED_TRANSPORT']);args=sys.argv[1:]
with (root/'calls.jsonl').open('a') as out:out.write(json.dumps(args)+'\\n')
if pathlib.Path(sys.argv[0]).name=='gh':
 endpoint=args[-1];table=json.loads((root/'routes.json').read_text())
 if endpoint not in table: print('unstubbed endpoint '+endpoint,file=sys.stderr);sys.exit(1)
 name=table[endpoint]
 if name=='run.json' and os.environ.get('REPAIRED_EARLY')=='1':name='early.json'
 sys.stdout.buffer.write((root/name).read_bytes())
else:
 url=args[-1]
 pathlib.Path(args[args.index('--dump-header')+1]).write_text('HTTP/1.1 200 OK\\r\\n\\r\\n')
 aid=url.split('/artifacts/')[1].split('/')[0]
 pathlib.Path(args[args.index('--output')+1]).write_bytes((root/(aid+'.zip')).read_bytes())
 print('200',end='')
'''
                for name in ("gh", "curl"):
                    (binary / name).write_text(stub)
                    (binary / name).chmod(0o755)
                bundles, environments = {}, {}
                for offset, role in enumerate(("before", "after")):
                    run, pr, merge, jobs, checks, artifacts, directory = datasets[role]
                    run_id, number = run["id"], pr["number"]
                    routes = {}
                    def route(endpoint, filename, payload):
                        write(directory / filename, payload)
                        routes[endpoint] = filename
                    route("rate_limit", "rate.json", {"resources": {"core": {"remaining": 5000, "reset": 2000000000}}})
                    route(REPOSITORY, "repository.json", {"id": 1207487684, "full_name": "szTheory/sigra", "default_branch": "main"})
                    route(REPOSITORY + "/rules/branches/main", "rules.json", [{"type": "required_status_checks", "ruleset_id": 1,
                        "parameters": {"required_status_checks": [{"context": name, "integration_id": 15368} for name in contract["required_contexts"]]}}])
                    route(REPOSITORY + "/branches/main/protection/required_status_checks", "protection.json",
                        {"contexts": contract["required_contexts"], "checks": [{"context": name, "app_id": 15368} for name in contract["required_contexts"]]})
                    route(REPOSITORY + "/rulesets?per_page=100", "rulesets.json", [])
                    route(REPOSITORY + f"/actions/runs/{run_id}", "run.json", run)
                    write(directory / "early.json", {**run, "status": "in_progress", "conclusion": None})
                    route(REPOSITORY + f"/actions/runs/{run_id}/attempts/1/jobs?per_page=100&page=1", "jobs.json", jobs)
                    route(REPOSITORY + f"/pulls/{number}", "pr.json", pr)
                    route(REPOSITORY + f"/git/commits/{producer}", "merge.json", merge)
                    route(REPOSITORY + f"/pulls/{number}/files?per_page=100&page=1", "changes.json", [{"filename": "lib/sigra.ex", "status": "modified"}])
                    route(REPOSITORY + f"/commits/{head}/check-runs?per_page=100", "checks.json", checks)
                    route(REPOSITORY + f"/actions/runs/{run_id}/artifacts?per_page=100", "artifacts.json", {"total_count": len(artifacts), "artifacts": artifacts})
                    route(REPOSITORY + f"/commits/{producer}", "commit.json", source["commit"])
                    route(REPOSITORY + f"/git/trees/{source['tree']['sha']}?recursive=1", "tree.json", source["tree"])
                    route(REPOSITORY + f"/contents/.github/workflows/ci.yml?ref={producer}", "workflow.json", source["workflow"])
                    write(directory / "routes.json", routes)
                    environment = {**os.environ, "PATH": str(binary) + os.pathsep + os.environ["PATH"],
                        "GH_TOKEN": "synthetic-fixture-token", "REPAIRED_TRANSPORT": str(directory)}
                    environments[role] = environment
                    reservation = contract["family_reservations"][offset]
                    self.command(["--register-comparison-run", "--contract", str(contract_path), "--registrations", str(ledger_path),
                        "--reservation-id", reservation["reservation_id"], "--run-id", str(run_id), "--request-budget-ledger", str(budget)],
                        {**environment, "REPAIRED_EARLY": "1"})
                    bundle = root / ("collected-" + role)
                    self.command(["--collect-comparison", "--comparison-role", role, "--contract", str(contract_path),
                        "--registrations", str(ledger_path), "--request-budget-ledger", str(budget), "--source-bundle", str(bundle)], environment)
                    bundles[role] = bundle
                    manifest = json.loads((bundle / "manifest.json").read_text())
                    self.assertEqual("passed", manifest["comparison_collection"]["origin_status"], manifest["comparison_collection"])
                    self.assertEqual("warm", manifest["comparison_families"][0]["cache_stratum"])
                    self.assertNotEqual(contract["cache_eligibility"]["expected_keys"]["before"], contract["cache_eligibility"]["expected_keys"]["after"])
                args = ["--evaluate-comparison", "--contract", str(contract_path), "--registrations", str(ledger_path),
                    "--before-bundle", str(bundles["before"]), "--after-bundle", str(bundles["after"]),
                    "--baseline-source-bundle", str(SEED_ARCHIVE), "--format", "json"]
                report = json.loads(self.command(args, environments["after"]).stdout)
                self.assertEqual("insufficient_data", report["status"])
                self.assertEqual(1, report["metrics"]["comparable_successful_pairs"], report["diagnostics"])
                self.assertEqual(2, report["metrics"]["native_parity"]["origins_verified"], report["diagnostics"])
                self.assertEqual("passed", report["metrics"]["native_parity"]["origin_status"], report["diagnostics"])
                # Independently calculate expected sums/endpoints from fixture timestamps.
                def timestamp(value):
                    return dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
                for side, label in (("before", "baseline"), ("after", "candidate")):
                    run, _, _, jobs, checks, _, directory = datasets[side]
                    executed = [job for job in jobs["jobs"] if job["conclusion"] != "skipped"]
                    self.assertTrue(all(job.get("runner_id") and job.get("steps") for job in executed))
                    total = sum((timestamp(job["completed_at"]) - timestamp(job["started_at"])).total_seconds()
                                for job in executed)
                    self.assertEqual(2042, total)
                    endpoint = max(timestamp(check["completed_at"]) for check in checks["check_runs"]
                                   if check["name"] in contract["required_contexts"])
                    wait = (endpoint - timestamp(run["created_at"])).total_seconds()
                    self.assertEqual(total, report["metrics"][label + "_runner_seconds"])
                    self.assertEqual(wait, report["metrics"][label + "_median_seconds"])
                    calls = [json.loads(line) for line in (directory / "calls.jsonl").read_text().splitlines()]
                    endpoints = {call[-1] for call in calls if call and call[0] == "api"}
                    self.assertIn(REPOSITORY + f"/pulls/{run['pull_requests'][0]['number']}", endpoints)
                    self.assertIn(REPOSITORY + f"/git/commits/{producer}", endpoints)

                # Acquire a separately retained, internally hashed observation
                # with one invalid physical-job duration. This must invalidate
                # cost, rather than becoming a zero-duration successful pair.
                run, _, _, jobs, _, _, directory = datasets["after"]
                invalid_jobs = json.loads(json.dumps(jobs))
                changed_job = next(job for job in invalid_jobs["jobs"] if job["name"] == "Detect docs-only change")
                changed_job["started_at"] = (timestamp(changed_job["completed_at"]) + dt.timedelta(seconds=1)).isoformat().replace("+00:00", "Z")
                write(directory / "jobs.json", invalid_jobs)
                invalid_cost_bundle = root / "collected-after-negative-duration"
                self.command(["--collect-comparison", "--comparison-role", "after", "--contract", str(contract_path),
                    "--registrations", str(ledger_path), "--request-budget-ledger", str(budget),
                    "--source-bundle", str(invalid_cost_bundle)], environments["after"])
                invalid_args = list(args)
                invalid_args[invalid_args.index("--after-bundle") + 1] = str(invalid_cost_bundle)
                invalid_cost = json.loads(self.command(invalid_args, environments["after"]).stdout)
                self.assertEqual("insufficient_data", invalid_cost["status"])
                self.assertIsNone(invalid_cost["metrics"]["candidate_runner_seconds"])
                self.assertEqual(0, invalid_cost["metrics"]["comparable_successful_pairs"])
                self.assertTrue(any("runner_cost_unknown" in row["reason"] for row in invalid_cost["diagnostics"]), invalid_cost["diagnostics"])
                write(directory / "jobs.json", jobs)
                family = bundles["after"] / "raw/families" / str(datasets["after"][0]["id"])
                pr_file = family / "pull-request.json"
                original = pr_file.read_bytes()
                altered = json.loads(original)
                altered["merge_commit_sha"] = "f" * 40
                write(pr_file, altered)
                invalid = json.loads(self.command(args, environments["after"]).stdout)
                self.assertEqual("insufficient_data", invalid["status"])
                self.assertTrue(any("origin_verification_failed" in row["reason"] for row in invalid["diagnostics"]), invalid["diagnostics"])
                self.assertEqual(0, invalid["metrics"]["comparable_successful_pairs"])
            finally:
                map_path.unlink(missing_ok=True)
                parity_path.unlink(missing_ok=True)


if __name__ == "__main__":
    unittest.main(verbosity=2)
