import copy
import importlib.util
import pathlib
import unittest

B = pathlib.Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('offline_check', B / 'check.py')
c = importlib.util.module_from_spec(spec)
spec.loader.exec_module(c)

class SourceScope(unittest.TestCase):
    def test_actual_old_normal_and_repaired_docs_are_rejected(self):
        import json
        old = json.loads((c.ROOT / '.planning/execution/253-proof-bundle-a6838a8f9/pr-freeze.json').read_text())
        repaired = copy.deepcopy(old)
        repaired['source']['source_sha'] = c.NEW
        with self.assertRaisesRegex(AssertionError, 'source freezes differ'):
            c.require_same_source(old, repaired)
        c.require_same_source(old, copy.deepcopy(old))

    def test_every_actual_gate_input_is_identical(self):
        before = {p: c.source_bytes(c.OLD, p) for p in c.GATE_INPUTS}
        after = {p: c.source_bytes(c.NEW, p) for p in c.GATE_INPUTS}
        c.compare_gate_inputs(before, after)
        for path in before:
            changed = dict(after, **{path: after[path] + b'\n# changed'})
            with self.subTest(path=path), self.assertRaisesRegex(AssertionError, 'gate behavior input changed'):
                c.compare_gate_inputs(before, changed)
        after.pop(next(iter(after)))
        with self.assertRaisesRegex(AssertionError, 'inventory changed'):
            c.compare_gate_inputs(before, after)

    def test_canary_verifier_mutation_is_rejected(self):
        old = c.source_bytes(c.OLD, 'scripts/ci/ci-hosted-gate-verify.py')
        new = c.source_bytes(c.NEW, 'scripts/ci/ci-hosted-gate-verify.py')
        c.compare_verifier(old, new)
        mutated = new.replace(b'def verify_canary_matrix(evidence):', b'def verify_canary_matrix(evidence):\n    return {}', 1)
        with self.assertRaisesRegex(AssertionError, 'non-PR verifier code changed'):
            c.compare_verifier(old, mutated)

    def test_actual_publication_source_and_pack(self):
        c.main()

if __name__ == '__main__':
    unittest.main(verbosity=2)
