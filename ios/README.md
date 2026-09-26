# Agenda — aplicația nativă pentru iPad și iPhone

Aplicația nativă afișează **aceeași aplicație web** ca în Safari (încărcată de pe GitHub Pages). Adaugă ce nu poate face o pagină web:

- **widgeturi**: pe ecranul principal (mic, mediu, mare) și pe ecranul blocat (cerc, dreptunghi, rând);
- **notificări** pentru termene, activități, backup și sărbătorile legale;
- **cifra de pe iconiță**: lucrurile urgente;
- **partajarea și tipărirea**, prin ferestrele iOS.

**Actualizările** din `main` ajung singure, ca pe iPad acum: apare bara „Versiune nouă” și apăsați **Actualizează**. În Xcode lucrați doar când se schimbă ceva în folderul `ios/`.

---

## Instalarea (o singură dată)

Pașii sunt pentru un MacBook cu Xcode 27 și un iPad cu iPadOS 27 sau un iPhone cu iOS 27.

### 1. Programele necesare, în Terminal
Dacă nu aveți Homebrew, instalați-l mai întâi (comanda de pe https://brew.sh). Apoi:
```
brew install xcodegen
```

### 2. Proiectul
```
cd ~/Documents
git clone https://github.com/BlackFire1894/AGENDA-INSPECTORULUI.git
cd AGENDA-INSPECTORULUI/ios
xcodegen
open Agenda.xcodeproj
```
Dacă aveți deja folderul: `cd ~/Documents/AGENDA-INSPECTORULUI && git pull && cd ios && xcodegen`.

### 3. Contul Apple în Xcode
1. **Xcode → Settings → Accounts → +** → Apple Account. Autentificați-vă cu contul dumneavoastră Apple.
2. În proiect, în stânga, apăsați **Agenda**, apoi alegeți ținta **Agenda** → tabul **Signing & Capabilities**.
3. La **Team**, alegeți echipa cu numele dumneavoastră și „(Personal Team)”.
4. Faceți la fel pentru ținta **AgendaWidget**.

Dacă Xcode spune că identificatorul `ro.cucuta.agenda` e deja folosit, trimiteți-mi mesajul și îl schimb.

### 4. iPad-ul (sau iPhone-ul)
1. Conectați-l prin cablu la MacBook. Pe dispozitiv, la întrebare, apăsați **Ai încredere**.
2. Pe dispozitiv: **Configurări → Confidențialitate și securitate → Mod dezvoltator → Activat**. Dispozitivul repornește.
3. În Xcode, sus, alegeți dispozitivul ca destinație și apăsați **▶︎ (Run)**.
4. La prima pornire, pe dispozitiv: **Configurări → General → VPN și gestionare dispozitive** → contul dumneavoastră → **Ai încredere**.

### 5. În aplicație
1. **Prima deschidere are nevoie de internet**; după aceea, aplicația merge și fără.
2. La întrebare, **permiteți notificările**.
3. **Mutați datele o singură dată.** Aplicația nativă are datele ei, separate de cele din Safari:
   - în aplicația de acum (de pe ecranul principal) apăsați **Backup rapid** → Salvează în Fișiere;
   - în aplicația nativă: **Setări → Importă backup** → alegeți fișierul → **Înlocuiește tot**.
4. **Widgeturile:**
   - pe ecranul principal: țineți apăsat pe un loc gol → **Editează → Adaugă widget** → Agenda;
   - pe ecranul blocat: țineți apăsat pe ecranul blocat → **Personalizează** → ecranul blocat → zona de widgeturi → Agenda.

---

## De știut: contul gratuit (Personal Team)

- **Aplicația se oprește după 7 zile.** Conectați dispozitivul și apăsați din nou ▶︎ în Xcode. Datele rămân, pentru că reinstalarea peste aceeași aplicație nu le șterge. Cât timp aplicația e oprită, nu merg nici widgeturile, nici notificările.
- Sunt permise **maximum 3 aplicații instalate așa pe un dispozitiv** și 3 dispozitive.
- Contul plătit (Apple Developer Program, 99 USD pe an) elimină limita de 7 zile: aplicația rămâne instalată un an.

## Când actualizați

| Ce s-a schimbat | Ce faceți |
|---|---|
| Doar aplicația web (cazul obișnuit) | Nimic în Xcode. În aplicație apare „Versiune nouă” → **Actualizează**. |
| Folderul `ios/` (widgeturi, notificări) | `git pull`, apoi `cd ios && xcodegen`, apoi ▶︎ în Xcode. |
| Au trecut 7 zile (cont gratuit) | ▶︎ în Xcode, cu dispozitivul conectat. |

## Dacă ceva nu merge
- **Eroare la compilare:** copiați mesajul din Xcode (panoul din stânga, tabul cu triunghiul roșu) și trimiteți-mi-l.
- **Widgetul arată „Deschideți aplicația”:** deschideți aplicația o dată, ca să primească cifrele.
- **„App Groups” refuzat la contul gratuit:** trimiteți-mi mesajul exact. Fără App Groups, widgetul nu poate citi cifrele aplicației.
- **Adresa aplicației web** e `https://blackfire1894.github.io/AGENDA-INSPECTORULUI/`. Dacă în Safari folosiți altă adresă, spuneți-mi: trebuie schimbată în `Shared/StareAgenda.swift` și în `project.yml` (`WKAppBoundDomains`).

---

## Pentru dezvoltare: ce primește aplicația nativă

Aplicația web (`js/nativ.js`) trimite prin `window.webkit.messageHandlers.agenda.postMessage` trei tipuri de mesaje:

- `{ tip: 'stare', stare }`, după fiecare schimbare. `stare` conține:
  - `v`: versiunea formatului (acum 1);
  - `generat`, `azi`;
  - `zile[21]`: cifrele Panoului pe zile: `amenzi {rosu, galben, albastru}`, `amenziActive`, `asi`, `asiDepasite`, `deIncarcat`, `incarcareUrgent`, `neincheiate`, `netrecute`, `deConfirmat`, `urgente`;
  - `urmatoare[]`: `{data, nivel, titlu, text}`;
  - `notificari[]`: `{id, data, ora, titlu, text}`, maximum 60;
  - `insigna`.
- `{ tip: 'share', titlu, text, url, fisiere: [{nume, tip, date(base64)}] }`. Aplicația web cheamă `navigator.share`, pe care aplicația nativă îl înlocuiește (`Punte.scriptInjectat`).
- `{ tip: 'print' }`. Aplicația web cheamă `window.print()`.

Toată logica termenelor rămâne în aplicația web. Aplicația nativă doar afișează și programează.

Fișierele:
- `project.yml`: proiectul (XcodeGen);
- `Agenda/`: aplicația (`AgendaApp`, `WebModel`, `Punte`, `Notificari`);
- `AgendaWidget/`: widgeturile;
- `Shared/`: formatul datelor, comun aplicației și widgetului.
