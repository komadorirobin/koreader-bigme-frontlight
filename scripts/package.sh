#!/bin/sh
set -eu
project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_dir"
patch_version=$(sed -n 's/^local VERSION = "\([^"]*\)"/\1/p' 2-bigme-frontlight.lua)
case "$patch_version" in
    ''|*[!0-9a-z.-]*) echo 'Invalid patch version' >&2; exit 1 ;;
esac
mkdir -p dist
if [ -e "dist/bigme-frontlight-$patch_version.zip" ]; then
    echo "Refusing to overwrite existing versioned ZIP: $patch_version" >&2
    exit 1
fi
package_stage=$(mktemp -d "${TMPDIR:-/tmp}/bigme-frontlight-package.XXXXXXXX")
package_name="koreader-bigme-frontlight-$patch_version"
mkdir "$package_stage/$package_name"
cp 2-bigme-frontlight.lua README.md README.sv.md CHANGELOG.md LICENSE "$package_stage/$package_name/"
(
    cd "$package_stage/$package_name"
    shasum -a 256 2-bigme-frontlight.lua README.md README.sv.md CHANGELOG.md LICENSE > SHA256SUMS
)
(
    cd "$package_stage"
    COPYFILE_DISABLE=1 zip -X -r -q "$package_stage/package.zip" "$package_name"
)
cp "$package_stage/package.zip" "dist/bigme-frontlight-$patch_version.zip"
cp "$package_stage/$package_name/SHA256SUMS" dist/SHA256SUMS
cp 2-bigme-frontlight.lua dist/
printf 'Built dist/bigme-frontlight-%s.zip\n' "$patch_version"
