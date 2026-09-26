# Aplicația nativă (Swift) — specificație

Documentul e pentru chatul care construiește aplicația nativă pe MacBook. Promptul de pornire e în `PROMPT.md`, iar promptul pentru actualizări în `ACTUALIZARI.md`.

## 0. Scopul și regula de bază

- Aplicația nativă este **aceeași aplicație ca varianta web**, 1 la 1: aceleași ecrane, informații, texte, reguli de calcul, culori și fluxuri. Diferă doar tehnologia: SwiftUI în loc de HTML.
- **Sursa adevărului este aplicația web din acest repo.** La orice nelămurire se citește codul web, nu se ghicește:
  - `js/model.js`: modelul de date și regulile (termene, nereguli, statistici, PV);
  - `js/dates.js`: date, zile lucrătoare, sărbători;
  - `js/activitati.js`: plan lunar, raport;
  - `js/views.js`, `js/editor.js`: ecranele;
  - `js/app.js`: fluxurile și acțiunile;
  - `js/fisa.js`: Fișa controlului;
  - `css/app.css` + `css/telefon.css`: aspectul pe tabletă și pe telefon;
  - `js/help.js`: Ghidul aplicației.
- Aplicația web rulează local, pentru comparație ecran cu ecran: `python3 -m http.server 8080` în rădăcina repo, apoi http://localhost:8080 în Safari sau în simulator.
- **Nu se inventează funcții, texte sau reguli** și nu se „îmbunătățește” nimic fără aprobarea utilizatorului. Propunerile se fac sub formă de întrebări cu variante.
- **Adăugiri native**, care nu există în web:
  - widgeturi pe ecranul principal și pe ecranul blocat;
  - notificări locale;
  - cifra urgentelor pe iconiță;
  - partajare și tipărire prin ferestrele iOS.
- **Utilizatorul:**
  - inspector de prevenire ISU; comunică în română; vrea răspunsuri scurte, fără ziduri de text;
  - propunerile i se fac ca întrebări cu variante;
  - greșelile și limitele i se spun direct;
  - dispozitive: iPad Air 11" (iPadOS 27), iPhone 12 Pro Max (iOS 27), MacBook Air M2 (8 GB), Xcode 27, cont Apple gratuit (Personal Team).

## 1. Datele comune și cazurile de test (`docs/nativ/`)

Sunt generate din aplicația web cu `npm run nativ` (scriptul `tests/nativ/exporta.mjs`) și regenerate la fiecare versiune web. **Nu se editează de mână.**

| Fișier | Ce conține | Cum se folosește |
|---|---|---|
| `date/catalog.json` | Rândurile de nereguli și rubrici (`sablon`), actele, dotările, categoriile, secțiunile, tipurile de activitate, termenele, lunile, `schema` | **Se include în aplicație și se citește la pornire.** Rândurile nu se transcriu în Swift. |
| `date/sarbatori.json` | Sărbătorile legale 2024–2040 și Paștele ortodox | Verificare: calculul din Swift trebuie să dea aceleași date (algoritmul e în `sarbatoriLegale()` din `js/dates.js`). |
| `date/ghid.json` | Ghidul aplicației: capitole cu blocuri (`p`, `h`, `ul`, `ol`, `note`, `btns`) care conțin HTML | Ecranul Ghid afișează acest conținut, cu căutare. |
| `date/icon-1024.png` | Pictograma aplicației (aceeași ca în web), 1024×1024, fără transparență | Iconița aplicației (AppIcon, o singură mărime). |
| `date/stiluri-fisa.css` | Stilurile Fișei și ale Planului lunar (pagină albă, pentru tipărire) | Fișa și raportul se generează ca HTML, cu aceste stiluri, și se tipăresc sau exportă PDF printr-un `WKWebView` ascuns. |
| `vectori/date.json` | Formatarea datelor, pluralul, zilele nelucrătoare 2024–2030, zile lucrătoare, căutarea după dată | Teste XCTest: rezultatul trebuie să fie identic. |
| `vectori/termene.json` | Stadiul amenzilor zi cu zi (`fineStatus`), ASI 90 de zile + 5 zile (`asiDeadline`), încărcarea (`incarcareStatus`), cu toate textele | Teste XCTest: fiecare câmp identic, **inclusiv mesajele**. |
| `vectori/sume.json` | Citirea sumelor scrise românește („2.500”, „1.500,50”) și afișarea lor în lei | Teste XCTest. |
| `vectori/demo.json` | Setul demonstrativ (7 controale, 5 activități) la data 15.10.2026, plus tot ce afișează aplicația despre el: statistici, „Ce mai aveți de făcut”, Text PV, literele rândurilor, neregula veche, sigilii, adăposturi, Fișa (HTML), căutări, Panou, raportul lunii (date + HTML), **widgeturi și notificări** (`nativ`), un fișier de backup | Teste XCTest pe setul întreg. E și setul de date demonstrative al aplicației native. |
| `vectori/normalizare.json` | Controale din versiuni vechi → cum sunt completate (`normalizeControl`) | Teste: backupurile vechi se importă corect. |

**Regula:** toate testele pe vectori trebuie să treacă 100% înainte de orice ecran construit pe logica respectivă. Un vector care nu trece înseamnă o greșeală în Swift. Nu se schimbă vectorul; la o nelămurire se întreabă utilizatorul.

## 2. Arhitectura recomandată

- **Proiect:** Xcode, SwiftUI, țintă minimă iOS/iPadOS 17 (dispozitivele au 27). O singură aplicație pentru iPad și iPhone, plus o extensie WidgetKit. Cod în folderul `ios/` al acestui repo.
- **Identificatori:**
  - aplicația: `ro.cucuta.agenda`;
  - widgetul: `ro.cucuta.agenda.widget`;
  - grupul comun: `group.ro.cucuta.agenda`.
  Dacă Xcode refuză vreunul, se alege altul și se notează în `ios/README.md`.
- **Modelul:** structuri `Codable` care oglindesc exact JSON-ul aplicației web (`docs/MODEL_DATE.md`): `Control`, `Neregula`, `Constructie`, `Amenda`, `Activitate`, `Meta`.
  - Decodare tolerantă: câmp lipsă = valoarea implicită.
  - Chei necunoscute se păstrează, ca un backup să nu piardă date la dus-întors.
  - Aceleași nume de câmpuri ca în web.
- **Stocarea:** fișiere JSON în containerul aplicației (`controls.json`, `activitati.json`, `meta.json`), scrise atomic, la fiecare modificare, cu o mică întârziere, ca în web.
  - Nu SwiftData: formatul identic cu backupul face importul și exportul trivial și sigur.
  - Cifrele pentru widget se scriu separat în grupul comun.
- **Logica:** un modul Swift pur, fără UI, care portează funcțiile din `js/model.js`, `js/dates.js`, `js/activitati.js`, cu **aceleași nume** (`fineStatus`, `asiDeadline`, `incarcareStatus`, `controlStats`, `secStats`, `todoList`, `pvText`, `raportLunar`, `normalizeControl` …), ca actualizările să se poată face funcție cu funcție.
- **Datele calendaristice:** șiruri `"AAAA-LL-ZZ"`, ca în web, cu aritmetică pe calendarul gregorian, în fusul orar al dispozitivului. Ora nu intră în calculul termenelor.
- **Fișa controlului și Planul lunar:** se generează același HTML ca `fisaMarkup` / `raportMarkup`, verificat pe `demo.json`, cu `stiluri-fisa.css`.
  - Tipărire: `UIPrintInteractionController` cu `viewPrintFormatter()` al unui `WKWebView`.
  - Partajare: fișierul HTML sau PDF prin `UIActivityViewController`.
- **Backupul:**
  - **export:** același format (`{app, schema, exportedAt, controls, activitati}`) și același nume de fișier ca în web, prin fereastra de partajare;
  - **import:** `fileImporter`, cu variantele Combină / Înlocuiește tot, exact ca în web (`importBackup` din `js/app.js`).
  - Backupurile se mută astfel în ambele sensuri între web și nativ.

## 3. Ce trebuie să existe (lista de verificare)

Inventarul complet e în `docs/JURNAL.md`, §4 „Ce face aplicația”, iar manualul utilizatorului în `date/ghid.json`. **Fiecare capitol din ghid descrie comportamente care trebuie să existe identic.** Pe scurt:

1. **Navigarea:**
   - iPad orizontal: bară laterală, cu ceas, Control nou, Panou, Obiective, Calendar, Istoric, Anulează / Sus / Refă în control, Backup rapid, Ghid, Setări;
   - iPad vertical: bara de jos (Panou, Obiective, +, Calendar, Istoric, Setări);
   - iPhone: 5 butoane, iar Setările se deschid din Panou (`css/telefon.css`).
2. **Panoul:**
   - antet cu data și ora, plus Ghid și Backup rapid (pe vertical);
   - „Activități de confirmat”;
   - memento pentru sărbătorile legale;
   - 5 casete: amenzi active pe stadii, neîncheiate, ASI, de încărcat, netrecute în PV;
   - secțiunile cu elemente urcă primele (v1.21).
3. **Controlul (editorul):**
   - taburile Obiectiv, Acte & evidențe, Nereguli, plus Planuri și SVSU / Protecție civilă la Localitate;
   - „Ce mai aveți de făcut”;
   - construcții cu dotări DA / NU / NEC, GRF / NSI, GPS la cerere;
   - nereguli pe categorii, cu bara categoriei (necompletate, constatate, PV, amendate, criterii de sigilare);
   - rândul neregulii: Conform / Constatat / NEC, observații, construcții, PV, amendă cu termene, neregulă veche, sigiliu, ASI;
   - nereguli grave G, auto-nereguli ah / ai / am din dotări, rânduri adăugate;
   - adăposturi PC; căutare; filtre; „Restul conform”; restrângere;
   - Anulează / Refă;
   - încheiere, redeschidere, încărcare după încheiere;
   - Text PV; Fișa PDF.
4. **Obiective și Istoric:**
   - căutare după nume, localitate, adresă, dată;
   - filtrele de tip;
   - cele 10 filtre (amenzi pe stadii, ASI, încărcare, PV, grave, sigiliu, adăposturi);
   - cardurile și rândurile controlului, cu toate pastilele;
   - pagina obiectivului, cu istoricul.
5. **Calendarul și planul lunar:**
   - lună / an, controale, termene, activități, zile libere (weekend și sărbători);
   - ziua selectată;
   - activități: tipuri, stări, confirmare, reprogramare;
   - raportul lunii, cu tipărire și partajare.
6. **Setările:**
   - mărimea textului (Mic / Mediu / Mare, care scalează tot);
   - tema (Automat / Luminoasă / Întunecată);
   - backup, import;
   - sărbătorile legale;
   - date demonstrative (din `demo.json`);
   - ștergerea tuturor datelor;
   - versiunea.
7. **Ghidul:** capitolele din `ghid.json`, cu căutare.

**Controalele încheiate își păstrează lista de nereguli** din momentul încheierii (`catalog`, `din`, `retrasDin` în `catalog.json`; `catalogOf` / `inCatalog` în `js/model.js`). Regula e obligatorie.

## 4. Aspectul

- Culorile se iau din `css/app.css` (tokenurile din `:root`, plus varianta întunecată): accent violet, culorile stadiilor amenzilor, culorile casetelor Panoului, benzile categoriilor.
- **Temă luminoasă și întunecată.** Textul e mare; ținte de atingere ≥ 44 pt.
- **Mărimea textului** scalează toată interfața, cu aceleași proporții ca în web: Mare = 18 px, Mediu = 16,5, Mic = 15 pe tabletă, respectiv 17 / 16 / 15 pe telefon.
- **Tonul textelor e formal** („Completați…”, „Ștergeți…?”). Etichetele butoanelor sunt nume de acțiuni („Anulează”, „Șterge”). Textele se copiază din web, cuvânt cu cuvânt.
- **Informația se citește direct, fără atingeri** (principiul utilizatorului): nimic important ascuns în etichete lungi trunchiate sau sub pictograme fără text.

## 5. Widgeturi și notificări (adăugiri native)

- **Implementarea de referință** e în `tests/nativ/referinta.mjs`, iar rezultatul ei pentru setul demonstrativ e în `vectori/demo.json` → `nativ`.
- **Widgeturile:**
  - pe ecranul principal: mic (urgente + bara amenzilor), mediu (amenzi, ASI, de încărcat, neîncheiate, PV, de confirmat), mare (aceleași + termenele următoare; cele depășite marcate „depășit”);
  - pe ecranul blocat: cerc (urgente), dreptunghi (3 rânduri de cifre), rând;
  - cifrele se calculează pentru 21 de zile (`cifreZi`), ca widgetul să se schimbe la miezul nopții fără ca aplicația să fie deschisă;
  - atingerea deschide Panoul.
- **Notificările (locale):**
  - la ziua în care o amendă își schimbă stadiul;
  - în ziua de dinainte și în ultima zi pentru ANAF, ASI și încărcare (08:00);
  - activitățile planificate (07:30);
  - activitățile de confirmat (09:00, a doua zi);
  - backupul, la 7 zile după ultimul (17:00);
  - sărbătorile legale, ca în Panou.
  Maximum 60 programate (iOS permite 64). Se reprogramează la fiecare modificare și la fiecare deschidere.
- **Cifra de pe iconiță** = `urgente` pentru azi.

## 6. Ordinea de lucru (etape)

Fiecare etapă se încheie cu testele trecute și cu o scurtă prezentare pentru utilizator, care o încearcă pe iPad.

1. **Proiectul:** aplicație + widget, semnare cu contul gratuit. Pornește pe iPad cu un ecran gol. Se verifică imediat dacă App Groups e acceptat la contul gratuit; dacă nu, se spune utilizatorului.
2. **Modelul, catalogul, logica pură** și **testele pe toți vectorii** (date, termene, sume, normalizare, demo fără HTML).
3. **Stocarea, backupul** (export / import, compatibil cu web), **datele demonstrative.** Utilizatorul importă backupul său real și se verifică numărul de controale și de activități.
4. **Panoul, Obiectivele, Istoricul** (cu filtre), pagina obiectivului.
5. **Editorul controlului**, tab cu tab, cu Anulează / Refă.
6. **Calendarul, activitățile, raportul lunii.**
7. **Fișa, Text PV, tipărirea și partajarea** (HTML identic cu vectorii).
8. **Setările, Ghidul**, mărimea textului, temele.
9. **Widgeturile și notificările** (identice cu `nativ` din `demo.json`).
10. **iPhone:** aspectul de telefon, după deciziile din `css/telefon.css`.
11. **Auditul final:** fiecare ecran, comparat cu varianta web pe aceleași date, pe iPad (vertical și orizontal) și pe iPhone, în ambele teme și la cele 3 mărimi de text.

## 7. Semnarea cu contul gratuit (de spus utilizatorului)

- Aplicația instalată din Xcode se oprește după 7 zile. Se reinstalează cu ▶︎, iar datele rămân.
- Sunt permise maximum 3 aplicații instalate așa pe un dispozitiv.
- Contul plătit (99 USD pe an) ridică limita la un an.
- Pe iPad trebuie activat Mod dezvoltator (Configurări → Confidențialitate și securitate). La prima instalare, contul se aprobă în Configurări → General → VPN și gestionare dispozitive.

## 8. Actualizările

- La fiecare versiune a aplicației web, utilizatorul primește **un prompt de actualizare** (vedeți `ACTUALIZARI.md`), cu ce s-a schimbat, fișierele web atinse și vectorii regenerați.
- Aplicarea: `git pull`, modificarea Swift, testele pe vectori 100%, verificarea ecranelor atinse, apoi un scurt raport pentru utilizator.
- Versiunea aplicației native urmează versiunea web pe care o reproduce (`versiuneAplicatieWeb` din `catalog.json`).

## 9. `ios/CLAUDE.md` (de creat la început, în proiectul nativ)

Se copiază în `ios/CLAUDE.md`, ca fiecare chat nou pe proiectul nativ să știe regulile:

```
# Agenda inspectorului — aplicația nativă (Swift)
- Reproduce 1 la 1 aplicația web din acest repo (sursa adevărului: js/, css/, docs/). Specificația: docs/nativ/SPECIFICATIE.md.
- Utilizatorul comunică în română; răspunsuri scurte; propunerile ca întrebări cu variante; fără funcții sau texte inventate.
- Datele comune (docs/nativ/date/) se includ și se citesc, nu se transcriu. Vectorii (docs/nativ/vectori/) sunt teste: 100% înainte de push.
- Datele: același JSON ca web (docs/MODEL_DATE.md), backup compatibil în ambele sensuri; controalele încheiate își păstrează lista (catalog).
- Actualizări: fiecare prompt din docs/nativ/ACTUALIZARI.md se aplică integral; la final, versiunea nativă = versiuneAplicatieWeb.
- Cont Apple gratuit: aplicația se reinstalează la 7 zile; spuneți-i utilizatorului dacă o funcție cere cont plătit.
```
