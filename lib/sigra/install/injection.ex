defmodule Sigra.Install.Injection do
  @moduledoc """
  Structured injection descriptor for `Sigra.Install.Injector`.

  Features return a list of `%Sigra.Install.Injection{}` records from
  the `injections/1` callback in `Sigra.Install.Feature`; the walker
  passes each to `Sigra.Install.Injector.apply/2`, which owns marker
  checking and
  anchor resolution so every feature inherits idempotency (GEN-04)
  for free.

  ## Fields

    * `:target` — project-relative path of the file to mutate
      (e.g. `"lib/my_app_web/router.ex"`).
    * `:marker` — idempotency marker comment. If the file already
      contains this string, `Injector.apply/2` is a no-op.
    * `:anchor` — where to insert the content. One of
      `:before_last_end`, `:after_use_block`, `:at_top`, or a custom
      atom routed by `Injector`.
    * `:content` — rendered code block to insert.

  Per CONTEXT.md CD-03 the planner may rename these fields; this plan
  keeps the draft names (`target`/`marker`/`anchor`/`content`) verbatim
  so Wave 3 (`Features.Core` extraction) and Wave 4 (walker refactor)
  can reference them without a second rename.
  """

  @enforce_keys [:target, :marker, :anchor, :content]
  defstruct [:target, :marker, :anchor, :content]

  @type anchor :: :before_last_end | :after_use_block | :at_top | :browser_pipeline | atom()
  @type t :: %__MODULE__{
          target: Path.t(),
          marker: String.t(),
          anchor: anchor(),
          content: String.t()
        }
end
