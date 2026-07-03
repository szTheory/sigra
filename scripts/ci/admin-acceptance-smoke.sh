#!/usr/bin/env bash
# scripts/ci/admin-acceptance-smoke.sh
#
# Scaffolds a fresh Phoenix app, installs Sigra, patches in a deterministic
# admin policy + seed data, boots the generated host, and runs the focused
# Phase 27 Playwright acceptance smoke against the generated admin routes.
#
# Local reproduction:
#   GITHUB_WORKSPACE=$(pwd) scripts/ci/admin-acceptance-smoke.sh
#   GITHUB_WORKSPACE=$(pwd) scripts/ci/admin-acceptance-smoke.sh --test chrome
#   GITHUB_WORKSPACE=$(pwd) scripts/ci/admin-acceptance-smoke.sh --test errors
#   GITHUB_WORKSPACE=$(pwd) scripts/ci/admin-acceptance-smoke.sh --test audit-export
#   GITHUB_WORKSPACE=$(pwd) scripts/ci/admin-acceptance-smoke.sh --test impersonation-controller
#
# Every --test target (including slices above) runs the bash HTTP parity probes
# first, then the filtered or full Playwright suite — probes are never skipped.

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

echo "==> admin-acceptance: patching generated admin policy"
cat > "lib/${APP_NAME}/sigra_admin_policy.ex" <<'EOF'
defmodule SigraAdminSmoke.SigraAdminPolicy do
  @moduledoc """
  Deterministic admin policy used by the generated-host acceptance smoke.
  """

  @behaviour Sigra.Admin.Policy

  import Ecto.Query, only: [from: 2]

  alias SigraAdminSmoke.Accounts.OrganizationMembership
  alias SigraAdminSmoke.Repo

  @platform_admin_email System.get_env("SIGRA_PLATFORM_ADMIN_EMAIL", "platform-admin@example.test")
  @org_admin_email System.get_env("SIGRA_ORG_ADMIN_EMAIL", "org-admin@example.test")

  @impl true
  def platform_admin?(%{user: %{email: email}}) when is_binary(email), do: email == @platform_admin_email
  def platform_admin?(_scope), do: false

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
    ;;
  chrome)
    PLAYWRIGHT_ARGS=("${PLAYWRIGHT_SPEC}" "-g" "generated host admin shell renders on desktop and mobile")
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
  npx playwright test "${PLAYWRIGHT_ARGS[@]}"
)

echo "==> admin-acceptance: success"
