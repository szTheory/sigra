const fs=require('node:fs');
const {chromium:webkit,devices}=require('/Users/jon/projects/sigra/test/example/priv/playwright/node_modules/playwright');
const output='/Users/jon/projects/sigra/.planning/execution/254-environment-recovery/MEASUREMENT/LOCAL-REGISTRATION';
(async()=>{const browser=await webkit.launch({headless:true});const results=[];
try{for(const mode of ['drop_primary_replies']){
 const context=await browser.newContext({viewport:{width:390,height:844},isMobile:true,baseURL:'http://localhost:4317'});
 await context.tracing.start({screenshots:true,snapshots:true,sources:true});const events=[];const start=Date.now();const add=(type,data={})=>events.push({ms:Date.now()-start,type,...data});
 await context.routeWebSocket(/\/live\/websocket(?:\?|$)/,route=>{const server=route.connectToServer();server.onMessage(message=>{let a;try{a=JSON.parse(String(message))}catch{};const heartbeat=a?.[2]==='phoenix';add('primary_server_reply',{event:a?.[3],topic:heartbeat?'phoenix':'liveview',status:a?.[4]?.status,reason:a?.[4]?.response?.reason,dropped:mode==='drop_primary_replies'||heartbeat});if(mode!=='drop_primary_replies'&&!heartbeat)route.send(message)})});
 const page=await context.newPage();
 page.on('framenavigated',f=>{if(f===page.mainFrame())add('navigation',{path:new URL(f.url()).pathname})});
 page.on('pageerror',e=>add('pageerror',{name:e.name,message:e.message.slice(0,150)}));
 page.on('request',r=>{const u=new URL(r.url());if(r.isNavigationRequest()||u.pathname.includes('longpoll'))add('request',{method:r.method(),path:u.pathname})});
 page.on('response',r=>{const u=new URL(r.url());if(u.pathname.includes('longpoll'))add('response',{status:r.status(),path:u.pathname})});
 page.on('console',m=>{const t=m.text();if(/falling back|unable to join|encountered.*reload|exceeded.*reload|view crashed/i.test(t))add('console',{message:t.slice(0,150)})});
 let passed=false,error;try{await page.goto('/users/register',{timeout:15000});if(mode==='drop_primary_health_reply')await page.waitForFunction(()=>window.liveSocket?.socket.transport.name!=='WebSocket',{},{timeout:10000});await page.waitForSelector('[data-phx-session].phx-connected',{state:'attached',timeout:15000});passed=true}catch(e){error=e.message.slice(0,280)}
 let state;try{state=await page.evaluate(()=>({readyState:document.readyState,connected:document.querySelectorAll('[data-phx-session].phx-connected').length,socketConnected:window.liveSocket?.socket.isConnected(),transport:window.liveSocket?.socket.transport.name}))}catch{}
 results.push({mode,passed,error,state,events});console.log(JSON.stringify({mode,passed,error,state}));await context.tracing.stop({path:output+'/final-chromium-'+mode+'.trace.zip'});fs.writeFileSync(output+'/FINAL-CHROMIUM-RESULT.json',JSON.stringify({scope:'controlled local transport fault; not evidence of original failure cause',source_sha:'fb2d3faa4b25918d14415dd00a51545f0a9c6683',platform:process.platform,results},null,2)+'\n');await context.close();
}}finally{await browser.close()}})().catch(e=>{console.error(e.message);process.exitCode=1});
