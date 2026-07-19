defmodule Mix.Tasks.Sigra.Admin.Check do
  use Mix.Task

  @shortdoc "Check whether an account has platform-admin access"
  @requirements ["app.config"]

  @impl Mix.Task
  def run(args), do: SigraInstallGoldenTmp.SigraAdminTask.run(:check, args)
end
