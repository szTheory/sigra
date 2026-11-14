defmodule ExampleWeb.EnumerationParityTest do
  @moduledoc """
  Enumeration-boundary parity harness for the pre-auth surfaces (BCOPY-03).

  The registry `test/fixtures/brand/public-surfaces.json` names every pre-auth
  surface and the state it is asserted in:

    * `parity` - the SAME request for an existing identity and an unknown
      identity must compare `:same` on the dimensions the row lists.
    * `known_divergence` - the two responses are known to differ today. The test
      asserts they STILL differ, so fixing the product forces the registry row
      to be removed or changed (shrink discipline).
    * `by_design` - the documented behaviour is asserted.
    * `not_proven` - no assertion exists; the row cites the file:line that
      prevents a deterministic probe.

  One pure comparator (`compare/3`) returns `:same` or `{:diff, details}`. The
  only normalization is CSRF tokens, request ids and the echoed email; it is
  never loosened to hide a real difference.

  A positive control (`run_all/2` with `leak: {surface_id, text}`) appends a
  deliberately leaky string to the unknown-identity response of exactly one
  surface and proves the harness goes red exactly once. The leak lives in this
  test module only; there is no leak switch in app code.

  ## What this does NOT prove

  These tests run in the example host (`test/example`), a hand-maintained copy
  of the generated host that already drifts from the generated templates. Only
  `install_smoke` proves a generated host. A `parity` row is bounded to the
  dimensions it lists, for one request, and is not a claim that a surface is
  enumeration-safe in general (timing, repeat attempts and account states that
  are not listed are not compared).
  """
  use ExampleWeb.ConnCase, async: false

  import Example.AccountsFixtures
  import Phoenix.LiveViewTest

  @moduletag :example_app

  @registry_path Path.expand("../../../fixtures/brand/public-surfaces.json", __DIR__)
  # __DIR__ is <root>/test/example/test/example_web: four levels up is the repo root.
  @repo_root Path.expand("../../../..", __DIR__)
  @schema_version "sigra.brand-public-surfaces/v1"
  @states ~w(parity known_divergence by_design not_proven)
  @kinds ~w(controller liveview json library)
  @row_keys ~w(id route kind compare state note todo blocker)
  @dimensions %{
    "status" => :status,
    "redirect" => :location,
    "flash" => :flash,
    "body" => :body,
    "json_keys" => :json_keys
  }
  @leak_text "No account found for"
  @blocker_shape ~r/[\w.\/-]+:\d+/
  @citation_shape ~r/([\w.\/-]+\.\w+):(\d+)/
  # BCOPY-03 requires these five surfaces by name; each is parity or, only where
  # the example host cannot drive it, not_proven with a path:line blocker.
  @named_parity_ids ~w(password-signin magic-link-request password-reset-request confirmation-resend mfa-challenge)
  # A LiveView event has no HTTP status; "re-rendered in place" is reported as 200.
  @live_render_status 200

  # ---------------------------------------------------------------------------
  # Registry
  # ---------------------------------------------------------------------------

  describe "registry" do
    test "decodes, carries the example-host limitation and every row is well formed" do
      registry = registry()

      assert registry["schema_version"] == @schema_version
      assert is_binary(registry["note"])
      assert registry["note"] =~ "hand-maintained copy of the generated host"
      assert registry["note"] =~ "install_smoke"

      rows = registry["surfaces"]
      assert is_list(rows) and rows != []

      for row <- rows do
        id = inspect(row["id"])

        for key <- @row_keys do
          assert Map.has_key?(row, key), "row #{id} is missing key #{key}"
        end

        assert is_binary(row["id"]) and row["id"] != "", "row #{id} needs a string id"
        assert is_binary(row["route"]) and row["route"] != "", "row #{id} needs a route"
        assert row["kind"] in @kinds, "row #{id} has kind #{inspect(row["kind"])}"
        assert row["state"] in @states, "row #{id} has state #{inspect(row["state"])}"
        assert is_binary(row["note"]) and row["note"] != "", "row #{id} needs a note"
        assert is_list(row["compare"]), "row #{id} compare must be a list"

        for dimension <- row["compare"] do
          assert Map.has_key?(@dimensions, dimension),
                 "row #{id} compares unknown dimension #{inspect(dimension)}"
        end

        if row["state"] in ~w(parity known_divergence by_design) do
          assert row["compare"] != [], "row #{id} asserts a state but lists no dimension"
        end

        assert is_nil(row["todo"]) or is_binary(row["todo"]),
               "row #{id} todo must be null or a path string"

        assert_blocker_rule(row)
      end

      ids = Enum.map(rows, & &1["id"])
      assert ids == Enum.uniq(ids), "registry ids must be unique"
    end

    test "the five named parity surfaces exist, downgrades carry a blocker, at least three are parity" do
      by_id = Map.new(surfaces(), &{&1["id"], &1})

      named =
        for id <- @named_parity_ids do
          assert Map.has_key?(by_id, id), "named surface #{id} is missing from the registry"
          Map.fetch!(by_id, id)
        end

      for row <- named do
        assert row["state"] in ~w(parity not_proven),
               "named surface #{row["id"]} may only be parity or not_proven, got #{row["state"]}"

        if row["state"] == "not_proven" do
          assert is_binary(row["blocker"]) and row["blocker"] =~ @blocker_shape,
                 "named surface #{row["id"]} is not_proven without a path:line blocker"
        end
      end

      assert Enum.count(named, &(&1["state"] == "parity")) >= 3,
             "at least three of the five named surfaces must be parity"
    end

    test "every blocker citation points at a real file and an existing line" do
      for %{"id" => id, "blocker" => blocker} when is_binary(blocker) <- surfaces() do
        citations = Regex.scan(@citation_shape, blocker)
        assert citations != [], "#{id}: blocker holds no path:line citation"

        for [_whole, path, line] <- citations do
          full = Path.join(@repo_root, path)
          assert File.regular?(full), "#{id}: blocker cites #{path}, which does not exist"

          line_count = full |> File.read!() |> String.split("\n") |> length()

          assert String.to_integer(line) in 1..line_count//1,
                 "#{id}: blocker cites #{path}:#{line}, beyond the #{line_count} lines in the file"
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Comparator and normalization (pure)
  # ---------------------------------------------------------------------------

  describe "comparator" do
    test "returns :same for equal normalized responses" do
      a = response(status: 302, location: "/users/log_in", flash: %{"error" => "x"}, body: "b")
      b = response(status: 302, location: "/users/log_in", flash: %{"error" => "x"}, body: "b")

      assert compare(a, b, all_dimensions()) == :same
    end

    test "returns {:diff, details} naming the dimension for a planted difference" do
      a = response(flash: %{"error" => "Invalid email or password"})
      b = response(flash: %{"error" => "No account found for that email"})

      assert {:diff, [{:flash, left, right}]} = compare(a, b, all_dimensions())
      assert left == %{"error" => "Invalid email or password"}
      assert right == %{"error" => "No account found for that email"}
    end

    test "compares only the dimensions the registry row lists" do
      a = response(status: 302, body: "same")
      b = response(status: 200, body: "same")

      assert compare(a, b, [:body]) == :same
      assert {:diff, [{:status, 302, 200}]} = compare(a, b, [:status, :body])
    end
  end

  describe "normalization" do
    test "replaces only CSRF tokens, request ids and the echoed email" do
      email = "person-1@example.com"

      raw =
        ~s(<meta name="csrf-token" content="abc123XYZ"> ) <>
          ~s(<input name="_csrf_token" type="hidden" hidden value="zzz999QQQ"> ) <>
          ~s(<input type="email" value="#{email}"> ) <>
          ~s(request_id=F9xk2Lw0aBcDeF12 ) <>
          "No account found for #{email}"

      normalized = normalize(response(body: raw), email).body

      assert normalized =~ ~s(content="{{CSRF}}")
      assert normalized =~ ~s(value="{{CSRF}}")
      assert normalized =~ ~s(value="{{EMAIL}}")
      assert normalized =~ "request_id={{REQUEST_ID}}"
      refute normalized =~ "abc123XYZ"
      refute normalized =~ "zzz999QQQ"
      refute normalized =~ email
      # A real difference survives normalization: only the email inside the
      # sentence is replaced, the leaky wording is not hidden.
      assert normalized =~ "No account found for {{EMAIL}}"
    end

    test "does not hide a difference in unrelated content" do
      email = "person-2@example.com"
      a = normalize(response(body: "Invalid email or password"), email)
      b = normalize(response(body: "Invalid email or password. Account locked."), email)

      assert {:diff, [{:body, _, _}]} = compare(a, b, all_dimensions())
    end
  end

  # ---------------------------------------------------------------------------
  # Surfaces: parity, positive control
  # ---------------------------------------------------------------------------

  describe "parity surfaces" do
    test "every parity row compares :same for an existing versus an unknown identity" do
      results = run_all(registry())
      parity_ids = for %{"state" => "parity", "id" => id} <- surfaces(), do: id

      assert Enum.sort(Enum.map(results, &elem(&1, 0))) == Enum.sort(parity_ids)

      failures = for {id, {:diff, details}} <- results, do: "#{id}: #{inspect_diff(details)}"
      assert failures == [], "parity rows differ:\n" <> Enum.join(failures, "\n")
    end
  end

  describe "positive control" do
    test "a leak on exactly one parity surface yields exactly one diff, the others stay :same" do
      registry = registry()

      clean = run_all(registry)
      assert clean != []
      assert Enum.all?(clean, fn {_id, result} -> result == :same end)

      leaked = run_all(registry, leak: {"password-signin", @leak_text})
      diffs = for {id, {:diff, details}} <- leaked, do: {id, details}

      assert [{"password-signin", details}] = diffs, "expected one diff, got: #{inspect(diffs)}"
      assert Enum.any?(details, &match?({:body, _, _}, &1))
      assert Enum.any?(details, &match?({:flash, _, _}, &1))

      # Non-vacuity: "the others stay same" must be about real rows, never an
      # empty list. The named-surface rule guarantees at least three parity rows.
      others = for {id, result} <- leaked, id != "password-signin", do: {id, result}
      assert length(others) >= 2, "vacuous control: fewer than two other parity rows"
      assert Enum.all?(others, fn {_id, result} -> result == :same end)
    end

    test "every parity surface can go red: leaking any one yields exactly that one diff" do
      registry = registry()
      parity_ids = for %{"state" => "parity", "id" => id} <- registry["surfaces"], do: id
      assert length(parity_ids) >= 3

      for id <- parity_ids do
        leaked = run_all(registry, leak: {id, @leak_text})
        diffs = for {surface, {:diff, _} = diff} <- leaked, do: {surface, diff}

        assert [{^id, _}] = diffs,
               "leaking #{id} should produce exactly one diff at #{id}, got: #{inspect(diffs)}"
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Harness
  # ---------------------------------------------------------------------------

  defp registry, do: @registry_path |> File.read!() |> JSON.decode!()
  defp surfaces, do: registry()["surfaces"]
  defp all_dimensions, do: Map.values(@dimensions)

  defp dimensions(row), do: Enum.map(row["compare"], &Map.fetch!(@dimensions, &1))

  defp assert_blocker_rule(%{"state" => "not_proven"} = row) do
    id = inspect(row["id"])

    assert is_binary(row["blocker"]) and row["blocker"] =~ @blocker_shape,
           "not_proven row #{id} needs a path:line blocker citation, got #{inspect(row["blocker"])}"
  end

  defp assert_blocker_rule(row) do
    assert is_nil(row["blocker"]), "only a not_proven row may carry a blocker (#{row["id"]})"
  end

  # Runs every parity row. `leak: {surface_id, text}` appends `text` to the
  # unknown-identity response of that one surface only (test-only control).
  defp run_all(registry, opts \\ []) do
    leak = Keyword.get(opts, :leak)

    for %{"state" => "parity"} = row <- registry["surfaces"] do
      existing = probe(row["id"], :existing)
      unknown = probe(row["id"], :unknown) |> maybe_leak(row["id"], leak)

      {row["id"], compare(existing, unknown, dimensions(row))}
    end
  end

  defp maybe_leak(response, id, {id, text}), do: leak(response, text)
  defp maybe_leak(response, _id, _leak), do: response

  defp leak(response, text) do
    %{
      response
      | body: response.body <> "\n" <> text,
        flash: Map.put(response.flash, "leak", text),
        json_keys: response.json_keys && response.json_keys ++ [text]
    }
  end

  # Pure comparator: :same | {:diff, [{dimension, left, right}]}.
  defp compare(left, right, dimensions) do
    diffs =
      for dimension <- dimensions,
          Map.fetch!(left, dimension) != Map.fetch!(right, dimension) do
        {dimension, Map.fetch!(left, dimension), Map.fetch!(right, dimension)}
      end

    if diffs == [], do: :same, else: {:diff, diffs}
  end

  defp response(attrs) do
    Map.merge(
      %{status: 200, location: nil, flash: %{}, body: "", json_keys: nil},
      Map.new(attrs)
    )
  end

  defp inspect_diff(details), do: inspect(details, limit: 8, printable_limit: 240)

  # --- identities -------------------------------------------------------------

  # :existing is a real registered account; :unknown is an address never stored.
  defp identity_email(:existing), do: user_fixture().email
  defp identity_email(:unknown), do: unique_user_email()

  # --- probes -----------------------------------------------------------------

  defp probe("password-signin", identity) do
    email = identity_email(identity)

    build_conn()
    |> post(~p"/users/log_in", %{"user" => %{"email" => email, "password" => "wrong-password"}})
    |> capture_redirect(email)
  end

  defp probe("magic-link-request", identity) do
    email = identity_email(identity)

    build_conn()
    |> post(~p"/users/log_in", %{"_action" => "magic_link", "user" => %{"email" => email}})
    |> capture_redirect(email)
  end

  # Identity here is the code KIND: a wrong authenticator code (:existing)
  # versus a wrong backup code (:unknown), each for a freshly enrolled user
  # with an MFA-pending session.
  defp probe("mfa-challenge", identity) do
    %{user: user, totp_secret: secret} = mfa_pending_session_fixture()

    conn =
      build_conn()
      |> log_in_user(user, type: :mfa_pending)
      |> put_session(:mfa_pending, true)

    {:ok, view, _html} = live(conn, ~p"/users/mfa")

    result =
      case identity do
        :existing ->
          view
          |> form("#mfa_totp_form", mfa: %{code: wrong_totp_code(secret)})
          |> render_submit()

        :unknown ->
          render_click(view, "show_backup")
          view |> form("#mfa_backup_form", mfa: %{code: "AAAA-BBBB"}) |> render_submit()
      end

    capture_live(view, result, user.email)
  end

  defp probe(id, _identity), do: raise(ArgumentError, "no probe defined for surface #{id}")

  # A well-formed 6-digit code that is outside the +/-1 step drift window, so
  # the probe is deterministic.
  defp wrong_totp_code(secret) do
    now = System.os_time(:second)

    valid =
      for offset <- -90..90//30, do: NimbleTOTP.verification_code(secret, time: now + offset)

    Enum.find(~w(000000 111111 222222), &(&1 not in valid))
  end

  # Captures a controller redirect response: the POST status, location and
  # server-side flash map, plus the page the redirect lands on.
  defp capture_redirect(conn, email) do
    location = redirected_to(conn)
    followed = conn |> recycle() |> get(location)

    normalize(
      response(
        status: conn.status,
        location: location,
        flash: conn.assigns.flash,
        body: html_response(followed, 200)
      ),
      email
    )
  end

  # Captures an in-place LiveView re-render. A LiveView event has no HTTP status
  # and the views here do not render their flash in their own markup, so the
  # flash is read from the LiveView process state (test-only introspection).
  # Anything other than a re-render (a redirect tuple) fails loudly.
  defp capture_live(view, html, email) when is_binary(html) do
    flash = :sys.get_state(view.pid).socket.assigns.flash

    normalize(
      response(status: @live_render_status, location: nil, flash: flash, body: html),
      email
    )
  end

  defp capture_live(_view, other, _email) do
    flunk("expected an in-place LiveView re-render, got: #{inspect(other, limit: 5)}")
  end

  # --- normalization ------------------------------------------------------------

  # Normalizes ONLY CSRF tokens, request ids and the echoed email.
  defp normalize(response, email) do
    %{
      response
      | location: normalize_text(response.location, email),
        flash:
          Map.new(response.flash, fn {key, value} -> {key, normalize_text(value, email)} end),
        body: normalize_text(response.body, email)
    }
  end

  defp normalize_text(text, email) when is_binary(text) do
    text
    |> replace_email(email)
    |> then(
      &Regex.replace(
        ~r/(name="_?csrf[-_]token"[^>]*?(?:value|content)=")[^"]*"/,
        &1,
        "\\1{{CSRF}}\""
      )
    )
    |> then(&Regex.replace(~r/(data-csrf=")[^"]*"/, &1, "\\1{{CSRF}}\""))
    |> then(
      &Regex.replace(
        ~r/(request[-_]id["']?\s*[:=]\s*["']?)[A-Za-z0-9_=-]{8,}/i,
        &1,
        "\\1{{REQUEST_ID}}"
      )
    )
  end

  defp normalize_text(other, _email), do: other

  defp replace_email(text, email) do
    text
    |> String.replace(email, "{{EMAIL}}")
    |> String.replace(Plug.HTML.html_escape(email), "{{EMAIL}}")
    |> String.replace(URI.encode_www_form(email), "{{EMAIL}}")
  end
end
