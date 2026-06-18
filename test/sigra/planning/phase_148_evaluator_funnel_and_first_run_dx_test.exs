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
          "admin@demo.vaultr.test",
          "alice@demo.vaultr.test",
          "bob@demo.vaultr.test",
          "carol@demo.vaultr.test",
          "dave@demo.vaultr.test",
          "frank@demo.vaultr.test"
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

  test "148-04: UAT proxy contract uses shared Traefik without Sigra owning port 80" do
    up = read!("scripts/uat/up.sh")
    dockerfile = read!("scripts/uat/Dockerfile.example")
    compose = read!("scripts/uat/docker-compose.yml")
    dev_proxy_up = read!("scripts/dev-proxy/up.sh")
    dev_proxy_compose = read!("scripts/dev-proxy/docker-compose.yml")
    runbook = read!("scripts/uat/RUNBOOK.md")
    example = read!("test/example/README.md")
    local_dev = read!("guides/recipes/local-development.md")
    example_dev = read!("test/example/config/dev.exs")

    assert up =~ "--proxy"
    assert up =~ "--private-traefik"
    assert up =~ "--refresh-code"
    # --refresh-code is now a cache-aware image rebuild, not a forced runtime recompile.
    assert up =~ "--profile proxy build web"
    refute up =~ "mix deps.compile sigra --force"
    assert up =~ "fail_on_proxy_host_conflict"
    assert up =~ "dev.sigra.proxy-host"
    assert up =~ "dev_proxy-traefik-1"
    assert up =~ "scripts/dev-proxy/up.sh"
    assert up =~ "SIGRA_UAT_PROXY_NETWORK"
    assert up =~ "Project-private Traefik is not allowed to bind 127.0.0.1:80"
    refute up =~ "scoria"

    # Cache-correct Dockerfile: deps compiled in a build layer (no forced runtime recompile).
    assert dockerfile =~ "mix deps.compile"
    refute dockerfile =~ "mix deps.compile sigra --force"
    assert example_dev =~ "reloadable_apps: [:example, :sigra]"

    assert compose =~ "profiles: [\"proxy\"]"
    assert compose =~ "traefik.enable=true"
    assert compose =~ "traefik.docker.network=${SIGRA_UAT_PROXY_NETWORK:-proxy}"
    assert compose =~ "name: ${SIGRA_UAT_PROXY_NETWORK:-proxy}"
    assert compose =~ "external: true"
    assert compose =~ "profiles: [\"private-traefik\"]"
    assert compose =~ "${SIGRA_UAT_PROXY_PORT:-18080}:80"
    refute compose =~ "${SIGRA_UAT_PROXY_PORT:-80}:80"
    refute compose =~ "127.0.0.1:80:80"

    assert dev_proxy_up =~ "SIGRA_DEV_PROXY_PROJECT:-dev_proxy"
    assert dev_proxy_up =~ "SIGRA_DEV_PROXY_NETWORK:-proxy"
    assert dev_proxy_up =~ "docker network create"
    assert dev_proxy_compose =~ "--providers.docker=true"
    assert dev_proxy_compose =~ "--providers.docker.exposedbydefault=false"

    assert dev_proxy_compose =~
             "${SIGRA_DEV_PROXY_BIND:-127.0.0.1}:${SIGRA_DEV_PROXY_HTTP_PORT:-80}:80"

    assert dev_proxy_compose =~ "name: ${SIGRA_DEV_PROXY_NETWORK:-proxy}"
    assert dev_proxy_compose =~ "external: true"

    # The full shared-proxy contract now lives in the example README (canonical
    # evaluator doc) — unchanged.
    assert example =~ "dev_proxy-traefik-1"
    assert example =~ ~r/external Docker\s+network named `proxy`/
    assert example =~ "http://sigra.localhost"
    assert example =~ "scripts/dev-proxy/up.sh"
    assert example =~ "--private-traefik"
    assert example =~ "--refresh-code"
    assert example =~ "18080"
    refute example =~ "scoria"

    # The shared-proxy + per-branch-host workflow is documented in the
    # local-development guide (the runbook now points here rather than duplicating it).
    assert local_dev =~ "scripts/dev-proxy/up.sh"
    assert local_dev =~ "sigra.localhost"
    assert local_dev =~ "--private-traefik"
    assert local_dev =~ "--refresh-code"
    assert local_dev =~ ~r/shared .proxy. Docker network/
    refute local_dev =~ "scoria"

    # The runbook delegates environment setup to the guide instead of duplicating it.
    assert runbook =~ "guides/recipes/local-development.md"
  end
end
