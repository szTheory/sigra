defmodule Mix.Tasks.Sigra.Upgrade do
  @shortdoc "Upgrades a Sigra-installed app to the current library version"

  @moduledoc """
  Upgrades a Sigra-installed app from an older schema version to the
  current library version (Phase 18 D-08).

  ## Usage

      mix sigra.upgrade [--yes] [--dry-run] [--allow-dirty]
                        [--backfill-personal-orgs] [--from VERSION]

  ## Flags

    * `--yes` — skip interactive prompts. **Required for CI.**
    * `--dry-run` — print the plan without writing anything.
    * `--allow-dirty` — bypass the dirty-git-tree check.
    * `--backfill-personal-orgs` — generate the personal-org
      backfill data migration (Phase 18 D-02).
    * `--from VERSION` — override auto-detected source version
      (normally read from `config :sigra, :schema_version` in
      `config/config.exs`). Useful for partial rollbacks.

  ## Examples

      # Standard upgrade with interactive confirmation:
      mix sigra.upgrade

      # Non-interactive (CI) upgrade with backfill:
      mix sigra.upgrade --backfill-personal-orgs --yes

      # Preview without writing:
      mix sigra.upgrade --dry-run

  ## Telemetry

  Backfill emits `[:sigra, :upgrade, :backfill, :batch]` events per
  batch. See `Sigra.Upgrade.Backfill` moduledoc for measurement
  keys.

  ## Behaviour

  Delegates to `Sigra.Upgrade.run/1` after validating options via
  `NimbleOptions`. All security-critical logic (git dirty check,
  version detection, downgrade refusal, injection, template
  walking) lives in the versioned library so fixes ship via
  `mix deps.update`.
  """

  use Mix.Task

  @options_schema [
    yes: [
      type: :boolean,
      default: false,
      doc: "Skip interactive prompts (required for CI)."
    ],
    dry_run: [
      type: :boolean,
      default: false,
      doc: "Print the plan without writing anything."
    ],
    allow_dirty: [
      type: :boolean,
      default: false,
      doc: "Bypass the dirty-git-tree refusal."
    ],
    backfill_personal_orgs: [
      type: :boolean,
      default: false,
      doc: "Generate the personal-org backfill data migration (Phase 18 D-02)."
    ],
    from: [
      type: {:or, [:string, nil]},
      default: nil,
      doc: "Override auto-detected source version."
    ]
  ]

  @switches [
    yes: :boolean,
    dry_run: :boolean,
    allow_dirty: :boolean,
    backfill_personal_orgs: :boolean,
    from: :string
  ]

  @impl Mix.Task
  def run(args) do
    {opts, _parsed, _invalid} = OptionParser.parse(args, switches: @switches)
    validated = NimbleOptions.validate!(opts, @options_schema)
    Sigra.Upgrade.run(validated)
  end

  @doc false
  def promote_vault(opts), do: Sigra.Upgrade.promote_vault(opts)
end
