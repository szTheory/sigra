"""Offline repair candidate; never performs HTTP or activates a closed attempt."""
import re

class Refusal(ValueError):
    pass

def candidates(checks, repository, head_sha):
    """Commit checks are hints only. Each hinted run still needs direct validation."""
    pattern = re.compile(r'https://github\.com/' + re.escape(repository) + r'/actions/runs/([1-9][0-9]*)/job/[1-9][0-9]*\Z')
    ids = set()
    if checks.get('total_count', 0) > len(checks.get('check_runs', [])):
        raise Refusal('check listing is incomplete; paginate within an allocated limit')
    for check in checks.get('check_runs', []):
        if check.get('head_sha') != head_sha or (check.get('app') or {}).get('id') != 15368:
            continue
        match = pattern.fullmatch(check.get('details_url') or '')
        if match:
            ids.add(int(match[1]))
    return sorted(ids)

def validate(run, *, run_id, repository_id, workflow_id, pr_number, head_sha, head_ref, base_sha, base_ref):
    """A run URL alone proves neither the PR, source, workflow nor run attempt."""
    expected = {'id':run_id, 'workflow_id':workflow_id, 'event':'pull_request',
                'head_sha':head_sha, 'head_branch':head_ref, 'run_attempt':1}
    if any(run.get(k) != v for k,v in expected.items()):
        raise Refusal('run identity differs from the frozen PR')
    if (run.get('repository') or {}).get('id') != repository_id:
        raise Refusal('run repository differs')
    matches = []
    for pr in run.get('pull_requests', []):
        if pr.get('number') != pr_number:
            continue
        for side, sha, ref in [('head',head_sha,head_ref),('base',base_sha,base_ref)]:
            value=pr.get(side) or {}
            if value.get('sha') != sha or value.get('ref') != ref or (value.get('repo') or {}).get('id') != repository_id:
                raise Refusal('run PR source or base differs')
        matches.append(pr)
    if len(matches) != 1:
        raise Refusal('run does not identify the exact PR once')
    return run_id
