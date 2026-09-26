# Agenda inspectorului — aplicația nativă (Swift)

Reproducere 1 la 1 a aplicației web din acest repo. Specificația: `docs/nativ/SPECIFICATIE.md`. Regulile pentru chat: `ios/CLAUDE.md`.

## Structura

| Folder | Ce conține |
|---|---|
| `Agenda.xcodeproj` | Proiectul Xcode (grupuri sincronizate cu folderele: un fișier nou dintr-un folder intră singur în țintă) |
| `Agenda/` | Aplicația (SwiftUI) |
| `AgendaWidget/` | Extensia WidgetKit |
| `Comun/` | Cod de interfață comun aplicației și widgetului (culorile din `css/app.css`) |
| `AgendaKit/` | Logica pură, fără UI (pachet Swift): portează `js/model.js`, `js/dates.js`, `js/activitati.js` și `tests/nativ/referinta.mjs` cu aceleași nume |
| `Config/` | Entitlements și Info.plist-ul widgetului |

Datele comune (`docs/nativ/date/`: catalog, ghid, sărbători, stilurile fișei) intră în aplicație direct din folderul lor, fără copii. Excepție: pictograma, copiată în `Agenda/Assets.xcassets/AppIcon.appiconset/` (un catalog de resurse cere fișierul înăuntru); dacă se schimbă `docs/nativ/date/icon-1024.png`, se copiază din nou.

## Modelul de date în Swift

- Datele sunt **exact JSON-ul aplicației web** (`JSONValue` / `JSObiect`, cu ordinea cheilor păstrată), citit și scris ca `JSON.parse` / `JSON.stringify`. `Control`, `Neregula`, `Constructie`, `Activitate`… sunt acces cu tip peste acest JSON, nu copii: cheile necunoscute rămân, backupul trece dus-întors fără pierderi.
- Catalogul (`catalog.json`) se încarcă la pornire (`Catalog.incarca`); `K` = catalogul curent. Rândurile de nereguli, dotările, actele, termenele, lunile vin din el, nu din Swift.
- Transcrise în Swift (nu sunt în catalog): textele funcțiilor, glosarul căutării (`GLOSAR`), numele scurte ale sărbătorilor (`SARB_SCURT`), lista sărbătorilor legale (`sarbatoriLegale`, verificată cu sarbatori.json).
- Ceasul, fusul orar și numerele aleatoare trec prin `Ceas` (testele le fixează la 15.10.2026, 09:00, ora României).

## Identificatori

- aplicația: `ro.cucuta.agenda`
- widgetul: `ro.cucuta.agenda.widget`
- grupul comun (App Group): `group.ro.cucuta.agenda` — **acceptat de contul gratuit** (verificat 26.09.2026: profilul „iOS Team Provisioning Profile” conține grupul, la aplicație și la widget)
- echipa: `C6B357FN4W` (Personal Team), setată la nivel de proiect

## Testele

Testele pe vectori rulează pe Mac, fără simulator:

```
ios/teste.sh
```

Folderul de build e în `~/Library/Caches/AgendaKit-build`: în `~/Documents`, `codesign` refuză pachetul de teste („resource fork, Finder information, or similar detritus not allowed”).

## Compilare și instalare pe iPad (din Terminal)

```
cd ios
xcodebuild -project Agenda.xcodeproj -scheme Agenda -destination 'id=<UDID>' -allowProvisioningUpdates -allowProvisioningDeviceRegistration build
xcrun devicectl device install app --device <UDID> ~/Library/Developer/Xcode/DerivedData/Agenda-*/Build/Products/Debug-iphoneos/Agenda.app
xcrun devicectl device process launch --device <UDID> ro.cucuta.agenda
```

`xcrun devicectl list devices` arată UDID-ul. Din Xcode: destinația iPad-ul, apoi ▶︎.

## Contul gratuit (Personal Team) — limite

- Aplicația instalată din Xcode se oprește după **7 zile**; se reinstalează (▶︎ sau comenzile de mai sus), datele rămân.
- Maximum **3 aplicații** instalate așa pe un dispozitiv; maximum 10 identificatori de aplicație noi pe 7 zile (aplicația + widgetul = 2).
- La prima instalare: Configurări → General → VPN și gestionare dispozitive → aprobați dezvoltatorul.
- Mod dezvoltator activat pe dispozitiv (Configurări → Confidențialitate și securitate).
- La prima semnare, macOS cere parola de login a Mac-ului pentru cheia certificatului („Permite întotdeauna”).

## Deciziile utilizatorului (față de specificație)

- **26.09.2026 — ordinea:** widgeturile și notificările se construiesc **imediat după etapa 3** (cu backupul real importat), nu în etapa 9.
- **26.09.2026 — widgeturile:** două familii în galerie:
  - **„Cifre”**, ca în specificație: cerc, dreptunghi, rând, mic, mediu, mare;
  - **„Sarcini”** (nou), cu tot mai multe detalii de la o mărime la alta: rând (cea mai urgentă sarcină), dreptunghi (primele 2), mic (3 sarcini: ce + obiectiv + termen), mediu (5, cu stadiul colorat), mare (10, pe grupe: Amenzi / ASI / Încărcare / Neîncheiate / PV / De confirmat), foarte mare doar pe iPad (lista completă, ca în Panou, cu mesajul fiecărui termen).
- **26.09.2026 — notificările:**
  - termenele, ca în specificație;
  - **rezumatul zilei** (nou): dimineața, în zilele lucrătoare, ce mai e de făcut; atingerea deschide Panoul;
  - **butoane în notificare** (nou): „Amână 1 oră” / „Amână până mâine”; la activități, „Efectuată”;
  - **setări pe categorii** (nou): activare pe categorii și ora rezumatului.
- **26.09.2026 — după finalizare,** utilizatorul lucrează doar în aplicația nativă. Aplicația web rămâne pe GitHub pentru actualizări (sursa promptelor din docs/nativ/ACTUALIZARI.md). Mutarea datelor: un backup din web, importat o dată în nativ.

## Stadiul (etapele din SPECIFICATIE.md §6)

- [x] **1. Proiectul** (26.09.2026): aplicație + widget, semnate cu contul gratuit, instalate pe iPad Air 11" (iPadOS 27). App Groups acceptat; proba de legătură (`Library/Application Support/proba.json` în grupul comun) scrisă de aplicație pe iPad. Ecranul e temporar (`EcranPornire`), la fel widgetul de probă.
- [x] **2. Modelul, catalogul, logica pură** (26.09.2026): `AgendaKit` portează js/dates.js, js/model.js (fără UI), js/activitati.js (fără HTML) și tests/nativ/referinta.mjs, cu aceleași nume de funcții. **65 de teste, toate trec:** 22 pe vectori (date, sărbători 2024–2040, termene, sume, normalizare, setul demonstrativ întreg fără HTML, widgeturi și notificări; fișierele JSON se rescriu identic, octet cu octet) + 43 portate din tests/model.test.js. Verificat și invers: o greșeală introdusă intenționat pică testele.
- [ ] 3. Stocarea, backupul, datele demonstrative
- [ ] 4. Panoul, Obiectivele, Istoricul, pagina obiectivului
- [ ] 5. Editorul controlului
- [ ] 6. Calendarul, activitățile, raportul lunii
- [ ] 7. Fișa, Text PV, tipărirea și partajarea
- [ ] 8. Setările, Ghidul, mărimea textului, temele
- [ ] 9. Widgeturile și notificările
- [ ] 10. iPhone
- [ ] 11. Auditul final
