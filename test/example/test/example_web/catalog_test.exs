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

  Ranking is by (current value, ctid), so list ordering (the explorers sort by
  `inserted_at`) is preserved, and a value that is in the future at pin time stays in
  the future (2099 base) so `expired?` flags keep their meaning. The pin is idempotent
  and runs before every request.

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

  @clock_token ~r/\b\d{4}-\d{2}-\d{2}\b/
  # Long opaque attribute values (csrf, signed phx tokens) can contain digit runs that
  # look like a date; they are not rendered text, so the clock control skips them.
  @opaque_value ~r/="[A-Za-z0-9_\-.=+\/]{40,}"/

  setup do
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

    test "writing with no raw directory writes nothing" do
      assert :skipped = write_raw("admin-planted", "<p>x</p>", nil)
      assert :skipped = write_raw("admin-planted", "<p>x</p>", "")
    end
  end

  # -- helpers ---------------------------------------------------------------

  defp persona_key(%{email: email}), do: email |> String.split("@") |> hd()

  defp persona!(personas, key),
    do: Enum.find(personas, &(&1.key == key)) || flunk("no persona #{key}")

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
  # ctid). Values in the past at pin time use the 2026 base and values in the future
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
      SELECT id, ctid AS cid, #{column} AS v,
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
               ORDER BY (v >= base AND v < base + interval '1 day') DESC, v, cid
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
    out = html |> replace_persona_ids(ctx.persona_ids) |> replace_capture_stamps(stamps)

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
