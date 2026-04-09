defmodule Sigra.Hooks do
  @moduledoc """
  Lifecycle hook execution engine.

  Hooks are `{module, function}` tuples configured in the `:hooks` config section.
  Each hook function receives `(multi, context_map)` where:
  - `multi` is a fresh `Ecto.Multi` (the hook can add steps to it)
  - `context_map` is a map with at least `:user`, `:changes` (prior multi results),
    and operation-specific keys

  The hook function must return `{:ok, multi}` with optional additional Multi steps,
  or `{:error, reason}` to abort the entire transaction.

  ## Example

      defmodule MyApp.Auth.Hooks do
        def on_password_change(_multi, %{user: user}) do
          {:ok, Ecto.Multi.new() |> Ecto.Multi.run(:notify_admin, fn _repo, _changes ->
            MyApp.Admin.notify_password_change(user)
            {:ok, :notified}
          end)}
        end
      end
  """

  alias Ecto.Multi

  @type hook :: {module(), atom()} | nil
  @type context_map :: %{required(:user) => struct(), optional(atom()) => term()}

  @doc """
  Conditionally appends a hook step to the Ecto.Multi.

  If the hook for the given operation is nil (not configured), the multi is
  returned unchanged. If configured, the hook function is called and its
  result is incorporated into the multi.

  The hook step is named `:on_{operation}_hook` (e.g., `:on_password_change_hook`)
  so transaction error tuples can identify hook failures distinctly from
  auth operation failures.

  ## Parameters

  - `multi` - The current Ecto.Multi
  - `operation` - The operation atom (e.g., :password_change, :email_change,
    :delete, :register)
  - `context_map` - Map with :user and operation-specific data
  - `config` - Sigra config struct, keyword list with :hooks key, or keyword list
    of hooks directly
  """
  @doc since: "0.8.0"
  @spec maybe_run_hook(Multi.t(), atom(), context_map(), keyword() | map()) :: Multi.t()
  def maybe_run_hook(multi, operation, context_map, config) do
    hook = get_hook(config, operation)

    case hook do
      nil ->
        multi

      {mod, fun} ->
        step_name = :"on_#{operation}_hook"

        Multi.run(multi, step_name, fn _repo, changes ->
          merged_context = Map.merge(context_map, %{changes: changes})

          case apply(mod, fun, [Multi.new(), merged_context]) do
            {:ok, _multi} -> {:ok, :hook_completed}
            {:error, reason} -> {:error, reason}
          end
        end)
    end
  end

  @doc """
  Gets the hook for a given operation from config.

  Accepts either a map with a `:hooks` key (such as a `Sigra.Config` struct),
  a keyword list with a `:hooks` key, or returns nil for unrecognized config shapes.

  The operation is prefixed with `on_` to match the config key naming convention
  (e.g., operation `:register` looks up `:on_register`).
  """
  @doc since: "0.8.0"
  @spec get_hook(keyword() | map() | term(), atom()) :: hook()
  def get_hook(%{hooks: hooks}, operation) when is_list(hooks) do
    Keyword.get(hooks, :"on_#{operation}")
  end

  def get_hook(config, operation) when is_list(config) do
    hooks = Keyword.get(config, :hooks, [])
    Keyword.get(hooks, :"on_#{operation}")
  end

  def get_hook(_config, _operation), do: nil
end
