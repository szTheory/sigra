"""Recover actual order from the immutable Phase252 archive; no browser/network work."""
import hashlib,json,pathlib,re,subprocess,tarfile
ROOT=pathlib.Path(__file__).resolve().parents[3]
ARCHIVE=ROOT/'.planning/phases/252-measure-current-ci/252-CI-SOURCE-BUNDLE.tar.gz'
ARCHIVE_HASH='95334957b5b05494028ec72be5c95ee00e9ed4328e53fa78b35264c482a5af30'
RUN=38205503164
SOURCE='4ff6c50e4c6122ed8f27e67473f3b6408b3aaa97'
HELPER='test/example/priv/playwright/tests/admin-eval.spec.ts'
TARGET='Admin eval — render matrix, probes, bundles › render bundle: board-mg-9/populated'
PATTERN=re.compile(r'^(\S+)\s+([✓✘])\s+(\d+) \[([^]]+)\] › tests/admin-eval\.spec\.ts:(\d+):(\d+) › (.+?) \([^)]*\)\s*$')
def need(ok,message):
 if not ok:raise ValueError(message)
def parse_order(text):
 rows=[]
 for line_no,line in enumerate(text.splitlines(),1):
  m=PATTERN.match(line)
  if m:rows.append(dict(timestamp=m[1],outcome='passed' if m[2]=='✓' else 'failed',ordinal=int(m[3]),project=m[4],source_line=int(m[5]),title=m[7],log_line=line_no))
 need(len(rows)==192 and [r['ordinal'] for r in rows]==list(range(1,193)),'incomplete, duplicated or reordered native test rows')
 for start,project in [(0,'admin-eval'),(64,'admin-eval-mobile'),(128,'admin-eval-dark')]:need(all(r['project']==project for r in rows[start:start+64]),'project ordering differs')
 failures=[r for r in rows if r['outcome']=='failed']
 need(len(failures)==1 and failures[0]['ordinal']==161 and failures[0]['project']=='admin-eval-dark' and failures[0]['title']==TARGET,'selected historical failure identity differs')
 return rows

def extract():
 raw=ARCHIVE.read_bytes();need(hashlib.sha256(raw).hexdigest()==ARCHIVE_HASH,'archive digest mismatch')
 with tarfile.open(ARCHIVE,'r:gz') as t:
  base=f'./raw/families/{RUN}'
  log=t.extractfile(base+'/failed-job.log').read();family=json.load(t.extractfile(base+'/manifest.json'));run_raw=t.extractfile(base+'/run.json').read();run=json.loads(run_raw)
  refs=[d['result'] for d in family['artifact_diagnostics'] if d['kind']=='failed_job_log']
  need(len(refs)==1 and refs[0]['status']=='retained_redacted' and refs[0]['sha256']==hashlib.sha256(log).hexdigest(),'family log receipt mismatch')
  need(hashlib.sha256(run_raw).hexdigest()==family['source_run_sha256'],'run receipt mismatch')
  need(run['id']==RUN and run['head_sha']==SOURCE and run['run_attempt']==1,'run/source/attempt mismatch')
 text=log.decode('utf8','strict');rows=parse_order(text);lines=text.splitlines();fail=rows[160]
 need(any('Running 192 tests using 1 worker' in l for l in lines),'single worker not observed')
 node=[(i+1,l.strip().split('node: ')[-1]) for i,l in enumerate(lines) if 'node: v20.20.2' in l];need(len(node)==1,'recorded Node version missing/ambiguous')
 diagnostic=[(i+1,l) for i,l in enumerate(lines) if 'registration diagnostics={' in l and 'registrationRequest' in l and 'throw new Error' not in l]
 need(len(diagnostic)==1 and all(k+':null' in diagnostic[0][1] for k in ['"registrationRequest"','"registrationPost"','"registrationRequestFailure"']),'failure diagnostics missing or changed')
 blob=subprocess.check_output(['git','-C',str(ROOT),'rev-parse',SOURCE+':'+HELPER],text=True).strip()
 return dict(schema='sigra.phase253.recovered-registration-order/v1',archive_sha256=ARCHIVE_HASH,archive_member=base+'/failed-job.log',log_sha256=hashlib.sha256(log).hexdigest(),log_bytes=len(log),run_id=RUN,attempt=1,source_commit=SOURCE,helper_blob=blob,node_observation=dict(version=node[0][1],log_line=node[0][0]),native_rows=rows,selected_failure=fail,dark_project_prefix=rows[128:161],preceding_global_count=160,preceding_same_project_count=32,registration_post_count=text.count('POST /users/log_in'),diagnostic_log_line=diagnostic[0][0],transport_before_post='no registration request/response/failure was captured by the helper',remaining_unknown=['original database snapshot and exact account state','pageState fields after finalUrl were removed by archive redaction','cause of the registration failure; order alone does not establish it'],browser_launches=0,github_requests=0,original_ledger_modified=False)
if __name__=='__main__':print(json.dumps(extract(),indent=2))
