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
  test module only; there is no leak switch in app code. That control proves the
  comparator detects a difference; it cannot prove a probe observes the real
  response, because the leak is applied after the response was captured.

  A second rule closes that gap: a `parity` row must not be empty-versus-empty.
  Each parity probe must capture a non-empty value for every content dimension
  (`flash`, `body`) its row lists, and the flash it captures is asserted against
  the message the surface really shows. If a probe stopped observing its surface
  (a LiveView assign moved, a redirect stopped carrying its flash), both sides
  would capture the same empty value and compare `:same`; this rule turns that
  into a failure.

  ## The five named surfaces

  BCOPY-03 names five surfaces and all five are `parity` rows. They are three
  different kinds of probe and are counted apart (`named_surface_violations/1`
  judges each id on its own, so no total can hide a failure):

    * account-existence: `password-signin`, `magic-link-request` and
      `password-reset-request` compare an address that has an account against one
      that has none. These are the enumeration probes proper; each must be
      `parity` with no blocker.
    * payload-ignored: `confirmation-resend` proves that an email a visitor puts in
      the resend event payload is ignored. No email-keyed resend form exists, so it
      is not an account-existence probe.
    * code-kind: `mfa-challenge` compares a wrong authenticator code with a wrong
      backup code. Its identity is the code kind, not account existence.

  The last two stay green and are real probes, but neither can satisfy or stand in
  for an account-existence surface. Planted controls in the "registry" tests prove
  each rule can fail.

  ## What this does NOT prove

  These tests run in the example host (`test/example`), a hand-maintained copy
  of the generated host that already drifts from the generated templates. Only
  `install_smoke` proves a generated host. A `parity` row is bounded to the
  dimensions it lists, for one request, and is not a claim that a surface is
  enumeration-safe in general (timing, repeat attempts and account states that
  are not listed are not compared).
  """
  use ExampleWeb.ConnCase, async: false

  import Ecto.Query, only: [from: 2]
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
    "json_keys" => :json_keys,
    "result" => :result
  }
  @leak_text "No account found for"
  @blocker_shape ~r/[\w.\/-]+:\d+/
  @citation_shape ~r/([\w.\/-]+\.\w+):(\d+)/
  # BCOPY-03 requires these five surfaces by name, and every one is a parity row.
  # They are three different kinds of probe and are judged apart, never pooled:
  #
  #   * account-existence ids vary whether the submitted address has an account. Only
  #     these three are enumeration probes in the strict sense.
  #   * payload-ignored ids prove a value a visitor puts in an event payload is
  #     ignored (the resend handler never reads its params).
  #   * code-kind ids vary which authenticator was used (a wrong authenticator code
  #     versus a wrong backup code), not whether an account exists.
  #
  # The last two are counted separately and can never stand in for an
  # account-existence surface (see named_surface_violations/1).
  @account_existence_ids ~w(password-signin magic-link-request password-reset-request)
  @payload_ignored_ids ~w(confirmation-resend)
  @code_kind_ids ~w(mfa-challenge)
  @named_parity_ids @account_existence_ids ++ @payload_ignored_ids ++ @code_kind_ids
  # Phrases the registry notes of the two separately counted classes must keep, so a
  # note cannot drift into claiming what its probe does not prove.
  @payload_note_phrases ["payload", "email-keyed resend form"]
  @code_kind_note_phrases ["code kind", "not account existence"]
  # A LiveView event has no HTTP status; "re-rendered in place" is reported as 200.
  @live_render_status 200
  # ...and a server `redirect` outcome from a LiveView event is reported as 302.
  @live_redirect_status 302
  # The dimensions that carry what the user is shown. Status and redirect are constants
  # for some surfaces (a LiveView re-render is always 200 with no redirect), so they
  # cannot show that a probe observed anything.
  @content_dimensions [:flash, :body]

  # The leaks that exist today. None of them may ever be registered as parity.
  @named_leak_ids ~w(passkey-signin-options registration password-signin-repeat-attempts magic-link-rate-limit password-reset-rate-limit)

  # The exact todo path each row carries (single path per row, every other row
  # null). Plan 259-13 asserts the three new files exist, Plan 259-17 the fourth
  # (the generated reset page); this test only fixes the strings, so it stays
  # green on its own.
  @expected_todos %{
    "passkey-signin-options" =>
      ".planning/todos/pending/2026-11-13-passkey-options-email-existence-oracle.md",
    "password-reset-request" =>
      ".planning/todos/pending/2026-11-14-generated-reset-request-page-mount-and-user-struct-call.md",
    "password-signin-repeat-attempts" =>
      ".planning/todos/pending/2026-11-13-lockout-and-rate-limit-enumeration-channels.md",
    "magic-link-rate-limit" =>
      ".planning/todos/pending/2026-11-13-lockout-and-rate-limit-enumeration-channels.md",
    "password-reset-rate-limit" =>
      ".planning/todos/pending/2026-11-13-lockout-and-rate-limit-enumeration-channels.md",
    "lib-moduledoc-claims" =>
      ".planning/todos/pending/2026-11-13-lib-moduledoc-enumeration-overclaims.md",
    "registration" =>
      ".planning/todos/pending/2026-11-13-duplicate-registration-timing-oracle.md",
    "confirmation-resend" =>
      ".planning/todos/pending/2026-09-15-generated-confirm-routes-unreachable-both-session-states.md"
  }

  # The four fix-tracking todos filed for the known divergences, the deferred
  # library over-claims and the generated host's reset request page (a parity row
  # here covers the example host only). Named here independently of
  # @expected_todos so that a registry edit which drops a reference to one of them
  # goes red.
  @new_todo_paths [
    ".planning/todos/pending/2026-11-13-passkey-options-email-existence-oracle.md",
    ".planning/todos/pending/2026-11-13-lockout-and-rate-limit-enumeration-channels.md",
    ".planning/todos/pending/2026-11-13-lib-moduledoc-enumeration-overclaims.md",
    ".planning/todos/pending/2026-11-14-generated-reset-request-page-mount-and-user-struct-call.md"
  ]

  # Dimensions on which each known divergence differs today. Asserted exactly, so
  # a partial fix also forces the registry row to be updated.
  @expected_divergence_dims %{
    "registration" => [:body, :flash],
    "passkey-signin-options" => [:json_keys],
    "password-signin-repeat-attempts" => [:result]
  }

  # by_design rows that have a documented-behaviour assertion below.
  @by_design_ids ~w(invitation-accept enterprise-sso-discovery)

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

    test "every named surface is parity with no blocker, each judged in its own class" do
      by_id = Map.new(surfaces(), &{&1["id"], &1})

      assert named_surface_violations(by_id) == []
    end

    test "a not_proven account-existence surface with a valid blocker is reported (control)" do
      by_id = Map.new(surfaces(), &{&1["id"], &1})
      planted = downgrade(by_id, "password-reset-request")

      # The shape the previous rule accepted: not_proven plus a path:line blocker.
      assert planted["password-reset-request"]["state"] == "not_proven"
      assert planted["password-reset-request"]["blocker"] =~ @blocker_shape

      violations = named_surface_violations(planted)

      assert violated_ids(violations) == ["password-reset-request"]
      assert Enum.any?(violations, &(&1 =~ "must be parity"))
      assert Enum.any?(violations, &(&1 =~ "blocker"))
    end

    test "the payload-ignored and code-kind rows never satisfy an account-existence surface (control)" do
      by_id = Map.new(surfaces(), &{&1["id"], &1})

      # password-reset-request not_proven while confirmation-resend and mfa-challenge
      # stay parity: the failure is reported at the account-existence id.
      planted = downgrade(by_id, "password-reset-request")
      assert planted["confirmation-resend"]["state"] == "parity"
      assert planted["mfa-challenge"]["state"] == "parity"
      assert violated_ids(named_surface_violations(planted)) == ["password-reset-request"]

      # Only mfa-challenge parity among the five: every other named id is reported
      # and mfa-challenge itself is not what rescues the registry.
      only_mfa =
        Enum.reduce(@named_parity_ids -- ["mfa-challenge"], by_id, &downgrade(&2, &1))

      assert violated_ids(named_surface_violations(only_mfa)) ==
               Enum.sort(@named_parity_ids -- ["mfa-challenge"])

      # Only confirmation-resend parity among the five: same.
      only_resend =
        Enum.reduce(@named_parity_ids -- ["confirmation-resend"], by_id, &downgrade(&2, &1))

      assert violated_ids(named_surface_violations(only_resend)) ==
               Enum.sort(@named_parity_ids -- ["confirmation-resend"])
    end

    test "a confirmation-resend note that drops a guard phrase is reported (control)" do
      by_id = Map.new(surfaces(), &{&1["id"], &1})

      for phrase <- @payload_note_phrases do
        planted =
          update_note(by_id, "confirmation-resend", &String.replace(&1, phrase, "(removed)"))

        refute planted["confirmation-resend"]["note"] =~ phrase,
               "setup: #{phrase} was not removed"

        violations = named_surface_violations(planted)

        assert violated_ids(violations) == ["confirmation-resend"]
        assert Enum.any?(violations, &(&1 =~ phrase))
      end
    end

    test "an mfa-challenge note that no longer says code kind is reported (control)" do
      by_id = Map.new(surfaces(), &{&1["id"], &1})

      for phrase <- @code_kind_note_phrases do
        planted = update_note(by_id, "mfa-challenge", &String.replace(&1, phrase, "(removed)"))
        refute planted["mfa-challenge"]["note"] =~ phrase, "setup: #{phrase} was not removed"

        violations = named_surface_violations(planted)

        assert violated_ids(violations) == ["mfa-challenge"]
        assert Enum.any?(violations, &(&1 =~ phrase))
      end
    end

    test "a registry missing a named id is reported as missing (control)" do
      by_id = Map.new(surfaces(), &{&1["id"], &1})

      for id <- @named_parity_ids do
        violations = by_id |> Map.delete(id) |> named_surface_violations()

        assert violated_ids(violations) == [id]
        assert Enum.any?(violations, &(&1 =~ "missing"))
      end
    end

    test "the leaks that exist today are never registered as parity" do
      by_id = Map.new(surfaces(), &{&1["id"], &1})

      for id <- @named_leak_ids do
        assert Map.has_key?(by_id, id), "leak row #{id} is missing from the registry"

        assert by_id[id]["state"] != "parity",
               "#{id} is a known leak and must not be registered as parity"

        assert by_id[id]["state"] in ~w(known_divergence not_proven)
      end
    end

    test "rows carry exactly the fixed todo paths, every other row carries null" do
      rows = surfaces()

      for row <- rows do
        assert row["todo"] == Map.get(@expected_todos, row["id"]),
               "row #{row["id"]} todo is #{inspect(row["todo"])}, expected " <>
                 inspect(Map.get(@expected_todos, row["id"]))
      end

      ids = Enum.map(rows, & &1["id"])

      for id <- Map.keys(@expected_todos) do
        assert id in ids, "row #{id} (which carries a todo) is missing from the registry"
      end
    end

    test "every non-null registry todo path is a real file, and the four new todos are referenced" do
      todos = for %{"todo" => todo} when is_binary(todo) <- surfaces(), do: todo

      assert todos != [], "no registry row carries a todo path"

      assert missing_files(todos) == [],
             "registry todo paths that are not files under the repo root: " <>
               inspect(missing_files(todos))

      for path <- @new_todo_paths do
        assert path in todos, "no registry row references the todo #{path}"
      end
    end

    test "the todo-path helper reports a planted fake path and a directory (control)" do
      real = "test/fixtures/brand/public-surfaces.json"
      fake = ".planning/todos/pending/2026-11-13-this-todo-was-never-filed.md"
      directory = ".planning/todos/pending"

      assert missing_files([real]) == []
      assert missing_files([real, fake, real]) == [fake]
      assert missing_files([fake, directory]) == [fake, directory]
      # An absolute path is not a repo-relative todo path, even when it exists.
      assert missing_files([Path.join(@repo_root, real)]) == [Path.join(@repo_root, real)]
    end

    test "the library-claims row is a not_proven library row with no probe dimensions" do
      row = Enum.find(surfaces(), &(&1["id"] == "lib-moduledoc-claims"))

      assert row["kind"] == "library"
      assert row["state"] == "not_proven"
      assert row["compare"] == []
      assert row["blocker"] =~ "lib/sigra/lockout.ex:13"
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
          ~s(<div id="phx-GOf2PoyjnnHHrwZD" data-phx-session="SFMyNTY.abc" data-phx-static="SFMyNTY.def"> ) <>
          ~s(<form id="login_form"> ) <>
          ~s(request_id=F9xk2Lw0aBcDeF12 ) <>
          "No account found for #{email}"

      normalized = normalize(response(body: raw), email).body

      assert normalized =~ ~s(content="{{CSRF}}")
      assert normalized =~ ~s(value="{{CSRF}}")
      assert normalized =~ ~s(value="{{EMAIL}}")
      assert normalized =~ "request_id={{REQUEST_ID}}"
      # LiveView per-mount ids and session/static tokens are request-scoped
      # identifiers; every other id and attribute is left alone.
      assert normalized =~ ~s(id="phx-{{REQUEST_ID}}")
      assert normalized =~ ~s(data-phx-session="{{REQUEST_ID}}")
      assert normalized =~ ~s(data-phx-static="{{REQUEST_ID}}")
      assert normalized =~ ~s(id="login_form")
      refute normalized =~ "GOf2PoyjnnHHrwZD"
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

    test "no parity row passes as empty-versus-empty: each probe captures the surface's real response" do
      rows = for %{"state" => "parity"} = row <- surfaces(), do: row

      # Every named surface is checked here, not just "a few": a floor on the count
      # is how the criterion shrank before.
      assert @named_parity_ids -- Enum.map(rows, & &1["id"]) == []

      for row <- rows do
        id = row["id"]
        listed = dimensions(row)

        {key, expected} =
          expected_parity_flash(id) ||
            flunk("parity row #{id} has no expected flash in expected_parity_flash/1")

        assert Enum.any?(listed, &(&1 in @content_dimensions)),
               "parity row #{id} lists no content dimension (flash or body), so :same proves nothing"

        {existing, unknown} = probe_pair(id)

        for {identity, response} <- [existing: existing, unknown: unknown] do
          assert empty_content_dimensions(response, listed) == [],
                 "#{id}: the #{identity} probe captured an empty " <>
                   inspect(empty_content_dimensions(response, listed)) <>
                   ", so a :same result would be empty-versus-empty"

          text = Map.get(response.flash, key)

          assert is_binary(text) and text =~ expected,
                 "#{id}: the #{identity} probe captured flash #{inspect(response.flash)}, " <>
                   "expected #{key} matching #{inspect(expected)}"
        end
      end
    end

    test "the non-vacuity check reports a response that observed nothing (control)" do
      nothing = response([])
      observed = response(flash: %{"error" => "Invalid"}, body: "<p>page</p>")

      assert empty_content_dimensions(nothing, [:status, :flash, :body]) == [:flash, :body]
      assert empty_content_dimensions(nothing, [:flash]) == [:flash]
      assert empty_content_dimensions(observed, [:status, :flash, :body]) == []
      # Only the content dimensions count: a constant status or a nil redirect is not content.
      assert empty_content_dimensions(nothing, [:status, :location]) == []
    end

    test "the expected-flash table names exactly the parity rows, so a new parity row must state its flash" do
      parity_ids = for %{"state" => "parity", "id" => id} <- surfaces(), do: id

      assert Enum.sort(parity_ids) ==
               Enum.sort(Enum.filter(@named_parity_ids, &expected_parity_flash/1))
    end
  end

  describe "known divergences (asserted: fixing the product must change the registry)" do
    setup :ensure_passkey_config_secret

    test "every known_divergence row still differs on exactly the registered dimensions" do
      rows = for %{"state" => "known_divergence"} = row <- surfaces(), do: row
      ids = Enum.map(rows, & &1["id"])

      assert Enum.sort(ids) == Enum.sort(Map.keys(@expected_divergence_dims)),
             "known_divergence rows #{inspect(ids)} do not match the asserted set"

      for row <- rows do
        {existing, unknown} = probe_pair(row["id"])

        case compare(existing, unknown, dimensions(row)) do
          :same ->
            flunk(
              "#{row["id"]} no longer differs. The divergence is fixed: remove or change " <>
                "its row in test/fixtures/brand/public-surfaces.json and its todo."
            )

          {:diff, details} ->
            assert details |> Enum.map(&elem(&1, 0)) |> Enum.sort() ==
                     Enum.sort(Map.fetch!(@expected_divergence_dims, row["id"])),
                   "#{row["id"]} differs on other dimensions than registered: " <>
                     inspect_diff(details)
        end
      end
    end

    test "the lockout divergence is masked at the example sign-in controller" do
      # The library result differs (asserted above); the example controller maps
      # every error to one flash, so the HTTP response does not expose it.
      attempts = lockout_attempts()

      masked =
        for identity <- [:existing, :unknown] do
          email = identity_email(identity)

          conn =
            Enum.reduce(1..attempts, nil, fn _n, _last ->
              post(build_conn(), ~p"/users/log_in", %{
                "user" => %{"email" => email, "password" => "wrong-password"}
              })
            end)

          normalize(
            response(
              status: conn.status,
              location: redirected_to(conn),
              flash: conn.assigns.flash
            ),
            email
          )
        end

      assert [existing, unknown] = masked
      assert compare(existing, unknown, [:status, :location, :flash]) == :same
      assert existing.flash["error"] == "Invalid email or password"
    end

    test "the email-less conditional passkey flow involves no identity: two anonymous calls match" do
      [first, second] =
        for _call <- 1..2 do
          build_conn()
          |> put_passkey_json_headers()
          |> post(~p"/users/log_in/passkey/options", %{"conditional" => "true"})
          |> capture_json("nobody@example.com")
        end

      assert first.json_keys == ["options"]
      assert compare(first, second, [:status, :json_keys]) == :same
    end
  end

  describe "by design (documented behaviour is asserted)" do
    test "every by_design row has an asserted behaviour in this module" do
      ids = for %{"state" => "by_design", "id" => id} <- surfaces(), do: id
      assert Enum.sort(ids) == Enum.sort(@by_design_ids)
    end

    test "invitation-accept: the signup branch does not depend on the invitee having an account" do
      row = Enum.find(surfaces(), &(&1["id"] == "invitation-accept"))
      {existing, unknown} = probe_pair("invitation-accept")

      assert existing.body =~ "Join Parity Org"
      assert existing.body =~ ~s(phx-submit="accept_with_signup")
      assert compare(existing, unknown, dimensions(row)) == :same
    end

    test "enterprise-sso-discovery: answers per email domain, never per user" do
      row = Enum.find(surfaces(), &(&1["id"] == "enterprise-sso-discovery"))
      {existing, unknown} = probe_pair("enterprise-sso-discovery")

      assert existing.location =~ "routing_source=domain_discovery"
      assert compare(existing, unknown, dimensions(row)) == :same

      # What is revealed is the connection for the DOMAIN: an address on a domain
      # without one gets a different answer, by design.
      ctx = prepare("enterprise-sso-discovery")
      other_domain = probe("enterprise-sso-discovery", :other_domain, ctx)

      assert {:diff, details} = compare(existing, other_domain, dimensions(row))
      assert Enum.any?(details, &match?({:location, _, _}, &1))
    end
  end

  describe "password-reset-request reaches the library" do
    test "an existing email writes one reset token for that account, an unknown email writes none" do
      user = user_fixture()
      unknown_email = unique_user_email()
      assert reset_tokens(user_id: user.id) == [], "setup: the account starts with no reset token"

      {_view, existing_outcome} = submit_reset_request(user.email)
      {_view, unknown_outcome} = submit_reset_request(unknown_email)

      # Both requests are accepted the same way (a redirect), so the difference
      # below is the library path being reached, not a rejected request.
      assert {:error, {:redirect, %{to: "/users/log_in"}}} = existing_outcome
      assert {:error, {:redirect, %{to: "/users/log_in"}}} = unknown_outcome

      assert [%{sent_to: sent_to}] = reset_tokens(user_id: user.id)
      assert sent_to == user.email
      assert reset_tokens(sent_to: unknown_email) == []
    end
  end

  describe "confirmation-resend probe is real" do
    test "an anonymous resend carrying an unconfirmed account's email creates no token, for either address" do
      user = user_fixture()
      unknown_email = unique_user_email()
      assert user.confirmed_at == nil, "setup: the existing identity is an unconfirmed account"
      assert confirmation_token_count(user.email) == 0, "setup: no token before the resend"
      assert confirmation_token_count(unknown_email) == 0, "setup: nothing stored for the address"

      existing = anonymous_resend(user.email)
      unknown = anonymous_resend(unknown_email)

      assert existing.result == %{confirmation_tokens: 0}
      assert unknown.result == %{confirmation_tokens: 0}
      assert Example.Repo.get!(Example.Accounts.User, user.id).confirmed_at == nil
    end

    test "the token count can see a delivery (control): a direct delivery takes it from 0 to at least 1" do
      user = user_fixture()
      assert user.confirmed_at == nil, "setup: the account is unconfirmed"
      assert confirmation_token_count(user.email) == 0, "setup: no token before the delivery"

      assert {:ok, :sent} =
               Example.Accounts.deliver_user_confirmation_instructions(user, fn token ->
                 "http://localhost/users/confirm/" <> token
               end)

      assert confirmation_token_count(user.email) >= 1
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

      # Non-vacuity: "the others stay same" must be about real rows, never an empty
      # or tiny list. Every named surface is a parity row, so leaking one leaves at
      # least the other four named rows to be compared.
      others = for {id, result} <- leaked, id != "password-signin", do: {id, result}

      assert length(others) >= length(@named_parity_ids) - 1,
             "vacuous control: only #{length(others)} other parity rows were compared, " <>
               "expected at least #{length(@named_parity_ids) - 1}"

      assert Enum.all?(others, fn {_id, result} -> result == :same end)
    end

    test "every parity surface can go red: leaking any one yields exactly that one diff" do
      registry = registry()
      parity_ids = for %{"state" => "parity", "id" => id} <- registry["surfaces"], do: id

      # Every named surface is a parity row (extra parity rows are allowed), so this
      # loop covers all five and cannot shrink to a subset without a red test.
      assert @named_parity_ids -- parity_ids == [],
             "named surfaces that are not parity rows: #{inspect(@named_parity_ids -- parity_ids)}"

      for id <- parity_ids do
        leaked = run_all(registry, leak: {id, @leak_text})
        diffs = for {surface, {:diff, _} = diff} <- leaked, do: {surface, diff}

        assert [{^id, _}] = diffs,
               "leaking #{id} should produce exactly one diff at #{id}, got: #{inspect(diffs)}"

        # ...and the rows that stay :same are real rows, never an empty list.
        others = for {surface, result} <- leaked, surface != id, do: result

        assert length(others) >= length(@named_parity_ids) - 1,
               "vacuous control: leaking #{id} left only #{length(others)} other parity rows"

        assert Enum.all?(others, &(&1 == :same))
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

  # Pure: the repo-relative paths that are not regular files under the repo root.
  # An absolute path is never a valid todo path, so it is reported as missing.
  defp missing_files(paths) do
    paths
    |> Enum.uniq()
    |> Enum.reject(fn path ->
      Path.type(path) == :relative and File.regular?(Path.join(@repo_root, path))
    end)
  end

  # Pure: the human-readable rule breaks among the named surfaces, each formatted
  # "<id>: <what is wrong>". `by_id` maps a registry id to its row.
  #
  # Every named id must be a parity row with a null blocker, judged on its own: there
  # is no total across ids, so a payload-ignored or code-kind row can never satisfy
  # or stand in for an account-existence requirement, and a not_proven account-existence
  # row is never excused by a blocker. The two separately counted classes also keep the
  # note phrases that say what their probe does and does not prove.
  defp named_surface_violations(by_id) do
    Enum.flat_map(@account_existence_ids, &named_row_violations(by_id, &1, [])) ++
      Enum.flat_map(@payload_ignored_ids, &named_row_violations(by_id, &1, @payload_note_phrases)) ++
      Enum.flat_map(@code_kind_ids, &named_row_violations(by_id, &1, @code_kind_note_phrases))
  end

  defp named_row_violations(by_id, id, note_phrases) do
    case Map.fetch(by_id, id) do
      :error ->
        ["#{id}: named surface is missing from the registry"]

      {:ok, row} ->
        state =
          if row["state"] == "parity",
            do: [],
            else: ["#{id}: state is #{inspect(row["state"])} but a named surface must be parity"]

        blocker =
          if is_nil(row["blocker"]),
            do: [],
            else: ["#{id}: blocker is #{inspect(row["blocker"])} but a parity row must have none"]

        note =
          for phrase <- note_phrases, not String.contains?(row["note"] || "", phrase) do
            "#{id}: note no longer contains #{inspect(phrase)}"
          end

        state ++ blocker ++ note
    end
  end

  # Pure test helpers for the planted controls: they build a modified copy of the
  # registry rows in memory and never touch the fixture file.
  defp downgrade(by_id, id) do
    Map.update!(
      by_id,
      id,
      &Map.merge(&1, %{"state" => "not_proven", "blocker" => "lib/sigra/lockout.ex:13"})
    )
  end

  defp update_note(by_id, id, fun) do
    Map.update!(by_id, id, &Map.update!(&1, "note", fun))
  end

  # The sorted unique ids a list of "<id>: <message>" violations names.
  defp violated_ids(violations) do
    violations
    |> Enum.map(&(&1 |> String.split(":", parts: 2) |> hd()))
    |> Enum.uniq()
    |> Enum.sort()
  end

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
      {existing, unknown} = probe_pair(row["id"])
      unknown = maybe_leak(unknown, row["id"], leak)

      {row["id"], compare(existing, unknown, dimensions(row))}
    end
  end

  # Probes one surface for an existing identity and an unknown identity against
  # the same shared fixtures (`prepare/1`).
  defp probe_pair(id) do
    ctx = prepare(id)
    {probe(id, :existing, ctx), probe(id, :unknown, ctx)}
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
      %{status: 200, location: nil, flash: %{}, body: "", json_keys: nil, result: nil},
      Map.new(attrs)
    )
  end

  defp inspect_diff(details), do: inspect(details, limit: 8, printable_limit: 240)

  # Pure: the content dimensions (`flash`, `body`) among `dimensions` that `response`
  # leaves empty. A parity row whose probe captured nothing compares empty against
  # empty and reads :same without proving anything.
  defp empty_content_dimensions(response, dimensions) do
    for dimension <- dimensions,
        dimension in @content_dimensions,
        Map.fetch!(response, dimension) in [nil, %{}, ""],
        do: dimension
  end

  # The flash each parity probe must capture on BOTH sides, as `{key, regex}`. These
  # are the messages the surfaces really show; `nil` for any other surface.
  defp expected_parity_flash("password-signin"),
    do: {"error", ~r/\AInvalid email or password\z/}

  defp expected_parity_flash("magic-link-request"),
    do: {"info", ~r/\AIf your email is registered, you will receive a magic link shortly\.\z/}

  defp expected_parity_flash("password-reset-request"),
    do:
      {"info",
       ~r/\AIf your email is in our system, you will receive reset instructions shortly\.\z/}

  defp expected_parity_flash("confirmation-resend"),
    do: {"error", ~r/\ALog in to request a new confirmation email\.\z/}

  defp expected_parity_flash("mfa-challenge"),
    do: {"error", ~r/\AInvalid verification code\. \d+ attempts? remaining\.\z/}

  defp expected_parity_flash(_id), do: nil

  # --- identities -------------------------------------------------------------

  # :existing is a real registered account; :unknown is an address never stored.
  defp identity_email(:existing), do: user_fixture().email
  defp identity_email(:unknown), do: unique_user_email()

  # --- probes -----------------------------------------------------------------

  defp probe("password-signin", identity, _ctx) do
    email = identity_email(identity)

    build_conn()
    |> post(~p"/users/log_in", %{"user" => %{"email" => email, "password" => "wrong-password"}})
    |> capture_redirect(email)
  end

  defp probe("magic-link-request", identity, _ctx) do
    email = identity_email(identity)

    build_conn()
    |> post(~p"/users/log_in", %{"_action" => "magic_link", "user" => %{"email" => email}})
    |> capture_redirect(email)
  end

  # Identity here is whether the submitted email belongs to an account: one reset
  # request through the LiveView form, which answers with a server redirect.
  defp probe("password-reset-request", identity, _ctx) do
    email = identity_email(identity)
    {view, outcome} = submit_reset_request(email)

    capture_live_redirect(view, outcome, email)
  end

  # Identity here is the email an anonymous visitor puts in the resend event payload:
  # an existing, still-unconfirmed account versus an address never stored. The resend
  # handler takes its target from the session user and never reads its payload, so this
  # proves a visitor-supplied identity is ignored. It does NOT probe an email-keyed
  # resend form: none exists, in the example or in the generated page.
  defp probe("confirmation-resend", identity, _ctx) do
    anonymous_resend(identity_email(identity))
  end

  # Identity here is the code KIND: a wrong authenticator code (:existing)
  # versus a wrong backup code (:unknown), each for a freshly enrolled user
  # with an MFA-pending session.
  defp probe("mfa-challenge", identity, _ctx) do
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

  # Identity here is whether the invitee email already has an account. The org
  # and owner are shared (`prepare/1`) so only the invitee differs.
  defp probe("invitation-accept", identity, %{owner: owner, org: org, scope: scope}) do
    email = identity_email(identity)

    {:ok, invitation} =
      Example.Organizations.create_invitation(%{
        actor: scope,
        organization_id: org.id,
        email: email,
        role: :member,
        invited_by_id: owner.id
      })

    {:ok, view, html} =
      live(build_conn(), ~p"/invitations/#{invitation.__encoded_token__}/accept")

    capture_live(view, html, email)
  end

  # By design: discovery answers per email DOMAIN. :existing and :unknown are both
  # on the connected domain; :other_domain is not.
  defp probe("enterprise-sso-discovery", identity, %{domain: domain}) do
    email =
      case identity do
        :existing -> user_fixture(%{email: "member-#{unique()}@#{domain}"}).email
        :unknown -> "nobody-#{unique()}@#{domain}"
        :other_domain -> "nobody-#{unique()}@unconnected-#{unique()}.example"
      end

    build_conn()
    |> post(~p"/users/log_in", %{"_action" => "enterprise", "user" => %{"email" => email}})
    |> capture_redirect(email, follow: false)
  end

  defp probe("registration", identity, _ctx) do
    # :existing is a duplicate registration, :unknown is a new one.
    email = identity_email(identity)
    {:ok, view, _html} = live(build_conn(), ~p"/users/register")

    result =
      view
      |> form("#registration_form", user: %{email: email, password: valid_user_password()})
      |> render_submit()

    capture_live(view, result, email)
  end

  defp probe("passkey-signin-options", identity, _ctx) do
    email = identity_email(identity)

    build_conn()
    |> put_passkey_json_headers()
    |> post(~p"/users/log_in/passkey/options", %{"user" => %{"email" => email}})
    |> capture_json(email)
  end

  # Library level: the same wrong password repeated past the lockout threshold.
  defp probe("password-signin-repeat-attempts", identity, _ctx) do
    email = identity_email(identity)

    {:error, reason} =
      Enum.reduce(1..lockout_attempts(), nil, fn _n, _last ->
        Example.Accounts.authenticate_user(email, "wrong-password")
      end)

    normalize(
      response(result: %{reason: reason, safe_message: Sigra.Error.safe_message(reason)}),
      email
    )
  end

  defp probe(id, _identity, _ctx), do: raise(ArgumentError, "no probe defined for surface #{id}")

  # Shared fixtures for the two probes of one surface; most surfaces need none.
  defp prepare("invitation-accept") do
    owner = user_fixture()
    org = create_organization(%{name: "Parity Org"})
    create_membership(owner, org, :owner)

    scope = %Example.Accounts.Scope{
      user: owner,
      active_organization: org,
      membership: %Example.Accounts.OrganizationMembership{role: :owner}
    }

    %{owner: owner, org: org, scope: scope}
  end

  defp prepare("enterprise-sso-discovery") do
    domain = "parity-#{unique()}.example"
    organization = create_organization(%{name: "Parity SSO Org"})

    %Example.Accounts.EnterpriseConnection{}
    |> Example.Accounts.EnterpriseConnection.changeset(%{
      organization_id: organization.id,
      protocol: :oidc,
      status: :active,
      display_name: "Parity enterprise connection",
      login_hint_domains: [domain],
      oidc_settings: %{
        issuer: "https://idp.example.com",
        discovery_document_uri: "https://idp.example.com/.well-known/openid-configuration",
        client_id: "client-id",
        encrypted_client_secret: "super-secret",
        client_authentication_method: "client_secret_basic",
        scopes: ["openid", "profile", "email"]
      }
    })
    |> Example.Repo.insert!()

    %{domain: domain, organization: organization}
  end

  defp prepare(_id), do: nil

  defp unique, do: System.unique_integer([:positive])

  # The reset_password tokens stored for one account (`user_id:`) or one address
  # (`sent_to:`). Queried straight from the repo, so it does not depend on which
  # process delivers the email.
  defp reset_tokens(filter) do
    Example.Repo.all(
      from(t in Example.Accounts.UserToken,
        where: t.context == "reset_password",
        where: ^filter
      )
    )
  end

  # The confirmation tokens (link and code) stored for one address (`sent_to`). Queried
  # straight from the repo, so a delivery shows up whichever process performed it.
  defp confirmation_token_count(email) do
    Example.Repo.aggregate(
      from(t in Example.Accounts.UserToken,
        where: t.context in ["confirm", "confirm_code"],
        where: t.sent_to == ^email
      ),
      :count
    )
  end

  # One anonymous resend event carrying `email` in its payload. The captured response
  # also carries the number of confirmation tokens stored for that address afterwards,
  # under `result`, so a resend that acted on the payload would differ from one that
  # ignored it even if the visible redirect were identical.
  defp anonymous_resend(email) do
    {:ok, view, _html} = live(build_conn(), ~p"/users/confirm")
    outcome = render_click(view, "resend", %{"email" => email})

    view
    |> capture_live_redirect(outcome, email)
    |> Map.put(:result, %{confirmation_tokens: confirmation_token_count(email)})
  end

  # One more than the configured lockout threshold.
  defp lockout_attempts do
    Keyword.fetch!(Example.Accounts.sigra_config().lockout, :threshold) + 1
  end

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
  defp capture_redirect(conn, email, opts \\ []) do
    location = redirected_to(conn)

    body =
      if Keyword.get(opts, :follow, true) do
        conn |> recycle() |> get(location) |> html_response(200)
      else
        ""
      end

    normalize(
      response(status: conn.status, location: location, flash: conn.assigns.flash, body: body),
      email
    )
  end

  # Captures a JSON endpoint response: status and the sorted top-level keys. The
  # body is not compared (it carries a per-request challenge).
  defp capture_json(conn, email) do
    decoded = json_response(conn, 200)

    normalize(
      response(status: conn.status, json_keys: decoded |> Map.keys() |> Enum.sort()),
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

  # Mounts the reset request page and submits the form once; returns the view and
  # the outcome of the submit (a server redirect when the request is accepted).
  defp submit_reset_request(email) do
    {:ok, view, _html} = live(build_conn(), ~p"/users/reset-password")

    outcome =
      view
      |> form("#reset_password_request_form", user: %{email: email})
      |> render_submit()

    {view, outcome}
  end

  # Captures a LiveView event that ends in a server `redirect`: the reported status
  # (a LiveView event has none, so @live_redirect_status), the redirect location, the
  # flash carried by the redirect and the page the redirect lands on. Anything other
  # than that redirect fails loudly.
  defp capture_live_redirect(view, {:error, {:redirect, %{to: to}}} = outcome, email) do
    flash = assert_redirect(view, to)
    {:ok, conn} = follow_redirect(outcome, build_conn())

    normalize(
      response(
        status: @live_redirect_status,
        location: to,
        flash: flash,
        body: html_response(conn, 200)
      ),
      email
    )
  end

  defp capture_live_redirect(_view, other, _email) do
    flunk("expected a LiveView redirect, got: #{inspect(other, limit: 5)}")
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
    |> then(&Regex.replace(~r/(\bid="phx-)[A-Za-z0-9_-]+"/, &1, "\\1{{REQUEST_ID}}\""))
    |> then(&Regex.replace(~r/(data-phx-(?:session|static)=")[^"]*"/, &1, "\\1{{REQUEST_ID}}\""))
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

  # --- passkey helpers (copied: the originals in passkey_session_controller_test
  # are private) --------------------------------------------------------------

  defp ensure_passkey_config_secret(_context) do
    old_config = Application.get_env(:example, :sigra_config)
    old_otp_app = Application.get_env(:sigra, :otp_app)

    Application.put_env(:sigra, :otp_app, :example)

    Application.put_env(
      :example,
      :sigra_config,
      Keyword.put(old_config, :secret_key_base, ExampleWeb.Endpoint.config(:secret_key_base))
    )

    Sigra.Passkeys.reset_cached_config()

    on_exit(fn ->
      restore_env(:sigra, :otp_app, old_otp_app)
      restore_env(:example, :sigra_config, old_config)
      Sigra.Passkeys.reset_cached_config()
    end)

    :ok
  end

  defp restore_env(app, key, nil), do: Application.delete_env(app, key)
  defp restore_env(app, key, value), do: Application.put_env(app, key, value)

  defp put_passkey_json_headers(conn) do
    conn
    |> put_req_header("accept", "application/json")
    |> put_req_header("content-type", "application/json")
  end
end
