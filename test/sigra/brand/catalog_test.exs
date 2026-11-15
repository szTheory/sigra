defmodule Sigra.Brand.CatalogTest do
  @moduledoc """
  BGEN-03 harness checks for the before/after text catalog of rendered output.

  The catalog is a set of normalized, human-reviewable text files: pure renders of
  the eight library admin LiveViews (tier 1), plus the raw tier-2 and generated-host
  dumps that other plans produce. Phase 262 diffs "after" against a committed
  "before" taken while shipped `lib/` and `priv/` were still identical to main.

  What this module protects:

    * the normalizer removes every per-render volatile (csrf tokens, phx ids,
      UUIDs, wall-clock relative text) and never rewrites an absolute timestamp,
      which is pinned at the source instead,
    * rendering the same tier-1 state twice yields byte-identical normalized text,
    * the committed "before" is protected by hash and by refuse-to-overwrite, never
      by equality with current sources (that comparison would go red in Phase 261
      by design),
    * a privacy scan over the catalog text, proven by planted leaks.

  The writer is opt-in. `SIGRA_BRAND_CATALOG=after mix test test/sigra/brand/catalog_test.exs`
  writes the "after" catalog into the gitignored `tmp/catalog-after/`; the `before`
  value writes the committed baseline exactly once. Both go through
  `Sigra.Test.Brand.RegenGuard`, so they are refused when `CI` is `true`.

  Red-ness is proven only by the in-memory controls below. Never mutate a real
  committed catalog file to show that a guard can fail.
  """

  use ExUnit.Case, async: true

  alias Sigra.Admin.Live.UserShowLive
  alias Sigra.Test.Brand.Catalog

  @root Path.expand("../../..", __DIR__)

  # Written before any test reads the output. `setup_all` keeps the opt-in write
  # ordered ahead of the async tests; without the variable it does nothing.
  setup_all do
    Catalog.write_if_requested!()
  end

  describe "normalize/2" do
    test "csrf token inputs and meta tags lose their values" do
      html =
        ~s(<input type="hidden" name="_csrf_token" value="AbC123-secret-token"/>) <>
          ~s(<meta name="csrf-token" content="XyZ987-meta-token"/>)

      out = Catalog.normalize(html)

      refute out =~ "AbC123-secret-token"
      refute out =~ "XyZ987-meta-token"
      assert out =~ ~s(value="{{CSRF}}")
      assert out =~ ~s(content="{{CSRF}}")
    end

    test "phx request ids and the session and static signed values are replaced" do
      html =
        ~s(<div id="phx-F9abc_Def12" data-phx-session="SFMyNTY.signed.session" ) <>
          ~s(data-phx-static="SFMyNTY.signed.static"></div>)

      out = Catalog.normalize(html)

      refute out =~ "F9abc_Def12"
      refute out =~ "signed.session"
      refute out =~ "signed.static"
      assert out =~ ~s(id="phx-{{REQUEST_ID}}")
      assert out =~ ~s(data-phx-session="{{PHX_SESSION}}")
      assert out =~ ~s(data-phx-static="{{PHX_STATIC}}")
    end

    test "the asset vsn query and per-render ids lose their volatile part" do
      html =
        ~s(<link rel="stylesheet" href="/assets/sigra_admin.css?vsn=d"/>) <>
          ~s(<h2 id="mg-11-confirm-title-42">Revoke</h2>)

      out = Catalog.normalize(html)

      assert out =~ "/assets/sigra_admin.css?vsn={{VSN}}"
      assert out =~ ~s(id="mg-11-confirm-title-{{N}}")
      refute out =~ "confirm-title-42"
    end

    test "every UUID becomes a placeholder and personas get their label" do
      persona = "11111111-2222-4333-8444-555555555555"
      other = "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee"
      html = ~s(<a href="/admin/users/#{persona}">#{persona}</a><code>#{other}</code>)

      out = Catalog.normalize(html, personas: %{persona => "locked"})

      assert out =~ ~s(href="/admin/users/{{PERSONA:locked}}")
      assert out =~ "<code>\n{{UUID}}\n</code>"
      refute out =~ persona
      refute out =~ other
    end

    test "wall-clock relative text is replaced and absolute timestamps are kept" do
      html =
        "<p>just now</p><p>5m ago</p><p>3h ago</p><p>304d ago</p>" <>
          "<p>2026-01-02 03:04</p><p>2026-05-14 08:12:00</p>"

      out = Catalog.normalize(html)

      refute out =~ "just now"
      refute out =~ ~r/\d+[mhd] ago/
      assert length(String.split(out, "{{RELATIVE}}")) == 5
      assert out =~ "2026-01-02 03:04"
      assert out =~ "2026-05-14 08:12:00"
    end

    test "whitespace runs collapse and every tag sits on its own line" do
      out = Catalog.normalize("<div>\n   <p>a   b</p>\n</div>")

      assert out == "<div>\n<p>\na b\n</p>\n</div>\n"
    end

    test "planted controls: a csrf value, a UUID and 304d ago are all gone, an absolute stamp stays" do
      leaky =
        ~s(<input name="_csrf_token" value="PLANTED-csrf-value"/>) <>
          "<code>9f8e7d6c-5b4a-4321-8fed-cba987654321</code><span>304d ago</span>"

      out = Catalog.normalize(leaky)

      refute out =~ "PLANTED-csrf-value"
      refute out =~ "9f8e7d6c-5b4a-4321-8fed-cba987654321"
      refute out =~ "304d ago"

      assert Catalog.normalize("<td>2026-01-02 03:04</td>") =~ "2026-01-02 03:04"
    end
  end

  describe "tier 1 tracer: UserShowLive locked state" do
    test "two renders of the same literal state normalize to identical bytes" do
      first = Catalog.tier1_html({UserShowLive, :locked})
      second = Catalog.tier1_html({UserShowLive, :locked})

      assert first != ""
      assert first == second
    end

    test "the baseline is non-vacuous: it carries the verbatim locked guidance and the raw render was volatile" do
      raw = Catalog.tier1_raw({UserShowLive, :locked})
      normalized = Catalog.tier1_html({UserShowLive, :locked})

      assert normalized =~ "revoke active sessions and unlock below."
      assert normalized =~ "Locked"

      # The raw render really did carry the volatiles the normalizer is claimed to remove.
      assert raw =~ ~r/name="_csrf_token" value="[^"]{8,}"/
      assert raw =~ ~r/\d+d ago/
      assert normalized =~ "{{CSRF}}"
      assert normalized =~ "{{RELATIVE}}"
    end
  end

  describe "write!/2 in after mode" do
    test "writes the tier-1 files under tier1-library-admin/ of the output directory" do
      out = tmp_dir()

      result =
        Catalog.write!(:after, env: %{"SIGRA_BRAND_CATALOG" => "after"}, out_dir: out)

      path = "tier1-library-admin/user_show_live--locked.html"

      assert path in result.files
      assert File.read!(Path.join(out, path)) == Catalog.tier1_html({UserShowLive, :locked})
    end

    test "the default output directory is the gitignored tmp/catalog-after" do
      assert Catalog.out_dir(:after) == Path.join(@root, "tmp/catalog-after")
    end

    test "is refused, and writes nothing, when CI=true is planted in the injected env" do
      out = Path.join(tmp_dir(), "never-written")

      assert_raise RuntimeError, ~r/SIGRA_BRAND_CATALOG=after.*refused when CI is set/s, fn ->
        Catalog.write!(:after,
          env: %{"SIGRA_BRAND_CATALOG" => "after", "CI" => "true"},
          out_dir: out
        )
      end

      refute File.exists?(out)
    end

    test "is refused when the environment does not request this mode" do
      out = Path.join(tmp_dir(), "never-written")

      assert_raise ArgumentError, ~r/SIGRA_BRAND_CATALOG=after/, fn ->
        Catalog.write!(:after, env: %{}, out_dir: out)
      end

      refute File.exists?(out)
    end
  end

  describe "manifest/2" do
    @pinned %{
      origin_main_sha: "1111111111111111111111111111111111111111",
      merge_base_sha: "2222222222222222222222222222222222222222",
      lib_tree: "aaaa",
      priv_tree: "bbbb",
      golden_tree: "cccc",
      css_sha256: %{"priv/templates/sigra.install/admin/sigra_admin.css" => "ee"}
    }

    test "is pretty JSON with sorted keys, one element per line, and exactly the pinned fields" do
      text = Catalog.manifest(%{"tier1-library-admin/a.html" => "<p>a</p>\n"}, %{pinned: @pinned})
      decoded = JSON.decode!(text)

      assert decoded |> Map.keys() |> Enum.sort() ==
               Enum.sort(~w(schema provenance pinned capture_command lanes personas coverage
                            example_files_changed_vs_main deferred_shipped_byte_fixes files))

      assert decoded["provenance"] == "brand book v2.0 (2026-11-13)"

      assert decoded["capture_command"] ==
               "SIGRA_BRAND_CATALOG=before mix test test/sigra/brand/catalog_test.exs"

      assert decoded["coverage"] |> Map.keys() |> Enum.sort() ==
               ~w(covered not_covered theme_note)

      assert decoded["pinned"] |> Map.keys() |> Enum.sort() ==
               ~w(css_sha256 golden_tree lib_tree merge_base_sha origin_main_sha priv_tree)

      assert decoded["files"] == %{"tier1-library-admin/a.html" => sha256("<p>a</p>\n")}

      # Sorted keys and one element per line: re-serializing is byte-stable.
      keys = for [_, key] <- Regex.scan(~r/^  "([a-z_0-9]+)": /m, text), do: key
      assert keys == Enum.sort(keys)
      assert String.ends_with?(text, "}\n")
      refute text =~ ~r/\[[^\]\n]*,[^\]\n]*\]/
    end

    test "the coverage text states what is NOT covered and both halves of the theme note" do
      coverage = Catalog.coverage()
      text = JSON.encode!(coverage)

      assert text =~ "authenticated generated screens"
      assert text =~ "golden install tree"
      assert text =~ "client-side"
      assert text =~ "data-theme"
      assert text =~ "default-profile value"
      assert text =~ "email_from_address overridden"
      assert text =~ "shipped default sender"
    end

    test "the manifest text itself passes the privacy scan" do
      text = Catalog.manifest(%{}, %{pinned: @pinned})

      assert Catalog.privacy_violations(%{"MANIFEST.json" => text}) == []
    end

    test "records the owed pre-262 shipped-byte fixes and the re-capture rule" do
      decoded = JSON.decode!(Catalog.manifest(%{}, %{pinned: @pinned}))
      text = JSON.encode!(decoded["deferred_shipped_byte_fixes"])

      assert text =~ "registration timing oracle"
      assert text =~ "passkey-options oracle"
      assert text =~ "confirm"
      assert text =~ "re-captured first"
    end
  end

  describe "verify_manifest/1" do
    test "returns [] for matching files and exactly one {:changed, path} when one byte is mutated" do
      dir =
        write_catalog_dir(%{
          "tier1-library-admin/a.html" => "one\n",
          "tier2-example-admin/b.html" => "two\n"
        })

      assert Catalog.verify_manifest(dir) == []

      mutated = Path.join(dir, "tier1-library-admin/a.html")
      File.write!(mutated, File.read!(mutated) <> "x")

      assert Catalog.verify_manifest(dir) == [{:changed, "tier1-library-admin/a.html"}]
    end

    test "reports a removed file and an added file" do
      dir =
        write_catalog_dir(%{
          "tier1-library-admin/a.html" => "one\n",
          "tier2-example-admin/b.html" => "two\n"
        })

      File.rm!(Path.join(dir, "tier2-example-admin/b.html"))
      File.write!(Path.join(dir, "tier1-library-admin/extra.html"), "extra\n")

      assert Catalog.verify_manifest(dir) ==
               [
                 {:added, "tier1-library-admin/extra.html"},
                 {:removed, "tier2-example-admin/b.html"}
               ]
    end

    test "committed_status/1 is :absent without a manifest and live when a planted one exists" do
      assert Catalog.committed_status(Path.join(tmp_dir(), "nothing-here")) == :absent

      dir = write_catalog_dir(%{"tier1-library-admin/a.html" => "one\n"})
      assert Catalog.committed_status(dir) == {:present, []}

      File.write!(Path.join(dir, "tier1-library-admin/a.html"), "tampered\n")

      assert Catalog.committed_status(dir) ==
               {:present, [{:changed, "tier1-library-admin/a.html"}]}
    end

    test "the committed before catalog, when it exists, matches its manifest byte for byte" do
      case Catalog.committed_status() do
        :absent ->
          :ok

        {:present, diff} ->
          assert diff == [], "committed before catalog drifted: #{inspect(diff)}"
      end
    end
  end

  describe "assert_main_identity!/1" do
    test "returns the merge-base and tree hashes when lib and priv match origin/main" do
      assert Catalog.assert_main_identity!(&clean_git/1) == %{
               origin_main_sha: "1111111111111111111111111111111111111111",
               merge_base_sha: "2222222222222222222222222222222222222222",
               lib_tree: "aaaa",
               priv_tree: "bbbb",
               golden_tree: "cccc"
             }
    end

    test "raises naming the differing area when lib differs from origin/main" do
      git = fn
        ["diff", "--quiet", "origin/main", "--", "lib", "priv"] -> {"", 1}
        ["diff", "--quiet", "origin/main", "--", "lib"] -> {"", 1}
        ["diff", "--quiet", "origin/main", "--", "priv"] -> {"", 0}
        args -> clean_git(args)
      end

      error = assert_raise RuntimeError, fn -> Catalog.assert_main_identity!(git) end

      assert error.message =~ "differ from origin/main in: lib."
    end

    test "raises naming both areas when both differ" do
      git = fn
        ["diff", "--quiet" | _] -> {"", 1}
        args -> clean_git(args)
      end

      error = assert_raise RuntimeError, fn -> Catalog.assert_main_identity!(git) end

      assert error.message =~ "differ from origin/main in: lib, priv."
    end
  end

  describe "write!/2 in before mode" do
    test "writes the lane files and the manifest last, then verify_manifest/1 is clean" do
      %{out: out, opts: opts} = before_setup()

      result = Catalog.write!(:before, opts)

      assert "MANIFEST.json" in result.files
      assert "tier1-library-admin/user_show_live--locked.html" in result.files
      assert "tier2-example-admin/admin-users-index.html" in result.files
      assert "generated-host-pages/log-in.html" in result.files
      assert "generated-host-emails/confirmation.txt" in result.files

      manifest = out |> Path.join("MANIFEST.json") |> File.read!() |> JSON.decode!()

      assert manifest["pinned"]["origin_main_sha"] == "1111111111111111111111111111111111111111"
      assert manifest["pinned"]["lib_tree"] == "aaaa"

      assert Map.has_key?(
               manifest["pinned"]["css_sha256"],
               "priv/templates/sigra.install/admin/sigra_admin.css"
             )

      assert manifest["files"] |> Map.keys() |> Enum.sort() == result.files -- ["MANIFEST.json"]
      assert Catalog.verify_manifest(out) == []

      # Raw inputs are normalized on the way in.
      page = File.read!(Path.join(out, "tier2-example-admin/admin-users-index.html"))
      refute page =~ "leaky-csrf-value"
      assert page =~ "{{CSRF}}"
    end

    test "refuses to overwrite once MANIFEST.json exists, and changes nothing" do
      %{out: out, opts: opts} = before_setup()
      Catalog.write!(:before, opts)
      before_bytes = File.read!(Path.join(out, "MANIFEST.json"))

      error = assert_raise RuntimeError, fn -> Catalog.write!(:before, opts) end

      assert error.message =~ "immutable"
      assert File.read!(Path.join(out, "MANIFEST.json")) == before_bytes
    end

    test "refuses, and writes nothing, when shipped lib or priv differ from origin/main" do
      %{out: out, opts: opts} = before_setup()

      git = fn
        ["diff", "--quiet" | _] -> {"", 1}
        args -> clean_git(args)
      end

      assert_raise RuntimeError, ~r/differ from origin\/main/, fn ->
        Catalog.write!(:before, Keyword.put(opts, :git, git))
      end

      refute File.exists?(out)
    end

    test "refuses, and writes nothing, when the raw inputs are missing" do
      %{out: out, opts: opts} = before_setup()

      assert_raise ArgumentError, ~r/raw/, fn ->
        Catalog.write!(:before, Keyword.put(opts, :raw_dir, Path.join(tmp_dir(), "no-raw")))
      end

      refute File.exists?(out)
    end

    test "a raw dir with a missing lane is an error naming the lane, and writes nothing" do
      %{out: out, opts: opts, raw: raw} = before_setup()
      File.rm_rf!(Path.join(raw, "generated-host/emails"))

      assert_raise RuntimeError, ~r/generated-host\/emails/, fn ->
        Catalog.write!(:before, opts)
      end

      refute File.exists?(out)
    end

    test "is refused under CI=true" do
      %{out: out, opts: opts} = before_setup()

      assert_raise RuntimeError, ~r/SIGRA_BRAND_CATALOG=before.*refused when CI is set/s, fn ->
        Catalog.write!(
          :before,
          Keyword.put(opts, :env, %{"SIGRA_BRAND_CATALOG" => "before", "CI" => "true"})
        )
      end

      refute File.exists?(out)
    end
  end

  describe "privacy_violations/1 planted-failure controls" do
    @slash "/"
    @users_dir @slash <> "Users" <> @slash
    @home_dir @slash <> "home" <> @slash

    test "flags a macOS home-directory path" do
      assert {:home_path, "p.html"} in leak("rendered from " <> @users_dir <> "someone/app")
    end

    test "flags a Linux home-directory path" do
      assert {:home_path, "p.html"} in leak("cached at " <> @home_dir <> "someone/.cache")
    end

    test "flags a Windows user-profile path" do
      assert {:windows_profile, "p.html"} in leak(
               "C:" <> "\\" <> "Users" <> "\\" <> "someone" <> "\\x"
             )
    end

    test "flags a macOS temp path" do
      assert {:private_var_path, "p.html"} in leak("built in /private/var/folders/xx/y")
    end

    test "flags an absolute local file URL" do
      assert {:file_url, "p.html"} in leak("src=" <> "file:" <> "//" <> "/tmp/logo.png")
    end

    test "flags an email whose domain does not end in .test" do
      assert {:email, "p.html"} in leak("mail " <> "someone" <> "@" <> "example.com" <> " now")
    end

    test "flags a secret_key_base mention" do
      assert {:secret_key_base, "p.html"} in leak(~s(config secret_key_base: "abc"))
    end

    test "flags a signing_salt mention" do
      assert {:signing_salt, "p.html"} in leak(~s(live_view: [signing_salt: "abc"]))
    end

    test "flags a long csrf-looking token value in either attribute order and in a key form" do
      token = "AbCdEfGhIjKlMnOpQrSt1234567890-_"

      for html <- [
            ~s(<input type="hidden" name="_csrf_token" value="#{token}"/>),
            ~s(<input value="#{token}" name="_csrf_token"/>),
            ~s(<meta name="csrf-token" content="#{token}"/>),
            ~s(csrf_token: "#{token}")
          ] do
        assert {:csrf_token_value, "p.html"} in leak(html), "not flagged: #{html}"
      end
    end

    test "narrowness: seeded .test emails, the CSRF placeholder and persona labels pass" do
      text =
        "alice@demo.tasklane.test and bob@host.example.test " <>
          ~s(<input name="_csrf_token" value="{{CSRF}}"/> {{PERSONA:locked}} {{UUID}} ) <>
          "2026-05-14 08:12 203.0.113.24"

      assert Catalog.privacy_violations(%{"p.html" => text}) == []
    end

    test "a planted leak makes the scan fail once, with one finding per leaked kind" do
      text =
        "rendered " <>
          @users_dir <> "someone/x " <> "a" <> "@" <> "b.com" <> ~s( secret_key_base: "x")

      kinds = text |> leak() |> Enum.map(&elem(&1, 0)) |> Enum.sort()

      assert kinds == [:email, :home_path, :secret_key_base]
    end
  end

  describe ".gitattributes" do
    test "keeps the before catalog byte-exact and still vendors brand/" do
      lines =
        @root
        |> Path.join(".gitattributes")
        |> File.read!()
        |> String.replace("\r\n", "\n")
        |> String.split("\n")

      assert "test/fixtures/brand/before/** -text" in lines
      assert "brand/** -text linguist-vendored" in lines
    end
  end

  defp leak(text), do: Catalog.privacy_violations(%{"p.html" => text})

  defp sha256(bytes), do: :sha256 |> :crypto.hash(bytes) |> Base.encode16(case: :lower)

  defp clean_git(["diff", "--quiet" | _]), do: {"", 0}

  defp clean_git(["rev-parse", "origin/main"]),
    do: {"1111111111111111111111111111111111111111\n", 0}

  defp clean_git(["merge-base", "origin/main", "HEAD"]),
    do: {"2222222222222222222222222222222222222222\n", 0}

  defp clean_git(["rev-parse", "HEAD:lib"]), do: {"aaaa\n", 0}
  defp clean_git(["rev-parse", "HEAD:priv"]), do: {"bbbb\n", 0}
  defp clean_git(["rev-parse", "HEAD:test/fixtures/install_golden/tree"]), do: {"cccc\n", 0}
  defp clean_git(["diff", "--name-only" | _]), do: {"", 0}

  # A directory holding the given lane files plus the manifest Catalog.manifest/2 builds.
  defp write_catalog_dir(files) do
    dir = tmp_dir()

    for {path, bytes} <- files do
      File.mkdir_p!(Path.dirname(Path.join(dir, path)))
      File.write!(Path.join(dir, path), bytes)
    end

    manifest = Catalog.manifest(files, %{pinned: @pinned})
    File.write!(Path.join(dir, "MANIFEST.json"), manifest)
    dir
  end

  # Output dir (not created), a planted raw dir with all three lanes, and writer opts.
  defp before_setup do
    base = tmp_dir()
    out = Path.join(base, "before")
    raw = Path.join(base, "raw")

    plant = fn path, bytes ->
      File.mkdir_p!(Path.dirname(Path.join(raw, path)))
      File.write!(Path.join(raw, path), bytes)
    end

    plant.(
      "tier2-example-admin/admin-users-index.html",
      ~s(<input name="_csrf_token" value="leaky-csrf-value"/><p>{{PERSONA:active}}</p>)
    )

    plant.("generated-host/pages/log-in.html", "<h1>Log in</h1>")
    plant.("generated-host/emails/confirmation.txt", "Subject: Confirm\n=== TEXT ===\nHello  \n")

    %{
      out: out,
      raw: raw,
      opts: [
        env: %{"SIGRA_BRAND_CATALOG" => "before"},
        out_dir: out,
        raw_dir: raw,
        git: &clean_git/1
      ]
    }
  end

  defp tmp_dir do
    dir = Path.join(System.tmp_dir!(), "sigra_catalog_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    dir
  end
end
