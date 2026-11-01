#!/usr/bin/env python3
"""Semantic contract for the Phase 255 comparison report and reproduction guides."""
import copy
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
REPORT = ROOT / '.planning/execution/255-replay/REPORT.json'
REPORT_MD = ROOT / '.planning/execution/255-replay/REPORT.md'
CONTRIBUTING = ROOT / 'CONTRIBUTING.md'
MAINTAINING = ROOT / 'MAINTAINING.md'
BASELINE = 'fb2d3faa4b25918d14415dd00a51545f0a9c6683'
CANDIDATE = 'ebb1d3ef0207d64f5f22f409032cf6125abab941'
ANALYSIS = 'd5b7300c809ce7cd474e87aa55fda278b3a09cbc'
REMOTE_REF = 'refs/heads/evidence/phase255-replay-6d098e9bee2d28b0d88d'
PACKAGE_SHA = '6d098e9bee2d28b0d88dda2c517503467448939b4e48af84bf6e2ffd5255fe23'


def validate_report(report):
    if report['status'] != 'insufficient_data':
        raise ValueError('comparison_status_must_remain_insufficient_data')
    sources = report['measured_sources']
    if sources['baseline']['application_sha'] != BASELINE or sources['candidate']['application_sha'] != CANDIDATE:
        raise ValueError('measured_source_identity_mismatch')
    if report['analysis_source']['commit'] != ANALYSIS:
        raise ValueError('analysis_source_mismatch')
    observations = report['observations']
    if (observations['measured_invocations'] != 2 or observations['successful_comparable_pairs'] != 0
            or observations['unspent_invocations'] != 38 or observations['replacement_samples_started'] != 0):
        raise ValueError('observation_count_mismatch')
    stats = report['statistics']
    if stats['median_seconds'] is not None or stats['p95_seconds'] is not None:
        raise ValueError('insufficient_data_statistics_must_be_null')
    if stats['baseline_runner_seconds'] != 2046 or stats['candidate_runner_seconds'] != 1589:
        raise ValueError('literal_cost_mismatch')
    if report['requirements']['CISPEED-01'] != 'open' or report['requirements']['CISPEED-02'] != 'open':
        raise ValueError('speed_requirements_must_remain_open')
    distribution = report['replay_distribution']
    if distribution['remote_ref'] != REMOTE_REF or distribution['package_sha256'] != PACKAGE_SHA:
        raise ValueError('distribution_identity_mismatch')
    if distribution['evidence_commit'] != '52d2f3611fa195042d52ab0ef9dba64e4d75a2eb':
        raise ValueError('distribution_commit_mismatch')
    if (distribution['evidence_parent'] != distribution['publisher_helper_source']
            or distribution['publisher_helper_source'] == distribution['corrected_verification_controller_source']):
        raise ValueError('publisher_and_corrected_controller_sources_must_remain_distinct')
    attempts = distribution['retrieval_attempts']
    if (len(attempts) != 2 or attempts[0]['status'] != 'failed_replay_after_exact_fetch'
            or attempts[1]['status'] != 'passed'):
        raise ValueError('distribution_retrieval_history_mismatch')
    budget = distribution['budget']
    if (budget['successful_create_only_pushes'] != 1 or budget['transient_transport_retries'] != 0
            or budget['fresh_checkout_retrieval_attempts'] != 2 or budget['workflow_dispatches'] != 0):
        raise ValueError('distribution_budget_mismatch')
    passed = [item for item in distribution['retrieval_attempts'] if item['status'] == 'passed']
    if distribution['status'] != 'verified' or len(passed) != 1:
        raise ValueError('distribution_replay_not_verified_offline')
    replay = passed[0]['offline_replay']
    if (replay['performance_verdict'] != 'insufficient_data'
            or replay['comparable_successful_pairs'] != 0
            or replay['median_seconds'] is not None or replay['p95_seconds'] is not None):
        raise ValueError('offline_replay_semantics_mismatch')


class ComparisonReportTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.report = json.loads(REPORT.read_text())
        cls.report_md = REPORT_MD.read_text()
        cls.contributing = CONTRIBUTING.read_text()
        cls.maintaining = MAINTAINING.read_text()

    def test_saved_sources_costs_and_zero_pair_result_are_literal(self):
        validate_report(self.report)

    def test_false_speed_pass_and_source_substitution_are_rejected(self):
        for change in ('speed', 'source'):
            candidate = copy.deepcopy(self.report)
            if change == 'speed':
                candidate['statistics']['median_seconds'] = 100
            else:
                candidate['measured_sources']['baseline']['application_sha'] = 'f' * 40
            with self.subTest(change=change), self.assertRaises(ValueError):
                validate_report(candidate)

    def test_acceptance_sample_inflation_is_rejected(self):
        candidate = copy.deepcopy(self.report)
        candidate['observations']['successful_comparable_pairs'] = 20
        with self.assertRaisesRegex(ValueError, 'observation_count_mismatch'):
            validate_report(candidate)

    def test_both_guides_link_the_same_report_and_real_offline_commands(self):
        for guide in (self.contributing, self.maintaining):
            self.assertIn('.planning/execution/255-replay/REPORT.md', guide)
            self.assertIn(REMOTE_REF, guide)
            self.assertIn(PACKAGE_SHA, guide)
            self.assertIn('verify-distribution --record', guide)
        self.assertIn('replay --package', self.contributing)
        self.assertIn('CONTRIBUTING.md#retrieve-the-saved-comparison-inputs', self.maintaining)

    def test_report_separates_development_diagnostics_and_missing_capture_files(self):
        limits = self.report['development_verification']
        self.assertEqual(limits['acceptance_samples_added'], 0)
        self.assertEqual(limits['run_id'], 40054033393)
        self.assertIn('final-output.log', self.report['phase255_diagnostics']['cancellation_missing_files'])
        self.assertIn('final-trace.zip', self.report['phase255_diagnostics']['cancellation_missing_files'])
        self.assertIn('unknown', self.report['limitations']['original_initiating_event'].lower())

    def test_guides_document_prerequisites_seeded_commands_and_artifact_retention(self):
        joined = self.contributing + self.maintaining + self.report_md
        for text in ('MIX_ENV=test mix ci', 'SIGRA_TEST_PG_HOSTNAME', 'PGHOST',
                     'Erlang/OTP `28.5`', 'Elixir `1.19.5-otp-28`', 'phx_new 1.8.8',
                     'npm ci', 'compare-only', '2026-10-31', 'gh run download'):
            with self.subTest(text=text):
                self.assertIn(text, joined)


if __name__ == '__main__':
    unittest.main(verbosity=2)
