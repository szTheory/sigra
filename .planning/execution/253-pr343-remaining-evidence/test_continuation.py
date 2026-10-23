"""Offline-only continuation tests; all HTTP responses here are synthetic fixtures."""
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
import zipfile
import ast
from unittest.mock import patch

B = Path(__file__).resolve().parent
R = B / "runtime"
sys.path.insert(0, str(R))
import execution_guard as guard
import run


def load_transport():
    import types
    path = R / "ci-hosted-transport.py"
    module = types.ModuleType("test_transport_real")
    module.__file__ = str(path)
    exec(compile(path.read_bytes(), str(path), "exec"), module.__dict__)
    return module


class Response:
    def __init__(self, status, body=b"", headers=()):
        self.status, self.stream, self.headers = status, io.BytesIO(body), list(headers)
    def getheaders(self): return self.headers
    def read(self, size): return self.stream.read(size)


class Connection:
    sock = None
    def __init__(self, response, calls): self.response, self.calls = response, calls
    def request(self, method, path, body=None, headers=None): self.calls.append((method, path, dict(headers or {})))
    def getresponse(self): return self.response
    def close(self): pass


def allocation():
    value = json.loads((B / "allocation-template.json").read_text())
    value["source_sha256"] = hashlib.sha256((B / "pr-freeze.json").read_bytes()).hexdigest()
    return value


def load_verifier():
    import types
    path = R / "ci-hosted-gate-verify.py"
    value = types.ModuleType("test_actual_verifier"); value.__file__ = str(path)
    exec(compile(path.read_bytes(), str(path), "exec"), value.__dict__)
    return value


def artifact_request():
    spec = json.loads((B / "proposal.json").read_text())["browser_artifacts"][0]
    return {"method": "GET", "route_id": "artifact_zip", "category": "artifact_downloads", "family": "normal",
            "params": {"artifact_id": spec["id"]}}


class ContinuationTests(unittest.TestCase):
    def test_empty_workflow_listing_uses_exact_commit_check_hint(self):
        import base64
        p = json.loads((B / "proposal.json").read_text())
        head = p["docs_only_pr"]["head_sha"]
        def tx(route, body, family="docs-only", category="run_discovery"):
            return {"route_id":route,"family":family,"category":category,"actual_status":200,
                    "url":f"https://api.github.com/repos/szTheory/sigra/commits/{head}/check-runs?per_page=100&page=1",
                    "response_body_base64":base64.b64encode(json.dumps(body).encode()).decode()}
        check={"head_sha":head,"app":{"id":15368},"details_url":"https://github.com/szTheory/sigra/actions/runs/9901/job/71"}
        rows=[tx("workflow_runs",{"workflow_runs":[]}),tx("check_runs",{"total_count":1,"check_runs":[check]},"shared")]
        v=load_verifier()
        self.assertEqual(v.pr_discovery_ids(rows,"docs-only",head),{9901})
        for wrong in (dict(check,head_sha="0"*40),dict(check,app={"id":1}),dict(check,details_url="https://evil.example/actions/runs/9901/job/71")):
            changed=[rows[0],tx("check_runs",{"total_count":1,"check_runs":[wrong]},"shared")]
            self.assertEqual(v.pr_discovery_ids(changed,"docs-only",head),set())
        with self.assertRaises(v.VerificationError):
            v.pr_discovery_ids([tx("check_runs",{"total_count":2,"check_runs":[check]},"shared")],"docs-only",head)

    def test_actual_collector_uses_fallback_before_direct_terminal_poll(self):
        import base64, types
        python_source=(R/"ci-pr-proof.sh").read_text().split("<<'PYEOF'\n",1)[1].split("\nPYEOF",1)[0]
        ns={"__name__":"offline_collector_test"}
        with patch.dict("os.environ",{"SIGRA_PR_PROOF_ROOT":str(ROOT),"SIGRA_PR_PROOF_RUNTIME":str(R)}):
            exec(compile(python_source.rsplit("sys.exit(main())",1)[0],"ci-pr-proof.sh","exec"),ns)
        f=json.loads((B/"pr-freeze.json").read_text());spec=f["docs-only"]
        collector=object.__new__(ns["Collector"]);collector.family="docs-only";collector.freeze=f;collector.spec=spec
        collector.base_preflight=None;collector.docs_receipt_path=None;collector.notes=[];collector.downloads=[]
        collector.preflight=lambda:None;collector.publish_docs=lambda:None;collector.require_listed_pr=lambda body:None;collector.sleep=lambda:None
        rows=[];calls=[]
        collector.ledger=lambda:{"transactions":rows}
        def jcall(mode,route,category,*args,**kw):
            calls.append((route,category,kw))
            body={"pr_create":{"number":344},"workflow_runs":{"workflow_runs":[]},
                  "check_runs":{"total_count":1,"check_runs":[{"head_sha":spec["head_sha"],"app":{"id":15368},"details_url":"https://github.com/szTheory/sigra/actions/runs/9901/job/71"}]},
                  "run":{"id":9901,"run_attempt":1,"status":"completed"},
                  "pr_read":{"merge_commit_sha":"f"*40,"base":{"sha":spec["base_sha"]}},"run_artifacts":{"artifacts":[]}}.get(route,{})
            rows.append({"route_id":route,"category":category,"family":kw.get("family","docs-only"),"actual_status":200,
                         "url":f"https://api.github.com/repos/szTheory/sigra/commits/{spec['head_sha']}/check-runs?per_page=100&page=1",
                         "response_body_base64":base64.b64encode(json.dumps(body).encode()).decode()})
            return 201 if route=="pr_create" else 200,body
        collector.jcall=jcall
        answer=collector.collect()
        self.assertEqual(answer["id"],9901)
        discovery=[c for c in calls if c[1]=="run_discovery"]
        self.assertEqual([c[0] for c in discovery],["workflow_runs","check_runs"])
        self.assertEqual(next(c[2]["params"]["run_id"] for c in calls if c[0]=="run"),9901)

    def test_default_cli_is_offline_and_exact(self):
        proc = subprocess.run([sys.executable, str(B / "run.py")], capture_output=True, text=True)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        result = json.loads(proc.stdout)
        self.assertEqual(result["status"], "offline-ready")
        self.assertEqual(result["network_requests"], 0)
        self.assertEqual(len(result["artifacts_to_download"]), 5)
        self.assertEqual(result["normal_pr"]["run_id"], 39815188159)

    def test_run_refuses_without_committed_exact_proposal_approval_before_state_or_requests(self):
        proc = subprocess.run([sys.executable, str(B / "run.py"), "--run"], capture_output=True, text=True)
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("fresh exact proposal approval is missing", proc.stderr)
        for name in ("run-state.json", "allocation.json", "ledger.json", "attempt-result.json"):
            self.assertFalse((B / name).exists(), name)

    def test_ci_accounting_never_reports_false_zero_after_pr_creation(self):
        pr={"route_id":"pr_create","family":"docs-only","state":"complete","actual_status":201}
        self.assertEqual(run.ci_accounting([pr])["ci_launch_status"],"unknown_after_docs_pr_creation")
        listing={"route_id":"workflow_runs","family":"docs-only","state":"complete","actual_status":200,
                 "response_body_base64":__import__("base64").b64encode(b'{"workflow_runs":[{"id":9901}]}').decode()}
        answer=run.ci_accounting([pr,listing])
        self.assertEqual(answer["workflow_run_ids_discovered"],["9901"])
        self.assertEqual(answer["ci_launch_status"],"run_ids_discovered")
        self.assertEqual(run.ci_accounting([])["ci_launch_status"],"no_docs_pr_creation_recorded")

    def test_saved_metadata_rejects_wrong_attempt_head_or_digest(self):
        proposal = json.loads((B / "proposal.json").read_text())
        old = B.parent / "253-pr343-recovery" / "ledger.json"
        ledger = json.loads(old.read_text())
        import base64
        tx = next(row for row in ledger["transactions"] if row["route_id"] == "run_artifacts")
        metadata = json.loads(base64.b64decode(tx["response_body_base64"]))["artifacts"]
        run.check_artifact_metadata(proposal, metadata)
        for change in (
            lambda rows: rows[0]["workflow_run"].update(id=39815188160),
            lambda rows: rows[0]["workflow_run"].update(head_sha="0" * 40),
            lambda rows: rows[0].update(digest="sha256:" + "0" * 64),
        ):
            altered = json.loads(json.dumps(metadata))
            item = next(x for x in altered if x.get("id") == proposal["browser_artifacts"][0]["id"])
            change([item])
            with self.assertRaises(guard.Refusal):
                run.check_artifact_metadata(proposal, altered)

    def test_download_receipt_requires_exact_archive_hash_and_artifact_route(self):
        spec = json.loads((B / "proposal.json").read_text())["browser_artifacts"][0]
        archive = b"synthetic archive bytes"
        sha = hashlib.sha256(archive).hexdigest()
        receipt = {"actual_status": 200, "raw_observation_sha256": sha, "response_bytes": len(archive), "request_group": "fixture"}
        tx = [{"request_group": "fixture", "hop_ordinal": 0, "family": "normal", "route_id": "artifact_zip",
               "category": "artifact_downloads", "actual_status": 200,
               "url": f"https://api.github.com/repos/szTheory/sigra/actions/artifacts/{spec['id']}/zip"}]
        spec = dict(spec, digest="sha256:" + sha, size_in_bytes=len(archive))
        run.check_download_receipt(spec, archive, receipt, tx)
        for wrong in (dict(receipt, raw_observation_sha256="0" * 64), dict(receipt, actual_status=302)):
            with self.assertRaises(guard.Refusal): run.check_download_receipt(spec, archive, wrong, tx)
        wrong_route = [dict(tx[0], url=tx[0]["url"].replace(str(spec["id"]), "1"))]
        with self.assertRaises(guard.Refusal): run.check_download_receipt(spec, archive, receipt, wrong_route)

    def test_exact_proposal_approval_digest_and_scope_are_checked(self):
        with tempfile.TemporaryDirectory() as raw:
            d = Path(raw); p = json.loads((B / "proposal.json").read_text())
            proposal_path, approval_path = d / "proposal.json", d / "approval.json"
            proposal_path.write_text(json.dumps(p, sort_keys=True))
            now = int(time.time())
            approval = {"schema": "sigra.phase253.pr343-remaining-evidence-approval/v1", "decision": "approve",
                        "proposal_sha256": hashlib.sha256(proposal_path.read_bytes()).hexdigest(),
                        "scope": p["approval_required"]["scope"], "decision_text": "approve exact proposal",
                        "approved_at_epoch": now, "expires_epoch": now + 3600}
            approval_path.write_text(json.dumps(approval))
            with patch.object(guard, "PROPOSAL", proposal_path), patch.object(guard, "APPROVAL", approval_path), patch.object(guard, "committed"):
                guard.verify_approval()
                p["candidate_sha"] = "0" * 40
                proposal_path.write_text(json.dumps(p, sort_keys=True))
                with self.assertRaisesRegex(guard.Refusal, "does not bind"):
                    guard.verify_approval()

    def test_request_guard_rejects_wrong_family_dispatch_id_and_spent_downloads(self):
        proposal = json.loads((B / "proposal.json").read_text())
        allowed = artifact_request()
        with patch.object(guard, "verify_approval", return_value=(proposal, {})):
            guard.check_request(allowed, [])
            bad_id = json.loads(json.dumps(allowed)); bad_id["params"]["artifact_id"] = 12443120351
            with self.assertRaises(guard.Refusal): guard.check_request(bad_id, [])
            dispatch = {"method": "POST", "route_id": "dispatch", "category": "infrastructure_rerun", "family": "shared", "params": {}}
            with self.assertRaises(guard.Refusal): guard.check_request(dispatch, [])
            wrong_family = {"method": "GET", "route_id": "rules_main", "category": "preflight", "family": "normal", "params": {}}
            with self.assertRaises(guard.Refusal): guard.check_request(wrong_family, [])
            spent = [{"category": "artifact_downloads", "actual_status": 200} for _ in range(20)]
            with self.assertRaisesRegex(guard.Refusal, "ceiling exhausted"): guard.check_request(allowed, spent)

    def test_request_guard_allows_only_docs_artifacts_from_the_verified_docs_run_inventory(self):
        proposal = json.loads((B / "proposal.json").read_text())
        docs = proposal["docs_only_pr"]; number = 701; run_id = 998877; artifact_id = 443322; attempt = 1
        def row(route, body, status=200, url=""):
            return {"family": "docs-only", "route_id": route, "actual_status": status, "response_body_base64": __import__("base64").b64encode(json.dumps(body).encode()).decode(), "url": url}
        created = {"number": number, "draft": True}
        pr = {"number": number, "state": "open", "draft": True, "merged": False,
              "head": {"ref": docs["head_ref"], "sha": docs["head_sha"]},
              "base": {"ref": docs["base_ref"], "sha": docs["base_sha"]}}
        run_record = {"id": run_id, "workflow_id": 259268962, "event": "pull_request", "head_sha": docs["head_sha"],
                      "head_branch": docs["head_ref"], "status": "completed", "conclusion": "success", "run_attempt": attempt,
                      "pull_requests": [{"number": number, "head": {"sha": docs["head_sha"]}, "base": {"sha": docs["base_sha"]}}]}
        listing = {"artifacts": [{"id": artifact_id, "name": f"browser-execution-admin_behavior-{run_id}-{attempt}",
                                   "digest": "sha256:" + "a" * 64, "size_in_bytes": 100, "expired": False,
                                   "workflow_run": {"id": run_id, "head_sha": docs["head_sha"]}}]}
        rows = [row("pr_create", created, 201), row("pr_read", pr),
                row("workflow_runs", {"workflow_runs": [{"id": run_id, "event": "pull_request", "head_sha": docs["head_sha"]}]}),
                row("run", run_record), row("run_artifacts", listing, url=f"https://api.github.com/repos/szTheory/sigra/actions/runs/{run_id}/artifacts")]
        req = {"method": "GET", "route_id": "artifact_zip", "category": "artifact_downloads", "family": "docs-only",
               "params": {"artifact_id": artifact_id}}
        with patch.object(guard, "verify_approval", return_value=(proposal, {})):
            guard.check_request(req, rows)
            wrong = json.loads(json.dumps(req)); wrong["params"]["artifact_id"] = artifact_id + 1
            with self.assertRaises(guard.Refusal): guard.check_request(wrong, rows)
            rows[3]["response_body_base64"] = __import__("base64").b64encode(json.dumps(dict(run_record, conclusion="failure")).encode()).decode()
            with self.assertRaises(guard.Refusal): guard.check_request(req, rows)

    def test_real_transport_redirect_strips_github_authorization_on_blob_host(self):
        transport = load_transport()
        calls = []
        responses = [Response(302, headers=[("Location", "https://productionresultssa0.blob.core.windows.net/a?sig=fixture")]),
                     Response(200, b"synthetic-zip")]
        with tempfile.TemporaryDirectory() as raw:
            d = Path(raw)
            a, q, l, receipt, out = d / "allocation.json", d / "request.json", d / "ledger.json", d / "receipt.json", d / "out.zip"
            a.write_text(json.dumps(allocation()))
            q.write_text(json.dumps(artifact_request()))
            with patch.object(guard, "authorize_request", return_value=True), \
                 patch.object(transport, "_check_bound_documents"), patch.object(transport, "_preserve", return_value=None), \
                 patch.object(transport, "_connect", side_effect=lambda *args: Connection(responses.pop(0), calls)), \
                 patch.dict("os.environ", {"GH_TOKEN": "synthetic-github-token"}):
                received = transport.follow_download(a, l, q, receipt, out)
            self.assertEqual(received["actual_status"], 200)
            self.assertEqual(out.read_bytes(), b"synthetic-zip")
            self.assertEqual(len(calls), 2)
            self.assertEqual(calls[0][2].get("Authorization"), "Bearer synthetic-github-token")
            self.assertNotIn("Authorization", calls[1][2])

    def test_real_transport_403_and_429_are_one_request_terminal_stops(self):
        transport = load_transport()
        for status in (403, 429):
            with self.subTest(status=status), tempfile.TemporaryDirectory() as raw:
                d = Path(raw); a, q, l, out = d / "allocation.json", d / "request.json", d / "ledger.json", d / "receipt.json"
                a.write_text(json.dumps(allocation())); q.write_text(json.dumps(artifact_request())); calls = []
                with patch.object(guard, "authorize_request", return_value=True), \
                     patch.object(transport, "_check_bound_documents"), patch.object(transport, "_preserve", return_value=None), \
                     patch.object(transport, "_connect", side_effect=lambda *args: (calls.append(1) or Connection(Response(status, b"{}"), []))), \
                     patch.dict("os.environ", {"GH_TOKEN": "synthetic-github-token"}):
                    with self.assertRaises(transport.TransportError):
                        transport.request_one(a, l, q, out)
                    self.assertEqual(len(calls), 1)
                    self.assertEqual(json.loads(l.read_text())["terminal_stop"]["code"], f"http_{status}")
                    with self.assertRaises(transport.TransportError):
                        transport.request_one(a, l, q, out)
                    self.assertEqual(len(calls), 1)

    def test_rate_limit_body_at_250_stops_even_when_headers_are_absent(self):
        transport = load_transport()
        with tempfile.TemporaryDirectory() as raw:
            d = Path(raw); a, q, l, out = d / "allocation.json", d / "request.json", d / "ledger.json", d / "receipt.json"
            a.write_text(json.dumps(allocation()))
            q.write_text(json.dumps({"method": "GET", "route_id": "rate_limit", "category": "preflight", "family": "shared", "params": {}}))
            response = Response(200, b'{"resources":{"core":{"remaining":250}}}')
            with patch.object(guard, "authorize_request", return_value=True), \
                 patch.object(transport, "_check_bound_documents"), patch.object(transport, "_preserve", return_value=None), \
                 patch.object(transport, "_connect", return_value=Connection(response, [])), \
                 patch.dict("os.environ", {"GH_TOKEN": "synthetic-github-token"}):
                with self.assertRaises(transport.TransportError) as caught:
                    transport.request_one(a, l, q, out)
            self.assertEqual(caught.exception.code, "core_budget_stop")
            ledger = json.loads(l.read_text())
            self.assertEqual(len(ledger["transactions"]), 1)
            self.assertEqual(ledger["terminal_stop"]["code"], "core_budget_stop")

    def test_real_transport_request_ceiling_predebits_and_never_connects(self):
        transport = load_transport()
        with tempfile.TemporaryDirectory() as raw:
            d = Path(raw); a, q, l, out = d / "allocation.json", d / "request.json", d / "ledger.json", d / "receipt.json"
            alloc = allocation(); a.write_text(json.dumps(alloc)); q.write_text(json.dumps(artifact_request()))
            rows = [{"sequence": n, "category": "preflight", "state": "complete", "actual_status": 200, "error": None} for n in range(1, 121)]
            l.write_text(json.dumps({"schema_version": transport.SCHEMA, "window_id": alloc["window_id"],
                "allocation_sha256": hashlib.sha256(a.read_bytes()).hexdigest(), "source_sha256": alloc["source_sha256"],
                "transactions": rows, "terminal_stop": None, "preserved_revisions": []}))
            with patch.object(guard, "authorize_request", return_value=True), patch.object(transport, "_check_bound_documents"), \
                 patch.object(transport, "_connect", side_effect=AssertionError("network connector must not run")):
                with self.assertRaises(transport.TransportError) as caught:
                    transport.request_one(a, l, q, out)
            self.assertEqual(caught.exception.code, "request_budget_exhausted")
            self.assertEqual(json.loads(l.read_text())["terminal_stop"]["code"], "request_budget_exhausted")

    def test_existing_independent_verifier_rejects_failed_docs_gate(self):
        import types
        verifier_path = R / "ci-hosted-gate-verify.py"
        v = types.ModuleType("docs_gate_verifier"); v.__file__ = str(verifier_path)
        exec(compile(verifier_path.read_bytes(), str(verifier_path), "exec"), v.__dict__)
        evidence_path = B.parent / "253-docs-continuation-pr341-fixed" / "docs-only-evidence.json"
        with self.assertRaises(v.VerificationError):
            v.verify_pr_family(json.loads(evidence_path.read_text()), "docs-only")


    def test_aggregate_proposal_cap_and_exact_docs_write_bodies(self):
        proposal = json.loads((B / "proposal.json").read_text())
        freeze = json.loads((B / "pr-freeze.json").read_text())["docs-only"]
        pub = freeze["publication"]
        def request(route, body):
            return {"method":"POST","route_id":route,"category":"docs_publication","family":"docs-only","params":{},"body":body}
        with patch.object(guard, "verify_approval", return_value=(proposal, {})):
            rows = [{"category":"preflight","actual_status":200} for _ in range(70)]
            with self.assertRaisesRegex(guard.Refusal, "aggregate proposal"):
                guard.check_request(artifact_request(), rows)
            tree_body = {"base_tree":pub["candidate_tree"],"tree":[{"path":".github/workflows/ci.yml","mode":"100644","type":"blob","content":(B/"docs-workflow.yml").read_text()}]}
            guard.check_request(request("git_create_tree", tree_body), [])
            bad = json.loads(json.dumps(tree_body)); bad["tree"][0]["path"] = "unapproved.yml"
            with self.assertRaisesRegex(guard.Refusal, "exact source bytes"):
                guard.check_request(request("git_create_tree", bad), [])
            author={"name":"Sigra Publication Bot","email":"sigra-publication@users.noreply.github.com","date":pub["date_utc_second"]}
            prefix=[{"family":"docs-only","category":"docs_publication","route_id":"git_create_tree","actual_status":201}]
            commit_body={"message":"Phase 253 docs probe base workflow exception\n","tree":pub["docs_base_tree"],
                "parents":[pub["candidate_sha"]],"author":author,"committer":author}
            guard.check_request(request("git_create_commit",commit_body),prefix)
            wrong_commit=json.loads(json.dumps(commit_body));wrong_commit["parents"]=["0"*40]
            with self.assertRaisesRegex(guard.Refusal,"frozen source commit"):
                guard.check_request(request("git_create_commit",wrong_commit),prefix)
            stage_prefix = [{"family":"docs-only","category":"docs_publication","route_id":route,"actual_status":200}
                            for route in ("git_create_tree","git_create_commit","git_get_commit","git_get_blob","get_ref")]
            guard.check_request(request("create_ref", {"ref":"refs/heads/"+freeze["base_ref"],"sha":freeze["base_sha"]}), stage_prefix)
            with self.assertRaisesRegex(guard.Refusal, "exact frozen docs ref"):
                guard.check_request(request("create_ref", {"ref":"refs/heads/other","sha":freeze["base_sha"]}), stage_prefix)

    def test_actual_approved_section_reads_exact_final_proposal_and_action_section(self):
        source = (R / "ci-pr-proof.sh").read_text()
        marker = "# ---------------------------------------------------------------------------------- section approval\n"
        python_source = source.split("<<'PYEOF'\n",1)[1].split("\nPYEOF",1)[0]
        tree = ast.parse(python_source)
        function = next(node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name == "approved_section")
        namespace = {"Path":Path,"os":__import__("os"),"json":json,"sha256":lambda raw:hashlib.sha256(raw).hexdigest(),"ROOT":ROOT}
        exec(compile(ast.Module(body=[function],type_ignores=[]),"ci-pr-proof.sh#approved_section","exec"),namespace)
        with tempfile.TemporaryDirectory(dir=B) as raw:
            scoped = Path(raw); runtime = scoped / "runtime"; runtime.mkdir()
            for name in ("proposal.json","actions.json"):
                (scoped/name).write_bytes((B/name).read_bytes())
            proposal = json.loads((scoped/"proposal.json").read_text()); now = int(time.time())
            approval = {"schema":"sigra.phase253.pr343-remaining-evidence-approval/v1","decision":"approve",
                "proposal_sha256":hashlib.sha256((scoped/"proposal.json").read_bytes()).hexdigest(),
                "scope":proposal["approval_required"]["scope"],"decision_text":"approve exact proposal",
                "approved_at_epoch":now,"expires_epoch":now+3600}
            approval_path = scoped/"approval.json"; approval_path.write_text(json.dumps(approval))
            args = type("Args",(),{"revision_freeze":"exact","action_approval":str(approval_path)})()
            with patch.dict("os.environ",{"SIGRA_PR_PROOF_RUNTIME":str(runtime)}):
                section, record, ref = namespace["approved_section"](args)
            self.assertEqual(record["section"],"docs_and_prs")
            self.assertEqual(record["section_sha256"],proposal["source_freeze"]["docs_and_prs_section_sha256"])
            self.assertEqual(ref,"refs/heads/"+proposal["normal_candidate_ref"])
            approval["proposal_sha256"]="0"*64; approval_path.write_text(json.dumps(approval))
            with patch.dict("os.environ",{"SIGRA_PR_PROOF_RUNTIME":str(runtime)}), self.assertRaisesRegex(SystemExit,"does not authorize"):
                namespace["approved_section"](args)

    def test_synthetic_normal_archives_pass_actual_archive_and_browser_policy_verifiers(self):
        verifier = load_verifier()
        with tempfile.TemporaryDirectory(prefix="pr343-synthetic-policy-") as raw:
            root = Path(raw); dirs = root/"producers"; dirs.mkdir()
            generated = subprocess.run(["node",str(R/"synthetic_browser_archives.mjs"),str(dirs),str(B/"normal-workflow.yml")],
                                       capture_output=True,text=True,check=False)
            self.assertEqual(generated.returncode,0,generated.stderr)
            producers = {}
            for directory in sorted(dirs.iterdir()):
                archive_path = root/(directory.name+".zip")
                with zipfile.ZipFile(archive_path,"w",compression=zipfile.ZIP_DEFLATED) as bundle:
                    for member in sorted(directory.iterdir()): bundle.write(member,member.name)
                members = verifier.validate_producer_zip(archive_path.read_bytes())
                record = json.loads(members["execution-record.json"])
                self.assertEqual(record["run_id"],"39815188159")
                producers[directory.name] = members
            expected = {"run_id":"39815188159","run_attempt":"1","source_sha":"d6024255ed139f7c19bd44e68c10a85cc9ecca3b",
                "event":"pull_request","workflow_ref":"szTheory/sigra/.github/workflows/ci.yml@refs/pull/343/merge",
                "workflow_sha":"d6024255ed139f7c19bd44e68c10a85cc9ecca3b","classifier_result":"success","docs_only":"false"}
            result = verifier._run_browser_policy((B/"normal-workflow.yml").read_bytes(),producers,expected)
            self.assertEqual(result["status"],"passed")
            first = next(iter(producers.values())); altered = dict(first); altered["execution-record.json"] = b"{}"
            with self.assertRaises(verifier.VerificationError): verifier.validate_producer_zip(b"not a zip")


    def test_approved_activate_runs_synthetic_download_policy_collector_and_verifier_path(self):
        # Synthetic transport and approval exercise the real activate control flow only; no hosted state is accepted.
        actual_verifier = load_verifier()
        real_module_loader = run.module
        with tempfile.TemporaryDirectory(prefix="pr343-approved-activate-fixture-") as raw:
            scoped = Path(raw); runtime = scoped/"runtime"; runtime.mkdir()
            for path in B.iterdir():
                if path.is_file(): (scoped/path.name).write_bytes(path.read_bytes())
                elif path.is_dir() and path.name == "runtime":
                    import shutil; shutil.copytree(path,runtime,dirs_exist_ok=True)
            expected_files = scoped/"synthetic-producers"; expected_files.mkdir()
            gen = subprocess.run(["node",str(R/"synthetic_browser_archives.mjs"),str(expected_files),str(B/"normal-workflow.yml")],
                                 capture_output=True,text=True,check=False)
            self.assertEqual(gen.returncode,0,gen.stderr)
            archive_by_name = {}
            for directory in sorted(expected_files.iterdir()):
                buf=io.BytesIO()
                with zipfile.ZipFile(buf,"w",compression=zipfile.ZIP_DEFLATED) as z:
                    for member in sorted(directory.iterdir()): z.writestr(member.name,member.read_bytes())
                archive_by_name[directory.name]=buf.getvalue()
            p = json.loads((scoped/"proposal.json").read_text())
            archives=[archive_by_name[x["name"]] for x in p["browser_artifacts"]]
            for spec, archive in zip(p["browser_artifacts"],archives):
                spec["digest"]="sha256:"+hashlib.sha256(archive).hexdigest(); spec["size_in_bytes"]=len(archive)
            (scoped/"proposal.json").write_text(json.dumps(p,sort_keys=True,indent=2)+"\n")
            now=int(time.time()); approval={"schema":"sigra.phase253.pr343-remaining-evidence-approval/v1","decision":"approve",
                "proposal_sha256":hashlib.sha256((scoped/"proposal.json").read_bytes()).hexdigest(),"scope":p["approval_required"]["scope"],
                "decision_text":"synthetic test fixture approval only","approved_at_epoch":now,"expires_epoch":now+3600}
            (scoped/"approval.json").write_text(json.dumps(approval))
            (scoped/"allocation-template.json").write_text((B/"allocation-template.json").read_text())
            transactions=[]; archive_iter=iter(archives)
            class FakeTransport:
                def preservation_preflight(self, path): return None
                def request_one(self, allocation_path, ledger_path, request_path, receipt_path, body_path):
                    req=json.loads(Path(request_path).read_text()); raw_body=b'{"resources":{"core":{"remaining":500}}}'
                    row={"sequence":len(transactions)+1,"request_group":"fixture-rate","hop_ordinal":0,"route_id":req["route_id"],
                         "family":req["family"],"category":req["category"],"url":"https://api.github.com/rate_limit","state":"complete",
                         "actual_status":200,"error":None,"response_body_base64":__import__("base64").b64encode(raw_body).decode()}
                    transactions.append(row); Path(ledger_path).write_text(json.dumps({"transactions":transactions}))
                    receipt={"actual_status":200,"error":None}; Path(receipt_path).write_text(json.dumps(receipt)); Path(body_path).write_bytes(raw_body)
                    return receipt,None,raw_body,None
                def follow_download(self, allocation_path, ledger_path, request_path, receipt_path, archive_path):
                    req=json.loads(Path(request_path).read_text()); spec_id=req["params"]["artifact_id"]
                    spec=next(x for x in p["browser_artifacts"] if x["id"]==spec_id); archive=next(archive_iter)
                    group=f"fixture-{spec_id}"; Path(archive_path).write_bytes(archive)
                    row={"sequence":len(transactions)+1,"request_group":group,"hop_ordinal":0,"route_id":"artifact_zip","family":"normal",
                         "category":"artifact_downloads","url":f"https://api.github.com/repos/szTheory/sigra/actions/artifacts/{spec_id}/zip",
                         "state":"complete","actual_status":200,"error":None}
                    transactions.append(row); Path(ledger_path).write_text(json.dumps({"transactions":transactions}))
                    rec={"actual_status":200,"raw_observation_sha256":hashlib.sha256(archive).hexdigest(),"response_bytes":len(archive),"request_group":group}
                    Path(receipt_path).write_text(json.dumps(rec)); return rec
            fake_transport=FakeTransport()
            def module_loader(path,name):
                if name == "remaining_transport": return fake_transport
                if name == "remaining_independent_verifier": return actual_verifier
                if name == "remaining_docs_pair_verifier":
                    class SyntheticDocsVerifier:
                        def verify_pr_family(self,evidence,family,captured):
                            self.assertion = evidence.get("synthetic_test_only") is True and family == "docs-only"
                            if not self.assertion: raise AssertionError("synthetic docs fixture missing marker")
                            captured["workflow_bytes"]=(scoped/"docs-workflow.yml").read_bytes()
                        verify_docs_workflow_relation=staticmethod(actual_verifier.verify_docs_workflow_relation)
                    return SyntheticDocsVerifier()
                return real_module_loader(path,name)
            def subprocess_fixture(command,**kwargs):
                if command[0] == "bash" and "--family" in command:
                    (scoped/"docs-only-evidence.json").write_text(json.dumps({"synthetic_test_only":True}))
                    return subprocess.CompletedProcess(command,0,"synthetic collector fixture","" )
                if str(command[1]).endswith("ci-hosted-gate-verify.py"):
                    return subprocess.CompletedProcess(command,0,'{"status":"synthetic fixture accepted"}','')
                return real_subprocess_run(command,**kwargs)
            real_subprocess_run=subprocess.run
            guard_patches=[patch.object(guard,name,value) for name,value in (("B",scoped),("ROOT",ROOT),("PROPOSAL",scoped/"proposal.json"),
                ("APPROVAL",scoped/"approval.json"),("ALLOCATION",scoped/"allocation.json"),("LEDGER",scoped/"ledger.json"),
                ("committed",lambda path:None))]
            with patch.object(run,"B",scoped),patch.object(run,"R",runtime),patch.object(run,"offline",return_value={"status":"synthetic offline preflight"}),                 patch.object(run,"verify_manifest",return_value={}),patch.object(run,"module",side_effect=module_loader),patch.object(run.subprocess,"run",side_effect=subprocess_fixture):
                for patcher in guard_patches: patcher.start()
                try: run.activate()
                finally:
                    for patcher in reversed(guard_patches): patcher.stop()
            state=json.loads((scoped/"run-state.json").read_text())
            policy=json.loads((scoped/"browser-policy-result.json").read_text())
            self.assertEqual(state["status"],"collected-and-independently-verified")
            self.assertTrue(state["closed"])
            self.assertEqual(policy["policy_result"]["status"],"passed")
            self.assertTrue(json.loads((scoped/"docs-only-evidence.json").read_text())["synthetic_test_only"])
            result=json.loads((scoped/"attempt-result.json").read_text())
            self.assertEqual(result["docs_pr_creation_count"],0)
            self.assertEqual(result["ci_launch_status"],"no_docs_pr_creation_recorded")

    def test_existing_browser_record_policy_suite_uses_synthetic_positive_and_negative_fixtures(self):
        proc = subprocess.run(["node", "--test", str(ROOT / "scripts/ci/ci-browser-records.test.mjs")],
                              cwd=ROOT, capture_output=True, text=True, check=False)
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        self.assertIn("pass", proc.stdout)


ROOT = next(p for p in B.parents if (p / ".git").exists())

if __name__ == "__main__":
    unittest.main(verbosity=2)
