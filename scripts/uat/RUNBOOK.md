# Sigra v1.0 UAT Runbook

## CI vs manual (shift-left)

Many checklist items are now duplicated or superseded by **merge-blocking CI** and **ExUnit/Playwright** contracts. Before spending human time on a row, see **[`docs/uat-ci-coverage.md`](../../docs/uat-ci-coverage.md)** for the SEED-001 / v1.3 mapping (which jobs close which SEED, and what is still residual).

| Work type | Use this runbook when… |
|-----------|-------------------------|
| **CI already covers it** | You only need a release paper trail — link workflow run URLs + commit SHA in `.planning/uat-evidence/` instead of re-running every click. |
| **Residual row** | You care about real Gmail/Outlook/Apple rendering or live Google OAuth UX — run the relevant section below. |

---

This runbook walks through the **19 human verification items** the per-phase verifiers deferred during phases 4, 5, 6, 8, 9, and 10. Once all are checked off, milestone v1.0 is GA-ready.

**Estimated time:** 90-150 minutes for all 19 items in one focused session.
**Prerequisites:** Docker Desktop running, Elixir 1.19+, a modern browser.

---

## 0. Bring up the environment

### Start the stack

```bash
# From the repo root:
scripts/uat/up.sh
```

This will:
1. Start Postgres in Docker under a project-scoped Compose name
2. Fetch deps in `test/example/`
3. Create, migrate, and seed the `example_dev` database
4. Write the current runtime env to `tmp/uat.env`
5. Print the exact Postgres port, app port, server command, and entry-point URLs

Optional stable local URL through the shared proxy:

```bash
scripts/dev-proxy/up.sh
scripts/uat/up.sh --proxy
```

`--proxy` starts the Dockerized Vaultr example app and attaches it to the
external Docker network named `proxy`. The shared `dev_proxy-traefik-1`
container owns `127.0.0.1:80` and routes `.localhost` hostnames, so Sigra is
reachable at `http://sigra.localhost` without reserving its own port-80 proxy.
The raw `127.0.0.1:<port>` URL is still printed as a fallback. The
`scripts/dev-proxy/up.sh` helper is generic local developer infrastructure:
any compatible Traefik attached to the external Docker network named `proxy`
can route Sigra's labels, and no sibling project checkout is required.

Do not use a project-private Sigra Traefik on port 80. If you explicitly need a
private fallback proxy for UAT isolation, use the opt-in fallback:

```bash
scripts/uat/up.sh --private-traefik
```

That keeps Phoenix running on the host and starts Sigra's private Traefik on
`http://sigra.localhost:18080`. Choose another nonstandard fallback port with:

```bash
SIGRA_UAT_PROXY_PORT=18081 scripts/uat/up.sh --private-traefik
```

The private fallback proxy image defaults to `traefik:v3.7.1`. Override
`SIGRA_UAT_TRAEFIK_IMAGE` if your local Docker cache or project policy uses a
different Traefik v3 tag.

For the default raw path and the `--private-traefik` fallback, start Phoenix in
a second terminal:

```bash
cd test/example
PGHOST=127.0.0.1 PGPORT=<printed-postgres-port> PORT=<printed-app-port> SIGRA_EXAMPLE_URL=<printed-app-url> iex -S mix phx.server
```

The app URL is printed by `scripts/uat/up.sh`.
Use the printed app URL for every local browser step below unless a step
explicitly calls out a fixed external-provider callback URL. In shared proxy
mode, Phoenix is already running inside the Compose `web` service and
`scripts/uat/status.sh` prints the Docker logs command instead of a manual
server command.

The local Swoosh mailbox preview is at `/dev/mailbox` on that app URL — open this in a second tab and keep it visible. Every time the app would send an email, it appears here instead.

When you're done with the UAT session:

```bash
scripts/uat/status.sh         # reprint URLs and the server command
scripts/uat/up.sh --print-env # print export lines for ad-hoc commands
scripts/uat/down.sh           # stop containers for this Compose project, keep DB
scripts/uat/down.sh --purge   # also wipe this project's DB volume
```

By default, the UAT stack does not reserve host port `5432`, so Homebrew
Postgres, `act`, and other Docker projects can keep running. To force a stable
Postgres port for debugging, run `SIGRA_UAT_PG_PORT=5432 scripts/uat/up.sh`;
if that fixed port is occupied, Docker will report the bind conflict.

The helper also avoids fixed Phoenix port `4000` by default. Use
`SIGRA_EXAMPLE_PORT=4000 scripts/uat/up.sh` only when you need a stable browser
origin, such as an external OAuth callback. If multiple demo projects are
running, leave both ports dynamic and use `scripts/uat/status.sh` to recover the
current URLs.

Each checkout gets a Compose project name based on user, branch, and checkout
path. That keeps containers, networks, and volumes separate when you run several
Sigra clones or sibling OSS libraries at the same time. The default
dynamic-port path stays the lowest-friction UAT route; the stable
`http://sigra.localhost` path composes with the one shared local Traefik instead
of starting a Sigra-owned port-80 proxy.

---

## How to use this runbook

Each item has:
- **Phase / source** — which phase verifier deferred it
- **Steps** — exact click-by-click walkthrough
- **Expected** — what you should see
- **Pass criteria** — what makes it a ✓
- **Notes** — caveats, fallbacks, or what to capture for an issue if it fails

Mark each item with `[x]` as you complete it. If something fails, leave the checkbox empty and add a brief note — that becomes the gap-closure plan input.

---

## Phase 4 — Session Management & Security Baseline

### [ ] 4.1 Session listing LiveView visual render

**Source:** `04-VERIFICATION.md` (human_needed item 1)

**Steps:**
1. Visit `<printed-app-url>/users/register`
2. Register with email `test1@example.com` / password `correcthorsebatterystaple`
3. Open `/dev/mailbox` in another tab → click the confirmation email → click the confirmation link → you're confirmed and logged in
4. Navigate to `<printed-app-url>/users/sessions`
5. Open an incognito window → log in as the same user with the same password (this creates a second session)
6. Switch back to your normal window → refresh `/users/sessions`

**Expected:**
- "Active Sessions" page heading
- 2 rows shown, each with: device/user-agent string, IP address, last-active timestamp
- The current session is marked with a "This device" badge
- Each non-current row has a "Revoke session" button
- A "Log out of all devices" button at the bottom

**Pass criteria:** All visual elements present, Tailwind styling intact, both sessions visible.

**Notes:** The location field may show `unknown` or `localhost` since we're testing locally — that's fine. The connect-params token identification is what marks the current session.

---

### [ ] 4.2 Sudo re-auth flow end-to-end

**Source:** `04-VERIFICATION.md` (human_needed item 2)

**Steps:**
1. Logged in from the previous step
2. Wait at least the configured sudo TTL (default 5 minutes) OR open a private window and log in fresh
3. Navigate to `<printed-app-url>/users/settings`
4. Try to change email or trigger any sensitive action

**Expected:**
- You're redirected to `/users/sudo`
- Page asks for current password
- Entering correct password redirects you back to the original settings page with the action now allowed
- The sudo state persists for the full TTL window (try changing email twice in a row — the second should not re-prompt)

**Pass criteria:** Multi-step redirect flow works, sudo state persists for the TTL, sudo expiry re-prompts.

**Notes:** If your dev session is still in sudo mode from registration, log out, log back in, then try.

---

### [ ] 4.3 Lockout + suspicious-login email visual rendering

**Source:** `04-VERIFICATION.md` (human_needed item 3)

**Steps:**
1. Log out
2. Navigate to /users/log_in
3. Enter `test1@example.com` with a wrong password 5 times in a row
4. Open /dev/mailbox

**Expected:**
- 1 "Account locked" email appears
- Subject line is clear and non-alarmist
- HTML body has a heading, an explanation paragraph, and the unlock-time
- Plain-text version is also present and readable
- (Optional) A separate suspicious-login email if your IP/user-agent looks new — this fires on first successful login from an unrecognized device

**Pass criteria:** Both emails render with correct copy, CTA buttons (if any), and clear visual hierarchy.

**Notes:** Suspicious-login detection compares IP + user-agent against the user's history. From localhost on the same machine it may not fire — that's expected. Test the lockout email at minimum.

---

### [ ] 4.4 Remember-me cookie rehydration

**Source:** `04-VERIFICATION.md` (human_needed item 4)

**Steps:**
1. Wait for lockout (default 15 min) or restart the database to clear it: `cd test/example && mix ecto.reset`
2. Re-register if needed (or use a different email)
3. Log in with the "Remember me" checkbox **checked**
4. Verify you're logged in (any authenticated page works — try /users/settings)
5. Quit the browser entirely (not just the tab — the whole app)
6. Reopen the browser, navigate to the printed app URL

**Expected:**
- You're still logged in (no login prompt)
- /users/sessions still shows the session as active
- The session was rehydrated from the long-lived `_example_user_remember_me` cookie

**Pass criteria:** Session restored without re-entering credentials.

**Notes:** Browsers may clear "session" cookies on close but preserve "persistent" cookies — that's exactly the remember-me distinction we're testing. If your browser is configured to clear all cookies on quit, test in a different browser.

---

## Phase 5 — OAuth & Social Login

### [ ] 5.1 mix sigra.gen.oauth in a fresh Phoenix project

**Source:** `05-VERIFICATION.md` (human_needed item 1)

**Steps:**
1. In a temp directory: `mix phx.new test_oauth_app --no-tailwind --no-esbuild --binary-id`
2. `cd test_oauth_app`
3. Add to `mix.exs` deps: `{:sigra, path: "/Users/jon/projects/sigra"}`
4. `mix deps.get`
5. `mix sigra.install`
6. `mix sigra.gen.oauth google github`

**Expected:**
- Generator creates 12+ files without errors
- Routes injected into `router.ex` for OAuth callbacks
- Config injected into `config/config.exs` for provider strategies
- Vault child injected into `application.ex` (for encrypted token storage)
- `mix compile --warnings-as-errors` succeeds

**Pass criteria:** All generated files exist, routes/config/vault wired, clean compile.

**Notes:** This is the only UAT item that requires generating a fresh Phoenix app outside the example. If `mix phx.new` complains about missing tailwind/esbuild, the `--no-*` flags above should suppress them.

---

### [ ] 5.2 End-to-end Google OAuth credential cycle

**Source:** `05-VERIFICATION.md` (human_needed item 2)

**Requires:** A Google OAuth client ID + secret. Get one from https://console.cloud.google.com/apis/credentials → "Create OAuth client ID" → Web application → Authorized redirect URI: `http://localhost:4000/auth/google/callback`

**Steps (using the example app from `scripts/uat/up.sh`, NOT a fresh app):**
1. Stop the server (Ctrl-C twice)
2. Edit `test/example/config/dev.exs` and add a strategy block (or set env vars and reload):
   ```elixir
   config :example, ExampleWeb.OauthController,
     google: [
       client_id: System.get_env("GOOGLE_CLIENT_ID"),
       client_secret: System.get_env("GOOGLE_CLIENT_SECRET"),
       redirect_uri: "http://localhost:4000/auth/google/callback"
     ]
   ```
3. `GOOGLE_CLIENT_ID=... GOOGLE_CLIENT_SECRET=... iex -S mix phx.server`
4. In a new private browser window, visit the matching `/users/register` URL for the callback origin you configured
5. Click "Sign in with Google"
6. Grant permission in Google's consent screen
7. You're redirected back to the app

**Expected:**
- Redirect to Google succeeds (no SSL/redirect-URI mismatch)
- Google consent screen lists the right scopes (email, profile)
- Callback creates a new user with the Google email
- You land logged in with a remember-me session
- /users/settings shows Google as a linked provider

**Pass criteria:** Full register-via-Google cycle completes without manual intervention.

**Notes:** If your example app does not have the OAuth controller wired, **skip this item** and run UAT 5.1 in the temp app instead — the temp app will have it wired by `mix sigra.gen.oauth`. Mark this item as "covered by 5.1" if so.

---

### [ ] 5.3 Provider linking + last-method unlink prevention

**Source:** `05-VERIFICATION.md` (human_needed item 3)

**Requires:** UAT 5.2 set up (or similar OAuth provider config in the temp app)

**Steps:**
1. Logged in as a user that registered via password
2. Navigate to /users/settings
3. Find the "Linked accounts" section
4. Click "Link Google" → complete the Google OAuth flow → you're redirected back
5. Confirm Google now appears as linked
6. Try to unlink your password method (or unlink Google — whichever leaves you with 0 auth methods)

**Expected:**
- Linking flow works without losing the original session
- After linking, both auth methods are visible
- The "unlink" button on the **last** auth method is disabled with a tooltip explaining why
- After setting a password (if you started OAuth-only), the unlink button on Google becomes enabled

**Pass criteria:** Linking works; last-method unlink is blocked.

---

### [ ] 5.4 Email-match confirmation flash + redirect

**Source:** `05-VERIFICATION.md` (human_needed item 4)

**Steps:**
1. Register a user with email `match@example.com` and a password (DO NOT link OAuth)
2. Log out
3. Visit /users/log_in
4. Click "Sign in with Google" using a Google account whose email is also `match@example.com`

**Expected:**
- The app detects the email match
- You see a flash: "An account with this email already exists. Log in to link your provider."
- You're redirected to /users/log_in
- After password login, the OAuth provider auto-links to your existing account

**Pass criteria:** Email-match detection prevents account takeover; user is guided to link rather than create a duplicate.

**Notes:** If the configured behavior is "auto-link without confirmation" (CONFIG-driven), the flash message changes to "Linked Google to your account". Verify whichever mode your config sets.

---

## Phase 6 — Multi-Factor Authentication

### [ ] 6.1 mix sigra.install MFA file generation

**Source:** `06-VERIFICATION.md` (human_needed item 1)

**Steps:**
1. Already covered as a side-effect of UAT 5.1 (the temp app)
2. Verify in the temp app:
   - `lib/test_oauth_app/accounts/user_mfa_credential.ex` exists
   - `lib/test_oauth_app_web/live/mfa_settings_live.ex` exists
   - `lib/test_oauth_app_web/live/mfa_challenge_live.ex` exists
   - `priv/repo/migrations/*_create_user_mfa_credentials.exs` exists
   - `router.ex` contains `live "/users/mfa", MFAChallengeLive`
   - `router.ex` authenticated pipeline contains `plug :require_mfa`
3. `mix compile --warnings-as-errors` succeeds

**Pass criteria:** All MFA artifacts generated, router wired, clean compile.

---

### [ ] 6.2 MFA challenge page browser render

**Source:** `06-VERIFICATION.md` (human_needed item 2)

**Steps:**
1. In the example app, log in as a user
2. Navigate to /users/settings/mfa
3. Click "Enroll in MFA"
4. Scan the QR code with Google Authenticator / 1Password / Authy
5. Type the 6-digit code
6. Save the displayed backup codes
7. Click "Done" (you may need to acknowledge the backup codes first)
8. Log out
9. Log back in with email/password
10. You should be redirected to the MFA challenge page

**Expected on the challenge page:**
- Two tabs: "Authenticator code" and "Backup code"
- 6-digit input field (or 6 separate boxes)
- Auto-submit fires when you've typed all 6 digits (no submit button click required)
- "Trust this browser" checkbox visible
- Cancel link to log out

**Pass criteria:** Visual layout matches above, auto-submit JS works, tabs switch.

---

### [ ] 6.3 End-to-end TOTP enrollment with QR code + backup grid

**Source:** `06-VERIFICATION.md` (human_needed item 3)

**Steps:** Combined with 6.2 — the enrollment flow itself.

**Expected during enrollment:**
- QR code renders (clearly scannable)
- Manual entry secret (Base32 string) is visible below the QR
- Confirmation code input accepts a valid 6-digit code
- After confirmation, 8-10 backup codes appear in a 2-column grid
- Copy button copies all codes to clipboard
- Download button saves them as a .txt file
- Acknowledgment checkbox ("I've saved my codes") gates the "Done" button

**Pass criteria:** All enrollment UI elements work, QR scannable, backup codes presented properly.

---

### [ ] 6.4 Backup code regeneration wiring

**Source:** `06-VERIFICATION.md` (human_needed item 4 — flagged because the handler has a TODO comment)

**Steps:**
1. Logged in with MFA enabled
2. Navigate to /users/settings/mfa
3. Click "Regenerate backup codes"
4. Enter your TOTP code
5. New backup codes appear

**Expected:**
- The new set of 8-10 codes is displayed
- The OLD backup codes no longer work (try to log in using one of the old codes — should fail with "invalid code")
- The new codes work

**Pass criteria:** Old codes are invalidated, new codes are functional.

**Notes:** The phase 6 verifier flagged this specifically because `regenerate_codes` in `mfa_settings_live.ex` has a `TODO: Wire to Auth.mfa_regenerate_backup_codes/2 when available` comment. **If the regeneration is not actually wired** (codes look new but old ones still work), this is a real gap and should become a fix-plan input — capture the failure mode and report it.

---

## Phase 8 — Account Lifecycle

### [ ] 8.1 Settings LiveView 3-section render

**Source:** `08-VERIFICATION.md` (human_needed item 1)

**Steps:**
1. Logged in as a user
2. Navigate to /users/settings

**Expected (3 sections, top to bottom):**
- **Email** section: current email, change-email form (new email + current password), pending-change banner if a change is in progress
- **Password** section: change-password form (current + new + confirm) for password users, OR a "Set password" form for OAuth-only users
- **Danger zone** section: red border, account deletion form requiring you to type your email to confirm

**Pass criteria:** All three sections render, the danger zone is visually distinct (red border / bg), forms have proper labels.

---

### [ ] 8.2 Sudo mode gates on sensitive operations

**Source:** `08-VERIFICATION.md` (human_needed item 2)

**Steps:**
1. Wait for sudo TTL to expire (or log out + back in)
2. Try to:
   - Change email (submit the form)
   - Delete account (submit the form)
   - For OAuth-only users: set a password

**Expected:** Each sensitive op triggers a redirect to /users/sudo before executing. After sudo verification, you're returned to the settings page and the action proceeds.

**Pass criteria:** All 3 ops are sudo-gated when sudo has expired.

**Notes:** Sudo enforcement depends on how the host app wires the router pipeline. The example app's router (test/example/lib/example_web/router.ex) has the sudo route mounted but no `:require_sudo` pipeline applied to settings — verify the actual behavior. If sudo isn't gating, that's expected for the example app's current router config and should be documented as "router-pipeline-dependent, app responsibility."

---

### [ ] 8.3 Reactivation page during grace-period login

**Source:** `08-VERIFICATION.md` (human_needed item 3)

**Steps:**
1. Logged in as a user
2. Navigate to /users/settings → Danger zone
3. Type your email in the confirm field and click "Delete account"
4. You should be logged out and the account marked for deletion (grace period defaults to 30 days)
5. Try to log back in

**Expected:**
- After login, instead of landing on the home page, you see the /users/reactivation page
- The page explains the account is scheduled for deletion
- A "Cancel deletion" button restores the account
- A "Log out and proceed with deletion" link does what it says

**Pass criteria:** Reactivation page appears for users in the grace window, cancel button restores them.

**Notes:** This integrates with phase 8's `Sigra.Accounts.scheduled_for_deletion?/1` check on login. If deletion happens immediately (no grace), the test/example app may have configured `:hard_delete` mode — verify the deletion mode in `Example.Accounts` config and adjust expectations.

---

### [ ] 8.4 7 new email templates visual quality

**Source:** `08-VERIFICATION.md` (human_needed item 4)

**Steps:**
1. Trigger each of these flows from a logged-in user and check `/dev/mailbox`:
   - Email change request → 1 email to **new** address (confirmation), 1 email to **old** address (notification)
   - Email change cancel → 1 email to old address (cancelled)
   - Password change → 1 email (changed-confirmation)
   - Password set (OAuth-only user setting password for the first time) → 1 email (set)
   - Account deletion request → 1 email (scheduled-for-deletion)
   - Account reactivation → 1 email (cancelled)

**Expected:** All 7 emails render with:
- Clear subject lines
- Heading + body copy that matches the action
- Security footer ("If you did not initiate this, contact support immediately")
- CTA button where applicable (e.g., "Confirm new email address")

**Pass criteria:** Visual quality is acceptable for production. Compare against the UI-SPEC if you have one handy.

---

## Phase 9 — Audit Logging

Phase 9 has a single architectural caveat (C-1: log_safe hybrid is non-atomic) and **no human UAT items** beyond what's covered above. The audit log is exercised by the test suite. Confirm by:

### [ ] 9.1 Spot-check audit table

**Steps:**
1. After running the UAT items above, open `psql`:
   ```bash
   docker compose -p <printed-compose-project> -f scripts/uat/docker-compose.yml exec postgres psql -U postgres example_dev
   ```
2. `SELECT event_type, actor_id, ip, occurred_at FROM audit_events ORDER BY occurred_at DESC LIMIT 30;`

**Expected:**
- Rows for: `auth.register.success`, `auth.login.success`, `auth.login.failure` (5 of these from item 4.3), `auth.password_reset_complete`, `auth.confirmation_verify.success`, `auth.mfa.enroll`, `auth.email_change.request`, `auth.account.delete.request`, etc.
- Each row has user ID (where applicable), IP, timestamp, JSONB metadata

**Pass criteria:** Audit rows are present and well-formed for every flow you exercised.

**Caveat to verify:** Per phase 9 C-1, audit writes via `log_safe/3` are NOT atomic with their parent operation at most call sites — if the parent transaction commits but the audit insert fails, you'll see the parent change reflected in the user table without an audit row. This is **accepted for v1.0** but worth knowing. If you want stricter atomicity, that's a v1.1 candidate.

---

## Phase 10 — Developer Experience

### [ ] 10.1 Example-app smoke suite against Postgres

**Source:** `10-VERIFICATION.md` (human_needed item 1)

**Steps:**
```bash
cd test/example
PGHOST=127.0.0.1 PGPORT=<printed-postgres-port> MIX_ENV=test mix ecto.create
PGHOST=127.0.0.1 PGPORT=<printed-postgres-port> MIX_ENV=test mix ecto.migrate
PGHOST=127.0.0.1 PGPORT=<printed-postgres-port> mix test --include integration
```

**Expected:** Full example-app test suite runs against the dockerized Postgres. The phase 10-06 SUMMARY claims 34/34 tests pass.

**Pass criteria:** All tests green, no DB connection errors.

**Notes:** Locally the verifier reported "no postgres role 'postgres'" — the dockerized Postgres in this UAT env solves that. If any tests fail, capture the failure and that's a real gap (not just a CI-environment quirk).

---

### [ ] 10.2 mix docs HexDocs visual smoke

**Source:** `10-VERIFICATION.md` (human_needed item 2)

**Steps:**
```bash
cd /Users/jon/projects/sigra   # repo root, NOT test/example
mix docs
open doc/index.html            # macOS; xdg-open on Linux
```

**Expected:**
- The landing page is `getting-started.md` content (not the README or a stub)
- Sidebar is grouped: **Introduction** / **Flows** / **Recipes**
- All 15 guides render with formatting intact
- `doc/llms.txt` exists and is well-formed (Markdown index of all docs for LLM consumption)

**Pass criteria:** Visual quality acceptable, no broken links, sidebar grouping correct.

---

### [ ] 10.3 Clean-machine read-through of getting-started.md

**Source:** `10-VERIFICATION.md` (human_needed item 3)

**Steps:** Read `guides/introduction/getting-started.md` from top to bottom as if you were a new user who just discovered Sigra. Check:
- Does the intro explain what Sigra is and why someone would use it (vs phx.gen.auth, Pow, Guardian)?
- Are the install steps complete and copy-pasteable?
- Are there obvious typos, broken links, dead code samples?
- Does the example-app section actually correspond to the test/example/ structure you just stood up?

**Pass criteria:** A first-time reader could go from zero to "Sigra works in my Phoenix app" using only this doc.

**Notes:** This is the biggest UX risk for the v1.0 launch. Spend 10-15 minutes here and capture **any** friction.

---

## Running CI locally with `act` (Phase 10.1.1)

`act` runs the `.github/workflows/ci.yml` workflow inside Docker containers
that closely mirror the real GitHub Actions runner. It's the fastest way to
iterate on CI changes without the push → wait → red-build loop.

### One-time setup

```bash
brew install act            # requires Docker Desktop running
docker pull --platform linux/arm64 catthehacker/ubuntu:act-20.04  # M-series macs
```

An `.actrc` at the repo root pins `ubuntu-latest` (and `-20.04`, `-22.04`,
`-24.04`) to `catthehacker/ubuntu:act-20.04`. **Do not change this without
understanding the reason:** `erlef/setup-beam` only publishes arm64 Erlang/OTP
prebuilts for Ubuntu 20.04 (libssl1.1). Newer Ubuntu images (22/24) break the
`:crypto` NIF with `libcrypto.so.1.1: cannot open shared object file`, which
in turn breaks `mix local.rebar` (can't make HTTPS requests).

### Port 5432 collision

Act's postgres service binds `0.0.0.0:5432`, so anything already listening
there (Homebrew Postgres or stale fixed-port Docker containers) will block the
job setup. The UAT stack uses a dynamic Postgres port by default, so it should
not be the source of this conflict unless you started it with
`SIGRA_UAT_PG_PORT=5432`.

```bash
lsof -i :5432                              # find who owns it
docker ps --format 'table {{.Names}}\t{{.Ports}}'
brew services stop postgresql@14           # if Homebrew Postgres
```

Restart whatever you stopped when the act run finishes.

### Common commands

```bash
act -l                                        # list jobs
act -j library_tests                          # run one job
act -j example_playwright_smoke --reuse       # --reuse keeps container warm
act --graph                                   # draw the workflow graph
act -j <job> --verbose                        # full stdout, not just grouped output
```

`--reuse` is the big performance win — without it, act rebuilds the container
and re-fetches deps on every run. With it, the second run skips `mix deps.get`,
`npm ci`, and the chromium download entirely, dropping a full Playwright run
from ~12 minutes to ~90 seconds.

### Troubleshooting

- **`EACCES: permission denied, rmdir '/opt/hostedtoolcache/...'`** — The
  image starts as a non-root user. Fix with `--container-options --user=0:0`
  in `.actrc` (already set).
- **`Bind for 0.0.0.0:5432 failed: port is already allocated`** — See the
  Port 5432 collision section above.
- **`Unable to load crypto library ... libcrypto.so.1.1`** — You're running
  against an Ubuntu 22/24 image. Switch back to `act-20.04`.

---

## Branch protection — required status checks (Phase 10.1.1)

After merging phase 10.1.1 (example-app repair + CI smoke harness), update
GitHub branch protection so every PR must pass all five CI jobs before merge.
This is a manual step in the GitHub UI — Actions can run the jobs but cannot
configure branch protection via the workflow file.

Settings path:
GitHub → Repo → Settings → Branches → Branch protection rules →
`main` → Require status checks to pass before merging → select the jobs below.

Required checks:

1. `library_tests` — library ExUnit + mix docs --warnings-as-errors
2. `example_unit_smoke` — example app ExUnit + ConnTest (renamed from example_app_smoke in phase 10.1.1)
3. `example_http_smoke` — curls critical routes against a booted example app
4. `example_playwright_smoke` — Playwright browser lifecycle test (register → confirm → login → sudo → MFA → logout)
5. `install_smoke` — fresh mix phx.new + mix sigra.install + compile with --warnings-as-errors

IMPORTANT — rename migration: The old `example_app_smoke` required-check
was renamed to `example_unit_smoke`. When editing branch protection, remove
the stale `example_app_smoke` entry (which will show as "not reporting"
after the rename merges) and add `example_unit_smoke` in its place.

No continue-on-error discipline: All five jobs are PR-required. Flakes must
be fixed at the root cause, not masked with continue-on-error or marked
optional. See phase 10.1.1 CONTEXT.md D-15.

---

## When you're done

Total checked: ___ / 19

If all 19 are `[x]` and the test suite still passes:

```bash
cd /Users/jon/projects/sigra
mix test                      # confirm 1249 tests still green
scripts/uat/down.sh           # tear down (or --purge to wipe DB volume)
```

Then come back to me with the results and I'll:
1. Update each phase's `*-HUMAN-UAT.md` file marking gaps as resolved
2. Run `/gsd-validate-phase` for the 6 Nyquist-non-compliant phases
3. Run `/gsd-complete-milestone v1.0` to archive
4. Tell you exactly what manual steps remain (`@version` bump, CHANGELOG, `mix hex.publish`)

If any items failed, just tell me which ones and what you saw — I'll create gap-closure plans for them in `/gsd-plan-milestone-gaps`.
