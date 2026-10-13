#!/usr/bin/env python3
"""Local Git object publication contracts; no GitHub access is used."""

import base64
import hashlib
import http.server
import json
import os
import pathlib
import subprocess
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]
PUBLISHER = ROOT / "scripts/ci/ci-git-publication.py"
TRANSPORT = ROOT / "scripts/ci/ci-hosted-transport.py"


def object_sha(kind, data):
    return hashlib.sha1(f"{kind} {len(data)}\0".encode() + data).hexdigest()


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
                                    "body": base64.b64encode(self.server.last_body).decode()})

    def _read(self):
        self.server.last_body = self.rfile.read(int(self.headers.get("Content-Length", "0")))
        return json.loads(self.server.last_body or b"{}")

    def do_GET(self):  # noqa: N802
        prefix = "/repos/szTheory/sigra/git/"
        if self.path.startswith(prefix + "commits/"):
            sha = self.path.removeprefix(prefix + "commits/")
            value = self.server.commits.get(sha)
            self._reply(200, value) if value else self._reply(404, {"message": "Not Found"})
            return
        if self.path.startswith(prefix + "blobs/"):
            sha = self.path.removeprefix(prefix + "blobs/")
            value = self.server.blobs.get(sha)
            self._reply(200, value) if value else self._reply(404, {"message": "Not Found"})
            return
        if self.path.startswith("/repos/szTheory/sigra/git/ref/heads/"):
            name = self.path.removeprefix("/repos/szTheory/sigra/git/ref/heads/")
            sha = self.server.refs.get(name)
            self._reply(200, {"ref": "refs/heads/" + name, "object": {"sha": sha}}) if sha else self._reply(404, {"message": "Not Found"})
            return
        self._reply(404, {"message": "Not Found"})

    def do_POST(self):  # noqa: N802
        value = self._read()
        prefix = "/repos/szTheory/sigra/git/"
        if self.path == prefix + "blobs":
            data = value.get("content", "").encode("utf-8") if value.get("encoding") == "utf-8" else base64.b64decode(value.get("content", ""), validate=True)
            sha = object_sha("blob", data)
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
                    self.server.blobs[sha] = {"sha": sha, "content": base64.b64encode(data).decode(), "size": len(data)}
                if sha not in self.server.blobs:
                    self._reply(422, {"message": "tree references unknown blob"})
                    return
                entries[path] = {"path": path, "mode": item["mode"], "type": "blob", "sha": sha}
            tree_bytes = b"".join(
                f"{entry['mode']} blob {entry['sha']}\t{path}\0".encode()
                for path, entry in sorted(entries.items())
            )
            sha = object_sha("tree", tree_bytes)
            self.server.tree_entries[sha] = entries
            self.server.trees[sha] = {"sha": sha, "tree": list(entries.values()), "truncated": False}
            self._reply(201, self.server.trees[sha])
            return
        if self.path == prefix + "commits":
            tree = value.get("tree")
            parents = [item["sha"] for item in value.get("parents", [])]
            if tree not in self.server.trees or any(parent not in self.server.commits for parent in parents):
                self._reply(422, {"message": "commit references unknown object"})
                return
            author, committer = value["author"], value["committer"]
            date = author["date"]
            def ident(item):
                stamp = item["date"].replace("-", "").replace(":", "")
                epoch = subprocess.check_output(["date", "-u", "-j", "-f", "%Y-%m-%dT%H:%M:%SZ", item["date"], "+%s"], text=True).strip()
                return f"{item['name']} <{item['email']}> {epoch} +0000"
            raw = f"tree {tree}\n" + "".join(f"parent {parent}\n" for parent in parents)
            raw += f"author {ident(author)}\ncommitter {ident(committer)}\n\n{value['message']}"
            sha = object_sha("commit", raw.encode())
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
            if name in self.server.refs:
                self._reply(422, {"message": "reference already exists"})
                return
            self.server.refs[name] = sha
            self._reply(201, {"ref": ref, "object": {"sha": sha}})
            return
        self._reply(404, {"message": "Not Found"})

    def log_message(self, *_args):
        pass


class PublicationTests(unittest.TestCase):
    def test_prepare_reports_complete_product_tree_request_that_exceeds_hard_body_limit(self):
        with tempfile.TemporaryDirectory(prefix="sigra-publication-proposal-") as temp:
            output = pathlib.Path(temp) / "proposal.json"
            result = subprocess.run(["python3", str(PUBLISHER), "--prepare", "--candidate-source",
                                     subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
                                     "--server-parent", subprocess.check_output(["git", "rev-parse", "origin/main"], cwd=ROOT, text=True).strip(),
                                     "--output", str(output)], cwd=ROOT, text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            manifest = json.loads(output.read_text())
            self.assertEqual(manifest["status"], "blocked")
            self.assertGreater(manifest["projection"]["largest_tree_body_bytes"], 2 * 1024 * 1024)
            self.assertFalse(manifest["projection"]["complete_product_delta_dropped"])

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


if __name__ == "__main__":
    unittest.main(verbosity=2)
