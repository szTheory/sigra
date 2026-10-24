#!/usr/bin/env python3
"""Safely reproduce a selected Playwright seam against invocation-owned resources."""

from __future__ import annotations

import argparse
import getpass
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import signal
import socket
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
import uuid


ROOT = Path(__file__).resolve().parents[2]
EXAMPLE = ROOT / "test/example"
PLAYWRIGHT = EXAMPLE / "priv/playwright"
RECORDER = ROOT / "scripts/ci/ci-command-record.py"
BROWSER_COMMAND = ROOT / "scripts/ci/ci-browser-command.mjs"
DIAGNOSTIC_CONFIG = ROOT / "scripts/ci/fixtures/playwright-diagnostics.config.ts"
LOCK = PLAYWRIGHT / "package-lock.json"
OWNER_FILE = "resource-owner.json"
SCHEMA = "sigra.browser-local-owner/v1"
SEAMS = ("admin_behavior", "admin_checkpoints", "design_gallery", "non_admin_smoke", "demo_showcase")
EVENTS = ("pull_request", "push", "schedule", "workflow_dispatch")


class BrowserLocalError(RuntimeError):
    def __init__(self, message: str, code: int = 1):
        super().__init__(message)
        self.code = code


def port_available(port: int, host: str = "127.0.0.1") -> bool:
    """Return whether an IPv4 loopback port can be bound, without touching its owner."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as probe:
        probe.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 0)
        try:
            probe.bind((host, port))
        except OSError:
            return False
    return True


def make_output_root(requested: str | None) -> Path:
    if requested:
        root = Path(requested).expanduser().resolve()
        root.mkdir(mode=0o700, parents=True, exist_ok=False)
        root.chmod(0o700)
        return root
    root = Path(tempfile.mkdtemp(prefix="sigra-browser-local-"))
    root.chmod(0o700)
    return root


def write_json(path: Path, value: dict, *, exclusive: bool = False) -> None:
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{uuid.uuid4().hex}.tmp")
    with temporary.open("x", encoding="utf-8") as handle:
        json.dump(value, handle, ensure_ascii=False, indent=2, sort_keys=True)
        handle.write("\n")
    if exclusive and path.exists():
        temporary.unlink()
        raise FileExistsError(path)
    temporary.replace(path)


def initialize_owner(root: Path, database: str, marker: str, port: int,
                     pg_configuration: dict[str, str]) -> dict:
    """Persist a fail-closed cleanup record before creating the database or server."""
    owner = {
        "schema_version": SCHEMA,
        "ownership_token": marker,
        "owned_output_root": str(root),
        "owned_database": database,
        "database_created": False,
        "database_comment": None,
        "owned_pid": None,
        "owned_process_group": None,
        "compiled_port": port,
        "serving_port": port,
        "example_postgres": pg_configuration,
        "cleanup_errors": [],
    }
    write_json(root / OWNER_FILE, owner, exclusive=True)
    return owner


def safe_pg_configuration(source: dict[str, str]) -> dict[str, str]:
    return {key: source[key] for key in ("PGHOST", "PGPORT", "PGUSER", "PGDATABASE") if source.get(key)}


def example_environment(source: dict[str, str], database: str, port: int, mix_build_path: Path) -> dict[str, str]:
    """Build dev app settings. SIGRA_TEST_PG_* stays reserved for library tests."""
    env = dict(source)
    env.update({
        "MIX_ENV": "dev",
        "CI": "true",
        "PORT": str(port),
        "MIX_BUILD_PATH": str(mix_build_path),
        "PGDATABASE": database,
        "PGHOST": source.get("PGHOST", "localhost"),
        "PGPORT": source.get("PGPORT", "5432"),
        "PGUSER": source.get("PGUSER", getpass.getuser()),
        "PGPASSWORD": source.get("PGPASSWORD", ""),
    })
    return env


def admin_environment(env: dict[str, str], database: str) -> dict[str, str]:
    result = dict(env)
    result["PGDATABASE"] = database
    return result


def _psql(env: dict[str, str], sql: str, *, capture: bool = True) -> subprocess.CompletedProcess:
    psql = shutil.which("psql")
    if not psql:
        raise BrowserLocalError("PostgreSQL client psql is required")
    return subprocess.run([psql, "-X", "-A", "-t", "-v", "ON_ERROR_STOP=1", "-c", sql],
                          env=env, cwd=ROOT, capture_output=capture, text=True, check=False)


def _database_comment(database: str, env: dict[str, str]) -> str | None:
    if not re.fullmatch(r"[a-z][a-z0-9_]{0,62}", database):
        raise BrowserLocalError("unsafe generated PostgreSQL database name")
    # Database comments are shared-object comments; obj_description only reads
    # comments attached to ordinary catalog objects.
    sql = f"SELECT 'present|' || coalesce(shobj_description(oid, 'pg_database'), '') FROM pg_database WHERE datname = '{database}';"
    result = _psql(env, sql)
    if result.returncode:
        detail = (result.stderr or result.stdout or "PostgreSQL query failed").strip()
        raise BrowserLocalError(f"PostgreSQL ownership query failed: {detail}", result.returncode)
    value = result.stdout.strip()
    if not value:
        return None
    if not value.startswith("present|"):
        raise BrowserLocalError("PostgreSQL returned an invalid database ownership query")
    return value.removeprefix("present|")


def database_exists(database: str, env: dict[str, str]) -> bool:
    return _database_comment(database, env) is not None


def require_createdb(env: dict[str, str]) -> None:
    result = _psql(env, "SELECT rolcreatedb FROM pg_roles WHERE rolname = current_user;")
    if result.returncode:
        raise BrowserLocalError("cannot verify PostgreSQL CREATE DATABASE permission", result.returncode)
    if result.stdout.strip() != "t":
        raise BrowserLocalError("the configured PostgreSQL role lacks CREATEDB permission")


def create_marked_database(database: str, marker: str, env: dict[str, str]) -> None:
    if not re.fullmatch(r"[a-z][a-z0-9_]{0,62}", database) or not re.fullmatch(r"[0-9a-f]{32}", marker):
        raise BrowserLocalError("invalid invocation-owned database identity")
    created = _psql(env, f'CREATE DATABASE "{database}";')
    if created.returncode:
        detail = (created.stderr or created.stdout or "CREATE DATABASE failed").strip()
        raise BrowserLocalError(f"could not create unique invocation database: {detail}", created.returncode)
    comment = f"sigra-repro:{marker}"
    marked = _psql(env, f'COMMENT ON DATABASE "{database}" IS \'{comment}\';')
    if marked.returncode:
        detail = (marked.stderr or marked.stdout or "database ownership mark failed").strip()
        raise BrowserLocalError(f"database created but ownership could not be verified; it was left untouched: {detail}", marked.returncode)
    if _database_comment(database, env) != comment:
        raise BrowserLocalError("database ownership comment did not read back; database was left untouched")


def drop_marked_database(database: str, marker: str, env: dict[str, str]) -> None:
    expected = f"sigra-repro:{marker}"
    actual = _database_comment(database, env)
    if actual != expected:
        raise BrowserLocalError("refusing database cleanup: ownership comment is absent or does not match")
    result = _psql(env, f'DROP DATABASE "{database}";')
    if result.returncode:
        detail = (result.stderr or result.stdout or "DROP DATABASE failed").strip()
        raise BrowserLocalError(f"owned database cleanup failed: {detail}", result.returncode)


def _redact(path: Path, password: str) -> None:
    if not password or not path.is_file():
        return
    payload = path.read_bytes()
    redacted = payload.replace(password.encode(), b"[REDACTED]")
    if redacted != payload:
        path.write_bytes(redacted)


def run_recorded(argv: list[str], cwd: Path, root: Path, invocation: str,
                 env: dict[str, str]) -> int:
    command = [sys.executable, str(RECORDER), "--cwd", str(cwd), "--output-root", str(root),
               "--invocation", invocation, "--", *argv]
    result = subprocess.run(command, cwd=ROOT, env=env, capture_output=True, text=True, check=False)
    invocation_root = root / invocation
    password = env.get("PGPASSWORD", "")
    for name in ("stdout.bin", "stderr.bin", "cleanup.stdout.bin", "cleanup.stderr.bin"):
        _redact(invocation_root / name, password)
    _redact(invocation_root / "record.json", password)
    if result.returncode and result.stderr:
        print(result.stderr.rstrip(), file=sys.stderr)
    if result.returncode < 0:
        return 128 + -result.returncode
    return result.returncode


def _locked_playwright_version() -> str:
    lock = json.loads(LOCK.read_text())
    return lock["packages"]["node_modules/@playwright/test"]["version"]


def check_runtime_prerequisites(source_env: dict[str, str]) -> dict:
    node = shutil.which("node")
    if not node:
        raise BrowserLocalError("Node.js 20 is required; use the same Node 20 runtime configured by the CI boot action")
    node_version = subprocess.run([node, "--version"], capture_output=True, text=True, check=False)
    if node_version.returncode or not re.fullmatch(r"v20\.[0-9]+\.[0-9]+", node_version.stdout.strip()):
        raise BrowserLocalError(f"browser reproduction requires Node 20; observed {node_version.stdout.strip() or 'unavailable'}")
    pinned_playwright = _locked_playwright_version()
    installed_playwright = json.loads((PLAYWRIGHT / "node_modules/@playwright/test/package.json").read_text())["version"]
    if installed_playwright != pinned_playwright:
        raise BrowserLocalError(f"Playwright package does not match package-lock.json ({installed_playwright} != {pinned_playwright})")
    executable_probe = subprocess.run([node, "-e", "const p=require('playwright');process.stdout.write(JSON.stringify([p.chromium.executablePath(),p.webkit.executablePath()]))"],
                                      cwd=PLAYWRIGHT, env=source_env, capture_output=True, text=True, check=False)
    if executable_probe.returncode:
        raise BrowserLocalError("could not resolve locked Playwright browser binaries")
    try:
        executables = json.loads(executable_probe.stdout)
    except json.JSONDecodeError as error:
        raise BrowserLocalError("Playwright returned malformed browser binary paths") from error
    missing = [path for path in executables if not Path(path).is_file()]
    if missing:
        raise BrowserLocalError(f"locked Playwright browser binary missing: {', '.join(missing)}")

    versions = {}
    for tool in ("elixir", "mix"):
        executable = shutil.which(tool)
        if not executable:
            raise BrowserLocalError(f"pinned {tool} executable is required")
        result = subprocess.run([executable, "--version"], env={**source_env, "MIX_ENV": "dev"},
                                capture_output=True, text=True, check=False)
        if result.returncode:
            raise BrowserLocalError(f"cannot read pinned {tool} version")
        versions[tool] = (result.stdout or result.stderr).strip()
    tool_versions = dict(line.split(maxsplit=1) for line in (ROOT / ".tool-versions").read_text().splitlines() if line.strip())
    expected_elixir = tool_versions.get("elixir", "").split("-otp-", 1)[0]
    expected_otp = tool_versions.get("erlang", "").split(".", 1)[0]
    if not re.search(rf"\bElixir {re.escape(expected_elixir)}\b", versions["elixir"]):
        raise BrowserLocalError(f"Elixir version differs from .tool-versions ({versions['elixir']})")
    if not re.search(rf"Erlang/OTP {re.escape(expected_otp)}\b", versions["elixir"]):
        raise BrowserLocalError(f"OTP version differs from .tool-versions ({versions['elixir']})")
    if not re.search(rf"\bMix {re.escape(expected_elixir)}\b", versions["mix"]):
        raise BrowserLocalError(f"Mix version differs from .tool-versions ({versions['mix']})")
    return {"node": node_version.stdout.strip(), "playwright": installed_playwright,
            "elixir": versions["elixir"], "mix": versions["mix"],
            "host_os": sys.platform, "browser_equivalence": "behavior only on macOS; Ubuntu 24.04 is required for font/pixel parity"}


def _source_identity() -> dict:
    def git(*args: str) -> str | None:
        result = subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True, check=False)
        return result.stdout.strip() if result.returncode == 0 else None
    return {"source_sha": git("rev-parse", "HEAD"), "source_ref": git("rev-parse", "--abbrev-ref", "HEAD"),
            "dirty_status": git("status", "--short", "--untracked-files=normal")}


def prepare_owned_example(environment: dict[str, str], root: Path, database: str,
                          marker: str, port: int, owner: dict) -> None:
    environment = dict(environment)
    environment["PGUSER"] = environment.get("PGUSER") or getpass.getuser()
    admin_db = environment.get("PGDATABASE") or environment["PGUSER"]
    admin_env = admin_environment(environment, admin_db)
    require_createdb(admin_env)
    if database_exists(database, admin_env):
        raise BrowserLocalError("refusing pre-existing invocation database")
    create_marked_database(database, marker, admin_env)
    owner["database_created"] = True
    owner["database_comment"] = f"sigra-repro:{marker}"
    write_json(root / OWNER_FILE, owner)
    app_env = example_environment(environment, database, port, root / "mix-build")
    preparation = [
        ("prepare-deps", ["mix", "deps.get"]),
        ("prepare-compile", ["mix", "compile", "--warnings-as-errors"]),
        ("prepare-ecto-create", ["mix", "ecto.create", "--quiet"]),
        ("prepare-ecto-migrate", ["mix", "ecto.migrate", "--quiet"]),
        ("prepare-seeds", ["mix", "run", "priv/repo/seeds.exs"]),
    ]
    for invocation, argv in preparation:
        code = run_recorded(argv, EXAMPLE, root, invocation, app_env)
        if code:
            raise BrowserLocalError(f"{invocation} failed; command streams are in {root / invocation}", code)


def wait_ready(url: str, process: subprocess.Popen, timeout: float = 45.0) -> None:
    deadline = time.monotonic() + timeout
    last_error = "no HTTP response yet"
    while time.monotonic() < deadline:
        if process.poll() is not None:
            raise BrowserLocalError(f"example server exited before readiness (status {process.returncode})")
        try:
            with urllib.request.urlopen(url, timeout=1.0) as response:
                if 200 <= response.status < 400:
                    return
                last_error = f"HTTP {response.status}"
        except (urllib.error.URLError, TimeoutError, OSError) as error:
            last_error = str(error)
        time.sleep(0.25)
    raise BrowserLocalError(f"example server did not become ready at {url}: {last_error}")


def selected_identities(selection_root: Path) -> list[dict]:
    """Return the exact native project/spec/title rows produced by Playwright --list."""
    identities = []
    for report_path in sorted(selection_root.glob("*.selection.json")):
        report = json.loads(report_path.read_text())

        def visit(suites: list, parents: tuple[str, ...] = ()) -> None:
            for suite in suites:
                suite_path = (*parents, suite.get("title", ""))
                for spec in suite.get("specs", []):
                    for entry in spec.get("tests", []):
                        identities.append({
                            "project": entry["projectName"],
                            "file": spec["file"].replace("\\", "/"),
                            "suite_path": list(suite_path),
                            "spec_id": spec["id"],
                            "title": spec["title"],
                            "expected_status": entry["expectedStatus"],
                        })
                visit(suite.get("suites", []), suite_path)

        visit(report.get("suites", []))
    keys = [json.dumps(identity, sort_keys=True) for identity in identities]
    if not identities or len(set(keys)) != len(keys):
        raise BrowserLocalError("Playwright selection is empty or has duplicate native identities")
    return sorted(identities, key=lambda row: (row["project"], row["file"], row["suite_path"], row["title"]))


def _identities_from_report(report: dict) -> set[str]:
    identities = set()

    def visit(suites: list, parents: tuple[str, ...] = ()) -> None:
        for suite in suites:
            suite_path = (*parents, suite.get("title", ""))
            for spec in suite.get("specs", []):
                for entry in spec.get("tests", []):
                    identity = [entry["projectName"], spec["file"].replace("\\", "/"), list(suite_path), spec["id"], spec["title"]]
                    identities.add(json.dumps(identity, ensure_ascii=False, separators=(",", ":")))
            visit(suite.get("suites", []), suite_path)

    visit(report.get("suites", []))
    return identities


def verify_execution_identities(selection_root: Path, selected: list[dict]) -> list[dict]:
    expected = {json.dumps([row["project"], row["file"], row["suite_path"], row["spec_id"], row["title"]],
                           ensure_ascii=False, separators=(",", ":")) for row in selected}
    actual = set()
    reports = []
    for selection_path in sorted(selection_root.glob("*.selection.json")):
        report_path = selection_path.with_name(selection_path.name.removesuffix(".selection.json") + ".json")
        if not report_path.is_file():
            raise BrowserLocalError(f"native Playwright execution report is missing: {report_path.name}")
        report = json.loads(report_path.read_text())
        rows = _identities_from_report(report)
        if not rows:
            raise BrowserLocalError(f"native Playwright execution report has no selected identities: {report_path.name}")
        actual.update(rows)
        reports.append({"report": report_path.name, "selected_identities": len(rows)})
    if expected != actual:
        missing = len(expected - actual)
        unexpected = len(actual - expected)
        raise BrowserLocalError(f"native Playwright selection and execution identities differ (missing={missing}, unexpected={unexpected})")
    return reports


def stop_owned_server(process: subprocess.Popen, expected_pid: int, timeout: float = 8.0) -> None:
    if process.pid != expected_pid:
        raise BrowserLocalError("refusing server cleanup: PID differs from recorded owner")
    if process.poll() is not None:
        return
    try:
        os.killpg(expected_pid, signal.SIGTERM)
    except ProcessLookupError:
        return
    try:
        process.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
        if process.poll() is None:
            os.killpg(expected_pid, signal.SIGKILL)
            process.wait(timeout=timeout)


def cleanup_owned_resources(owner: dict, environment: dict[str, str], process: subprocess.Popen | None = None,
                            *, stop_server=stop_owned_server, comment_query=_database_comment,
                            database_drop=drop_marked_database) -> list[str]:
    """Clean up only resources identified by both the in-memory owner and durable token."""
    errors = []
    pid = owner.get("owned_pid")
    if process is not None and pid is not None:
        try:
            stop_server(process, pid)
            owner["owned_pid"] = None
            owner["owned_process_group"] = None
        except (OSError, BrowserLocalError, subprocess.SubprocessError) as error:
            errors.append(f"server_cleanup_failed:{error}")
    if owner.get("database_created"):
        database = owner.get("owned_database")
        token = owner.get("ownership_token")
        base_database = owner.get("postgres_admin_database") or environment.get("PGDATABASE") or environment.get("PGUSER") or getpass.getuser()
        admin_env = admin_environment(environment, base_database)
        try:
            expected = f"sigra-repro:{token}"
            if comment_query(database, admin_env) != expected or owner.get("database_comment") != expected:
                raise BrowserLocalError("refusing database cleanup: ownership marker did not match")
            database_drop(database, token, admin_env)
            owner["database_created"] = False
            owner["database_comment"] = None
        except (OSError, BrowserLocalError, subprocess.SubprocessError) as error:
            errors.append(f"database_cleanup_failed:{error}")
    owner["cleanup_errors"] = errors
    return errors


def _run_local(args: argparse.Namespace) -> int:
    if not 1 <= args.port <= 65535:
        raise BrowserLocalError("--port must be between 1 and 65535")
    source_env = dict(os.environ)
    runtime = check_runtime_prerequisites(source_env)
    if not port_available(args.port):
        raise BrowserLocalError(f"port {args.port} is already bound; the existing listener was left untouched")

    output_root = make_output_root(args.output_root)
    token = uuid.uuid4().hex
    database = f"sigra_repro_{os.getpid()}_{token[:12]}"
    owned_mix_build_path = output_root / "mix-build"
    example_env = example_environment(source_env, database, args.port, owned_mix_build_path)
    safe_pg = safe_pg_configuration(example_env)
    owner = initialize_owner(output_root, database, token, args.port, safe_pg)
    admin_database = source_env.get("PGDATABASE") or source_env.get("PGUSER", getpass.getuser())
    owner.update(runtime=runtime, postgres_admin_database=admin_database,
                 owned_mix_build_path=str(owned_mix_build_path), **_source_identity(), seam=args.seam, event=args.event,
                 native_test_filter=args.grep, host_os=sys.platform)
    write_json(output_root / OWNER_FILE, owner)

    process = None
    server_pid = None
    startup_failure_listener = None
    primary_code = 0
    cleanup_errors: list[str] = []
    try:
        prepare_owned_example(source_env, output_root, database, token, args.port, owner)
        app_env = example_environment(example_env, database, args.port, owned_mix_build_path)
        app_env.update({"PHX_SERVER": "true", "SIGRA_EXAMPLE_URL": f"http://127.0.0.1:{args.port}"})
        argv = ["mix", "phx.server"]
        if args.diagnostic_startup_failure:
            startup_failure_listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            startup_failure_listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 0)
            startup_failure_listener.bind(("127.0.0.1", args.port))
            startup_failure_listener.listen()
            owner["trace_unavailable_reason"] = "context_not_created"
        server_stdout = (output_root / "server.stdout.bin").open("xb")
        server_stderr = (output_root / "server.stderr.bin").open("xb")
        try:
            process = subprocess.Popen(argv, cwd=EXAMPLE, env=app_env, stdout=server_stdout,
                                       stderr=server_stderr, start_new_session=True, close_fds=True)
        except OSError:
            server_stdout.close()
            server_stderr.close()
            raise
        server_stdout.close()
        server_stderr.close()
        owner.update(owned_pid=process.pid, owned_process_group=process.pid, server_argv=argv,
                     server_cwd=str(EXAMPLE), server_stdout=str(output_root / "server.stdout.bin"),
                     server_stderr=str(output_root / "server.stderr.bin"), server_status="starting",
                     serving_port=args.port)
        server_pid = process.pid
        write_json(output_root / OWNER_FILE, owner)
        try:
            wait_ready(f"http://127.0.0.1:{args.port}/", process)
        except BrowserLocalError as error:
            if not args.diagnostic_startup_failure:
                raise
            owner["server_startup_failure"] = {
                "observed": True,
                "error": str(error),
                "trace_unavailable_reason": "context_not_created",
            }
            raise
        owner["server_status"] = "ready"
        write_json(output_root / OWNER_FILE, owner)

        if args.diagnostic_case:
            diagnostic_root = output_root / "native-diagnostics" / args.diagnostic_case
            invocation_id = f"{output_root.name}-{args.diagnostic_case}"
            diagnostic_env = dict(app_env)
            diagnostic_env.update({
                "SIGRA_CI_DIAGNOSTICS": "1",
                "SIGRA_CI_DIAGNOSTICS_ROOT": str(diagnostic_root),
                "SIGRA_CI_TRACE_REGISTRY": str(diagnostic_root / "trace-registry.jsonl"),
                "SIGRA_CI_INVOCATION_ID": invocation_id,
                "SIGRA_CI_NATIVE_IDENTITY": "chromium:playwright-diagnostics.spec.ts",
                "SIGRA_DIAGNOSTIC_CASE": args.diagnostic_case,
            })
            command = ["node", str(PLAYWRIGHT / "node_modules/playwright/cli.js"), "test",
                       "--config", str(DIAGNOSTIC_CONFIG), "--project=chromium", "--retries=0"]
            if args.diagnostic_case == "terminate":
                command.extend(["--grep", "retains a default-context first failure"])
            code = run_recorded(command, PLAYWRIGHT, output_root, f"diagnostic-{args.diagnostic_case}", diagnostic_env)
            command_record_path = output_root / f"diagnostic-{args.diagnostic_case}" / "record.json"
            command_record = json.loads(command_record_path.read_text()) if command_record_path.is_file() else {}
            owner["native_diagnostic"] = {
                "case": args.diagnostic_case,
                "invocation_id": invocation_id,
                "native_identity": "chromium:playwright-diagnostics.spec.ts",
                "exit_code": code,
                "observed_signal": command_record.get("primary_signal"),
                "trace_unavailable_reason": "runner_terminated" if command_record.get("primary_signal") else None,
                "output_root": str(diagnostic_root),
            }
            write_json(output_root / OWNER_FILE, owner)
            if args.diagnostic_case == "pass" and code != 0:
                raise BrowserLocalError(f"passing diagnostic browser invocation failed; streams are in {output_root / f'diagnostic-{args.diagnostic_case}'}", code)
            if args.diagnostic_case == "fail" and code == 0:
                raise BrowserLocalError("failing diagnostic browser invocation unexpectedly passed")
            if args.diagnostic_case == "terminate" and command_record.get("primary_signal") != signal.SIGTERM:
                raise BrowserLocalError("diagnostic browser invocation did not record the expected SIGTERM", code or 1)
            owner["test_result"] = f"diagnostic_{args.diagnostic_case}_observed"
        else:
            command = ["node", str(BROWSER_COMMAND), "list", "--seam", args.seam, "--event", args.event,
                       "--output-root", str(output_root / "playwright-report")]
            if args.grep:
                command.extend(["--grep", args.grep])
            code = run_recorded(command, ROOT, output_root, "playwright-discovery", app_env)
            if code:
                raise BrowserLocalError(f"Playwright selection discovery failed; command streams are in {output_root / 'playwright-discovery'}", code)
            owner["selected_native_identities"] = selected_identities(output_root / "playwright-report")
            write_json(output_root / OWNER_FILE, owner)
            command = ["node", str(BROWSER_COMMAND), "run", "--seam", args.seam, "--event", args.event,
                       "--output-root", str(output_root / "playwright-report")]
            if args.grep:
                command.extend(["--grep", args.grep])
            code = run_recorded(command, ROOT, output_root, "playwright-run", app_env)
            if code:
                raise BrowserLocalError(f"Playwright run failed; command streams and native reports are retained in {output_root / 'playwright-run'}", code)
            owner["execution_reports"] = verify_execution_identities(output_root / "playwright-report", owner["selected_native_identities"])
            owner["test_result"] = "passed"
    except KeyboardInterrupt:
        primary_code = 130
        owner["test_result"] = "interrupted"
        owner["primary_exit_code"] = primary_code
    except BrowserLocalError as error:
        primary_code = error.code or 1
        owner["test_result"] = "failed"
        owner["primary_exit_code"] = primary_code
        owner["primary_error"] = str(error)
        print(str(error), file=sys.stderr)
    except OSError as error:
        primary_code = 1
        owner["test_result"] = "failed"
        owner["primary_exit_code"] = primary_code
        owner["primary_error"] = f"{type(error).__name__}: {error}"
        print(owner["primary_error"], file=sys.stderr)
    finally:
        if startup_failure_listener is not None:
            startup_failure_listener.close()
        cleanup_errors = cleanup_owned_resources(owner, example_env, process)
        owner["cleanup_errors"] = cleanup_errors
        owner["ended_at"] = time.time()
        write_json(output_root / OWNER_FILE, owner)
        if primary_code == 0 and cleanup_errors:
            primary_code = 1
        if primary_code == 0 and not cleanup_errors and not args.keep_output:
            try:
                if output_root.is_symlink() or json.loads((output_root / OWNER_FILE).read_text()).get("ownership_token") != token:
                    raise BrowserLocalError("refusing output cleanup: ownership marker did not match")
                shutil.rmtree(output_root)
            except (OSError, BrowserLocalError, json.JSONDecodeError) as error:
                cleanup_errors.append(f"output_cleanup_failed:{error}")
                owner["cleanup_errors"] = cleanup_errors
                primary_code = 1
        if primary_code != 0 or cleanup_errors:
            print(f"Browser reproduction diagnostics: {output_root}", file=sys.stderr)
        else:
            if args.diagnostic_case:
                print(f"Browser diagnostic case observed: {args.diagnostic_case}; artifacts: {output_root}")
            else:
                print(f"Browser reproduction passed: {args.seam} ({args.event}) on port {args.port}")
            print(f"Owned database cleaned: {database}")
            if server_pid is not None:
                print(f"Owned server stopped: pid {server_pid}")
            for report in owner.get("execution_reports", []):
                print(f"Executed report: {report['report']} ({report['selected_identities']} native identities)")
            for identity in owner.get("selected_native_identities", []):
                title_path = " › ".join([*identity["suite_path"], identity["title"]])
                print(f"Selected: {identity['project']} {identity['file']} :: {title_path} [{identity['expected_status']}]")
        for error in cleanup_errors:
            print(f"Cleanup issue: {error}", file=sys.stderr)
    return primary_code


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seam", choices=SEAMS, required=True)
    parser.add_argument("--event", choices=EVENTS, required=True)
    parser.add_argument("--port", type=int, required=True)
    parser.add_argument("--grep", help="narrow the selected seam to a matching test title")
    parser.add_argument("--diagnostic-case", choices=("pass", "fail", "terminate"), help="run the isolated real-browser diagnostics fixture")
    parser.add_argument("--diagnostic-startup-failure", action="store_true", help="occupy the owned port to capture a real Phoenix startup failure")
    parser.add_argument("--keep-output", action="store_true", help="retain the owned output directory after cleanup; diagnostics only")
    parser.add_argument("--output-root", help="new, non-existent directory for this invocation's diagnostics")
    args = parser.parse_args(argv)
    if args.keep_output and not (args.diagnostic_case or args.diagnostic_startup_failure):
        parser.error("--keep-output is available only with diagnostic mode")
    if args.diagnostic_case and args.diagnostic_startup_failure:
        parser.error("choose either --diagnostic-case or --diagnostic-startup-failure")
    try:
        return _run_local(args)
    except BrowserLocalError as error:
        print(str(error), file=sys.stderr)
        return error.code
    except (FileExistsError, PermissionError) as error:
        print(f"could not create invocation-owned output directory: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
