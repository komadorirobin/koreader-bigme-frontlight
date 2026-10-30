# Bigme-ljusstyrning för KOReader

[English](README.md) · [Hämta Beta 3](https://github.com/komadorirobin/koreader-bigme-frontlight/releases/tag/v0.1.0-beta.3)

En fristående användarpatch som kopplar KOReaders vanliga ljusreglage till en
verifierad Bigme-profil. OrbitUIs snabbkontroller använder samma PowerD-backend,
men OrbitUI krävs inte. Ingen root, APK-ersättning, firmware- eller behörighetsändring.

**Aktuell release: v0.1.0-beta.3.** Den integrerade patchen är provad på ägarens
matchande Bigme: kallt och varmt ljus, av/på med återställning, återläsning efter
omstart samt synkning åt båda håll med Bigmes reglage. Detta är fortfarande en
beta för exakt den testade firmwareprofilen, inte stöd för alla Bigme-enheter.
Råvärdenas faktiska lagring är inte separat återläst; se begränsningarna nedan.

**Ersätt Beta 1 och Beta 2 innan aktivering.** Beta 1 kunde stoppa KOReader vid
start. Beta 2 undvek startavbrottet men Android nekade dess råvärdesläsning.
Även direkta skrivningar nekades i den första lokala Beta 3-kandidaten. Beta 3
läser tillåtna nivåindex och sparar genom Bigmes egen verifierade tjänst.

## Enhet och krav

| Egenskap | Krävt värde |
| --- | --- |
| Tillverkare eller varumärke | `bigme` |
| Modell | `hibreak` |
| Produkt | `hibreak_eea` |
| Hårdvara | `mt6877` |
| Arkitektur | Android `arm64` |

Försäljningsnamnet räcker inte som kontroll. Strängen `hibreak` betyder inte
att alla HiBreak-telefoner eller Bigme-läsare stöds. Andra profiler lämnas
orörda. En matchande enhet med okända värden, saknad tjänst eller behörighet
behåller originaldrivrutinen och får en varning.

KOReader måste stödja användarpatchar och använda vanlig Android-PowerD. KOReader
behöver redan få **ändra systeminställningar** i Android. Patchen begär/beviljar
inga behörigheter och ändrar aldrig SELinux. Utvecklingen använder låsta
[KOReader-källor](https://github.com/koreader/koreader/tree/801277394b7fdb77da5580459a9827e9d95e95a4)
och [Android-launcher](https://github.com/koreader/android-luajit-launcher/tree/367b7bb7ef06171438b2fa910449fa8a2b227ec1).
Varianter utan användarpatchstöd kan inte ladda filen.

## Installation

### Ereader Patch Manager

Samma Lua-fil distribueras i [Ereader](https://github.com/komadorirobin/Ereader).
[Ereader Patch Manager](https://github.com/komadorirobin/ereader-patch-manager.koplugin)
hittar numrerade patchar automatiskt. Synkronisera patcharna och starta om
KOReader. Ingen ny OrbitUI- eller Patch Manager-version behövs.

En inaktiverad kopia förblir inaktiverad. Efter en felande beta: låt den vara
avstängd under synkroniseringen, kontrollera att ersättningen är
**0.1.0-beta.3**, aktivera sedan och starta om. Återaktivera aldrig en gammal
felkopia. En manuellt installerad lokal testversion kan nu ersättas via synk.

### Manuellt

Hämta releasens `2-bigme-frontlight.lua`, eller packa upp ZIP:en och kopiera
**bara Lua-filen** till:

```text
/storage/emulated/0/koreader/patches/2-bigme-frontlight.lua
```

Inaktivera alla tidigare diagnostikpatchar, även omdöpta aktiva kopior:

- `2-bigme-frontlight-access-diagnostic.lua`
- `2-bigme-frontlight-manual-test.lua`
- `2-bigme-frontlight-warm-test.lua`
- `2-bigme-settings-readonly-diagnostic.lua`
- `2-bigme-settings-provider-test.lua`
- `2-bigme-settings-provider-roundtrip.lua`

Byt `.lua` till `.lua.disabled` eller flytta testerna utanför `patches/`.
Behåll loggar och återställningsfiler. Patchen spärrar sex kända filnamn men kan
inte hitta godtyckligt omdöpta kopior. Ha bara en aktiv ljusdrivrutin. Avsluta
KOReader helt och starta om efter installation.

## Reglage

- **Ljusstyrka:** kall LED-kanal, nivå **0–36**.
- **Värme:** separat varm LED-kanal, nativ nivå **0–36**. PowerD:s publika
  värme-API behåller skalan 0–100; patchen räknar om.
- **Växla / av–på:** båda kanalerna släcks och det ihågkomna paret återkommer vid
  nästa tryck. Saknas tidigare nivåer gissas ingen standard.
- Nivåindex är inte procent. Värmen är ingen färgtemperaturmixer med konstant
  total ljusstyrka: mer varmt ljus kan också göra skärmen ljusare.

Själva laddningen läser nivåer utan ljuskommandon eller Android-skrivningar.
Befintliga automatiseringar kan fortfarande anropa PowerD. Ändringar i Bigmes
meny läses vid efterföljande KOReader-anrop; ingen bakgrundspollning införs.
KOReader-inställningen `bigme_frontlight_restore` minns paret för av/på och
normal lagring gäller över normala omstarter.

## Synkning och begränsningar

Endast systemtjänsten `com.xrz.SettingProvider`, paketet `com.xrz.settings` och
klassen `com.xrz.settings.provider.SettingProvider` tillåts. Identitet,
systemapp-flagga, aktivering/export och befintliga behörigheter kontrolleras.
Skrivningar använder bara `setting_put_data_system`, med Bundle-fälten `name`,
`type=1` och heltalet `value`. Den fasta listan över tillåtna skrivningar är:

- `ColdValue`, `WarmValue`
- `screen_brightness_cold`, `screen_brightness_warm`
- `LightUser_Brightness`, `LightUser_ColorTemp` (endast i valt läge 4)

Valt läge och dag-/nattförinställningar skrivs aldrig. Inför första begärda
ändringen i ett valt läge provas samma-värde-skrivningar och oförändrade läsbara
värden före det direkta ljuskommandot. Även samma värde kan aktivera Androids
observatörer. Efter ljuskommandot stängs enhetsfilen och värdena sparas. Nivåindex,
läge och egen förinställning återläses; den orörda kanalen ska vara oförändrad.

**Råfälten kan fortfarande inte läsas från KOReaders vanliga app-UID.** Alla
hårdvaruvärden kommer ur den tidigare verifierade tabellen med 37 steg, men ett
returnerat tjänsteanrop bevisar inte rålagring. OEM-kodens standardstatus `-1`
ändras inte i denna gren och används därför inte som framgångsindikator. Tyst
ignorerade råskrivningar kan inte uteslutas via återläsningen i appen;
logg/status lämnar `raw_verified=false`. Fysiskt ljus och reglagen är
användarbekräftade, men det bevisar inte rålagring eller otestad firmware/hela området.

Använd inte reglagen i Android och KOReader samtidigt. Detta är ingen atomär
transaktion med andra appar. Pausa andra ljusautomatiseringar vid felsökning.
Böcker, konton, batterier, nätverk och skärmuppdatering ändras inte.

## Fel, säkerhet och borttagning

Endast `/dev/lm3630a`, kallt kommando `0x7901` och varmt `0x7902` används,
med ägd 32-bitars heltalsarray. Fel från open/ioctl/close kontrolleras,
enhetsfilen stängs även vid anropsundantag och inga automatiska återförsök eller
gissade ioctls används. Publika JNI-metoder/fält kontrolleras före anrop med
typade A-array-argument, rensade Java-undantag och frigjorda lokala referenser/
UTF-buffertar. Avknoppade miniatyrprocesser får inte använda JNI eller ljushårdvara.

Den gamla `android.canWriteSettings()` används aldrig; dess saknade Java-mål
orsakade Beta 1:s startavbrott. `Settings.System.canWrite(Context)` kontrolleras
direkt, även före senare kommandon.

Ett upptäckt fel spärrar fortsatt styrning till omstart. Ett ljuskommando kan
redan ha ändrat ljuset även om efterföljande lagring misslyckas. Sluta testa,
välj önskade nivåer i **Bigmes egen meny**, inaktivera patchen och starta om
KOReader. Ingen blind återställning görs. Varningarna finns på svenska/engelska.

Om KOReader inte startar: tvångsavsluta via Android, **rensa inte appdata** och
byt `koreader/patches/2-bigme-frontlight.lua` till `.lua.disabled` i en
filhanterare. Låt felkopior vara avstängda, synkronisera/hämta Beta 3, kontrollera
versionen och aktivera bara ersättningen. Böcker/inställningar behöver inte nollställas.

För att ta bort patchen: inaktivera i Patch Manager eller byt filändelse och starta
om. Befintligt ljus och användardata återställs inte.

## Loggning och verifiering

Den begränsade, append-only supportloggen behåller sitt tidigare namn:
`koreader/bigme-frontlight-local-test.log` (högst omkring 256 KiB). Den innehåller
version/profil, ljusvärden och Java-fel, inte böcker/konton. Gamla felsessioner kan
finnas kvar; läs versionsnumret på varje rad. Granska före delning.

Enhetsunderlag på den matchande profilen, 2026-10-30:

- Separata hårdvarutester ändrade och återställde kallt respektive varmt ljus.
- Ett tjänstetest ändrade faktiskt `ColdValue` **27→26→27**, med originalbilden
  verifierad. Tidigare samma-värde-svar tolkades inte som bevis.
- Den integrerade lokala kandidaten `0.1.0-beta.3-local.2` loggade **32**
  lyckade justeringar (14 kalla, 18 varma), verifierade nivåer/förinställningar,
  inga fel i den nya versionen och korrekta slutnivåer vid nästa start.
- Ägaren bekräftade separat fysiskt ljus, av/på med återställning och synkning åt
  båda håll. Releasen ändrar kandidatens version/texter/kommentarer, inte ljuslogiken.
- Alla 37 nivåer testas lokalt, inte ett påstående om fysiskt prov av varje värde.
  Oberoende återläsning av rålagringen är fortfarande overifierad.

Inga proprietära APK-filer, bibliotek eller privata enhetsloggar medföljer.

## Utveckling

```sh
make test LUA=lua
make test LUA=luajit
make test-native
make package
```

Fem officiella källfiler är låsta och SHA-256-kontrolleras. 105 funktionstester
använder verklig PowerD/widget-kod med simulerad I/O. Native-testerna lägger till
fyra FFI/enhets-ABI-fall, 41 typade JNI-/kontextfall och en säker negativ kontroll
av den gamla saknade-metod-kraschen. Ingen riktig JVM/tjänst/hårdvara används.
Historiska diagnostikregressioner körs separat:

```sh
sh diagnostics/android-settings-readonly/tests/run.sh
sh diagnostics/provider-current-values/tests/run.sh
sh diagnostics/provider-roundtrip/tests/run.sh
```

Diagnostik installeras aldrig automatiskt och ingår inte i release-ZIP:en.
Paketet innehåller patchen, dokumentation på båda språk, ändringslogg, MIT-licens
och SHA-256-kontrollsummor. Efter uppackning: `shasum -a 256 -c SHA256SUMS`.
Paketeringen vägrar skriva över en befintlig versionsspecifik ZIP.
Ereader-kopian ska vara byte-identisk med den fristående releasen.

Oberoende gemenskapsprojekt, inte en officiell Bigme- eller KOReader-release.
[MIT](LICENSE); testreferenser behåller sina egna licenser.
