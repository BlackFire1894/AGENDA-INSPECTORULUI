# Jurnalul proiectului „Agenda inspectorului”

Memoria proiectului: ce face aplicația, de ce arată și funcționează așa, ce s-a decis și ce s-a respins.
**Se citește la începutul oricărei sesiuni de lucru și se completează la fiecare versiune nouă** (regulă în `CLAUDE.md`).

Ultima actualizare: v1.23.0 — 25.09.2026.

---

## 1. Contextul

- **Utilizatorul:** inspector de prevenire ISU (securitate la incendiu, protecție civilă). Lucrează pe **iPad Air 11" (M4)**, pe teren, în mișcare prin construcție, împreună cu reprezentantul obiectivului. Comunică în română.
- **Aplicația:** PWA fără build (HTML / CSS / JS module), publicată cu GitHub Pages din `main`: repo `BlackFire1894/AGENDA-INSPECTORULUI`. Funcționează offline; datele stau **doar pe iPad** (IndexedDB); singura copie de siguranță e backupul (fișier JSON).
- **Fluxul de lucru:**
  1. Modificările se fac pe branch (`claude/objectives-control-app-ubn3fc`).
  2. Se deschide un PR; utilizatorul îl aprobă cu Merge.
  3. GitHub Pages publică `main`.
  4. iPad-ul primește actualizarea prin service worker („Versiune nouă disponibilă → Actualizează”).
- **Cum preferă utilizatorul să lucrăm:**
  - rol de mentor exigent: onest, corect, verificat;
  - greșelile se spun direct, fără laude inutile;
  - propunerile se fac **sub formă de întrebări cu variante**, nu ca text lung („wall of text”);
  - **nicio modificare de interfață fără aprobare**; defectele se corectează direct și se raportează;
  - raport final scurt, în română, cu tonul formal al aplicației.

## 2. Reguli permanente (detalii în `CLAUDE.md`)

- **Versiunea:** la fiecare publicare, `APP_VERSION` (`js/version.js`) = `VERSION` (`sw.js`), în format semver.
- **Service worker:** fișierele noi din `js/`, `css/` și `icons/` intră în `ASSETS` din `sw.js`.
- **Date vechi:** orice câmp nou se completează în `normalizeControl()`; structura datelor e descrisă în `docs/MODEL_DATE.md`.
- **Controalele încheiate** își păstrează lista de nereguli (`catalog`).
  - Un rând nou în listă primește `din: <schemă>`; un rând scos primește `retrasDin`.
  - O cheie nu se refolosește niciodată.
- **CSS:**
  - dimensiunile doar în `rem` (bază 18 / 16,5 / 15 px pentru Mare / Mediu / Mic);
  - țintele de atingere au cel puțin 44 px (`max(44px, …)`);
  - câmpurile de text au font de cel puțin 16 px (altfel iOS mărește pagina).
- **Ton formal** („dumneavoastră”: „Completați…”, „Ștergeți…?”). Butoanele rămân nume de acțiuni („Anulează”, „Șterge”).
- **Ghidul aplicației** (`js/help.js`) se actualizează odată cu funcțiile pe care le descrie.
- **Principiul de afișare (v1.15):** informația se citește direct, fără atingeri.
  - Nimic ascuns în `title` (pe iPad nu apare).
  - Fără buline cu cifre neexplicate, fără prescurtări obscure, fără text mic în colț.
  - Curat, dar nu discret.
- **Teme și orientări:** temă luminoasă și întunecată; vertical (bara de jos) și orizontal (bara laterală, de la 1000 px).

## 3. Cronologia versiunilor

| Versiune | Ce a adus |
|---|---|
| 1.0–1.1 | PWA de bază: controale, obiective, acte, nereguli, amenzi, Panou, Calendar, Istoric; NEC = „nu este cazul”; mesajul „Versiune nouă disponibilă” |
| 1.2 | Mărimea textului Mic / Mediu / Mare (totul în `rem`) |
| 1.3 | Tipul Localitate: taburile Planuri și SVSU, Protecție civilă; nereguli pe categorii |
| 1.4 | Acte despre exerciții; construcția neregulii; observații pe mai multe rânduri; seria amenzii; anul în calendar |
| 1.5 | Neregulă veche; Text PV; Fișa controlului (PDF); avertizare pentru termenele în zile nelucrătoare; Backup rapid |
| 1.6 | „Ce mai aveți de făcut”; Restul conform; verificare la încheiere; ghid |
| 1.7 | Nereguli noi; detectori autonomi; **nereguli grave la NU** la dotări (G1–G12) |
| 1.8 | Adresă, localitate, **coordonate GPS pe fiecare construcție** (doar la cerere, fără urmărire) |
| 1.9 | Căutare în nereguli; o neregulă în mai multe construcții; tema aleasă manual; GRF/NSI pe construcție (G13: GRF/NSI V peste parter); sigiliu; confirmare la „Restul conform” |
| 1.10 | Nereguli ah (fără ASI) și ai (lucrări fără aviz), legate de NU la ASI / AVIZ |
| 1.11 | Anulează / Refă; NEC; verificări defalcate pe construcții, cu date; stare „completat” pe categorii |
| 1.12 | Bare de nereguli restrângibile, fixe la derulare; Anulează / Sus / Refă; actele funcționează ca neregulile; **lista înghețată la încheiere (`catalog`)**; Ghidul aplicației în locul butoanelor „?” |
| 1.12.1 | Bara categoriei arată constatările netrecute în PV |
| 1.13 | Taburi evidențiate, cu bară de progres; cod de culori pe casetele Panoului |
| 1.14 | Interfață mai curată: Panou aerisit; ✓ ✗ NEC pe bara rândului; „+ Obs.”; meniul ⋯; bara laterală compactă; ton formal |
| 1.15 | Informația se citește direct (cuvinte în loc de buline); **audit numeric** (532 de verificări, 8 defecte corectate); Ghidul rescris pentru utilizator nou |
| 1.16 | **Încărcarea după încheiere** (aplicația ISU + documentul), cu termen de 3 zile lucrătoare; **ASI: 5 zile pentru constatarea pierderii valabilității**; caseta „De încărcat” în Panou |
| 1.17 | Recomandarea **primei zile lucrătoare** când un termen cade într-o zi liberă; **verificarea anuală a sărbătorilor legale** (Panou, din 1 decembrie; lista în Setări); acest jurnal; testele din browser mutate în repo (`tests/e2e`) |
| 1.18 | **Planul lunar**: activități introduse manual în Calendar (7 tipuri, dată / interval, oră, obiectiv, stare planificată / efectuată / anulată); „Activități de confirmat” în Panou; **raportul lunii** (ecran + PDF / partajare); activitățile în backup; **citirea corectă a sumelor** scrise românește („2.500”, „1.500,50”) |
| 1.19 | **Zile libere implicite**: weekendurile și sărbătorile legale apar singure în Calendar (fundal gri, etichetă „Liber” / numele sărbătorii), efectuate până azi inclusiv, planificate după; în raportul lunii: weekend, sărbători, efectuate / planificate, zile lucrătoare și zilele libere în care s-a lucrat |
| 1.20 | **Sigiliul** vizibil și în bara categoriei („N criterii de sigilare”, restrânsă: și literele, ca amenzile) și pe rândul controlului din liste (Istoric, Calendar, pagina obiectivului), în Panou la „Controale neîncheiate” și pe cardul din Obiective (ultimul control): „Sigiliu aplicat · 2 criterii” / „2 sigilii (2 construcții) · 3 criterii”; corectat: „nereguli grave” din liste numără și rândurile adăugate marcate grave; **filtre în Istoric și Obiective** (butoane vizibile cu numărul rezultatelor, combinate cu ȘI): amendă în curs / 15 zile expirat / ANAF / achitată, ASI în curs, de încărcat, netrecute în PV, nereguli grave, sigiliu; cardul din Obiective arată acum și amenzile pe stadii, ASI în curs, netrecutele în PV și grave la ultimul control |
| 1.21 | **Panou**: secțiunile cu ceva de rezolvat (amenzi active, ASI, de încărcat, controale neîncheiate, netrecute în PV) urcă primele, sub statistici; cele goale coboară la final; corectat: pe orizontal, pastilele lungi din „De încărcat” intrau sub caseta cu zilele rămase |
| 1.22 | **Protecție civilă**: categoria nouă „Organizare protecție civilă” (agent de inundații, inspector PC, taxa PC, convenții cu OPEC; schema 11). **Adăposturi de protecție civilă** la Localitate (tabul PC) și la OPEC (tabul Obiectiv + grupul din Nereguli): DA → câte → fiecare cu locație, Conform / Neconform, observații; neconform = neregulă completă; pe bară „3 adăposturi: 2 conforme, 1 neconform”; filtrul „Adăposturi PC” (Istoric, Obiective – ultimul control); în Fișa PDF (tabel) |
| 1.23 | **Telefon** (`css/telefon.css`, doar sub 600px lățime sau 520px înălțime): bara de jos cu 5 butoane (Setări din Panou), antet și taburi compacte, derulabile, butoanele Conform / Constatat / NEC sub denumire, calendar cu buline, filtrele pe 2 rânduri derulabile, text Mare/Mediu/Mic = 17/16/15px, peisaj cu bare subțiri; textele „tabletă / iPad” devin „telefon” pe telefon. Tableta: capturile identice (verificat pixel cu pixel pe 60 de ecrane; singura diferență: capitolul nou din Ghid) |

## 4. Ce face aplicația (inventar)

### Navigarea
- **Orizontal:** bara laterală, cu ceasul, Control nou, Panou, Obiective, Calendar, Istoric, Anulează / Sus / Refă (în control), Backup rapid, Ghidul aplicației, Setări.
- **Vertical:** bara de jos (Panou, Obiective, +, Calendar, Istoric, Setări) și banda Anulează / Sus / Refă în control.
- **Numerele de pe meniu:**
  - Panou = amenzi urgente (galbene și roșii);
  - Istoric = controale neîncheiate.
  - Pe orizontal sunt scrise în cuvinte; pe vertical apar ca buline.

### Panoul
- **Sus:** data și ora tabletei, pe un rând.
- **Cinci casete, fiecare cu culoarea ei:**
  - Amenzi active, cu legenda scrisă; achitatele apar separat și nu intră în total;
  - Controale neîncheiate;
  - Termene ASI;
  - De încărcat;
  - Netrecute în PV.
- **Secțiuni cu liste:** atingeți un rând și controlul se deschide exact la locul respectiv.
- **Din 1 decembrie:** cererea de verificare a sărbătorilor legale pentru anul următor.
- **Activități de confirmat:** planificatele a căror zi a trecut (Efectuată / Reprogramează / Anulată).

### Controlul
- **Antetul:** Înapoi, Salvat, Text PV, Fișa PDF, Istoric, Backup, Șterge.
- **„Ce mai aveți de făcut”:** pasul următor, cu acces direct.
- **Taburile:** Obiectiv, Acte, Nereguli; la localități în plus Planuri și SVSU, Protecție civilă. Fiecare arată starea în cuvinte și progresul („Dotări 18/38”, „Verificate 4/37”).
- **Tabul Obiectiv:**
  - datele obiectivului și perioada controlului (Încheie controlul / Redeschide);
  - **Încărcare după încheiere** (două bife);
  - construcțiile: date, GRF/NSI, GPS, dotări DA / NU / NEC, centrala termică, nr. ASI / aviz.
- **Tabul Acte:** Prezentat / Lipsă / NEC; căutare; filtre; Restul prezentate.
- **Tabul Nereguli:**
  - partea de sus: sumar, căutare (cu glosar de abrevieri), meniul ⋯, filtre, Restul conform;
  - categorii cu bară scrisă în cuvinte;
  - rânduri cu ✓ ✗ NEC pe bară;
  - la ✗: construcțiile, PV, amenda (seria și nr., data, suma, achitată), neregulă veche, sigiliu (la cele grave), termenul ASI la „a”;
  - rânduri adăugate de inspector (se pot marca grave).
- **Observațiile:** câmpul apare doar cu text, la ✗ sau când apăsați „+ Obs.”.
- **Text PV:** constatările și actele lipsă; opțiunile „Doar netrecute” și „Include actele lipsă”; butoane Copiază, Partajează, Marchează-le trecute.
- **Fișa PDF:** tipărire sau partajare.

### Celelalte ecrane
- **Obiective:** căutare după nume, localitate, adresă sau dată; pagina obiectivului (date, GPS, statistici, istoric); „Control nou pe acest obiectiv” preia datele din ultimul control.
- **Istoric:** controalele pe luni; pastile scrise (nereguli, netrecute, amenzi cu stadiul, ASI, încărcare).
- **Calendar = plan lunar:** controalele, **activitățile** (în culoarea tipului; ✓ = efectuată) termenele și **zilele libere** (weekend + sărbători legale, derivate automat), pe zile; ziua selectată cu listele și butoanele „Control nou / Activitate nouă în această zi”; butonul **Plan lunar** → raportul lunii (`#/luna/AAAA-LL`), de tipărit / partajat.
- **Setări:**
  - mărimea textului, tema;
  - backup: Exportă / Importă (Combină sau Înlocuiește tot);
  - actualizări;
  - regulile termenelor;
  - **sărbătorile legale** (anul curent și următorul);
  - date demonstrative;
  - zona periculoasă.

## 5. Reguli de calcul (verificate cu teste)

- **Amenda:** termenele se numără de la data aplicării (implicit, data încheierii). Ziua aplicării = ziua 0.
  - Albastru, „În curs”: zilele 0–15.
  - Galben, „Termen 15 zile expirat”: zilele 16–39.
  - Roșu, „Trimite la ANAF”: din ziua 40; termenul ANAF = ziua 45.
  - Verde: „Achitată”.
  - Data aplicării în viitor: se afișează corect (cu data plății), nu „15 zile”.
- **ASI (neregula „a”, bifa „Termen de prezentare 90 de zile”):**
  - 90 de zile de la încheiere;
  - apoi **5 zile calendaristice** pentru constatarea pierderii valabilității;
  - termenul se închide cu „Documentație prezentată” sau „Pierderea valabilității constatată” (fiecare cu data).
- **Încărcarea în aplicația ISU și a documentului (PV scanat):**
  - se cere doar după încheiere;
  - termen: **3 zile lucrătoare** de la încheiere (ziua încheierii nu se numără; weekendurile și sărbătorile se sar);
  - portocaliu cât mai sunt zile; **roșu în ultima zi** și după termen.
- **Zile nelucrătoare:**
  - weekendul și cele 17 sărbători legale din art. 139 Codul muncii: 1–2 ian., 6–7 ian. (din 2024), 24 ian., Vinerea Mare, Paștele și a doua zi, 1 mai, 1 iunie, Rusaliile și a doua zi, 15 aug., 30 nov., 1 dec., 25–26 dec.;
  - Paștele ortodox se calculează (verificat pentru 2024–2028);
  - un termen care cade într-o zi liberă **nu se mută**: aplicația avertizează și **recomandă prima zi lucrătoare** de după (v1.17).
- **Verificările instalațiilor:**
  - valabilitate: b1 12 luni, b2 12 sau 24 de luni, b3 24 de luni, c1 12 luni, c2 și c3 6 luni, c4–c7 12 luni;
  - se compară cu data începerii controlului;
  - „valabilă până la X” include ziua X; după X: „expirată — era valabilă până la X”.
- **Corelări:**
  - DA la o instalație → apar neregulile ei;
  - NU la o instalație necesară → neregulă gravă G1–G12;
  - GRF/NSI V + regim de înălțime peste parter → G13;
  - NU la ASI / AVIZ / Iluminat Hint → ah / ai / am, constatate automat și retrase la DA / NEC, dacă nu s-a lucrat pe ele;
  - neregula veche = aceeași cheie constatată la un control anterior al obiectivului.
- **Raportul lunii:** controalele începute în lună (și câte încheiate), neregulile constatate la ele; amenzile **aplicate în lună** după data aplicării (implicit data încheierii), cu suma; amenzile fără dată (controale neîncheiate) separat; activitățile care ating luna — efectuate pe tipuri (număr și zile din lună), planificate, anulate; **zilele libere** (weekend + sărbători legale, o sărbătoare căzută în weekend se numără o dată, ca sărbătoare): efectuate = până azi inclusiv, planificate = după; zile lucrătoare = zilele lunii − zilele libere; „lucrată” = în ziua liberă a început un control sau există o activitate efectuată, alta decât concediul.
- **Sumele** se citesc în stil românesc: punct = mii, virgulă = zecimale („2.500” = 2500, „1.500,50” = 1500,5); până la v1.18, „2.500” apărea greșit ca 2,5 lei.
- **Cifre consistente:** „Ce mai aveți de făcut”, filtrul „Neverificate”, sumarul, tabul și suma barelor de categorie dau aceeași cifră.

## 6. Decizii de design

**Aprobate și implementate:**
- v1.14: Panou aerisit; ✓ ✗ NEC lângă denumire; fără câmpuri goale de observații; bara categoriei compactă; Anulează / Refă într-o bandă subțire; etichetă de tip discretă; stadiile amenzilor ca pastile; „început azi” / „de N zile”; bara laterală compactă, cu ceas.
- v1.15: bara categoriei în cuvinte întregi (literele doar când e restrânsă); text în loc de buline; avertizări mai mari; pastile de amendă pline; la ✗ observațiile se deschid fără tastatură; Anulează / Refă cu contur.
- v1.16: încărcarea (bife în tabul Obiectiv; pastile în Istoric și Obiective; caseta și secțiunea din Panou); etapa a doua ASI.
- v1.17: recomandarea zilei lucrătoare; verificarea anuală a sărbătorilor legale.
- v1.18: plan lunar — tipuri fixe + „Altă activitate”; câmpuri tip, dată (interval), oră, descriere, stare, obiectiv, observații; planificatele trecute „de confirmat” în Panou; raport pe ecran + PDF / partajare.
- v1.23: telefonul — alese de utilizator: 5 butoane jos + Setări în Panou; antet și taburi compacte; calendar cu buline; text puțin mai mic (17/16/15). Testat pe iPhone 12 Pro Max (428×926 portret, 926×428 peisaj) — de aceea condiția e și pe înălțime (peisajul are 926px lățime). Regula: tableta nu se schimbă; foaia pentru telefon nu se aplică pe iPad (cel mai mic iPad are 744px pe latura scurtă). Doar prezența foii schimbă netezirea marginilor cu ≤ 7/255 pe câțiva pixeli (invizibil).
- **Aplicația nativă — decizia finală (26.09.2026): rescriere completă în Swift (varianta B), într-un chat separat pe MacBook.** Varianta A (înveliș WKWebView + widgeturi, PR #16 inițial) a fost scrisă și apoi retrasă la cererea utilizatorului; codul rămâne în istoricul git. Avertizat: două aplicații de ținut sincronizate, logica de termene scrisă de două ori. Măsuri: datele comune exportate din web (`docs/nativ/date/`: catalog, sărbători, ghid, stilurile fișei) se citesc, nu se transcriu; cazurile de test (`docs/nativ/vectori/`, generate cu `npm run nativ` din codul web, deterministe) trebuie trecute 100% de Swift; la fiecare versiune web, un prompt de actualizare în `docs/nativ/ACTUALIZARI.md`. Pornire: `docs/nativ/PROMPT.md`. Utilizatorul: MacBook Air M2 (8 GB), Xcode 27, iPad Air 11" cu iPadOS 27, iPhone 12 Pro Max cu iOS 27, cont Apple gratuit. Identificatori propuși: `ro.cucuta.agenda`, `ro.cucuta.agenda.widget`, `group.ro.cucuta.agenda`. Planul inițial (pentru varianta A, păstrat ca istoric):
- v1.22: adăposturi — alese de utilizator: la OPEC în tabul Obiectiv (nu tab PC separat), neconform = neregulă completă (PV, amendă, veche), texte PV „… nestabilit(ă)” / „Lipsă convenții cu OPEC”, filtru în Obiective + Istoric. Decizii proprii: adăpostul e un rând de neregulă (reutilizează PV, amendă, numărători, Text PV, fișa); numerotare A1, A2…; fără NEC pe adăpost; trecerea pe NU / NEC șterge adăposturile după confirmare; adăposturile se preiau la controlul următor cu locația, starea golită.
- v1.21: ordinea secțiunilor din Panou e dinamică: întâi cele cu elemente (în ordinea fixă amenzi → ASI → încărcare → neîncheiate → PV), apoi cele goale; casetele de statistici rămân pe loc.
- v1.20: filtrele — alese de utilizator din propuneri (respinse: „nereguli vechi”, „fără nereguli”; afișare în fereastră „Filtre”); în Obiective regula „mixt”: termenele la oricare control, gravitatea (grave, sigiliu) la ultimul; filtrele țin doar cât e deschisă aplicația (nu se salvează).
- v1.20: **sigiliul se aplică pe construcție**; neregulile grave constatate (✗) cu bifa Sigiliu sunt **criteriile** lui (precizarea utilizatorului): mai multe criterii în aceeași construcție = un sigiliu; construcții diferite = câte un sigiliu pe fiecare; o neregulă constatată în mai multe construcții = sigiliu în toate (fără alegere separată a construcțiilor sigilate); „bara obiectivului” = rândul controlului din liste (ales de utilizator, nu antetul controlului și nu pagina obiectivului).
- v1.19: zilele libere nu se salvează (nu sunt activități) — se calculează din `zinelucratoare()`, deci nu intră în backup și nu cer confirmare; se actualizează singure odată cu lista sărbătorilor.

**Respinse (nu se repropun fără un motiv nou):**
- scoaterea ceasului din bara laterală;
- mai puține culori;
- **antet de control compact** (nici doar pe orizontal, v1.15: „Las așa”);
- fără texte repetate;
- titluri scurte;
- Text PV cu font normal;
- calendar cu buline;
- etichete ✓ ✗ NEC mai mari;
- nume mai mari în calendar;
- „+ Obs.” mare.

**Compromis acceptat:** pe orizontal, în control, primul rând de neregulă stă chiar sub marginea ecranului (textele scrise din taburi și din sumar ocupă ~60 px). Pe vertical nu e afectat.

## 7. Verificarea

- **`npm test`**: logica de termene, catalog, corelări, zile lucrătoare, încărcare, ASI (node:test, `tests/model.test.js`).
- **`tests/e2e/ruleaza.sh`**: testele din browser (Playwright + Chromium), pe aplicația servită local pe portul 8080.
  - **Suitele pe versiuni** (`v110` … `v114`, `flow`, `loc`, `obsind`, `bk`, `gps`, `live`, `hol`, …) verifică funcțiile introduse de fiecare versiune.
  - **`audit.cjs`**: 459 de ecrane (3 mărimi de text × 2 orientări × 2 teme). Caută scroll orizontal, ținte de atingere sub 44 px (prin hit-test real), câmpuri cu font sub 16 px și text tăiat.
  - **`oracol.cjs`** (cu `gen.mjs`): **oracolul numeric**. Compară fiecare cifră afișată (Panou, meniu, Istoric, taburi, sumar, bare, filtre, fișă, Text PV, Calendar, încărcare, ASI) cu o numărătoare independentă făcută direct din date, pe un set cu toate cazurile-limită și pe datele demonstrative.
  - **`activitati.cjs`**: planul lunar (adăugare, validare, confirmare, reprogramare, raport comparat cu datele din backup, backup dus-întors, ștergerea datelor demonstrative).
  - **`reguli.cjs`** (cu `reguli.mjs`): ce rânduri apar la DA / NU / GRF V, comparat cu listele-șablon.
  - **`upd.cjs`**: actualizarea prin service worker (versiunea curentă → următoarea).
- **ESLint** pe `js/*.js` și `sw.js`.

## 8. Anual

- **Decembrie:**
  - Panoul cere verificarea sărbătorilor legale pentru anul următor.
  - Se verifică legea (art. 139 Codul muncii, eventuale modificări). Dacă s-a schimbat, se actualizează `sarbatoriLegale()` din `js/dates.js` și testele, apoi se publică o versiune nouă.
  - Singurul semnal e mementoul din aplicație (Panou). Rutina programată din sesiunea de lucru a fost ștearsă la cererea utilizatorului (v1.21).

## 9. Limite cunoscute și idei

- Datele sunt doar pe tabletă; fără backup regulat, se pot pierde.
- Controalele încheiate înainte de v1.3 (schema < 3) ar arăta actele despre exerciții ca neverificate; în practică nu există astfel de date pe iPad.
- Testele din browser încarcă Playwright dintr-o cale a mediului Claude Code (`/opt/node22/...`).
