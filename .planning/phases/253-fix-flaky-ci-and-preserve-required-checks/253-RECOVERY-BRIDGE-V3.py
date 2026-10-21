#!/usr/bin/env python3
"""Read-only Plan 168/172 correction consumer; never executes acceptance or CI.

V2 remains immutable. Only its reads of Plan168/172 are projected back to the
preserved V2 bytes, AFTER checking both exact corrected current files. All
other V2 checks read the real checkout, including the original180 record.
No global monkeypatching, new summaries, synthetic execution or SDK replay.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import subprocess
import types

PHASE = '.planning/phases/253-fix-flaky-ci-and-preserve-required-checks'
PLAN = PHASE + '/253-168-PLAN.md'
PLAN_172 = PHASE + '/253-172-PLAN.md'
BASE = 'e87b56fe32466749aedaf1ac8b47735a54cbf030'
V2_SHA256 = '093fabeb53a2bb35150ec645eed5b928647640cb1a600597713ff06841330b14'
PATCHES = [['clean post-253-174 tree', 'clean post-253-179/180 tree'], ['and re-pointed through 253-174, which owns new acceptance for halted 253-167 Task 3.', 'and continued through completed 253-179 local acceptance and the completed 253-180 local bridge. Plans 253-167, 253-173 and 253-174 remain halted.'], ['174 continuation: 167 and 173 remain halted; require completed 174 and execute its exact Task 2 receipt verifier before each existing automated block. The canonical receipt is 253-179-RECOVERY-RECEIPT.json, schema sigra.phase253.git-permission-recovery/v1;', '179/180 continuation: the 253-174 SUMMARY remains halted, as do 167 and 173; the 253-179 SUMMARY is complete and the 253-180 SUMMARY is complete for their local work only. Execute the V3 read-only receipt consumer before each existing automated block. The canonical receipt is 253-179-RECOVERY-RECEIPT.json, schema sigra.phase253.successor-acceptance/v1;'], ["The explicit SIGRA_253_174_RECEIPT_CONSUMER=168 mode reopens the producing commit's shared-file bytes against the receipt, permitting later committed root-owned planning updates without restoring them; every other receipt check and current clean-tree requirement remains mandatory.", "The explicit V3 verify-receipt --consumer 168 command checks this exact prerequisite correction, then reopens the original Plan 168 and Plan 172 bytes solely for the unchanged V2 historical bridge checks, after checking both exact current corrections. Every other file is read from the current checkout. It verifies Plan 179's source shared-file bytes without restoring them and preserves all receipt checks and the current clean-tree requirement. Plan 180's original record, checks and summary remain historical records, not proof that these corrected instructions were executed."], ["253-174 amendment: require completed 174's permission preflight/log/recovery receipt plus the unchanged 173 review before freezing; 167 stays halted.", "253-179 prerequisite: require completed 179's permission preflight/log/recovery receipt plus the unchanged 173 review and completed 180 local bridge before freezing; 167, 173 and 174 stay halted."], ['Execution-input prerequisite (253-174 recovery): root first commits the exact current .planning/config.json and .planning/recovery/opengsd-codex-switch-20261020T153653Z/record.json bytes after matching .planning/recovery/phase253-gap-planning-20261020/capture.json and recovery-copy commit 631e146dd79cbd2d2d6c92b7dac6db60db1a1347. Both inputs must be tracked and clean;', 'Execution-input prerequisite (completed 253-179 recovery): the previously committed .planning/config.json and .planning/recovery/opengsd-codex-switch-20261020T153653Z/record.json inputs remain tracked and clean. The V3 consumer verifies the original 179 source and current protected files; do not recommit or restore the old capture, rerun 179, or relaunch its acceptance. Both inputs must be tracked and clean;'], ['the 253-174 SUMMARY is complete with its hash-bound new recovery receipt, reviewed correction, scoped paged pass and within-cap projection;', 'the 253-174 SUMMARY remains halted and byte-identical; the 253-179 SUMMARY is complete with its hash-bound successor receipt, reviewed correction, scoped paged pass and within-cap projection; the 253-180 SUMMARY is complete for the local bridge only; the V3 receipt consumer passes before any task action;'], ['253-RECOVERY-BRIDGE-V2.py', '253-RECOVERY-BRIDGE-V3.py']]

def digest(data):
    return hashlib.sha256(data).hexdigest()

def git(root, *args):
    return subprocess.check_output(['git', '-C', str(root), *args])

def corrected_plan(original):
    text = original.decode('utf-8')
    for before, after in PATCHES:
        count = 2 if before == '253-RECOVERY-BRIDGE-V2.py' else 1
        if text.count(before) != count:
            raise ValueError('ambiguous original correction anchor: ' + before)
        text = text.replace(before, after)
    return text.encode('utf-8')

def corrected_plan172(original):
    before = 'python3 ' + PHASE + '/253-RECOVERY-BRIDGE-V2.py verify-receipt --consumer 168 &&'
    after = 'python3 -B ' + PHASE + '/253-RECOVERY-BRIDGE-V3.py verify-receipt --consumer 168 || exit $?;'
    text = original.decode('utf-8')
    if text.count(before) != 1:
        raise ValueError('ambiguous Plan172 receipt prefix')
    return text.replace(before, after, 1).encode('utf-8')

def validate_current(root):
    root = root.resolve()
    if subprocess.run(['git', '-C', str(root), 'merge-base', '--is-ancestor', BASE, 'HEAD'],
                      capture_output=True).returncode:
        raise ValueError('preserved pre-correction commit is not an ancestor')
    original = git(root, 'show', BASE + ':' + PLAN)
    if (root / PLAN).read_bytes() != corrected_plan(original):
        raise ValueError('current Plan168 differs from the exact scoped prerequisite correction')
    original172 = git(root, 'show', BASE + ':' + PLAN_172)
    if (root / PLAN_172).read_bytes() != corrected_plan172(original172):
        raise ValueError('current Plan172 differs from the exact scoped receipt correction')
    rows = git(root, 'ls-tree', '-rz', '--name-only', BASE, '--', PHASE,
               '.planning/phases/252-measure-current-ci').decode().rstrip('\0').split('\0')
    for rel in rows:
        if rel not in (PLAN, PLAN_172) and (root / rel).read_bytes() != git(root, 'show', BASE + ':' + rel):
            raise ValueError('pre-correction phase history changed: ' + rel)
    for number, status in [(174, 'halted'), (179, 'complete'), (180, 'complete')]:
        text = (root / PHASE / f'253-{number}-SUMMARY.md').read_text()
        if not re.search(r'(?m)^status: ' + status + r'$', text):
            raise ValueError('actual summary status differs: ' + str(number))
    return original, len(rows) - 2

def verify(root):
    root = root.resolve()
    original, protected = validate_current(root)
    originals = {PLAN: original, PLAN_172: git(root, 'show', BASE + ':' + PLAN_172)}
    path = root / PHASE / '253-RECOVERY-BRIDGE-V2.py'
    if digest(path.read_bytes()) != V2_SHA256:
        raise ValueError('immutable V2 consumer changed')
    spec = importlib.util.spec_from_file_location('phase253_historical_v2', path)
    v2 = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(v2)
    # Private namespace retains all original functions and defaults. Only
    # module-owned functions are rebound; imported legacy checks are untouched.
    namespace = vars(v2).copy()
    for name, value in vars(v2).items():
        if isinstance(value, types.FunctionType) and value.__globals__ is vars(v2):
            clone = types.FunctionType(value.__code__, namespace, value.__name__,
                                       value.__defaults__, value.__closure__)
            clone.__kwdefaults__ = value.__kwdefaults__
            namespace[name] = clone
    def projected_reader(reader):
        def read(at_root, rel, *args, **kwargs):
            if Path(at_root).resolve() == root and rel in originals:
                return originals[rel]
            return reader(at_root, rel, *args, **kwargs)
        return read
    namespace['read_bytes'] = projected_reader(v2.read_bytes)
    namespace['read_source_bytes'] = projected_reader(v2.read_source_bytes)
    result = namespace['verify_receipt'](root, '168')
    return {**result, 'consumer': '168-172-v3', 'protected_phase_files': protected,
            'correction_base': BASE, 'historical_plan180_unchanged': True,
            'acceptance_reruns': 0, 'github_requests': 0,
            'phase_verification_status': 'not_started'}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['verify-receipt'])
    parser.add_argument('--consumer', required=True, choices=['168'])
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2].parent
    try:
        print(json.dumps(verify(root), sort_keys=True))
    except (ValueError, RuntimeError, OSError, subprocess.CalledProcessError) as error:
        parser.exit(1, str(error) + '\n')

if __name__ == '__main__':
    main()
