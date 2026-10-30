LUA ?= luajit

.PHONY: test test-native package
test:
	@LUA="$(LUA)" sh scripts/test.sh

test-native:
	@LUA=luajit sh scripts/test.sh native

package:
	@sh scripts/package.sh
