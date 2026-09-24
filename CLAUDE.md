# Agenda inspectorului — reguli pentru lucru

- Aplicație PWA fără build (HTML/CSS/JS module), publicată cu GitHub Pages din `main`. Utilizatorul lucrează pe iPad Air 11" și comunică în română.
- Modificările se fac pe branch și ajung în `main` doar prin PR aprobat de utilizator.
- **La fiecare modificare publicată**: crește `APP_VERSION` în `js/version.js` și `VERSION` în `sw.js` (aceeași valoare, semver). Fără asta, iPad-ul nu primește actualizarea.
- Orice fișier nou din `js/`, `css/` sau `icons/` trebuie adăugat în `ASSETS` din `sw.js` (testul verifică `js/`).
- Datele stau doar pe iPad (IndexedDB). O schimbare de structură trebuie să fie compatibilă cu datele vechi: completează câmpurile lipsă în `normalizeControl()` din `js/model.js`. Structura e descrisă în `docs/MODEL_DATE.md` — actualizeaz-o.
- **Controalele încheiate nu se schimbă la actualizări**: fiecare păstrează lista de nereguli din momentul încheierii (`catalog`). Când adaugi un rând în listă (`NEREGULI`, `PLANURI`, …), crește `SCHEMA_VERSION` și pune-i `din: <noua schemă>`; când scoți unul, nu-l șterge — pune `retrasDin: <noua schemă>`. Nu schimba sensul unei chei existente (textul poate fi corectat, cheia nu se refolosește).
- Logica de termene (`fineStatus`, `asiDeadline`) e acoperită de `npm test`; rulează testele înainte de push.
- Dimensiuni în CSS doar în `rem` (baza = 18px la „Mare”, 16.5px „Mediu”, 15px „Mic”), ca setarea de mărime a textului să scaleze tot. Excepții: bordurile subțiri, umbrele și media queries rămân în px. Înălțimile țintelor de atingere folosesc `max(44px, …rem)`, iar fontul câmpurilor de text `max(16px, …rem)`, altfel iOS mărește pagina la focus.
- Ajutorul din aplicație (`js/help.js`: ghidul în 4 pași și textele „?” pe fiecare ecran/tab) trebuie actualizat odată cu funcțiile pe care le descrie.
- UI: text mare, ținte de atingere ≥ 44px, temă luminoasă și întunecată, portret (bara de jos) și peisaj (bara laterală, ≥ 1000px).
