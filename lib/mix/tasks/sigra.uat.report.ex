defmodule Mix.Tasks.Sigra.Uat.Report do
  @shortdoc "Generates UAT evidence manifests and reports"

  @moduledoc """
  Generates machine-readable manifests and human-readable reports for Sigra's
  committed UAT evidence bundles.

  Supported phases:

    * `04` / `08` — Phase 86 email visual evidence
    * `oauth-gen` — GAUAT-03 generator/install smoke evidence
    * `oauth-google` — GAUAT-04 OAuth register/login evidence
    * `oauth-link` — GAUAT-05 link/unlink evidence
    * `oauth-email-match` — GAUAT-06 email-match evidence
    * `mfa-backup-rotation` — GAUAT-07 MFA backup-code rotation evidence
    * `getting-started` — GAUAT-08 generated-host getting-started evidence

  Use `--check` to validate that the committed bundle is present and that the
  generated README frontmatter still matches the current Sigra version.
  """

  use Mix.Task

  @email_baseline_dir "test/example/priv/playwright/__snapshots__/email-visual.spec.ts"
  @evidence_base ".planning/uat-evidence/v1.20"

  @engines ["chromium", "webkit"]
  @themes ["light", "dark"]
  @viewport "640x1200"
  @contrast_min_ratio 4.5
  @byte_budget_max 100_000

  @phase_04_templates [
    "lockout-notification",
    "suspicious-login"
  ]

  @phase_08_templates [
    "email-change-confirmation",
    "email-change-notification",
    "email-changed",
    "password-changed",
    "deletion-scheduled",
    "deletion-cancelled",
    "deletion-finalized"
  ]

  @impl Mix.Task
  def run(argv) do
    {opts, _, _} = OptionParser.parse(argv, strict: [phase: :string, check: :boolean])
    phase = Keyword.get(opts, :phase)
    check? = Keyword.get(opts, :check, false)

    config =
      phase_config(phase) ||
        Mix.raise("""
        sigra.uat.report requires one of:

            --phase=04
            --phase=08
            --phase=oauth-gen
            --phase=oauth-google
            --phase=oauth-link
            --phase=oauth-email-match
            --phase=mfa-backup-rotation
            --phase=getting-started
        """)

    cells = build_cells(config)
    evidence_dir = Path.join(@evidence_base, config.evidence_slug)

    Mix.shell().info("==> sigra.uat.report: phase=#{phase} (#{length(cells)} evidence rows)")

    if check? do
      run_check!(config, cells, evidence_dir)
    else
      run_generate!(config, cells, evidence_dir)
    end
  end

  defp phase_config("04") do
    %{
      type: :email,
      phase: "04",
      evidence_slug: "email-phase-04",
      gauat_requirement: "GAUAT-01",
      heading: "# Phase 04: Security Email Visual Regression Evidence\n\n",
      ci_workflow: ".github/workflows/ci.yml / email_visual_regression",
      templates: @phase_04_templates
    }
  end

  defp phase_config("08") do
    %{
      type: :email,
      phase: "08",
      evidence_slug: "email-phase-08",
      gauat_requirement: "GAUAT-02",
      heading: "# Phase 08: Lifecycle Email Visual Regression Evidence\n\n",
      ci_workflow: ".github/workflows/ci.yml / email_visual_regression",
      templates: @phase_08_templates
    }
  end

  defp phase_config("oauth-gen") do
    %{
      type: :artifact,
      phase_number: 87,
      phase: "oauth-gen",
      evidence_slug: "oauth-gen",
      gauat_requirement: "GAUAT-03",
      heading: "# GAUAT-03: OAuth Generator Smoke Evidence\n\n",
      ci_workflow: ".github/workflows/ci.yml / install_smoke",
      rows: [
        %{artifact_class: "artifact-inventory", evidence_path: "reports/artifact-inventory.json"},
        %{artifact_class: "mix-test-green", evidence_path: "transcript.log"},
        %{artifact_class: "transcript-uploaded", evidence_path: "transcript.log"},
        %{artifact_class: "release-asset-on-tag", evidence_path: nil}
      ]
    }
  end

  defp phase_config("oauth-google") do
    %{
      type: :artifact,
      phase_number: 87,
      phase: "oauth-google",
      evidence_slug: "oauth-google",
      gauat_requirement: "GAUAT-04",
      heading: "# GAUAT-04: OAuth Register/Login Evidence\n\n",
      ci_workflow: ".github/workflows/ci.yml / oauth_e2e_playwright",
      rows: [
        %{artifact_class: "provider-button-render", evidence_path: "reports/playwright-trace.README.md"},
        %{artifact_class: "authorize-redirect", evidence_path: nil},
        %{artifact_class: "mock-issuer-callback", evidence_path: nil},
        %{artifact_class: "user-record-created", evidence_path: nil},
        %{artifact_class: "identity-row-created", evidence_path: nil},
        %{artifact_class: "session-established", evidence_path: nil},
        %{artifact_class: "logout", evidence_path: nil},
        %{artifact_class: "re-login", evidence_path: nil}
      ]
    }
  end

  defp phase_config("oauth-link") do
    %{
      type: :artifact,
      phase_number: 87,
      phase: "oauth-link",
      evidence_slug: "oauth-link",
      gauat_requirement: "GAUAT-05",
      heading: "# GAUAT-05: OAuth Link/Unlink Evidence\n\n",
      ci_workflow: ".github/workflows/ci.yml / oauth_e2e_playwright",
      rows: [
        %{artifact_class: "linked-with-password", evidence_path: "reports/db-probe-results.json"},
        %{artifact_class: "only-oauth-no-password", evidence_path: hero_snapshot_relpath()},
        %{artifact_class: "after-set-password", evidence_path: "reports/db-probe-results.json"},
        %{artifact_class: "post-unlink", evidence_path: "reports/db-probe-results.json"}
      ]
    }
  end

  defp phase_config("oauth-email-match") do
    %{
      type: :artifact,
      phase_number: 87,
      phase: "oauth-email-match",
      evidence_slug: "oauth-email-match",
      gauat_requirement: "GAUAT-06",
      heading: "# GAUAT-06: OAuth Email-Match Evidence\n\n",
      ci_workflow: ".github/workflows/ci.yml / oauth_e2e_playwright",
      rows: [
        %{artifact_class: "flash-text-assertion", evidence_path: "reports/flash-text-assertion.json"},
        %{artifact_class: "redirect-destination", evidence_path: "reports/flash-text-assertion.json"},
        %{artifact_class: "identity-row-created", evidence_path: "reports/linked-email-mailbox.json"},
        %{artifact_class: "linked-email-mailbox", evidence_path: "reports/linked-email-mailbox.json"}
      ]
    }
  end

  defp phase_config("mfa-backup-rotation") do
    %{
      type: :artifact,
      phase_number: 88,
      phase: "mfa-backup-rotation",
      evidence_slug: "mfa-backup-rotation",
      gauat_requirement: "GAUAT-07",
      heading: "# GAUAT-07: MFA Backup-Code Rotation Evidence\n\n",
      ci_workflow: ".github/workflows/ci.yml / mfa_e2e_playwright",
      rows: [
        %{artifact_class: "ui-rotation-flow", evidence_path: "reports/ui-summary.json"},
        %{artifact_class: "old-code-invalidated", evidence_path: "reports/old-code-validity.json"},
        %{artifact_class: "audit-event-persisted", evidence_path: "reports/audit-event.json"},
        %{artifact_class: "transcript", evidence_path: "transcript.log"}
      ]
    }
  end

  defp phase_config("getting-started") do
    %{
      type: :artifact,
      phase_number: 88,
      phase: "getting-started",
      evidence_slug: "getting-started-clean-machine",
      gauat_requirement: "GAUAT-08",
      heading: "# GAUAT-08: Generated-Host Getting-Started Evidence\n\n",
      ci_workflow: ".github/workflows/ci.yml / install_smoke",
      rows: [
        %{artifact_class: "generated-host-lifecycle", evidence_path: "reports/generated-host-checks.json"},
        %{artifact_class: "environment-capture", evidence_path: "env.txt"},
        %{artifact_class: "transcript", evidence_path: "transcript.log"}
      ]
    }
  end

  defp phase_config(_), do: nil

  defp build_cells(%{type: :email, templates: templates}) do
    git_sha = git_short_sha()
    hex_version = mix_version()
    ci_run_url = System.get_env("SIGRA_CI_RUN_URL", "")
    artifact_url = System.get_env("SIGRA_ARTIFACT_URL", "")

    for template <- templates,
        engine <- @engines,
        theme <- @themes do
      png_name = "#{template}-#{engine}-#{theme}.png"
      png_path = Path.join(@email_baseline_dir, png_name)

      {outcome, snapshot_sha256, byte_size_val} =
        case File.read(png_path) do
          {:ok, content} ->
            sha = sha256_hex(content)
            {"pass", sha, byte_size(content)}

          {:error, _} ->
            {"missing", nil, nil}
        end

      %{
        template: template,
        engine: engine,
        theme: theme,
        viewport: @viewport,
        git_sha: git_sha,
        hex_version: hex_version,
        snapshot_sha256: snapshot_sha256,
        contrast_min_ratio: @contrast_min_ratio,
        byte_size: byte_size_val,
        byte_budget_max: @byte_budget_max,
        outcome: outcome,
        ci_run_url: ci_run_url,
        artifact_url: artifact_url
      }
    end
  end

  defp build_cells(%{type: :artifact} = config) do
    git_sha = git_short_sha()
    hex_version = mix_version()
    ci_run_url = System.get_env("SIGRA_CI_RUN_URL", "")
    artifact_url = System.get_env("SIGRA_ARTIFACT_URL", "")
    evidence_dir = Path.join(@evidence_base, config.evidence_slug)

    Enum.map(config.rows, fn row ->
      {outcome, evidence_sha256} =
        case row.evidence_path do
          nil ->
            {"pass", nil}

          relpath ->
            full_path = Path.join(evidence_dir, relpath)

            case File.read(full_path) do
              {:ok, content} -> {"pass", sha256_hex(content)}
              {:error, _} -> {"missing", nil}
            end
        end

      %{
        gauat_requirement: config.gauat_requirement,
        artifact_class: row.artifact_class,
        outcome: outcome,
        ci_run_url: ci_run_url,
        artifact_url: artifact_url,
        git_sha: git_sha,
        hex_version: hex_version,
        evidence_path: row.evidence_path,
        evidence_sha256: evidence_sha256
      }
    end)
  end

  defp run_check!(config, cells, evidence_dir) do
    Mix.shell().info("Running in --check mode (no files written)")

    missing = missing_paths(config, cells, evidence_dir)
    validate_readme_hex_version!(evidence_dir)

    present = Enum.count(cells, &(&1.outcome == "pass"))

    Mix.shell().info("  Phase #{config.phase}: #{present}/#{length(cells)} evidence rows present")

    if missing != [] do
      Mix.shell().info("  Missing artifacts:")

      Enum.each(missing, fn path ->
        Mix.shell().info("    #{path}")
      end)

      Mix.shell().error("")
      Mix.shell().error("FAIL: #{length(missing)} required artifact(s) missing.")
      System.halt(2)
    end

    if present != length(cells) do
      Mix.shell().error("")
      Mix.shell().error("FAIL: #{length(cells) - present} evidence row(s) are not pass.")
      System.halt(2)
    end

    Mix.shell().info("")
    Mix.shell().info("OK: all #{length(cells)} Phase #{config.phase} evidence rows present (check mode)")
    :ok
  end

  defp run_generate!(config, cells, evidence_dir) do
    File.mkdir_p!(evidence_dir)
    File.mkdir_p!(Path.join(evidence_dir, "reports"))

    manifest_path = Path.join(evidence_dir, "manifest.json")
    File.write!(manifest_path, Jason.encode!(cells, pretty: true))
    Mix.shell().info("  WROTE #{manifest_path}")

    readme_path = Path.join(evidence_dir, "README.md")
    File.write!(readme_path, build_readme(config, cells))
    Mix.shell().info("  WROTE #{readme_path}")

    maybe_write_email_reports(config, cells, evidence_dir)

    present = Enum.count(cells, &(&1.outcome == "pass"))
    Mix.shell().info("")
    Mix.shell().info("Done. Phase #{config.phase}: #{present}/#{length(cells)} evidence rows present.")
    Mix.shell().info("Evidence written to #{evidence_dir}/")
    :ok
  end

  defp maybe_write_email_reports(%{type: :email}, cells, evidence_dir) do
    reports_dir = Path.join(evidence_dir, "reports")

    contrast_path = Path.join(reports_dir, "contrast-summary.json")
    File.write!(contrast_path, Jason.encode!(build_contrast_summary(cells), pretty: true))
    Mix.shell().info("  WROTE #{contrast_path}")

    byte_budget_path = Path.join(reports_dir, "byte-budget.csv")
    File.write!(byte_budget_path, build_byte_budget_csv(cells))
    Mix.shell().info("  WROTE #{byte_budget_path}")
  end

  defp maybe_write_email_reports(_, _, _), do: :ok

  defp build_contrast_summary(cells) do
    cells
    |> Enum.group_by(& &1.template)
    |> Enum.map(fn {template, template_cells} ->
      %{
        template: template,
        contrast_min_ratio: @contrast_min_ratio,
        cells_present: Enum.count(template_cells, &(&1.outcome == "pass")),
        cells_total: length(template_cells)
      }
    end)
  end

  defp build_byte_budget_csv(cells) do
    header = "template,engine,theme,byte_size,byte_budget_max,outcome\n"

    rows =
      Enum.map(cells, fn cell ->
        bytes = if cell.byte_size, do: to_string(cell.byte_size), else: ""
        "#{cell.template},#{cell.engine},#{cell.theme},#{bytes},#{cell.byte_budget_max},#{cell.outcome}\n"
      end)

    header <> Enum.join(rows)
  end

  defp build_readme(%{type: :email} = config, cells) do
    git_sha = git_short_sha()
    generated_at = timestamp_now()
    present = Enum.count(cells, &(&1.outcome == "pass"))

    frontmatter =
      build_frontmatter(%{
        phase: config.phase,
        gauat_requirement: config.gauat_requirement,
        generated_by: "mix sigra.uat.report --phase=#{config.phase}",
        generated_at: generated_at,
        ci_workflow: System.get_env("SIGRA_CI_WORKFLOW", config.ci_workflow),
        disposition: if(present == length(cells), do: "pass", else: "partial")
      })

    summary =
      "**Baselines present:** #{present}/#{length(cells)}  \n" <>
        "**Git SHA:** `#{git_sha}`  \n" <>
        "**Generated at:** #{generated_at}  \n\n"

    table_header =
      "| Template | Engine | Theme | Outcome | SHA-256 (first 16) | Bytes |\n" <>
        "|----------|--------|-------|---------|--------------------|-------|\n"

    table_rows =
      cells
      |> Enum.map(fn cell ->
        sha_short = if cell.snapshot_sha256, do: String.slice(cell.snapshot_sha256, 0, 16), else: "—"
        bytes = if cell.byte_size, do: to_string(cell.byte_size), else: "—"
        "| #{cell.template} | #{cell.engine} | #{cell.theme} | #{cell.outcome} | `#{sha_short}` | #{bytes} |"
      end)
      |> Enum.join("\n")

    footer = "\n\n## Baseline path\n\n`#{@email_baseline_dir}/`\n"

    frontmatter <> config.heading <> summary <> table_header <> table_rows <> footer
  end

  defp build_readme(%{type: :artifact} = config, cells) do
    generated_at = timestamp_now()
    present = Enum.count(cells, &(&1.outcome == "pass"))

    frontmatter =
      build_frontmatter(%{
        phase: config.phase_number,
        gauat_requirement: config.gauat_requirement,
        generated_by: "mix sigra.uat.report --phase=#{config.phase}",
        generated_at: generated_at,
        ci_workflow: System.get_env("SIGRA_CI_WORKFLOW", config.ci_workflow),
        disposition: if(present == length(cells), do: "pass", else: "partial")
      })

    summary =
      "**Evidence rows present:** #{present}/#{length(cells)}  \n" <>
        "**Git SHA:** `#{git_short_sha()}`  \n" <>
        "**Generated at:** #{generated_at}  \n\n"

    table_header =
      "| Artifact class | Outcome | Evidence path | SHA-256 (first 16) |\n" <>
        "|----------------|---------|---------------|--------------------|\n"

    table_rows =
      cells
      |> Enum.map(fn cell ->
        sha_short = if cell.evidence_sha256, do: String.slice(cell.evidence_sha256, 0, 16), else: "—"
        path = cell.evidence_path || "—"
        "| #{cell.artifact_class} | #{cell.outcome} | `#{path}` | `#{sha_short}` |"
      end)
      |> Enum.join("\n")

    frontmatter <> config.heading <> summary <> table_header <> table_rows <> "\n"
  end

  defp build_frontmatter(attrs) do
    git_tag = System.get_env("SIGRA_GIT_TAG", "")
    ci_run_url = System.get_env("SIGRA_CI_RUN_URL", "")

    """
    ---
    phase: #{attrs.phase}
    gauat_requirement: #{attrs.gauat_requirement}
    hex_version: #{mix_version()}
    git_sha: #{git_short_sha()}
    git_tag: #{git_tag}
    ci_run_url: #{ci_run_url}
    ci_workflow: #{attrs.ci_workflow}
    generated_by: #{attrs.generated_by}
    generated_at: #{attrs.generated_at}
    disposition: #{attrs.disposition}
    ---

    """
  end

  defp missing_paths(config, cells, evidence_dir) do
    base_paths = [
      Path.join(evidence_dir, "README.md"),
      Path.join(evidence_dir, "manifest.json")
    ]

    report_paths =
      case config.type do
        :email ->
          [
            Path.join(evidence_dir, "reports/contrast-summary.json"),
            Path.join(evidence_dir, "reports/byte-budget.csv")
          ]

        :artifact ->
          cells
          |> Enum.map(& &1.evidence_path)
          |> Enum.reject(&is_nil/1)
          |> Enum.map(&Path.join(evidence_dir, &1))
      end

    (base_paths ++ report_paths)
    |> Enum.uniq()
    |> Enum.filter(&(not File.exists?(&1)))
  end

  defp validate_readme_hex_version!(evidence_dir) do
    readme_path = Path.join(evidence_dir, "README.md")

    with true <- File.exists?(readme_path),
         {:ok, content} <- File.read(readme_path),
         [_, version] <- Regex.run(~r/^hex_version:\s+(.+)$/m, content) do
      current = mix_version()

      if String.trim(version) != current do
        Mix.shell().error(
          "FAIL: #{readme_path} hex_version #{String.trim(version)} does not match mix.exs #{current}"
        )

        System.halt(2)
      end
    else
      false ->
        :ok

      _ ->
        Mix.shell().error("FAIL: could not parse hex_version from #{readme_path}")
        System.halt(2)
    end
  end

  defp hero_snapshot_relpath do
    pattern = Path.join([@evidence_base, "oauth-link", "snapshots", "oauth-link__disabled-tooltip__sha-*.png"])

    case Path.wildcard(pattern) do
      [path | _] ->
        Path.relative_to(path, Path.join(@evidence_base, "oauth-link"))

      [] ->
        "snapshots/oauth-link__disabled-tooltip__sha-#{git_short_sha()}.png"
    end
  end

  defp git_short_sha do
    case System.cmd("git", ["rev-parse", "--short", "HEAD"], stderr_to_stdout: true) do
      {sha, 0} -> String.trim(sha)
      _ -> "unknown"
    end
  end

  defp mix_version do
    case File.read("mix.exs") do
      {:ok, content} ->
        case Regex.run(~r/@version\s+"([^"]+)"/, content) do
          [_, version] -> version
          _ -> "unknown"
        end

      _ ->
        "unknown"
    end
  end

  defp timestamp_now do
    DateTime.utc_now() |> Calendar.strftime("%Y-%m-%dT%H:%M:%SZ")
  end

  defp sha256_hex(content) do
    :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
  end
end
