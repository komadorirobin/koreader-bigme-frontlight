# KOReader Bigme frontlight compatibility

[Svenska](README.sv.md) · [Download](https://github.com/komadorirobin/koreader-bigme-frontlight/releases)

A small, standalone KOReader userpatch that connects KOReader's normal light
controls to the cold and warm LEDs on one verified Bigme firmware family.
It also serves interfaces such as OrbitUI's quick controls that use PowerD.
OrbitUI is **not** required. No root, APK replacement or firmware modification.

**Initial beta: v0.1.0-beta.1.** Both channel commands and their restoration were
physically verified on the owner's Bigme. The integrated driver, complete range,
Android-settings bridge and lifecycle still require device acceptance; automated
tests are not a substitute. Keep Bigme's own Android light panel available.

## Supported device profile

The test device is a Bigme B7 Pro whose firmware reports these generic identifiers:

| Property | Required value |
| --- | --- |
| Manufacturer or brand | `bigme` |
| Model | `hibreak` |
| Product | `hibreak_eea` |
| Hardware | `mt6877` |
| Architecture | Android `arm64` |

Marketing names alone are not a compatibility check. In particular, a model
string of `hibreak` is not a promise that every HiBreak phone or Bigme reader is
supported. Other profiles do nothing. Unknown/mismatched OEM light values leave
the original backend intact and produce a warning on an otherwise matching device.

Requires a KOReader build with userpatch support and the stock Android PowerD
backend. Developed/tested against KOReader
[`801277394b7fdb77da5580459a9827e9d95e95a4`](https://github.com/koreader/koreader/tree/801277394b7fdb77da5580459a9827e9d95e95a4).
F-Droid builds without userpatch support cannot load this file.
KOReader must already be allowed to **modify system settings** in Android;
the patch neither requests nor grants that permission, and never changes SELinux.

## Install

### Ereader Patch Manager

The identical `2-bigme-frontlight.lua` is also published in
[komadorirobin/Ereader](https://github.com/komadorirobin/Ereader).
[Ereader Patch Manager](https://github.com/komadorirobin/ereader-patch-manager.koplugin)
discovers new numbered patches automatically when it synchronizes. Synchronize
and restart KOReader. Previously disabled copies remain disabled.
No Patch Manager update or new OrbitUI release is required for discovery.

### Manual

Download `2-bigme-frontlight.lua` from a release, or extract its ZIP and copy
**only that Lua file** into KOReader's `patches/` directory. Normally on Android:

```text
/storage/emulated/0/koreader/patches/2-bigme-frontlight.lua
```

Disable the earlier access/cold/warm diagnostic patches first, if installed:
`2-bigme-frontlight-access-diagnostic.lua`, `2-bigme-frontlight-manual-test.lua`
and `2-bigme-frontlight-warm-test.lua`. Rename `.lua` to `.lua.disabled` or move
them outside `patches/`; keep their logs. Do not disable unrelated patches.
Install just one copy of the compatibility patch, then fully quit/restart KOReader.

## Controls and saved levels

- **Brightness** controls the cold channel, indices **0–36**.
- **Warmth** controls the warm channel, also 0–36 in the native dialog. KOReader's
  public warmth API remains 0–100; the patch handles the conversion.
- These follow Bigme's independent channel controls: warmth is not a
  constant-brightness colour-temperature mixer. Increasing warm light can also
  make the display brighter. Other frontlight automations retain those semantics.
- **Toggle** switches both channels off and restores their previous pair on the
  next toggle. It does not guess an arbitrary default when no previous pair exists.
- OEM index-to-driver mapping is nonlinear; the slider numbers are not percentages.

Loading the patch reads existing levels without sending a light command or
changing system settings. Existing automations can still call PowerD normally.
Getters read back Bigme's settings, so changes in the Android panel are visible
to subsequent KOReader controls. No background poller is added.

After a successful hardware command, the corresponding `ColdValue`/`WarmValue`
and `screen_brightness_cold`/`screen_brightness_warm` are synchronized. The matching
custom-preset value is also updated when `LightMode=4`; day/night presets and
the selected mode are not rewritten. One profile-scoped KOReader setting,
`bigme_frontlight_restore`, remembers the pair for switching back on, including
normal KOReader restarts. Normal KOReader settings persistence still applies.

The patch does not change batteries, books, reading data, network controls,
rendering, screen refresh mode or unrelated Android settings.

## Safety, failures and removal

Only `/dev/lm3630a` and the two OEM setter requests are used: cold `0x7901`, warm
`0x7902`, each with an owning 32-bit integer array. The device is opened O_WRONLY
and closed immediately after each command, including after call exceptions.
Open, ioctl and close failures are checked; no automatic retry or guessed ioctl.
JNI uses public `Settings.System` APIs with checked lookups, exception clearing
and local-reference cleanup. Forked thumbnail workers cannot call JNI or hardware.

Failures latch the driver until a restart rather than pretending success or
falling back to the ineffective generic brightness path. A partial operation
may already have changed one channel. Use Bigme's own panel to set the desired
levels, then restart. Warnings are available in Swedish/English.

To remove: disable this patch in Patch Manager, or rename `.lua` to `.lua.disabled`,
then restart. Existing light levels and user data are not reset.

When reporting a problem, include the device properties above, KOReader version
and only relevant `[Bigme frontlight ...]` lines from `crash.log`. Do not upload
account tokens, book data or full private logs. Do not use `settings put` as a
hardware test: changing a stored number alone did not change this device's LEDs.

## Verification and development

Hardware evidence, 2026-10-30, ordinary KOReader app UID, no root/security changes:
cold index **12→26→12** (raw **114→198→114**) and warm index **13→30→13** (raw
**120→210→120**), with accepted ioctls and user-confirmed physical restoration.
The 37-entry mapping and request ABI were identified by static inspection of
the owner's OEM files. **No proprietary APKs, libraries or private logs are
included in this repository or releases.**

```sh
make test LUA=luajit
make test LUA=lua
make test-native
make package
```

Tests fetch three unmodified KOReader sources at the exact revision above and
verify their SHA-256 hashes before loading them. They exercise real PowerD and
native frontlight-widget callbacks with mocked hardware/JNI/settings. All 37
indices, channel isolation, toggles, readback, guards, partial failures, scalar
JNI arguments, cleanup and background-worker isolation are covered. A separate
host C fixture checks real LuaJIT FFI pointers/varargs/errno without any device,
real JNI or kernel ioctl. Release ZIPs contain only the patch, docs, license and
checksums. Verify extracted files with `shasum -a 256 -c SHA256SUMS`.

The Ereader catalogue copy must stay byte-identical to the standalone release.
This is an independent community project, not an official Bigme or KOReader release.

## License

[MIT](LICENSE). KOReader and downloaded test references retain their own licenses.
