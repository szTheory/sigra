#!/usr/bin/env bash
set -euo pipefail

PACKAGE="sigra"
VERSION=""
TAG=""
REPOSITORY="sztheory/sigra"
EVIDENCE_FILE="release-post-publish-evidence.json"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-36}"
WAIT_SECONDS="${WAIT_SECONDS:-10}"

usage() {
  cat <<'EOF'
Usage: release-post-publish-verify.sh --version <version> --tag <tag> [options]

Options:
  --package <name>       Hex package name (default: sigra)
  --repository <owner/repo>
                         GitHub repository used by HexDocs source links
                         (default: sztheory/sigra)
  --evidence-file <path> JSON evidence output path
  --max-attempts <n>     Retry attempts for external propagation
  --wait-seconds <n>     Sleep between attempts
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --package)
      PACKAGE="$2"
      shift 2
      ;;
    --version)
      VERSION="$2"
      shift 2
      ;;
    --tag)
      TAG="$2"
      shift 2
      ;;
    --repository)
      REPOSITORY="$2"
      shift 2
      ;;
    --evidence-file)
      EVIDENCE_FILE="$2"
      shift 2
      ;;
    --max-attempts)
      MAX_ATTEMPTS="$2"
      shift 2
      ;;
    --wait-seconds)
      WAIT_SECONDS="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$VERSION" || -z "$TAG" ]]; then
  echo "--version and --tag are required" >&2
  usage >&2
  exit 2
fi

if [[ "$TAG" != "v${VERSION}" ]]; then
  echo "tag/version mismatch: tag=${TAG} expected=v${VERSION}" >&2
  exit 1
fi

HEX_RELEASE_URL="https://hex.pm/api/packages/${PACKAGE}/releases/${VERSION}"
HEXDOCS_BASE_URL="https://hexdocs.pm/${PACKAGE}/${VERSION}"
SOURCE_LINK_NEEDLE="github.com/${REPOSITORY}/blob/${TAG}/"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

write_evidence() {
  local status="$1"
  local reason="${2:-}"
  cat >"$EVIDENCE_FILE" <<EOF
{
  "status": "${status}",
  "reason": "${reason}",
  "package": "${PACKAGE}",
  "version": "${VERSION}",
  "tag": "${TAG}",
  "hex_release_url": "${HEX_RELEASE_URL}",
  "hexdocs_base_url": "${HEXDOCS_BASE_URL}",
  "source_link_needle": "${SOURCE_LINK_NEEDLE}",
  "verified_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
}

for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
  echo "Checking Hex release ${PACKAGE} ${VERSION} (${attempt}/${MAX_ATTEMPTS})..."
  if curl -fsS "$HEX_RELEASE_URL" -o "$TMP_DIR/hex-release.json" &&
    grep -q "\"version\"[[:space:]]*:[[:space:]]*\"${VERSION}\"" "$TMP_DIR/hex-release.json"; then
    echo "Hex.pm lists ${PACKAGE} ${VERSION}: ${HEX_RELEASE_URL}"
    break
  fi

  if [[ "$attempt" -eq "$MAX_ATTEMPTS" ]]; then
    write_evidence "failed" "hex_release_not_visible"
    echo "Timed out waiting for ${HEX_RELEASE_URL}" >&2
    exit 1
  fi

  sleep "$WAIT_SECONDS"
done

DOC_CANDIDATES=(
  "${HEXDOCS_BASE_URL}/"
  "${HEXDOCS_BASE_URL}/readme.html"
  "${HEXDOCS_BASE_URL}/Sigra.html"
)

for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
  echo "Checking HexDocs and source links (${attempt}/${MAX_ATTEMPTS})..."

  for url in "${DOC_CANDIDATES[@]}"; do
    safe_name="$(echo "$url" | tr -c 'A-Za-z0-9' '_')"
    html_file="${TMP_DIR}/${safe_name}.html"

    if ! curl -fsSL "$url" -o "$html_file"; then
      continue
    fi

    if grep -q "$SOURCE_LINK_NEEDLE" "$html_file"; then
      echo "HexDocs source link resolves to ${TAG}: ${url}"
      write_evidence "passed" ""
      exit 0
    fi

    if grep -q "github.com/${REPOSITORY}/blob/main/" "$html_file"; then
      write_evidence "failed" "hexdocs_source_link_points_to_main"
      echo "HexDocs source link points to main instead of ${TAG}: ${url}" >&2
      exit 1
    fi
  done

  if [[ "$attempt" -eq "$MAX_ATTEMPTS" ]]; then
    write_evidence "failed" "hexdocs_source_link_not_found"
    echo "Timed out waiting for HexDocs source link containing ${SOURCE_LINK_NEEDLE}" >&2
    exit 1
  fi

  sleep "$WAIT_SECONDS"
done
