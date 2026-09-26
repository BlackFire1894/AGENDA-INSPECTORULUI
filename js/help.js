// Ghidul aplicației — manualul complet, scris pentru cineva care vede aplicația prima dată.
// Se actualizează odată cu funcțiile pe care le descrie (regulă în CLAUDE.md).
import { icon } from './ui.js';

// Replici mici ale butoanelor din aplicație, ca inspectorul să le recunoască pe ecran
const B = (ic, text, cls = '') => `<span class="m-btn ${cls}">${ic ? icon(ic) : ''}${text ? `<span>${text}</span>` : ''}</span>`;
const P = (text, cls = 'neutral', ic = '') => `<span class="pill pill-${cls}">${ic ? icon(ic) : ''}${text}</span>`;
const F = (level, text) => `<span class="pill fine-st fs-${level}">${icon('fine')}${text}</span>`;
const OK = B('check', 'Conform', 'm-ok');
const NOK = B('x', 'Constatat', 'm-nok');
// Adăposturile de protecție civilă: același text în tabul Obiectiv (OPEC) și în Protecție civilă (Localitate)
const ADP = 'Adăposturile de protecție civilă: alegeți <b>DA</b>, <b>NU</b> sau <b>NEC</b>. La DA apare întrebarea <b>„Câte adăposturi?”</b>: apăsați + pentru fiecare. Fiecare adăpost (A1, A2…) are locația, butoanele <b>Conform</b> / <b>Neconform</b> și observațiile. Un adăpost <b>neconform</b> este neregulă: are bifele Trecut în PV, Sancționat cu amendă și Neregulă veche și intră în Text PV („Adăpost de protecție civilă neconform – locația”). La controlul următor al obiectivului, adăposturile se preiau cu locația, iar starea se verifică din nou. Dacă treceți înapoi pe NU sau NEC, aplicația cere confirmare și șterge adăposturile.';
const NEC = B('', '<b>NEC</b>', 'm-nec');

// Fiecare capitol: id (legătură directă #/ghid/<id>), pictogramă, titlu, blocuri.
// Bloc: { p } paragraf · { h } subtitlu · { ol: [...] } pași numerotați · { ul: [...] } listă
//       · { btns: [[replică, explicație], ...] } butoane · { note } atenționare
export const MANUAL = [
  {
    id: 'start', ic: 'home', title: 'Pe scurt: la ce folosește aplicația',
    blocks: [
      { p: 'Agenda inspectorului ține locul agendei de teren. În ea notați fiecare control: datele obiectivului, construcțiile și dotările lor, actele verificate și neregulile constatate. Aplicația urmărește apoi amenzile și termenele și vă arată în fiecare zi ce trebuie făcut.' },
      { p: 'Tot ce scrieți se salvează <b>automat</b>, pe loc, pe această tabletă. Aplicația funcționează și fără internet.' },
      { h: 'Un control, pas cu pas' },
      { ol: [
        `Apăsați ${B('plus', 'Control nou', 'm-prim')} și scrieți denumirea obiectivului. Dacă obiectivul a mai fost controlat, alegeți-l din listă: datele lui se preiau din ultimul control.`,
        'În tabul <b>Obiectiv</b> completați datele obiectivului, construcțiile și dotările fiecărei construcții (DA / NU / NEC). Dotările stabilesc ce nereguli vi se cer mai departe.',
        'În tabul <b>Acte</b> marcați fiecare act: Prezentat, Lipsă sau NEC (nu este cazul).',
        'În tabul <b>Nereguli</b> parcurgeți lista și marcați fiecare rând: Conform, Constatat sau NEC. La o neregulă constatată completați detaliile: construcțiile, observațiile, trecerea în procesul-verbal, amenda.',
        `La final, folosiți ${B('pv', 'Text PV')} pentru procesul-verbal și ${B('download', 'Fișa PDF')} pentru arhivă, apoi apăsați <b>Încheie controlul</b> (în tabul Obiectiv).`,
        'După încheiere, în cel mult 3 zile lucrătoare, încărcați controlul în aplicația ISU și documentul (PV scanat) și bifați-le în tabul Obiectiv.',
      ] },
      { p: 'Pe tot parcursul controlului, bara <b>„Ce mai aveți de făcut”</b> vă arată pasul următor.' },
      { note: `Datele există doar pe această tabletă. Faceți des ${B('download', 'Backup rapid')}: este singura copie de siguranță.` },
    ],
  },
  {
    id: 'navigare', ic: 'list', title: 'Cum vă deplasați în aplicație',
    blocks: [
      { p: 'Meniul principal stă în bara laterală din stânga când țineți tableta orizontal și în bara de jos când o țineți vertical.' },
      { btns: [
        [B('home', 'Panou'), 'Pagina de pornire: ce trebuie urmărit azi (amenzi, termene ASI, controale neîncheiate, constatări netrecute în PV).'],
        [B('building', 'Obiective'), 'Toate obiectivele controlate, cu datele și istoricul fiecăruia.'],
        [B('plus', '', 'm-prim m-round'), 'Control nou (butonul rotund din bara de jos sau „Control nou” din bara laterală).'],
        [B('calendar', 'Calendar'), 'Planul lunar: controalele, activitățile și termenele, zi cu zi; raportul lunii.'],
        [B('history', 'Istoric'), 'Toate controalele, grupate pe luni.'],
        [B('settings', 'Setări'), 'Mărimea textului, tema, backupul, actualizările.'],
        [B('book', 'Ghidul aplicației'), 'Acest manual (în bara laterală; pe vertical, sus în Panou; în Setări).'],
        [B('download', 'Backup rapid'), 'Salvează într-un fișier toate controalele (în bara laterală; pe vertical, sus în Panou; în antetul fiecărui control). Devine portocaliu când backupul e vechi.'],
      ] },
      { h: 'Ce înseamnă numerele de pe meniu' },
      { ul: [
        'La <b>Panou</b>: câte <b>amenzi urgente</b> aveți, adică amenzi cu termenul de plată expirat sau de trimis la ANAF. Pe orizontal scrie „2 amenzi urgente”; pe vertical apare doar numărul, pe o bulină roșie.',
        'La <b>Istoric</b>: câte controale sunt <b>neîncheiate</b>. Pe orizontal scrie „2 neîncheiate”; pe vertical apare doar numărul.',
      ] },
    ],
  },
  {
    id: 'culori', ic: 'info', title: 'Cum citiți culorile',
    blocks: [
      { p: 'Culorile au același înțeles în toată aplicația. Lângă fiecare culoare există mereu și un text, deci nu trebuie să le rețineți pe dinafară.' },
      { ul: [
        `${P('Roșu', 'red')} — constatat, neregulă gravă, termen ANAF sau ASI: cere acțiune.`,
        `${P('Portocaliu', 'warn')} — de completat: act lipsă, constatare netrecută în PV, rânduri necompletate.`,
        `${P('Galben', 'yellow')} — amendă cu termenul de plată expirat.`,
        `${P('Albastru', 'blue')} — termen în curs (amendă în termenul de plată) sau o informație.`,
        `${P('Verde', 'green')} — conform, completat, achitat, trecut în PV.`,
        `${P('Violet', 'open')} — control în desfășurare și tabul în care lucrați.`,
        `${P(`${icon('history')}Neregulă veche`, 'veche')} — aceeași neregulă a fost constatată și la un control anterior al obiectivului.`,
      ] },
    ],
  },
  {
    id: 'panou', ic: 'home', title: 'Panoul: ce urmăriți azi',
    blocks: [
      { p: 'Sus vedeți data și ora tabletei. Pe vertical, deasupra lor, stau <b>Ghidul aplicației</b> și <b>Backup rapid</b>; pe orizontal, acestea sunt în bara laterală. Backup rapid devine portocaliu dacă nu ați făcut niciun backup sau dacă ultimul are 7 zile sau mai mult.' },
      { h: 'Cele cinci casete' },
      { p: 'Fiecare casetă are o culoare; secțiunea ei de mai jos are aceeași culoare. Atingeți o casetă ca să ajungeți la secțiunea ei.' },
      { ul: [
        '<span class="m-k k-fines"></span><b>Amenzi active</b> (verde-albastru): câte amenzi nu sunt încă achitate. Dedesubt scrie câte sunt de trimis la ANAF, câte au termenul de plată expirat și câte sunt în curs. Amenzile achitate apar separat („+ 1 achitată”) și nu intră în total.',
        '<span class="m-k k-open"></span><b>Controale neîncheiate</b> (violet): controalele care nu au încă dată de încheiere. Dedesubt: data celui mai vechi dintre ele.',
        '<span class="m-k k-asi"></span><b>Termene ASI 90 zile</b> (albastru): termenele de prezentare a documentației ASI care au început să curgă. Dedesubt: cel mai apropiat termen. Termenele din controalele încă neîncheiate nu au început; ele apar separat, ca „neîncepute”.',
        '<span class="m-k k-inc"></span><b>De încărcat</b> (gri-albastru): controalele încheiate care nu sunt încă încărcate în aplicația ISU sau nu au documentul încărcat. Dedesubt: câte au ultima zi azi sau termenul depășit.',
        '<span class="m-k k-pv"></span><b>Netrecute în PV</b> (portocaliu): constatările pe care nu le-ați marcat încă „Trecut în procesul-verbal”.',
      ] },
      { h: 'Listele de sub casete' },
      { p: 'Listele care au ceva de rezolvat apar primele, imediat sub casete; cele goale („Nicio amendă activă”, „Toate controalele sunt încheiate” etc.) coboară la final. Între cele cu conținut, ordinea rămâne: Amenzi, Termene ASI, De încărcat, Controale neîncheiate, Netrecute în PV.' },
      { ul: [
        `<b>Amenzi</b>: fiecare amendă, cu stadiul ei scris pe o pastilă colorată — ${F('blue', 'În curs')} ${F('yellow', 'Termen 15 zile expirat')} ${F('red', 'Trimite la ANAF')} ${F('green', 'Achitată')} —, suma și un mesaj care spune exact câte zile mai sunt (vedeți „Amenzile și termenele”).`,
        '<b>Termene ASI</b>: câte zile au rămas sau cu câte zile a fost depășit termenul. După cele 90 de zile, rândul arată a doua etapă — „Constatarea pierderii valabilității” — cu cele 5 zile ale ei.',
        `<b>De încărcat în aplicație</b>: fiecare control încheiat neîncărcat, cu ce lipsește (${P('Document neîncărcat', 'red')}), termenul și câte zile lucrătoare au rămas. Portocaliu cât mai sunt zile; roșu în ultima zi și după termen.`,
        `<b>Controale neîncheiate</b>: de când sunt deschise (${P('început azi', 'open')}, ${P('de 3 zile', 'open')}); la cele programate pentru o zi viitoare, peste câte zile încep; dacă ați aplicat sigiliu, și ${P(`${icon('lock')}Sigiliu aplicat · 2 criterii`, 'red')}.`,
        '<b>Nereguli netrecute în procesul-verbal</b>: fiecare constatare pe care o mai aveți de trecut în PV.',
      ] },
      { p: 'Atingeți orice rând și controlul se deschide exact la neregula respectivă. Semnul <b>⚠</b> apare când un termen cade într-o zi nelucrătoare; alături vedeți prima zi lucrătoare de după.' },
      { p: 'În decembrie (și în ianuarie, dacă nu ați confirmat), sus în Panou apare cererea de a verifica lista sărbătorilor legale pentru anul care vine.' },
      { p: 'Tot sus apar <b>Activitățile de confirmat</b>: cele planificate a căror zi a trecut. Pentru fiecare alegeți <b>Efectuată</b>, <b>Reprogramează</b> sau <b>Anulată</b> (vedeți „Planul lunar”).' },
    ],
  },
  {
    id: 'control-nou', ic: 'plus', title: 'Începerea unui control',
    blocks: [
      { ol: [
        `Apăsați ${B('plus', 'Control nou', 'm-prim')} și scrieți denumirea obiectivului. Sub câmp apar obiectivele deja controlate care au un nume asemănător.`,
        'Dacă alegeți un obiectiv existent, controlul nou preia din ultimul control: datele de contact, adresa, localitatea, construcțiile (cu dotările, GRF/NSI, anul construirii și coordonatele GPS) și datele ultimelor verificări. Actele și neregulile pornesc de la zero.',
        'Alegeți tipul: <b>OPEC / Instituție</b> (taburile Obiectiv, Acte, Nereguli) sau <b>Localitate</b> (în plus: Planuri și SVSU, Protecție civilă).',
        'Data începerii este, implicit, ziua de azi; o puteți schimba.',
      ] },
      { p: 'Dacă obiectivul avea în controlul trecut NU la ASI, AVIZ sau Iluminat Hint, neregulile legate de ele apar deja constatate (vedeți „Ce se completează singur”).' },
    ],
  },
  {
    id: 'control', ic: 'check', title: 'Ecranul controlului',
    blocks: [
      { h: 'Antetul' },
      { btns: [
        [B('back', '', 'm-icon'), 'Înapoi, la ecranul de unde ați venit.'],
        [B('check', 'Salvat', 'm-flat m-green'), 'Arată că salvarea automată s-a făcut („Se salvează…”, apoi „Salvat”).'],
        [B('pv', 'Text PV'), 'Textul constatărilor, gata de copiat în procesul-verbal.'],
        [B('download', 'Fișa PDF'), 'Fișa completă a controlului, de tipărit sau de salvat.'],
        [B('history', 'Istoric'), 'Toate controalele acestui obiectiv.'],
        [B('upload', 'Backup'), 'Backup rapid al tuturor controalelor.'],
        [B('trash', '', 'm-icon m-danger'), 'Șterge controlul (vă cere confirmarea).'],
      ] },
      { h: '„Ce mai aveți de făcut”' },
      { p: 'Bara de sub antet vă arată pasul următor, de exemplu „14 acte neverificate”, „Nereguli: 17 nereguli neverificate”, „1 constatare netrecută în PV”, „Amendă fără seria / nr.” sau „Verificare expirată”. Atingeți-l și aplicația vă duce exact acolo. <b>Toate (N)</b> deschide lista completă. Neregulile grave încă nemarcate apar primele, pe roșu.' },
      { h: 'Taburile' },
      { p: 'Controlul are trei taburi: Obiectiv, Acte, Nereguli. La localități are cinci: în plus, Planuri și SVSU și Protecție civilă. Tabul în care lucrați este violet. Fiecare tab arată, scris:' },
      { ul: [
        'pe primul rând, situația: numărul de construcții, câte acte lipsesc sau câte constatări aveți (și câte nu sunt trecute în PV); textul e portocaliu când cere atenție;',
        'pe al doilea rând, cât ați completat: „Dotări 12/38” la Obiectiv, „Verificate 13/14” la Acte, „Verificate 4/37” la Nereguli. Bara subțire de dedesubt arată același lucru și devine verde când totul e completat.',
      ] },
      { p: 'Bara taburilor rămâne sus când derulați.' },
      { h: 'Anulează, Sus, Refă' },
      { p: 'Pe vertical, aceste butoane stau în banda de deasupra meniului de jos; pe orizontal, în bara laterală.' },
      { btns: [
        [B('undo', 'Anulează'), 'Anulează ultima modificare: o atingere sau un text tastat până la prima pauză. Aplicația vă duce la locul schimbat (chiar dacă e în alt tab), îl deschide și îl evidențiază.'],
        [B('up', 'Sus', 'm-accent'), 'Vă duce la începutul paginii.'],
        [B('redo', 'Refă'), 'Refă ce ați anulat. Butoanele sunt estompate când nu e nimic de anulat sau de refăcut.'],
      ] },
      { note: 'Anulează și Refă țin minte modificările cât timp aplicația e deschisă, separat pentru fiecare control.' },
    ],
  },
  {
    id: 'obiectiv', ic: 'building', title: 'Tabul Obiectiv: obiectivul, construcțiile, dotările',
    blocks: [
      { h: 'Datele obiectivului' },
      { p: 'Tipul, denumirea, administratorul, telefonul, emailul, adresa și localitatea. Ulterior, în Obiective, puteți căuta și după adresă sau localitate.' },
      { h: 'Perioada controlului' },
      { p: 'Data începerii și butonul <b>Încheie controlul</b> (vedeți capitolul „La final”).' },
      { h: 'Încărcare după încheiere' },
      { p: `După ce încheiați controlul, apare secțiunea „Încărcare după încheiere”, cu două bife: ${B('check', 'Încărcat în aplicație', 'm-ok')} (controlul introdus în aplicația ISU) și ${B('check', 'Document încărcat', 'm-ok')} (procesul-verbal scanat). Aplicația reține ziua în care ați bifat. Dedesubt vedeți termenul: <b>3 zile lucrătoare</b> de la data încheierii (vedeți „Amenzile și termenele”).` },
      { h: 'Adăposturi de protecție civilă (OPEC / Instituție)' },
      { p: `La OPEC / Instituție, sub construcții. ${ADP} Cele neconforme apar și în tabul Nereguli, în grupul „Adăposturi de protecție civilă”. (La Localitate, adăposturile sunt în tabul Protecție civilă.)` },
      { h: 'Construcțiile' },
      { p: 'Numărul construcțiilor se schimbă cu − și +. Fiecare construcție se deschide și se strânge din antetul ei. Antetul arată pe scurt: dotările completate, suprafața, regimul de înălțime, GRF/NSI, „GPS ✓” și avertizările (instalații lipsă, GRF/NSI V peste parter). Pentru fiecare construcție completați:' },
      { ul: [
        '<b>Datele</b>: suprafața desfășurată, regimul de înălțime (ex. S+P+2E), numărul de angajați, anul construirii, structura de rezistență, materialul pereților.',
        '<b>GRF / NSI</b>: I, II, III, IV, V sau „Nu e necesar” — gradul de rezistență la foc (P118/1999) sau nivelul de stabilitate la incendiu (P118-1/2025).',
        `<b>Coordonatele GPS</b>: stați lângă construcție și apăsați ${B('locate', 'Completează coordonatele', 'm-prim')}. Poziția se citește o singură dată, doar când apăsați; aplicația nu vă urmărește. Apar precizia (± metri), ora, legături spre Google Maps și Hărți Apple, Copiază și Actualizează. Dacă localizarea e oprită, aplicația vă arată pașii de activare.`,
      ] },
      { h: 'Dotări și instalații' },
      { p: `Pe fiecare rând alegeți ${B('', 'DA')}, ${B('', 'NU')} sau ${B('', 'NEC')} (nu este cazul); câteva rânduri au doar DA și NU. La centrala termică alegeți tipul (SOLID, GAZOS, ELECTRIC) sau NU ARE. La ASI și AVIZ, pe DA, apare câmpul pentru numărul autorizației, respectiv al avizului.` },
      { p: `<b>Observațiile</b>: câmpul apare doar când are text. Atingeți ${B('plus', 'Obs.')} ca să-l deschideți; poate avea mai multe rânduri (Enter) și crește în jos. Dacă îl lăsați gol, se strânge la loc.` },
      { note: 'Dotările contează: ele decid ce nereguli vi se cer în tabul Nereguli și declanșează singure neregulile grave (vedeți capitolul următor).' },
    ],
  },
  {
    id: 'corelari', ic: 'layers', title: 'Ce se completează singur',
    blocks: [
      { p: 'Ce bifați la dotări modifică automat lista de nereguli. Nu se pierde nimic: un rând pe care l-ați completat nu dispare niciodată.' },
      { ul: [
        '<b>DA la o instalație</b>: apar neregulile ei (de exemplu, DA la Hidranți interiori aduce „Probleme Hint”, „Hint nefuncțional” și verificarea c2). Neregulile instalațiilor fără DA stau ascunse; butonul „+N rânduri ascunse (instalații fără DA) · Arată”, din sumarul tabului Nereguli, le afișează.',
        `<b>NU la o instalație necesară</b> (hidranți interiori sau exteriori, sprinklere, drencere, instalații speciale, IDSAI, detectori autonomi, EXIT, desfumare, ignifugare, rezervă de apă, stație de pompe): apare o <b>neregulă gravă</b>, notată ${P('G1', 'red')}–${P('G12', 'red')}. Ea stă primul rând în Nereguli și e semnalată cu o alertă și butonul „Vezi”. Dacă instalația nu e necesară, alegeți NEC, nu NU.`,
        '<b>GRF/NSI V</b> la o construcție cu regim de înălțime peste parter (P+1, P+2E, S+P+1, P+M…): apare neregula gravă <b>G13</b>, iar construcția primește o notă roșie.',
        '<b>NU la ASI</b>: „Construcția funcționează fără ASI” (ah) apare constatată. <b>NU la AVIZ</b>: „Lucrări … fără aviz” (ai). <b>NU la Iluminat Hint</b>: „Lipsă iluminat Hint” (am). Aceste nereguli preiau construcțiile cu NU și observațiile din fișă. Dacă reveniți la DA sau NEC, neregula se retrage — cu excepția cazului în care ați lucrat pe ea (PV, amendă, observații): atunci rămâne, iar aplicația vă anunță.',
        '<b>Meniul de construcții</b> al unei nereguli de instalație arată doar construcțiile care au instalația pe DA.',
        `<b>Neregula veche</b>: dacă aceeași neregulă a fost constatată la un control anterior al obiectivului, apare automat ${P(`${icon('history')}Neregulă veche`, 'veche')}. O puteți bifa și manual.`,
        '<b>Controlul următor</b> pe același obiectiv preia construcțiile, dotările, coordonatele și datele verificărilor.',
        '<b>Controalele încheiate</b> își păstrează lista de nereguli din ziua încheierii: rândurile adăugate în versiuni ulterioare ale aplicației nu apar la ele. Un control redeschis primește lista actuală.',
      ] },
    ],
  },
  {
    id: 'acte', ic: 'doc', title: 'Tabul Acte și evidențe',
    blocks: [
      { p: 'Aici marcați actele de autoritate și evidențele. Pentru fiecare act alegeți:' },
      { btns: [
        [B('check', 'Prezentat', 'm-ok'), 'Actul a fost prezentat.'],
        [B('x', 'Lipsă', 'm-nok'), 'Actul lipsește; apare în Text PV și în fișă.'],
        [NEC, 'Nu este cazul (de exemplu, contractul de transmitere a unui bun, dacă nu există).'],
      ] },
      { p: 'Butoanele stau pe bara fiecărui act, lângă denumire. La Prezentat sau NEC actul se strânge singur; la Lipsă, câmpul de observații se deschide singur.' },
      { p: 'Restul funcționează ca în tabul Nereguli: sumarul pe un rând, căutarea (după număr sau text, de exemplu „LFD” sau „foc deschis”), filtrele Toate / Lipsă / Neverificate și butonul „Restul prezentate”, care vă cere confirmarea.' },
    ],
  },
  {
    id: 'nereguli', ic: 'alert', title: 'Tabul Nereguli (și Planuri și SVSU, Protecție civilă)',
    blocks: [
      { p: 'Aici parcurgeți lista de nereguli și marcați fiecare rând. La localități, tabul Planuri și SVSU și tabul Protecție civilă funcționează la fel.' },
      { h: 'Partea de sus' },
      { ul: [
        '<b>Sumarul</b>, pe un rând: câte rânduri ați verificat din total, câte sunt constatate, câte sunt trecute în PV și câte amenzi ați aplicat.',
        `<b>Căutarea</b> ${B('search', 'Caută…')}: scrieți litera rândului (d, ag, G1, +1) sau cel puțin 3 litere din text, fără diacritice. Găsește și după abrevieri (vedeți „Glosar”). ✕ golește căutarea.`,
        `${B('more', '', 'm-icon')}, lângă căutare, deschide opțiunile de afișare: ${B('list', 'Restrânge categoriile')} / ${B('chevD', 'Extinde categoriile')} și ${B('list', 'Restrânge completate')} / ${B('chevD', 'Deschide rândurile')}.`,
        `<b>Filtrele</b> ${B('', 'Toate')} ${B('', 'Constatate')} ${B('', 'Neverificate')} și, alături, ${B('check', 'Restul conform', 'm-green-out')} (vedeți mai jos).`,
      ] },
      { h: 'Categoriile' },
      { p: 'Neregulile sunt grupate pe categorii. Atingeți bara unei categorii ca s-o strângeți sau s-o deschideți. Bara spune, în cuvinte, situația categoriei:' },
      { ul: [
        `${P('8 necompletate', 'warn')} sau ${P(`${icon('check')} Completat`, 'green')} — câte rânduri mai sunt de marcat;`,
        `${P('2 constatate', 'red')} — câte sunt constatate;`,
        `${P(`${icon('pv')} 1 netrecută în PV`, 'warn')} sau ${P(`${icon('pv')} toate în PV`, 'green')} — dacă au fost trecute în procesul-verbal;`,
        `${P(`${icon('fine')} 1 amendată`, 'blue')} — câte sunt amendate;`,
        `${P(`${icon('lock')} 2 criterii de sigilare`, 'red')} — câte nereguli grave din categorie sunt temei pentru sigiliu (bifa Sigiliu).`,
      ] },
      { p: 'Când categoria e strânsă, bara arată în plus <b>literele</b> rândurilor (de exemplu „3 necompletate: b2, c1, e”), ca să știți exact care sunt.' },
      { h: 'Rândul unei nereguli' },
      { p: `Bara rândului are litera, denumirea, butoanele ${OK} ${NOK} ${NEC} și o săgeată. Când derulați, bara categoriei și bara neregulii curente rămân sus, sub taburi.` },
      { ul: [
        `La ${OK} sau ${NEC} rândul se strânge singur. Strâns, arată starea — ${P('Conform', 'green')}, ${P('Constatat', 'red')}, ${P('NEC')} sau <span class="pill pill-todo">Necompletat</span> — și tot ce e important: ${P('Netrecut în PV', 'warn')}, amenda cu stadiul ei, ${P('Sigiliu', 'red')}, ${P(`${icon('history')}Neregulă veche`, 'veche')}, ${P('Verificare expirată', 'warn')}, construcțiile.`,
        'Atingeți denumirea sau săgeata ca să deschideți ori să strângeți rândul.',
        `Neregulile grave au doar ${OK} și ${NOK}; pentru ele nu există NEC.`,
      ] },
      { h: 'Când constatați o neregulă' },
      { p: `După ce apăsați ${NOK}, rândul rămâne deschis pentru detalii:` },
      { ul: [
        '<b>Observațiile</b> sunt deja deschise, fără să pornească tastatura; scrieți doar dacă e nevoie.',
        `<b>Construcțiile</b>: din meniul ${B('building', 'Construcția Corp A', 'm-flat')} bifați una sau mai multe construcții (sau „Toate construcțiile”), apoi „Gata”.`,
        '<b>Trecut în procesul-verbal</b>: bifați după ce ați scris neregula în PV.',
        '<b>Sancționat cu amendă</b>: completați seria și numărul într-un singur câmp (de exemplu „DB 0012345”), data aplicării (implicit, data încheierii controlului) și suma. Când primiți dovada plății, bifați <b>Achitată – dovadă primită</b> și data ei.',
        '<b>Neregulă veche</b>: bifați-o dacă aplicația nu a găsit-o singură în controalele anterioare.',
        '<b>Sigiliu</b> (doar la neregulile grave): bifați dacă neregula este criteriu (temei) pentru sigiliul aplicat. Sigiliul se aplică pe construcție: mai multe nereguli bifate în aceeași construcție înseamnă un singur sigiliu, cu mai multe criterii; în construcții diferite, câte un sigiliu pe fiecare. O neregulă constatată în mai multe construcții înseamnă sigiliu în fiecare dintre ele.',
        'La neregula „a” (documentație ASI): <b>Termen de prezentare 90 de zile</b> și, când primiți documentația, <b>Documentație prezentată</b>, cu data.',
      ] },
      { h: 'Rânduri adăugate de dumneavoastră' },
      { p: `${B('plus', 'Adaugă rând', 'm-prim')} adaugă o neregulă care nu se află în listă. Scrieți descrierea; dacă e cazul, bifați <b>Neregulă gravă</b> (atunci apare și Sigiliu). Rândurile adăugate au secțiunea lor, care se strânge ca o categorie.` },
      { h: 'Restul conform' },
      { p: `${B('check', 'Restul conform (N)', 'm-green-out')} marchează Conform toate rândurile rămase nemarcate. Înainte, vă arată lista exactă și vă cere să confirmați „Am verificat la fața locului…”. Neregulile grave nu sunt incluse niciodată. Imediat după, puteți apăsa Anulează.` },
      { h: 'Planuri și SVSU, Protecție civilă (doar la localități)' },
      { p: 'Funcționează la fel, cu Conform / Neconform / NEC. În Text PV, rubricile neconforme apar formulate negativ (de exemplu „PAAR neavizat”). Protecție civilă are categoria <b>Organizare protecție civilă</b> (agent de inundații, inspector de protecție civilă, taxa de protecție civilă, convenții cu OPEC) și, la „Dotare și adăpost”, adăposturile.' },
      { p: `${ADP}` },
    ],
  },
  {
    id: 'verificari', ic: 'hourglass', title: 'Verificările instalațiilor',
    blocks: [
      { p: 'Verificările periodice sunt rânduri separate, în categoria „Documentație și verificări”. Fiecare are o perioadă de valabilitate:' },
      { ul: [
        '<b>b1</b> instalații electrice — 12 luni; <b>b2</b> împământare (IPT) — 12 sau 24 de luni, la alegere pentru fiecare construcție; <b>b3</b> centrală termică — 24 de luni. Acestea se cer la <b>toate</b> construcțiile.',
        '<b>c1</b> IDSAI — 12 luni; <b>c2</b> hidranți interiori — 6 luni; <b>c3</b> hidranți exteriori — 6 luni; <b>c4</b> desfumare, <b>c5</b> sprinklere, <b>c6</b> drencere, <b>c7</b> instalații speciale — câte 12 luni. Acestea se cer doar la construcțiile care au instalația pe DA.',
      ] },
      { h: 'Cum lucrați' },
      { p: 'La fiecare construcție completați <b>data ultimei verificări</b>. Aplicația calculează până când este valabilă și compară cu data începerii controlului:' },
      { ul: [
        '✓ „valabilă până la 10.06.2027” — verificarea este în termen (inclusiv în ultima zi);',
        '⚠ „expirată — era valabilă până la 10.06.2026” — termenul a trecut înainte de începerea controlului.',
      ] },
      { p: `Pentru o verificare expirată apar o avertizare, un rând în „Ce mai aveți de făcut” și butonul ${B('x', 'Constatat pentru aceasta')}. Decizia vă aparține: aplicația nu constată singură. Datele verificărilor apar în Text PV și în fișă și se preiau la controlul următor al obiectivului.` },
    ],
  },
  {
    id: 'amenzi', ic: 'fine', title: 'Amenzile și termenele',
    blocks: [
      { p: 'Termenele unei amenzi se numără de la <b>data aplicării</b>; dacă nu o completați, aplicația folosește data încheierii controlului. Ziua aplicării este ziua 0, iar ziua următoare este ziua 1.' },
      { ul: [
        `${F('blue', 'În curs')} — zilele 0–15: amenda este în termenul de plată de 15 zile;`,
        `${F('yellow', 'Termen 15 zile expirat')} — zilele 16–39: termenul de plată a trecut;`,
        `${F('red', 'Trimite la ANAF')} — din ziua 40: mai sunt cel mult 5 zile până la termenul de trimitere la ANAF, care este ziua 45;`,
        `${F('green', 'Achitată')} — ați bifat „Achitată – dovadă primită”.`,
      ] },
      { h: 'Exemplu' },
      { p: 'O amendă aplicată pe 5 octombrie 2026:' },
      { ul: [
        '5–20 octombrie: <b>În curs</b>; 20 octombrie este ultima zi de plată;',
        '21 octombrie – 13 noiembrie: <b>Termen 15 zile expirat</b>;',
        'din 14 noiembrie: <b>Trimite la ANAF</b> („Mai aveți 5 zile…”); 19 noiembrie este ultima zi pentru trimiterea la ANAF.',
      ] },
      { h: 'Termenul ASI' },
      { p: 'Dacă la neregula „a” bifați „Termen de prezentare 90 de zile”, termenul este de 90 de zile de la data încheierii controlului. De exemplu, pentru un control încheiat pe 5 octombrie 2026, termenul este 3 ianuarie 2027.' },
      { p: 'Dacă documentația nu a fost prezentată în cele 90 de zile, urmează <b>5 zile calendaristice</b> pentru constatarea pierderii valabilității: în exemplu, 4–8 ianuarie 2027. În aceste zile apare, la neregula „a”, bifa <b>Pierderea valabilității constatată</b> (cu data); după ce o bifați, termenul dispare din Panou.' },
      { h: 'Încărcarea în aplicație' },
      { p: 'Controlul încheiat și documentul (PV scanat) se încarcă în <b>3 zile lucrătoare</b> de la data încheierii; ziua încheierii nu se numără, iar weekendurile și sărbătorile legale se sar. Exemplu: control încheiat joi, 24 septembrie 2026 → vineri 25, luni 28, marți 29 → termen marți, 29 septembrie. Cât mai sunt zile, termenul e portocaliu; în ultima zi și după termen, roșu.' },
      { h: 'Zile nelucrătoare' },
      { p: 'Dacă un termen cade sâmbătă, duminică sau într-o sărbătoare legală (art. 139 din Codul muncii), aplicația <b>nu</b> mută termenul și nici numărătoarea, dar vă avertizează și vă recomandă prima zi lucrătoare de după: ⚠ „cade duminică — următoarea zi lucrătoare: luni, 4 ianuarie 2027; verificați prelungirea”. În exemplul de mai sus, 3 ianuarie 2027 este duminică.' },
      { h: 'Sărbătorile legale, în fiecare an' },
      { p: 'Aplicația calculează singură sărbătorile legale (datele fixe și Paștele ortodox). Legea se poate schimba — de exemplu, 6 și 7 ianuarie au devenit zile libere din 2024 —, așa că din 1 decembrie Panoul vă arată lista pentru anul următor și vă cere s-o verificați. Dacă lista e corectă, apăsați „Am verificat lista pentru …”; dacă nu, cereți actualizarea aplicației. Lista pentru anul curent și cel următor se vede oricând în Setări → Sărbători legale.' },
    ],
  },
  {
    id: 'final', ic: 'pv', title: 'La final: Text PV, Fișa PDF, încheierea',
    blocks: [
      { btns: [
        [B('pv', 'Text PV'), 'Textul constatărilor, gata de copiat în procesul-verbal: fiecare constatare cu construcțiile, datele verificărilor, observațiile, amenda, „neregulă veche” și „sigiliu aplicat”, apoi actele lipsă. Rândurile NEC nu apar. Puteți alege „Doar cele netrecute în PV” și „Include actele lipsă”. Butoane: Copiază, Partajează, Marchează-le trecute în PV.'],
        [B('download', 'Fișa PDF'), 'Fișa completă a controlului: datele, construcțiile (GRF/NSI, anul, GPS, dotările, nr. ASI / aviz), actele, constatările, amenzile, verificările. Apăsați „Tipărește / PDF”, apoi, în fereastra de tipărire, Partajare → Salvează în Fișiere. Dacă tipărirea nu pornește, folosiți „Partajează fișierul”.'],
        [B('check', 'Încheie controlul', 'm-ok'), 'În tabul Obiectiv. Aplicația vă arată întâi ce ați omis, cu acces direct la fiecare lucru; apoi puteți „Încheia oricum”. Data încheierii pornește termenele amenzilor și termenul ASI.'],
      ] },
      { p: 'Un control încheiat se poate redeschide cu <b>Redeschide</b>, lângă data încheierii.' },
    ],
  },
  {
    id: 'obiective', ic: 'building', title: 'Obiective, Istoric, Calendar',
    blocks: [
      { ul: [
        '<b>Obiective</b>: lista obiectivelor controlate. Căutați după nume, localitate, adresă sau dată (12.09.2026, 09.2026 sau 2026; butonul „Dată” deschide un calendar) și filtrați după tip și după <b>filtrele</b> de mai jos. Cardul arată, la toate controalele obiectivului, amenzile pe stadii, ASI în curs, netrecutele în PV și încărcarea, iar pentru <b>ultimul control</b> neregulile grave și sigiliul. Atingeți un obiectiv ca să vedeți datele lui, coordonatele GPS ale construcțiilor, istoricul controalelor și butonul „Control nou pe acest obiectiv”.',
        '<b>Istoric</b>: toate controalele, grupate pe luni, cu căutare după obiectiv, administrator sau dată și cu filtrele În desfășurare / Încheiate și filtrele de mai jos. Fiecare control arată, scris: numărul de nereguli (cele grave primele), adăposturile („3 adăposturi: 2 conforme, 1 neconform”), sigiliul („Sigiliu aplicat · 2 criterii” sau, la construcții diferite, „2 sigilii (2 construcții) · 3 criterii”), câte nu sunt trecute în PV, amenzile cu stadiul lor, termenul ASI și încărcarea — „Neîncărcat în aplicație”, „Document neîncărcat” cu termenul, sau „Încărcat în aplicație · document încărcat”. La fel pe pagina fiecărui obiectiv; în lista Obiective, cardul arată câte controale sunt neîncărcate și sigiliul aplicat la ultimul control.',
        '<b>Calendar</b>: anul și luna se schimbă separat. În fiecare zi vedeți controalele (violet = în desfășurare, albastru închis = încheiat), activitățile (în culoarea tipului lor), zilele libere (fundal gri: weekend și sărbători legale) și bulinele termenelor (albastru = termen de plată, roșu = termen ANAF sau ASI, portocaliu = termen de încărcare). Atingeți o zi ca să vedeți lista completă și butoanele „Control nou în această zi” și „Activitate nouă în această zi” (vedeți „Planul lunar”).',
      ] },
      { h: 'Filtrele din Istoric și Obiective' },
      { p: `Sub căutare, un rând de butoane: ${B('fine', 'Amendă în curs')} ${B('fine', 'Termen 15 zile expirat')} ${B('fine', 'Trimite la ANAF')} ${B('fine', 'Amendă achitată')} ${B('hourglass', 'ASI în curs')} ${B('upload', 'De încărcat')} ${B('pv', 'Netrecute în PV')} ${B('alert', 'Nereguli grave')} ${B('lock', 'Sigiliu aplicat')} ${B('shield', 'Adăposturi PC')}. Fiecare arată câte rezultate ați avea dacă îl atingeți; butonul cu 0 e inactiv. Puteți activa mai multe deodată: rămân doar cele care le îndeplinesc pe <b>toate</b> (de exemplu, Netrecute în PV + Trimite la ANAF). Deasupra listei scrie ce filtre sunt active; ${B('x', 'Șterge filtrele')} le anulează. Filtrele se combină cu căutarea și cu În desfășurare / Încheiate (sau tipul obiectivului).` },
      { p: 'În <b>Obiective</b>, amenzile, ASI, încărcarea și PV se caută la <b>oricare</b> control al obiectivului (sunt lucruri încă deschise); neregulile grave, sigiliul și adăposturile, doar la <b>ultimul control</b> (starea actuală a obiectivului).' },
    ],
  },
  {
    id: 'plan', ic: 'calendar', title: 'Planul lunar: activități și raport',
    blocks: [
      { p: 'Pe lângă controale, în Calendar puteți trece orice altă activitate: planificată dinainte sau notată după ce ați făcut-o. La sfârșitul lunii, <b>Plan lunar</b> vă arată tot ce ați efectuat.' },
      { h: 'O activitate nouă' },
      { ol: [
        'În Calendar, atingeți ziua, apoi <b>Activitate nouă în această zi</b>.',
        'Alegeți tipul: Instruire / pregătire, Ședință, Activitate de birou, Informare publică, Exercițiu / aplicație, Concediu / liber sau Altă activitate. Fiecare tip are culoarea lui în calendar.',
        'Scrieți descrierea (la „Altă activitate” e obligatorie), data, „Până la” dacă ține mai multe zile (de exemplu, un concediu), ora (opțional) și, dacă e cazul, obiectivul la care se referă.',
        'Starea: <b>Planificată</b> sau <b>Efectuată</b> (pentru o zi trecută, aplicația propune „Efectuată”). O activitate se poate și <b>anula</b>.',
      ] },
      { p: 'Atingeți o activitate (în ziua selectată sau în Panou) ca s-o modificați sau s-o ștergeți. În calendar, activitățile efectuate au semnul ✓, iar cele anulate nu mai apar în zi.' },
      { h: 'Zilele libere' },
      { p: 'Weekendurile și sărbătorile legale apar singure în calendar ca zile libere, fără să le introduceți: ziua are fundal gri și eticheta „Liber” sau numele sărbătorii (cu roșu). Până azi inclusiv sunt <b>efectuate</b> (cu ✓), iar cele viitoare sunt <b>planificate</b>. Atingeți ziua ca să vedeți motivul (de exemplu „Zi liberă (sâmbătă)” sau „Sărbătoare legală: Crăciunul”) și starea. Ele nu trebuie confirmate și nu apar la „Activități de confirmat”. Concediul de odihnă se trece în continuare ca activitate „Concediu / liber”.' },
      { h: 'Activitățile de confirmat' },
      { p: 'O activitate planificată a cărei zi a trecut apare în Panou, la „Activități de confirmat”, până alegeți <b>Efectuată</b>, <b>Reprogramează</b> (o mutați pe altă zi) sau <b>Anulată</b>.' },
      { h: 'Raportul lunii' },
      { p: `Butonul ${B('list', 'Plan lunar', 'm-prim')} din Calendar deschide raportul lunii, pe care îl puteți răsfoi lună cu lună. Arată:` },
      { ul: [
        'câte controale ați început în lună (și câte sunt încheiate) și câte nereguli ați constatat la ele;',
        'amenzile aplicate în lună (după data aplicării) și suma lor; amenzile din controale neîncheiate, fără dată, apar separat;',
        'activitățile efectuate, pe tipuri (câte și câte zile), cele încă planificate și cele anulate;',
        'zilele libere ale lunii: câte de weekend, ce sărbători legale, câte efectuate și câte planificate, și câte zile lucrătoare are luna; dacă într-o zi liberă ați început un control sau ați efectuat o activitate (alta decât concediul), ziua apare la „Zile libere în care s-a lucrat”;',
        'lista zi cu zi: controalele și activitățile fiecărei zile.',
      ] },
      { p: 'Raportul se tipărește sau se salvează ca PDF (<b>Tipărește / PDF</b>) ori se trimite ca fișier (<b>Partajează fișierul</b>), la fel ca Fișa controlului. Activitățile intră și în backup.' },
    ],
  },
  {
    id: 'setari', ic: 'settings', title: 'Setări, backup, actualizări',
    blocks: [
      { ul: [
        '<b>Mărimea textului</b>: Mic, Mediu sau Mare; toată interfața se mărește sau se micșorează proporțional.',
        '<b>Tema</b>: Automat (urmează setarea iPad-ului), Luminoasă sau Întunecată.',
        '<b>Backup</b>: „Exportă backup” (același lucru ca Backup rapid) creează un fișier cu toate controalele; salvați-l în Fișiere sau în iCloud Drive. „Importă backup” are două variante: <b>Combină</b> (adaugă controalele din fișier; dacă un control există deja, păstrează versiunea cea mai recentă) și <b>Înlocuiește tot</b>.',
        '<b>Actualizări</b>: aplicația verifică singură, la fiecare deschidere. Când apare bara „Versiune nouă disponibilă”, apăsați <b>Actualizează</b>. „Verifică acum” caută manual.',
        '<b>Sărbători legale</b>: lista pentru anul curent și pentru cel următor, cu starea verificării (vedeți „Amenzile și termenele”).',
        '<b>Date demonstrative</b>: se pot încărca și șterge oricând, fără să vă atingă datele.',
        '<b>Zona periculoasă</b>: ștergerea tuturor datelor. Faceți întâi un backup.',
      ] },
    ],
  },
  {
    id: 'date', ic: 'shield', title: 'Datele dumneavoastră și siguranța lor',
    blocks: [
      { ul: [
        'Datele stau <b>doar pe această tabletă</b>, nu pe internet. Singura copie de siguranță este backupul, deci faceți-l des.',
        'Instalați aplicația pe ecranul principal (Safari → Partajare → „Adaugă pe ecranul principal”): așa datele sunt păstrate în siguranță, iar aplicația merge fără internet.',
        'Localizarea se folosește doar când apăsați „Completează coordonatele”.',
        'Actualizările nu schimbă controalele încheiate: acestea își păstrează lista de nereguli. Câmpurile noi se completează automat și la controalele vechi.',
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
        '<b>EXIT</b> — instalație de iluminat de securitate pentru evacuare · <b>Iluminat Hint</b> — iluminat de securitate pentru marcarea hidranților interiori',
        '<b>CTPSI</b> — cadru tehnic PSI · <b>RESP</b> — responsabil PSI · <b>LFD</b> — lucru cu foc deschis',
        '<b>GRF</b> — grad de rezistență la foc (P118/1999) · <b>NSI</b> — nivel de stabilitate la incendiu (P118-1/2025)',
        '<b>SVSU</b> — serviciu voluntar pentru situații de urgență · <b>PAAR</b> — plan de analiză și acoperire a riscurilor',
        '<b>NEC</b> — nu este cazul · <b>PV</b> — proces-verbal · <b>CT</b> — centrală termică · <b>IPT</b> — instalație de protecție împotriva trăsnetului / împământare',
      ] },
      { p: 'Căutarea din Nereguli și Acte cunoaște aceste abrevieri: „hidranti interiori” găsește și rândurile „Hint”, iar „foc deschis” găsește actul LFD.' },
    ],
  },
];
