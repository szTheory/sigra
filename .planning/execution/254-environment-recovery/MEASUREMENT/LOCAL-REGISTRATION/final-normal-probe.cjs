const fs=require('node:fs');
const {webkit,devices}=require('/Users/jon/projects/sigra/test/example/priv/playwright/node_modules/playwright');
(async()=>{
 const results=[];const browser=await webkit.launch({headless:true});const output='/Users/jon/projects/sigra/.planning/execution/254-environment-recovery/MEASUREMENT/LOCAL-REGISTRATION';
 try{for(let i=0;i<5;i++){
 const context=await browser.newContext({...devices['iPhone 13'],baseURL:'http://localhost:4317'});
 await context.tracing.start({screenshots:true,snapshots:true,sources:true});const page=await context.newPage();const events=[];const start=Date.now();const add=(type,data={})=>events.push({ms:Date.now()-start,type,...data});
 page.on('pageerror',e=>add('pageerror',{name:e.name,message:e.message.slice(0,180)}));
 page.on('framenavigated',frame=>{if(frame===page.mainFrame())add('navigation',{path:new URL(frame.url()).pathname})});
 page.on('domcontentloaded',()=>add('domcontentloaded'));page.on('load',()=>add('load'));
 page.on('requestfailed',r=>add('requestfailed',{path:new URL(r.url()).pathname,failure:r.failure()?.errorText}));
 page.on('console',m=>{const t=m.text();if(/falling back|unable to join|encountered.*reload|exceeded.*reload|view crashed|error/i.test(t))add('console',{message:t.slice(0,160)})});
 page.on('websocket',s=>{add('websocket');s.on('close',()=>add('websocket_closed'));s.on('socketerror',e=>add('websocket_error',{message:String(e).slice(0,120)}));s.on('framereceived',f=>{try{const a=JSON.parse(String(f.payload));add('ws_receive',{event:a[3],status:a[4]?.status,reason:a[4]?.response?.reason})}catch{}})});
 let passed=false,error;try{await page.goto('/users/register',{timeout:15000});await page.waitForSelector('[data-phx-session].phx-connected',{state:'attached',timeout:15000});passed=true}catch(e){error=e.message.slice(0,250)}
 let state;try{state=await page.evaluate(()=>({readyState:document.readyState,connected:document.querySelectorAll('[data-phx-session].phx-connected').length,socketConnected:window.liveSocket?.socket.isConnected(),transport:window.liveSocket?.socket.transport.name}))}catch{}
 results.push({iteration:i+1,passed,error,state,events});console.log(JSON.stringify({iteration:i+1,passed,error,state}));await context.tracing.stop({path:output+'/final-normal-navigation-'+(i+1)+'.trace.zip'});fs.writeFileSync(output+'/FINAL-NORMAL-RESULT.json',JSON.stringify({scope:'local development navigation only',platform:process.platform,source_sha:'fb2d3faa4b25918d14415dd00a51545f0a9c6683',results},null,2)+'\n');await context.close();
 }}finally{await browser.close();fs.writeFileSync('/tmp/sigra-mobile-readiness-probe.json',JSON.stringify(results,null,2)+'\n')}
})().catch(e=>{console.error(e.message);process.exitCode=1});
