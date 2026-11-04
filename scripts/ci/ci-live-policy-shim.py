#!/usr/bin/env python3
"""Test-only live-policy seam for the Phase 253 hosted transport (253-107).

The hosted transport decides every policy question (allocation mode, route, hop, host, token
scope, ledger charge) in Python before it opens a socket. This module redirects only the layer
BELOW those decisions, so a live-mode allocation can be exercised end to end against a local
HTTPS server with zero real network I/O:

* ``socket.create_connection`` for a mapped ``(host, 443)`` connects to ``127.0.0.1:<port>`` and
  appends ``{"host", "port"}`` to the connect log; every other destination is refused with
  ``OSError("live-policy shim refused real network destination ...")`` and logged as a refusal.
* ``socket.getaddrinfo`` only resolves loopback names; anything else is refused and logged, so a
  connection path that bypasses ``create_connection`` still cannot reach the network.
* ``ssl.create_default_context`` returns a context that trusts ONLY the test CA, with hostname
  checking on, so SNI and certificate verification still use the real hostname
  (``api.github.com``, ``productionresultssa17.blob.core.windows.net``).
* ``time.sleep`` is optionally scaled.

Product code never imports this module. It is inert unless ``SIGRA_LIVE_POLICY_SHIM`` is set in a
process whose ``PYTHONPATH`` carries the ``sitecustomize.py`` written by :func:`prepare`, or unless a
test enters :func:`patched` in-process.
"""

from __future__ import annotations

import contextlib
import json
import os
import socket
import ssl
import subprocess
import threading
import time
from pathlib import Path

ENV_VAR = "SIGRA_LIVE_POLICY_SHIM"
LOOPBACK = "127.0.0.1"
LOOPBACK_NAMES = {"127.0.0.1", "localhost", "::1"}
_LOG_LOCK = threading.Lock()


def make_tls_identity(directory, hostnames) -> tuple[Path, Path]:
    """Write a self-signed certificate and key whose subjectAltName lists ``hostnames`` (wildcards allowed)."""
    directory = Path(directory)
    directory.mkdir(parents=True, exist_ok=True)
    names = [str(name) for name in hostnames]
    if not names or any(not name or "," in name or "\n" in name for name in names):
        raise ValueError("TLS identity needs at least one plain DNS name")
    cert, key = directory / "live-policy-cert.pem", directory / "live-policy-key.pem"
    san = ",".join(f"DNS:{name}" for name in names)
    subprocess.run(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1",
                    "-subj", "/CN=sigra-live-policy-test-ca", "-addext", f"subjectAltName={san}",
                    "-keyout", str(key), "-out", str(cert)],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return cert, key


def refusal_log_for(connect_log) -> Path:
    """The refusal log that sits beside a connect log."""
    return Path(str(connect_log) + ".refusals")


def read_log(path) -> list[dict]:
    path = Path(path)
    if not path.exists():
        return []
    return [json.loads(line) for line in path.read_text().splitlines() if line.strip()]


def _config(host_map, ca_file, connect_log, sleep_scale=None) -> dict:
    mapping = {}
    for host, port in dict(host_map).items():
        if not isinstance(host, str) or not host or isinstance(port, bool) or not isinstance(port, int) or not 1 <= port <= 65535:
            raise ValueError("host map entries must be a DNS name and a local port")
        mapping[host.lower()] = port
    if sleep_scale is not None and (isinstance(sleep_scale, bool) or not isinstance(sleep_scale, (int, float)) or sleep_scale < 0):
        raise ValueError("sleep_scale must be a non-negative number")
    return {"host_map": mapping, "ca_file": str(Path(ca_file).resolve()),
            "connect_log": str(Path(connect_log).resolve()),
            "refusal_log": str(refusal_log_for(Path(connect_log).resolve())),
            "sleep_scale": sleep_scale}


def _append(path: str, entry: dict) -> None:
    with _LOG_LOCK:
        with open(path, "a", encoding="utf-8") as stream:
            stream.write(json.dumps(entry, sort_keys=True) + "\n")


def _install(config: dict) -> dict:
    """Apply the patches described by ``config``; return the originals for restoration."""
    originals = {"create_connection": socket.create_connection, "getaddrinfo": socket.getaddrinfo,
                 "create_default_context": ssl.create_default_context, "sleep": time.sleep}
    host_map = config["host_map"]
    real_create_connection = originals["create_connection"]
    real_getaddrinfo = originals["getaddrinfo"]
    real_context = originals["create_default_context"]
    real_sleep = originals["sleep"]

    def refuse(kind: str, host, port):
        _append(config["refusal_log"], {"event": kind, "host": str(host), "port": port, "pid": os.getpid()})
        raise OSError(f"live-policy shim refused real network destination {host}:{port}")

    def create_connection(address, *args, **kwargs):
        host, port = address[0], address[1]
        key = str(host).lower()
        if key in host_map and port == 443:
            _append(config["connect_log"], {"host": key, "port": port})
            return real_create_connection((LOOPBACK, host_map[key]), *args, **kwargs)
        return refuse("refused_connect", host, port)

    def getaddrinfo(host, port, *args, **kwargs):
        name = host.decode() if isinstance(host, bytes) else host
        if name is None or str(name).lower() in LOOPBACK_NAMES:
            return real_getaddrinfo(host, port, *args, **kwargs)
        return refuse("refused_resolve", name, port)

    def create_default_context(purpose=ssl.Purpose.SERVER_AUTH, *, cafile=None, capath=None, cadata=None):
        # Trust only the test CA; hostname checking and certificate verification stay on.
        context = real_context(purpose, cafile=config["ca_file"])
        context.check_hostname = True
        context.verify_mode = ssl.CERT_REQUIRED
        return context

    socket.create_connection = create_connection
    socket.getaddrinfo = getaddrinfo
    ssl.create_default_context = create_default_context
    if config.get("sleep_scale") is not None:
        scale = config["sleep_scale"]
        time.sleep = lambda seconds: real_sleep(max(0.0, seconds * scale))
    return originals


def _restore(originals: dict) -> None:
    socket.create_connection = originals["create_connection"]
    socket.getaddrinfo = originals["getaddrinfo"]
    ssl.create_default_context = originals["create_default_context"]
    time.sleep = originals["sleep"]


SITECUSTOMIZE = '''"""Generated by scripts/ci/ci-live-policy-shim.py (test only). Inert without {env}."""
import os as _os
if _os.environ.get({env!r}):
    import importlib.util as _util
    _spec = _util.spec_from_file_location("sigra_live_policy_shim", {shim!r})
    _module = _util.module_from_spec(_spec)
    _spec.loader.exec_module(_module)
    _module.install_from_environment()
'''


def prepare(directory, host_map, ca_file, connect_log, sleep_scale=None) -> dict:
    """Write ``directory/sitecustomize.py`` and return the environment additions that activate it."""
    directory = Path(directory)
    directory.mkdir(parents=True, exist_ok=True)
    config = _config(host_map, ca_file, connect_log, sleep_scale)
    (directory / "sitecustomize.py").write_text(
        SITECUSTOMIZE.format(env=ENV_VAR, shim=str(Path(__file__).resolve())))
    return {"PYTHONPATH": str(directory.resolve()), ENV_VAR: json.dumps(config, sort_keys=True)}


def install_from_environment() -> bool:
    """Called by the generated sitecustomize; does nothing when the variable is absent."""
    raw = os.environ.get(ENV_VAR)
    if not raw:
        return False
    _install(json.loads(raw))
    return True


@contextlib.contextmanager
def patched(host_map, ca_file, connect_log, sleep_scale=None):
    """In-process equivalent of :func:`prepare` for unit tests; restores every patch on exit."""
    originals = _install(_config(host_map, ca_file, connect_log, sleep_scale))
    try:
        yield
    finally:
        _restore(originals)
