# Modelul de date (schema 3)

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
`id, denumire, suprafata, regimInaltime, nrAngajati, structura, materialPereti, dotari`

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
| `constructieId` | string | construcția în care s-a constatat; `""` sau un id inexistent = prima construcție (`constructieOf()`) |
| `asiTermen`, `asiPrezentat`, `asiDataPrezentare` | | doar pentru `a` |
| `amenda` | `{ aplicata, serie, numar, data, suma, achitata, dataAchitare }` | `data = ""` → data încheierii; `serie`/`numar` = seria și numărul procesului-verbal de amendă |

Calculul termenelor: `js/model.js` → `fineStatus()`, `asiDeadline()`.

## Catalog (js/model.js)
- `NEREGULI`, `PLANURI`, `PROTECTIE_CIVILA` → `SABLON`: rândurile standard, fiecare cu `cat` (categoria pentru codul de culori) și, la instalații, `req` (dotările de care depinde).
- O neregulă cu `req` apare doar dacă cel puțin o construcție are DA la una din dotările listate (`centrala` = cel puțin un tip bifat). Un rând deja completat rămâne mereu vizibil.
- Schema 2 → 3: câmpurile noi (`constructieId`, `amenda.serie`, `amenda.numar`, actele noi) se completează cu valori goale de `normalizeControl()`.
- Schema 1 → 2: `normalizeControl()` adaugă `sec: "ner"` rândurilor vechi și creează rândurile Planuri/PC și `adapostPC`.
