#!/usr/bin/env python3
"""Execute the actual workflow step against advancing Git history, without HTTP."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


def workflow_body():
    job = (ROOT / '.github/workflows/ci.yml').read_text().split('\n  changes:\n', 1)[1]
    lines = job.split('        run: |\n', 1)[1].splitlines()
    body = []
    for line in lines:
        if line.strip() and not line.startswith('          '):
            break
        body.append(line[10:])
    return '\n'.join(body) + '\n'


class WorkflowHistory(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='sigra-docs-history-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.origin = self.root / 'origin'
        self.origin.mkdir()
        self.git(self.origin, 'init', '-b', 'main')
        self.git(self.origin, 'config', 'user.name', 'Fixture')
        self.git(self.origin, 'config', 'user.email', 'fixture@example.invalid')
        self.commit('README.md', 'original', 'base')
        self.git(self.origin, 'checkout', '-b', 'old-pr')
        self.commit('lib/example.ex', 'defmodule Example do end', 'product change')
        self.git(self.origin, 'checkout', 'main')
        self.commit('README.md', 'newer main', 'advance main')

    def git(self, directory, *args):
        return subprocess.run(['git', *args], cwd=directory, capture_output=True, text=True, check=True).stdout.strip()

    def commit(self, name, text, message):
        file = self.origin / name
        file.parent.mkdir(parents=True, exist_ok=True)
        file.write_text(text)
        self.git(self.origin, 'add', name)
        self.git(self.origin, 'commit', '-m', message)

    def checkout(self, name):
        clone = self.root / name
        self.git(self.root, 'clone', '--no-local', str(self.origin), str(clone))
        self.git(clone, 'checkout', 'origin/old-pr')
        (clone / 'scripts/ci').mkdir(parents=True)
        shutil.copy2(ROOT / 'scripts/ci/docs-only-classify.sh', clone / 'scripts/ci/docs-only-classify.sh')
        return clone

    def execute(self, clone, body=None, **extra):
        output = clone / 'github-output'
        result = subprocess.run(['bash', '-e', '-o', 'pipefail', '-c', body or workflow_body()], cwd=clone,
            env={**os.environ, 'EVENT_NAME':'pull_request', 'BASE_REF':'main', 'GITHUB_OUTPUT':str(output), **extra},
            capture_output=True, text=True)
        return result, output.read_text() if output.exists() else ''

    def test_old_shallow_fetch_reproduces_false_docs_only_after_main_advances(self):
        clone = self.checkout('old-runner')
        # Exact failing commands retained from baseline attempt 2's authenticated log.
        body = 'git fetch origin "${BASE_REF}" --depth=1\ngit diff --name-only "origin/${BASE_REF}...HEAD" | bash scripts/ci/docs-only-classify.sh | tee -a "$GITHUB_OUTPUT"'
        result, output = self.execute(clone, body)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('no merge base', result.stderr)
        self.assertEqual(output.strip(), 'docs_only=true')

    def test_actual_workflow_keeps_history_and_runs_product_changes(self):
        result, output = self.execute(self.checkout('current-runner'))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(output.strip(), 'docs_only=false')

    def test_diff_failure_cannot_publish_a_docs_only_skip(self):
        clone = self.checkout('shallow-runner')
        self.git(clone, 'fetch', 'origin', 'main', '--depth=1')
        result, output = self.execute(clone)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('no merge base', result.stderr)
        self.assertEqual(output.strip(), 'docs_only=false')

    def test_real_docs_only_change_still_skips_the_cost_body(self):
        self.git(self.origin, 'checkout', '-B', 'old-pr', 'main~1')
        self.commit('guides/example.md', 'documentation', 'docs change')
        result, output = self.execute(self.checkout('docs-runner'))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(output.strip(), 'docs_only=true')

    def test_fetch_failure_runs_full_workload(self):
        clone = self.checkout('offline-runner')
        self.git(clone, 'remote', 'set-url', 'origin', str(self.root / 'missing-origin'))
        result, output = self.execute(clone)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(output.strip(), 'docs_only=false')


if __name__ == '__main__':
    unittest.main()
