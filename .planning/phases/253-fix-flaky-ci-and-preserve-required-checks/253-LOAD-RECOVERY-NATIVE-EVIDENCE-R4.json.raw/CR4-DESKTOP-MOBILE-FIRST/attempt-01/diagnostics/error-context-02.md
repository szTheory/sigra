# Instructions

- Following Playwright test failed.
- Explain why, be concise, respect Playwright best practices.
- Provide a snippet of code with the fix, if possible.

# Test info

- Name: admin-eval.spec.ts >> registration fails when the readiness wait is deliberately broken
- Location: tests/admin-eval.spec.ts:384:7

# Error details

```
TimeoutError: page.waitForSelector: Timeout 1500ms exceeded.
Call log:
  - waiting for locator('[data-phx-session].phx-connected[data-sigra-never-connected]')

```

# Test source

```ts
  47  | // __dirname resolves to tests/ directory in CJS context
  48  | const PW_ROOT = join(__dirname, '..');
  49  | 
  50  | function resolveHeadSha(): string {
  51  |   try {
  52  |     return execSync('git rev-parse HEAD', { encoding: 'utf8' }).trim();
  53  |   } catch {
  54  |     throw new Error('admin-eval.spec.ts: could not resolve git HEAD sha');
  55  |   }
  56  | }
  57  | 
  58  | interface WriteBundleOpts {
  59  |   appGitSha?: string;
  60  |   surface: string;
  61  |   theme: 'light' | 'dark';
  62  |   viewport: 'desktop' | 'mobile';
  63  |   state: 'populated' | 'zero' | 'loading' | 'error';
  64  |   outerHTML: string;
  65  |   pngBuffer: Buffer;
  66  |   axeJson: object;
  67  |   facts: BundleFacts;
  68  |   findings: ProbeFinding[];
  69  | }
  70  | 
  71  | /**
  72  |  * Enrich raw probe findings to the D-22 shape (216-08 W1).
  73  |  *
  74  |  * Each raw probe finding carries probe_class + anchor (plus probe-specific extras).
  75  |  * D-22 requires findings.json entries to also carry:
  76  |  *   - class:       probe_class alias (for guard destructuring compatibility)
  77  |  *   - surface:     the bundle surface string
  78  |  *   - finding_id:  sha256(surface NUL class NUL anchor) as 64 lowercase hex
  79  |  *
  80  |  * The finding_id key MUST use the NUL-delimited layout specified by D-22 so it
  81  |  * matches Phase-217 AUTOFIX-01 settled-findings.tsv keys.
  82  |  *
  83  |  * probe_class is kept on the record (gate/warn split at L258-266 + downstream
  84  |  * readers still reference probe_class; class is an additive alias).
  85  |  */
  86  | function enrichFindingsForBundle(surface: string, findings: ProbeFinding[]): ProbeFinding[] {
  87  |   return findings.map((f) => {
  88  |     const probeClass = f.probe_class;
  89  |     const anchor = f.anchor ?? '';
  90  |     const finding_id = createHash('sha256')
  91  |       .update(surface)
  92  |       .update('\0')
  93  |       .update(probeClass)
  94  |       .update('\0')
  95  |       .update(anchor)
  96  |       .digest('hex');
  97  |     return {
  98  |       ...f,
  99  |       class: probeClass,
  100 |       surface,
  101 |       finding_id,
  102 |     };
  103 |   });
  104 | }
  105 | 
  106 | async function writeBundleLocal(opts: WriteBundleOpts): Promise<string> {
  107 |   const appGitSha = (opts.appGitSha ?? resolveHeadSha()).trim();
  108 |   const cell = `${opts.theme}-${opts.viewport}-${opts.state}`;
  109 |   const bundleDir = join(PW_ROOT, 'eval', appGitSha, opts.surface, cell);
  110 | 
  111 |   mkdirSync(bundleDir, { recursive: true });
  112 | 
  113 |   const renderSha = await renderSha256(opts.outerHTML);
  114 | 
  115 |   // Enrich findings to D-22 shape before writing (W1, 216-08).
  116 |   const enrichedFindings = enrichFindingsForBundle(opts.surface, opts.findings);
  117 | 
  118 |   writeFileSync(join(bundleDir, 'dom.html'), opts.outerHTML, 'utf8');
  119 |   writeFileSync(join(bundleDir, 'screenshot.png'), opts.pngBuffer);
  120 |   writeFileSync(join(bundleDir, 'axe.json'), JSON.stringify(opts.axeJson, null, 2), 'utf8');
  121 |   writeFileSync(join(bundleDir, 'facts.json'), JSON.stringify(opts.facts, null, 2), 'utf8');
  122 |   writeFileSync(join(bundleDir, 'findings.json'), JSON.stringify(enrichedFindings, null, 2), 'utf8');
  123 | 
  124 |   const manifest = {
  125 |     app_git_sha: appGitSha,
  126 |     surface: opts.surface,
  127 |     cell,
  128 |     render_sha256: renderSha,
  129 |     findings_summary: {
  130 |       total: opts.findings.length,
  131 |       gate: opts.findings.filter((f) => f.severity === 'gate').length,
  132 |       warn: opts.findings.filter((f) => f.severity === 'warn').length,
  133 |     },
  134 |   };
  135 |   writeFileSync(join(bundleDir, 'bundle.json'), JSON.stringify(manifest, null, 2), 'utf8');
  136 | 
  137 |   return bundleDir;
  138 | }
  139 | 
  140 | // ── Reuse waitForLiveViewReady VERBATIM from admin-design.spec.ts (D-03) ──────
  141 | 
  142 | async function waitForLiveViewReady(
  143 |   page: Page,
  144 |   selector = '[data-phx-session].phx-connected',
  145 |   timeout?: number,
  146 | ) {
> 147 |   await page.waitForSelector(selector, {
      |              ^ TimeoutError: page.waitForSelector: Timeout 1500ms exceeded.
  148 |     state: 'attached',
  149 |     ...(timeout === undefined ? {} : { timeout }),
  150 |   });
  151 |   await page.evaluate(async () => { await (document as any).fonts.ready; });
  152 |   const ok = await page.evaluate(() => (document as any).fonts.check('16px "Space Grotesk"'));
  153 |   expect(ok, 'Space Grotesk must be loaded before snapshot').toBe(true);
  154 | }
  155 | 
  156 | // ── Admin registration (platform-admin+…@example.test prefix) ─────────────────
  157 | 
  158 | async function registerUser(
  159 |   page: Page,
  160 |   email: string,
  161 |   password: string,
  162 |   readiness: { selector?: string; timeout?: number } = {},
  163 | ) {
  164 |   // D-09: waitUntil:'domcontentloaded' on first-nav goto prevents the ~16min hung-on-load
  165 |   // flake (16 first-nav failures observed in 216-09). waitForLiveViewReady gates on
  166 |   // phx-connected + Space Grotesk ready after each goto.
  167 |   await page.goto('/users/register', { waitUntil: 'domcontentloaded' });
  168 |   await waitForLiveViewReady(page, readiness.selector, readiness.timeout);
  169 |   await page.getByRole('textbox', { name: 'Email', exact: true }).fill(email);
  170 |   await page.getByLabel('Password', { exact: true }).fill(password);
  171 |   let registrationRequest: { method: string; path: string } | null = null;
  172 |   let registrationPost: { path: string; status: number; redirectPath: string | null } | null = null;
  173 |   let registrationRequestFailure: string | null = null;
  174 |   const captureRegistrationRequest = (request: Request) => {
  175 |     const requestUrl = new URL(request.url());
  176 |     if (request.method() === 'POST' && requestUrl.pathname === '/users/log_in') {
  177 |       registrationRequest = { method: request.method(), path: requestUrl.pathname };
  178 |     }
  179 |   };
  180 |   const captureRegistrationRequestFailure = (request: Request) => {
  181 |     const requestUrl = new URL(request.url());
  182 |     if (request.method() === 'POST' && requestUrl.pathname === '/users/log_in') {
  183 |       registrationRequestFailure = request.failure()?.errorText ?? 'request failed without a browser error';
  184 |     }
  185 |   };
  186 |   const captureRegistrationPost = (response: Response) => {
  187 |     const request = response.request();
  188 |     const responseUrl = new URL(response.url());
  189 |     if (request.method() !== 'POST' || responseUrl.pathname !== '/users/log_in') return;
  190 |     const location = response.headers()['location'];
  191 |     registrationPost = {
  192 |       path: responseUrl.pathname,
  193 |       status: response.status(),
  194 |       redirectPath: location ? new URL(location, response.url()).pathname : null,
  195 |     };
  196 |   };
  197 |   page.on('request', captureRegistrationRequest);
  198 |   page.on('requestfailed', captureRegistrationRequestFailure);
  199 |   page.on('response', captureRegistrationPost);
  200 |   try {
  201 |     await Promise.all([
  202 |       page.waitForURL((url) => !url.pathname.endsWith('/users/register'), {
  203 |         timeout: 10_000,
  204 |         waitUntil: 'domcontentloaded',
  205 |       }),
  206 |       page.getByRole('button', { name: /Create an account/ }).click(),
  207 |     ]);
  208 |   } catch (error) {
  209 |     const pageState = await page.evaluate(() => {
  210 |       const form = document.querySelector<HTMLFormElement>('#registration_form');
  211 |       const submit = form?.querySelector<HTMLButtonElement>('button[type="submit"]');
  212 |       return {
  213 |         finalUrl: location.href,
  214 |         liveViewConnected: Boolean(document.querySelector('[data-phx-session].phx-connected')),
  215 |         formPresent: Boolean(form),
  216 |         formAction: form?.getAttribute('action') ?? null,
  217 |         triggerSubmit: form?.getAttribute('phx-trigger-action') ?? null,
  218 |         submitDisabled: submit?.disabled ?? null,
  219 |         validationSummary: form?.querySelector('[role="alert"], .alert')?.textContent?.trim().slice(0, 240) ?? null,
  220 |       };
  221 |     }).catch((stateError: unknown) => ({ stateCaptureError: String(stateError) }));
  222 |     page.off('request', captureRegistrationRequest);
  223 |     page.off('requestfailed', captureRegistrationRequestFailure);
  224 |     page.off('response', captureRegistrationPost);
  225 |     const message = error instanceof Error ? error.message : String(error);
  226 |     throw new Error(`${message}; registration diagnostics=${JSON.stringify({ registrationRequest, registrationPost, registrationRequestFailure, pageState })}`);
  227 |   }
  228 |   page.off('request', captureRegistrationRequest);
  229 |   page.off('requestfailed', captureRegistrationRequestFailure);
  230 |   page.off('response', captureRegistrationPost);
  231 |   // The success flash proves the server accepted registration; validation
  232 |   // responses retain a different alert and fail this assertion.
  233 |   await expect(page.getByRole('alert')).toContainText('Account created successfully!');
  234 |   await expect(page).not.toHaveURL(/\/users\/register(?:\?.*)?$/);
  235 |   // Check the short-lived success flash before waiting on web fonts; LiveView
  236 |   // readiness is still required before the caller navigates into the admin UI.
  237 |   await waitForLiveViewReady(page);
  238 | }
  239 | 
  240 | async function withRegistrationControlContext(
  241 |   browser: Browser,
  242 |   testInfo: TestInfo,
  243 |   action: (page: Page) => Promise<void>,
  244 | ) {
  245 |   const context = await browser.newContext();
  246 |   const runId = process.env.SIGRA_CONTROL_RUN_ID;
  247 |   testInfo.annotations.push({
```