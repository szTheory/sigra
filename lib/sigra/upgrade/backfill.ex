defmodule Sigra.Upgrade.Backfill do
  @moduledoc """
  Library-resident backfill logic for `mix sigra.upgrade --backfill-personal-orgs`.

  The host app's generated data migration
  (`priv/repo/data_migrations/*_backfill_personal_orgs.exs`) is a
  10-line shim that calls `run_personal_orgs/2`. All batching,
  telemetry, and SQL logic lives here so fixes ship via
  `mix deps.update` — the host never re-runs the generator.

  ## Idempotency guarantees (Phase 18 D-03)

  Two independent layers:

    1. **Selector-level** — `where: not exists(...)` narrows the work
       set to users without a personal org on every re-run. A keyset
       cursor (`u.id > ^last_cursor`) avoids Postgres `OFFSET`'s O(n)
       scan and makes crash-resume free.
    2. **Insert-level** — `Repo.insert_all/3` with `on_conflict:
       :nothing` and `conflict_target: {:unsafe_fragment,
       "(owner_user_id) WHERE personal = true"}` catches any race
       with concurrent signups, collapsing duplicates silently.

  ## Personal workspace naming (Phase 18 D-04)

    * Name — `"{display_name || email_local_part || "Personal"}'s
      Workspace"`.
    * Slug — `"user-\#{user.id}"`. Opaque, immutable, PII-safe.

  ## Telemetry

  Emits `[:sigra, :upgrade, :backfill, :batch]` per batch with
  measurements:

    * `:batch_index`     — zero-based counter
    * `:batch_size`      — rows returned by the selector
    * `:inserted`        — rows actually inserted (may be
      `< batch_size` on conflict)
    * `:total_processed` — running total across batches

  A terminal `[:sigra, :upgrade, :backfill, :done]` event fires once
  when the selector returns an empty batch, with `%{total_processed:
  n, batches: k}` measurements.
  """

  import Ecto.Query

  @options_schema [
    batch_size: [
      type: :pos_integer,
      default: 1_000,
      doc: "Rows per batch. Default 1000 (CD-02); tune down for low-memory hosts."
    ],
    users_schema: [
      type: :atom,
      required: true,
      doc: "Ecto schema module for the users table (e.g. MyApp.Accounts.User)."
    ],
    orgs_schema: [
      type: :atom,
      required: true,
      doc: "Ecto schema module for the organizations table (e.g. MyApp.Accounts.Organization)."
    ]
  ]

  @doc """
  Backfills a personal organization for every user that does not
  already have one.

  Idempotent: safe to re-run. See module docs for guarantees.

  Returns `{:ok, total_inserted}`.
  """
  @spec run_personal_orgs(module(), keyword()) :: {:ok, non_neg_integer()}
  def run_personal_orgs(repo, opts \\ []) do
    opts = NimbleOptions.validate!(opts, @options_schema)
    batch_size = opts[:batch_size]
    users_schema = opts[:users_schema]
    orgs_schema = opts[:orgs_schema]

    do_batch(repo, users_schema, orgs_schema, batch_size, nil, 0, 0)
  end

  defp do_batch(
         repo,
         users_schema,
         orgs_schema,
         batch_size,
         last_cursor,
         batch_index,
         total_processed
       ) do
    query = build_query(users_schema, orgs_schema, last_cursor, batch_size)

    case repo.all(query) do
      [] ->
        :telemetry.execute(
          [:sigra, :upgrade, :backfill, :done],
          %{total_processed: total_processed, batches: batch_index},
          %{}
        )

        {:ok, total_processed}

      users ->
        rows = Enum.map(users, &build_personal_org_row/1)

        {inserted, _} =
          repo.insert_all(orgs_schema, rows,
            on_conflict: :nothing,
            conflict_target: {:unsafe_fragment, "(owner_user_id) WHERE personal = true"}
          )

        new_total = total_processed + inserted

        :telemetry.execute(
          [:sigra, :upgrade, :backfill, :batch],
          %{
            batch_index: batch_index,
            batch_size: length(users),
            inserted: inserted,
            total_processed: new_total
          },
          %{}
        )

        next_cursor = users |> List.last() |> Map.fetch!(:id)

        do_batch(
          repo,
          users_schema,
          orgs_schema,
          batch_size,
          next_cursor,
          batch_index + 1,
          new_total
        )
    end
  end

  # First batch — no cursor constraint.
  defp build_query(users_schema, orgs_schema, nil, batch_size) do
    exists_query = personal_exists_subquery(orgs_schema)

    from u in users_schema,
      as: :u,
      where: not exists(exists_query),
      order_by: u.id,
      limit: ^batch_size
  end

  # Subsequent batches — keyset cursor.
  defp build_query(users_schema, orgs_schema, last_cursor, batch_size) do
    exists_query = personal_exists_subquery(orgs_schema)

    from u in users_schema,
      as: :u,
      where: u.id > ^last_cursor,
      where: not exists(exists_query),
      order_by: u.id,
      limit: ^batch_size
  end

  defp personal_exists_subquery(orgs_schema) do
    from o in orgs_schema,
      where: o.owner_user_id == parent_as(:u).id and o.personal == true,
      select: 1
  end

  defp build_personal_org_row(user) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    display = derive_display_name(user)

    %{
      id: Ecto.UUID.generate(),
      owner_user_id: user.id,
      name: "#{display}'s Workspace",
      slug: "user-#{user.id}",
      personal: true,
      inserted_at: now,
      updated_at: now
    }
  end

  defp derive_display_name(user) do
    cond do
      has_nonblank_field?(user, :display_name) ->
        Map.fetch!(user, :display_name)

      has_email?(user) ->
        user.email |> String.split("@") |> List.first()

      true ->
        "Personal"
    end
  end

  defp has_nonblank_field?(user, field) do
    case Map.get(user, field) do
      value when is_binary(value) and value != "" -> true
      _ -> false
    end
  end

  defp has_email?(user) do
    case Map.get(user, :email) do
      value when is_binary(value) -> String.contains?(value, "@")
      _ -> false
    end
  end
end
