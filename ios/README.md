# Agenda inspectorului — aplicația nativă (Swift)

Reproducere 1 la 1 a aplicației web din acest repo. Specificația: `docs/nativ/SPECIFICATIE.md`. Regulile pentru chat: `ios/CLAUDE.md`.

## Structura

| Folder | Ce conține |
|---|---|
| `Agenda.xcodeproj` | Proiectul Xcode (grupuri sincronizate cu folderele: un fișier nou dintr-un folder intră singur în țintă) |
| `Agenda/` | Aplicația (SwiftUI): `UI/` (sistemul vizual din css/app.css: rem, carduri, butoane, ferestre, mesaje), `Ecrane/`, `Depanare/` (capturi, doar în versiunea de dezvoltare) |
| `AgendaWidget/` | Extensia WidgetKit |
| `Comun/` | Cod de interfață comun aplicației și widgetului (culorile din `css/app.css`) |
| `AgendaKit/` | Logica pură, fără UI (pachet Swift): portează `js/model.js`, `js/dates.js`, `js/activitati.js` și `tests/nativ/referinta.mjs` cu aceleași nume |
| `Config/` | Entitlements și Info.plist-ul widgetului |
| `Diferential/` | Verificarea încrucișată web ↔ Swift (`genereaza.mjs`, rulat de `teste.sh`) |
| `Agenda/Navigare/` | Cadrul: bara laterală (fereastra ≥ 1000 pt), bara de jos (vertical), rutele (`Navigare`) |
| `AgendaKit/Sources/AgendaKit/Ecrane/` | Conținutul ecranelor ca modele fără interfață (`modelPanou`, `modelListaObiective`, `modelIstoric`, `modelObiectiv`, `modelRandControl`, filtrele), verificat cu HTML-ul web |
| `Agenda/Nativ/` | Adăugirile native: sincronizarea cu widgeturile, notificările (programare, butoane), cifra de pe iconiță |
| `Comun/Widgeturi/` | Vederile widgeturilor (în codul comun: aplicația le desenează și la capturile de verificare) |

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

Rulează pe Mac, fără simulator (în jur de un minut):

```
ios/teste.sh
```

- vectorii din docs/nativ/vectori/ (rezultatele exacte ale aplicației web);
- testele aplicației web (tests/model.test.js), portate;
- **verificarea încrucișată:** `Diferential/genereaza.mjs` creează ~140 de controale aleatoare (amenzi în weekend și de sărbători, ASI, încărcare, liste înghețate vechi, adăposturi, nereguli vechi, date din versiuni vechi) și le trece prin **codul web**; `DiferentialTests` refac totul în Swift și cer rezultate identice, câmp cu câmp și mesaj cu mesaj. Cere Node.js; altă sămânță: `SAMANTA=123 ios/teste.sh`.
- **ecranele:** `EcraneWebTests` compară conținutul modelelor Swift (texte, pastile cu culoarea lor, filtre cu numărul lor, în ordine) cu HTML-ul generat de `js/views.js` pentru aceleași date: rândul fiecărui control, Obiective și Istoric (7 căutări × 8 combinații de filtre), paginile tuturor obiectivelor, Panoul în 8 zile diferite și fără date.
- Verificat și invers: o greșeală introdusă intenționat (un mesaj, o regulă, pragul roșu al încărcării) pică testele.

Folderul de build e în `~/Library/Caches/AgendaKit-build`: în `~/Documents`, `codesign` refuză pachetul de teste („resource fork, Finder information, or similar detritus not allowed”).

## Salvarea datelor

- `Application Support/Agenda/` din containerul aplicației: `controale/<id>.json` (câte un fișier pe control, același JSON ca în backup), `activitati.json`, `meta.json` (ultimul backup, sărbătorile verificate). Scriere atomică, cu o scurtă pauză după tastare (ca `touch()` din web).
- Un fișier pe control (nu un singur `controls.json`): un control are ~40 KB, deci o atingere nu rescrie toate controalele.
- Backupul: `exportBackup` / `pregatesteImport` / `combina` (AgendaKit/Backup.swift), același format și nume de fișier ca în web.

## Capturi de verificare (versiunea de dezvoltare)

Pornită cu `-captura`, aplicația desenează ecranele întregi (fără derulare), cu datele demonstrative într-un folder temporar (datele utilizatorului nu se ating), în ambele teme, în `Documents/capturi/`:

```
xcrun devicectl device process launch --terminate-existing --device <UDID> ro.cucuta.agenda -- -captura
xcrun devicectl device copy from --device <UDID> --domain-type appDataContainer --domain-identifier ro.cucuta.agenda --source Documents/capturi/setari-luminos.png --destination setari.png
```

## Widgeturile și notificările

- **Datele:** la fiecare schimbare (și la fiecare deschidere), aplicația calculează pentru 21 de zile cifrele Panoului (`cifreZi`) și sarcinile (`sarciniZi`) și le scrie în grupul comun (`Library/Application Support/widget.json`); widgetul face câte o intrare pe zi, deci se schimbă singur la miezul nopții.
- **„Cifre”** (specificația §5): cerc, dreptunghi, rând, mic, mediu, mare (+ termenele următoare, „depășit” la cele trecute).
- **„Sarcini”** (decizia utilizatorului): rând, dreptunghi, mic (3), mediu (5), mare (până la 10, pe grupe), foarte mare (iPad: trei coloane, cu mesajul fiecărui termen). Aceleași elemente și texte ca secțiunile Panoului; ordinea după urgență = aceeași regulă ca cifra de pe iconiță (`sarciniDupaUrgenta`). Widgetul arată câte rânduri încap (`ViewThatFits`) și „+N” pentru rest; pastilele de stadiu nu se scurtează niciodată.
- **Notificările** (`planNotificari`): cele din referință (`notificari`, verificate pe vectori) + rezumatul zilei (zilele lucrătoare, ora aleasă, implicit 07:45) + actualizări fără mesaj ale cifrei de pe iconiță în zilele în care se schimbă fără altă notificare; cel mult 60 (4 locuri pentru cele amânate). Categoriile se opresc din Setări → Notificări (preferință a dispozitivului, nu intră în backup).
- **Butoanele:** „Amână 1 oră”, „Amână până mâine” (mâine la 08:00; copia rămâne la reprogramări), la activități și „Efectuată” (marchează activitatea efectuată, ca butonul din web). Verificate pe iPad (27.09.2026).

## Unelte de verificare (doar în versiunea de dezvoltare)

- `ios/Depanare-captura.sh <UDID> <folder>`: capturile ecranelor și ale tuturor widgeturilor, în ambele teme, cu datele demonstrative (datele utilizatorului nu se ating).
- Pornire cu `-proba-notificari`: două notificări de probă (activitatea de probă nu există); butoanele apăsate se notează în `Documents/depanare/actiuni.log`. La pornirea obișnuită, urmele probei se șterg.
- `Documents/depanare/notificari.json`: notificările programate după ultima sincronizare (id, ora, permisiunea, cele livrate).
- Atenție: aplicația instalată din Xcode e versiunea de dezvoltare; uneltele de mai sus nu apar în interfață (doar cu argumente la pornire).

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

## De hotărât înainte de final

- **Expirarea la 7 zile (cont gratuit):** după final, aplicația nativă e singura aplicație de lucru; dacă expiră pe teren, nu se deschide până la reinstalare (datele rămân). Variante propuse (27.09.2026): cont Apple Developer plătit (1 an, TestFlight), reinstalare automată de pe Mac, script cu dublu-clic. Utilizatorul a amânat decizia; până atunci, reinstalare la fiecare sesiune. (Aplicațiile Mac nu au această limită; cele de iPad / iPhone, da.)

## Stadiul (etapele din SPECIFICATIE.md §6)

- [x] **1. Proiectul** (26.09.2026): aplicație + widget, semnate cu contul gratuit, instalate pe iPad Air 11" (iPadOS 27). App Groups acceptat; proba de legătură (`Library/Application Support/proba.json` în grupul comun) scrisă de aplicație pe iPad. Ecranul e temporar (`EcranPornire`), la fel widgetul de probă.
- [x] **2. Modelul, catalogul, logica pură** (26.09.2026): `AgendaKit` portează js/dates.js, js/model.js (fără UI), js/activitati.js (fără HTML) și tests/nativ/referinta.mjs, cu aceleași nume de funcții. **65 de teste, toate trec:** 22 pe vectori (date, sărbători 2024–2040, termene, sume, normalizare, setul demonstrativ întreg fără HTML, widgeturi și notificări; fișierele JSON se rescriu identic, octet cu octet) + 43 portate din tests/model.test.js. Verificat și invers: o greșeală introdusă intenționat pică testele.
- [x] **3. Stocarea, backupul, datele demonstrative** (27.09.2026): salvarea pe disc, export / import (Combină / Înlocuiește tot) compatibil cu web, datele demonstrative (identice cu web), ecranul Setări (Backup, Stocare, Zonă periculoasă) + caseta temporară de verificare. **82 de teste** (inclusiv verificarea încrucișată pe 4 seturi aleatoare, ~570 de controale). De făcut de utilizator: importul backupului real și compararea cifrelor cu Panoul web.
- [x] **3b. Widgeturile și notificările** (27.09.2026, adus înainte la cererea utilizatorului): „Cifre” și „Sarcini” în toate mărimile, notificări cu rezumatul zilei, butoane, setări pe categorii, cifra de pe iconiță. 87 de teste. Verificat pe iPad cu datele reale (widgeturi pe ecranul principal, 14 notificări programate la ora corectă, butoanele Amână / Efectuată).
- [x] **4. Panoul, Obiectivele, Istoricul, pagina obiectivului** (27.09.2026): cadrul (bara laterală / bara de jos, ceasul, cifrele de pe meniu, Backup rapid), Panoul complet (casetele, secțiunile, activitățile de confirmat cu Efectuată / Anulată, mementoul sărbătorilor), Obiectivele și Istoricul cu căutare (text și dată), tipuri și cele 10 filtre, pagina obiectivului (date, GPS cu hărți, statistici, istoric). 93 de teste. Provizoriu până la etapele următoare: „Control nou” și deschiderea unui control (editorul, etapa 5), „Reprogramează” (etapa 6), Calendarul (etapa 6), Ghidul (etapa 8).
- [ ] 5. Editorul controlului
- [ ] 6. Calendarul, activitățile, raportul lunii
- [ ] 7. Fișa, Text PV, tipărirea și partajarea
- [ ] 8. Setările, Ghidul, mărimea textului, temele
- [x] 9. Widgeturile și notificările (făcute ca 3b; atingerea widgetului va deschide Panoul după etapa 4)
- [ ] 10. iPhone
- [ ] 11. Auditul final
