#!/usr/bin/env bash
# ============================================================
# Build TOS deb packages for owncast (x86_64 + aarch64)
# ============================================================
# Usage:
#   ./build.sh              # build both platforms
#   ./build.sh x86_64       # build one platform
#   ./build.sh aarch64
#
# Payload layout (upstream cwd-relative design): binary in bin/,
# WorkingDirectory=/var/lib/owncast (config.yaml + data/owncast.db).
# ============================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${REPO_ROOT}"

BUILD_DIR="build"
OUTPUT_DIR="${BUILD_DIR}/output"
mkdir -p "${OUTPUT_DIR}"

# ---- parse UPSTREAM pin ----
declare -A PIN
while IFS='=' read -r key value; do
    [[ -z "${key}" || "${key}" =~ ^# ]] && continue
    PIN["${key}"]="${value}"
done < UPSTREAM

APP_ID="owncast"
VERSION="${PIN[UPSTREAM_VERSION]}"
TAG="${PIN[UPSTREAM_TAG]}"

# ---- keep config.ini version in lockstep with the pin ----
CONFIG_VERSION=$(python3 -c "import json; print(json.load(open('config.ini'))['version'])")
if [[ "${CONFIG_VERSION}" != "${VERSION}" ]]; then
    echo "ERROR: config.ini version (${CONFIG_VERSION}) != UPSTREAM version (${VERSION})" >&2
    echo "  run: ./scripts/bump_upstream.sh ${VERSION}   # or update config.ini" >&2
    exit 1
fi

# ---- fetch + verify upstream assets ----
EVALS="$(bash scripts/fetch_upstream.sh)"
X64_FILE="$(sed -n 's/^FETCHED_X64=//p' <<< "${EVALS}")"
A64_FILE="$(sed -n 's/^FETCHED_A64=//p' <<< "${EVALS}")"
declare -A ASSET_FILE=( [x86_64]="${X64_FILE}" [aarch64]="${A64_FILE}" )

# platform -> dpkg architecture
platform_to_dpkg() {
    case "$1" in
        x86_64)  echo "amd64" ;;
        aarch64) echo "arm64" ;;
        *) echo "ERROR: unknown platform $1" >&2; exit 1 ;;
    esac
}

# extract the owncast binary from the release zip into <dest>/bin
extract_payload() {
    local archive="$1" dest="$2"
    mkdir -p "${dest}/bin"
    python3 - "$archive" "${dest}/bin" <<'ENDPY'
import sys, zipfile, os
archive, dest = sys.argv[1], sys.argv[2]
z = zipfile.ZipFile(archive)
found = []
for i in z.infolist():
    base = os.path.basename(i.filename)
    if base == "owncast":
        with z.open(i) as f, open(os.path.join(dest, base), "wb") as out:
            out.write(f.read())
        os.chmod(os.path.join(dest, base), 0o755)
        found.append(base)
if "owncast" not in found:
    raise SystemExit(f"ERROR: owncast binary missing from {archive}")
print("  extracted: owncast")
ENDPY
}

build_platform() {
    local platform="$1"
    local dpkg_arch
    dpkg_arch="$(platform_to_dpkg "${platform}")"
    local staging="${BUILD_DIR}/${platform}/staging"

    echo "=== Building ${APP_ID} v${VERSION} for ${platform} (${dpkg_arch}) ==="
    rm -rf "${BUILD_DIR}/${platform}"
    mkdir -p "${staging}/usr/local/${APP_ID}/bin" \
             "${staging}/usr/local/${APP_ID}/images/icons" \
             "${staging}/usr/local/${APP_ID}/init.d" \
             "${staging}/usr/local/${APP_ID}/packaging-extras" \
             "${staging}/usr/share/doc/${APP_ID}" \
             "${staging}/DEBIAN"

    # Debian doc files (copyright/changelog are expected by lintian and by
    # the MIT redistribution obligations — see NOTICE)
    cat > "${staging}/usr/share/doc/${APP_ID}/copyright" <<EOF
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: Owncast
Upstream-Homepage: ${PIN[UPSTREAM_REPO]}
Source: ${PIN[UPSTREAM_REPO]}

Files: *
Copyright: $(date +%Y) Owncast contributors
License: MIT
 The complete text of the MIT license is available upstream at
 https://github.com/owncast/owncast/blob/${TAG}/LICENSE and in the LICENSE
 file of the packaging repository. On Debian systems it can be found in
 /usr/share/common-licenses/MIT.
EOF
    {
        echo "owncast (${VERSION}) upstream; urgency=low"
        echo
        echo "  * Built from upstream ${PIN[UPSTREAM_REPO]} ${TAG} release zips for TOS"
        echo "    (unmodified; web UI embedded). Binary sha256 pinned in the UPSTREAM"
        echo "    file of the packaging repository."
        echo
        echo " -- ericbyz <ericbyz@users.noreply.github.com>  $(date -R)"
    } | gzip -9 > "${staging}/usr/share/doc/${APP_ID}/changelog.gz"

    # application payload
    extract_payload "${ASSET_FILE[${platform}]}" "${staging}/usr/local/${APP_ID}"
    install -m 644 config.ini "${staging}/usr/local/${APP_ID}/config.ini"
    install -m 644 owncast.lang "${staging}/usr/local/${APP_ID}/owncast.lang"
    install -m 644 images/icons/owncast.svg "${staging}/usr/local/${APP_ID}/images/icons/owncast.svg"
    install -m 644 init.d/owncast.service "${staging}/usr/local/${APP_ID}/init.d/owncast.service"
    install -m 644 packaging-extras/owncast.env.default "${staging}/usr/local/${APP_ID}/packaging-extras/owncast.env.default"

    install -m 644 DEBIAN/control "${staging}/DEBIAN/control"
    python3 - "$staging" "${dpkg_arch}" "${platform}" <<'PYEOF'
import json, sys
staging, dpkg_arch, platform = sys.argv[1], sys.argv[2], sys.argv[3]
app_root = f"{staging}/usr/local/owncast"
cfg = json.load(open(f"{app_root}/config.ini", encoding="utf-8"))
cfg["platform"] = platform
with open(f"{app_root}/config.ini", "w", encoding="utf-8", newline="\n") as f:
    json.dump(cfg, f, ensure_ascii=False, indent=2)
    f.write("\n")
ctl = open(f"{staging}/DEBIAN/control", encoding="utf-8").read()
import re
ctl = re.sub(r"^Architecture:.*$", f"Architecture: {dpkg_arch}", ctl, flags=re.M)
with open(f"{staging}/DEBIAN/control", "w", encoding="utf-8", newline="\n") as f:
    f.write(ctl)
print(f"  config.ini platform={platform}, control Architecture={dpkg_arch}")
PYEOF

    # maintainer scripts
    for s in postinst prerm postrm; do
        install -m 755 "DEBIAN/${s}" "${staging}/DEBIAN/${s}"
    done

    # ---- pack ----
    local out="${OUTPUT_DIR}/${APP_ID}_${platform}.deb"
    if command -v dpkg-deb >/dev/null 2>&1; then
        dpkg-deb --build --root-owner-group "${staging}" "${out}"
    else
        python3 scripts/build_deb.py --staging "${staging}" --output "${out}"
    fi
    (cd "${OUTPUT_DIR}" && sha256sum "$(basename "${out}")" > "$(basename "${out}").sha256")

    # ---- unpack + verify ----
    python3 scripts/unpack_check.py "${out}" "${platform}" "${VERSION}"
    echo "=== done: ${out}"
}

PLATFORMS=("$@")
[[ ${#PLATFORMS[@]} -eq 0 ]] && PLATFORMS=(x86_64 aarch64)
for p in "${PLATFORMS[@]}"; do
    build_platform "${p}"
done

echo
echo "=== Artifacts ==="
ls -lh "${OUTPUT_DIR}"
