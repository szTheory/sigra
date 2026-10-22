root = System.get_env("SIGRA_DEBUG_ROOT", File.cwd!())

for path <- Path.wildcard(Path.join(root, "test/example/_build/dev/lib/*/ebin")) do
  Code.prepend_path(path)
end

{:module, module} = Code.ensure_loaded(ExampleWeb.Endpoint)
beam = :code.which(module)
{:ok, {^module, [imports: imports]}} = :beam_lib.chunks(beam, [:imports])
reload_calls = Enum.filter(imports, fn {mod, _, _} -> mod in [Phoenix.CodeReloader, Phoenix.LiveReloader] end)
[] = reload_calls
sockets = module.__sockets__()
false = Enum.any?(sockets, fn {path, _, _} -> path == "/phoenix/live_reload/socket" end)
true = Enum.any?(sockets, fn {path, _, _} -> path == "/live" end)

result = %{
  status: "compiled_ci_endpoint_has_no_reloader",
  beam_sha256: Base.encode16(:crypto.hash(:sha256, File.read!(beam)), case: :lower),
  reloader_calls: [],
  live_reload_socket: false,
  liveview_socket_retained: true,
  app_started: false,
  browser_invocations: 0,
  ci_launches: 0
}

IO.puts(Jason.encode!(result, pretty: true))
