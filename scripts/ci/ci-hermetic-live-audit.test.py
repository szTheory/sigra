#!/usr/bin/env python3
"""253-110: the hermetic-vs-live branch audit, kept complete and current automatically. No network.

253-104 halted on a branch whose live side no offline gate had executed: every harness ran hermetic-test allocations,
so request_one's live origin check first ran in a hosted window. This checker re-scans the five hosted-proof files
with a stated matcher and fails when

- a matched site has no audit row, or a row no longer names a current site (stale anchor or moved line);
- a coverage ref names a test that does not exist, or an offline-live-test ref names a test with no live marker;
- a live-policy-gate row names no live-policy test, or no summary assertion that proves the branch ran;
- a justified row has no justification or no residual risk;
- (test_no_gap_rows) any row is still a gap.

Its own positive controls prove it can fail: a removed row, an added hermetic branch in a source copy, a missing test
ref, a hermetic-only test cited as live coverage, a moved line and a justified row without residual risk.

253-118 (schema r10) adds the response-shape class. Branch rows could not see a fake whose response differs from what
GitHub sends (253-113 halted on exactly that), so every GitHub route in ci-hosted-transport.py ROUTES (test routes
excluded) and the two workflow sources have one response_shape_rows entry naming the fields local verifiers and drivers
compare, the committed real responses those fields resolve in, and either the tests that compare against those real
bytes or a justification with its residual risk. The checker fails when

- a route has no row, a row names an unknown route, or a route has two rows;
- a real-sample locator does not hash as recorded, names a transaction of another route or status, or a pointer, archive
  member or source file that does not resolve;
- a compared field resolves in no real sample and has no per-field reason;
- a real-shape-test ref names no single existing test, or a test with no visible real-sample read;
- a justified row has no justification or residual risk, or any row is a gap (test_no_gap_rows).

Field syntax: a dotted path into the decoded response body ([] steps into each list item, a leading [] for a list root);
meta:FIELD for a ledger transaction field; header:NAME for a scrubbed response header; value:PATH=TEXT for a leaf equal to
TEXT; source:TEXT for text present in a committed source sample (a workflow file).
"""
import base64
import copy
import hashlib
import importlib.util
import io
import json
import re
import tarfile
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PHASE_REL = ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks"
AUDIT_REL = f"{PHASE_REL}/253-LOAD-RECOVERY-HERMETIC-LIVE-AUDIT-R11.json"
SCHEMA = "sigra.phase253.hermetic-live-audit/r10"
FILES = ("scripts/ci/ci-hosted-transport.py", "scripts/ci/ci-gate-canary.sh", "scripts/ci/ci-pr-proof.sh",
         "scripts/ci/ci-git-publication.py", "scripts/ci/ci-hosted-gate-verify.py")
KINDS = ("offline-live-test", "live-policy-gate", "justified", "gap")
TEST_FILES = ("scripts/ci/ci-hosted-transport.test.py", "scripts/ci/ci-hosted-gate-verify.test.py",
              "scripts/ci/ci-git-publication.test.py", "scripts/ci/ci-gate-canary-flow.test.py",
              "scripts/ci/ci-gate-canary-recovery.test.py", "scripts/ci/ci-gate-canary-dryrun.test.py",
              "scripts/ci/ci-pr-proof.test.sh")
LIVE_POLICY_GATE_FILES = ("scripts/ci/ci-gate-canary-dryrun.test.py", "scripts/ci/ci-pr-proof.test.sh")

# The matcher is part of the record: the record must state exactly the patterns this checker applies.
MATCHER = {
    "files": list(FILES),
    "skip": "blank lines, lines whose first non-space character is #, and text inside triple-quoted strings",
    "literal_strip": "a quoted literal that contains whitespace and neither == nor != (a message, not a compared value) "
                     "is replaced by an empty literal before matching",
    "topic": r"hermetic|HERMETIC|test_origin|test_ca_file|[\"']live[\"']|synthetic|API_HOST|dryrun_window|DRYRUN_WINDOW_PREFIX",
    "condition": r"^\s*(if|elif|while|assert)\b|\bif\b.*\belse\b|==|!=|\[\[|jq -e|\bnot in\b|\band\b|\bor\b|\brequire\(",
    "selector": r"require_live_origin|--require-live-origin",
    "selector_excludes": r"add_argument\(|^\s*def ",
    "rule": "a line is a site when condition and topic both match its stripped code, or when selector matches it and "
            "selector_excludes does not; a site is keyed by file, its exact stripped source line (anchor) and the "
            "1-based occurrence of that exact line in the file",
}
LITERAL = re.compile(r'"(?:[^"\\\n]|\\.)*"|\'(?:[^\'\\\n]|\\.)*\'')
# A test cited as offline live coverage must visibly run the live side: a live mode value, the live-policy shim, the
# live-policy dry-run, a Live* test class, a real (non-dry-run) window constant or a test named for the live side. It is
# a floor, not a proof: each row's live_behavior states what the cited test actually runs.
LIVE_MARKER = re.compile(r"[\"']live[\"']|mode=\"live\"|live_run\(|--live-policy|LiveWorld|LivePolicy|LiveHost|self\.shim\b|"
                         r"live_allocation\(|def test_\w*live|github-api|REAL_CANARY|REAL_PR")


def _strip_literals(code):
    return LITERAL.sub(lambda m: '""' if re.search(r"\s", m.group(0)) and not re.search(r"==|!=", m.group(0)) else m.group(0),
                       code)


def code_lines(text):
    """Yield (line number, raw line, code) for every line outside triple-quoted strings and full-line comments."""
    in_doc = False
    for number, raw in enumerate(text.splitlines(), 1):
        parts = raw.split('"""')
        outside = parts[1::2] if in_doc else parts[0::2]
        if (len(parts) - 1) % 2:
            in_doc = not in_doc
        code = "".join(outside)
        if not code.strip() or code.strip().startswith("#"):
            continue
        yield number, raw, code


def scan_text(text, matcher=MATCHER):
    topic, condition = re.compile(matcher["topic"]), re.compile(matcher["condition"])
    selector, excludes = re.compile(matcher["selector"]), re.compile(matcher["selector_excludes"])
    sites = []
    stripped_lines = [line.strip() for line in text.splitlines()]
    for number, raw, code in code_lines(text):
        code = _strip_literals(code)
        hit = (condition.search(code) and topic.search(code)) or (selector.search(code) and not excludes.search(code))
        if hit:
            anchor = raw.strip()
            occurrence = sum(1 for line in stripped_lines[:number] if line == anchor)
            sites.append({"anchor": anchor, "occurrence": occurrence, "line": number})
    return sites


def scan(root):
    return {rel: scan_text((Path(root) / rel).read_text()) for rel in FILES}


def anchor_line(text, anchor, occurrence):
    seen = 0
    for number, line in enumerate(text.splitlines(), 1):
        if line.strip() == anchor:
            seen += 1
            if seen == occurrence:
                return number
    return None


def _block(lines, start):
    """The indented block that starts at lines[start] (a def or class line)."""
    indent = len(lines[start]) - len(lines[start].lstrip())
    end = start + 1
    while end < len(lines) and (not lines[end].strip() or len(lines[end]) - len(lines[end].lstrip()) > indent):
        end += 1
    return lines[start:end], indent


def test_source(text, name):
    """Return (function body, enclosing class header) for a test ref name ("test_x" or "Class.test_x"), else None.

    A bare name must be defined exactly once in the file; a qualified name is looked up inside its class."""
    lines = text.splitlines()
    wanted_class, _, func = name.rpartition(".")
    found = []
    for index, line in enumerate(lines):
        if re.match(rf"\s*def {re.escape(func)}\(", line):
            body, indent = _block(lines, index)
            owner, header = None, ""
            for back in range(index - 1, -1, -1):
                match = re.match(r"(\s*)class (\w+)", lines[back])
                if match and len(match.group(1)) < indent:
                    owner = match.group(2)
                    class_lines = [lines[back]]
                    for follow in lines[back + 1:index]:
                        if re.match(r"\s*def ", follow):
                            break
                        class_lines.append(follow)
                    header = "\n".join(class_lines)
                    break
            if not wanted_class or owner == wanted_class:
                found.append(("\n".join(body), header))
    return found[0] if len(found) == 1 else None


def check(record, root, matcher=MATCHER):
    """Every problem with the record against the source tree at root; an empty list means complete and current."""
    root = Path(root)
    problems = []
    if record.get("schema") != SCHEMA:
        problems.append(f"schema is not {SCHEMA}")
    if record.get("matcher") != matcher:
        problems.append("the record's matcher is not the checker's matcher")
    if not re.fullmatch(r"[0-9a-f]{40}", str(record.get("audit_head", ""))):
        problems.append("audit_head is not a full commit id")
    rows = record.get("rows")
    if not isinstance(rows, list) or not rows:
        return problems + ["the record has no rows"]
    texts = {rel: (root / rel).read_text() for rel in FILES}
    tests = {rel: (root / rel).read_text() for rel in TEST_FILES if (root / rel).exists()}
    sites = {rel: scan_text(texts[rel], matcher) for rel in FILES}
    keyed = {}
    ids = set()
    for row in rows:
        rid = row.get("id")
        if not rid or rid in ids:
            problems.append(f"row id {rid!r} is missing or repeated")
        ids.add(rid)
        if row.get("file") not in FILES:
            problems.append(f"{rid}: file {row.get('file')!r} is not one of the five audited files")
            continue
        for field in ("anchor", "hermetic_behavior", "live_behavior"):
            if not isinstance(row.get(field), str) or not row[field].strip():
                problems.append(f"{rid}: {field} is missing")
        key = (row["file"], row.get("anchor"), row.get("occurrence", 1))
        if key in keyed:
            problems.append(f"{rid}: duplicates row {keyed[key]['id']} for the same site")
        keyed[key] = row
        line = anchor_line(texts[row["file"]], row.get("anchor"), row.get("occurrence", 1))
        if line is None:
            problems.append(f"{rid}: anchor no longer exists in {row['file']}: {row.get('anchor')!r}")
        elif line != row.get("line"):
            problems.append(f"{rid}: anchor moved from line {row.get('line')} to line {line} in {row['file']}")
        is_site = any((row["file"], site["anchor"], site["occurrence"]) == key for site in sites[row["file"]])
        if not is_site and not (row.get("supplementary") and str(row.get("supplementary_reason", "")).strip()):
            problems.append(f"{rid}: anchor is not a matcher site and the row is not a reasoned supplementary row")
        coverage = row.get("coverage") or {}
        kind = coverage.get("kind")
        if kind not in KINDS:
            problems.append(f"{rid}: coverage kind {kind!r} is not one of {KINDS}")
            continue
        refs = coverage.get("refs") or []
        if kind in ("offline-live-test", "live-policy-gate") and not refs:
            problems.append(f"{rid}: {kind} needs at least one test ref")
        bodies = []
        for ref in refs:
            path, sep, name = str(ref).partition("::")
            if not sep or path not in TEST_FILES:
                problems.append(f"{rid}: ref {ref!r} is not path::test_name in an approved test file")
                continue
            found = test_source(tests.get(path, ""), name)
            if found is None:
                problems.append(f"{rid}: ref {ref!r} names no single existing test function")
                continue
            body, header = found
            bodies.append(body)
            if kind == "offline-live-test" and not LIVE_MARKER.search(body + "\n" + header):
                problems.append(f"{rid}: ref {ref!r} shows no live marker, so it cannot count as live coverage")
            if kind == "live-policy-gate" and path not in LIVE_POLICY_GATE_FILES:
                problems.append(f"{rid}: live-policy-gate ref {ref!r} is not a live-policy gate test")
        if kind == "live-policy-gate":
            assertions = coverage.get("summary_assertions") or []
            if not assertions:
                problems.append(f"{rid}: live-policy-gate needs the summary assertion that proves the branch ran")
            for item in assertions:
                if not any(item in body for body in bodies):
                    problems.append(f"{rid}: summary assertion {item!r} is not asserted by any cited test")
        if kind == "justified":
            for field in ("justification", "residual_risk"):
                if not str(coverage.get(field, "")).strip():
                    problems.append(f"{rid}: a justified row needs a non-empty {field}")
    for rel in FILES:
        for site in sites[rel]:
            if (rel, site["anchor"], site["occurrence"]) not in keyed:
                problems.append(f"unaudited site {rel}:{site['line']}: {site['anchor']}")
    counts = record.get("match_counts")
    actual_counts = {rel: len(sites[rel]) for rel in FILES}
    if counts != actual_counts:
        problems.append(f"match_counts {counts} differ from the scan {actual_counts}")
    return problems + check_response_shapes(record, root)


# ------------------------------------------------------------------------------------------- response shapes (253-118)
TRANSPORT_REL = "scripts/ci/ci-hosted-transport.py"
TEST_ROUTES = frozenset({"test_probe", "test_page"})
WORKFLOW_SOURCE_IDS = ("workflow-source:canary-fixture", "workflow-source:ci-yml")
SHAPE_KINDS = ("real-shape-test", "justified", "gap")
SHAPE_FAMILIES = ("canary", "pr", "both")
SHAPE_TEST_FILES = ("scripts/ci/ci-gate-canary-dryrun.test.py", "scripts/ci/ci-hosted-gate-verify.test.py",
                    "scripts/ci/ci-git-publication.test.py", "scripts/ci/ci-pr-proof.test.sh")
# A test cited as real-shape coverage must visibly read committed real bytes, in its body or its class's setUp or
# setUpClass: a committed ledger, evidence, workflow or bundle constant, the 253-117 real-shape builders, or the dry-run's
# response_shape gate (which compares every served response with the committed R9 ledger). Like LIVE_MARKER it is a
# floor: each row states what its tests compare.
REAL_SAMPLE_MARKER = re.compile(r"EVIDENCE_R9|REAL_LEDGER_R9|\bLEDGER_R[789]\b|\bR[789]_LEDGER\b|LEDGER-R[789]|FIRST_CANARY_RUN|"
                                r"38347679431|\breal_(?:bodies|run|job|steps|artifact)\(|verifier_run_receipt\(|ledger_body\(|bundle_member\(|"
                                r"response_shape|REGISTERED_FIXTURE|CANARY-WORKFLOW|CI_YML|PUBLICATION_RECEIPT_R9|REAL_RECEIPT")
_NO_BODY = object()
_MEMBER_CACHE = {}


def transport_routes(root):
    """ROUTES as the transport module at root defines it (imported, never parsed by pattern)."""
    spec = importlib.util.spec_from_file_location("audit_transport_routes", Path(root) / TRANSPORT_REL)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return dict(module.ROUTES)


def _path_tokens(path):
    tokens = []
    for part in path.split("."):
        name, each = part, 0
        while name.endswith("[]"):
            name, each = name[:-2], each + 1
        if name:
            tokens.append(name)
        tokens.extend([None] * each)
    return tokens


def _leaves(value, tokens):
    """Every value at a tokenized path; a key must be present (its value may be null), [] steps into each list item."""
    if not tokens:
        yield value
        return
    head, rest = tokens[0], tokens[1:]
    if head is None:
        if isinstance(value, list):
            for item in value:
                yield from _leaves(item, rest)
    elif isinstance(value, dict) and head in value:
        yield from _leaves(value[head], rest)


def json_pointer(document, pointer):
    if pointer == "":
        return document
    if not pointer.startswith("/"):
        raise KeyError(pointer)
    for raw in pointer[1:].split("/"):
        key = raw.replace("~1", "/").replace("~0", "~")
        document = document[int(key)] if isinstance(document, list) else document[key]
    return document


def field_resolves(field, sample):
    """True when field is present in one loaded real sample ({tx, body} for a response, {text} for a source file)."""
    body, tx, text = sample.get("body", _NO_BODY), sample.get("tx"), sample.get("text")
    if field.startswith("source:"):
        return text is not None and field[len("source:"):] in text
    if field.startswith("meta:"):
        return isinstance(tx, dict) and any(True for _ in _leaves(tx, _path_tokens(field[len("meta:"):])))
    if field.startswith("header:"):
        headers = tx.get("scrubbed_headers") if isinstance(tx, dict) else None
        return isinstance(headers, dict) and any(True for _ in _leaves(headers, _path_tokens(field[len("header:"):])))
    if body is _NO_BODY:
        return False
    if field.startswith("value:"):
        path, sep, wanted = field[len("value:"):].partition("=")
        return bool(sep) and any(leaf == wanted or (not isinstance(leaf, (dict, list)) and leaf is not None and str(leaf) == wanted)
                                 for leaf in _leaves(body, _path_tokens(path)))
    return any(True for _ in _leaves(body, _path_tokens(field)))


def load_sample(root, sample, route, cache):
    """Return (loaded sample, problems) for one locator. A sequence must be a transaction of the row's route (or, for a
    workflow-source row, of the route the locator names) with the recorded status; its body is the decoded response."""
    if not isinstance(sample, dict):
        return None, ["a real sample is not an object"]
    rel = sample.get("path")
    if not isinstance(rel, str) or not rel or Path(rel).is_absolute() or ".." in Path(rel).parts:
        return None, [f"real sample path {rel!r} is not a relative checkout path"]
    path = Path(root) / rel
    if rel not in cache:
        cache[rel] = path.read_bytes() if path.is_file() else None
    raw = cache[rel]
    if raw is None:
        return None, [f"real sample {rel} does not exist"]
    digest = hashlib.sha256(raw).hexdigest()
    if digest != sample.get("sha256"):
        return None, [f"real sample {rel} hashes to {digest}, not the recorded {sample.get('sha256')}"]
    data, where = raw, rel
    if "member" in sample:
        key = (digest, sample["member"])
        if key not in _MEMBER_CACHE:  # keyed by the archive's verified digest, so a changed archive is re-read
            try:
                with tarfile.open(fileobj=io.BytesIO(raw), mode="r:*") as bundle:
                    handle = bundle.extractfile(sample["member"])
                    _MEMBER_CACHE[key] = handle.read() if handle is not None else None
            except (tarfile.TarError, KeyError):
                _MEMBER_CACHE[key] = None
        data = _MEMBER_CACHE[key]
        if data is None:
            return None, [f"real sample {rel} has no archive member {sample['member']!r}"]
        member_digest = hashlib.sha256(data).hexdigest()
        if member_digest != sample.get("member_sha256"):
            return None, [f"real sample {rel} member {sample['member']} hashes to {member_digest}, not the recorded "
                          f"{sample.get('member_sha256')}"]
        where = f"{rel}!{sample['member']}"
    if sample.get("kind") == "source":
        try:
            return {"text": data.decode("utf-8", "strict")}, []
        except UnicodeError:
            return None, [f"source sample {where} is not UTF-8 text"]
    try:
        document = json.loads(data)
    except (UnicodeError, ValueError):
        return None, [f"real sample {where} is not JSON"]
    if "sequence" in sample:
        wanted_route = sample.get("route", route) if route.startswith("workflow-source:") else route
        if route.startswith("workflow-source:") and "route" not in sample:
            return None, [f"real sample {where} sequence {sample['sequence']} names no route for a workflow-source row"]
        rows = [tx for tx in (document.get("transactions") if isinstance(document, dict) else None) or []
                if isinstance(tx, dict) and tx.get("sequence") == sample["sequence"]]
        if len(rows) != 1:
            return None, [f"real sample {where} has no single transaction with sequence {sample['sequence']}"]
        tx = rows[0]
        if tx.get("route_id") != wanted_route:
            return None, [f"real sample {where} sequence {sample['sequence']} is route {tx.get('route_id')}, not {wanted_route}"]
        if tx.get("actual_status") != sample.get("actual_status"):
            return None, [f"real sample {where} sequence {sample['sequence']} has status {tx.get('actual_status')}, "
                          f"not the recorded {sample.get('actual_status')}"]
        try:
            body = json.loads(base64.b64decode(tx.get("response_body_base64") or "", validate=True))
        except (UnicodeError, ValueError):
            body = _NO_BODY
        return {"tx": tx, "body": body}, []
    if "pointer" in sample:
        if not str(sample.get("route_evidence", "")).strip():
            return None, [f"real sample {where} pointer {sample['pointer']!r} states no route_evidence (a pointer cannot be "
                          "route-checked, so the locator must say why it is this route's response)"]
        try:
            return {"tx": None, "body": json_pointer(document, sample["pointer"])}, []
        except (KeyError, IndexError, ValueError, TypeError):
            return None, [f"real sample {where} pointer {sample['pointer']!r} does not resolve"]
    return None, [f"real sample {where} names no sequence, pointer or source kind"]


def _consumer_problems(rid, consumers, root, texts):
    problems = []
    if not isinstance(consumers, list) or not consumers:
        return [f"{rid}: consumers must name at least one file::symbol that reads this response"]
    for consumer in consumers:
        rel, sep, symbol = str(consumer).partition("::")
        if not sep or rel not in FILES or not symbol:
            problems.append(f"{rid}: consumer {consumer!r} is not file::symbol in one of the five hosted-proof files")
            continue
        if rel not in texts:
            texts[rel] = (Path(root) / rel).read_text()
        if not re.search(rf"(?<![\w]){re.escape(symbol)}(?![\w])", texts[rel]):
            problems.append(f"{rid}: consumer symbol {symbol!r} does not occur in {rel}")
    return problems


def check_response_shapes(record, root):
    """Every problem with the response-shape class; an empty list means route-complete, resolved and current."""
    root = Path(root)
    rows = record.get("response_shape_rows")
    if not isinstance(rows, list) or not rows:
        return ["the record has no response_shape_rows"]
    problems = []
    expected = (set(transport_routes(root)) - TEST_ROUTES) | set(WORKFLOW_SOURCE_IDS)
    tests = {rel: (root / rel).read_text() for rel in SHAPE_TEST_FILES if (root / rel).exists()}
    cache, texts, seen, ids = {}, {}, {}, set()
    for row in rows:
        rid = row.get("id") if isinstance(row, dict) else None
        if not rid or rid in ids:
            problems.append(f"response-shape row id {rid!r} is missing or repeated")
        ids.add(rid)
        if not isinstance(row, dict):
            continue
        route = row.get("route")
        if route not in expected:
            problems.append(f"{rid}: route {route!r} is not a transport route (test routes excluded) or a workflow-source id")
            continue
        if route in seen:
            problems.append(f"{rid}: route {route} already has response-shape row {seen[route]}")
        seen.setdefault(route, rid)
        if row.get("families") not in SHAPE_FAMILIES:
            problems.append(f"{rid}: families {row.get('families')!r} is not one of {SHAPE_FAMILIES}")
        problems += _consumer_problems(rid, row.get("consumers"), root, texts)
        fields = row.get("fields_compared")
        if not isinstance(fields, list) or not fields or not all(isinstance(item, str) and item for item in fields) \
                or len(set(fields)) != len(fields):
            problems.append(f"{rid}: fields_compared must be a non-empty list of unique field strings")
            fields = [item for item in fields or [] if isinstance(item, str)]
        coverage = row.get("coverage") if isinstance(row.get("coverage"), dict) else {}
        kind = coverage.get("kind")
        if kind not in SHAPE_KINDS:
            problems.append(f"{rid}: coverage kind {kind!r} is not one of {SHAPE_KINDS}")
        without = coverage.get("fields_without_real_sample") or {}
        if not isinstance(without, dict):
            problems.append(f"{rid}: fields_without_real_sample must map a field to its reason")
            without = {}
        loaded = []
        samples = row.get("real_samples")
        if not isinstance(samples, list):
            problems.append(f"{rid}: real_samples must be a list")
            samples = []
        for sample in samples:
            value, found = load_sample(root, sample, route, cache)
            problems += [f"{rid}: {item}" for item in found]
            if value is not None:
                loaded.append(value)
        for field in fields:
            resolved = any(field_resolves(field, sample) for sample in loaded)
            if resolved and field in without:
                problems.append(f"{rid}: field {field!r} resolves in a real sample but is also listed without one")
            if not resolved and not str(without.get(field, "")).strip():
                problems.append(f"{rid}: compared field {field!r} resolves in no real sample and has no reason in "
                                "fields_without_real_sample")
        for field in without:
            if field not in fields:
                problems.append(f"{rid}: fields_without_real_sample names {field!r}, which is not a compared field")
        if not samples and (kind != "justified" or set(without) != set(fields)):
            problems.append(f"{rid}: real_samples may be empty only for a fully justified row")
        for nearest in row.get("nearest_real_samples") or []:
            # A nearest sample is evidence from a neighbouring route, so a sequence locator names its own route.
            near_route = nearest.get("route", route) if isinstance(nearest, dict) else route
            value, found = load_sample(root, nearest, near_route, cache)
            problems += [f"{rid}: nearest {item}" for item in found]
            shows = nearest.get("shows") if isinstance(nearest, dict) else None
            if value is not None and not (isinstance(shows, str) and field_resolves(shows, value)):
                problems.append(f"{rid}: the nearest real sample does not show {shows!r}")
        if (without or kind == "justified") and not str(coverage.get("residual_risk", "")).strip():
            problems.append(f"{rid}: a row with a justified field or a justified row needs a non-empty residual_risk")
        if kind == "justified" and not str(coverage.get("justification", "")).strip():
            problems.append(f"{rid}: a justified row needs a non-empty justification")
        refs = coverage.get("refs") or []
        if kind == "real-shape-test" and not refs:
            problems.append(f"{rid}: real-shape-test needs at least one test ref")
        for ref in refs:
            path, sep, name = str(ref).partition("::")
            if not sep or path not in SHAPE_TEST_FILES:
                problems.append(f"{rid}: ref {ref!r} is not path::test_name in an approved real-shape test file")
                continue
            found = test_source(tests.get(path, ""), name)
            if found is None:
                problems.append(f"{rid}: ref {ref!r} names no single existing test function")
                continue
            body, header = found
            # The real bytes may be loaded by the test's own class fixture (setUp or setUpClass), so those count too.
            owner = name.rpartition(".")[0]
            fixtures = [test_source(tests.get(path, ""), f"{owner}.{hook}") for hook in ("setUp", "setUpClass")] if owner else []
            visible = "\n".join([body, header, *[item[0] for item in fixtures if item is not None]])
            if not REAL_SAMPLE_MARKER.search(visible):
                problems.append(f"{rid}: ref {ref!r} shows no real-sample read, so it cannot count as real-shape coverage")
    for route in sorted(expected - set(seen)):
        problems.append(f"route {route} has no response-shape row")
    return problems


def load_record(root=ROOT):
    return json.loads((Path(root) / AUDIT_REL).read_text())


def gap_rows(record):
    return [row.get("id") for row in record.get("rows", []) + record.get("response_shape_rows", [])
            if (row.get("coverage") or {}).get("kind") == "gap"]


def response_shape_sample_paths(record):
    paths = set()
    for row in record.get("response_shape_rows", []):
        for sample in (row.get("real_samples") or []) + (row.get("nearest_real_samples") or []):
            if isinstance(sample, dict) and isinstance(sample.get("path"), str):
                paths.add(sample["path"])
    return sorted(paths)


def copy_audited_tree(record, root):
    """Copy everything the checker reads into a scratch root: audited sources, test files and every real sample."""
    for rel in sorted(set(FILES + TEST_FILES + SHAPE_TEST_FILES) | set(response_shape_sample_paths(record))):
        target = Path(root) / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / rel, target)


class AuditCompletenessTests(unittest.TestCase):
    def test_the_committed_record_is_complete_and_current(self):
        problems = check(load_record(), ROOT)
        self.assertEqual(problems, [], "\n".join(problems))

    def test_the_matcher_finds_sites_in_all_five_files(self):
        # Positive control for the scan itself: an empty scan would make every completeness check vacuous.
        sites = scan(ROOT)
        for rel in FILES:
            with self.subTest(file=rel):
                self.assertGreater(len(sites[rel]), 0)
        self.assertGreaterEqual(sum(len(value) for value in sites.values()), 20)

    def test_the_audit_head_is_a_commit_of_this_checkout(self):
        head = load_record()["audit_head"]
        result = subprocess.run(["git", "-C", str(ROOT), "merge-base", "--is-ancestor", head, "HEAD"], capture_output=True)
        self.assertEqual(result.returncode, 0, f"audit_head {head} is not an ancestor of HEAD")

    def test_no_gap_rows(self):
        gaps = gap_rows(load_record())
        self.assertEqual(gaps, [], f"rows whose live side is neither tested offline nor justified: {gaps}")

    def test_every_row_records_both_behaviours_and_a_known_coverage_kind(self):
        for row in load_record()["rows"]:
            with self.subTest(row=row["id"]):
                self.assertIn(row["coverage"]["kind"], KINDS)
                self.assertTrue(row["hermetic_behavior"].strip() and row["live_behavior"].strip())


class AuditPositiveControls(unittest.TestCase):
    """Each control mutates a temporary copy and must make the checker fail for the stated reason."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="sigra-253-110-audit-")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.record = load_record()
        copy_audited_tree(self.record, self.root)
        self.assertEqual(check(self.record, self.root), [], "the unmutated copy must pass before a control means anything")

    def problems(self, record=None):
        return check(record if record is not None else self.record, self.root)

    def assert_fails_with(self, needle, record=None):
        problems = self.problems(record)
        self.assertTrue(any(needle in item for item in problems), problems)

    def test_control_a_removed_row_fails(self):
        record = copy.deepcopy(self.record)
        removed = record["rows"].pop(0)
        self.assert_fails_with(f"unaudited site {removed['file']}:", record)

    def test_control_an_added_hermetic_branch_fails(self):
        path = self.root / "scripts/ci/ci-hosted-transport.py"
        path.write_text(path.read_text() + '\n\ndef _control(allocation):\n    if allocation.get("mode") == "hermetic-test":\n'
                        '        return 1\n')
        self.assert_fails_with('unaudited site scripts/ci/ci-hosted-transport.py:')

    def test_control_a_ref_to_a_nonexistent_test_fails(self):
        record = copy.deepcopy(self.record)
        row = next(row for row in record["rows"] if row["coverage"]["kind"] == "offline-live-test")
        row["coverage"]["refs"].append("scripts/ci/ci-hosted-transport.test.py::test_253_110_does_not_exist")
        self.assert_fails_with("names no single existing test function", record)

    def test_control_a_hermetic_only_test_cited_as_live_coverage_fails(self):
        record = copy.deepcopy(self.record)
        row = next(row for row in record["rows"] if row["coverage"]["kind"] == "offline-live-test")
        row["coverage"]["refs"] = ["scripts/ci/ci-hosted-transport.test.py::"
                                   "test_hermetic_canary_allocation_routes_every_canary_route_to_its_local_origin"]
        self.assert_fails_with("shows no live marker", record)

    def test_control_a_stale_anchor_and_a_moved_line_fail(self):
        record = copy.deepcopy(self.record)
        record["rows"][0]["anchor"] += "  # changed"
        self.assert_fails_with("anchor no longer exists", record)
        record = copy.deepcopy(self.record)
        record["rows"][0]["line"] += 1
        self.assert_fails_with("anchor moved", record)

    def test_control_a_justified_row_without_residual_risk_fails(self):
        record = copy.deepcopy(self.record)
        row = record["rows"][0]
        row["coverage"] = {"kind": "justified", "refs": [], "justification": "control", "residual_risk": ""}
        self.assert_fails_with("needs a non-empty residual_risk", record)

    def test_control_a_live_policy_gate_row_without_its_summary_assertion_fails(self):
        record = copy.deepcopy(self.record)
        row = record["rows"][0]
        row["coverage"] = {"kind": "live-policy-gate",
                           "refs": ["scripts/ci/ci-gate-canary-dryrun.test.py::test_the_seeded_r8_refs_never_move"],
                           "summary_assertions": ["live_hops"]}
        self.assert_fails_with("is not asserted by any cited test", record)

    def test_control_a_gap_row_is_reported(self):
        record = copy.deepcopy(self.record)
        record["rows"][0]["coverage"] = {"kind": "gap", "refs": []}
        self.assertEqual(gap_rows(record), [record["rows"][0]["id"]])
        self.assertEqual(self.problems(record), [], "a gap row is honest and well-formed; only test_no_gap_rows rejects it")

    def test_control_a_changed_matcher_fails(self):
        record = copy.deepcopy(self.record)
        record["matcher"]["topic"] = "hermetic"
        self.assert_fails_with("matcher is not the checker's matcher", record)


class ResponseShapeCompletenessTests(unittest.TestCase):
    """253-118: the response-shape class on the committed record and the live source tree."""

    def test_every_github_transport_route_and_both_workflow_sources_have_exactly_one_row(self):
        routes = [row["route"] for row in load_record()["response_shape_rows"]]
        expected = (set(transport_routes(ROOT)) - TEST_ROUTES) | set(WORKFLOW_SOURCE_IDS)
        self.assertEqual(sorted(routes), sorted(expected))
        self.assertEqual(len(routes), len(set(routes)))
        self.assertGreaterEqual(len(routes), 29)

    def test_resolution_reads_real_bytes_and_refuses_an_absent_field(self):
        # Positive control for field resolution itself: a vacuous resolver would make every field check meaningless.
        record = load_record()
        row = next(row for row in record["response_shape_rows"] if row["route"] == "run")
        loaded = [load_sample(ROOT, sample, "run", {})[0] for sample in row["real_samples"]]
        self.assertTrue(loaded and all(item is not None for item in loaded))
        self.assertTrue(any(field_resolves("display_title", item) for item in loaded))
        self.assertTrue(any(field_resolves("value:display_title=Phase 253 Gate Canary / full-pass / 38906314106-1", item)
                            for item in loaded))
        self.assertTrue(any(field_resolves("meta:raw_observation_sha256", item) for item in loaded))
        self.assertFalse(any(field_resolves("display_titel", item) for item in loaded))
        self.assertFalse(any(field_resolves("value:display_title=Phase 253 Gate Canary", item) for item in loaded))

    def test_no_response_shape_row_is_a_gap_and_every_justified_row_states_its_risk(self):
        for row in load_record()["response_shape_rows"]:
            with self.subTest(row=row["id"]):
                coverage = row["coverage"]
                self.assertIn(coverage["kind"], ("real-shape-test", "justified"))
                if coverage["kind"] == "justified":
                    self.assertTrue(coverage["justification"].strip() and coverage["residual_risk"].strip())


class ResponseShapePositiveControls(unittest.TestCase):
    """Each control mutates a temporary copy (record or tree) and must make the checker fail for its stated reason."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="sigra-253-118-shape-")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.record = load_record()
        copy_audited_tree(self.record, self.root)
        self.assertEqual(check_response_shapes(self.record, self.root), [],
                         "the unmutated copy must pass before a control means anything")

    def row(self, record, route):
        return next(row for row in record["response_shape_rows"] if row["route"] == route)

    def assert_fails_with(self, needle, record):
        problems = check_response_shapes(record, self.root)
        self.assertTrue(any(needle in item for item in problems), problems)

    def test_control_a_removed_route_row_fails(self):
        record = copy.deepcopy(self.record)
        record["response_shape_rows"] = [row for row in record["response_shape_rows"] if row["route"] != "artifact_zip"]
        self.assert_fails_with("route artifact_zip has no response-shape row", record)

    def test_control_an_added_transport_route_without_a_row_fails(self):
        path = self.root / TRANSPORT_REL
        text = path.read_text()
        self.assertIn('    "test_probe": ("GET", "/probe", "test"),\n', text)
        path.write_text(text.replace('    "test_probe": ("GET", "/probe", "test"),\n',
                                     '    "control_route": ("GET", "/repos/{repo}/control", "json"),\n'
                                     '    "test_probe": ("GET", "/probe", "test"),\n', 1))
        self.assert_fails_with("route control_route has no response-shape row", self.record)

    def test_control_a_locator_on_another_route_fails(self):
        record = copy.deepcopy(self.record)
        sample = next(item for item in self.row(record, "run")["real_samples"] if "sequence" in item)
        sample["sequence"] = 28
        self.assert_fails_with("is route run_jobs, not run", record)

    def test_control_a_locator_with_another_status_fails(self):
        record = copy.deepcopy(self.record)
        sample = next(item for item in self.row(record, "artifact_zip")["real_samples"] if "sequence" in item)
        sample["actual_status"] = 200 if sample["actual_status"] == 302 else 302
        self.assert_fails_with("not the recorded", record)

    def test_control_a_compared_field_absent_from_its_real_samples_without_a_reason_fails(self):
        record = copy.deepcopy(self.record)
        self.row(record, "run")["fields_compared"].append("display_titel")
        self.assert_fails_with("compared field 'display_titel' resolves in no real sample", record)

    def test_control_a_justified_field_that_does_resolve_is_reported(self):
        record = copy.deepcopy(self.record)
        self.row(record, "run")["coverage"].setdefault("fields_without_real_sample", {})["display_title"] = "control"
        self.assert_fails_with("resolves in a real sample but is also listed without one", record)

    def test_control_a_ref_to_a_nonexistent_test_fails(self):
        record = copy.deepcopy(self.record)
        row = next(row for row in record["response_shape_rows"] if row["coverage"]["kind"] == "real-shape-test")
        row["coverage"]["refs"].append("scripts/ci/ci-hosted-gate-verify.test.py::test_253_118_does_not_exist")
        self.assert_fails_with("names no single existing test function", record)

    def test_control_a_hermetic_only_test_cited_as_real_shape_coverage_fails(self):
        record = copy.deepcopy(self.record)
        row = next(row for row in record["response_shape_rows"] if row["coverage"]["kind"] == "real-shape-test")
        row["coverage"]["refs"] = ["scripts/ci/ci-git-publication.test.py::"
                                   "PublicationTests.test_actual_measured_https_uploads_local_only_objects_before_create_only_ref_readback"]
        self.assert_fails_with("shows no real-sample read", record)

    def test_control_a_changed_real_sample_hash_fails(self):
        record = copy.deepcopy(self.record)
        sample = self.row(record, "run_jobs")["real_samples"][0]
        sample["sha256"] = "0" * 64
        self.assert_fails_with("not the recorded " + "0" * 64, record)

    def test_control_changed_real_sample_bytes_fail(self):
        sample = self.row(self.record, "run")["real_samples"][0]
        path = self.root / sample["path"]
        path.write_bytes(path.read_bytes() + b"\n")
        self.assert_fails_with(f"real sample {sample['path']} hashes to", self.record)

    def test_control_a_justified_row_without_residual_risk_fails(self):
        record = copy.deepcopy(self.record)
        row = next(row for row in record["response_shape_rows"] if row["coverage"]["kind"] == "justified")
        row["coverage"]["residual_risk"] = ""
        self.assert_fails_with("needs a non-empty residual_risk", record)

    def test_control_a_consumer_symbol_that_no_longer_exists_fails(self):
        record = copy.deepcopy(self.record)
        self.row(record, "run")["consumers"].append("scripts/ci/ci-hosted-gate-verify.py::verify_253_118_absent")
        self.assert_fails_with("does not occur in scripts/ci/ci-hosted-gate-verify.py", record)

    def test_control_a_response_shape_gap_row_is_reported_by_the_gap_rule(self):
        record = copy.deepcopy(self.record)
        row = self.row(record, "pr_read")
        row["coverage"] = {"kind": "gap", "refs": []}
        self.assertIn(row["id"], gap_rows(record))


if __name__ == "__main__":
    unittest.main(verbosity=2)
