#!/usr/bin/env python3
"""Local Git object publication contracts; no GitHub access is used."""

import base64
import hashlib
import http.server
import json
import os
import pathlib
import ssl
import subprocess
import sys
import tempfile
import threading
import time
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]
PUBLISHER = ROOT / "scripts/ci/ci-git-publication.py"
TRANSPORT = ROOT / "scripts/ci/ci-hosted-transport.py"


def object_sha(kind, data):
    return hashlib.sha1(f"{kind} {len(data)}\0".encode() + data).hexdigest()


PHASE_REL = ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks"
HELPER_COPIES = ("scripts/ci/ci-gate-canary.sh", "scripts/ci/ci-git-publication.py", "scripts/ci/ci-hosted-gate-verify.py",
                 "scripts/ci/ci-hosted-transport.py", "scripts/ci/ci-pr-proof.sh", "scripts/ci/ci-browser-records.mjs",
                 "scripts/ci/honest-skip-verdict.sh")
HELPER_DUMMIES = ("scripts/ci/ci-gate-canary.test.sh", "scripts/ci/ci-git-publication.test.py",
                  "scripts/ci/ci-hosted-gate-verify.test.py", "scripts/ci/ci-pr-proof.test.sh")
FIXTURE_TEXT = "name: Phase 253 Gate Canary\non:\n  workflow_dispatch:\n    inputs: {}\npermissions:\n  contents: read\njobs: {}\n"


def git_fixture(root, oversized=False, many_entries=0, helpers=False):
    root.mkdir()
    subprocess.run(["git", "init", "-q", str(root)], check=True)
    subprocess.run(["git", "-C", str(root), "config", "user.name", "Fixture"], check=True)
    subprocess.run(["git", "-C", str(root), "config", "user.email", "fixture@example.test"], check=True)
    (root / ".github/workflows").mkdir(parents=True)
    (root / ".github/workflows/ci.yml").write_text("name: CI\non:\n  pull_request:\n    branches: [main]\n")
    (root / "app.txt").write_text("base\n")
    tool = root / "tool.sh"
    tool.write_text("#!/bin/sh\necho ready\n")
    tool.chmod(0o755)
    subprocess.run(["git", "-C", str(root), "add", "."], check=True)
    subprocess.run(["git", "-C", str(root), "commit", "-qm", "parent"], check=True)
    parent = subprocess.check_output(["git", "-C", str(root), "rev-parse", "HEAD"], text=True).strip()
    (root / "app.txt").write_text("UTF-8 Δ\nterminal newline retained\n" + (("x" * (3 * 1024 * 1024)) if oversized else ""))
    (root / "binary.dat").write_bytes(b"\x00\xff\x10binary\n")
    for index in range(many_entries):
        path = root / "bulk" / f"file-{index:04d}.txt"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text((f"file {index:04d} Δ\n" + "x" * 30000 + "\n") * 1)
    paths = ["app.txt", "binary.dat", "tool.sh"] + (["bulk"] if many_entries else [])
    if helpers:
        for rel in HELPER_COPIES:
            target = root / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes((ROOT / rel).read_bytes())
            target.chmod(0o755 if rel.endswith((".sh", ".py")) else 0o644)
        for rel in HELPER_DUMMIES:
            (root / rel).write_text(f"# placeholder for {rel}\n")
        phase = root / PHASE_REL
        phase.mkdir(parents=True)
        (phase / "253-LOAD-RECOVERY-CANARY-WORKFLOW.yml").write_text(FIXTURE_TEXT)
        (phase / "253-PREHOST-REVIEW.md").write_text("# review\n")
        for name in ("ACCEPTANCE-EVIDENCE", "TARGET-DISPOSITION", "TARGET-DISPOSITION-APPROVAL"):
            (phase / f"253-LOAD-RECOVERY-{name}.json").write_text(json.dumps({"fixture": name}) + "\n")
        paths += ["scripts", ".planning"]
    subprocess.run(["git", "-C", str(root), "add", *paths], check=True)
    subprocess.run(["git", "-C", str(root), "commit", "-qm", "candidate"], check=True)
    source = subprocess.check_output(["git", "-C", str(root), "rev-parse", "HEAD"], text=True).strip()
    return parent, source


def seed_server(server, repo, parent):
    server.git_dir = str(repo.parent / "server.git")
    subprocess.run(["git", "init", "--bare", "-q", server.git_dir], check=True)
    object_rows = subprocess.check_output(["git", "-C", str(repo), "rev-list", "--objects", parent], text=True).splitlines()
    object_kinds = {}
    for row in object_rows:
        sha = row.split(" ", 1)[0]
        kind = subprocess.check_output(["git", "-C", str(repo), "cat-file", "-t", sha], text=True).strip()
        data = subprocess.check_output(["git", "-C", str(repo), "cat-file", kind, sha])
        stored = server.git("hash-object", "-w", "-t", kind, "--stdin", data=data).decode().strip()
        if stored != sha:
            raise AssertionError("server seed object identity differs")
        object_kinds[sha] = kind
        if kind == "blob":
            server.blobs[sha] = {"sha": sha, "content": base64.b64encode(data).decode(), "size": len(data)}
    for sha, kind in object_kinds.items():
        if kind == "tree":
            flattened = subprocess.check_output(["git", f"--git-dir={server.git_dir}", "ls-tree", "-rz", "-r", sha])
            values = {}
            for entry in flattened.split(b"\0"):
                if entry:
                    meta, name = entry.split(b"\t", 1)
                    mode, typ, blob = meta.decode().split()
                    values[name.decode()] = {"path": name.decode(), "mode": mode, "type": typ, "sha": blob}
            server.tree_entries[sha] = values
            server.trees[sha] = {"sha": sha, "tree": list(values.values()), "truncated": False}
    for sha in subprocess.check_output(["git", "-C", str(repo), "rev-list", parent], text=True).splitlines():
        raw = subprocess.check_output(["git", "-C", str(repo), "cat-file", "commit", sha])
        head, message = raw.split(b"\n\n", 1)
        lines = head.decode().splitlines()
        tree = next(line.split()[1] for line in lines if line.startswith("tree "))
        parents = [line.split()[1] for line in lines if line.startswith("parent ")]
        server.commits[sha] = {"sha": sha, "tree": {"sha": tree}, "parents": [{"sha": p} for p in parents],
                               "message": message.decode(), "author": {}, "committer": {}}


def parse_local_tree(repo, commit):
    result = {}
    raw = subprocess.check_output(["git", "-C", str(repo), "ls-tree", "-rz", "-r", commit])
    for row in raw.split(b"\0"):
        if row:
            meta, path = row.split(b"\t", 1)
            mode, kind, sha = meta.decode().split()
            result[path.decode()] = {"path": path.decode(), "mode": mode, "type": kind, "sha": sha}
    return result


class ObjectServer(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def _reply(self, status, value):
        body = json.dumps(value, ensure_ascii=False, separators=(",", ":")).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("X-GitHub-Request-Id", "local-object-fixture")
        self.end_headers()
        self.wfile.write(body)
        self.server.journal.append({"method": self.command, "path": self.path, "status": status,
                                    "charged": self.server.ledger_pending(),
                                    "request_body_sha256": hashlib.sha256(self.server.last_body).hexdigest() if self.server.last_body else None,
                                    "request_body_bytes": len(self.server.last_body)})

    def _read(self):
        self.server.last_body = self.rfile.read(int(self.headers.get("Content-Length", "0")))
        return json.loads(self.server.last_body or b"{}")

    def _first(self):
        hook = getattr(self.server, "first_hook", None)
        if hook:
            self.server.first_hook = None
            hook()

    def do_GET(self):  # noqa: N802
        self._first()
        self.server.last_body = b""
        prefix = "/repos/szTheory/sigra/git/"
        if self.path.startswith(prefix + "commits/"):
            sha = self.path.removeprefix(prefix + "commits/")
            value = self.server.commits.get(sha)
            if value and self.server.flags.get("alter_commit_readback") and sha != self.server.parent_sha:
                value = dict(value, message="tampered message\n")
                self.server.flags["alter_commit_readback"] = False
            self._reply(200, value) if value else self._reply(404, {"message": "Not Found"})
            return
        if self.path.startswith(prefix + "blobs/"):
            sha = self.path.removeprefix(prefix + "blobs/")
            value = self.server.blobs.get(sha)
            self._reply(200, value) if value else self._reply(404, {"message": "Not Found"})
            return
        if self.path.startswith(prefix + "trees/"):
            sha = self.path.removeprefix(prefix + "trees/")
            value = self.server.trees.get(sha)
            self._reply(200, value) if value else self._reply(404, {"message": "Not Found"})
            return
        if self.path.startswith("/repos/szTheory/sigra/git/ref/heads/"):
            name = self.path.removeprefix("/repos/szTheory/sigra/git/ref/heads/")
            sha = self.server.refs.get(name)
            if sha and self.server.flags.get("lose_ref_readback"):
                self.server.flags["lose_ref_readback"] = False
                self._reply(404, {"message": "Not Found"})
                return
            self._reply(200, {"ref": "refs/heads/" + name, "object": {"sha": sha}}) if sha else self._reply(404, {"message": "Not Found"})
            return
        self._reply(404, {"message": "Not Found"})

    def do_POST(self):  # noqa: N802
        self._first()
        value = self._read()
        prefix = "/repos/szTheory/sigra/git/"
        if self.path == prefix + "blobs":
            data = value.get("content", "").encode("utf-8") if value.get("encoding") == "utf-8" else base64.b64decode(value.get("content", ""), validate=True)
            sha = object_sha("blob", data)
            stored = self.server.git("hash-object", "-w", "--stdin", data=data).decode().strip()
            if stored != sha:
                self._reply(422, {"message": "blob SHA mismatch"})
                return
            self.server.blobs[sha] = {"sha": sha, "content": base64.b64encode(data).decode(), "size": len(data)}
            self._reply(201, self.server.blobs[sha])
            return
        if self.path == prefix + "trees":
            base = value.get("base_tree")
            entries = dict(self.server.tree_entries.get(base, {}))
            for item in value.get("tree", []):
                path = item["path"]
                if item.get("sha") is None and "content" not in item:
                    entries.pop(path, None)
                    continue
                data = item["content"].encode("utf-8") if "content" in item else None
                sha = object_sha("blob", data) if data is not None else item.get("sha")
                if data is not None:
                    stored = self.server.git("hash-object", "-w", "--stdin", data=data).decode().strip()
                    if stored != sha:
                        self._reply(422, {"message": "inline blob SHA mismatch"})
                        return
                    self.server.blobs[sha] = {"sha": sha, "content": base64.b64encode(data).decode(), "size": len(data)}
                if sha not in self.server.blobs:
                    self._reply(422, {"message": "tree references unknown blob"})
                    return
                entries[path] = {"path": path, "mode": item["mode"], "type": "blob", "sha": sha}
            sha = self.server.write_tree(entries)
            self.server.tree_entries[sha] = entries
            self.server.trees[sha] = {"sha": sha, "tree": list(entries.values()), "truncated": False}
            response = dict(self.server.trees[sha])
            if self.server.flags.get("alter_tree_sha"):
                response["sha"] = "f" * 40
                self.server.flags["alter_tree_sha"] = False
            self._reply(201, response)
            return
        if self.path == prefix + "commits":
            tree = value.get("tree")
            parents = list(value.get("parents", []))
            if tree not in self.server.trees or any(parent not in self.server.commits for parent in parents):
                self._reply(422, {"message": "commit references unknown object"})
                return
            author, committer = value["author"], value["committer"]
            def ident(item):
                from datetime import datetime, timezone
                epoch = int(datetime.strptime(item["date"], "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc).timestamp())
                return f"{item['name']} <{item['email']}> {epoch} +0000"
            raw = f"tree {tree}\n" + "".join(f"parent {parent}\n" for parent in parents)
            raw += f"author {ident(author)}\ncommitter {ident(committer)}\n\n{value['message']}"
            sha = self.server.git("hash-object", "-w", "-t", "commit", "--stdin", data=raw.encode()).decode().strip()
            result = {"sha": sha, "tree": {"sha": tree}, "parents": [{"sha": p} for p in parents],
                      "message": value["message"], "author": author, "committer": committer}
            self.server.commits[sha] = result
            self._reply(201, result)
            return
        if self.path == prefix + "refs":
            ref = value.get("ref", "")
            sha = value.get("sha")
            name = ref.removeprefix("refs/heads/")
            if not ref.startswith("refs/heads/gsd/253-replan-") or sha not in self.server.commits:
                self._reply(422, {"message": "invalid ref or unknown commit"})
                return
            if self.server.flags.get("race_create"):
                self.server.refs[name] = self.server.parent_sha
                self.server.flags["race_create"] = False
                self._reply(422, {"message": "reference already exists"})
                return
            if name in self.server.refs:
                self._reply(422, {"message": "reference already exists"})
                return
            self.server.refs[name] = sha
            self._reply(201, {"ref": ref, "object": {"sha": sha}})
            return
        self._reply(404, {"message": "Not Found"})

    def server_git(self, *args, data=None):
        return self.server.git(*args, data=data)

    def log_message(self, *_args):
        pass


class ObjectHTTPServer(http.server.ThreadingHTTPServer):
    def git(self, *args, data=None):
        return subprocess.check_output(["git", f"--git-dir={self.git_dir}", *args], input=data)

    def ledger_pending(self):
        if not pathlib.Path(self.ledger_path).exists():
            return False
        ledger = json.loads(pathlib.Path(self.ledger_path).read_text())
        return bool(ledger.get("transactions") and ledger["transactions"][-1]["state"] == "pending")

    def write_tree(self, entries):
        def build(prefix):
            direct, directories = {}, set()
            for path, entry in entries.items():
                if path.startswith(prefix):
                    remainder = path[len(prefix):]
                    if "/" in remainder:
                        directories.add(remainder.split("/", 1)[0])
                    else:
                        direct[remainder] = entry
            rows = [f"{e['mode']} blob {e['sha']}\t{name}\0".encode() for name, e in direct.items()]
            for name in directories:
                sha = build(prefix + name + "/")
                rows.append(f"040000 tree {sha}\t{name}\0".encode())
            return self.git("mktree", "-z", data=b"".join(rows)).decode().strip()
        return build("")


class PublicationTests(unittest.TestCase):
    def transport_module(self):
        import importlib.util
        spec = importlib.util.spec_from_file_location("hosted_transport", TRANSPORT)
        transport = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(transport)
        return transport

    def test_prepare_reports_complete_product_tree_request_that_exceeds_hard_body_limit(self):
        with tempfile.TemporaryDirectory(prefix="sigra-publication-proposal-") as temp:
            temp_path = pathlib.Path(temp)
            repo = temp_path / "repo"
            parent, source = git_fixture(repo, oversized=True)
            output = temp_path / "proposal.json"
            result = subprocess.run(["python3", str(PUBLISHER), "--prepare", "--candidate-source",
                                     source, "--server-parent", parent, "--repo-root", str(repo),
                                     "--output", str(output)], cwd=ROOT, text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            manifest = json.loads(output.read_text())
            self.assertEqual(manifest["status"], "blocked")
            self.assertGreater(sum(row["body_bytes"] for row in manifest["tree_requests"]
                                   if row["variant"] == "candidate"), 2 * 1024 * 1024)
            self.assertFalse(manifest["projection"]["complete_product_delta_dropped"])
            checked = subprocess.run(["python3", str(PUBLISHER), "--check-manifest", str(output)],
                                     cwd=ROOT, text=True, capture_output=True)
            self.assertEqual(checked.returncode, 0, checked.stderr)
            self.assertIn('"valid": true', checked.stdout)

    def test_large_multifile_product_delta_is_packed_into_ordered_bounded_tree_chain(self):
        with tempfile.TemporaryDirectory(prefix="sigra-publication-packed-") as temp:
            temp_path = pathlib.Path(temp)
            repo = temp_path / "repo"
            parent, source = git_fixture(repo, many_entries=120)
            output = temp_path / "proposal.json"
            result = subprocess.run(["python3", str(PUBLISHER), "--prepare", "--candidate-source",
                                     source, "--server-parent", parent, "--repo-root", str(repo),
                                     "--output", str(output)], cwd=ROOT, text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            manifest = json.loads(output.read_text())
            self.assertEqual(manifest["status"], "ready-local-proposal")
            candidate = [row for row in manifest["tree_requests"] if row["name"].startswith("candidate")]
            self.assertGreater(len(candidate), 1)
            self.assertTrue(all(row["body_bytes"] <= 2 * 1024 * 1024 for row in manifest["tree_requests"]))
            self.assertEqual(candidate[0]["base_tree_sha"], manifest["parent_tree_sha"])
            self.assertTrue(all(candidate[i]["base_tree_sha"] == candidate[i - 1]["tree_sha"]
                                for i in range(1, len(candidate))))
            self.assertEqual(candidate[-1]["tree_sha"], manifest["candidate_tree_sha"])
            self.assertEqual(manifest["projection"]["projected_total_requests"],
                             1 + 12 + len(manifest["tree_requests"]) + manifest["projection"]["binary_blob_requests"])
            checked = subprocess.run(["python3", str(PUBLISHER), "--check-manifest", str(output)],
                                     cwd=ROOT, text=True, capture_output=True)
            self.assertEqual(checked.returncode, 0, checked.stderr)

    def test_manifest_rejects_broken_tree_base_chain_and_over_budget_chain(self):
        with tempfile.TemporaryDirectory(prefix="sigra-publication-chain-negative-") as temp:
            temp_path = pathlib.Path(temp)
            repo = temp_path / "repo"
            parent, source = git_fixture(repo, many_entries=120)
            output = temp_path / "proposal.json"
            prepared = subprocess.run(["python3", str(PUBLISHER), "--prepare", "--candidate-source",
                                       source, "--server-parent", parent, "--repo-root", str(repo),
                                       "--output", str(output)], cwd=ROOT, text=True, capture_output=True)
            self.assertEqual(prepared.returncode, 0, prepared.stderr)
            original = json.loads(output.read_text())
            mutations = {
                "broken base": lambda value: next(row for row in value["tree_requests"]
                                                    if row["variant"] == "candidate" and row["sequence"] == 2).__setitem__("base_tree_sha", "f" * 40),
                "tampered SHA": lambda value: next(row for row in value["tree_requests"]
                                                     if row["variant"] == "candidate" and row["sequence"] == 1).__setitem__("tree_sha", "f" * 40),
                "over-budget projection": lambda value: value["projection"].update({
                    "tree_request_count": len(value["tree_requests"]) + 8,
                    "projected_total_requests": 1 + 12 + len(value["tree_requests"]) + 8
                    + value["projection"]["binary_blob_requests"]}),
                "single oversized request": lambda value: (value["tree_requests"][0].update({"body_bytes": 2 * 1024 * 1024 + 1}),
                                                              value["projection"].update({"largest_tree_body_bytes": 2 * 1024 * 1024 + 1})),
            }
            def remove_middle_candidate(value):
                value["tree_requests"].pop(1)
                value["projection"]["tree_request_count"] -= 1
                value["projection"]["projected_total_requests"] -= 1
            mutations["incomplete chain"] = remove_middle_candidate
            for label, mutate in mutations.items():
                with self.subTest(label=label):
                    value = json.loads(json.dumps(original))
                    mutate(value)
                    output.write_text(json.dumps(value))
                    rejected = subprocess.run(["python3", str(PUBLISHER), "--check-manifest", str(output)],
                                              cwd=ROOT, text=True, capture_output=True)
                    self.assertNotEqual(rejected.returncode, 0, label)

    def make_local_publication(self, temp, flags=None, many_entries=0, helpers=False, prepare_args=(), allocation=None):
        temp_path = pathlib.Path(temp)
        repo = temp_path / "repo"
        parent, source = git_fixture(repo, many_entries=many_entries, helpers=helpers)
        manifest_path = temp_path / "manifest.json"
        prepared = subprocess.run(["python3", str(PUBLISHER), "--prepare", "--candidate-source", source,
                                   "--server-parent", parent, "--repo-root", str(repo), "--output", str(manifest_path),
                                   *prepare_args],
                                  cwd=ROOT, text=True, capture_output=True)
        self.assertEqual(prepared.returncode, 0, prepared.stderr)
        manifest = json.loads(manifest_path.read_text())
        self.assertEqual(manifest["status"], "ready-local-proposal")
        self.assertNotEqual(manifest["candidate_helper_commit"], source)
        self.assertNotEqual(manifest["candidate_helper_commit"], manifest["fixture_workflow_commit"])

        cert, key = temp_path / "server.pem", temp_path / "server-key.pem"
        subprocess.run(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1",
                        "-subj", "/CN=localhost", "-addext", "subjectAltName=DNS:localhost",
                        "-keyout", str(key), "-out", str(cert)], check=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        server = ObjectHTTPServer(("127.0.0.1", 0), ObjectServer)
        server.git_dir = str(temp_path / "server.git")
        server.journal, server.commits, server.trees = [], {}, {}
        server.tree_entries, server.blobs, server.refs = {}, {}, {}
        server.flags = dict(flags or {})
        server.last_body = b""
        self.addCleanup(server.server_close)
        seed_server(server, repo, parent)
        server.parent_sha = parent
        ledger_path = temp_path / "ledger.json"
        server.ledger_path = str(ledger_path)
        tls = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        tls.load_cert_chain(cert, key)
        server.socket = tls.wrap_socket(server.socket, server_side=True)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        self.addCleanup(thread.join)
        self.addCleanup(server.shutdown)
        host, port = server.server_address
        allocation_path = temp_path / "allocation.json"
        allocation_value = {"schema_version": "sigra.phase253.http-allocation/v1", "window_id": "publication-test-window",
                            "source_sha256": hashlib.sha256(manifest_path.read_bytes()).hexdigest(), "max_requests": 24,
                            "max_elapsed_seconds": 60, "max_response_bytes": 2 * 1024 * 1024, "max_pages": 1,
                            "max_hops": 2, "repository": "szTheory/sigra", "download_hosts": [], "mode": "hermetic-test",
                            "test_origin": f"https://localhost:{port}", "test_ca_file": str(cert)}
        allocation_value.update(allocation or {})
        allocation_path.write_text(json.dumps(allocation_value))
        return repo, parent, source, manifest_path, manifest, allocation_path, ledger_path, server, temp_path

    def test_actual_measured_https_uploads_local_only_objects_before_create_only_ref_readback(self):
        with tempfile.TemporaryDirectory(prefix="sigra-object-publication-") as temp:
            repo, parent, source, manifest_path, manifest, allocation, ledger_path, server, root = self.make_local_publication(temp)
            self.assertNotIn(manifest["candidate_helper_commit"], server.commits)
            binary_source = subprocess.check_output(["git", "-C", str(repo), "rev-parse", "HEAD:binary.dat"], text=True).strip()
            self.assertNotIn(binary_source, server.blobs)
            receipt_path = root / "publication-receipt.json"
            result = subprocess.run(["python3", str(PUBLISHER), "--publish", "--manifest", str(manifest_path),
                                    "--allocation", str(allocation), "--ledger", str(ledger_path),
                                    "--receipt", str(receipt_path), "--repo-root", str(repo)],
                                   cwd=ROOT, text=True, capture_output=True, timeout=45)
            self.assertEqual(result.returncode, 0, result.stderr + json.dumps(server.journal))
            ledger = json.loads(ledger_path.read_text())
            receipt = json.loads(receipt_path.read_text())
            self.assertEqual(receipt["status"], "published-local-fixture")
            self.assertEqual(receipt["production_publish_performed"], False)
            self.assertLessEqual(receipt["request_count"], 24)
            self.assertEqual(receipt["request_count"], 16)
            self.assertEqual(len(ledger["transactions"]), len(server.journal))
            self.assertTrue(all(row["charged"] for row in server.journal))
            self.assertEqual([row["status"] for row in server.journal], [row["actual_status"] for row in ledger["transactions"]])
            self.assertEqual([row["method"] for row in server.journal], [row["method"] for row in ledger["transactions"]])
            self.assertEqual([row["request_body_sha256"] for row in server.journal],
                             [row["request_body_sha256"] for row in ledger["transactions"]])
            self.assertEqual([row["request_body_bytes"] for row in server.journal],
                             [row["request_body_bytes"] or 0 for row in ledger["transactions"]])
            self.assertNotIn("authorization", server.journal[0])
            self.assertTrue(any(row["path"].endswith("/blobs") and row["method"] == "POST" for row in server.journal))
            self.assertEqual(server.refs["gsd/253-replan-candidate"], manifest["candidate_helper_commit"])
            self.assertEqual(server.refs["gsd/253-replan-fixture"], manifest["fixture_workflow_commit"])
            self.assertNotEqual(manifest["candidate_helper_commit"], manifest["candidate_source_commit"])
            self.assertEqual(manifest["commit_metadata"]["unsigned"], True)
            candidate_tree = subprocess.check_output(["git", "-C", str(repo), "rev-parse",
                                                       f"{manifest['candidate_helper_commit']}^{{tree}}"], text=True).strip()
            published_app = server.tree_entries[candidate_tree]["app.txt"]
            self.assertEqual(published_app["mode"], "100644")
            self.assertEqual(base64.b64decode(server.blobs[published_app["sha"]]["content"]),
                             (repo / "app.txt").read_bytes())
            published_exec = server.tree_entries[candidate_tree]["tool.sh"]
            self.assertEqual(published_exec["mode"], "100755")
            fixture_changes = subprocess.check_output(["git", "-C", str(repo), "diff", "--name-only",
                                                         manifest["candidate_helper_commit"], manifest["fixture_workflow_commit"]], text=True).splitlines()
            self.assertEqual(fixture_changes, [".github/workflows/phase-253-gate-canary.yml"])
            docs_base_changes = subprocess.check_output(["git", "-C", str(repo), "diff", "--name-only",
                                                          manifest["candidate_helper_commit"], manifest["docs_base_commit"]], text=True).splitlines()
            docs_head_changes = subprocess.check_output(["git", "-C", str(repo), "diff", "--name-only",
                                                          manifest["docs_base_commit"], manifest["docs_head_commit"]], text=True).splitlines()
            self.assertEqual(docs_base_changes, [".github/workflows/ci.yml"])
            self.assertEqual(docs_head_changes, ["guides/reference/phase253-docs-only-proof.md"])
            candidate_raw = subprocess.check_output(["git", "-C", str(repo), "cat-file", "commit",
                                                       manifest["candidate_helper_commit"]])
            self.assertNotIn(b"gpgsig ", candidate_raw)
            self.assertNotIn(b"mergetag ", candidate_raw)
            check = subprocess.run(["python3", str(PUBLISHER), "--verify-publication", str(receipt_path)],
                                   cwd=ROOT, text=True, capture_output=True)
            self.assertEqual(check.returncode, 0, check.stderr)

            # A ledger hash alone cannot prove both scoped refs were read back.
            # Removing the candidate-ref receipt must invalidate publication evidence.
            incomplete_receipt = json.loads(receipt_path.read_text())
            incomplete_receipt["server_object_receipts"] = [
                row for row in incomplete_receipt["server_object_receipts"]
                if not (row.get("kind") == "ref" and row.get("variant") == "candidate")
            ]
            receipt_path.write_text(json.dumps(incomplete_receipt))
            rejected = subprocess.run(["python3", str(PUBLISHER), "--verify-publication", str(receipt_path)],
                                      cwd=ROOT, text=True, capture_output=True)
            self.assertNotEqual(rejected.returncode, 0, "receipt verifier accepted a missing candidate ref readback")

    def test_actual_transport_publishes_full_multifile_delta_through_bounded_tree_chain(self):
        with tempfile.TemporaryDirectory(prefix="sigra-object-publication-packed-") as temp:
            repo, parent, source, manifest_path, manifest, allocation, ledger_path, server, root = self.make_local_publication(
                temp, many_entries=120)
            self.assertGreater(sum(row["body_bytes"] for row in manifest["tree_requests"]
                                   if row["variant"] == "candidate"), 2 * 1024 * 1024)
            self.assertTrue(all(row["body_bytes"] <= 2 * 1024 * 1024 for row in manifest["tree_requests"]))
            receipt_path = root / "publication-receipt.json"
            result = subprocess.run(["python3", str(PUBLISHER), "--publish", "--manifest", str(manifest_path),
                                     "--allocation", str(allocation), "--ledger", str(ledger_path),
                                     "--receipt", str(receipt_path), "--repo-root", str(repo)],
                                    cwd=ROOT, text=True, capture_output=True, timeout=90)
            self.assertEqual(result.returncode, 0, result.stderr + json.dumps(server.journal))
            ledger = json.loads(ledger_path.read_text())
            receipt = json.loads(receipt_path.read_text())
            self.assertEqual(len(ledger["transactions"]), len(server.journal))
            self.assertEqual(receipt["request_count"], len(server.journal))
            self.assertLessEqual(receipt["request_count"], 24)
            self.assertEqual([row["request_body_bytes"] for row in server.journal],
                             [row["request_body_bytes"] or 0 for row in ledger["transactions"]])
            self.assertTrue(all(row["charged"] for row in server.journal))
            tree_posts = [row for row in server.journal if row["path"].endswith("/trees") and row["method"] == "POST"]
            self.assertEqual(len(tree_posts), len(manifest["tree_requests"]))
            self.assertTrue(all(row["request_body_bytes"] <= 2 * 1024 * 1024 for row in tree_posts))
            first_ref_index = next(i for i, row in enumerate(server.journal) if row["path"].endswith("/refs"))
            last_tree_index = max(i for i, row in enumerate(server.journal)
                                  if row["path"].endswith("/trees") and row["method"] == "POST")
            self.assertLess(last_tree_index, first_ref_index)
            last_commit_index = max(i for i, row in enumerate(server.journal)
                                    if "/commits/" in row["path"] or row["path"].endswith("/commits"))
            self.assertLess(last_commit_index, first_ref_index)
            local_entries = parse_local_tree(repo, manifest["candidate_helper_commit"])
            self.assertEqual(server.tree_entries[manifest["candidate_tree_sha"]], local_entries)
            for entry in local_entries.values():
                if entry["type"] == "blob":
                    self.assertEqual(base64.b64decode(server.blobs[entry["sha"]]["content"]),
                                     subprocess.check_output(["git", "-C", str(repo), "cat-file", "blob", entry["sha"]]))
            self.assertEqual(server.refs["gsd/253-replan-candidate"], manifest["candidate_helper_commit"])
            self.assertEqual(server.refs["gsd/253-replan-fixture"], manifest["fixture_workflow_commit"])

    def test_exact_existing_ref_is_reused_only_with_matching_manifest_and_window_receipt(self):
        with tempfile.TemporaryDirectory(prefix="sigra-object-matching-ref-") as temp:
            repo, parent, source, manifest_path, manifest, allocation, ledger_path, server, root = self.make_local_publication(temp)
            server.refs["gsd/253-replan-candidate"] = manifest["candidate_helper_commit"]
            receipt_path = root / "receipt.json"
            receipt_path.write_text(json.dumps({
                "manifest_sha256": hashlib.sha256(manifest_path.read_bytes()).hexdigest(),
                "allocation_sha256": hashlib.sha256(allocation.read_bytes()).hexdigest(),
                "server_object_receipts": [{"kind": "candidate", "sha": manifest["candidate_helper_commit"]}],
            }))
            result = subprocess.run(["python3", str(PUBLISHER), "--publish", "--manifest", str(manifest_path),
                                     "--allocation", str(allocation), "--ledger", str(ledger_path), "--receipt", str(receipt_path),
                                     "--repo-root", str(repo)], cwd=ROOT, text=True, capture_output=True, timeout=45)
            self.assertEqual(result.returncode, 0, result.stderr)
            candidate_ref_calls = [row for row in server.journal if "gsd/253-replan-candidate" in row["path"]]
            self.assertEqual([(row["method"], row["status"]) for row in candidate_ref_calls], [("GET", 200)])

    def test_unknown_parent_is_a_counted_preflight_stop_before_any_upload(self):
        with tempfile.TemporaryDirectory(prefix="sigra-object-parent-missing-") as temp:
            _, parent, _, _, _, allocation, ledger_path, server, _ = self.make_local_publication(temp)
            del server.commits[parent]
            manifest = json.loads((pathlib.Path(temp) / "manifest.json").read_text())
            receipt_path = pathlib.Path(temp) / "receipt.json"
            result = subprocess.run(["python3", str(PUBLISHER), "--publish", "--manifest", str(pathlib.Path(temp) / "manifest.json"),
                                     "--allocation", str(allocation), "--ledger", str(ledger_path), "--receipt", str(receipt_path),
                                     "--repo-root", str(pathlib.Path(temp) / "repo")], cwd=ROOT, text=True, capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("HTTP 404", result.stderr)
            self.assertEqual(len(server.journal), 1)
            self.assertEqual(json.loads(ledger_path.read_text())["transactions"][0]["actual_status"], 404)

    def test_changed_server_tree_sha_stops_before_commit_or_ref(self):
        with tempfile.TemporaryDirectory(prefix="sigra-object-tree-sha-") as temp:
            *_, allocation, ledger_path, server, root = self.make_local_publication(temp, {"alter_tree_sha": True})
            result = subprocess.run(["python3", str(PUBLISHER), "--publish", "--manifest", str(root / "manifest.json"),
                                     "--allocation", str(allocation), "--ledger", str(ledger_path), "--receipt", str(root / "receipt.json"),
                                     "--repo-root", str(root / "repo")], cwd=ROOT, text=True, capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("server tree identity differs", result.stderr)
            self.assertFalse(any(path.endswith("/commits") or path.endswith("/refs") for path in (row["path"] for row in server.journal)))
            self.assertTrue(all(tx["state"] == "complete" for tx in json.loads(ledger_path.read_text())["transactions"]))

    def test_existing_wrong_ref_is_never_overwritten(self):
        with tempfile.TemporaryDirectory(prefix="sigra-object-wrong-ref-") as temp:
            repo, parent, source, manifest_path, manifest, allocation, ledger_path, server, root = self.make_local_publication(temp)
            server.refs["gsd/253-replan-candidate"] = parent
            result = subprocess.run(["python3", str(PUBLISHER), "--publish", "--manifest", str(manifest_path),
                                     "--allocation", str(allocation), "--ledger", str(ledger_path), "--receipt", str(root / "receipt.json"),
                                     "--repo-root", str(repo)], cwd=ROOT, text=True, capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("already points to a different commit", result.stderr)
            self.assertEqual(server.refs["gsd/253-replan-candidate"], parent)
            self.assertFalse(any(row["path"].endswith("/refs") and row["method"] == "POST" for row in server.journal))

    def test_create_race_is_counted_and_never_retried_or_patched(self):
        with tempfile.TemporaryDirectory(prefix="sigra-object-ref-race-") as temp:
            repo, parent, source, manifest_path, manifest, allocation, ledger_path, server, root = self.make_local_publication(temp, {"race_create": True})
            result = subprocess.run(["python3", str(PUBLISHER), "--publish", "--manifest", str(manifest_path),
                                     "--allocation", str(allocation), "--ledger", str(ledger_path), "--receipt", str(root / "receipt.json"),
                                     "--repo-root", str(repo)], cwd=ROOT, text=True, capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            refs = [row for row in server.journal if row["path"].endswith("/refs")]
            self.assertEqual([(row["method"], row["status"]) for row in refs], [("POST", 422)])
            self.assertEqual(server.refs["gsd/253-replan-candidate"], parent)
            self.assertFalse(any(row["method"] in {"PATCH", "PUT"} for row in server.journal))

    def test_lost_ref_readback_keeps_created_ref_and_never_replays_create(self):
        with tempfile.TemporaryDirectory(prefix="sigra-object-lost-readback-") as temp:
            repo, parent, source, manifest_path, manifest, allocation, ledger_path, server, root = self.make_local_publication(temp, {"lose_ref_readback": True})
            result = subprocess.run(["python3", str(PUBLISHER), "--publish", "--manifest", str(manifest_path),
                                     "--allocation", str(allocation), "--ledger", str(ledger_path), "--receipt", str(root / "receipt.json"),
                                     "--repo-root", str(repo)], cwd=ROOT, text=True, capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("HTTP 404", result.stderr)
            creates = [row for row in server.journal if row["path"].endswith("/refs") and row["method"] == "POST"]
            self.assertEqual(len(creates), 1)
            self.assertEqual(server.refs["gsd/253-replan-candidate"], manifest["candidate_helper_commit"])

    def test_tampered_commit_readback_metadata_is_rejected_after_charge(self):
        with tempfile.TemporaryDirectory(prefix="sigra-object-commit-metadata-") as temp:
            repo, parent, source, manifest_path, manifest, allocation, ledger_path, server, root = self.make_local_publication(temp, {"alter_commit_readback": True})
            result = subprocess.run(["python3", str(PUBLISHER), "--publish", "--manifest", str(manifest_path),
                                     "--allocation", str(allocation), "--ledger", str(ledger_path), "--receipt", str(root / "receipt.json"),
                                     "--repo-root", str(repo)], cwd=ROOT, text=True, capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("commit readback differs", result.stderr)
            self.assertTrue(all(row["charged"] for row in server.journal))
            self.assertEqual(len(server.journal), len(json.loads(ledger_path.read_text())["transactions"]))

    def test_empty_null_single_and_forged_manifest_inputs_are_rejected(self):
        with tempfile.TemporaryDirectory(prefix="sigra-object-invalid-manifest-") as temp:
            path = pathlib.Path(temp) / "manifest.json"
            values = [None, [], {"schema_version": "fake"}, {"schema_version": "sigra.phase253.git-publication/v1",
                      "status": "ready-local-proposal", "source_sha": "f" * 40, "server_parent_sha": "f" * 40,
                      "candidate_helper_commit": "f" * 40, "fixture_workflow_commit": "f" * 40,
                      "fixture_workflow_blob": "f" * 40, "tree_requests": [], "projection": {
                          "max_requests": 24, "complete_product_delta_dropped": True, "projected_total_requests": 1}}]
            for value in values:
                with self.subTest(value=value):
                    path.write_text(json.dumps(value))
                    result = subprocess.run(["python3", str(PUBLISHER), "--check-manifest", str(path)],
                                            cwd=ROOT, text=True, capture_output=True)
                    self.assertNotEqual(result.returncode, 0)

    def test_git_object_route_rejects_short_uppercase_and_nonhex_sha(self):
        transport = self.transport_module()
        allocation = {"mode": "live", "repository": "szTheory/sigra"}
        for sha in ("a" * 39, "A" * 40, "g" * 40, "a" * 39 + "/"):
            with self.subTest(sha=sha), self.assertRaises(transport.TransportError):
                transport._route({"route_id": "git_get_blob", "method": "GET", "params": {"sha": sha}}, allocation)

    def test_tree_route_rejects_absolute_traversal_empty_segment_and_nul_path(self):
        transport = self.transport_module()
        allocation = {"mode": "live", "repository": "szTheory/sigra"}
        for path in ("/etc/passwd", "../main", "a//b", "a\x00b"):
            body = {"tree": [{"path": path, "mode": "100644", "type": "blob", "content": "text\n"}]}
            with self.subTest(path=path), self.assertRaises(transport.TransportError):
                transport._route({"route_id": "git_create_tree", "method": "POST", "body": body}, allocation)

    def test_tree_route_rejects_nul_text_and_accepts_executable_mode(self):
        transport = self.transport_module()
        allocation = {"mode": "live", "repository": "szTheory/sigra"}
        invalid = {"tree": [{"path": "safe.txt", "mode": "100644", "type": "blob", "content": "bad\x00text"}]}
        with self.assertRaises(transport.TransportError):
            transport._route({"route_id": "git_create_tree", "method": "POST", "body": invalid}, allocation)
        valid = {"tree": [{"path": "bin/tool", "mode": "100755", "type": "blob", "content": "#!/bin/sh\n"}]}
        host, port, body, path = transport._route({"route_id": "git_create_tree", "method": "POST", "body": valid}, allocation)
        self.assertEqual(path, "/repos/szTheory/sigra/git/trees")
        self.assertEqual(json.loads(body)["tree"][0]["mode"], "100755")

    def test_tree_route_allows_explicit_null_sha_deletion(self):
        transport = self.transport_module()
        allocation = {"mode": "live", "repository": "szTheory/sigra"}
        body = {"base_tree": "a" * 40, "tree": [{"path": "old.txt", "mode": "100644", "type": "blob", "sha": None}]}
        _, _, encoded, _ = transport._route({"route_id": "git_create_tree", "method": "POST", "body": body}, allocation)
        self.assertEqual(json.loads(encoded)["tree"][0]["sha"], None)

    def test_tree_request_wire_body_is_capped_at_two_mib(self):
        transport = self.transport_module()
        request = {"route_id": "git_create_tree", "method": "POST", "body": {
            "tree": [{"path": "large.txt", "mode": "100644", "type": "blob", "content": "x" * (2 * 1024 * 1024)}]}}
        with self.assertRaises(transport.TransportError) as error:
            transport._route(request, {"mode": "live", "repository": "szTheory/sigra"})
        self.assertEqual(error.exception.code, "request_body_too_large")

    def test_commit_route_rejects_signed_or_unknown_header_representation(self):
        transport = self.transport_module()
        allocation = {"mode": "live", "repository": "szTheory/sigra"}
        identity = {"name": "Signer", "email": "signer@example.test", "date": "2026-10-13T00:00:00Z"}
        body = {"message": "unsigned\n", "tree": "a" * 40, "parents": ["b" * 40],
                "author": identity, "committer": identity}
        good = {"route_id": "git_create_commit", "method": "POST", "body": body}
        self.assertEqual(json.loads(transport._route(good, allocation)[2]), body)
        for extra in ({"gpgsig": "sig"}, {"verification": {"verified": True}}):
            with self.subTest(extra=extra), self.assertRaises(transport.TransportError):
                transport._route({**good, "body": {**body, **extra}}, allocation)

    def test_blob_route_rejects_invalid_base64_without_transmitting(self):
        transport = self.transport_module()
        request = {"route_id": "git_create_blob", "method": "POST", "body": {"encoding": "base64", "content": "%%%"}}
        with self.assertRaises(transport.TransportError):
            transport._route(request, {"mode": "live", "repository": "szTheory/sigra"})

    def test_changed_product_worktree_status_blocks_preparation(self):
        with tempfile.TemporaryDirectory(prefix="sigra-dirty-source-") as temp:
            repo = pathlib.Path(temp) / "repo"
            parent, source = git_fixture(repo)
            (repo / "app.txt").write_text("uncommitted product change\n")
            output = pathlib.Path(temp) / "proposal.json"
            result = subprocess.run(["python3", str(PUBLISHER), "--prepare", "--candidate-source", source,
                                     "--server-parent", parent, "--repo-root", str(repo), "--output", str(output)],
                                    cwd=ROOT, text=True, capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("dirty outside the exact preserved config", result.stderr)
            self.assertFalse(output.exists())

    def test_dirty_config_with_changed_bytes_and_no_exact_preservation_ref_is_rejected(self):
        with tempfile.TemporaryDirectory(prefix="sigra-config-variant-") as temp:
            repo = pathlib.Path(temp) / "repo"
            parent, source = git_fixture(repo)
            (repo / ".planning").mkdir()
            (repo / ".planning/config.json").write_text("{\"model\":\"old\"}\n")
            subprocess.run(["git", "-C", str(repo), "add", ".planning/config.json"], check=True)
            subprocess.run(["git", "-C", str(repo), "commit", "-qm", "tracked planning config"], check=True)
            source = subprocess.check_output(["git", "-C", str(repo), "rev-parse", "HEAD"], text=True).strip()
            (repo / ".planning/config.json").write_text("{\"model\":\"changed\"}\n")
            output = pathlib.Path(temp) / "proposal.json"
            result = subprocess.run(["python3", str(PUBLISHER), "--prepare", "--candidate-source", source,
                                     "--server-parent", parent, "--repo-root", str(repo), "--output", str(output)],
                                    cwd=ROOT, text=True, capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("dirty outside the exact preserved config", result.stderr)
            self.assertFalse(output.exists())

    def test_exact_preserved_config_status_and_bytes_allow_only_planning_metadata_changes(self):
        with tempfile.TemporaryDirectory(prefix="sigra-exact-config-") as temp:
            repo = pathlib.Path(temp) / "repo"
            parent, source = git_fixture(repo)
            (repo / ".planning").mkdir()
            config_path = repo / ".planning/config.json"
            config_path.write_text("baseline config\n")
            subprocess.run(["git", "-C", str(repo), "add", str(config_path)], check=True)
            subprocess.run(["git", "-C", str(repo), "commit", "-qm", "tracked config baseline"], check=True)
            source = subprocess.check_output(["git", "-C", str(repo), "rev-parse", "HEAD"], text=True).strip()
            exact_bytes = (ROOT / ".planning/config.json").read_bytes()
            config_path.write_bytes(exact_bytes)
            blob = subprocess.check_output(["git", "-C", str(repo), "hash-object", "-w", str(config_path)], text=True).strip()
            subprocess.run(["git", "-C", str(repo), "update-ref", "refs/gsd/phase253-recovery-execution-unrelated-config", blob], check=True)
            evidence = repo / ".planning/runtime/evidence.log"
            evidence.parent.mkdir(parents=True)
            evidence.write_text("local runtime evidence is not product source\n")
            output = pathlib.Path(temp) / "proposal.json"
            result = subprocess.run(["python3", str(PUBLISHER), "--prepare", "--candidate-source", source,
                                     "--server-parent", parent, "--repo-root", str(repo), "--output", str(output)],
                                    cwd=ROOT, text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            manifest = json.loads(output.read_text())
            self.assertTrue(manifest["source_cleanliness"]["clean"])
            self.assertEqual(manifest["source_cleanliness"]["config_ref"],
                             "refs/gsd/phase253-recovery-execution-unrelated-config")
            self.assertEqual(manifest["source_cleanliness"]["config_sha256"], "8e312f6ccd3485941059446e5852b39651f7ad1863fa003c62f6e5635d7c0b8d")

    def test_commit_route_requires_second_resolution_utc_metadata_and_final_newline(self):
        transport = self.transport_module()
        allocation = {"mode": "live", "repository": "szTheory/sigra"}
        identity = {"name": "Signer", "email": "signer@example.test", "date": "2026-10-13T00:00:00Z"}
        base = {"message": "complete\n", "tree": "a" * 40, "parents": ["b" * 40],
                "author": identity, "committer": identity}
        for invalid in ({**base, "message": "missing newline"},
                        {**base, "author": {**identity, "date": "2026-10-13T00:00:00.123Z"}},
                        {**base, "committer": {**identity, "date": "2026-10-13T00:00:00+01:00"}}):
            with self.subTest(invalid=invalid), self.assertRaises(transport.TransportError):
                transport._route({"route_id": "git_create_commit", "method": "POST", "body": invalid}, allocation)

    def test_actual_server_rejects_create_ref_for_a_local_only_unknown_commit(self):
        with tempfile.TemporaryDirectory(prefix="sigra-object-missing-") as temp:
            repo, parent, source, manifest_path, manifest, allocation, ledger_path, server, root = self.make_local_publication(temp)
            unknown = "f" * 40
            request = {"route_id": "create_ref", "method": "POST", "body": {
                "ref": "refs/heads/gsd/253-replan-unknown", "sha": unknown}}
            request_path, receipt_path = root / "request.json", root / "response.json"
            request_path.write_text(json.dumps(request))
            result = subprocess.run([sys.executable, str(TRANSPORT), "--allocation", str(allocation), "--ledger", str(ledger_path),
                                     "--request", str(request_path), "--output", str(receipt_path)],
                                    cwd=ROOT, text=True, capture_output=True, timeout=10)
            self.assertEqual(result.returncode, 0, result.stderr)
            response = json.loads(receipt_path.read_text())
            self.assertEqual(response["actual_status"], 422)
            self.assertNotIn("gsd/253-replan-unknown", server.refs)
            self.assertEqual(len(server.journal), 1)
            self.assertTrue(server.journal[0]["charged"])

    def test_git_object_tree_route_is_live_repo_bound_and_post_only(self):
        import importlib.util
        spec = importlib.util.spec_from_file_location("hosted_transport", TRANSPORT)
        transport = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(transport)
        request = {"route_id": "git_create_tree", "method": "POST", "body": {"tree": []}}
        live = {"mode": "live", "repository": "szTheory/sigra"}
        host, port, body, path = transport._route(request, live)
        self.assertEqual((host, port, path), ("api.github.com", 443, "/repos/szTheory/sigra/git/trees"))
        self.assertEqual(json.loads(body), {"tree": []})
        with self.assertRaises(transport.TransportError):
            transport._route({**request, "method": "GET"}, live)
        with self.assertRaises(transport.TransportError):
            transport._route(request, {"mode": "live", "repository": "attacker/repo"})

    def test_hermetic_git_object_route_is_restricted_to_local_https_origin(self):
        import importlib.util
        spec = importlib.util.spec_from_file_location("hosted_transport", TRANSPORT)
        transport = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(transport)
        allocation = {"mode": "hermetic-test", "test_origin": "https://localhost:4555", "max_pages": 1}
        host, port, body, path = transport._route(
            {"route_id": "git_get_commit", "method": "GET", "params": {"sha": "a" * 40}}, allocation)
        self.assertEqual((host, port, path, body), ("localhost", 4555, "/repos/szTheory/sigra/git/commits/" + "a" * 40, None))
        allocation["test_origin"] = "https://outside.example:4555"
        with self.assertRaises(transport.TransportError):
            transport._route({"route_id": "git_get_commit", "method": "GET", "params": {"sha": "a" * 40}}, allocation)

    def test_ref_creation_body_enforces_scoped_namespace_and_full_sha(self):
        import importlib.util
        spec = importlib.util.spec_from_file_location("hosted_transport", TRANSPORT)
        transport = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(transport)
        allocation = {"mode": "live", "repository": "szTheory/sigra"}
        good = {"route_id": "create_ref", "method": "POST", "body": {
            "ref": "refs/heads/gsd/253-replan-candidate", "sha": "a" * 40}}
        self.assertEqual(json.loads(transport._route(good, allocation)[2]), good["body"])
        for ref, sha in (("refs/heads/main", "a" * 40), ("refs/tags/v9.9.9", "a" * 40),
                         ("refs/heads/gsd/253-replan-evil/../../main", "a" * 40),
                         ("refs/heads/gsd/253-replan-candidate", "a" * 39)):
            with self.subTest(ref=ref, sha=sha), self.assertRaises(transport.TransportError):
                transport._route({**good, "body": {"ref": ref, "sha": sha}}, allocation)




def canonical_sha(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, ensure_ascii=False, separators=(",", ":")).encode()).hexdigest()


def load_publisher():
    import importlib.util
    spec = importlib.util.spec_from_file_location("ci_git_publication_under_test", PUBLISHER)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def no_network_env(temp):
    """Environment in which a live transport cannot obtain a token, so it stops before any connection."""
    stub_dir = pathlib.Path(temp) / "stub-bin"
    stub_dir.mkdir(exist_ok=True)
    stub = stub_dir / "gh"
    stub.write_text("#!/bin/sh\nexit 1\n")
    stub.chmod(0o755)
    env = {key: value for key, value in os.environ.items() if key not in {"GH_TOKEN", "GITHUB_TOKEN"}}
    env["PATH"] = f"{stub_dir}:{env['PATH']}"
    env["HOME"] = str(temp)
    return env


def git_run(repo, *args):
    return subprocess.run(["git", "-C", str(repo), *args], check=True, text=True, capture_output=True).stdout.strip()


class RegisteredPublicationTests(unittest.TestCase):
    """Registered ci.yml fixture, actual-github origin, section approvals and the docs publisher (253-91)."""

    make_local_publication = PublicationTests.make_local_publication

    def prepare_registered(self, temp, **kwargs):
        fixture_rel = f"{PHASE_REL}/253-LOAD-RECOVERY-CANARY-WORKFLOW.yml"
        return self.make_local_publication(temp, helpers=True, prepare_args=(
            "--fixture-file", fixture_rel, "--workflow-path", ".github/workflows/ci.yml"), **kwargs)

    def publish_args(self, manifest_path, allocation, ledger_path, receipt_path, repo):
        return ["python3", str(PUBLISHER), "--publish", "--manifest", str(manifest_path), "--allocation", str(allocation),
                "--ledger", str(ledger_path), "--receipt", str(receipt_path), "--repo-root", str(repo)]

    def freeze_environment(self, temp, **kwargs):
        """A registered publication plus a committed publication manifest and a built, committed freeze."""
        repo, parent, source, manifest_path, manifest, allocation, ledger_path, server, root = self.prepare_registered(temp, **kwargs)
        phase = repo / PHASE_REL
        manifest_rel = f"{PHASE_REL}/253-LOAD-RECOVERY-CANARY-PUBLICATION.json"
        (repo / manifest_rel).write_bytes(manifest_path.read_bytes())
        freeze_rel = f"{PHASE_REL}/253-LOAD-RECOVERY-CANARY-FREEZE.json"
        git_run(repo, "add", manifest_rel)
        git_run(repo, "-c", "user.name=Fixture", "-c", "user.email=fixture@example.test", "commit", "-qm", "planning: publication manifest")
        built = subprocess.run(["python3", str(PUBLISHER), "--build-freeze", "--manifest", manifest_rel, "--output", freeze_rel,
                                "--repo-root", str(repo)], cwd=ROOT, text=True, capture_output=True)
        self.assertEqual(built.returncode, 0, built.stderr)
        git_run(repo, "add", freeze_rel)
        git_run(repo, "-c", "user.name=Fixture", "-c", "user.email=fixture@example.test", "commit", "-qm", "planning: freeze")
        freeze = json.loads((repo / freeze_rel).read_text())
        return {"repo": repo, "parent": parent, "source": source, "manifest_path": manifest_path, "manifest": manifest,
                "allocation": allocation, "ledger": ledger_path, "server": server, "root": root,
                "freeze_path": repo / freeze_rel, "freeze": freeze, "manifest_rel": manifest_rel, "phase": phase}

    def write_approval(self, env, section, *, commit=True, tamper=False, section_sha=None, decision="approve", name=None):
        record = {"schema_version": "sigra.phase253.outward-action-approval/v1", "decision": decision, "section": section,
                  "section_sha256": section_sha or env["freeze"]["outward_actions_sha256"][section],
                  "decided_by": "test-operator", "recorded_at": "2026-10-14T00:00:00Z"}
        path = env["phase"] / f"approval-{name or section}.json"
        path.write_text(json.dumps(record, indent=2) + "\n")
        if commit:
            git_run(env["repo"], "add", str(path))
            git_run(env["repo"], "-c", "user.name=Fixture", "-c", "user.email=fixture@example.test", "commit", "-qm", f"planning: {path.name}")
        if tamper:
            path.write_text(path.read_text() + "\n")
        return path

    def production_allocation(self, env, name="docs-allocation.json", ledger_name="docs-ledger.json"):
        transport = PublicationTests.transport_module(self)
        base = json.loads(env["allocation"].read_text())
        base.update({"allocation_kind": "production", "max_requests": 120, "category_limits": transport.PRODUCTION_CATEGORY_LIMITS,
                     "source_sha256": hashlib.sha256(env["freeze_path"].read_bytes()).hexdigest(), "window_id": "docs-publication-test-window"})
        path = env["root"] / name
        path.write_text(json.dumps(base))
        ledger = env["root"] / ledger_name
        env["server"].ledger_path = str(ledger)
        return path, ledger

    def canary_allocation(self, env, name="canary-allocation.json", ledger_name="canary-ledger.json"):
        base = json.loads(env["allocation"].read_text())
        base.update({"allocation_kind": "canary", "max_requests": 117,
                     "source_sha256": hashlib.sha256(env["freeze_path"].read_bytes()).hexdigest(), "window_id": "canary-publication-test-window"})
        path = env["root"] / name
        path.write_text(json.dumps(base))
        ledger = env["root"] / ledger_name
        env["server"].ledger_path = str(ledger)
        return path, ledger

    # -- registered fixture path and origin -------------------------------------------------
    def test_registered_ci_yml_fixture_child_changes_exactly_the_registered_workflow_and_is_published(self):
        with tempfile.TemporaryDirectory(prefix="sigra-registered-fixture-") as temp:
            repo, parent, source, manifest_path, manifest, allocation, ledger_path, server, root = self.prepare_registered(temp)
            self.assertEqual(manifest["workflow_path"], ".github/workflows/ci.yml")
            self.assertEqual(manifest["fixture_file"]["path"], f"{PHASE_REL}/253-LOAD-RECOVERY-CANARY-WORKFLOW.yml")
            changed = git_run(repo, "diff", "--name-only", manifest["candidate_helper_commit"], manifest["fixture_workflow_commit"]).splitlines()
            self.assertEqual(changed, [".github/workflows/ci.yml"])
            self.assertEqual(git_run(repo, "rev-parse", f"{manifest['fixture_workflow_commit']}:.github/workflows/ci.yml"),
                             manifest["fixture_workflow_blob"])
            receipt_path = root / "receipt.json"
            result = subprocess.run(self.publish_args(manifest_path, allocation, ledger_path, receipt_path, repo),
                                    cwd=ROOT, text=True, capture_output=True, timeout=90)
            self.assertEqual(result.returncode, 0, result.stderr + json.dumps(server.journal))
            receipt = json.loads(receipt_path.read_text())
            self.assertEqual(receipt["origin"]["kind"], "hermetic")
            self.assertEqual(receipt["status"], "published-local-fixture")
            self.assertEqual(server.refs["gsd/253-replan-fixture"], manifest["fixture_workflow_commit"])
            fixture_entry = server.tree_entries[manifest["fixture_tree_sha"]][".github/workflows/ci.yml"]
            self.assertEqual(base64.b64decode(server.blobs[fixture_entry["sha"]]["content"]).decode(), FIXTURE_TEXT)
            candidate_entry = server.tree_entries[manifest["candidate_tree_sha"]][".github/workflows/ci.yml"]
            self.assertNotEqual(candidate_entry["sha"], fixture_entry["sha"])
            ok = subprocess.run(["python3", str(PUBLISHER), "--verify-publication", str(receipt_path)], cwd=ROOT, text=True, capture_output=True)
            self.assertEqual(ok.returncode, 0, ok.stderr)

    def test_unregistered_workflow_path_and_missing_fixture_are_rejected_at_preparation(self):
        with tempfile.TemporaryDirectory(prefix="sigra-registered-reject-") as temp:
            repo = pathlib.Path(temp) / "repo"
            parent, source = git_fixture(repo, helpers=True)
            fixture_rel = f"{PHASE_REL}/253-LOAD-RECOVERY-CANARY-WORKFLOW.yml"
            for label, args in {"outside workflows": ("--fixture-file", fixture_rel, "--workflow-path", "scripts/evil.yml"),
                                "missing fixture": ("--fixture-file", f"{PHASE_REL}/absent.yml", "--workflow-path", ".github/workflows/ci.yml"),
                                "traversal": ("--fixture-file", "../outside.yml", "--workflow-path", ".github/workflows/ci.yml")}.items():
                with self.subTest(label=label):
                    result = subprocess.run(["python3", str(PUBLISHER), "--prepare", "--candidate-source", source, "--server-parent", parent,
                                             "--repo-root", str(repo), "--output", str(pathlib.Path(temp) / "m.json"), *args],
                                            cwd=ROOT, text=True, capture_output=True)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertFalse((pathlib.Path(temp) / "m.json").exists())

    def test_hermetic_and_legacy_origins_are_rejected_by_live_acceptance(self):
        with tempfile.TemporaryDirectory(prefix="sigra-origin-hermetic-") as temp:
            repo, parent, source, manifest_path, manifest, allocation, ledger_path, server, root = self.prepare_registered(temp)
            receipt_path = root / "receipt.json"
            self.assertEqual(subprocess.run(self.publish_args(manifest_path, allocation, ledger_path, receipt_path, repo),
                                            cwd=ROOT, text=True, capture_output=True, timeout=90).returncode, 0)
            live = subprocess.run(["python3", str(PUBLISHER), "--verify-publication", str(receipt_path), "--require-live-origin"],
                                  cwd=ROOT, text=True, capture_output=True)
            self.assertNotEqual(live.returncode, 0)
            self.assertIn("live acceptance", live.stderr)
            legacy = json.loads(receipt_path.read_text())
            del legacy["origin"]
            receipt_path.write_text(json.dumps(legacy))
            self.assertEqual(subprocess.run(["python3", str(PUBLISHER), "--verify-publication", str(receipt_path)],
                                            cwd=ROOT, text=True, capture_output=True).returncode, 0)
            rejected = subprocess.run(["python3", str(PUBLISHER), "--verify-publication", str(receipt_path), "--require-live-origin"],
                                      cwd=ROOT, text=True, capture_output=True)
            self.assertNotEqual(rejected.returncode, 0)

    def test_actual_github_origin_needs_live_allocation_hosts_and_server_derived_identities(self):
        with tempfile.TemporaryDirectory(prefix="sigra-origin-actual-") as temp:
            repo, parent, source, manifest_path, manifest, allocation, ledger_path, server, root = self.prepare_registered(temp)
            receipt_path = root / "receipt.json"
            self.assertEqual(subprocess.run(self.publish_args(manifest_path, allocation, ledger_path, receipt_path, repo),
                                            cwd=ROOT, text=True, capture_output=True, timeout=90).returncode, 0)
            hermetic_receipt = json.loads(receipt_path.read_text())
            hermetic_ledger = json.loads(ledger_path.read_text())

            def live_shaped(mutate=None):
                """Rewrite the measured hermetic run into the shape a live allocation would have produced."""
                live_allocation = {"schema_version": "sigra.phase253.http-allocation/v1", "window_id": "publication-test-window",
                                   "source_sha256": hashlib.sha256(manifest_path.read_bytes()).hexdigest(), "max_requests": 24,
                                   "max_elapsed_seconds": 60, "max_response_bytes": 2 * 1024 * 1024, "max_pages": 1, "max_hops": 2,
                                   "repository": "szTheory/sigra", "download_hosts": [], "mode": "live"}
                allocation_file = root / "live-allocation.json"
                allocation_file.write_text(json.dumps(live_allocation))
                ledger = json.loads(json.dumps(hermetic_ledger))
                ledger["allocation_sha256"] = hashlib.sha256(allocation_file.read_bytes()).hexdigest()
                for tx in ledger["transactions"]:
                    tx["host"] = "api.github.com"
                receipt = json.loads(json.dumps(hermetic_receipt))
                receipt.update({"status": "published-actual-github", "production_publish_performed": True,
                                "allocation_path": str(allocation_file), "allocation_sha256": ledger["allocation_sha256"],
                                "origin": {"kind": "actual-github", "host": "api.github.com", "allocation_mode": "live",
                                           "transactions": len(ledger["transactions"]), "identities_from_ledger": True}})
                if mutate:
                    mutate(receipt, ledger, allocation_file)
                ledger_file = root / "live-ledger.json"
                ledger_file.write_text(json.dumps(ledger))
                receipt["ledger_path"] = str(ledger_file)
                receipt["ledger_sha256"] = hashlib.sha256(ledger_file.read_bytes()).hexdigest()
                path = root / "live-receipt.json"
                path.write_text(json.dumps(receipt))
                return path

            def verify(path, *extra):
                return subprocess.run(["python3", str(PUBLISHER), "--verify-publication", str(path), *extra], cwd=ROOT, text=True, capture_output=True)

            accepted = verify(live_shaped(), "--require-live-origin")
            self.assertEqual(accepted.returncode, 0, accepted.stderr)

            def forged_commit(receipt, ledger, allocation_file):
                for row in receipt["server_object_receipts"]:
                    if row["kind"] == "commit" and row["variant"] == "candidate":
                        row["sha"] = "e" * 40
                receipt["candidate_sha"] = "e" * 40

            def local_host(receipt, ledger, allocation_file):
                ledger["transactions"][3]["host"] = "localhost"

            def hermetic_allocation(receipt, ledger, allocation_file):
                value = json.loads(allocation_file.read_text())
                value.update({"mode": "hermetic-test", "test_origin": "https://localhost:1", "test_ca_file": "/dev/null"})
                allocation_file.write_text(json.dumps(value))
                ledger["allocation_sha256"] = hashlib.sha256(allocation_file.read_bytes()).hexdigest()
                receipt["allocation_sha256"] = ledger["allocation_sha256"]

            def stripped_response(receipt, ledger, allocation_file):
                for tx in ledger["transactions"]:
                    if tx["route_id"] == "git_create_commit":
                        tx["response_body_base64"] = base64.b64encode(b"{}").decode()

            for label, mutate in {"identity absent from every server response": forged_commit, "non-GitHub host in the ledger": local_host,
                                  "hermetic allocation claimed as actual": hermetic_allocation,
                                  "commit response stripped": stripped_response}.items():
                with self.subTest(label=label):
                    self.assertNotEqual(verify(live_shaped(mutate), "--require-live-origin").returncode, 0, label)

    def test_validate_frozen_product_source_accepts_planning_only_descendants_and_rejects_product_changes(self):
        module = load_publisher()
        for label in ("planning-only", "product-descendant", "product-dirt", "not-an-ancestor"):
            with self.subTest(label=label), tempfile.TemporaryDirectory(prefix="sigra-frozen-source-") as temp:
                repo = pathlib.Path(temp) / "repo"
                parent, source = git_fixture(repo)
                frozen = source
                (repo / ".planning").mkdir(exist_ok=True)
                (repo / ".planning/note.txt").write_text("planning only\n")
                git_run(repo, "add", ".planning/note.txt")
                git_run(repo, "-c", "user.name=F", "-c", "user.email=f@example.test", "commit", "-qm", "planning only")
                if label == "product-descendant":
                    (repo / "app.txt").write_text("changed product\n")
                    git_run(repo, "add", "app.txt")
                    git_run(repo, "-c", "user.name=F", "-c", "user.email=f@example.test", "commit", "-qm", "product change")
                elif label == "product-dirt":
                    (repo / "tool.sh").write_text("#!/bin/sh\necho dirty\n")
                elif label == "not-an-ancestor":
                    frozen = parent  # earlier product tree, ancestor, but a different product tree
                if label == "planning-only":
                    result = module.validate_frozen_product_source(repo, frozen)
                    self.assertEqual(result["frozen_source"], frozen)
                    self.assertTrue(result["planning_only_movement"])
                    self.assertTrue(hasattr(module, "validateFrozenProductSource"))
                else:
                    with self.assertRaises(module.PublicationError):
                        module.validate_frozen_product_source(repo, frozen)

    # -- per-section approvals, docs publication ---------------------------------------------
    def test_publish_docs_publishes_only_the_frozen_docs_variants_within_fourteen_requests(self):
        with tempfile.TemporaryDirectory(prefix="sigra-publish-docs-") as temp:
            env = self.freeze_environment(temp)
            repo, server, manifest = env["repo"], env["server"], env["manifest"]
            canary_allocation, canary_ledger = self.canary_allocation(env)
            approval = self.write_approval(env, "canary")
            published = subprocess.run(self.publish_args(env["manifest_path"], canary_allocation, canary_ledger, env["root"] / "canary-receipt.json", repo)
                                       + ["--freeze", str(env["freeze_path"]), "--action-approval", str(approval)],
                                       cwd=ROOT, text=True, capture_output=True, timeout=90)
            self.assertEqual(published.returncode, 0, published.stderr + json.dumps(server.journal))
            canary_receipt = json.loads((env["root"] / "canary-receipt.json").read_text())
            self.assertEqual(canary_receipt["action_approval"]["section"], "canary")
            canary_count = len(server.journal)
            docs_approval = self.write_approval(env, "docs_and_prs")
            allocation, ledger = self.production_allocation(env)
            receipt_path = env["root"] / "docs-receipt.json"
            seen = {}
            server.first_hook = lambda: seen.update(receipt=json.loads(receipt_path.read_text()) if receipt_path.exists() else None)
            result = subprocess.run(["python3", str(PUBLISHER), "--publish-docs", "--freeze", str(env["freeze_path"]), "--allocation", str(allocation),
                                     "--ledger", str(ledger), "--receipt", str(receipt_path), "--repo-root", str(repo),
                                     "--action-approval", str(docs_approval)], cwd=ROOT, text=True, capture_output=True, timeout=90)
            self.assertEqual(result.returncode, 0, result.stderr + json.dumps(server.journal[canary_count:]))
            requests = server.journal[canary_count:]
            self.assertEqual(len(requests), 14)
            self.assertLessEqual(len(requests), 14)
            ledger_value = json.loads(ledger.read_text())
            self.assertEqual({tx["category"] for tx in ledger_value["transactions"]}, {"docs_publication"})
            self.assertEqual(server.refs["gsd/253-replan-docs-base"], manifest["docs_base_commit"])
            self.assertEqual(server.refs["gsd/253-replan-docs-head"], manifest["docs_head_commit"])
            self.assertNotIn("gsd/253-replan-main", server.refs)
            # the approval record exists in the receipt before the first request leaves the process
            self.assertIsNotNone(seen["receipt"], "receipt was not created before the first request")
            record = seen["receipt"]["action_approval"]
            self.assertEqual(set(record), {"path", "sha256", "section", "section_sha256", "commit", "window_wall_start_epoch"})
            self.assertEqual(record["section"], "docs_and_prs")
            self.assertEqual(record["section_sha256"], env["freeze"]["outward_actions_sha256"]["docs_and_prs"])
            self.assertEqual(record["sha256"], hashlib.sha256(docs_approval.read_bytes()).hexdigest())
            self.assertEqual(record["commit"], git_run(repo, "rev-list", "-1", "HEAD", "--", str(docs_approval.relative_to(repo))))
            self.assertIsInstance(record["window_wall_start_epoch"], int)
            self.assertLessEqual(record["window_wall_start_epoch"], int(time.time()))

    def test_publish_docs_refuses_every_unapproved_or_wrongly_scoped_approval_before_any_request(self):
        with tempfile.TemporaryDirectory(prefix="sigra-publish-docs-refusal-") as temp:
            env = self.freeze_environment(temp)
            allocation, ledger = self.production_allocation(env)
            whole = canonical_sha(env["freeze"]["outward_actions"])
            cases = {
                "canary-section approval": lambda: self.write_approval(env, "canary", name="a1"),
                "whole-manifest sha": lambda: self.write_approval(env, "docs_and_prs", section_sha=whole, name="a2"),
                "uncommitted file": lambda: self.write_approval(env, "docs_and_prs", commit=False, name="a3"),
                "modified file": lambda: self.write_approval(env, "docs_and_prs", tamper=True, name="a4"),
                "decision reject": lambda: self.write_approval(env, "docs_and_prs", decision="reject", name="a5"),
            }
            for label, make in cases.items():
                with self.subTest(label=label):
                    approval = make()
                    receipt_path = env["root"] / "refused-receipt.json"
                    result = subprocess.run(["python3", str(PUBLISHER), "--publish-docs", "--freeze", str(env["freeze_path"]), "--allocation",
                                             str(allocation), "--ledger", str(ledger), "--receipt", str(receipt_path), "--repo-root", str(env["repo"]),
                                             "--action-approval", str(approval)], cwd=ROOT, text=True, capture_output=True, timeout=30)
                    self.assertNotEqual(result.returncode, 0, label)
                    self.assertIn("approval", result.stderr.lower())
                    self.assertEqual(env["server"].journal, [], label)
                    self.assertFalse(ledger.exists(), label)
                    self.assertFalse(receipt_path.exists(), label)
            missing = subprocess.run(["python3", str(PUBLISHER), "--publish-docs", "--freeze", str(env["freeze_path"]), "--allocation", str(allocation),
                                      "--ledger", str(ledger), "--receipt", str(env["root"] / "r.json"), "--repo-root", str(env["repo"])],
                                     cwd=ROOT, text=True, capture_output=True)
            self.assertNotEqual(missing.returncode, 0)
            self.assertEqual(env["server"].journal, [])

    def test_publish_with_a_freeze_needs_the_canary_section_approval_and_a_live_allocation_needs_a_freeze(self):
        with tempfile.TemporaryDirectory(prefix="sigra-publish-canary-approval-") as temp:
            env = self.freeze_environment(temp)
            allocation, ledger = self.canary_allocation(env)
            wrong = self.write_approval(env, "docs_and_prs", name="wrong")
            result = subprocess.run(self.publish_args(env["manifest_path"], allocation, ledger, env["root"] / "r.json", env["repo"])
                                    + ["--freeze", str(env["freeze_path"]), "--action-approval", str(wrong)], cwd=ROOT, text=True, capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(env["server"].journal, [])
            live = json.loads(allocation.read_text())
            live.pop("test_origin"), live.pop("test_ca_file")
            live["mode"] = "live"
            allocation.write_text(json.dumps(live))
            unguarded = subprocess.run(self.publish_args(env["manifest_path"], allocation, ledger, env["root"] / "r2.json", env["repo"]),
                                       cwd=ROOT, text=True, capture_output=True, env=no_network_env(temp), timeout=30)
            self.assertNotEqual(unguarded.returncode, 0)
            self.assertIn("freeze", unguarded.stderr)
            self.assertFalse(ledger.exists(), "a live allocation reached the transport without a freeze")

    # -- the canary script drives the same publisher ------------------------------------------
    def test_canary_publish_only_drives_the_publisher_end_to_end_and_records_the_approval_first(self):
        with tempfile.TemporaryDirectory(prefix="sigra-canary-publish-only-") as temp:
            started = int(time.time())
            env = self.freeze_environment(temp)
            repo, server, manifest = env["repo"], env["server"], env["manifest"]
            allocation, ledger = self.canary_allocation(env)
            approval = self.write_approval(env, "canary")
            evidence = env["phase"] / "253-LOAD-RECOVERY-CANARY-EVIDENCE.json"
            receipt = env["phase"] / "253-LOAD-RECOVERY-CANARY-PUBLICATION-RECEIPT.json"
            seen = {}
            server.first_hook = lambda: seen.update(evidence=json.loads(evidence.read_text()) if evidence.exists() else None)
            result = subprocess.run(["bash", str(repo / "scripts/ci/ci-gate-canary.sh"), "--publish-only", "--revision-freeze", str(env["freeze_path"]),
                                     "--action-approval", str(approval), "--http-allocation", str(allocation), "--requests", str(ledger),
                                     "--evidence", str(evidence), "--publication-receipt", str(receipt)],
                                    cwd=repo, text=True, capture_output=True, timeout=120)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr + json.dumps(server.journal))
            self.assertEqual(server.refs["gsd/253-replan-candidate"], manifest["candidate_helper_commit"])
            self.assertEqual(server.refs["gsd/253-replan-fixture"], manifest["fixture_workflow_commit"])
            self.assertLessEqual(len(server.journal), 24)
            first = seen["evidence"]["action_approval"]
            self.assertEqual(set(first), {"path", "sha256", "section", "section_sha256", "commit", "window_wall_start_epoch"})
            self.assertEqual(first["section"], "canary")
            self.assertGreaterEqual(first["window_wall_start_epoch"], started)
            final = json.loads(evidence.read_text())
            self.assertEqual(final["action_approval"], first)
            self.assertEqual(final["publication"]["origin"]["kind"], "hermetic")
            self.assertEqual(final["publication"]["request_count"], len(server.journal))
            verified = subprocess.run(["python3", str(PUBLISHER), "--verify-publication", str(receipt)], cwd=ROOT, text=True, capture_output=True)
            self.assertEqual(verified.returncode, 0, verified.stderr)
            stale = sorted(path.name for path in env["phase"].glob("253-RECOVERY-CANARY-*"))
            self.assertEqual(stale, [], "the registered flow wrote to the superseded RECOVERY output paths")


if __name__ == "__main__":
    unittest.main(verbosity=2)
