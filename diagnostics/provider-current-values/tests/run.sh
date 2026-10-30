#!/bin/sh
set -eu
# Run from repository root. No JVM/device is started or contacted.
sh scripts/fetch-test-sources.sh
"${LUA:-luajit}" diagnostics/provider-current-values/tests/test_provider.lua
