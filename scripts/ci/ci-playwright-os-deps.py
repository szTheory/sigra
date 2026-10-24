#!/usr/bin/env python3
"""Install the locked Playwright OS packages without unbounded apt downloads.

Only Ubuntu 24.04 amd64 is supported. Repository signatures and TLS verification
remain enabled. Acquisition may retry once; package configuration never retries
or receives this helper's wall-clock timeout.
"""

from __future__ import annotations

import argparse
from contextlib import contextmanager
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shlex
import shutil
import subprocess
import tempfile
import time
import urllib.parse


HOSTS = {"archive.ubuntu.com", "security.ubuntu.com", "azure.archive.ubuntu.com"}
PACKAGE = re.compile(r"[a-z0-9][a-z0-9+.-]*\Z")
SUITES = {"noble", "noble-updates", "noble-security", "noble-backports"}
KEYRING = "/usr/share/keyrings/ubuntu-archive-keyring.gpg"


def packages_from_dry_run(output: str) -> list[str]:
    """Parse the public CLI's printed command as data, never execute its shell."""
    if len(output) > 65536 or len(output.strip().splitlines()) != 1:
        raise ValueError("unexpected_playwright_dry_run_output")
    wrapper = shlex.split(output)
    if wrapper[:4] == ["sudo", "--", "sh", "-c"] and len(wrapper) == 5:
        command = wrapper[4]
    elif wrapper[:2] == ["sh", "-c"] and len(wrapper) == 3:
        command = wrapper[2]
    else:
        raise ValueError("unexpected_playwright_dry_run_wrapper")
    lexer = shlex.shlex(command, posix=True, punctuation_chars=True)
    lexer.whitespace_split = True
    lexer.commenters = ""
    tokens = list(lexer)
    prefix = ["apt-get", "update", "&&", "apt-get", "install", "-y", "--no-install-recommends"]
    packages = tokens[len(prefix):]
    if tokens[:len(prefix)] != prefix or not packages or any(not PACKAGE.fullmatch(p) for p in packages):
        raise ValueError("unexpected_playwright_apt_command")
    if len(set(packages)) != len(packages):
        raise ValueError("duplicate_playwright_package")
    return packages


def _official_uri(value: str) -> bool:
    uri = urllib.parse.urlsplit(value)
    return (uri.scheme in {"http", "https"} and uri.hostname in HOSTS
            and not uri.username and not uri.password and uri.port is None
            and uri.path.rstrip("/") == "/ubuntu" and not uri.query and not uri.fragment)


def ubuntu_sources(original: str, mirrorlists: dict[str, str]) -> str:
    """Retain each Ubuntu stanza, replacing only its URI field and continuations."""
    result = []
    for stanza in re.split(r"\n[ \t]*\n", original.strip()):
        lines = stanza.splitlines()
        fields = {}
        spans = {}
        current = None
        for index, line in enumerate(lines):
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            if line.startswith((" ", "\t")):
                if current is None:
                    raise ValueError("invalid_ubuntu_sources_continuation")
                fields[current] += " " + line.strip()
                spans[current][1] = index + 1
                continue
            match = re.fullmatch(r"([A-Za-z][A-Za-z-]*):[ \t]*(.*)", line)
            if not match or match[1].lower() in fields:
                raise ValueError("invalid_ubuntu_sources_field")
            current = match[1].lower()
            fields[current] = match[2]
            spans[current] = [index, index + 1]
        if not fields:
            result.append(stanza)
            continue
        required = {"types", "uris", "suites", "components", "signed-by"}
        allowed = required | {"architectures", "languages", "targets", "enabled", "pdiffs", "by-hash"}
        if not required <= fields.keys() or not fields.keys() <= allowed:
            raise ValueError("unsupported_ubuntu_sources_fields")
        if (not set(fields["types"].split()) <= {"deb", "deb-src"}
                or not fields["types"].split()
                or not set(fields["suites"].split()) <= SUITES or not fields["suites"].split()
                or not set(fields["components"].split()) <= {"main", "restricted", "universe", "multiverse"}
                or not fields["components"].split()
                or fields["signed-by"].strip() != KEYRING
                or fields.get("architectures", "amd64").split() != ["amd64"]
                or fields.get("enabled", "yes") != "yes"):
            raise ValueError("unsupported_ubuntu_sources_identity")
        for uri in fields["uris"].split():
            if uri in {"mirror+file:/etc/apt/apt-mirrors.txt", "mirror+file:/etc/apt/apt-security-mirrors.txt"}:
                mirrorlist = mirrorlists.get(uri, "")
                mirrors = [line.split()[0] for line in mirrorlist.splitlines()
                           if line.strip() and not line.lstrip().startswith("#")]
                if not mirrors or not all(_official_uri(item) for item in mirrors):
                    raise ValueError("unrecognized_ubuntu_mirrorlist")
            elif not _official_uri(uri):
                raise ValueError("unrecognized_ubuntu_source_uri")
        if not fields["uris"].split():
            raise ValueError("missing_ubuntu_source_uri")
        security_only = set(fields["suites"].split()) == {"noble-security"}
        host = "security.ubuntu.com" if security_only else "archive.ubuntu.com"
        start, end = spans["uris"]
        lines[start:end] = [f"URIs: https://{host}/ubuntu/"]
        result.append("\n".join(lines))
    if not result or not any("URIs: https://" in stanza for stanza in result):
        raise ValueError("no_ubuntu_sources")
    return "\n\n".join(result) + "\n"


def transient_acquisition(code: int, output: str) -> bool:
    if re.search(r"NO_PUBKEY|GPG error|not signed|Certificate verification failed|Release file.*expired", output, re.I):
        return False
    return code in {124, 137} or bool(re.search(
        r"Temporary failure resolving|Could not connect|Connection (?:failed|timed out)|"
        r"TLS connection was non-properly terminated|(?:500|502|503|504) (?:Internal|Bad|Service|Gateway)",
        output, re.I))


def run_logged(argv: list[str], log: Path) -> int:
    with log.open("x") as output:
        return subprocess.run(argv, stdout=output, stderr=subprocess.STDOUT).returncode


@contextmanager
def apt_directory():
    # apt creates root/_apt-owned files; only remove the directory we generated.
    folder = Path(tempfile.mkdtemp(prefix="sigra-playwright-apt-"))
    try:
        folder.chmod(0o755)
        yield folder
    finally:
        try:
            shutil.rmtree(folder)
        except PermissionError:
            subprocess.run(["sudo", "--non-interactive", "rm", "--recursive", "--force",
                            "--one-file-system", "--", str(folder)], check=True)


def install(playwright_dir: Path, browsers: list[str], report_path: Path, *,
            system_root: Path = Path("/"), runner=run_logged) -> int:
    report = {"schema_version": "sigra.playwright-os-deps/v1", "status": "failed",
              "browsers": browsers, "phases": [], "maximum_acquisition_attempts": 2,
              "package_configuration_retried": False,
              "retry_policy": "one fresh connection to the official HTTPS sources"}
    if report_path.exists():
        raise ValueError("report_already_exists")
    report_path.parent.mkdir(parents=True, exist_ok=True)

    def save():
        report_path.write_text(json.dumps(report, indent=2) + "\n")

    def stage(name, attempt, argv):
        log = report_path.with_name(report_path.stem + f".{attempt}.{name}.log")
        started = time.monotonic()
        code = runner(argv, log)
        report["phases"].append({"phase": name, "attempt": attempt, "exit_code": code,
                                 "elapsed_seconds": round(time.monotonic() - started, 3),
                                 "log": str(log), "log_sha256": hashlib.sha256(log.read_bytes()).hexdigest()})
        save()
        return code, log.read_text(errors="replace")

    try:
        if not browsers or len(set(browsers)) != len(browsers) or not set(browsers) <= {"chromium", "webkit", "firefox"}:
            raise ValueError("unsupported_browser_selection")
        release = dict(line.split("=", 1) for line in (system_root/"etc/os-release").read_text().splitlines()
                       if "=" in line and not line.startswith("#"))
        if (platform.system() != "Linux" or platform.machine() != "x86_64"
                or release.get("ID", "").strip('"') != "ubuntu"
                or release.get("VERSION_ID", "").strip('"') != "24.04"):
            raise ValueError("requires_ubuntu_24_04_amd64")
        if not (system_root/KEYRING.lstrip("/")).is_file():
            raise ValueError("ubuntu_archive_keyring_missing")
        source = (system_root/"etc/apt/sources.list.d/ubuntu.sources").read_text()
        mirrors = {}
        for name in ("apt-mirrors.txt", "apt-security-mirrors.txt"):
            path = system_root/"etc/apt"/name
            if path.is_file():
                mirrors[f"mirror+file:/etc/apt/{name}"] = path.read_text()
        generated = ubuntu_sources(source, mirrors)
        node = shutil.which("node")
        cli = playwright_dir/"node_modules/playwright/cli.js"
        if not node or not cli.is_file():
            raise ValueError("locked_playwright_cli_missing")
        # The public CLI derives package names for the actual host and selection.
        code, dry_run = stage("package-plan", 0, [node, str(cli.resolve()), "install-deps", "--dry-run", *browsers])
        if code:
            return code
        packages = packages_from_dry_run(dry_run)
        report.update(packages=packages, original_sources_sha256=hashlib.sha256(source.encode()).hexdigest())
        sudo = [] if os.geteuid() == 0 else ["sudo", "--non-interactive"]
        with apt_directory() as temporary:
            (temporary/"empty-sources").mkdir(mode=0o755)
            (temporary/"lists").mkdir(mode=0o755)
            (temporary/"archives").mkdir(mode=0o755)
            for attempt in (1, 2):
                sources = temporary/"ubuntu.sources"
                sources.write_text(generated); sources.chmod(0o644)
                env = ["env", "DEBIAN_FRONTEND=noninteractive"]
                # Command-line options win over any later image apt.conf.d file.
                options = {"Dir::Etc::sourcelist": sources,
                           "Dir::Etc::sourceparts": temporary/"empty-sources",
                           "Dir::State::lists": temporary/"lists",
                           "Dir::Cache::archives": temporary/"archives",
                           "Dir::Cache::pkgcache": "", "Dir::Cache::srcpkgcache": "",
                           "Acquire::Retries": "0", "Acquire::http::Timeout": "15",
                           "Acquire::https::Timeout": "15", "APT::Update::Error-Mode": "any"}
                apt = ["/usr/bin/apt-get", *[arg for key, value in options.items()
                       for arg in ("-o", f"{key}={value}")], "-y", "--no-install-recommends"]
                failure = None
                for name, seconds, arguments in (("update", 60, ["update"]),
                                                 ("download", 240, ["--download-only", "install", *packages])):
                    command = [*sudo, "timeout", "--signal=TERM", "--kill-after=10s", f"{seconds}s", *env, *apt, *arguments]
                    code, output = stage(name, attempt, command)
                    if code:
                        failure = (code, output)
                        break
                if failure:
                    if attempt == 1 and transient_acquisition(*failure):
                        continue
                    return failure[0]
                # Every package is acquired and verified before dpkg can run.
                # Do not put a kill timer around package configuration.
                code, _ = stage("install", attempt, [*sudo, *env, *apt, "--no-download", "install", *packages])
                if code:
                    return code
                report["status"] = "passed"
                report["successful_acquisition_attempt"] = attempt
                return 0
        raise AssertionError("unreachable_acquisition_state")
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        report["status"] = "failed"
        report["diagnostic"] = str(error)
        return 1
    finally:
        save()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("browsers", nargs="+", choices=["chromium", "webkit", "firefox"])
    parser.add_argument("--playwright-dir", type=Path, default=Path.cwd())
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    return install(args.playwright_dir.resolve(), args.browsers, args.report.resolve())


if __name__ == "__main__":
    raise SystemExit(main())
