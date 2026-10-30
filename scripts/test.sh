#!/bin/sh
set -eu
sh scripts/fetch-test-sources.sh
if [ "${1:-}" = native ]; then
    case "$(uname -s)" in
        Darwin) fixture=.cache/native_fixture.dylib; shared_flag=-dynamiclib ;;
        *) fixture=.cache/native_fixture.so; shared_flag=-shared ;;
    esac
    "${CC:-cc}" "$shared_flag" -fPIC -Wall -Wextra -Werror -o "$fixture" tests/native_fixture.c
    BIGME_NATIVE_FIXTURE="$(pwd)/$fixture" "${LUA:-luajit}" tests/test_frontlight.lua .cache/upstream
    jni_fixture="${fixture%.*}-jni.${fixture##*.}"
    "${CC:-cc}" "$shared_flag" -fPIC -Wall -Wextra -Werror -o "$jni_fixture" tests/jni_fixture.c
    BIGME_JNI_FIXTURE="$(pwd)/$jni_fixture" "${LUA:-luajit}" tests/test_jni.lua .cache/upstream
else
    "${LUA:-luajit}" tests/test_frontlight.lua .cache/upstream
fi
