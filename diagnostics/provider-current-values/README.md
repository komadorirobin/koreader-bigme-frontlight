# Bigme settings provider — same-value test r1

## Svenska

**Tillfälligt, manuellt startat test. Inte en release eller en ny ljusdrivrutin.**
Testet provar Bigmes egen inställningstjänst från KOReaders vanliga appbehörighet.
Det skickar inga ljuskommandon, öppnar ingen ljusenhet och installerar inga
PowerD-kopplingar. Ingen root, APK-installation eller ändrad/begärd behörighet.

Det är **inte enbart avläsning**: efter ditt knapptryck sparas befintliga,
läsbara nivåer tillbaka. Samma-värde-skrivningar kan meddela Androids observatörer.
Inga nya ljusnivåer väljs. Råvärdena kan inte läsas säkert och **varken läses,
beräknas eller skrivs** i detta test. Inget ljusläge eller dag-/nattläge skrivs.

### Installation och körning

1. Inaktivera `2-bigme-frontlight.lua` (inklusive den lokala Beta 3-testversionen)
   och alla tidigare tester: `2-bigme-frontlight-access-diagnostic.lua`,
   `2-bigme-frontlight-manual-test.lua`, `2-bigme-frontlight-warm-test.lua` och
   `2-bigme-settings-readonly-diagnostic.lua`. Byt `.lua` till `.lua.disabled`
   eller flytta bort dem från `patches/`. Återaktivera inga gamla felkopior.
2. Avsluta KOReader helt. Kopiera **bara `2-bigme-settings-provider-test.lua`**
   till `/storage/emulated/0/koreader/patches/`. Starta KOReader igen.
3. Stäng Bigmes egen ljusmeny och pausa eventuella ljusautomatiseringar. Ändra
   inga ljusreglage under testet. Tryck **Prova aktuella värden** en gång.
   Inga JNI-anrop eller sparningar görs innan knapptrycket. Testet vägrar köra
   om någon av de fem kända äldre patcharna finns kvar som aktiv `.lua`.
4. Lägg `/storage/emulated/0/koreader/bigme-settings-provider-test.log` på iCloud
   och meddela resultatet. En bild på resultat-/felrutan går också bra.
5. Inaktivera testpatchen efteråt. Låt den tidigare ljuspatchen vara avstängd.

Vid oväntad ljusändring: avbryt, använd Bigmes egen meny för att välja önskade
nivåer och skicka loggen. Vid startproblem: tvångsavsluta KOReader och byt
testfilens `.lua` till `.lua.disabled`. Rensa inte appdata.

### Avgränsning och tolkning

Testet kräver den tidigare verifierade Bigme-profilen `hibreak` /
`hibreak_eea` / `mt6877` / Android arm64. Det löser endast
`content://com.xrz.SettingProvider` och kontrollerar ägarpaket, klassnamn,
systemapp-flagga, export/aktivering och eventuella befintliga behörigheter.
Saknade eller nekade villkor stoppar testet utan att nya behörigheter begärs.

Det enda tjänsteanropet är `setting_put_data_system`, med en Bundle som bara
innehåller `name`, `type=1` och `value=<aktuellt heltal>`. Endast `ColdValue` och
`WarmValue` sparas; när `LightMode=4` även `LightUser_Brightness` och
`LightUser_ColorTemp`. Alla nivåer måste vara heltal 0–36. `LightMode` läses men
skrivs aldrig. Inga andra tjänstefunktioner, secure-/globalinställningar, skal,
ADB, nätverk, konton eller bokfiler används.

Aktuella nivåer läses innan och efter varje anrop. En observerad ändring stoppar
testet utan automatisk återställning eller återförsök. Kontrollen är inte en
atomär transaktion med Android-menyn/andra appar; därför ska andra ljusreglage
och automatiseringar inte användas samtidigt. Testet körs högst en gång per
KOReader-start, högst fyra tjänsteanrop, utan bakgrundspollning.

**Ett returnerat svar och oförändrade nivåer bevisar inte att tjänsten faktiskt
verkställer skrivningen.** En tjänst som ignorerar anropet skulle ge samma utfall.
OEM-koden ger inte en tillförlitlig framgångsstatus för den här funktionen:
`status` börjar på `-1` och uppdateras inte i dess kodgren. Status loggas därför
som rå information, inte som lyckad/misslyckad skrivning. Råfält, ändring till nya
nivåer och full ljussynkning är fortfarande **otestade**.

Loggen innehåller generisk enhets-/tjänstinformation, fasta ljusvärden och
eventuell Java-feltext. Granska innan delning. Den utökas utan att gamla rader
raderas; vid cirka 256 KiB avbryts testet. Om loggen inte kan sparas stoppas
vidare testanrop och rutan visar ett loggfel. Loggen stängs före varje kontrollerat
JNI-steg. Java-fel rensas och lokala referenser/UTF-buffertar släpps före avslut.

## English

**Temporary manual same-value test, not a release or replacement driver.**
Disable the production/local frontlight patch and all four earlier diagnostics
listed above. Fully quit KOReader, install only `2-bigme-settings-provider-test.lua`
in `koreader/patches/`, then restart. Close Bigme's light panel, pause light
automations and do not adjust lights during the test. Press **Try current values**
once. No JNI work or provider write occurs before that press. Send
`koreader/bigme-settings-provider-test.log`, then disable this test and keep the
failed driver disabled. Never restore old failed backups.

This is **not read-only**. It saves back current readable indices through the
verified-profile Bigme system provider; same-value writes may notify Android
observers. No hardware device is opened, no light command/PowerD hook is installed,
no new level or light mode is selected and no permission is requested or changed.
No root, APK installation or ADB is needed. If anything unexpected happens, stop
and use Bigme's own panel to restore desired lights. For startup failure force-stop
KOReader and rename this test to `.lua.disabled`; do not clear app data.

Only `com.xrz.SettingProvider` / `com.xrz.settings.provider.SettingProvider` in
the system application `com.xrz.settings` is eligible. Metadata, exported/enabled
state and existing permissions are checked first. Only `setting_put_data_system`
is called, with Bundle keys `name`, `type=1`, and the current integer `value`.
The fixed setting allowlist is `ColdValue`, `WarmValue` and, only in mode 4,
`LightUser_Brightness`/`LightUser_ColorTemp`, all 0–36. Raw fields are neither read,
derived nor written; mode, day/night presets, secure/global settings, unrelated
provider operations, shell, network, books and account files are never touched.

Readable values are checked before/after each bounded call. Observed changes
stop testing without automatic restoration/retry. This is not an atomic operation
with concurrent Android apps, so keep other light controls/automations inactive.
At most four provider calls run, once per KOReader startup, with no polling.

**Returned calls and unchanged values are not proof of successful mutation.**
A no-op provider gives the same observation. The inspected OEM branch leaves
its initial `status=-1` untouched; returned status is logged, not interpreted as
success or failure. Raw-field writes, new-level writes, physical output and full
synchronization remain untested. Logging is bounded and append-only; a saving
failure prevents further diagnostic calls. Review generic profile/permission
names, light values and Java error text before sharing. No proprietary files or
private device logs are included in this package.

## Host validation and references

From the repository root run
`PATH=/opt/homebrew/bin:$PATH sh diagnostics/provider-current-values/tests/run.sh`
(or set `LUA=luajit` on another platform). Tests use the checksum-pinned official
JNI layout and unchanged context with harmless typed FFI callbacks. No JVM,
Android provider, device or real settings are accessed. Coverage includes exact
Bundle/argument types, same-value/key restrictions, no-op replies, metadata and
permission gates, missing JNI IDs, exceptions, changed levels, reference/UTF/thread
cleanup, consent/stale callbacks, owner PID, log failures and Swedish/English text.
Host tests do not establish Android acceptance or successful provider writes.

Public API references: [ContentResolver.call](https://developer.android.com/reference/android/content/ContentResolver),
[JNI exception handling](https://developer.android.com/ndk/guides/jni-tips#exceptions).
The fixed OEM protocol was identified by read-only static inspection of the
owner's supplied APK; the APK was not executed here or copied into the package.
License: MIT, see LICENSE. No GitHub release, push or Ereader catalogue update.
