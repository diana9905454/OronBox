#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
RELEASE_DIR="${PROJECT_ROOT}/build/release"
DEV_MODE="false"
SKIP_CLEAN_CHECK="false"
VERSION=""
GIT_HASH=""
BUILD_USER=""

APP_NAME="oronbox"
PACKAGE_NAME="org.zxor.oronbox"
DESCRIPTION="A pretty fast wearable management tool for VelaOS and ZeppOS built with Flutter."
MAINTAINER="OronBox Team"
LICENSE="AGPL-3.0"
HOMEPAGE="https://github.com/zxor-org/OronBox"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
  echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $*" >&2
}

print_common_help() {
  cat <<EOF
Usage: $1 [options]

Options:
  --dev       Allow a dirty worktree and append git metadata to the package version
  --skip-clean-check
              Skip the clean-worktree check when repackaging an existing build
  -h, --help  Show this help
EOF
}

parse_common_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dev)
        DEV_MODE="true"
        shift
        ;;
      --skip-clean-check)
        SKIP_CLEAN_CHECK="true"
        shift
        ;;
      -h|--help)
        print_common_help "$(basename "$0")"
        exit 0
        ;;
      *)
        log_error "Unknown option: $1"
        print_common_help "$(basename "$0")" >&2
        exit 1
        ;;
    esac
  done
}

get_version() {
  awk -F'[:+]' '/^version:/ { gsub(/[[:space:]]/, "", $2); print $2; exit }' \
    "${PROJECT_ROOT}/pubspec.yaml"
}

get_build_number() {
  awk -F'+' '/^version:/ { gsub(/[[:space:]]/, "", $2); print $2; exit }' \
    "${PROJECT_ROOT}/pubspec.yaml"
}

get_git_hash() {
  git -C "${PROJECT_ROOT}" rev-parse --short=7 HEAD 2>/dev/null || echo "nogit"
}

get_build_user() {
  if command -v id >/dev/null 2>&1; then
    id -un
  elif [[ -n "${USER:-}" ]]; then
    echo "${USER}"
  elif [[ -n "${USERNAME:-}" ]]; then
    echo "${USERNAME}"
  else
    echo "unknown"
  fi
}

is_git_dirty() {
  git -C "${PROJECT_ROOT}" update-index --refresh >/dev/null 2>&1 || true
  ! git -C "${PROJECT_ROOT}" diff-index --quiet HEAD -- 2>/dev/null || \
    [ -n "$(git -C "${PROJECT_ROOT}" ls-files --others --exclude-standard)" ]
}

check_clean_tree() {
  if is_git_dirty; then
    log_error "Git working tree is dirty. Commit or stash changes first, or use --dev."
    exit 1
  fi
}

compute_version() {
  local dev_mode="${1:-false}"
  local version
  version="$(get_version)"
  if [[ -z "${version}" ]]; then
    log_error "Could not read version from pubspec.yaml"
    exit 1
  fi

  if [[ "${dev_mode}" == "true" ]]; then
    local suffix="dev.${GIT_HASH:-$(get_git_hash)}"
    if is_git_dirty; then
      suffix="${suffix}.dirty"
    fi
    version="${version}-${suffix}"
  else
    if [[ "${SKIP_CLEAN_CHECK}" != "true" ]]; then
      check_clean_tree
    fi
  fi

  echo "${version}"
}

# Debian forbids '-' in the upstream version; '~' sorts a prerelease before
# the release it precedes (1.0.0~rc.1 < 1.0.0).
deb_upstream_version() {
  echo "${1//-/'~'}"
}

# RPM forbids '-' in Version; prereleases go into Release as 0.1.<pre>
# (Fedora convention) so 1.0.0-0.1.rc.1 < 1.0.0-1.
rpm_version_release() {
  local base="${1%%-*}"
  local pre=""
  [[ "$1" == *-* ]] && pre="${1#*-}"
  if [[ -n "${pre}" ]]; then
    echo "${base} 0.1.${pre//-/.}"
  else
    echo "${base} 1"
  fi
}

# pacman pkgver forbids '-'; alphabetic segments sort before numeric ones in
# vercmp, so dotted prereleases order correctly (1.0.0.rc.1 < 1.0.0).
arch_pkgver() {
  echo "${1//-/.}"
}

init_build_metadata() {
  parse_common_args "$@"
  GIT_HASH="$(get_git_hash)"
  BUILD_USER="$(get_build_user)"
  VERSION="$(compute_version "${DEV_MODE}")"
}

init_build() {
  init_build_metadata "$@"
  setup_build_integrity
}

ensure_release_dir() {
  mkdir -p "${RELEASE_DIR}"
}

clean_release_dir() {
  rm -rf "${RELEASE_DIR}"
  mkdir -p "${RELEASE_DIR}"
}

require_command() {
  if ! command -v "$1" &>/dev/null; then
    log_error "Required command not found: $1"
    exit 1
  fi
}

require_flutter() {
  if command -v flutter &>/dev/null; then
    return 0
  fi
  if command -v fvm &>/dev/null || [[ -x "/opt/homebrew/bin/fvm" ]]; then
    return 0
  fi
  log_error "Required command not found: flutter or fvm"
  exit 1
}

setup_build_integrity() {
  require_command python3
  python3 "${SCRIPT_DIR}/prepare_build_integrity.py" \
    --project-root "${PROJECT_ROOT}" \
    --version "${VERSION}" \
    --commit "$(git -C "${PROJECT_ROOT}" rev-parse HEAD)"
}

flutter_release_defines() {
  echo "--dart-define=APP_VERSION=${VERSION}"
  echo "--dart-define=GIT_COMMIT_HASH=${GIT_HASH}"
  echo "--dart-define=BUILD_USER=${BUILD_USER}"
  echo "--dart-define-from-file=${PROJECT_ROOT}/build/integrity_defines.json"
}

build_number_or_default() {
  local build_number
  build_number="$(get_build_number)"
  if [[ -n "${build_number}" ]]; then
    if [[ ! "${build_number}" =~ ^[1-9][0-9]*$ ]]; then
      log_error "pubspec.yaml contains an invalid Android build number: ${build_number}"
      exit 1
    fi
    echo "${build_number}"
    return
  fi

  # Keep source builds without +N usable while releases validate +N before
  # invoking the platform build jobs.
  if git -C "${PROJECT_ROOT}" rev-parse --git-dir >/dev/null 2>&1; then
    git -C "${PROJECT_ROOT}" rev-list --count HEAD
    return
  fi
  echo "1"
}

run_cmd() {
  log_info "Running: $*"
  if [[ "$1" == "flutter" ]] && ! command -v flutter &>/dev/null; then
    if command -v fvm &>/dev/null; then
      shift
      fvm flutter "$@"
      return
    elif [[ -x "/opt/homebrew/bin/fvm" ]]; then
      shift
      /opt/homebrew/bin/fvm flutter "$@"
      return
    fi
  fi
  "$@"
}

retry_cmd() {
  local attempts="${ORONBOX_RETRY_ATTEMPTS:-3}"
  local delay="${ORONBOX_RETRY_DELAY_SECONDS:-10}"
  local attempt=1

  while true; do
    if "$@"; then
      return 0
    fi
    if [[ "${attempt}" -ge "${attempts}" ]]; then
      return 1
    fi
    log_warn "Attempt ${attempt}/${attempts} failed; retrying in $((delay * attempt))s: $*"
    sleep "$((delay * attempt))"
    attempt=$((attempt + 1))
  done
}

host_os() {
  case "$(uname -s)" in
    Darwin*) echo "macos" ;;
    Linux*) echo "linux" ;;
    MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
    *) echo "unknown" ;;
  esac
}

archive_zip() {
  local src="$1"
  local dst="$2"
  local parent
  local name
  parent="$(dirname "${src}")"
  name="$(basename "${src}")"
  rm -f "${dst}"
  (
    cd "${parent}"
    zip -qry "${dst}" "${name}"
  )
  log_info "Produced ${dst}"
}

setup_android_signing() {
  local props_file="${PROJECT_ROOT}/android/key.properties"

  if [[ -f "${props_file}" ]]; then
    log_info "Found existing ${props_file}; using existing Android release signing config."
    return 0
  fi

  if [[ -z "${ORONBOX_KEYSTORE_PATH:-}" ]]; then
    log_warn "Neither android/key.properties nor ORONBOX_KEYSTORE_PATH was found; Android build will use the debug signing config."
    log_warn "Set ORONBOX_KEYSTORE_PATH, ORONBOX_KEYSTORE_PASSWORD, ORONBOX_KEY_ALIAS, and ORONBOX_KEY_PASSWORD or provide android/key.properties for release signing."
    return 0
  fi

  if [[ ! -f "${ORONBOX_KEYSTORE_PATH}" ]]; then
    log_error "Keystore file not found: ${ORONBOX_KEYSTORE_PATH}"
    exit 1
  fi

  if [[ -z "${ORONBOX_KEYSTORE_PASSWORD:-}" || -z "${ORONBOX_KEY_ALIAS:-}" || -z "${ORONBOX_KEY_PASSWORD:-}" ]]; then
    log_error "When ORONBOX_KEYSTORE_PATH is set, ORONBOX_KEYSTORE_PASSWORD, ORONBOX_KEY_ALIAS, and ORONBOX_KEY_PASSWORD must also be set."
    exit 1
  fi

  log_info "Configuring Android release signing..."
  cat > "${props_file}" <<EOF
storePassword=${ORONBOX_KEYSTORE_PASSWORD}
keyPassword=${ORONBOX_KEY_PASSWORD}
keyAlias=${ORONBOX_KEY_ALIAS}
storeFile=${ORONBOX_KEYSTORE_PATH}
EOF

  log_info "Wrote ${props_file}"
}

generate_checksums() {
  local dir="$1"
  local checksum_file="${dir}/sha256sums.txt"

  rm -f "${checksum_file}"
  (
    cd "${dir}"
    find . -maxdepth 1 -type f ! -name "$(basename "${checksum_file}")" \
      -printf '%f\0' | sort -z | xargs -0 sha256sum -- >"${checksum_file}"
  )

  log_info "Wrote ${checksum_file}"
}

copy_artifact() {
  local src="$1"
  local dst="$2"

  if [[ ! -f "${src}" ]]; then
    log_error "Expected artifact not found: ${src}"
    exit 1
  fi

  cp "${src}" "${dst}"
  log_info "Produced ${dst}"
}

archive_symbols_if_present() {
  local src="$1"
  local dst="$2"

  if [[ ! -d "${src}" ]]; then
    log_warn "Symbols directory not found; skipped symbols package: ${src}"
    return 0
  fi

  rm -f "${dst}"
  (
    cd "$(dirname "${src}")"
    tar czf "${dst}" "$(basename "${src}")"
  )
  log_info "Produced ${dst}"
}
