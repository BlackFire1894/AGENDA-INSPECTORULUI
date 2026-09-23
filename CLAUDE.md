# Agenda inspectorului — reguli pentru lucru

- Aplicație PWA fără build (HTML/CSS/JS module), publicată cu GitHub Pages din `main`. Utilizatorul lucrează pe iPad Air 11" și comunică în română.
- Modificările se fac pe branch și ajung în `main` doar prin PR aprobat de utilizator.
- **La fiecare modificare publicată**: crește `APP_VERSION` în `js/version.js` și `VERSION` în `sw.js` (aceeași valoare, semver). Fără asta, iPad-ul nu primește actualizarea.
- Orice fișier nou din `js/`, `css/` sau `icons/` trebuie adăugat în `ASSETS` din `sw.js` (testul verifică `js/`).
- Datele stau doar pe iPad (IndexedDB). O schimbare de structură trebuie să fie compatibilă cu datele vechi: completează câmpurile lipsă în `normalizeControl()` din `js/model.js`. Structura e descrisă în `docs/MODEL_DATE.md` — actualizeaz-o.
- Logica de termene (`fineStatus`, `asiDeadline`) e acoperită de `npm test`; rulează testele înainte de push.
- UI: text mare, ținte de atingere ≥ 44px, temă luminoasă și întunecată, portret (bara de jos) și peisaj (bara laterală, ≥ 1000px).
