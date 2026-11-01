"""Read-only analysis of retained CI and Linux logs. No app/browser/network calls."""
import datetime
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import tarfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
ORDER = ROOT / '.planning/execution/253-registration-order-recovery'
LINUX = ROOT / '.planning/execution/253-registration-linux'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def flows(text):
    lines = text.splitlines()
    starts = [i for i, line in enumerate(lines) if 'HANDLE EVENT "save" in ExampleWeb.RegistrationLive' in line]
    rows = []
    for i, start in enumerate(starts):
        end = starts[i + 1] if i + 1 < len(starts) else len(lines)
        block = '\n'.join(lines[start:end])
        match = re.search(r'"email" => "(platform-admin\+ev-([^"@]+)@example.test)"', block)
        if not match:
            raise ValueError('save event lacks its generated test account')
        identity = re.fullmatch(r'([a-z0-9]+)-([a-z0-9]*)-([a-z0-9]+)-(\d+)-w([a-z0-9]+)', match[2])
        if not identity:
            raise ValueError('unknown generated account format')
        rows.append(dict(ordinal=i + 1, first_log_line=start + 1, last_log_line=end,
                         email_sha256=hashlib.sha256(match[1].encode()).hexdigest(),
                         email_generated_at_ms=int(identity[1], 36), project_suffix=identity[2],
                         project_sequence=int(identity[3], 36), retry=int(identity[4]),
                         login_posts=block.count('POST /users/log_in'),
                         user_inserts=block.count('INSERT INTO "auth"."users"'),
                         confirmation_token_inserts=block.count('INSERT INTO "auth"."user_tokens"'),
                         queryable_exception='function Ecto.Queryable.to_query/1 is undefined' in block))
    return rows


def analyze():
    # Reuse the authenticated original-run/source/order extractor; never change it.
    spec = importlib.util.spec_from_file_location('original_order', ORDER / 'extract.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    original = module.extract()
    archive = ROOT / '.planning/phases/252-measure-current-ci/252-CI-SOURCE-BUNDLE.tar.gz'
    with tarfile.open(archive) as bundle:
        raw = bundle.extractfile(original['archive_member']).read()
    if hashlib.sha256(raw).hexdigest() != original['log_sha256']:
        raise ValueError('original log identity mismatch')
    text = raw.decode()
    rows = flows(text)
    if len(rows) != 192 or sum(row['queryable_exception'] for row in rows) != 1:
        raise ValueError('original save/error count differs')
    for row in rows:
        expected = (0, 0, True) if row['ordinal'] == 161 else (1, 1, False)
        if (row['login_posts'], row['user_inserts'], row['queryable_exception']) != expected:
            raise ValueError('unexpected original registration outcome')
    failed = rows[160]
    if (failed['project_suffix'], failed['project_sequence'], failed['retry']) != ('dark', 33, 0):
        raise ValueError('crashing account does not identify selected dark test')
    previous_end = datetime.datetime.fromisoformat(original['native_rows'][159]['timestamp'].replace('Z', '+00:00')).timestamp() * 1000
    failure_end = datetime.datetime.fromisoformat(original['native_rows'][160]['timestamp'].replace('Z', '+00:00')).timestamp() * 1000
    if not previous_end < failed['email_generated_at_ms'] < failure_end:
        raise ValueError('crashing account timestamp does not fall within selected test')
    saved = json.loads((LINUX / 'RESULT.json').read_text())
    linux_log = LINUX / 'diagnostic-output/app.log'
    if sha(linux_log) != saved['raw_output_sha256']['diagnostic-output/app.log']:
        raise ValueError('Linux app log changed')
    linux = flows(linux_log.read_text())
    if len(linux) != 161 or any((r['login_posts'], r['user_inserts'], r['queryable_exception']) != (1, 1, False) for r in linux):
        raise ValueError('Linux registrations do not match successful report')
    lines = text.splitlines()
    stack_start = next(i for i, line in enumerate(lines) if '** (UndefinedFunctionError)' in line and 'Ecto.Queryable.to_query/1' in line)
    # Exclude parameters, socket state, CSRF values and the encoded password payload.
    stack = [dict(log_line=i + 1, text=lines[i].split('Z ', 1)[-1]) for i in range(stack_start, stack_start + 18)]
    if any(word in json.dumps(stack) for word in ['Parameters:', 'Last message:', 'State:', 'password']):
        raise ValueError('unsafe stack excerpt')
    probes = []
    for script, log, count in [('purge_probe.exs', 'purge-probe.log', 40000),
                               ('loaded_purge_probe.exs', 'loaded-purge-probe.log', 400000)]:
        content = (HERE / log).read_text()
        for observed in ['ecto_version=3.13.5; elixir=1.19.5; otp=28', 'control=2000_passed',
                         'concurrent_outcomes: %{ok: ' + str(count) + '}',
                         'process_exit_reasons: %{normal: 5}', 'restored_query=passed']:
            if observed not in content:
                raise ValueError('probe log does not establish its reported result: ' + log)
        probes.append(dict(script=script, script_sha256=sha(HERE / script), log=log,
                           log_sha256=sha(HERE / log), control_passes=2000,
                           concurrent_passes=count, module_error_reproduced=False,
                           local_development_only=True))
    return dict(schema='sigra.phase253.registration-offline-diagnosis/v1',
                status='original_server_failure_identified_upstream_loader_cause_unconfirmed',
                original=dict(run_id=original['run_id'], attempt=original['attempt'],
                              source=original['source_commit'], archive_sha256=original['archive_sha256'],
                              log_sha256=original['log_sha256'], native_failed_ordinal=161,
                              save_events=192, login_posts=191, successful_user_inserts=191,
                              selected_and_neighbors=rows[159:162], stack=stack,
                              selected_account_time_within_native_test=True),
                linux=dict(log_sha256=sha(linux_log), save_events=161, login_posts=161,
                           successful_user_inserts=161, queryable_exceptions=0,
                           selected_flow=linux[160], report=str(LINUX.relative_to(ROOT) / 'RESULT.json')),
                established='Registration save161 crashed in email uniqueness validation before inserting an account or triggering the login POST. The missing POST and browser timeout follow this crash.',
                unproved='Why Ecto.Queryable was unavailable at that instant; original log has no module load/delete trace.',
                reloader_hypothesis='Development reloading purges consolidated protocols; source supports this candidate but both isolated concurrency probes passed.',
                local_probes=probes,
                candidate_fix_applied=False, CIREL_01='incomplete', CIREL_02='complete_unchanged',
                phase_complete=False, browser_invocations=0, ci_launches=0, network_requests=0)


if __name__ == '__main__':
    print(json.dumps(analyze(), indent=2))
