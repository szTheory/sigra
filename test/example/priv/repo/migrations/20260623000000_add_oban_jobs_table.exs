defmodule Example.Repo.Migrations.AddObanJobsTable do
  @moduledoc """
  Creates the Oban jobs table so the account-deletion flow's optional
  `maybe_enqueue_deletion_job` insert succeeds end-to-end in the example suite.

  Sigra treats Oban as an optional dependency — `Sigra.OptionalDeps.oban_available?/0`
  is `Code.ensure_loaded?(Oban)`, which is `true` whenever Oban is compiled (it is,
  as a dep of this example). Without the `oban_jobs` table the enqueue INSERT raises
  `42P01 undefined_table`, poisoning the surrounding audit transaction. Migrating
  the table lets the real deletion path (revoke sessions + enqueue job) run cleanly.
  """
  use Ecto.Migration

  def up, do: Oban.Migration.up(version: 12)

  def down, do: Oban.Migration.down(version: 1)
end
