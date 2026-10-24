"""Extract the five existing PR selections, without executing their test bodies."""
import hashlib
import json
from pathlib import Path
import shlex

SEAMS = ['admin_behavior', 'admin_checkpoints', 'design_gallery', 'non_admin_smoke', 'demo_showcase']
ROOT = Path(__file__).resolve().parents[3]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def selections(workflow):
    import re
    result = {}
    for seam in SEAMS:
        block = re.search(r'^      - name: .*\n        id: ' + seam + r'\n(?P<body>.*?)(?=^      - name:)', workflow, re.M | re.S)
        assert block, 'missing workflow step: ' + seam
        body = block['body']
        assert 'working-directory: test/example/priv/playwright' in body
        run = body.split('        run: |\n', 1)[1].replace('\\\n', ' ')
        commands = [shlex.split(line.strip()) for line in run.splitlines() if 'npx playwright test' in line]
        assert len(commands) == 2, 'selection/execution pair missing: ' + seam
        collect = commands[0]
        assert collect[:3] == ['npx', 'playwright', 'test'] and '--list' in collect
        args = collect[3:collect.index('--list')]
        assert collect[collect.index('--list'):] == ['--list', '--reporter=json', '>', 'playwright-report/' + {
            'admin_behavior': 'admin-behavior', 'admin_checkpoints': 'admin-checkpoints',
            'design_gallery': 'design-gallery-pr-behavior', 'non_admin_smoke': 'non-admin-smoke',
            'demo_showcase': 'demo-showcase'}[seam] + '.selection.json']
        native = commands[1]
        assert native[1:4] == ['npx', 'playwright', 'test'] and native[4:] == args
        assert args.count('--retries=0') == 1
        assert not any(a.startswith(('--repeat', '--update', '--timeout', '--workers')) for a in args)
        result[seam] = args
    return result


def rows(report):
    result = []
    def walk(suite, parents):
        titles = parents + ([suite['title']] if suite.get('title') else [])
        for spec in suite.get('specs', []):
            for test in spec.get('tests', []):
                result.append(dict(file=spec['file'], line=spec['line'], title=titles + [spec['title']],
                                   project=test['projectName'], expected=test['expectedStatus'], test=test))
        for child in suite.get('suites', []):
            walk(child, titles)
    walk(report, [])
    return result


def identities(report):
    return [{k:v for k,v in row.items() if k != 'test'} for row in rows(report)]


def check_report(report, frozen, collection=False):
    assert not report.get('errors'), 'global native error'
    assert frozen and identities(report) == frozen, 'native inventory changed/missing/duplicated'
    assert report['config']['workers'] == 1 and report['config']['fullyParallel'] is False
    for row in rows(report):
        test = row['test']
        assert row['expected'] == 'passed', 'selected expected failure/skip requires explicit review'
        outcomes = test.get('results', [])
        if collection:
            assert outcomes == [], 'list-only collection executed a body'
        else:
            assert len(outcomes) == 1, 'missing result or repeated execution'
            assert outcomes[0]['retry'] == 0 and outcomes[0]['status'] == 'passed', 'failure/retry/skip'
            assert test['status'] == 'expected', 'unexpected outcome'
    if not collection:
        stats = report['stats']
        assert stats['expected'] == len(frozen)
        assert all(stats[key] == 0 for key in ['unexpected', 'flaky', 'skipped'])


def load(path):
    return json.loads(Path(path).read_text())
