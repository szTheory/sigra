#!/usr/bin/env python3
"""Fixed pair-pass budgets use one contract without renewing an existing pass."""

import copy
import hashlib
import json
import os
from pathlib import Path
import tempfile
import unittest

import ci_metrics_security as security


class ComparisonPassBudget(unittest.TestCase):
    def setUp(self):
        self.previous_cwd = Path.cwd()
        self.temporary = tempfile.TemporaryDirectory(prefix="sigra-pass-budget-")
        os.chdir(self.temporary.name)
        self.contract = {
            # A declaration must disable this legacy fallback completely.
            "request_budget_ledger_id": "f" * 64,
            "collection_passes": [
                {"pair_id": f"pair-{number:02d}",
                 "ledger_path": f".planning/execution/comparison/pair-{number:02d}/budget.json",
                 "ledger_id": hashlib.sha256(f"fixed pair {number}".encode()).hexdigest(),
                 "reservation_ids": [f"pair-{number:02d}-before", f"pair-{number:02d}-after"]}
                for number in (1, 2)
            ],
            "family_reservations": [
                {"pair_id": f"pair-{number:02d}", "reservation_id": f"pair-{number:02d}-{role}"}
                for number in (1, 2) for role in ("before", "after")
            ],
        }

    def tearDown(self):
        os.chdir(self.previous_cwd)
        self.temporary.cleanup()

    def ledger_path(self, index):
        return Path(self.contract["collection_passes"][index]["ledger_path"])

    def test_two_declared_ids_keep_the_same_global_contract_hash(self):
        first = security.initialize_comparison_request_budget(self.contract, self.ledger_path(0), now=1000)
        second = security.initialize_comparison_request_budget(self.contract, self.ledger_path(1), now=2000)
        self.assertNotEqual(first["ledger_id"], second["ledger_id"])
        self.assertEqual(first["contract_sha256"], second["contract_sha256"])
        self.assertEqual(first["contract_sha256"], security.comparison_contract_sha256(self.contract))
        self.assertNotEqual(first["ledger_id"], self.contract["request_budget_ledger_id"])

    def test_undeclared_path_and_invalid_or_duplicate_declarations_fail(self):
        for path in (Path("new-budget.json"), Path(".planning/execution/comparison/pair-03/budget.json")):
            with self.assertRaisesRegex(ValueError, "path_undeclared"):
                security.initialize_comparison_request_budget(self.contract, path)
            self.assertFalse(path.exists())
        for field in ("ledger_path", "ledger_id", "pair_id", "reservation_ids"):
            contract = copy.deepcopy(self.contract)
            contract["collection_passes"][1][field] = contract["collection_passes"][0][field]
            with self.subTest(field=field), self.assertRaises(ValueError):
                security.initialize_comparison_request_budget(contract, self.ledger_path(0))
        for declaration in ([], None):
            with self.assertRaisesRegex(ValueError, "collection_passes_invalid"):
                security.initialize_comparison_request_budget({**self.contract, "collection_passes": declaration}, Path("legacy.json"))

    def test_absolute_escaping_and_symlink_declarations_fail(self):
        for path in ("/tmp/outside-budget.json", "../outside-budget.json", "a/../budget.json"):
            contract = copy.deepcopy(self.contract)
            contract["collection_passes"][0]["ledger_path"] = path
            with self.subTest(path=path), self.assertRaisesRegex(ValueError, "collection_pass"):
                security.initialize_comparison_request_budget(contract, self.ledger_path(0))
        outside = Path(self.temporary.name).parent
        Path("linked").symlink_to(outside, target_is_directory=True)
        contract = copy.deepcopy(self.contract)
        contract["collection_passes"][0]["ledger_path"] = "linked/budget.json"
        with self.assertRaisesRegex(ValueError, "pass_path_invalid"):
            security.initialize_comparison_request_budget(contract, Path("linked/budget.json"))

    def test_only_the_declared_pair_reservations_are_authorized(self):
        path = self.ledger_path(0)
        for role in ("before", "after"):
            security.validate_comparison_pass_reservation(self.contract, path, f"pair-01-{role}")
        for reservation in ("pair-02-before", "unknown", ""):
            with self.assertRaisesRegex(ValueError, "reservation_mismatch"):
                security.validate_comparison_pass_reservation(self.contract, path, reservation)
        contract = copy.deepcopy(self.contract)
        contract["collection_passes"][0]["reservation_ids"][0] = "pair-02-before"
        with self.assertRaisesRegex(ValueError, "reservations_invalid"):
            security.initialize_comparison_request_budget(contract, path)

    def test_reinitializing_closed_or_expired_pass_does_not_reset_it(self):
        path = self.ledger_path(0)
        security.initialize_comparison_request_budget(self.contract, path, now=1000)
        security.comparison_request_budget_reserve(self.contract, path, "rate_limit", owner="fixture", now=1010)
        security.comparison_request_budget_record_response(self.contract, path, stop_reason="pass_complete")
        original = path.read_bytes()
        retained = security.initialize_comparison_request_budget(self.contract, path, now=9000)
        self.assertEqual(retained["started_at_epoch"], 1000)
        with self.assertRaisesRegex(ValueError, "hard_stop"):
            security.comparison_request_budget_reserve(self.contract, path, "rate_limit", owner="fixture", now=1020)
        with self.assertRaisesRegex(ValueError, "ledger_closed"):
            security.comparison_request_budget_record_response(self.contract, path)
        self.assertEqual(path.read_bytes(), original)

    def test_hash_chain_global_contract_and_wrong_pass_copies_are_rejected(self):
        first, second = self.ledger_path(0), self.ledger_path(1)
        security.initialize_comparison_request_budget(self.contract, first, now=1000)
        security.comparison_request_budget_reserve(self.contract, first, "rate_limit", owner="fixture", now=1010)
        original = first.read_bytes()
        changed = json.loads(original)
        changed["records"][0]["endpoint"] = "tampered"
        first.write_text(json.dumps(changed))
        with self.assertRaisesRegex(ValueError, "chain_invalid"):
            security.initialize_comparison_request_budget(self.contract, first)
        first.write_bytes(original)
        changed_contract = {**self.contract, "extra_unfrozen_field": True}
        with self.assertRaisesRegex(ValueError, "contract_mismatch"):
            security.initialize_comparison_request_budget(changed_contract, first)
        second.parent.mkdir(parents=True)
        second.write_bytes(original)
        with self.assertRaisesRegex(ValueError, "contract_mismatch"):
            security.initialize_comparison_request_budget(self.contract, second)

    def test_each_pass_clock_starts_only_when_it_is_initialized(self):
        first, second = self.ledger_path(0), self.ledger_path(1)
        security.initialize_comparison_request_budget(self.contract, first, now=1000)
        self.assertFalse(second.exists())
        security.initialize_comparison_request_budget(self.contract, second, now=5000)
        with self.assertRaisesRegex(ValueError, "time_limit_exhausted"):
            security.comparison_request_budget_reserve(self.contract, first, "rate_limit", owner="fixture", now=5010)
        self.assertEqual(security.comparison_request_budget_reserve(
            self.contract, second, "rate_limit", owner="fixture", now=5010)["request_count"], 1)

    def test_legacy_single_ledger_contract_is_unchanged(self):
        contract = {"request_budget_ledger_id": "a" * 64}
        path = Path("legacy/budget.json")
        ledger = security.initialize_comparison_request_budget(contract, path, now=1000)
        self.assertEqual(ledger["ledger_id"], "a" * 64)
        security.validate_comparison_pass_reservation(contract, path, "old-preparation-reservation")
        self.assertEqual(security.comparison_request_budget_reserve(
            contract, path, "rate_limit", owner="fixture", now=1010)["request_count"], 1)


if __name__ == "__main__":
    unittest.main()
