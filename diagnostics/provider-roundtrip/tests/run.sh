#!/bin/sh
set -eu
sh scripts/fetch-test-sources.sh
"${LUA:-luajit}" diagnostics/provider-roundtrip/tests/test_roundtrip.lua
