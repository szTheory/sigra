#!/usr/bin/env python3
"""Local Git object publication contracts; no GitHub access is used."""

import base64
import hashlib
import http.server
import io
import json
import os
import pathlib
import re
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
PRESERVED_CONFIG_FIXTURE_B64 = (
    "ewogICJtb2RlbF9wcm9maWxlIjogImFkYXB0aXZlIiwKICAiY29tbWl0X2RvY3MiOiB0cnVlLAog"
    "ICJwYXJhbGxlbGl6YXRpb24iOiB0cnVlLAogICJzZWFyY2hfZ2l0aWdub3JlZCI6IGZhbHNlLAog"
    "ICJicmF2ZV9zZWFyY2giOiBmYWxzZSwKICAiZmlyZWNyYXdsIjogZmFsc2UsCiAgImV4YV9zZWFy"
    "Y2giOiBmYWxzZSwKICAiZ2l0IjogewogICAgImNyZWF0ZV90YWciOiBmYWxzZSwKICAgICJicmFu"
    "Y2hpbmdfc3RyYXRlZ3kiOiAibm9uZSIsCiAgICAicGhhc2VfYnJhbmNoX3RlbXBsYXRlIjogImdz"
    "ZC9waGFzZS17cGhhc2V9LXtzbHVnfSIsCiAgICAibWlsZXN0b25lX2JyYW5jaF90ZW1wbGF0ZSI6"
    "ICJnc2Qve21pbGVzdG9uZX0te3NsdWd9IiwKICAgICJxdWlja19icmFuY2hfdGVtcGxhdGUiOiBu"
    "dWxsCiAgfSwKICAid29ya2Zsb3ciOiB7CiAgICAicmVzZWFyY2giOiB0cnVlLAogICAgInBsYW5f"
    "Y2hlY2siOiB0cnVlLAogICAgInZlcmlmaWVyIjogdHJ1ZSwKICAgICJhaV9pbnRlZ3JhdGlvbl9w"
    "aGFzZSI6IHRydWUsCiAgICAibnlxdWlzdF92YWxpZGF0aW9uIjogdHJ1ZSwKICAgICJhdXRvX2Fk"
    "dmFuY2UiOiBmYWxzZSwKICAgICJub2RlX3JlcGFpciI6IHRydWUsCiAgICAibm9kZV9yZXBhaXJf"
    "YnVkZ2V0IjogMiwKICAgICJ1aV9waGFzZSI6IHRydWUsCiAgICAidWlfc2FmZXR5X2dhdGUiOiB0"
    "cnVlLAogICAgInRleHRfbW9kZSI6IGZhbHNlLAogICAgInJlc2VhcmNoX2JlZm9yZV9xdWVzdGlv"
    "bnMiOiB0cnVlLAogICAgImRpc2N1c3NfbW9kZSI6ICJhc3N1bXB0aW9ucyIsCiAgICAic2tpcF9k"
    "aXNjdXNzIjogZmFsc2UsCiAgICAiX2F1dG9fY2hhaW5fYWN0aXZlIjogZmFsc2UsCiAgICAiZGlz"
    "Y3Vzc19jb21wcmVoZW5zaXZlX3Jlc2VhcmNoIjogdHJ1ZSwKICAgICJkaXNjdXNzX3N5bnRoZXNp"
    "emVfd2hlbl91c2VyX2RlbGVnYXRlcyI6IHRydWUsCiAgICAiZGlzY3Vzc19hbHdheXNfc3VyZmFj"
    "ZV9mb3JfdXNlciI6IFsKICAgICAgInNlbXZlcl9vcl9wdWJsaWNfYXBpX2JyZWFrIiwKICAgICAg"
    "InNlY3VyaXR5X21vZGVsX3ZzX293YXNwX2RvYyIsCiAgICAgICJnZW5lcmF0b3Jfb3JfaG9zdF9j"
    "b250cmFjdF9vdXRwdXQiCiAgICBdLAogICAgInVzZV93b3JrdHJlZXMiOiBmYWxzZQogIH0sCiAg"
    "InNpZ3JhX2RlZmF1bHRzIjogewogICAgImF1ZGl0X2F0b21pY2l0eV9kb2MiOiAiLnBsYW5uaW5n"
    "L0FVRElULUFUT01JQ0lUWS1ERUZBVUxUUy5tZCIsCiAgICAibm90ZSI6ICJTdWJhZ2VudC1iYWNr"
    "ZWQgZGVmYXVsdHMgZnJvbSBQaGFzZSA4MCBkaXNjdXNzOyBsb2FkIGZvciBTRUVELTAwMiAvIGF1"
    "ZGl0IE11bHRpIHBoYXNlcyB1bmxlc3MgQ09OVEVYVCBvdmVycmlkZXMuIgogIH0sCiAgImhvb2tz"
    "IjogewogICAgImNvbnRleHRfd2FybmluZ3MiOiB0cnVlCiAgfSwKICAicHJvamVjdF9jb2RlIjog"
    "bnVsbCwKICAicGhhc2VfbmFtaW5nIjogInNlcXVlbnRpYWwiLAogICJhZ2VudF9za2lsbHMiOiB7"
    "fSwKICAibW9kZSI6ICJ5b2xvIiwKICAiZ3JhbnVsYXJpdHkiOiAiZmluZSIsCiAgIm1vZGVsX3By"
    "b2ZpbGVfb3ZlcnJpZGVzIjogewogICAgImNvZGV4IjogewogICAgICAib3B1cyI6ICJncHQtNi4x"
    "LXNvbCIsCiAgICAgICJzb25uZXQiOiAiZ3B0LTYtbHVuYSIsCiAgICAgICJoYWlrdSI6ICJncHQt"
    "Ni1sdW5hIgogICAgfSwKICAgICJjbGF1ZGUiOiB7CiAgICAgICJvcHVzIjogImNsYXVkZS1vcHVz"
    "LTUtNSIsCiAgICAgICJzb25uZXQiOiAiY2xhdWRlLW9wdXMtNS01IiwKICAgICAgImhhaWt1Ijog"
    "ImNsYXVkZS1zb25uZXQtNS01IgogICAgfQogIH0KfQo="
)
PRESERVED_CONFIG_FIXTURE_SHA256 = "8e312f6ccd3485941059446e5852b39651f7ad1863fa003c62f6e5635d7c0b8d"


def object_sha(kind, data):
    return hashlib.sha1(f"{kind} {len(data)}\0".encode() + data).hexdigest()


PHASE_REL = ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks"
HELPER_COPIES = ("scripts/ci/ci-gate-canary.sh", "scripts/ci/ci-git-publication.py", "scripts/ci/ci-hosted-gate-verify.py",
                 "scripts/ci/ci-hosted-transport.py", "scripts/ci/ci-pr-proof.sh", "scripts/ci/ci-browser-records.mjs",
                 "scripts/ci/honest-skip-verdict.sh")
HELPER_DUMMIES = ("scripts/ci/ci-gate-canary.test.sh", "scripts/ci/ci-git-publication.test.py",
                  "scripts/ci/ci-hosted-gate-verify.test.py", "scripts/ci/ci-pr-proof.test.sh")
_REAL_FIXTURE = pathlib.Path(__file__).resolve().parents[2] / PHASE_REL / "253-LOAD-RECOVERY-CANARY-WORKFLOW.yml"
FIXTURE_TEXT = (_REAL_FIXTURE.read_text() if _REAL_FIXTURE.exists()
                else "name: Phase 253 Gate Canary\non:\n  workflow_dispatch:\n    inputs: {}\npermissions:\n  contents: read\njobs: {}\n")
OBSERVERS = (".github/workflows/ci-observe.yml", ".github/workflows/release-pr-automerge.yml", ".github/workflows/release-run-observer.yml")


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
        for rel in OBSERVERS:
            (root / rel).write_bytes((ROOT / rel).read_bytes())
        for rel in HELPER_DUMMIES:
            (root / rel).write_text(f"# placeholder for {rel}\n")
        phase = root / PHASE_REL
        phase.mkdir(parents=True)
        (phase / "253-LOAD-RECOVERY-CANARY-WORKFLOW.yml").write_text(FIXTURE_TEXT)
        (phase / "253-PREHOST-REVIEW.md").write_text("# review\n")
        for name in ("ACCEPTANCE-EVIDENCE", "TARGET-DISPOSITION", "TARGET-DISPOSITION-APPROVAL"):
            (phase / f"253-LOAD-RECOVERY-{name}.json").write_text(json.dumps({"fixture": name}) + "\n")
        paths += ["scripts", ".planning", ".github/workflows"]
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


MISSING = object()


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

    def _wire_commit(self, value):
        """GitHub's commit JSON drops exactly one trailing newline from the stored message.

        The stored object (and so its sha) keeps the newline-terminated bytes. The
        echo_message_verbatim flag restores the older fixture behaviour.
        """
        message = value.get("message")
        if (not self.server.flags.get("echo_message_verbatim") and isinstance(message, str)
                and message.endswith("\n")):
            return dict(value, message=message[:-1])
        return value

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
            value = self._wire_commit(value) if value else value
            override = self.server.flags.get("readback_message")
            if value and override is not None and sha != self.server.parent_sha:
                value = {k: v for k, v in value.items() if k != "message"}
                sent = self.server.commits[sha]["message"]
                replaced = override(sent)
                if replaced is not MISSING:
                    value["message"] = replaced
            if value and self.server.flags.get("readback_other_sha") and sha != self.server.parent_sha:
                value = dict(value, sha="e" * 40)
            self._reply(200, value) if value else self._reply(404, {"message": "Not Found"})
            return
        if self.path.startswith(prefix + "blobs/"):
            sha = self.path.removeprefix(prefix + "blobs/")
            value = self.server.blobs.get(sha)
            if value:
                raw = base64.b64decode(value["content"])
                if self.server.flags.get("alter_blob_readback") and sha != self.server.parent_sha:
                    raw = bytes([raw[0] ^ 1]) + raw[1:]
                    self.server.flags["alter_blob_readback"] = False
                encoded = base64.b64encode(raw).decode()
                # GitHub wraps blob base64 in 60-character lines, each ending with a newline.
                wrapped = "".join(encoded[i:i + 60] + "\n" for i in range(0, len(encoded), 60))
                if len(encoded) > 60:
                    self.server.flags["multiline_blob_reads"] = self.server.flags.get("multiline_blob_reads", 0) + 1
                value = dict(value, content=wrapped)
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
            self._reply(201, self._wire_commit(result))
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

    def test_candidate_carries_exact_reviewed_inputs_and_rejects_changed_bytes(self):
        import importlib.util
        spec = importlib.util.spec_from_file_location("publication_inputs", PUBLISHER)
        publisher = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(publisher)
        with tempfile.TemporaryDirectory() as temp:
            repo = pathlib.Path(temp) / "repo"
            parent, _ = git_fixture(repo)
            selected = ".planning/archived/required.txt"
            excluded = ".planning/private-runtime.txt"
            for rel in (selected, excluded):
                (repo / rel).parent.mkdir(parents=True, exist_ok=True)
                (repo / rel).write_text("original bytes\n")
            manifest = repo / "scripts/ci/ci-candidate-inputs.json"
            manifest.parent.mkdir(parents=True)
            value = {"schema_version": "sigra.ci-candidate-inputs/v1",
                     "inputs": {selected: hashlib.sha256((repo / selected).read_bytes()).hexdigest()}}
            manifest.write_text(json.dumps(value))
            subprocess.run(["git", "-C", str(repo), "add", "."], check=True)
            subprocess.run(["git", "-C", str(repo), "commit", "-qm", "immutable inputs"], check=True)
            source = subprocess.check_output(["git", "-C", str(repo), "rev-parse", "HEAD"], text=True).strip()
            fixture = repo / ".planning/canary.yml"
            fixture.write_text("name: canary\n")
            result = publisher.source_variants(repo, source, parent, fixture_file=".planning/canary.yml")
            candidate = publisher.tree_entries(repo, result["candidate_helper_commit"])
            self.assertEqual(candidate[selected], publisher.tree_entries(repo, source)[selected])
            self.assertNotIn(excluded, candidate)
            (repo / selected).write_text("changed bytes\n")
            subprocess.run(["git", "-C", str(repo), "add", "."], check=True)
            subprocess.run(["git", "-C", str(repo), "commit", "-qm", "tampered input"], check=True)
            source = subprocess.check_output(["git", "-C", str(repo), "rev-parse", "HEAD"], text=True).strip()
            with self.assertRaisesRegex(publisher.PublicationError, "immutable input hash differs"):
                publisher.source_variants(repo, source, parent, fixture_file=".planning/canary.yml")

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

    def make_local_publication(self, temp, flags=None, many_entries=0, helpers=False, prepare_args=(), allocation=None,
                               main_record=False):
        temp_path = pathlib.Path(temp)
        repo = temp_path / "repo"
        parent, source = git_fixture(repo, many_entries=many_entries, helpers=helpers)
        manifest_path = temp_path / "manifest.json"
        if main_record:
            # 253-138: a main-fetch record naming the synthetic server parent, with the local origin/main at it.
            prepare_args = (*prepare_args, "--main-record", write_main_record(repo, parent))
            git_run(repo, "update-ref", "refs/remotes/origin/main", parent)
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
            commit_rows = [row for row in receipt["server_object_receipts"] if row.get("kind") == "commit"]
            self.assertEqual(sorted(row["variant"] for row in commit_rows), ["candidate", "fixture"])
            for row in commit_rows:
                self.assertTrue(row["message"].endswith("\n"))
                self.assertEqual(row["server_message_form"], "trailing_newline_stripped")
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

    def test_publication_also_accepts_a_server_that_echoes_the_commit_message_verbatim(self):
        with tempfile.TemporaryDirectory(prefix="sigra-object-publication-verbatim-") as temp:
            repo, parent, source, manifest_path, manifest, allocation, ledger_path, server, root = self.make_local_publication(
                temp, {"echo_message_verbatim": True})
            receipt_path = root / "publication-receipt.json"
            result = subprocess.run(["python3", str(PUBLISHER), "--publish", "--manifest", str(manifest_path),
                                    "--allocation", str(allocation), "--ledger", str(ledger_path),
                                    "--receipt", str(receipt_path), "--repo-root", str(repo)],
                                   cwd=ROOT, text=True, capture_output=True, timeout=45)
            self.assertEqual(result.returncode, 0, result.stderr + json.dumps(server.journal))
            receipt = json.loads(receipt_path.read_text())
            commit_rows = [row for row in receipt["server_object_receipts"] if row.get("kind") == "commit"]
            self.assertEqual([row["server_message_form"] for row in commit_rows], ["verbatim", "verbatim"])
            check = subprocess.run(["python3", str(PUBLISHER), "--verify-publication", str(receipt_path)],
                                   cwd=ROOT, text=True, capture_output=True)
            self.assertEqual(check.returncode, 0, check.stderr)

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

    def publish_against(self, flags):
        with tempfile.TemporaryDirectory(prefix="sigra-object-readback-") as temp:
            repo, parent, source, manifest_path, manifest, allocation, ledger_path, server, root = self.make_local_publication(temp, flags)
            result = subprocess.run(["python3", str(PUBLISHER), "--publish", "--manifest", str(manifest_path),
                                     "--allocation", str(allocation), "--ledger", str(ledger_path), "--receipt", str(root / "receipt.json"),
                                     "--repo-root", str(repo)], cwd=ROOT, text=True, capture_output=True, timeout=45)
            return result, server, len(json.loads(ledger_path.read_text())["transactions"])

    def test_commit_message_matches_accepts_only_equality_or_one_stripped_newline(self):
        import importlib.util
        spec = importlib.util.spec_from_file_location("ci_git_publication_unit", PUBLISHER)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        sent = "Phase 253 frozen CI candidate\n"
        for label, server_message in {"stripped": sent[:-1], "verbatim": sent}.items():
            with self.subTest(label):
                self.assertTrue(module.commit_message_matches(server_message, sent))
        for label, server_message in {
            "one extra newline": sent + "\n", "two characters stripped": sent[:-2], "crlf": sent[:-1] + "\r\n",
            "trailing space": sent[:-1] + " ", "stripped plus space newline": sent[:-1] + " \n", "empty": "",
            "missing": None, "non-string": 5, "list": [sent], "unrelated": "other\n", "case change": sent.lower(),
        }.items():
            with self.subTest(label):
                self.assertFalse(module.commit_message_matches(server_message, sent))
        self.assertFalse(module.commit_message_matches(sent, None))
        self.assertFalse(module.commit_message_matches("a", "ab\n"))

    def test_every_other_commit_message_readback_is_rejected_after_charge_without_a_ref(self):
        cases = {
            "one extra newline": lambda sent: sent + "\n",
            "two characters stripped": lambda sent: sent[:-2],
            "crlf": lambda sent: sent[:-1] + "\r\n",
            "trailing space": lambda sent: sent[:-1] + " ",
            "missing message": lambda sent: MISSING,
            "non-string message": lambda sent: 5,
            "unrelated message": lambda sent: "unrelated\n",
        }
        for label, mutate in cases.items():
            with self.subTest(label):
                result, server, ledger_rows = self.publish_against({"readback_message": mutate})
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("server commit readback differs for candidate", result.stderr)
                self.assertEqual(server.refs, {})
                self.assertTrue(all(row["charged"] for row in server.journal))
                self.assertEqual(len(server.journal), ledger_rows)

    def test_a_tolerated_stripped_message_with_a_different_sha_is_still_rejected(self):
        result, server, _ = self.publish_against({"readback_other_sha": True})
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("server commit readback differs for candidate", result.stderr)
        self.assertEqual(server.refs, {})

    def test_wrapped_github_blob_base64_is_accepted_and_a_changed_wrapped_byte_is_rejected(self):
        with tempfile.TemporaryDirectory(prefix="sigra-object-wrapped-blob-") as temp:
            repo, parent, source, manifest_path, manifest, allocation, ledger_path, server, root = self.make_local_publication(temp)
            result = subprocess.run(["python3", str(PUBLISHER), "--publish", "--manifest", str(manifest_path),
                                     "--allocation", str(allocation), "--ledger", str(ledger_path), "--receipt", str(root / "receipt.json"),
                                     "--repo-root", str(repo)], cwd=ROOT, text=True, capture_output=True, timeout=45)
            self.assertEqual(result.returncode, 0, result.stderr)
            blob_reads = [row for row in server.journal if "/git/blobs/" in row["path"] and row["method"] == "GET"]
            self.assertTrue(blob_reads)
            self.assertGreater(server.flags.get("multiline_blob_reads", 0), 0, "no multi-line wrapped blob was served")
        result, server, _ = self.publish_against({"alter_blob_readback": True})
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("server workflow blob readback differs for candidate", result.stderr)
        self.assertEqual(server.refs, {})

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

    def run_preserved_config_case(self, *, config_bytes=None, stage_config=False, preservation_ref=True,
                                  ref_bytes=None, dirty_product=False, clean_config=False):
        with tempfile.TemporaryDirectory(prefix="sigra-exact-config-") as temp:
            repo = pathlib.Path(temp) / "repo"
            parent, source = git_fixture(repo)
            (repo / ".planning").mkdir()
            config_path = repo / ".planning/config.json"
            config_path.write_bytes(b"baseline config\n" if clean_config else b"baseline config\n")
            subprocess.run(["git", "-C", str(repo), "add", str(config_path)], check=True)
            subprocess.run(["git", "-C", str(repo), "commit", "-qm", "tracked config baseline"], check=True)
            source = subprocess.check_output(["git", "-C", str(repo), "rev-parse", "HEAD"], text=True).strip()
            if not clean_config:
                exact_bytes = base64.b64decode(PRESERVED_CONFIG_FIXTURE_B64, validate=True)
                self.assertEqual(hashlib.sha256(exact_bytes).hexdigest(), PRESERVED_CONFIG_FIXTURE_SHA256)
                config_path.write_bytes(exact_bytes if config_bytes is None else config_bytes)
                if stage_config:
                    subprocess.run(["git", "-C", str(repo), "add", str(config_path)], check=True)
                if preservation_ref:
                    ref_payload = exact_bytes if ref_bytes is None else ref_bytes
                    blob = subprocess.check_output(["git", "-C", str(repo), "hash-object", "-w", "--stdin"],
                                                   input=ref_payload, text=False).decode().strip()
                    subprocess.run(["git", "-C", str(repo), "update-ref",
                                    "refs/gsd/phase253-recovery-execution-unrelated-config", blob], check=True)
                evidence = repo / ".planning/runtime/evidence.log"
                evidence.parent.mkdir(parents=True)
                evidence.write_text("local runtime evidence is not product source\n")
            if dirty_product:
                (repo / "app.txt").write_text("uncommitted product change\n")
            output = pathlib.Path(temp) / "proposal.json"
            result = subprocess.run(["python3", str(PUBLISHER), "--prepare", "--candidate-source", source,
                                     "--server-parent", parent, "--repo-root", str(repo), "--output", str(output)],
                                    cwd=ROOT, text=True, capture_output=True)
            return result, (output.read_bytes() if output.exists() else None), output.exists()

    def test_exact_preserved_config_status_and_bytes_allow_only_planning_metadata_changes(self):
        result, payload, exists = self.run_preserved_config_case()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(exists)
        manifest = json.loads(payload)
        self.assertTrue(manifest["source_cleanliness"]["clean"])
        self.assertEqual(manifest["source_cleanliness"]["config_status_hex"],
                         b" M .planning/config.json\0".hex())
        self.assertEqual(manifest["source_cleanliness"]["config_ref"],
                         "refs/gsd/phase253-recovery-execution-unrelated-config")
        self.assertEqual(manifest["source_cleanliness"]["config_sha256"], PRESERVED_CONFIG_FIXTURE_SHA256)

    def test_preserved_config_independent_byte_and_trailing_newline_drift_is_rejected(self):
        exact_bytes = base64.b64decode(PRESERVED_CONFIG_FIXTURE_B64, validate=True)
        for label, changed in (("content byte", exact_bytes.replace(b"adaptive", b"AdaptivE", 1)),
                               ("trailing newline", exact_bytes[:-1])):
            with self.subTest(label=label):
                result, payload, exists = self.run_preserved_config_case(config_bytes=changed)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("dirty outside the exact preserved config", result.stderr)
                self.assertFalse(exists)

    def test_preserved_config_staged_exact_bytes_are_rejected(self):
        result, payload, exists = self.run_preserved_config_case(stage_config=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("dirty outside the exact preserved config", result.stderr)
        self.assertFalse(exists)

    def test_preserved_config_missing_preservation_ref_is_rejected(self):
        result, payload, exists = self.run_preserved_config_case(preservation_ref=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("dirty outside the exact preserved config", result.stderr)
        self.assertFalse(exists)

    def test_preserved_config_ref_pointing_at_different_bytes_is_rejected(self):
        result, payload, exists = self.run_preserved_config_case(ref_bytes=b"not the preserved historical config\n")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("dirty outside the exact preserved config", result.stderr)
        self.assertFalse(exists)

    def test_preserved_config_does_not_allow_dirty_product_source(self):
        result, payload, exists = self.run_preserved_config_case(dirty_product=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("dirty outside the exact preserved config", result.stderr)
        self.assertFalse(exists)

    def test_preserved_config_clean_committed_config_uses_ordinary_clean_path(self):
        result, payload, exists = self.run_preserved_config_case(clean_config=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(exists)
        cleanliness = json.loads(payload)["source_cleanliness"]
        self.assertTrue(cleanliness["clean"])
        self.assertIsNone(cleanliness["config_ref"])
        self.assertEqual(cleanliness["config_status_hex"], "")

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


MAIN_RECORD_REL = f"{PHASE_REL}/253-LOAD-RECOVERY-MAIN-FETCH-R12.json"


def write_main_record(repo, fetched, rel=MAIN_RECORD_REL, **overrides):
    """253-138: a sigra.phase253.main-fetch/r12 record (the 253-136 field names) naming `fetched` as the fresh main."""
    record = {"schema_version": "sigra.phase253.main-fetch/r12", "status": "fetched",
              "command": "git fetch --no-tags origin main", "fetched_main_sha": fetched, "fetch_head_sha": fetched,
              "fetched_at_utc": "2026-10-19T03:43:56Z", "anomalies": []}
    record.update(overrides)
    for key in [key for key, value in record.items() if value is MISSING]:
        del record[key]
    path = pathlib.Path(repo) / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(record, indent=2) + "\n")
    return rel


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

    def freeze_environment(self, temp, ref_pair=None, **kwargs):
        """A registered publication plus a committed publication manifest and a built, committed freeze."""
        repo, parent, source, manifest_path, manifest, allocation, ledger_path, server, root = self.prepare_registered(temp, **kwargs)
        phase = repo / PHASE_REL
        manifest_rel = f"{PHASE_REL}/253-LOAD-RECOVERY-CANARY-PUBLICATION.json"
        (repo / manifest_rel).write_bytes(manifest_path.read_bytes())
        freeze_rel = f"{PHASE_REL}/253-LOAD-RECOVERY-CANARY-FREEZE.json"
        git_run(repo, "add", manifest_rel)
        if kwargs.get("main_record"):
            git_run(repo, "add", MAIN_RECORD_REL)
        git_run(repo, "-c", "user.name=Fixture", "-c", "user.email=fixture@example.test", "commit", "-qm", "planning: publication manifest")
        built = subprocess.run(["python3", str(PUBLISHER), "--build-freeze", "--manifest", manifest_rel, "--output", freeze_rel,
                                "--repo-root", str(repo), *(["--ref-pair", ref_pair] if ref_pair else [])],
                               cwd=ROOT, text=True, capture_output=True)
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
                receipt["publication_transactions"] = [{"sequence": tx["sequence"], "sha256": canonical_sha(tx)} for tx in ledger["transactions"]]
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
                    if tx["route_id"] in ("git_create_commit", "git_get_commit"):
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
            allocation, _ = self.canary_allocation(env)
            ledger = env["phase"] / "253-LOAD-RECOVERY-CANARY-REQUESTS.json"
            server.ledger_path = str(ledger)
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
            self.assertEqual(final["expected"]["fixture_ref_state"], "hermetic-unverified",
                             "a hermetic publication must never mark the fixture ref verified")
            published = json.loads(receipt.read_text())
            self.assertEqual(published["action_approval"]["window_wall_start_epoch"], first["window_wall_start_epoch"],
                             "the publisher and the evidence record one shared window start")
            self.assertEqual(final["publication"]["origin"]["kind"], "hermetic")
            self.assertEqual(final["publication"]["request_count"], len(server.journal))
            verified = subprocess.run(["python3", str(PUBLISHER), "--verify-publication", str(receipt)], cwd=ROOT, text=True, capture_output=True)
            self.assertEqual(verified.returncode, 0, verified.stderr)
            stale = sorted(path.name for path in env["phase"].glob("253-RECOVERY-CANARY-*"))
            self.assertEqual(stale, [], "the registered flow wrote to the superseded RECOVERY output paths")



def module_rows(ledger, category):
    return load_publisher().category_rows(ledger, category)


class ReviewRemediationTests(unittest.TestCase):
    """Fixes for the final code review of the 253-91 product changes."""

    make_local_publication = PublicationTests.make_local_publication
    prepare_registered = RegisteredPublicationTests.prepare_registered
    freeze_environment = RegisteredPublicationTests.freeze_environment
    write_approval = RegisteredPublicationTests.write_approval
    canary_allocation = RegisteredPublicationTests.canary_allocation
    production_allocation = RegisteredPublicationTests.production_allocation

    def test_a_publication_receipt_stays_verifiable_after_later_requests_join_the_shared_ledger(self):
        with tempfile.TemporaryDirectory(prefix="sigra-receipt-growth-") as temp:
            env = self.freeze_environment(temp)
            allocation, ledger = self.canary_allocation(env)
            approval = self.write_approval(env, "canary")
            receipt = env["root"] / "growth-receipt.json"
            result = subprocess.run(RegisteredPublicationTests.publish_args(self, env["manifest_path"], allocation, ledger, receipt, env["repo"])
                                    + ["--freeze", str(env["freeze_path"]), "--action-approval", str(approval)],
                                    cwd=ROOT, text=True, capture_output=True, timeout=90)
            self.assertEqual(result.returncode, 0, result.stderr)
            def verify():
                return subprocess.run(["python3", str(PUBLISHER), "--verify-publication", str(receipt)], cwd=ROOT, text=True, capture_output=True)
            self.assertEqual(verify().returncode, 0)
            published_count = json.loads(receipt.read_text())["request_count"]
            grown = json.loads(ledger.read_text())
            grown["transactions"].append({"sequence": len(grown["transactions"]) + 1, "route_id": "rate_limit", "state": "pending",
                                          "category": "preflight", "host": "api.github.com"})
            ledger.write_text(json.dumps(grown))
            self.assertEqual(verify().returncode, 0, "later requests in the shared ledger must not invalidate the pinned publication")
            original_status = grown["transactions"][2]["actual_status"]
            grown["transactions"][2]["actual_status"] = 500
            ledger.write_text(json.dumps(grown))
            tampered = verify()
            self.assertNotEqual(tampered.returncode, 0)
            self.assertIn("pinned publication transaction", tampered.stderr)
            grown["transactions"][2]["actual_status"] = original_status
            ledger.write_text(json.dumps(grown))
            self.assertEqual(verify().returncode, 0)
            doubled = json.loads(receipt.read_text())
            doubled["publication_transactions"] = doubled["publication_transactions"][:1] * 2
            doubled["request_count"] = 2
            receipt.write_text(json.dumps(doubled))
            duplicate = verify()
            self.assertNotEqual(duplicate.returncode, 0)
            self.assertIn("unique", duplicate.stderr)
            self.assertEqual(len(module_rows(json.loads(ledger.read_text()), "publication")), published_count)

    def test_a_recorded_window_start_is_never_moved_by_a_retry(self):
        module = load_publisher()
        with tempfile.TemporaryDirectory(prefix="sigra-window-keep-") as temp:
            receipt = pathlib.Path(temp) / "receipt.json"
            record = {"path": "a.json", "sha256": "a" * 64, "section": "canary", "section_sha256": "b" * 64, "commit": "c" * 40,
                      "window_wall_start_epoch": None}
            module.write_receipt_stub(receipt, dict(record), 1791909000)
            self.assertEqual(json.loads(receipt.read_text())["action_approval"]["window_wall_start_epoch"], 1791909000)
            retry = dict(record)
            module.write_receipt_stub(receipt, retry, 1791909000)
            self.assertEqual(retry["window_wall_start_epoch"], 1791909000)
            unspecified = dict(record)
            module.write_receipt_stub(receipt, unspecified)
            self.assertEqual(unspecified["window_wall_start_epoch"], 1791909000)
            with self.assertRaises(module.PublicationError):
                module.write_receipt_stub(receipt, dict(record), 1791999999)
            other = dict(record, section_sha256="d" * 64)
            module.write_receipt_stub(receipt, other, 1791999999)
            self.assertEqual(other["window_wall_start_epoch"], 1791999999, "a different approval opens a different window")

    def test_publish_docs_applies_the_full_freeze_policy_before_any_request(self):
        with tempfile.TemporaryDirectory(prefix="sigra-publish-docs-policy-") as temp:
            env = self.freeze_environment(temp)
            approval = self.write_approval(env, "docs_and_prs")
            original = env["freeze_path"].read_text()
            value = json.loads(original)
            value["expired_reruns"]["pull_requests"]["status"] = "available"
            env["freeze_path"].write_text(json.dumps(value, indent=2))
            allocation, ledger = self.production_allocation(env)
            result = subprocess.run(["python3", str(PUBLISHER), "--publish-docs", "--freeze", str(env["freeze_path"]), "--allocation", str(allocation),
                                     "--ledger", str(ledger), "--receipt", str(env["root"] / "r.json"), "--repo-root", str(env["repo"]),
                                     "--action-approval", str(approval)], cwd=ROOT, text=True, capture_output=True, timeout=30)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("expired reruns", result.stderr)
            self.assertEqual(env["server"].journal, [])
            self.assertFalse(ledger.exists())

    def test_the_canary_script_never_depends_on_ripgrep_for_a_guard(self):
        text = (ROOT / "scripts/ci/ci-gate-canary.sh").read_text()
        self.assertEqual(re.findall(r"(?m)^(?!\s*#).*(?<![-\w])rg\s", text), [])

    def test_live_modes_work_from_another_directory_with_relative_paths(self):
        with tempfile.TemporaryDirectory(prefix="sigra-relative-paths-") as temp:
            env = self.freeze_environment(temp)
            allocation = LiveModeApprovalTests.live_allocation(self, env)
            approval = self.write_approval(env, "canary")
            evidence = env["phase"] / "253-LOAD-RECOVERY-CANARY-EVIDENCE.json"
            process_env, marker, snapshot = LiveModeApprovalTests.recording_env(self, temp, evidence)
            elsewhere = env["repo"] / "scripts"
            relative = lambda path: os.path.relpath(path, elsewhere)
            result = subprocess.run(["bash", os.path.relpath(env["repo"] / CANARY_SCRIPT_RELATIVE, elsewhere), "--preflight-only",
                                     "--revision-freeze", relative(env["freeze_path"]), "--action-approval", relative(approval),
                                     "--http-allocation", relative(allocation)],
                                    cwd=elsewhere, text=True, capture_output=True, env=process_env, timeout=120)
            self.assertNotEqual(result.returncode, 0, "the stub has no credentials, so the first transaction fails")
            self.assertEqual(marker.read_text().splitlines(), ["gh auth token"], result.stderr)
            self.assertIn("action_approval", json.loads(snapshot.read_text()))

    def test_relative_evidence_and_ledger_paths_are_anchored_where_the_script_was_invoked(self):
        with tempfile.TemporaryDirectory(prefix="sigra-relative-evidence-") as temp:
            env = self.freeze_environment(temp)
            allocation = LiveModeApprovalTests.live_allocation(self, env)
            approval = self.write_approval(env, "canary")
            evidence = env["phase"] / "anchored-evidence.json"
            ledger = env["phase"] / "anchored-ledger.json"
            process_env, marker, snapshot = LiveModeApprovalTests.recording_env(self, temp, evidence)
            elsewhere = env["phase"]
            result = subprocess.run(["bash", os.path.relpath(env["repo"] / CANARY_SCRIPT_RELATIVE, elsewhere), "--preflight-only",
                                     "--revision-freeze", os.path.relpath(env["freeze_path"], elsewhere), "--action-approval",
                                     os.path.relpath(approval, elsewhere), "--http-allocation", os.path.relpath(allocation, elsewhere),
                                     "--evidence", "anchored-evidence.json", "--requests", "anchored-ledger.json"],
                                    cwd=elsewhere, text=True, capture_output=True, env=process_env, timeout=120)
            self.assertNotEqual(result.returncode, 0)
            self.assertTrue(evidence.exists() and ledger.exists(), result.stderr)
            self.assertFalse((env["repo"] / "anchored-evidence.json").exists())

    def test_publish_only_refuses_evidence_without_a_recorded_window_start(self):
        with tempfile.TemporaryDirectory(prefix="sigra-window-guard-") as temp:
            env = self.freeze_environment(temp)
            allocation, _ = self.canary_allocation(env)
            ledger = env["phase"] / "253-LOAD-RECOVERY-CANARY-REQUESTS.json"
            approval = self.write_approval(env, "canary")
            evidence = env["phase"] / "253-LOAD-RECOVERY-CANARY-EVIDENCE.json"
            evidence.write_text(json.dumps({"schema_version": "sigra.phase253.hosted-replan-evidence/v2",
                                            "action_approval": {"section_sha256": env["freeze"]["outward_actions_sha256"]["canary"]}}))
            result = subprocess.run(["bash", str(env["repo"] / CANARY_SCRIPT_RELATIVE), "--publish-only", "--revision-freeze", str(env["freeze_path"]),
                                     "--action-approval", str(approval), "--http-allocation", str(allocation), "--requests", str(ledger),
                                     "--evidence", str(evidence)], cwd=env["repo"], text=True, capture_output=True, timeout=60)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("window start", result.stderr)
            self.assertEqual(env["server"].journal, [])
            self.assertFalse(ledger.exists())

    def test_publish_only_marks_nothing_verified_for_a_hermetic_allocation_and_requires_live_origin_otherwise(self):
        source = (ROOT / "scripts/ci/ci-gate-canary.sh").read_text()
        self.assertIn("--verify-publication \"$PUBLICATION_RECEIPT\" --require-live-origin", source)
        self.assertIn("REF_STATE=hermetic-unverified", source)


CANARY_SCRIPT_RELATIVE = "scripts/ci/ci-gate-canary.sh"
LIVE_MODES = (("--preflight-only",), ("--publish-ref-only",), ("--publish-only",), ("--scenario", "full-pass"), ("--remaining-scenarios",))


class LiveModeApprovalTests(unittest.TestCase):
    """Per-section approval, expired reruns and native_target re-hash enforced by the canary script (253-91 Task 2)."""

    make_local_publication = PublicationTests.make_local_publication
    prepare_registered = RegisteredPublicationTests.prepare_registered
    freeze_environment = RegisteredPublicationTests.freeze_environment
    write_approval = RegisteredPublicationTests.write_approval
    canary_allocation = RegisteredPublicationTests.canary_allocation

    def live_allocation(self, env):
        value = {"schema_version": "sigra.phase253.http-allocation/v1", "window_id": "live-test-window",
                 "source_sha256": hashlib.sha256(env["freeze_path"].read_bytes()).hexdigest(), "max_requests": 117,
                 "max_elapsed_seconds": 3600, "max_response_bytes": 4 * 1024 * 1024, "max_pages": 3, "max_hops": 2,
                 "repository": "szTheory/sigra", "download_hosts": [], "mode": "live", "allocation_kind": "canary"}
        path = env["root"] / "live-allocation.json"
        path.write_text(json.dumps(value))
        return path

    def recording_env(self, temp, evidence):
        stub_dir = pathlib.Path(temp) / "rec-bin"
        stub_dir.mkdir(exist_ok=True)
        marker, snapshot = pathlib.Path(temp) / "calls", pathlib.Path(temp) / "evidence-at-first-call.json"
        for name in ("gh", "curl"):
            stub = stub_dir / name
            stub.write_text(f'#!/bin/sh\nprintf "{name} %s\\n" "$*" >> "{marker}"\n'
                            f'[ -f "{evidence}" ] && cp "{evidence}" "{snapshot}"\nexit 1\n')
            stub.chmod(0o755)
        env = {key: value for key, value in os.environ.items() if key not in {"GH_TOKEN", "GITHUB_TOKEN"}}
        env["PATH"] = f"{stub_dir}:{env['PATH']}"
        env["HOME"] = str(temp)
        return env, marker, snapshot

    def canary(self, env, args, *, process_env=None, timeout=120):
        return subprocess.run(["bash", str(env["repo"] / CANARY_SCRIPT_RELATIVE), *args], cwd=env["repo"], text=True,
                              capture_output=True, env=process_env, timeout=timeout)

    def mutate_freeze(self, env, mutate):
        original = env["freeze_path"].read_text()
        value = json.loads(original)
        mutate(value)
        env["freeze_path"].write_text(json.dumps(value, indent=2))
        return original

    # -- strict freeze policy ----------------------------------------------------------------
    def test_build_freeze_plan_defaults_to_253_91_and_accepts_only_a_plan_id_override(self):
        with tempfile.TemporaryDirectory(prefix="sigra-freeze-plan-") as temp:
            env = self.freeze_environment(temp)
            repo = env["repo"]
            self.assertEqual(env["freeze"]["plan"], "253-91")
            for bad in ("", "253-9", "253-95x", "x253-95", "253-95\n253-96", "../253-95", "254-95", "253-095"):
                with self.subTest(bad=bad):
                    refused = subprocess.run(["python3", str(PUBLISHER), "--build-freeze", "--manifest", env["manifest_rel"],
                                              "--output", f"{PHASE_REL}/bad-freeze.json", "--freeze-plan", bad,
                                              "--repo-root", str(repo)], cwd=ROOT, text=True, capture_output=True)
                    self.assertNotEqual(refused.returncode, 0)
                    self.assertFalse((repo / PHASE_REL / "bad-freeze.json").exists())
            alt_rel = f"{PHASE_REL}/253-LOAD-RECOVERY-CANARY-FREEZE-ALT.json"
            built = subprocess.run(["python3", str(PUBLISHER), "--build-freeze", "--manifest", env["manifest_rel"],
                                    "--output", alt_rel, "--freeze-plan", "253-95", "--repo-root", str(repo)],
                                   cwd=ROOT, text=True, capture_output=True)
            self.assertEqual(built.returncode, 0, built.stderr)
            alt = json.loads((repo / alt_rel).read_text())
            self.assertEqual(alt["plan"], "253-95")
            self.assertEqual(alt["outward_actions_sha256"], env["freeze"]["outward_actions_sha256"])
            self.assertEqual({k: v for k, v in alt.items() if k != "plan"}, {k: v for k, v in env["freeze"].items() if k != "plan"})

    def test_check_freeze_enforces_expired_reruns_native_target_bounds_and_categories(self):
        with tempfile.TemporaryDirectory(prefix="sigra-freeze-policy-") as temp:
            env = self.freeze_environment(temp)
            def check():
                return subprocess.run(["python3", str(PUBLISHER), "--check-freeze", str(env["freeze_path"]), "--repo-root", str(env["repo"])],
                                      cwd=ROOT, text=True, capture_output=True)
            self.assertEqual(check().returncode, 0, check().stderr)
            native = env["freeze"]["native_target"]
            self.assertEqual(native["route"], "not_reproduced_disposition")
            self.assertEqual(env["freeze"]["scenarios"]["optional_infrastructure_retry"], 0)
            self.assertEqual(env["freeze"]["scenarios"]["retry_status"], "expired")
            self.assertEqual(env["freeze"]["bounds"]["new_measured_max_requests"], 117)
            self.assertEqual(sum(env["freeze"]["categories"]["canary"].values()), 117)
            mutations = {
                "one optional retry": lambda v: v["scenarios"].update(optional_infrastructure_retry=1),
                "retry not expired": lambda v: v["scenarios"].update(retry_status="available"),
                "canary rerun available": lambda v: v["expired_reruns"]["canary"].update(status="available"),
                "canary rerun used": lambda v: v["expired_reruns"]["canary"].update(used=1),
                "PR rerun available": lambda v: v["expired_reruns"]["pull_requests"].update(status="available"),
                "PR rerun wrong reason": lambda v: v["expired_reruns"]["pull_requests"].update(reason="maybe later"),
                "native_target missing": lambda v: v.pop("native_target"),
                "native route unknown": lambda v: v["native_target"].update(route="invented"),
                "acceptance hash wrong": lambda v: v["native_target"]["acceptance_evidence"].update(sha256="0" * 64),
                "acceptance hash missing": lambda v: v["native_target"]["acceptance_evidence"].pop("sha256"),
                "disposition hash wrong": lambda v: v["native_target"]["disposition"].update(sha256="1" * 64),
                "disposition missing": lambda v: v["native_target"].pop("disposition"),
                "approval hash wrong": lambda v: v["native_target"]["disposition_approval"].update(sha256="2" * 64),
                "approval path escapes": lambda v: v["native_target"]["disposition_approval"].update(path="../outside.json"),
                "note changed": lambda v: v["native_target"].update(note="CIREL-01 accepted"),
                "time bound changed": lambda v: v["bounds"].update(max_minutes=61),
                "canary category changed": lambda v: v["categories"]["canary"].update(publication=25),
                "production category changed": lambda v: v["categories"]["production"].update(infrastructure_rerun=20),
                "historical http claimed exact": lambda v: v["historical"].update(previous_exact_http_count_proven=True),
                "old failed run changed": lambda v: v["identity"].update(old_failed_run_id="1"),
                "clock starts late": lambda v: v["clock"].update(begins="after_preflight"),
            }
            for label, mutate in mutations.items():
                with self.subTest(label=label):
                    original = self.mutate_freeze(env, mutate)
                    try:
                        self.assertNotEqual(check().returncode, 0, label)
                    finally:
                        env["freeze_path"].write_text(original)
            # a re-hash is against the bytes on disk: change a bound disposition file instead of the freeze
            target = env["repo"] / env["freeze"]["native_target"]["disposition"]["path"]
            original = target.read_text()
            target.write_text(original + " ")
            try:
                self.assertNotEqual(check().returncode, 0, "changed disposition bytes were accepted")
            finally:
                target.write_text(original)
            self.assertEqual(check().returncode, 0)

    def test_check_only_applies_the_revision_policy_without_approval_or_network(self):
        with tempfile.TemporaryDirectory(prefix="sigra-check-only-revision-") as temp:
            env = self.freeze_environment(temp)
            process_env, marker, _ = self.recording_env(temp, env["phase"] / "none.json")
            ok = self.canary(env, ["--check-only", "--revision-freeze", str(env["freeze_path"])], process_env=process_env)
            self.assertEqual(ok.returncode, 0, ok.stdout + ok.stderr)
            self.assertIn("local fixture contract passed", ok.stdout)
            self.assertFalse(marker.exists())
            original = self.mutate_freeze(env, lambda v: v["scenarios"].update(optional_infrastructure_retry=1))
            bad = self.canary(env, ["--check-only", "--revision-freeze", str(env["freeze_path"])], process_env=process_env)
            self.assertNotEqual(bad.returncode, 0)
            env["freeze_path"].write_text(original)
            original = self.mutate_freeze(env, lambda v: v["native_target"]["acceptance_evidence"].update(sha256="3" * 64))
            bad = self.canary(env, ["--check-only", "--revision-freeze", str(env["freeze_path"])], process_env=process_env)
            self.assertNotEqual(bad.returncode, 0)
            self.assertFalse(marker.exists())

    # -- live-mode approval gate -------------------------------------------------------------
    def test_every_live_mode_refuses_without_the_committed_canary_section_approval_before_any_request(self):
        with tempfile.TemporaryDirectory(prefix="sigra-live-refusal-") as temp:
            env = self.freeze_environment(temp)
            allocation = self.live_allocation(env)
            evidence = env["phase"] / "253-LOAD-RECOVERY-CANARY-EVIDENCE.json"
            ledger = env["phase"] / "253-LOAD-RECOVERY-CANARY-REQUESTS.json"
            process_env, marker, _ = self.recording_env(temp, evidence)
            whole = canonical_sha(env["freeze"]["outward_actions"])
            approvals = {
                "no approval": None,
                "docs_and_prs approval": lambda: self.write_approval(env, "docs_and_prs", name="b1"),
                "whole-manifest sha": lambda: self.write_approval(env, "canary", section_sha=whole, name="b2"),
                "uncommitted file": lambda: self.write_approval(env, "canary", commit=False, name="b3"),
                "modified file": lambda: self.write_approval(env, "canary", tamper=True, name="b4"),
                "decision reject": lambda: self.write_approval(env, "canary", decision="reject", name="b5"),
            }
            for label, make in approvals.items():
                approval = make() if make else None
                for mode in LIVE_MODES:
                    with self.subTest(approval=label, mode=mode[0]):
                        args = [*mode, "--revision-freeze", str(env["freeze_path"]), "--http-allocation", str(allocation)]
                        if approval is not None:
                            args += ["--action-approval", str(approval)]
                        result = self.canary(env, args, process_env=process_env, timeout=60)
                        self.assertNotEqual(result.returncode, 0)
                        self.assertIn("approval", result.stderr.lower())
                        self.assertFalse(marker.exists(), "a GitHub command was attempted before the approval check")
                        self.assertFalse(evidence.exists())
                        self.assertFalse(ledger.exists())
            self.assertEqual(sorted(path.name for path in env["phase"].glob("253-RECOVERY-CANARY-*")), [])

    def test_first_transaction_follows_the_recorded_action_approval(self):
        with tempfile.TemporaryDirectory(prefix="sigra-live-first-transaction-") as temp:
            started = int(time.time())
            env = self.freeze_environment(temp)
            allocation = self.live_allocation(env)
            approval = self.write_approval(env, "canary")
            evidence = env["phase"] / "253-LOAD-RECOVERY-CANARY-EVIDENCE.json"
            process_env, marker, snapshot = self.recording_env(temp, evidence)
            result = self.canary(env, ["--preflight-only", "--revision-freeze", str(env["freeze_path"]), "--action-approval", str(approval),
                                       "--http-allocation", str(allocation)], process_env=process_env)
            self.assertNotEqual(result.returncode, 0, "the stub has no GitHub credentials, so the first transaction must fail")
            calls = marker.read_text().splitlines()
            self.assertEqual(calls, ["gh auth token"], "only the credential lookup ran; no network command was issued")
            at_first_call = json.loads(snapshot.read_text())
            record = at_first_call["action_approval"]
            self.assertEqual(set(record), {"path", "sha256", "section", "section_sha256", "commit", "window_wall_start_epoch"})
            self.assertEqual(record["section"], "canary")
            self.assertEqual(record["section_sha256"], env["freeze"]["outward_actions_sha256"]["canary"])
            self.assertEqual(record["sha256"], hashlib.sha256(approval.read_bytes()).hexdigest())
            self.assertEqual(record["commit"], git_run(env["repo"], "rev-list", "-1", "HEAD", "--", str(approval.relative_to(env["repo"]))))
            self.assertGreaterEqual(record["window_wall_start_epoch"], started)
            self.assertLessEqual(record["window_wall_start_epoch"], int(time.time()))
            ledger = json.loads((env["phase"] / "253-LOAD-RECOVERY-CANARY-REQUESTS.json").read_text())
            self.assertEqual(len(ledger["transactions"]), 1)
            self.assertEqual(ledger["transactions"][0]["error"]["code"], "authentication_unavailable")
            self.assertEqual(ledger["transactions"][0]["category"], "preflight",
                             "every canary request is charged to its frozen category (rate_limit before the first preflight read)")
            self.assertEqual(sorted(path.name for path in env["phase"].glob("253-RECOVERY-CANARY-*")), [])

    def test_a_halted_window_and_rerun_flags_are_refused_before_any_request(self):
        with tempfile.TemporaryDirectory(prefix="sigra-live-rerun-") as temp:
            env = self.freeze_environment(temp)
            allocation = self.live_allocation(env)
            approval = self.write_approval(env, "canary")
            evidence = env["phase"] / "253-LOAD-RECOVERY-CANARY-EVIDENCE.json"
            process_env, marker, _ = self.recording_env(temp, evidence)
            for flag in ("--rerun", "--retry-infrastructure", "--rerun-failed"):
                with self.subTest(flag=flag):
                    result = self.canary(env, [flag, "--revision-freeze", str(env["freeze_path"]), "--action-approval", str(approval),
                                               "--http-allocation", str(allocation)], process_env=process_env)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn("rerun", result.stderr.lower())
                    self.assertFalse(marker.exists())
            evidence.write_text(json.dumps({"schema_version": "sigra.phase253.hosted-replan-evidence/v2", "status": "halted",
                                            "diagnostics": [{"kind": "canary-stop"}]}))
            before = evidence.read_bytes()
            halted = self.canary(env, ["--preflight-only", "--revision-freeze", str(env["freeze_path"]), "--action-approval", str(approval),
                                       "--http-allocation", str(allocation)], process_env=process_env)
            self.assertNotEqual(halted.returncode, 0)
            self.assertIn("halted", halted.stderr)
            self.assertFalse(marker.exists())
            self.assertEqual(evidence.read_bytes(), before)

    def test_mutations_outside_the_approved_canary_section_are_refused(self):
        with tempfile.TemporaryDirectory(prefix="sigra-listed-actions-") as temp:
            env = self.freeze_environment(temp)
            source = (ROOT / "scripts/ci/ci-gate-canary.sh").read_text()
            match = re.search(r"^require_listed\(\) \{.*?^\}", source, re.M | re.S)
            self.assertIsNotNone(match, "the canary script has no require_listed guard")
            fixture = env["freeze"]["identity"]
            candidate, fixture_sha, blob = fixture["candidate_helper_commit"], fixture["fixture_workflow_commit"], fixture["fixture_workflow_blob"]
            def listed(want):
                script = ('set -euo pipefail\nfail() { echo "FAIL: $*" >&2; exit 1; }\n'
                          f'REVISION_FREEZE={env["freeze_path"]}\n{match.group(0)}\nrequire_listed \'{json.dumps(want)}\'\n')
                return subprocess.run(["bash", "-c", script], text=True, capture_output=True)
            inputs = {"scenario": "full-pass", "candidate_sha": candidate, "fixture_sha": fixture_sha, "fixture_blob": blob}
            accepted = {
                "candidate ref": {"action": "create_ref", "ref": "refs/heads/gsd/253-replan-candidate", "sha": candidate},
                "fixture ref": {"action": "create_ref", "ref": "refs/heads/gsd/253-replan-fixture", "sha": fixture_sha},
                "full-pass dispatch": {"action": "workflow_dispatch", "ref": "gsd/253-replan-fixture", "inputs": inputs},
                "cancelled dispatch": {"action": "workflow_dispatch", "ref": "gsd/253-replan-fixture", "inputs": {**inputs, "scenario": "cancelled"}},
                "verifier dispatch": {"action": "workflow_dispatch", "ref": "gsd/253-replan-fixture",
                                      "inputs": {**inputs, "scenario": "verifier"}},
                "identified cancellation": {"action": "cancel_run", "scenario": "cancelled"},
            }
            refused = {
                "ref on main": {"action": "create_ref", "ref": "refs/heads/main", "sha": candidate},
                "fixture ref wrong sha": {"action": "create_ref", "ref": "refs/heads/gsd/253-replan-fixture", "sha": candidate},
                "tag ref": {"action": "create_ref", "ref": "refs/tags/v1", "sha": candidate},
                "unknown scenario": {"action": "workflow_dispatch", "ref": "gsd/253-replan-fixture", "inputs": {**inputs, "scenario": "extra"}},
                "wrong fixture sha": {"action": "workflow_dispatch", "ref": "gsd/253-replan-fixture", "inputs": {**inputs, "fixture_sha": "9" * 40}},
                "dispatch on main": {"action": "workflow_dispatch", "ref": "main", "inputs": inputs},
                "cancel another scenario": {"action": "cancel_run", "scenario": "full-pass"},
                "pull request create": {"action": "pr_create", "head": "gsd/253-replan-candidate", "base": "main", "draft": True},
                "dispatch with fewer inputs": {"action": "workflow_dispatch", "ref": "gsd/253-replan-fixture",
                                               "inputs": {key: value for key, value in inputs.items() if key != "fixture_blob"}},
                "dispatch with an extra input": {"action": "workflow_dispatch", "ref": "gsd/253-replan-fixture",
                                                 "inputs": {**inputs, "extra": "x"}},
                "rerun": {"action": "rerun", "scenario": "full-pass"},
                "merge": {"action": "merge"},
            }
            for label, want in accepted.items():
                with self.subTest(accepted=label):
                    result = listed(want)
                    self.assertEqual(result.returncode, 0, result.stderr)
            for label, want in refused.items():
                with self.subTest(refused=label):
                    self.assertNotEqual(listed(want).returncode, 0, label)

    # -- bounded serialization --------------------------------------------------------------
    def test_compact_matrix_payload_is_bounded_gzip_base64_and_decodes_with_the_verifier(self):
        import importlib.util, gzip
        spec = importlib.util.spec_from_file_location("hosted_gate_verify_for_matrix", ROOT / "scripts/ci/ci-hosted-gate-verify.py")
        verifier = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(verifier)
        with tempfile.TemporaryDirectory(prefix="sigra-compact-matrix-") as temp:
            evidence = pathlib.Path(temp) / "evidence.json"
            full = {"schema_version": "sigra.phase253.hosted-replan-evidence/v2", "repository": "szTheory/sigra",
                    "expected": {"candidate_sha": "a" * 40}, "budget": {"actual_jobs": 36},
                    "scenarios": {"full-pass": {"run": {"id": 1}}}, "transport_ledger": {"transactions": [{"x": "y" * 5000}] * 50},
                    "transport_receipts": [{"x": "z" * 5000}] * 50, "preserved_revisions": ["ignored"], "preflight": {"big": "q" * 100000}}
            evidence.write_text(json.dumps(full))
            result = subprocess.run(["python3", str(PUBLISHER), "--compact-matrix", str(evidence)], cwd=ROOT, text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            payload = result.stdout.strip()
            self.assertLessEqual(len(payload), 65535)
            self.assertEqual(gzip.decompress(base64.b64decode(payload, validate=True))[:1], b"{")
            decoded = verifier.decode_matrix_payload(payload)
            self.assertEqual(set(decoded), {"schema_version", "repository", "expected", "scenarios", "budget"})
            self.assertEqual(decoded["budget"], {"actual_jobs": 36})
            self.assertNotIn("transport_ledger", decoded)
            noisy = dict(full, scenarios={"full-pass": {"blob": os.urandom(60000).hex()}})
            evidence.write_text(json.dumps(noisy))
            over = subprocess.run(["python3", str(PUBLISHER), "--compact-matrix", str(evidence)], cwd=ROOT, text=True, capture_output=True)
            self.assertNotEqual(over.returncode, 0)
            self.assertIn("65535", over.stderr)
            self.assertEqual(over.stdout, "")

    def test_canary_artifact_extraction_enforces_the_zip_limits(self):
        import zipfile
        def archive(members, compression=zipfile.ZIP_DEFLATED):
            buffer = io.BytesIO()
            with zipfile.ZipFile(buffer, "w", compression=compression) as bundle:
                for name, data in members:
                    bundle.writestr(name, data)
            return buffer.getvalue()
        with tempfile.TemporaryDirectory(prefix="sigra-zip-limits-") as temp:
            def extract(data):
                path = pathlib.Path(temp) / "artifact.zip"
                path.write_bytes(data)
                return subprocess.run(["python3", str(PUBLISHER), "--extract-canary-artifact", str(path)], cwd=ROOT, text=True, capture_output=True)
            good = extract(archive([("canary-result.json", b'{"scenario":"full-pass"}\n')]))
            self.assertEqual(good.returncode, 0, good.stderr)
            value = json.loads(good.stdout)
            self.assertEqual(value["file"]["json"], {"scenario": "full-pass"})
            self.assertEqual(value["archive_sha256"], hashlib.sha256((pathlib.Path(temp) / "artifact.zip").read_bytes()).hexdigest())
            bad = {
                "extra member": archive([("canary-result.json", b"{}"), ("other.json", b"{}")]),
                "wrong member": archive([("result.json", b"{}")]),
                "directory traversal": archive([("../canary-result.json", b"{}")]),
                "extracted over 4 MiB": archive([("canary-result.json", b'{"a":"' + b"x" * (4 * 1024 * 1024) + b'"}')]),
                "compressed over 2 MiB": archive([("canary-result.json", b'{"a":"' + os.urandom(1100000).hex().encode() + b'"}')],
                                                 compression=zipfile.ZIP_STORED),
                "not JSON": archive([("canary-result.json", b"not json")]),
                "not a zip": b"PK\x03\x04 truncated",
            }
            for label, data in bad.items():
                with self.subTest(label=label):
                    rejected = extract(data)
                    self.assertNotEqual(rejected.returncode, 0, label)
                    self.assertEqual(rejected.stdout, "")


LEGACY_PAIR = ("refs/heads/gsd/253-replan-candidate", "refs/heads/gsd/253-replan-fixture")
R8_PAIR = ("refs/heads/gsd/253-replan-r8-candidate", "refs/heads/gsd/253-replan-r8-fixture")
R9_PAIR = ("refs/heads/gsd/253-replan-r9-candidate", "refs/heads/gsd/253-replan-r9-fixture")
R10_PAIR = ("refs/heads/gsd/253-replan-r10-candidate", "refs/heads/gsd/253-replan-r10-fixture")
R11_PAIR = ("refs/heads/gsd/253-replan-r11-candidate", "refs/heads/gsd/253-replan-r11-fixture")
# 253-111: r9 became a known pair, so the unknown-name probes moved to r10. 253-119: r10 became a known pair, so they
# moved to r11. 253-130: r11 is now a known pair too, so they used r12.
# 253-137: r12 is now a known pair too, so they used r13.
# 253-166: r13 is now a known pair too, so they use r14, a name that is never pinned.
UNKNOWN_PAIR = ("refs/heads/gsd/253-replan-r14-candidate", "refs/heads/gsd/253-replan-r14-fixture")
FREEZE_R10_DIGESTS = {"canary": "3ef4162bbff963b0613635729104476fd3d83c081de9c8b9ad8bf6bc531504fe",
                      "docs_and_prs": "a3734ed5b1445ef41fa1d77afc37fe7f787f9e0cf6e3e32e83b2a5be9f1c3c7b"}
FREEZE_R9_DIGESTS = {"canary": "f4210ba50fbc1a3bc94e45f8c7091b4083c45d80076a890596e1fc269c708b4a",
                     "docs_and_prs": "5f8b394a8ce66929839f4344a5617f0ff1c28a86028156b97ecbf47fb8ad9e0e"}
FREEZE_R8_DIGESTS = {"canary": "e272c040ecb6533f775340885bfac68a917f3da8866ab1312947aba32af54cc7",
                     "docs_and_prs": "083a4ce31dd0c036319a0cd3a54b95fbba0d2d71e2fb360b75c9f3ec247ba183"}
EARLIER_FREEZE_DIGESTS = {
    "253-LOAD-RECOVERY-CANARY-FREEZE-R7.json": {"canary": "9059971bd427cf05cd49a26a8b06bb4176f4b65c266b8fa4e555399aeaf1c67d",
                                                "docs_and_prs": "c2f66af0143ff604317cc5a4df97f8f919f5f92a5a13e3bc7d4aec05ef087ca4"},
    "253-LOAD-RECOVERY-CANARY-FREEZE.json": {"canary": "678e2576b2aec98434410aeb6b1ed9ab257fce850ade6737277c6287b902a071",
                                             "docs_and_prs": "5d15af53e2c0f4fff002b436fa80a0f872815f818172880f951282f7ff337138"},
}


class RefPairTests(unittest.TestCase):
    """253-102: the freeze selects one of exactly two code-pinned scoped ref pairs; the legacy pair stays the default."""

    make_local_publication = PublicationTests.make_local_publication
    prepare_registered = RegisteredPublicationTests.prepare_registered
    freeze_environment = RegisteredPublicationTests.freeze_environment
    write_approval = RegisteredPublicationTests.write_approval
    canary_allocation = RegisteredPublicationTests.canary_allocation
    publish_args = RegisteredPublicationTests.publish_args

    def test_exactly_seven_ref_pairs_exist_and_legacy_is_the_default(self):
        module = load_publisher()
        self.assertEqual(module.REF_PAIRS, {
            "legacy": {"candidate": "gsd/253-replan-candidate", "fixture": "gsd/253-replan-fixture"},
            "r8": {"candidate": "gsd/253-replan-r8-candidate", "fixture": "gsd/253-replan-r8-fixture"},
            "r9": {"candidate": "gsd/253-replan-r9-candidate", "fixture": "gsd/253-replan-r9-fixture"},
            "r10": {"candidate": "gsd/253-replan-r10-candidate", "fixture": "gsd/253-replan-r10-fixture"},
            "r11": {"candidate": "gsd/253-replan-r11-candidate", "fixture": "gsd/253-replan-r11-fixture"},
            "r12": {"candidate": "gsd/253-replan-r12-candidate", "fixture": "gsd/253-replan-r12-fixture"},
            "r13": {"candidate": "gsd/253-replan-r13-candidate", "fixture": "gsd/253-replan-r13-fixture"}})
        self.assertEqual(module.DEFAULT_REF_PAIR, "legacy")
        self.assertEqual(module.ref_pair_name(*LEGACY_PAIR), "legacy")
        self.assertEqual(module.ref_pair_name(*R8_PAIR), "r8")
        self.assertEqual(module.ref_pair_name(*R9_PAIR), "r9")
        self.assertEqual(module.ref_pair_name(*R10_PAIR), "r10")
        self.assertEqual(module.ref_pair_name(*R11_PAIR), "r11")
        for mixed in ((LEGACY_PAIR[0], R8_PAIR[1]), (R8_PAIR[0], LEGACY_PAIR[1]), (R8_PAIR[1], R8_PAIR[0]),
                      (R9_PAIR[0], R8_PAIR[1]), (R8_PAIR[0], R9_PAIR[1]), (R9_PAIR[0], LEGACY_PAIR[1]),
                      (LEGACY_PAIR[0], R9_PAIR[1]), (R9_PAIR[1], R9_PAIR[0]),
                      (R10_PAIR[0], R9_PAIR[1]), (R9_PAIR[0], R10_PAIR[1]), (R10_PAIR[0], R8_PAIR[1]),
                      (R8_PAIR[0], R10_PAIR[1]), (R10_PAIR[0], LEGACY_PAIR[1]), (R10_PAIR[1], R10_PAIR[0]),
                      (R11_PAIR[0], R10_PAIR[1]), (R10_PAIR[0], R11_PAIR[1]), (R11_PAIR[0], R9_PAIR[1]),
                      (R9_PAIR[0], R11_PAIR[1]), (R11_PAIR[0], R8_PAIR[1]), (R11_PAIR[0], LEGACY_PAIR[1]),
                      (R11_PAIR[1], R11_PAIR[0]), UNKNOWN_PAIR,
                      ("gsd/253-replan-candidate", "gsd/253-replan-fixture"), (None, None)):
            with self.subTest(mixed=mixed):
                with self.assertRaises(module.PublicationError):
                    module.ref_pair_name(*mixed)

    def test_both_earlier_freezes_replay_their_recorded_section_digests_exactly(self):
        module = load_publisher()
        for name, digests in EARLIER_FREEZE_DIGESTS.items():
            with self.subTest(freeze=name):
                freeze = json.loads((ROOT / PHASE_REL / name).read_text())
                self.assertEqual((freeze["identity"]["candidate_ref"], freeze["identity"]["fixture_ref"]), LEGACY_PAIR)
                sections, derived = module.build_outward_actions(freeze["identity"])
                self.assertEqual(derived, digests)
                self.assertEqual(freeze["outward_actions_sha256"], digests)
                self.assertEqual(sections, freeze["outward_actions"])

    def test_an_r8_identity_moves_every_candidate_and_fixture_ref_and_a_mixed_identity_is_refused(self):
        module = load_publisher()
        r7 = json.loads((ROOT / PHASE_REL / "253-LOAD-RECOVERY-CANARY-FREEZE-R7.json").read_text())["identity"]
        identity = {**r7, "candidate_ref": R8_PAIR[0], "fixture_ref": R8_PAIR[1]}
        sections, digests = module.build_outward_actions(identity)
        canary, docs = sections["canary"]["actions"], sections["docs_and_prs"]["actions"]
        self.assertEqual([a["ref"] for a in canary if a["action"] == "create_ref"], list(R8_PAIR))
        self.assertEqual({a["ref"] for a in canary if a["action"] == "workflow_dispatch"}, {"gsd/253-replan-r8-fixture"})
        self.assertEqual([a["run_identity"]["head_branch"] for a in canary if a["action"] == "cancel_run"], ["gsd/253-replan-r8-fixture"])
        prs = {a["family"]: (a["head"], a["base"]) for a in docs if a["action"] == "pr_create"}
        self.assertEqual(prs, {"normal": ("gsd/253-replan-r8-candidate", "main"),
                               "docs-only": ("gsd/253-replan-docs-head", "gsd/253-replan-docs-base")})
        self.assertEqual(docs[0]["refs"], [{"ref": "refs/heads/gsd/253-replan-docs-base", "sha": r7["docs_base_commit"]},
                                           {"ref": "refs/heads/gsd/253-replan-docs-head", "sha": r7["docs_head_commit"]}])
        self.assertNotIn("gsd/253-replan-candidate\"", json.dumps(sections))
        self.assertNotIn("gsd/253-replan-fixture\"", json.dumps(sections))
        for section, value in EARLIER_FREEZE_DIGESTS["253-LOAD-RECOVERY-CANARY-FREEZE-R7.json"].items():
            self.assertNotEqual(digests[section], value)
        for mixed in ({"candidate_ref": R8_PAIR[0]}, {"fixture_ref": R8_PAIR[1]},
                      {"candidate_ref": UNKNOWN_PAIR[0], "fixture_ref": UNKNOWN_PAIR[1]}):
            with self.subTest(mixed=mixed):
                with self.assertRaises(module.PublicationError):
                    module.build_outward_actions({**r7, **mixed})

    def test_build_freeze_selects_the_pair_refuses_unknown_pairs_and_accepts_three_digit_plans(self):
        with tempfile.TemporaryDirectory(prefix="sigra-ref-pair-freeze-") as temp:
            env = self.freeze_environment(temp)
            repo = env["repo"]
            self.assertEqual((env["freeze"]["identity"]["candidate_ref"], env["freeze"]["identity"]["fixture_ref"]), LEGACY_PAIR)

            def build(rel, *extra):
                return subprocess.run(["python3", str(PUBLISHER), "--build-freeze", "--manifest", env["manifest_rel"],
                                       "--output", rel, "--repo-root", str(repo), *extra], cwd=ROOT, text=True, capture_output=True)
            for bad in ("", "r14", "R8", "R9", "legacy,r8", "r8,r9", "r9 ", "candidate"):
                with self.subTest(pair=bad):
                    refused = build(f"{PHASE_REL}/bad-pair.json", "--ref-pair", bad)
                    self.assertNotEqual(refused.returncode, 0)
                    self.assertFalse((repo / PHASE_REL / "bad-pair.json").exists())
            for bad in ("253-095", "253-1000", "253-10a", "253-1"):
                with self.subTest(plan=bad):
                    refused = build(f"{PHASE_REL}/bad-plan.json", "--freeze-plan", bad)
                    self.assertNotEqual(refused.returncode, 0)
                    self.assertFalse((repo / PHASE_REL / "bad-plan.json").exists())
            r8_rel = f"{PHASE_REL}/253-LOAD-RECOVERY-CANARY-FREEZE-R8.json"
            built = build(r8_rel, "--freeze-plan", "253-102", "--ref-pair", "r8")
            self.assertEqual(built.returncode, 0, built.stderr)
            r8 = json.loads((repo / r8_rel).read_text())
            self.assertEqual(r8["plan"], "253-102")
            self.assertEqual((r8["identity"]["candidate_ref"], r8["identity"]["fixture_ref"]), R8_PAIR)
            self.assertNotEqual(r8["outward_actions_sha256"], env["freeze"]["outward_actions_sha256"])
            git_run(repo, "add", r8_rel)
            git_run(repo, "-c", "user.name=Fixture", "-c", "user.email=fixture@example.test", "commit", "-qm", "planning: r8 freeze")
            legacy_explicit = build(f"{PHASE_REL}/legacy-explicit.json", "--ref-pair", "legacy")
            self.assertEqual(legacy_explicit.returncode, 0, legacy_explicit.stderr)
            self.assertEqual(json.loads((repo / PHASE_REL / "legacy-explicit.json").read_text()), env["freeze"])
            (repo / PHASE_REL / "legacy-explicit.json").unlink()
            checked = subprocess.run(["python3", str(PUBLISHER), "--check-freeze", str(repo / r8_rel), "--repo-root", str(repo)],
                                     cwd=ROOT, text=True, capture_output=True)
            self.assertEqual(checked.returncode, 0, checked.stderr)

    def test_check_freeze_refuses_a_mixed_pair_or_a_third_name(self):
        with tempfile.TemporaryDirectory(prefix="sigra-ref-pair-check-") as temp:
            env = self.freeze_environment(temp, ref_pair="r8")
            original = env["freeze_path"].read_text()

            def check():
                return subprocess.run(["python3", str(PUBLISHER), "--check-freeze", str(env["freeze_path"]), "--repo-root", str(env["repo"])],
                                      cwd=ROOT, text=True, capture_output=True)
            self.assertEqual(check().returncode, 0, check().stderr)
            for label, refs in {"legacy candidate with r8 fixture": (LEGACY_PAIR[0], R8_PAIR[1]),
                                "r8 candidate with legacy fixture": (R8_PAIR[0], LEGACY_PAIR[1]),
                                "fourth pair": UNKNOWN_PAIR,
                                "fixture as candidate": (R8_PAIR[1], R8_PAIR[1])}.items():
                with self.subTest(label=label):
                    value = json.loads(original)
                    value["identity"]["candidate_ref"], value["identity"]["fixture_ref"] = refs
                    env["freeze_path"].write_text(json.dumps(value, indent=2))
                    refused = check()
                    self.assertNotEqual(refused.returncode, 0, label)
                    self.assertIn("ref", refused.stderr)
            env["freeze_path"].write_text(original)
            self.assertEqual(check().returncode, 0)

    def seed_legacy_refs(self, env):
        seeded = {"gsd/253-replan-candidate": env["parent"], "gsd/253-replan-fixture": env["parent"]}
        env["server"].refs.update(seeded)
        return dict(seeded)

    def test_r8_publication_creates_only_the_r8_refs_end_to_end_and_leaves_seeded_legacy_refs_untouched(self):
        with tempfile.TemporaryDirectory(prefix="sigra-ref-pair-r8-publish-") as temp:
            env = self.freeze_environment(temp, ref_pair="r8")
            server, manifest = env["server"], env["manifest"]
            seeded = self.seed_legacy_refs(env)
            allocation, ledger = self.canary_allocation(env)
            approval = self.write_approval(env, "canary")
            receipt = env["root"] / "r8-receipt.json"
            result = subprocess.run(self.publish_args(env["manifest_path"], allocation, ledger, receipt, env["repo"])
                                    + ["--freeze", str(env["freeze_path"]), "--action-approval", str(approval)],
                                    cwd=ROOT, text=True, capture_output=True, timeout=90)
            self.assertEqual(result.returncode, 0, result.stderr + json.dumps(server.journal))
            self.assertEqual(server.refs["gsd/253-replan-r8-candidate"], manifest["candidate_helper_commit"])
            self.assertEqual(server.refs["gsd/253-replan-r8-fixture"], manifest["fixture_workflow_commit"])
            for name, sha in seeded.items():
                self.assertEqual(server.refs[name], sha)
            self.assertEqual(set(server.refs), set(seeded) | {"gsd/253-replan-r8-candidate", "gsd/253-replan-r8-fixture"})
            ref_paths = [row["path"] for row in server.journal if "/git/ref" in row["path"]]
            self.assertTrue(ref_paths)
            self.assertFalse([path for path in ref_paths if path.endswith(("/253-replan-candidate", "/253-replan-fixture"))],
                             "an r8 publication read or wrote a legacy ref")
            value = json.loads(receipt.read_text())
            self.assertEqual((value["candidate_ref"], value["fixture_ref"]), R8_PAIR)
            self.assertEqual(sorted(row["ref"] for row in value["server_object_receipts"] if row["kind"] == "ref"), sorted(R8_PAIR))

            def verify():
                return subprocess.run(["python3", str(PUBLISHER), "--verify-publication", str(receipt)], cwd=ROOT, text=True, capture_output=True)
            self.assertEqual(verify().returncode, 0, verify().stderr)
            original = receipt.read_text()
            for label, refs in {"mixed": (R8_PAIR[0], LEGACY_PAIR[1]),
                                "fourth": UNKNOWN_PAIR}.items():
                with self.subTest(label=label):
                    tampered = json.loads(original)
                    by_variant = dict(zip(("candidate", "fixture"), refs))
                    tampered["candidate_ref"], tampered["fixture_ref"] = refs
                    for row in tampered["server_object_receipts"]:
                        if row["kind"] == "ref":
                            row["ref"] = by_variant[row["variant"]]
                    receipt.write_text(json.dumps(tampered))
                    refused = verify()
                    self.assertNotEqual(refused.returncode, 0, label)
                    self.assertIn("scoped refs", refused.stderr)
            receipt.write_text(original)
            self.assertEqual(verify().returncode, 0)

    def test_legacy_freeze_publication_stops_on_seeded_refs_at_another_sha_with_no_ref_changed(self):
        with tempfile.TemporaryDirectory(prefix="sigra-ref-pair-legacy-stop-") as temp:
            env = self.freeze_environment(temp)
            server = env["server"]
            seeded = self.seed_legacy_refs(env)
            allocation, ledger = self.canary_allocation(env)
            approval = self.write_approval(env, "canary")
            result = subprocess.run(self.publish_args(env["manifest_path"], allocation, ledger, env["root"] / "legacy-receipt.json", env["repo"])
                                    + ["--freeze", str(env["freeze_path"]), "--action-approval", str(approval)],
                                    cwd=ROOT, text=True, capture_output=True, timeout=90)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("scoped ref gsd/253-replan-candidate already points to a different commit", result.stderr)
            self.assertEqual(server.refs, seeded)
            self.assertFalse([row for row in server.journal if row["method"] == "POST" and row["path"].endswith("/git/refs")])



class R9RefPairTests(unittest.TestCase):
    """253-111: r9 is the third and last code-pinned pair. The r8 refs 253-104 left on GitHub are never read, moved or deleted."""

    make_local_publication = PublicationTests.make_local_publication
    prepare_registered = RegisteredPublicationTests.prepare_registered
    freeze_environment = RegisteredPublicationTests.freeze_environment
    write_approval = RegisteredPublicationTests.write_approval
    canary_allocation = RegisteredPublicationTests.canary_allocation
    publish_args = RegisteredPublicationTests.publish_args

    def test_freeze_r8_replays_its_recorded_section_digests_exactly(self):
        module = load_publisher()
        freeze = json.loads((ROOT / PHASE_REL / "253-LOAD-RECOVERY-CANARY-FREEZE-R8.json").read_text())
        self.assertEqual((freeze["identity"]["candidate_ref"], freeze["identity"]["fixture_ref"]), R8_PAIR)
        sections, derived = module.build_outward_actions(freeze["identity"])
        self.assertEqual(derived, FREEZE_R8_DIGESTS)
        self.assertEqual(freeze["outward_actions_sha256"], FREEZE_R8_DIGESTS)
        self.assertEqual(sections, freeze["outward_actions"])

    def test_an_r9_identity_moves_every_candidate_and_fixture_ref_to_the_r9_names(self):
        module = load_publisher()
        r8 = json.loads((ROOT / PHASE_REL / "253-LOAD-RECOVERY-CANARY-FREEZE-R8.json").read_text())["identity"]
        identity = {**r8, "candidate_ref": R9_PAIR[0], "fixture_ref": R9_PAIR[1]}
        sections, digests = module.build_outward_actions(identity)
        canary, docs = sections["canary"]["actions"], sections["docs_and_prs"]["actions"]
        self.assertEqual([a["ref"] for a in canary if a["action"] == "create_ref"], list(R9_PAIR))
        self.assertEqual({a["ref"] for a in canary if a["action"] == "workflow_dispatch"}, {"gsd/253-replan-r9-fixture"})
        self.assertEqual([a["run_identity"]["head_branch"] for a in canary if a["action"] == "cancel_run"], ["gsd/253-replan-r9-fixture"])
        prs = {a["family"]: (a["head"], a["base"]) for a in docs if a["action"] == "pr_create"}
        self.assertEqual(prs, {"normal": ("gsd/253-replan-r9-candidate", "main"),
                               "docs-only": ("gsd/253-replan-docs-head", "gsd/253-replan-docs-base")})
        self.assertNotIn("253-replan-r8-", json.dumps(sections))
        for section, value in FREEZE_R8_DIGESTS.items():
            self.assertNotEqual(digests[section], value)
        for mixed in ({"candidate_ref": R9_PAIR[0]}, {"fixture_ref": R9_PAIR[1]},
                      {"candidate_ref": R9_PAIR[0], "fixture_ref": LEGACY_PAIR[1]}):
            with self.subTest(mixed=mixed):
                with self.assertRaises(module.PublicationError):
                    module.build_outward_actions({**r8, **mixed})

    def test_build_freeze_accepts_r9_and_the_cli_refuses_a_fourth_pair(self):
        with tempfile.TemporaryDirectory(prefix="sigra-ref-pair-r9-freeze-") as temp:
            env = self.freeze_environment(temp, ref_pair="r9")
            self.assertEqual((env["freeze"]["identity"]["candidate_ref"], env["freeze"]["identity"]["fixture_ref"]), R9_PAIR)
            module = load_publisher()
            with self.assertRaises(module.PublicationError):
                module.build_freeze(env["repo"], env["manifest_rel"], env["repo"] / PHASE_REL / "r14.json", ref_pair="r14")
            self.assertFalse((env["repo"] / PHASE_REL / "r14.json").exists())
            refused = subprocess.run(["python3", str(PUBLISHER), "--build-freeze", "--manifest", env["manifest_rel"],
                                      "--output", f"{PHASE_REL}/r14.json", "--repo-root", str(env["repo"]), "--ref-pair", "r14"],
                                     cwd=ROOT, text=True, capture_output=True)
            self.assertNotEqual(refused.returncode, 0)
            self.assertIn("r9", refused.stderr)
            self.assertFalse((env["repo"] / PHASE_REL / "r14.json").exists())

    def test_check_freeze_refuses_r9_mixed_with_r8_or_legacy(self):
        with tempfile.TemporaryDirectory(prefix="sigra-ref-pair-r9-check-") as temp:
            env = self.freeze_environment(temp, ref_pair="r9")
            original = env["freeze_path"].read_text()

            def check():
                return subprocess.run(["python3", str(PUBLISHER), "--check-freeze", str(env["freeze_path"]), "--repo-root", str(env["repo"])],
                                      cwd=ROOT, text=True, capture_output=True)
            self.assertEqual(check().returncode, 0, check().stderr)
            for label, refs in {"r9 candidate with r8 fixture": (R9_PAIR[0], R8_PAIR[1]),
                                "r8 candidate with r9 fixture": (R8_PAIR[0], R9_PAIR[1]),
                                "r9 candidate with legacy fixture": (R9_PAIR[0], LEGACY_PAIR[1]),
                                "r8 pair under an r9 freeze": R8_PAIR,
                                "fourth pair": UNKNOWN_PAIR}.items():
                with self.subTest(label=label):
                    value = json.loads(original)
                    value["identity"]["candidate_ref"], value["identity"]["fixture_ref"] = refs
                    env["freeze_path"].write_text(json.dumps(value, indent=2))
                    refused = check()
                    self.assertNotEqual(refused.returncode, 0, label)
            env["freeze_path"].write_text(original)
            self.assertEqual(check().returncode, 0)

    def seed_r8_refs(self, env, sha):
        seeded = {"gsd/253-replan-r8-candidate": sha, "gsd/253-replan-r8-fixture": sha}
        env["server"].refs.update(seeded)
        return dict(seeded)

    def test_r9_publication_creates_only_the_r9_refs_and_leaves_seeded_r8_refs_untouched(self):
        with tempfile.TemporaryDirectory(prefix="sigra-ref-pair-r9-publish-") as temp:
            env = self.freeze_environment(temp, ref_pair="r9")
            server, manifest = env["server"], env["manifest"]
            seeded = self.seed_r8_refs(env, env["parent"])
            allocation, ledger = self.canary_allocation(env)
            approval = self.write_approval(env, "canary")
            receipt = env["root"] / "r9-receipt.json"
            result = subprocess.run(self.publish_args(env["manifest_path"], allocation, ledger, receipt, env["repo"])
                                    + ["--freeze", str(env["freeze_path"]), "--action-approval", str(approval)],
                                    cwd=ROOT, text=True, capture_output=True, timeout=90)
            self.assertEqual(result.returncode, 0, result.stderr + json.dumps(server.journal))
            self.assertEqual(server.refs["gsd/253-replan-r9-candidate"], manifest["candidate_helper_commit"])
            self.assertEqual(server.refs["gsd/253-replan-r9-fixture"], manifest["fixture_workflow_commit"])
            for name, sha in seeded.items():
                self.assertEqual(server.refs[name], sha)
            self.assertEqual(set(server.refs), set(seeded) | {"gsd/253-replan-r9-candidate", "gsd/253-replan-r9-fixture"})
            ref_paths = [row["path"] for row in server.journal if "/git/ref" in row["path"]]
            self.assertTrue(ref_paths)
            self.assertFalse([path for path in ref_paths if "253-replan-r8-" in path], "an r9 publication read or wrote an r8 ref")
            ref_bodies = json.dumps([row for row in server.journal if row["method"] == "POST" and row["path"].endswith("/git/refs")])
            self.assertNotIn("253-replan-r8-", ref_bodies)
            value = json.loads(receipt.read_text())
            self.assertEqual((value["candidate_ref"], value["fixture_ref"]), R9_PAIR)
            self.assertEqual(sorted(row["ref"] for row in value["server_object_receipts"] if row["kind"] == "ref"), sorted(R9_PAIR))

            def verify():
                return subprocess.run(["python3", str(PUBLISHER), "--verify-publication", str(receipt)], cwd=ROOT, text=True, capture_output=True)
            self.assertEqual(verify().returncode, 0, verify().stderr)
            original = receipt.read_text()
            for label, refs in {"r9 candidate, r8 fixture": (R9_PAIR[0], R8_PAIR[1]),
                                "r8 candidate, r9 fixture": (R8_PAIR[0], R9_PAIR[1]),
                                "fourth": UNKNOWN_PAIR}.items():
                with self.subTest(label=label):
                    tampered = json.loads(original)
                    by_variant = dict(zip(("candidate", "fixture"), refs))
                    tampered["candidate_ref"], tampered["fixture_ref"] = refs
                    for row in tampered["server_object_receipts"]:
                        if row["kind"] == "ref":
                            row["ref"] = by_variant[row["variant"]]
                    receipt.write_text(json.dumps(tampered))
                    refused = verify()
                    self.assertNotEqual(refused.returncode, 0, label)
                    self.assertIn("scoped refs", refused.stderr)
            receipt.write_text(original)
            self.assertEqual(verify().returncode, 0)

    def test_r8_freeze_publication_stops_on_seeded_r8_refs_at_another_sha_with_no_ref_changed(self):
        with tempfile.TemporaryDirectory(prefix="sigra-ref-pair-r8-stop-") as temp:
            env = self.freeze_environment(temp, ref_pair="r8")
            server = env["server"]
            seeded = self.seed_r8_refs(env, env["parent"])
            allocation, ledger = self.canary_allocation(env)
            approval = self.write_approval(env, "canary")
            result = subprocess.run(self.publish_args(env["manifest_path"], allocation, ledger, env["root"] / "r8-receipt.json", env["repo"])
                                    + ["--freeze", str(env["freeze_path"]), "--action-approval", str(approval)],
                                    cwd=ROOT, text=True, capture_output=True, timeout=90)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("scoped ref gsd/253-replan-r8-candidate already points to a different commit", result.stderr)
            self.assertEqual(server.refs, seeded)
            self.assertFalse([row for row in server.journal if row["method"] == "POST" and row["path"].endswith("/git/refs")])

    def test_the_unused_canary_branch_alias_is_gone(self):
        module = load_publisher()
        self.assertFalse(hasattr(module, "CANARY_BRANCH"))
        self.assertNotIn("CANARY_BRANCH", PUBLISHER.read_text())
        self.assertIn("DEFAULT_REF_PAIR", PUBLISHER.read_text())


class R10RefPairTests(unittest.TestCase):
    """253-119: r10 is the fourth code-pinned pair. The r8 and r9 refs already on GitHub are never read, moved or deleted."""

    make_local_publication = PublicationTests.make_local_publication
    prepare_registered = RegisteredPublicationTests.prepare_registered
    freeze_environment = RegisteredPublicationTests.freeze_environment
    write_approval = RegisteredPublicationTests.write_approval
    canary_allocation = RegisteredPublicationTests.canary_allocation
    publish_args = RegisteredPublicationTests.publish_args

    def test_freeze_r9_replays_its_recorded_section_digests_exactly(self):
        module = load_publisher()
        freeze = json.loads((ROOT / PHASE_REL / "253-LOAD-RECOVERY-CANARY-FREEZE-R9.json").read_text())
        self.assertEqual((freeze["identity"]["candidate_ref"], freeze["identity"]["fixture_ref"]), R9_PAIR)
        sections, derived = module.build_outward_actions(freeze["identity"])
        self.assertEqual(derived, FREEZE_R9_DIGESTS)
        self.assertEqual(freeze["outward_actions_sha256"], FREEZE_R9_DIGESTS)
        self.assertEqual(sections, freeze["outward_actions"])

    def test_every_earlier_freeze_still_replays_with_the_fourth_pair_present(self):
        module = load_publisher()
        recorded = {"253-LOAD-RECOVERY-CANARY-FREEZE-R9.json": FREEZE_R9_DIGESTS,
                    "253-LOAD-RECOVERY-CANARY-FREEZE-R8.json": FREEZE_R8_DIGESTS, **EARLIER_FREEZE_DIGESTS}
        self.assertEqual(len(recorded), 4)
        for name, digests in recorded.items():
            with self.subTest(freeze=name):
                freeze = json.loads((ROOT / PHASE_REL / name).read_text())
                self.assertEqual(module.build_outward_actions(freeze["identity"])[1], digests)

    def test_an_r10_identity_moves_every_candidate_and_fixture_ref_to_the_r10_names(self):
        module = load_publisher()
        r9 = json.loads((ROOT / PHASE_REL / "253-LOAD-RECOVERY-CANARY-FREEZE-R9.json").read_text())["identity"]
        identity = {**r9, "candidate_ref": R10_PAIR[0], "fixture_ref": R10_PAIR[1]}
        sections, digests = module.build_outward_actions(identity)
        canary, docs = sections["canary"]["actions"], sections["docs_and_prs"]["actions"]
        self.assertEqual([a["ref"] for a in canary if a["action"] == "create_ref"], list(R10_PAIR))
        self.assertEqual({a["ref"] for a in canary if a["action"] == "workflow_dispatch"}, {"gsd/253-replan-r10-fixture"})
        self.assertEqual([a["run_identity"]["head_branch"] for a in canary if a["action"] == "cancel_run"], ["gsd/253-replan-r10-fixture"])
        prs = {a["family"]: (a["head"], a["base"]) for a in docs if a["action"] == "pr_create"}
        self.assertEqual(prs, {"normal": ("gsd/253-replan-r10-candidate", "main"),
                               "docs-only": ("gsd/253-replan-docs-head", "gsd/253-replan-docs-base")})
        self.assertNotIn("253-replan-r9-", json.dumps(sections))
        self.assertNotIn("253-replan-r8-", json.dumps(sections))
        for section, value in FREEZE_R9_DIGESTS.items():
            self.assertNotEqual(digests[section], value)
        for mixed in ({"candidate_ref": R10_PAIR[0]}, {"fixture_ref": R10_PAIR[1]},
                      {"candidate_ref": R10_PAIR[0], "fixture_ref": R9_PAIR[1]},
                      {"candidate_ref": R9_PAIR[0], "fixture_ref": R10_PAIR[1]},
                      {"candidate_ref": R10_PAIR[0], "fixture_ref": R8_PAIR[1]},
                      {"candidate_ref": UNKNOWN_PAIR[0], "fixture_ref": UNKNOWN_PAIR[1]}):
            with self.subTest(mixed=mixed):
                with self.assertRaises(module.PublicationError):
                    module.build_outward_actions({**r9, **mixed})

    def test_build_freeze_accepts_r10_and_the_cli_refuses_a_fifth_pair_naming_all_four(self):
        with tempfile.TemporaryDirectory(prefix="sigra-ref-pair-r10-freeze-") as temp:
            env = self.freeze_environment(temp, ref_pair="r10")
            self.assertEqual((env["freeze"]["identity"]["candidate_ref"], env["freeze"]["identity"]["fixture_ref"]), R10_PAIR)
            module = load_publisher()
            for bad in ("r14", "R10", "r10 ", "r9,r10", "r1"):
                with self.subTest(pair=bad):
                    with self.assertRaises(module.PublicationError):
                        module.build_freeze(env["repo"], env["manifest_rel"], env["repo"] / PHASE_REL / "bad.json", ref_pair=bad)
                    self.assertFalse((env["repo"] / PHASE_REL / "bad.json").exists())
            refused = subprocess.run(["python3", str(PUBLISHER), "--build-freeze", "--manifest", env["manifest_rel"],
                                      "--output", f"{PHASE_REL}/r14.json", "--repo-root", str(env["repo"]), "--ref-pair", "r14"],
                                     cwd=ROOT, text=True, capture_output=True)
            self.assertNotEqual(refused.returncode, 0)
            for name in ("legacy", "r8", "r9", "r10"):
                self.assertIn(f"'{name}'", refused.stderr)
            self.assertFalse((env["repo"] / PHASE_REL / "r14.json").exists())
            helped = subprocess.run(["python3", str(PUBLISHER), "--help"], cwd=ROOT, text=True, capture_output=True)
            self.assertEqual(helped.returncode, 0)
            self.assertIn("r9, r10, r11, r12 or r13", " ".join(helped.stdout.split()))
            mixed = module.PublicationError
            with self.assertRaises(mixed) as raised:
                module.ref_pair_name(R10_PAIR[0], R9_PAIR[1])
            self.assertIn("legacy, r8, r9, r10, r11, r12 or r13", str(raised.exception))

    def test_check_freeze_refuses_r10_mixed_with_r9_r8_or_legacy(self):
        with tempfile.TemporaryDirectory(prefix="sigra-ref-pair-r10-check-") as temp:
            env = self.freeze_environment(temp, ref_pair="r10")
            original = env["freeze_path"].read_text()

            def check():
                return subprocess.run(["python3", str(PUBLISHER), "--check-freeze", str(env["freeze_path"]), "--repo-root", str(env["repo"])],
                                      cwd=ROOT, text=True, capture_output=True)
            self.assertEqual(check().returncode, 0, check().stderr)
            for label, refs in {"r10 candidate with r9 fixture": (R10_PAIR[0], R9_PAIR[1]),
                                "r9 candidate with r10 fixture": (R9_PAIR[0], R10_PAIR[1]),
                                "r10 candidate with r8 fixture": (R10_PAIR[0], R8_PAIR[1]),
                                "r10 candidate with legacy fixture": (R10_PAIR[0], LEGACY_PAIR[1]),
                                "r9 pair under an r10 freeze": R9_PAIR,
                                "fixture as candidate": (R10_PAIR[1], R10_PAIR[1]),
                                "fifth pair": UNKNOWN_PAIR}.items():
                with self.subTest(label=label):
                    value = json.loads(original)
                    value["identity"]["candidate_ref"], value["identity"]["fixture_ref"] = refs
                    env["freeze_path"].write_text(json.dumps(value, indent=2))
                    refused = check()
                    self.assertNotEqual(refused.returncode, 0, label)
            env["freeze_path"].write_text(original)
            self.assertEqual(check().returncode, 0)

    def seed_r8_and_r9_refs(self, env, sha):
        seeded = {"gsd/253-replan-r8-candidate": sha, "gsd/253-replan-r8-fixture": sha,
                  "gsd/253-replan-r9-candidate": sha, "gsd/253-replan-r9-fixture": sha}
        env["server"].refs.update(seeded)
        return dict(seeded)

    def test_r10_publication_creates_only_the_r10_refs_and_leaves_seeded_r8_and_r9_refs_untouched(self):
        with tempfile.TemporaryDirectory(prefix="sigra-ref-pair-r10-publish-") as temp:
            env = self.freeze_environment(temp, ref_pair="r10")
            server, manifest = env["server"], env["manifest"]
            seeded = self.seed_r8_and_r9_refs(env, env["parent"])
            allocation, ledger = self.canary_allocation(env)
            approval = self.write_approval(env, "canary")
            receipt = env["root"] / "r10-receipt.json"
            result = subprocess.run(self.publish_args(env["manifest_path"], allocation, ledger, receipt, env["repo"])
                                    + ["--freeze", str(env["freeze_path"]), "--action-approval", str(approval)],
                                    cwd=ROOT, text=True, capture_output=True, timeout=90)
            self.assertEqual(result.returncode, 0, result.stderr + json.dumps(server.journal))
            self.assertEqual(server.refs["gsd/253-replan-r10-candidate"], manifest["candidate_helper_commit"])
            self.assertEqual(server.refs["gsd/253-replan-r10-fixture"], manifest["fixture_workflow_commit"])
            for name, sha in seeded.items():
                self.assertEqual(server.refs[name], sha)
            self.assertEqual(set(server.refs), set(seeded) | {"gsd/253-replan-r10-candidate", "gsd/253-replan-r10-fixture"})
            ref_paths = [row["path"] for row in server.journal if "/git/ref" in row["path"]]
            self.assertTrue(ref_paths)
            self.assertTrue([path for path in ref_paths if "253-replan-r10-" in path])
            self.assertFalse([path for path in ref_paths if "253-replan-r8-" in path or "253-replan-r9-" in path],
                             "an r10 publication read or wrote an r8 or r9 ref")
            ref_bodies = json.dumps([row for row in server.journal if row["method"] == "POST" and row["path"].endswith("/git/refs")])
            self.assertNotIn("253-replan-r8-", ref_bodies)
            self.assertNotIn("253-replan-r9-", ref_bodies)
            value = json.loads(receipt.read_text())
            self.assertEqual((value["candidate_ref"], value["fixture_ref"]), R10_PAIR)
            self.assertEqual(sorted(row["ref"] for row in value["server_object_receipts"] if row["kind"] == "ref"), sorted(R10_PAIR))

            def verify():
                return subprocess.run(["python3", str(PUBLISHER), "--verify-publication", str(receipt)], cwd=ROOT, text=True, capture_output=True)
            self.assertEqual(verify().returncode, 0, verify().stderr)
            original = receipt.read_text()
            for label, refs in {"r10 candidate, r9 fixture": (R10_PAIR[0], R9_PAIR[1]),
                                "r9 candidate, r10 fixture": (R9_PAIR[0], R10_PAIR[1]),
                                "r10 candidate, r8 fixture": (R10_PAIR[0], R8_PAIR[1]),
                                "fifth": UNKNOWN_PAIR}.items():
                with self.subTest(label=label):
                    tampered = json.loads(original)
                    by_variant = dict(zip(("candidate", "fixture"), refs))
                    tampered["candidate_ref"], tampered["fixture_ref"] = refs
                    for row in tampered["server_object_receipts"]:
                        if row["kind"] == "ref":
                            row["ref"] = by_variant[row["variant"]]
                    receipt.write_text(json.dumps(tampered))
                    refused = verify()
                    self.assertNotEqual(refused.returncode, 0, label)
                    self.assertIn("scoped refs", refused.stderr)
            receipt.write_text(original)
            self.assertEqual(verify().returncode, 0)

    def test_r9_freeze_publication_stops_on_seeded_r9_refs_at_another_sha_with_no_ref_changed(self):
        with tempfile.TemporaryDirectory(prefix="sigra-ref-pair-r9-stop-") as temp:
            env = self.freeze_environment(temp, ref_pair="r9")
            server = env["server"]
            seeded = self.seed_r8_and_r9_refs(env, env["parent"])
            allocation, ledger = self.canary_allocation(env)
            approval = self.write_approval(env, "canary")
            result = subprocess.run(self.publish_args(env["manifest_path"], allocation, ledger, env["root"] / "r9-receipt.json", env["repo"])
                                    + ["--freeze", str(env["freeze_path"]), "--action-approval", str(approval)],
                                    cwd=ROOT, text=True, capture_output=True, timeout=90)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("scoped ref gsd/253-replan-r9-candidate already points to a different commit", result.stderr)
            self.assertEqual(server.refs, seeded)
            self.assertFalse([row for row in server.journal if row["method"] == "POST" and row["path"].endswith("/git/refs")])


class R11RefPairTests(unittest.TestCase):
    """253-130: r11 is the fifth code-pinned pair. The r8, r9 and r10 refs already on GitHub are never read, moved or deleted."""

    make_local_publication = PublicationTests.make_local_publication
    prepare_registered = RegisteredPublicationTests.prepare_registered
    freeze_environment = RegisteredPublicationTests.freeze_environment
    write_approval = RegisteredPublicationTests.write_approval
    canary_allocation = RegisteredPublicationTests.canary_allocation
    publish_args = RegisteredPublicationTests.publish_args

    def test_freeze_r10_replays_its_recorded_section_digests_exactly(self):
        module = load_publisher()
        freeze = json.loads((ROOT / PHASE_REL / "253-LOAD-RECOVERY-CANARY-FREEZE-R10.json").read_text())
        self.assertEqual((freeze["identity"]["candidate_ref"], freeze["identity"]["fixture_ref"]), R10_PAIR)
        sections, derived = module.build_outward_actions(freeze["identity"])
        self.assertEqual(derived, FREEZE_R10_DIGESTS)
        self.assertEqual(freeze["outward_actions_sha256"], FREEZE_R10_DIGESTS)
        self.assertEqual(sections, freeze["outward_actions"])

    def test_every_earlier_freeze_still_replays_with_the_fifth_pair_present(self):
        module = load_publisher()
        recorded = {"253-LOAD-RECOVERY-CANARY-FREEZE-R10.json": FREEZE_R10_DIGESTS,
                    "253-LOAD-RECOVERY-CANARY-FREEZE-R9.json": FREEZE_R9_DIGESTS,
                    "253-LOAD-RECOVERY-CANARY-FREEZE-R8.json": FREEZE_R8_DIGESTS, **EARLIER_FREEZE_DIGESTS}
        self.assertEqual(len(recorded), 5)
        for name, digests in recorded.items():
            with self.subTest(freeze=name):
                freeze = json.loads((ROOT / PHASE_REL / name).read_text())
                self.assertEqual(module.build_outward_actions(freeze["identity"])[1], digests)
                self.assertEqual(freeze["outward_actions_sha256"], digests)

    def test_an_r11_identity_moves_every_candidate_and_fixture_ref_to_the_r11_names(self):
        module = load_publisher()
        r10 = json.loads((ROOT / PHASE_REL / "253-LOAD-RECOVERY-CANARY-FREEZE-R10.json").read_text())["identity"]
        identity = {**r10, "candidate_ref": R11_PAIR[0], "fixture_ref": R11_PAIR[1]}
        sections, digests = module.build_outward_actions(identity)
        canary, docs = sections["canary"]["actions"], sections["docs_and_prs"]["actions"]
        self.assertEqual([a["ref"] for a in canary if a["action"] == "create_ref"], list(R11_PAIR))
        self.assertEqual({a["ref"] for a in canary if a["action"] == "workflow_dispatch"}, {"gsd/253-replan-r11-fixture"})
        self.assertEqual([a["run_identity"]["head_branch"] for a in canary if a["action"] == "cancel_run"], ["gsd/253-replan-r11-fixture"])
        prs = {a["family"]: (a["head"], a["base"]) for a in docs if a["action"] == "pr_create"}
        self.assertEqual(prs, {"normal": ("gsd/253-replan-r11-candidate", "main"),
                               "docs-only": ("gsd/253-replan-docs-head", "gsd/253-replan-docs-base")})
        for earlier in ("253-replan-r10-", "253-replan-r9-", "253-replan-r8-"):
            self.assertNotIn(earlier, json.dumps(sections))
        for section, value in FREEZE_R10_DIGESTS.items():
            self.assertNotEqual(digests[section], value)
        for mixed in ({"candidate_ref": R11_PAIR[0]}, {"fixture_ref": R11_PAIR[1]},
                      {"candidate_ref": R11_PAIR[0], "fixture_ref": R10_PAIR[1]},
                      {"candidate_ref": R10_PAIR[0], "fixture_ref": R11_PAIR[1]},
                      {"candidate_ref": R11_PAIR[0], "fixture_ref": R9_PAIR[1]},
                      {"candidate_ref": R9_PAIR[0], "fixture_ref": R11_PAIR[1]},
                      {"candidate_ref": R11_PAIR[0], "fixture_ref": R8_PAIR[1]},
                      {"candidate_ref": UNKNOWN_PAIR[0], "fixture_ref": UNKNOWN_PAIR[1]}):
            with self.subTest(mixed=mixed):
                with self.assertRaises(module.PublicationError):
                    module.build_outward_actions({**r10, **mixed})

    def test_build_freeze_accepts_r11_and_the_cli_refuses_a_sixth_pair_naming_all_five(self):
        with tempfile.TemporaryDirectory(prefix="sigra-ref-pair-r11-freeze-") as temp:
            env = self.freeze_environment(temp, ref_pair="r11")
            self.assertEqual((env["freeze"]["identity"]["candidate_ref"], env["freeze"]["identity"]["fixture_ref"]), R11_PAIR)
            module = load_publisher()
            for bad in ("r14", "R11", "r11 ", "r10,r11", "r1", "r110"):
                with self.subTest(pair=bad):
                    with self.assertRaises(module.PublicationError):
                        module.build_freeze(env["repo"], env["manifest_rel"], env["repo"] / PHASE_REL / "bad.json", ref_pair=bad)
                    self.assertFalse((env["repo"] / PHASE_REL / "bad.json").exists())
            refused = subprocess.run(["python3", str(PUBLISHER), "--build-freeze", "--manifest", env["manifest_rel"],
                                      "--output", f"{PHASE_REL}/r14.json", "--repo-root", str(env["repo"]), "--ref-pair", "r14"],
                                     cwd=ROOT, text=True, capture_output=True)
            self.assertNotEqual(refused.returncode, 0)
            for name in ("legacy", "r8", "r9", "r10", "r11"):
                self.assertIn(f"'{name}'", refused.stderr)
            self.assertFalse((env["repo"] / PHASE_REL / "r14.json").exists())
            helped = subprocess.run(["python3", str(PUBLISHER), "--help"], cwd=ROOT, text=True, capture_output=True)
            self.assertEqual(helped.returncode, 0)
            self.assertIn("legacy (default), r8, r9, r10, r11, r12 or r13", " ".join(helped.stdout.split()))
            with self.assertRaises(module.PublicationError) as raised:
                module.ref_pair_name(R11_PAIR[0], R10_PAIR[1])
            self.assertIn("legacy, r8, r9, r10, r11, r12 or r13", str(raised.exception))

    def test_check_freeze_refuses_r11_mixed_with_r10_r9_r8_or_legacy(self):
        with tempfile.TemporaryDirectory(prefix="sigra-ref-pair-r11-check-") as temp:
            env = self.freeze_environment(temp, ref_pair="r11")
            original = env["freeze_path"].read_text()

            def check():
                return subprocess.run(["python3", str(PUBLISHER), "--check-freeze", str(env["freeze_path"]), "--repo-root", str(env["repo"])],
                                      cwd=ROOT, text=True, capture_output=True)
            self.assertEqual(check().returncode, 0, check().stderr)
            for label, refs in {"r11 candidate with r10 fixture": (R11_PAIR[0], R10_PAIR[1]),
                                "r10 candidate with r11 fixture": (R10_PAIR[0], R11_PAIR[1]),
                                "r11 candidate with r9 fixture": (R11_PAIR[0], R9_PAIR[1]),
                                "r9 candidate with r11 fixture": (R9_PAIR[0], R11_PAIR[1]),
                                "r11 candidate with r8 fixture": (R11_PAIR[0], R8_PAIR[1]),
                                "r11 candidate with legacy fixture": (R11_PAIR[0], LEGACY_PAIR[1]),
                                "r10 pair under an r11 freeze": R10_PAIR,
                                "fixture as candidate": (R11_PAIR[1], R11_PAIR[1]),
                                "sixth pair": UNKNOWN_PAIR}.items():
                with self.subTest(label=label):
                    value = json.loads(original)
                    value["identity"]["candidate_ref"], value["identity"]["fixture_ref"] = refs
                    env["freeze_path"].write_text(json.dumps(value, indent=2))
                    refused = check()
                    self.assertNotEqual(refused.returncode, 0, label)
            env["freeze_path"].write_text(original)
            self.assertEqual(check().returncode, 0)

    def seed_r8_r9_and_r10_refs(self, env, sha):
        seeded = {f"gsd/253-replan-{pair}-{variant}": sha for pair in ("r8", "r9", "r10") for variant in ("candidate", "fixture")}
        self.assertEqual(len(seeded), 6)
        env["server"].refs.update(seeded)
        return dict(seeded)

    def test_r11_publication_creates_only_the_r11_refs_and_leaves_seeded_r8_r9_and_r10_refs_untouched(self):
        with tempfile.TemporaryDirectory(prefix="sigra-ref-pair-r11-publish-") as temp:
            env = self.freeze_environment(temp, ref_pair="r11")
            server, manifest = env["server"], env["manifest"]
            seeded = self.seed_r8_r9_and_r10_refs(env, env["parent"])
            allocation, ledger = self.canary_allocation(env)
            approval = self.write_approval(env, "canary")
            receipt = env["root"] / "r11-receipt.json"
            result = subprocess.run(self.publish_args(env["manifest_path"], allocation, ledger, receipt, env["repo"])
                                    + ["--freeze", str(env["freeze_path"]), "--action-approval", str(approval)],
                                    cwd=ROOT, text=True, capture_output=True, timeout=90)
            self.assertEqual(result.returncode, 0, result.stderr + json.dumps(server.journal))
            self.assertEqual(server.refs["gsd/253-replan-r11-candidate"], manifest["candidate_helper_commit"])
            self.assertEqual(server.refs["gsd/253-replan-r11-fixture"], manifest["fixture_workflow_commit"])
            for name, sha in seeded.items():
                self.assertEqual(server.refs[name], sha)
            self.assertEqual(set(server.refs), set(seeded) | {"gsd/253-replan-r11-candidate", "gsd/253-replan-r11-fixture"})
            ref_paths = [row["path"] for row in server.journal if "/git/ref" in row["path"]]
            self.assertTrue(ref_paths)
            self.assertTrue([path for path in ref_paths if "253-replan-r11-" in path])
            self.assertFalse([path for path in ref_paths if any(f"253-replan-{p}-" in path for p in ("r8", "r9", "r10"))],
                             "an r11 publication read or wrote an r8, r9 or r10 ref")
            # The journal records body digests, not bodies, so the binding proof is the server.refs set equality above;
            # this counts the create_ref POSTs (exactly the two r11 refs).
            ref_posts = [row for row in server.journal if row["method"] == "POST" and row["path"].endswith("/git/refs")]
            self.assertEqual(len(ref_posts), 2)
            self.assertFalse([row for row in server.journal if row["method"] in ("DELETE", "PATCH")])
            value = json.loads(receipt.read_text())
            self.assertEqual((value["candidate_ref"], value["fixture_ref"]), R11_PAIR)
            self.assertEqual(sorted(row["ref"] for row in value["server_object_receipts"] if row["kind"] == "ref"), sorted(R11_PAIR))

            def verify():
                return subprocess.run(["python3", str(PUBLISHER), "--verify-publication", str(receipt)], cwd=ROOT, text=True, capture_output=True)
            self.assertEqual(verify().returncode, 0, verify().stderr)
            original = receipt.read_text()
            for label, refs in {"r11 candidate, r10 fixture": (R11_PAIR[0], R10_PAIR[1]),
                                "r10 candidate, r11 fixture": (R10_PAIR[0], R11_PAIR[1]),
                                "r11 candidate, r9 fixture": (R11_PAIR[0], R9_PAIR[1]),
                                "sixth": UNKNOWN_PAIR}.items():
                with self.subTest(label=label):
                    tampered = json.loads(original)
                    by_variant = dict(zip(("candidate", "fixture"), refs))
                    tampered["candidate_ref"], tampered["fixture_ref"] = refs
                    for row in tampered["server_object_receipts"]:
                        if row["kind"] == "ref":
                            row["ref"] = by_variant[row["variant"]]
                    receipt.write_text(json.dumps(tampered))
                    refused = verify()
                    self.assertNotEqual(refused.returncode, 0, label)
                    self.assertIn("scoped refs", refused.stderr)
            receipt.write_text(original)
            self.assertEqual(verify().returncode, 0)

    def test_r10_freeze_publication_stops_on_seeded_r10_refs_at_another_sha_with_no_ref_changed(self):
        with tempfile.TemporaryDirectory(prefix="sigra-ref-pair-r10-stop-") as temp:
            env = self.freeze_environment(temp, ref_pair="r10")
            server = env["server"]
            seeded = self.seed_r8_r9_and_r10_refs(env, env["parent"])
            self.assertNotEqual(env["parent"], env["manifest"]["candidate_helper_commit"])
            allocation, ledger = self.canary_allocation(env)
            approval = self.write_approval(env, "canary")
            result = subprocess.run(self.publish_args(env["manifest_path"], allocation, ledger, env["root"] / "r10-receipt.json", env["repo"])
                                    + ["--freeze", str(env["freeze_path"]), "--action-approval", str(approval)],
                                    cwd=ROOT, text=True, capture_output=True, timeout=90)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("scoped ref gsd/253-replan-r10-candidate already points to a different commit", result.stderr)
            self.assertEqual(server.refs, seeded)
            self.assertFalse([row for row in server.journal if row["method"] == "POST" and row["path"].endswith("/git/refs")])


R12_PAIR = ("refs/heads/gsd/253-replan-r12-candidate", "refs/heads/gsd/253-replan-r12-fixture")
FREEZE_R11_DIGESTS = {"canary": "898ffa480dc8b56dc72945feba35af326f12b9e291230ead17e76f7751ca410f",
                      "docs_and_prs": "f0e47f00c63f2ac3b9e8ed3a560ba9d5d2148c31aa00234329e18e2d65646ee2"}
DRYRUN = ROOT / "scripts/ci/ci-gate-canary-dryrun.py"


def real_earlier_refs():
    """253-137: the eight refs 253-104, 253-113, 253-122 and 253-133 created on GitHub, at their real SHAs. The r8-r10
    values are read from the dry-run harness's existing seed tables and the r11 values from FREEZE-R11's identity (never
    retyped)."""
    import importlib.util
    spec = importlib.util.spec_from_file_location("ci_gate_canary_dryrun_seed_tables", DRYRUN)
    runner = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(runner)
    identity = json.loads((ROOT / PHASE_REL / "253-LOAD-RECOVERY-CANARY-FREEZE-R11.json").read_text())["identity"]
    r11 = {identity["candidate_ref"].removeprefix("refs/heads/"): identity["candidate_helper_commit"],
           identity["fixture_ref"].removeprefix("refs/heads/"): identity["fixture_workflow_commit"]}
    refs = {**runner.R8_REFS, **runner.R9_REFS, **runner.R10_REFS, **r11}
    return refs


class R12RefPairTests(unittest.TestCase):
    """253-137: r12 is the sixth code-pinned pair. The r8, r9, r10 and r11 refs already on GitHub are never read, moved or
    deleted."""

    make_local_publication = PublicationTests.make_local_publication
    prepare_registered = RegisteredPublicationTests.prepare_registered
    freeze_environment = RegisteredPublicationTests.freeze_environment
    write_approval = RegisteredPublicationTests.write_approval
    canary_allocation = RegisteredPublicationTests.canary_allocation
    publish_args = RegisteredPublicationTests.publish_args

    def test_r12_is_a_known_pair_and_every_mixed_or_unknown_pair_is_refused(self):
        module = load_publisher()
        self.assertEqual(module.REF_PAIRS["r12"], {"candidate": "gsd/253-replan-r12-candidate", "fixture": "gsd/253-replan-r12-fixture"})
        self.assertEqual(len(module.REF_PAIRS), 7)
        self.assertEqual(module.DEFAULT_REF_PAIR, "legacy")
        self.assertEqual(module.ref_pair_name(*R12_PAIR), "r12")
        self.assertEqual(module.ref_pair_name(*R11_PAIR), "r11")
        for mixed in ((R12_PAIR[0], R11_PAIR[1]), (R11_PAIR[0], R12_PAIR[1]), (R12_PAIR[0], R10_PAIR[1]),
                      (R12_PAIR[0], R9_PAIR[1]), (R12_PAIR[0], R8_PAIR[1]), (R12_PAIR[0], LEGACY_PAIR[1]),
                      (R12_PAIR[1], R12_PAIR[0]), UNKNOWN_PAIR,
                      ("refs/heads/gsd/253-replan-r120-candidate", "refs/heads/gsd/253-replan-r120-fixture"),
                      ("gsd/253-replan-r12-candidate", "gsd/253-replan-r12-fixture")):
            with self.subTest(mixed=mixed):
                with self.assertRaises(module.PublicationError):
                    module.ref_pair_name(*mixed)

    def test_freeze_r11_and_every_earlier_freeze_replay_their_recorded_digests_with_the_sixth_pair_present(self):
        module = load_publisher()
        freeze = json.loads((ROOT / PHASE_REL / "253-LOAD-RECOVERY-CANARY-FREEZE-R11.json").read_text())
        self.assertEqual((freeze["identity"]["candidate_ref"], freeze["identity"]["fixture_ref"]), R11_PAIR)
        sections, derived = module.build_outward_actions(freeze["identity"])
        self.assertEqual(derived, FREEZE_R11_DIGESTS)
        self.assertEqual(freeze["outward_actions_sha256"], FREEZE_R11_DIGESTS)
        self.assertEqual(sections, freeze["outward_actions"])
        recorded = {"253-LOAD-RECOVERY-CANARY-FREEZE-R10.json": FREEZE_R10_DIGESTS,
                    "253-LOAD-RECOVERY-CANARY-FREEZE-R9.json": FREEZE_R9_DIGESTS,
                    "253-LOAD-RECOVERY-CANARY-FREEZE-R8.json": FREEZE_R8_DIGESTS, **EARLIER_FREEZE_DIGESTS}
        self.assertEqual(len(recorded), 5)
        for name, digests in recorded.items():
            with self.subTest(freeze=name):
                value = json.loads((ROOT / PHASE_REL / name).read_text())
                self.assertEqual(module.build_outward_actions(value["identity"])[1], digests)
                self.assertEqual(value["outward_actions_sha256"], digests)

    def test_an_r12_identity_moves_every_candidate_and_fixture_ref_to_the_r12_names(self):
        module = load_publisher()
        r11 = json.loads((ROOT / PHASE_REL / "253-LOAD-RECOVERY-CANARY-FREEZE-R11.json").read_text())["identity"]
        identity = {**r11, "candidate_ref": R12_PAIR[0], "fixture_ref": R12_PAIR[1]}
        sections, digests = module.build_outward_actions(identity)
        canary, docs = sections["canary"]["actions"], sections["docs_and_prs"]["actions"]
        self.assertEqual([a["ref"] for a in canary if a["action"] == "create_ref"], list(R12_PAIR))
        self.assertEqual({a["ref"] for a in canary if a["action"] == "workflow_dispatch"}, {"gsd/253-replan-r12-fixture"})
        self.assertEqual([a["run_identity"]["head_branch"] for a in canary if a["action"] == "cancel_run"], ["gsd/253-replan-r12-fixture"])
        prs = {a["family"]: (a["head"], a["base"]) for a in docs if a["action"] == "pr_create"}
        self.assertEqual(prs, {"normal": ("gsd/253-replan-r12-candidate", "main"),
                               "docs-only": ("gsd/253-replan-docs-head", "gsd/253-replan-docs-base")})
        for earlier in ("253-replan-r11-", "253-replan-r10-", "253-replan-r9-", "253-replan-r8-"):
            self.assertNotIn(earlier, json.dumps(sections))
        for section, value in FREEZE_R11_DIGESTS.items():
            self.assertNotEqual(digests[section], value)
        for mixed in ({"candidate_ref": R12_PAIR[0]}, {"fixture_ref": R12_PAIR[1]},
                      {"candidate_ref": R12_PAIR[0], "fixture_ref": R11_PAIR[1]},
                      {"candidate_ref": R11_PAIR[0], "fixture_ref": R12_PAIR[1]},
                      {"candidate_ref": R12_PAIR[0], "fixture_ref": R10_PAIR[1]},
                      {"candidate_ref": R12_PAIR[0], "fixture_ref": R8_PAIR[1]},
                      {"candidate_ref": UNKNOWN_PAIR[0], "fixture_ref": UNKNOWN_PAIR[1]}):
            with self.subTest(mixed=mixed):
                with self.assertRaises(module.PublicationError):
                    module.build_outward_actions({**r11, **mixed})

    def test_build_freeze_accepts_r12_and_the_cli_refuses_a_seventh_pair_naming_all_six(self):
        with tempfile.TemporaryDirectory(prefix="sigra-ref-pair-r12-freeze-") as temp:
            env = self.freeze_environment(temp, ref_pair="r12", main_record=True)
            self.assertEqual((env["freeze"]["identity"]["candidate_ref"], env["freeze"]["identity"]["fixture_ref"]), R12_PAIR)
            module = load_publisher()
            for bad in ("r14", "R12", "r12 ", "r11,r12", "r1", "r120"):
                with self.subTest(pair=bad):
                    with self.assertRaises(module.PublicationError):
                        module.build_freeze(env["repo"], env["manifest_rel"], env["repo"] / PHASE_REL / "bad.json", ref_pair=bad)
                    self.assertFalse((env["repo"] / PHASE_REL / "bad.json").exists())
            refused = subprocess.run(["python3", str(PUBLISHER), "--build-freeze", "--manifest", env["manifest_rel"],
                                      "--output", f"{PHASE_REL}/r14.json", "--repo-root", str(env["repo"]), "--ref-pair", "r14"],
                                     cwd=ROOT, text=True, capture_output=True)
            self.assertNotEqual(refused.returncode, 0)
            for name in ("legacy", "r8", "r9", "r10", "r11", "r12"):
                self.assertIn(f"'{name}'", refused.stderr)
            self.assertFalse((env["repo"] / PHASE_REL / "r14.json").exists())
            helped = subprocess.run(["python3", str(PUBLISHER), "--help"], cwd=ROOT, text=True, capture_output=True)
            self.assertEqual(helped.returncode, 0)
            self.assertIn("legacy (default), r8, r9, r10, r11, r12 or r13", " ".join(helped.stdout.split()))
            with self.assertRaises(module.PublicationError) as raised:
                module.ref_pair_name(R12_PAIR[0], R11_PAIR[1])
            self.assertIn("legacy, r8, r9, r10, r11, r12 or r13", str(raised.exception))

    def test_check_freeze_refuses_r12_mixed_with_an_earlier_pair(self):
        with tempfile.TemporaryDirectory(prefix="sigra-ref-pair-r12-check-") as temp:
            env = self.freeze_environment(temp, ref_pair="r12", main_record=True)
            original = env["freeze_path"].read_text()

            def check():
                return subprocess.run(["python3", str(PUBLISHER), "--check-freeze", str(env["freeze_path"]), "--repo-root", str(env["repo"])],
                                      cwd=ROOT, text=True, capture_output=True)
            self.assertEqual(check().returncode, 0, check().stderr)
            for label, refs in {"r12 candidate with r11 fixture": (R12_PAIR[0], R11_PAIR[1]),
                                "r11 candidate with r12 fixture": (R11_PAIR[0], R12_PAIR[1]),
                                "r12 candidate with r10 fixture": (R12_PAIR[0], R10_PAIR[1]),
                                "r12 candidate with legacy fixture": (R12_PAIR[0], LEGACY_PAIR[1]),
                                "r11 pair under an r12 freeze": R11_PAIR,
                                "fixture as candidate": (R12_PAIR[1], R12_PAIR[1]),
                                "seventh pair": UNKNOWN_PAIR}.items():
                with self.subTest(label=label):
                    value = json.loads(original)
                    value["identity"]["candidate_ref"], value["identity"]["fixture_ref"] = refs
                    env["freeze_path"].write_text(json.dumps(value, indent=2))
                    refused = check()
                    self.assertNotEqual(refused.returncode, 0, label)
            env["freeze_path"].write_text(original)
            self.assertEqual(check().returncode, 0)

    def test_the_seed_table_is_the_eight_real_refs_from_the_committed_records(self):
        refs = real_earlier_refs()
        self.assertEqual(len(refs), 8)
        self.assertEqual(set(refs), {f"gsd/253-replan-{pair}-{variant}" for pair in ("r8", "r9", "r10", "r11")
                                     for variant in ("candidate", "fixture")})
        self.assertEqual(refs["gsd/253-replan-r11-candidate"], "2b239a98df72b8d47e8c4e03edf193905b3239da")
        self.assertEqual(refs["gsd/253-replan-r11-fixture"], "65c402f966602dfc4a609af724457808cd8528eb")
        for name, sha in refs.items():
            with self.subTest(ref=name):
                self.assertRegex(sha, r"^[0-9a-f]{40}$")
        self.assertEqual(len(set(refs.values())), 8)

    def test_r12_publication_creates_only_the_r12_refs_beside_the_four_seeded_earlier_pairs(self):
        with tempfile.TemporaryDirectory(prefix="sigra-ref-pair-r12-publish-") as temp:
            env = self.freeze_environment(temp, ref_pair="r12", main_record=True)
            server, manifest = env["server"], env["manifest"]
            seeded = real_earlier_refs()
            server.refs.update(seeded)
            allocation, ledger = self.canary_allocation(env)
            approval = self.write_approval(env, "canary")
            receipt = env["root"] / "r12-receipt.json"
            result = subprocess.run(self.publish_args(env["manifest_path"], allocation, ledger, receipt, env["repo"])
                                    + ["--freeze", str(env["freeze_path"]), "--action-approval", str(approval)],
                                    cwd=ROOT, text=True, capture_output=True, timeout=90)
            self.assertEqual(result.returncode, 0, result.stderr + json.dumps(server.journal))
            self.assertEqual(server.refs["gsd/253-replan-r12-candidate"], manifest["candidate_helper_commit"])
            self.assertEqual(server.refs["gsd/253-replan-r12-fixture"], manifest["fixture_workflow_commit"])
            for name, sha in seeded.items():
                with self.subTest(seeded=name):
                    self.assertEqual(server.refs[name], sha)
            self.assertEqual(set(server.refs), set(seeded) | {"gsd/253-replan-r12-candidate", "gsd/253-replan-r12-fixture"})
            ref_paths = [row["path"] for row in server.journal if "/git/ref" in row["path"]]
            self.assertTrue([path for path in ref_paths if "253-replan-r12-" in path])
            self.assertFalse([path for path in ref_paths if any(f"253-replan-{p}-" in path for p in ("r8", "r9", "r10", "r11"))],
                             "an r12 publication read or wrote an r8, r9, r10 or r11 ref")
            ref_posts = [row for row in server.journal if row["method"] == "POST" and row["path"].endswith("/git/refs")]
            self.assertEqual(len(ref_posts), 2)
            self.assertFalse([row for row in server.journal if row["method"] in ("DELETE", "PATCH")])
            value = json.loads(receipt.read_text())
            self.assertEqual((value["candidate_ref"], value["fixture_ref"]), R12_PAIR)
            self.assertEqual(sorted(row["ref"] for row in value["server_object_receipts"] if row["kind"] == "ref"), sorted(R12_PAIR))

            def verify():
                return subprocess.run(["python3", str(PUBLISHER), "--verify-publication", str(receipt)], cwd=ROOT, text=True, capture_output=True)
            self.assertEqual(verify().returncode, 0, verify().stderr)
            original = receipt.read_text()
            for label, refs in {"r12 candidate, r11 fixture": (R12_PAIR[0], R11_PAIR[1]),
                                "r11 candidate, r12 fixture": (R11_PAIR[0], R12_PAIR[1]),
                                "seventh": UNKNOWN_PAIR}.items():
                with self.subTest(label=label):
                    tampered = json.loads(original)
                    by_variant = dict(zip(("candidate", "fixture"), refs))
                    tampered["candidate_ref"], tampered["fixture_ref"] = refs
                    for row in tampered["server_object_receipts"]:
                        if row["kind"] == "ref":
                            row["ref"] = by_variant[row["variant"]]
                    receipt.write_text(json.dumps(tampered))
                    refused = verify()
                    self.assertNotEqual(refused.returncode, 0, label)
                    self.assertIn("scoped refs", refused.stderr)
            receipt.write_text(original)
            self.assertEqual(verify().returncode, 0)

    def test_positive_control_an_r11_publication_stops_on_the_seeded_real_r11_refs_with_no_ref_changed(self):
        with tempfile.TemporaryDirectory(prefix="sigra-ref-pair-r11-over-r11-") as temp:
            env = self.freeze_environment(temp, ref_pair="r11")
            server = env["server"]
            seeded = real_earlier_refs()
            server.refs.update(seeded)
            self.assertNotEqual(seeded["gsd/253-replan-r11-candidate"], env["manifest"]["candidate_helper_commit"])
            allocation, ledger = self.canary_allocation(env)
            approval = self.write_approval(env, "canary")
            result = subprocess.run(self.publish_args(env["manifest_path"], allocation, ledger, env["root"] / "r11-receipt.json", env["repo"])
                                    + ["--freeze", str(env["freeze_path"]), "--action-approval", str(approval)],
                                    cwd=ROOT, text=True, capture_output=True, timeout=90)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("scoped ref gsd/253-replan-r11-candidate already points to a different commit", result.stderr)
            self.assertEqual(server.refs, seeded)
            self.assertFalse([row for row in server.journal if row["method"] == "POST" and row["path"].endswith("/git/refs")])


def commit_all(repo, message):
    git_run(repo, "add", "-A")
    git_run(repo, "-c", "user.name=Fixture", "-c", "user.email=fixture@example.test", "commit", "-qm", message)
    return git_run(repo, "rev-parse", "HEAD")


def stale_parent_repo(root):
    """253-134 reproduced: the candidate source sits on an old parent P0 while main advanced P0 -> M1 with conflicting edits
    to the same release-managed files; refs/remotes/origin/main and a main-fetch record name M1."""
    root.mkdir()
    subprocess.run(["git", "init", "-q", str(root)], check=True)
    (root / ".github/workflows").mkdir(parents=True)
    (root / ".github/workflows/ci.yml").write_text("name: CI\non:\n  pull_request:\n    branches: [main]\n")
    (root / "mix.exs").write_text('version: "1.4.0"\n')
    (root / "CHANGELOG.md").write_text("# Changelog\n\n## 1.4.0\n")
    (root / ".release-please-manifest.json").write_text('{".": "1.4.0"}\n')
    (root / "app.txt").write_text("base\n")
    p0 = commit_all(root, "P0")
    git_run(root, "checkout", "-q", "-b", "upstream-main")
    (root / "mix.exs").write_text('version: "1.5.0"\n')
    (root / "CHANGELOG.md").write_text("# Changelog\n\n## 1.5.0 (main)\n\n## 1.4.0\n")
    (root / ".release-please-manifest.json").write_text('{".": "1.5.0"}\n')
    m1 = commit_all(root, "M1: main advanced")
    git_run(root, "checkout", "-q", "-b", "candidate-source", p0)
    (root / "mix.exs").write_text('version: "1.4.1-candidate"\n')
    (root / "CHANGELOG.md").write_text("# Changelog\n\n## 1.4.1 (candidate)\n\n## 1.4.0\n")
    (root / ".release-please-manifest.json").write_text('{".": "1.4.1"}\n')
    (root / "app.txt").write_text("candidate\n")
    source = commit_all(root, "S: candidate on the stale parent")
    git_run(root, "update-ref", "refs/remotes/origin/main", m1)
    write_main_record(root, m1)
    return p0, m1, source


class MainFreshnessTests(unittest.TestCase):
    """253-138 (blind spot #4, offline half): an R12 publication or freeze must sit on the recorded fresh main and merge
    cleanly into it. 253-131/253-134 froze a candidate on the stale 84ebcea60 because nothing compared the parent with main."""

    make_local_publication = PublicationTests.make_local_publication
    prepare_registered = RegisteredPublicationTests.prepare_registered
    freeze_environment = RegisteredPublicationTests.freeze_environment

    def prepare(self, repo, source, parent, output, *extra):
        return subprocess.run(["python3", str(PUBLISHER), "--prepare", "--candidate-source", source, "--server-parent", parent,
                               "--repo-root", str(repo), "--output", str(output), *extra],
                              cwd=ROOT, text=True, capture_output=True)

    def test_merge_preflight_reports_conflicting_paths_clean_children_and_raises_on_unknown_objects(self):
        module = load_publisher()
        with tempfile.TemporaryDirectory(prefix="sigra-merge-preflight-") as temp:
            repo = pathlib.Path(temp) / "repo"
            repo.mkdir()
            subprocess.run(["git", "init", "-q", str(repo)], check=True)
            (repo / "mix.exs").write_text("base\n")
            (repo / "CHANGELOG.md").write_text("base\n")
            (repo / "other.txt").write_text("untouched\n")
            parent = commit_all(repo, "parent")
            git_run(repo, "checkout", "-q", "-b", "head-side")
            (repo / "mix.exs").write_text("head\n")
            (repo / "CHANGELOG.md").write_text("head\n")
            head = commit_all(repo, "head")
            git_run(repo, "checkout", "-q", "-b", "base-side", parent)
            (repo / "mix.exs").write_text("base side\n")
            (repo / "CHANGELOG.md").write_text("base side\n")
            base = commit_all(repo, "base")
            (repo / "other.txt").write_text("child of base\n")
            child = commit_all(repo, "child")
            conflicted = module.merge_preflight(repo, head, base)
            self.assertEqual(conflicted, {"head": head, "base": base, "exit": 1, "clean": False,
                                          "conflicts": ["CHANGELOG.md", "mix.exs"]})
            self.assertEqual(module.merge_preflight(repo, child, base),
                             {"head": child, "base": base, "exit": 0, "clean": True, "conflicts": []})
            refs_before = git_run(repo, "for-each-ref")
            for unknown in ("f" * 40, "not-a-commit"):
                with self.subTest(unknown=unknown):
                    with self.assertRaises(module.PublicationError):
                        module.merge_preflight(repo, unknown, base)
                    with self.assertRaises(module.PublicationError):
                        module.merge_preflight(repo, head, unknown)
            self.assertEqual(git_run(repo, "for-each-ref"), refs_before, "merge_preflight wrote a ref")
            self.assertEqual(git_run(repo, "status", "--porcelain"), "", "merge_preflight touched the working tree")

    def test_a_stale_server_parent_on_the_reproduced_253_134_shape_is_refused_with_no_output(self):
        with tempfile.TemporaryDirectory(prefix="sigra-stale-parent-") as temp:
            repo = pathlib.Path(temp) / "repo"
            p0, m1, source = stale_parent_repo(repo)
            output = pathlib.Path(temp) / "stale-manifest.json"
            refused = self.prepare(repo, source, p0, output, "--main-record", MAIN_RECORD_REL)
            self.assertNotEqual(refused.returncode, 0, f"the stale server parent {p0} was accepted: {refused.stdout.strip()}")
            self.assertIn("server parent is not the recorded fresh main", refused.stderr)
            self.assertFalse(output.exists(), "a refused stale-parent preparation wrote its manifest")

    def test_the_recorded_fresh_main_as_server_parent_is_ready_with_a_clean_main_freshness(self):
        module = load_publisher()
        with tempfile.TemporaryDirectory(prefix="sigra-fresh-parent-") as temp:
            repo = pathlib.Path(temp) / "repo"
            p0, m1, source = stale_parent_repo(repo)
            # Positive control: the source really conflicts with the advanced main on the release-managed files.
            self.assertEqual(module.merge_preflight(repo, source, m1)["conflicts"],
                             [".release-please-manifest.json", "CHANGELOG.md", "mix.exs"])
            output = pathlib.Path(temp) / "fresh-manifest.json"
            prepared = self.prepare(repo, source, m1, output, "--main-record", MAIN_RECORD_REL)
            self.assertEqual(prepared.returncode, 0, prepared.stderr)
            manifest = json.loads(output.read_text())
            self.assertEqual(manifest["status"], "ready-local-proposal")
            self.assertEqual(manifest["server_parent_sha"], m1)
            record_sha = hashlib.sha256((repo / MAIN_RECORD_REL).read_bytes()).hexdigest()
            self.assertEqual(manifest["main_freshness"], {
                "record_path": MAIN_RECORD_REL, "record_sha256": record_sha, "fetched_main_sha": m1,
                "fetched_at_utc": "2026-10-19T03:43:56Z",
                "merge_preflight": {"head": manifest["candidate_helper_commit"], "base": m1, "exit": 0, "clean": True,
                                    "conflicts": []},
                "candidate_parent_is_fetched_main": True})
            parents = git_run(repo, "rev-list", "--parents", "-n", "1", manifest["candidate_helper_commit"]).split()[1:]
            self.assertEqual(parents, [m1])
            checked = subprocess.run(["python3", str(PUBLISHER), "--check-manifest", str(output)], cwd=ROOT, text=True,
                                     capture_output=True)
            self.assertEqual(checked.returncode, 0, checked.stderr)
            # Without --main-record the pre-R12 preparation is unchanged (no main_freshness block).
            plain = pathlib.Path(temp) / "plain-manifest.json"
            self.assertEqual(self.prepare(repo, source, p0, plain).returncode, 0)
            self.assertNotIn("main_freshness", json.loads(plain.read_text()))

    def test_a_record_that_is_not_a_fetched_r12_record_or_disagrees_with_local_main_is_refused_with_no_output(self):
        with tempfile.TemporaryDirectory(prefix="sigra-bad-main-record-") as temp:
            repo = pathlib.Path(temp) / "repo"
            p0, m1, source = stale_parent_repo(repo)
            absent = "0123456789abcdef0123456789abcdef01234567"
            cases = {
                "wrong schema": ({"schema_version": "sigra.phase253.main-fetch/r11"}, None,
                                 "main-fetch record is not a fetched sigra.phase253.main-fetch/r12 record"),
                "status failed": ({"status": "failed"}, None,
                                  "main-fetch record is not a fetched sigra.phase253.main-fetch/r12 record"),
                "fetched main absent locally": ({"fetched_main_sha": absent, "fetch_head_sha": absent}, None,
                                                "is not present in the local object store"),
                "local origin/main moved": ({}, p0, "local origin/main differs from the main-fetch record"),
                "local origin/main missing": ({}, "delete", "local origin/main differs from the main-fetch record"),
            }
            for label, (overrides, origin, message) in cases.items():
                with self.subTest(label=label):
                    write_main_record(repo, m1, **overrides)
                    if origin == "delete":
                        git_run(repo, "update-ref", "-d", "refs/remotes/origin/main")
                    elif origin:
                        git_run(repo, "update-ref", "refs/remotes/origin/main", origin)
                    output = pathlib.Path(temp) / f"{label.replace(' ', '-').replace('/', '-')}.json"
                    parent = absent if "absent" in label else m1
                    refused = self.prepare(repo, source, parent, output, "--main-record", MAIN_RECORD_REL)
                    self.assertNotEqual(refused.returncode, 0, f"{label} accepted: {refused.stdout.strip()}")
                    self.assertIn(message, refused.stderr)
                    self.assertFalse(output.exists(), f"{label} wrote a manifest")
                    git_run(repo, "update-ref", "refs/remotes/origin/main", m1)
            write_main_record(repo, m1)
            control = pathlib.Path(temp) / "control.json"
            accepted = self.prepare(repo, source, m1, control, "--main-record", MAIN_RECORD_REL)
            self.assertEqual(accepted.returncode, 0, accepted.stderr)

    def build(self, env, manifest_rel, output_rel, ref_pair="r12"):
        return subprocess.run(["python3", str(PUBLISHER), "--build-freeze", "--manifest", manifest_rel, "--output", output_rel,
                               "--repo-root", str(env["repo"]), "--ref-pair", ref_pair, "--freeze-plan", "253-138"],
                              cwd=ROOT, text=True, capture_output=True)

    def test_an_r12_freeze_refuses_a_manifest_without_a_clean_main_freshness_on_its_server_parent(self):
        with tempfile.TemporaryDirectory(prefix="sigra-r12-freeze-freshness-") as temp:
            env = self.freeze_environment(temp, ref_pair="r12", main_record=True)
            record_sha = hashlib.sha256((env["repo"] / MAIN_RECORD_REL).read_bytes()).hexdigest()
            self.assertEqual(env["freeze"]["bound_documents"]["main_freshness_record"],
                             {"path": MAIN_RECORD_REL, "sha256": record_sha})
            good = json.loads((env["repo"] / env["manifest_rel"]).read_text())

            def no_freshness(value):
                del value["main_freshness"]

            def conflicting(value):
                value["main_freshness"]["merge_preflight"].update({"exit": 1, "clean": False, "conflicts": ["mix.exs"]})

            def other_parent(value):
                value["main_freshness"]["fetched_main_sha"] = env["source"]
                value["main_freshness"]["merge_preflight"]["base"] = env["source"]
            cases = {"no main_freshness": (no_freshness, "main_freshness"),
                     "conflicting merge preflight": (conflicting, "candidate does not merge cleanly into the recorded fresh main: mix.exs"),
                     "server parent differs from the fetched main": (other_parent, "server parent is not the recorded fresh main")}
            for index, (label, (mutate, message)) in enumerate(cases.items()):
                with self.subTest(label=label):
                    value = json.loads(json.dumps(good))
                    mutate(value)
                    rel = f"{PHASE_REL}/bad-manifest-{index}.json"
                    (env["repo"] / rel).write_text(json.dumps(value, indent=2) + "\n")
                    commit_all(env["repo"], f"planning: {label}")
                    output_rel = f"{PHASE_REL}/bad-freeze-{index}.json"
                    refused = self.build(env, rel, output_rel)
                    self.assertNotEqual(refused.returncode, 0, f"{label} accepted: {refused.stdout.strip()}")
                    self.assertIn(message, refused.stderr)
                    self.assertFalse((env["repo"] / output_rel).exists(), f"{label} wrote a freeze")
            accepted = self.build(env, env["manifest_rel"], f"{PHASE_REL}/control-freeze.json")
            self.assertEqual(accepted.returncode, 0, accepted.stderr)

    def test_check_freeze_rehashes_the_main_record_and_never_reads_origin_main(self):
        with tempfile.TemporaryDirectory(prefix="sigra-r12-check-freshness-") as temp:
            env = self.freeze_environment(temp, ref_pair="r12", main_record=True)
            record = env["repo"] / MAIN_RECORD_REL
            original = record.read_bytes()

            def check():
                return subprocess.run(["python3", str(PUBLISHER), "--check-freeze", str(env["freeze_path"]),
                                       "--repo-root", str(env["repo"])], cwd=ROOT, text=True, capture_output=True)
            first = check()
            self.assertEqual(first.returncode, 0, first.stderr)
            record.write_bytes(original.replace(b'"fetched"', b'"fetched" '))
            changed = check()
            self.assertNotEqual(changed.returncode, 0, "a changed main-fetch record still validated")
            self.assertIn("main_freshness_record", changed.stderr)
            record.write_bytes(original)
            self.assertEqual(check().returncode, 0)
            # A later re-fetch moves the local origin/main; the freeze binds the record, never the ref.
            git_run(env["repo"], "update-ref", "refs/remotes/origin/main", env["source"])
            moved = check()
            self.assertEqual(moved.returncode, 0, moved.stderr)
            git_run(env["repo"], "update-ref", "-d", "refs/remotes/origin/main")
            deleted = check()
            self.assertEqual(deleted.returncode, 0, deleted.stderr)

    def test_earlier_pairs_build_freezes_without_a_main_record_exactly_as_before(self):
        for pair in ("r11", "r10", "legacy"):
            with self.subTest(pair=pair):
                with tempfile.TemporaryDirectory(prefix=f"sigra-{pair}-no-main-record-") as temp:
                    env = self.freeze_environment(temp, ref_pair=pair)
                    self.assertNotIn("main_freshness", env["manifest"])
                    self.assertEqual(set(env["freeze"]["bound_documents"]), {"publication_manifest", "fixture_workflow"})


R13_PAIR = ("refs/heads/gsd/253-replan-r13-candidate", "refs/heads/gsd/253-replan-r13-fixture")
R13_CANARY_TABLE = {"preflight": 16, "publication": 24, "dispatch": 7, "run_discovery": 7, "pre_watch_rate": 7,
                    "terminal_polls": 18, "attempt_jobs": 7, "artifact_metadata": 7, "artifact_downloads": 12,
                    "failure_logs": 6, "cancellation": 1, "infrastructure_retry": 5}


def real_earlier_refs_r13():
    """253-166: the ten refs 253-104, 253-113, 253-122, 253-133 and 253-143 created on GitHub, at their real SHAs. The
    r8-r11 values come from real_earlier_refs() (seed tables and FREEZE-R11) and the r12 values from FREEZE-R12's
    identity (never retyped)."""
    identity = json.loads((ROOT / PHASE_REL / "253-LOAD-RECOVERY-CANARY-FREEZE-R12.json").read_text())["identity"]
    r12 = {identity["candidate_ref"].removeprefix("refs/heads/"): identity["candidate_helper_commit"],
           identity["fixture_ref"].removeprefix("refs/heads/"): identity["fixture_workflow_commit"]}
    return {**real_earlier_refs(), **r12}


class R13RefPairTests(unittest.TestCase):
    """253-166: r13 is the seventh code-pinned pair, under the 253-138 main-freshness guard through one pair set, with its
    own canary table (preflight 16, infrastructure_retry 5). The r8-r12 refs already on GitHub are never read, moved or
    deleted."""

    make_local_publication = PublicationTests.make_local_publication
    prepare_registered = RegisteredPublicationTests.prepare_registered
    freeze_environment = RegisteredPublicationTests.freeze_environment
    write_approval = RegisteredPublicationTests.write_approval
    canary_allocation = RegisteredPublicationTests.canary_allocation
    publish_args = RegisteredPublicationTests.publish_args

    def build(self, env, manifest_rel, output_rel, ref_pair="r13"):
        return subprocess.run(["python3", str(PUBLISHER), "--build-freeze", "--manifest", manifest_rel, "--output", output_rel,
                               "--repo-root", str(env["repo"]), "--ref-pair", ref_pair, "--freeze-plan", "253-166"],
                              cwd=ROOT, text=True, capture_output=True)

    def check(self, env, path=None):
        return subprocess.run(["python3", str(PUBLISHER), "--check-freeze", str(path or env["freeze_path"]),
                               "--repo-root", str(env["repo"])], cwd=ROOT, text=True, capture_output=True)

    def test_r13_is_a_known_pair_and_every_mixed_or_unknown_pair_is_refused(self):
        module = load_publisher()
        self.assertEqual(module.REF_PAIRS["r13"], {"candidate": "gsd/253-replan-r13-candidate", "fixture": "gsd/253-replan-r13-fixture"})
        self.assertEqual(len(module.REF_PAIRS), 7)
        self.assertEqual(module.DEFAULT_REF_PAIR, "legacy")
        self.assertEqual(module.ref_pair_name(*R13_PAIR), "r13")
        self.assertEqual(module.ref_pair_name(*R12_PAIR), "r12")
        for mixed in ((R13_PAIR[0], R12_PAIR[1]), (R12_PAIR[0], R13_PAIR[1]), (R13_PAIR[0], R11_PAIR[1]),
                      (R13_PAIR[0], R8_PAIR[1]), (R13_PAIR[0], LEGACY_PAIR[1]), (R13_PAIR[1], R13_PAIR[0]), UNKNOWN_PAIR,
                      ("refs/heads/gsd/253-replan-r130-candidate", "refs/heads/gsd/253-replan-r130-fixture"),
                      ("gsd/253-replan-r13-candidate", "gsd/253-replan-r13-fixture")):
            with self.subTest(mixed=mixed):
                with self.assertRaises(module.PublicationError):
                    module.ref_pair_name(*mixed)
        with self.assertRaises(module.PublicationError) as raised:
            module.ref_pair_name(R13_PAIR[0], R12_PAIR[1])
        self.assertIn("legacy, r8, r9, r10, r11, r12 or r13", str(raised.exception))
        helped = subprocess.run(["python3", str(PUBLISHER), "--help"], cwd=ROOT, text=True, capture_output=True)
        self.assertEqual(helped.returncode, 0)
        self.assertIn("legacy (default), r8, r9, r10, r11, r12 or r13", " ".join(helped.stdout.split()))

    def test_the_main_freshness_guard_keys_on_one_pair_set_naming_r12_and_r13(self):
        module = load_publisher()
        self.assertEqual(module.MAIN_FRESHNESS_PAIRS, ("r12", "r13"))
        source = PUBLISHER.read_text()
        code = "\n".join(line for line in source.splitlines() if not line.lstrip().startswith("#"))
        self.assertNotIn('ref_pair == "r12"', code)
        self.assertNotIn('pair_name == "r12"', code)
        self.assertGreaterEqual(code.count("MAIN_FRESHNESS_PAIRS"), 3)

    def test_an_r13_identity_moves_every_candidate_and_fixture_ref_to_the_r13_names(self):
        module = load_publisher()
        r12 = json.loads((ROOT / PHASE_REL / "253-LOAD-RECOVERY-CANARY-FREEZE-R12.json").read_text())["identity"]
        identity = {**r12, "candidate_ref": R13_PAIR[0], "fixture_ref": R13_PAIR[1]}
        sections, _ = module.build_outward_actions(identity)
        canary, docs = sections["canary"]["actions"], sections["docs_and_prs"]["actions"]
        self.assertEqual([a["ref"] for a in canary if a["action"] == "create_ref"], list(R13_PAIR))
        self.assertEqual({a["ref"] for a in canary if a["action"] == "workflow_dispatch"}, {"gsd/253-replan-r13-fixture"})
        prs = {a["family"]: (a["head"], a["base"]) for a in docs if a["action"] == "pr_create"}
        self.assertEqual(prs, {"normal": ("gsd/253-replan-r13-candidate", "main"),
                               "docs-only": ("gsd/253-replan-docs-head", "gsd/253-replan-docs-base")})
        for earlier in ("253-replan-r12-", "253-replan-r11-", "253-replan-r10-", "253-replan-r9-", "253-replan-r8-"):
            self.assertNotIn(earlier, json.dumps(sections))
        # Positive control: the unchanged FREEZE-R12 identity still derives its committed outward actions.
        freeze = json.loads((ROOT / PHASE_REL / "253-LOAD-RECOVERY-CANARY-FREEZE-R12.json").read_text())
        self.assertEqual(module.build_outward_actions(freeze["identity"]), (freeze["outward_actions"], freeze["outward_actions_sha256"]))

    def test_the_r13_canary_table_moves_eight_requests_from_the_expired_retry_to_preflight_and_nothing_else(self):
        module = load_publisher()
        self.assertEqual(module.CANARY_CATEGORIES_R13, R13_CANARY_TABLE)
        self.assertEqual(sum(module.CANARY_CATEGORIES_R13.values()), 117)
        self.assertEqual(module.CANARY_CATEGORIES["preflight"], 8)
        self.assertEqual(module.CANARY_CATEGORIES["infrastructure_retry"], 13)
        self.assertEqual(sum(module.CANARY_CATEGORIES.values()), 117)
        # Every committed earlier freeze still carries the legacy table and a 13-request expired retry.
        for name in ("253-LOAD-RECOVERY-CANARY-FREEZE-R12.json", "253-LOAD-RECOVERY-CANARY-FREEZE-R11.json"):
            with self.subTest(freeze=name):
                value = json.loads((ROOT / PHASE_REL / name).read_text())
                self.assertEqual(value["categories"]["canary"], module.CANARY_CATEGORIES)
                self.assertEqual(value["expired_reruns"]["canary"]["requests"], 13)

    def test_an_r13_freeze_needs_a_clean_main_freshness_on_its_server_parent_and_binds_the_record(self):
        with tempfile.TemporaryDirectory(prefix="sigra-r13-freeze-freshness-") as temp:
            env = self.freeze_environment(temp, ref_pair="r13", main_record=True)
            self.assertEqual((env["freeze"]["identity"]["candidate_ref"], env["freeze"]["identity"]["fixture_ref"]), R13_PAIR)
            record_sha = hashlib.sha256((env["repo"] / MAIN_RECORD_REL).read_bytes()).hexdigest()
            self.assertEqual(env["freeze"]["bound_documents"]["main_freshness_record"], {"path": MAIN_RECORD_REL, "sha256": record_sha})
            good = json.loads((env["repo"] / env["manifest_rel"]).read_text())

            def no_freshness(value):
                del value["main_freshness"]

            def conflicting(value):
                value["main_freshness"]["merge_preflight"].update({"exit": 1, "clean": False, "conflicts": ["mix.exs"]})

            def other_parent(value):
                value["main_freshness"]["fetched_main_sha"] = env["source"]
                value["main_freshness"]["merge_preflight"]["base"] = env["source"]
            cases = {"no main_freshness": (no_freshness, "an r13 freeze needs a publication manifest with main_freshness"),
                     "conflicting merge preflight": (conflicting, "candidate does not merge cleanly into the recorded fresh main: mix.exs"),
                     "server parent differs from the fetched main": (other_parent, "server parent is not the recorded fresh main")}
            for index, (label, (mutate, message)) in enumerate(cases.items()):
                with self.subTest(label=label):
                    value = json.loads(json.dumps(good))
                    mutate(value)
                    rel = f"{PHASE_REL}/bad-r13-manifest-{index}.json"
                    (env["repo"] / rel).write_text(json.dumps(value, indent=2) + "\n")
                    commit_all(env["repo"], f"planning: {label}")
                    output_rel = f"{PHASE_REL}/bad-r13-freeze-{index}.json"
                    refused = self.build(env, rel, output_rel)
                    self.assertNotEqual(refused.returncode, 0, f"{label} accepted: {refused.stdout.strip()}")
                    self.assertIn(message, refused.stderr)
                    self.assertFalse((env["repo"] / output_rel).exists(), f"{label} wrote a freeze")
            accepted = self.build(env, env["manifest_rel"], f"{PHASE_REL}/control-r13-freeze.json")
            self.assertEqual(accepted.returncode, 0, accepted.stderr)

    def test_an_r13_freeze_without_a_main_record_is_refused_and_writes_nothing(self):
        with tempfile.TemporaryDirectory(prefix="sigra-r13-no-record-") as temp:
            env = self.freeze_environment(temp)
            self.assertNotIn("main_freshness", env["manifest"])
            output_rel = f"{PHASE_REL}/r13-no-record.json"
            refused = self.build(env, env["manifest_rel"], output_rel)
            self.assertNotEqual(refused.returncode, 0)
            self.assertIn("an r13 freeze needs a publication manifest with main_freshness (prepare with --main-record)", refused.stderr)
            self.assertFalse((env["repo"] / output_rel).exists())
            # Positive control: the same manifest still builds an r11 freeze, which has no main-freshness guard.
            self.assertEqual(self.build(env, env["manifest_rel"], f"{PHASE_REL}/r11-no-record.json", ref_pair="r11").returncode, 0)

    def test_check_freeze_rehashes_the_r13_main_record(self):
        with tempfile.TemporaryDirectory(prefix="sigra-r13-check-freshness-") as temp:
            env = self.freeze_environment(temp, ref_pair="r13", main_record=True)
            record = env["repo"] / MAIN_RECORD_REL
            original = record.read_bytes()
            first = self.check(env)
            self.assertEqual(first.returncode, 0, first.stderr)
            record.write_bytes(original.replace(b'"fetched"', b'"fetched" '))
            changed = self.check(env)
            self.assertNotEqual(changed.returncode, 0, "a changed main-fetch record still validated")
            self.assertIn("main_freshness_record", changed.stderr)
            record.write_bytes(original)
            self.assertEqual(self.check(env).returncode, 0)
            value = json.loads(env["freeze_path"].read_text())
            del value["bound_documents"]["main_freshness_record"]
            env["freeze_path"].write_text(json.dumps(value, indent=2))
            unbound = self.check(env)
            self.assertNotEqual(unbound.returncode, 0, "an r13 freeze without its main-record binding validated")
            self.assertIn("main_freshness_record", unbound.stderr)

    def test_an_r13_freeze_carries_the_r13_canary_table_and_an_r12_freeze_the_legacy_one(self):
        module = load_publisher()
        with tempfile.TemporaryDirectory(prefix="sigra-r13-canary-table-") as temp:
            env = self.freeze_environment(temp, ref_pair="r13", main_record=True)
            self.assertEqual(env["freeze"]["categories"]["canary"], R13_CANARY_TABLE)
            self.assertEqual(env["freeze"]["categories"]["production"], module.PRODUCTION_CATEGORIES)
            self.assertEqual(env["freeze"]["expired_reruns"]["canary"],
                             {"category": "infrastructure_retry", "status": "expired", "requests": 5, "jobs": 6, "used": 0,
                              "reason": module.RERUN_REASON})
            self.assertEqual(self.check(env).returncode, 0)
            original = env["freeze_path"].read_text()
            legacy_table = json.loads(original)
            legacy_table["categories"]["canary"] = dict(module.CANARY_CATEGORIES)
            both = json.loads(json.dumps(legacy_table))
            both["expired_reruns"]["canary"]["requests"] = 13
            retry_only = json.loads(original)
            retry_only["expired_reruns"]["canary"]["requests"] = 13
            for label, value in {"canary table edited back to the R12 values": legacy_table,
                                 "table and expired retry edited back to the R12 values": both,
                                 "expired retry edited back to 13": retry_only}.items():
                with self.subTest(label=label):
                    env["freeze_path"].write_text(json.dumps(value, indent=2))
                    refused = self.check(env)
                    self.assertNotEqual(refused.returncode, 0, f"{label} validated")
                    self.assertIn("differs from the frozen policy", refused.stderr)
            env["freeze_path"].write_text(original)
            self.assertEqual(self.check(env).returncode, 0)
        with tempfile.TemporaryDirectory(prefix="sigra-r12-canary-table-") as temp:
            env = self.freeze_environment(temp, ref_pair="r12", main_record=True)
            self.assertEqual(env["freeze"]["categories"]["canary"], module.CANARY_CATEGORIES)
            self.assertEqual(env["freeze"]["categories"]["canary"]["preflight"], 8)
            self.assertEqual(env["freeze"]["categories"]["canary"]["infrastructure_retry"], 13)
            self.assertEqual(env["freeze"]["expired_reruns"]["canary"]["requests"], 13)
            self.assertEqual(self.check(env).returncode, 0)
            value = json.loads(env["freeze_path"].read_text())
            value["categories"]["canary"] = dict(R13_CANARY_TABLE)
            value["expired_reruns"]["canary"]["requests"] = 5
            env["freeze_path"].write_text(json.dumps(value, indent=2))
            refused = self.check(env)
            self.assertNotEqual(refused.returncode, 0, "an r12 freeze carrying the r13 table validated")
            self.assertIn("differs from the frozen policy", refused.stderr)

    def test_the_seed_table_is_the_ten_real_refs_from_the_committed_records(self):
        refs = real_earlier_refs_r13()
        self.assertEqual(len(refs), 10)
        self.assertEqual(set(refs), {f"gsd/253-replan-{pair}-{variant}" for pair in ("r8", "r9", "r10", "r11", "r12")
                                     for variant in ("candidate", "fixture")})
        self.assertEqual(refs["gsd/253-replan-r12-candidate"], "6e4f87657254ed9d4a3c8b661d5e707751bc5214")
        self.assertEqual(refs["gsd/253-replan-r12-fixture"], "b37f05424b2b497b3c786fc604caa4dab4dbcdf0")
        self.assertEqual(len(set(refs.values())), 10)

    def test_r13_publication_creates_only_the_r13_refs_beside_the_five_seeded_earlier_pairs(self):
        with tempfile.TemporaryDirectory(prefix="sigra-ref-pair-r13-publish-") as temp:
            env = self.freeze_environment(temp, ref_pair="r13", main_record=True)
            server, manifest = env["server"], env["manifest"]
            seeded = real_earlier_refs_r13()
            server.refs.update(seeded)
            allocation, ledger = self.canary_allocation(env)
            approval = self.write_approval(env, "canary")
            receipt = env["root"] / "r13-receipt.json"
            result = subprocess.run(self.publish_args(env["manifest_path"], allocation, ledger, receipt, env["repo"])
                                    + ["--freeze", str(env["freeze_path"]), "--action-approval", str(approval)],
                                    cwd=ROOT, text=True, capture_output=True, timeout=90)
            self.assertEqual(result.returncode, 0, result.stderr + json.dumps(server.journal))
            self.assertEqual(server.refs["gsd/253-replan-r13-candidate"], manifest["candidate_helper_commit"])
            self.assertEqual(server.refs["gsd/253-replan-r13-fixture"], manifest["fixture_workflow_commit"])
            for name, sha in seeded.items():
                with self.subTest(seeded=name):
                    self.assertEqual(server.refs[name], sha)
            self.assertEqual(set(server.refs), set(seeded) | {"gsd/253-replan-r13-candidate", "gsd/253-replan-r13-fixture"})
            ref_paths = [row["path"] for row in server.journal if "/git/ref" in row["path"]]
            self.assertTrue([path for path in ref_paths if "253-replan-r13-" in path])
            self.assertFalse([path for path in ref_paths if any(f"253-replan-{p}-" in path for p in ("r8", "r9", "r10", "r11", "r12"))],
                             "an r13 publication read or wrote an r8, r9, r10, r11 or r12 ref")
            for name in ("gsd/253-replan-r13-candidate", "gsd/253-replan-r13-fixture"):
                with self.subTest(create_only=name):
                    touching = [row for row in server.journal if row["path"].endswith("/git/ref/heads/" + name)]
                    self.assertTrue(touching and touching[0]["method"] == "GET", "get_ref must run before create_ref")
            ref_posts = [row for row in server.journal if row["method"] == "POST" and row["path"].endswith("/git/refs")]
            self.assertEqual(len(ref_posts), 2)
            self.assertFalse([row for row in server.journal if row["method"] in ("DELETE", "PATCH")])
            value = json.loads(receipt.read_text())
            self.assertEqual((value["candidate_ref"], value["fixture_ref"]), R13_PAIR)
            verified = subprocess.run(["python3", str(PUBLISHER), "--verify-publication", str(receipt)], cwd=ROOT, text=True,
                                      capture_output=True)
            self.assertEqual(verified.returncode, 0, verified.stderr)

    def test_positive_control_an_r12_publication_stops_on_the_seeded_real_r12_refs_with_no_ref_changed(self):
        with tempfile.TemporaryDirectory(prefix="sigra-ref-pair-r12-over-r12-") as temp:
            env = self.freeze_environment(temp, ref_pair="r12", main_record=True)
            server = env["server"]
            seeded = real_earlier_refs_r13()
            server.refs.update(seeded)
            self.assertNotEqual(seeded["gsd/253-replan-r12-candidate"], env["manifest"]["candidate_helper_commit"])
            allocation, ledger = self.canary_allocation(env)
            approval = self.write_approval(env, "canary")
            result = subprocess.run(self.publish_args(env["manifest_path"], allocation, ledger, env["root"] / "r12-receipt.json", env["repo"])
                                    + ["--freeze", str(env["freeze_path"]), "--action-approval", str(approval)],
                                    cwd=ROOT, text=True, capture_output=True, timeout=90)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("scoped ref gsd/253-replan-r12-candidate already points to a different commit", result.stderr)
            self.assertEqual(server.refs, seeded)
            self.assertFalse([row for row in server.journal if row["method"] == "POST" and row["path"].endswith("/git/refs")])


class LiveOriginDerivationTests(unittest.TestCase):
    """253-110: derive_origin's live branch, called directly (the publish-time and verify-time label rule)."""

    def setUp(self):
        self.publisher = load_publisher()
        self.live = {"mode": "live", "window_id": "253-113-canary-window-1"}

    def ledger(self, *hosts, state="complete"):
        return {"transactions": [{"sequence": index, "host": host, "state": state} for index, host in enumerate(hosts, 1)]}

    def test_live_allocation_with_an_all_api_complete_ledger_is_actual_github_with_its_window(self):
        origin = self.publisher.derive_origin(self.live, self.ledger("api.github.com", "api.github.com"))
        self.assertEqual((origin["kind"], origin["host"], origin["allocation_mode"], origin["transactions"], origin["window_id"]),
                         ("actual-github", "api.github.com", "live", 2, "253-113-canary-window-1"))

    def test_live_allocation_refuses_any_non_api_publication_host_or_incomplete_transaction(self):
        for label, ledger in {
            "blob host": self.ledger("api.github.com", "productionresultssa17.blob.core.windows.net"),
            "pipelines host": self.ledger("pipelines.actions.githubusercontent.com"),
            "local origin": self.ledger("localhost"),
            "missing host": {"transactions": [{"sequence": 1, "state": "complete"}]},
            "pending transaction": self.ledger("api.github.com", state="pending"),
            "empty ledger": self.ledger(),
        }.items():
            with self.subTest(case=label):
                with self.assertRaisesRegex(self.publisher.PublicationError, "non-GitHub host or an incomplete transaction"):
                    self.publisher.derive_origin(self.live, ledger)

    def test_a_hermetic_allocation_is_labelled_hermetic_whatever_its_hosts(self):
        origin = self.publisher.derive_origin({"mode": "hermetic-test", "window_id": "w"}, self.ledger("api.github.com"))
        self.assertEqual(origin["kind"], "hermetic")



LEDGER_R9 = ROOT / PHASE_REL / "253-LOAD-RECOVERY-CANARY-HTTP-LEDGER-R9.json"
PUBLICATION_RECEIPT_R9 = ROOT / PHASE_REL / "253-LOAD-RECOVERY-CANARY-PUBLICATION-RECEIPT-R9.json"


class RealPublicationShapeTests(unittest.TestCase):
    """253-118 (D-18/D-23): the publication readbacks against GitHub's recorded responses (the R9 window's 17 publication
    transactions), not the local object server's. Every field the publisher compares must be where GitHub put it."""

    def setUp(self):
        self.publisher = load_publisher()
        self.ledger = json.loads(LEDGER_R9.read_text())
        self.receipt = json.loads(PUBLICATION_RECEIPT_R9.read_text())

    def rows(self, route, status=None):
        return [(tx, json.loads(base64.b64decode(tx["response_body_base64"]))) for tx in self.ledger["transactions"]
                if tx["route_id"] == route and (status is None or tx["actual_status"] == status)]

    def test_live_r9_real_publication_ledger_proves_every_receipt_identity_and_readback_field(self):
        found = self.publisher.ledger_identities(self.ledger)
        for wanted in self.publisher.required_identities(self.receipt):
            with self.subTest(identity=wanted):
                self.assertTrue(self.publisher.identity_present(found, wanted))
        commits = {row["sha"]: row for row in self.receipt["server_object_receipts"] if row["kind"] == "commit"}
        readbacks = [body for _tx, body in self.rows("git_get_commit", 200) if body["sha"] in commits]
        self.assertEqual(sorted(body["sha"] for body in readbacks), sorted(commits))
        for body in readbacks:
            sent = commits[body["sha"]]
            self.assertEqual(body["tree"]["sha"], sent["tree"])
            self.assertEqual([parent["sha"] for parent in body["parents"]], [sent["parent"]])
            self.assertTrue(self.publisher.commit_message_matches(body["message"], sent["message"]))
            self.assertEqual(body["message"] == sent["message"], sent["server_message_form"] == "verbatim")
            for role in ("author", "committer"):
                self.assertEqual(set(body[role]), {"name", "email", "date"})
        created = [body for _tx, body in self.rows("git_create_commit", 201)]
        self.assertEqual(sorted(body["sha"] for body in created), sorted(commits))
        blobs = self.rows("git_get_blob", 200)
        self.assertEqual(len(blobs), 2)
        for _tx, body in blobs:
            data = base64.b64decode(body["content"].replace("\n", ""))
            self.assertEqual(body["encoding"], "base64")
            self.assertEqual((self.publisher.object_sha("blob", data), body["size"]), (body["sha"], len(data)))
        self.assertEqual({body["sha"] for _tx, body in self.rows("git_create_tree", 201)},
                         {row["sha"] for row in self.receipt["server_object_receipts"] if row["kind"] == "tree"})
        refs = {self.receipt["candidate_ref"]: self.receipt["candidate_sha"], self.receipt["fixture_ref"]: self.receipt["fixture_sha"]}
        for route, status in (("create_ref", 201), ("get_ref", 200)):
            bodies = [body for _tx, body in self.rows(route, status)]
            self.assertTrue(bodies)
            for body in bodies:
                self.assertEqual(body["object"]["sha"], refs[body["ref"]])
        probes = self.rows("get_ref", 404)
        self.assertEqual(len(probes), 2)
        self.assertTrue(all(tx["actual_status"] == 404 and "ref" not in body for tx, body in probes))
        # Negative control: the same check on a scratch copy without the ref readbacks loses the ref identities.
        stripped = {"transactions": [tx for tx in self.ledger["transactions"] if tx["route_id"] not in ("get_ref", "create_ref")]}
        lost = self.publisher.ledger_identities(stripped)
        self.assertFalse(all(self.publisher.identity_present(lost, wanted) for wanted in self.publisher.required_identities(self.receipt)))



EVIDENCE_R9 = ROOT / PHASE_REL / "253-LOAD-RECOVERY-CANARY-EVIDENCE-R9.json"
EVIDENCE_R9_SHA256 = "a3ca8cc0b562b2a060540f6b55fc1c0d29907c7103f87db970e1f4f678043aba"
SOURCE_SCENARIOS = ("full-pass", "docs-only", "actual-failure", "missing-seam", "unexpected-skip", "cancelled")
ISO_TIME = re.compile(r'"(20[0-9]{2}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z)"')


def load_hosted_verifier():
    import importlib.util
    spec = importlib.util.spec_from_file_location("hosted_gate_verify_compact_matrix", ROOT / "scripts/ci/ci-hosted-gate-verify.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def derived_receipt(real, scenario, index):
    """One scenario receipt derived from the real R9 full-pass receipt: its own run, job and artifact ids, run-name,
    shifted timestamps, random node ids and runner ids, and fresh random archive bytes of the real archive's length.
    Every scenario keeps an archive (the real cancelled source has none), so the size is an upper bound."""
    import datetime
    import random
    rng = random.Random(253118 + index)
    run_id = str(real["run_id"])
    new_run = str(int(run_id) + 1000 * index)
    text = json.dumps(real)
    for job in real["jobs"]["jobs"]:
        text = text.replace(str(job["id"]), str(job["id"] + 10_000_000 * index))
    for artifact in real["artifacts"]["artifacts"]:
        text = text.replace(str(artifact["id"]), str(artifact["id"] + index))
    text = text.replace(run_id, new_run).replace("/ full-pass /", f"/ {scenario} /").replace("gate-canary-full-pass-",
                                                                                           f"gate-canary-{scenario}-")
    shift = datetime.timedelta(minutes=7 * index, seconds=index)
    text = ISO_TIME.sub(lambda match: '"' + (datetime.datetime.strptime(match.group(1), "%Y-%m-%dT%H:%M:%SZ") + shift)
                        .strftime("%Y-%m-%dT%H:%M:%SZ") + '"', text)
    receipt = json.loads(text)
    alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-"

    def scramble(value):
        if isinstance(value, dict):
            for key, item in value.items():
                if key == "node_id" and isinstance(item, str):
                    value[key] = item[:3] + "".join(rng.choice(alphabet) for _ in item[3:])
                elif key == "runner_id" and type(item) is int and item:
                    value[key] = rng.randrange(1_000_000_000, 1_999_999_999)
                    value["runner_name"] = f"GitHub Actions {value[key]}"
                else:
                    scramble(item)
        elif isinstance(value, list):
            for item in value:
                scramble(item)
    scramble(receipt)
    retained = receipt["retained_artifact"]
    archive = bytes(rng.randrange(256) for _ in range(len(base64.b64decode(real["retained_artifact"]["archive_base64"]))))
    digest = hashlib.sha256(archive).hexdigest()
    retained.update(archive_base64=base64.b64encode(archive).decode("ascii"), archive_sha256=digest)
    for artifact in receipt["artifacts"]["artifacts"]:
        if str(artifact["id"]) == str(retained["artifact_id"]):
            artifact["digest"] = "sha256:" + digest
    return receipt


class RealShapeCompactMatrixTests(unittest.TestCase):
    """253-118 (D-16/D-23): the separate verifier's dispatch input, measured on receipts with GitHub's real shape (the R9
    full-pass receipt of run 38906314106) rather than on fake receipts, plus a real-bytes round trip of the compaction."""

    def setUp(self):
        self.publisher = load_publisher()
        self.raw = EVIDENCE_R9.read_bytes()
        self.assertEqual(hashlib.sha256(self.raw).hexdigest(), EVIDENCE_R9_SHA256)
        self.evidence = json.loads(self.raw)
        self.tmp = tempfile.TemporaryDirectory(prefix="sigra-253-118-matrix-")
        self.addCleanup(self.tmp.cleanup)

    def write(self, name, value):
        path = pathlib.Path(self.tmp.name) / name
        path.write_text(json.dumps(value, sort_keys=True))
        return path

    def six(self):
        real = self.evidence["scenarios"]["full-pass"]
        scenarios = {name: derived_receipt(real, name, index) for index, name in enumerate(SOURCE_SCENARIOS, 1)}
        return dict(self.evidence, scenarios=scenarios)

    def test_live_real_shape_compact_matrix_fits_and_round_trips(self):
        verifier = load_hosted_verifier()
        limit = self.publisher.MATRIX_PAYLOAD_LIMIT
        self.assertEqual(limit, 64511)
        matrix = self.six()
        run_ids = {receipt["run_id"] for receipt in matrix["scenarios"].values()}
        archives = {receipt["retained_artifact"]["archive_sha256"] for receipt in matrix["scenarios"].values()}
        titles = {receipt["run"]["display_title"] for receipt in matrix["scenarios"].values()}
        self.assertEqual((len(run_ids), len(archives), len(titles)), (6, 6, 6))
        payload = self.publisher.compact_matrix(self.write("six.json", matrix))
        self.assertLess(len(payload), limit)
        print(f"\nreal-shape compact matrix: {len(payload)} characters, limit {limit}, margin {limit - len(payload)}")
        decoded = verifier.decode_matrix_payload(payload)
        self.assertEqual(sorted(decoded["scenarios"]), sorted(SOURCE_SCENARIOS))
        self.assertEqual(set(decoded), set(self.publisher.MATRIX_KEYS))
        # The real full-pass receipt alone: compacted, decoded by the hosted verifier and verified as full-pass.
        single = self.publisher.compact_matrix(EVIDENCE_R9)
        print(f"real R9 full-pass receipt alone: {len(single)} characters")
        alone = verifier.decode_matrix_payload(single)
        self.assertEqual(alone["scenarios"]["full-pass"], self.evidence["scenarios"]["full-pass"])
        result = verifier.verify_scenario(alone["scenarios"]["full-pass"], "full-pass", alone)
        self.assertEqual((result["status"], result["run_id"]), ("verified", "38906314106"))
        # Negative control: padding the same six receipts past the cap raises the documented refusal.
        padded = self.six()
        filler = base64.b64encode(os.urandom(limit)).decode("ascii")
        padded["scenarios"]["full-pass"]["run"]["display_title"] += filler
        with self.assertRaisesRegex(self.publisher.PublicationError, "compact matrix payload is [0-9]+ characters; the dispatch "
                                                                     "input cap is 65535"):
            self.publisher.compact_matrix(self.write("padded.json", padded))


if __name__ == "__main__":
    unittest.main(verbosity=2)
