# Pornirea aplicației native — pașii și promptul

## Pașii dumneavoastră, înainte de noul chat (o singură dată)

1. **Claude, pe MacBook.** Noul chat trebuie să ruleze **pe MacBook**, ca să poată compila în Xcode și să-și corecteze singur erorile. Aveți două variante:
   - aplicația **Claude** pentru Mac (claude.ai/download) → secțiunea **Code**;
   - sau, în Terminal: `npm install -g @anthropic-ai/claude-code`, apoi `claude` în folderul proiectului.
2. **Proiectul, în Terminal:**
   ```
   cd ~/Documents
   git clone https://github.com/BlackFire1894/AGENDA-INSPECTORULUI.git
   cd AGENDA-INSPECTORULUI
   ```
   Dacă îl aveți deja: `cd ~/Documents/AGENDA-INSPECTORULUI && git pull`.
3. **Xcode 27:** deschideți-l o dată și adăugați contul Apple în **Xcode → Settings → Accounts → +**.
4. **iPad-ul:**
   - conectați-l prin cablu și apăsați **Ai încredere**;
   - activați **Configurări → Confidențialitate și securitate → Mod dezvoltator**; iPad-ul repornește.
5. **Chatul nou:** porniți-l în folderul `AGENDA-INSPECTORULUI` și lipiți promptul de mai jos.

---

## Promptul (copiați tot ce e între linii)

---

Construim de la zero, în Swift, **aplicația nativă iOS/iPadOS „Agenda inspectorului”**. Este o reproducere **1 la 1** a aplicației web din acest repo: aceleași ecrane, texte, reguli de calcul, culori și fluxuri. În plus: widgeturi pe ecranul principal și pe ecranul blocat, notificări locale și cifra urgentelor pe iconiță.

**Citește întâi, în ordinea asta:**
1. `docs/nativ/SPECIFICATIE.md`: specificația completă, arhitectura și ordinea de lucru. E obligatorie.
2. `CLAUDE.md` și `docs/JURNAL.md`: regulile și memoria proiectului (context, funcții, reguli de calcul, decizii).
3. `docs/MODEL_DATE.md`: structura datelor. Backupurile trebuie să fie compatibile în ambele sensuri.

**Sursa adevărului e aplicația web** (`js/`, `css/`). Nu inventa funcții, texte sau reguli. Portează funcțiile păstrându-le numele. Rulează aplicația web local (`python3 -m http.server 8080`) și compar-o ecran cu ecran.

**Datele comune și testele** sunt în `docs/nativ/date/` (se includ în aplicație și se citesc) și în `docs/nativ/vectori/` (cazuri de test cu rezultatul exact al aplicației web). Scrie teste XCTest care trec 100% pe toți vectorii înainte de a construi ecranele pe logica respectivă. Nu modifica vectorii; la o nepotrivire, greșeala e în Swift.

**Cum lucrezi:**
- Cod în folderul `ios/`. La început, creează `ios/CLAUDE.md` cu textul din secțiunea 9 a specificației.
- Lucrează pe etapele din secțiunea 6 a specificației. După fiecare etapă:
  - compilează și rulează testele;
  - instalează pe iPad-ul conectat;
  - dă-mi un raport scurt, în română, cu ce pot încerca;
  - fă commit pe un branch și deschide un PR. Ajunge în `main` doar după aprobarea mea.
- În etapa 1, verifică imediat dacă contul meu gratuit (Personal Team) acceptă App Groups, necesar widgetului. Spune-mi rezultatul.
- Comunică în română, scurt, fără ziduri de text. Propunerile și nelămuririle mi le pui ca întrebări cu variante.
- Spune-mi direct orice greșeală, limită sau risc, inclusiv limitele contului gratuit (reinstalare la 7 zile).

**Despre mine:** sunt inspector de prevenire ISU. Lucrez pe iPad Air 11" (iPadOS 27), am un iPhone 12 Pro Max (iOS 27), un MacBook Air M2 cu Xcode 27 și un cont Apple gratuit.

Începe cu etapa 1.

---

## După aceea

- **La fiecare actualizare** a aplicației web vă dau **un prompt de actualizare** pentru chatul aplicației native. Toate se adună în `docs/nativ/ACTUALIZARI.md`.
- **Dacă chatul nativ se oprește** sau începeți unul nou, spuneți-i: „Citește `ios/CLAUDE.md`, `docs/nativ/SPECIFICATIE.md` și ultimele intrări din `docs/nativ/ACTUALIZARI.md`, apoi continuă de unde a rămas.”
