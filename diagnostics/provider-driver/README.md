# Bigme frontlight — 0.1.0-beta.3-local.2

## Svenska

**Lokal testversion, inte en release eller automatisk uppdatering.** Den använder
Bigmes egen inställningstjänst för de sex fasta ljusvärdena, i stället för de
direkta Android-skrivningar som nekades på din enhet. Den separata testen har
verifierat en verklig `ColdValue`-ändring och återställning. Detta paket ska nu
testa kombinationen med de tidigare fungerande ljuskommandona och synkningen.

Patchen skickar **inga ljuskommandon och skriver inga Android-inställningar vid
själva laddningen**. När du använder ett ljusreglage skickas verkliga kommandon
till ljusenheten. Ingen root, APK-installation eller behörighetsändring behövs.
Paketet är fristående från OrbitUI.

### Installera

1. Inaktivera samtliga tidigare tester genom att byta `.lua` till `.lua.disabled`
   eller flytta dem ut ur `koreader/patches/`:

   - `2-bigme-frontlight-access-diagnostic.lua`
   - `2-bigme-frontlight-manual-test.lua`
   - `2-bigme-frontlight-warm-test.lua`
   - `2-bigme-settings-readonly-diagnostic.lua`
   - `2-bigme-settings-provider-test.lua`
   - `2-bigme-settings-provider-roundtrip.lua`

   Behåll loggarna och roundtrip-testets återställningsfil. Även omdöpta aktiva
   kopior av testerna ska vara avstängda; filnamnskontrollen kan inte hitta dem.
2. Avsluta KOReader helt. Behåll gamla felande `2-bigme-frontlight.lua`-kopior
   inaktiverade som säkerhetskopior. Installera **bara den nya
   `2-bigme-frontlight.lua`** i `/storage/emulated/0/koreader/patches/`.
   Ha bara en aktiv drivrutinskopia. Versionsraden ska innehålla
   `0.1.0-beta.3-local.2`.
3. **Synkronisera inte Patch Manager under testet.** Den publika katalogen
   innehåller fortfarande Beta 2 och kan annars ersätta testfilen. Ingen ändring
   har publicerats i katalogen eller på GitHub.

### Testa stegvis

Pausa ljusautomatiseringar i Android och KOReader under testet. Använd inte
Bigmes och KOReaders reglage samtidigt.

1. Välj ett behagligt ljus i Bigmes egen meny. Notera båda nivåerna och stäng
   menyn. Starta KOReader. Nivåerna ska kunna läsas utan något felmeddelande.
2. Använd först KOReaders vanliga ljusdialog. Ändra ljusstyrkan **ett steg** och
   tillbaka. Kontrollera om ljuset faktiskt ändras, inte bara siffran.
3. Gör samma sak med varmt ljus. Öppna Bigmes egen meny efteråt och kontrollera
   att båda reglagen visar de valda nivåerna. Stäng menyn igen.
4. Ändra nivåerna i Bigmes meny, stäng den och kontrollera att KOReader läser de
   nya nivåerna. Prova därefter motsvarande små justeringar via OrbitUI.
5. **Bara om båda kanalerna och synkningen fungerar:** prova av/på i KOReader och
   kontrollera att samma nivåer återkommer. Gör sedan en normal omstart av
   KOReader och kontrollera avläsningen igen.
6. Lägg `/storage/emulated/0/koreader/bigme-frontlight-local-test.log` på iCloud.
   Berätta vad det fysiska ljuset och Bigmes reglage gjorde. Även en bild på ett
   eventuellt fel är användbar. Loggen ensam bevisar inte fysisk effekt.

Kall- och varmnivåerna är 0–36. Värmen styr en separat LED-kanal; detta är inte
en färgtemperaturmixer som håller total ljusstyrka konstant. Inställningar i
andra program kan visa andra skalor.

### Vid fel

Sluta justera via KOReader/OrbitUI. Välj önskade nivåer i **Bigmes egen ljusmeny**,
inaktivera testpatchen och starta om KOReader. Fotografera felrutan och behåll
loggen. Patchen låser vidare justeringar efter ett upptäckt fel; den försöker
inte automatiskt igen eller återställa blint. Om ett ljuskommando redan har
gått igenom kan ljuset ha ändrats trots att sparningen därefter misslyckades.

Vid startproblem: tvångsavsluta KOReader och byt testfilens `.lua` till
`.lua.disabled` i Androids filhanterare. Rensa inte appdata och återaktivera inte
gamla felkopior. Ta inte bort roundtrip-testets återställningsfil för nya försök.

### Vad som verifieras — och inte

- Endast den tidigare verifierade profilen `bigme` / `hibreak` / `hibreak_eea` /
  `mt6877` / Android arm64 med vanlig app-UID och SELinux-kontext tillåts.
- Tjänsten måste ha rätt authority, paket, klass, systemapp-flagga, export/
  aktivering och redan beviljade eventuella behörigheter. KOReaders befintliga
  `WRITE_SETTINGS` kontrolleras utan den gamla kraschande hjälpfunktionen.
- Bara `setting_put_data_system` används med Bundle-fälten `name`, `type=1`
  och heltalsvärdet `value`. Tillåtna nycklar är `ColdValue`, `WarmValue`,
  `screen_brightness_cold`, `screen_brightness_warm`, `LightUser_Brightness` och
  `LightUser_ColorTemp`. Inga lägen eller dag-/nattförinställningar skrivs.
- Före första justeringen i ett valt läge provas samma befintliga nivåer och
  tabellberäknade råvärden. Ett upptäckt fel stoppar före ljuskommandot. Även
  samma-värde-skrivningar kan aktivera Android-observatörer.
- Efter ljuskommandot stängs enhetsfilen och de nya värdena sparas. Nivåindex,
  läge och i läge 4 egen förinställning kontrolleras genom återläsning. Värden
  för orörd kanal ska vara oförändrade. Detta är inte en atomär transaktion med
  andra appar; därför måste andra reglage/automatiseringar vara vilande.
- **Råfälten kan fortfarande inte läsas tillbaka från KOReaders app.** De
  härleds ur den tidigare verifierade 37-stegstabellen, men deras faktiska
  lagring kan inte bevisas av tjänstens svar. Även ett tyst ignorerat råvärde
  skulle passera den begränsningen. Logg/status markerar råavläsning som
  otillgänglig/overifierad; det är inte ett godkännande för publicering.
- Tjänstens oförändrade standardstatus `-1` tolkas inte som framgång/fel.
  Ett returnerat anrop eller godtaget ioctl bevisar inte fysisk ljusändring.

Om ADB finns till hands kan rålagringen kontrolleras separat efter en justering
med följande **enbart läsande** kommandon. Ändra inte ljuset samtidigt:

```sh
adb -d shell settings get --user current system ColdValue
adb -d shell settings get --user current system screen_brightness_cold
adb -d shell settings get --user current system WarmValue
adb -d shell settings get --user current system screen_brightness_warm
adb -d shell settings get --user current system LightMode
adb -d shell settings get --user current system LightUser_Brightness
adb -d shell settings get --user current system LightUser_ColorTemp
```

Exempel ur tabellen: kallnivå 26 motsvarar råvärde 198, varmnivå 30 råvärde 210.
Jämför bara sådana exempel om just dessa nivåer är valda. Du kan börja med det
fysiska testet utan ADB; rålagringen är då uttryckligen fortfarande overifierad.

Loggen utökas utan att äldre rader raderas, upp till cirka 256 KiB. Den innehåller
version, generisk profil, fasta ljusvärden och eventuella Java-fel, inte böcker
eller kontofiler. Granska före delning. Detta paket innehåller inga privata
loggar eller proprietära APK-filer.

## English

**Local device-test candidate, not a release or automatic update.** This version
replaces rejected direct Android settings writes with the verified-profile Bigme
provider. A separate device test proved a real `ColdValue` change and restoration;
the full driver still needs device acceptance. Loading itself issues no light
command and writes no Android settings. Using its sliders sends real hardware
commands. No root, APK installation or permission changes. No OrbitUI update is
required.

Disable all six diagnostics listed above, including renamed active copies. Fully
quit KOReader, keep failed old drivers disabled and install only the new
`2-bigme-frontlight.lua` in `koreader/patches/`. Its version must be
`0.1.0-beta.3-local.2`. **Do not synchronize Patch Manager during testing**: the
public catalogue still has Beta 2. Keep all prior logs and the roundtrip recovery
record. No GitHub release or catalogue update has been made.

### Device test

Pause light automations in Android and KOReader. Set comfortable lights in
Bigme's panel, note both levels, close the panel and start KOReader. First use
KOReader's normal light dialog: change cold light one step and back, then warm
light one step and back. Check physical LEDs, not just numbers. Afterwards check
Bigme's sliders, then change them in Bigme, close the panel and check KOReader's
readback. Try the same small adjustments through OrbitUI. Never use both control
panels concurrently.

**Only if both channels and synchronization work**, try off/on restoration and a
normal KOReader restart. Send `koreader/bigme-frontlight-local-test.log` plus your
physical observations and any error photo. Levels are 0–36. Warmth controls a
separate LED channel, not constant-brightness color mixing.

On any failure, stop testing, use Bigme's own panel to restore desired levels,
disable this patch and restart KOReader. Failures latch: there are no automatic
retries or blind rollback. A hardware command may have applied even if subsequent
persistence fails. For startup failure, force-stop KOReader and rename the file
from `.lua` to `.lua.disabled`; do not clear app data or re-enable old failed
backups. Do not delete the earlier recovery record to rerun diagnostics.

### Limits and validation

The driver checks the exact supported profile, ordinary app UID/context, existing
permission and OEM provider identity/system/export/enabled/permission metadata.
Only `setting_put_data_system` and the six light keys listed above are allowed.
All method IDs and typed A-array arguments are checked before calls. No hidden
Java API, shell, network, root or permission request is used.

The first change per selected mode preflights same-value writes before hardware
I/O. Android observers may react even to those writes. After hardware acceptance
and descriptor closure, settings are saved and readable indices/mode/custom-mode
presets independently checked. Other-channel values must remain unchanged. This
is not atomic with concurrent apps. An observed failure stops further control.

**Raw settings remain unreadable to KOReader.** Raw arguments derive only from
the fixed OEM table, but neither provider response nor its unchanged `status=-1`
proves their persistence. Even silently ignored raw writes cannot be ruled out by
in-app readback. Status/logs explicitly leave raw persistence unverified; ioctl
acceptance does not prove physical output. If ADB is available, the read-only
commands above can independently inspect raw storage after an adjustment. Example:
cold index 26 maps to raw 198, warm index 30 to raw 210. Do not assume those are
the correct values for a different selected index. Without ADB, physical/slider
tests can proceed but raw storage remains explicitly unverified.

The bounded append-only log contains version/profile, light values and Java error
text, not books/accounts. Review it before sharing. No proprietary APKs or private
device logs are included. MIT, see LICENSE.

## Host tests

From the repository root:

```sh
PATH=/opt/homebrew/bin:$PATH sh diagnostics/provider-driver/tests/run.sh native
```

109 functional/native-ABI cases use pinned upstream PowerD and actual frontlight
widget callbacks with mocked Java/device behavior. Another 41 cases use the
checksum-pinned official JNI layout/context and typed FFI callbacks. Coverage
includes all 37 levels, both channels, preflight and post-hardware errors, provider
metadata/permission/missing-ID failures, no-op/null replies, off/on, preset/mode
preservation, duplicate/background-process guards and cleanup. No real JVM,
provider, hardware or Android user settings are accessed. These tests cannot
establish device acceptance or verify inaccessible raw persistence.
