# KOReader Bigme frontlight compatibility

[Svenska](README.sv.md) · [Download Beta 3](https://github.com/komadorirobin/koreader-bigme-frontlight/releases/tag/v0.1.0-beta.3)

A standalone KOReader userpatch that connects KOReader's normal light controls
to the cold and warm LEDs on one verified Bigme firmware profile. PowerD callers
such as OrbitUI's quick controls use the same backend; OrbitUI is not required.
No root, APK replacement, firmware modification or permission grant.

**Current release: v0.1.0-beta.3.** The integrated implementation has been tested
on the owner's matching Bigme: brightness, warmth, off/on restoration, restart
readback and synchronization in both directions with Bigme's own controls.
It remains a beta for this exact firmware profile, not general Bigme support.
Raw-settings storage has not been independently read back; see the limits below.

**Replace Beta 1 and Beta 2 before enabling.** Beta 1 could abort KOReader at
startup; Beta 2 avoided that abort but Android rejected its protected raw-key
reads. Direct writes also failed in the first local Beta 3 candidate. Beta 3
reads permitted indices and saves through Bigme's own verified settings provider.

## Supported profile and requirements

| Property | Required value |
| --- | --- |
| Manufacturer or brand | `bigme` |
| Model | `hibreak` |
| Product | `hibreak_eea` |
| Hardware | `mt6877` |
| Architecture | Android `arm64` |

Marketing names alone are not a compatibility check. The `hibreak` string does
not promise support for every HiBreak phone or Bigme reader. Other profiles are
left unchanged. Matching devices with invalid values, unavailable provider or
missing permission keep their original backend and receive a warning.

KOReader must support userpatches and use its stock Android PowerD backend.
KOReader must already be allowed to **modify system settings** in Android.
The patch neither requests nor grants permissions and never changes SELinux.
Development uses pinned KOReader
[`80127739`](https://github.com/koreader/koreader/tree/801277394b7fdb77da5580459a9827e9d95e95a4)
and Android launcher
[`367b7bb7`](https://github.com/koreader/android-luajit-launcher/tree/367b7bb7ef06171438b2fa910449fa8a2b227ec1).
Builds without userpatch support cannot load this file.

## Installation

### Ereader Patch Manager

The identical Lua file is distributed in
[komadorirobin/Ereader](https://github.com/komadorirobin/Ereader).
[Ereader Patch Manager](https://github.com/komadorirobin/ereader-patch-manager.koplugin)
discovers numbered root-level patches automatically. Synchronize patches and
restart KOReader; no new OrbitUI or Patch Manager version is required.

Existing disabled copies remain disabled. If upgrading from a failed beta, keep
it disabled while synchronizing, verify the replacement is **0.1.0-beta.3**, then
enable it and restart. Never rename an old failed backup back to `.lua`.
For a previous manual local test, synchronization can now replace it with Beta 3.

### Manual

Download the release's `2-bigme-frontlight.lua`, or extract the ZIP and copy
**only that Lua file** to:

```text
/storage/emulated/0/koreader/patches/2-bigme-frontlight.lua
```

Disable all earlier diagnostics first, including renamed active copies:

- `2-bigme-frontlight-access-diagnostic.lua`
- `2-bigme-frontlight-manual-test.lua`
- `2-bigme-frontlight-warm-test.lua`
- `2-bigme-settings-readonly-diagnostic.lua`
- `2-bigme-settings-provider-test.lua`
- `2-bigme-settings-provider-roundtrip.lua`

Rename `.lua` to `.lua.disabled` or move diagnostics outside `patches/`;
preserve their logs and recovery records. The driver blocks the six known active
filenames, but cannot detect arbitrary renamed copies. Keep only one active
frontlight driver. Fully quit and restart KOReader after installation.

## Controls

- **Brightness:** cold LED channel, indices **0–36**.
- **Warmth:** independent warm LED channel, native indices **0–36**. The public
  PowerD warmth API remains 0–100 with conversion handled by the patch.
- **Toggle / Switch:** both channels off, then restoration of their remembered
  pair. No arbitrary default is guessed when no prior pair exists.
- The nonlinear slider indices are not percentages. Warmth is not a
  constant-brightness color mixer: raising warm light can also brighten the screen.

Loading reads current levels without sending a light command or writing Android
settings. Existing automations can still call PowerD. Getters reread Bigme's
readable settings, making Android-panel changes visible without background polling.
A profile-scoped KOReader setting, `bigme_frontlight_restore`, remembers the pair
for off/on; normal KOReader settings persistence applies across normal restarts.

## Settings synchronization and limits

Only the exact system provider `com.xrz.SettingProvider`, package
`com.xrz.settings`, class `com.xrz.settings.provider.SettingProvider` is allowed.
Identity, system-app flag, enabled/exported state and existing permissions are
checked. Writes use only `setting_put_data_system`, with typed Bundle keys
`name`, `type=1` and integer `value`. The fixed write allowlist is:

- `ColdValue`, `WarmValue`
- `screen_brightness_cold`, `screen_brightness_warm`
- `LightUser_Brightness`, `LightUser_ColorTemp` (only while the selected mode is 4)

The selected mode and day/night presets are never written. Before the first
requested adjustment in a selected mode, same-value preflight writes check for
exceptions and unexpected readable-state changes before a direct light command.
Even same-value writes can notify Android observers. After a hardware command,
the descriptor is closed and settings are saved. Readable indices, mode and
custom-mode presets are independently checked; the untouched channel must match.

**Raw fields remain unreadable from KOReader's ordinary app UID.** Hardware
arguments use only the previously verified 37-entry OEM table, but returned
provider calls do not independently prove raw persistence. The OEM branch leaves
its default `status=-1` unchanged, so status is not used as a success indicator.
Silently ignored raw writes cannot be ruled out by in-app readback; logs/status
leave `raw_verified=false`. Physical operation and panel synchronization were
user-confirmed, but this does not establish raw storage or untested firmware/ranges.

Do not operate Android and KOReader light controls concurrently. This is not an
atomic transaction with other apps. Avoid concurrent automations when diagnosing.
No changes to books, accounts, batteries, networking or screen refresh behavior.

## Safety, recovery and removal

Only `/dev/lm3630a`, cold request `0x7901` and warm request `0x7902` are used,
with an owning 32-bit integer array. Open/ioctl/close failures are checked,
descriptors are closed on exception, and no automatic retry or guessed ioctl is
used. Public JNI methods/fields are checked before invocation with typed A-array
arguments, exception clearing and local-reference/UTF cleanup. Forked thumbnail
workers cannot use JNI or light hardware.

The obsolete `android.canWriteSettings()` helper is never called: its missing
Java target caused Beta 1's native abort. Public `Settings.System.canWrite(Context)`
is resolved and checked directly, including before later commands.

After a detected failure, further control is latched off until restart. A light
command may already have applied even if subsequent saving failed. Stop testing,
set desired levels through **Bigme's own panel**, disable the patch and restart
KOReader. There is no blind rollback. Warnings are Swedish/English.

If KOReader cannot start: force-stop it in Android, **do not clear app data**,
and rename `koreader/patches/2-bigme-frontlight.lua` to `.lua.disabled` using a
file manager. Keep failed backups disabled, synchronize/download Beta 3, verify
its version, then re-enable only the replacement. Books/settings need no reset.

To remove, disable in Patch Manager or rename the Lua extension and restart.
Existing lights and user data are not reset.

## Logs and verification

The bounded, append-only support trace keeps its previous filename for continuity:
`koreader/bigme-frontlight-local-test.log` (about 256 KiB maximum). It contains
version/profile, light values and Java errors, not books/accounts. Logs may include
old failed sessions: identify the version on each line. Review before sharing.

Device evidence on the matching profile, 2026-10-30:

- Separate cold and warm hardware tests physically changed/restored both channels.
- A provider roundtrip actually changed `ColdValue` **27→26→27** with original
  state verified; earlier same-value responses alone were not treated as proof.
- Integrated local candidate `0.1.0-beta.3-local.2` logged **32** successful
  adjustments (14 cold, 18 warm), readable indices/presets verified each time,
  no new-version error, and correct final readings at the next startup.
- The owner separately confirmed physical operation, off/on restoration and
  bidirectional synchronization with Bigme's controls. The release changes that
  candidate's version/messages/comments, not its light-control logic.
- Full 37-level behavior is host-tested, not a claim of physical testing of every
  value. Independent raw-storage readback remains unverified.

No proprietary APKs, libraries or private device logs are included.

## Development

```sh
make test LUA=lua
make test LUA=luajit
make test-native
make package
```

Five official source files are pinned and SHA-256 checked. The 105 functional
cases exercise actual upstream PowerD/widget callbacks with mocked I/O. Native
tests add four real FFI device-ABI cases, 41 typed-JNI/context cases and one safe
negative control of the old missing-method abort. No real JVM/provider/hardware
is used by host tests. Historical diagnostic regressions are separate:

```sh
sh diagnostics/android-settings-readonly/tests/run.sh
sh diagnostics/provider-current-values/tests/run.sh
sh diagnostics/provider-roundtrip/tests/run.sh
```

Diagnostics are never automatically installed or included in the release ZIP.
Release files contain the patch, bilingual docs, changelog, MIT license and
SHA-256 checksums. After extraction: `shasum -a 256 -c SHA256SUMS`.
Packaging refuses to overwrite an existing versioned ZIP.
The Ereader copy must remain byte-identical to the standalone release.

Independent community project, not an official Bigme or KOReader release.
[MIT](LICENSE); downloaded test references retain their own licenses.
