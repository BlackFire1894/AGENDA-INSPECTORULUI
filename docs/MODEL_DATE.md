# Modelul de date (schema 1)

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
| `acte` | `{ [cheie]: { status: "" \| "ok" \| "nok", obs } }` | chei: `ctpsi, lfd, instruire, organizare, comisie, sezon, controale, analiza, fise, stingatoare, contract` |
| `nereguli` | Neregula[] | șablon a–z + rânduri `custom` |
| `createdAt`, `updatedAt` | ISO datetime | `updatedAt` decide la importul „Combină” |
| `demo` | bool? | date demonstrative |

## Constructie
`id, denumire, suprafata, regimInaltime, nrAngajati, structura, materialPereti, dotari`

`dotari[cheie] = { v: "" | "DA" | "NU" | "NEC", obs }` pentru
`asi, aviz, hidInt, hidExt, sprinklere, drencere, instSpeciale, idsai, exit, desfumare, ignifugare, rezervaApa, statiePompe`
(DA/NU/NEC) și `fotovoltaice, acumulatori, ilumHint, ipt` (DA/NU).

`dotari.centrala = { tipuri: ("SOLID"|"GAZOS"|"ELECTRIC")[], nuAre: bool, obs }`

## Neregula
| câmp | tip | note |
|---|---|---|
| `key` | string | literă (`a`…`z`, `ș`, `ț`) sau `k…` pentru rândurile custom |
| `custom` | bool | `label` e folosit doar la cele custom |
| `status` | `""` \| `"ok"` (conform) \| `"nok"` (constatat) | |
| `obs` | string | |
| `inPV` | bool | trecut / netrecut în procesul-verbal |
| `asiTermen`, `asiPrezentat`, `asiDataPrezentare` | | doar pentru `a` |
| `amenda` | `{ aplicata, data, suma, achitata, dataAchitare }` | `data = ""` → data încheierii |

Calculul termenelor: `js/model.js` → `fineStatus()`, `asiDeadline()`.
