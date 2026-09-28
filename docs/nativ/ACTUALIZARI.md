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
