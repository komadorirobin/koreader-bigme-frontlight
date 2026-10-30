# Bigme settings provider — one-step roundtrip r1

## Svenska

**Tillfälligt, manuellt startat diagnostiktest. Inte en release eller en
fungerande ersättare för ljusdrivrutinen.**

Testet ändrar endast den lagrade kalla nivån `ColdValue` ett steg och försöker
sedan återställa och verifiera originalvärdet. Den aktuella nivån läses från
enheten: exempelvis **27 → 26 → 27**, aldrig ett hårdkodat utgångsvärde.
Om nivån är 0 används 0 → 1 → 0; annars minskas den ett steg. Alla nivåer är
heltal 0–36. **Detta är en verklig tillfällig inställningsändring.**

Inga direkta ljuskommandon skickas, men Androids observatörer kan reagera på
ändringen. Återställning kan inte garanteras om processen avbryts, tjänsten
nekar skrivningen eller avläsningen misslyckas. Håll Bigmes egen ljusmeny
tillgänglig för manuell kontroll.

### Installation och körning

1. Inaktivera följande filer om de finns i `koreader/patches/`. Byt `.lua` till
   `.lua.disabled` eller flytta filerna ut ur mappen. Återaktivera inga gamla
   felkopior:

   - `2-bigme-frontlight.lua` (även den lokala Beta 3-versionen)
   - `2-bigme-frontlight-access-diagnostic.lua`
   - `2-bigme-frontlight-manual-test.lua`
   - `2-bigme-frontlight-warm-test.lua`
   - `2-bigme-settings-readonly-diagnostic.lua`
   - `2-bigme-settings-provider-test.lua`

2. Avsluta KOReader helt. Kopiera **bara
   `2-bigme-settings-provider-roundtrip.lua`** till
   `/storage/emulated/0/koreader/patches/` och starta KOReader igen.
3. Stäng Bigmes ljusmeny och pausa eventuella ljusautomatiseringar. Använd inga
   andra ljusreglage under testet. Tryck **Visa testplan**. Detta steg kontrollerar
   enheten och läser aktuella värden, men ändrar inga Android-inställningar.
4. Kontrollera den visade sekvensen med dina aktuella värden. Tryck
   **Kör ändring och återställning** en gång. Du kan välja **Avbryt** före detta
   steg utan någon inställningsändring. Värdena kontrolleras på nytt före körning.
5. Fotografera resultatet och skicka följande två filer, exempelvis via iCloud:

   - `/storage/emulated/0/koreader/bigme-settings-provider-roundtrip.log`
   - `/storage/emulated/0/koreader/bigme-settings-provider-roundtrip.recovery`

6. Inaktivera testpatchen efteråt. Låt den tidigare ljuspatchen vara avstängd.
   Behåll loggen och återställningsfilen, även om testet lyckas. Radera inte
   återställningsfilen för att försöka igen utan nya instruktioner.

Ingen JNI-körning eller inställningsändring görs automatiskt vid start. Testet
vägrar arbeta om någon av de sex kända äldre patchfilerna är aktiv eller om en
återställningsfil redan finns. Filnamnskontrollen upptäcker inte andra namn på
samma kod; även sådana kopior måste vara inaktiverade.

### Resultat och återställning

- **Ändringen verifierad och originalet återställt:** den nya nivån lästes
  tillbaka och hela den läsbara ursprungsbilden verifierades efter återställning.
  Det bevisar inte fysisk ljusändring, råfältsåtkomst eller en komplett drivrutin.
- **Testet gav inte en felfri verifierad ändring:** originalbilden kunde
  verifieras, men ändringen eller ett annat steg gav inte ett rent resultat.
- **ÅTERSTÄLLNING INTE BEKRÄFTAD:** använd Bigmes egen ljusmeny för att kontrollera
  och vid behov återställa den kalla originalnivån som visas i rutan och i
  återställningsfilens `original=`. Inaktivera testet, behåll och skicka båda
  filerna. Fortsätt inte med nya tester eller gamla felande ljuspatchar.

Före ändringen sparas original och mål i en separat `.recovery`-fil. Den
skrivs, flushas, stängs och läses tillbaka före tjänsteanropet. Det är inte en
garanti mot dataförlust vid exempelvis ett hårt strömavbrott. Efter verifierad
återställning läggs `RESTORED_VERIFIED` till i samma fil. Om det inte går att
markera filen klar visar resultatet en separat varning, även om originalvärdet
kunde läsas tillbaka.

En befintlig, skadad eller oavslutad återställningsfil blockerar nästa test.
**Ingen automatisk återställning görs vid nästa start.** Vid startproblem:
tvångsavsluta KOReader och byt testfilens `.lua` till `.lua.disabled`. Använd
Bigmes panel för manuell kontroll; rensa inte KOReaders appdata.

### Teknisk avgränsning

Endast den tidigare verifierade Bigme-profilen `hibreak` / `hibreak_eea` /
`mt6877`, Linux/Android arm64 och vanlig app-UID/SELinux-kontext tillåts.
Testet kontrollerar tjänstens paket `com.xrz.settings`, klass
`com.xrz.settings.provider.SettingProvider`, authority `com.xrz.SettingProvider`,
systemapp-flagga, export/aktivering och eventuella befintliga behörigheter.
Inga behörigheter begärs eller ändras.

Endast `setting_put_data_system` används, med Bundle-fälten `name=ColdValue`,
`type=1`, `value=<planerad nivå>`. Högst två anrop görs: en ändring och ett
kompenserande återställningsanrop, utan återförsök eller bakgrundspollning.
`WarmValue`, `LightMode` och, i läge 4, `LightUser_Brightness` samt
`LightUser_ColorTemp` läses för att upptäcka andra ändringar men skrivs aldrig.

Återställningsanropet görs bara om den läsbara bilden fortfarande motsvarar
ursprunget eller exakt den planerade testbilden. Om andra värden observeras
eller avläsningen misslyckas skrivs inget blint; filen lämnas för manuell kontroll.
Detta är inte en atomär transaktion med andra appar. Även dessa kontroller har
en kapplöpningsrisk, så andra ljusreglage och automatiseringar måste vara vilande.

Tjänstens svar/status används inte som framgångsbevis. Endast verklig ändrad
avläsning och verifierat original räknas. Råfält, ljusenheten, PowerD, root,
APK-installation, skal, nätverk, konton och böcker berörs inte.

Loggen utökas utan trunkering, med en gräns omkring 256 KiB. Loggfel före
ändringen stoppar körningen. Efter ett försökt ändringsanrop får loggfel inte
blockera återställningsförsöket; JNI-/värde-/processkontroller gäller fortfarande.
Granska generisk enhets-/tjänstinformation, ljusvärden och Java-feltext före
delning. Paketet innehåller inga privata loggar eller proprietära APK-filer.

## English

**Temporary manual diagnostic, not a release or working replacement driver.**
It changes only the stored cold level `ColdValue` by one step and attempts to
restore and verify the original. The plan uses current readings, for example
**27 → 26 → 27**. Zero uses 0 → 1 → 0; other values decrease one step. All levels
are integers 0–36. **This is a real temporary settings mutation.** No direct
hardware light commands are sent, but Android observers may react. Restoration
cannot be guaranteed after process interruption, denied writes or failed reads.

### Installation and use

1. Disable the six production/local/diagnostic patches listed in the Swedish
   installation section above, including any renamed active copies. Rename
   `.lua` to `.lua.disabled` or move them out of `koreader/patches/`. Never
   re-enable old failed copies.
2. Fully quit KOReader. Install **only
   `2-bigme-settings-provider-roundtrip.lua`** in
   `/storage/emulated/0/koreader/patches/`, then restart.
3. Close Bigme's panel, pause light automations and leave all other light
   controls alone during the test. Press **Show test plan**. This performs
   read-only validation; it does not change Android settings.
4. Check the displayed current-value sequence. Press **Run change and
   restoration** once, or **Cancel** to make no mutation. The current state is
   checked again before execution.
5. Photograph the result and send both `koreader/bigme-settings-provider-roundtrip.log`
   and `koreader/bigme-settings-provider-roundtrip.recovery`.
6. Disable this diagnostic afterwards and keep the failed driver disabled.
   Preserve both files even after success. Do not delete the recovery record
   to rerun the test without further instructions.

No JNI work or settings mutation runs automatically at startup. Any existing
recovery record blocks another test, including a completed or invalid record.
No automatic restoration runs at the next startup.

### Interpretation and recovery

A clean result means the one-step change was read back and the original readable
state was restored and verified. An inconclusive result can still confirm the
original state. Neither establishes physical light control, raw-field access or
full driver synchronization. If **RESTORATION NOT CONFIRMED** appears, use Bigme's
own panel to check/restore the original cold level shown in the dialog and the
record's `original=` field. Disable the test, preserve/send both files and stop
testing. For startup failure, force-stop KOReader and rename this test to
`.lua.disabled`; do not clear app data.

Before mutation, the original and target are written, flushed, closed and read
back in the recovery file. This does not guarantee durability after hard power
loss. `RESTORED_VERIFIED` is appended only after original-state readback. A
separate warning is shown if the original is verified but completing the record
fails. Records are never deleted or overwritten by the test.

Only the exact verified Bigme/arm64 profile, ordinary app UID/context and verified
system provider described above are allowed. No permissions are requested or
changed. Only `setting_put_data_system` with `name=ColdValue`, integer `type=1`
and the planned integer `value` is used. At most two calls run: one change and
one compensating restoration, without retries or polling. Warm level, mode and
custom-mode preset levels are read as concurrency guards, never written.

Restoration is attempted only when the readable state matches either the entire
original or exact test state. Unexpected values or failed reads prevent a blind
overwrite and leave the recovery record for manual checking. This is not an
atomic transaction with Android apps, so concurrent light controls/automations
must remain inactive. Provider reply/status is never treated as proof of a write.

Logging is bounded and append-only. A logging error before mutation stops the
test; after an attempted mutation, logging failures cannot block the compensating
restoration attempt. Mandatory JNI/state/process checks still apply. No hardware
device, PowerD hook, raw field, root, APK installation, shell, network, account or
book file is used. Review generic device/provider metadata, light values and Java
error text before sharing. No private logs or proprietary APKs are included.

## Host validation / lokal validering

From the repository root:

```sh
PATH=/opt/homebrew/bin:$PATH sh diagnostics/provider-roundtrip/tests/run.sh
```

The 63 host tests use the checksum-pinned official JNI layout/context with
harmless typed FFI callbacks, not a real JVM, provider, Android settings or device.
They check exact Bundle types/keys, bounded change/restoration, no-op/error
responses, missing IDs/permissions, state changes, journal/log failures,
interrupted-run records, consent/stale callbacks, reference/UTF/thread cleanup,
owner-process guards and Swedish/English text. They do not prove Android acceptance.

MIT, see LICENSE. This local package does not publish a GitHub release, push code
or update the Ereader patch catalogue.
