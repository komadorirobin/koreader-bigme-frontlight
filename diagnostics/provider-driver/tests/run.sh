#!/bin/sh
set -eu
sh scripts/fetch-test-sources.sh
BIGME_PATCH=${BIGME_PATCH:-diagnostics/provider-driver/2-bigme-frontlight.lua}
BIGME_PROVIDER_DRIVER=1
export BIGME_PATCH BIGME_PROVIDER_DRIVER
if [ "${1:-}" = native ]; then
    case "$(uname -s)" in
        Darwin) fixture=.cache/provider_driver_native.dylib; shared_flag=-dynamiclib ;;
        *) fixture=.cache/provider_driver_native.so; shared_flag=-shared ;;
    esac
    "${CC:-cc}" "$shared_flag" -fPIC -Wall -Wextra -Werror -o "$fixture" tests/native_fixture.c
    BIGME_NATIVE_FIXTURE="$(pwd)/$fixture" "${LUA:-luajit}" tests/test_frontlight.lua .cache/upstream
else
    "${LUA:-luajit}" tests/test_frontlight.lua .cache/upstream
fi
"${LUA:-luajit}" diagnostics/provider-driver/tests/test_driver_jni.lua
