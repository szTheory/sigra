defmodule Sigra.ArchitectureGuidesContractTest do
  use ExUnit.Case, async: true

  @architecture "guides/introduction/architecture.md"
  @walkthrough "guides/introduction/code-walkthrough.md"

  @forbidden_published_paths ~r{
    (?:lib/|priv/templates/|test/example/|test/sigra/)|
    github[^\s)]*/blob/|
    \#L\d+
  }ix

  @architecture_headings [
    "## The boundary that makes Sigra work",
    "## Sigra in one picture",
    "## Vocabulary for the trip",
    "## Journey 1: Installation creates an ownership boundary",
    "## Journey 2: A login becomes durable identity and session state",
    "## Security is the architecture",
    "## Cross-cutting mechanics",
    "## Module atlas",
    "## Code-reading routes",
    "## Changing Sigra safely",
    "## Where to go next"
  ]

  @source_anchors [
    %{
      name: "Runner enabled-feature filtering",
      source: "lib/sigra/install/runner.ex",
      source_line: "active = Enum.filter(features, fn f -> f.enabled?(opts) end)",
      walkthrough_line: "active = Enum.filter(features, fn f -> f.enabled?(opts) end)"
    },
    %{
      name: "Ecto session raw/hashed token split",
      source: "lib/sigra/session_stores/ecto.ex",
      source_line: "{raw_token, hashed_token} = Sigra.Token.generate_hashed_token()",
      walkthrough_line: "{raw_token, hashed_token} = Sigra.Token.generate_hashed_token()"
    },
    %{
      name: "Plug session identifier renewal",
      source: "priv/templates/sigra.install/core/user_auth.ex",
      source_line: "|> configure_session(renew: true)",
      walkthrough_line: "|> configure_session(renew: true)"
    },
    %{
      name: "Plug session clearing",
      source: "priv/templates/sigra.install/core/user_auth.ex",
      source_line: "|> clear_session()",
      walkthrough_line: "|> clear_session()"
    },
    %{
      name: "Audit insertion into caller-owned Multi",
      source: "lib/sigra/auth.ex",
      source_line: "|> Audit.log_multi_safe(",
      walkthrough_line: "|> Audit.log_multi_safe("
    },
    %{
      name: "Audit telemetry after commit",
      source: "lib/sigra/auth.ex",
      source_line: "Audit.emit_telemetry_from_changes(changes)",
      walkthrough_line: "Audit.emit_telemetry_from_changes(changes)"
    },
    %{
      name: "Oban supervision-aware forwarding",
      source: "lib/sigra/audit/forwarders.ex",
      source_line: "Sigra.OptionalDeps.oban_running?()",
      walkthrough_line: "Sigra.OptionalDeps.oban_running?()"
    }
  ]

  test "guides are ordered ExDoc extras and discoverable from the intended reading path" do
    assert File.regular?(@architecture), "missing #{@architecture}"
    assert File.regular?(@walkthrough), "missing #{@walkthrough}"

    mix = File.read!("mix.exs")

    assert mix =~
             ~r{
               "guides/introduction/getting-started\.md",\s*
               "guides/introduction/architecture\.md",\s*
               "guides/introduction/code-walkthrough\.md"
             }x,
           "ExDoc extras must list getting-started, architecture, then code-walkthrough"

    readme = File.read!("README.md")
    first_hour = File.read!("guides/introduction/first-hour.md")

    assert readme =~ "guides/introduction/architecture.md"
    assert readme =~ "guides/introduction/code-walkthrough.md"
    assert first_hour =~ "architecture.html"
    assert first_hour =~ "code-walkthrough.html"

    architecture = File.read!(@architecture)
    walkthrough = File.read!(@walkthrough)

    assert architecture =~ "code-walkthrough.html"
    assert walkthrough =~ "architecture.html"
  end

  test "architecture keeps the boundary-first narrative order" do
    architecture = File.read!(@architecture)

    indexes =
      Enum.map(@architecture_headings, fn heading ->
        case :binary.match(architecture, heading) do
          {index, _length} -> index
          :nomatch -> flunk("architecture guide is missing essential heading: #{heading}")
        end
      end)

    assert indexes == Enum.sort(indexes),
           "architecture headings drifted from the required outside-in journey order"

    assert indexes == Enum.uniq(indexes), "architecture headings must each appear once"
  end

  test "architecture contains four accessible Mermaid diagrams" do
    diagrams = fenced_blocks(File.read!(@architecture), "mermaid")

    assert length(diagrams) == 4,
           "architecture must contain exactly four Mermaid diagrams, got #{length(diagrams)}"

    Enum.with_index(diagrams, 1)
    |> Enum.each(fn {diagram, number} ->
      [declaration, acc_title, acc_description | _rest] = String.split(diagram, "\n")

      assert declaration =~ ~r/^(flowchart|sequenceDiagram)\b/,
             "Mermaid diagram #{number} must put its declaration first"

      assert String.starts_with?(acc_title, "  accTitle:"),
             "Mermaid diagram #{number} must put accTitle immediately after its declaration"

      assert String.starts_with?(acc_description, "  accDescr:"),
             "Mermaid diagram #{number} must put accDescr immediately after accTitle"
    end)
  end

  test "walkthrough excerpts remain bounded and parseable" do
    blocks = fenced_blocks(File.read!(@walkthrough), "elixir")

    assert length(blocks) in 12..18,
           "walkthrough must contain 12-18 Elixir excerpts, got #{length(blocks)}"

    Enum.with_index(blocks, 1)
    |> Enum.each(fn {block, number} ->
      line_count = block |> String.trim_trailing() |> String.split("\n") |> length()

      assert line_count in 8..35,
             "walkthrough excerpt #{number} has #{line_count} lines; expected 8-35"

      case Code.string_to_quoted(block) do
        {:ok, _ast} ->
          :ok

        {:error, error} ->
          flunk("walkthrough excerpt #{number} does not parse: #{inspect(error)}")
      end
    end)
  end

  test "published guides do not expose repository-path or line-anchor navigation" do
    Enum.each([@architecture, @walkthrough], fn path ->
      body = File.read!(path)

      refute body =~ @forbidden_published_paths,
             "#{path} must use module pages and View Source, not repository paths or line anchors"
    end)
  end

  test "Mermaid hook is pinned, strict, navigation-aware, and fallback-safe" do
    mix = File.read!("mix.exs")

    assert mix =~ "https://cdn.jsdelivr.net/npm/mermaid@11.16.0/dist/mermaid.min.js"
    assert mix =~ ~r/integrity="sha384-[A-Za-z0-9+\/=]{64}"/
    refute mix =~ "sha384-PLACEHOLDER"
    assert mix =~ "startOnLoad: false"
    assert mix =~ ~s(securityLevel: "strict")
    assert mix =~ "suppressErrorRendering: true"
    assert mix =~ ~s|window.addEventListener("exdoc:loaded", renderMermaid)|
    assert mix =~ "window.__sigraMermaidHookInstalled"
    assert mix =~ "catch (error)"
    assert mix =~ "delete code.dataset.mermaidPending"
    assert mix =~ ~s|defp before_closing_head_tag(:epub), do: ""|
    assert mix =~ ~s|defp before_closing_body_tag(:epub), do: ""|

    html_index = byte_index!(mix, "container.innerHTML = svg")
    rendered_index = byte_index!(mix, ~s(code.dataset.mermaidRendered = "true"))
    hide_index = byte_index!(mix, "source.hidden = true")

    assert html_index < rendered_index and rendered_index < hide_index,
           "Mermaid source must be hidden only after successful SVG rendering"
  end

  test "walkthrough source anchors fail actionably when implementation drifts" do
    walkthrough = File.read!(@walkthrough)

    Enum.each(@source_anchors, fn anchor ->
      source = File.read!(anchor.source)

      assert source =~ anchor.source_line,
             "#{anchor.name} moved in #{anchor.source}; refresh the walkthrough excerpt and anchor"

      assert walkthrough =~ anchor.walkthrough_line,
             "walkthrough lost the #{anchor.name} excerpt line: #{anchor.walkthrough_line}"
    end)
  end

  test "lockout remains before password verification in source and walkthrough" do
    source = File.read!("lib/sigra/auth.ex")
    [_before, config_path] = String.split(source, "defp authenticate_with_config", parts: 2)
    walkthrough = File.read!(@walkthrough)

    assert byte_index!(config_path, "Sigra.Lockout.check(user, lockout_opts)") <
             byte_index!(config_path, "Crypto.verify_with_upgrade(password, hashed_password)"),
           "config authentication must check lockout before password verification"

    assert byte_index!(walkthrough, "Sigra.Lockout.check(user, lockout_opts)") <
             byte_index!(walkthrough, "Crypto.verify_with_upgrade(password, hashed_password)"),
           "walkthrough must preserve lockout-before-password ordering"
  end

  test "documented double-session seam remains anchored to generated-host evidence" do
    generated_context = File.read!("test/example/lib/example/accounts.ex")
    generated_web = File.read!("test/example/lib/example_web/user_auth.ex")
    walkthrough = File.read!(@walkthrough)

    collapse = "{:ok, user, _session_meta} -> {:ok, user}"

    second_create =
      "Example.Accounts.generate_user_session_token(user, ip: ip, user_agent: user_agent)"

    assert generated_context =~ collapse,
           "generated host no longer collapses session metadata; update the documented seam"

    assert generated_web =~ second_create,
           "generated UserAuth no longer creates the later session; update the documented seam"

    assert walkthrough =~ collapse
    assert walkthrough =~ second_create
    assert walkthrough =~ ~r/current implementation\s+drift/
  end

  defp fenced_blocks(body, language) do
    ~r/```#{Regex.escape(language)}\n(.*?)```/s
    |> Regex.scan(body, capture: :all_but_first)
    |> List.flatten()
  end

  defp byte_index!(body, needle) do
    case :binary.match(body, needle) do
      {index, _length} -> index
      :nomatch -> flunk("missing expected contract text: #{needle}")
    end
  end
end
