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
"""
import copy
import json
import re
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PHASE_REL = ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks"
AUDIT_REL = f"{PHASE_REL}/253-LOAD-RECOVERY-HERMETIC-LIVE-AUDIT-R9.json"
SCHEMA = "sigra.phase253.hermetic-live-audit/v1"
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
    return problems


def load_record(root=ROOT):
    return json.loads((Path(root) / AUDIT_REL).read_text())


def gap_rows(record):
    return [row.get("id") for row in record.get("rows", []) if (row.get("coverage") or {}).get("kind") == "gap"]


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
        for rel in FILES + TEST_FILES:
            target = self.root / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / rel, target)
        self.record = load_record()
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


if __name__ == "__main__":
    unittest.main(verbosity=2)
