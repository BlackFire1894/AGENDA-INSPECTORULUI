# Modelul de date (schema 6)

Backupul exportat este un JSON: `{ app, schema, exportedAt, controls: Control[] }`.
Datele calendaristice sunt șiruri `AAAA-LL-ZZ` în ora locală; `""` înseamnă necompletat.

## Control
| câmp | tip | note |
|---|---|---|
| `id` | string | unic |
| `objectiveId` | string | leagă controalele aceluiași obiectiv (istoric) |
| `tip` | `"OPEC"` \| `"LOCALITATE"` | |
| `denumire`, `administrator`, `telefon`, `email` | string | datele obiectivului se iau din cel mai recent control |
| `dataInceput` | date | implicit data curentă |
| `dataIncheiere` | date \| `""` | `""` = control neîncheiat |
| `catalog` | number? | doar la controalele încheiate: versiunea (schema) listei de nereguli cu care au fost încheiate; lista lor nu se mai schimbă la actualizări |
| `constructii` | Constructie[] | |
| `acte` | `{ [cheie]: { status: "" \| "ok" \| "nok" \| "nec", obs } }` | chei: `ctpsi, lfd, instruire, organizare, comisie, sezon, controale, analiza, fise, stingatoare, contract, exercitii, registreExercitii, rapoarteExercitii` |
| `nereguli` | Neregula[] | toate rândurile de constatări, din toate secțiunile (vezi `sec`): șablon + rânduri `custom` |
| `adapostPC` | `{ v: "" \| "DA" \| "NU" \| "NEC", obs }` | adăposturi de protecție civilă (Localitate: tabul PC; OPEC: tabul Obiectiv, din v1.22); la DA, fiecare adăpost e un rând `adapost` în `nereguli` |
| `incarcare` | `{ aplicatie, aplicatieData, document, documentData }` | după încheiere: controlul încărcat în aplicația ISU / documentul (PV scanat) încărcat — bifa (`true/false`) și data bifării; termen: 3 zile lucrătoare de la `dataIncheiere` |
| `createdAt`, `updatedAt` | ISO datetime | `updatedAt` decide la importul „Combină” |
| `demo` | bool? | date demonstrative |

## Constructie
`id, denumire, suprafata, regimInaltime, nrAngajati, anConstruire, structura, materialPereti, dotari, grf, gps`

`grf`: `"I"`…`"V"`, `"NN"` (nu e necesar) sau `""` — GRF (P118/1999) / NSI (P118-1/2025). `"V"` cu `regimInaltime` peste parter (`pesteParter()`: P+1, P+2E, S+P+1, P+M…) declanșează neregula gravă `grav-grfV`.

`gps`: `{ lat, lon, acc, la }` sau `null` — coordonatele construcției (grade zecimale, WGS84), precizia în metri și momentul preluării. Se preiau doar la cerere („Completează coordonatele”) și se copiază la controlul următor pe același obiectiv.

`dotari[cheie] = { v: "" | "DA" | "NU" | "NEC", obs }` (NEC = nu este cazul) pentru
`asi, aviz, hidInt, hidExt, sprinklere, drencere, instSpeciale, idsai, exit, desfumare, ignifugare, rezervaApa, statiePompe`
(DA/NU/NEC) și `fotovoltaice, acumulatori, ilumHint, ipt` (DA/NU).

`dotari.centrala = { tipuri: ("SOLID"|"GAZOS"|"ELECTRIC")[], nuAre: bool, obs }`

## Neregula
| câmp | tip | note |
|---|---|---|
| `key` | string | literă (`a`…`z`, `ș`, `ț`) la Nereguli, cheie text la Planuri/PC (ex. `paar`, `svsuSef`, `pcSireneDefecte`), `k…` la rândurile custom |
| `sec` | `"ner"` \| `"plan"` \| `"pc"` | tabul: Nereguli / Planuri și SVSU / Protecție civilă. `plan` și `pc` contează doar la LOCALITATE |
| `custom` | bool | `label` e folosit doar la cele custom |
| `status` | `""` \| `"ok"` (conform) \| `"nok"` (constatat) \| `"nec"` (nu este cazul; nu apare în PV) | |
| `obs` | string | |
| `inPV` | bool | trecut / netrecut în procesul-verbal |
| `vecheManual` | bool | marcată manual „neregulă veche”; se detectează și automat din istoric (`vecheInfo()`): același rând constatat la un control anterior al aceluiași obiectiv |
| `constructieIds` | string[] | construcțiile în care s-a constatat (una sau mai multe); `[]` sau doar id-uri inexistente = implicit: la neregulile grave cele cu NU la dotare, altfel prima construcție (`constructiiOf()`) |
| `grav` | bool | doar la rândurile adăugate (`custom`): marcat de inspector ca neregulă gravă |
| `sigiliu` | bool | la neregulile grave (din listă sau `grav`): s-a aplicat sigiliu în baza acestei nereguli |
| `auto` | bool | `ah` / `ai`: constatată automat din NU la ASI / AVIZ (dotări) |
| `obsAuto` | string | observațiile preluate automat; cât timp `obs === obsAuto`, se actualizează din dotări |
| `verificari` | object | rândurile de verificare (b1–b3, c1–c7): `idConstrucție → { data: "AAAA-LL-ZZ", luni }` — data ultimei verificări; `luni` doar la b2 (12 / 24). Expirare = data + luni < data începerii controlului (`verifStare()`). Se preiau la controlul următor. |
| `asiTermen`, `asiPrezentat`, `asiDataPrezentare` | | doar pentru `a` |
| `asiPierdere`, `asiDataPierdere` | | doar pentru `a`: după cele 90 de zile, pierderea valabilității constatată (5 zile calendaristice) |
| `amenda` | `{ aplicata, serieNr, data, suma, achitata, dataAchitare }` | `data = ""` → data încheierii; `serieNr` = seria și numărul procesului-verbal de amendă, într-un singur câmp (ex. „DB 0012345”; afișat „Seria DB nr. 0012345”) |

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
