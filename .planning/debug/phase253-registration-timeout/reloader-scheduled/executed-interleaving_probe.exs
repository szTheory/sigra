# Force a valid loader/reloader interleaving without changing either algorithm.
# The OTP source is renamed so only this probe's worker uses interpreted code;
# the VM's global error_handler remains untouched.
defmodule RegistrationLoaderInterleaving do
  def run(_server, temp, tracer) do
    source_path = Path.join(to_string(:code.lib_dir(:kernel, :src)), "error_handler.erl")
    original = File.read!(source_path)
    renamed = String.replace(original, "-module(error_handler).", "-module(sigra253_error_handler).")
    true = original != renamed
    true = String.replace(renamed, "-module(sigra253_error_handler).", "-module(error_handler).") == original
    source = Path.join(temp, "sigra253_error_handler.erl")
    File.write!(source, renamed)
    {:ok, :sigra253_error_handler, binary, []} = :compile.file(String.to_charlist(source), [:binary, :debug_info, :return_errors, :return_warnings])
    File.write!(Path.join(temp, "sigra253_error_handler.beam"), binary)
    Code.prepend_path(temp)
    [debugger_path] = Path.wildcard(Path.join([to_string(:code.root_dir()), "lib", "debugger-*", "ebin"]))
    Code.prepend_path(debugger_path)
    :int.start()
    {:module, :sigra253_error_handler} = :int.i(:sigra253_error_handler)
    :int.subscribe()
    line = original |> String.split("\n") |> Enum.find_index(&String.contains?(&1, "case erlang:function_exported(Module, Func, length(Args)) of"))
    true = is_integer(line)
    line = line + 1

    results = for purge <- [true, false] do
      :ok = RegistrationReloaderQuery.once()
      :ok = Phoenix.CodeReloader.Server.reload!(RegistrationReloaderProbeEndpoint, [])
      false = :code.is_loaded(Ecto.Queryable)
      :ok = :int.break(:sigra253_error_handler, line)
      parent = self()
      {worker, ref} = spawn_monitor(fn ->
        receive do: (:start -> :ok)
        :erlang.process_flag(:error_handler, :sigra253_error_handler)
        outcome = try do
          value = apply(Ecto.Queryable, :to_query, [Example.Accounts.User])
          true = Map.get(value, :__struct__) == Ecto.Query
          %{status: "passed"}
        rescue
          error in UndefinedFunctionError ->
            %{status: "undefined", module: inspect(error.module), function: to_string(error.function),
              arity: error.arity, message: Exception.message(error),
              first_stack_frame: inspect(hd(__STACKTRACE__))}
        end
        send(parent, {:controlled_result, self(), outcome})
      end)
      1 = :erlang.trace(worker, true, [:call, :monotonic_timestamp, {:tracer, tracer}])
      send(worker, :start)
      wait_break(worker, line, System.monotonic_time(:millisecond) + 5000)
      true = :erlang.function_exported(Ecto.Queryable, :to_query, 1)
      :int.delete_break(:sigra253_error_handler, line)
      if purge do
        :ok = Phoenix.CodeReloader.Server.reload!(RegistrationReloaderProbeEndpoint, [])
        false = :code.is_loaded(Ecto.Queryable)
      end
      :ok = :int.continue(worker)
      outcome = receive do
        {:controlled_result, ^worker, value} -> value
      after
        5000 -> raise "controlled query did not complete"
      end
      receive do
        {:DOWN, ^ref, :process, ^worker, :normal} -> :ok
        {:DOWN, ^ref, :process, ^worker, reason} -> raise "controlled worker exited: #{inspect(reason)}"
      after
        5000 -> raise "controlled worker not reaped"
      end
      expected = if purge, do: "undefined", else: "passed"
      true = outcome.status == expected
      Map.merge(outcome, %{purged_after_ensure_loaded: purge, breakpoint_line: line})
    end
    :int.stop()
    %{cases: results, actual_reloader_calls: 3, source_path: source_path,
      source_sha256: Base.encode16(:crypto.hash(:sha256, original), case: :lower),
      interpreted_source_sha256: Base.encode16(:crypto.hash(:sha256, renamed), case: :lower),
      only_source_change: "module declaration renamed; breakpoint controls scheduling",
      original_handler_globally_replaced: false}
  end

  defp wait_break(worker, line, deadline) do
    if System.monotonic_time(:millisecond) > deadline, do: raise("loader breakpoint not reached")
    receive do
      {:int, {:new_status, ^worker, :break, {:sigra253_error_handler, ^line}}} -> :ok
      {:int, {:new_process, {^worker, _, :break, {:sigra253_error_handler, ^line}}}} -> :ok
      _ -> wait_break(worker, line, deadline)
    after
      1000 -> wait_break(worker, line, deadline)
    end
  end
end

System.put_env("SIGRA_DEBUG_INTERLEAVING", "true")
Code.require_file(Path.join(__DIR__, "reloader_probe.exs"))
