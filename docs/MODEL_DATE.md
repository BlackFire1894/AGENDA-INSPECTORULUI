# Modelul de date (schema 12)

Backupul exportat este un JSON: `{ app, schema, exportedAt, controls: Control[] }`.
Datele calendaristice sunt șiruri `AAAA-LL-ZZ` în ora locală; `""` înseamnă necompletat.

## Control
| câmp | tip | note |
|---|---|---|
| `id` | string | unic |
| `objectiveId` | string | leagă controalele aceluiași obiectiv (istoric) |
| `tip` | `"OPEC"` \| `"LOCALITATE"` | |
| `denumire`, `administrator`, `telefon`, `email` | string | datele obiectivului se iau din cel mai recent control |
| `persoanaParticipanta` | string | v1.25: persoana care a participat la control din partea obiectivului |
| `observatiiGenerale` | string | v1.25: notițe libere despre obiectiv / control |
| `deIntrebat` | `{ id, text, gata }[]` | v1.25: „De întrebat până la finalizarea controlului”; cele cu `gata: false` și text apar în `todoList()` (`intreb-<id>`) |
| `dataInceput` | date | implicit data curentă |
| `dataIncheiere` | date \| `""` | `""` = control neîncheiat |
| `catalog` | number? | doar la controalele încheiate: versiunea (schema) listei de nereguli cu care au fost încheiate; lista lor nu se mai schimbă la actualizări |
| `constructii` | Constructie[] | |
| `acte` | `{ [cheie]: { status: "" \| "ok" \| "nok" \| "nec", obs } }` | chei: `ctpsi, lfd, fumat (v1.25), instruire, organizare, comisie, sezon, controale, analiza, fise, stingatoare, contract, exercitii, registreExercitii, rapoarteExercitii`; actele cu `din` apar doar în lista controalelor deschise / încheiate de atunci (`acteOf()`) |
| `nereguli` | Neregula[] | toate rândurile de constatări, din toate secțiunile (vezi `sec`): șablon + rânduri `custom` |
| `adapostPC` | `{ v: "" \| "DA" \| "NU" \| "NEC", obs }` | adăposturi de protecție civilă (Localitate: tabul PC; OPEC: tabul Obiectiv, din v1.22); la DA, fiecare adăpost e un rând `adapost` în `nereguli` |
| `incarcare` | `{ aplicatie, aplicatieData, document, documentData }` | după încheiere: controlul încărcat în aplicația ISU / documentul (PV scanat) încărcat — bifa (`true/false`) și data bifării; termen: 3 zile lucrătoare de la `dataIncheiere` |
| `createdAt`, `updatedAt` | ISO datetime | `updatedAt` decide la importul „Combină” |
| `demo` | bool? | date demonstrative |

## Constructie
`id, denumire, suprafata, regimInaltime, nrAngajati, anConstruire, structura, materialPereti, dotari, grf, gps`

`grf`: `"I"`…`"V"`, `"NN"` (nu e necesar) sau `""` — GRF (P118/1999) / NSI (P118-1/2025). `"V"` cu `regimInaltime` peste parter (`pesteParter()`: P+1, P+2E, S+P+1, P+M…) declanșează neregula gravă `grav-grfV`.

`gps`: `{ lat, lon, acc, la }` sau `null` — coordonatele construcției (grade zecimale, WGS84), precizia în metri și momentul preluării. Se preiau doar la cerere („Completează coordonatele”) și se copiază la controlul următor pe același obiectiv. v1.25: introduse de mână (`parseCoord()`): `{ lat, lon, acc: null, la, manual: true }`; „Aceleași coordonate ca la prima construcție” copiază obiectul primei construcții.

`dotari[cheie] = { v: "" | "DA" | "NU" | "NEC", obs }` (NEC = nu este cazul) pentru
`asi, aviz, hidInt, hidExt, sprinklere, drencere, instSpeciale, idsai, exit, desfumare, ignifugare, rezervaApa, statiePompe`
(DA/NU/NEC) și `fotovoltaice, acumulatori, ipt, ascensor` (DA/NU); `ilumHint` DA/NU/NEC din v1.25 (ascuns și ignorat când `hidInt` e NU / NEC: `ilumHintAscuns()`, `valDotare()`). `ascensor` (v1.25, `din: 12`): fără neregulă.

`dotari.centrala = { tipuri: ("SOLID"|"GAZOS"|"ELECTRIC")[], nuAre: bool, obs, ct: { id, tipuri }[] }` — v1.25: `ct` = centralele construcției (CT 1, CT 2…), fiecare cu tipurile ei; `tipuri` = toate tipurile lor (compatibilitate). Date vechi: `tipuri` nevide → `ct: [{ id: "ct1", tipuri }]` (`normalizeControl()`).

## Neregula
| câmp | tip | note |
|---|---|---|
| `key` | string | literă (`a`…`z`, `ș`, `ț`) la Nereguli, cheie text la Planuri/PC (ex. `paar`, `svsuSef`, `pcSireneDefecte`), `k…` la rândurile custom |
| `sec` | `"ner"` \| `"plan"` \| `"pc"` | tabul: Nereguli / Planuri și SVSU / Protecție civilă. `plan` și `pc` contează doar la LOCALITATE |
| `custom` | bool | `label` e folosit doar la cele custom |
| `status` | `""` \| `"ok"` (conform) \| `"nok"` (constatat) \| `"nec"` (nu este cazul; nu apare în PV) | |
| `obs` | string | |
| `inPV` | bool | trecut / netrecut în procesul-verbal |
| `vecheManual` | bool | marcată manual „neregulă veche”; se detectează și automat (`vecheInfo()`): același rând constatat la controlul **imediat anterior** al aceluiași obiectiv (v1.25; înainte: oricare anterior) |
| `constructieIds` | string[] | construcțiile în care s-a constatat (una sau mai multe); `[]` sau doar id-uri inexistente = implicit: la neregulile grave cele cu NU la dotare, altfel prima construcție (`constructiiOf()`); neregulile actelor (`ao`, `ap`, `aq`) nu au construcție |
| `ctIds` | string[]? | v1.25, doar la rândurile pe centrală termică (`b3`, `g`, `h`): centralele alese, `"<idConstrucție>:<idCentrală>"`; lipsă = toate centralele construcțiilor alese (`centraleAlese()`) |
| `grav` | bool | doar la rândurile adăugate (`custom`): marcat de inspector ca neregulă gravă |
| `sigiliu` | bool | la neregulile grave (din listă sau `grav`): s-a aplicat sigiliu în baza acestei nereguli |
| `auto` | bool | `ah` / `ai` / `am`: constatată automat din NU la ASI / AVIZ / iluminat Hint (dotări); `ao` / `ap` / `aq` (v1.25): din actele „Lipsă” (`syncAutoActe()`) |
| `obsAuto` | string | observațiile preluate automat; cât timp `obs === obsAuto`, se actualizează din dotări / acte |
| `verificari` | object | rândurile de verificare (b1–b3, c1–c7): `idUnitate → { data: "AAAA-LL-ZZ", luni }` — data ultimei verificări; `luni` doar la b2 (12 / 24). Unitatea (`verifUnitati()`) = construcția; la `b3` din v1.25, fiecare centrală: `"<idConstrucție>:<idCentrală>"` (prima centrală preia data scrisă înainte pe construcție). Expirare = data + luni < data începerii controlului (`verifStare()`). v1.25: la controlul următor pornesc goale. |
| `asiTermen`, `asiPrezentat`, `asiDataPrezentare` | | doar pentru `a` |
| `asiPierdere`, `asiDataPierdere` | | doar pentru `a`: după cele 90 de zile, pierderea valabilității constatată (5 zile calendaristice) |
| `amenda` | `{ aplicata, serieNr, data, suma, achitata, dataAchitare }` | `data = ""` → data încheierii; `serieNr` = seria și numărul, într-un singur câmp — din v1.25 nu se mai completează și nu se mai afișează (valorile vechi rămân în date) |

Calculul termenelor: `js/model.js` → `fineStatus()`, `asiDeadline()`.

## Catalog (js/model.js)
- `NEREGULI`, `PLANURI`, `PROTECTIE_CIVILA` → `SABLON`: rândurile standard, fiecare cu `cat` (categoria pentru codul de culori) și, la instalații, `req` (dotările de care depinde).
- O neregulă cu `req` apare doar dacă cel puțin o construcție are DA la una din dotările listate (`centrala` = cel puțin un tip bifat). Un rând deja completat rămâne mereu vizibil.
- Schema 9 → 10: `catalog` (număr) pe controalele încheiate — lista de nereguli a versiunii în care au fost încheiate (`catalogOf()`, `inCatalog()`; rândurile au `din` / `retrasDin`); cele încheiate înainte primesc `schema` (versiunea în care au fost create). Se fixează la încheiere și se eliberează la redeschidere (`fixeazaCatalog()`, la fiecare salvare). Amenda: `serie` + `numar` → `serieNr` (un singur câmp). Actele pot avea și `status: "nec"`.
- Schema 8 → 9: `status` poate fi și `"nec"` (nu este cazul); verificările `b` și `c` sunt defalcate în `b1`–`b3`, `c1`–`c7` (cele vechi rămân doar unde au fost completate); nereguli noi `aj` (EXIT incomplet), `ak` (iluminat Hint incomplet), `al` (stingătoare insuficiente / lipsă), `am` (lipsă iluminat Hint — constatată automat la NU pentru Iluminat Hint, vizibilă doar atunci); `verificari` pe nereguli; construcțiile primesc `anConstruire`; dotările ASI / AVIZ primesc `nr` (numărul autorizației / avizului, la DA).
- Schema 7 → 8: neregulile noi `ah` (construcția funcționează fără ASI) și `ai` (lucrări de extindere / modificare fără aviz), primele din listă, adăugate de `normalizeControl()`; câmpurile `auto` și `obsAuto` pe nereguli. NU la dotarea ASI / AVIZ constată automat `ah` / `ai` (`syncAutoNU()`), cu observațiile din dotări.
- Schema 6 → 7: construcțiile primesc `grf` (`""`); neregulile primesc `grav` și `sigiliu` (`false`); `constructieId` (un singur id) devine `constructieIds` (listă): `"x"` → `["x"]`, `""` → `[]` (`normalizeControl()`).
- Schema 5 → 6: `adresa`, `localitate` (`''`) pe control și `gps` (`null`) pe fiecare construcție. Schema 4 → 5: rândurile noi de nereguli (inclusiv `lipsa-*`, neregulile grave la NU) și dotarea `detectoriAutonomi`.
- Schema 3 → 4: `vecheManual: false` adăugat de `normalizeControl()`.
- Schema 2 → 3: câmpurile noi (`constructieId`, `amenda.serie`, `amenda.numar`, actele noi) se completează cu valori goale de `normalizeControl()`.
- Schema 1 → 2: `normalizeControl()` adaugă `sec: "ner"` rândurilor vechi și creează rândurile Planuri/PC și `adapostPC`.
- v1.25 (schema 12): nereguli noi `ao` (acte lipsă, grupate), `ap` (lipsă controale proprii), `aq` (lipsă analiză semestrială) — automate, vizibile doar cât timp actele sunt „Lipsă” (`autoActe`) — și `an` (chepengul / ușa de acces în pod nu este RF 30 / 45 minute, categoria `electric`); actul `fumat`; dotarea `ascensor`; `b3`, `g`, `h` pe centrală termică (`perCT`). Toate cu `din: 12`: controalele încheiate înainte nu le primesc. Controalele **în desfășurare** cu `schema < 12` primesc o singură dată, la încărcare, neregulile actelor lipsă și retragerea „Lipsă iluminat Hint” fără hidranți interiori; `schema` devine 12. Control nou pe obiectiv (`controlFromPrevious()`): preia tot din controlul imediat anterior (constatările cu `status: "nok"`, observațiile și construcțiile lor; adăposturile neconforme); de la zero: perioada, `verificari`, starea actelor, încărcarea, PV, amenzile, sigiliile, termenul ASI, rândurile ok / nec.
- v1.22 (schema 11): 4 rânduri noi în Protecție civilă, categoria `pcorg`: `pcAgentInundatii`, `pcInspector`, `pcTaxa`, `pcConventii` (`din: 11`; controalele încheiate înainte nu le primesc).
- v1.22: **adăposturile** sunt rânduri în `nereguli` cu `custom: true`, `adapost: true`, cheia `adp…`, `locatie` (text) și `sec` = `pc` (Localitate) sau `ner` (OPEC), sincronizat cu tipul la fiecare salvare (`syncAdaposturi`). `status`: `ok` (conform) / `nok` (neconform = neregulă, cu PV, amendă, neregulă veche) / gol. Contează doar când `adapostPC.v === "DA"`; trecerea pe NU / NEC le șterge (cu confirmare). Controlul următor le preia cu aceeași cheie și locație, starea golită (neregula veche se recunoaște după cheie). Datele vechi nu au astfel de rânduri: nimic de completat.
- v1.16: `normalizeControl()` adaugă `incarcare` (bife goale) controalelor vechi; rândurile primesc `asiPierdere: false`, `asiDataPierdere: ""` din șablonul gol. Fără schimbare de `SCHEMA_VERSION` (lista de nereguli nu se schimbă).

## Activitățile planului lunar (v1.18)

Se păstrează separat de controale, în `meta` (cheia `activitati`, o listă), și intră în backup (`activitati` lângă `controls`). Un backup mai vechi, fără `activitati`, nu le atinge pe cele de pe tabletă.

| Câmp | Valori | Rol |
|---|---|---|
| `id` | text | identificator |
| `tip` | `instruire`, `sedinta`, `birou`, `informare`, `exercitiu`, `concediu`, `alta` | tipul (culoarea în calendar, gruparea în raport) |
| `data`, `dataSfarsit` | `AAAA-LL-ZZ`; `dataSfarsit` gol = o singură zi | perioada |
| `ora` | `HH:MM` sau gol | opțional |
| `descriere` | text | obligatorie la `alta` |
| `stare` | `planificat` / `efectuat` / `anulat` | planificatele trecute apar în Panou „de confirmat” |
| `obs` | text | observații |
| `objectiveId` | id sau gol | obiectivul la care se referă (opțional) |
| `demo` | `true` | doar la datele demonstrative |
| `createdAt`, `updatedAt` | ISO | la import „Combină” rămâne versiunea mai nouă |

`normalizeActivitate()` (în `js/activitati.js`) completează câmpurile lipsă și corectează valorile necunoscute.


Zilele libere (weekend + sărbători legale, v1.19) **nu se salvează**: `ziLibera()` le calculează la afișare din `zinelucratoare()` (efectuate până azi inclusiv, planificate după), deci nu intră în backup și nu schimbă structura datelor.
