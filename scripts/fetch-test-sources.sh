#!/bin/sh
set -eu
test_reference_dir=${1:-.cache/upstream}
mkdir -p "$test_reference_dir"
revision=801277394b7fdb77da5580459a9827e9d95e95a4
base_url="https://raw.githubusercontent.com/koreader/koreader/$revision/frontend"
fetch() {
    remote_path=$1
    local_name=$2
    expected_sha=$3
    target="$test_reference_dir/$local_name"
    if [ -f "$target" ]; then
        actual_sha=$(shasum -a 256 "$target" | awk '{print $1}')
        if [ "$actual_sha" = "$expected_sha" ]; then return; fi
    fi
    curl --fail --silent --show-error --location --retry 2 --output "$target.download" "$base_url/$remote_path"
    actual_sha=$(shasum -a 256 "$target.download" | awk '{print $1}')
    if [ "$actual_sha" != "$expected_sha" ]; then
        echo "Upstream fixture checksum mismatch: $local_name" >&2
        exit 1
    fi
    mv "$target.download" "$target"
}
fetch device/generic/powerd.lua generic-powerd.lua e1a12b8b566ecfd43025de96e01ba32ef03e2cab2569edcee384137f739119f4
fetch device/android/powerd.lua android-powerd.lua e2784cad9c3c8a2f088f9119c058d8313d960dbc3f0fc65d1b4eb1f00866d780
fetch ui/widget/frontlightwidget.lua frontlightwidget.lua 8057dab505a61a9dd2807c2dd13cc15a74e0fe256cd42453407cf72080aa12ae
