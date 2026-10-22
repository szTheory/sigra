#!/usr/bin/env python3
"""Offline source-scope checks. This never accepts requirements or contacts GitHub."""
import ast
import hashlib
import json
import pathlib
import tempfile
import os
import subprocess

B = pathlib.Path(__file__).resolve().parent
ROOT = B.parents[2]
OLD = 'a6838a8f9e107a49e11ea47ef34e3171fe15eed0'
NEW = '5e13621e50e646c63e135035080d2e6e46fbc955'
GATE_INPUTS = [
    '.github/workflows/ci.yml', '.github/ci-skip-manifest.tsv',
    'scripts/ci/ci-browser-records.mjs', 'scripts/ci/ci-playwright-report.mjs',
    'scripts/ci/honest-skip-verdict.sh',
    '.planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-WORKFLOW.yml',
]

def git(*args, **kwargs):
    return subprocess.check_output(['git', '-C', str(ROOT), *args], **kwargs)

def digest(raw):
    return hashlib.sha256(raw).hexdigest()

def source_bytes(commit, path):
    return git('show', commit + ':' + path)

def compare_gate_inputs(previous, repaired):
    """Exact byte equality, including the report module imported by the recorder."""
    assert previous.keys() == repaired.keys(), 'gate input inventory changed'
    assert all(previous[p] == repaired[p] for p in previous), 'gate behavior input changed'
    return {p: digest(previous[p]) for p in previous}

def compare_verifier(previous, repaired):
    # Permit only the reviewed PR inventory repair. Every other declaration,
    # statement, constant, decorator and canary checker stays identical.
    def filtered(raw):
        tree = ast.parse(raw)
        return ast.Module(body=[node for node in tree.body if not (
            isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)) and
            node.name in {'compare_file_paths', 'verify_pr_family'})], type_ignores=[])
    assert ast.dump(filtered(previous)) == ast.dump(filtered(repaired)), 'non-PR verifier code changed'
    return dict(canary_code_unchanged=True, excluded_pr_functions=['compare_file_paths', 'verify_pr_family'])

def require_same_source(normal_freeze, docs_freeze):
    assert normal_freeze == docs_freeze, 'normal/docs source freezes differ; historical normal result cannot accept repaired docs'

def main():
    publication = json.loads((B / 'publication.json').read_text())
    objects = json.loads((B / 'objects.json').read_text())
    assert publication['source_sha'] == NEW
    assert publication['product_tree_parity']['same_paths_modes_blobs'] is True
    assert digest((B / 'objects.pack').read_bytes()) == objects['pack_sha256']
    assert objects['refs_published'] is False
    # Import the prepared pack in a disposable object store, then read back all
    # exact paths/modes/blob IDs. No object or ref in the source repo is written.
    with tempfile.TemporaryDirectory(prefix='253-pack-readback-') as temporary:
        object_dir = pathlib.Path(temporary) / 'objects'
        object_dir.mkdir()
        env = dict(os.environ, GIT_OBJECT_DIRECTORY=str(object_dir),
                   GIT_ALTERNATE_OBJECT_DIRECTORIES=str(ROOT / '.git/objects'))
        git('index-pack', '--stdin', input=(B / 'objects.pack').read_bytes(), env=env)
        def product(commit):
            return {entry for entry in git('ls-tree', '-rz', commit, env=env).split(b'\0')
                    if entry and not entry.split(b'\t', 1)[1].startswith(b'.planning/')}
        candidate, base, head = objects['commits']
        assert product(candidate) == product(NEW), 'packed candidate product differs from repaired source'
        assert git('diff', '--name-only', candidate, base, env=env).decode().splitlines() == ['.github/workflows/ci.yml']
        assert git('diff', '--name-only', base, head, env=env).decode().splitlines() == ['guides/reference/phase253-docs-only-proof.md']
        workflow = git('show', base + ':.github/workflows/ci.yml', env=env)
        assert workflow == (B / 'docs-workflow.yml').read_bytes()
        original = source_bytes(NEW, '.github/workflows/ci.yml')
        assert workflow == original.replace(b'    branches: [main]\n', b'    branches: [main, gsd/253-replan-proof-5e13621e5-docs-*]\n', 1)
    paths = git('diff', '--name-only', OLD, NEW, '--', '.', ':(exclude).planning').decode().splitlines()
    assert set(paths) == {
        'scripts/ci/ci-hosted-gate-verify.py', 'scripts/ci/ci-pr-proof.test.sh',
        'scripts/ci/admin-acceptance-smoke.sh', 'test/sigra/planning/phase_146_release_validation_test.exs',
    }, paths
    inputs = compare_gate_inputs({p: source_bytes(OLD, p) for p in GATE_INPUTS},
                                {p: source_bytes(NEW, p) for p in GATE_INPUTS})
    verifier = compare_verifier(source_bytes(OLD, 'scripts/ci/ci-hosted-gate-verify.py'),
                               source_bytes(NEW, 'scripts/ci/ci-hosted-gate-verify.py'))
    old_freeze = json.loads((ROOT / '.planning/execution/253-proof-bundle-a6838a8f9/pr-freeze.json').read_text())
    changed = dict(old_freeze, source=dict(old_freeze['source'], source_sha=NEW))
    try:
        require_same_source(old_freeze, changed)
    except AssertionError:
        stale_rejected = True
    else:
        raise AssertionError('historical PR341 was incorrectly accepted for repaired source')
    result = dict(schema='sigra.phase253.repaired-source-offline-checks/v1',
        source_sha=NEW, product_delta=paths, gate_inputs=inputs, verifier_scope=verifier,
        old_normal_with_repaired_docs_rejected=stale_rejected,
        objects_pack_verified=True, network_calls=0, ci_launches=0,
        historical_canaries_remain_proof_of_original_gate_inputs=True,
        repaired_source_hosted_acceptance=False, phase_verified=False,
        original_selected_failure_reproduced=False)
    print(json.dumps(result, indent=2))

if __name__ == '__main__':
    main()
