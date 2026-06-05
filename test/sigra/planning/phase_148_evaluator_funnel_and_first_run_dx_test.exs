defmodule Sigra.Planning.Phase148EvaluatorFunnelAndFirstRunDxTest do
  @moduledoc """
  Nyquist validation for Phase 148 evaluator funnel and first-run DX contracts.
  """

  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  defp root do
    Path.expand("../../..", __DIR__)
  end

  defp read!(rel) do
    root() |> Path.join(rel) |> File.read!()
  end

  test "148-01: routing contract points evaluators to the same showcase lane across surfaces" do
    readme = read!("README.md")
    mix_exs = read!("mix.exs")
    llms = read!("doc/llms.txt")

    assert readme =~ "Pick your lane"

    assert readme =~
             "| **Evaluating** | Start with the [Demo Showcase](guides/introduction/demo-showcase.md)"

    assert readme =~ "Troubleshooting install"

    assert mix_exs =~ ~s(main: "demo-showcase")
    assert mix_exs =~ "Evaluating first? Start with https://hexdocs.pm/sigra/demo-showcase.html."

    assert llms =~ "- [Demo Showcase — Vaultr Example App](demo-showcase.md)"
    assert llms =~ "- [Troubleshooting install](troubleshooting-install.md)"
    assert llms =~ "Evaluating first? Start with https://hexdocs.pm/sigra/demo-showcase.html."
  end

  test "148-02: demo showcase locks runnable command, personas, screenshot proof, and boundary language" do
    showcase = read!("guides/introduction/demo-showcase.md")
    example = read!("test/example/README.md")

    assert showcase =~ "scripts/uat/up.sh"
    assert showcase =~ "scripts/uat/status.sh"
    assert showcase =~ "printed `/demo/credentials` URL"
    assert showcase =~ "mix setup && mix phx.server"

    for email <- [
          "admin@demo.sigra.dev",
          "alice@demo.sigra.dev",
          "bob@demo.sigra.dev",
          "carol@demo.sigra.dev",
          "dave@demo.sigra.dev",
          "frank@demo.sigra.dev"
        ] do
      assert showcase =~ email
    end

    for asset <- [
          "demo-credentials-demo-showcase-chromium.png",
          "admin-user-list-demo-showcase-chromium.png",
          "admin-user-detail-demo-showcase-chromium.png",
          "audit-explorer-demo-showcase-chromium.png"
        ] do
      assert showcase =~ asset
    end

    assert showcase =~ "not production certification"
    assert showcase =~ "not compliance evidence"

    assert example =~
             "Vaultr is the runnable local companion for Sigra's canonical evaluator walkthrough:"

    assert example =~ "[Demo Showcase](https://hexdocs.pm/sigra/demo-showcase.html)"
  end

  test "148-03: first-run troubleshooting preserves exact doctor states, verdicts, and exit contract" do
    troubleshooting = read!("guides/introduction/troubleshooting-install.md")

    assert troubleshooting =~ "mix sigra.doctor"
    assert troubleshooting =~ "mix sigra.doctor --quiet"
    assert troubleshooting =~ "[ ] missing"
    assert troubleshooting =~ "[~] available"
    assert troubleshooting =~ "[✓] loaded"
    assert troubleshooting =~ "[!] misconfigured"

    assert troubleshooting =~ "OK: all configured features are properly wired."

    assert troubleshooting =~
             "ERROR: misconfigured features detected (see above). Fix the issues above before deploying."

    assert troubleshooting =~ "exit 0"
    assert troubleshooting =~ "exit 1"

    dep_off_opts = [
      predicates: %{
        oban: false,
        bcrypt: false,
        eqrcode: false,
        threadline: false,
        assent: false,
        swoosh: false,
        joken: false,
        hammer: false,
        req: false,
        encryption_active: false
      },
      host_sigra: []
    ]

    assert capture_io(fn ->
             Mix.Tasks.Sigra.Doctor.run_with_opts(dep_off_opts)
           end) =~ "OK: all configured features are properly wired."

    configured_oauth_without_assent =
      Keyword.merge(dep_off_opts,
        host_sigra: [oauth: [providers: [github: [client_id: "id", client_secret: "secret"]]]]
      )

    assert catch_exit(
             capture_io(:stderr, fn ->
               capture_io(fn ->
                 Mix.Tasks.Sigra.Doctor.run_with_opts(configured_oauth_without_assent)
               end)
             end)
           ) == {:shutdown, 1}
  end
end
