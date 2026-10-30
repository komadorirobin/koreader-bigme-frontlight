# Changelog

## v0.1.0-beta.3 — 2026-10-30

- Replace rejected direct Android writes with the exact verified Bigme system
  provider and typed `setting_put_data_system` calls. Validate identity,
  system-app/export/enabled flags and existing permissions. Only six fixed
  cold/warm light keys are allowed; no root, hidden API or permission changes.
- Avoid protected raw-key reads; use readable indices, selected mode and custom
  presets with the verified OEM table. Raw persistence is explicitly unverified,
  not inferred from returned calls or the provider's unchanged `status=-1`.
- Preflight same-value writes before the first light command in each selected
  mode; verify readable levels/presets after changes. Keep startup free of
  hardware commands/Android writes, latch errors, preserve owner-process and
  native ABI guards, and report checked JNI operation/Java error details.
- Promote device-tested `0.1.0-beta.3-local.2` without light-logic changes.
  Its device log shows 32 successful adjustments, clean readable verification
  and correct next-start readings. The owner separately confirmed physical
  cold/warm operation, off/on restoration and panel synchronization both ways.
  This is evidence for this exact profile, not all Bigme models or every level.
- Add 105 functional, four native device-ABI and 41 typed-JNI cases, plus the
  legacy missing-method negative control. Historical diagnostic tests cover
  actual-change/no-op distinctions and recovery behavior. Host tests use no real
  JVM/provider/hardware. No private logs or proprietary files are distributed.
- English/Swedish upgrade/recovery guidance. Standalone release and Ereader
  catalogue use identical Lua bytes; no OrbitUI/Patch Manager update is needed.
  Existing disabled copies stay disabled. Old beta tags/assets are untouched.

### Svenska

Första integrerade betan med användarbekräftat kallt/varmt ljus, av/på,
återställning och synkning åt båda håll på den matchande Bigme-profilen.
Blockerade Android-skrivningar ersätts av Bigmes egen verifierade tjänst,
och skyddade råvärden läses inte längre. Lagringen av råvärden är fortfarande
inte separat återläst; betastatus och exakt profilbegränsning kvarstår.
Svenska/engelska instruktioner, förbättrad felrapportering och typade JNI-tester.
Synkronisera via Ereader Patch Manager och starta om; ingen ny pluginversion
krävs. Inaktiverade kopior förblir inaktiverade. Återaktivera inte gamla felkopior.

## v0.1.0-beta.3-local.1 — unpublished device-test candidate

- Device diagnostic proved `ColdValue`/`WarmValue` readable and `canWrite=1`,
  but `Settings.System.getInt(screen_brightness_cold)` throws SecurityException
  with both variadic and array JNI calls. Do not infer permission denial or an
  ABI problem from that error. No private log is included here.
- Read only the two indices, selected mode and (in custom mode) preset indices.
  Keep exact profile/range checks and the already verified nonlinear OEM table.
  Raw values are written after commands but never queried. Independent raw
  consistency checking is necessarily unavailable, not silently simulated.
- Preflight required settings writes before the first light command in each
  selected mode, with current indices/presets and derived raw values. A denial
  stops before ioctl. No preflight/settings write/light command during loading
  or getters. Read back indices/presets and detect mode changes after commands.
- Include failing JNI operation and Java exception text with checked Throwable
  formatting and reference/UTF cleanup. Append bounded local test trace.
- Block installation if known earlier diagnostics remain active. All original
  profile, native ABI, permission, lifecycle and owner-process guards remain.
- 86 ordinary, four device-FFI and twelve JNI-boundary host cases pass. Optional
  old-Beta-2 negative control reproduces the actual protected-read failure.
  These are not Android/device acceptance tests. Local delivery only: no GitHub
  release, tag, push, Ereader catalogue or immutable public asset update.

### Svenska

Lokal testversion, inte publicerad. Undviker Androids blockerade råvärdesläsning
och använder läsbara nivåindex med den verifierade hårdvarutabellen. Skrivåtkomst
kontrolleras inför första justeringen, före ljuskommandon, och fel får eget
anropsnamn/Java-feltext i loggen. Återläsning av råvärden är inte möjlig och
hävdas inte. Synkning och fysisk effekt behöver bekräftas på Bigmen innan release.

## v0.1.0-beta.2 — 2026-10-30

Fixes the confirmed Beta 1 startup abort on KOReader v2026.07.1 / Bigme Android 14.
Beta 1 repeatedly reached `CallBooleanMethod` with a NULL method ID through
`android.canWriteSettings()` and the missing `hasWriteSettingsPermission` Java
target. Disabling the patch restored startup. No private log is distributed.

- Replace that obsolete helper with checked public
  `Settings.System.canWrite(Context)` calls. Validate the ID/exception before
  invoking it; denied/missing/error states fail closed without hardware writes.
- Recheck permission before settings reads and later commands; do not request,
  grant or modify permissions. Cold/warm mapping, ioctls and saved-state schema
  are unchanged. No OrbitUI or Patch Manager release is required.
- Add a regression that fails against Beta 1, permission revocation and invalid
  JNI-lookup cases. Test official pinned bridge code and Kotlin method names,
  not only the previously mocked boolean permission result.
- A harmless C JNI table reproduces the old NULL-method call without aborting,
  then exercises the complete corrected patch with official JNI layouts/context
  and real FFI calls. Checks success/denial/missing method/Java exception,
  references and attach/detach; no real JVM/hardware/settings are touched.
- 69 ordinary Lua/LuaJIT cases, four native device-ABI cases and seven JNI-boundary
  cases pass locally. GitHub CI and exact public-byte checks gate publication.
- English/Swedish recovery guidance. Beta 1 release notes are prominently warned;
  its immutable tag and assets are not replaced. The corrected integrated patch
  still needs physical startup/light/suspend acceptance on the Bigme.

### Svenska

Rättar Beta 1:s konstaterade startkrasch. Den gamla behörighetsfunktionen försökte
anropa en Java-metod som saknas; Android avbröt då KOReader upprepade gånger.
Den ersätts av en kontrollerad publik Android-kontroll, utan ändrade behörigheter.
Även saknade metoder, nekad/återkallad behörighet och Java-undantag testas.
80 separata fall täcker logik samt enhets-/JNI-gränser; ingen riktig Android-JVM
eller ljushårdvara används i testerna. Beta 1 har en varning. Håll den avstängd,
synkronisera/hämta Beta 2 och återaktivera inte den gamla filen. Den rättade
integrerade patchen behöver fortfarande bekräftas på enheten.

## v0.1.0-beta.1 — 2026-10-30

**Unsafe: do not enable.** A native startup abort was subsequently confirmed;
the original notes below describe the initial automated coverage, not device
acceptance. Use Beta 2 or later. **Osäker: aktivera inte.** Konstaterat startfel;
använd Beta 2 eller senare, se räddningsanvisningarna i README.

First public beta of the standalone Bigme frontlight compatibility patch.

- Connects normal KOReader/PowerD light controls, including OrbitUI callers,
  to the verified cold/warm driver requests and nonlinear 37-level OEM table.
- Reads existing settings without light writes during loading; synchronizes
  successful changes with Bigme's own stored channel values.
- Remembers both channels for off/on, with strict profile validation.
- Restricts activation to the verified `hibreak_eea` / `mt6877` / Android arm64
  profile with existing WRITE_SETTINGS access. No root or permission changes.
- Checks native/JNI failures, closes descriptors, cleans references/exceptions
  and prevents light/JNI calls from forked thumbnail workers.
- Includes English/Swedish instructions, warnings, MIT license and tests.
- The identical Lua file is distributed through Ereader Patch Manager's normal
  Ereader catalogue synchronization; no plugin update is needed.

Verification: 60 automated Lua/LuaJIT cases against pinned actual KOReader
PowerD/widget sources, plus four real-FFI cases against a harmless host C fixture.
No real hardware/JNI/user data is accessed by those tests. Earlier separate
device tests confirmed cold 12→26→12 and warm 13→30→13, including physical
restoration. **The integrated beta, full range and lifecycle still need physical
acceptance.** Keep Bigme's Android panel available; disable old diagnostics.

### Svenska

Första publika betan: vanliga ljusreglage, separata kall-/varmkanaler, synkade
OEM-värden och på/av med återställning. Begränsad till den verifierade profilen,
utan root eller ändrade behörigheter. Svensk/engelsk dokumentation och varningar.
Installeras också genom vanlig Ereader Patch Manager-synkronisering och omstart.
60 automatiska fall samt fyra FFI-fall passerar. Separata hårdvaruprov är godkända,
men **den färdiga betan behöver fortfarande testas på enheten**.
