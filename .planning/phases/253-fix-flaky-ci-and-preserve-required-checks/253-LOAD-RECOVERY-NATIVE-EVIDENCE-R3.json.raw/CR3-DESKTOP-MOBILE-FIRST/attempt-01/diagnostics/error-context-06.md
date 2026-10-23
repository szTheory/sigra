# Instructions

- Following Playwright test failed.
- Explain why, be concise, respect Playwright best practices.
- Provide a snippet of code with the fix, if possible.

# Test info

- Name: admin-eval.spec.ts >> registration retains the first forced assertion failure trace
- Location: tests/admin-eval.spec.ts:416:7

# Error details

```
Error: expect(page).toHaveURL(expected) failed

Expected pattern: /\/sigra-control-forced-assertion-must-fail$/
Received string:  "http://127.0.0.1:25311/users/log_in"
Timeout: 1500ms

Call log:
  - Expect "toHaveURL" with timeout 1500ms
    5 × unexpected value "http://127.0.0.1:25311/users/log_in"

```

# Test source

```ts
  333 |         release: () => {
  334 |           releaseState.released = true;
  335 |           release();
  336 |           releaseLongpoll();
  337 |         },
  338 |         waitUntilReady: async (heldPage: Page) => { await waitForLiveViewReady(heldPage); },
  339 |         refillAfterReady: async (heldPage: Page) => {
  340 |           const heldEmail = registrationControlAccount(testInfo.project.name, 'held-positive');
  341 |           const emailBox = heldPage.getByRole('textbox', { name: 'Email', exact: true });
  342 |           const passwordBox = heldPage.getByLabel('Password', { exact: true });
  343 |           emailEmptyAfterReady = (await emailBox.inputValue()) === '';
  344 |           await emailBox.fill(heldEmail);
  345 |           await passwordBox.fill(TEST_PASSWORD);
  346 |           await expect(emailBox).toHaveValue(heldEmail);
  347 |           await expect(passwordBox).toHaveValue(TEST_PASSWORD);
  348 |         },
  349 |         assertSuccess: async (heldPage: Page) => {
  350 |           await expect(heldPage.getByRole('alert')).toContainText('Account created successfully!');
  351 |           await expect(heldPage).not.toHaveURL(/\/users\/register(?:\?.*)?$/);
  352 |           expect(postsBeforeRelease, 'registration must not bypass the held connection').toBe(0);
  353 |           expect(registrationPosts, 'release must be followed by exactly one accepted registration POST').toBe(1);
  354 |           await waitForLiveViewReady(heldPage);
  355 |         },
  356 |         annotate: annotateStage,
  357 |       });
  358 |       annotateRegistrationControl(testInfo, {
  359 |         websocket_route_observed: websocketRouteObserved,
  360 |         readiness_released_by_signal: true,
  361 |         posts_before_release: postsBeforeRelease,
  362 |         server_registration_posts: registrationPosts,
  363 |         email_value_after_ready_was_empty: emailEmptyAfterReady,
  364 |         longpoll_requests_observed: longpollRequests,
  365 |         longpoll_requests_held_until_release: heldLongpollRequests,
  366 |         stage_order: stageOrder,
  367 |       });
  368 |     });
  369 |   });
  370 | 
  371 |   test('registration stops when LiveView readiness is never released', async ({ browser }, testInfo) => {
  372 |     await withRegistrationControlContext(browser, testInfo, async (page) => {
  373 |       let routeObserved!: () => void;
  374 |       const websocketObserved = new Promise<void>((resolve) => { routeObserved = resolve; });
  375 |       await page.routeWebSocket(/\/live\/websocket(?:\?|$)/, () => { routeObserved(); });
  376 |       await page.goto('/users/register', { waitUntil: 'domcontentloaded' });
  377 |       await websocketObserved;
  378 |       // The websocket route deliberately remains unconnected. This real LiveView signal
  379 |       // cannot become phx-connected, so the original readiness assertion must fail.
  380 |       await waitForLiveViewReady(page, '[data-phx-session].phx-connected', 1_500);
  381 |     });
  382 |   });
  383 | 
  384 |   test('registration fails when the readiness wait is deliberately broken', async ({ browser }, testInfo) => {
  385 |     const { registrationControlAccount } = await import('../helpers/registrationControls.mjs');
  386 |     await withRegistrationControlContext(browser, testInfo, async (page) => {
  387 |       await registerUser(page, registrationControlAccount(testInfo.project.name, 'broken-readiness-positive'), TEST_PASSWORD, {
  388 |         selector: '[data-phx-session].phx-connected[data-sigra-never-connected]',
  389 |         timeout: 1_500,
  390 |       });
  391 |     });
  392 |   });
  393 | 
  394 |   test('registration detects a deliberate same-account collision', async ({ browser }, testInfo) => {
  395 |     const { registrationControlAccount } = await import('../helpers/registrationControls.mjs');
  396 |     const email = registrationControlAccount(testInfo.project.name, 'collision');
  397 |     const emailDigest = createHash('sha256').update(email).digest('hex');
  398 |     await withRegistrationControlContext(browser, testInfo, async (firstPage) => {
  399 |       await registerUser(firstPage, email, TEST_PASSWORD);
  400 |     });
  401 |     await withRegistrationControlContext(browser, testInfo, async (page) => {
  402 |       await page.goto('/users/register', { waitUntil: 'domcontentloaded' });
  403 |       await waitForLiveViewReady(page);
  404 |       await page.getByRole('textbox', { name: 'Email', exact: true }).fill(email);
  405 |       await page.getByLabel('Password', { exact: true }).fill(TEST_PASSWORD);
  406 |       await page.getByRole('button', { name: /Create an account/ }).click();
  407 |       await expect(page.getByText('If this email is available, your account has been created. Please check your email.')).toBeVisible();
  408 |       annotateRegistrationControl(testInfo, {
  409 |         collision_email_sha256: emailDigest,
  410 |         first_registration_succeeded: true,
  411 |         duplicate_response_confirmed: true,
  412 |       });
  413 |     });
  414 |   });
  415 | 
  416 |   test('registration retains the first forced assertion failure trace', async ({ browser }, testInfo) => {
  417 |     const { registrationControlAccount } = await import('../helpers/registrationControls.mjs');
  418 |     await withRegistrationControlContext(browser, testInfo, async (page) => {
  419 |       const requestPaths: string[] = [];
  420 |       page.on('request', (request) => {
  421 |         const url = new URL(request.url());
  422 |         if (request.method() === 'POST' && url.pathname === '/users/log_in') requestPaths.push(url.pathname);
  423 |       });
  424 |       await page.goto('/users/register', { waitUntil: 'domcontentloaded' });
  425 |       await waitForLiveViewReady(page);
  426 |       await page.getByRole('textbox', { name: 'Email', exact: true }).fill(
  427 |         registrationControlAccount(testInfo.project.name, 'forced-trace-positive'),
  428 |       );
  429 |       await page.getByRole('button', { name: /Create an account/ }).click();
  430 |       await page.locator('#registration_form').evaluate((form: HTMLFormElement) => form.submit());
  431 |       await page.waitForURL((url) => url.pathname === '/users/log_in', { waitUntil: 'domcontentloaded' });
  432 |       annotateRegistrationControl(testInfo, { navigation_started: true, submit_post_path: requestPaths[0] ?? null });
> 433 |       await expect(page).toHaveURL(/\/sigra-control-forced-assertion-must-fail$/, { timeout: 1_500 });
      |                          ^ Error: expect(page).toHaveURL(expected) failed
  434 |     });
  435 |   });
  436 | }
  437 | 
  438 | if (CONTROL_STAGE === 'second') {
  439 |   test('registration starts from a fresh database and context', async ({ browser }, testInfo) => {
  440 |     const { registrationControlAccount } = await import('../helpers/registrationControls.mjs');
  441 |     await withRegistrationControlContext(browser, testInfo, async (page) => {
  442 |       const email = registrationControlAccount(testInfo.project.name, 'collision');
  443 |       await registerUser(page, email, TEST_PASSWORD);
  444 |       annotateRegistrationControl(testInfo, {
  445 |         prior_collision_account_email_sha256: createHash('sha256').update(email).digest('hex'),
  446 |         fresh_database_account_created: true,
  447 |       });
  448 |     });
  449 |   });
  450 | 
  451 |   test('registration discards trace after a passing control', async ({ browser }, testInfo) => {
  452 |     await withRegistrationControlContext(browser, testInfo, async (page) => {
  453 |       await registerUser(page, adminEvalEmail(testInfo), TEST_PASSWORD);
  454 |       annotateRegistrationControl(testInfo, { passing_registration: true, trace_expected: false });
  455 |     });
  456 |   });
  457 | }
  458 | 
  459 | let registrationSequence = 0;
  460 | 
  461 | function adminEvalEmail(testInfo: TestInfo) {
  462 |   // Example.SigraAdminPolicy requires this prefix for global admin access.
  463 |   const project = testInfo.project.name
  464 |     .replace(/^admin-eval-?/, '')
  465 |     .replace(/[^a-z0-9]+/gi, '')
  466 |     .slice(0, 8);
  467 |   const sequence = (++registrationSequence).toString(36);
  468 |   const timestamp = Date.now().toString(36);
  469 |   // WR-06: registrationSequence resets per worker, so two parallel workers can
  470 |   // reach the same (timestamp, sequence, retry) tuple and collide on the
  471 |   // unique-email constraint. Add worker-unique entropy — testInfo.workerIndex
  472 |   // plus a short random suffix — so same-millisecond collisions across
  473 |   // workers are no longer possible.
  474 |   const worker = testInfo.workerIndex.toString(36);
  475 |   const rand = Math.random().toString(36).slice(2, 6);
  476 |   return `platform-admin+ev-${timestamp}-${project}-${sequence}-${testInfo.retry}-w${worker}${rand}@example.test`;
  477 | }
  478 | 
  479 | // ── Gate/warn project detection (D-15) ────────────────────────────────────────
  480 | 
  481 | function isGateProject(testInfo: TestInfo): boolean {
  482 |   // Hard-gate only in admin-eval (Desktop Chrome DPR1); -mobile and -dark are warn-only
  483 |   return testInfo.project.name === 'admin-eval';
  484 | }
  485 | 
  486 | // ── Gallery surface×cell matrix ───────────────────────────────────────────────
  487 | 
  488 | // L1 Component boards — single-state (no mg-N-{populated,zero,loading,error} markers).
  489 | // Copied verbatim from admin-design.spec.ts:98-103 (D-02: MUST NOT fabricate 4 states;
  490 | // L1 boards expose only one fixture — capture ONE cell per board with a synthetic -default state).
  491 | const COMPONENT_BOARDS = [
  492 |   'board-stat', 'board-stat_link', 'board-task_card', 'board-summary_chip',
  493 |   'board-applied_chip', 'board-empty_state', 'board-page_back', 'board-scope_ribbon',
  494 |   'board-notice',       // designated canary (D-10)
  495 |   'board-notice_link', 'board-field_help', 'board-skeleton', 'board-audit_row',
  496 | ] as const;
  497 | 
  498 | type ComponentBoard = (typeof COMPONENT_BOARDS)[number];
  499 | 
  500 | // Group boards from the design gallery
  501 | const GROUP_BOARDS = [
  502 |   'board-mg-1',
  503 |   'board-mg-2',
  504 |   'board-mg-3',
  505 |   'board-mg-4',
  506 |   'board-mg-5',
  507 |   'board-mg-6',
  508 |   'board-mg-7',
  509 |   'board-mg-8',
  510 |   'board-mg-9',
  511 |   'board-mg-10',
  512 |   'board-mg-11',
  513 | ] as const;
  514 | 
  515 | type GroupBoard = (typeof GROUP_BOARDS)[number];
  516 | 
  517 | // State markers by group board — maps to data-testid="mg-N-{state}" testids
  518 | const GROUP_STATE_MARKERS: Record<GroupBoard, string[]> = {
  519 |   'board-mg-1': ['mg-1-populated', 'mg-1-zero', 'mg-1-loading', 'mg-1-error'],
  520 |   'board-mg-2': ['mg-2-populated', 'mg-2-zero', 'mg-2-loading', 'mg-2-error'],
  521 |   'board-mg-3': ['mg-3-populated', 'mg-3-zero-note', 'mg-3-loading-note', 'mg-3-error'],
  522 |   'board-mg-4': ['mg-4-populated', 'mg-4-zero', 'mg-4-loading', 'mg-4-error'],
  523 |   'board-mg-5': ['mg-5-populated', 'mg-5-zero', 'mg-5-loading', 'mg-5-error'],
  524 |   'board-mg-6': ['mg-6-populated', 'mg-6-zero', 'mg-6-loading', 'mg-6-error'],
  525 |   'board-mg-7': ['mg-7-populated', 'mg-7-zero', 'mg-7-loading', 'mg-7-error'],
  526 |   'board-mg-8': ['mg-8-populated', 'mg-8-zero', 'mg-8-loading', 'mg-8-error'],
  527 |   'board-mg-9': ['mg-9-populated', 'mg-9-zero', 'mg-9-loading', 'mg-9-error'],
  528 |   'board-mg-10': ['mg-10-populated', 'mg-10-zero', 'mg-10-loading', 'mg-10-error'],
  529 |   'board-mg-11': ['mg-11-populated', 'mg-11-zero', 'mg-11-loading', 'mg-11-error'],
  530 | };
  531 | 
  532 | // ── Render matrix capture helper ───────────────────────────────────────────────
  533 | 
```