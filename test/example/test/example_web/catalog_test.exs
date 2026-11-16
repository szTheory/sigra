defmodule ExampleWeb.CatalogTest do
  @moduledoc """
  Tier-2 producer for the before catalog (BGEN-03): the library admin pages as the
  example app renders them, on seeded `@demo.tasklane.test` personas, through the
  real router.

  This is NOT a render of generated auth screens. The example app is a
  hand-maintained mirror whose admin shell is its own; every file written here is
  the `library-admin (example-mirror shell)` lane. The generated lane comes from a
  freshly generated host (`scripts/ci/admin-acceptance-smoke.sh --test catalog`).

  ## Contract with the root harness (`Sigra.Test.Brand.Catalog`)

  With `SIGRA_CATALOG_RAW_DIR` set, each page is written RAW to
  `<dir>/tier2-example-admin/<slug>.html`. With it unset the same tests are a plain
  smoke (HTTP 200, no seeded persona id in the dump, clock control) and write
  nothing. This module only dumps text; it compares nothing to a committed file.
  The root normalizer owns csrf values, phx ids, per-render ids, non-persona UUIDs
  and relative time.

  ## What is pinned here, and why

  Absolute wall-clock values are pinned at the source, never normalized by pattern.
  `pin_wall_clock!/0` rewrites every displayed wall-clock column to a fixed base
  plus one second per row rank, so the dumps are a function of the committed seeds:

    * `users.inserted_at` - the "Registered:" label on the users index
    * `audit_events.inserted_at` - the audit row timestamps (the pinned
      `occurred_at` is not what the rows display)
    * `organization_invitations.expires_at` - the "Expires" label on the
      organization page

  Ranking is by (current value, insertion command id, ctid), so list ordering (the
  explorers sort by `inserted_at`) is preserved, and a value that is in the future at
  pin time stays in the future (2099 base) so `expired?` flags keep their meaning. The
  command id (`cmin`) is what makes ties deterministic: `users.inserted_at` has
  one-second precision, so the seeded users tie, and ctid alone orders ties by heap
  position, which drifts once earlier tests have left dead tuples for the table to
  reuse. That drift moved the persona rows off page one of the users index after a few
  suite runs, so the dumps would not have been a function of the seeds. The pin is
  idempotent and runs before every request.

  Session rows are deliberately NOT pinned: seeds already pin their activity from the
  reference timestamp, and `Sigra.Plug.FetchSession` enforces an idle timeout on
  `last_active_at` (and throttles it back to now), so pinning the capturing admin
  session would either trip the timeout or be undone. That one stamp is replaced by
  exact value, never by pattern, with `{{CAPTURE_SESSION_ACTIVITY}}`.

  `assert_clock_pinned!/3` is the clock control: any rendered date that is not a
  seed-era constant (on or before the seeds' reference date) or the 2099 far-future
  pin, or that equals the run day, fails the dump and names the page and the token.
  A failure means another displayed column has to join the pin set.

  Run (the example suite is not part of `mix ci`):

      source tmp/db.env && cd test/example && MIX_ENV=test \\
        SIGRA_CATALOG_RAW_DIR="$(git rev-parse --show-toplevel)/tmp/catalog-raw" \\
        mix test --include example_app test/example_web/catalog_test.exs
  """
  use ExampleWeb.ConnCase, async: false

  import Ecto.Query, only: [from: 2]

  alias Example.Accounts
  alias Example.Accounts.Organization
  alias Example.Accounts.OrganizationMembership
  alias Example.Accounts.User
  alias Example.Accounts.UserSession
  alias Example.Demo.Personas
  alias Example.Demo.Seeds
  alias Example.Repo

  @moduletag :example_app

  @raw_env "SIGRA_CATALOG_RAW_DIR"
  @lane_dir "tier2-example-admin"

  # The seeds' reference date (`Example.Demo.Seeds` `@seed_reference_ts`). Rendered
  # dates must be on or before it, or in the far-future pin band.
  @seed_reference_date "2026-05-15"
  @far_future_prefix "2099-01-01"
  @past_base "2026-01-01 00:00:00"
  @future_base "2099-01-01 00:00:00"

  # Displayed wall-clock columns, all in the `auth` schema. Extend this list when the
  # clock control flags another rendered column.
  @pin_columns [
    {"users", "inserted_at"},
    {"audit_events", "inserted_at"},
    {"organization_invitations", "expires_at"}
  ]

  # Seeded `.test` sender used in place of the host's default sender while capturing.
  @capture_sender "noreply@catalog.example.test"

  # Account states of the per-user pages, in slug order of appearance.
  @states ~w(active locked unconfirmed scheduled-deletion zero-state)

  # The fixed tier-2 slug list. A page that stops rendering, or a new one that is not
  # listed here, fails `dumps exactly the fixed slug list`: the catalog is never vacuous.
  @expected_slugs ~w(
    admin-audit-index
    admin-auth-branding
    admin-org-acme
    admin-overview
    admin-user-audit-active
    admin-user-audit-locked
    admin-user-audit-scheduled-deletion
    admin-user-audit-unconfirmed
    admin-user-audit-zero-state
    admin-user-sessions-active
    admin-user-sessions-locked
    admin-user-sessions-scheduled-deletion
    admin-user-sessions-unconfirmed
    admin-user-sessions-zero-state
    admin-user-show-active
    admin-user-show-locked
    admin-user-show-scheduled-deletion
    admin-user-show-unconfirmed
    admin-user-show-zero-state
    admin-users-index
  )
  # Page groups, each identified by its slug prefix.
  @groups [
    overview: "admin-overview",
    users: "admin-users-index",
    user_show: "admin-user-show-",
    user_sessions: "admin-user-sessions-",
    user_audit: "admin-user-audit-",
    audit: "admin-audit-index",
    branding: "admin-auth-branding",
    org: "admin-org-"
  ]
  @email_shape ~r/[A-Za-z0-9._+-]+@[A-Za-z0-9-]+\.[A-Za-z0-9.-]+/

  @clock_token ~r/\b\d{4}-\d{2}-\d{2}\b/
  # Long opaque attribute values (csrf, signed phx tokens) can contain digit runs that
  # look like a date; they are not rendered text, so the clock control skips them.
  @opaque_value ~r/="[A-Za-z0-9_\-.=+\/]{40,}"/

  setup do
    use_capture_sender!()
    ExUnit.CaptureIO.capture_io(fn -> Seeds.run() end)

    personas =
      Enum.map(Personas.all(), fn persona ->
        %{
          key: persona_key(persona),
          flags: persona,
          user: Accounts.get_user_by_email(persona.email)
        }
      end)

    admin = persona!(personas, "admin")

    session_ids_before = session_ids(admin.user.id)
    token = Accounts.generate_user_session_token(admin.user)
    [session_id] = session_ids(admin.user.id) -- session_ids_before

    %{
      personas: personas,
      persona_ids: Map.new(personas, &{&1.user.id, &1.key}),
      admin: admin,
      token: token,
      session_id: session_id,
      run_date: Date.utc_today()
    }
  end

  describe "tracer: users index on the seeded admin persona" do
    test "renders through the real router and dumps raw text", ctx do
      page = fetch(ctx, "/admin/users")
      html = dump("admin-users-index", page, ctx)

      refute_persona_ids!(html, ctx)
      assert html =~ "Admin (operator)"
      assert html =~ "{{PERSONA:"
      assert html =~ "{{CAPTURE_SESSION_ACTIVITY}}"
    end
  end

  describe "tier-2 pages, one test per page group" do
    test("overview", ctx, do: assert_group!(ctx, :overview))

    test "users index", ctx do
      html = ctx |> assert_group!(:users) |> Map.fetch!("admin-users-index")

      assert html =~ "{{PERSONA:"
      assert html =~ "{{CAPTURE_SESSION_ACTIVITY}}"
    end

    test("user detail, one page per account state", ctx, do: assert_group!(ctx, :user_show))
    test("user sessions, one page per account state", ctx, do: assert_group!(ctx, :user_sessions))
    test("user audit, one page per account state", ctx, do: assert_group!(ctx, :user_audit))
    test("audit index", ctx, do: assert_group!(ctx, :audit))
    test("auth branding", ctx, do: assert_group!(ctx, :branding))
    test("organization", ctx, do: assert_group!(ctx, :org))
  end

  describe "the whole tier-2 set" do
    test "dumps exactly the fixed slug list", ctx do
      slugs = ctx |> capture_all() |> Map.keys() |> Enum.sort()

      assert slugs == Enum.sort(@expected_slugs)
      assert length(slugs) == length(Enum.uniq(slugs))
    end

    test "a second pass with the pin run between yields identical pages", ctx do
      first = capture_all(ctx)
      pin_wall_clock!()
      second = capture_all(ctx)

      assert Map.keys(first) |> Enum.sort() == Map.keys(second) |> Enum.sort()

      moved =
        for {slug, html} <- first, comparable(html) != comparable(second[slug]), do: slug

      assert moved == [], "pages that changed between two passes: #{inspect(Enum.sort(moved))}"
    end
  end

  describe "the wall-clock pin" do
    test "ranks users in creation order, whatever the heap layout", _ctx do
      pin_wall_clock!()

      emails = Repo.all(from(u in User, order_by: [asc: u.inserted_at], select: u.email))
      loadtest = Enum.filter(emails, &String.starts_with?(&1, "loadtest-"))

      # Bulk users in numeric order and the i18n user after them, then the personas in
      # their seeded order. A heap-order tie-break scrambles this on a reused heap.
      assert emails == Enum.sort(loadtest) ++ Enum.map(Personas.all(), & &1.email)
    end

    test "is idempotent: a second pin changes no value", _ctx do
      pin_wall_clock!()
      first = pinned_values()
      pin_wall_clock!()

      assert pinned_values() == first
      assert Enum.all?(first, fn {_table, rows} -> rows != [] end), "a pinned table has no rows"
    end
  end

  describe "planted controls (pure, in memory)" do
    test "capture-session stamp is replaced by exact value and a seeded stamp is left alone" do
      capture = ~U[2026-11-15 18:40:07Z]
      seeded = "2026-05-14 12:00"

      html =
        ~s(<span>Last activity: 2026-11-15 18:40</span><i>2026-11-15 18:40:07</i><b>#{seeded}</b>)

      out = replace_capture_stamps(html, [capture])

      assert out =~ "Last activity: {{CAPTURE_SESSION_ACTIVITY}}"
      refute out =~ "2026-11-15 18:40"
      assert out =~ "<b>#{seeded}</b>"
      assert out =~ "<i>{{CAPTURE_SESSION_ACTIVITY}}</i>"
    end

    test "the clock control fails on a token dated today" do
      today = Date.utc_today()

      assert_raise ExUnit.AssertionError, ~r/admin-planted: rendered date #{today}/, fn ->
        assert_clock_pinned!("admin-planted", "<p>Registered: #{today}</p>", today)
      end
    end

    test "the run-day rule fires on its own, for a date that is otherwise seed-era" do
      # 2026-05-10 passes the reference-date rule, so only the run-day rule can fail it.
      assert_raise ExUnit.AssertionError, ~r/is the run day/, fn ->
        assert_clock_pinned!("admin-planted", "<p>Registered: 2026-05-10</p>", ~D[2026-05-10])
      end
    end

    test "the clock control fails on a date after the seeds' reference date" do
      assert_raise ExUnit.AssertionError, ~r/2026-08-01/, fn ->
        assert_clock_pinned!("admin-planted", "<p>Registered: 2026-08-01</p>", ~D[2026-11-15])
      end
    end

    test "the clock control accepts seed-era dates and the 2099 pin band" do
      html = "<p>2026-01-01 00:00:07 2026-05-15 2099-01-01 00:00:03</p>"
      assert :ok = assert_clock_pinned!("admin-planted", html, ~D[2026-11-15])
    end

    test "persona replacement turns a seeded user id into its label and removes the id" do
      id = "11111111-2222-4333-8444-555555555555"
      html = ~s(<a href="/admin/users/#{id}">Alice</a>)

      out = replace_persona_ids(html, %{id => "alice"})

      assert out == ~s(<a href="/admin/users/{{PERSONA:alice}}">Alice</a>)
      refute out =~ id
    end

    test "the address scan flags a non-.test address and leaves .test addresses alone" do
      assert foreign_emails("<p>x a@" <> "b.com y</p>") == ["a@" <> "b.com"]
      assert foreign_emails("<p>alice@demo.tasklane.test</p>") == []
    end

    test "the shipped preview placeholder address is masked and then passes the address scan" do
      html = ~s(<input type="email" value="alex@) <> ~s(example.com" />)

      assert foreign_emails(html) != []
      masked = mask_shipped_placeholder(html)
      assert masked =~ "{{PREVIEW_EMAIL}}"
      assert foreign_emails(masked) == []
    end

    test "the comparison scrub removes per-render ids and keeps absolute dates" do
      a =
        ~s(<div id="phx-F1abcDEF" data-phx-session="x"><i id="mg-11-confirm-title-12"></i>3h ago 2026-01-01</div>)

      b =
        ~s(<div id="phx-F2zzzXYZ" data-phx-session="y"><i id="mg-11-confirm-title-20"></i>5h ago 2026-01-01</div>)

      c =
        ~s(<div id="phx-F2zzzXYZ" data-phx-session="y"><i id="mg-11-confirm-title-20"></i>5h ago 2026-01-02</div>)

      assert comparable(a) == comparable(b)
      assert comparable(a) != comparable(c)
    end

    test "writing with no raw directory writes nothing" do
      assert :skipped = write_raw("admin-planted", "<p>x</p>", nil)
      assert :skipped = write_raw("admin-planted", "<p>x</p>", "")
    end
  end

  # -- helpers ---------------------------------------------------------------

  # `{group, slug, path}` for every tier-2 page. The per-user pages exist once per
  # account state, each state resolved to a seeded persona by its documented flags.
  defp pages(ctx) do
    per_state = fn group, prefix, suffix ->
      for {state, persona} <- state_personas(ctx) do
        {group, prefix <> state, "/admin/users/#{persona.user.id}#{suffix}"}
      end
    end

    org = owner_org(ctx)

    [
      {:overview, "admin-overview", "/admin"},
      {:users, "admin-users-index", "/admin/users"}
    ] ++
      per_state.(:user_show, "admin-user-show-", "") ++
      per_state.(:user_sessions, "admin-user-sessions-", "/sessions") ++
      per_state.(:user_audit, "admin-user-audit-", "/audit") ++
      [
        {:audit, "admin-audit-index", "/admin/audit"},
        {:branding, "admin-auth-branding", "/admin/auth-branding"},
        {:org, "admin-org-#{org.handle}", "/admin/organizations/#{org.slug}"}
      ]
  end

  defp state_personas(ctx), do: Enum.map(@states, &{&1, resolve_state(ctx.personas, &1)})

  # The seeds carry one unconfirmed persona and it is also the locked one, so the
  # unconfirmed state falls back to it when no unlocked unconfirmed persona exists.
  defp resolve_state(personas, state) do
    Enum.find(personas, &state_match?(state, :strict, &1.flags)) ||
      Enum.find(personas, &state_match?(state, :loose, &1.flags)) ||
      flunk("no seeded persona is in the #{state} state")
  end

  defp state_match?("active", _precision, flags) do
    confirmed_plain?(flags) and not is_nil(flags.org_member)
  end

  defp state_match?("locked", _precision, flags), do: flags.locked
  defp state_match?("unconfirmed", :strict, flags), do: not flags.confirmed and not flags.locked
  defp state_match?("unconfirmed", :loose, flags), do: not flags.confirmed
  defp state_match?("scheduled-deletion", _precision, flags), do: flags.scheduled_deletion

  defp state_match?("zero-state", _precision, flags) do
    confirmed_plain?(flags) and is_nil(flags.org_owner) and is_nil(flags.org_admin) and
      is_nil(flags.org_member)
  end

  defp state_match?(_state, _precision, _flags), do: false

  defp confirmed_plain?(flags) do
    flags.confirmed and not flags.locked and not flags.scheduled_deletion and not flags.totp and
      not flags.passkey and not flags.identity_github
  end

  # The one seeded organization, resolved through the admin persona's owner
  # membership (the persona carries a handle, the route needs the slug).
  defp owner_org(ctx) do
    org_id =
      Repo.one(
        from(m in OrganizationMembership,
          where: m.user_id == ^ctx.admin.user.id and m.role == :owner,
          select: m.organization_id
        )
      )

    %{handle: ctx.admin.flags.org_owner, slug: Repo.get!(Organization, org_id).slug}
  end

  defp expected_slugs(group) do
    prefix = Keyword.fetch!(@groups, group)
    Enum.filter(@expected_slugs, &String.starts_with?(&1, prefix))
  end

  defp capture_group(ctx, group) do
    for {^group, slug, path} <- pages(ctx), into: %{} do
      {slug, dump(slug, fetch(ctx, path), ctx)}
    end
  end

  defp capture_all(ctx) do
    for {group, _prefix} <- @groups, reduce: %{} do
      acc -> Map.merge(acc, capture_group(ctx, group))
    end
  end

  # Every group renders exactly its fixed slugs, and every dumped page is free of
  # seeded persona ids and of any non-.test address.
  defp assert_group!(ctx, group) do
    captured = capture_group(ctx, group)

    assert captured |> Map.keys() |> Enum.sort() == Enum.sort(expected_slugs(group))

    for {slug, html} <- captured do
      refute_persona_ids!(html, ctx)
      assert foreign_emails(html) == [], "#{slug}: non-.test address in the dump"
    end

    captured
  end

  defp foreign_emails(html) do
    @email_shape
    |> Regex.scan(html)
    |> List.flatten()
    |> Enum.reject(&String.ends_with?(&1, ".test"))
    |> Enum.uniq()
  end

  # `Sigra.Admin.Components.preview_pair/1` ships a placeholder sign-in address on
  # a real-looking domain, and `lib/` does not change in this phase. It is masked to
  # the same token the root normalizer uses, so no non-.test address reaches the raw
  # directory and the root normalizer's own mask stays a no-op on these dumps.
  defp mask_shipped_placeholder(html) do
    String.replace(html, "alex@" <> "example.com", "{{PREVIEW_EMAIL}}")
  end

  # In-memory view used only to compare two passes of the same page. Raw dumps keep
  # their per-render ids (the root normalizer owns those for the committed catalog);
  # two renders can only be compared once the same volatiles are masked.
  defp comparable(html) do
    html
    |> then(&Regex.replace(@opaque_value, &1, "=\"\""))
    |> then(&Regex.replace(~r/(\bid="phx-)[A-Za-z0-9_-]+"/, &1, "\\1\""))
    |> then(&Regex.replace(~r/(data-phx-[a-z-]+=")[^"]*"/, &1, "\\1\""))
    |> then(&Regex.replace(~r/\b(mg-\d+-[a-z][a-z-]*-)\d+\b/, &1, "\\1N"))
    |> then(&Regex.replace(~r/\bjust now\b|\b\d+[mhd] ago\b/, &1, "RELATIVE"))
  end

  # The example host's branding default sender is a real-looking address
  # (`config :example, :sigra_config`), and the auth branding page shows it in a
  # form field. For the capture only, the running test VM's config carries a seeded
  # `.test` sender instead, restored afterwards. No shipped config, template or
  # default changes, and the manifest coverage text says the sender is overridden.
  defp use_capture_sender! do
    original = Application.fetch_env!(:example, :sigra_config)

    branding =
      Keyword.put(Keyword.fetch!(original, :branding), :email_from_address, @capture_sender)

    Application.put_env(:example, :sigra_config, Keyword.put(original, :branding, branding))
    on_exit(fn -> Application.put_env(:example, :sigra_config, original) end)
  end

  defp persona_key(%{email: email}), do: email |> String.split("@") |> hd()

  defp persona!(personas, key),
    do: Enum.find(personas, &(&1.key == key)) || flunk("no persona #{key}")

  defp pinned_values do
    for {table, column} <- @pin_columns do
      %{rows: rows} =
        Ecto.Adapters.SQL.query!(
          Repo,
          "SELECT id::text, #{column}::text FROM auth.#{table} ORDER BY id",
          []
        )

      {table, rows}
    end
  end

  defp session_ids(user_id) do
    Repo.all(from(s in UserSession, where: s.user_id == ^user_id, select: s.id))
  end

  defp session_stamp(session_id) do
    Repo.one(from(s in UserSession, where: s.id == ^session_id, select: s.last_active_at))
  end

  defp authed_conn(token) do
    Phoenix.ConnTest.build_conn()
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, token)
  end

  # Pins, requests, and records the capture session's activity stamp before and
  # after the request (the throttled activity update may move it during the request).
  defp fetch(ctx, path) do
    pin_wall_clock!()
    stamp_before = session_stamp(ctx.session_id)
    conn = ctx.token |> authed_conn() |> get(path)
    stamp_after = session_stamp(ctx.session_id)

    %{html: html_response(conn, 200), stamps: Enum.uniq([stamp_before, stamp_after])}
  end

  # Idempotent, rank-preserving pin of every displayed wall-clock column. Each value
  # maps to a fixed base plus one second per row rank, ranking by (current value,
  # insertion command id, ctid). Values in the past at pin time use the 2026 base and values in the future
  # use the 2099 base, so each row keeps its relation to "now". Rows already inside
  # their base band rank first, so re-running the pin never reshuffles them. "Now" is
  # the Elixir clock, the same clock that wrote the timestamps.
  defp pin_wall_clock! do
    now = NaiveDateTime.utc_now()

    for {table, column} <- @pin_columns do
      Ecto.Adapters.SQL.query!(Repo, pin_sql(table, column), [now])
    end

    :ok
  end

  defp pin_sql(table, column) do
    """
    WITH keyed AS (
      SELECT id, cmin::text::bigint AS cm, ctid AS cid, #{column} AS v,
             (#{column} > $1::timestamp) AS future,
             CASE WHEN #{column} > $1::timestamp
                  THEN timestamp '#{@future_base}'
                  ELSE timestamp '#{@past_base}' END AS base
      FROM auth.#{table}
      WHERE #{column} IS NOT NULL
    ), ranked AS (
      SELECT id, base,
             row_number() OVER (
               PARTITION BY future
               ORDER BY (v >= base AND v < base + interval '1 day') DESC, v, cm, cid
             ) AS rn
      FROM keyed
    )
    UPDATE auth.#{table} AS t
    SET #{column} = ranked.base + ranked.rn * interval '1 second'
    FROM ranked
    WHERE t.id = ranked.id
    """
  end

  # Replaces the capturing session's own activity stamp, by exact string only. Both
  # renderings are listed longest first so the seconds form is not left half replaced.
  defp replace_capture_stamps(html, stamps) do
    stamps
    |> Enum.filter(&match?(%DateTime{}, &1))
    |> Enum.flat_map(fn stamp ->
      [Calendar.strftime(stamp, "%Y-%m-%d %H:%M:%S"), Calendar.strftime(stamp, "%Y-%m-%d %H:%M")]
    end)
    |> Enum.uniq()
    |> Enum.sort_by(&(-String.length(&1)))
    |> Enum.reduce(html, &String.replace(&2, &1, "{{CAPTURE_SESSION_ACTIVITY}}"))
  end

  defp replace_persona_ids(html, persona_ids) do
    Enum.reduce(persona_ids, html, fn {id, key}, acc ->
      String.replace(acc, id, "{{PERSONA:#{key}}}")
    end)
  end

  defp refute_persona_ids!(html, ctx) do
    for {id, key} <- ctx.persona_ids do
      refute html =~ id, "seeded persona id for #{key} survived replacement"
    end

    :ok
  end

  # The clock control. A rendered date must be a seed-era constant (on or before the
  # seeds' reference date) or sit in the 2099 pin band, and must never be the run day.
  defp assert_clock_pinned!(slug, html, today) do
    today_token = Date.to_iso8601(today)
    scrubbed = Regex.replace(@opaque_value, html, "=\"\"")

    for [token] <- Regex.scan(@clock_token, scrubbed) do
      cond do
        token == today_token ->
          flunk(
            "#{slug}: rendered date #{token} is the run day; a wall-clock column is not pinned"
          )

        String.starts_with?(token, @far_future_prefix) ->
          :ok

        token <= @seed_reference_date ->
          :ok

        true ->
          flunk(
            "#{slug}: rendered date #{token} is later than the seeds' reference date " <>
              "#{@seed_reference_date}; add the displayed column to @pin_columns"
          )
      end
    end

    :ok
  end

  # Persona ids become labels, the capture stamp is replaced, the clock control runs,
  # then the page is written raw when SIGRA_CATALOG_RAW_DIR is set. Returns the
  # replaced html. The env read is allowed here: the RegenGuardTest scan covers only
  # root brand tests.
  defp dump(slug, %{html: html, stamps: stamps}, ctx) do
    out =
      html
      |> replace_persona_ids(ctx.persona_ids)
      |> replace_capture_stamps(stamps)
      |> mask_shipped_placeholder()

    assert_clock_pinned!(slug, out, ctx.run_date)
    write_raw(slug, out, System.get_env(@raw_env))
    out
  end

  defp write_raw(_slug, _html, dir) when dir in [nil, ""], do: :skipped

  defp write_raw(slug, html, dir) do
    lane = Path.join(dir, @lane_dir)
    File.mkdir_p!(lane)
    File.write!(Path.join(lane, slug <> ".html"), html)
    :written
  end
end
