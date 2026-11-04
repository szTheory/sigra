#!/usr/bin/env python3
"""Synthetic rerun samples: repeated run IDs, exact attempt bytes, real CLI evaluation."""
import base64
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import tarfile
import io
import datetime
import unittest
import zipfile

from ci_metrics_security import comparison_contract_sha256

ROOT = Path(__file__).resolve().parents[2]
OWNERS = ("admin_behavior", "admin_checkpoints", "design_gallery", "non_admin_smoke", "demo_showcase")


def write(path, value):
    path.write_text(json.dumps(value, sort_keys=True, separators=(",", ":")))


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def attempt_fixture(root):
    # Reuse the existing full native-workload fixture; change its observation unit.
    source = (ROOT / "scripts/ci/ci-run-metrics-comparison.test.sh").read_text()
    generator = source.split('python3 - "$TMP" "$ROOT" <<\'PY\'\n', 1)[1].split("\nPY\n", 1)[0]
    project = root / "fixture-project"
    (project / "scripts/ci").mkdir(parents=True)
    subprocess.run([sys.executable, "-", str(root), str(project)], input=generator, text=True, check=True)
    contract = json.loads((root / "contract.json").read_text())
    registrations = json.loads((root / "registrations.json").read_text())["records"]
    observation_rows = {}
    for role, directory, run_id in (("before", "before", 9001), ("after", "after", 9002)):
        bundle = root / directory
        manifest = json.loads((bundle / "manifest.json").read_text())
        population = json.loads((bundle / "raw/populations/pull_request.json").read_text())
        requests = []
        for index, row in enumerate(manifest["comparison_families"], 1):
            old_id = row["run_id"]
            attempt = index + 2
            sample = f"{run_id}-attempt-{attempt}"
            family = bundle / "raw/families" / sample
            (bundle / "raw/families" / str(old_id)).rename(family)
            run = json.loads((family / "run.json").read_text())
            origin = run["created_at"]
            run.update(id=run_id, run_attempt=attempt, run_started_at=origin, created_at="2026-10-12T00:00:00Z")
            write(family / "run.json", run)
            jobs = json.loads((family / "jobs-attempt-2.json").read_text())
            for job in jobs["jobs"]:
                job.update(run_id=run_id, run_attempt=attempt)
            jobs_path = family / f"jobs-attempt-{attempt}.json"
            write(jobs_path, jobs)
            if attempt != 2:
                (family / "jobs-attempt-2.json").unlink()
            # The retained failed old attempt must never enter this sample's cost.
            self_old = json.loads((family / "jobs-attempt-1.json").read_text())
            assert self_old["jobs"][0]["conclusion"] == "failure"
            evidence = []
            artifacts = []
            for owner_index, owner in enumerate(OWNERS, 1):
                native = family / "artifacts/coverage" / owner
                descriptor = json.loads((native / "coverage-source.json").read_text())
                report = (native / "native.json").read_bytes()
                selection = (native / "selection.json").read_bytes()
                descriptor["reports"][0].update(path="report.json", selection_path=f"{owner}.selection.json")
                artifact_id = 800 + owner_index
                extracted = family / "artifacts" / str(artifact_id)
                extracted.mkdir()
                (extracted / "report.json").write_bytes(report)
                (extracted / f"{owner}.selection.json").write_bytes(selection)
                write(extracted / "coverage-source.json", descriptor)
                archive = family / "artifacts" / f"{artifact_id}.zip"
                with zipfile.ZipFile(archive, "w") as target:
                    for member in sorted(extracted.iterdir()):
                        target.writestr(member.name, member.read_bytes())
                artifact = {"id": artifact_id, "name": f"browser-execution-{owner}-{run_id}-{attempt}",
                            "expired": False, "digest": "sha256:" + digest(archive),
                            "workflow_run": {"id": run_id, "run_attempt": attempt,
                                             "head_sha": run["head_sha"], "repository_id": 1207487684}}
                artifacts.append(artifact)
                evidence.append({"artifact": artifact, "result": {"status": "accepted", "archive_sha256": digest(archive),
                    "members": [{"member": member.name, "sha256": digest(member)} for member in sorted(extracted.iterdir())]}})
            shutil.rmtree(family / "artifacts/coverage")
            # Drop the unrelated synthetic legacy archive and its extraction.
            (family / "artifacts/777.zip").unlink()
            shutil.rmtree(family / "artifacts/777")
            write(family / "artifact-evidence.json", evidence)
            write(family / "artifacts-metadata.json", {"artifacts": artifacts})
            detail = json.loads((family / "manifest.json").read_text())
            detail.update(run_id=run_id, sample_id=sample, run_attempt=attempt,
                          source_run_sha256=digest(family / "run.json"),
                          attempt_jobs={str(attempt): {"path": f"raw/families/{sample}/{jobs_path.name}", "sha256": digest(jobs_path)}},
                          artifact_metadata_sha256=digest(family / "artifacts-metadata.json"),
                          artifact_evidence={"path": f"raw/families/{sample}/artifact-evidence.json", "sha256": digest(family / "artifact-evidence.json")})
            write(family / "manifest.json", detail)
            row.update(run_id=run_id, run_attempt=attempt, sample_id=sample, reservation_id=f"r-pair-{index:02d}-{role}",
                       created_at=run["created_at"], attempt_origin_at=origin,
                       source_workload_revision_sha256=contract['baseline_workload_revision_sha256'] if role=='before' else contract['candidate_identity']['workload_revision_sha256'],
                       coverage_map_sha256=contract['native_coverage_comparison']['mapping_sha256'])
            api_run = population["runs"][index - 1]
            api_run.update(run, detail_status="complete", workload="full", attempt_jobs=detail["attempt_jobs"])
            observation_rows[(row["pair_id"], role)] = run
            requests.append(f"/repos/szTheory/sigra/actions/runs/{run_id}/attempts/{attempt}/jobs?per_page=100")
        write(bundle / "raw/populations/pull_request.json", population)
        write(bundle / "request-ledger.json", {"requests": requests})
        manifest["populations"]["pull_request"]["runs"] = population["runs"]
        manifest["source_sha256"]["pull_request"] = digest(bundle / "raw/populations/pull_request.json")
        manifest["source_sha256"]["request_ledger"] = digest(bundle / "request-ledger.json")
        write(bundle / "manifest.json", manifest)
    contract["sample_identity"] = "run_id+run_attempt"
    contract["instrumentation_identity"] = {"exunit": "exunit-v1", "playwright": "playwright-v1"}
    for reservation in contract["family_reservations"]:
        run = observation_rows[(reservation["pair_id"], reservation["family_role"])]
        reservation.update(run_id=run["id"], run_attempt=run["run_attempt"], created_at=run["created_at"])
    previous = "0" * 64
    for registration in registrations:
        run = observation_rows[(registration["pair_id"], registration["family_role"])]
        early = {**run, "status": "in_progress", "conclusion": None}
        raw = json.dumps(early, sort_keys=True, separators=(",", ":")).encode()
        registration.update(previous_sha256=previous, run_id=run["id"], run_attempt=run["run_attempt"],
                            sample_id=f"{run['id']}-attempt-{run['run_attempt']}", created_at=run["created_at"],
                            attempt_origin_at=run["run_started_at"], api_run_sha256=hashlib.sha256(raw).hexdigest(),
                            api_run_response_b64=base64.b64encode(raw).decode())
        registration.pop("record_sha256", None)
        registration["record_sha256"] = hashlib.sha256(json.dumps(registration, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
        previous = registration["record_sha256"]
    for key, filename in (("mapping_path", ".comparison-test-map.json"), ("parity_receipt_path", ".comparison-test-parity.json")):
        path = ROOT / "scripts/ci" / filename.replace(".comparison-test-", ".comparison-attempt-test-")
        path.write_bytes((project / "scripts/ci" / filename).read_bytes())
        contract["native_coverage_comparison"][key] = str(path.relative_to(ROOT))
    write(root / "contract.json", contract)
    write(root / "registrations.json", {"schema_version": "sigra.ci-comparison-registration/v1", "contract_sha256": comparison_contract_sha256(contract), "records": registrations})
    return contract


class AttemptEvaluation(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix="sigra-attempt-evaluation-")
        cls.root = Path(cls.temp.name)
        cls.contract = attempt_fixture(cls.root)

    @classmethod
    def tearDownClass(cls):
        for name in (".comparison-attempt-test-map.json", ".comparison-attempt-test-parity.json"):
            (ROOT / "scripts/ci" / name).unlink(missing_ok=True)
        cls.temp.cleanup()

    def evaluate(self, before=None, after=None):
        result = subprocess.run(["bash", str(ROOT / "scripts/ci/ci-run-metrics.sh"), "--evaluate-comparison",
            "--contract", str(self.root / "contract.json"), "--registrations", str(self.root / "registrations.json"),
            "--before-bundle", str(before or self.root / "before"), "--after-bundle", str(after or self.root / "after"),
            "--baseline-source-bundle", str(self.root / "baseline-source-bundle.tar.gz"), "--format", "json"],
            cwd=ROOT, capture_output=True, text=True, timeout=120)
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def test_twenty_pairs_reuse_two_run_ids_without_cumulative_costs(self):
        result = self.evaluate()
        self.assertEqual(result["status"], "pass", result.get("diagnostics"))
        metrics = result["metrics"]
        self.assertEqual(metrics["baseline_median_seconds"], 210.5)
        self.assertEqual(metrics["candidate_median_seconds"], 105)
        self.assertEqual(metrics["baseline_runner_seconds"], 1000)
        self.assertEqual(metrics["candidate_runner_seconds"], 500)
        self.assertEqual(metrics["native_parity"]["origin_status"], "passed")
        self.assertEqual(len(metrics["native_parity"]["comparisons"]), 100)

    def test_offline_assembly_preserves_all_twenty_pairs_and_rejects_duplicate_or_tampered_inputs(self):
        from ci_metrics_security import assemble_comparison_snapshots
        assembled = {}
        for role in ('before','after'):
            chunks = []
            for index in range(2):
                chunk = self.root/f'chunk-{role}-{index}'
                shutil.copytree(self.root/role,chunk)
                manifest = json.loads((chunk/'manifest.json').read_text())
                manifest['comparison_families'] = manifest['comparison_families'][index*10:(index+1)*10]
                keep = {row['sample_id'] for row in manifest['comparison_families']}
                for family in (chunk/'raw/families').iterdir():
                    if family.name not in keep: shutil.rmtree(family)
                population = json.loads((chunk/'raw/populations/pull_request.json').read_text())
                population['runs'] = [r for r in population['runs'] if f"{r['id']}-attempt-{r['run_attempt']}" in keep]
                population['api_total_count'] = len(population['runs'])
                write(chunk/'raw/populations/pull_request.json',population)
                manifest['populations']['pull_request'] = population
                manifest['source_sha256']['pull_request'] = digest(chunk/'raw/populations/pull_request.json')
                manifest['comparison_collection'] = {'role':role,'contract_sha256':comparison_contract_sha256(self.contract),
                    'origin_status':'passed','registered_runs':[],'origin_verification':[]}
                write(chunk/'manifest.json',manifest)
                chunks.append(chunk)
            index_path = self.root/f'assembly-index-{role}.json'
            write(index_path,[{'path':str(path),'manifest_sha256':digest(path/'manifest.json')} for path in chunks])
            output = self.root/f'assembled-{role}'
            result = subprocess.run(['bash',str(ROOT/'scripts/ci/ci-run-metrics.sh'),'--assemble-comparison',
                '--contract',str(self.root/'contract.json'),'--source-pages',str(index_path),'--source-bundle',str(output)],
                cwd=ROOT,capture_output=True,text=True,timeout=30)
            self.assertEqual(result.returncode,0,result.stderr)
            self.assertEqual(json.loads(result.stdout),{'status':'assembled','samples':20,'acquisition_passes':2,'network_requests':0})
            assembled[role]=output
            with self.assertRaisesRegex(ValueError,'duplicate'):
                assemble_comparison_snapshots(self.contract,[chunks[0],chunks[0]],self.root/f'duplicate-{role}')
            raw = next((chunks[0]/'raw/families').glob('*/run.json'))
            original = raw.read_bytes(); raw.write_bytes(original+b' ')
            with self.assertRaisesRegex(ValueError,'input_hash_invalid'):
                assemble_comparison_snapshots(self.contract,chunks,self.root/f'tampered-{role}')
            raw.write_bytes(original)
        report=self.evaluate(before=assembled['before'],after=assembled['after'])
        self.assertEqual(report['status'],'pass',report['diagnostics'])
        self.assertEqual(report['metrics']['native_parity']['origins_verified'],40)
        self.assertEqual(report['metrics']['baseline_runner_seconds'],1000)
        self.assertEqual(report['metrics']['candidate_runner_seconds'],500)

    def test_measured_trigger_requires_durable_previous_bytes_and_is_once_only(self):
        from ci_metrics_security import verify_durable_attempt_capture, validate_next_comparison_trigger
        project=self.root/'trigger-project'
        (project/'scripts/ci').mkdir(parents=True)
        for name in ('ci-run-metrics.sh','ci_metrics_security.py'):
            shutil.copy2(ROOT/'scripts/ci'/name,project/'scripts/ci'/name)
        capture=project/'capture'
        shutil.copytree(self.root/'before',capture)
        manifest=json.loads((capture/'manifest.json').read_text())
        manifest['comparison_collection']={'origin_status':'passed'}
        write(capture/'manifest.json',manifest)
        def git(*args):
            return subprocess.check_output(['git',*args],cwd=project,text=True,stderr=subprocess.DEVNULL).strip()
        git('init');git('config','user.name','Fixture');git('config','user.email','fixture@example.invalid')
        git('add','capture');git('commit','-m','retain previous attempts')
        commit=git('rev-parse','HEAD');ref='refs/evidence/fixture-previous-attempt'
        git('update-ref',ref,commit)
        receipt={'capture_path':'capture','ref':ref,'commit':commit,
            'files':{str(path.relative_to(project)):digest(path) for path in capture.rglob('*') if path.is_file()}}
        source='a'*40
        verify_durable_attempt_capture(receipt,project,9001,3,source)
        invalid=json.loads(json.dumps(receipt));invalid['files'].pop(next(iter(invalid['files'])))
        with self.assertRaisesRegex(ValueError,'file_set_incomplete'):
            verify_durable_attempt_capture(invalid,project,9001,3,source)
        contract=json.loads(json.dumps(self.contract))
        current=datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0)-datetime.timedelta(seconds=1)
        contract['window']={'start_utc':current.isoformat().replace('+00:00','Z'),
            'end_utc':(current+datetime.timedelta(hours=48)).isoformat().replace('+00:00','Z')}
        for index,row in enumerate(contract['family_reservations']):
            row['run_attempt']=100+index
        reservation=contract['family_reservations'][0];reservation['run_attempt']=4
        endpoint='/repos/szTheory/sigra/actions/runs/9001/rerun'
        contract.update(authorized_mutations=[endpoint],maximum_mutations=40)
        prior=json.loads((capture/'raw/families/9001-attempt-3/run.json').read_text())
        selected=validate_next_comparison_trigger(contract,reservation['reservation_id'],None,prior,receipt,project)
        self.assertEqual(selected['run_attempt'],4)
        with self.assertRaisesRegex(ValueError,'not_next_reserved_slot'):
            validate_next_comparison_trigger(contract,contract['family_reservations'][1]['reservation_id'],None,prior,receipt,project)
        with self.assertRaisesRegex(ValueError,'previous_attempt_changed_or_failed'):
            validate_next_comparison_trigger(contract,reservation['reservation_id'],None,{**prior,'conclusion':'failure'},receipt,project)
        write(project/'contract.json',contract);write(project/'receipt.json',receipt)
        transport=project/'bin';transport.mkdir()
        stub=transport/'gh'
        stub.write_text('''#!/usr/bin/env python3
import json,os,pathlib,sys
args=sys.argv[1:];endpoint=args[args.index('--method')+2]
root=pathlib.Path(os.environ['TRIGGER_FIXTURE'])
with (root/'transport.jsonl').open('a') as out:out.write(json.dumps(args)+'\\n')
if endpoint=='rate_limit':print(json.dumps({'resources':{'core':{'remaining':5000,'reset':2000000000}}}))
elif args[args.index('--method')+1]=='POST':print('{}')
else:print((root/'prior.json').read_text())
''')
        stub.chmod(0o755);write(project/'prior.json',prior)
        env={**os.environ,'PATH':str(transport)+os.pathsep+os.environ['PATH'],'TRIGGER_FIXTURE':str(project)}
        for index in range(2):
            result=subprocess.run(['bash',str(project/'scripts/ci/ci-run-metrics.sh'),'--bounded-request',endpoint,
                '--request-method','POST','--comparison-role','before','--reservation-id',reservation['reservation_id'],
                '--contract',str(project/'contract.json'),'--registrations',str(project/'registrations.json'),
                '--capture-receipt',str(project/'receipt.json'),'--request-budget-ledger',str(project/'budget.json'),
                '--output',str(project/f'trigger-{index}.json')],cwd=project,env=env,capture_output=True,text=True,timeout=30)
            if index==0:self.assertEqual(result.returncode,0,result.stderr)
            else:self.assertNotEqual(result.returncode,0)
        calls=[json.loads(line) for line in (project/'transport.jsonl').read_text().splitlines()]
        self.assertEqual(sum(row[row.index('--method')+1]=='POST' for row in calls),1)

    def test_twenty_valid_attempt_pairs_preserve_a_measured_miss(self):
        import datetime
        after = self.root / "after-miss"
        shutil.copytree(self.root / "after", after)
        for family in (after / "raw/families").iterdir():
            detail = json.loads((family / "manifest.json").read_text())
            for ref in detail["attempt_jobs"].values():
                path = after / ref["path"]
                doc = json.loads(path.read_text())
                for job in doc["jobs"]:
                    for key in ("started_at", "completed_at"):
                        job[key] = (datetime.datetime.fromisoformat(job[key].replace("Z", "+00:00")) +
                                    datetime.timedelta(seconds=200)).isoformat().replace("+00:00", "Z")
                write(path, doc)
                ref["sha256"] = digest(path)
            path = family / "check-runs.json"
            doc = json.loads(path.read_text())
            for check in doc["check_runs"]:
                for key in ("started_at", "completed_at"):
                    check[key] = (datetime.datetime.fromisoformat(check[key].replace("Z", "+00:00")) +
                                  datetime.timedelta(seconds=200)).isoformat().replace("+00:00", "Z")
            write(path, doc)
            detail["check_runs_sha256"] = digest(path)
            write(family / "manifest.json", detail)
        result = self.evaluate(after=after)
        self.assertEqual(result["status"], "miss", result.get("diagnostics"))
        self.assertEqual(result["metrics"]["comparable_successful_pairs"], 20)
        self.assertEqual(result["metrics"]["candidate_runner_seconds"], 500)

    def test_missing_reserved_attempt_is_insufficient_not_a_replacement(self):
        after = self.root / "after-missing"
        shutil.copytree(self.root / "after", after)
        manifest = json.loads((after / "manifest.json").read_text())
        removed = manifest["comparison_families"].pop()
        shutil.rmtree(after / "raw/families" / removed["sample_id"])
        manifest["populations"]["pull_request"]["runs"].pop()
        population_path = after / "raw/populations/pull_request.json"
        population = json.loads(population_path.read_text())
        population["runs"].pop()
        write(population_path, population)
        manifest["source_sha256"]["pull_request"] = digest(population_path)
        write(after / "manifest.json", manifest)
        result = self.evaluate(after=after)
        self.assertEqual(result["status"], "insufficient_data")
        self.assertEqual(result["metrics"]["comparable_successful_pairs"], 19)


class AttemptAcquisition(unittest.TestCase):
    def test_collector_acquires_one_pair_with_frozen_reports_and_merge_source(self):
        """Replay-shaped fixtures use recorded schemas; no HTTP leaves the stubs."""
        rid = 38317383419
        phase = ROOT / ".planning/phases/254-speed-up-the-measured-slow-jobs"
        baseline = json.loads((ROOT / ".planning/phases/252-measure-current-ci/252-COMPARISON-CONTRACT.json").read_text())
        with tempfile.TemporaryDirectory(prefix="sigra-attempt-acquisition-") as temp:
            root = Path(temp)
            fixture_project = root / "fixture-project"
            (fixture_project / "scripts/ci").mkdir(parents=True)
            generator = (ROOT / "scripts/ci/ci-run-metrics-comparison.test.sh").read_text().split('python3 - "$TMP" "$ROOT" <<\'PY\'\n', 1)[1].split("\nPY\n", 1)[0]
            subprocess.run([sys.executable, "-", str(root), str(fixture_project)], input=generator, text=True, check=True)
            contract = json.loads((root / "contract.json").read_text())
            head = baseline["baseline_application_sha"]
            producer = baseline["baseline_identity"]["producer_source_sha"]
            contract.update(sample_identity="run_id+run_attempt", baseline_application_sha=head,
                            baseline_identity={**baseline["baseline_identity"], 'preparation_attempt': 2}, baseline_workflow_sha256=baseline["baseline_workflow_sha256"],
                            baseline_workload_revision_sha256=baseline["baseline_workload_revision_sha256"],
                            instrumentation_identity={"exunit": "exunit-v1", "playwright": "playwright-v1"})
            contract["candidate_identity"].update(application_sha=head, workflow_revision=head, producer_source_sha=producer,
                workflow_file_sha256=baseline["baseline_workflow_sha256"], workload_revision_sha256=baseline["baseline_workload_revision_sha256"])
            test_origin = datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0)
            contract['window'] = {'start_utc': (test_origin-datetime.timedelta(minutes=1)).isoformat().replace('+00:00','Z'),
                                  'end_utc': (test_origin-datetime.timedelta(minutes=1)+datetime.timedelta(hours=48)).isoformat().replace('+00:00','Z')}
            mapping = json.loads((phase / "254-WORKLOAD-MAP.json").read_text())
            for row in mapping["rows"]:
                row["after"] = row["before"]
            map_path = ROOT / "scripts/ci/.comparison-acquisition-map.json"
            parity_path = ROOT / "scripts/ci/.comparison-acquisition-parity.json"
            try:
                write(map_path, {"schema_version": "sigra.browser-coverage-map/v1", "rows": mapping["rows"]})
                # Real optimization sources have distinct revision fingerprints;
                # the retained native mapping proves their useful-work equivalence.
                contract['candidate_identity']['workload_revision_sha256']=digest(map_path)
                self.assertNotEqual(contract['candidate_identity']['workload_revision_sha256'],contract['baseline_workload_revision_sha256'])
                write(parity_path, {"schema_version": "sigra.browser-parity-receipt/v1", "status": "passed",
                    "owner_integration_status": "profiled", "mapping_sha256": digest(map_path), "baseline_source_sha": head,
                    "candidate_source_sha": head, "event": "pull_request", "owners": [{"owner": owner, "status": "passed"} for owner in OWNERS]})
                inventories = {}
                for owner in OWNERS:
                    directory = phase / "254-BASELINE-NATIVE-VERIFIED" / owner
                    descriptor = directory / "coverage-source.json"
                    doc = json.loads(descriptor.read_text())
                    selection = directory / doc["reports"][0]["selection_path"]
                    inventories[owner] = {"descriptor_path": str(descriptor.relative_to(ROOT)), "descriptor_sha256": digest(descriptor),
                        "selection_path": str(selection.relative_to(ROOT)), "selection_sha256": digest(selection), "inventory_source_sha": head}
                contract["native_coverage_comparison"] = {"mapping_path": str(map_path.relative_to(ROOT)), "mapping_sha256": digest(map_path),
                    "parity_receipt_path": str(parity_path.relative_to(ROOT)), "parity_receipt_sha256": digest(parity_path),
                    "inventories": {"before": inventories, "after": inventories}}
                from ci_metrics_security import comparison_native_inventories, legacy_playwright_artifact_matches_attempt
                invalid = json.loads(json.dumps(contract))
                invalid["native_coverage_comparison"]["inventories"]["before"]["admin_behavior"]["selection_sha256"] = "0" * 64
                with self.assertRaisesRegex(ValueError, "comparison_inventory_digest_invalid"):
                    comparison_native_inventories(invalid, "before", ROOT)
                for index, reservation in enumerate(contract["family_reservations"]):
                    reservation.update(run_id=rid, run_attempt=index + 2)
                write(root / "acquisition-contract.json", contract)
                archive = ROOT / ".planning/phases/252-measure-current-ci/252-CI-SOURCE-BUNDLE.tar.gz"
                with tarfile.open(archive) as saved:
                    prefix = f"./raw/families/{rid}/"
                    read = lambda name: saved.extractfile(prefix + name).read()
                    recorded_run = json.loads(read("run.json"))
                    pr = recorded_run['pull_requests'][0]
                    contract['baseline_identity'].update(branch=pr['head']['ref'], parent_main_sha=pr['base']['sha'])
                    contract['baseline_identity'].pop('run_id')
                    write(root / 'acquisition-contract.json', contract)
                    recorded_jobs = json.loads(read("jobs-attempt-1.json"))
                    recorded_checks = json.loads(read("check-runs.json"))
                    recorded_metadata = json.loads(read("artifacts-metadata.json"))
                    recorded_artifact_origins = {str(entry["artifact"]["id"]): entry["artifact"]["workflow_run"]
                                                 for entry in json.loads(read("artifact-evidence.json"))}
                    recorded_detail = json.loads(read("manifest.json"))
                    producer_ref = recorded_detail["producer_commits"][producer]
                    source_documents = {"commit": json.loads(saved.extractfile("./" + producer_ref["commit_path"]).read()),
                        "tree": json.loads(saved.extractfile("./" + producer_ref["tree_path"]).read()),
                        "workflow": {"encoding": "base64", "content": base64.b64encode(saved.extractfile("./" + producer_ref["workflow_path"]).read()).decode()}}
                    payloads = {str(item["id"]): read(f"artifacts/{item['id']}.zip") for item in recorded_metadata["artifacts"]
                                if any(member.name == prefix + f"artifacts/{item['id']}.zip" for member in saved.getmembers())}
                transport = root / "bin"
                transport.mkdir()
                stub = '''#!/usr/bin/env python3
import json,os,pathlib,sys,urllib.parse
root=pathlib.Path(os.environ['ATTEMPT_TRANSPORT'])
args=sys.argv[1:]
if pathlib.Path(sys.argv[0]).name=='gh':
 endpoint=args[-1]; table=json.loads((root/'routes.json').read_text())
 if endpoint not in table: print('unstubbed endpoint '+endpoint,file=sys.stderr);sys.exit(1)
 sys.stdout.buffer.write((root/table[endpoint]).read_bytes())
else:
 url=args[-1]
 pathlib.Path(args[args.index('--dump-header')+1]).write_text('HTTP/1.1 200 OK\\r\\n\\r\\n')
 if '/actions/jobs/' in url:
  pathlib.Path(args[args.index('--output')+1]).write_bytes(b'checkout details\\n'+b'x'*20000+b'\\nPostgreSQL image pull: authentication required\\n')
 else:
  aid=url.split('/artifacts/')[1].split('/')[0]
  pathlib.Path(args[args.index('--output')+1]).write_bytes((root/(aid+'.zip')).read_bytes())
 print('200',end='')
'''
                for command in ("gh", "curl"):
                    (transport / command).write_text(stub)
                    (transport / command).chmod(0o755)
                ledger_path = root / "early-registration.json"
                from ci_metrics_security import register_comparison_run
                ledger = None
                pair_runs = []
                for offset, role in enumerate(("before", "after")):
                    attempt = offset + 2
                    origin = test_origin + datetime.timedelta(seconds=offset*10)
                    delta = origin - datetime.datetime.fromisoformat(recorded_run["created_at"].replace("Z", "+00:00"))
                    def shifted(value):
                        if isinstance(value, dict):
                            return {key: (str(attempt) if isinstance(item, str) else attempt) if key.endswith("run_attempt")
                                    else shifted(item) for key, item in value.items()}
                        if isinstance(value, list):
                            return [shifted(item) for item in value]
                        if isinstance(value, str):
                            if len(value) > 19 and value[:4] == "2026" and "T" in value and value.endswith("Z"):
                                try:
                                    return (datetime.datetime.fromisoformat(value.replace("Z", "+00:00")) + delta).isoformat().replace("+00:00", "Z")
                                except ValueError:
                                    pass
                            return value.replace(f"-{rid}-1", f"-{rid}-{attempt}")
                        return value
                    run = shifted(recorded_run)
                    run.update(created_at=recorded_run["created_at"], run_started_at=origin.isoformat().replace("+00:00", "Z"), run_attempt=attempt)
                    jobs = shifted(recorded_jobs)
                    checks = shifted(recorded_checks)
                    for job in jobs["jobs"]:
                        job["run_attempt"] = attempt
                    early = {**run, "status": "in_progress", "conclusion": None}
                    write(root / ('early-' + role + '.json'), early)
                    raw = json.dumps(early, sort_keys=True, separators=(",", ":")).encode()
                    reservation = contract["family_reservations"][offset]
                    ledger = register_comparison_run(contract, reservation["reservation_id"], early,
                        api_run_sha256=hashlib.sha256(raw).hexdigest(), api_run_response_bytes=raw, ledger=ledger)
                    if role == 'after':
                        # The other reservation has no transport route. Collection must
                        # retain exactly this attempt, without reacquiring earlier slots.
                        for other_index in (2, 3):
                            other = {**early, 'run_attempt': other_index + 2,
                                     'run_started_at': (origin+datetime.timedelta(seconds=other_index)).isoformat().replace('+00:00','Z')}
                            other_raw = json.dumps(other, sort_keys=True, separators=(',', ':')).encode()
                            ledger = register_comparison_run(contract, contract['family_reservations'][other_index]['reservation_id'], other,
                                api_run_sha256=hashlib.sha256(other_raw).hexdigest(), api_run_response_bytes=other_raw, ledger=ledger)
                    write(ledger_path, ledger)
                    directory = root / ("transport-" + role)
                    directory.mkdir()
                    metadata = shifted(recorded_metadata)
                    retained_artifacts = []
                    for artifact in metadata["artifacts"]:
                        old_id = str(artifact["id"])
                        if old_id not in payloads or not any(word in artifact["name"] for word in ("timing", "playwright", "measurement-metadata")):
                            continue
                        aid = artifact["id"] + attempt * 1000000000000
                        artifact["id"] = aid
                        artifact["workflow_run"].pop("run_attempt", None)
                        # Restore fields from the archived raw API receipt, not its reduced projection.
                        artifact["workflow_run"].update(recorded_artifact_origins[old_id])
                        output = io.BytesIO()
                        with zipfile.ZipFile(io.BytesIO(payloads[old_id])) as original, zipfile.ZipFile(output, "w") as zipped:
                            for member in original.infolist():
                                if member.is_dir() or not member.filename.endswith(".json"):
                                    continue
                                data = json.dumps(shifted(json.loads(original.read(member))), separators=(",", ":")).encode()
                                zipped.writestr(member.filename, data)
                        (directory / f"{aid}.zip").write_bytes(output.getvalue())
                        artifact["digest"] = "sha256:" + digest(directory / f"{aid}.zip")
                        artifact["expired"] = False
                        retained_artifacts.append(artifact)
                    if role == 'after':
                        for owner_index, owner in enumerate(OWNERS, 1):
                            # The actual candidate adds this known native record
                            # to its artifact. It must be retained, not rejected
                            # as an unexpected JSON member.
                            aid = 9000000000000 + owner_index
                            output = io.BytesIO()
                            with zipfile.ZipFile(output, 'w') as zipped:
                                zipped.writestr('execution-record.json', json.dumps({'schema_version':'sigra.browser-execution-record/v1',
                                    'run_id':str(rid),'run_attempt':str(attempt),'source_sha':producer,'seam':owner}))
                            (directory / f'{aid}.zip').write_bytes(output.getvalue())
                            retained_artifacts.append({**retained_artifacts[0], 'id':aid,
                                'name':f'browser-execution-{owner}-{rid}-{attempt}',
                                'digest':'sha256:'+digest(directory / f'{aid}.zip')})
                    routes = {}
                    diagnostic = next(item for item in retained_artifacts if item["name"] == f"example-playwright-admin_behavior-{rid}")
                    self.assertTrue(legacy_playwright_artifact_matches_attempt(diagnostic, run, jobs["jobs"], attempt))
                    stale = {**diagnostic, "created_at": "2026-10-12T00:00:00Z"}
                    self.assertFalse(legacy_playwright_artifact_matches_attempt(stale, run, jobs["jobs"], attempt))
                    self.assertFalse(legacy_playwright_artifact_matches_attempt(diagnostic, run, jobs["jobs"], attempt - 1))
                    def route(endpoint, name, value):
                        write(directory / name, value)
                        routes[endpoint] = name
                    route("rate_limit", "rate.json", {"resources": {"core": {"remaining": 5000, "reset": 2000000000}}})
                    route("/repos/szTheory/sigra/rules/branches/main", "rules.json", [{"type": "required_status_checks", "ruleset_id": 1,
                        "parameters": {"required_status_checks": [{"context": name} for name in contract["required_contexts"]]}}])
                    route("/repos/szTheory/sigra/branches/main/protection/required_status_checks", "protection.json", {"contexts": contract["required_contexts"]})
                    route("/repos/szTheory/sigra/rulesets?per_page=100", "rulesets.json", [])
                    route(f"/repos/szTheory/sigra/actions/runs/{rid}/attempts/{attempt}", "run.json", run)
                    route(f"/repos/szTheory/sigra/actions/runs/{rid}/attempts/{attempt}/jobs?per_page=100", "jobs.json", jobs)
                    route("/repos/szTheory/sigra/pulls/331/files?per_page=100&page=1", "changes.json", [{"filename": "lib/sigra.ex", "status": "modified"}]
                          + [{'filename':f'guides/example-{index}.md','status':'modified'} for index in range(99)])
                    route(f"/repos/szTheory/sigra/commits/{head}/check-runs?per_page=100", "checks.json", checks)
                    route(f"/repos/szTheory/sigra/actions/runs/{rid}/artifacts?per_page=100", "artifacts.json", {"total_count": len(retained_artifacts), "artifacts": retained_artifacts})
                    route(f"/repos/szTheory/sigra/commits/{producer}", "commit.json", source_documents["commit"])
                    route(f"/repos/szTheory/sigra/git/trees/{source_documents['tree']['sha']}?recursive=1", "tree.json", source_documents["tree"])
                    route(f"/repos/szTheory/sigra/contents/.github/workflows/ci.yml?ref={producer}", "workflow.json", source_documents["workflow"])
                    write(directory / "routes.json", routes)
                    environment = {**os.environ, "PATH": str(transport) + os.pathsep + os.environ["PATH"],
                        "GH_TOKEN": "synthetic-fixture-token", "ATTEMPT_TRANSPORT": str(directory)}
                    bundle = root / ("collected-" + role)
                    command = ["bash", str(ROOT / "scripts/ci/ci-run-metrics.sh"), "--collect-comparison", "--comparison-role", role,
                        "--reservation-id", reservation['reservation_id'],
                        "--contract", str(root / "acquisition-contract.json"), "--registrations", str(ledger_path),
                        "--request-budget-ledger", str(root / "budget.json"), "--source-bundle", str(bundle)]
                    result = subprocess.run(command, cwd=ROOT, env=environment, capture_output=True, text=True, timeout=120)
                    self.assertEqual(result.returncode, 0, result.stderr[-3000:])
                    manifest = json.loads((bundle / "manifest.json").read_text())
                    self.assertEqual(manifest["comparison_collection"]["origin_status"], "passed", manifest["comparison_collection"])
                    from ci_metrics_security import verify_snapshot_hashes
                    self.assertEqual(verify_snapshot_hashes(bundle), [])
                    if role == 'after':
                        evidence = json.loads((bundle / f'raw/families/{rid}-attempt-{attempt}/artifact-evidence.json').read_text())
                        records = [row for row in evidence if row['artifact']['name'].startswith('browser-execution-')]
                        self.assertEqual(len(records), 5)
                        self.assertTrue(all(row['result']['status']=='accepted' for row in records), records)
                    raw_run = bundle / f"raw/families/{rid}-attempt-{attempt}/run.json"
                    self.assertEqual(json.loads(raw_run.read_text())["run_attempt"], attempt)
                    self.assertEqual(list((bundle / "raw/families").iterdir()), [raw_run.parent])
                    detail = json.loads((raw_run.parent / 'manifest.json').read_text())
                    self.assertEqual(detail['changed_paths_status'], 'non_docs_witness')
                    self.assertEqual(detail['workload'], 'full')
                    self.assertTrue(all(len(list((raw_run.parent / "artifacts/derived-native" / owner).glob("coverage-source.json"))) == 1 for owner in OWNERS))
                    if role == 'before':
                        # An always-uploaded metadata artifact can have valid
                        # origin even when its producing browser test failed.
                        # Retain that failed observation and reject eligibility
                        # for its actual outcome, never call it an origin error.
                        failed_jobs = json.loads(json.dumps(jobs))
                        checkpoint = [job for job in failed_jobs['jobs']
                                      if job['name'] == 'Example Playwright shard (admin_checkpoints)']
                        self.assertEqual(len(checkpoint), 1)
                        checkpoint[0]['conclusion'] = 'failure'
                        write(directory / 'jobs.json', failed_jobs)
                        write(directory / 'run.json', {**run, 'conclusion': 'failure'})
                        failed_bundle = root / 'collected-before-failed-job'
                        try:
                            failed_collection = subprocess.run(command[:-1] + [str(failed_bundle)], cwd=ROOT,
                                env=environment, capture_output=True, text=True, timeout=120)
                            self.assertNotEqual(failed_collection.returncode, 0)
                            self.assertIn(f'attempt_measurement_job_not_successful:{rid}-attempt-{attempt}:'
                                          'Example Playwright shard (admin_checkpoints):failure', failed_collection.stderr)
                            self.assertNotIn('attempt_measurement_metadata_origin_invalid', failed_collection.stderr)
                            failed_raw = failed_bundle / f'raw/families/{rid}-attempt-{attempt}'
                            self.assertEqual(json.loads((failed_raw / 'run.json').read_text())['conclusion'], 'failure')
                            failed_manifest = json.loads((failed_bundle / 'manifest.json').read_text())
                            self.assertFalse(failed_manifest.get('comparison_families'))
                            self.assertFalse((failed_raw / 'artifacts/derived-native').exists())
                        finally:
                            write(directory / 'jobs.json', jobs)
                            write(directory / 'run.json', run)
                        # The isolated diagnostic uses the same bounded, digest-checked artifact transport.
                        chosen = retained_artifacts[0]
                        write(root / 'single-artifact.json', chosen)
                        download_command = ['bash', str(ROOT / 'scripts/ci/ci-run-metrics.sh'),
                            '--bounded-artifact-download', '--validate-artifact-json', str(root / 'single-artifact.json'),
                            '--run-json', str(directory / 'run.json'), '--contract', str(root / 'acquisition-contract.json'),
                            '--request-budget-ledger', str(root / 'budget.json')]
                        downloaded = root / 'single-artifact.zip'
                        acquired = subprocess.run(download_command + ['--output', str(downloaded)],
                            cwd=ROOT, env=environment, capture_output=True, text=True, timeout=30)
                        self.assertEqual(acquired.returncode, 0, acquired.stderr)
                        self.assertEqual('sha256:' + digest(downloaded), chosen['digest'])
                        write(root / 'single-artifact.json', {**chosen, 'digest': 'sha256:' + '0' * 64})
                        rejected = subprocess.run(download_command + ['--output', str(root / 'tampered-artifact.zip')],
                            cwd=ROOT, env=environment, capture_output=True, text=True, timeout=30)
                        self.assertNotEqual(rejected.returncode, 0)
                        self.assertFalse((root / 'tampered-artifact.zip').exists())
                        preparation = subprocess.run(['bash', str(ROOT / 'scripts/ci/ci-run-metrics.sh'),
                            '--collect-preparation', '--comparison-role', role, '--contract', str(root / 'acquisition-contract.json'),
                            '--run-json', str(root / 'early-before.json'), '--request-budget-ledger', str(root / 'budget.json'),
                            '--source-bundle', str(root / 'preparation-before')], cwd=ROOT, env=environment,
                            capture_output=True, text=True, timeout=120)
                        self.assertEqual(preparation.returncode, 0, preparation.stderr[-3000:])
                        prepared = json.loads((root / 'preparation-before/preparation-origin-verification.json').read_text())
                        self.assertEqual(prepared['status'], 'origin_verified')
                        failed_job = {**jobs['jobs'][0], 'conclusion':'failure'}
                        write(root / 'failed-job-receipt.json', {'jobs':[failed_job]})
                        failed_log = subprocess.run(['bash', str(ROOT / 'scripts/ci/ci-run-metrics.sh'),
                            '--collect-failed-job-log', str(failed_job['id']), '--failed-job-receipt', str(root / 'failed-job-receipt.json'),
                            '--contract', str(root / 'acquisition-contract.json'), '--request-budget-ledger', str(root / 'budget.json'),
                            '--output', str(root / 'container-failure.log')], cwd=ROOT, env=environment,
                            capture_output=True, text=True, timeout=30)
                        self.assertEqual(failed_log.returncode, 0, failed_log.stderr)
                        self.assertIn('authentication required', (root / 'container-failure.log').read_text())
                        failed_job['conclusion']='cancelled'
                        write(root/'cancelled-job-receipt.json',{'jobs':[failed_job]})
                        annotations=root/'timeout-annotations.json'
                        write(annotations,[{'annotation_level':'failure','message':'The job has exceeded the maximum execution time of 30m0s'}])
                        write(Path(str(annotations)+'.requests.json'),{'requests':[f"/repos/szTheory/sigra/check-runs/{failed_job['id']}/annotations"]})
                        timeout_command=['bash',str(ROOT/'scripts/ci/ci-run-metrics.sh'),'--collect-failed-job-log',str(failed_job['id']),
                            '--failed-job-receipt',str(root/'cancelled-job-receipt.json'),'--contract',str(root/'acquisition-contract.json'),
                            '--request-budget-ledger',str(root/'budget.json'),'--output',str(root/'timeout.log')]
                        denied=subprocess.run(timeout_command,cwd=ROOT,env=environment,capture_output=True,text=True,timeout=30)
                        self.assertNotEqual(denied.returncode,0)
                        allowed=subprocess.run(timeout_command+['--timeout-annotations',str(annotations)],cwd=ROOT,env=environment,capture_output=True,text=True,timeout=30)
                        self.assertEqual(allowed.returncode,0,allowed.stderr)
                    pair_runs.append(raw_run.parent)
                # Verify actual derived native bytes through the existing comparator for every owner.
                for owner in OWNERS:
                    local_map = root / (owner + ".json")
                    write(local_map, {"schema_version": "sigra.browser-coverage-map/v1", "rows": [row for row in mapping["rows"] if row["owner"] == owner]})
                    result = subprocess.run(["node", str(ROOT / "scripts/ci/ci-browser-records.mjs"), "--compare-coverage",
                        "--before-directory", str(pair_runs[0] / "artifacts/derived-native" / owner),
                        "--after-directory", str(pair_runs[1] / "artifacts/derived-native" / owner), "--mapping", str(local_map)],
                        cwd=ROOT, capture_output=True, text=True, timeout=30)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(json.loads(result.stdout)["status"], "passed")
                evaluation = subprocess.run(["bash", str(ROOT / "scripts/ci/ci-run-metrics.sh"), "--evaluate-comparison",
                    "--contract", str(root / "acquisition-contract.json"), "--registrations", str(ledger_path),
                    "--before-bundle", str(root / "collected-before"), "--after-bundle", str(root / "collected-after"),
                    "--baseline-source-bundle", str(archive), "--format", "json"], cwd=ROOT, capture_output=True, text=True, timeout=60)
                self.assertEqual(evaluation.returncode, 0, evaluation.stderr[-2500:])
                report = json.loads(evaluation.stdout)
                self.assertEqual(report["status"], "insufficient_data")
                self.assertEqual(report["metrics"]["comparable_successful_pairs"], 1, report["diagnostics"])
                self.assertEqual(report["metrics"]["native_parity"]["origin_status"], "passed", report["diagnostics"])
                changed_manifest=root/'collected-after/manifest.json'
                original_manifest=json.loads(changed_manifest.read_text())
                for field,reason in [('source_workload_revision_sha256','after_family_source_workload_identity_mismatch'),
                                     ('coverage_map_sha256','after_family_coverage_map_identity_mismatch')]:
                    altered=json.loads(json.dumps(original_manifest));altered['comparison_families'][0][field]='0'*64
                    write(changed_manifest,altered)
                    bad=subprocess.run(["bash",str(ROOT/"scripts/ci/ci-run-metrics.sh"),"--evaluate-comparison",
                        "--contract",str(root/"acquisition-contract.json"),"--registrations",str(ledger_path),
                        "--before-bundle",str(root/"collected-before"),"--after-bundle",str(root/"collected-after"),
                        "--baseline-source-bundle",str(archive),"--format","json"],cwd=ROOT,capture_output=True,text=True,timeout=60)
                    invalid=json.loads(bad.stdout)
                    self.assertEqual(invalid['status'],'insufficient_data')
                    self.assertIn(reason,{row['reason'] for row in invalid['diagnostics']})
                write(changed_manifest,original_manifest)
                self.assertEqual(report["metrics"]["native_parity"]["status"], "passed", report["diagnostics"])
                self.assertFalse(any("origin" in row["reason"] or "unverified" in row["reason"] for row in report["diagnostics"]), report["diagnostics"])
                derived = pair_runs[0] / "artifacts/derived-native/admin_behavior/report.json"
                derived.write_bytes(derived.read_bytes() + b" ")
                self.assertTrue(any("derived_native_origin_or_digest_mismatch" in issue for issue in verify_snapshot_hashes(root / "collected-before")))
            finally:
                map_path.unlink(missing_ok=True)
                parity_path.unlink(missing_ok=True)


class ApprovedInventoryAmendment(unittest.TestCase):
    def test_independent_image_reader_rejects_conflicting_or_tampered_native_proof(self):
        from ci_metrics_security import comparison_runner_images
        module=(ROOT/'scripts/ci/ci-runner-image.mjs').as_uri()
        javascript = """
import {captureRunnerImage, verifyRunnerImage} from MODULE;
const env={ImageOS:'ubuntu24',ImageVersion:'20261012.334.1',GITHUB_REPOSITORY:'szTheory/sigra',
 GITHUB_RUN_ID:'9001',GITHUB_RUN_ATTEMPT:'1',GITHUB_SHA:'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',GITHUB_JOB:'example_playwright_shard',MATRIX_SEAM:'design_gallery'};
const input={imageData:Buffer.from(JSON.stringify([{group:'Runner Image',detail:'Image: ubuntu-24.04\\nVersion: 20261012.334.1'}])),
 osRelease:Buffer.from('ID=ubuntu\\nVERSION_ID="24.04"\\n'),machine:'x86_64',env};
const proof=captureRunnerImage(input);const verification=verifyRunnerImage({proof,...input});
console.log(JSON.stringify({repository:env.GITHUB_REPOSITORY,run_id:'9001',run_attempt:'1',source_sha:env.GITHUB_SHA,
 matrix_seam:'design_gallery',job_name:'Example Playwright shard',runner_os:'Linux',runner_arch:'X64',
 runner_image:{...proof.runner_image,source_proof:proof,verification}}));
""".replace('MODULE',json.dumps(module))
        result=subprocess.run(['node','--input-type=module','-e',javascript],capture_output=True,text=True,check=True)
        row=json.loads(result.stdout)
        actual=comparison_runner_images([row],require_proof=True)
        self.assertEqual(actual['Example Playwright shard (design_gallery)']['image_version'],'20261012.334.1')
        differing = javascript.replace("ImageVersion:'20261012.334.1'", "ImageVersion:'20261023.334.3'")
        observed = subprocess.run(['node','--input-type=module','-e',differing],capture_output=True,text=True,check=True)
        diagnostic_row = json.loads(observed.stdout)
        self.assertFalse(diagnostic_row['runner_image']['source_proof']['environment_agrees'])
        self.assertEqual(comparison_runner_images([diagnostic_row],require_proof=True), actual)
        historical = ROOT/'.planning/execution/254-environment-recovery/PREPARATION/IMAGE-METADATA-before.json'
        if historical.is_file():
            with self.assertRaisesRegex(ValueError,'comparison_runner_image_proof_invalid'):
                comparison_runner_images([json.loads(historical.read_text())],require_proof=True)
        for mutation in ('missing','bytes','environment','run','verification'):
            changed=json.loads(json.dumps(row))
            if mutation=='missing':changed['runner_image'].pop('source_proof')
            elif mutation=='bytes':changed['runner_image']['source_proof']['image_file']['base64']=base64.b64encode(b'[]').decode()
            elif mutation=='environment':changed['runner_image']['source_proof']['environment_image']['image_version']='20261023.334.3'
            elif mutation=='run':changed['run_id']='9002'
            else:changed['runner_image']['verification']['status']='image_identity_conflict'
            with self.assertRaisesRegex(ValueError,'comparison_runner_image_proof_invalid'):
                comparison_runner_images([changed],require_proof=True)

    def test_same_image_set_does_not_hide_images_swapped_between_browser_owners(self):
        from ci_metrics_security import comparison_runner_images
        def row(owner,version):
            return {'job_name':'Example Playwright shard','matrix_seam':owner,'runner_os':'Linux','runner_arch':'X64',
                    'runner_image':{'image_os':'ubuntu24','image_version':version}}
        before=[row('design_gallery','new'),row('demo_showcase','old')]
        after=[row('design_gallery','old'),row('demo_showcase','new')]
        self.assertEqual({r['runner_image']['image_version'] for r in before},{r['runner_image']['image_version'] for r in after})
        self.assertNotEqual(comparison_runner_images(before),comparison_runner_images(after))

    def test_only_the_explicitly_approved_workflow_change_can_reuse_the_original_inventory(self):
        from ci_metrics_security import comparison_native_inventories, validate_profiled_receipt_sources
        path=ROOT/'.planning/execution/254-rebaseline-preparation/NATIVE-INVENTORY-CONTRACT.json'
        contract=json.loads(path.read_text())
        retained_receipt=json.loads((ROOT/'.planning/phases/254-speed-up-the-measured-slow-jobs/254-INTEGRATION-CHECK-FINAL8-PARITY-RECEIPT.json').read_text())
        validate_profiled_receipt_sources(contract,retained_receipt,ROOT)
        invalid_receipt={**retained_receipt,'candidate_source_sha':'0'*40}
        with self.assertRaisesRegex(ValueError,'source_equivalence_missing'):
            validate_profiled_receipt_sources(contract,invalid_receipt,ROOT)
        for role in ('before','after'):
            inventories=comparison_native_inventories(contract,role,ROOT)
            self.assertEqual(len(inventories),5)
            self.assertTrue(all(row['workflow_authorization_sha256'] for row in inventories.values()))
            invalid=json.loads(json.dumps(contract))
            invalid['native_coverage_comparison']['source_equivalence'][role]['authorization_sha256']='0'*64
            with self.assertRaisesRegex(ValueError,'inventory_digest_invalid'):
                comparison_native_inventories(invalid,role,ROOT)
            invalid=json.loads(json.dumps(contract))
            invalid['native_coverage_comparison'].pop('source_equivalence')
            with self.assertRaisesRegex(ValueError,'amendment_not_approved'):
                comparison_native_inventories(invalid,role,ROOT)


class BoundedPreparation(unittest.TestCase):
    def test_fixed_source_update_is_nonforcing_once_only_and_checks_previous_head(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);binary=root/'bin';binary.mkdir();calls=root/'calls.jsonl'
            stub=binary/'gh'
            stub.write_text("""#!/usr/bin/env python3
import json,os,sys
args=sys.argv[1:];method=args[args.index('--method')+1];endpoint=args[args.index('--method')+2]
with open(os.environ['SOURCE_UPDATE_CALLS'],'a') as out:out.write(json.dumps([method,endpoint])+'\\n')
if endpoint=='rate_limit':print(json.dumps({'resources':{'core':{'remaining':5000,'reset':2000000000}}}))
else:print(json.dumps({'ref':'refs/heads/evidence/phase254-fixture','object':{'sha':'b'*40 if method=='PATCH' else os.environ.get('SOURCE_UPDATE_OLD','a'*40)}}))
""")
            stub.chmod(0o755)
            endpoint='/repos/szTheory/sigra/git/refs/heads/evidence/phase254-fixture'
            contract={'request_budget_ledger_id':'f'*64,'maximum_mutations':2,'authorized_mutations':[endpoint],
                'preparation_order':['before','after'],'baseline_identity':{'branch':'evidence/phase254-fixture','application_sha':'b'*40,'reviewed_source':'a'*40}}
            write(root/'contract.json',contract);write(root/'body.json',{'sha':'b'*40,'force':False})
            env={**os.environ,'PATH':str(binary)+os.pathsep+os.environ['PATH'],'SOURCE_UPDATE_CALLS':str(calls)}
            command=['bash',str(ROOT/'scripts/ci/ci-run-metrics.sh'),'--bounded-request',endpoint,'--request-method','PATCH',
                '--request-body',str(root/'body.json'),'--comparison-role','before','--contract',str(root/'contract.json'),
                '--request-budget-ledger',str(root/'budget.json')]
            first=subprocess.run(command+['--output',str(root/'first.json')],env=env,cwd=ROOT,capture_output=True,text=True,timeout=30)
            self.assertEqual(first.returncode,0,first.stderr)
            self.assertIn(['GET', endpoint.replace('/git/refs/', '/git/ref/')], [json.loads(line) for line in calls.read_text().splitlines()])
            again=subprocess.run(command+['--output',str(root/'again.json')],env=env,cwd=ROOT,capture_output=True,text=True,timeout=30)
            self.assertNotEqual(again.returncode,0)
            self.assertEqual(sum(json.loads(line)[0]=='PATCH' for line in calls.read_text().splitlines()),1)
            write(root/'body.json',{'sha':'b'*40,'force':True})
            forcing=subprocess.run(command+['--output',str(root/'forcing.json')],env=env,cwd=ROOT,capture_output=True,text=True,timeout=30)
            self.assertNotEqual(forcing.returncode,0)
            write(root/'body.json',{'sha':'b'*40,'force':False})
            changed=subprocess.run(command+['--output',str(root/'changed.json')],env={**env,'SOURCE_UPDATE_OLD':'c'*40},cwd=ROOT,capture_output=True,text=True,timeout=30)
            self.assertNotEqual(changed.returncode,0)
            self.assertIn('source_update_previous_ref_changed',changed.stderr)
            self.assertEqual(sum(json.loads(line)[0]=='PATCH' for line in calls.read_text().splitlines()),1)

    def test_two_initial_pr_triggers_have_distinct_frozen_roles_and_no_retries(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            transport = root / 'bin'
            transport.mkdir()
            gh = transport / 'gh'
            gh.write_text('''#!/usr/bin/env python3
import json,os,pathlib,sys
args=sys.argv[1:]; endpoint=args[args.index('--method')+2]
with pathlib.Path(os.environ['TRANSPORT_LOG']).open('a') as out: out.write(json.dumps(args)+'\\n')
print(json.dumps({'resources':{'core':{'remaining':5000,'reset':2000000000}}}) if endpoint=='rate_limit' else '{}')
''')
            gh.chmod(0o755)
            endpoint = '/repos/szTheory/sigra/pulls'
            contract = {'request_budget_ledger_id':'b'*64, 'maximum_mutations':2,
                'authorized_mutations':[endpoint], 'preparation_order':['before','after'],
                'baseline_identity':{'branch':'evidence/phase254-new-before'},
                'candidate_identity':{'branch':'evidence/phase254-new-after'}}
            write(root/'contract.json',contract)
            env={**os.environ,'PATH':str(transport)+os.pathsep+os.environ['PATH'],'TRANSPORT_LOG':str(root/'transport.jsonl')}
            def invoke(role, sequence):
                branch=contract['baseline_identity' if role=='before' else 'candidate_identity']['branch']
                write(root/f'body-{sequence}.json',{'head':branch,'base':'main','draft':True,'title':'fixture'})
                return subprocess.run(['bash',str(ROOT/'scripts/ci/ci-run-metrics.sh'),'--bounded-request',endpoint,
                    '--request-method','POST','--request-body',str(root/f'body-{sequence}.json'),'--comparison-role',role,
                    '--contract',str(root/'contract.json'),'--request-budget-ledger',str(root/'budget.json'),
                    '--output',str(root/f'output-{sequence}.json')],env=env,capture_output=True,text=True)
            self.assertNotEqual(invoke('after',0).returncode,0)
            self.assertEqual(invoke('before',1).returncode,0)
            self.assertNotEqual(invoke('before',2).returncode,0)
            self.assertEqual(invoke('after',3).returncode,0)
            self.assertNotEqual(invoke('after',4).returncode,0)
            ledger=json.loads((root/'budget.json').read_text())
            self.assertEqual([row['mutation_key'] for row in ledger['records'] if row['kind']=='mutation'],['before','after'])
            calls=[json.loads(line) for line in (root/'transport.jsonl').read_text().splitlines()]
            self.assertEqual(sum(row[row.index('--method')+1]=='POST' for row in calls),2)

    def test_mutations_are_once_only_and_share_the_collection_budget(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            transport = root / 'bin'
            transport.mkdir()
            gh = transport / 'gh'
            gh.write_text('''#!/usr/bin/env python3
import json,os,pathlib,sys
args=sys.argv[1:]; endpoint=args[args.index('--method')+2]
with pathlib.Path(os.environ['TRANSPORT_LOG']).open('a') as out: out.write(json.dumps(args)+'\\n')
if endpoint=='rate_limit': print(json.dumps({'resources':{'core':{'remaining':5000,'reset':2000000000}}}))
elif os.environ.get('FAIL_POST')=='1': print('HTTP 503 unavailable',file=sys.stderr);sys.exit(1)
else: print('{}')
''')
            gh.chmod(0o755)
            endpoint = '/repos/szTheory/sigra/actions/runs/38317383419/rerun'
            contract = {'request_budget_ledger_id': 'a' * 64, 'maximum_mutations': 2,
                        'authorized_mutations': [endpoint]}
            write(root / 'contract.json', contract)
            env = {**os.environ, 'PATH': str(transport) + os.pathsep + os.environ['PATH'],
                   'TRANSPORT_LOG': str(root / 'transport.jsonl')}
            def invoke(output, extra_env=None):
                return subprocess.run(['bash', str(ROOT / 'scripts/ci/ci-run-metrics.sh'),
                    '--bounded-request', endpoint, '--request-method', 'POST',
                    '--contract', str(root / 'contract.json'), '--request-budget-ledger', str(root / 'budget.json'),
                    '--output', str(root / output)], env={**env, **(extra_env or {})}, capture_output=True, text=True)
            # A timeout/5xx on a mutation is uncertain and must consume the slot, without retry.
            failed = invoke('uncertain.json', {'FAIL_POST': '1'})
            self.assertNotEqual(failed.returncode, 0)
            second = invoke('duplicate.json')
            self.assertNotEqual(second.returncode, 0)
            calls = [json.loads(line) for line in (root / 'transport.jsonl').read_text().splitlines()]
            self.assertEqual(sum('--method' in row and row[row.index('--method')+1]=='POST' for row in calls), 1)
            ledger = json.loads((root / 'budget.json').read_text())
            self.assertEqual(sum(row['kind']=='request' for row in ledger['records']), 3)
            self.assertEqual(sum(row['kind']=='mutation' for row in ledger['records']), 1)
            # A spent shared clock also stops the read before transport.
            ledger['started_at_epoch'] -= 3601
            write(root / 'budget.json', ledger)
            third = invoke('expired.json')
            self.assertNotEqual(third.returncode, 0)
            self.assertEqual(len((root / 'transport.jsonl').read_text().splitlines()), 3)


if __name__ == "__main__":
    unittest.main()
