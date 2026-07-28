defmodule Mix.Tasks.Sigra.Admin.List do
  use Mix.Task

  @shortdoc "List active platform-admin grants"
  @requirements ["app.config"]

  @impl Mix.Task
  def run(args), do: <%= app_module %>.SigraAdminTask.run(:list, args)
end
