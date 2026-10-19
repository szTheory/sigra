#!/usr/bin/env python3
"""253-110: the hermetic-vs-live branch audit, kept complete and current automatically. No network.

253-104 halted on a branch whose live side no offline gate had executed: every harness ran hermetic-test allocations,
so request_one's live origin check first ran in a hosted window. This checker re-scans the hosted-proof files (five,
plus the 253-126 shape-probe driver since schema r11) with a stated matcher and fails when

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

253-129 adds the observed-route rule (test_probe_observed_routes_are_not_justified): for every committed ledger whose name
ends -R11-PROBE.json (the 253-127 read-only probe), every route with a 2xx or 3xx row there must have a response-shape
row that is real-shape-test and cites at least one of that ledger's rows for the route; fields the probe did not observe
may stay in fields_without_real_sample with a reason. Its positive controls revert shape-run_logs to justified, remove
its probe sample, point a probe locator at the wrong sequence, and delete the probe ledgers (a vacuous rule is reported).

253-140 adds three rules (blind spot #4: the R11 audit listed pr_create as justified with no real sample and had no
mergeable field anywhere, while GitHub withheld the PR run because the PR conflicted):

- fields_backed (check_fields_backed): every fields_compared entry of every response-shape row resolves at its dotted path
  (meta: against the ledger transaction, header: against its scrubbed headers) in at least one decoded real sample, or is
  a key of coverage.fields_without_real_sample with a non-empty reason, and then coverage.residual_risk is non-empty. A
  fabricated locator (path, sha256, sequence, route or status not matching a committed transaction) loads nothing, so
  it backs no field and is itself a problem.
- window observed routes (check_window_observed_routes): every route with a 2xx or 3xx transaction in a committed R11
  window ledger (CANARY-HTTP-LEDGER-R11, PR-HTTP-LEDGER-R11) has a real-shape-test row that cites at least one of that
  ledger's 2xx/3xx rows for the route, exactly as 253-129's probe rule does for the -R11-PROBE ledger.
- consumed PR keys (PR_BODY_KEYS): every key ci-pr-proof.sh or ci-hosted-gate-verify.py reads from a pr_create or pr_read
  body is in that route's fields_compared. PRBodyKeysTrackTheCodeTests scans the code's PR-body read sites so the list
  cannot fall behind the code, and greps every listed key in the code so it cannot run ahead of it either.

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
AUDIT_REL = f"{PHASE_REL}/253-LOAD-RECOVERY-HERMETIC-LIVE-AUDIT-R12.json"
SCHEMA = "sigra.phase253.hermetic-live-audit/r12"
FILES = ("scripts/ci/ci-hosted-transport.py", "scripts/ci/ci-gate-canary.sh", "scripts/ci/ci-pr-proof.sh",
         "scripts/ci/ci-git-publication.py", "scripts/ci/ci-hosted-gate-verify.py", "scripts/ci/ci-shape-probe.py")
KINDS = ("offline-live-test", "live-policy-gate", "justified", "gap")
TEST_FILES = ("scripts/ci/ci-hosted-transport.test.py", "scripts/ci/ci-hosted-gate-verify.test.py",
              "scripts/ci/ci-git-publication.test.py", "scripts/ci/ci-gate-canary-flow.test.py",
              "scripts/ci/ci-gate-canary-recovery.test.py", "scripts/ci/ci-gate-canary-dryrun.test.py",
              "scripts/ci/ci-pr-proof.test.sh", "scripts/ci/ci-shape-probe.test.py")
LIVE_POLICY_GATE_FILES = ("scripts/ci/ci-gate-canary-dryrun.test.py", "scripts/ci/ci-pr-proof.test.sh",
                          "scripts/ci/ci-shape-probe.test.py")

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
                    "scripts/ci/ci-git-publication.test.py", "scripts/ci/ci-pr-proof.test.sh",
                    # 253-129: the transport's run_logs chain tests read the R10 ledger and the R11 probe ledger, and this
                    # checker's own ProbeObservedRouteTests compare the transport's typed job_logs route with the probe row.
                    "scripts/ci/ci-hosted-transport.test.py", "scripts/ci/ci-hermetic-live-audit.test.py")
# A test cited as real-shape coverage must visibly read committed real bytes, in its body or its class's setUp or
# setUpClass: a committed ledger, evidence, workflow or bundle constant, the 253-117 real-shape builders, or the dry-run's
# response_shape gate (which compares every served response with the committed R9 ledger). Like LIVE_MARKER it is a
# floor: each row states what its tests compare.
REAL_SAMPLE_MARKER = re.compile(r"EVIDENCE_R9|REAL_LEDGER_R9|\bLEDGER_R[789]\b|\bR[789]_LEDGER\b|LEDGER-R[789]|FIRST_CANARY_RUN|"
                                r"38347679431|\breal_(?:bodies|run|job|steps|artifact)\(|verifier_run_receipt\(|ledger_body\(|bundle_member\(|"
                                r"response_shape|REGISTERED_FIXTURE|CANARY-WORKFLOW|CI_YML|PUBLICATION_RECEIPT_R9|REAL_RECEIPT|"
                                # 253-129: the committed R10 ledger and the 253-127 read-only probe records (-R11-PROBE).
                                r"\bR10_LEDGER\b|PROBE_(?:LEDGER|EVIDENCE|BODIES)|probe_run_logs_chain\(|self\.seq47\(|"
                                # 253-140: the committed R11 window ledgers (253-133 canary, 253-134 PR), read at test time.
                                r"\bR11_(?:PR|CANARY)_LEDGER\b|\bREAL_CREATE_KEYS\b|\bR11_EMPTY_DISCOVERY_BODY\b|"
                                r"window_ledger_tx\(")
# 253-140: every GitHub response key the collector or the verifier reads from a PR body (dotted, as fields_compared spells
# it). pr_create is the 253-134 create response (check_pr, the step-0 base binding, the PR number); pr_read is the
# post-run read (check_pr, merge_commit_sha, base.sha) and the 253-139 failure-path diagnostic read (mergeable,
# mergeable_state). mergeable and mergeable_state are listed for pr_create too: GitHub returns them there (null and
# "unknown" in 253-134) and the PR fake models them from those real bytes.
PR_BODY_KEYS = {
    "pr_create": ["number", "state", "draft", "merged", "head.ref", "head.sha", "head.repo.full_name", "base.ref", "base.sha",
                  "base.repo.full_name", "mergeable", "mergeable_state"],
    "pr_read": ["number", "state", "draft", "merged", "head.ref", "head.sha", "head.repo.full_name", "base.ref", "base.sha",
                "base.repo.full_name", "merge_commit_sha", "mergeable", "mergeable_state"],
}
PR_KEY_SOURCES = ("scripts/ci/ci-pr-proof.sh", "scripts/ci/ci-hosted-gate-verify.py")
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
        problems += check_fields_backed(rid, fields, coverage, loaded)
        for key in PR_BODY_KEYS.get(route, ()):
            if key not in fields:
                problems.append(f"{rid}: the code reads {key!r} from the {route} body but fields_compared does not list it "
                                "(PR_BODY_KEYS)")
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
        if kind == "justified" and not str(coverage.get("residual_risk", "")).strip():
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
    return problems + check_probe_observed_routes(record, root) + check_window_observed_routes(record, root)


def check_fields_backed(rid, fields, coverage, loaded):
    """253-140 fields_backed: each compared field resolves in a loaded (hash-, route-, sequence- and status-checked) real
    sample, or carries a per-field reason, and any reasoned field needs the row's residual_risk."""
    problems = []
    without = coverage.get("fields_without_real_sample") or {}
    if not isinstance(without, dict):
        without = {}
    for field in fields:
        resolved = any(field_resolves(field, sample) for sample in loaded)
        if resolved and field in without:
            problems.append(f"{rid}: field {field!r} resolves in a real sample but is also listed without one")
        if not resolved and not str(without.get(field, "")).strip():
            problems.append(f"{rid}: compared field {field!r} resolves in no real sample and has no reason in "
                            "fields_without_real_sample (fields_backed)")
    for field in without:
        if field not in fields:
            problems.append(f"{rid}: fields_without_real_sample names {field!r}, which is not a compared field")
    if without and not str(coverage.get("residual_risk", "")).strip():
        problems.append(f"{rid}: a row with a justified field or a justified row needs a non-empty residual_risk")
    return problems


# 253-129: a route a committed read-only probe ledger (name ending -R11-PROBE.json) saw answer 2xx or 3xx is observed
# live, so its response-shape row may no longer be justified: it must be real-shape-test and cite at least one of that
# ledger's rows for the route. Fields the probe did not observe may still sit in fields_without_real_sample with a reason.
PROBE_LEDGER_GLOB = "*-R11-PROBE.json"
PROBE_LEDGER_R11_REL = f"{PHASE_REL}/253-LOAD-RECOVERY-PROBE-HTTP-LEDGER-R11-PROBE.json"
PROBE_ALLOCATION_R11_REL = f"{PHASE_REL}/253-LOAD-RECOVERY-PROBE-ALLOCATION-R11-PROBE.json"


def probe_ledger_paths(root):
    """Every -R11-PROBE record in the phase directory at root (relative paths, sorted)."""
    return sorted(f"{PHASE_REL}/{path.name}" for path in (Path(root) / PHASE_REL).glob(PROBE_LEDGER_GLOB) if path.is_file())


def observed_probe_routes(root):
    """{ledger rel: {route: {sequence, ...}}} for every 2xx/3xx transaction of every -R11-PROBE ledger at root. A probe
    record without a transactions list (allocation, approval, bodies, evidence, requests) is not a ledger."""
    observed = {}
    for rel in probe_ledger_paths(root):
        try:
            document = json.loads((Path(root) / rel).read_bytes())
        except (UnicodeError, ValueError):
            continue
        transactions = document.get("transactions") if isinstance(document, dict) else None
        if not isinstance(transactions, list):
            continue
        routes = observed.setdefault(rel, {})
        for tx in transactions:
            status = tx.get("actual_status") if isinstance(tx, dict) else None
            if type(status) is int and 200 <= status < 400 and isinstance(tx.get("route_id"), str):
                routes.setdefault(tx["route_id"], set()).add(tx.get("sequence"))
    return observed


def check_probe_observed_routes(record, root):
    """Every probe-observed route whose row is not real-shape-test on at least one row of that probe ledger."""
    observed = observed_probe_routes(root)
    if not any(observed.values()):
        return [f"no committed {PROBE_LEDGER_GLOB} ledger with a 2xx/3xx row was found, so the observed-route rule "
                "would be vacuous"]
    rows = {row.get("route"): row for row in record.get("response_shape_rows") or [] if isinstance(row, dict)}
    problems = []
    for rel, routes in sorted(observed.items()):
        for route, sequences in sorted(routes.items()):
            row = rows.get(route)
            if row is None:
                problems.append(f"route {route} was observed live in {rel} (sequence {sorted(sequences)}) and has no "
                                "response-shape row")
                continue
            rid = row.get("id")
            kind = (row.get("coverage") or {}).get("kind")
            if kind != "real-shape-test":
                problems.append(f"{rid}: route {route} was observed live in {rel} (sequence {sorted(sequences)}), so its "
                                f"coverage must be real-shape-test, not {kind}")
            cited = [sample for sample in row.get("real_samples") or [] if isinstance(sample, dict) and sample.get("path") == rel]
            for sample in cited:
                if sample.get("sequence") not in sequences:
                    problems.append(f"{rid}: real sample {rel} sequence {sample.get('sequence')!r} is not a 2xx/3xx {route} "
                                    f"row of that probe ledger (its rows are {sorted(sequences)})")
            if not any(sample.get("sequence") in sequences for sample in cited):
                problems.append(f"{rid}: route {route} was observed live in {rel} but the row cites none of its rows "
                                f"{sorted(sequences)}")
    return problems


# 253-140: the committed R11 hosted-window ledgers. 253-133's canary window and 253-134's PR window answered real GitHub
# requests the fakes had only modelled; every route either saw answer 2xx/3xx must rest on that window's own bytes.
CANARY_LEDGER_R11_REL = f"{PHASE_REL}/253-LOAD-RECOVERY-CANARY-HTTP-LEDGER-R11.json"
PR_LEDGER_R11_REL = f"{PHASE_REL}/253-LOAD-RECOVERY-PR-HTTP-LEDGER-R11.json"
WINDOW_LEDGERS_R11 = (CANARY_LEDGER_R11_REL, PR_LEDGER_R11_REL)


def observed_window_routes(root):
    """{ledger rel: {route: {sequence, ...}}} for every 2xx/3xx transaction of each committed R11 window ledger at root."""
    observed = {}
    for rel in WINDOW_LEDGERS_R11:
        path = Path(root) / rel
        if not path.is_file():
            continue
        try:
            document = json.loads(path.read_bytes())
        except (UnicodeError, ValueError):
            continue
        transactions = document.get("transactions") if isinstance(document, dict) else None
        if not isinstance(transactions, list):
            continue
        routes = observed.setdefault(rel, {})
        for tx in transactions:
            status = tx.get("actual_status") if isinstance(tx, dict) else None
            if type(status) is int and 200 <= status < 400 and isinstance(tx.get("route_id"), str):
                routes.setdefault(tx["route_id"], set()).add(tx.get("sequence"))
    return observed


def check_window_observed_routes(record, root):
    """Every route a committed R11 window ledger saw answer 2xx/3xx whose row is not real-shape-test on one of its rows."""
    observed = observed_window_routes(root)
    missing = [rel for rel in WINDOW_LEDGERS_R11 if not observed.get(rel)]
    if missing:
        return [f"the committed R11 window ledger(s) {missing} hold no 2xx/3xx row or are absent, so the window "
                "observed-route rule would be vacuous"]
    rows = {row.get("route"): row for row in record.get("response_shape_rows") or [] if isinstance(row, dict)}
    problems = []
    for rel, routes in sorted(observed.items()):
        for route, sequences in sorted(routes.items()):
            row = rows.get(route)
            if row is None:
                problems.append(f"route {route} was observed live in {rel} (sequence {sorted(sequences)}) and has no "
                                "response-shape row")
                continue
            rid = row.get("id")
            kind = (row.get("coverage") or {}).get("kind")
            if kind != "real-shape-test":
                problems.append(f"{rid}: route {route} was observed live in window ledger {rel} (sequence "
                                f"{sorted(sequences)}), so its coverage must be real-shape-test, not {kind}")
            cited = [sample for sample in row.get("real_samples") or [] if isinstance(sample, dict) and sample.get("path") == rel]
            for sample in cited:
                if sample.get("sequence") not in sequences:
                    problems.append(f"{rid}: real sample {rel} sequence {sample.get('sequence')!r} is not a 2xx/3xx {route} "
                                    f"row of that window ledger (its rows are {sorted(sequences)})")
            if not any(sample.get("sequence") in sequences for sample in cited):
                problems.append(f"{rid}: route {route} was observed live in window ledger {rel} but the row cites none of "
                                f"its rows {sorted(sequences)}")
    return problems


def window_ledger_tx(rel, sequence, root=ROOT):
    """(transaction, decoded body bytes) for one sequence of a committed R11 window ledger."""
    rows = [tx for tx in json.loads((Path(root) / rel).read_bytes())["transactions"] if tx["sequence"] == sequence]
    if len(rows) != 1:
        raise AssertionError(f"{rel} has {len(rows)} transactions with sequence {sequence}")
    return rows[0], base64.b64decode(rows[0].get("response_body_base64") or "")


# 253-140: the code's PR-body read sites. Each region is the stretch of source between a start and an end line (both
# exact stripped lines that must exist once), and roots maps a variable (or call) holding a PR body, or one of its
# sub-objects, to its dotted prefix and to the route(s) whose body it is.
PR_READ_REGIONS = (
    {"file": "scripts/ci/ci-pr-proof.sh",
     "start": '_, created = self.jcall("one", "pr_create", "pr_create", "POST", body=create_body, expect=(201,))',
     "end": 'raise Stop("the PR has no tested merge commit or base identity")',
     "roots": {"created": ("", ("pr_create",)), "pr": ("", ("pr_read",))}},
    {"file": "scripts/ci/ci-pr-proof.sh",
     "start": "def no_run_verdict(self, number):",
     "end": 'return f"no pull_request run although pull request #{number} is mergeable (mergeable_state {state})"',
     "roots": {"pr": ("", ("pr_read",))}},
    {"file": "scripts/ci/ci-hosted-gate-verify.py",
     "start": 'creates = _family(transactions, family, "pr_create")',
     "end": "merge_sha, base_sha = merges.pop(), bases.pop()",
     # check_pr reads both the created and the read PR; document is the PR read body inside this region only.
     "roots": {"created": ("", ("pr_create",)), "pr": ("", ("pr_create", "pr_read")),
               "head": ("head.", ("pr_create", "pr_read")), "base": ("base.", ("pr_create", "pr_read")),
               "document": ("", ("pr_read",))}},
    {"file": "scripts/ci/ci-hosted-gate-verify.py",
     "start": 'created_base = (tx_json(creates[0], "PR creation").get("base") or {}).get("sha")',
     "end": 'created_base = (tx_json(creates[0], "PR creation").get("base") or {}).get("sha")',
     "roots": {'tx_json(creates[0], "PR creation")': ("", ("pr_create",))}},
)
_ACCESS = r"""(?:\.get\(["']\w+["']\)|\[["']\w+["']\])"""


def pr_body_reads(text, region):
    """{route: {dotted key, ...}} the region reads from PR bodies: VAR.get("k"), VAR["k"], (VAR or {}).get("k") and
    (VAR.get("a") or {}).get("b") chains on the region's roots."""
    lines = [line.strip() for line in text.splitlines()]
    starts = [index for index, line in enumerate(lines) if line == region["start"]]
    ends = [index for index, line in enumerate(lines) if line == region["end"]]
    if len(starts) != 1 or len(ends) != 1 or ends[0] < starts[0]:
        raise AssertionError(f"PR read region in {region['file']} is not delimited exactly once: {region['start']!r} .. "
                             f"{region['end']!r} (starts {starts}, ends {ends})")
    body = "\n".join(text.splitlines()[starts[0]:ends[0] + 1])
    reads = {}
    for root, (prefix, routes) in region["roots"].items():
        chain = re.compile(rf"(?<![\w.]){re.escape(root)}(?![\w(])((?:\s+or\s+\{{\}}\))?(?:{_ACCESS}(?:\s+or\s+\{{\}}\))?)+)")
        for match in chain.finditer(body):
            keys = re.findall(r"""\.get\(["'](\w+)["']\)|\[["'](\w+)["']\]""", match.group(1))
            path = prefix + ".".join(get or item for get, item in keys)
            for route in routes:
                reads.setdefault(route, set()).add(path)
    # A sub-object read only to step into it (pr.get("head") or {}, then head.get("ref")) is not itself a compared key.
    return {route: {key for key in keys if not any(other.startswith(key + ".") for other in keys)}
            for route, keys in reads.items()}


def code_pr_body_reads(root=ROOT):
    reads = {}
    for region in PR_READ_REGIONS:
        for route, keys in pr_body_reads((Path(root) / region["file"]).read_text(), region).items():
            reads.setdefault(route, set()).update(keys)
    return reads


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
    for rel in sorted(set(FILES + TEST_FILES + SHAPE_TEST_FILES) | set(response_shape_sample_paths(record))
                      | set(probe_ledger_paths(ROOT)) | set(WINDOW_LEDGERS_R11)):
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


def load_transport(root=ROOT):
    spec = importlib.util.spec_from_file_location("audit_transport_module", Path(root) / TRANSPORT_REL)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class ProbeObservedRouteTests(unittest.TestCase):
    """253-129: every route the 253-127 read-only probe saw answer 2xx/3xx is on real samples of that probe ledger."""

    def test_probe_observed_routes_are_not_justified(self):
        # Positive control for the rule's input: the committed probe ledger is found, committed, and names the five
        # routes the probe read with 2xx/3xx, so an empty problem list below is not a vacuous pass.
        observed = observed_probe_routes(ROOT)
        self.assertEqual({rel: {route: sorted(seqs) for route, seqs in routes.items()} for rel, routes in observed.items()},
                         {PROBE_LEDGER_R11_REL: {"rate_limit": [1], "run": [2], "run_jobs": [3], "job_logs": [4],
                                                 "run_logs": [5, 6]}})
        tracked = subprocess.run(["git", "-C", str(ROOT), "ls-files", "--error-unmatch", *probe_ledger_paths(ROOT)],
                                 capture_output=True, text=True)
        self.assertEqual(tracked.returncode, 0, tracked.stderr)
        problems = check_probe_observed_routes(load_record(), ROOT)
        self.assertEqual(problems, [], "\n".join(problems))

    def test_live_probe_job_logs_hop0_matches_the_typed_download_route(self):
        # The probe's job_logs request (seq 4) is hop 0 only: GitHub answered 302, empty text/html body, Location on a
        # productionresultssa{N} blob host with a signed query. The transport types job_logs as a download route at
        # that path and its single live download-hop predicate admits the recorded host as hop 1 of job_logs (under the
        # probe's own allocation) and refuses results-receiver there. Hop 1 itself was never requested.
        rows = [row for row in json.loads((ROOT / PROBE_LEDGER_R11_REL).read_text())["transactions"] if row["sequence"] == 4]
        self.assertEqual(len(rows), 1)
        row = rows[0]
        self.assertEqual((row["route_id"], row["method"], row["host"], row["actual_status"]), ("job_logs", "GET", "api.github.com", 302))
        self.assertEqual((row["response_body_base64"], row["scrubbed_headers"]["content-length"],
                          row["scrubbed_headers"]["content-type"]), ("", "0", "text/html;charset=utf-8"))
        transport = load_transport()
        method, template, kind = transport.ROUTES["job_logs"]
        self.assertEqual((method, kind), ("GET", "download"))
        job_id = re.fullmatch(r"https://api\.github\.com/repos/szTheory/sigra/actions/jobs/([0-9]+)/logs", row["url"])
        self.assertIsNotNone(job_id, row["url"])
        self.assertEqual(template.format(repo="szTheory/sigra", job_id=job_id.group(1)), urllib_path(row["url"]))
        location = row["scrubbed_headers"]["location"]
        self.assertTrue(location["has_query"])
        self.assertIsNone(location["port"])
        self.assertRegex(location["host"], r"^productionresultssa[0-9]+\.blob\.core\.windows\.net$")
        allocation = json.loads((ROOT / PROBE_ALLOCATION_R11_REL).read_text())
        self.assertTrue(transport._trusted_download_host(location["host"], location["port"], allocation, "job_logs", 1))
        # Positive controls: the same predicate refuses results-receiver on job_logs, and a lookalike blob host.
        self.assertFalse(transport._trusted_download_host(transport.RESULTS_RECEIVER_HOST, None, allocation, "job_logs", 1))
        self.assertFalse(transport._trusted_download_host(location["host"] + ".evil", None, allocation, "job_logs", 1))


def urllib_path(url):
    from urllib.parse import urlsplit
    return urlsplit(url).path


class ProbeObservedRoutePositiveControls(unittest.TestCase):
    """Each control mutates a temporary copy of the record and must make the observed-route rule fail."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="sigra-253-129-probe-")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.record = load_record()
        copy_audited_tree(self.record, self.root)
        self.assertEqual(check_probe_observed_routes(self.record, self.root), [],
                         "the unmutated copy must pass before a control means anything")

    def run_logs(self, record):
        return next(row for row in record["response_shape_rows"] if row["route"] == "run_logs")

    def assert_fails_with(self, needle, record):
        problems = check_probe_observed_routes(record, self.root)
        self.assertTrue(any(needle in item for item in problems), problems)
        self.assertTrue(any(needle in item for item in check_response_shapes(record, self.root)))

    def test_control_shape_run_logs_reverted_to_justified_fails(self):
        record = copy.deepcopy(self.record)
        coverage = self.run_logs(record)["coverage"]
        coverage.update(kind="justified", justification="control", residual_risk="control")
        self.assert_fails_with("so its coverage must be real-shape-test, not justified", record)

    def test_control_shape_run_logs_without_its_probe_sample_fails(self):
        record = copy.deepcopy(self.record)
        row = self.run_logs(record)
        row["real_samples"] = [item for item in row["real_samples"] if item.get("path") != PROBE_LEDGER_R11_REL]
        self.assert_fails_with("but the row cites none of its rows [5, 6]", record)

    def test_control_a_probe_locator_on_the_wrong_sequence_fails(self):
        record = copy.deepcopy(self.record)
        sample = next(item for item in self.run_logs(record)["real_samples"]
                      if item.get("path") == PROBE_LEDGER_R11_REL and item.get("sequence") == 5)
        sample["sequence"] = 1
        self.assert_fails_with("sequence 1 is not a 2xx/3xx run_logs row of that probe ledger", record)

    def test_control_no_probe_ledger_is_reported_as_vacuous(self):
        for rel in probe_ledger_paths(self.root):
            (self.root / rel).unlink()
        self.assertTrue(any("would be vacuous" in item for item in check_probe_observed_routes(self.record, self.root)))


R11_PR_LEDGER = PR_LEDGER_R11_REL
R11_CANARY_LEDGER = CANARY_LEDGER_R11_REL
R11_CANDIDATE_HEAD = "2b239a98df72b8d47e8c4e03edf193905b3239da"


def _resolves(body, path):
    return any(True for _ in _leaves(body, _path_tokens(path)))


class FieldsBackedTests(unittest.TestCase):
    """253-140: the fields_backed rule and the consumed PR keys on the committed record and the real R11 window bytes."""

    def test_every_pr_row_lists_every_key_the_code_reads(self):
        rows = {row["route"]: row for row in load_record()["response_shape_rows"]}
        for route, keys in PR_BODY_KEYS.items():
            with self.subTest(route=route):
                self.assertEqual([key for key in keys if key not in rows[route]["fields_compared"]], [])
        problems = [item for item in check_response_shapes(load_record(), ROOT) if "fields_backed" in item or "PR_BODY_KEYS" in item]
        self.assertEqual(problems, [], "\n".join(problems))

    def test_real_r11_pr_create_body_carries_every_consumed_key(self):
        # 253-134 seq 5: the first real create-PR response (#337). Every key the collector and the verifier read from a
        # create body is present; mergeable null and mergeable_state "unknown" are GitHub's own values right after create.
        tx, raw = window_ledger_tx(R11_PR_LEDGER, 5)
        self.assertEqual((tx["route_id"], tx["method"], tx["host"], tx["actual_status"], tx["category"]),
                         ("pr_create", "POST", "api.github.com", 201, "pr_create"))
        body = json.loads(raw)
        for key in PR_BODY_KEYS["pr_create"]:
            with self.subTest(key=key):
                self.assertTrue(_resolves(body, key), key)
        self.assertEqual((body["state"], body["draft"], body["merged"], body["mergeable"], body["mergeable_state"]),
                         ("open", True, False, None, "unknown"))
        self.assertEqual((body["head"]["ref"], body["head"]["sha"], body["base"]["ref"]),
                         ("gsd/253-replan-r11-candidate", R11_CANDIDATE_HEAD, "main"))
        self.assertEqual({body["head"]["repo"]["full_name"], body["base"]["repo"]["full_name"]}, {"szTheory/sigra"})
        self.assertRegex(body["base"]["sha"], r"^[0-9a-f]{40}$")
        self.assertIn("merge_commit_sha", body)  # present but null at creation; the success path reads it from pr_read
        # Positive control for the resolver: an absent key does not resolve.
        self.assertFalse(_resolves(body, "mergeable_statez"))

    def test_real_r11_pull_request_discovery_bodies_are_empty(self):
        # 253-134 seq 6 and 7: both pull_request discovery reads for the published head answered an empty list.
        for sequence in (6, 7):
            with self.subTest(sequence=sequence):
                tx, raw = window_ledger_tx(R11_PR_LEDGER, sequence)
                self.assertEqual((tx["route_id"], tx["method"], tx["actual_status"], tx["category"]),
                                 ("workflow_runs", "GET", 200, "run_discovery"))
                self.assertEqual(raw, b'{"total_count":0,"workflow_runs":[]}')
                self.assertIn("event=pull_request", tx["url"])
                self.assertIn(f"head_sha={R11_CANDIDATE_HEAD}", tx["url"])
                body = json.loads(raw)
                self.assertTrue(_resolves(body, "total_count") and _resolves(body, "workflow_runs"))
                # An empty list backs no per-run field: those stay on the canary samples (positive control).
                self.assertFalse(_resolves(body, "workflow_runs[].id"))

    def test_real_r11_cancel_run_matches_the_typed_route(self):
        # 253-133 seq 73: the identified cancellation. The typed route, its {} request body and the driver's 202 check
        # match what GitHub answered.
        tx, raw = window_ledger_tx(R11_CANARY_LEDGER, 73)
        self.assertEqual((tx["route_id"], tx["method"], tx["host"], tx["actual_status"], tx["category"]),
                         ("cancel_run", "POST", "api.github.com", 202, "cancellation"))
        self.assertEqual(raw, b"{}")
        self.assertEqual(tx["scrubbed_headers"]["content-length"], "2")
        method, template, kind = load_transport().ROUTES["cancel_run"]
        self.assertEqual((method, kind), ("POST", "json"))
        run_id = re.fullmatch(r"https://api\.github\.com/repos/szTheory/sigra/actions/runs/([0-9]+)/cancel", tx["url"])
        self.assertIsNotNone(run_id, tx["url"])
        self.assertEqual(template.format(repo="szTheory/sigra", run_id=run_id.group(1)), urllib_path(tx["url"]))
        driver = (ROOT / "scripts/ci/ci-gate-canary.sh").read_text()
        self.assertIn('[[ "$LAST_REQUEST_STATUS" == 202 ]] || fail "identified canary cancellation returned HTTP', driver)


class FieldsBackedPositiveControls(unittest.TestCase):
    """Each control mutates a temporary copy and must make fields_backed or the consumed-key rule fail."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="sigra-253-140-fields-")
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

    def test_control_pr_read_without_the_mergeability_fields_fails(self):
        for key in ("mergeable", "mergeable_state", "merge_commit_sha"):
            with self.subTest(key=key):
                record = copy.deepcopy(self.record)
                row = self.row(record, "pr_read")
                row["fields_compared"].remove(key)
                row["coverage"].get("fields_without_real_sample", {}).pop(key, None)
                self.assert_fails_with(f"the code reads {key!r} from the pr_read body", record)

    def test_control_pr_create_without_mergeable_state_fails(self):
        record = copy.deepcopy(self.record)
        self.row(record, "pr_create")["fields_compared"].remove("mergeable_state")
        self.assert_fails_with("the code reads 'mergeable_state' from the pr_create body", record)

    def test_control_a_fabricated_pr_create_sample_backs_nothing(self):
        mutations = {"sha256": ("sha256", "0" * 64, "not the recorded " + "0" * 64),
                     "sequence": ("sequence", 6, "is route workflow_runs, not pr_create"),
                     "status": ("actual_status", 200, "not the recorded 200"),
                     "path": ("path", PR_LEDGER_R11_REL.replace("-R11.json", "-R11-FAKE.json"), "does not exist")}
        for label, (key, value, needle) in mutations.items():
            with self.subTest(mutation=label):
                record = copy.deepcopy(self.record)
                row = self.row(record, "pr_create")
                row["real_samples"] = [{**sample, key: value} if sample.get("path") == PR_LEDGER_R11_REL else sample
                                       for sample in row["real_samples"]]
                self.assert_fails_with(needle, record)
                self.assert_fails_with("compared field 'mergeable_state' resolves in no real sample", record)

    def test_control_an_unbacked_meta_or_header_field_fails(self):
        for field in ("meta:no_such_transaction_field", "header:x-no-such-header"):
            with self.subTest(field=field):
                record = copy.deepcopy(self.record)
                self.row(record, "pr_create")["fields_compared"].append(field)
                self.assert_fails_with(f"compared field {field!r} resolves in no real sample", record)

    def test_control_a_reasoned_field_on_a_real_shape_row_needs_a_residual_risk(self):
        record = copy.deepcopy(self.record)
        row = self.row(record, "pr_create")
        row["fields_compared"].append("auto_merge_never_seen")
        row["coverage"]["fields_without_real_sample"] = {"auto_merge_never_seen": "control"}
        row["coverage"]["residual_risk"] = ""
        self.assert_fails_with("needs a non-empty residual_risk", record)
        row["coverage"]["residual_risk"] = "control"
        self.assertEqual(check_response_shapes(record, self.root), [], "a reasoned field with a residual risk is well-formed")


class WindowObservedRouteTests(unittest.TestCase):
    """253-140: every route the 253-133 canary and 253-134 PR windows saw answer 2xx/3xx rests on that window's bytes."""

    EXPECTED = {
        CANARY_LEDGER_R11_REL: {
            "git_get_commit": [1, 6, 10], "git_create_tree": [2, 3, 4, 8], "git_create_commit": [5, 9], "git_get_blob": [7, 11],
            "get_ref": [14, 17, 23, 32], "create_ref": [13, 16], "rate_limit": [18, 26, 35, 43, 53, 63, 74, 80],
            "rules_main": [19], "check_runs": [21], "workflow": [22], "dispatch": [24, 33, 41, 51, 61, 71, 78],
            "workflow_runs": [25, 34, 42, 52, 62, 72, 79], "run": [27, 36, 44, 54, 64, 75, 81],
            "run_jobs": [28, 37, 45, 55, 65, 76, 82], "run_artifacts": [29, 38, 46, 56, 66, 77],
            "artifact_zip": [30, 31, 39, 40, 49, 50, 59, 60, 69, 70], "run_logs": [47, 48, 57, 58, 67, 68], "cancel_run": [73]},
        PR_LEDGER_R11_REL: {"rate_limit": [1], "rules_main": [2], "workflow": [4], "pr_create": [5], "workflow_runs": [6, 7]},
    }

    def test_window_observed_routes_rest_on_their_window_bytes(self):
        # Positive control for the rule's input: both committed window ledgers are found, tracked, and name these routes.
        observed = observed_window_routes(ROOT)
        self.assertEqual({rel: {route: sorted(seqs) for route, seqs in routes.items()} for rel, routes in observed.items()},
                         self.EXPECTED)
        tracked = subprocess.run(["git", "-C", str(ROOT), "ls-files", "--error-unmatch", *WINDOW_LEDGERS_R11],
                                 capture_output=True, text=True)
        self.assertEqual(tracked.returncode, 0, tracked.stderr)
        problems = check_window_observed_routes(load_record(), ROOT)
        self.assertEqual(problems, [], "\n".join(problems))

    def test_every_real_sample_is_a_committed_file(self):
        # A locator must name committed bytes, not a file left in the working tree.
        paths = response_shape_sample_paths(load_record())
        self.assertIn(PR_LEDGER_R11_REL, paths)
        tracked = subprocess.run(["git", "-C", str(ROOT), "ls-files", "--error-unmatch", *paths], capture_output=True, text=True)
        self.assertEqual(tracked.returncode, 0, tracked.stderr)
        untracked = subprocess.run(["git", "-C", str(ROOT), "ls-files", "--error-unmatch", f"{PHASE_REL}/253-140-not-committed.json"],
                                   capture_output=True, text=True)
        self.assertNotEqual(untracked.returncode, 0, "positive control: an uncommitted path is refused")


class WindowObservedRoutePositiveControls(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="sigra-253-140-window-")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.record = load_record()
        copy_audited_tree(self.record, self.root)
        self.assertEqual(check_window_observed_routes(self.record, self.root), [],
                         "the unmutated copy must pass before a control means anything")

    def row(self, record, route):
        return next(row for row in record["response_shape_rows"] if row["route"] == route)

    def assert_fails_with(self, needle, record):
        problems = check_window_observed_routes(record, self.root)
        self.assertTrue(any(needle in item for item in problems), problems)
        self.assertTrue(any(needle in item for item in check_response_shapes(record, self.root)))

    def test_control_cancel_run_reverted_to_justified_fails(self):
        record = copy.deepcopy(self.record)
        self.row(record, "cancel_run")["coverage"].update(kind="justified", justification="control", residual_risk="control")
        self.assert_fails_with("so its coverage must be real-shape-test, not justified", record)

    def test_control_pr_create_without_its_window_sample_fails(self):
        record = copy.deepcopy(self.record)
        row = self.row(record, "pr_create")
        row["real_samples"] = [item for item in row["real_samples"] if item.get("path") != PR_LEDGER_R11_REL]
        self.assert_fails_with("but the row cites none of its rows [5]", record)

    def test_control_a_window_locator_on_the_wrong_sequence_fails(self):
        record = copy.deepcopy(self.record)
        sample = next(item for item in self.row(record, "run_logs")["real_samples"] if item.get("path") == CANARY_LEDGER_R11_REL)
        sample["sequence"] = 46
        self.assert_fails_with("sequence 46 is not a 2xx/3xx run_logs row of that window ledger", record)

    def test_control_no_window_ledger_is_reported_as_vacuous(self):
        (self.root / PR_LEDGER_R11_REL).unlink()
        self.assertTrue(any("would be vacuous" in item for item in check_window_observed_routes(self.record, self.root)))


class PRBodyKeysTrackTheCodeTests(unittest.TestCase):
    """253-140: PR_BODY_KEYS can neither fall behind the code's PR-body reads nor list a key the code never reads."""

    def test_every_listed_key_is_read_by_the_code(self):
        texts = {rel: (ROOT / rel).read_text() for rel in PR_KEY_SOURCES}

        def quoted(leaf):
            return [rel for rel, text in texts.items() if f'"{leaf}"' in text or f"'{leaf}'" in text]

        # Positive control: the grep finds the 253-139 diagnostic key in the collector; negative: a near miss is absent.
        self.assertIn("scripts/ci/ci-pr-proof.sh", quoted("mergeable_state"))
        self.assertEqual(quoted("mergeable_statez"), [])
        for route, keys in PR_BODY_KEYS.items():
            for key in keys:
                with self.subTest(route=route, key=key):
                    self.assertTrue(quoted(key.rpartition(".")[2]), f"{key} is listed for {route} but no source quotes it")

    def test_every_pr_body_read_in_the_code_is_listed(self):
        reads = code_pr_body_reads(ROOT)
        # Positive controls: the scan sees the reads 253-139 added and the verifier's check_pr reads.
        self.assertTrue({"mergeable", "mergeable_state", "merge_commit_sha", "base.sha", "head.repo.full_name"} <= reads["pr_read"],
                        reads)
        self.assertTrue({"number", "base.sha", "draft", "head.ref", "base.repo.full_name"} <= reads["pr_create"], reads)
        for route, keys in reads.items():
            with self.subTest(route=route):
                self.assertEqual(sorted(keys - set(PR_BODY_KEYS[route])), [], f"{route} reads unlisted PR body keys")

    def test_control_a_new_pr_body_read_in_the_collector_is_caught(self):
        with tempfile.TemporaryDirectory(prefix="sigra-253-140-keys-") as tmp:
            for rel in PR_KEY_SOURCES:
                (Path(tmp) / rel).parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(ROOT / rel, Path(tmp) / rel)
            path = Path(tmp) / "scripts/ci/ci-pr-proof.sh"
            text = path.read_text()
            anchor = 'mergeable, state = (pr or {}).get("mergeable"), (pr or {}).get("mergeable_state")'
            self.assertEqual(text.count(anchor), 1)
            path.write_text(text.replace(anchor, anchor + '\n        rebase = (pr or {}).get("rebaseable")', 1))
            reads = code_pr_body_reads(Path(tmp))
            self.assertIn("rebaseable", reads["pr_read"])
            self.assertNotIn("rebaseable", PR_BODY_KEYS["pr_read"])
            # A deleted region anchor is loud, never a silent empty scan.
            path.write_text(text.replace("def no_run_verdict(self, number):", "def no_run_verdict_renamed(self, number):", 1))
            with self.assertRaises(AssertionError):
                code_pr_body_reads(Path(tmp))


if __name__ == "__main__":
    unittest.main(verbosity=2)
