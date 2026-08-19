# Phase 247: Language-Learning Digital Twin - Pattern Map

**Mapped:** 2026-08-18
**Files analyzed:** 16 planned new/modified files
**Analogs found:** 13 / 16

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| test/example/lib/example/learning_twin.ex | service | CRUD / request-response | lib/example/accounts/crosswake_continuations.ex | role-match |
| test/example/lib/example/learning_twin/{lease,replay_receipt}.ex | model | CRUD | lib/example/accounts/crosswake_continuation.ex | exact |
| test/example/lib/example_web/live/learning_twin_live.ex | LiveView component | request-response / event-driven | lib/example_web/live/app_live.ex | exact |
| test/example/lib/example_web/controllers/learning_twin_controller.ex | controller | request-response | lib/example_web/controllers/crosswake_controller.ex | role-match |
| test/example/lib/example_web/router.ex | route/config | request-response | authenticated /app scope | exact |
| test/example/priv/repo/migrations/*_create_learning_twin_tables.exs | migration | CRUD | 20260811170000_create_crosswake_continuations.exs | exact |
| test/example/priv/static/assets/js/learning_twin.js | utility/browser client | file-I/O / event-driven | priv/static/assets/js/app.js | partial |
| test/example/priv/static/assets/js/learning_twin_worker.js | worker | file-I/O / event-driven | none | none |
| test/example/priv/static/assets/media/twin-market-morning.{svg,ogg} | static media | file-I/O | none | none |
| test/example/priv/static/assets/css/app.css | stylesheet config | transform | existing vt-* rules | exact |
| test/example/test/example/learning_twin/learning_twin_test.exs | test | CRUD / request-response | crosswake_controller_test.exs | role-match |
| test/example/test/example_web/controllers/learning_twin_controller_test.exs | test | request-response | crosswake_controller_test.exs | exact |
| test/example/test/example_web/live/learning_twin_live_test.exs | test | request-response | app_live_test.exs | exact |
| test/example/priv/playwright/tests/twin-offline.spec.ts | browser integration test | event-driven / file-I/O | crosswake-hosted-runtime.spec.ts, demo-showcase.spec.ts | role-match |

Exact host context/schema names are left to planner discretion. These are the recommended RESEARCH.md paths; preserve the responsibilities if files are consolidated.

## Pattern Assignments

### test/example/lib/example/learning_twin.ex (service, CRUD / request-response)

**Analog:** test/example/lib/example/accounts/crosswake_continuations.ex.

**Imports and guarded public API** (lines 1-11, 19-40):

    import Ecto.Query, warn: false

    alias Example.Accounts.CrosswakeContinuation
    alias Example.Repo

    def issue(raw_token, %DateTime{} = as_of, opts) when is_binary(raw_token) and is_list(opts) do
      with {:ok, binding} <- CrosswakeSessionAdapter.expected_binding(raw_token, as_of),
           true <- is_integer(ttl) and ttl > 0,
           {:ok, continuation} <- insert_continuation(binding, as_of, ttl) do
        {:ok, continuation}
      else
        {:error, :session_unavailable} -> {:error, :session_unavailable}
        false -> {:error, :invalid_ttl}
        {:error, _changeset} -> {:error, :issue_failed}
      end
    end

**Exactly-once core** (lines 42-60, 121-139):

    case claim(handle, as_of) do
      {:ok, continuation} ->
        result = complete_claimed(continuation, raw_token, return_input, as_of, evaluator_opts)
        record_outcome(continuation, result)
        result

      {:error, reason} ->
        {:deny, %{status: :deny, reason: reason}}
    end

Adapt this to reload the server-owned Scope, compare active account plus host partition to request data, and transact on a unique (account_partition, idempotency_key) receipt. Persist one accepted/rejected/conflict result before responding; retries return that receipt.

### test/example/lib/example/learning_twin/{lease,replay_receipt}.ex (model, CRUD)

**Analog:** test/example/lib/example/accounts/crosswake_continuation.ex (lines 1-89).

    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:id, :binary_id, autogenerate: true}
    @foreign_key_type :binary_id
    @schema_prefix "auth"

    schema "crosswake_continuations" do
      field :issued_at, :utc_datetime_usec
      field :expires_at, :utc_datetime_usec
      field :outcome, :string
      timestamps(type: :utc_datetime)
    end

    %__MODULE__{}
    |> change(Map.take(attrs, @issue_fields))
    |> validate_required([...])
    |> unique_constraint(:handle_digest)

Use explicit UTC timestamps, required-field/terminal-outcome validation, and schema constraints matching the migration. Never persist cookies, raw app-session values, or bearer credentials.

### test/example/lib/example_web/live/learning_twin_live.ex (LiveView, request-response / event-driven)

**Analog:** test/example/lib/example_web/live/app_live.ex.

**Scope-derived mount** (lines 17-39):

    def mount(_params, _session, socket) do
      scope = socket.assigns.current_scope
      user = scope.user

      {:ok,
       socket
       |> assign(:page_title, "Your Tasklane account")
       |> assign(:greeting_name, user.display_name || user.email)}
    end

**Tasklane layout/hook pattern** (lines 42-55):

    <Layouts.app flash={@flash} current_scope={@current_scope} user_organizations={@user_organizations}>
      <section class="vt-page-intro" data-testid="app-account-home">
        <header class="vt-panel__header">
          <div>
            <p class="vt-kicker">Your Tasklane account</p>
            <h1 class="vt-panel__title">Welcome back, {@greeting_name}</h1>
          </div>
        </header>
      </section>
    </Layouts.app>

Adapt to the approved twin root/hook, assigning data-twin-ready only after current-account bootstrap. Use semantic headings/panels, native audio, form and ordered receipt list. Never render raw partition, checksum, cookie, or mutation ID.

### test/example/lib/example_web/controllers/learning_twin_controller.ex (controller, request-response)

**Analog:** test/example/lib/example_web/controllers/crosswake_controller.ex (lines 1-18, 69-90).

    defmodule ExampleWeb.CrosswakeController do
      use ExampleWeb, :controller
      alias Example.Accounts.CrosswakeContinuations

      def start(conn, _params) do
        case CrosswakeContinuations.issue(get_session(conn, :user_token), DateTime.utc_now()) do
          {:ok, values} -> conn |> put_status(:see_other) |> redirect(to: "/crosswake/return?...")
          {:error, _reason} -> deny(conn, :session_unavailable)
        end
      end
    end

Keep controllers thin: derive conn.assigns.current_scope, validate scalar inputs, delegate to the host context, and return stable response errors. Do not select owner from JSON or provide a browser credential to JS/SW.

### test/example/lib/example_web/router.ex (route, request-response)

**Analog:** existing authenticated /app scope, lines 1-14 and 113-128.

    pipeline :browser do
      plug :accepts, ["html"]
      plug :fetch_session
      plug :protect_from_forgery
      plug :put_secure_browser_headers
      plug :fetch_current_scope
    end

    scope "/", ExampleWeb do
      pipe_through [:browser, :require_authenticated]

      live_session :app_authenticated,
        on_mount: [{ExampleWeb.UserAuth, :ensure_authenticated}] do
        live "/app", AppLive, :home
      end
    end

Place the lesson LiveView plus bootstrap/manifest/replay browser endpoints behind this same pipeline. Preserve CSRF and Scope loading; do not introduce a bearer-token API path.

### Migration (migration, CRUD)

**Analog:** test/example/priv/repo/migrations/20260811170000_create_crosswake_continuations.exs (lines 1-31).

    def change do
      create table(:crosswake_continuations, Keyword.merge(@prefix_opts, primary_key: false)) do
        add(:id, :binary_id, primary_key: true)
        add(:expires_at, :utc_datetime_usec, null: false)
        add(:outcome, :string)
        timestamps(type: :utc_datetime)
      end

      create(unique_index(:crosswake_continuations, [:handle_digest], @prefix_opts))
      create(index(:crosswake_continuations, [:expires_at], @prefix_opts))
    end

Create host-owned lease/receipt tables, a durable replay-identity unique index, and account/expiry indexes. Commit the terminal receipt before responding.

### test/example/priv/static/assets/js/learning_twin.js (utility, file-I/O / event-driven)

**Partial analog:** test/example/priv/static/assets/js/app.js (lines 8971-8990).

    var csrfMeta = document.querySelector("meta[name='csrf-token']");
    var csrfToken = csrfMeta ? csrfMeta.getAttribute("content") : null;
    var liveSocket = new LiveView.LiveSocket("/live", Phoenix.Socket, {
      hooks: { /* named, bounded hooks */ },
      params: { _csrf_token: csrfToken },
    });
    liveSocket.connect();
    window.liveSocket = liveSocket;

Use this static-asset convention and one named bounded hook/runtime. It may use the CSRF meta tag for same-origin protection only; it must never read/copy HttpOnly cookies, session tokens, raw partitions, cache bytes, or digests into window/hook/test messages.

### test/example/priv/static/assets/js/learning_twin_worker.js (worker, file-I/O / event-driven)

**No codebase analog. Use RESEARCH.md Pattern 1.** Fetch complete bytes, exact-size check, SHA-256 using crypto.subtle.digest, create a new Response, await Cache.put, then write the partitioned IndexedDB marker last. Readers require current matching partition + unexpired lease + marker + cache entry. The worker protocol exposes only bounded readiness/outcome/failure acknowledgements.

### test/example/priv/static/assets/css/app.css (stylesheet config, transform)

**Analog:** Tasklane rules in the same file (lines 554-559, 630-642, 1104-1107).

    .vt-card-grid {
      display: grid;
      gap: var(--sg-space-3);
    }

    .vt-panel__header {
      display: flex;
      flex-wrap: wrap;
      justify-content: space-between;
      gap: var(--sg-space-3);
      margin-bottom: var(--sg-space-4);
    }

    .vt-page-intro {
      display: grid;
      gap: var(--sg-space-4);
    }

Append only BEM-scoped vt-twin-* rules in current style order. Reuse vt-* and --sg-*, preserve light/dark/system, and do not add admin sg-* markup, a second system, Tailwind, or inline visual styles.

### LiveView and ExUnit tests

**LiveView analog:** test/example/test/example_web/live/app_live_test.exs (lines 1-68).

    use ExampleWeb.ConnCase, async: true
    import Phoenix.LiveViewTest
    import Example.AccountsFixtures

    test "redirects unauthenticated visitors to the login page", %{conn: conn} do
      assert {:error, {:redirect, %{to: path}}} = live(conn, ~p"/app")
      assert path =~ "/users/log_in"
    end

    {:ok, _lv, html} = live(conn, ~p"/app")
    assert html =~ "app-account-home"

**Context/controller analog:** test/example/test/example_web/controllers/crosswake_controller_test.exs (lines 1-25, 89-148). Use deterministic fixtures and direct request/assertion helpers. Cover lease/partition expiry, account switch, CSRF/current-owner derivation, no credential-bearing bootstrap/worker data, concurrent/duplicate exactly-once replay, and rejected/conflict outcomes.

### test/example/priv/playwright/tests/twin-offline.spec.ts (browser integration test)

**Readiness analog:** demo-showcase.spec.ts lines 134-138.

    async function waitForLiveViewReady(page: Page) {
      await page.waitForSelector("[data-phx-session].phx-connected", {
        state: "attached",
      });
    }

**Pre-armed wait and role selector analog:** crosswake-hosted-runtime.spec.ts lines 24-40.

    const appRequest = page.waitForRequest((request) => {
      const url = new URL(request.url());
      return request.method() === 'GET' && request.resourceType() === 'document' && url.pathname === '/app';
    });

    await expect(page.getByRole('button', { name: 'Continue to Crosswake' })).toBeVisible();
    await page.getByRole('button', { name: 'Continue to Crosswake' }).click();
    await appRequest;

First wait for connected LiveView and the twin readiness hook. Use roles for visible controls and only approved stable hooks for storage/worker proof. Pre-arm worker/request/response waits, use browserContext.setOffline, inspect Cache Storage and IndexedDB directly, and test valid/short/corrupt/write-failure/offline/expiry/logout/switch/reconnect/duplicate/rejected/conflict. No sleeps, timing guesses, raw cookies, raw partition/checksum/media values, or visual-only assertions.

### Immutable media (static media, file-I/O)

**No analog found.** Add one versioned immutable image and one audio file with expected byte size/SHA-256 recorded by the host manifest. Cache bytes can remain physically present only when account metadata and a valid matching lease make them unreachable otherwise.

## Shared Patterns

### Authentication and Scope

**Sources:** router.ex lines 1-14, 113-128; user_auth.ex lines 177-184, 328-342, 412-422.

    def fetch_current_scope(conn, _opts) do
      {user_token, conn} = ensure_user_token(conn)
      {conn, _user, session, scope} = load_current_scope(conn, user_token)
      conn |> put_private(:sigra_session, session) |> assign(:current_scope, scope)
    end

    if socket.assigns.current_scope do
      {:cont, socket}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/users/log_in")}
    end

Apply to every lesson/bootstrap/replay boundary. Browser storage or client lease never authenticates replay.

### Failure handling and durable outcomes

**Source:** crosswake_continuations.ex lines 21-60, 121-139. Use guarded public functions and stable explicit errors. A failed fetch/read/digest/cache/IndexedDB operation has no ready marker; replay returns an existing persistent terminal receipt or one newly persisted terminal receipt.

### Tasklane UI and deterministic proof

**Sources:** app_live.ex lines 42-174; app.css lines 554-559, 630-642, 1104-1154; Playwright sources above. Reuse Layouts.app, vt-page-intro, vt-panel, vt-panel__header, vt-card-grid, vt-btn, vt-status-pill, vt-copy, and vt-kicker. Use one h1/mapped h2s, text status plus semantic state, native audio/transcript, and role selectors before stable hooks. Wait on LiveView/readiness—not elapsed time.

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| priv/static/assets/js/learning_twin_worker.js | worker | file-I/O / event-driven | No service-worker, Cache Storage, IndexedDB, or integrity-promotion implementation exists. |
| priv/static/assets/media/twin-market-morning.{svg,ogg} | static media | file-I/O | No bounded lesson-media asset/manifest pattern exists. |
| integrity/cache/IndexedDB helper portion of learning_twin.js | utility | file-I/O | Browser storage protocol is Phase 247’s first implementation. |

## Metadata

**Analog search scope:** test/example/lib, test/example/test, test/example/priv/static, test/example/priv/playwright, test/example/priv/repo/migrations, vendored Crosswake.  
**Files scanned:** 15 primary analog/config/test files.  
**Pattern extraction date:** 2026-08-18.

