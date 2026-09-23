# Agenda inspectorului

Aplicație web instalabilă (PWA) pentru iPad, în care inspectorul își completează datele constatate în teren.
Funcționează **offline**, iar datele rămân **doar pe tabletă** (IndexedDB), cu backup manual în Fișiere / iCloud Drive.

## Ce face

| Ecran | Conținut |
|---|---|
| **Panou** (în locul widgetului) | data și ora tabletei, amenzi pe stadii (albastru / galben / roșu / verde), controale neîncheiate, termene ASI 90 de zile, nereguli netrecute în PV — fiecare cu detalii și link direct |
| **Obiective** | lista obiectivelor controlate, căutare după nume **sau** dată (`12.09.2026`, `09.2026`, `2026` sau selector de dată), filtru OPEC / Localitate |
| **Obiectiv** | datele de contact (apel / email dintr-o atingere) și istoricul tuturor controalelor |
| **Calendar** | controalele marcate pe zile, plus termenele de plată, ANAF și ASI; „Control nou în această zi” |
| **Istoric** | toate controalele, grupate pe luni, cu căutare și filtre |
| **Control** | 3 taburi: **Obiectiv** (date, perioadă, construcții și dotări) · **Acte & evidențe** (✓ verde / ✗ roșu) · **Nereguli** (șablon a–z + nereguli suplimentare, trecut/netrecut în PV, amendă, termen ASI) |

Salvare automată la fiecare modificare. Mărimea textului (Mic / Mediu / Mare) se alege din **Setări** și scalează proporțional toată interfața. Un control nou pe un obiectiv existent preia automat datele de contact și construcțiile din ultimul control.

## Termene

Toate termenele curg de la data de referință **+ 1 zi**, după data și ora tabletei.

- **Amendă** (data aplicării, implicit data încheierii controlului):
  - 🔵 zilele 1–15: în curs
  - 🟡 zilele 16–39: termenul de 15 zile a expirat
  - 🔴 din ziua 40: *„Mai ai 5 zile până să o trimiți la ANAF, consultă calculatorul de termene”* (termen ANAF: ziua 45 = 15 + 30 de zile, conform art. 39 alin. (1) din OG 2/2001)
  - 🟢 achitată, cu dovada primită
- **ASI**: 90 de zile de la data încheierii controlului.
- Aplicația **nu** prelungește termenele care se încheie într-o zi nelucrătoare.

Logica este acoperită de teste: `npm test`.

## Instalare pe iPad

Aplicația trebuie servită prin **HTTPS** (e o cerință pentru service worker și stocarea persistentă):

1. Publicați conținutul folderului pe un host static:
   - **GitHub Pages**: repository-ul este privat, deci Pages cere un plan GitHub Pro; alternativ, faceți repository-ul public (codul nu conține date — acestea rămân pe tabletă).
   - **Netlify / Cloudflare Pages**: încărcați folderul prin drag-and-drop.
2. Pe iPad, deschideți adresa în **Safari** → butonul Partajare → **Adaugă pe ecranul principal**.
3. Porniți aplicația **din iconița de pe ecranul principal**. Doar așa Safari păstrează datele pe termen lung; în taburile obișnuite, stocarea poate fi ștearsă după o perioadă de neutilizare.
4. Faceți periodic backup: **Setări → Exportă backup → Salvează în Fișiere**. Panoul vă reamintește după 7 zile fără backup.

Rulare locală: `npm start` și apoi `http://localhost:8080`.

## Modificări și actualizări

1. Modificările se fac pe un branch separat și ajung în `main` printr-un **Pull Request** aprobat.
2. GitHub Pages publică `main` automat, în 1–3 minute după aprobare.
3. Pe iPad, la următoarea deschidere apare mesajul **„Versiune nouă disponibilă — Actualizează”**. Există și butonul **Setări → Actualizări → Verifică acum**.
4. Datele controalelor nu sunt atinse de actualizări. Faceți totuși backup înaintea actualizărilor importante.

Regula pentru fiecare versiune publicată: se crește `APP_VERSION` în `js/version.js` **și** `VERSION` în `sw.js`, cu aceeași valoare. Fără asta, iPad-ul nu află de versiunea nouă. `npm test` verifică potrivirea.

## Widget pe Home / Lock Screen

Widgeturile iOS sunt disponibile doar în aplicațiile native (WidgetKit), deci nu pot exista într-o aplicație web. Pentru compilarea lor e nevoie de Xcode pe Mac. Modelul de date este documentat în [`docs/MODEL_DATE.md`](docs/MODEL_DATE.md) și pregătit pentru portarea în SwiftUI: backupul JSON poate fi importat direct într-o versiune nativă.

## Structură

```
index.html            shell-ul aplicației
css/app.css           stiluri (temă luminoasă/întunecată, portret/peisaj)
js/app.js             rutare, evenimente, control nou, backup
js/views.js           Panou, Obiective, Calendar, Istoric, Setări
js/editor.js          editorul controlului (3 taburi)
js/model.js           modelul de date + calculul termenelor (fără DOM, testabil)
js/dates.js           utilitare pentru date
js/store.js           IndexedDB (cu localStorage ca rezervă)
js/demo.js            date demonstrative
js/version.js         versiunea aplicației
sw.js                 funcționare offline
tests/                teste pentru logica de termene și căutare
```
