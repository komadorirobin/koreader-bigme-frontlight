# Bigme-ljusstyrning för KOReader

[English](README.md) · [Hämta](https://github.com/komadorirobin/koreader-bigme-frontlight/releases)

En fristående användarpatch som kopplar KOReaders vanliga ljusreglage till
Bigmes kalla och varma lysdioder. OrbitUIs snabbkontroller använder samma
PowerD-gränssnitt och kan därför också använda den. OrbitUI krävs inte.
Ingen root, APK-ersättning eller firmwareändring.

**Första beta: v0.1.0-beta.1.** Båda kanalernas styrkommandon och återställning
är fysiskt verifierade på ägarens Bigme. Den integrerade patchen, hela området,
Android-inställningskopplingen och livscykeln behöver fortfarande testas på enheten.
Lokala tester ersätter inte det. Behåll Bigmes egen Android-ljusmeny tillgänglig.

## Enhet och krav

Testenheten är en Bigme B7 Pro med dessa firmwareidentifierare:

| Egenskap | Krävt värde |
| --- | --- |
| Tillverkare eller varumärke | `bigme` |
| Modell | `hibreak` |
| Produkt | `hibreak_eea` |
| Hårdvara | `mt6877` |
| Arkitektur | Android `arm64` |

Försäljningsnamnet räcker inte som kompatibilitetskontroll. Modellsträngen
`hibreak` betyder inte att alla HiBreak-telefoner eller Bigme-läsare stöds.
Andra profiler påverkas inte. Okända eller inkonsekventa ljusvärden lämnar
originaldrivrutinen kvar och ger en varning på en i övrigt matchande enhet.

KOReader måste ha stöd för användarpatchar och använda sin vanliga Android-PowerD.
Utvecklad och testad mot revision
[`801277394b7fdb77da5580459a9827e9d95e95a4`](https://github.com/koreader/koreader/tree/801277394b7fdb77da5580459a9827e9d95e95a4).
F-Droid-varianter utan patchstöd kan inte ladda filen.
KOReader behöver redan vara tillåtet att **ändra systeminställningar** i Android.
Patchen begär eller beviljar inte någon behörighet och ändrar aldrig SELinux.

## Installation

### Ereader Patch Manager

Samma `2-bigme-frontlight.lua` publiceras också i
[Ereader](https://github.com/komadorirobin/Ereader).
[Ereader Patch Manager](https://github.com/komadorirobin/ereader-patch-manager.koplugin)
hittar nya numrerade patchar automatiskt vid synkronisering. Synkronisera och
starta om KOReader. En tidigare inaktiverad kopia förblir inaktiverad.
Ingen ny version av Patch Manager eller OrbitUI behövs för upptäckten.

### Manuellt

Hämta Lua-filen från en release, eller packa upp ZIP:en och kopiera **bara
`2-bigme-frontlight.lua`** till KOReaders `patches/`. Vanlig Android-sökväg:

```text
/storage/emulated/0/koreader/patches/2-bigme-frontlight.lua
```

Inaktivera först tidigare diagnostikpatchar om de finns:
`2-bigme-frontlight-access-diagnostic.lua`, `2-bigme-frontlight-manual-test.lua`
och `2-bigme-frontlight-warm-test.lua`. Byt `.lua` till `.lua.disabled` eller
flytta dem utanför `patches/`; behåll loggarna. Ändra inga andra patchar.
Installera bara en kopia av kompatibilitetspatchen och starta sedan om KOReader helt.

## Reglage och nivåer

- **Ljusstyrka** styr den kalla kanalen, nivå **0–36**.
- **Värme** styr den varma kanalen, också 0–36 i den vanliga ljusdialogen.
  KOReaders offentliga värme-API behåller skalan 0–100; patchen räknar om.
- Det följer Bigmes separata kanalreglage, inte en färgtemperaturblandare med
  konstant total ljusstyrka. Mer varmt ljus kan också göra skärmen ljusare.
  Andra ljusautomatiseringar använder samma innebörd.
- **Växla/på–av** stänger av båda kanalerna och återställer det föregående paret
  vid nästa tryck. Saknas ett tidigare par gissas ingen standardnivå.
- Mappningen till hårdvaruvärden är olinjär. Nivåerna är inte procent.

När patchen laddas läser den befintliga nivåer utan ljuskommandon eller ändrade
systeminställningar. Befintliga automatiseringar kan fortfarande anropa PowerD.
Ändringar i Bigmes Android-meny läses tillbaka vid efterföljande KOReader-anrop.
Ingen bakgrundspollning införs.

Efter ett lyckat hårdvaruanrop synkas respektive `ColdValue`/`WarmValue` och
`screen_brightness_cold`/`screen_brightness_warm`. När `LightMode=4` uppdateras
även motsvarande värde i den egna ljusförinställningen. Dag-/nattförinställningar
och valt läge skrivs inte om. En profilspecifik KOReader-inställning,
`bigme_frontlight_restore`, minns paret för återaktivering, även över normala
KOReader-omstarter. KOReaders vanliga lagring av inställningar gäller fortfarande.

Batteri, böcker, läsdata, nätverk, rendering, skärmuppdateringsläge och andra
Android-inställningar ändras inte.

## Fel, säkerhet och borttagning

Endast `/dev/lm3630a` och två identifierade OEM-kommandon används: kallt `0x7901`
och varmt `0x7902`, med en pekare till en ägd 32-bitars heltalsarray. Enhetsfilen
öppnas O_WRONLY och stängs direkt efter varje kommando, även vid anropsfel.
Returer och errno kontrolleras. Inga automatiska återförsök eller gissade ioctls.
JNI använder publika `Settings.System` med kontrollerade uppslag, rensade
Java-undantag och lokala referenser. Avknoppade miniatyrprocesser får inte anropa
JNI eller ljushårdvaran.

Ett fel spärrar fortsatta kommandon till omstart i stället för att visa falsk
framgång eller återgå till den verkningslösa generiska ljusvägen. Vid delvis
misslyckade på/av-anrop kan en kanal redan ha ändrats. Ställ önskade nivåer i
Bigmes egen meny och starta om. Varningarna finns på svenska och engelska.

För att ta bort patchen: inaktivera i Patch Manager, eller byt `.lua` till
`.lua.disabled`, och starta om. Befintliga ljusnivåer och användardata återställs inte.

Vid felrapport: ange enhetsegenskaperna, KOReader-version och relevanta rader
märkta `[Bigme frontlight ...]` ur `crash.log`. Publicera inte tokens, bokdata
eller hela privata loggar. Använd inte `settings put` som hårdvarutest: en ändrad
lagrad siffra ensam ändrade inte denna enhets lampor.

## Verifiering och utveckling

Fysiska prov 2026-10-30 från KOReaders vanliga appbehörigheter, utan root eller
säkerhetsändringar: kallt **12→26→12** (råvärden **114→198→114**) och varmt
**13→30→13** (**120→210→120**). Kommandona godtogs och användaren bekräftade både
ljusändringar och återgång. Mappningens 37 nivåer och anropsformatet identifierades
statiskt i ägarens OEM-filer. **Inga proprietära APK:er, bibliotek eller privata
loggar publiceras i repot eller releaserna.**

```sh
make test LUA=luajit
make test LUA=lua
make test-native
make package
```

Testerna hämtar tre orörda KOReader-källor på exakt revision ovan och kontrollerar
deras SHA-256. Riktiga PowerD- och ljusdialogsfunktioner testas med simulerad
hårdvara/JNI/lagring: alla nivåer, kanalavgränsning, på/av, återläsning, skydd,
delvisa fel, JNI-heltal, stängning och bakgrundsprocesser. En egen ofarlig C-stub
kontrollerar LuaJIT-FFI:s pekare, variadiska anrop och errno, utan enhet, riktig
JNI eller kärn-ioctl. ZIP:en innehåller bara patch, dokumentation, licens och
kontrollsummor. Kontrollera med `shasum -a 256 -c SHA256SUMS` efter uppackning.

Ereader-kopian ska vara byte-identisk med den fristående releasen.
Detta är ett oberoende communityprojekt, inte en officiell Bigme-/KOReader-release.
Licens: [MIT](LICENSE). KOReader och testreferenser behåller sina egna licenser.
