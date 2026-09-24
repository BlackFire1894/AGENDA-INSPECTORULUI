// Ghidul aplicației — manualul complet (butoane cu pictograme, funcții, corelări, flux de lucru).
// Se actualizează odată cu funcțiile pe care le descrie (regulă în CLAUDE.md).
import { icon } from './ui.js';

// Replici mici ale butoanelor din aplicație, ca inspectorul să le recunoască pe ecran
const B = (ic, text, cls = '') => `<span class="m-btn ${cls}">${ic ? icon(ic) : ''}${text ? `<span>${text}</span>` : ''}</span>`;
const P = (text, cls = 'neutral', ic = '') => `<span class="pill pill-${cls}">${ic ? icon(ic) : ''}${text}</span>`;
const OK = B('check', 'Conform', 'm-ok');
const NOK = B('x', 'Constatat', 'm-nok');
const NEC = B('', '<b>NEC</b>', 'm-nec');

// Fiecare capitol: id (legătură directă #/ghid/<id>), pictogramă, titlu, blocuri.
// Bloc: { p } paragraf · { ul: [...] } listă · { btns: [[replică, explicație], ...] } butoane · { note } atenționare
export const MANUAL = [
  {
    id: 'start', ic: 'home', title: 'Pe scurt: un control, de la început la sfârșit',
    blocks: [
      { ul: [
        `<b>1. Control nou</b> ${B('plus', 'Control nou', 'm-prim')}: scrieți denumirea. Dacă obiectivul există, alegeți-l — datele de contact, adresa și construcțiile (cu dotări, GRF/NSI, coordonate, date de verificare) se preiau din ultimul control.`,
        '<b>2. Tabul Obiectiv</b>: completați datele, construcțiile și dotările (DA / NU / NEC). Dotările decid ce nereguli apar și declanșează singure neregulile grave.',
        '<b>3. Tabul Acte</b>: ✓ Prezentat, ✗ Lipsă sau NEC pentru fiecare act.',
        '<b>4. Tabul Nereguli</b> (la localități și Planuri, Protecție civilă): ✓, ✗ sau NEC pe fiecare rând; la ✗ completați PV-ul, amenda, construcțiile.',
        `<b>5. La final</b>: ${B('pv', 'Text PV')} pentru procesul-verbal, ${B('download', 'Fișa PDF')} pentru arhivă, apoi <b>Încheie controlul</b> (tabul Obiectiv).`,
      ] },
      { p: `Bara <b>„Ce mai ai de făcut”</b> din control vă arată mereu pasul următor. Totul se salvează <b>automat</b>, pe loc; faceți des ${B('download', 'Backup rapid')}.` },
    ],
  },
  {
    id: 'navigare', ic: 'list', title: 'Navigarea',
    blocks: [
      { p: 'Pe <b>orizontal</b>, meniul e în bara laterală din stânga; pe <b>vertical</b>, în bara de jos.' },
      { btns: [
        [B('home', 'Panou'), 'Punctul de pornire: amenzi, termene, controale neîncheiate, ce nu e trecut în PV.'],
        [B('building', 'Obiective'), 'Lista obiectivelor controlate, cu căutare și istoricul fiecăruia.'],
        [B('plus', '', 'm-prim m-round'), 'Control nou (butonul rotund din bara de jos / „Control nou” din bara laterală).'],
        [B('calendar', 'Calendar'), 'Controalele pe zile și termenele (plată, ANAF, ASI).'],
        [B('history', 'Istoric'), 'Toate controalele, grupate pe luni.'],
        [B('settings', 'Setări'), 'Mărimea textului, tema, backup, actualizări, termene.'],
        [B('book', 'Ghidul aplicației'), 'Acest manual (bara laterală, Panou și Setări).'],
        [B('download', 'Backup rapid'), 'Salvează un fișier cu toate controalele (bara laterală, Panou, antetul controlului).'],
      ] },
      { p: 'Numărul de pe Panou arată amenzile care cer atenție (galben / roșu); cel de pe Istoric, controalele neîncheiate.' },
    ],
  },
  {
    id: 'panou', ic: 'home', title: 'Panoul',
    blocks: [
      { p: 'Sus: data și ora tabletei și <b>Backup rapid</b> (devine portocaliu dacă n-ați făcut niciun backup sau dacă ultimul are 7 zile sau mai mult). Apoi patru casete — atingeți una ca să ajungeți la secțiunea ei:' },
      { p: 'Fiecare statistică are culoarea ei — aceeași pe casetă și pe secțiunea ei de mai jos, ca s-o găsiți dintr-o privire:' },
      { ul: [
        '<span class="m-k k-fines"></span><b>Amenzi active</b> — <b>verde-albastru (teal)</b>; în interior, fiecare amendă are culoarea stadiului ei (vedeți „Amenzi și termene”).',
        '<span class="m-k k-open"></span><b>Controale neîncheiate</b> — <b>violet</b>, ca eticheta „În desfășurare”.',
        '<span class="m-k k-asi"></span><b>Termene ASI 90 zile</b> — <b>albastru</b>; neregula „a” cu termen de prezentare.',
        '<span class="m-k k-pv"></span><b>Netrecute în PV</b> — <b>portocaliu</b>, ca pastilele „Netrecut în PV”.',
      ] },
      { p: 'Atingeți orice rând din Panou și controlul se deschide <b>exact la neregula respectivă</b>. <b>⚠</b> apare când un termen cade într-o zi nelucrătoare.' },
    ],
  },
  {
    id: 'control-nou', ic: 'plus', title: 'Control nou',
    blocks: [
      { ul: [
        'Scrieți denumirea; sub câmp apar obiectivele existente cu nume asemănător. Alegându-l pe unul, controlul nou preia: datele de contact, adresa, localitatea, construcțiile (dotări, GRF/NSI, an construire, coordonate GPS) și datele ultimelor verificări. Actele și neregulile pornesc de la zero.',
        'Alegeți tipul: <b>OPEC / Instituție</b> (taburile Obiectiv, Acte, Nereguli) sau <b>Localitate</b> (în plus: Planuri și SVSU, Protecție civilă).',
        'Data începerii e azi, implicit; o puteți schimba.',
        'Dacă obiectivul are NU la ASI / AVIZ / Iluminat Hint din controlul trecut, neregulile legate apar deja constatate (vedeți „Corelări automate”).',
      ] },
    ],
  },
  {
    id: 'control', ic: 'check', title: 'În control: antet, taburi, Anulează / Refă',
    blocks: [
      { p: 'Antetul controlului:' },
      { btns: [
        [B('back', '', 'm-icon'), 'Înapoi, la ecranul de unde ați venit.'],
        [B('check', 'Salvat', 'm-flat m-green'), 'Salvarea automată: „Se salvează…” apoi „Salvat”.'],
        [B('pv', 'Text PV'), 'Lista constatărilor, gata de copiat în procesul-verbal.'],
        [B('download', 'Fișa PDF'), 'Rezumatul complet al controlului, de tipărit sau salvat.'],
        [B('history', 'Istoric'), 'Istoricul obiectivului (toate controalele lui).'],
        [B('upload', 'Backup'), 'Backup rapid al tuturor controalelor.'],
        [B('trash', '', 'm-icon m-danger'), 'Șterge controlul (cere confirmare).'],
      ] },
      { p: '<b>„Ce mai ai de făcut”</b>: pasul următor (ex. „14 acte neverificate”, „1 constatare netrecută în PV”, „Verificare expirată”, „Amendă fără seria / nr.”). Atingeți-l și ajungeți acolo; <b>Toate (N)</b> deschide lista completă.' },
      { p: '<b>Taburile</b> (Obiectiv, Acte, Nereguli, Planuri și SVSU, Protecție civilă) stau într-o bară întunecată, separată de conținut; tabul în care lucrați e plin, violet. Fiecare arată pe scurt situația (ex. „2 lipsă”, „4 constatate” — portocaliu dacă sunt netrecute în PV) și o bară de progres jos: cât e completat (dotările, actele, rândurile verificate); devine verde la 100%. Bara taburilor rămâne sus la derulare.' },
      { p: '<b>Anulează / Sus / Refă</b> — pe vertical în banda de deasupra barei de jos, pe orizontal în bara laterală:' },
      { btns: [
        [B('undo', 'Anulează'), 'Un pas înapoi: o atingere, sau un text tastat până la pauză. Ecranul merge la locul schimbat (chiar dacă e în alt tab), îl deschide și îl evidențiază.'],
        [B('up', 'Sus', 'm-accent'), 'Înapoi la începutul paginii.'],
        [B('redo', 'Refă'), 'Refă pasul anulat. Butoanele sunt estompate când nu e nimic de anulat / refăcut.'],
      ] },
      { note: 'Istoricul Anulează / Refă ține cât timp aplicația e deschisă și e separat pentru fiecare control.' },
    ],
  },
  {
    id: 'obiectiv', ic: 'building', title: 'Tabul Obiectiv',
    blocks: [
      { p: '<b>Datele obiectivului</b>: tipul, denumirea, administratorul, telefonul, emailul, <b>adresa</b> și <b>localitatea</b> (se caută și după ele în Obiective).' },
      { p: '<b>Perioada controlului</b>: data începerii și <b>Încheie controlul</b>. La încheiere, aplicația vă arată întâi ce ați omis (cu acces direct la fiecare), apoi puteți „Încheia oricum”. Data încheierii pornește termenele amenzilor și ASI.' },
      { p: '<b>Construcțiile</b>: numărul se schimbă cu − / +; fiecare construcție se deschide / strânge din antet. În antet vedeți pe scurt: dotări completate, suprafață, regim, GRF/NSI, „GPS ✓” și avertizările (instalații lipsă, GRF/NSI V peste parter).' },
      { ul: [
        '<b>Date</b>: suprafață desfășurată, regim de înălțime (ex. S+P+2E), nr. angajați, <b>anul construirii</b>, structură, material pereți.',
        '<b>GRF / NSI</b>: I, II, III, IV, V sau „Nu e necesar” (grad de rezistență la foc — P118/1999 / nivel de stabilitate la incendiu — P118-1/2025).',
        `<b>Coordonate GPS</b>: ${B('locate', 'Completează coordonatele', 'm-prim')} — stați lângă construcție. Poziția se citește o singură dată, doar la cerere (nu se urmărește locația). Apar precizia (± m), ora, legături Google Maps / Hărți Apple, Copiază, Actualizează. Dacă localizarea e oprită, aplicația arată pașii de activare.`,
        `<b>Dotări și instalații</b>: ${B('', 'DA')} ${B('', 'NU')} ${B('', 'NEC')} pe fiecare rând (NEC = nu este cazul); centrala termică: SOLID / GAZOS / ELECTRIC sau NU ARE. La <b>ASI</b> și <b>AVIZ</b> pe DA apare câmpul pentru <b>numărul autorizației / avizului</b>.`,
        'Observațiile acceptă mai multe rânduri (Enter) și cresc în jos; săgeata de lângă ele le ascunde / arată, iar „Ascunde observațiile” le ascunde pe toate.',
      ] },
    ],
  },
  {
    id: 'corelari', ic: 'layers', title: 'Corelări automate (fișă → nereguli)',
    blocks: [
      { p: 'Ce bifați în fișa obiectivului schimbă singur lista de nereguli. Nu se pierde nimic: un rând completat nu dispare niciodată.' },
      { ul: [
        `<b>DA la o instalație</b> → apar neregulile ei (ex. DA la Hidranți interiori → „Probleme Hint”, „Hint nefuncțional”, verificarea c2). Celelalte stau ascunse; ${B('', 'Arată toate')} le afișează.`,
        `<b>NU la o instalație necesară</b> (hidranți, sprinklere, IDSAI, detectori autonomi, EXIT, desfumare, ignifugare, rezervă de apă, stație de pompe…) → <b>neregulă gravă</b> ${P('G1', 'red')}, cu alertă și „Vezi”, primul rând din Nereguli, cu construcțiile care au NU. Pentru „nu e cazul” folosiți NEC.`,
        '<b>GRF / NSI V</b> și regim de înălțime peste parter (P+1, P+2E, S+P+1, P+M…) → neregula gravă <b>G13</b>, cu alertă, notă roșie pe construcție.',
        '<b>NU la ASI</b> → „Construcția funcționează fără ASI” (<b>ah</b>) constatată automat; <b>NU la AVIZ</b> → „Lucrări … fără aviz” (<b>ai</b>); <b>NU la Iluminat Hint</b> → „Lipsă iluminat Hint” (<b>am</b>). Cu construcțiile care au NU și cu observațiile din fișă (până le editați în neregulă). La revenirea la DA / NEC, neregula nelucrată se retrage; una lucrată (PV, amendă, observații) rămâne, cu mesaj.',
        '<b>Meniul de construcții</b> al unei nereguli de instalație arată doar construcțiile cu instalația pe DA.',
        '<b>Neregulă veche</b>: dacă aceeași neregulă a fost constatată la un control anterior al obiectivului, apare singură ' + P(`${icon('history')}Neregulă veche`, 'veche') + '; o puteți bifa și manual.',
        '<b>Controlul următor</b> pe același obiectiv preia construcțiile, dotările, coordonatele și datele verificărilor.',
        '<b>Controalele încheiate</b> își păstrează lista de nereguli de la încheiere: rândurile adăugate în versiuni ulterioare ale aplicației nu apar la ele. Un control redeschis primește lista curentă.',
      ] },
    ],
  },
  {
    id: 'acte', ic: 'doc', title: 'Tabul Acte și evidențe',
    blocks: [
      { btns: [
        [B('check', 'Prezentat', 'm-ok'), 'Actul a fost prezentat.'],
        [B('x', 'Lipsă', 'm-nok'), 'Actul lipsește (apare în Text PV și în fișă).'],
        [NEC, 'Nu este cazul (ex. contract de transmitere a unui bun, dacă nu există).'],
      ] },
      { p: 'Funcționează ca tabul Nereguli: căutare (după număr sau text — ex. „LFD”, „foc deschis”), filtrul Toate / Lipsă / Neverificate, bara listei (care acte sunt necompletate, care lipsesc), fiecare act se strânge din bara lui (singur la ✓ / NEC), „Restrânge completate”, „Restul prezentate” (cu confirmare).' },
    ],
  },
  {
    id: 'nereguli', ic: 'alert', title: 'Tabul Nereguli (și Planuri și SVSU, Protecție civilă)',
    blocks: [
      { p: 'Sus: sumarul (verificate, constatate, trecute în PV, amenzi). Apoi:' },
      { ul: [
        `<b>Căutare</b> ${B('search', 'Caută…')}: litera exactă (d, ag, G1, +1) sau text de minim 3 litere, fără diacritice; găsește și după abrevieri / denumirea completă (vedeți „Glosar”). ✕ golește căutarea.`,
        `<b>Filtre</b>: ${B('', 'Toate')} ${B('', 'Constatate')} ${B('', 'Neverificate')}.`,
        `${B('list', 'Restrânge categoriile')} / ${B('chevD', 'Extinde categoriile')}, ${B('list', 'Restrânge completate')} / ${B('chevD', 'Deschide rândurile')}, ${B('doc', 'Ascunde observațiile')}.`,
      ] },
      { p: '<b>Bara categoriei</b> (se strânge / deschide la atingere) arată mereu, și când e strânsă:' },
      { ul: [
        `${P(`${icon('check')} Completat`, 'green')} sau ${P('3 necompletate: b2, c1, e', 'warn')} — <b>care</b> rânduri mai sunt de completat;`,
        `${P('1 constatată', 'red')} — câte sunt constatate; ${P(`${icon('pv')} 1 netrecută în PV: d`, 'warn')} — <b>care</b> constatări nu sunt încă trecute în procesul-verbal (sau ${P(`${icon('pv')} toate în PV`, 'green')}); ${P(`${icon('fine')} 1 amendată: d`, 'blue')} — <b>care</b> sunt amendate.`,
      ] },
      { p: '<b>Bara fiecărei nereguli</b>: litera, denumirea și săgeata. Atingeți titlul sau săgeata ca să o strângeți / deschideți. Strânsă, bara arată tot ce contează:' },
      { ul: [
        `starea: ${P('Conform', 'green')} ${P('Constatat', 'red')} ${P('NEC')} <span class="pill pill-todo">Necompletat</span>;`,
        `${P('Netrecut în PV', 'warn')} / ${P('Trecut în PV', 'green')}, ${P('Amendă · În curs', 'blue')}, ${P('Sigiliu', 'red')}, ${P('Neregulă veche', 'veche')}, ${P('Verificare expirată', 'warn')}, construcțiile.`,
      ] },
      { p: `La ${OK} sau ${NEC} rândul se strânge singur; la ${NOK} rămâne deschis, pentru detalii. Barele categoriei și neregulii curente rămân sus la derulare, sub taburi.` },
      { p: '<b>La constatat</b> (✗):' },
      { ul: [
        `<b>Construcțiile</b>: meniul ${B('building', 'Construcția Corp A', 'm-flat')} — bifați una sau mai multe; „Toate construcțiile”, „Gata”.`,
        `<b>Trecut în procesul-verbal</b>, <b>Sancționat cu amendă</b> (apoi: <b>Seria și nr.</b> într-un singur câmp, ex. „DB 0012345”; data aplicării — implicit data încheierii; suma; <b>Achitată</b> și data dovezii), <b>Neregulă veche</b>.`,
        '<b>Neregulile grave</b> au în plus bifa <b>Sigiliu</b> — în baza cărei nereguli ați aplicat sigiliul. Rândurile adăugate au bifa <b>Neregulă gravă</b>; bifată, apare și Sigiliu.',
        'La „a” (documentație ASI): <b>Termen de prezentare 90 de zile</b> și „Documentație prezentată” cu data.',
      ] },
      { p: `<b>Rânduri adăugate</b>: ${B('plus', 'Adaugă rând', 'm-prim')} pentru nereguli din afara listei; secțiunea lor se strânge din titlu, ca o categorie.` },
      { p: `<b>Restul conform</b> ${B('check', 'Restul conform (N)', 'm-green-out')}: arată lista exactă a rândurilor nemarcate și cere bifa „Am verificat la fața locului…”. Neregulile grave nu intră niciodată în marcarea în bloc. Imediat după, aveți „Anulează”.` },
      { p: '<b>Planuri și SVSU</b> / <b>Protecție civilă</b> (doar la localități): la fel, cu ✓ Conform / ✗ Neconform / NEC; în Text PV rubricile neconforme apar formulate negativ („PAAR neavizat”). Protecție civilă are și adăpostul (DA / NU / NEC).' },
    ],
  },
  {
    id: 'verificari', ic: 'hourglass', title: 'Verificări pe instalații',
    blocks: [
      { p: 'Verificările sunt rânduri separate, în categoria „Documentație și verificări”:' },
      { ul: [
        '<b>b1</b> instalații electrice (12 luni), <b>b2</b> împământare (12 sau 24 de luni, la alegere pe construcție), <b>b3</b> CT (24 luni) — la <b>toate</b> construcțiile;',
        '<b>c1</b> IDSAI (12), <b>c2</b> hidranți interiori (6), <b>c3</b> hidranți exteriori (6), <b>c4</b> desfumare (12), <b>c5</b> sprinklere (12), <b>c6</b> drencere (12), <b>c7</b> instalații speciale (12) — doar la construcțiile cu instalația pe DA.',
      ] },
      { p: 'La fiecare construcție completați <b>data ultimei verificări</b>. Aplicația calculează expirarea față de data începerii controlului: ✓ „valabilă până la…” sau ⚠ „expirată din…”.' },
      { p: `La expirare apar avertizarea, rândul în „Ce mai ai de făcut” și butonul ${B('x', 'Constatat pentru aceasta')} — decideți dumneavoastră. Datele apar în Text PV și în fișă și se preiau la controlul următor.` },
    ],
  },
  {
    id: 'amenzi', ic: 'fine', title: 'Amenzi și termene',
    blocks: [
      { p: 'Toate termenele curg de la data de referință + 1 zi (data aplicării amenzii — implicit data încheierii controlului).' },
      { ul: [
        `${P('albastru', 'blue')} zilele 1–15: în termenul de plată de 15 zile;`,
        `${P('galben', 'yellow')} zilele 16–39: termenul de plată a expirat;`,
        `${P('roșu', 'red')} din ziua 40: „Mai ai 5 zile până să o trimiți la ANAF” (termen: ziua 45);`,
        `${P('verde', 'green')} achitată, cu dovadă primită.`,
        '<b>ASI</b>: 90 de zile de la data încheierii controlului.',
        '<b>Zile nelucrătoare</b> (weekend, sărbători legale, art. 139 Codul muncii): termenul <b>nu</b> se mută; apare ⚠ „cade sâmbătă — verifică prelungirea”.',
      ] },
    ],
  },
  {
    id: 'final', ic: 'pv', title: 'La final: Text PV, Fișa PDF, încheierea',
    blocks: [
      { btns: [
        [B('pv', 'Text PV'), 'Lista constatărilor (cu construcțiile, datele verificărilor, amenzile, „neregulă veche”, „sigiliu aplicat”) și actele lipsă. Butoane: Copiază, Partajează, <b>Marchează-le trecute în PV</b>. Rândurile NEC nu apar.'],
        [B('download', 'Fișa PDF'), 'Fișa completă: date, construcții (GRF/NSI, an, GPS, dotări, nr. ASI / aviz), acte, constatări, amenzi, verificări. „Tipărește / PDF” → Partajare → Salvează în Fișiere; sau „Partajează fișierul”.'],
        [B('check', 'Încheie controlul', 'm-ok'), 'În tabul Obiectiv: arată omisiunile, apoi încheie; pornește termenele.'],
      ] },
    ],
  },
  {
    id: 'obiective', ic: 'building', title: 'Obiective, Istoric, Calendar',
    blocks: [
      { ul: [
        '<b>Obiective</b>: căutați după nume, localitate, adresă sau dată (12.09.2026, 09.2026, 2026; butonul „Dată” deschide calendarul). Filtrați pe tip. Atingeți un obiectiv pentru pagina lui: date, <b>coordonatele GPS ale fiecărei construcții</b>, istoric, <b>Control nou pe acest obiectiv</b>.',
        '<b>Istoric</b>: toate controalele, pe luni; căutare după obiectiv, administrator sau dată; filtrele În desfășurare / Încheiate.',
        '<b>Calendar</b>: anul și luna se schimbă separat; zilele au controalele (mov = în desfășurare, bleumarin = încheiat) și punctele termenelor (albastru = plată, roșu = ANAF / ASI). Atingeți o zi pentru detalii sau „Control nou în această zi”.',
      ] },
    ],
  },
  {
    id: 'setari', ic: 'settings', title: 'Setări, backup, actualizări',
    blocks: [
      { ul: [
        '<b>Mărimea textului</b>: Mic / Mediu / Mare — tot se scalează împreună.',
        '<b>Tema</b>: Automat (ca iPad-ul), Luminoasă, Întunecată.',
        '<b>Backup</b>: „Exportă backup” (același lucru ca Backup rapid) — salvați fișierul în Fișiere / iCloud Drive. „Importă backup”: <b>Combină</b> (adaugă, păstrează versiunea cea mai recentă) sau <b>Înlocuiește tot</b>.',
        '<b>Actualizări</b>: aplicația verifică singură la deschidere; când există o versiune nouă apare bara „Versiune nouă disponibilă” cu <b>Actualizează</b>. „Verifică acum” caută manual.',
        '<b>Zonă periculoasă</b>: ștergerea tuturor datelor (după backup!).',
      ] },
    ],
  },
  {
    id: 'glosar', ic: 'info', title: 'Glosar',
    blocks: [
      { ul: [
        '<b>ASI</b> — autorizație de securitate la incendiu · <b>AVIZ</b> — aviz de securitate la incendiu',
        '<b>IDSAI</b> — instalație de detectare, semnalizare și alarmare la incendiu',
        '<b>Hint</b> — instalație de stingere a incendiilor cu hidranți interiori · <b>Hext</b> — cu hidranți exteriori',
        '<b>EXIT</b> — instalație de iluminare de securitate pentru evacuare · <b>Iluminat Hint</b> — iluminare de securitate pentru marcarea hidranților interiori',
        '<b>CTPSI</b> — cadru tehnic PSI · <b>RESP</b> — responsabil PSI · <b>LFD</b> — lucru cu foc deschis',
        '<b>GRF</b> — grad de rezistență la foc (P118/1999) · <b>NSI</b> — nivel de stabilitate la incendiu (P118-1/2025)',
        '<b>NEC</b> — nu este cazul · <b>PV</b> — proces-verbal · <b>CT</b> — centrală termică · <b>IPT</b> — instalație de protecție împotriva trăsnetului / împământare',
      ] },
      { p: 'Căutarea din Nereguli și Acte cunoaște aceste abrevieri: „hidranti interiori” găsește și rândurile „Hint”, „foc deschis” găsește actul LFD.' },
    ],
  },
  {
    id: 'date', ic: 'shield', title: 'Datele și siguranța lor',
    blocks: [
      { ul: [
        'Datele stau <b>doar pe această tabletă</b> (nu pe internet). Singura copie de siguranță este backup-ul: faceți-l des.',
        'Instalați aplicația pe ecranul principal (Safari → Partajare → „Adaugă pe ecranul principal”): așa stocarea e persistentă și aplicația merge offline.',
        'Localizarea se folosește doar când apăsați „Completează coordonatele”.',
        'Actualizările nu schimbă controalele încheiate (își păstrează lista de nereguli) și completează automat câmpurile noi la cele vechi.',
      ] },
    ],
  },
];
