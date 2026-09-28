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
| `AgendaKit/Sources/AgendaKit/Editor/` | Editorul controlului, fără interfață: acțiunile (`Editor.click` / `input` / `schimbaData`…, aceleași nume și date ca `data-act` din web), Anulează / Refă (`IstoricEditor`), căile de date (`seteazaLaCale`), modelele ecranului (`modelEditor`), fereastra Control nou |
| `Agenda/Editor/` | Editorul (SwiftUI): antetul, „Ce mai aveți de făcut”, taburile fixe, tabul Obiectiv (construcții, dotări, GRF, GPS, adăposturi), Acte, Nereguli / Planuri / PC (categorii, rânduri, amenzi, ASI, verificări), barele fixe la derulare (`Lipici`), ferestrele, citirea poziției |

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
- **editorul:** `Diferential/editor.mjs` rulează aplicația web originală (js/app.js) într-un DOM simulat și face pași aleatori în editor, pe controale aleatoare: apasă butoanele de pe ecran (toate acțiunile, echilibrat), scrie în câmpuri, caută, schimbă taburile, anulează / reface, confirmă sau renunță la ferestre. După fiecare pas înregistrează controlul, ecranul (ca șir de „jetoane”: texte, pastile, câmpuri cu valoarea lor, butoane apăsate / dezactivate, stări), mesajele, ferestrele, istoricul. `EditorWebTests` reia pașii în Swift și cere același rezultat la fiecare pas (60 × 40 de pași; verificat pe 4 semințe, ~8.600 de pași). La fel fereastra „Control nou” (13 căutări).
- **fișa controlului:** HTML-ul (`fisaMarkup`) și numele fișierului identice cu web: cele 7 controale din `demo.json` și toate controalele aleatoare (~144 la fiecare rulare). „Marchează-le trecute în PV” (Text PV) intră în pașii editorului.
- **ghidul:** cuprinsul și capitolele (HTML identic cu `viewGhid` din web), pe 12 căutări; capitolele vin din `ghid.json`, iconițele din `AgendaKit/Iconite.swift` (aceleași trasee ca `js/ui.js`).
- **raportul lunii:** HTML-ul (`raportMarkup`) identic, caracter cu caracter, cu cel din web: vectorul `demo.json` și 30 de rapoarte aleatoare trecute prin codul web.
- **calendarul:** grila, zilele libere, termenele și ziua selectată, față de `viewCalendar` din web (70 de luni / zile, ca șir de jetoane cu clasele de stare).
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

- La pornire se pot da preferințele, fără să se salveze: `-agenda-font mic|mediu|mare`, `-agenda-theme auto|light|dark`; `-fereastra activitate|controlnou|pv` deschide o fereastră.
- Pornită cu `-demo`: aplicația lucrează cu datele demonstrative într-un folder temporar, fără widgeturi și notificări (datele utilizatorului nu se ating; la pornirea obișnuită totul revine). Cu `-ruta demo:opec|loc:<tab>[:<element>]` se deschide editorul pe un control demonstrativ (ex. `-ruta demo:opec:nereguli:d`), pentru capturi reale de ecran (`xcrun devicectl device capture screenshot --device <UDID> --destination x.png`). **După verificare, aplicația se repornește fără argumente.**

## Widgeturile și notificările

- **Datele:** la fiecare schimbare (și la fiecare deschidere), aplicația calculează pentru 21 de zile cifrele Panoului (`cifreZi`) și sarcinile (`sarciniZi`) și le scrie în grupul comun (`Library/Application Support/widget.json`); widgetul face câte o intrare pe zi, deci se schimbă singur la miezul nopții.
- **„Cifre”** (specificația §5): cerc, dreptunghi, rând, mic, mediu, mare (+ termenele următoare, „depășit” la cele trecute).
- **„Sarcini”** (decizia utilizatorului): rând, dreptunghi, mic (3), mediu (5), mare (până la 10, pe grupe), foarte mare (iPad: trei coloane, cu mesajul fiecărui termen). Aceleași elemente și texte ca secțiunile Panoului; ordinea după urgență = aceeași regulă ca cifra de pe iconiță (`sarciniDupaUrgenta`). Widgetul arată câte rânduri încap (`ViewThatFits`) și „+N” pentru rest; pastilele de stadiu nu se scurtează niciodată.
- **Notificările** (`planNotificari`): termenele după regulile alese de utilizator (`notificariDupaReguli`, AgendaKit/RegulileNotificarilor.swift) + sărbătorile legale (ca în referință) + rezumatul zilei (zilele lucrătoare, ora aleasă, implicit 07:45) + actualizări fără mesaj ale cifrei de pe iconiță în zilele în care se schimbă fără altă notificare; cel mult 60 (4 locuri pentru cele amânate). Preferințele sunt ale dispozitivului (nu intră în backup).
- **Regulile (decizia din 27.09.2026), din Setări → Notificări → „Reguli”:** ora fiecărei categorii; treptele „în ultimele N zile: zilnic / la fiecare N zile / la fiecare N ore în programul de lucru” (implicit 08:00–16:00); amintirea zilnică după termen (zilele lucrătoare, până la rezolvare, programată cu 2 săptămâni înainte); minutele dinaintea activităților. Implicit: ASI la fiecare 30 de zile, zilnic în ultimele 5, la 3 ore în ultimele 2 (și pentru cele 5 zile ale pierderii valabilității); încărcarea zilnic, penultima zi la 3 ore, ultima zi la 2 ore, **în zile lucrătoare** (termenul e în zile lucrătoare); amenzile ca în referință (schimbarea stadiului, ziua dinainte și ultima zi pentru ANAF); activitățile la 08:00 în ziua lor și cu 30 de minute înainte de oră. Fereastra arată următoarele notificări calculate din datele reale. Teste: `NotificariTests` (zilele și orele calculate de mână; regulile neschimbate = referința).
- **Blocarea cu Touch ID** (decizia utilizatorului, 27.09.2026; `Agenda/Nativ/Blocare.swift`): comutator în Setări → „Blocarea aplicației” (preferință a dispozitivului, implicit oprită; la pornire se verifică o dată amprenta). Pornită, aplicația cere Touch ID / Face ID / codul la fiecare deschidere și la fiecare revenire din fundal, fără temporizator; ecranul de blocare acoperă tot (și în comutatorul de aplicații). Verificare vizuală: `-demo -arata-blocarea`.
- **Fotografiile constatărilor** (decizia utilizatorului, 27.09.2026; AgendaKit/Fotografii.swift, Agenda/Editor/Fotografii.swift): pe rândurile constatate, „Fotografii (N)” le arată / ascunde (**ascunse implicit**), „Adaugă fotografie” = camera sau galeria (până la 10 odată); atingerea deschide fotografia (mărire cu două degete, „Șterge” cu confirmare); adăugarea și ștergerea au pas în Anulează / Refă.
  - **Datele:** în control doar `nereguli[].fotografii = [{ id, data }]` (web păstrează câmpul la normalizare, dar nu afișează fotografiile); imaginile: `Application Support/Agenda/fotografii/<id>.jpg`, JPEG micșorat la 1600 px (~250 KB).
  - **Backupul:** cheia în plus `fotografii` = { id: JPEG base64 }, doar dacă există (web o ignoră; un backup fără fotografii e identic cu cel din web). La import, numele de fișier se verifică (`idFotografieValid`). Atenție: un backup făcut din web nu are fișierele.
  - **Fișa:** la final, „Fotografii”, pe nereguli (litera, denumirea, data), 2 pe rând; la tipărire pe pagină nouă.
  - **Fișierele nefolosite** (rând șters, Anulează după ieșire, „Înlocuiește tot”): se șterg la pornire după **30 de zile de când au rămas nefolosite** (`fotografii/nefolosite.json`), nu imediat.
  - Verificare: `ios/Depanare-tur.sh … "foto,foto-rand,foto-fisa"` (două imagini de probă pe rândul „d”).
- **Vibrația la atingere** (`Agenda/Nativ/Vibratie.swift`): o confirmare discretă la marcările din editor (Conform / Constatat / NEC, DA / NU / NEC, bife, construcțiile constatării). Doar pe iPhone: iPad-ul nu are motor de vibrație.
- **Reîmprospătarea în fundal** (`BGAppRefreshTask`, `Config/Agenda-Info.plist`): o dată pe zi, iOS alege momentul; reprogramează notificările și fără deschiderea aplicației.
- **Butoanele:** „Amână 1 oră”, „Amână până mâine” (mâine la 08:00; copia rămâne la reprogramări), la activități și „Efectuată” (marchează activitatea efectuată, ca butonul din web). Verificate pe iPad (27.09.2026).

## Unelte de verificare (doar în versiunea de dezvoltare)

- `ios/Depanare-captura.sh <UDID> <folder>`: capturile ecranelor și ale tuturor widgeturilor, în ambele teme, cu datele demonstrative (datele utilizatorului nu se ating).
- Pornire cu `-proba-notificari`: două notificări de probă (activitatea de probă nu există); butoanele apăsate se notează în `Documents/depanare/actiuni.log`. La pornirea obișnuită, urmele probei se șterg.
- `Documents/depanare/notificari.json`: notificările programate după ultima sincronizare (id, ora, permisiunea, cele livrate).
- `ios/Depanare-tur.sh <UDID> <folder> [orizontal|vertical] [mărimi] [teme] [ecrane]`: turul ecranelor pentru auditul vizual. Aplicația (cu `-demo -tur <eticheta>`) trece singură prin toate ecranele și ferestrele, derulează pagină cu pagină și salvează fiecare pagină ca imagine (`<folder>/<mărime>-<temă>-<orientare>/NN-<ecran>-pK.png`); scriptul rotește iPad-ul, aduce imaginile pe Mac și repornește aplicația normal. Ex.: `ios/Depanare-tur.sh <UDID> ~/Desktop/tur vertical "mic" "light dark" "panou,opec-nereguli"`.
- Pornire cu `-demo -miezul-noptii`: ceasul folosit la calcule pornește azi la 23:59:45 (trecerea în ziua următoare, cu aplicația deschisă).
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
- **Reinstalarea cu dublu-clic** (decizia utilizatorului, 27.09.2026): `ios/Reinstaleaza-Agenda.command` (scurtătură pe Birou: „Reinstalează Agenda”). Găsește iPad-ul conectat, mută deoparte profilurile vechi ale aplicației (`~/Library/Caches/Agenda-profile-vechi`; altfel Xcode le refolosește și data de expirare nu se mută), compilează versiunea finală (Release, fără uneltele de verificare) din folderul curent, o instalează, o pornește și arată noua dată de expirare. Dacă o etapă eșuează, instalarea de pe iPad rămâne neatinsă. Jurnalul compilării: `~/Library/Caches/Agenda-reinstalare/jurnal.txt`.
- **Avertizarea din aplicație:** data de expirare se citește din profilul inclus (`embedded.mobileprovision`); cu 2 zile înainte, notificare la 09:00 (categoria „Expirarea instalării”, loc rezervat între cele 60) și mesaj în Panou; în Setări → Actualizări, data până la care e valabilă. Verificare: `-demo -expira-peste <ore>`.
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
- **27.09.2026 — expirarea la 7 zile:** script de reinstalare cu dublu-clic pe Mac + avertizare în aplicație cu 2 zile înainte.
- **27.09.2026 — după audit:** notificări configurabile (ASI, încărcare, activități, termene depășite, orele), blocare cu Touch ID (comutator în Setări, la fiecare deschidere / revenire), fotografii la constatări (ascunse implicit, în backup și în Fișă), culoare pentru „Organizare protecție civilă” (albastru-cer, în web și în nativ), vibrație la atingere (doar iPhone: iPad-ul nu are motor de vibrație).
- **26.09.2026 — după finalizare,** utilizatorul lucrează doar în aplicația nativă. Aplicația web rămâne pe GitHub pentru actualizări (sursa promptelor din docs/nativ/ACTUALIZARI.md). Mutarea datelor: un backup din web, importat o dată în nativ.

## Stadiul (etapele din SPECIFICATIE.md §6)

- [x] **1. Proiectul** (26.09.2026): aplicație + widget, semnate cu contul gratuit, instalate pe iPad Air 11" (iPadOS 27). App Groups acceptat; proba de legătură (`Library/Application Support/proba.json` în grupul comun) scrisă de aplicație pe iPad. Ecranul e temporar (`EcranPornire`), la fel widgetul de probă.
- [x] **2. Modelul, catalogul, logica pură** (26.09.2026): `AgendaKit` portează js/dates.js, js/model.js (fără UI), js/activitati.js (fără HTML) și tests/nativ/referinta.mjs, cu aceleași nume de funcții. **65 de teste, toate trec:** 22 pe vectori (date, sărbători 2024–2040, termene, sume, normalizare, setul demonstrativ întreg fără HTML, widgeturi și notificări; fișierele JSON se rescriu identic, octet cu octet) + 43 portate din tests/model.test.js. Verificat și invers: o greșeală introdusă intenționat pică testele.
- [x] **3. Stocarea, backupul, datele demonstrative** (27.09.2026): salvarea pe disc, export / import (Combină / Înlocuiește tot) compatibil cu web, datele demonstrative (identice cu web), ecranul Setări (Backup, Stocare, Zonă periculoasă) + caseta temporară de verificare. **82 de teste** (inclusiv verificarea încrucișată pe 4 seturi aleatoare, ~570 de controale). De făcut de utilizator: importul backupului real și compararea cifrelor cu Panoul web.
- [x] **3b. Widgeturile și notificările** (27.09.2026, adus înainte la cererea utilizatorului): „Cifre” și „Sarcini” în toate mărimile, notificări cu rezumatul zilei, butoane, setări pe categorii, cifra de pe iconiță. 87 de teste. Verificat pe iPad cu datele reale (widgeturi pe ecranul principal, 14 notificări programate la ora corectă, butoanele Amână / Efectuată).
- [x] **4. Panoul, Obiectivele, Istoricul, pagina obiectivului** (27.09.2026): cadrul (bara laterală / bara de jos, ceasul, cifrele de pe meniu, Backup rapid), Panoul complet (casetele, secțiunile, activitățile de confirmat cu Efectuată / Anulată, mementoul sărbătorilor), Obiectivele și Istoricul cu căutare (text și dată), tipuri și cele 10 filtre, pagina obiectivului (date, GPS cu hărți, statistici, istoric). 93 de teste. Provizoriu până la etapele următoare: „Control nou” și deschiderea unui control (editorul, etapa 5), „Reprogramează” (etapa 6), Calendarul (etapa 6), Ghidul (etapa 8).
- [x] **5. Editorul controlului** (27.09.2026): fereastra „Control nou” (obiective găsite, date preluate din ultimul control), antetul (Text PV / Fișa: etapa 7), „Ce mai aveți de făcut”, taburile cu progresul, tabul Obiectiv (date, perioada, încheiere cu verificarea omisiunilor, redeschidere, încărcarea după încheiere, construcțiile cu dotări DA / NU / NEC, centrala, GRF / NSI, GPS la cerere, adăposturile), Acte, Nereguli / Planuri și SVSU / Protecție civilă (căutare, filtre, „Restul conform” cu confirmare, categorii restrânse, rânduri restrânse, verificări pe construcție, construcțiile constatării, PV, amendă cu termene, neregulă veche, gravă, sigiliu, ASI, rânduri adăugate), Anulează / Sus / Refă, barele fixe la derulare. **96 de teste**, inclusiv reluarea pas cu pas a editorului web. Verificat pe iPad (ecran întreg și fereastră). Adaptare nativă: fereastra „Activați localizarea” are pașii pentru aplicație (nu pentru Safari) și butonul Setări.
- [x] **6. Calendarul, activitățile, raportul lunii** (27.09.2026): Calendarul (an / lună / Azi, grila cu controalele, activitățile, zilele libere și punctele termenelor, legenda, ziua selectată cu controalele, termenele, activitățile, Control nou / Activitate nouă în ziua aleasă), fereastra activității (tip, descriere, perioadă, oră, obiectiv, stare, observații, ștergere; Reprogramează din Panou), Efectuată / Anulată, Planul lunar (raportul ca document, lunile vecine, Tipărește / PDF, Partajează fișierul). **98 de teste.** Verificat pe iPad, față de web.
- [x] **7. Fișa, Text PV, tipărirea și partajarea** (27.09.2026): Fișa controlului ca document (Tipărește / PDF, Partajează fișierul), fereastra Text PV (doar netrecute, cu acte, Copiază, Partajează, Marchează-le trecute în PV). Tipărirea: `UIPrintInteractionController` cu un `WKWebView` ascuns; documentele au stilurile din `stiluri-fisa.css`. **100 de teste.** Verificat pe iPad.
- [x] **8. Setările, Ghidul, mărimea textului, temele** (27.09.2026): mărimea textului (Mic / Mediu / Mare, scalează tot) și tema (Automat / Luminoasă / Întunecată), cu aceleași chei ca în web; versiunea, regulile termenelor, sărbătorile legale (cu „Am verificat lista”); Ghidul (căutare, cuprins, capitole, `#/ghid/<capitol>`) cu HTML-ul și stilurile din web. Adaptare nativă: la „Actualizări”, fără „Verifică acum” (aplicația se actualizează prin reinstalare). Așezarea pe rânduri: elementele își păstrează lățimea naturală (un text nu se mai rupe din rotunjire), iar cele mai late decât rândul se rup ca în web. **101 teste.**
- [x] 9. Widgeturile și notificările (făcute ca 3b; atingerea widgetului va deschide Panoul după etapa 4)
- [x] **11. Auditul final, pe iPad** (27.09.2026; iPhone-ul rămâne pentru etapa 10):
  - **calculele:** testele pe 30 de semințe aleatoare (~4.200 de controale și ~72.000 de pași în editor, trecuți prin codul web și prin Swift); o diferență găsită și corectată: bifele „Documentație prezentată” / „Pierderea valabilității constatată” nu completau data cu ziua de azi (calea se termina într-un rând: `nereguli.@a`), acum ca în web, cu test dedicat;
  - **ziua nouă:** cu aplicația deschisă (sau lăsată în fundal) peste miezul nopții, ecranele își recalculează termenele, calendarul trece pe azi, notificările și widgeturile se reprogramează (ca `tick()` / `dayChanged()` din web, la 15 secunde); verificat pe iPad cu `-miezul-noptii`;
  - **aspectul:** turul complet (`Depanare-tur.sh`: 22 de ecrane și ferestre, derulate până jos) × 3 mărimi × 2 teme × 2 orientări, comparat cu web; corectate: textele scurte din butoane / taburi care se rupeau deși aveau loc („Acte & evidențe”), antetele cu butoane pe vertical (Panou, Fișa, Planul lunar: butoanele pe rândul titlului doar dacă încap, ca `flex-wrap`); **102 teste.**
- [ ] 10. iPhone (după decizia utilizatorului: iPhone conectat la Mac sau simulator)
