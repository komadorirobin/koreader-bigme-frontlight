#!/bin/sh
set -eu
# Run from the repository root. Uses pinned official JNI layout/context.
sh scripts/fetch-test-sources.sh
case "$(uname -s)" in
    Darwin) diag_fixture=.cache/readonly-diagnostic.dylib; shared_flag=-dynamiclib ;;
    *) diag_fixture=.cache/readonly-diagnostic.so; shared_flag=-shared ;;
esac
"${CC:-cc}" "$shared_flag" -fPIC -Wall -Wextra -Werror -o "$diag_fixture" diagnostics/android-settings-readonly/tests/native_fixture.c
BIGME_DIAG_FIXTURE="$(pwd)/$diag_fixture" "${LUA:-luajit}" diagnostics/android-settings-readonly/tests/test_readonly.lua
