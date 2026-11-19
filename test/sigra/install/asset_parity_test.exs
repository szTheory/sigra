defmodule Sigra.Install.AssetParityTest do
  @moduledoc """
  BGEN-01: every `.css`, `.svg` and `.js` file under `priv/templates/sigra.install/`
  is classified in the `@assets` table below, and every classified file stays in
  step with its counterparts.

  The example application (`test/example/`) is a hand mirror of the installer
  templates, so it drifts silently: `core/sigra_auth.css` was 32,072 bytes in the
  template and 13,867 bytes in the example before this guard existed. The golden
  install tree (`test/fixtures/install_golden/tree/`) carries the copied
  stylesheets and logos too.

  ## Relations

    * `:byte_identical` - the template equals the example copy and, when a golden
      path is declared, the golden copy. A failure names the resync command.
    * `{:documented_divergence, reason}` - the example differs on purpose. The
      reason is a non-empty sentence, and a shrink-only guard (see
      `@divergence_guards`) stops the difference from growing unnoticed.
    * `:injected_snippet` - the file is read by an installer feature and spliced
      into a host file; it has no copy to compare.

  ## Completeness

  The table must cover exactly the set of `.css/.svg/.js` files found on disk. A
  new template asset with no row, or a row whose file is gone, fails. That is what
  stops an asset from escaping the table.

  The older DIST-05 test in `features/admin_test.exs` (admin stylesheet,
  template against example) is left in place; this table makes it redundant but
  harmless.
  """

  use ExUnit.Case, async: true

  @repo_root Path.expand("../../..", __DIR__)
  @templates_dir "priv/templates/sigra.install"
  @asset_extensions ~w(.css .svg .js)

  @example_assets "test/example/priv/static/assets"
  @example_images "test/example/priv/static/images"
  @example_js "test/example/assets/js"
  @golden_assets "test/fixtures/install_golden/tree/priv/static/assets"
  @golden_images "test/fixtures/install_golden/tree/priv/static/images"

  # One row per template asset. `example` and `golden` are repo-relative paths, or
  # nil when there is no such counterpart (the golden tree carries only the
  # stylesheets and logos; the passkey scripts are not in it).
  @assets [
    %{
      template: "#{@templates_dir}/admin/admin_hooks.js",
      example: "#{@example_js}/admin_hooks.js",
      golden: nil,
      relation:
        {:documented_divergence,
         "the example copy is a superset of the template: it widens the click-to-copy chip " <>
           "selector to the public demo credential chips (code.vt-code--copy) and adds the " <>
           "demo password fill and persona switch helpers that only the Tasklane demo uses"}
    },
    %{
      template: "#{@templates_dir}/admin/sigra-logo-primary-dark.svg",
      example: "#{@example_images}/sigra-logo-primary-dark.svg",
      golden: "#{@golden_images}/sigra-logo-primary-dark.svg",
      relation: :byte_identical
    },
    %{
      template: "#{@templates_dir}/admin/sigra-logo-primary.svg",
      example: "#{@example_images}/sigra-logo-primary.svg",
      golden: "#{@golden_images}/sigra-logo-primary.svg",
      relation: :byte_identical
    },
    %{
      template: "#{@templates_dir}/admin/sigra_admin.css",
      example: "#{@example_assets}/sigra_admin.css",
      golden: "#{@golden_assets}/sigra_admin.css",
      relation: :byte_identical
    },
    %{
      template: "#{@templates_dir}/core/sigra_auth.css",
      example: "#{@example_assets}/sigra_auth.css",
      golden: "#{@golden_assets}/sigra_auth.css",
      relation: :byte_identical
    },
    %{
      template: "#{@templates_dir}/passkeys/passkey_browser.js",
      example: "#{@example_js}/passkey_browser.js",
      golden: nil,
      relation:
        {:documented_divergence,
         "the template imports the WebAuthn ceremony helpers from the @simplewebauthn/browser " <>
           "package, while the example inlines its own base64url and credential serialization " <>
           "helpers so it needs no npm install"}
    },
    %{
      template: "#{@templates_dir}/passkeys/passkey_hooks.js",
      example: "#{@example_js}/passkey_hooks.js",
      golden: nil,
      relation: :byte_identical
    }
  ]

  # Shrink-only guards for the documented divergences. A divergence row with no
  # entry here fails, so a new divergence cannot be added without a guard.
  #
  #   * `:ceiling` - at most this many non-blank template lines may be missing from
  #     the example copy. Lower the number when the difference shrinks; raising it
  #     means the template gained code the example does not have.
  #   * `:must_have` - function or marker names that must exist in BOTH files. The
  #     admin_hooks.js entries are the markers that
  #     `test/sigra/templates/installer_drift_test.exs` already pins (fixes #20,
  #     #21 and #22: page loading indicator, field help, auth branding preview).
  #   * `:only_in_template` / `:only_in_example` - the markers that make the
  #     documented reason true. If one stops being true, the reason is stale.
  @divergence_guards %{
    "#{@templates_dir}/admin/admin_hooks.js" => %{
      ceiling: 5,
      must_have: [
        "function installPageLoadingIndicator(",
        "phx:page-loading-start",
        "phx:page-loading-stop",
        "PAGE_LOADING_MAX_ACTIVE_MS",
        "data-sg-admin-page-loading",
        "function installFieldHelp(",
        "data-sg-field-help-root",
        "data-sg-field-help-trigger",
        "var AuthBrandingPreview = {",
        "AUTH_BRANDING_COLOR_TOKENS",
        "data-sg-auth-branding-color",
        "data-sg-auth-branding-preview",
        "AuthBrandingPreview: AuthBrandingPreview"
      ],
      only_in_template: [],
      only_in_example: [
        "code.vt-code--copy",
        "installDemoPasswordFill",
        "installDemoPersonaSwitch"
      ]
    },
    "#{@templates_dir}/passkeys/passkey_browser.js" => %{
      ceiling: nil,
      must_have: [
        "export class WebAuthnError",
        "export const WebAuthnAbortService",
        "function normalizeAbort(",
        "function csrfToken(",
        "function safeLoginStatus(",
        "function updateLoginStatus(",
        "function clearLoginStatus(",
        "function fetchLoginOptions()",
        "async function fetchAuthenticationOptions(",
        "function submitPasskeyLogin(",
        "export async function conditionalMediationAvailable(",
        "export async function startRegistration(",
        "export async function startAuthentication(",
        "export function attachPasskeyLogin("
      ],
      only_in_template: ["@simplewebauthn/browser"],
      only_in_example: ["function base64UrlEncode(", "function serializeCredential("]
    }
  }

  # An injected snippet has no counterpart to compare; the guard is that an
  # installer feature still reads it.
  @snippet_readers %{
    "#{@templates_dir}/passkeys/app_js_passkeys_injection.js" => %{
      reader: "lib/sigra/install/features/passkeys.ex",
      reference: "passkeys/app_js_passkeys_injection.js"
    }
  }

  # The injection snippet row is declared separately so the table above reads as
  # the copied assets only; both lists together are the classified set.
  @snippet_rows [
    %{
      template: "#{@templates_dir}/passkeys/app_js_passkeys_injection.js",
      example: nil,
      golden: nil,
      relation: :injected_snippet
    }
  ]

  @table @assets ++ @snippet_rows

  describe "the declared table" do
    test "every row has a valid shape and a non-empty reason where one is required" do
      refute Enum.empty?(@table)

      for row <- @table do
        assert validate_row!(row) == row
      end
    end

    test "every documented divergence has a shrink-only guard entry" do
      for %{template: template, relation: {:documented_divergence, _reason}} <- @table do
        assert Map.has_key?(@divergence_guards, template),
               "#{template} is a documented divergence with no entry in @divergence_guards"
      end

      guarded = Map.keys(@divergence_guards) |> Enum.sort()

      diverging =
        for(%{template: t, relation: {:documented_divergence, _}} <- @table, do: t)
        |> Enum.sort()

      assert guarded == diverging,
             "@divergence_guards must name exactly the documented divergences; got #{inspect(guarded)} vs #{inspect(diverging)}"
    end
  end

  describe "completeness" do
    test "the table classifies exactly the css, svg and js files under the templates directory" do
      found = discover_template_assets()

      assert found != [], "no .css/.svg/.js template asset found; the glob is broken"

      assert completeness(table_templates(), found) ==
               %{unclassified: [], stale: [], duplicates: []}
    end

    # The controls below start from the files actually on disk (never from @table), so
    # they stay valid, and stay able to fail, whatever the real table says.
    test "a planted extra file on disk is reported as unclassified" do
      on_disk = discover_template_assets()
      planted = "#{@templates_dir}/core/zz_planted_asset.css"

      assert completeness(on_disk, [planted | on_disk]) ==
               %{unclassified: [planted], stale: [], duplicates: []}
    end

    test "a planted table that omits a real file reports that file as unclassified" do
      [dropped | kept] = discover_template_assets()

      assert completeness(kept, [dropped | kept]) ==
               %{unclassified: [dropped], stale: [], duplicates: []}
    end

    test "a planted row for a file that is gone is reported as stale" do
      on_disk = discover_template_assets()
      ghost = "#{@templates_dir}/admin/zz_gone.svg"

      assert completeness([ghost | on_disk], on_disk) ==
               %{unclassified: [], stale: [ghost], duplicates: []}
    end

    test "a planted duplicate row is reported" do
      [first | _] = on_disk = discover_template_assets()

      assert completeness([first | on_disk], on_disk) ==
               %{unclassified: [], stale: [], duplicates: [first]}
    end

    test "the row validator rejects an unknown relation, a missing example and an empty reason" do
      assert_raise ArgumentError, ~r/unknown relation/, fn ->
        validate_row!(%{template: "t", example: "e", golden: nil, relation: :close_enough})
      end

      assert_raise ArgumentError, ~r/needs an example path/, fn ->
        validate_row!(%{template: "t", example: nil, golden: nil, relation: :byte_identical})
      end

      assert_raise ArgumentError, ~r/non-empty reason/, fn ->
        validate_row!(%{
          template: "t",
          example: "e",
          golden: nil,
          relation: {:documented_divergence, "  "}
        })
      end

      assert_raise ArgumentError, ~r/must not name a counterpart/, fn ->
        validate_row!(%{template: "t", example: "e", golden: nil, relation: :injected_snippet})
      end
    end
  end

  describe "byte-identical assets" do
    for %{relation: :byte_identical} = row <- @assets do
      @row row

      test "#{@row.template}: example copy equals the installer template" do
        template = read!(@row.template)
        example = read!(@row.example)

        assert parity(template, example) == :ok,
               mismatch_message(
                 @row.template,
                 @row.example,
                 parity(template, example),
                 "cp #{@row.template} #{@row.example}"
               )
      end

      if row.golden do
        test "#{@row.template}: golden install tree copy equals the installer template" do
          template = read!(@row.template)
          golden = read!(@row.golden)

          assert parity(template, golden) == :ok,
                 mismatch_message(
                   @row.template,
                   @row.golden,
                   parity(template, golden),
                   "MIX_ENV=test mix sigra.fixture.rebless_golden " <>
                     "(only after confirming the template change is intended)"
                 )
        end
      end
    end

    test "the stale-example defect class is covered: sigra_auth.css has all three counterparts" do
      row = Enum.find(@assets, &String.ends_with?(&1.template, "core/sigra_auth.css"))

      assert row.relation == :byte_identical
      assert row.example == "#{@example_assets}/sigra_auth.css"
      assert row.golden == "#{@golden_assets}/sigra_auth.css"
    end
  end

  # BGEN-04: the first line of sigra_admin.css is a version stamp, an integer CSS
  # contract level (not the package version) that a host can read to know which
  # shipped rules it has. The three copies must carry the same one. These are three
  # separate tests so a stale copy names itself: a stale golden tree fails only the
  # golden test until it is reblessed.
  describe "sigra_admin.css version stamp" do
    @stamp_template "#{@templates_dir}/admin/sigra_admin.css"
    @stamp_example "#{@example_assets}/sigra_admin.css"
    @stamp_golden "#{@golden_assets}/sigra_admin.css"

    test "the template starts with a /* sigra-admin-css: N */ stamp line" do
      assert {:ok, level} = stamp_level(read!(@stamp_template))
      assert level >= 1
    end

    test "the example copy carries the same stamp as the template" do
      assert stamp_level(read!(@stamp_example)) == stamp_level(read!(@stamp_template)),
             "#{@stamp_example} first line differs from the template; resync with: " <>
               "cp #{@stamp_template} #{@stamp_example}"
    end

    test "the golden install tree copy carries the same stamp as the template" do
      assert stamp_level(read!(@stamp_golden)) == stamp_level(read!(@stamp_template)),
             "#{@stamp_golden} first line differs from the template; resync with: " <>
               "MIX_ENV=test mix sigra.fixture.rebless_golden " <>
               "(only after confirming the template change is intended)"
    end

    test "the stamp reader accepts only an integer level on the very first line" do
      assert stamp_level("/* sigra-admin-css: 1 */\n/* header */\n") == {:ok, 1}
      assert stamp_level("/* sigra-admin-css: 12 */") == {:ok, 12}

      # Planted bad stamps: absent, not on the first line, non-integer, malformed, and an
      # unrendered template tag (the file is EEx-rendered and must stay tag-free).
      assert stamp_level("/* Vaultr/Sigra demo design layer.\n */\n") == :error
      assert stamp_level("/* header */\n/* sigra-admin-css: 1 */\n") == :error
      assert stamp_level("/* sigra-admin-css: x */\n") == :error
      assert stamp_level("/* sigra-admin-css: 1.2 */\n") == :error
      assert stamp_level("/* sigra-admin-css: 1 */ trailing\n") == :error
      assert stamp_level("/* sigra-admin-css: <%= level %> */\n") == :error
      assert stamp_level("") == :error
    end

    test "two different stamp levels are reported as different" do
      refute stamp_level("/* sigra-admin-css: 1 */\n") ==
               stamp_level("/* sigra-admin-css: 2 */\n")
    end
  end

  describe "documented divergences" do
    for %{relation: {:documented_divergence, _reason}} = row <- @assets do
      @row row
      @guard Map.fetch!(@divergence_guards, row.template)
      @reason elem(row.relation, 1)

      test "#{@row.template}: reason is stated and the example still differs as described" do
        assert String.trim(@reason) != ""

        template = read!(@row.template)
        example = read!(@row.example)

        refute template == example,
               "#{@row.template} now equals #{@row.example}: move this row to :byte_identical " <>
                 "and delete its entry in @divergence_guards"

        for marker <- @guard.only_in_template do
          assert template =~ marker,
                 "reason is stale: template no longer contains #{inspect(marker)}"

          refute example =~ marker, "reason is stale: example now contains #{inspect(marker)}"
        end

        for marker <- @guard.only_in_example do
          assert example =~ marker,
                 "reason is stale: example no longer contains #{inspect(marker)}"

          refute template =~ marker, "reason is stale: template now contains #{inspect(marker)}"
        end
      end

      test "#{@row.template}: the must-have markers exist in both copies" do
        template = read!(@row.template)
        example = read!(@row.example)

        for marker <- @guard.must_have do
          assert template =~ marker,
                 "marker #{inspect(marker)} missing in template #{@row.template}"

          assert example =~ marker, "marker #{inspect(marker)} missing in example #{@row.example}"
        end
      end

      if @guard.ceiling do
        test "#{@row.template}: template-only lines stay at or under the shrink-only ceiling" do
          missing = template_lines_missing_from(read!(@row.template), read!(@row.example))

          assert length(missing) <= @guard.ceiling,
                 """
                 #{length(missing)} non-blank template lines are absent from #{@row.example}; the ceiling is #{@guard.ceiling}.
                 The template gained code the example does not have. Mirror it into the example
                 (do not raise the ceiling). Lines absent from the example:

                 #{Enum.join(missing, "\n")}
                 """
        end
      end
    end

    test "the ceiling guard counts a planted template-only line" do
      template = "keep one\nkeep two\nplanted template-only line\n\n"
      example = "keep one\nkeep two\nexample only\n"

      assert template_lines_missing_from(template, example) == ["planted template-only line"]
    end

    test "the ceiling guard ignores blank lines and example-only lines" do
      assert template_lines_missing_from("a\n\n  \nb\n", "b\na\nextra\n") == []
    end
  end

  describe "injected snippets" do
    for {template, %{reader: reader, reference: reference}} <- @snippet_readers do
      @template template
      @reader reader
      @reference reference

      test "#{@template} is still read by #{@reader}" do
        assert File.regular?(Path.join(@repo_root, @template))

        assert read!(@reader) =~ @reference,
               "#{@reader} no longer references #{@reference}; the snippet is orphaned or the row is stale"
      end
    end

    test "every injected_snippet row has a reader entry" do
      snippets = for %{relation: :injected_snippet, template: t} <- @table, do: t

      assert Enum.sort(snippets) == @snippet_readers |> Map.keys() |> Enum.sort()
    end
  end

  describe "parity/2 positive controls" do
    test "equal binaries are reported as parity" do
      assert parity("body { color: red; }\n", "body { color: red; }\n") == :ok
    end

    test "one appended byte is reported as a mismatch at the appended offset" do
      a = "body { color: red; }\n"
      b = a <> "x"

      assert parity(a, b) == {:mismatch, byte_size(a), byte_size(a), byte_size(b)}
    end

    test "one changed byte in the middle is reported at that offset with equal sizes" do
      a = "body { color: red; }\n"
      b = String.replace(a, "red", "rex")
      # "red" starts at byte 14, so its third byte (the planted change) is byte 16.
      {red_start, _len} = :binary.match(a, "red")

      assert parity(a, b) == {:mismatch, red_start + 2, byte_size(a), byte_size(b)}
    end
  end

  # -- helpers ----------------------------------------------------------------

  # Pure comparator: `:ok` when equal, otherwise the first differing byte offset
  # with both sizes, so a failure names how far apart the two files are.
  defp parity(a, b) when is_binary(a) and is_binary(b) do
    if a == b do
      :ok
    else
      {:mismatch, first_diff_offset(a, b, 0), byte_size(a), byte_size(b)}
    end
  end

  defp first_diff_offset(<<byte, rest_a::binary>>, <<byte, rest_b::binary>>, offset),
    do: first_diff_offset(rest_a, rest_b, offset + 1)

  defp first_diff_offset(_a, _b, offset), do: offset

  # `{:ok, level}` when the first line is exactly `/* sigra-admin-css: N */` with an
  # integer N, otherwise `:error`. Pure, so the planted controls call the same function
  # the real assertions call.
  defp stamp_level(css) when is_binary(css) do
    first_line = css |> String.split("\n", parts: 2) |> hd()

    case Regex.run(~r/\A\/\* sigra-admin-css: (\d+) \*\/\z/, first_line) do
      [_whole, level] -> {:ok, String.to_integer(level)}
      nil -> :error
    end
  end

  # Pure completeness check over two lists of repo-relative template paths.
  defp completeness(table_paths, found_paths) do
    %{
      unclassified: Enum.sort(found_paths -- table_paths),
      stale: table_paths |> Enum.uniq() |> Kernel.--(found_paths) |> Enum.sort(),
      duplicates: Enum.sort(table_paths -- Enum.uniq(table_paths))
    }
  end

  # Non-blank template lines that do not appear (exact match) in the example.
  defp template_lines_missing_from(template, example) do
    example_lines = example |> String.split("\n") |> MapSet.new()

    template
    |> String.split("\n")
    |> Enum.reject(&(String.trim(&1) == ""))
    |> Enum.reject(&MapSet.member?(example_lines, &1))
  end

  defp validate_row!(
         %{template: template, example: example, golden: golden, relation: relation} = row
       ) do
    case relation do
      :byte_identical ->
        if is_nil(example),
          do: raise(ArgumentError, "#{template}: byte_identical needs an example path")

      {:documented_divergence, reason} ->
        if not is_binary(reason) or String.trim(reason) == "",
          do:
            raise(ArgumentError, "#{template}: a documented divergence needs a non-empty reason")

        if is_nil(example),
          do: raise(ArgumentError, "#{template}: a documented divergence needs an example path")

      :injected_snippet ->
        if not is_nil(example) or not is_nil(golden),
          do: raise(ArgumentError, "#{template}: an injected snippet must not name a counterpart")

      other ->
        raise ArgumentError, "#{template}: unknown relation #{inspect(other)}"
    end

    row
  end

  defp table_templates, do: Enum.map(@table, & &1.template)

  defp discover_template_assets do
    @repo_root
    |> Path.join("#{@templates_dir}/**/*")
    |> Path.wildcard()
    |> Enum.filter(&(File.regular?(&1) and Path.extname(&1) in @asset_extensions))
    |> Enum.map(&Path.relative_to(&1, @repo_root))
    |> Enum.sort()
  end

  defp mismatch_message(template_rel, other_rel, {:mismatch, offset, size_a, size_b}, resync) do
    "#{other_rel} has diverged from the installer template #{template_rel}: " <>
      "first differing byte at offset #{offset}; template #{size_a} bytes, other #{size_b} bytes. " <>
      "Resync with: #{resync}"
  end

  defp mismatch_message(_template_rel, _other_rel, :ok, _resync), do: "byte parity holds"

  defp read!(rel), do: @repo_root |> Path.join(rel) |> File.read!()
end
