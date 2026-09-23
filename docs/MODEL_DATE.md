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
| `constructii` | Constructie[] | |
| `acte` | `{ [cheie]: { status: "" \| "ok" \| "nok", obs } }` | chei: `ctpsi, lfd, instruire, organizare, comisie, sezon, controale, analiza, fise, stingatoare, contract, exercitii, registreExercitii, rapoarteExercitii` |
| `nereguli` | Neregula[] | toate rândurile de constatări, din toate secțiunile (vezi `sec`): șablon + rânduri `custom` |
| `adapostPC` | `{ v: "" \| "DA" \| "NU" \| "NEC", obs }` | adăpost de protecție civilă (doar LOCALITATE) |
| `createdAt`, `updatedAt` | ISO datetime | `updatedAt` decide la importul „Combină” |
| `demo` | bool? | date demonstrative |

## Constructie
`id, denumire, suprafata, regimInaltime, nrAngajati, structura, materialPereti, dotari, grf, gps`

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
| `status` | `""` \| `"ok"` (conform) \| `"nok"` (constatat) | |
| `obs` | string | |
| `inPV` | bool | trecut / netrecut în procesul-verbal |
| `vecheManual` | bool | marcată manual „neregulă veche”; se detectează și automat din istoric (`vecheInfo()`): același rând constatat la un control anterior al aceluiași obiectiv |
| `constructieIds` | string[] | construcțiile în care s-a constatat (una sau mai multe); `[]` sau doar id-uri inexistente = implicit: la neregulile grave cele cu NU la dotare, altfel prima construcție (`constructiiOf()`) |
| `grav` | bool | doar la rândurile adăugate (`custom`): marcat de inspector ca neregulă gravă |
| `sigiliu` | bool | la neregulile grave (din listă sau `grav`): s-a aplicat sigiliu în baza acestei nereguli |
| `auto` | bool | `ah` / `ai`: constatată automat din NU la ASI / AVIZ (dotări) |
| `obsAuto` | string | observațiile preluate automat; cât timp `obs === obsAuto`, se actualizează din dotări |
| `asiTermen`, `asiPrezentat`, `asiDataPrezentare` | | doar pentru `a` |
| `amenda` | `{ aplicata, serie, numar, data, suma, achitata, dataAchitare }` | `data = ""` → data încheierii; `serie`/`numar` = seria și numărul procesului-verbal de amendă |

Calculul termenelor: `js/model.js` → `fineStatus()`, `asiDeadline()`.

## Catalog (js/model.js)
- `NEREGULI`, `PLANURI`, `PROTECTIE_CIVILA` → `SABLON`: rândurile standard, fiecare cu `cat` (categoria pentru codul de culori) și, la instalații, `req` (dotările de care depinde).
- O neregulă cu `req` apare doar dacă cel puțin o construcție are DA la una din dotările listate (`centrala` = cel puțin un tip bifat). Un rând deja completat rămâne mereu vizibil.
- Schema 7 → 8: neregulile noi `ah` (construcția funcționează fără ASI) și `ai` (lucrări de extindere / modificare fără aviz), primele din listă, adăugate de `normalizeControl()`; câmpurile `auto` și `obsAuto` pe nereguli. NU la dotarea ASI / AVIZ constată automat `ah` / `ai` (`syncAutoNU()`), cu observațiile din dotări.
- Schema 6 → 7: construcțiile primesc `grf` (`""`); neregulile primesc `grav` și `sigiliu` (`false`); `constructieId` (un singur id) devine `constructieIds` (listă): `"x"` → `["x"]`, `""` → `[]` (`normalizeControl()`).
- Schema 5 → 6: `adresa`, `localitate` (`''`) pe control și `gps` (`null`) pe fiecare construcție. Schema 4 → 5: rândurile noi de nereguli (inclusiv `lipsa-*`, neregulile grave la NU) și dotarea `detectoriAutonomi`.
- Schema 3 → 4: `vecheManual: false` adăugat de `normalizeControl()`.
- Schema 2 → 3: câmpurile noi (`constructieId`, `amenda.serie`, `amenda.numar`, actele noi) se completează cu valori goale de `normalizeControl()`.
- Schema 1 → 2: `normalizeControl()` adaugă `sec: "ner"` rândurilor vechi și creează rândurile Planuri/PC și `adapostPC`.
