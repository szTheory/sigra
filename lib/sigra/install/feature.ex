defmodule Sigra.Install.Feature do
  @moduledoc """
  Behaviour that every `mix sigra.install` feature module implements.

  A feature is a self-contained unit of installer work: a set of EEx
  templates to render, a set of code injections to apply, a set of
  migrations to emit, and a set of post-install instruction lines.

  The generic walker in `Mix.Tasks.Sigra.Install` iterates a
  canonical feature list (initially `[Sigra.Install.Features.Core]`)
  and calls each callback in turn. Adding a feature is purely
  additive: drop a new module implementing this behaviour into the
  list.

  Features MUST NOT reference each other (see Pitfall X-1 boundary
  discipline): `Features.Core` never mentions `Features.Organizations`
  and vice versa. This isolation is what makes
  `mix sigra.install --no-organizations` produce a compiling app even
  with no Organizations code present.
  """

  @doc """
  Returns true when this feature should run against the given opts.

  In `Sigra.Install.Features.Core` this always returns true per
  Phase 11 Success Criterion #4.
  """
  @callback enabled?(opts :: keyword()) :: boolean()

  @doc """
  Returns the list of non-migration EEx template file tuples to
  render. Each tuple is `{:eex, source, target}` where `source` is a
  path under `priv/templates/sigra.install/<feature>/` and `target`
  is the project-relative destination path.
  """
  @callback files(binding :: keyword()) ::
              [{:eex, source :: String.t(), target :: String.t()}]

  @doc """
  Returns a list of `%Sigra.Install.Injection{}` records describing
  code injections into existing files (router, config, runtime.exs,
  etc.). The walker applies each via `Sigra.Install.Injector.apply/2`.
  """
  @callback injections(binding :: keyword()) :: [Sigra.Install.Injection.t()]

  @doc """
  Returns the migrations this feature needs, in intended execution
  order. Each entry is `{slot_key, template_path, target_basename}`.
  The central `Sigra.Install.MigrationTimestamps` allocator assigns
  strictly-monotonic timestamps (GEN-07).

  In `Sigra.Install.Features.Core` this returns slots `:primary`,
  `:api_token`, `:audit_events`.
  """
  @callback migrations(binding :: keyword()) ::
              [{slot_key :: atom(), template :: String.t(), target_basename :: String.t()}]

  @doc """
  Returns iodata lines to append to the final post-install summary.
  Receives the fully-populated `Sigra.Install.Report` so features can
  tailor instructions based on what was generated vs skipped.
  """
  @callback post_instructions(binding :: keyword(), report :: Sigra.Install.Report.t()) ::
              [iodata()]
end
