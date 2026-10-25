"""Pure validators for data crossing the Phase 252 CI evidence trust boundaries."""

from __future__ import annotations

import hashlib
import json
import pathlib
import re
import base64
import urllib.parse
import zipfile


def _digest(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _matches(path: pathlib.Path, expected: object) -> bool:
    return isinstance(expected, str) and bool(re.fullmatch(r"[0-9a-f]{64}", expected)) and path.is_file() and _digest(path) == expected


def verify_snapshot_hashes(bundle: pathlib.Path) -> list[str]:
    """Check every source file that replay may consume before parsing any of them."""
    bundle = pathlib.Path(bundle)
    diagnostics: list[str] = []
    try:
        manifest = json.loads((bundle / "manifest.json").read_text())
    except (OSError, ValueError):
        return ["snapshot_manifest_invalid"]
    hashes = manifest.get("source_sha256") or {}
    paths = {
        "request_ledger": bundle / "request-ledger.json",
        "selection_ledger": bundle / "selection-ledger.json",
    }
    for event in ("pull_request", "push_main", "schedule", "manual", "release_push"):
        paths[event] = bundle / "raw" / "populations" / f"{event}.json"
    for key, filename in (("rate_limit", "rate-limit.json"), ("effective_rules", "effective-rules.json"),
                          ("branch_protection", "branch-protection.json"), ("rulesets", "rulesets.json")):
        paths[key] = bundle / "raw" / filename
    for key, path in paths.items():
        if not _matches(path, hashes.get(key)):
            diagnostics.append(f"snapshot_hash_mismatch:{key}")

    try:
        ledger = json.loads((bundle / "request-ledger.json").read_text())
        requests = set(ledger.get("requests", []))
        repository = manifest.get("repository")
        population_runs = []
        for event in ("pull_request", "push_main", "schedule"):
            data = json.loads((bundle / "raw" / "populations" / f"{event}.json").read_text())
            population_runs.extend(data.get("runs", []))
    except (OSError, ValueError, TypeError):
        requests, population_runs, repository = set(), [], None

    for name, expected in (manifest.get("source_file_sha256") or {}).items():
        path = bundle / "source" / name
        if not path.resolve().is_relative_to((bundle / "source").resolve()) or not _matches(path, expected):
            diagnostics.append(f"snapshot_source_file_hash_mismatch:{name}")

    for family in sorted((bundle / "raw" / "families").glob("*")):
        manifest_path = family / "manifest.json"
        if not manifest_path.is_file():
            continue
        try:
            facts = json.loads(manifest_path.read_text())
        except (OSError, ValueError):
            diagnostics.append(f"family_manifest_invalid:{family.name}")
            continue
        run_path = family / "run.json"
        try:
            family_run = json.loads(run_path.read_text())
            matches = [row for row in population_runs if str(row.get("id")) == str(family_run.get("id")) and row.get("run_attempt") == family_run.get("run_attempt")]
            identity_keys = ("id", "head_sha", "event", "path", "run_attempt", "created_at", "pull_requests")
            if len(matches) != 1 or any(matches[0].get(key) != family_run.get(key) for key in identity_keys):
                diagnostics.append(f"family_run_population_binding_invalid:{family.name}")
            if repository != "szTheory/sigra" or facts.get("run_id") != family_run.get("id"):
                diagnostics.append(f"family_repository_or_run_identity_invalid:{family.name}")
        except (OSError, ValueError, TypeError):
            family_run = {}
            diagnostics.append(f"family_run_identity_invalid:{family.name}")
        refs = [("run", facts.get("source_run_sha256"), family / "run.json")]
        for item in facts.get("changed_path_pages", []):
            rel = item.get("path", "")
            path = bundle / rel
            if (not rel or not path.resolve().is_relative_to(bundle.resolve())
                    or not _matches(path, item.get("sha256"))):
                diagnostics.append(f"changed_path_page_hash_mismatch:{family.name}:{item.get('page', 'unknown')}")
        actual_pages = sorted(family.glob("changed-paths-page-*.json"))
        referenced = {str(item.get("path", "")) for item in facts.get("changed_path_pages", [])}
        expected_pages = {path.relative_to(bundle).as_posix() for path in actual_pages}
        if referenced != expected_pages:
            diagnostics.append(f"changed_path_page_hash_reference_set_mismatch:{family.name}")
        if facts.get("artifact_metadata_sha256"):
            refs.append(("artifact_metadata", facts["artifact_metadata_sha256"], family / "artifacts-metadata.json"))
        if facts.get("check_runs_sha256"):
            refs.append(("check_runs", facts["check_runs_sha256"], family / "check-runs.json"))
        if facts.get("artifact_evidence"):
            ref = facts["artifact_evidence"]
            refs.append(("artifact_evidence", ref.get("sha256"), bundle / ref.get("path", "")))
        for attempt, ref in (facts.get("attempt_jobs") or {}).items():
            rel = ref.get("path") or f"raw/families/{family.name}/jobs-attempt-{attempt}.json"
            path = bundle / rel
            expected_rel = f"raw/families/{family.name}/jobs-attempt-{attempt}.json"
            request = f"/repos/{repository}/actions/runs/{family_run.get('id')}/attempts/{attempt}/jobs?per_page=100"
            request_ok = request in requests
            if not request_ok:
                pages = sorted(row for row in requests if row.startswith(request + "&page="))
                try:
                    response = json.loads(path.read_text())
                    total = response.get("total_count")
                    jobs = response.get("jobs")
                    page_numbers = [int(row.rsplit("=", 1)[1]) for row in pages]
                    request_ok = (isinstance(total, int) and isinstance(jobs, list) and len(jobs) == total
                                  and page_numbers == list(range(1, len(page_numbers) + 1))
                                  and bool(page_numbers) and (total <= 100 or len(page_numbers) == (total + 99) // 100))
                except (OSError, ValueError, TypeError):
                    request_ok = False
            if (rel != expected_rel or not path.resolve().is_relative_to(bundle.resolve())
                    or not _matches(path, ref.get("sha256")) or not request_ok):
                diagnostics.append(f"family_attempt_hash_mismatch:{family.name}:{attempt}")
        for item in facts.get("changed_path_pages", []):
            try:
                pr_number = family_run["pull_requests"][0]["number"]
                expected_request = f"/repos/{repository}/pulls/{pr_number}/files?per_page=100&page={item.get('page')}"
            except (KeyError, IndexError, TypeError):
                expected_request = ""
            if expected_request not in requests:
                diagnostics.append(f"changed_path_page_api_request_missing:{family.name}:{item.get('page', 'unknown')}")
        for label, digest, path in refs:
            if not _matches(path, digest):
                diagnostics.append(f"family_source_hash_mismatch:{family.name}:{label}")

        for native in facts.get("derived_native_coverage") or []:
            directory = (bundle / native.get("directory", "")).resolve()
            member = (bundle / native.get("report_member_path", "")).resolve()
            try:
                artifact_root = (family / "artifacts" / str(native.get("artifact_id"))).resolve()
                if (not directory.is_relative_to((family / "artifacts/derived-native").resolve())
                        or not member.is_relative_to(artifact_root)
                        or set(native.get("file_sha256") or {}) != {"report.json", "selection.json", "coverage-source.json"}
                        or any(not _matches(directory / name, expected) for name, expected in native["file_sha256"].items())
                        or (directory / "report.json").read_bytes() != member.read_bytes()):
                    raise ValueError("derived_native_origin_or_digest_mismatch")
            except (OSError, ValueError, TypeError):
                diagnostics.append(f"derived_native_origin_or_digest_mismatch:{family.name}:{native.get('owner')}")

        metadata_path = family / "artifacts-metadata.json"
        evidence_path = family / "artifact-evidence.json"
        if metadata_path.is_file() and not facts.get("artifact_metadata_sha256"):
            diagnostics.append(f"artifact_metadata_hash_missing:{family.name}")
        if not metadata_path.is_file() and not evidence_path.is_file():
            continue
        try:
            metadata = json.loads(metadata_path.read_text()) if metadata_path.is_file() else {"artifacts": []}
            evidence = json.loads(evidence_path.read_text()) if evidence_path.is_file() else []
        except (OSError, ValueError):
            diagnostics.append(f"artifact_metadata_invalid:{family.name}")
            continue
        by_id = {str(item.get("id")): item for item in metadata.get("artifacts", [])}
        records = evidence if isinstance(evidence, list) else []
        for record in records:
            artifact = record.get("artifact") or {}
            result = record.get("result") or {}
            if result.get("status") not in ("accepted", "verified"):
                continue
            artifact_id = str(artifact.get("id", ""))
            source = by_id.get(artifact_id, artifact)
            zip_path = family / "artifacts" / f"{artifact_id}.zip"
            expected = (result.get("archive_sha256") or "").removeprefix("sha256:")
            if not artifact_id.isdigit() or not _matches(zip_path, expected):
                diagnostics.append(f"artifact_zip_hash_mismatch:{family.name}:{artifact_id}")
                continue
            try:
                member_records = [item for item in result.get("members", []) if isinstance(item, dict) and item.get("member")]
                if any(not item.get("sha256") for item in member_records):
                    diagnostics.append(f"artifact_member_hash_missing:{family.name}:{artifact_id}")
                    continue
                verified_zip_members(zip_path, expected, {item["member"]: item["sha256"] for item in member_records})
                with zipfile.ZipFile(zip_path) as archive:
                    zip_members = {info.filename for info in archive.infolist() if not info.is_dir()}
                recorded_json_members = {item.get("member") for item in member_records}
                with zipfile.ZipFile(zip_path) as archive:
                    all_extracted_json = {n for n in zip_members if pathlib.PurePosixPath(n).suffix.lower() == ".json" and (pathlib.PurePosixPath(n).name.lower() in {
                        "report.json", "playwright-report.json", "test-results.json", "timing.json", "ci-timing.json", "metrics.json", "manifest.json", "ci-measurement-metadata.json", "ci-exunit-timing-main.json", "ci-exunit-timing-threadline-guard.json", "admin-behavior.json", "admin-checkpoints.json", "design-gallery-pr-behavior.json", "design-gallery-nonpr-snapshots.json", "design-gallery-nonpr-behavior.json", "non-admin-smoke.json", "demo-showcase.json", "coverage-source.json", "execution-record.json"} or pathlib.PurePosixPath(n).name.lower().endswith(".selection.json"))}
                if all_extracted_json != recorded_json_members:
                    diagnostics.append(f"artifact_json_member_coverage_mismatch:{family.name}:{artifact_id}")
                for item in member_records:
                    member = item.get("member")
                    extracted = family / "artifacts" / artifact_id / pathlib.PurePosixPath(member)
                    if not extracted.exists():
                        # Phase252 extraction flattened nested archive paths. Keep
                        # that frozen replay layout readable while new comparison
                        # artifacts preserve native report-relative directories.
                        extracted = family / "artifacts" / artifact_id / pathlib.PurePosixPath(member).name
                    if member not in zip_members or not extracted.resolve().is_relative_to(bundle.resolve()):
                        diagnostics.append(f"artifact_extracted_member_invalid:{family.name}:{artifact_id}")
                        continue
                    with zipfile.ZipFile(zip_path) as archive:
                        payload = archive.read(member)
                    if not extracted.is_file() or extracted.read_bytes() != payload:
                        diagnostics.append(f"artifact_extracted_member_mismatch:{family.name}:{artifact_id}:{member}")
                # Every JSON member the collector may consume must have a recorded digest,
                # and later readers must use the bytes returned from this verified ZIP.
                if recorded_json_members != all_extracted_json:
                    diagnostics.append(f"artifact_json_members_not_fully_hash_bound:{family.name}:{artifact_id}")
            except (OSError, ValueError, KeyError, zipfile.BadZipFile):
                diagnostics.append(f"artifact_member_verification_failed:{family.name}:{artifact_id}")
    return sorted(set(diagnostics))


def assemble_comparison_snapshots(contract: dict, inputs: list[pathlib.Path], destination: pathlib.Path) -> dict:
    """Combine already retained attempts offline; never reacquire or replace a sample."""
    import copy
    import shutil
    destination = pathlib.Path(destination)
    if not inputs or destination.exists():
        raise ValueError("comparison_assembly_inputs_or_destination_invalid")
    manifests = []
    sample_ids, reservations = set(), set()
    frozen_keys = ("repository", "workflow", "source_sha", "workflow_sha256", "workflow_blob_sha",
                   "source_file_sha256", "required_contexts", "required_rule_provenance", "active_rulesets", "measured_pr_identity")
    for item in inputs:
        root = pathlib.Path(item).resolve()
        if any(path.is_symlink() for path in root.rglob('*')) or verify_snapshot_hashes(root):
            raise ValueError("comparison_assembly_input_hash_invalid")
        manifest = json.loads((root/'manifest.json').read_text())
        collection = manifest.get('comparison_collection') or {}
        if (manifest.get('status') != 'complete' or not manifest.get('comparison_families')
                or collection.get('contract_sha256') != comparison_contract_sha256(contract)
                or collection.get('role') not in ('before', 'after')):
            raise ValueError("comparison_assembly_input_identity_invalid")
        if manifests:
            first = manifests[0][1]
            if (any(manifest.get(key) != first.get(key) for key in frozen_keys)
                    or collection['role'] != first['comparison_collection']['role']):
                raise ValueError("comparison_assembly_source_or_rules_changed")
            for name in ('effective-rules.json','branch-protection.json','rulesets.json'):
                if (root/'raw'/name).read_bytes() != (manifests[0][0]/'raw'/name).read_bytes():
                    raise ValueError("comparison_assembly_raw_rules_changed")
        expected = set()
        for family in manifest['comparison_families']:
            sample = f"{family['run_id']}-attempt-{family['run_attempt']}" if contract.get('sample_identity')=='run_id+run_attempt' else str(family['run_id'])
            reservation = family.get('reservation_id')
            if sample in sample_ids or not reservation or reservation in reservations or family.get('family_role') != collection['role']:
                raise ValueError("comparison_assembly_duplicate_or_wrong_role")
            sample_ids.add(sample); reservations.add(reservation); expected.add(sample)
        if {path.name for path in (root/'raw/families').iterdir()} != expected:
            raise ValueError("comparison_assembly_family_set_invalid")
        manifests.append((root, manifest))
    first_root, first = manifests[0]
    shutil.copytree(first_root, destination)
    shutil.rmtree(destination/'raw/families')
    (destination/'raw/families').mkdir()
    output = copy.deepcopy(first)
    output['comparison_families'] = []
    requests, acquisitions, registrations, origins = [], [], [], []
    populations = {}
    for index, (root, manifest) in enumerate(manifests):
        retained = destination/'raw/acquisition-passes'/f'{index:02d}'
        retained.mkdir(parents=True)
        for name in ('manifest.json','request-ledger.json','selection-ledger.json'):
            shutil.copy2(root/name, retained/name)
        shutil.copytree(root/'raw/populations',retained/'populations')
        acquisitions.append({'manifest_path':str((retained/'manifest.json').relative_to(destination)),
                             'manifest_sha256':_digest(retained/'manifest.json'), 'input_directory':str(root)})
        for path in (root/'raw/families').iterdir():
            shutil.copytree(path,destination/'raw/families'/path.name)
        output['comparison_families'].extend(manifest['comparison_families'])
        requests.extend(json.loads((root/'request-ledger.json').read_text()).get('requests') or [])
        collection = manifest['comparison_collection']
        registrations.extend(collection.get('registered_runs') or [])
        origins.extend(collection.get('origin_verification') or [])
        for name in ('pull_request','push_main','schedule','manual','release_push'):
            doc = json.loads((root/'raw/populations'/f'{name}.json').read_text())
            if name not in populations:
                populations[name] = {**doc,'runs':[],'pages':[],'selected_run_ids':[],'api_total_count':0}
            combined = populations[name]
            combined['runs'].extend(doc.get('runs') or [])
            combined['pages'].extend(doc.get('pages') or [])
            combined['selected_run_ids'].extend(doc.get('selected_run_ids') or [r['id'] for r in doc.get('runs') or []])
            combined['api_total_count'] += doc.get('api_total_count') or 0
    def save(path, value):
        path.write_text(json.dumps(value,sort_keys=True,separators=(',',':'))+'\n')
    save(destination/'request-ledger.json',{'status':'complete','request_count':len(requests),'requests':requests,
                                          'acquisition_passes':acquisitions,'network_requests_during_assembly':0})
    save(destination/'selection-ledger.json',{'schema_version':'sigra.ci-run-metrics/selection-ledger-v1',
        'cutoff_utc':first['cutoff_utc'],'populations':list(populations.values()),'acquisition_passes':acquisitions})
    for name, doc in populations.items():
        save(destination/'raw/populations'/f'{name}.json',doc)
        output['source_sha256'][name] = _digest(destination/'raw/populations'/f'{name}.json')
        output['populations'][name] = doc if name in ('pull_request','push_main','schedule') else {'population':name,'event':doc.get('event'),'records':doc['runs'],'api_total_count':doc['api_total_count']}
    output['source_sha256']['request_ledger'] = _digest(destination/'request-ledger.json')
    output['source_sha256']['selection_ledger'] = _digest(destination/'selection-ledger.json')
    output['request_count'] = len(requests)
    output['captured_at_utc'] = max(m['captured_at_utc'] for _,m in manifests)
    output['comparison_collection'].update(registered_runs=registrations,origin_verification=origins,
        origin_status='passed' if all(m['comparison_collection'].get('origin_status')=='passed' for _,m in manifests) else 'insufficient_data',
        acquisition_passes=acquisitions,network_requests_during_assembly=0)
    save(destination/'manifest.json',output)
    issues = verify_snapshot_hashes(destination)
    if issues:
        raise ValueError('comparison_assembly_output_invalid:'+','.join(issues))
    return {'status':'assembled','samples':len(sample_ids),'acquisition_passes':len(manifests),'network_requests':0}


def verify_durable_attempt_capture(receipt: dict, root: pathlib.Path, run_id: int, attempt: int, source: str) -> None:
    """A rerun may not hide an earlier attempt until its complete bytes are recoverable."""
    import subprocess
    root = pathlib.Path(root).resolve()
    relative = receipt.get('capture_path','')
    capture = (root/relative).resolve()
    ref, commit = receipt.get('ref',''), receipt.get('commit','')
    if (not relative or not capture.is_relative_to(root) or not capture.is_dir()
            or not ref.startswith('refs/evidence/') or not re.fullmatch('[0-9a-f]{40}',commit)
            or any(path.is_symlink() for path in capture.rglob('*'))):
        raise ValueError('previous_attempt_capture_receipt_invalid')
    def git(*args):
        return subprocess.check_output(['git','-C',str(root),*args],stderr=subprocess.DEVNULL)
    if git('rev-parse','--verify',ref).decode().strip() != commit:
        raise ValueError('previous_attempt_capture_ref_changed')
    files = {path.relative_to(root).as_posix():path for path in capture.rglob('*') if path.is_file()}
    recorded = receipt.get('files') or {}
    prefix = pathlib.Path(relative).as_posix().rstrip('/')+'/'
    if set(files) != {name for name in recorded if name.startswith(prefix)}:
        raise ValueError('previous_attempt_capture_file_set_incomplete')
    for name,path in files.items():
        if not _matches(path,recorded.get(name)) or hashlib.sha256(git('show',ref+':'+name)).hexdigest()!=recorded[name]:
            raise ValueError('previous_attempt_capture_readback_failed')
    if verify_snapshot_hashes(capture):
        raise ValueError('previous_attempt_capture_hashes_invalid')
    run = json.loads((capture/f'raw/families/{run_id}-attempt-{attempt}/run.json').read_text())
    manifest = json.loads((capture/'manifest.json').read_text())
    origin_file = capture/'preparation-origin-verification.json'
    origins_valid = (manifest.get('comparison_collection') or {}).get('origin_status')=='passed'
    if origin_file.is_file():
        origins_valid = json.loads(origin_file.read_text()).get('status')=='origin_verified'
    if (manifest.get('status')!='complete' or not origins_valid or run.get('id')!=run_id or run.get('run_attempt')!=attempt
            or run.get('head_sha')!=source or run.get('status')!='completed' or run.get('conclusion')!='success'):
        raise ValueError('previous_attempt_capture_not_successful_and_verified')


def validate_next_comparison_trigger(contract: dict, reservation_id: str, registrations: dict | None,
                                     prior_run: dict, receipt: dict, root: pathlib.Path, *, now=None) -> dict:
    """Check the exact next reserved attempt, previous result, window and durable capture."""
    import datetime
    if contract.get('sample_identity')!='run_id+run_attempt' or validate_comparison_plan(contract):
        raise ValueError('comparison_trigger_plan_invalid')
    if registrations is not None and validate_comparison_registration_ledger(contract,registrations):
        raise ValueError('comparison_trigger_registration_invalid')
    rows = (registrations or {}).get('records') or []
    reservations = contract.get('family_reservations') or []
    if len(rows)>=len(reservations) or reservations[len(rows)].get('reservation_id')!=reservation_id:
        raise ValueError('comparison_trigger_not_next_reserved_slot')
    reservation = reservations[len(rows)]
    current = now or datetime.datetime.now(datetime.timezone.utc)
    if not _utc(contract['window']['start_utc']) <= current <= _utc(contract['window']['end_utc']):
        raise ValueError('comparison_trigger_outside_frozen_window')
    source = contract['baseline_application_sha'] if reservation['family_role']=='before' else contract['candidate_identity']['application_sha']
    if (prior_run.get('id')!=reservation['run_id'] or prior_run.get('run_attempt')!=reservation['run_attempt']-1
            or prior_run.get('head_sha')!=source or prior_run.get('status')!='completed' or prior_run.get('conclusion')!='success'):
        raise ValueError('comparison_trigger_previous_attempt_changed_or_failed')
    verify_durable_attempt_capture(receipt,root,reservation['run_id'],reservation['run_attempt']-1,source)
    return reservation


def validate_check_bindings(run: dict, attempt: int, jobs: list[dict], checks: list[dict], required: list[str]) -> list[str]:
    errors, by_attempt, _ = bind_required_checks_by_attempt(run, {str(attempt): jobs}, checks, required)
    if errors:
        return errors
    current = by_attempt.get(str(attempt), {})
    diagnostics = []
    for name in required:
        check = current.get(name)
        if not check or check.get("status") != "completed" or check.get("conclusion") != "success":
            diagnostics.append(f"required_check_result_invalid:{name}")
    return sorted(set(diagnostics))


def validate_producer_binding(run: dict, job: dict, artifact: dict, metadata: dict, expected_job: str) -> list[str]:
    diagnostics = []
    run_id, attempt = str(run.get("id")), str(job.get("run_attempt"))
    seam = metadata.get("matrix_seam")
    if expected_job == "Library tests shard":
        expected_job_names = {"Library tests shard"}
        timing_name = f"library-test-timing-{run_id}-{attempt}"
        metadata_name = f"library-measurement-metadata-{run_id}-{attempt}"
        artifact_steps = {
            timing_name: "Upload library test timing",
            metadata_name: "Upload library measurement metadata",
        }
        expected_artifacts = {timing_name, metadata_name}
    elif expected_job.startswith("Example Playwright shard (") and isinstance(seam, str):
        expected_job_names = {f"Example Playwright shard ({seam})"}
        timing_name = f"example-playwright-{seam}-{run_id}"
        metadata_name = f"playwright-measurement-metadata-{seam}-{run_id}-{attempt}"
        artifact_steps = {timing_name: "Upload shard diagnostics", metadata_name: "Upload Playwright measurement metadata"}
        expected_artifacts = {timing_name, metadata_name}
    else:
        return ["producer_job_contract_unknown"]
    artifact_name = artifact.get("name")
    artifact_run = artifact.get("workflow_run") or {}
    upload_step_name = artifact_steps.get(artifact_name)
    steps = [s for s in job.get("steps", []) if s.get("name") == upload_step_name and s.get("conclusion") == "success"] if upload_step_name else []
    try:
        artifact_time = _utc(artifact.get("created_at"))
        in_step = any(_utc(s["started_at"]) <= artifact_time <= _utc(s["completed_at"]) for s in steps)
    except (KeyError, TypeError, ValueError):
        in_step = False
    valid = (
        str(job.get("run_id")) == run_id and str(job.get("run_attempt")) == attempt
        and job.get("name") in expected_job_names and job.get("conclusion") == "success"
        and str(artifact.get("workflow_run", {}).get("id")) == run_id
        and artifact.get("workflow_run", {}).get("head_sha") == run.get("head_sha")
        and artifact_run.get("repository_id") == 1207487684
        and artifact_run.get("head_repository_id") == 1207487684
        and artifact_name in expected_artifacts
        and (metadata.get("timing_artifact_name") in (None, "", timing_name))
        and str(metadata.get("run_id")) == run_id and str(metadata.get("run_attempt")) == attempt
        and metadata.get("job_name") == ("Library tests shard" if expected_job == "Library tests shard" else "Example Playwright shard") and metadata.get("event") == run.get("event")
        and metadata.get("repository") == "szTheory/sigra" and in_step
    )
    if not valid:
        diagnostics.append("producer_metadata_not_bound_to_successful_job_upload")
    return diagnostics


def legacy_playwright_artifact_matches_attempt(artifact: dict, run: dict, jobs: list[dict], attempt: int) -> bool:
    """Bind frozen, run-only diagnostic names to the selected attempt's upload window."""
    name = artifact.get("name")
    owners = ("admin_behavior", "admin_checkpoints", "design_gallery", "non_admin_smoke", "demo_showcase")
    owner = next((owner for owner in owners if name == f"example-playwright-{owner}-{run.get('id')}"), None)
    if owner is None or str((artifact.get("workflow_run") or {}).get("id")) != str(run.get("id")):
        return False
    if (artifact.get("workflow_run") or {}).get("head_sha") != run.get("head_sha"):
        return False
    try:
        created = _utc(artifact.get("created_at"))
        return any(job.get("name") == f"Example Playwright shard ({owner})"
                   and job.get("run_id") == run.get("id") and job.get("run_attempt") == attempt
                   and job.get("head_sha") == run.get("head_sha") and job.get("conclusion") == "success"
                   and any(step.get("name") == "Upload shard diagnostics" and step.get("conclusion") == "success"
                           and _utc(step.get("started_at")) <= created <= _utc(step.get("completed_at"))
                           for step in job.get("steps", [])) for job in jobs)
    except (TypeError, ValueError):
        return False


def comparison_native_inventories(contract: dict, role: str, root: pathlib.Path) -> dict:
    """Read frozen selections only when their complete Playwright tree still matches."""
    import subprocess
    root = pathlib.Path(root).resolve()
    source = contract.get("baseline_application_sha") if role == "before" else (contract.get("candidate_identity") or {}).get("application_sha")
    rows = ((contract.get("native_coverage_comparison") or {}).get("inventories") or {}).get(role)
    owners = {"admin_behavior", "admin_checkpoints", "design_gallery", "non_admin_smoke", "demo_showcase"}
    if not isinstance(rows, dict) or set(rows) != owners:
        raise ValueError("comparison_native_inventories_missing")

    def git(*args):
        return subprocess.check_output(["git", "-C", str(root), *args], stderr=subprocess.DEVNULL)

    def retained(row, name):
        path = (root / row.get(name + "_path", "")).resolve()
        if not path.is_relative_to(root) or not _matches(path, row.get(name + "_sha256")):
            raise ValueError("comparison_inventory_digest_invalid:" + name)
        return path.read_bytes()

    def approved_workflow_equivalence(inventory_source, descriptor, actual_hash):
        proof = ((contract.get('native_coverage_comparison') or {}).get('source_equivalence') or {}).get(role) or {}
        if proof.get('inventory_source_sha') != inventory_source or proof.get('amended_source_sha') != source:
            raise ValueError('comparison_inventory_workflow_amendment_not_approved')
        authority = json.loads(retained(proof, 'authorization'))
        snapshots = json.loads(retained(proof, 'snapshots'))
        proposal_path = (root/authority.get('proposal_path','')).resolve()
        if (authority.get('status') != 'approved' or not proposal_path.is_relative_to(root)
                or not _matches(proposal_path, authority.get('proposal_sha256'))):
            raise ValueError('comparison_inventory_amendment_authority_invalid')
        proposal = json.loads(proposal_path.read_text())
        snapshot = (snapshots.get('sources') or {}).get(role) or {}
        if (snapshot.get('application_sha') != source or snapshot.get('workflow_sha256') != actual_hash
                or snapshot.get('tree_sha') != git('rev-parse',source+'^{tree}').decode().strip()
                or hashlib.sha256(git('show',inventory_source+':.github/workflows/ci.yml')).hexdigest() != descriptor.get('workflow_sha256')):
            raise ValueError('comparison_inventory_amended_source_mismatch')
        if authority.get('method') == 'symmetric_environment_transport_recovery':
            amendment = (proposal.get('patches') or {}).get(role) or {}
            patch = (root/amendment.get('path', '')).resolve()
            base = amendment.get('base_sha')
            if (proposal.get('inventory_sources', {}).get(role) != inventory_source
                    or snapshot.get('reviewed_source') != base
                    or not re.fullmatch('[0-9a-f]{40}', str(base or ''))
                    or not patch.is_relative_to(root) or not _matches(patch, amendment.get('sha256'))
                    or hashlib.sha256(git('diff', '--binary', '--full-index', base, source)).hexdigest() != amendment.get('sha256')
                    or git('diff', '--name-only', base, source).decode().splitlines() != amendment.get('allowed_paths')):
                raise ValueError('comparison_inventory_environment_patch_mismatch')
            return proof['authorization_sha256']
        if role == 'before':
            patch = (root/proposal.get('patch_path','')).resolve()
            if (snapshot.get('reviewed_source') != inventory_source or not patch.is_relative_to(root)
                    or not _matches(patch, authority.get('approved_patch_sha256'))
                    or proposal.get('proposed_workflow_sha256') != actual_hash
                    or proposal.get('original_workflow_sha256') != descriptor.get('workflow_sha256')):
                raise ValueError('comparison_inventory_baseline_patch_mismatch')
            changed = git('diff','--name-only',inventory_source,source).decode().splitlines()
            fixture = 'test/sigra/planning/phase_232_playwright_economics_test.exs'
            if changed != ['.github/workflows/ci.yml',fixture]:
                raise ValueError('comparison_inventory_unapproved_baseline_changes')
            old = git('show',inventory_source+':'+fixture)
            expected = old.replace(b'assert shard =~ "image: public.ecr.aws/docker/library/postgres:15"',b'assert shard =~ "image: postgres:15"')
            if git('show',source+':'+fixture) != expected:
                raise ValueError('comparison_inventory_baseline_fixture_changed')
        else:
            reviewed = proposal.get('proposed_candidate_local_source_commit')
            if (snapshot.get('reviewed_source') != reviewed
                    or git('rev-parse',source+'^{tree}') != git('rev-parse',reviewed+'^{tree}')):
                raise ValueError('comparison_inventory_candidate_not_reviewed')
        return proof['authorization_sha256']

    result = {}
    for owner, row in rows.items():
        approval = None
        descriptor = json.loads(retained(row, "descriptor"))
        selection = retained(row, "selection")
        inventory_source = row.get("inventory_source_sha")
        if not re.fullmatch(r"[0-9a-f]{40}", str(source or "")) or not re.fullmatch(r"[0-9a-f]{40}", str(inventory_source or "")):
            raise ValueError("comparison_inventory_source_invalid")
        try:
            if git("rev-parse", source + ":test/example/priv/playwright") != git("rev-parse", inventory_source + ":test/example/priv/playwright"):
                raise ValueError("comparison_inventory_playwright_tree_changed:" + owner)
            for field, path in (("workflow_sha256", ".github/workflows/ci.yml"),
                                ("configuration_sha256", "test/example/priv/playwright/playwright.config.ts"),
                                ("lock_sha256", "test/example/priv/playwright/package-lock.json")):
                actual_hash = hashlib.sha256(git("show", source + ":" + path)).hexdigest()
                if actual_hash != descriptor.get(field):
                    if field == 'workflow_sha256':
                        approval = approved_workflow_equivalence(inventory_source, descriptor, actual_hash)
                    else:
                        raise ValueError("comparison_inventory_source_input_changed:" + field)
        except subprocess.CalledProcessError as error:
            raise ValueError("comparison_inventory_source_unavailable") from error
        if (descriptor.get("schema_version") != "sigra.browser-coverage-source/v1"
                or descriptor.get("owner") != owner or descriptor.get("seam") != owner
                or descriptor.get("source_sha") != inventory_source or len(descriptor.get("reports") or []) != 1
                or descriptor["reports"][0].get("selection_sha256") != hashlib.sha256(selection).hexdigest()):
            raise ValueError("comparison_inventory_descriptor_invalid:" + owner)
        result[owner] = {"descriptor": descriptor, "selection": selection, "inventory_source_sha": inventory_source,
                         "workflow_authorization_sha256": approval}
    return result


def comparison_runner_images(metadata: list[dict], *, require_proof: bool = False) -> dict:
    """Match images by the work they execute; equal image sets can hide owner drift."""
    result = {}
    for row in metadata:
        owner = row.get('matrix_seam')
        key = f"{row.get('job_name')} ({owner})" if owner else row.get('job_name')
        image = row.get('runner_image') or {}
        proof = image.get('source_proof')
        if require_proof or proof is not None:
            try:
                if proof.get('status') != 'verified' or proof.get('schema_version') not in ('sigra.ci-runner-image/v1', 'sigra.ci-runner-image/v2'):
                    raise ValueError('unverified')
                raw = {}
                for field in ('image_file', 'os_release_file'):
                    retained = proof[field]
                    data = base64.b64decode(retained['base64'], validate=True)
                    if hashlib.sha256(data).hexdigest() != retained['sha256']:
                        raise ValueError('hash')
                    raw[field] = data.decode()
                images = [item for item in json.loads(raw['image_file']) if item.get('group') == 'Runner Image']
                if len(images) != 1:
                    raise ValueError('image_row')
                lines = images[0]['detail'].splitlines()
                names = [line[7:] for line in lines if line.startswith('Image: ')]
                versions = [line[9:] for line in lines if line.startswith('Version: ')]
                normalize = lambda value: 'ubuntu24' if value in ('ubuntu24', 'ubuntu-24.04') else None
                actual = {'image_os': normalize(names[0]), 'image_version': versions[0]}
                if (len(names) != 1 or len(versions) != 1 or actual['image_os'] is None
                        or not re.fullmatch(r'[0-9]{8}\.[0-9]+\.[0-9]+', actual['image_version'])
                        or any(proof.get(field) != actual for field in ('file_image', 'runner_image'))
                        or image.get('image_os') != actual['image_os'] or image.get('image_version') != actual['image_version']):
                    raise ValueError('image_conflict')
                if proof['schema_version'] == 'sigra.ci-runner-image/v1':
                    if proof.get('environment_image') != actual:
                        raise ValueError('v1_environment_conflict')
                elif (proof.get('identity_authority') != 'runner_native_image_file'
                      or proof.get('environment_agrees') is not (proof.get('environment_image') == actual)):
                    raise ValueError('native_image_authority_or_diagnostic_invalid')
                os_fields = dict(line.split('=', 1) for line in raw['os_release_file'].splitlines() if re.match(r'^(ID|VERSION_ID)=', line))
                if os_fields.get('ID', '').strip('"') != 'ubuntu' or os_fields.get('VERSION_ID', '').strip('"') != '24.04':
                    raise ValueError('os')
                identity = proof['identity']
                for field in ('repository', 'run_id', 'run_attempt', 'source_sha', 'matrix_seam'):
                    if str(identity.get(field)) != str(row.get(field)):
                        raise ValueError('identity')
                verification = image['verification']
                if (verification.get('status') != 'verified' or verification.get('runner_image') != actual
                        or verification.get('identity') != identity
                        or verification.get('image_file_sha256') != proof['image_file']['sha256']
                        or verification.get('os_release_sha256') != proof['os_release_file']['sha256']
                        or verification.get('machine') != proof.get('machine')
                        or (proof['schema_version'] == 'sigra.ci-runner-image/v2' and (
                            verification.get('identity_authority') != 'runner_native_image_file'
                            or verification.get('early_environment_image') != proof.get('environment_image')
                            or verification.get('environment_agrees') is not (verification.get('environment_image') == actual)
                            or verification.get('environment_changed') is not (verification.get('environment_image') != proof.get('environment_image'))))
                        or proof.get('machine') != {'X64': 'x86_64', 'ARM64': 'aarch64'}.get(row.get('runner_arch'))):
                    raise ValueError('verification')
            except (ValueError, TypeError, KeyError, IndexError, AttributeError) as error:
                raise ValueError('comparison_runner_image_proof_invalid') from error
        if (not key or key in result or not row.get('runner_os') or not row.get('runner_arch')
                or not image.get('image_os') or not image.get('image_version')):
            raise ValueError('comparison_runner_image_missing_or_duplicate_owner')
        result[key] = {'runner_os':row['runner_os'],'runner_arch':row['runner_arch'],
                       'image_os':image['image_os'],'image_version':image['image_version']}
        if proof and proof.get('schema_version') == 'sigra.ci-runner-image/v2':
            result[key]['image_file_sha256'] = proof['image_file']['sha256']
            result[key]['os_release_sha256'] = proof['os_release_file']['sha256']
    return result


def validate_repaired_control_metadata(metadata: list[dict], *, expected_ref: str | None = None,
                                       eligible_scopes: set[str] | None = None,
                                       expected_keys: dict | None = None) -> list[str]:
    """Require exact warm-cache and native runner identity for each of six owners."""
    diagnostics = []
    owners = {"library", "admin_behavior", "admin_checkpoints", "design_gallery", "non_admin_smoke", "demo_showcase"}
    by_owner = {}
    for row in metadata if isinstance(metadata, list) else []:
        owner = row.get("matrix_seam") or ("library" if row.get("job_name") == "Library tests shard" else None)
        if owner in by_owner:
            diagnostics.append("repaired_metadata_owner_duplicate:" + owner)
        by_owner[owner] = row
    if set(by_owner) != owners:
        diagnostics.append("repaired_metadata_owner_set_incomplete")
    for owner in sorted(owners & set(by_owner)):
        row = by_owner[owner]
        cache = row.get("cache_outcome")
        if not isinstance(cache, dict) or not cache:
            diagnostics.append("repaired_cache_outcome_missing:" + owner)
            continue
        for component, result in cache.items():
            if not isinstance(result, dict) or result.get("cache_hit") is not True or result.get("exact_key") is not True:
                diagnostics.append("repaired_cache_not_exact_hit:" + owner + ":" + str(component))
                continue
            if (not all(isinstance(result.get(field), str) and result.get(field)
                        for field in ("matched_cache_key", "scope", "ref"))
                    or not isinstance(result.get("conditions"), list) or not result.get("conditions")):
                diagnostics.append("repaired_cache_identity_incomplete:" + owner + ":" + str(component))
            else:
                if expected_ref is not None and result.get("ref") != expected_ref:
                    diagnostics.append("repaired_cache_consumer_ref_mismatch:" + owner + ":" + str(component))
                if eligible_scopes is not None and result.get("scope") not in eligible_scopes:
                    diagnostics.append("repaired_cache_scope_ineligible:" + owner + ":" + str(component))
                elif eligible_scopes is None and expected_ref is not None and result.get("scope") != expected_ref:
                    diagnostics.append("repaired_cache_ref_scope_mismatch:" + owner + ":" + str(component))
                expected = (expected_keys or {}).get(owner, {}).get(component)
                if expected is not None and result.get("matched_cache_key") != expected:
                    diagnostics.append("repaired_cache_key_mismatch:" + owner + ":" + str(component))
                if result.get("fallback_used") is True or result.get("restore_kind") == "fallback":
                    diagnostics.append("repaired_cache_fallback_used:" + owner + ":" + str(component))
        image = row.get("runner_image") or {}
        if not all(isinstance(value, str) and value for value in (row.get("runner_os"), row.get("runner_arch"), image.get("image_os"), image.get("image_version"))):
            diagnostics.append("repaired_native_runner_identity_missing:" + owner)
    return sorted(set(diagnostics))


def validate_repaired_pr_origin(run: dict, pull_request: dict, merge_commit: dict,
                                registration: dict | None = None) -> list[str]:
    """Bind GitHub's minimal workflow PR identity to retained full PR and merge-commit API objects."""
    diagnostics = []
    workflow_prs = run.get("pull_requests") or []
    if len(workflow_prs) != 1:
        return ["repaired_pull_request_minimal_identity_invalid"]
    minimal = workflow_prs[0]
    number = pull_request.get("number")
    head = pull_request.get("head") or {}
    base = pull_request.get("base") or {}
    minimal_head = minimal.get("head") or {}
    minimal_base = minimal.get("base") or {}
    head_repo_id = (head.get("repo") or {}).get("id")
    base_repo_id = (base.get("repo") or {}).get("id")
    run_repo_id = (run.get("repository") or {}).get("id")
    if (type(number) is not int or minimal.get("number") != number
            or minimal_head.get("sha") != head.get("sha")
            or minimal_base.get("sha") != base.get("sha")
            or not isinstance(head.get("ref"), str) or not head.get("ref")
            or not isinstance(base.get("ref"), str) or not base.get("ref")
            or minimal_head.get("ref") != head.get("ref")
            or minimal_base.get("ref") != base.get("ref")
            or type(head_repo_id) is not int or head_repo_id <= 0
            or minimal_head.get("repo", {}).get("id") != head_repo_id
            or base_repo_id != 1207487684 or run_repo_id != base_repo_id
            or minimal_base.get("repo", {}).get("id") != base_repo_id):
        diagnostics.append("repaired_pull_request_api_origin_mismatch")
    merge_sha = pull_request.get("merge_commit_sha")
    merge_tree = (merge_commit.get("commit") or {}).get("tree") or merge_commit.get("tree") or {}
    parents = merge_commit.get("parents") or (merge_commit.get("commit") or {}).get("parents") or []
    expected_parents = {head.get("sha"), base.get("sha")}
    actual_parents = {parent.get("sha") for parent in parents if isinstance(parent, dict)}
    if (not isinstance(merge_sha, str) or not re.fullmatch(r"[0-9a-f]{40}", merge_sha)
            or merge_commit.get("sha") != merge_sha
            or not isinstance(merge_tree.get("sha"), str) or not re.fullmatch(r"[0-9a-f]{40}", merge_tree.get("sha", ""))
            or len(parents) != 2 or actual_parents != expected_parents):
        diagnostics.append("repaired_merge_commit_origin_invalid")
    if registration is not None:
        if (number != registration.get("pull_request_number")
                or head.get("sha") != registration.get("pull_request_head_sha")
                or base.get("sha") != registration.get("pull_request_base_sha")
                or merge_sha != registration.get("pull_request_merge_sha")
                or merge_tree.get("sha") != registration.get("pull_request_merge_tree_sha")):
            diagnostics.append("repaired_registered_pull_request_or_merge_changed")
    return sorted(set(diagnostics))


def repaired_cache_stratum(metadata: list[dict]) -> tuple[str, dict]:
    """Classify six-owner cache metadata without treating structured hit rows as misses."""
    owners = {"library", "admin_behavior", "admin_checkpoints", "design_gallery", "non_admin_smoke", "demo_showcase"}
    by_owner = {}
    for row in metadata if isinstance(metadata, list) else []:
        owner = row.get("matrix_seam") or ("library" if row.get("job_name") == "Library tests shard" else None)
        if owner in by_owner:
            return "not_warm", {}
        by_owner[owner] = row
    if set(by_owner) != owners:
        return "not_warm", {}
    components = {}
    for owner in sorted(owners):
        outcomes = by_owner[owner].get("cache_outcome")
        if not isinstance(outcomes, dict) or not outcomes:
            return "not_warm", {}
        for result in outcomes.values():
            if (not isinstance(result, dict) or result.get("cache_hit") is not True
                    or result.get("exact_key") is not True or result.get("fallback_used") is True
                    or result.get("restore_kind") == "fallback"):
                return "not_warm", {}
        components[owner] = sorted(outcomes)
    return "warm", components


def validate_profiled_receipt_sources(contract: dict, receipt: dict, root: pathlib.Path) -> None:
    """Keep a historical profiling receipt intact while checking an approved source amendment."""
    expected = {'before':contract.get('baseline_application_sha'),
                'after':(contract.get('candidate_identity') or {}).get('application_sha')}
    observed = {'before':receipt.get('baseline_source_sha'),'after':receipt.get('candidate_source_sha')}
    if expected == observed:
        return
    proofs = ((contract.get('native_coverage_comparison') or {}).get('source_equivalence') or {})
    for role in ('before','after'):
        if (proofs.get(role) or {}).get('inventory_source_sha') != observed[role]:
            raise ValueError('profiled_receipt_source_equivalence_missing')
        inventories = comparison_native_inventories(contract,role,root)
        if not all(row.get('workflow_authorization_sha256') for row in inventories.values()):
            raise ValueError('profiled_receipt_amended_source_not_approved')


def validate_producer_commit(source_sha: str, commit: dict, run: dict) -> list[str]:
    prs = run.get("pull_requests") or []
    if len(prs) != 1:
        return ["producer_commit_pull_request_origin_unavailable"]
    pr = prs[0]
    expected = {pr.get("head", {}).get("sha"), pr.get("base", {}).get("sha")}
    parents = {p.get("sha") for p in commit.get("parents", [])}
    if commit.get("sha") != source_sha or not re.fullmatch(r"[0-9a-f]{40}", source_sha or "") or parents != expected:
        return ["producer_merge_commit_origin_unverified"]
    if pr.get("number") is None or run.get("head_sha") != pr.get("head", {}).get("sha"):
        return ["producer_pr_head_binding_invalid"]
    return []


def validate_workflow_source(source_sha: str, tree: dict, workflow_bytes: bytes, expected_sha256: str, expected_tree_sha: str | None = None) -> list[str]:
    entries = [item for item in tree.get("tree", []) if item.get("path") == ".github/workflows/ci.yml" and item.get("type") == "blob"]
    blob_sha = hashlib.sha1(b"blob " + str(len(workflow_bytes)).encode() + b"\0" + workflow_bytes).hexdigest()
    commit_tree_sha = expected_tree_sha or tree.get("_expected_commit_tree_sha")
    if (tree.get("sha") is None or not re.fullmatch(r"[0-9a-f]{40}", source_sha or "")
            or not re.fullmatch(r"[0-9a-f]{40}", str(tree.get("sha") or ""))
            or (commit_tree_sha is not None and tree.get("sha") != commit_tree_sha)):
        return ["producer_workflow_tree_origin_unverified"]
    if len(entries) != 1 or entries[0].get("sha") != blob_sha or hashlib.sha256(workflow_bytes).hexdigest() != expected_sha256:
        return ["producer_workflow_source_hash_mismatch"]
    return []


def validate_general_job_identity(
    run: dict, attempt: int, job: dict, repository: str = "szTheory/sigra", *, request_bound: bool = False
) -> list[str]:
    """Check native API identity; request context may fill only genuinely absent fields."""
    expected_repo_id = 1207487684 if repository == "szTheory/sigra" else None
    diagnostics = []
    for native, expected in (("run_id", run.get("id")), ("run_attempt", attempt), ("head_sha", run.get("head_sha"))):
        value = job.get(native)
        if value is not None:
            if str(value) != str(expected):
                diagnostics.append("ranking_job_native_identity_conflict")
        elif not request_bound:
            diagnostics.append("ranking_job_native_identity_missing")
    # Collector assertions are supplementary evidence only. They can never mask a
    # conflicting native API field, and callers enable request_bound only after
    # validating the exact hashed request endpoint for this response.
    for asserted, expected in (("source_run_id", run.get("id")), ("source_run_attempt", attempt),
                               ("source_head_sha", run.get("head_sha")), ("source_repository", repository),
                               ("source_repository_id", expected_repo_id)):
        value = job.get(asserted)
        if value is not None and str(value) != str(expected):
            diagnostics.append("ranking_job_request_assertion_conflict")
    repo = job.get("repository")
    if repo is not None and repo != repository:
        diagnostics.append("ranking_job_repository_conflict")
    if not str(job.get("id", "")).isdigit():
        diagnostics.append("ranking_job_id_invalid")
    return sorted(set(diagnostics))


def bind_required_checks_by_attempt(run: dict, jobs_by_attempt: dict, checks: list[dict], required: list[str], repository: str = "szTheory/sigra",
                                    expected_app_ids: dict | None = None) -> tuple[list[str], dict, float | None]:
    """Validate every required check against the exact attempt job set before exposing endpoints or cost."""
    diagnostics = []
    repository_id = ((run.get("repository") or {}).get("id")
                     or (((run.get("pull_requests") or [{}])[0].get("head") or {}).get("repo") or {}).get("id"))
    if repository == "szTheory/sigra" and repository_id != 1207487684:
        diagnostics.append("family_repository_identity_invalid")
    job_by_id = {}
    runner_seconds = 0.0
    runner_complete = True
    seen_physical_ids = set()
    for attempt_text, jobs in sorted(jobs_by_attempt.items(), key=lambda item: int(item[0])):
        attempt = int(attempt_text)
        for job in jobs:
            row_errors = validate_general_job_identity(run, attempt, job, repository, request_bound=True)
            diagnostics.extend(row_errors)
            job_id = str(job.get("id", ""))
            if not job_id.isdigit() or row_errors:
                continue
            if job_id in job_by_id:
                prior = {key: value for key, value in job_by_id[job_id].items() if key != "_verified_attempt" and key not in ("run_attempt", "source_run_attempt", "attempt")}
                current = {key: value for key, value in job.items() if key not in ("run_attempt", "source_run_attempt", "attempt")}
                if prior != current:
                    diagnostics.append("ranking_job_physical_identity_conflict")
                    continue
            job_by_id[job_id] = {**job, "_verified_attempt": attempt}
            if job_id not in seen_physical_ids:
                seen_physical_ids.add(job_id)
                if job.get("conclusion") == "skipped":
                    continue
                try:
                    start, end = _utc(job["started_at"]), _utc(job["completed_at"])
                    if end < start:
                        raise ValueError
                    runner_seconds += (end - start).total_seconds()
                except (KeyError, TypeError, ValueError):
                    runner_complete = False
    endpoints = {}
    seen_checks = set()
    for check in checks:
        name = check.get("name")
        if name not in required:
            continue
        check_id = str(check.get("id", ""))
        external_id = str(check.get("external_id", ""))
        candidates = {key: row for key, row in job_by_id.items()
                     if key == check_id or (external_id.isdigit() and key == external_id)
                     or (row.get("check_run_url") is not None
                         and row.get("check_run_url", "").endswith(f"/check-runs/{check_id}"))}
        job = next(iter(candidates.values())) if len(candidates) == 1 else None
        if job is None or job.get("name") != name:
            diagnostics.append(f"required_check_job_binding_invalid:{name}")
            continue
        if (check.get("head_sha") != run.get("head_sha")
                or (check.get("app") or {}).get("slug") != "github-actions"
                or (check.get("check_suite") or {}).get("id") is None):
            diagnostics.append(f"required_check_origin_invalid:{name}")
            continue
        if expected_app_ids is not None:
            if (type((check.get("app") or {}).get("id")) is not int
                    or (check.get("app") or {}).get("id") != expected_app_ids.get(name)
                    or type((check.get("check_suite") or {}).get("id")) is not int
                    or type(run.get("check_suite_id")) is not int
                    or (check.get("check_suite") or {}).get("id") != run.get("check_suite_id")):
                diagnostics.append(f"required_check_app_or_suite_binding_invalid:{name}")
                continue
        attempt = job["_verified_attempt"]
        key = (attempt, name)
        if key in seen_checks:
            diagnostics.append(f"required_check_duplicate:{name}:attempt-{attempt}")
            continue
        seen_checks.add(key)
        endpoints.setdefault(str(attempt), {})[name] = {
            "id": check.get("id"), "external_id": check.get("external_id"),
            "job_id": job.get("id"), "attempt": attempt,
            "head_sha": check.get("head_sha"), "status": check.get("status"),
            "conclusion": check.get("conclusion"),
            "started_at": check.get("started_at"), "completed_at": check.get("completed_at"),
        }
    if diagnostics:
        return sorted(set(diagnostics)), {}, None
    return [], endpoints, runner_seconds if runner_complete else None


def verified_failure_log(root: pathlib.Path, relative: str, expected_sha256: str) -> bytes:
    """Return a retained log only when its path is contained and bytes match the audited hash."""
    root = pathlib.Path(root).resolve()
    rel = pathlib.PurePosixPath(relative or "")
    if not relative or rel.is_absolute() or ".." in rel.parts:
        raise ValueError("failure_log_path_invalid")
    path = (root / pathlib.Path(*rel.parts)).resolve()
    if not path.is_relative_to(root) or not _matches(path, expected_sha256):
        raise ValueError("failure_log_hash_or_containment_invalid")
    return path.read_bytes()


def verified_zip_members(archive_path: pathlib.Path, expected_archive_sha256: str, member_hashes: dict) -> dict[str, bytes]:
    archive_path = pathlib.Path(archive_path)
    if not _matches(archive_path, expected_archive_sha256):
        raise ValueError("artifact_zip_hash_mismatch")
    values = {}
    with zipfile.ZipFile(archive_path) as archive:
        names = [i.filename for i in archive.infolist() if not i.is_dir()]
        if len(names) != len(set(names)):
            raise ValueError("duplicate_archive_member")
        for name, expected in member_hashes.items():
            if name not in names:
                raise ValueError(f"artifact_member_missing:{name}")
            payload = archive.read(name)
            if not _matches_bytes(payload, expected):
                raise ValueError(f"artifact_member_hash_mismatch:{name}")
            values[name] = payload
    return values


def _matches_bytes(data: bytes, expected: object) -> bool:
    return isinstance(expected, str) and re.fullmatch(r"[0-9a-f]{64}", expected) is not None and hashlib.sha256(data).hexdigest() == expected


def sanitize_failure_log(raw: bytes, max_input_bytes: int = 1024 * 1024, max_output_bytes: int = 16384) -> dict:
    clipped = len(raw) > max_input_bytes
    raw = raw[:max_input_bytes]
    text = raw.decode("utf-8", "replace")
    output = []
    env_count = 0
    for line in text.splitlines():
        candidate = re.sub(r"^\s*(?:(?:\+{1,}|\$|>)+\s*)?", "", line)
        candidate = re.sub(r"^(?:declare\s+(?:-[A-Za-z]+|--)|export)\s+", "", candidate)
        if (re.match(r"^[A-Za-z_][A-Za-z0-9_]*\s*=", candidate)
                or re.match(r"^[A-Za-z_][A-Za-z0-9_]*\s+.+$", candidate) and "=" in candidate.split(" ", 1)[-1]
                or re.search(r"(?i)(?:\bprintenv\b|\benv\s+(?:dump|--all|\||$)|\benv\s*$|\bdeclare\s+-p\b|\bcompgen\s+-e\b|\bgithub_env\b|environment variables|^set\s*$|set\s+-o\s+posix)", candidate)):
            if not env_count:
                output.append("[ENVIRONMENT DUMP REDACTED]")
            env_count += 1
            continue
        if env_count:
            env_count = 0
        output.append(line)
    text = "\n".join(output)
    text = re.sub(r"\b(?:gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,})\b", "[REDACTED_TOKEN]", text)
    text = re.sub(r"(?i)\bBearer\s+[^\s,;]+", "Bearer [REDACTED]", text)
    text = re.sub(r"https?://[^\s<>\]\[()]+", "[URL REDACTED]", text)
    encoded = text.encode("utf-8")
    if len(encoded) > max_output_bytes:
        text = encoded[:max_output_bytes].decode("utf-8", "ignore")
        clipped = True
    if clipped:
        suffix = "\n[LOG EXCERPT TRUNCATED]"
        text = text.encode("utf-8")[:max(0, max_output_bytes - len(suffix))].decode("utf-8", "ignore") + suffix
    return {"text": text, "truncated": clipped, "input_bytes": len(raw), "output_bytes": len(text.encode("utf-8"))}


def safe_markdown_url(value: str) -> str | None:
    try:
        parsed = urllib.parse.urlsplit(value)
        if parsed.scheme != "https" or parsed.netloc != "github.com" or parsed.query or parsed.fragment or parsed.username or parsed.password:
            return None
        if re.fullmatch(r"/szTheory/sigra/actions/runs/[1-9][0-9]*(?:/job/[1-9][0-9]*)?", parsed.path):
            return value
        if re.fullmatch(r"/szTheory/sigra/pull/[1-9][0-9]*", parsed.path):
            return value
        return None
    except (TypeError, ValueError):
        return None


def escape_markdown_text(value: object) -> str:
    """Render untrusted data as inert text in a Markdown report."""
    text = str(value if value is not None else "unknown")
    replacements = {
        "&": "&amp;", "<": "&lt;", ">": "&gt;", "`": "&#96;",
        "[": "&#91;", "]": "&#93;", "(": "&#40;", ")": "&#41;",
        "!": "&#33;", "*": "&#42;", "_": "&#95;", "|": "&#124;",
        "\\": "&#92;", "#": "&#35;", "\n": " ", "\r": " ",
    }
    return "".join(replacements.get(char, char) for char in text)


class CoreRequestBudget:
    def __init__(self, remaining: int | None):
        self.remaining = remaining

    def refresh(self, observed: int | None) -> None:
        if observed is not None:
            self.remaining = observed if self.remaining is None else min(self.remaining, observed)

    def reserve(self) -> bool:
        if self.remaining is not None and self.remaining <= 250:
            return False
        if self.remaining is not None:
            self.remaining -= 1
        return True


def _comparison_budget_pass(contract: dict, path: pathlib.Path) -> dict | None:
    """Bind a measured pass to its predeclared, repository-confined ledger path."""
    if "collection_passes" not in contract:
        return None
    passes = contract["collection_passes"]
    if not isinstance(passes, list) or not passes:
        raise ValueError("request_budget_collection_passes_invalid")
    root = pathlib.Path.cwd().resolve()
    requested = pathlib.Path(path).absolute()
    selected = None
    paths, identities, pairs, reservations = set(), set(), set(), set()
    declared_reservations = {row.get("reservation_id"): row.get("pair_id")
                             for row in contract.get("family_reservations", [])}
    for row in passes:
        if not isinstance(row, dict):
            raise ValueError("request_budget_collection_passes_invalid")
        relative, ledger_id, pair_id = row.get("ledger_path"), row.get("ledger_id"), row.get("pair_id")
        slots = row.get("reservation_ids")
        if (not isinstance(relative, str) or not relative or "\\" in relative
                or pathlib.PurePosixPath(relative).is_absolute()
                or ".." in pathlib.PurePosixPath(relative).parts
                or pathlib.PurePosixPath(relative).as_posix() != relative
                or not isinstance(ledger_id, str) or not re.fullmatch(r"[0-9a-f]{64}", ledger_id)
                or not isinstance(pair_id, str) or not re.fullmatch(r"pair-[0-9]{2}", pair_id)
                or not isinstance(slots, list) or len(slots) != 2
                or any(not isinstance(slot, str) or not slot for slot in slots)
                or len(set(slots)) != 2):
            raise ValueError("request_budget_collection_passes_invalid")
        candidate = root / relative
        resolved = candidate.resolve()
        if not resolved.is_relative_to(root) or resolved != candidate:
            raise ValueError("request_budget_collection_pass_path_invalid")
        if (relative in paths or ledger_id in identities or pair_id in pairs
                or reservations.intersection(slots)):
            raise ValueError("request_budget_collection_passes_duplicate")
        if declared_reservations and any(declared_reservations.get(slot) != pair_id for slot in slots):
            raise ValueError("request_budget_collection_pass_reservations_invalid")
        paths.add(relative); identities.add(ledger_id); pairs.add(pair_id); reservations.update(slots)
        if requested == candidate:
            selected = row
    if selected is None:
        raise ValueError("request_budget_collection_pass_path_undeclared")
    return selected


def _comparison_budget_expected_id(contract: dict, path: pathlib.Path) -> str:
    selected = _comparison_budget_pass(contract, path)
    ledger_id = selected["ledger_id"] if selected is not None else contract.get("request_budget_ledger_id")
    if not isinstance(ledger_id, str) or not re.fullmatch(r"[0-9a-f]{64}", ledger_id):
        raise ValueError("request_budget_ledger_id_missing")
    return ledger_id


def validate_comparison_pass_reservation(contract: dict, path: pathlib.Path, reservation_id: str) -> None:
    """Prevent another pair's fresh budget from authorizing this pair's mutation."""
    selected = _comparison_budget_pass(contract, path)
    if selected is not None and reservation_id not in selected["reservation_ids"]:
        raise ValueError("request_budget_collection_pass_reservation_mismatch")


def _comparison_budget_read(path: pathlib.Path, contract: dict) -> dict:
    ledger_id = _comparison_budget_expected_id(contract, path)
    ledger = json.loads(path.read_text())
    expected = comparison_contract_sha256(contract)
    if (ledger.get("schema_version") != "sigra.ci-comparison-request-budget/v1"
            or ledger.get("contract_sha256") != expected
            or ledger.get("ledger_id") != ledger_id):
        raise ValueError("request_budget_ledger_contract_mismatch")
    previous = "0" * 64
    for index, row in enumerate(ledger.get("records") or []):
        body = {key: value for key, value in row.items() if key != "record_sha256"}
        digest = hashlib.sha256(json.dumps(body, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
        if row.get("sequence") != index or row.get("previous_sha256") != previous or row.get("record_sha256") != digest:
            raise ValueError("request_budget_ledger_chain_invalid")
        previous = digest
    return ledger


def _comparison_budget_append(path: pathlib.Path, ledger: dict, event: dict) -> dict:
    records = ledger.get("records") or []
    if any(row.get("stop_reason") for row in records):
        raise ValueError("request_budget_ledger_closed")
    row = {"sequence": len(records), "previous_sha256": records[-1]["record_sha256"] if records else "0" * 64, **event}
    row["record_sha256"] = hashlib.sha256(json.dumps(row, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
    updated = {**ledger, "records": records + [row]}
    temp = path.with_name(path.name + ".tmp")
    with temp.open("w") as output:
        json.dump(updated, output, sort_keys=True, separators=(",", ":"))
        output.flush()
        import os
        os.fsync(output.fileno())
    temp.replace(path)
    with path.open("rb") as source:
        import os
        os.fsync(source.fileno())
    return updated


def initialize_comparison_request_budget(contract: dict, path: pathlib.Path, *, now: int | None = None) -> dict:
    """Create or read back a contract-bound pass ledger; never reset an existing pass."""
    path = pathlib.Path(path)
    ledger_id = _comparison_budget_expected_id(contract, path)
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        return _comparison_budget_read(path, contract)
    ledger = {"schema_version": "sigra.ci-comparison-request-budget/v1", "ledger_id": ledger_id,
              "contract_sha256": comparison_contract_sha256(contract), "started_at_epoch": int(now if now is not None else __import__("time").time()),
              "records": []}
    path.write_text(json.dumps(ledger, sort_keys=True, separators=(",", ":")))
    return _comparison_budget_read(path, contract)


def comparison_request_budget_reserve(contract: dict, path: pathlib.Path, endpoint: str, *, owner: str, now: int | None = None) -> dict:
    """Durably reserve one actual HTTP attempt before calling the transport."""
    import os
    import time
    path = pathlib.Path(path)
    lock = path.with_name(path.name + ".lock")
    try:
        lock.mkdir()
    except FileExistsError as error:
        raise ValueError("request_budget_ledger_locked") from error
    try:
        ledger = _comparison_budget_read(path, contract)
        records = ledger.get("records") or []
        requests = [row for row in records if row.get("kind") == "request"]
        latest = next((row for row in reversed(records) if row.get("kind") in ("request", "policy")), {})
        current = int(now if now is not None else time.time())
        elapsed = current - int(ledger.get("started_at_epoch", current))
        if latest.get("stop_reason"):
            raise ValueError("request_budget_hard_stop:" + latest["stop_reason"])
        if elapsed >= 3600:
            raise ValueError("request_budget_time_limit_exhausted")
        if len(requests) >= 600:
            raise ValueError("request_budget_request_limit_exhausted")
        remaining = latest.get("core_remaining")
        if remaining is not None and int(remaining) <= 250:
            raise ValueError("request_budget_core_limit_stop")
        if remaining is not None:
            remaining = int(remaining) - 1
        ledger = _comparison_budget_append(path, ledger, {"kind": "request", "at_epoch": current,
                "endpoint": endpoint, "owner": owner, "core_remaining": remaining})
        verified = _comparison_budget_read(path, contract)
        if len(verified.get("records") or []) != len(ledger["records"]):
            raise ValueError("request_budget_ledger_readback_failed")
        return {"request_count": sum(row.get("kind") == "request" for row in verified["records"]), "core_remaining": remaining}
    finally:
        try:
            lock.rmdir()
        except OSError:
            pass


def comparison_watcher_start(contract: dict, path: pathlib.Path, run_id: object, *, owner: str, now: int | None = None) -> dict:
    """Claim the single watcher slot for a run in the same durable budget ledger."""
    import time
    path = pathlib.Path(path)
    lock = path.with_name(path.name + ".lock")
    try:
        lock.mkdir()
    except FileExistsError as error:
        raise ValueError("request_budget_ledger_locked") from error
    try:
        ledger = _comparison_budget_read(path, contract)
        run_id = str(run_id)
        if not run_id.isdigit() or not owner:
            raise ValueError("comparison_watcher_identity_invalid")
        existing = next((row for row in ledger.get("records", []) if row.get("kind") == "watcher" and row.get("run_id") == run_id), None)
        if existing:
            if existing.get("owner") != owner:
                raise ValueError("comparison_watcher_already_claimed")
            return {"run_id": run_id, "owner": owner, "started_at_epoch": existing.get("at_epoch"), "resumed": True}
        requests = [row for row in ledger.get("records", []) if row.get("kind") == "request"]
        current = int(now if now is not None else time.time())
        if current - int(ledger.get("started_at_epoch", current)) >= 3600:
            raise ValueError("request_budget_time_limit_exhausted")
        if len(requests) >= 600:
            raise ValueError("request_budget_request_limit_exhausted")
        latest = next((row for row in reversed(ledger.get("records", [])) if row.get("kind") in ("request", "policy")), {})
        if latest.get("stop_reason"):
            raise ValueError("request_budget_hard_stop:" + latest["stop_reason"])
        if latest.get("core_remaining") is not None and int(latest["core_remaining"]) <= 250:
            raise ValueError("request_budget_core_limit_stop")
        updated = _comparison_budget_append(path, ledger, {"kind": "watcher", "run_id": run_id, "owner": owner, "at_epoch": current})
        _comparison_budget_read(path, contract)
        return {"run_id": run_id, "owner": owner, "started_at_epoch": current, "ledger_records": len(updated["records"])}
    finally:
        try:
            lock.rmdir()
        except OSError:
            pass


def comparison_request_budget_record_response(contract: dict, path: pathlib.Path, *, core_remaining: int | None = None, reset_at: int | None = None, stop_reason: str | None = None) -> None:
    path = pathlib.Path(path)
    ledger = _comparison_budget_read(path, contract)
    latest = next((row for row in reversed(ledger.get("records") or []) if row.get("kind") in ("request", "policy")), {})
    remaining = latest.get("core_remaining")
    if core_remaining is not None:
        remaining = int(core_remaining) if remaining is None else min(int(remaining), int(core_remaining))
    _comparison_budget_append(path, ledger, {"kind": "policy", "at_epoch": int(__import__("time").time()),
        "core_remaining": remaining, "reset_at": reset_at if reset_at is not None else latest.get("reset_at"),
        "stop_reason": stop_reason})
    _comparison_budget_read(path, contract)


def deduplicate_physical_jobs(attempts: dict) -> tuple[list[dict], list[dict]]:
    """Count each physical job once and mark contradictory repeated receipts."""
    seen = {}
    counted, rows = [], []
    for attempt, jobs in sorted(attempts.items(), key=lambda item: int(item[0])):
        for job in jobs:
            job_id = str(job.get("id", ""))
            normalized = {key: value for key, value in job.items() if key not in ("run_attempt", "source_run_attempt", "attempt")}
            if not job_id:
                rows.append({"attempt": int(attempt), "job": job, "counted": False, "conflict": True})
                continue
            if job_id in seen:
                conflict = seen[job_id] != normalized
                rows.append({"attempt": int(attempt), "job": job, "counted": False, "conflict": conflict})
                if conflict:
                    rows[-1]["physical_job_id"] = job_id
                continue
            seen[job_id] = normalized
            row = {"attempt": int(attempt), "job": job, "counted": True}
            counted.append(row)
            rows.append(row)
    return counted, rows


def derive_attempt_job_costs(attempt_jobs: dict, *, strict_skipped_duration: bool = False) -> dict:
    """Sum runner time from raw jobs, retaining every attempt and surfacing unknowns."""
    known = 0.0
    unknown = []
    diagnostics = []
    attempt_costs = []
    if not isinstance(attempt_jobs, dict) or not attempt_jobs:
        return {"total_seconds": None, "known_subtotal_seconds": 0.0, "attempts": [], "unknown_jobs": ["attempt_jobs"], "diagnostics": ["attempt_jobs_missing"]}
    counted, history = deduplicate_physical_jobs(attempt_jobs) if isinstance(attempt_jobs, dict) else ([], [])
    conflicts = {row.get("physical_job_id") for row in history if row.get("conflict")}
    for job_id in sorted(value for value in conflicts if value):
        unknown.append(f"physical:{job_id}")
        diagnostics.append("physical_job_identity_conflict")
    unique_by_attempt = {}
    for row in counted:
        unique_by_attempt.setdefault(str(row["attempt"]), []).append(row["job"])
    for attempt, jobs in sorted(attempt_jobs.items(), key=lambda item: int(item[0]) if str(item[0]).isdigit() else 0):
        if not str(attempt).isdigit() or int(attempt) < 1 or not isinstance(jobs, list):
            diagnostics.append("attempt_jobs_shape_invalid")
            unknown.append(f"{attempt}:*")
            continue
        attempt_total = 0.0
        for job in unique_by_attempt.get(str(attempt), []):
            job_id = str(job.get("id", ""))
            identity = f"{attempt}:{job_id or '?'}"
            if not job_id.isdigit():
                unknown.append(identity)
                diagnostics.append("job_id_invalid")
                continue
            if job_id in conflicts:
                continue
            try:
                unexecuted = (not job.get("started_at") and not job.get("completed_at")) or (
                    not strict_skipped_duration and job.get("status") == "completed" and not job.get("steps")
                    and job.get("runner_id") in (None, 0) and not job.get("runner_name"))
                if job.get("conclusion") == "skipped" and unexecuted:
                    if strict_skipped_duration and (job.get("started_at") or job.get("completed_at")
                            or job.get("status") != "completed" or job.get("steps")
                            or job.get("runner_id") not in (None, 0) or job.get("runner_name")):
                        raise ValueError("skipped_job_execution_evidence_inconsistent")
                    seconds = 0.0
                else:
                    start, end = _utc(job["started_at"]), _utc(job["completed_at"])
                    seconds = (end - start).total_seconds()
                    if seconds < 0:
                        raise ValueError("negative_duration")
            except (KeyError, TypeError, ValueError):
                unknown.append(identity)
                continue
            known += seconds
            attempt_total += seconds
        attempt_costs.append({"attempt": int(attempt), "known_subtotal_seconds": round(attempt_total, 6)})
    return {
        "total_seconds": None if unknown else round(known, 6),
        "known_subtotal_seconds": round(known, 6),
        "attempts": attempt_costs,
        "unknown_jobs": sorted(set(unknown)),
        "diagnostics": sorted(set(diagnostics)),
    }


def derive_required_result_wait(run: dict, jobs_by_attempt: dict, checks: list[dict], required: list[str], *,
                               attempt: int | None = None, expected_app_ids: dict | None = None) -> dict:
    """Bind required checks to native jobs and derive the last successful completion."""
    if attempt is None:
        errors, by_attempt, _ = bind_required_checks_by_attempt(run, jobs_by_attempt, checks, required, expected_app_ids=expected_app_ids)
        origin_field = "created_at"
    else:
        errors, by_attempt, _ = bind_required_checks_by_attempt(run, {str(attempt): jobs_by_attempt.get(str(attempt), [])}, checks, required, expected_app_ids=expected_app_ids)
        origin_field = "run_started_at" if run.get("run_started_at") else "queued_at"
    if errors:
        return {"seconds": None, "missing_contexts": list(required), "diagnostics": errors}
    latest = {}
    for checks_for_attempt in by_attempt.values():
        for name, check in checks_for_attempt.items():
            try:
                check_attempt = int(check.get("attempt", 0))
            except (TypeError, ValueError):
                check_attempt = 0
            current = latest.get(name)
            if current is None or check_attempt >= current[0]:
                latest[name] = (check_attempt, check)
    successes = {}
    stale_failures = []
    bound_jobs = {}
    for name, (check_attempt, check) in latest.items():
        if check.get("status") == "completed" and check.get("conclusion") == "success":
            try:
                completed = _utc(check["completed_at"])
                created = _utc(run[origin_field])
                seconds = (completed - created).total_seconds()
                if seconds < 0:
                    continue
            except (KeyError, TypeError, ValueError):
                continue
            successes[name] = seconds
            bound_jobs[name] = {"attempt": check.get("attempt"), "check_id": check.get("id"), "job_id": check.get("job_id"), "completed_at": check.get("completed_at")}
        else:
            stale_failures.append(name)
    missing = sorted(set(required) - set(successes))
    diagnostics = []
    if attempt is not None and not run.get(origin_field):
        diagnostics.append("attempt_queue_or_start_origin_missing")
    if stale_failures:
        diagnostics.append("later_required_check_not_successful:" + ",".join(sorted(stale_failures)))
    endpoint = max((check.get("completed_at") for name, (_, check) in latest.items() if name in successes), default=None)
    return {"seconds": None if missing or diagnostics else round(max(successes.values()), 6), "missing_contexts": missing,
            "diagnostics": diagnostics, "required_result_completed_at": endpoint, "bound_required_jobs": bound_jobs}


def derive_comparison_family_costs(bundle: pathlib.Path, run_id: object, required_contexts: list[str], *,
                                   run_attempt: int | None = None, repaired: bool = False,
                                   registration: dict | None = None, expected_app_ids: dict | None = None) -> dict:
    """Replay cost and wait only from authenticated family files already collected."""
    root = pathlib.Path(bundle).resolve()
    sample_id = str(run_id) if run_attempt is None else f"{run_id}-attempt-{run_attempt}"
    family = root / "raw" / "families" / sample_id
    try:
        detail_path = family / "manifest.json"
        detail = json.loads(detail_path.read_text())
        run_path = family / "run.json"
        run_bytes = run_path.read_bytes()
        if not _matches(run_path, detail.get("source_run_sha256")):
            raise ValueError("comparison_run_hash_mismatch")
        run = json.loads(run_bytes)
        if (str(run.get("id")) != str(run_id) or detail.get("detail_status") != "complete"
                or (run_attempt is not None and run.get("run_attempt") != run_attempt)):
            raise ValueError("comparison_family_detail_incomplete")
        pull_request_identity = {}
        repository_identity = {}
        if repaired:
            if not isinstance(registration, dict):
                raise ValueError("comparison_family_registration_missing")
            pr_ref, merge_ref = detail.get("pull_request"), detail.get("merge_commit")
            if not isinstance(pr_ref, dict) or not isinstance(merge_ref, dict):
                raise ValueError("comparison_family_pr_merge_receipt_missing")
            pr_path=(root/pr_ref.get("path", "")).resolve(); merge_path=(root/merge_ref.get("path", "")).resolve()
            if (not pr_path.is_relative_to(root) or not merge_path.is_relative_to(root)
                    or not _matches(pr_path,pr_ref.get("sha256")) or not _matches(merge_path,merge_ref.get("sha256"))):
                raise ValueError("comparison_family_pr_merge_receipt_hash_invalid")
            pr=json.loads(pr_path.read_bytes()); merge=json.loads(merge_path.read_bytes())
            if (pr_ref.get("endpoint")!=f"/repos/szTheory/sigra/pulls/{registration.get('pull_request_number')}"
                    or merge_ref.get("endpoint")!=f"/repos/szTheory/sigra/git/commits/{registration.get('pull_request_merge_sha')}"):
                raise ValueError("comparison_family_pr_merge_endpoint_invalid")
            if (hashlib.sha256(pr_path.read_bytes()).hexdigest()!=registration.get("pull_request_response_sha256")
                    or hashlib.sha256(merge_path.read_bytes()).hexdigest()!=registration.get("merge_commit_response_sha256")
                    or validate_repaired_pr_origin(run,pr,merge,registration)):
                raise ValueError("comparison_family_pr_merge_registration_mismatch")
            collection=(json.loads((root/"manifest.json").read_text()).get("comparison_collection") or {})
            repo_ref=collection.get("repository_identity") or {}
            repo_path=(root/repo_ref.get("path", "")).resolve()
            if (repo_ref.get("endpoint")!="/repos/szTheory/sigra" or not repo_path.is_relative_to(root)
                    or not _matches(repo_path,repo_ref.get("sha256"))):
                raise ValueError("comparison_repository_default_branch_proof_missing")
            repository=json.loads(repo_path.read_bytes())
            default_branch=repository.get("default_branch")
            if repository.get("id")!=1207487684 or not isinstance(default_branch,str) or not default_branch:
                raise ValueError("comparison_repository_default_branch_invalid")
            number=pr.get("number"); merge_sha=pr.get("merge_commit_sha")
            merge_tree=((merge.get("commit") or {}).get("tree") or merge.get("tree") or {}).get("sha")
            base_ref=(pr.get("base") or {}).get("ref"); head_ref=(pr.get("head") or {}).get("ref")
            eligible={f"refs/heads/{default_branch}",f"refs/pull/{number}/merge"}
            if isinstance(base_ref,str) and base_ref: eligible.add(f"refs/heads/{base_ref}")
            if (isinstance(head_ref,str) and head_ref
                    and ((pr.get("head") or {}).get("repo") or {}).get("id")==1207487684):
                eligible.add(f"refs/heads/{head_ref}")
            pull_request_identity={"pull_request_number":number,"pull_request_merge_sha":merge_sha,
                "pull_request_merge_tree_sha":merge_tree,"pull_request_base_ref":base_ref,
                "pull_request_head_ref":head_ref,"default_branch_ref":f"refs/heads/{default_branch}",
                "eligible_cache_scopes":sorted(eligible)}
        jobs_by_attempt = {}
        for attempt, ref in sorted((detail.get("attempt_jobs") or {}).items(), key=lambda item: int(item[0])):
            expected_rel = f"raw/families/{sample_id}/jobs-attempt-{attempt}.json"
            rel = ref.get("path")
            if rel != expected_rel:
                raise ValueError("comparison_attempt_path_invalid")
            path = (root / rel).resolve()
            if not path.is_relative_to(root) or not _matches(path, ref.get("sha256")):
                raise ValueError("comparison_attempt_hash_mismatch")
            response = json.loads(path.read_text())
            jobs = response.get("jobs")
            if not isinstance(jobs, list):
                raise ValueError("comparison_attempt_jobs_invalid")
            jobs_by_attempt[str(attempt)] = jobs
        checks_path = family / "check-runs.json"
        checks_hash = detail.get("check_runs_sha256")
        if not _matches(checks_path, checks_hash):
            raise ValueError("comparison_check_runs_hash_mismatch")
        checks = json.loads(checks_path.read_text()).get("check_runs")
        if not isinstance(checks, list):
            raise ValueError("comparison_check_runs_invalid")
        cost = derive_attempt_job_costs(jobs_by_attempt, strict_skipped_duration=repaired)
        wait = derive_required_result_wait(run, jobs_by_attempt, checks, required_contexts, attempt=run_attempt,
                                           expected_app_ids=expected_app_ids if repaired else None)
        unique_jobs, physical_history = deduplicate_physical_jobs(jobs_by_attempt)
        if any(row.get("conflict") for row in physical_history):
            cost["total_seconds"] = None
            cost["diagnostics"] = sorted(set(cost["diagnostics"] + ["physical_job_identity_conflict"]))
        return {"status": "complete", "run_id": run_id, "conclusion": run.get("conclusion"),
                "created_at": run.get("created_at"), "run_attempt": run.get("run_attempt"),
                **pull_request_identity,
                "attempt_origin_at": (run.get("run_started_at") or run.get("queued_at")) if run_attempt is not None else run.get("created_at"), "head_sha": run.get("head_sha"),
                "runner_seconds": cost["total_seconds"], "runner_known_subtotal_seconds": cost["known_subtotal_seconds"],
                "runner_unknown_jobs": cost["unknown_jobs"], "runner_diagnostics": cost["diagnostics"],
                "attempt_costs": cost["attempts"], "required_result_wait_seconds": wait["seconds"],
                "required_result_completed_at": wait.get("required_result_completed_at"),
                "bound_required_jobs": wait.get("bound_required_jobs", {}),
                "unique_physical_jobs": len(unique_jobs), "physical_job_history": physical_history,
                "unknown_durations": cost["unknown_jobs"],
                "missing_required_contexts": wait["missing_contexts"], "wait_diagnostics": wait["diagnostics"]}
    except (OSError, ValueError, TypeError, KeyError) as error:
        return {"status": "unknown", "run_id": run_id, "runner_seconds": None,
                "runner_known_subtotal_seconds": 0, "runner_unknown_jobs": [],
                "required_result_wait_seconds": None, "diagnostics": [str(error) or "comparison_raw_input_invalid"]}


def comparison_contract_sha256(contract: dict) -> str:
    frozen = {k: v for k, v in contract.items() if k not in ("family_registrations", "registration_ledger_sha256")}
    return hashlib.sha256(json.dumps(frozen, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


FINITE_STAGE_LIMITS = {
    "local-development-freeze": {"requests": 0, "mutations": 0},
    "prep-readiness": {"requests": 600, "request_total": 600, "mutations": 0,
                       "minutes": 60, "invocations": 1},
    "prep-full-workload": {"requests_per_invocation": 600, "request_total": 2400,
                            "mutations": 9, "invocations": 4,
                            "invocations_per_side": 2, "minutes": 120},
    "lightweight-canary": {"requests_per_scenario": 600, "request_total": 1800,
                            "mutations": 4, "invocations": 3, "minutes": 60,
                            "conditional_on_demonstrated_delivery_gap": True},
    "measurement": {"requests_per_family": 600, "request_total": 24000,
                    "mutations": 82, "primary_families": 40, "pairs": 20,
                    "window_hours": 48},
    "terminal-retrieval-cleanup": {"requests": 600, "request_total": 600,
                                   "mutations": 42, "minutes": 60,
                                   "closes_max": 40, "prep_ref_deletes_max": 2,
                                   "requires_explicit_approval_for_prep_ref_delete": True},
}


def finite_comparison_schedule(seed: int = 2551001, pair_count: int = 20) -> list[dict]:
    """Return SHA256-ranked, balanced pair order for the new finite experiment."""
    if type(seed) is not int or seed != 2551001 or type(pair_count) is not int or pair_count != 20:
        raise ValueError("finite_schedule_seed_or_pair_count_invalid")
    pair_ids = [f"pair-{number:02d}" for number in range(1, pair_count + 1)]
    ranked = sorted(pair_ids, key=lambda pair_id: hashlib.sha256(
        f"{seed}:{pair_id}".encode("utf-8")).hexdigest())
    control_first = set(ranked[:pair_count // 2])
    rows = []
    for pair_id in pair_ids:
        order = ("control", "candidate") if pair_id in control_first else ("candidate", "control")
        for position, role in enumerate(order, 1):
            rows.append({"pair_id": pair_id, "role": role, "family_role": role,
                         "position": position,
                         "family_id": f"{pair_id}-{role}"})
    return rows


def validate_finite_experiment_policy(contract: dict) -> list[str]:
    """Validate the additive Phase255.1 finite contract without changing legacy policy."""
    errors = []
    if contract.get("schema_version") != "sigra.ci-repaired-experiment/v1":
        return ["finite_contract_schema_invalid"]
    if contract.get("experiment_id") != "sigra-ci-repaired-255.1":
        errors.append("finite_contract_experiment_id_invalid")
    if contract.get("seed") != 2551001 or contract.get("pair_count") != 20 or contract.get("primary_family_count") != 40:
        errors.append("finite_contract_seed_or_family_count_invalid")
    if contract.get("schedule") != finite_comparison_schedule():
        errors.append("finite_contract_seeded_schedule_invalid")
    if contract.get("window_hours") != 48:
        errors.append("finite_contract_window_duration_invalid")
    if contract.get("maximum_pair_start_gap_seconds") != 3600:
        errors.append("finite_contract_pair_start_gap_invalid")
    if contract.get("maximum_second_side_after_terminal_seconds") != 300:
        errors.append("finite_contract_second_side_terminal_gap_invalid")
    if contract.get("maximum_infrastructure_retries_total") != 1:
        errors.append("finite_contract_infrastructure_retry_cap_invalid")
    if contract.get("product_retry_count") != 0:
        errors.append("finite_contract_product_retry_forbidden")
    if contract.get("replacement_family_count") != 0:
        errors.append("finite_contract_replacement_families_forbidden")
    if contract.get("window_renewals") != 0:
        errors.append("finite_contract_window_renewal_forbidden")
    if contract.get("preparation_retries") != 0:
        errors.append("finite_contract_preparation_retry_forbidden")
    if contract.get("stages") != FINITE_STAGE_LIMITS:
        errors.append("finite_contract_stage_limits_invalid")
    return errors


def validate_comparison_plan(contract: dict) -> list[str]:
    """Validate the immutable Phase 254 execution copy before runs are registered."""
    if contract.get("schema_version") == "sigra.ci-repaired-experiment/v1":
        return validate_finite_experiment_policy(contract)
    diagnostics = []
    if contract.get("comparison_kind") not in (None, "repaired_control_pr"):
        diagnostics.append("comparison_kind_invalid")
    if contract.get("comparison_kind") == "repaired_control_pr":
        required = contract.get("required_contexts")
        if not isinstance(required, list) or len(required) != 5 or len(set(required)) != 5:
            diagnostics.append("repaired_required_contexts_invalid")
        app_ids=contract.get("required_check_apps")
        if (not isinstance(app_ids,dict) or set(app_ids)!=set(required or [])
                or any(type(value) is not int or value<=0 for value in app_ids.values())):
            diagnostics.append("repaired_required_check_app_ids_invalid")
        cache=contract.get("cache_eligibility") or {}
        owners={"library","admin_behavior","admin_checkpoints","design_gallery","non_admin_smoke","demo_showcase"}
        expected_keys=cache.get("expected_keys") or {}
        if not isinstance(cache.get("default_branch_ref"),str) or not cache["default_branch_ref"].startswith("refs/heads/"):
            diagnostics.append("repaired_cache_default_branch_not_frozen")
        if set(expected_keys)!={"before","after"} or any(
                not isinstance(expected_keys.get(role),dict) or set(expected_keys[role])!=owners
                or any(not isinstance(expected_keys[role].get(owner),dict) or not expected_keys[role][owner]
                       or any(not isinstance(key,str) or not key or len(key)>512 for key in expected_keys[role][owner].values())
                       for owner in owners) for role in ("before","after")):
            diagnostics.append("repaired_source_specific_cache_keys_not_frozen")
    sample_identity = contract.get("sample_identity")
    if sample_identity not in (None, "run_id+run_attempt"):
        diagnostics.append("comparison_sample_identity_invalid")
    schedule = contract.get("comparison_schedule")
    reservations = contract.get("family_reservations") or []
    if contract.get("status") != "ready" or contract.get("pair_count") != 20 or contract.get("primary_family_count") != 40:
        diagnostics.append("comparison_plan_contract_invalid")
    if not isinstance(schedule, list) or len(schedule) != 40:
        diagnostics.append("comparison_schedule_incomplete")
        schedule = []
    expected = []
    for pair in range(1, 21):
        first = "before" if pair % 2 else "after"
        second = "after" if first == "before" else "before"
        expected.extend(((f"pair-{pair:02d}", first), (f"pair-{pair:02d}", second)))
    actual = [(row.get("pair_id"), row.get("family_role")) for row in schedule if isinstance(row, dict)]
    if actual != expected:
        diagnostics.append("comparison_schedule_order_invalid")
    if len([role for _, role in actual if role == "before"]) != 20 or len([role for _, role in actual if role == "after"]) != 20:
        diagnostics.append("comparison_schedule_balance_invalid")
    reservation_keys = [(row.get("pair_id"), row.get("family_role")) for row in reservations if isinstance(row, dict)]
    if reservation_keys != expected or len({row.get("reservation_id") for row in reservations if isinstance(row, dict)}) != 40:
        diagnostics.append("comparison_reservations_do_not_match_schedule")
    if sample_identity == "run_id+run_attempt":
        identities = [(str(row.get("run_id")), row.get("run_attempt")) for row in reservations]
        if any(not str(row.get("run_id", "")).isdigit() or type(row.get("run_attempt")) is not int or row["run_attempt"] < 1 for row in reservations):
            diagnostics.append("comparison_attempt_mapping_invalid")
        if len(identities) != len(set(identities)):
            diagnostics.append("comparison_attempt_mapping_duplicate")
        instrumentation=contract.get("instrumentation_identity") or {}
        if not all(isinstance(instrumentation.get(key),str) and instrumentation.get(key) for key in ("exunit","playwright")):
            diagnostics.append("comparison_attempt_instrumentation_identity_missing")
    if contract.get("maximum_pair_start_gap_seconds") != 1800:
        diagnostics.append("comparison_pair_start_bound_invalid")
    prep = contract.get("preparation_compatibility")
    if not isinstance(prep, dict) or not prep.get("baseline_cache_stratum") or not prep.get("candidate_cache_stratum") or not prep.get("runner_image_policy"):
        diagnostics.append("comparison_preparation_not_predeclared")
    candidate = contract.get("candidate_identity") or {}
    if not all(candidate.get(key) for key in ("application_sha", "workflow_revision", "workload_revision_sha256", "workflow_file_sha256")):
        diagnostics.append("comparison_candidate_identity_incomplete")
    window = contract.get("window") or {}
    try:
        if _utc(window["end_utc"]) - _utc(window["start_utc"]) != __import__("datetime").timedelta(hours=48):
            diagnostics.append("comparison_window_duration_invalid")
    except (KeyError, TypeError, ValueError):
        diagnostics.append("comparison_window_not_predeclared")
    return sorted(set(diagnostics))


def validate_comparison_schedule(contract: dict, registrations: list[dict]) -> list[str]:
    """Check append order and pair proximity using authenticated registered starts."""
    if contract.get("schema_version") == "sigra.ci-repaired-experiment/v1":
        errors = validate_finite_experiment_policy(contract)
        schedule = contract.get("schedule") or []
        if len(registrations) > len(schedule):
            return sorted(set(errors + ["finite_registration_late_or_extra"]))
        families = {row.get("family_id"): row for row in contract.get("families", []) if isinstance(row, dict)}
        pair_starts, pair_terminals = {}, {}
        for index, row in enumerate(registrations):
            expected = schedule[index] if index < len(schedule) else {}
            family_id = row.get("family_id")
            family = families.get(family_id, {})
            if (family_id != expected.get("family_id") or row.get("reservation_id") != family_id
                    or row.get("pair_id") != expected.get("pair_id")
                    or row.get("family_role") != expected.get("role")
                    or row.get("source_sha") != family.get("source_sha")):
                errors.append("finite_registration_identity_or_order_invalid")
            try:
                started = _utc(row.get("created_at"))
                pair_starts.setdefault(row.get("pair_id"), []).append(started)
                terminal = row.get("terminal_at")
                if terminal:
                    pair_terminals.setdefault(row.get("pair_id"), {})[row.get("family_role")] = _utc(terminal)
            except (TypeError, ValueError):
                errors.append("finite_registration_time_invalid")
        for pair_id, starts in pair_starts.items():
            if len(starts) == 2 and (starts[1] <= starts[0]
                    or (starts[1] - starts[0]).total_seconds() > 3600):
                errors.append("finite_pair_start_gap_exceeded")
            if len(starts) == 2:
                rows = [row for row in registrations if row.get("pair_id") == pair_id]
                earlier_role = rows[0].get("family_role")
                later_role = rows[1].get("family_role")
                terminal = pair_terminals.get(pair_id, {}).get(earlier_role)
                if terminal is None or (starts[1] - terminal).total_seconds() > 300:
                    errors.append("finite_second_side_terminal_gap_exceeded")
                if earlier_role == later_role:
                    errors.append("finite_pair_roles_not_distinct")
        return sorted(set(errors))
    diagnostics = []
    schedule = contract.get("comparison_schedule") or []
    reservations = {row.get("reservation_id"): row for row in contract.get("family_reservations") or []}
    if len(registrations) > len(schedule):
        return ["comparison_registration_late_or_extra"]
    for index, row in enumerate(registrations):
        expected = schedule[index] if index < len(schedule) else {}
        reservation = reservations.get(row.get("reservation_id"), {})
        key = (row.get("pair_id"), row.get("family_role"))
        if key != (expected.get("pair_id"), expected.get("family_role")) or key != (reservation.get("pair_id"), reservation.get("family_role")):
            diagnostics.append("comparison_registration_order_invalid")
        if row.get("reservation_id") != reservation.get("reservation_id"):
            diagnostics.append("comparison_registration_reservation_invalid")
        if contract.get("sample_identity") == "run_id+run_attempt" and (
                str(row.get("run_id")) != str(reservation.get("run_id"))
                or row.get("run_attempt") != reservation.get("run_attempt")):
            diagnostics.append("comparison_registration_attempt_mapping_invalid")
    starts = {}
    for row in registrations:
        try:
            starts.setdefault(row.get("pair_id"), []).append(_utc(row.get("attempt_origin_at") if contract.get("sample_identity") == "run_id+run_attempt" else row.get("created_at")))
        except (TypeError, ValueError):
            diagnostics.append("comparison_registration_created_at_invalid")
    for pair_id, values in starts.items():
        if len(values) > 2 or (len(values) == 2 and values[1] <= values[0]):
            diagnostics.append("comparison_pair_start_not_ordered")
        if len(values) == 2 and (values[1] - values[0]).total_seconds() > 1800:
            diagnostics.append("comparison_pair_start_gap_exceeded")
    if contract.get("sample_identity") == "run_id+run_attempt":
        identities = [(str(row.get("run_id")), row.get("run_attempt")) for row in registrations]
        if len(identities) != len(set(identities)):
            diagnostics.append("comparison_registration_attempt_duplicate")
    return sorted(set(diagnostics))


def validate_comparison_registration_ledger(contract: dict, ledger: dict) -> list[str]:
    """Authenticate a partial early-registration chain before collection uses its run IDs."""
    rows = ledger.get("records") or []
    diagnostics = validate_comparison_plan(contract)
    if ledger.get("contract_sha256") != comparison_contract_sha256(contract):
        diagnostics.append("comparison_registration_contract_hash_mismatch")
    if len(rows) > 40:
        diagnostics.append("comparison_registration_set_too_large")
    diagnostics.extend(validate_comparison_schedule(contract, rows))
    reservations = {row.get("reservation_id"): row for row in contract.get("family_reservations") or []}
    previous = "0" * 64
    for index, row in enumerate(rows):
        body = {key: value for key, value in row.items() if key != "record_sha256"}
        digest = hashlib.sha256(json.dumps(body, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
        reservation = reservations.get(row.get("reservation_id"))
        try:
            raw = base64.b64decode(row.get("api_run_response_b64", ""), validate=True)
            api_run = json.loads(raw)
            expected_sha = contract.get("baseline_application_sha") if row.get("family_role") == "before" else (contract.get("candidate_identity") or {}).get("application_sha")
            attempt_scoped = contract.get("sample_identity") == "run_id+run_attempt"
            expected_attempt = reservation.get("run_attempt") if reservation else None
            expected_run_id = reservation.get("run_id") if reservation else None
            attempt_origin = api_run.get("run_started_at") or api_run.get("queued_at")
            valid = (hashlib.sha256(raw).hexdigest() == row.get("api_run_sha256")
                     and str(api_run.get("id")) == str(row.get("run_id"))
                     and api_run.get("status") in ("queued", "in_progress") and api_run.get("conclusion") is None
                     and api_run.get("created_at") == row.get("created_at") and api_run.get("head_sha") == expected_sha
                     and (not attempt_scoped or (api_run.get("run_attempt") == expected_attempt == row.get("run_attempt")
                          and str(expected_run_id) == str(row.get("run_id"))
                          and attempt_origin == row.get("attempt_origin_at") and bool(attempt_origin)
                          and row.get("sample_id") == f"{row.get('run_id')}-attempt-{row.get('run_attempt')}"))
                     and api_run.get("event") == "pull_request" and api_run.get("path") == ".github/workflows/ci.yml"
                     and len(api_run.get("pull_requests") or []) == 1
                     and api_run["pull_requests"][0].get("head", {}).get("sha") == expected_sha)
            if contract.get("comparison_kind") == "repaired_control_pr":
                pr_raw = base64.b64decode(row.get("pull_request_response_b64", ""), validate=True)
                merge_raw = base64.b64decode(row.get("merge_commit_response_b64", ""), validate=True)
                if (hashlib.sha256(pr_raw).hexdigest() != row.get("pull_request_response_sha256")
                        or hashlib.sha256(merge_raw).hexdigest() != row.get("merge_commit_response_sha256")):
                    raise ValueError("comparison_registration_pr_proof_digest_mismatch")
                pr_doc, merge_doc = json.loads(pr_raw), json.loads(merge_raw)
                valid = valid and not validate_repaired_pr_origin(api_run, pr_doc, merge_doc, row)
        except (ValueError, TypeError, KeyError):
            valid = False
        if (row.get("sequence") != index or row.get("previous_sha256") != previous or row.get("record_sha256") != digest
                or reservation is None or row.get("pair_id") != reservation.get("pair_id")
                or row.get("family_role") != reservation.get("family_role") or not valid):
            diagnostics.append("comparison_registration_identity_invalid")
        previous = row.get("record_sha256", "")
    return sorted(set(diagnostics))


def comparison_registered_runs(contract: dict, ledger: dict, role: str) -> list[dict]:
    if role not in ("before", "after"):
        raise ValueError("comparison_role_invalid")
    issues = validate_comparison_registration_ledger(contract, ledger)
    if issues:
        raise ValueError(issues[0])
    rows = [row for row in ledger.get("records", []) if row.get("family_role") == role]
    if not rows:
        raise ValueError("comparison_role_has_no_registered_runs")
    return [{"comparison_kind": contract.get("comparison_kind"), "reservation_id": row["reservation_id"], "pair_id": row["pair_id"],
             "family_role": role, "run_id": row["run_id"], "run_attempt": row.get("run_attempt"),
             "sample_id": f"{row['run_id']}-attempt-{row['run_attempt']}" if row.get("run_attempt") is not None else str(row["run_id"]),
             "attempt_origin_at": row.get("attempt_origin_at"), "created_at": row["created_at"],
             "event": row.get("event"), "workflow_path": row.get("workflow_path"),
             "head_sha": row["head_sha"], "pull_request_head_sha": row["pull_request_head_sha"],
             "pull_request_base_sha": row["pull_request_base_sha"],
             **({"pull_request_merge_sha": row.get("pull_request_merge_sha"),
                 "pull_request_merge_tree_sha": row.get("pull_request_merge_tree_sha"),
                 "pull_request_response_sha256": row.get("pull_request_response_sha256"),
                 "merge_commit_response_sha256": row.get("merge_commit_response_sha256")}
                if contract.get("comparison_kind") == "repaired_control_pr" else {}),
             "pull_request_number": row["pull_request_number"]} for row in rows]


def validate_registered_run_observation(registration: dict, api_run: dict) -> list[str]:
    """Bind a later completed API read to its already-registered outcome-blind slot."""
    expected = (str(api_run.get("id")) == str(registration.get("run_id"))
                and api_run.get("created_at") == registration.get("created_at")
                and api_run.get("event") == "pull_request" and api_run.get("path") == ".github/workflows/ci.yml"
                and api_run.get("head_sha") == registration.get("head_sha"))
    prs = api_run.get("pull_requests") or []
    if len(prs) != 1:
        return ["comparison_run_pull_request_identity_invalid"]
    pr = prs[0]
    if registration.get("run_attempt") is not None:
        origin = api_run.get("run_started_at") or api_run.get("queued_at")
        expected = expected and api_run.get("run_attempt") == registration.get("run_attempt")
        expected = expected and origin == registration.get("attempt_origin_at") and bool(origin)
    expected = expected and pr.get("number") == registration.get("pull_request_number")
    expected = expected and pr.get("head", {}).get("sha") == registration.get("pull_request_head_sha")
    expected = expected and pr.get("base", {}).get("sha") == registration.get("pull_request_base_sha")
    return [] if expected else ["comparison_run_registered_identity_mismatch"]


def register_comparison_run(contract: dict, reservation_id: str, api_run: dict, ledger: dict | None = None,
                            api_run_sha256: str | None = None, api_run_response_bytes: bytes | None = None,
                            pull_request_response: dict | None = None, merge_commit_response: dict | None = None,
                            pull_request_response_bytes: bytes | None = None,
                            merge_commit_response_bytes: bytes | None = None) -> dict:
    """Create an append-only identity record without reading the API outcome fields."""
    reservations = [x for x in contract.get("family_reservations", []) if x.get("reservation_id") == reservation_id]
    if len(reservations) != 1:
        raise ValueError("comparison_reservation_unknown_or_duplicate")
    reservation = reservations[0]
    attempt_scoped = contract.get("sample_identity") == "run_id+run_attempt"
    expected_sha = contract.get("baseline_application_sha") if reservation.get("family_role") == "before" else (contract.get("candidate_identity") or {}).get("application_sha")
    try:
        start, end = _utc(contract["window"]["start_utc"]), _utc(contract["window"]["end_utc"])
        created = _utc(api_run["created_at"])
        attempt_origin = _utc(api_run.get("run_started_at") or api_run.get("queued_at")) if attempt_scoped else created
    except (KeyError, TypeError, ValueError):
        raise ValueError("comparison_run_identity_or_window_invalid")
    pull_requests = api_run.get("pull_requests") or []
    if (contract.get("status") != "ready" or not expected_sha or len(pull_requests) != 1
            or not isinstance(api_run.get("id"), int) or api_run.get("id") <= 0 or api_run.get("event") != "pull_request"
            or api_run.get("status") not in ("queued", "in_progress") or api_run.get("conclusion") is not None
            or not re.fullmatch(r"[0-9a-f]{64}", api_run_sha256 or "")
            or api_run.get("path") != ".github/workflows/ci.yml" or api_run.get("head_sha") != expected_sha
            or (not attempt_scoped and not start <= created <= end)
            or (attempt_scoped and (api_run.get("run_attempt") != reservation.get("run_attempt")
                or str(api_run.get("id")) != str(reservation.get("run_id"))
                or not (api_run.get("run_started_at") or api_run.get("queued_at"))
                or not start <= attempt_origin <= end))
            or reservation.get("pair_id") is None):
        raise ValueError("comparison_run_identity_does_not_match_reservation")
    pr = pull_requests[0]
    if pr.get("head", {}).get("sha") != expected_sha:
        raise ValueError("comparison_run_pull_request_head_mismatch")
    if (reservation.get("pull_request_number") is not None and pr.get("number") != reservation.get("pull_request_number")):
        raise ValueError("comparison_run_pull_request_number_mismatch")
    if (reservation.get("pull_request_base_sha") is not None and pr.get("base", {}).get("sha") != reservation.get("pull_request_base_sha")):
        raise ValueError("comparison_run_pull_request_base_mismatch")
    pr_raw = merge_raw = None
    if contract.get("comparison_kind") == "repaired_control_pr":
        if not isinstance(pull_request_response, dict) or not isinstance(merge_commit_response, dict):
            raise ValueError("comparison_pull_request_and_merge_commit_proofs_required")
        if validate_repaired_pr_origin(api_run, pull_request_response, merge_commit_response):
            raise ValueError("comparison_pull_request_or_merge_commit_origin_invalid")
        pr_raw = pull_request_response_bytes if pull_request_response_bytes is not None else json.dumps(pull_request_response, sort_keys=True, separators=(",", ":")).encode()
        merge_raw = merge_commit_response_bytes if merge_commit_response_bytes is not None else json.dumps(merge_commit_response, sort_keys=True, separators=(",", ":")).encode()
        try:
            if json.loads(pr_raw) != pull_request_response or json.loads(merge_raw) != merge_commit_response:
                raise ValueError("comparison_pull_request_proof_bytes_invalid")
        except (UnicodeError, json.JSONDecodeError, TypeError) as error:
            raise ValueError("comparison_pull_request_proof_bytes_invalid") from error
    previous_rows = (ledger or {}).get("records", [])
    if contract.get("comparison_schedule"):
        plan_errors = validate_comparison_plan(contract)
        if plan_errors:
            raise ValueError(plan_errors[0])
        schedule_row={"reservation_id": reservation_id, "pair_id": reservation.get("pair_id"), "family_role": reservation.get("family_role"), "created_at": api_run.get("created_at")}
        if attempt_scoped: schedule_row.update({"run_id": api_run.get("id"), "run_attempt": api_run.get("run_attempt"), "attempt_origin_at": (api_run.get("run_started_at") or api_run.get("queued_at"))})
        schedule_errors = validate_comparison_schedule(contract, previous_rows + [schedule_row])
        if schedule_errors:
            raise ValueError(schedule_errors[0])
    if (ledger and ledger.get("contract_sha256") != comparison_contract_sha256(contract)):
        raise ValueError("comparison_registration_contract_hash_mismatch")
    if any(x.get("reservation_id") == reservation_id or (str(x.get("run_id")) == str(api_run["id"]) and (not attempt_scoped or x.get("run_attempt") == api_run.get("run_attempt"))) for x in previous_rows):
        raise ValueError("comparison_registration_duplicate")
    raw_api = api_run_response_bytes if api_run_response_bytes is not None else json.dumps(api_run, sort_keys=True, separators=(",", ":")).encode()
    if hashlib.sha256(raw_api).hexdigest() != api_run_sha256:
        raise ValueError("comparison_registration_api_response_hash_mismatch")
    try:
        if json.loads(raw_api) != api_run:
            raise ValueError("comparison_registration_api_response_content_mismatch")
    except (ValueError, TypeError) as error:
        raise ValueError("comparison_registration_api_response_invalid") from error
    identity = {
        "reservation_id": reservation_id,
        "pair_id": reservation["pair_id"],
        "family_role": reservation["family_role"],
        "run_id": api_run["id"],
        **({"run_attempt": api_run["run_attempt"], "attempt_origin_at": api_run.get("run_started_at") or api_run.get("queued_at"), "sample_id": f"{api_run['id']}-attempt-{api_run['run_attempt']}"} if attempt_scoped else {}),
        "created_at": api_run["created_at"],
        "event": api_run["event"],
        "workflow_path": api_run["path"],
        "head_sha": api_run["head_sha"],
        "pull_request_number": pr.get("number"),
        "pull_request_head_sha": pr.get("head", {}).get("sha"),
        "pull_request_base_sha": pr.get("base", {}).get("sha"),
        **({"pull_request_merge_sha": pull_request_response.get("merge_commit_sha"),
            "pull_request_merge_tree_sha": ((merge_commit_response.get("commit") or {}).get("tree") or merge_commit_response.get("tree") or {}).get("sha"),
            "pull_request_response_sha256": hashlib.sha256(pr_raw).hexdigest(),
            "pull_request_response_b64": base64.b64encode(pr_raw).decode("ascii"),
            "merge_commit_response_sha256": hashlib.sha256(merge_raw).hexdigest(),
            "merge_commit_response_b64": base64.b64encode(merge_raw).decode("ascii")} if contract.get("comparison_kind") == "repaired_control_pr" else {}),
        "api_run_sha256": api_run_sha256,
        "api_run_response_b64": base64.b64encode(raw_api).decode("ascii"),
    }
    record = {"sequence": len(previous_rows), "previous_sha256": previous_rows[-1]["record_sha256"] if previous_rows else "0" * 64, **identity}
    record["record_sha256"] = hashlib.sha256(json.dumps(record, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
    return {"schema_version": "sigra.ci-comparison-registration/v1", "contract_sha256": comparison_contract_sha256(contract), "records": previous_rows + [record]}


def validate_comparison_reservations(contract: dict, families: list[dict], source_runs: list[dict], registration_ledger: dict | None = None) -> list[str]:
    reservations = contract.get("family_reservations") or []
    registration_ledger = registration_ledger or {"contract_sha256": comparison_contract_sha256(contract), "records": contract.get("family_registrations") or []}
    registrations = registration_ledger.get("records") or []
    reserved = {(x.get("pair_id"), x.get("family_role")): x for x in reservations}
    runs = {(str(x.get("id")), x.get("run_attempt")): x for x in source_runs if x.get("event") == "pull_request"}
    diagnostics = []
    if contract.get("comparison_schedule"):
        diagnostics.extend(validate_comparison_plan(contract))
        diagnostics.extend(validate_comparison_schedule(contract, registrations))
    if registration_ledger.get("contract_sha256") != comparison_contract_sha256(contract):
        diagnostics.append("comparison_registration_contract_hash_mismatch")
    if len(reservations) != 40 or len(reserved) != 40 or len({x.get("reservation_id") for x in reservations}) != 40:
        diagnostics.append("comparison_reservation_set_incomplete")
    if len(registrations) != 40:
        diagnostics.append("comparison_registration_set_incomplete")
    previous = "0" * 64
    registration_by_key = {}
    for index, row in enumerate(registrations):
        record = {k: v for k, v in row.items() if k != "record_sha256"}
        canonical = json.dumps(record, sort_keys=True, separators=(",", ":")).encode()
        digest = hashlib.sha256(canonical).hexdigest()
        if row.get("sequence") != index or row.get("previous_sha256") != previous or row.get("record_sha256") != digest:
            diagnostics.append("comparison_registration_chain_invalid")
        previous = row.get("record_sha256", "")
        registration_by_key[row.get("reservation_id")] = row
        try:
            raw = base64.b64decode(row.get("api_run_response_b64", ""), validate=True)
            api_run = json.loads(raw)
            valid_raw = hashlib.sha256(raw).hexdigest() == row.get("api_run_sha256")
            valid_raw = valid_raw and str(api_run.get("id")) == str(row.get("run_id"))
            valid_raw = valid_raw and api_run.get("status") in ("queued", "in_progress") and api_run.get("conclusion") is None
            valid_raw = valid_raw and api_run.get("created_at") == row.get("created_at") and api_run.get("head_sha") == row.get("head_sha")
            valid_raw = valid_raw and api_run.get("event") == "pull_request" and api_run.get("path") == ".github/workflows/ci.yml"
            valid_raw = valid_raw and len(api_run.get("pull_requests") or []) == 1
            valid_raw = valid_raw and api_run["pull_requests"][0].get("head", {}).get("sha") == row.get("pull_request_head_sha")
            if contract.get("sample_identity") == "run_id+run_attempt":
                valid_raw = valid_raw and api_run.get("run_attempt") == row.get("run_attempt")
                valid_raw = valid_raw and (api_run.get("run_started_at") or api_run.get("queued_at")) == row.get("attempt_origin_at")
                valid_raw = valid_raw and bool(row.get("attempt_origin_at"))
        except (ValueError, TypeError, KeyError):
            valid_raw = False
        if not valid_raw:
            diagnostics.append("comparison_registration_api_response_invalid")
    window = contract.get("window") or {}
    if not window.get("start_utc") or not window.get("end_utc"):
        diagnostics.append("comparison_window_not_predeclared")
        return diagnostics
    try:
        start, end = _utc(window["start_utc"]), _utc(window["end_utc"])
        if end - start != __import__("datetime").timedelta(hours=48):
            diagnostics.append("comparison_window_duration_invalid")
    except (KeyError, TypeError, ValueError):
        diagnostics.append("comparison_window_invalid")
        return sorted(set(diagnostics))
    seen = set()
    for family in families:
        key = (family.get("pair_id"), family.get("family_role"))
        reservation = reserved.get(key)
        registration = registration_by_key.get((reservation or {}).get("reservation_id"))
        if reservation is None or registration is None or reservation.get("reservation_id") != registration.get("reservation_id"):
            diagnostics.append("comparison_family_run_not_reserved")
            continue
        if key in seen:
            diagnostics.append("comparison_family_reservation_duplicate")
        seen.add(key)
        attempt_scoped = contract.get("sample_identity") == "run_id+run_attempt"
        try:
            created = _utc(family.get("attempt_origin_at") if attempt_scoped else family.get("created_at"))
        except (TypeError, ValueError):
            diagnostics.append("comparison_family_created_at_invalid")
            continue
        run_attempt = family.get("run_attempt") if attempt_scoped else None
        run = runs.get((str(family.get("run_id")), run_attempt)) if attempt_scoped else next((value for (runid, _), value in runs.items() if runid == str(family.get("run_id"))), None)
        expected_sha = contract.get("baseline_application_sha") if family.get("family_role") == "before" else (contract.get("candidate_identity") or {}).get("application_sha")
        if (family.get("run_id") != registration.get("run_id")
                or family.get("pair_id") != registration.get("pair_id")
                or family.get("family_role") != registration.get("family_role")
                or (family.get("created_at") != registration.get("created_at"))
                or (attempt_scoped and (family.get("run_attempt") != registration.get("run_attempt") or family.get("attempt_origin_at") != registration.get("attempt_origin_at")))
                or not run or (not attempt_scoped and run.get("created_at") != family.get("created_at"))
                or (attempt_scoped and run.get("run_started_at") != family.get("attempt_origin_at") and run.get("queued_at") != family.get("attempt_origin_at"))
                or run.get("head_sha") != expected_sha or run.get("detail_status") != "complete"
                or registration.get("head_sha") != expected_sha or registration.get("pull_request_head_sha") != expected_sha
                or not re.fullmatch(r"[0-9a-f]{64}", registration.get("api_run_sha256") or "")):
            diagnostics.append("comparison_family_api_origin_mismatch")
        if not start <= created <= end:
            diagnostics.append("comparison_family_outside_frozen_window")
    if seen != set(reserved):
        diagnostics.append("comparison_family_reservation_incomplete")
    return sorted(set(diagnostics))


def _utc(value: str):
    import datetime
    if not isinstance(value, str):
        raise ValueError("comparison_timestamp_invalid")
    return datetime.datetime.fromisoformat(value.replace("Z", "+00:00"))


def select_failure_context(raw: bytes, expected_sha256: str, line_offset: int = 0) -> dict:
    """Choose the actual failure before sanitizing and applying a display cap."""
    digest = hashlib.sha256(raw).hexdigest()
    result = {'input_sha256': digest, 'source_line_start': None, 'source_line_end': None,
              'text': '', 'truncated': False, 'completeness': 'incomplete', 'missing_details': []}
    if digest != expected_sha256:
        result['missing_details'] = ['log_hash_mismatch']
        return result
    rows = raw.decode('utf-8', 'replace').splitlines()
    hits = []
    for index, row in enumerate(rows):
        content = re.sub(r'^\d{4}-\d\d-\d\dT\S+\s+', '', row).strip()
        if re.match(r'(?:PASS:|Test [A-Z][0-9]*:)', content):
            continue
        if re.search(r'(?:^|\s)FAIL:|AssertionError|##\[error\]|command not found|Error:.*(?:expect|timeout)|Test timeout.*exceeded', content):
            hits.append(index)
    if not hits:
        result['missing_details'] = ['failure_assertion_not_retained']
        return result
    # Each consumer gets a bounded, source-indexed context. The original input
    # digest remains visible, and omitted ranges never imply a complete log.
    start, end = max(0, hits[0] - 3), min(len(rows), hits[-1] + 4)
    report = sanitize_failure_log('\n'.join(rows[start:end]).encode())
    result.update(text=report['text'], source_line_start=start + 1 + line_offset,
                  source_line_end=end + line_offset, truncated=report['truncated'])
    if report['truncated'] or '[LOG EXCERPT TRUNCATED]' in report['text']:
        result.update(truncated=True, missing_details=['selected_context_truncated'])
    else:
        result['completeness'] = 'complete'
    return result


def diagnose_snapshot(bundle: pathlib.Path, archive: pathlib.Path, baseline: pathlib.Path) -> dict:
    """A companion, never a rewrite of the immutable metrics replay."""
    saved = json.loads(baseline.read_text())
    errors = verify_snapshot_hashes(bundle)
    if _digest(archive) != saved.get('source_bundle_sha256'):
        errors.append('source_bundle_hash_mismatch')
    result = {'schema_version': 'sigra.ci-diagnosis/v1',
              'source_bundle_sha256': _digest(archive), 'baseline_sha256': _digest(baseline),
              'source_errors': sorted(set(errors)), 'records': [],
              'acquisition': {'mode': 'offline_saved_archive', 'github_requests': 0,
                              'additional_requests_ceiling': 60, 'additional_seconds_ceiling': 900},
              'cause_claim': 'observations_only; no current flake or application cause proved'}
    if errors:
        result['status'] = 'incomplete'
        return result
    for selected in saved.get('failure_analysis', {}).get('families', []):
        run_id = str(selected['run']['id'])
        family = bundle / 'raw/families' / run_id
        if not (family / 'manifest.json').is_file():
            result['records'].append({'run_id': run_id, 'attempt': selected['run'].get('run_attempt'),
                'source_sha': selected['run'].get('head_sha'), 'event': selected.get('event'),
                'job_id': None, 'job_name': None, 'step_name': None, 'step_number': None,
                'original_native_outcome': selected['run'].get('conclusion'),
                'corrected_category': 'unknown_failure', 'completeness': 'incomplete',
                'missing_details': ['family_jobs_and_logs_not_retained'], 'cause_status': 'unproved'})
            continue
        facts = json.loads((family / 'manifest.json').read_text())
        run = json.loads((family / 'run.json').read_text())
        for attempt, ref in sorted(facts.get('attempt_jobs', {}).items()):
            jobs_path = bundle / ref['path']
            jobs = json.loads(jobs_path.read_text())['jobs']
            failed = [j for j in jobs if j.get('conclusion') in ('failure', 'timed_out', 'cancelled')]
            log_ref = next((d.get('result', {}) for d in facts.get('artifact_diagnostics', [])
                            if d.get('kind') == 'failed_job_log'), {})
            # The old collector retained exactly the FIRST failing job in the LAST
            # attempt. It did not retain a log for the rest. Never reuse that log.
            logged_job = next((j['id'] for j in jobs if j.get('conclusion') in ('failure', 'timed_out')), None)
            for job in failed:
                steps = [s for s in job.get('steps', []) if s.get('conclusion') in ('failure', 'timed_out', 'cancelled')]
                for step in steps or [{'name': None, 'number': None, 'conclusion': job.get('conclusion')}]:
                    record = {'run_id': run_id, 'attempt': int(attempt), 'source_sha': run['head_sha'],
                              'event': run['event'], 'job_id': job['id'], 'job_name': job['name'],
                              'step_name': step['name'], 'step_number': step['number'],
                              'original_native_outcome': step['conclusion'], 'original_job_outcome': job['conclusion'],
                              'jobs_sha256': _digest(jobs_path), 'log_sha256': None,
                              'corrected_category': 'unknown_failure', 'observed_test': None,
                              'observed_command_exit': None, 'completeness': 'incomplete',
                              'missing_details': [], 'cause_status': 'unproved'}
                    if str(attempt) != str(run['run_attempt']) or job['id'] != logged_job or not log_ref.get('sha256'):
                        record['missing_details'].append('producer_log_not_retained')
                    else:
                        try:
                            raw = verified_failure_log(bundle, log_ref.get('path'), log_ref.get('sha256'))
                            record['log_sha256'] = log_ref['sha256']
                            lines = raw.decode('utf-8', 'replace').splitlines()
                            relevant = []
                            start, end = _utc(step['started_at']), _utc(step['completed_at'])
                            for number, line in enumerate(lines, 1):
                                try:
                                    stamp = _utc(line.split(' ', 1)[0])
                                except (ValueError, IndexError):
                                    continue
                                # GitHub step bounds have whole-second precision;
                                # log timestamps have fractional seconds.
                                if start <= stamp and stamp.timestamp() < end.timestamp() + 1:
                                    relevant.append((number, line))
                            text = '\n'.join(line for _, line in relevant)
                            selected_bytes = text.encode()
                            record['selected_context'] = select_failure_context(selected_bytes,
                                hashlib.sha256(selected_bytes).hexdigest(), relevant[0][0] - 1 if relevant else 0)
                            # These are excerpts of the archived producer log, not
                            # a newly acquired complete log or a native report.
                            record['selected_context']['producer_input_sha256'] = log_ref['sha256']
                            record['missing_details'].extend(record['selected_context']['missing_details'])
                            exits = re.findall(r'Process completed with exit code (\d+)', text)
                            if exits:
                                record['observed_command_exit'] = int(exits[-1])
                            if (step['name'] == 'CI run metrics self-test'
                                    and re.search(r'FAIL: legacy timing bundle did not fail closed', text)
                                    and 'Test Z:' in text):
                                record.update(corrected_category='historical_metrics_dependency_failure',
                                              observed_test='Test Z', cause_status='observed_dependency_error')
                                record['rejected_signature_status'] = ('passing_test_d' if any(
                                    'PASS: Test D: lint of --add result exits 0 (round-trip valid)' in line for line in lines) else 'unknown')
                            if not exits:
                                record['missing_details'].append('native_command_exit_not_retained')
                            if not relevant:
                                record['missing_details'].append('selected_step_context_not_retained')
                            if '[LOG EXCERPT TRUNCATED]' in text:
                                record['missing_details'].append('selected_log_truncated')
                            record['completeness'] = 'incomplete' if record['missing_details'] else 'complete'
                        except (OSError, ValueError, KeyError) as exc:
                            record['missing_details'].append('log_or_step_identity_invalid:' + str(exc))
                    result['records'].append(record)
    result['status'] = 'incomplete' if any(r['completeness'] != 'complete' for r in result['records']) else 'complete'
    return result
