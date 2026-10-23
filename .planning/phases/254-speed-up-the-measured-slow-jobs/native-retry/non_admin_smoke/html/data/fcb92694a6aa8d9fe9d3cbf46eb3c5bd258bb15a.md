# Instructions

- Following Playwright test failed.
- Explain why, be concise, respect Playwright best practices.
- Provide a snippet of code with the fix, if possible.

# Test info

- Name: passkeys-hooks.spec.ts >> generated passkey hooks complete real browser registration and authentication with a virtual authenticator
- Location: tests/passkeys-hooks.spec.ts:74:5

# Error details

```
Error: expect(received).toBe(expected) // Object.is equality

Expected: "sigra:passkey-register:success"
Received: "sigra:passkey-register:error"
```

# Page snapshot

```yaml
- main [ref=e2]:
  - generic [ref=e3]:
    - generic "Tasklane demo identity" [ref=e4]:
      - link "Tasklane Work tracking for teams" [ref=e5] [cursor=pointer]:
        - /url: /
        - generic [ref=e6]:
          - generic [ref=e7]: Tasklane
          - generic [ref=e8]: Work tracking for teams
    - generic [ref=e9]:
      - generic [ref=e10]:
        - paragraph [ref=e11]: Tasklane demo app · secured by Sigra
        - heading "Evaluate Sigra inside a distinct customer app." [level=1] [ref=e12]
        - paragraph [ref=e13]:
          - text: Tasklane is a fictional
          - strong [ref=e14]: project tracker
          - text: — teams plan and ship work together across shared workspaces. Its sign-in, organizations, audit trails, and operator tooling are all powered by Sigra underneath; the product itself (boards and tasks) is out of scope for this auth demo. The seeded Tasklane cohort lets evaluators inspect customer sign-in and support workflows without creating accounts.
        - generic [ref=e15]:
          - generic [ref=e16]:
            - generic [ref=e17]: Tasklane cohort domain
            - strong [ref=e18]: "@demo.tasklane.test"
          - generic [ref=e19]:
            - generic [ref=e20]: Local evaluation host
            - strong [ref=e21]: http://127.0.0.1:4142
          - generic [ref=e22]:
            - generic [ref=e23]: Sigra operator surface
            - strong [ref=e24]: /admin
        - link "Get started — pick a persona" [ref=e26] [cursor=pointer]:
          - /url: "#get-started"
        - paragraph [ref=e27]:
          - link "Open Sigra Admin" [ref=e28] [cursor=pointer]:
            - /url: /admin
          - text: ·
          - link "Inspect mailbox" [ref=e29] [cursor=pointer]:
            - /url: /dev/mailbox
      - complementary [ref=e30]:
        - paragraph [ref=e31]: One login, two jobs.
        - heading "Sign in as an operator." [level=2] [ref=e32]
        - paragraph [ref=e33]: Same Tasklane login as customers — operator personas continue into Sigra admin.
        - link "View all 10 personas →" [ref=e34] [cursor=pointer]:
          - /url: /demo/credentials
        - list [ref=e35]:
          - listitem [ref=e36]:
            - generic [ref=e37]:
              - strong [ref=e38]: Global Sigra Admin
              - paragraph [ref=e39]:
                - text: Platform-wide operator →
                - code [ref=e40]: /admin
            - link "Sign in as Admin" [ref=e41] [cursor=pointer]:
              - /url: /users/log_in?demo=admin
          - listitem [ref=e42]:
            - generic [ref=e43]:
              - strong [ref=e44]: Acme org admin
              - paragraph [ref=e45]:
                - text: Org-scoped operator →
                - code [ref=e46]: /admin/organizations/acme-corp
            - link "Sign in as Morgan" [ref=e47] [cursor=pointer]:
              - /url: /users/log_in?demo=morgan
    - generic [ref=e48]:
      - generic [ref=e49]:
        - generic [ref=e50]:
          - paragraph [ref=e51]: White-label preview
          - heading "Switch the auth brand" [level=2] [ref=e52]
          - paragraph [ref=e53]: Teal default for Tasklane — the fictional project tracker.
        - generic [ref=e54]:
          - generic [ref=e55]:
            - generic [ref=e56]: Brand preset
            - combobox "Brand preset" [ref=e57]:
              - option "Tasklane" [selected]
              - option "Rail Accent"
              - option "Meridian Health"
              - option "Night Ops"
          - group "Brand theme" [ref=e58]:
            - generic [ref=e59]: Brand theme
            - generic [ref=e60]:
              - generic [ref=e61]:
                - radio "System" [ref=e62] [cursor=pointer]
                - generic: System
              - generic [ref=e63]:
                - radio "Light" [checked] [ref=e64] [cursor=pointer]
                - generic: Light
              - generic [ref=e65]:
                - radio "Dark" [ref=e66] [cursor=pointer]
                - generic: Dark
      - generic [ref=e67]:
        - region "Auth preview" [ref=e69]:
          - generic [ref=e70]:
            - generic [ref=e71]:
              - img "Tasklane logo" [ref=e72]
              - paragraph [ref=e73]: Tasklane
            - generic [ref=e74]:
              - heading "Log in to Tasklane" [level=1] [ref=e75]
              - paragraph [ref=e76]: New here? Create an account.
            - form "Auth preview form" [ref=e77]:
              - textbox "Email preview" [ref=e78]: morgan@example.test
              - textbox "Password preview" [ref=e79]: password
              - button "Log in" [ref=e80] [cursor=pointer]
        - article [ref=e81]:
          - generic [ref=e86]:
            - generic [ref=e87]: From
            - strong [ref=e88]: Tasklane
            - code [ref=e89]: noreply@demo.tasklane.test
          - heading "Confirm your Tasklane account" [level=3] [ref=e90]
          - paragraph [ref=e91]: Finish setting up your Tasklane account. This preview uses the same brand tokens as the generated auth templates.
          - generic [ref=e92]: Confirm account
    - region "Seeded evidence" [ref=e93]:
      - generic [ref=e94]:
        - generic [ref=e95]:
          - term [ref=e96]: Demo personas
          - definition [ref=e97]: "10"
        - generic [ref=e98]:
          - term [ref=e99]: Organizations
          - definition [ref=e100]: "2"
        - generic [ref=e101]:
          - term [ref=e102]: Audit events
          - definition [ref=e103]: 15+
      - generic [ref=e105]:
        - paragraph [ref=e106]: Seeded evidence
        - heading "What the Tasklane world proves" [level=2] [ref=e107]
      - list [ref=e108]:
        - listitem [ref=e109]:
          - strong [ref=e110]: Acme Corp
          - text: and
          - strong [ref=e111]: Beta Labs
          - text: exercise organization scope, memberships, invitations, and tenant-aware audit rows.
        - listitem [ref=e112]:
          - strong [ref=e113]: "@demo.tasklane.test"
          - text: is the fixture-only Tasklane cohort domain.
        - listitem [ref=e114]:
          - generic [ref=e115]:
            - strong [ref=e116]: Sigra Admin
            - paragraph [ref=e117]:
              - text: "Support operations: user search, session review, impersonation, audit filters, exports, and scoped org views — opens"
              - code [ref=e118]: /admin
              - text: .
          - link "Sign in as Admin" [ref=e119] [cursor=pointer]:
            - /url: /users/log_in?demo=admin
        - listitem [ref=e120]:
          - generic [ref=e121]:
            - strong [ref=e122]: Org admin
            - paragraph [ref=e123]:
              - text: Org-scoped console →
              - code [ref=e124]: /admin/organizations/acme-corp
              - text: .
          - link "Sign in as Morgan" [ref=e125] [cursor=pointer]:
            - /url: /users/log_in?demo=morgan
```

# Test source

```ts
  84  |       hasResidentKey: true,
  85  |       hasUserVerification: true,
  86  |       isUserVerified: true,
  87  |       automaticPresenceSimulation: true,
  88  |     },
  89  |   });
  90  | 
  91  |   try {
  92  |     const [browserHelperSource, hookSource] = await Promise.all([
  93  |       fs.readFile(browserHelperPath, 'utf8'),
  94  |       fs.readFile(hookSourcePath, 'utf8'),
  95  |     ]);
  96  |     const inlinedHookSource = inlinePasskeyHookSource(browserHelperSource, hookSource);
  97  | 
  98  |     await page.goto('/');
  99  |     await page.addScriptTag({ path: simpleWebAuthnUmdPath });
  100 |     await page.addScriptTag({ content: inlinedHookSource });
  101 |     await expect
  102 |       .poll(async () =>
  103 |         page.evaluate(() => {
  104 |           const w = window as unknown as {
  105 |             PasskeyRegister?: { mounted?: unknown };
  106 |             PasskeyAuthenticate?: { mounted?: unknown };
  107 |           };
  108 |           return {
  109 |             reg: typeof w.PasskeyRegister?.mounted,
  110 |             auth: typeof w.PasskeyAuthenticate?.mounted,
  111 |           };
  112 |         }),
  113 |       )
  114 |       .toEqual({ reg: 'function', auth: 'function' });
  115 | 
  116 |     await page.evaluate(() => {
  117 |       const win = window as any;
  118 |       win.__sigraEvents = [];
  119 | 
  120 |       win.__mountSigraHook = (kind: 'register' | 'authenticate') => {
  121 |         const hookDef =
  122 |           kind === 'register' ? win.PasskeyRegister : win.PasskeyAuthenticate;
  123 |         const startEvent =
  124 |           kind === 'register'
  125 |             ? 'sigra:passkey-register:start'
  126 |             : 'sigra:passkey-authenticate:start';
  127 |         const listeners: Record<string, (payload: unknown) => unknown> = {};
  128 | 
  129 |         const hook = {
  130 |           ...hookDef,
  131 |           handleEvent(event: string, callback: (payload: unknown) => unknown) {
  132 |             listeners[event] = callback;
  133 |           },
  134 |           pushEvent(event: string, payload: unknown) {
  135 |             win.__sigraEvents.push({ event, payload });
  136 |           },
  137 |         };
  138 | 
  139 |         const mount = hookDef?.mounted;
  140 |         if (typeof mount !== 'function') {
  141 |           throw new Error(
  142 |             `Passkey hook missing mounted (kind=${kind}); keys=${Object.keys(hookDef ?? {}).join(',')}`,
  143 |           );
  144 |         }
  145 |         mount.call(hook);
  146 |         win.__sigraCurrentHook = hook;
  147 |         win.__sigraTrigger = (payload: unknown) => listeners[startEvent](payload);
  148 |       };
  149 |     });
  150 | 
  151 |     const regChallengeB64 = bytesToBase64Url([1, 2, 3, 4, 5, 6, 7, 8]);
  152 |     const regUserIdB64 = bytesToBase64Url([
  153 |       115, 105, 103, 114, 97, 45, 117, 115, 101, 114,
  154 |     ]);
  155 |     const authChallengeB64 = bytesToBase64Url([9, 10, 11, 12, 13, 14, 15, 16]);
  156 | 
  157 |     await page.evaluate(() => (window as any).__mountSigraHook('register'));
  158 |     await page.evaluate(
  159 |       ({ regChallengeB64: ch, regUserIdB64: uid }) =>
  160 |         (window as any).__sigraTrigger({
  161 |           options: {
  162 |             rp: { id: 'localhost', name: 'Sigra Test' },
  163 |             user: {
  164 |               id: uid,
  165 |               name: 'sigra@example.test',
  166 |               displayName: 'Sigra Test User',
  167 |             },
  168 |             challenge: ch,
  169 |             pubKeyCredParams: [{ type: 'public-key', alg: -7 }],
  170 |             authenticatorSelection: {
  171 |               residentKey: 'required',
  172 |               userVerification: 'preferred',
  173 |             },
  174 |             timeout: 60_000,
  175 |             attestation: 'none',
  176 |           },
  177 |         }),
  178 |       { regChallengeB64, regUserIdB64 },
  179 |     );
  180 | 
  181 |     await page.waitForFunction(() => (window as any).__sigraEvents.length === 1);
  182 |     const registrationEvent = await page.evaluate(() => (window as any).__sigraEvents.shift());
  183 | 
> 184 |     expect(registrationEvent.event).toBe('sigra:passkey-register:success');
      |                                     ^ Error: expect(received).toBe(expected) // Object.is equality
  185 |     expect(registrationEvent.payload.response.id).toBeTruthy();
  186 |     expect(registrationEvent.payload.response.rawId).toBeTruthy();
  187 | 
  188 |     const credentialId = registrationEvent.payload.response.rawId;
  189 | 
  190 |     await page.evaluate(() => (window as any).__mountSigraHook('authenticate'));
  191 |     await page.evaluate(
  192 |       ({ credentialId: id, authChallengeB64: ch }) =>
  193 |         (window as any).__sigraTrigger({
  194 |           options: {
  195 |             rpId: 'localhost',
  196 |             challenge: ch,
  197 |             timeout: 60_000,
  198 |             userVerification: 'preferred',
  199 |             allowCredentials: [{ type: 'public-key', id }],
  200 |           },
  201 |         }),
  202 |       { credentialId, authChallengeB64 },
  203 |     );
  204 | 
  205 |     await page.waitForFunction(() => (window as any).__sigraEvents.length === 1);
  206 |     const authenticationEvent = await page.evaluate(() => (window as any).__sigraEvents.shift());
  207 | 
  208 |     expect(authenticationEvent.event).toBe('sigra:passkey-authenticate:success');
  209 |     expect(authenticationEvent.payload.response.id).toBeTruthy();
  210 |     expect(authenticationEvent.payload.response.rawId).toBe(credentialId);
  211 |   } finally {
  212 |     await client.send('WebAuthn.removeVirtualAuthenticator', { authenticatorId });
  213 |     await client.send('WebAuthn.disable');
  214 |   }
  215 | });
  216 | 
```