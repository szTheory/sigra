%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "test/"],
        excluded: ["deps/"]
      },
      # Load Sigra's custom Credo checks before running. Credo's
      # RequireRequires task Code.require_file/1s each path. The sources
      # live in the normal lib/ tree and are compiled by `mix compile`,
      # but Credo does not load the host app automatically (runtime: false
      # in mix.exs), so we explicitly require the check source here.
      requires: ["lib/sigra/credo/no_log_safe2_in_lib.ex"],
      strict: true,
      color: true,
      checks: %{
        extra: [
          {Sigra.Credo.NoLogSafe2InLib, []}
        ]
      }
    }
  ]
}
