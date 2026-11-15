#!/usr/bin/env bash
# scripts/ci/admin-acceptance-smoke.sh
#
# Scaffolds a fresh Phoenix app, installs Sigra, adds deterministic organization
# policy + seed data, provisions the first platform admin through the generated
# Mix task, boots the host, and runs the focused Playwright acceptance smoke.
#
# Local reproduction:
#   GITHUB_WORKSPACE=$(pwd) scripts/ci/admin-acceptance-smoke.sh
#   GITHUB_WORKSPACE=$(pwd) scripts/ci/admin-acceptance-smoke.sh --test chrome
#   GITHUB_WORKSPACE=$(pwd) scripts/ci/admin-acceptance-smoke.sh --test auth
#   GITHUB_WORKSPACE=$(pwd) scripts/ci/admin-acceptance-smoke.sh --test errors
#   GITHUB_WORKSPACE=$(pwd) scripts/ci/admin-acceptance-smoke.sh --test audit-export
#   GITHUB_WORKSPACE=$(pwd) scripts/ci/admin-acceptance-smoke.sh --test impersonation-controller
#   GITHUB_WORKSPACE=$(pwd) scripts/ci/admin-acceptance-smoke.sh --test catalog
#
# Every --test target (including slices above) runs the bash HTTP parity probes
# first, then the filtered or full Playwright suite — probes are never skipped.
#
# --test catalog is the one exception. It is the generated-lane producer for the
# before catalog (Phase 260): it boots the same generated host, writes RAW
# anonymous auth pages and the generated email builders to
# ${SIGRA_CATALOG_RAW_DIR:-<repo>/tmp/catalog-raw}/generated-host/{pages,emails},
# then exits 0 before the parity probes and before any Playwright step.

set -euo pipefail

SIGRA_REPO="${GITHUB_WORKSPACE:-$(pwd)}"
PLAYWRIGHT_DIR="${SIGRA_REPO}/test/example/priv/playwright"
TMP_APP_DIR="${TMP_APP_DIR:-/tmp/sigra_admin_smoke}"
APP_NAME="sigra_admin_smoke"
APP_MODULE="SigraAdminSmoke"
WEB_MODULE="SigraAdminSmokeWeb"
CONTEXT_MODULE="SigraAdminSmoke.Accounts"
PORT="${PORT:-4017}"
TEST_TARGET="all"
PLAYWRIGHT_OUTPUT="test-results/generated-host"
SERVER_LOG="${TMP_APP_DIR}/server.log"
PLAYWRIGHT_SPEC="tests/admin-generated.spec.ts"

export PGUSER="${PGUSER:-postgres}"
export PGPASSWORD="${PGPASSWORD:-postgres}"
export PGHOST="${PGHOST:-localhost}"
export MIX_ENV="${MIX_ENV:-dev}"
# test-only: deterministic Cloak key for the ephemeral smoke DB; NEVER
# reuse in any non-test environment. The default value only takes effect
# when CLOAK_KEY is unset, so CI / local runs can override.
export CLOAK_KEY="${CLOAK_KEY:-MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=}"

export SIGRA_PLATFORM_ADMIN_EMAIL="${SIGRA_PLATFORM_ADMIN_EMAIL:-platform-admin@example.test}"
export SIGRA_ORG_ADMIN_EMAIL="${SIGRA_ORG_ADMIN_EMAIL:-org-admin@example.test}"
# test-only: deterministic smoke admin password; NEVER reuse in any
# non-test environment. Matches the shared Playwright TEST_PASSWORD
# fixture so the scaffolded admin user can log in from the spec side.
export SIGRA_ADMIN_PASSWORD="${SIGRA_ADMIN_PASSWORD:-CorrectHorseBatteryStaple123!}"
export SIGRA_ALLOWED_ORG_SLUG="${SIGRA_ALLOWED_ORG_SLUG:-allowed-org}"
export SIGRA_ALLOWED_ORG_NAME="${SIGRA_ALLOWED_ORG_NAME:-Allowed Org}"
export SIGRA_OTHER_ORG_SLUG="${SIGRA_OTHER_ORG_SLUG:-other-scope}"
export SIGRA_IMPERSONATION_TARGET_EMAIL="${SIGRA_IMPERSONATION_TARGET_EMAIL:-impersonation-target@example.test}"

# The disposable host is generated under /tmp, outside this repository's
# asdf lookup path. Preserve the repo-pinned Beam versions after changing cwd.
if command -v asdf >/dev/null 2>&1 && [[ -f "${SIGRA_REPO}/.tool-versions" ]]; then
  pinned_erlang_version=$(awk '$1 == "erlang" { print $2; exit }' "${SIGRA_REPO}/.tool-versions")
  pinned_elixir_version=$(awk '$1 == "elixir" { print $2; exit }' "${SIGRA_REPO}/.tool-versions")
  [[ -z "${ASDF_ERLANG_VERSION:-}" && -n "${pinned_erlang_version}" ]] && export ASDF_ERLANG_VERSION="${pinned_erlang_version}"
  [[ -z "${ASDF_ELIXIR_VERSION:-}" && -n "${pinned_elixir_version}" ]] && export ASDF_ELIXIR_VERSION="${pinned_elixir_version}"
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --test)
      TEST_TARGET="$2"
      shift 2
      ;;
    --help|-h)
      sed -n '2,48p' "${BASH_SOURCE[0]}"
      exit 0
      ;;
    *)
      echo "unknown arg: $1" >&2
      exit 1
      ;;
  esac
done

cleanup() {
  if [[ -n "${SERVER_PID:-}" ]]; then
    kill "${SERVER_PID}" 2>/dev/null || true
  fi
}

trap cleanup EXIT

echo "==> admin-acceptance: using Sigra repo at ${SIGRA_REPO}"

# D-11: assert the resolved phx.new version matches the pin target before
# scaffolding. A stale cached 1.8.7 archive on a reused CI runner would
# otherwise produce a false-green against the wrong generator version.
PHX_NEW_PIN="1.8.8"
PHX_NEW_RESOLVED=$(mix phx.new --version 2>&1 || true)
if ! echo "${PHX_NEW_RESOLVED}" | grep -q "${PHX_NEW_PIN}"; then
  echo "FAIL: resolved phx.new version does not match pin target ${PHX_NEW_PIN}"
  echo "  resolved: ${PHX_NEW_RESOLVED}"
  echo "  expected: Phoenix installer v${PHX_NEW_PIN}"
  echo "  Fix: mix archive.install --force hex phx_new ${PHX_NEW_PIN}"
  exit 1
fi
echo "==> admin-acceptance: phx.new version OK (${PHX_NEW_RESOLVED})"

echo "==> admin-acceptance: generating fresh Phoenix app at ${TMP_APP_DIR}"

rm -rf "${TMP_APP_DIR}"
mkdir -p "$(dirname "${TMP_APP_DIR}")"
cd "$(dirname "${TMP_APP_DIR}")"

mix phx.new "${APP_NAME}" \
  --no-install \
  --no-dashboard \
  --database postgres

cd "${TMP_APP_DIR}"
export HEX_HOME="${TMP_APP_DIR}/.hex"

echo "==> admin-acceptance: patching mix.exs with local Sigra path dep"
export SIGRA_REPO
elixir -e '
  path = "mix.exs"
  content = File.read!(path)
  sigra_dep = "      {:sigra, path: System.get_env(\"SIGRA_REPO\")},\n      {:phoenix,"
  new_content = String.replace(content, "      {:phoenix,", sigra_dep, global: false)
  if new_content == content do
    IO.puts(:stderr, "FAIL: anchor '"'"'      {:phoenix,'"'"' not found in mix.exs; mix phx.new output shape changed")
    System.halt(1)
  end
  File.write!(path, new_content)
'

echo "==> admin-acceptance: fetching deps"
mix deps.get

echo "==> admin-acceptance: running mix sigra.install --yes Accounts User users --no-passkeys"
mix sigra.install --yes Accounts User users --no-passkeys

echo "==> admin-acceptance: adding deterministic organization policy"
cat > "lib/${APP_NAME}/sigra_admin_policy.ex" <<'EOF'
defmodule SigraAdminSmoke.SigraAdminPolicy do
  @moduledoc """
  Deterministic admin policy used by the generated-host acceptance smoke.
  """

  @behaviour Sigra.Admin.Policy

  import Ecto.Query, only: [from: 2]

  alias SigraAdminSmoke.Accounts.OrganizationMembership
  alias SigraAdminSmoke.Repo

  @org_admin_email System.get_env("SIGRA_ORG_ADMIN_EMAIL", "org-admin@example.test")

  @impl true
  def platform_admin?(scope), do: SigraAdminSmoke.SigraAdminAccess.platform_admin?(scope)

  @impl true
  def admin_org_ids(%{user: %{id: user_id, email: email}})
      when is_binary(user_id) and is_binary(email) do
    if email == @org_admin_email do
      from(membership in OrganizationMembership,
        where: membership.user_id == ^user_id,
        select: %{organization_id: membership.organization_id, role: membership.role}
      )
      |> Repo.all()
      |> Sigra.Admin.Policy.admin_org_ids_from_memberships()
    else
      []
    end
  end

  def admin_org_ids(_scope), do: []
end
EOF

echo "==> admin-acceptance: compiling generated host"
mix compile --warnings-as-errors

echo "==> admin-acceptance: running generated allow/deny policy test"
MIX_ENV=test mix ecto.drop || true
MIX_ENV=test mix ecto.create
MIX_ENV=test mix ecto.migrate
MIX_ENV=test mix test "test/${APP_NAME}/sigra_admin_policy_test.exs"

echo "==> admin-acceptance: resetting database"
mix ecto.drop || true
mix ecto.create
mix ecto.migrate

echo "==> admin-acceptance: seeding deterministic admin fixtures"
SEED_FILE="${TMP_APP_DIR}/sigra_admin_acceptance_seed.exs"
cat > "${SEED_FILE}" <<'EOF'
alias SigraAdminSmoke.Repo
alias SigraAdminSmoke.Accounts
alias SigraAdminSmoke.Accounts.User
alias SigraAdminSmoke.Accounts.Organization
alias SigraAdminSmoke.Accounts.OrganizationMembership

platform_admin_email = System.fetch_env!("SIGRA_PLATFORM_ADMIN_EMAIL")
org_admin_email = System.fetch_env!("SIGRA_ORG_ADMIN_EMAIL")
password = System.fetch_env!("SIGRA_ADMIN_PASSWORD")
allowed_org_slug = System.fetch_env!("SIGRA_ALLOWED_ORG_SLUG")
allowed_org_name = System.fetch_env!("SIGRA_ALLOWED_ORG_NAME")
other_org_slug = System.fetch_env!("SIGRA_OTHER_ORG_SLUG")
impersonation_target_email = System.fetch_env!("SIGRA_IMPERSONATION_TARGET_EMAIL")

confirm! = fn user ->
  user
  |> User.confirm_changeset()
  |> Repo.update!()
end

{:ok, platform_admin} =
  Accounts.register_user(%{"email" => platform_admin_email, "password" => password})

platform_admin = confirm!.(platform_admin)

{:ok, org_admin} =
  Accounts.register_user(%{"email" => org_admin_email, "password" => password})

org_admin = confirm!.(org_admin)

allowed_org =
  %Organization{}
  |> Organization.changeset(%{name: allowed_org_name, slug: allowed_org_slug})
  |> Repo.insert!()

_other_org =
  %Organization{}
  |> Organization.changeset(%{name: "Other Scope", slug: other_org_slug})
  |> Repo.insert!()

%OrganizationMembership{}
|> OrganizationMembership.changeset(%{
  role: :admin,
  user_id: org_admin.id,
  organization_id: allowed_org.id
})
|> Repo.insert!()

{:ok, impersonation_target} =
  Accounts.register_user(%{
    "email" => impersonation_target_email,
    "password" => password
  })

impersonation_target = confirm!.(impersonation_target)

IO.puts(
  "seeded #{platform_admin.email}, #{org_admin.email}, #{impersonation_target.email}, #{allowed_org.slug}, #{other_org_slug}"
)
EOF

mix run "${SEED_FILE}"

echo "==> admin-acceptance: provisioning first admin through generated tasks"
mix sigra.admin.grant --email "${SIGRA_PLATFORM_ADMIN_EMAIL}" --yes
mix sigra.admin.check --email "${SIGRA_PLATFORM_ADMIN_EMAIL}"
mix sigra.admin.list | grep -F "${SIGRA_PLATFORM_ADMIN_EMAIL}"

if [[ ! -d "${PLAYWRIGHT_DIR}/node_modules" ]]; then
  echo "==> admin-acceptance: installing Playwright npm deps"
  (cd "${PLAYWRIGHT_DIR}" && npm ci)
fi

echo "==> admin-acceptance: booting generated host on port ${PORT}"
PORT="${PORT}" PHX_SERVER=true mix phx.server > "${SERVER_LOG}" 2>&1 &
SERVER_PID=$!

for i in $(seq 1 60); do
  if curl -sf "http://localhost:${PORT}/" > /dev/null; then
    echo "==> admin-acceptance: app responded after ${i}s"
    break
  fi

  if [[ "${i}" -eq 60 ]]; then
    echo "FAIL: generated host did not boot within 60 seconds"
    cat "${SERVER_LOG}"
    exit 1
  fi

  sleep 1
done

# --- Phase 260 before-catalog producer (generated lane) ---------------------
# Early exit: only --test catalog enters this block, and it never returns to the
# parity probes or the Playwright targets below. Raw text only; nothing is
# compared or committed here (Sigra.Test.Brand.Catalog normalizes the dumps).
if [[ "${TEST_TARGET}" == "catalog" ]]; then
  CATALOG_RAW_DIR="${SIGRA_CATALOG_RAW_DIR:-${SIGRA_REPO}/tmp/catalog-raw}/generated-host"
  echo "==> admin-acceptance: writing generated-host catalog raw to ${CATALOG_RAW_DIR}"
  rm -rf "${CATALOG_RAW_DIR}/pages" "${CATALOG_RAW_DIR}/emails"
  mkdir -p "${CATALOG_RAW_DIR}/pages" "${CATALOG_RAW_DIR}/emails"

  # slug|path|expected status for the anonymous generated auth pages. Dead
  # renders only, no redirects followed: a page must answer exactly its expected
  # status, so a redirect or any other status fails loudly.
  #
  # One documented known defect is pinned as 500: the generated `--live` router
  # emits `live "/reset-password", ResetPasswordLive` with no live action, so the
  # request page raises CaseClauseError at mount for every adopter (todo
  # 2026-11-14-generated-reset-request-page-mount-and-user-struct-call). A 500 is
  # accepted ONLY when the dev error page carries that exact signature; the error
  # page itself (local paths, stack) is never kept, a one-line marker is written
  # instead. When the template is fixed this status turns 200 and the script fails
  # until the entry below is changed to 200: the baseline never goes stale.
  CATALOG_PAGES=(
    "log-in|/users/log_in|200"
    "register|/users/register|200"
    "reset-password|/users/reset-password|500"
    "reset-password-invalid-token|/users/reset-password/catalog-invalid-token|200"
    "confirm|/users/confirm|200"
  )
  CATALOG_FAIL=0
  for entry in "${CATALOG_PAGES[@]}"; do
    slug="${entry%%|*}"
    rest="${entry#*|}"
    page_path="${rest%%|*}"
    expected="${rest#*|}"
    page_file="${CATALOG_RAW_DIR}/pages/${slug}.html"
    code=$(curl -s -o "${page_file}" -w "%{http_code}" \
      "http://localhost:${PORT}${page_path}" || true)
    if [[ "${code}" != "${expected}" ]]; then
      echo "FAIL: catalog page ${slug} (${page_path}) returned ${code}, expected ${expected}"
      CATALOG_FAIL=1
    elif [[ "${expected}" == "200" ]]; then
      echo "OK:   catalog page ${slug} (${page_path}) -> ${code}"
    elif grep -q "CaseClauseError at GET ${page_path}" "${page_file}" \
      && grep -q "ResetPasswordLive.mount/3" "${page_file}"; then
      printf '%s\n' "<!-- catalog: GET ${page_path} answered HTTP ${code} on the generated host (known defect: the request page raises CaseClauseError at mount because the generated route has no live action); the error page is not captured -->" > "${page_file}"
      echo "KNOWN: catalog page ${slug} (${page_path}) -> ${code}, documented defect confirmed, marker written"
    else
      echo "FAIL: catalog page ${slug} (${page_path}) returned ${code} without the documented defect signature"
      CATALOG_FAIL=1
    fi
  done
  if [[ "${CATALOG_FAIL}" -eq 1 ]]; then
    echo "==> admin-acceptance: catalog page capture failed"
    tail -n 200 "${SERVER_LOG}" || true
    exit 1
  fi

  # The generated email builders, called in the host with plain fixed inputs.
  # The capture host's branding sender is overridden in the running VM to a
  # seeded .test address (the installed default is a real-looking domain that
  # the catalog privacy rule correctly rejects); no template, default or
  # fixture changes. Every details map that is read for :time gets an explicit
  # fixed time, so no email carries the wall clock.
  CATALOG_EMAIL_FILE="${TMP_APP_DIR}/sigra_catalog_emails.exs"
  cat > "${CATALOG_EMAIL_FILE}" <<'EOF'
emails_dir = System.fetch_env!("SIGRA_CATALOG_EMAIL_DIR")
emails = Module.concat([System.fetch_env!("SIGRA_CATALOG_EMAILS_MODULE")])
user_module = Module.concat([System.fetch_env!("SIGRA_CATALOG_USER_MODULE")])
otp_app = String.to_atom(System.fetch_env!("SIGRA_CATALOG_OTP_APP"))
sender = "noreply@catalog.example.test"

config = Application.get_env(otp_app, :sigra_config, [])
branding = config |> Keyword.get(:branding, []) |> Keyword.put(:email_from_address, sender)
Application.put_env(otp_app, :sigra_config, Keyword.put(config, :branding, branding))

Code.ensure_loaded!(emails)

base = "https://host.example.test"
fixed_time = ~U[2026-01-01 00:00:00Z]
user = struct(user_module, email: "catalog-user@example.test")

details = %{
  ip: "203.0.113.7",
  geo_city: "Springfield",
  geo_country_code: "US",
  city: "Springfield",
  device: "Example Browser on Example OS",
  time: fixed_time
}

invitation = %{
  email: "catalog-invited@example.test",
  role: :member,
  expires_at: ~U[2099-01-01 00:00:00Z]
}

inviter = %{email: "catalog-inviter@example.test"}

# {slug, builder name, arity, required?, arguments}
builders = [
  {"confirmation", :confirmation_email, 3, true,
   [user, base <> "/users/confirm/catalog-token", "123456"]},
  {"reset-password", :reset_password_email, 2, true,
   [user, base <> "/users/reset-password/catalog-token"]},
  {"magic-link", :magic_link_email, 2, true, [user, base <> "/users/log_in/catalog-token"]},
  {"suspicious-login", :suspicious_login_email, 2, true, [user, details]},
  {"oauth-reset", :oauth_reset_email, 2, false, [user, "GitHub"]},
  {"enterprise-sso-reset", :enterprise_sso_reset_email, 3, false,
   [user, "Example Organization", base <> "/organizations/example/sso"]},
  {"passkey-registration", :passkey_registration_email, 2, false, [user, details]},
  {"lockout-notification", :lockout_notification_email, 2, false, [user, details]},
  {"mfa-enabled", :mfa_enabled_email, 1, false, [user]},
  {"mfa-disabled", :mfa_disabled_email, 1, false, [user]},
  {"backup-code-used", :backup_code_used_email, 2, false, [user, [remaining: 3]]},
  {"mfa-lockout", :mfa_lockout_email, 1, false, [user]},
  # email_change_confirmation_email/3 and email_change_notification_email/3 are left
  # out on purpose: both end a sentence with the new address and a period, which the
  # raw-directory address scan reads as a domain ending `.test.` rather than `.test`.
  {"email-changed", :email_changed_email, 1, false, [user]},
  {"deletion-scheduled", :deletion_scheduled_email, 3, false,
   [user, ~D[2026-02-01], base <> "/users/reactivation/catalog-token"]},
  {"deletion-cancelled", :deletion_cancelled_email, 2, false, [user, base <> "/users/log_in"]},
  {"deletion-finalized", :deletion_finalized_email, 1, false, ["catalog-user@example.test"]},
  {"password-changed", :password_changed_email, 2, false, [user, details]},
  {"organization-invitation", :organization_invitation, 4, false,
   [invitation, %{name: "Example Organization"}, inviter, base <> "/invitations/catalog-token/accept"]}
]

format_recipient = fn
  {name, address} when name in [nil, ""] -> address
  {name, address} -> "#{name} <#{address}>"
  address when is_binary(address) -> address
end

written =
  Enum.flat_map(builders, fn {slug, function, arity, required?, args} ->
    cond do
      not function_exported?(emails, function, arity) and required? ->
        IO.puts(:stderr, "FAIL: required builder #{function}/#{arity} is not exported by #{inspect(emails)}")
        System.halt(1)

      not function_exported?(emails, function, arity) ->
        IO.puts("skip: #{slug} (#{function}/#{arity} is not generated in this host)")
        []

      true ->
        try do
          email = apply(emails, function, args)

          content =
            Enum.join(
              [
                "Subject: #{email.subject}",
                "To: #{Enum.map_join(email.to, ", ", format_recipient)}",
                "From: #{format_recipient.(email.from)}",
                "=== HTML ===",
                email.html_body || "",
                "=== TEXT ===",
                email.text_body || ""
              ],
              "\n"
            ) <> "\n"

          File.write!(Path.join(emails_dir, slug <> ".txt"), content)
          IO.puts("wrote: #{slug}")
          [slug]
        rescue
          error ->
            if required? do
              IO.puts(:stderr, "FAIL: required builder #{function}/#{arity} raised: #{Exception.message(error)}")
              System.halt(1)
            else
              IO.puts("skip: #{slug} (#{function}/#{arity} raised: #{Exception.message(error)})")
              []
            end
        end
    end
  end)

IO.puts("catalog emails written: #{Enum.join(Enum.sort(written), " ")}")
EOF

  # PORT is pinned to the Phoenix default here: the generated builders embed
  # Endpoint.url(), which reads PORT, so without the pin the dumped emails would
  # carry whatever port the caller picked for the booted server. This process
  # starts no server, so the pin binds nothing.
  PORT=4000 \
  SIGRA_CATALOG_EMAIL_DIR="${CATALOG_RAW_DIR}/emails" \
  SIGRA_CATALOG_EMAILS_MODULE="${CONTEXT_MODULE}.Emails" \
  SIGRA_CATALOG_USER_MODULE="${CONTEXT_MODULE}.User" \
  SIGRA_CATALOG_OTP_APP="${APP_NAME}" \
  mix run "${CATALOG_EMAIL_FILE}"

  echo "==> admin-acceptance: catalog raw written to ${CATALOG_RAW_DIR}"
  exit 0
fi

for path in /users/log_in /admin "/admin/organizations/${SIGRA_ALLOWED_ORG_SLUG}"; do
  curl -s -o /dev/null "http://localhost:${PORT}${path}" || true
done

# --- Phase 31 generated-host runtime parity probes --------------------------
# Phase 30 `30-VERIFICATION.md` flagged an open gap: audit routes and CSV
# export were proven in the example app via ExUnit/LiveViewTest but never
# exercised through a booted generated-host app. Phase 31 D-10/D-11/D-17
# closes that gap here with a narrow set of real-HTTP checks. These stay
# intentionally thin: status-only probes for audit explorer and export
# routes, without duplicating the example app's ExUnit matrix.
echo "==> admin-acceptance: probing generated-host audit runtime parity"
GEN_PARITY_FAIL=0

gen_expect_non_5xx() {
  local path="$1"
  local code
  code=$(curl -s -o /dev/null -w "%{http_code}" -L --max-redirs 5 \
    "http://localhost:${PORT}${path}")
  if [[ "${code}" -ge 500 ]]; then
    echo "FAIL: ${path} returned ${code} on generated host"
    GEN_PARITY_FAIL=1
  else
    echo "OK:   ${path} -> ${code}"
  fi
}

# Admin-critical routes must be mounted and reachable on the generated
# host, matching example-app wiring. The original four entries prove
# Phase 30 audit + export reachability; the two `/users` entries prove
# Phase 32 INT-01 closure (UsersIndexLive in global + organization
# live_session blocks). Authorization policy truth stays in ExUnit;
# these checks only prove route shape + no 5xx.
GENERATED_HOST_AUDIT_ROUTES=(
  "/admin/audit"
  "/admin/audit/export.csv"
  "/admin/users"
  "/admin/organizations/${SIGRA_ALLOWED_ORG_SLUG}/audit"
  "/admin/organizations/${SIGRA_ALLOWED_ORG_SLUG}/audit/export.csv"
  "/admin/organizations/${SIGRA_ALLOWED_ORG_SLUG}/users"
)

for path in "${GENERATED_HOST_AUDIT_ROUTES[@]}"; do
  gen_expect_non_5xx "${path}"
done

# Phase 32 INT-02 closure: prove the ImpersonationController template is
# emitted by the installer and reachable as a routed controller module in
# the generated host. `mix compile --warnings-as-errors` does NOT catch
# undefined-module route references (Phoenix resolves controllers at
# dispatch time, not compile time) — so a missing template would produce
# a runtime 500 on POST, not a compile error. This unauthenticated probe
# hits the route with a bogus UUID and asserts the response is NOT 5xx;
# any non-5xx status (302 login redirect, 403, 404, 422) proves the
# controller module loaded and authorization ran. Full authenticated
# impersonation flow stays in Phase 34 Playwright.
echo "==> admin-acceptance: probing generated-host impersonation controller emission (INT-02)"
imp_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
  "http://localhost:${PORT}/admin/users/00000000-0000-0000-0000-000000000000/impersonation")
if [[ "${imp_code}" -ge 500 ]]; then
  echo "FAIL: POST /admin/users/.../impersonation returned ${imp_code} (controller module likely missing — INT-02 regressed)"
  GEN_PARITY_FAIL=1
else
  echo "OK:   POST /admin/users/.../impersonation -> ${imp_code}"
fi

# Per D-12/D-13, also assert one explicit denial-semantic probe: unknown
# organization slug must NOT return a 200 on the generated host, so a
# wiring regression that collapsed unknown-org to global admin would
# fail loudly here rather than silently leak data.
echo "==> admin-acceptance: probing generated-host unknown-org denial semantics"
unknown_org_code=$(curl -s -o /dev/null -w "%{http_code}" \
  "http://localhost:${PORT}/admin/organizations/definitely-not-an-org/audit")
if [[ "${unknown_org_code}" == "200" ]]; then
  echo "FAIL: /admin/organizations/definitely-not-an-org/audit returned 200 on generated host"
  GEN_PARITY_FAIL=1
else
  echo "OK:   /admin/organizations/definitely-not-an-org/audit -> ${unknown_org_code}"
fi

if [[ "${GEN_PARITY_FAIL}" -eq 1 ]]; then
  echo "==> admin-acceptance: generated-host parity probe failed"
  echo "==> admin-acceptance: dumping server log for diagnostics"
  tail -n 200 "${SERVER_LOG}" || true
  exit 1
fi

case "${TEST_TARGET}" in
  all)
    PLAYWRIGHT_ARGS=("${PLAYWRIGHT_SPEC}")
    RUN_CONFIRMATION=true
    ;;
  chrome)
    PLAYWRIGHT_ARGS=("${PLAYWRIGHT_SPEC}" "-g" "generated host admin shell renders on desktop and mobile")
    ;;
  auth)
    PLAYWRIGHT_ARGS=(
      "${PLAYWRIGHT_SPEC}"
      "-g"
      "generated auth shell communicates hierarchy"
    )
    ;;
  errors)
    PLAYWRIGHT_ARGS=("${PLAYWRIGHT_SPEC}" "-g" "generated host admin denial responses show explicit copy")
    ;;
  audit-export)
    PLAYWRIGHT_ARGS=(
      "${PLAYWRIGHT_SPEC}"
      "-g"
      "VFY-01 generated host audit CSV export"
    )
    ;;
  impersonation-controller)
    PLAYWRIGHT_ARGS=(
      "${PLAYWRIGHT_SPEC}"
      "-g"
      "VFY-01 generated host impersonation start"
    )
    ;;
  confirmation)
    PLAYWRIGHT_ARGS=(
      --project=generated-host-chromium
      tests/generated-confirmation.spec.ts
    )
    RUN_CONFIRMATION=false
    PLAYWRIGHT_OUTPUT="test-results/generated-confirmation"
    ;;
  *)
    echo "unknown --test target: ${TEST_TARGET}" >&2
    exit 1
    ;;
esac

echo "==> admin-acceptance: running Playwright target ${TEST_TARGET}"
(
  cd "${PLAYWRIGHT_DIR}"
  CI=true \
  SIGRA_EXAMPLE_URL="http://localhost:${PORT}" \
  npx playwright test --output "${PLAYWRIGHT_OUTPUT}" "${PLAYWRIGHT_ARGS[@]}"
)

if [[ "${RUN_CONFIRMATION:-false}" == "true" ]]; then
  echo "==> admin-acceptance: running generated confirmation Chromium journey"
  (
    cd "${PLAYWRIGHT_DIR}"
    CI=true \
    SIGRA_EXAMPLE_URL="http://localhost:${PORT}" \
    npx playwright test \
      --project=generated-host-chromium \
      --output test-results/generated-confirmation \
      tests/generated-confirmation.spec.ts
  )
fi

echo "==> admin-acceptance: revoking platform admin and proving deny-on-next-check"
if [[ "${TEST_TARGET}" != "confirmation" ]]; then
mix sigra.admin.revoke --email "${SIGRA_PLATFORM_ADMIN_EMAIL}" --yes

if mix sigra.admin.check --email "${SIGRA_PLATFORM_ADMIN_EMAIL}"; then
  echo "FAIL: revoked account still passes sigra.admin.check" >&2
  exit 1
else
  echo "OK:   generated check task denies the revoked grant"
fi

(
  cd "${PLAYWRIGHT_DIR}"
  CI=true \
  SIGRA_EXPECT_PLATFORM_DENIED=1 \
  SIGRA_EXAMPLE_URL="http://localhost:${PORT}" \
npx playwright test \
    --output test-results/revocation \
    "${PLAYWRIGHT_SPEC}" \
    -g "revoked platform admin is denied"
)
fi

echo "==> admin-acceptance: success"
