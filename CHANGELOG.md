# Changelog

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
