defmodule Sigra.Planning.Phase236AuditUrlOwnershipTest do
  use ExUnit.Case, async: true

  # Phase 236 (GREEN-02, SC-2): a source contract proving
  # `Sigra.Admin.Live.AuditIndexLive` owns every URL transition on the failing
  # test's path — its own preset/sort/clear anchors and its filter form —
  # instead of the browser owning them via plain `<a href>` / `<form
  # method="get">` document navigations that race LiveView's `unload()`
  # one-way latch (see 236-DIAGNOSIS.md). This is RED against HEAD: the file
  # has zero `phx-submit`, zero `handle_event(`, zero `patch=`.

  @live_view_path "lib/sigra/admin/live/audit_index_live.ex"

  test "filter form carries phx-submit while keeping method=get and action=" do
    source = File.read!(@live_view_path)

    assert source =~ ~s(phx-submit="apply_filters"),
           "the filter form must gain phx-submit=\"apply_filters\" so LiveView owns the submit " <>
             "instead of the browser's native GET racing live_socket.js's unload() latch"

    assert source =~ ~s(method="get"),
           "method=\"get\" must survive as the progressive-enhancement fallback for the dead-render window"

    assert source =~ "action={index_path(@admin_scope)}",
           "action= must still resolve via index_path/1 so the no-JS fallback targets the correct scope"
  end

  test "module defines at least one handle_event/3 clause" do
    source = File.read!(@live_view_path)

    assert source =~ ~r/def handle_event\(/,
           "AuditIndexLive must define handle_event/3 to own the apply_filters transition " <>
             "instead of leaving it entirely to a document navigation"
  end

  test "the six named anchors render as <.link patch=...>" do
    source = File.read!(@live_view_path)

    assert Regex.scan(~r/<\.link[^>]*patch=\{preset_path\(/s, source) |> length() == 2,
           "expected exactly 2 <.link patch={preset_path(...)}> anchors (Failures, Impersonation) " <>
             "— the parse broke, this is not a pass"

    assert Regex.scan(~r/<\.link[^>]*patch=\{index_path\(@admin_scope\)\}/s, source) |> length() ==
             3,
           "expected exactly 3 <.link patch={index_path(@admin_scope)}> anchors (Clear, Clear all, " <>
             "Clear all filters) — the parse broke, this is not a pass"

    assert Regex.scan(~r/<\.link[^>]*patch=\{sort_path\(/s, source) |> length() == 1,
           "expected exactly 1 <.link patch={sort_path(...)}> anchor (Occurred sort header) " <>
             "— the parse broke, this is not a pass"
  end

  test "export_path is still reached through href= on a plain <a, never through patch=" do
    source = File.read!(@live_view_path)

    assert source =~ ~r/<a\s+href=\{export_path\(/,
           "Export CSV is a controller CSV download and must remain a plain <a href> document navigation"

    refute source =~ ~r/patch=\{export_path\(/,
           "export_path must never be reached through patch= — it is not a LiveView transition"
  end

  test "non-vacuity floor: at least 6 occurrences of patch=" do
    source = File.read!(@live_view_path)

    count = Regex.scan(~r/patch=/, source) |> length()

    assert count >= 6,
           "found #{count} occurrences of patch= in #{@live_view_path} — the parse broke, this is not a pass"
  end

  test "remove_href= and prev_href=/next_href= remain unconverted (recorded scope exclusion)" do
    source = File.read!(@live_view_path)

    assert source =~ "remove_href={remove_chip_path(",
           "remove_href= must remain a component attribute — its anchor lives in the shared " <>
             "components.ex, out of this plan's scope"

    assert source =~ "prev_href={page_path(",
           "prev_href= must remain a component attribute — its anchor lives in the shared " <>
             "components.ex, out of this plan's scope"

    assert source =~ "next_href={page_path(",
           "next_href= must remain a component attribute — its anchor lives in the shared " <>
             "components.ex, out of this plan's scope"
  end

  test "the submit button renders verbatim" do
    source = File.read!(@live_view_path)

    assert source =~
             ~s(<button type="submit" class="sg-btn sg-btn--primary">Apply filters</button>),
           "the submit button is clicked by role in admin-audit.spec.ts and is in the PNG " <>
             "baselines — it must not change"
  end

  test "phx-change does not appear in the file" do
    source = File.read!(@live_view_path)

    refute source =~ "phx-change",
           "D-09: phx-change must not be added — live_socket.js keys its external-submit branch " <>
             "on phx-change && !phx-submit, and adding both changes debounce/validation semantics " <>
             "for no benefit"
  end

  test "the module declares @filter_param_keys and handle_event whitelists with Map.take" do
    source = File.read!(@live_view_path)

    assert source =~ "@filter_param_keys",
           "the whitelist module attribute must exist — ASVS V5 requires client-controlled " <>
             "params to be whitelisted before reaching the patched URL"

    assert source =~ "Map.take(",
           "handle_event must whitelist params with Map.take/2 against @filter_param_keys — " <>
             "without it a caller injects arbitrary query keys into the admin URL"
  end

  test "D-14 blank-equivalence contract: param_value default and append_query's blank rejection both survive" do
    source = File.read!(@live_view_path)

    assert source =~ "defp param_value(params, key, default \\\\ \"\")",
           "param_value/3's default must survive — it is what makes handle_params treat " <>
             "missing == blank, matching the no-JS fallback's submitted-blank behavior"

    assert source =~ "value in [nil, \"\", false]",
           "append_query/2's blank rejection must survive — together with param_value/3's " <>
             "default this makes the JS and no-JS URLs land on the same filtered state (D-14)"
  end
end
