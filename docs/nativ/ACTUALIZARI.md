# Actualizările pentru aplicația nativă

La fiecare versiune nouă a aplicației web, chatul aplicației web adaugă aici o intrare cu **promptul de actualizare**. Dumneavoastră îl lipiți în chatul aplicației native, pe MacBook.

## Pașii dumneavoastră, la fiecare actualizare
1. Aprobați PR-ul aplicației web pe GitHub.
2. Pe MacBook, în chatul aplicației native, lipiți promptul versiunii noi. Promptul începe cu `git pull`.
3. Chatul aplică modificările, rulează testele, instalează pe iPad și vă raportează.

## Cum arată un prompt (model)

```
Actualizare la versiunea web v1.X.Y. Rulează `git pull` pe main.
Ce s-a schimbat: … (funcții, reguli, texte; fișierele web atinse: js/…, css/…)
Date comune regenerate: docs/nativ/date/… (se includ din nou în aplicație)
Vectori regenerați: docs/nativ/vectori/… (teste noi: …)
Ce ai de făcut în Swift: 1) … 2) … 3) …
Criterii de acceptare: testele pe vectori 100%; ecranele … arată ca în web (compară cu aplicația web locală); …
La final: versiunea nativă = v1.X.Y; commit + PR; raport scurt pentru mine.
```

---

## Intrări

### Pornirea (baza: aplicația web v1.23.0)
Aplicația nativă se construiește de la zero, după `docs/nativ/PROMPT.md`. Nu e nevoie de un prompt de actualizare separat. Baza este v1.23.0: telefon, adăposturi PC, filtre, sigiliu, zile libere, plan lunar.

### v1.23.1 — culoarea categoriei „Organizare protecție civilă” (28.09.2026)
Aplicată deja în aplicația nativă, în același PR (lucrul s-a făcut din chatul nativ). Promptul rămâne pentru istoric:

```
Actualizare la versiunea web v1.23.1. Rulează `git pull` pe main.
Ce s-a schimbat: categoria „pcorg” (Organizare protecție civilă) are culoarea --cat-pcorg: #0284c7 (css/app.css); înainte nu avea culoare (fără bandă). Versiunea: js/version.js, sw.js.
Date comune regenerate: docs/nativ/date/catalog.json și ghid.json (doar versiuneAplicatieWeb = 1.23.1).
Vectori regenerați: niciunul schimbat.
Ce ai de făcut în Swift: 1) culoareCategorie("pcorg") = 0x0284c7 (Agenda/Editor/ComponenteEditor.swift); 2) testele.
Criterii de acceptare: testele 100%; în tabul Protecție civilă al unei Localități, bara și banda rândurilor „Organizare protecție civilă” sunt albastru-cer, ca în web; versiunea din Setări = 1.23.1.
La final: commit + PR; raport scurt.
```

### v1.24.0 — „ANAF / Taxe și impozite” (28.09.2026)
Aplicată deja în aplicația nativă, în același PR. Promptul rămâne pentru istoric:

```
Actualizare la versiunea web v1.24.0. Rulează `git pull` pe main.
Ce s-a schimbat: textul „ANAF” devine „ANAF / Taxe și impozite” peste tot (js/model.js: eticheta și mesajele fineStatus, nelucrNota; js/views.js: LEVEL_LABEL, filtrul am-red, legenda Panoului „de trimis la …”, „+25 zile: trimite la …”, mementoul sărbătorilor, termenul din calendar, legenda calendarului „termen ANAF / Taxe și impozite sau ASI”, regulile din Setări; js/editor.js: „… până la”; js/help.js: Ghidul; tests/nativ/referinta.mjs: titlurile notificărilor și ale widgetului). Regulile de calcul nu se schimbă.
Date comune regenerate: docs/nativ/date/catalog.json, ghid.json. Vectori regenerați: termene.json, demo.json (mesajele).
Ce ai de făcut în Swift: aceleași texte în Termene.swift, Liste.swift, Panou.swift, Calendar.swift, ModelEditor.swift, Nativ.swift, RegulileNotificarilor.swift, PlanNotificari.swift, EcranSetari.swift, ReguliNotificari.swift; testele portate (ModelTests, NotificariTests).
Criterii de acceptare: testele 100% (vectori, verificarea încrucișată, ghidul); pastila roșie a amenzii nu se taie (Panou, Istoric, Obiective, editor, filtre), la toate mărimile și orientările.
La final: commit + PR; raport scurt.
```

### v1.25.0 — cererea în 12 puncte, controlul următor, coordonatele de mână (28.09.2026)
Aplicată deja în aplicația nativă, în același PR (web și nativ lucrate împreună, la cererea utilizatorului: „Le fac eu pe amândouă”). Promptul rămâne pentru istoric și pentru verificare:

```
Actualizare la versiunea web v1.25.0 (schema 12). Rulează `git pull` pe main.
Ce s-a schimbat (js/model.js, js/editor.js, js/app.js, js/fisa.js, js/views.js, js/activitati.js, js/help.js, js/demo.js, css/app.css, css/telefon.css):
- Control: persoanaParticipanta, observatiiGenerale, deIntrebat [{id, text, gata}] (după localitate, în această ordine); cele nebifate cu text → „Ce mai aveți de făcut” (intreb-<id>, „De întrebat: …”, focus sec-intrebari).
- Seria amenzii nu se mai afișează și nu se mai cere (editor, Panou, Fișă, PV „sancționat cu amendă”, todo doar „Amendă fără suma”, raportul lunii fără coloană); amenda.serieNr rămâne în date.
- ACTE: „fumat” (din 12). acteOf(c) = actele din lista controlului. NEREGULI: ao / ap / aq (autoActe: grup / controale / analiza, din 12, docs) — syncAutoActe (ca syncAutoNU; obsOnly la observațiile actelor); constructiiOf = [] pentru ele; PV: fără lista separată a actelor dacă ao e în catalog; „an” (din 12, electric).
- DOTARI: ilumHint cu NEC, ascuns când hidInt e NU / NEC (ilumHintAscuns, dotariVizibile, valDotare); ascensor DA / NU (din 12).
- Centrala: dotari.centrala.ct [{id, tipuri}] (tipuri = reuniunea); normalizare: tipuri fără ct → ct1. b3 / g / h perCT: verifUnitati (unități „<k>:<ct>”, CT 1 preia data scrisă pe construcție), centraleAlese (ctIds), constructiiNume „Corp – CT 2”, verifText cu unități.
- GPS: gpsQuality(null) = 'manual'; gpsEgal; parseCoord (zecimal și Busolă, 6 zecimale cu Math.round); manual = {lat, lon, acc: null, la, manual: true}.
- controlFromPrevious: preia tot din controlul imediat anterior (constatările ca „nok” cu obs / construcții / ctIds remapate; adăposturile; observațiile actelor; deIntrebat nerezolvate); fără PV, amenzi, sigilii, starea actelor, termen ASI, verificări, rânduri Conform / NEC; apoi syncAutoNU + syncAutoActe.
- constatareAnterioara: doar controlul imediat anterior.
- migreazaDeschis (normalizare și fixeazaCatalog): control deschis cu schema < 12 → syncAutoActe + syncAutoNU('ilumHint') + schema 12, o singură dată.
- schimbare: deIntrebat, observatiiGenerale, „ordinea construcțiilor”.
- Editor: intreb-add / intreb-del, flag deIntrebat.#id.gata, constr-up / constr-down, gps-ca-prima, gps-manual (fereastra), ct-count, centrala cu data-ct (și fără centrale: tipul creează CT 1), ct-opt, verif-ca-prima, verif-nok cu ctIds, acte.X.status / obs → syncAutoActe (mesaje), hidInt → syncAutoNU('ilumHint'); GPS fără poziție → fereastra cu variantele.
Date comune regenerate: catalog.json, ghid.json, stiluri-fisa.css. Vectori regenerați: demo.json, normalizare.json.
Ce ai de făcut în Swift: portarea funcțiilor de mai sus (AgendaKit: Creare, Nereguli, PV, Termene, Cautare, Fisa, Raport, DateDemo, Editor, ModelEditor; aplicația: TabObiectiv, RandNeregula, Ferestre, SesiuneEditor, ComponenteEditor — CampData rămâne deschis până la „Gata”); genereaza.mjs / editor.mjs cu câmpurile și acțiunile noi; testele portate.
Criterii de acceptare: ios/teste.sh 100% (vectori, verificarea încrucișată pe mai multe semințe, editorul pas cu pas); turul vizual pe iPad (orizontal și vertical); datele utilizatorului neatinse (doar migrarea cerută, la controalele în desfășurare).
La final: commit + PR; raport scurt.
```

### v1.25.1 — corecturi telefon (dotări) și GPS (poziția aproximativă) (28.09.2026)

```
Actualizare la versiunea web v1.25.1. Rulează `git pull` pe main.
Ce s-a schimbat (css/telefon.css, js/app.js, js/help.js; testele tests/e2e/telefon.cjs, tests/e2e/gps2.cjs):
- Telefon, tabul Obiectiv, Dotări: denumirea și butoanele (DA / NU / NEC; la centrala termică − / + și NU ARE) stau pe același rând doar dacă încap; altfel butoanele coboară sub denumire. Niciun buton nu acoperă textul și nu iese din rând (verificat la 428, 390, 375 pt). Rândurile CT 1, CT 2… și Obs. rămân mereu dedesubt.
- GPS, ordinea cererilor: 1) precis (20 s, fără poziție din cache); 2) dacă precisul dă „fără poziție” sau „timp depășit” → aproximativ (15 s, poziție de cel mult 2 minute), salvat cu precizia lui (> 100 m = „precizie slabă”, mesaj „… Afară, apăsați „Actualizează”.”); 3) dacă nici aproximativul nu vine → fereastra cu variantele din v1.25.0 („Nu s-a găsit semnal la timp” / „Poziția nu a putut fi aflată”, cu „Introdu coordonatele”). Refuzul permisiunii (la oricare cerere) → fereastra „Activați localizarea”.
- Fereastra „Activați localizarea”: motivul („… nu dă aplicației permisiunea de localizare (localizarea poate fi oprită)”), denumirile „Configurări → Confidențialitate și securitate → Servicii de localizare”, „Site-uri Safari”, „Configurări → Aplicații → Safari → Localizare” (în web). Pasul „reinstalați iconița după Backup rapid” apare doar în aplicația web de pe ecranul principal — în nativ NU se aplică.
- Ghidul, capitolul Obiectiv, paragraful „Coordonatele GPS”.
Date comune regenerate: docs/nativ/date/catalog.json, ghid.json (versiuneAplicatieWeb = 1.25.1 și paragraful GPS din ghid).
Vectori regenerați: niciunul schimbat.
Ce ai de făcut în Swift: 1) Dotări (TabObiectiv / ComponenteEditor): pe lățimi compacte, denumirea + controalele într-un ViewThatFits (HStack, altfel VStack cu controalele sub denumire), fără trunchiere; 2) GPS (Ferestre / SesiuneEditor): CLLocationManager — întâi kCLLocationAccuracyBest cu 20 s; la eroare locationUnknown sau timp depășit, a doua încercare cu kCLLocationAccuracyReduced / kCLLocationAccuracyKilometer, 15 s, acceptând o poziție de cel mult 2 minute; apoi fereastra cu variantele (coordonatele de mână). La .denied / .restricted: fereastra „Activați localizarea” cu buton care deschide Configurările aplicației (UIApplication.openSettingsURLString), fără pașii despre Safari; 3) textul ghidului din ghid.json; 4) testele.
Criterii de acceptare: ios/teste.sh 100%; pe iPhone (portret, text Mare), la Centrală termică, Hidranți interiori / exteriori, nimic nu se suprapune; în interior, fără semnal GPS, se salvează poziția aproximativă cu „precizie slabă”; cu localizarea refuzată apare fereastra de activare; versiunea din Setări = 1.25.1.
La final: versiunea nativă = v1.25.1; commit + PR; raport scurt pentru mine.
```

Aplicată în aplicația nativă odată cu v1.25.2 (același PR).

### v1.25.2 — „Aceeași dată ca la …” pe construcție; „Achitat / Executat silit” (29.09.2026)
Aplicată deja în aplicația nativă, în același PR (împreună cu v1.25.1 de mai sus). Promptul rămâne pentru istoric:

```
Actualizare la versiunea web v1.25.2. Rulează `git pull` pe main.
Ce s-a schimbat:
- „Aceeași dată ca la …”: js/model.js → verifReferinta(list, u): CT 2, CT 3… se raportează la CT 1 al aceleiași construcții, restul rândurilor (construcțiile, CT 1 al fiecărei construcții) la primul rând; js/editor.js (verifBlock: butonul „Aceeași dată ca la <referință>”, doar dacă referința are dată), js/app.js (verif-ca-prima copiază de la referință).
- Amenda închisă: butonul „Achitat / Executat silit” (în loc de „Achitată – dovadă primită”), câmpul „Data achitării / executării”; stadiul verde „Achitată / executată silit”, mesajul „Închisă · <data>” / „Închisă” (js/model.js fineStatus); js/views.js: LEVEL_LABEL, filtrul „Amendă achitată / executată silit”, pastilele „N amenzi · Achitate / executate silit”, Panou („+ N achitate / executate silit (nu intră în total)”, „Achitate / executate silit (N)”, legenda), cardul din Obiective, regulile din Setări; js/help.js.
- Versiunea: js/version.js, sw.js.
Date comune regenerate: catalog.json, ghid.json. Vectori regenerați: termene.json, demo.json (eticheta și mesajul amenzii achitate).
Ce ai de făcut în Swift: verifReferinta (Nereguli.swift), Editor.swift (verif-ca-prima), ModelEditor.swift (modelVerificare, caseta amenzii), Termene.swift (fineStatus), Liste.swift, Panou.swift, EcranPanou.swift, EcranSetari.swift; testele (ModelTests, EcraneWebTests).
Criterii de acceptare: ios/teste.sh 100%; la b3 cu 2 construcții a câte 2 centrale: CT 2 al Construcției 2 arată „Aceeași dată ca la Construcția 2 – CT 1”; la o amendă bifată „Achitat / Executat silit”, stadiul verde „Achitată / executată silit” peste tot.
La final: commit + PR; raport scurt.
```

### v1.26.0 — căutare și filtre la construcții; butonul „Filtre” la acte și nereguli (01.10.2026)
Aplicată deja în aplicația nativă, în același PR (lucrul s-a făcut din chatul nativ). Promptul rămâne pentru istoric:

```
Actualizare la versiunea web v1.26.0. Rulează `git pull` pe main.
Ce s-a schimbat:
- Construcții (tabul Obiectiv, de la 2 construcții): căutare (denumire sau, de la 3 litere, dotare bifată DA) și butonul „Filtre” — Dotate cu (DA), Fără (NU) (doar dotările existente, cu numărul construcțiilor), Dotări necompletate, Instalații lipsă; cumulate; etichete ✕ și „N din M construcții”; o singură construcție găsită se deschide, mai multe rămân restrânse; dotarea potrivită e evidențiată (.dot-row.is-match). js/model.js: dotariSummary (mutat din editor.js), dotareVal, constructiiFiltrate, optiuniFiltreConstructii; js/editor.js: constrToolsHTML, constrResultsHTML, isOpen(…, filtrat, unica), dotareRow(…, gasit); js/app.js: constr-search (input), constr-filtre, constr-flt, constr-q-clear; js/state.js: constrQuery, constrFlt, constrFltOpen.
- Acte / Nereguli / Planuri / PC: butonul „Filtre” (data-act tools-more, cu cifra filtrelor active) — panoul cu Stare (Toate / Constatate / Netrecute în PV / Neverificate; la Acte: Toate / Lipsă / Neverificate), Construcția (nereguli, la mai multe construcții; js/model.js inConstructie) și Afișare (fostul meniu ⋯); filtrele active sub bară, ca etichete ✕, lângă „Restul …”. Filtrul nou nerFilter = 'PV' (constatate, netrecute în PV). js/state.js: nerConstr, revealFilter; se golesc la ieșirea din control (construcția rămâne între taburi).
- „Ce mai aveți de făcut” și fereastra „Înainte de încheiere”: rândul „N constatări netrecute în PV” (id pv) are data-flt="PV" → tabul se deschide cu filtrul „Netrecute în PV”.
- Iconița nouă „filter”; css/app.css (.btn-filtre, .filtre-panel, .flt-grup, .flt-chip, .flt-active, .dot-row.is-match), css/telefon.css (starea pe 2 coloane); js/help.js; versiunea (js/version.js, sw.js).
Date comune regenerate: catalog.json, ghid.json.
Ce ai de făcut în Swift: Model/FiltreConstructii.swift (dotareVal, constructiiFiltrate, optiuniFiltreConstructii, inConstructie); StareEditor (nerConstr, constrQuery, constrFlt ordonat, constrFltOpen, revealFilter); Editor.swift (acțiunile noi, cautaConstructii, isOpen cu filtrele, constrFiltruNer, render / reveal / todo-go); ModelEditor.swift (ModelCautare cu stare / construcții / afișare, ModelEticheta, ModelUnelteConstructii, filtrul PV în sectionRows); Iconite.swift („filter”); interfața: RandUnelte + ButonFiltre + PanouFiltre + SegmentStare + EtichetaFiltru + BaraFiltru (TabConstatari.swift), UnelteConstructii (TabObiectiv.swift); EditorWebTests (jetoanele noi, pasul cautareConstr) și Diferential/editor.mjs (constr-search).
Criterii de acceptare: ios/teste.sh 100% (și pe alte semințe, NR_SECVENTE=200); pe iPad și iPhone: „sprinklere” în Construcții arată doar construcțiile cu sprinklere DA; „Filtre” → „Netrecute în PV” arată doar constatările netrecute; eticheta ✕ scoate filtrul.
La final: commit + PR; raport scurt.
```
