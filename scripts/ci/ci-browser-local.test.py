#!/usr/bin/env python3
import socket
import tempfile
import unittest
import getpass
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import time
import uuid
from importlib.util import module_from_spec, spec_from_file_location
from unittest.mock import patch

spec = spec_from_file_location("ci_browser_local", Path(__file__).with_name("ci-browser-local.py"))
local = module_from_spec(spec)
spec.loader.exec_module(local)
ROOT = Path(__file__).resolve().parents[2]
NATIVE_EVIDENCE = ROOT / ".planning/phases/255-make-failures-reproducible-and-report-the-result/255-04-NATIVE.json"


class BrowserLocalSafetyTests(unittest.TestCase):
    def test_recorded_signal_is_reported_as_a_shell_compatible_exit_code(self):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            source = "import os, signal; os.kill(os.getpid(), signal.SIGTERM)"
            code = local.run_recorded([sys.executable, "-c", source], ROOT, root, "signal-probe", dict(os.environ))
            record = json.loads((root / "signal-probe" / "record.json").read_text())

        self.assertEqual(128 + signal.SIGTERM, code)
        self.assertEqual(signal.SIGTERM, record["primary_signal"])

    def test_missing_postgres_role_uses_os_user_for_local_preparation(self):
        observed_roles = []
        environment = {"PGDATABASE": ""}
        with tempfile.TemporaryDirectory() as raw, \
                patch.object(local, "require_createdb", side_effect=lambda env: observed_roles.append(env.get("PGUSER"))), \
                patch.object(local, "database_exists", return_value=False), \
                patch.object(local, "create_marked_database"), \
                patch.object(local, "run_recorded", return_value=0):
            try:
                local.prepare_owned_example(environment, Path(raw), "sigra_repro_1_abcd", "a" * 32, 4123, {})
            except KeyError:
                pass

        self.assertEqual(observed_roles, [getpass.getuser()])

    def test_rejects_an_already_bound_port_without_releasing_it(self):
        listener = socket.socket()
        listener.bind(("127.0.0.1", 0))
        listener.listen()
        try:
            port = listener.getsockname()[1]
            self.assertFalse(local.port_available(port))
            self.assertEqual(listener.getsockname()[1], port)
        finally:
            listener.close()

    def test_time_wait_is_not_reported_as_a_still_listening_server(self):
        listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        listener.bind(("127.0.0.1", 0))
        listener.listen()
        port = listener.getsockname()[1]
        client = socket.create_connection(("127.0.0.1", port))
        accepted, _ = listener.accept()
        accepted.shutdown(socket.SHUT_WR)
        accepted.close()
        self.assertEqual(client.recv(1), b"")
        client.close()
        listener.close()

        self.assertFalse(local.port_available(port), "the close should leave a TIME_WAIT socket without a listener")
        self.assertFalse(_port_has_listener(port), "TIME_WAIT is not an active listening server")

    def test_example_preparation_uses_ci_same_port_and_existing_command_order(self):
        environment = {"PGHOST": "127.0.0.1", "PGPORT": "5544", "PGUSER": "sigra_dev",
                       "PGDATABASE": "existing_admin_db", "SIGRA_TEST_PG_DATABASE": "library_test"}
        owner = {"database_created": False}
        calls = []
        with tempfile.TemporaryDirectory() as raw, \
                patch.object(local, "require_createdb") as require_createdb, \
                patch.object(local, "database_exists", return_value=False) as database_exists, \
                patch.object(local, "create_marked_database") as create_database, \
                patch.object(local, "run_recorded", side_effect=lambda argv, cwd, root, name, env: calls.append((name, argv, env)) or 0):
            local.prepare_owned_example(environment, Path(raw), "sigra_repro_1_abcd", "a" * 32, 4123, owner)

        require_createdb.assert_called_once()
        database_exists.assert_called_once()
        create_database.assert_called_once()
        self.assertEqual([name for name, _, _ in calls], ["prepare-deps", "prepare-compile", "prepare-ecto-create",
                                                          "prepare-ecto-migrate", "prepare-seeds"])
        self.assertEqual([argv[1] for _, argv, _ in calls], ["deps.get", "compile", "ecto.create", "ecto.migrate", "run"])
        self.assertTrue(all(env["CI"] == "true" and env["PORT"] == "4123" and env["MIX_ENV"] == "dev" for _, _, env in calls))
        self.assertTrue(all(env["PGDATABASE"] == "sigra_repro_1_abcd" for _, _, env in calls))
        self.assertTrue(all(env["SIGRA_TEST_PG_DATABASE"] == "library_test" for _, _, env in calls))
        self.assertTrue(all(env["MIX_BUILD_PATH"] == str(Path(raw) / "mix-build") for _, _, env in calls))
        self.assertTrue(owner["database_created"])
        self.assertEqual(owner["database_comment"], "sigra-repro:" + "a" * 32)

    def test_existing_database_is_refused_before_create(self):
        environment = {"PGUSER": "sigra_dev", "PGDATABASE": "admin"}
        with patch.object(local, "require_createdb"), patch.object(local, "database_exists", return_value=True), \
                patch.object(local, "create_marked_database") as create_database, tempfile.TemporaryDirectory() as raw:
            with self.assertRaisesRegex(local.BrowserLocalError, "pre-existing invocation database"):
                local.prepare_owned_example(environment, Path(raw), "sigra_repro_1_abcd", "a" * 32, 4123, {})
        create_database.assert_not_called()

    def test_cleanup_refuses_database_with_a_different_ownership_comment(self):
        owner = {"database_created": True, "owned_database": "sigra_repro_1_abcd", "ownership_token": "a" * 32,
                 "database_comment": "sigra-repro:" + "a" * 32, "postgres_admin_database": "admin"}
        drops = []
        errors = local.cleanup_owned_resources(owner, {"PGUSER": "sigra_dev"},
            comment_query=lambda database, env: "sigra-repro:" + "b" * 32,
            database_drop=lambda *args: drops.append(args))
        self.assertEqual(drops, [])
        self.assertTrue(owner["database_created"])
        self.assertTrue(any("ownership marker did not match" in error for error in errors))

    def test_cleanup_drops_only_database_with_matching_ownership_comment(self):
        owner = {"database_created": True, "owned_database": "sigra_repro_1_abcd", "ownership_token": "a" * 32,
                 "database_comment": "sigra-repro:" + "a" * 32, "postgres_admin_database": "admin"}
        drops = []
        errors = local.cleanup_owned_resources(owner, {"PGUSER": "sigra_dev"},
            comment_query=lambda database, env: "sigra-repro:" + "a" * 32,
            database_drop=lambda database, marker, env: drops.append((database, marker, env["PGDATABASE"])))
        self.assertEqual(errors, [])
        self.assertEqual(drops, [("sigra_repro_1_abcd", "a" * 32, "admin")])
        self.assertFalse(owner["database_created"])

    def test_database_comment_lookup_uses_postgres_shared_object_comments(self):
        result = subprocess.CompletedProcess([], 0, "present|sigra-repro:" + "a" * 32 + "\n", "")
        with patch.object(local, "_psql", return_value=result) as query:
            self.assertEqual(local._database_comment("sigra_repro_1_abcd", {"PGDATABASE": "admin"}),
                             "sigra-repro:" + "a" * 32)
        self.assertIn("shobj_description(oid, 'pg_database')", query.call_args.args[1])

    def test_output_root_creation_refuses_reusing_a_directory(self):
        with tempfile.TemporaryDirectory() as parent:
            path = Path(parent) / "existing"
            path.mkdir()
            with self.assertRaises(FileExistsError):
                local.make_output_root(str(path))

    def test_selection_and_execution_reports_must_have_the_same_native_identity(self):
        selection = {"suites": [{"title": "golden-path.spec.ts", "suites": [{"title": "account", "specs": [{
            "id": "native-1", "file": "tests/golden-path.spec.ts", "title": "full user lifecycle", "tests": [{
                "projectName": "chromium", "expectedStatus": "passed"}], "suites": []}]}]}]}
        execution = json.loads(json.dumps(selection))
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            (root / "golden-path.selection.json").write_text(json.dumps(selection))
            (root / "golden-path.json").write_text(json.dumps(execution))
            selected = local.selected_identities(root)
            reports = local.verify_execution_identities(root, selected)
            self.assertEqual(reports, [{"report": "golden-path.json", "selected_identities": 1}])
            execution["suites"][0]["suites"][0]["specs"][0]["tests"][0]["projectName"] = "mobile"
            (root / "golden-path.json").write_text(json.dumps(execution))
            with self.assertRaisesRegex(local.BrowserLocalError, "identities differ"):
                local.verify_execution_identities(root, selected)

    def test_password_redaction_replaces_secret_bytes_in_diagnostic_streams(self):
        with tempfile.TemporaryDirectory() as raw:
            path = Path(raw) / "stderr.bin"
            path.write_bytes(b"database password was top-secret\n")
            local._redact(path, "top-secret")
            self.assertEqual(path.read_bytes(), b"database password was [REDACTED]\n")


def _psql_value(env, sql):
    result = subprocess.run(["psql", "-X", "-A", "-t", "-v", "ON_ERROR_STOP=1", "-c", sql],
                            cwd=ROOT, env=env, capture_output=True, text=True, check=False)
    if result.returncode:
        raise AssertionError(f"read-only PostgreSQL query failed: {result.stderr}")
    return result.stdout.strip()


def _port_has_listener(port):
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as probe:
        probe.settimeout(0.5)
        return probe.connect_ex(("127.0.0.1", port)) == 0


def _process_rows():
    result = subprocess.run(["ps", "-axo", "pid=,pgid=,command="], capture_output=True, text=True, check=True)
    rows = []
    for line in result.stdout.splitlines():
        fields = line.strip().split(maxsplit=2)
        if len(fields) == 3:
            rows.append((int(fields[0]), int(fields[1]), fields[2]))
    return rows


def _wait_for_playwright_group(timeout=180):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        for pid, pgid, command in _process_rows():
            if "playwright/cli.js" in command and " test " in command:
                return pid, pgid
        time.sleep(0.05)
    return None


def _process_group_members(pgid):
    return [pid for pid, group, _ in _process_rows() if group == pgid]


def _native_sigterm_test(env, admin_database, before_names, before_database):
    """Send SIGTERM to the real outer runner while its browser command is active."""
    temporary_root = Path(tempfile.mkdtemp(prefix="sigra255-browser-sigterm-"))
    output_root = temporary_root / "owned-output"
    unrelated_listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    unrelated_listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 0)
    unrelated_listener.bind(("127.0.0.1", 0))
    unrelated_listener.listen()
    unrelated_port = unrelated_listener.getsockname()[1]
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as probe:
        probe.bind(("127.0.0.1", 0))
        owned_port = probe.getsockname()[1]
    command = [sys.executable, str(Path(__file__).with_name("ci-browser-local.py")),
        "--seam", "non_admin_smoke", "--event", "pull_request", "--port", str(owned_port),
        "--diagnostic-case", "fail", "--keep-output", "--output-root", str(output_root)]
    runner = subprocess.Popen(command, cwd=ROOT, env=env, stdout=subprocess.PIPE,
                              stderr=subprocess.PIPE, text=True)
    owner_path = output_root / local.OWNER_FILE
    owner = {}
    active_process = None
    runner_output = ("", "")
    passed = False
    try:
        deadline = time.monotonic() + 180
        while time.monotonic() < deadline:
            if owner_path.is_file():
                owner = json.loads(owner_path.read_text())
                if owner.get("server_status") == "ready":
                    active_process = _wait_for_playwright_group(timeout=20)
                    break
            if runner.poll() is not None:
                runner_output = runner.communicate(timeout=5)
                raise AssertionError(f"runner exited before active browser command: {runner.returncode} {runner_output[1]}")
            time.sleep(0.05)
        if not owner.get("server_status") == "ready" or active_process is None:
            raise AssertionError("real outer runner did not reach an active Playwright command")

        active_pid, active_pgid = active_process
        server_pid = int(owner["owned_pid"])
        database = owner["owned_database"]
        marker = owner["ownership_token"]
        runner.send_signal(signal.SIGTERM)
        runner_output = runner.communicate(timeout=20)
        owner = json.loads(owner_path.read_text())

        if runner.returncode != 128 + signal.SIGTERM:
            raise AssertionError(f"outer runner did not preserve SIGTERM as 143: {runner.returncode}")
        if owner.get("primary_signal") != signal.SIGTERM or owner.get("primary_exit_code") != 143:
            raise AssertionError(f"runner owner record omitted SIGTERM outcome: {owner}")
        if owner.get("cleanup_errors"):
            raise AssertionError(f"owned cleanup reported errors after SIGTERM: {owner['cleanup_errors']}")
        if owner.get("database_created") or owner.get("owned_pid") is not None:
            raise AssertionError("outer SIGTERM left owned database or server recorded as active")

        names_after = _psql_value(env, "SELECT datname FROM pg_database WHERE datname LIKE 'sigra_repro_%' ORDER BY datname;").splitlines()
        database_after = _psql_value(env, f"SELECT oid || '|' || datname || '|' || datallowconn || '|' || datconnlimit FROM pg_database WHERE datname = '{admin_database}';")
        if database in names_after or not set(before_names) <= set(names_after):
            raise AssertionError("outer SIGTERM did not remove only its owned database")
        if database_after != before_database:
            raise AssertionError("unrelated PostgreSQL database changed during SIGTERM cleanup")
        if _port_has_listener(owned_port):
            raise AssertionError("outer SIGTERM left its Phoenix server listening")
        if _process_group_members(server_pid) or _process_group_members(active_pgid):
            raise AssertionError("outer SIGTERM left an owned server or active command process")
        if unrelated_listener.fileno() < 0 or _port_has_listener(unrelated_port) is False:
            raise AssertionError("outer SIGTERM changed the unrelated listener")

        result = {"status": "passed", "command": command, "outer_exit_code": runner.returncode,
                "primary_signal": signal.SIGTERM, "primary_exit_code": 143,
                "owned_database_removed": True, "owned_server_group_removed": True,
                "active_command_pid": active_pid, "active_command_group_removed": True,
                "unrelated_database_unchanged": True, "unrelated_listener_still_listening": True}
        passed = True
        return result
    finally:
        if runner.poll() is None:
            runner.send_signal(signal.SIGTERM)
            try:
                runner.communicate(timeout=20)
            except subprocess.TimeoutExpired:
                runner.kill()
                runner.communicate(timeout=5)
        if owner_path.is_file():
            try:
                owner = json.loads(owner_path.read_text())
                pid = owner.get("owned_pid")
                if isinstance(pid, int):
                    os.killpg(pid, signal.SIGKILL)
                database = owner.get("owned_database")
                token = owner.get("ownership_token")
                if owner.get("database_created") and database and token:
                    admin_env = dict(env)
                    admin_env["PGDATABASE"] = admin_database
                    if local._database_comment(database, admin_env) == f"sigra-repro:{token}":
                        local.drop_marked_database(database, token, admin_env)
            except (OSError, local.BrowserLocalError):
                pass
        unrelated_listener.close()
        if passed:
            shutil.rmtree(temporary_root, ignore_errors=True)
        else:
            print(f"Preserved failed outer SIGTERM probe: {temporary_root}", file=sys.stderr)


def _native_test():
    env = dict(os.environ)
    env.setdefault("PGHOST", "localhost")
    env.setdefault("PGPORT", "5432")
    env.setdefault("PGUSER", getpass.getuser())
    admin_database = env.get("PGDATABASE") or env["PGUSER"]
    env["PGDATABASE"] = admin_database
    names_query = "SELECT datname FROM pg_database WHERE datname LIKE 'sigra_repro_%' ORDER BY datname;"
    fingerprint_query = ("SELECT oid || '|' || datname || '|' || datallowconn || '|' || datconnlimit "
                         f"FROM pg_database WHERE datname = '{admin_database}';")
    before_names = _psql_value(env, names_query).splitlines()
    before_database = _psql_value(env, fingerprint_query)
    if not before_database:
        raise AssertionError(f"configured PostgreSQL admin database does not exist: {admin_database}")
    runtime = local.check_runtime_prerequisites(env)
    sigterm_evidence = _native_sigterm_test(env, admin_database, before_names, before_database)
    source = local._source_identity()
    evidence = {
        "schema_version": "sigra.browser-local-native/v1",
        "status": "running",
        "source_identity": source,
        "runtime": runtime,
        "safe_postgres_settings": local.safe_pg_configuration(env),
        "unrelated_database": {"name": admin_database, "fingerprint_before": before_database},
        "unrelated_database_names_before": before_names,
        "outer_sigterm_cleanup": sigterm_evidence,
    }

    temporary_root = Path(tempfile.mkdtemp(prefix="sigra255-browser-native-"))
    collision_listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    collision_listener.bind(("127.0.0.1", 0))
    collision_listener.listen()
    collision_port = collision_listener.getsockname()[1]
    collision_output = temporary_root / "collision-output"
    collision = subprocess.run([sys.executable, str(Path(__file__).with_name("ci-browser-local.py")),
        "--seam", "demo_showcase", "--event", "pull_request", "--port", str(collision_port),
        "--output-root", str(collision_output)], cwd=ROOT, env=env, capture_output=True, text=True, check=False)
    listener_preserved = collision_listener.getsockname()[1] == collision_port and not local.port_available(collision_port)
    collision_listener.close()
    if collision.returncode == 0 or "already bound" not in collision.stderr or not listener_preserved or collision_output.exists():
        shutil.rmtree(temporary_root, ignore_errors=True)
        raise AssertionError(f"occupied port was not refused safely: exit={collision.returncode} stderr={collision.stderr}")
    evidence["port_collision"] = {"exit_code": collision.returncode, "listener_preserved": listener_preserved,
                                   "diagnostic": collision.stderr.strip()}

    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as probe:
        probe.bind(("127.0.0.1", 0))
        free_port = probe.getsockname()[1]
    output_root = temporary_root / "owned-output"
    command = [sys.executable, str(Path(__file__).with_name("ci-browser-local.py")),
               "--seam", "non_admin_smoke", "--event", "pull_request", "--port", str(free_port),
               "--grep", "full user lifecycle", "--output-root", str(output_root)]
    native = subprocess.run(command, cwd=ROOT, env=env, capture_output=True, text=True, check=False)
    if native.returncode:
        evidence["status"] = "failed"
        evidence["native_exit_code"] = native.returncode
        evidence["native_stdout"] = native.stdout
        evidence["native_stderr"] = native.stderr
        evidence["diagnostics"] = str(output_root)
        failure_path = ROOT / ".planning/phases/255-make-failures-reproducible-and-report-the-result/255-04-NATIVE-BLOCKER.json"
        if not failure_path.exists():
            failure_path.write_text(json.dumps(evidence, indent=2) + "\n")
        raise AssertionError(f"native browser reproduction failed; preserved diagnostics at {output_root}; {native.stderr}")

    selected_lines = [line for line in native.stdout.splitlines() if line.startswith("Selected: ")]
    project_names = sorted({re.match(r"Selected: ([^ ]+)", line).group(1) for line in selected_lines})
    executed_reports = [line for line in native.stdout.splitlines() if line.startswith("Executed report: ")]
    database_match = re.search(r"^Owned database cleaned: ([a-z0-9_]+)$", native.stdout, re.M)
    pid_match = re.search(r"^Owned server stopped: pid ([0-9]+)$", native.stdout, re.M)
    after_names = _psql_value(env, names_query).splitlines()
    after_database = _psql_value(env, fingerprint_query)
    if not any("full user lifecycle" in line for line in selected_lines):
        raise AssertionError(f"native selected identity is absent: {native.stdout}")
    if project_names != ["chromium", "mobile"]:
        raise AssertionError(f"focused original seam projects changed: {project_names}")
    if not executed_reports or database_match is None or pid_match is None or output_root.exists():
        raise AssertionError(f"owned resource cleanup or execution records are missing: {native.stdout}")
    if database_match.group(1) in after_names:
        raise AssertionError(f"invocation database remains after cleanup: {database_match.group(1)}")
    if before_database != after_database:
        raise AssertionError(f"unrelated database changed: {before_database!r} -> {after_database!r}")
    if not set(before_names) <= set(after_names):
        raise AssertionError("pre-existing sigra_repro_* databases were removed")
    if _port_has_listener(free_port):
        raise AssertionError(f"a server still listens on the owned port {free_port}")
    png_changes = subprocess.run(["git", "status", "--short", "--", "*.png"], cwd=ROOT,
                                 capture_output=True, text=True, check=False).stdout.strip()
    if png_changes:
        raise AssertionError(f"browser reproduction unexpectedly changed screenshot files: {png_changes}")

    evidence.update({
        "status": "passed",
        "native_command": command,
        "native_exit_code": native.returncode,
        "selected_identities": selected_lines,
        "selected_projects": project_names,
        "execution_reports": executed_reports,
        "owned_database": {"name": database_match.group(1), "absent_after_cleanup": True},
        "owned_server": {"pid": int(pid_match.group(1)), "port": free_port, "stopped": True},
        "owned_output_root_removed_after_success": True,
        "unrelated_database": {"name": admin_database, "fingerprint_before": before_database,
                               "fingerprint_after": after_database, "unchanged": True},
        "unrelated_database_names_before": before_names,
        "unrelated_database_names_after": after_names,
        "snapshot_changes": png_changes,
        "native_stdout": native.stdout,
    })
    if NATIVE_EVIDENCE.exists():
        raise AssertionError(f"refusing to overwrite native evidence: {NATIVE_EVIDENCE}")
    NATIVE_EVIDENCE.write_text(json.dumps(evidence, ensure_ascii=False, indent=2) + "\n")
    shutil.rmtree(temporary_root)
    print(f"Native evidence: {NATIVE_EVIDENCE.relative_to(ROOT)}")
    print(f"Native identity: {selected_lines}")
    print("Owned PostgreSQL database and Phoenix server cleaned; unrelated database fingerprint unchanged.")


def _native_sigterm_only():
    env = dict(os.environ)
    env.setdefault("PGHOST", "localhost")
    env.setdefault("PGPORT", "5432")
    env.setdefault("PGUSER", getpass.getuser())
    admin_database = env.get("PGDATABASE") or env["PGUSER"]
    env["PGDATABASE"] = admin_database
    names_query = "SELECT datname FROM pg_database WHERE datname LIKE 'sigra_repro_%' ORDER BY datname;"
    fingerprint_query = ("SELECT oid || '|' || datname || '|' || datallowconn || '|' || datconnlimit "
                         f"FROM pg_database WHERE datname = '{admin_database}';")
    before_names = _psql_value(env, names_query).splitlines()
    before_database = _psql_value(env, fingerprint_query)
    if not before_database:
        raise AssertionError(f"configured PostgreSQL admin database does not exist: {admin_database}")
    runtime = local.check_runtime_prerequisites(env)
    result = _native_sigterm_test(env, admin_database, before_names, before_database)
    print(json.dumps({"status": "passed", "source_identity": local._source_identity(),
                      "runtime": runtime, "outer_sigterm_cleanup": result}, sort_keys=True))


if __name__ == "__main__" and "--native-sigterm" in sys.argv:
    sys.argv.remove("--native-sigterm")
    unittest.main(exit=False)
    _native_sigterm_only()


if __name__ == "__main__" and "--native" in sys.argv:
    sys.argv.remove("--native")
    unittest.main(exit=False)
    _native_test()


if __name__ == "__main__":
    unittest.main()
