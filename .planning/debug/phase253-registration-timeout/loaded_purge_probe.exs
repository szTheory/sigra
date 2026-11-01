# Local module-loading diagnostic. No Mix task, application, DB, HTTP or browser.
# Uses existing dependency BEAM files; it does not change them.
root = System.fetch_env!("SIGRA_DEBUG_ROOT")
for path <- Path.wildcard(Path.join(root, "test/example/_build/dev/lib/*/ebin")) do
  Code.prepend_path(path)
end

consolidated = Path.join(root, "test/example/_build/dev/lib/example/consolidated")
Code.prepend_path(consolidated)

{:module, Ecto.Queryable} = Code.ensure_loaded(Ecto.Queryable)
:ok = :application.load(:ecto)
{:ok, properties} = :application.get_key(:ecto, :vsn)
IO.puts("ecto_version=#{properties}; elixir=#{System.version()}; otp=#{System.otp_release()}")
IO.puts("queryable_path=#{:code.which(Ecto.Queryable)}")

query = fn ->
  try do
    result = apply(Ecto.Queryable, :to_query, [Example.Accounts.User])
    if Map.get(result, :__struct__) == Ecto.Query, do: :ok, else: {:unexpected, result}
  rescue
    error in UndefinedFunctionError ->
      {:undefined, error.module, error.function, error.arity, Exception.message(error)}
  end
end

control = for _ <- 1..2000, do: query.()
true = Enum.all?(control, &(&1 == :ok))
IO.puts("control=2000_passed")

parent = self()
workers =
  for _ <- 1..4 do
    spawn_monitor(fn ->
      receive do: (:start -> :ok)
      outcomes = for _ <- 1..100000, do: query.()
      send(parent, {:outcomes, self(), Enum.frequencies(outcomes)})
    end)
  end

purger = spawn_monitor(fn ->
  receive do: (:start -> :ok)
  for _ <- 1..5000 do
    {:module, Ecto.Queryable} = Code.ensure_loaded(Ecto.Queryable)
    # The exact two operations in Phoenix1.8.5 CodeReloader.Server.purge_module/1.
    :code.purge(Ecto.Queryable)
    :code.delete(Ecto.Queryable)
  end
end)

for {pid, _} <- workers ++ [purger], do: send(pid, :start)

collect = fn collect, pending, outcomes, deaths ->
  if pending == [] do
    {outcomes, deaths}
  else
    receive do
      {:outcomes, _pid, counts} ->
        collect.(collect, pending, Map.merge(outcomes, counts, fn _key, a, b -> a + b end), deaths)
      {:DOWN, ref, :process, pid, reason} ->
        collect.(collect, List.keydelete(pending, ref, 1), outcomes, [{pid, reason} | deaths])
    after
      10000 -> raise "module-loading experiment exceeded10seconds"
    end
  end
end

{outcomes, deaths} = collect.(collect, workers ++ [purger], %{}, [])
IO.inspect(outcomes, label: "concurrent_outcomes", limit: 30)
IO.inspect(Enum.frequencies(Enum.map(deaths, &elem(&1, 1))), label: "process_exit_reasons")
{:module, Ecto.Queryable} = Code.ensure_loaded(Ecto.Queryable)
true = query.() == :ok
IO.puts("restored_query=passed")
