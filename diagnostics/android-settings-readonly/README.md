# Bigme settings read-only diagnostic r1

## Svenska

Tillfällig, manuellt startad diagnostik efter Beta 2:s generella Java-fel.
**Detta är inte en ny ljusdrivrutin eller release.** Den läser endast fem fasta
ljusinställningar och den befintliga skrivbehörigheten; enda skrivningen är dess
egen logg. Ingen ljusenhet öppnas, inga ljuskommandon skickas och inga
Android-/KOReader-inställningar, behörigheter eller PowerD-funktioner ändras.

1. Inaktivera `2-bigme-frontlight.lua` och tidigare åtkomst-/kall-/varmljustester.
   Döp inte tillbaka någon gammal `.lua.stoppad`-/`.lua.disabled`-kopia.
2. Kopiera **bara `2-bigme-settings-readonly-diagnostic.lua`** till
   `/storage/emulated/0/koreader/patches/` och starta om KOReader.
3. Tryck **Kör avläsning**. Testet vägrar köra om någon av de fyra kända
   ljuspatcharnas aktiva `.lua`-filer finns kvar. Inga JNI-anrop görs innan trycket.
4. Skicka `/storage/emulated/0/koreader/bigme-settings-readonly-diagnostic.log`,
   exempelvis via iCloud. Felrutan kan också fotograferas. Granska loggen före
   delning: den innehåller enhetens generiska profil, fasta ljusvärden och
   Java-feltext, men inga bok-/konto-/tokenfiler läses.
5. Inaktivera eller flytta bort diagnostikpatchen efter testet. Låt den riktiga
   ljuspatchen vara avstängd tills felet är utrett. Inget återställande behövs.

Varje steg för inställningsavläsning sparas och loggfilen stängs **före** anropet. Vid Java-fel
sparas originalundantagets klass och text via `Throwable.toString()`; sekundära
fel vid textläsning får inte dölja det ursprungliga steget. Testet jämför Beta 2:s
variadiska anrop (`VARARGS`) med explicita JNI-argumentarrayer (`ARRAY`). Båda
varianterna är enbart avläsning. Saknade metodreferenser anropas aldrig.
Testet körs högst en gång per start efter uttryckligt tryck, utan bakgrundspollning.
Den egna loggen utökas, inte töms; över 256 KiB avbryts testet utan fler anrop.

## English

Temporary, manually triggered read-only diagnostic for Beta 2's generic Java
exception. **Not a replacement driver or a new release.** Disable the production
frontlight patch and all previous access/cold/warm tests first. Install only
`2-bigme-settings-readonly-diagnostic.lua` in `koreader/patches/`, restart, then
press **Run read-only test**. No JNI call runs before that press; known active
light-patch files block the test. Send `koreader/bigme-settings-readonly-diagnostic.log`
and disable/remove the diagnostic afterwards. Do not re-enable old failed backups.

It logs each settings-read operation before calling it, the original Java exception text and
five fixed light-setting values, comparing variadic and explicit-array calls.
No device access, hardware commands, settings writes, permission changes, PowerD
hooks, network calls, books or account files. Only its own bounded append-only
log is written. Review Java error text before sharing. Unknown methods fail
closed; refs/UTF buffers/exceptions are cleaned before leaving the JNI context.
Host tests do not establish Android/hardware acceptance.

JNI exception handling follows the
[Android JNI guidance](https://developer.android.com/ndk/guides/jni-tips#exceptions).
License: MIT, as in the parent repository. This diagnostic is not automatically
distributed by Ereader Patch Manager and does not modify public beta assets.

## Host validation

From the repository root, run
`PATH=/opt/homebrew/bin:$PATH sh diagnostics/android-settings-readonly/tests/run.sh`
(or provide `LUA=luajit` on another platform). This uses the checksum-pinned
official Android JNI layout/context and a harmless C fixture, including Java
exceptions, missing methods, array/varargs comparison, UTF/ref/thread cleanup,
consent, active-patch blocking, language and log-failure checks. The fixture does
not access an Android device or hardware and cannot establish device acceptance.
