# Isolated, offline use of the real Phoenix.CodeReloader.Server.
# No Example application, endpoint listener, database, browser or network client.
root = System.fetch_env!("SIGRA_DEBUG_ROOT")
out = System.fetch_env!("SIGRA_DEBUG_OUTPUT")
mode = System.fetch_env!("SIGRA_DEBUG_CONSOLIDATE")
true = mode in ["true", "false"]
consolidate = mode == "true"
change = System.get_env("SIGRA_DEBUG_CHANGE", "none")
true = change in ["none", "source", "implementation"]
rounds = String.to_integer(System.get_env("SIGRA_DEBUG_ROUNDS", "50"))
true = rounds in 1..50
File.mkdir_p!(out)

for path <- Path.wildcard(Path.join(root, "test/example/_build/dev/lib/*/ebin")) do
  Code.prepend_path(path)
end

Code.prepend_path(Path.join(root, "test/example/_build/dev/lib/example/consolidated"))
{:module, Ecto.Queryable} = Code.ensure_loaded(Ecto.Queryable)
:ok = :application.load(:ecto)
:ok = :application.load(:phoenix)
{:ok, ~c"3.13.5"} = :application.get_key(:ecto, :vsn)
{:ok, ~c"1.8.5"} = :application.get_key(:phoenix, :vsn)
Mix.start()

defmodule RegistrationReloaderProbeEndpoint do
  def config(:reloadable_compilers), do: [:elixir]
  def config(:reloadable_apps), do: [:registration_reloader_probe]
end

defmodule RegistrationReloaderTrace do
  def loop(state) do
    receive do
      {:trace_ts, pid, :call, {module, function, args}, time} ->
        key = "#{inspect(module)}.#{function}/#{length(args)} call"
        event = %{pid: inspect(pid), mfa: key, args: inspect(args), time: time}
        loop(add(state, key, event, false))
      {:trace_ts, pid, :return_from, {module, function, arity}, result, time} ->
        key = "#{inspect(module)}.#{function}/#{arity} return #{inspect(result)}"
        event = %{pid: inspect(pid), mfa: key, time: time}
        loop(add(state, key, event, match?({:error, _}, result)))
      {:snapshot, from, ref} ->
        send(from, {ref, state})
        loop(state)
      :stop -> :ok
    end
  end

  defp add(state, key, event, error) do
    %{state | counts: Map.update(state.counts, key, 1, &(&1 + 1)),
              first: Enum.take(state.first ++ [event], 32),
              recent: Enum.take([event | state.recent], 64),
              errors: if(error, do: Enum.take([event | state.errors], 16), else: state.errors)}
  end
end

defmodule RegistrationReloaderQuery do
  def once do
    try do
      result = apply(Ecto.Queryable, :to_query, [Example.Accounts.User])
      true = Map.get(result, :__struct__) == Ecto.Query
      :ok
    rescue
      error in UndefinedFunctionError ->
        {:undefined, Map.take(error, [:module, :function, :arity, :reason])}
    end
  end

  def loop(parent, counts, errors) do
    receive do
      :stop -> send(parent, {:query_result, self(), counts, errors})
    after
      0 ->
        {counts, errors} =
          case once() do
            :ok -> {Map.update!(counts, :ok, &(&1 + 1)), errors}
            {:undefined, error} ->
              {Map.update!(counts, :undefined, &(&1 + 1)), Enum.take([error | errors], 8)}
          end
        loop(parent, counts, errors)
    end
  end
end

temp = Path.join(System.tmp_dir!(), "sigra253-reloader-#{System.unique_integer([:positive])}")
:ok = File.mkdir(temp)
File.mkdir_p!(Path.join(temp, "lib"))
File.mkdir_p!(Path.join(temp, "config"))
File.write!(Path.join(temp, "config/config.exs"), "import Config\n")
project = """
defmodule RegistrationReloaderProbe.MixProject do
  use Mix.Project
  def project do
    [app: :registration_reloader_probe, version: "0.0.0", deps: [],
     compilers: [:elixir, :app], consolidate_protocols: #{consolidate},
     listeners: [Phoenix.CodeReloader]]
  end
end
"""
File.write!(Path.join(temp, "mix.exs"), project)
File.write!(Path.join(temp, "lib/probe.ex"), "defmodule RegistrationReloaderProbe do\n  def marker, do: :ok\nend\n")
start = System.monotonic_time(:millisecond)

try do
  result = Mix.Project.in_project(:registration_reloader_probe, temp, fn _ ->
    Mix.Task.run("compile", ["--no-deps-check", "--no-archives-check"])
    true = File.exists?(Mix.Project.manifest_path() <> "/compile.elixir")
    # Mix prunes paths for a project with no declared dependencies. Restore only
    # read-only helper paths after the synthetic project has compiled. Copy the
    # original consolidated Queryable BEAM into our owned output, as the real
    # Example project does when compiling its Ecto dependency.
    for path <- Path.wildcard(Path.join(root, "test/example/_build/dev/lib/*/ebin")) do
      Code.prepend_path(path)
    end
    consolidation_path = Mix.Project.consolidation_path()
    File.mkdir_p!(consolidation_path)
    source_beam = Path.join(root, "test/example/_build/dev/lib/example/consolidated/Elixir.Ecto.Queryable.beam")
    File.cp!(source_beam, Path.join(consolidation_path, "Elixir.Ecto.Queryable.beam"))
    Code.prepend_path(consolidation_path)
    for _ <- 1..100, do: :ok = RegistrationReloaderQuery.once()
    {:ok, _listener} = Phoenix.CodeReloader.MixListener.start_link([])
    {:ok, server} = Phoenix.CodeReloader.Server.start_link([])
    tracer = spawn(fn -> RegistrationReloaderTrace.loop(%{counts: %{}, first: [], recent: [], errors: []}) end)

    # Trace the dependency implementation, not a copied approximation of its purge.
    for {mfa, flags, spec} <- [
          {{Phoenix.CodeReloader.Server, :purge_module, 1}, [:local], [{[Ecto.Queryable], [], [{:return_trace}]}]},
          {{:code, :delete, 1}, [], [{[Ecto.Queryable], [], [{:return_trace}]}]},
          {{:code, :purge, 1}, [], [{[Ecto.Queryable], [], [{:return_trace}]}]},
          {{:code, :ensure_loaded, 1}, [], [{[Ecto.Queryable], [], [{:return_trace}]}]},
          {{Code, :prepend_path, 1}, [], [{:_, [], [{:return_trace}]}]},
          {{Code, :delete_path, 1}, [], [{:_, [], [{:return_trace}]}]}
        ] do
      1 = :erlang.trace_pattern(mfa, spec, flags)
    end

    parent = self()
    workers = for _ <- 1..2 do
      spawn_monitor(fn ->
        receive do: (:start -> :ok)
        RegistrationReloaderQuery.loop(parent, %{ok: 0, undefined: 0}, [])
      end)
    end

    for pid <- [server | Enum.map(workers, &elem(&1, 0))] do
      1 = :erlang.trace(pid, true, [:call, :monotonic_timestamp, {:tracer, tracer}])
    end
    for {pid, _} <- workers, do: send(pid, :start)

    reloader_results = for i <- 1..rounds do
      if change != "none" do
        implementation = if change == "implementation", do: """
        defimpl Ecto.Queryable, for: RegistrationReloaderMarker#{i} do
          def to_query(_), do: Ecto.Queryable.to_query("probe")
        end
        """, else: ""
        File.write!(Path.join(temp, "lib/marker_#{i}.ex"), """
        defmodule RegistrationReloaderMarker#{i} do
          defstruct [:id]
        end
        #{implementation}
        """)
      end
      :ok = Phoenix.CodeReloader.Server.reload!(RegistrationReloaderProbeEndpoint, [])
      if System.monotonic_time(:millisecond) - start > 30_000, do: raise("probe exceeded30seconds")
      :ok
    end
    for {pid, _} <- workers, do: send(pid, :stop)
    results = for {pid, _} <- workers do
      receive do
        {:query_result, ^pid, counts, errors} -> %{counts: counts, errors: errors}
      after
        5000 -> raise "query worker did not return"
      end
    end
    for {pid, ref} <- workers do
      receive do
        {:DOWN, ^ref, :process, ^pid, :normal} -> :ok
        {:DOWN, ^ref, :process, ^pid, reason} -> raise "query worker exited: #{inspect(reason)}"
      after
        5000 -> raise "query worker was not reaped"
      end
    end
    :erlang.trace(server, false, [:all])
    delivered = :erlang.trace_delivered(:all)
    receive do: ({:trace_delivered, :all, ^delivered} -> :ok)
    ref = make_ref()
    send(tracer, {:snapshot, self(), ref})
    trace = receive do: ({^ref, state} -> state)
    send(tracer, :stop)
    GenServer.stop(server)
    :ok = RegistrationReloaderQuery.once()
    %{consolidate_protocols: consolidate, source_change: change, reloader_calls: length(reloader_results),
      workers: results, trace: trace, phoenix: "1.8.5", ecto: "3.13.5",
      elixir: System.version(), otp: System.otp_release(), control_queries_passed: 100,
      restored_query: "passed", experiment: "actual Phoenix reloader, isolated synthetic project",
      limitation: "isolated synthetic project, not the original full app or hosted VM; temporary source changes are controlled diagnostic inputs",
      browser_invocations: 0, ci_launches: 0, network_requests: 0,
      project_source: project}
  end)
  result = Map.put(result, :duration_ms, System.monotonic_time(:millisecond) - start)
  File.write!(Path.join(out, "result.json"), Jason.encode!(result, pretty: true) <> "\n")
  IO.puts("actual_reloader_probe_finished")
after
  File.rm_rf!(temp)
end
