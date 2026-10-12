import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from exunit_timing_contract import validate


class ExunitTimingContractTest(unittest.TestCase):
    def setUp(self):
        self.metadata = {
            "exunit_reports": [
                {"invocation": "main", "path": "ci-exunit-timing-main.json"},
                {
                    "invocation": "threadline_guard",
                    "path": "ci-exunit-timing-threadline-guard.json",
                },
            ],
            "timing_artifact_name": "library-test-timing-123-2",
        }
        self.reports = {
            "main": self.report("main"),
            "threadline_guard": self.report("threadline_guard"),
        }
        self.artifacts = {
            "main": "library-test-timing-123-2",
            "threadline_guard": "library-test-timing-123-2",
        }

    @staticmethod
    def report(invocation):
        return {
            "complete": True,
            "unit": "microsecond",
            "invocation": invocation,
            "tests": [
                {
                    "invocation": invocation,
                    "test_id": "Same.test name",
                    "duration_us": 13,
                    "result": "passed",
                }
            ],
            "test_duration_sum_us": 13,
            "passed_count": 1,
            "failed_count": 0,
            "skipped_count": 0,
            "excluded_count": 0,
        }

    def validate(self, metadata=None, reports=None, artifacts=None):
        return validate(
            metadata or self.metadata,
            reports or self.reports,
            artifacts or self.artifacts,
            "123",
            2,
        )

    def test_keeps_same_test_identity_separate_by_invocation(self):
        result = self.validate()
        self.assertTrue(result["valid"])
        self.assertEqual(
            [row["identity"] for row in result["tests"]],
            ["main:Same.test name", "threadline_guard:Same.test name"],
        )

    def test_rejects_missing_main_report(self):
        result = self.validate(reports={"threadline_guard": self.reports["threadline_guard"]})
        self.assertFalse(result["valid"])
        self.assertIn(
            "complete_exunit_main_timing_missing_or_wrong_invocation",
            result["diagnostics"],
        )

    def test_rejects_wrong_main_invocation(self):
        reports = dict(self.reports)
        reports["main"] = self.report("threadline_guard")
        result = self.validate(reports=reports)
        self.assertFalse(result["valid"])
        self.assertIn(
            "complete_exunit_main_timing_missing_or_wrong_invocation",
            result["diagnostics"],
        )

    def test_rejects_missing_child_report(self):
        result = self.validate(reports={"main": self.reports["main"]})
        self.assertFalse(result["valid"])
        self.assertIn(
            "complete_exunit_threadline_guard_timing_missing_or_wrong_invocation",
            result["diagnostics"],
        )


if __name__ == "__main__":
    unittest.main()
