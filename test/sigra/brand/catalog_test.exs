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

  alias Sigra.Admin.Live.{
    AuditIndexLive,
    AuditUserLive,
    BrandingLive,
    IndexLive,
    OrganizationLive,
    UserSessionsLive,
    UserShowLive,
    UsersIndexLive
  }

  alias Sigra.Admin.Components
  import Phoenix.LiveViewTest, only: [render_component: 2]
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

    test "a pagination cursor value is replaced, the rest of the query stays" do
      # The audit cursor is base64url of "<timestamp>|<row uuid>"; the row uuid is a
      # fresh random value on every seeded run, so two captures never agree on it.
      first = "MTc2NzIyNTYyMDAwMDAwMHw1MjI3ODc0Yy0xMWFkLTQzZDAtOTU2OC01MDQ5ZjI0ZDNmYTA"
      second = "MTc2NzIyNTYyMDAwMDAwMHwzOWUwZmQxNC1jZjhiLTRjYjAtODY3ZS1hNzBlY2QzNGZjNDQ"

      page = fn cursor ->
        ~s(<a href="/admin/audit?cursor=#{cursor}&amp;order_by=inserted_at">Next</a>) <>
          ~s(<a href="/admin/audit?order_by=inserted_at&amp;cursor=#{cursor}">Next</a>)
      end

      out = Catalog.normalize(page.(first))

      refute out =~ first
      assert out =~ ~s(href="/admin/audit?cursor={{CURSOR}}&amp;order_by=inserted_at")
      assert out =~ ~s(href="/admin/audit?order_by=inserted_at&amp;cursor={{CURSOR}}")
      assert out == Catalog.normalize(page.(second))
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

      assert normalized =~ "Locked — review active sessions with Manage sessions."
      assert normalized =~ "Locked"

      # The raw render really did carry the volatiles the normalizer is claimed to remove.
      assert raw =~ ~r/name="_csrf_token" value="[^"]{8,}"/
      assert raw =~ ~r/\d+d ago/
      assert normalized =~ "{{CSRF}}"
      assert normalized =~ "{{RELATIVE}}"
    end
  end

  describe "Phase 262 overview and audit copy" do
    test "overview and global audit captures use the approved zero-state language" do
      overview = Catalog.tier1_html({IndexLive, :overview})
      needs_review = Catalog.tier1_html({IndexLive, :needs_review})
      audit_empty = Catalog.tier1_html({AuditIndexLive, :empty})
      branding = Catalog.tier1_html({BrandingLive, :default_profile})

      assert overview =~ "No users need review."
      refute overview =~ "No flagged accounts"
      assert needs_review =~ "Review users"
      refute needs_review =~ "Review risky users"
      assert audit_empty =~ "No audit events yet."
      assert audit_empty =~ "Audit events appear here as activity is recorded."
      assert branding =~ "Sign-in preview"
      refute branding =~ "Login preview"
    end
  end

  describe "Phase 262 organization catalog states" do
    test "populated and empty organization captures retain scoped language and truthful states" do
      populated = Catalog.tier1_html({OrganizationLive, :populated})
      empty = Catalog.tier1_html({OrganizationLive, :empty})

      assert populated =~ "Members, audit events, and invitations stay within this organization."
      assert populated =~ "Review members"
      assert empty =~ "No members yet"
      assert empty =~ "No pending invitations"
      refute empty =~ "Review members"
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

    test "the coverage text carries the tier-2 sender override, the reset-page marker and the one exact-value replacement" do
      text = JSON.encode!(Catalog.coverage())

      assert text =~ "tier-2 auth branding page"
      assert text =~ "sender field is overridden"
      assert text =~ "generated-host-pages/reset-password.html is a marker"
      assert text =~ "HTTP 500"
      assert text =~ "{{CAPTURE_SESSION_ACTIVITY}}"
      assert text =~ "only exact-value replacement"
    end

    test "names the reset-request page fix as owed and says its before is a marker, not a page" do
      decoded = JSON.decode!(Catalog.manifest(%{}, %{pinned: @pinned}))
      text = JSON.encode!(decoded["deferred_shipped_byte_fixes"])

      assert text =~ "reset-request page"
      assert text =~ "HTTP 500"
      assert text =~ "marker"
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

    test "personas are the tier-1 personas plus the seeded cohort found in tier 2, not bulk rows or the capture sender" do
      %{out: out, opts: opts, raw: raw} = before_setup()

      File.write!(
        Path.join(raw, "tier2-example-admin/admin-users-index.html"),
        "<td>alice@demo.tasklane.test</td><td>alice@demo.tasklane.test</td>" <>
          "<td>loadtest-3-0123abcd@demo.tasklane.test</td><td>noreply@catalog.example.test</td>"
      )

      Catalog.write!(:before, opts)

      personas =
        out
        |> Path.join("MANIFEST.json")
        |> File.read!()
        |> JSON.decode!()
        |> Map.fetch!("personas")

      assert "alice@demo.tasklane.test" in personas
      assert "admin@demo.tasklane.test" in personas
      assert personas == Enum.sort(Enum.uniq(personas))
      refute Enum.any?(personas, &String.starts_with?(&1, "loadtest-"))
      refute "noreply@catalog.example.test" in personas
    end

    test "lists the example sources changed against origin/main, sorted, render paths only" do
      %{out: out, opts: opts} = before_setup()
      test_pid = self()

      git = fn
        ["diff", "--name-only" | _] = args ->
          send(test_pid, {:name_only_args, args})
          {"test/example/lib/b.ex\ntest/example/lib/a.ex\n", 0}

        args ->
          clean_git(args)
      end

      Catalog.write!(:before, Keyword.put(opts, :git, git))

      manifest = out |> Path.join("MANIFEST.json") |> File.read!() |> JSON.decode!()

      assert manifest["example_files_changed_vs_main"] ==
               ["test/example/lib/a.ex", "test/example/lib/b.ex"]

      assert_received {:name_only_args, args}
      assert "test/example/lib" in args
      refute Enum.any?(args, &String.contains?(&1, "playwright"))
      refute "test/example" in args
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

  describe "generated host after catalog review" do
    test "after capture includes the complete generated auth and email surface set" do
      if Sigra.Test.Brand.RegenGuard.requested?(Catalog.regen_env(), "after") do
        after_dir = Catalog.out_dir(:after)
        paths =
          after_dir
          |> Path.join("**/*")
          |> Path.wildcard()
          |> Enum.filter(&File.regular?/1)
          |> Enum.map(&Path.relative_to(&1, after_dir))

        for path <- ~w(
          generated-host-pages/confirm.html
          generated-host-pages/log-in.html
          generated-host-pages/register.html
          generated-host-pages/reset-password-invalid-token.html
          generated-host-pages/reset-password.html
          generated-host-emails/confirmation.txt
          generated-host-emails/reset-password.txt
          generated-host-emails/magic-link.txt
          generated-host-emails/suspicious-login.txt
          generated-host-emails/oauth-reset.txt
          generated-host-emails/enterprise-sso-reset.txt
          generated-host-emails/passkey-registration.txt
          generated-host-emails/lockout-notification.txt
          generated-host-emails/mfa-enabled.txt
          generated-host-emails/mfa-disabled.txt
          generated-host-emails/backup-code-used.txt
          generated-host-emails/mfa-lockout.txt
          generated-host-emails/email-changed.txt
          generated-host-emails/deletion-scheduled.txt
          generated-host-emails/deletion-cancelled.txt
          generated-host-emails/deletion-finalized.txt
          generated-host-emails/password-changed.txt
          generated-host-emails/organization-invitation.txt
        ) do
          assert path in paths, "generated host catalog is missing #{path}"
        end

        for path <- Enum.filter(paths, &String.starts_with?(&1, "generated-host-emails/")) do
          email = after_dir |> Path.join(path) |> File.read!()
          assert email =~ "=== HTML ==="
          assert email =~ "=== TEXT ==="
        end

        for path <- paths,
            String.starts_with?(path, "generated-host-emails/") or
              String.starts_with?(path, "generated-host-pages/") do
          content = after_dir |> Path.join(path) |> File.read!()
          visible_text = content |> then(&Regex.replace(~r/<!--.*?-->/s, &1, " "))
          visible_text = Regex.replace(~r/<[^>]*>/, visible_text, " ")

          accessible_labels =
            Regex.scan(~r/\b(?:aria-label|alt|title)="([^"]*)"/i, content, capture: :all_but_first)
            |> List.flatten()
            |> Enum.join(" ")

          refute (visible_text <> " " <> accessible_labels) =~ ~r/\b(?:Sigra|Kiln)\b/i,
                 "#{path} exposes library identity"
        end
      end
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

  describe "privacy_violations_in/1 over written catalog directories" do
    test "finds a planted leak in a lane file and in the manifest, and reports a clean directory as []" do
      leaky =
        write_catalog_dir(%{
          "tier2-example-admin/p.html" => "<p>reach out: someone@nowhere.invalid</p>\n",
          "generated-host-pages/q.html" => "<p>fine</p>\n"
        })

      assert Catalog.privacy_violations_in(leaky) == [{:email, "tier2-example-admin/p.html"}]

      File.write!(Path.join(leaky, "MANIFEST.json"), "{\"note\": \"someone@nowhere.invalid\"}\n")

      assert {:email, "MANIFEST.json"} in Catalog.privacy_violations_in(leaky)

      clean =
        write_catalog_dir(%{"tier1-library-admin/a.html" => "<p>a@demo.tasklane.test</p>\n"})

      assert Catalog.privacy_violations_in(clean) == []
    end

    test "whichever directory the writer just wrote is non-empty and clean" do
      # Live only while a maintainer runs the writer (`SIGRA_BRAND_CATALOG=after|before`);
      # the planted test above is the control that the scan itself can fail.
      written =
        for mode <- [:before, :after],
            Sigra.Test.Brand.RegenGuard.requested?(Catalog.regen_env(), Atom.to_string(mode)) do
          Catalog.out_dir(mode)
        end

      for dir <- written do
        assert map_size(Catalog.read_dir!(dir)) > 0, "writer produced no files in #{dir}"
        assert Catalog.privacy_violations_in(dir) == []
      end
    end

    test "the committed before catalog, when it exists, passes the privacy scan with its manifest" do
      case Catalog.committed_status() do
        :absent ->
          :ok

        {:present, _diff} ->
          dir = Catalog.out_dir(:before)

          assert map_size(Catalog.read_dir!(dir)) > 0
          assert Catalog.privacy_violations_in(dir) == []
      end
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

  describe "catalog-only status mark specimen" do
    test "Suspended renders as a pure specimen and stays out of runtime page output" do
      html = render_component(&Components.status_mark/1, status: :suspended)
      visible_text = html |> String.replace(~r/<[^>]+>/, "") |> String.trim()
      runtime_pages = Enum.map(Catalog.tier1_states(), &Catalog.tier1_html/1)

      assert html =~ ~s(data-status="suspended")
      assert visible_text == "Suspended"
      refute Enum.any?(runtime_pages, &String.contains?(&1, "Suspended"))
    end
  end

  describe "tier 1 state matrix" do
    # The state the pure render must actually show: a marker the shipped markup
    # produces only for that state, so a state cannot silently render as another.
    @state_markers [
      {{UsersIndexLive, :populated}, "Open user"},
      {{UsersIndexLive, :empty}, "No users match this view"},
      {{UsersIndexLive, :filtered_empty}, "No users match the active filters"},
      {{UserShowLive, :active}, "MFA + passkeys"},
      {{UserShowLive, :unconfirmed}, "Email unconfirmed"},
      {{UserShowLive, :locked}, "Locked — review active sessions with Manage sessions."},
      {{UserShowLive, :scheduled_deletion}, "Deletion scheduled"},
      {{UserSessionsLive, :populated}, "Revoke all sessions"},
      {{UserSessionsLive, :empty}, "This user has no active sessions in the current scope."},
      {{AuditIndexLive, :populated}, "Impersonation started"},
      {{AuditIndexLive, :empty}, "No audit events yet."},
      {{AuditUserLive, :populated}, "Review recorded activity for this user."},
      {{AuditUserLive, :empty}, "No scoped events are currently tied to this user."},
      {{OrganizationLive, :populated}, "members need review"},
      {{OrganizationLive, :empty}, "No members yet"},
      {{IndexLive, :overview}, "No users need review."},
      {{IndexLive, :needs_review}, "users need review"},
      {{BrandingLive, :default_profile}, "Config defaults"},
      {{BrandingLive, :explicit_profile}, "Admin profile"}
    ]

    test "tier1_states/0 is a sorted, unique list that covers the planned matrix" do
      states = Catalog.tier1_states()
      planned = Enum.map(@state_markers, &elem(&1, 0))

      assert states == Enum.sort(states)
      assert states == Enum.uniq(states)
      assert MapSet.subset?(MapSet.new(planned), MapSet.new(states))
    end

    test "every one of the eight library admin LiveViews appears at least once" do
      eight =
        @root
        |> Path.join("lib/sigra/admin/live/*_live.ex")
        |> Path.wildcard()
        |> Enum.map(
          &(&1
            |> Path.basename(".ex")
            |> Macro.camelize()
            |> then(fn name -> Module.concat(Sigra.Admin.Live, name) end))
        )
        |> Enum.sort()

      covered = Catalog.tier1_states() |> Enum.map(&elem(&1, 0)) |> Enum.uniq() |> Enum.sort()

      # Derived from the source tree, so a ninth LiveView added later fails here.
      assert length(eight) == 8
      assert covered == eight
    end

    test "tier1_entries/0 are unique, sorted, tier1-library-admin/<live>--<state>.html paths" do
      entries = Catalog.tier1_entries()

      assert entries != []
      assert entries == Enum.sort(Enum.uniq(entries))
      assert Enum.all?(entries, &(&1 =~ ~r{\Atier1-library-admin/[a-z0-9_]+--[a-z0-9_]+\.html\z}))
      assert length(entries) == length(Catalog.tier1_states())
    end

    test "every state shows what its name says" do
      for {entry, marker} <- @state_markers do
        html = Catalog.tier1_html(entry)

        assert html =~ marker, "#{inspect(entry)} does not contain #{inspect(marker)}"
      end
    end

    test "two renders of every state normalize to identical, non-empty bytes" do
      for entry <- Catalog.tier1_states() do
        first = Catalog.tier1_html(entry)

        assert first != "", "#{inspect(entry)} rendered nothing"
        assert first == Catalog.tier1_html(entry), "#{inspect(entry)} is not deterministic"
      end
    end

    test "no output holds a raw UUID, a csrf value or relative wall-clock text" do
      uuid = ~r/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/

      for entry <- Catalog.tier1_states() do
        html = Catalog.tier1_html(entry)

        refute html =~ uuid, "#{inspect(entry)} holds a raw UUID"
        refute html =~ ~r/\d+[mhd] ago|just now/, "#{inspect(entry)} holds relative text"

        refute html =~ ~r/name="_csrf_token" value="(?!\{\{CSRF\}\})/,
               "#{inspect(entry)} holds a csrf value"
      end
    end

    test "clock control: no output carries a date later than the pinned clock or on the run day" do
      for entry <- Catalog.tier1_states() do
        assert Catalog.clock_violations(Catalog.tier1_html(entry)) == [],
               "#{inspect(entry)} shows a date that is not pinned at the source"
      end
    end

    test "clock control, planted: a data timestamp that sneaked in as utc_now is flagged" do
      today = Date.to_iso8601(Date.utc_today())

      assert Catalog.clock_violations("<td>#{today} 10:00</td>") == [today]
      assert Catalog.clock_violations("<td>2099-01-01 00:00</td>") == ["2099-01-01"]

      assert Catalog.clock_violations("<td>2026-05-14 00:00</td>", ~D[2026-05-14]) == [
               "2026-05-14"
             ]

      assert Catalog.clock_violations("<td>2026-05-15 00:00</td>") == []
    end

    test "the tier-1 output passes the privacy scan: personas are fictional .test addresses" do
      assert Catalog.privacy_violations(Catalog.tier1_files()) == []
    end

    test "the branding preview placeholder address is masked, other example.com addresses are not" do
      # Built from fragments so this file holds no literal non-.test address.
      preview = "alex" <> "@" <> "example.com"
      other = "someone" <> "@" <> "example.com"

      masked = Catalog.normalize(~s(<input type="email" value="#{preview}"/>))

      assert masked =~ "{{PREVIEW_EMAIL}}"
      refute masked =~ preview
      assert Catalog.normalize("<p>#{other}</p>") =~ other
      assert {:email, "p.html"} in leak(Catalog.normalize("<p>#{other}</p>"))
    end

    test "the manifest coverage records the masked preview address and the event-driven states" do
      text = JSON.encode!(Catalog.coverage())

      assert text =~ "PREVIEW_EMAIL"
      assert text =~ "event-driven"
    end

    test "after mode writes a file for every tier-1 state" do
      out = tmp_dir()
      result = Catalog.write!(:after, env: %{"SIGRA_BRAND_CATALOG" => "after"}, out_dir: out)

      assert Catalog.tier1_entries() -- result.files == []
      assert Enum.all?(Catalog.tier1_entries(), &File.regular?(Path.join(out, &1)))
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
