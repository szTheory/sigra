// A new local diagnostic, never an old acceptance slot or an acceptance receipt.
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import crypto from 'node:crypto';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const here=path.dirname(fileURLToPath(import.meta.url));
const root=path.resolve(here,'../../..');
const proposal=JSON.parse(fs.readFileSync(path.join(here,'preparation.json')));
const sha=(file)=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
function need(ok,message){if(!ok)throw Error(message);}
const continuation=process.argv.includes('--continue-approved-diagnostic');
const run=process.argv.includes('--run')||continuation;
const setupCheck=process.argv.includes('--setup-check');
need(!(run&&setupCheck),'setup check and diagnostic are separate commands');
need(process.argv.slice(2).every(x=>['--run','--approved-new-diagnostic','--setup-check','--continue-approved-diagnostic'].includes(x)),'unknown argument');
if(!run&&!setupCheck){console.log(JSON.stringify({mode:'preview',...proposal.scope},null,2));process.exit(0);}
if(run)need(process.argv.includes('--approved-new-diagnostic'),'STOP: a new explicit diagnostic approval is required; expired slots remain closed');
const checkout=proposal.checkout, pw=path.join(checkout,'test/example/priv/playwright');
need(execFileSync('git',['-C',checkout,'rev-parse','HEAD'],{encoding:'utf8'}).trim()===proposal.source_commit,'source changed');
need(!execFileSync('git',['-C',checkout,'status','--porcelain','--untracked-files=no'],{encoding:'utf8'}).trim(),'tracked source is dirty');
for(const [rel,digest] of Object.entries(proposal.lock_sha256))need(sha(path.join(checkout,rel))===digest,'lock changed: '+rel);
need(sha(path.join(here,'replay.mjs'))===proposal.replay_sha256,'diagnostic runner changed');
need(sha(proposal.node)===proposal.node_binary_sha256,'Node binary changed');
need(sha(path.join(root,'scripts/ci/ci-registration-recovery.mjs'))===proposal.runner_library_sha256,'process runner changed');
need(execFileSync(proposal.node,['--version'],{encoding:'utf8'}).trim()==='v20.20.2','Node version changed');
const {runLoggedTree,diagnosticEnvironment,portAvailable,holdHostAwake}=await import(path.join(root,'scripts/ci/ci-registration-recovery.mjs'));
for(const port of [39453,58624])need(await portAvailable(port),'port already occupied: '+port);
if(run&&!continuation)fs.writeFileSync(path.join(here,'diagnostic-reservation.json'),JSON.stringify({started_at:new Date().toISOString(),scope:proposal.scope})+'\n',{flag:'wx'});
const out=fs.mkdtempSync(path.join(os.tmpdir(),setupCheck?'sigra-253-order-setup-check-':'sigra-253-order-diagnostic-'));
const start=Date.now(), limit=setupCheck?120000:600000;
let deadline=start+limit;
if(continuation){
 const reservation=JSON.parse(fs.readFileSync(path.join(here,'diagnostic-reservation.json')));
 const approval=JSON.parse(fs.readFileSync(path.join(here,'approval.json')));
 const prior=JSON.parse(fs.readFileSync(path.join(here,'diagnostic-output/result.json')));
 need(approval.decision==='approved'&&prior.browser_invocations===0&&prior.error==='command failed: setup','no unused approved browser invocation');
 need(JSON.stringify(reservation.scope)===JSON.stringify(proposal.scope),'approved scope changed');
 deadline=Date.parse(reservation.started_at)+600000;
 need(Date.now()<deadline-20000,'original approved deadline has expired');
 fs.writeFileSync(path.join(here,'browser-reservation.json'),JSON.stringify({started_at:new Date().toISOString(),deadline:new Date(deadline).toISOString(),approval:'approval.json',prior_setup:'diagnostic-output/result.json',max_browser_invocations:1,old_slots_reopened:0})+'\n',{flag:'wx'});
}
const workDeadline=deadline-20000;
const env={...diagnosticEnvironment({port:39453},'sigra253_order_diagnostic',out),CI:'true',SIGRA_EXAMPLE_URL:'http://127.0.0.1:39453',PATH:path.dirname(proposal.node)+path.delimiter+process.env.PATH};
const result={kind:setupCheck?'development_setup_check':'development_diagnostic',source:proposal.source_commit,started_at:new Date(start).toISOString(),output:out,steps:[],browser_invocations:0,github_requests:0,old_slots_reopened:0,acceptance:false,limitations:proposal.limitations,deadline:new Date(deadline).toISOString(),continuation_of_original_approval:continuation};
const servers=[];
const awake=holdHostAwake();
const step=async(name,program,args,cwd,ceiling=workDeadline)=>{
 const receipt=await runLoggedTree(program,args,cwd,env,path.join(out,name+'.log'),Math.max(1,ceiling-Date.now()));
 result.steps.push({name,args,...receipt});need(receipt.exit_code===0&&!receipt.timed_out&&!receipt.suspended,'command failed: '+name);return receipt;
};
const server=(name,program,args,cwd)=>{
 const controller=new AbortController();let ended=false;
 const promise=runLoggedTree(program,args,cwd,env,path.join(out,name+'.log'),Math.max(1,workDeadline-Date.now()),250,{signal:controller.signal}).then(receipt=>{ended=true;result.steps.push({name,...receipt});return receipt;});
 servers.push({controller,promise});return ()=>ended;
};
try{
 await step('initdb','initdb',['-D',path.join(out,'pg'),'-U','postgres','-A','trust','--no-locale','--encoding=UTF8'],out);
 const pgEnded=server('postgres','postgres',['-D',path.join(out,'pg'),'-p','58624','-h','127.0.0.1','-k',out],out);
 let ready=false;
 while(Date.now()<workDeadline&&!pgEnded()){
  const probe=await runLoggedTree('pg_isready',['-h','127.0.0.1','-p','58624','-U','postgres'],out,env,path.join(out,'pg-ready.log'),2000);
  if(probe.exit_code===0){ready=true;break;}
  await new Promise(r=>setTimeout(r,250)); // bounded readiness polling, never a test sleep
 }
 need(ready,'owned PostgreSQL did not become ready');
 await step('setup','mix',['ecto.setup'],path.join(checkout,'test/example'));
 const appEnded=server('app','mix',['phx.server'],path.join(checkout,'test/example'));
 ready=false;
 while(Date.now()<workDeadline&&!appEnded()){
  try{const response=await fetch('http://127.0.0.1:39453/users/register',{signal:AbortSignal.timeout(1500)});await response.body?.cancel();if(response.status===200){ready=true;break;}}catch{}
  await new Promise(r=>setTimeout(r,250));
 }
 need(ready,'original app did not become ready');
 if(setupCheck){result.outcome='setup_and_app_readiness_verified';}
 else{
 result.browser_invocations=1;
 await step('browser',proposal.node,[path.join(pw,'node_modules/playwright/cli.js'),'test','tests/admin-eval.spec.ts','--project=admin-eval-dark','--grep='+proposal.grep,'--workers=1','--retries=0','--max-failures=1','--trace=retain-on-failure','--reporter=json','--output='+path.join(out,'test-results')],pw);
 result.outcome='completed_without_reproducing_failure';
 }
}catch(error){result.outcome='stopped';result.error=error.message;process.exitCode=1;}
finally{
 for(const s of servers.reverse()){s.controller.abort();await s.promise;}
 awake.release();
 result.duration_ms=Date.now()-start;
 fs.writeFileSync(path.join(out,'result.json'),JSON.stringify(result,null,2)+'\n');
 const retained=path.join(here,setupCheck?'setup-check-output':continuation?'browser-output':'diagnostic-output');fs.mkdirSync(retained,{recursive:true});
 for(const item of ['initdb.log','postgres.log','setup.log','app.log','browser.log','result.json','test-results']){const from=path.join(out,item);if(fs.existsSync(from))fs.cpSync(from,path.join(retained,item),{recursive:true});}
 console.log(JSON.stringify({outcome:result.outcome,result:path.join(out,'result.json'),browser_invocations:result.browser_invocations,acceptance:false}));
}
