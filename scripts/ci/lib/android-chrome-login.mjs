#!/usr/bin/env node

const endpoint = process.env.SIGRA_CHROME_DEBUG_ENDPOINT || "http://127.0.0.1:9222";
const email = process.env.SIGRA_BROWSER_EMAIL;
const password = process.env.SIGRA_BROWSER_PASSWORD;
const expectedLogins = Number(process.env.SIGRA_BROWSER_LOGIN_COUNT || "1");
const deadline = Date.now() + 180_000;
const debugEndpoint = new URL(endpoint);
let lastDiagnostic = "Chrome endpoint not reached";

if (!email || !password || !Number.isInteger(expectedLogins) || expectedLogins < 1) {
  throw new Error("invalid Chrome login driver configuration");
}

const pause = (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds));

async function target() {
  const response = await fetch(`${endpoint}/json`, {signal: AbortSignal.timeout(2_000)});
  if (!response.ok) throw new Error(`Chrome target query failed: ${response.status}`);
  const targets = await response.json();
  const page = targets.find((item) => {
    if (item.type !== "page") return false;
    try {
      const url = new URL(item.url);
      return url.protocol === "http:" && ["localhost", "127.0.0.1"].includes(url.hostname);
    } catch {
      return false;
    }
  });
  const summaries = targets.map((item) => {
    try {
      const url = new URL(item.url);
      return `${item.type}:${url.protocol}//${url.host}${url.pathname}`;
    } catch {
      return `${item.type}:invalid-url`;
    }
  });
  lastDiagnostic = page ? `target=${summaries.find((value) => value.startsWith("page:"))}` : `targets=${summaries.join(",") || "none"}`;
  return page;
}

function pinnedDebuggerUrl(candidate) {
  const debuggerUrl = new URL(candidate);
  debuggerUrl.protocol = debugEndpoint.protocol === "https:" ? "wss:" : "ws:";
  debuggerUrl.hostname = debugEndpoint.hostname;
  debuggerUrl.port = debugEndpoint.port;
  return debuggerUrl.toString();
}

async function evaluate(expression) {
  const page = await target();
  if (!page?.webSocketDebuggerUrl) return undefined;
  const socket = new WebSocket(pinnedDebuggerUrl(page.webSocketDebuggerUrl));
  await new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error("Chrome DevTools socket timeout")), 3_000);
    socket.addEventListener("open", () => { clearTimeout(timer); resolve(); }, {once: true});
    socket.addEventListener("error", () => { clearTimeout(timer); reject(new Error("Chrome DevTools socket failed")); }, {once: true});
  });
  const id = 1;
  socket.send(JSON.stringify({id, method: "Runtime.evaluate", params: {expression, returnByValue: true}}));
  const result = await new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error("Chrome DevTools evaluation timeout")), 3_000);
    socket.addEventListener("message", (event) => {
      const message = JSON.parse(String(event.data));
      if (message.id !== id) return;
      clearTimeout(timer);
      if (message.error || message.result?.exceptionDetails) reject(new Error("Chrome DevTools evaluation failed"));
      else resolve(message.result?.result?.value);
    });
  });
  socket.close();
  return result;
}

async function waitFor(expression, description) {
  while (Date.now() < deadline) {
    try {
      if (await evaluate(expression)) return;
    } catch (error) {
      // Navigation replaces the renderer target; bounded polling reacquires it.
      lastDiagnostic = `error=${error instanceof Error ? error.message : "unknown"}`;
    }
    await pause(250);
  }
  throw new Error(`bounded Chrome login driver expired at ${description}; ${lastDiagnostic}`);
}

for (let index = 0; index < expectedLogins; index += 1) {
  await waitFor("Boolean(document.querySelector('#user_email') && document.querySelector('#user_password') && document.querySelector('#login_submit'))", "login form");
  const emailLiteral = JSON.stringify(email);
  const passwordLiteral = JSON.stringify(password);
  await waitFor(`(() => {
    const set = (element, value) => {
      const setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
      setter.call(element, value);
      element.dispatchEvent(new Event('input', {bubbles: true}));
      element.dispatchEvent(new Event('change', {bubbles: true}));
    };
    set(document.querySelector('#user_email'), ${emailLiteral});
    set(document.querySelector('#user_password'), ${passwordLiteral});
    document.querySelector('#login_submit').click();
    return true;
  })()`, "login submission");
  await waitFor("Boolean(document.querySelector('#app-login-approve'))", "hosted approval");
  await waitFor("(() => { document.querySelector('#app-login-approve').click(); return true; })()", "approval submission");
  await pause(500);
}

process.stdout.write(`android Chrome login driver: PASS (${expectedLogins})\n`);
