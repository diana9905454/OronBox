#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/build_common.sh"

FORMAT="all"
SKIP_BUILD="false"
case "$(uname -m)" in
  aarch64|arm64) ABI="aarch64" ;;
  *) ABI="x86_64" ;;
esac
COMMON_ARGS=()

print_help() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --format <fmt>  Only build the given package format:
                  tar.gz, deb, rpm, arch, appimage, flatpak, all (default: all)
  --abi <abi>     Target architecture: x86_64, aarch64 (default: host)
                  Cross-building aarch64 from x86_64 requires an arm64 sysroot
                  in ORONBOX_LINUX_ARM64_SYSROOT, and only produces tar.gz,
                  deb, rpm and arch packages
  --skip-build    Reuse the existing release bundle instead of running
                  "flutter build linux" (useful when repackaging)
  --dev           Allow a dirty worktree and append git metadata to the package version
  --skip-clean-check
                  Skip the clean-worktree check when repackaging an existing build
  -h, --help      Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --format)
      FORMAT="${2:?--format requires a value}"
      shift 2
      ;;
    --format=*)
      FORMAT="${1#*=}"
      shift
      ;;
    --abi)
      ABI="${2:?--abi requires a value}"
      shift 2
      ;;
    --abi=*)
      ABI="${1#*=}"
      shift
      ;;
    --skip-build)
      SKIP_BUILD="true"
      shift
      ;;
    -h|--help)
      print_help
      exit 0
      ;;
    *)
      COMMON_ARGS+=("$1")
      shift
      ;;
  esac
done

case "${FORMAT}" in
  tar.gz|deb|rpm|arch|appimage|flatpak|all) ;;
  *)
    log_error "Unknown format: ${FORMAT} (expected tar.gz, deb, rpm, arch, appimage, flatpak or all)"
    exit 1
    ;;
esac

HOST_ARCH="$(uname -m)"
case "${ABI}" in
  x86_64)
    FLUTTER_PLATFORM="linux-x64"
    BUNDLE_ARCH_DIR="x64"
    GENERIC_ARCH="amd64"
    DEB_ARCH="amd64"
    RPM_ARCH="x86_64"
    ;;
  aarch64)
    FLUTTER_PLATFORM="linux-arm64"
    BUNDLE_ARCH_DIR="arm64"
    GENERIC_ARCH="arm64"
    DEB_ARCH="arm64"
    RPM_ARCH="aarch64"
    ;;
  *)
    log_error "Unknown ABI: ${ABI} (expected x86_64 or aarch64)"
    exit 1
    ;;
esac

# flutter_soloud bundles x86_64 Xiph libraries only; ARM64 must use the
# architecture-matched system libraries instead.
if [[ "${ABI}" == "aarch64" ]]; then
  export TRY_SYSTEM_LIBS_FIRST="${TRY_SYSTEM_LIBS_FIRST:-1}"
fi

CROSS="false"
TARGET_ARGS=(--target-platform="${FLUTTER_PLATFORM}")
STRIP_CMD="strip"
if [[ "${HOST_ARCH}" == "x86_64" && "${ABI}" == "aarch64" ]]; then
  CROSS="true"
  if [[ -z "${ORONBOX_LINUX_ARM64_SYSROOT:-}" ]]; then
    log_error "Cross-building aarch64 requires ORONBOX_LINUX_ARM64_SYSROOT to point at an arm64 sysroot."
    exit 1
  fi
  TARGET_ARGS+=(--target-sysroot="${ORONBOX_LINUX_ARM64_SYSROOT}")
  if command -v aarch64-linux-gnu-strip >/dev/null 2>&1; then
    STRIP_CMD="aarch64-linux-gnu-strip"
  else
    log_warn "aarch64-linux-gnu-strip not found; binaries will not be stripped"
    STRIP_CMD="true"
  fi
elif [[ "${HOST_ARCH}" == "aarch64" && "${ABI}" == "x86_64" ]]; then
  log_error "Cross-building x86_64 from an aarch64 host is not supported."
  exit 1
fi

init_build_metadata "${COMMON_ARGS[@]}"
log_info "Building Linux release packages for version ${VERSION} (format=${FORMAT}, abi=${ABI})"

require_command tar
ensure_release_dir

if [[ "${SKIP_BUILD}" == "true" ]]; then
  log_info "Skipping Flutter build, reusing the existing release bundle"
else
  setup_build_integrity
  require_flutter
  DART_DEFINES=()
  while IFS= read -r define; do
    DART_DEFINES+=("${define}")
  done < <(flutter_release_defines)

  run_cmd flutter build linux \
    --release \
    --obfuscate \
    --split-debug-info=symbols/linux \
    "${TARGET_ARGS[@]}" \
    "${DART_DEFINES[@]}"
fi

BUNDLE_DIR="${PROJECT_ROOT}/build/linux/${BUNDLE_ARCH_DIR}/release/bundle"
SYMBOLS_DIR="${PROJECT_ROOT}/symbols/linux"
if [[ ! -d "${BUNDLE_DIR}" ]]; then
  log_error "Linux build bundle not found: ${BUNDLE_DIR}"
  exit 1
fi

if [[ "${FORMAT}" == "tar.gz" || "${FORMAT}" == "all" ]]; then
  TAR_DST="${RELEASE_DIR}/${APP_NAME}-${VERSION}-linux-${GENERIC_ARCH}.tar.gz"
  rm -f "${TAR_DST}"
  (
    cd "$(dirname "${BUNDLE_DIR}")"
    tar czf "${TAR_DST}" "$(basename "${BUNDLE_DIR}")"
  )
  log_info "Produced ${TAR_DST}"

  archive_symbols_if_present \
    "${SYMBOLS_DIR}" \
    "${RELEASE_DIR}/${APP_NAME}-${VERSION}-linux-${GENERIC_ARCH}.symbols.tar.gz"
fi

STAGING_ROOT="${PROJECT_ROOT}/build/linux_staging"
INSTALL_PREFIX="/opt/${APP_NAME}"
DESKTOP_FILE="${PACKAGE_NAME}.desktop"
rm -rf "${STAGING_ROOT}"
mkdir -p "${STAGING_ROOT}"

prepare_desktop_file() {
  local dst="$1"
  local exec_path="${2:-${INSTALL_PREFIX}/oronbox}"
  mkdir -p "$(dirname "${dst}")"
  cp "${PROJECT_ROOT}/linux/${DESKTOP_FILE}.in" "${dst}"
  sed -i "s|@CMAKE_INSTALL_PREFIX@/oronbox|${exec_path}|g" "${dst}"
}

copy_bundle_to() {
  local root="$1"
  mkdir -p "${root}${INSTALL_PREFIX}"
  cp -a "${BUNDLE_DIR}/." "${root}${INSTALL_PREFIX}/"
  chmod +x "${root}${INSTALL_PREFIX}/${APP_NAME}"
  find "${root}${INSTALL_PREFIX}" -type f \( -name '*.so' -o -name "${APP_NAME}" \) \
    -exec "${STRIP_CMD}" --strip-unneeded {} \; 2>/dev/null || true
}

copy_system_icons_to() {
  local root="$1"
  mkdir -p "${root}/usr/share/icons"
  cp -a "${PROJECT_ROOT}/linux/icons/hicolor" "${root}/usr/share/icons/"
}

copy_mime_definitions_to() {
  local root="$1"
  mkdir -p "${root}/usr/share/mime/packages"
  cp "${PROJECT_ROOT}/linux/org.zxor.oronbox.xml" \
    "${root}/usr/share/mime/packages/"
}

build_deb() {
  if ! command -v dpkg-deb >/dev/null 2>&1; then
    log_warn "dpkg-deb not found; skipped DEB package"
    return 0
  fi

  local deb_root="${STAGING_ROOT}/deb"
  rm -rf "${deb_root}"
  copy_bundle_to "${deb_root}"
  prepare_desktop_file "${deb_root}/usr/share/applications/${DESKTOP_FILE}"
  copy_system_icons_to "${deb_root}"
  copy_mime_definitions_to "${deb_root}"
  mkdir -p "${deb_root}/DEBIAN"

  local deb_version
  deb_version="$(deb_upstream_version "${VERSION}")-1"
  local deb_audio_depends=""
  if [[ "${ABI}" == "aarch64" ]]; then
    deb_audio_depends=", libflac12 | libflac12t64, libogg0, libopus0, libvorbis0a, libvorbisfile3"
  fi
  cat > "${deb_root}/DEBIAN/control" <<EOF
Package: ${APP_NAME}
Version: ${deb_version}
Section: utils
Priority: optional
Architecture: ${DEB_ARCH}
Depends: libsecret-1-0, libgtk-3-0, libblkid1, liblzma5, libasound2 | libasound2t64${deb_audio_depends}, libwebkit2gtk-4.1-0, bluez
Maintainer: ${MAINTAINER}
Description: ${DESCRIPTION}
EOF

  local deb_out="${RELEASE_DIR}/${APP_NAME}_${deb_version}_${DEB_ARCH}.deb"
  rm -f "${deb_out}"
  cat > "${deb_root}/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e
if command -v update-mime-database >/dev/null 2>&1; then
  update-mime-database /usr/share/mime >/dev/null 2>&1 || true
fi
exit 0
EOF
  chmod 755 "${deb_root}/DEBIAN/postinst"
  run_cmd dpkg-deb --root-owner-group --build "${deb_root}" "${deb_out}"
  log_info "Produced ${deb_out}"
}

build_rpm() {
  if ! command -v rpmbuild >/dev/null 2>&1; then
    log_warn "rpmbuild not found; skipped RPM package"
    return 0
  fi

  local rpm_top="${STAGING_ROOT}/rpm"
  local rpm_version rpm_release
  read -r rpm_version rpm_release <<< "$(rpm_version_release "${VERSION}")"
  local rpm_audio_requires=""
  if [[ "${ABI}" == "aarch64" ]]; then
    rpm_audio_requires=$'Requires:       flac-libs\nRequires:       libogg\nRequires:       opus\nRequires:       libvorbis'
  fi
  rm -rf "${rpm_top}"
  mkdir -p "${rpm_top}"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
  mkdir -p "${rpm_top}/rpmdb"
  prepare_desktop_file "${STAGING_ROOT}/rpm-desktop/${DESKTOP_FILE}"

  cat > "${rpm_top}/SPECS/${APP_NAME}.spec" <<EOF
Name:           ${APP_NAME}
Version:        ${rpm_version}
Release:        ${rpm_release}%{?dist}
Summary:        ${DESCRIPTION}
License:        ${LICENSE}
URL:            ${HOMEPAGE}
BuildArch:      ${RPM_ARCH}
Requires:       libsecret
Requires:       alsa-lib
${rpm_audio_requires}

%description
${DESCRIPTION}

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}${INSTALL_PREFIX}
cp -a ${BUNDLE_DIR}/* %{buildroot}${INSTALL_PREFIX}/
mkdir -p %{buildroot}/usr/share/applications
cp ${STAGING_ROOT}/rpm-desktop/${DESKTOP_FILE} %{buildroot}/usr/share/applications/
mkdir -p %{buildroot}/usr/share/icons
cp -a ${PROJECT_ROOT}/linux/icons/hicolor %{buildroot}/usr/share/icons/
mkdir -p %{buildroot}/usr/share/mime/packages
cp ${PROJECT_ROOT}/linux/org.zxor.oronbox.xml %{buildroot}/usr/share/mime/packages/

%post
if command -v update-mime-database >/dev/null 2>&1; then
  update-mime-database /usr/share/mime >/dev/null 2>&1 || true
fi
exit 0

%files
${INSTALL_PREFIX}
/usr/share/applications/${DESKTOP_FILE}
/usr/share/icons/hicolor
/usr/share/mime/packages/org.zxor.oronbox.xml

%changelog
* $(LC_ALL=C date +"%a %b %d %Y") ${MAINTAINER} - ${rpm_version}-${rpm_release}
- Package release
EOF

  run_cmd rpmbuild \
    --define "_topdir ${rpm_top}" \
    --define "_dbpath ${rpm_top}/rpmdb" \
    -bb "${rpm_top}/SPECS/${APP_NAME}.spec"
  local rpm_src
  rpm_src="$(find "${rpm_top}/RPMS" -name '*.rpm' | head -n 1)"
  if [[ -z "${rpm_src}" ]]; then
    log_error "RPM build failed: no .rpm file produced"
    exit 1
  fi
  copy_artifact "${rpm_src}" "${RELEASE_DIR}/${APP_NAME}-${rpm_version}-${rpm_release}.${RPM_ARCH}.rpm"
}

build_arch() {
  if ! command -v makepkg >/dev/null 2>&1; then
    log_warn "makepkg not found; skipped Arch package"
    return 0
  fi

  local arch_root="${STAGING_ROOT}/arch"
  local arch_pkgext=".pkg.tar.zst"
  local arch_audio_deps="'alsa-lib'"
  if [[ "${ABI}" == "aarch64" ]]; then
    arch_audio_deps="${arch_audio_deps} 'flac' 'libogg' 'opus' 'libvorbis'"
  fi
  rm -rf "${arch_root}"
  mkdir -p "${arch_root}"
  prepare_desktop_file "${STAGING_ROOT}/arch-desktop/${DESKTOP_FILE}"

  cat > "${arch_root}/PKGBUILD" <<EOF
# Maintainer: ${MAINTAINER}
pkgname=${APP_NAME}
pkgver=$(arch_pkgver "${VERSION}")
pkgrel=1
pkgdesc="${DESCRIPTION}"
arch=('${RPM_ARCH}')
url="${HOMEPAGE}"
license=('${LICENSE}')
depends=('libsecret' 'gtk3' 'libblockdev' 'xz' ${arch_audio_deps} 'webkit2gtk-4.1' 'bluez')
options=('!debug')
source=()

package() {
  mkdir -p "\${pkgdir}${INSTALL_PREFIX}"
  cp -a --no-preserve=ownership "${BUNDLE_DIR}"/* "\${pkgdir}${INSTALL_PREFIX}/"
  mkdir -p "\${pkgdir}/usr/share/applications"
  cp "${STAGING_ROOT}/arch-desktop/${DESKTOP_FILE}" "\${pkgdir}/usr/share/applications/"
  mkdir -p "\${pkgdir}/usr/share/icons"
  cp -a --no-preserve=ownership "${PROJECT_ROOT}/linux/icons/hicolor" "\${pkgdir}/usr/share/icons/"
  mkdir -p "\${pkgdir}/usr/share/mime/packages"
  cp "${PROJECT_ROOT}/linux/org.zxor.oronbox.xml" "\${pkgdir}/usr/share/mime/packages/"
}

post_install() {
  if command -v update-mime-database >/dev/null 2>&1; then
    update-mime-database /usr/share/mime >/dev/null 2>&1 || true
  fi
}
EOF

  local arch_package_list
  arch_package_list="$(
    cd "${arch_root}"
    makepkg --packagelist --nodeps "PKGDEST=${arch_root}" "PKGEXT=${arch_pkgext}"
  )"
  if [[ -z "${arch_package_list}" ]]; then
    log_error "Arch package build failed: makepkg did not report an output path"
    exit 1
  fi
  log_info "Expected Arch package path(s): ${arch_package_list//$'\n'/ }"

  (
    cd "${arch_root}"
    # Arch Linux ARM may override PKGDEST in makepkg.conf; keep the artifact
    # in our staging directory so the caller can collect it deterministically.
    # The bundle is already built; runtime dependencies belong in package
    # metadata and do not need to be installed in the packaging container.
    run_cmd makepkg -f --skipchecksums --nodeps "PKGDEST=${arch_root}" "PKGEXT=${arch_pkgext}"
  )

  local arch_src=""
  while IFS= read -r candidate; do
    if [[ -f "${candidate}" ]]; then
      arch_src="${candidate}"
      break
    fi
  done <<< "${arch_package_list}"
  if [[ -z "${arch_src}" ]]; then
    log_error "Arch package build completed but the expected package was not found"
    log_error "Files under staging:"
    find "${arch_root}" -maxdepth 2 -type f -name '*.pkg.tar*' -print >&2 || true
    exit 1
  fi
  local arch_suffix="${arch_src##*.pkg.tar}"
  if [[ "${arch_suffix}" == "${arch_src}" ]]; then
    arch_suffix=".zst"
  fi
  copy_artifact "${arch_src}" "${RELEASE_DIR}/${APP_NAME}-$(arch_pkgver "${VERSION}")-1-${RPM_ARCH}.pkg.tar${arch_suffix}"
}

build_appimage() {
  if [[ "${CROSS}" == "true" ]]; then
    log_warn "AppImage tools cannot cross-package aarch64 from ${HOST_ARCH}; skipped AppImage package"
    return 0
  fi
  local tool=""
  if command -v linuxdeploy >/dev/null 2>&1; then
    tool="linuxdeploy"
  elif command -v appimagetool >/dev/null 2>&1; then
    tool="appimagetool"
  else
    log_warn "linuxdeploy/appimagetool not found; skipped AppImage package"
    return 0
  fi

  local appdir="${STAGING_ROOT}/appimage/AppDir"
  rm -rf "${appdir}"
  copy_bundle_to "${appdir}"
  mkdir -p "${appdir}/usr/bin"
  cat > "${appdir}/usr/bin/${APP_NAME}" <<EOF
#!/usr/bin/env bash
HERE="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
exec "\${HERE}/../../opt/${APP_NAME}/${APP_NAME}" "\$@"
EOF
  chmod +x "${appdir}/usr/bin/${APP_NAME}"
  prepare_desktop_file "${appdir}/usr/share/applications/${DESKTOP_FILE}" "${APP_NAME}"
  mkdir -p "${appdir}/usr/share/icons/hicolor/512x512/apps"
  cp "${PROJECT_ROOT}/linux/icons/hicolor/512x512/apps/${PACKAGE_NAME}.png" \
    "${appdir}/usr/share/icons/hicolor/512x512/apps/${PACKAGE_NAME}.png"
  cp "${appdir}/usr/share/applications/${DESKTOP_FILE}" "${appdir}/${DESKTOP_FILE}"
  cp "${PROJECT_ROOT}/linux/icons/hicolor/512x512/apps/${PACKAGE_NAME}.png" \
    "${appdir}/${PACKAGE_NAME}.png"
  cat > "${appdir}/AppRun" <<EOF
#!/usr/bin/env bash
HERE="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
exec "\${HERE}/opt/${APP_NAME}/${APP_NAME}" "\$@"
EOF
  chmod +x "${appdir}/AppRun"

  local output="${RELEASE_DIR}/${APP_NAME}-${VERSION}-linux-${GENERIC_ARCH}.AppImage"
  rm -f "${output}"
  if [[ "${tool}" == "linuxdeploy" ]]; then
    (
      cd "${PROJECT_ROOT}"
      OUTPUT="${output}" run_cmd linuxdeploy \
        --appdir "${appdir}" \
        --desktop-file "${appdir}/usr/share/applications/${DESKTOP_FILE}" \
        --icon-file "${PROJECT_ROOT}/linux/icons/hicolor/512x512/apps/${PACKAGE_NAME}.png" \
        --output appimage
    )
  else
    run_cmd appimagetool "${appdir}" "${output}"
  fi

  if [[ -f "${output}" ]]; then
    log_info "Produced ${output}"
  else
    log_error "AppImage build failed: no AppImage produced"
    exit 1
  fi
}

build_flatpak() {
  if [[ "${CROSS}" == "true" ]]; then
    log_warn "Flatpak builds from source inside flatpak-builder and needs a matching-arch host; skipped Flatpak package"
    return 0
  fi
  if ! command -v flatpak-builder >/dev/null 2>&1; then
    log_warn "flatpak-builder not found; skipped Flatpak package"
    return 0
  fi

  local flatpak_stage="${STAGING_ROOT}/flatpak"
  local flatpak_build="${STAGING_ROOT}/flatpak-build"
  local flatpak_repo="${STAGING_ROOT}/flatpak-repo"
  local output="${RELEASE_DIR}/${APP_NAME}-${VERSION}-linux-${GENERIC_ARCH}.flatpak"
  rm -rf "${flatpak_stage}" "${flatpak_build}" "${flatpak_repo}"
  mkdir -p "${flatpak_stage}"

  # The checked-in manifest points at the x64 bundle; render an
  # arch-correct copy with absolute source paths into the staging tree.
  local manifest="${flatpak_stage}/${PACKAGE_NAME}.yml"
  sed -e "s|path: ../../|path: ${PROJECT_ROOT}/|g" \
      -e "s|build/linux/x64/release/bundle|build/linux/${BUNDLE_ARCH_DIR}/release/bundle|" \
    "${PROJECT_ROOT}/tool/packaging/flatpak/${PACKAGE_NAME}.yml" > "${manifest}"
  local runtime_version
  runtime_version="$(awk -F'"' '/^runtime-version:/ { print $2; exit }' "${manifest}")"
  if ! flatpak info "org.gnome.Sdk//${runtime_version}" >/dev/null 2>&1; then
    log_warn "Flatpak SDK org.gnome.Sdk//${runtime_version} not installed; skipped Flatpak package"
    log_warn "Install it with: flatpak install flathub org.gnome.Sdk//${runtime_version} org.gnome.Platform//${runtime_version}"
    return 0
  fi
  if ! flatpak info "org.gnome.Platform//${runtime_version}" >/dev/null 2>&1; then
    log_warn "Flatpak runtime org.gnome.Platform//${runtime_version} not installed; skipped Flatpak package"
    log_warn "Install it with: flatpak install flathub org.gnome.Sdk//${runtime_version} org.gnome.Platform//${runtime_version}"
    return 0
  fi

  prepare_desktop_file "${flatpak_stage}/${DESKTOP_FILE}" "${APP_NAME}"
  rm -f "${output}"

  run_cmd flatpak-builder \
    --force-clean \
    --default-branch=stable \
    --repo="${flatpak_repo}" \
    "${flatpak_build}" \
    "${manifest}"

  run_cmd flatpak build-bundle \
    "${flatpak_repo}" \
    "${output}" \
    "${PACKAGE_NAME}" \
    stable
  log_info "Produced ${output}"
}

case "${FORMAT}" in
  all)
    build_deb
    build_rpm
    build_arch
    build_appimage
    build_flatpak
    ;;
  deb) build_deb ;;
  rpm) build_rpm ;;
  arch) build_arch ;;
  appimage) build_appimage ;;
  flatpak) build_flatpak ;;
esac

log_info "Linux build complete"
