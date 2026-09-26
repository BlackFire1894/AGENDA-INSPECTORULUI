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
