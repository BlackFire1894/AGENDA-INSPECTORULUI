// Ghidul de la prima pornire și ajutorul contextual („?”) — texte scurte, ca să nu fie nevoie de manual.

export const GHID = [
  {
    ic: 'home', title: 'Panoul — punctul de pornire',
    lines: [
      '<b>Panoul</b> e punctul de pornire: amenzile pe culori, termenele ASI, controalele neîncheiate și ce nu e încă trecut în PV.',
      'Atingeți orice rând din Panou și ajungeți direct la el în control.',
    ],
  },
  {
    ic: 'plus', title: 'Un control nou',
    lines: [
      'Butonul <b>+</b> (sau <b>Control nou</b>). Scrieți denumirea: dacă obiectivul există deja, alegeți-l și datele de contact și construcțiile se preiau din ultimul control.',
      'Data începerii e azi, implicit. Obiectivul poate fi <b>OPEC / Instituție</b> sau <b>Localitate</b> (cu taburile Planuri și SVSU și Protecție civilă).',
    ],
  },
  {
    ic: 'check', title: 'În control',
    lines: [
      'Mergeți prin taburi, de la stânga la dreapta. La fiecare rând: <b>✓</b> e în regulă, <b>✗</b> e neregulă. La ✗ apar PV-ul și amenda. Căutarea din tab vă duce direct la o neregulă.',
      'Bara <b>„Ce mai ai de făcut”</b> vă arată mereu pasul următor; atingeți-o și vă duce acolo.',
      '<b>Restul conform</b> marchează rândurile rămase, după ce vedeți lista și confirmați cu bifa „Am verificat…”.',
      'Totul se salvează <b>automat</b>, pe loc.',
    ],
  },
  {
    ic: 'pv', title: 'La final',
    lines: [
      '<b>Text PV</b> vă dă lista neregulilor gata de copiat în procesul-verbal. <b>Fișa PDF</b> e rezumatul complet.',
      '<b>Încheie controlul</b> (tabul Obiectiv) vă arată ce ați omis și pornește termenele amenzilor și ASI.',
      'Faceți des <b>Backup rapid</b>: datele sunt doar pe această tabletă.',
    ],
  },
];

export const AJUTOR = {
  panou: {
    title: 'Panoul',
    lines: [
      '<b>Amenzi:</b> albastru = în termenul de 15 zile · galben = termen expirat · roșu = mai sunt ≤ 5 zile până la ANAF · verde = achitată.',
      '<b>⚠</b> apare când un termen cade în weekend sau într-o sărbătoare legală: termenul nu se mută automat, verificați prelungirea.',
      '<b>Neregulă veche</b> = constatată și la un control anterior al aceluiași obiectiv.',
      'Atingeți un rând ca să deschideți controlul exact la neregula respectivă.',
    ],
  },
  obiective: {
    title: 'Obiective',
    lines: [
      'Căutați după <b>nume</b>, <b>localitate</b>, <b>adresă</b> sau <b>dată</b>: 12.09.2026, 09.2026 sau 2026. Butonul <b>Dată</b> deschide calendarul.',
      'Atingeți un obiectiv pentru istoricul lui complet și pentru <b>Control nou pe acest obiectiv</b>.',
    ],
  },
  obiectiv: {
    title: 'Istoricul obiectivului',
    lines: [
      'Datele obiectivului (adresă, contact) și <b>coordonatele GPS ale fiecărei construcții</b>, cu legături spre Google Maps / Hărți Apple.',
      'Toate controalele obiectivului, de la cel mai recent.',
      '<b>Control nou pe acest obiectiv</b> preia datele de contact, adresa și construcțiile (cu dotări, GRF/NSI și coordonate) din ultimul control; actele și neregulile pornesc de la zero.',
    ],
  },
  calendar: {
    title: 'Calendar',
    lines: [
      'Controalele apar pe zilele în care s-au desfășurat (mov = în desfășurare, bleumarin = încheiat).',
      'Punctele colorate sunt termene: albastru = plata amenzii, roșu = ANAF sau ASI.',
      'Atingeți o zi pentru detalii sau pentru <b>Control nou în această zi</b>. Anul și luna se schimbă separat.',
    ],
  },
  istoric: {
    title: 'Istoric',
    lines: [
      'Toate controalele, grupate pe luni. Căutați după obiectiv, administrator sau dată.',
      'Filtrați doar controalele în desfășurare sau doar pe cele încheiate.',
    ],
  },
  setari: {
    title: 'Setări',
    lines: [
      '<b>Backup:</b> exportați regulat în Fișiere / iCloud Drive; la nevoie, importați înapoi (Combină sau Înlocuiește tot).',
      '<b>Mărimea textului</b> și <b>Tema</b> (Automat / Luminoasă / Întunecată) se aplică imediat în toată aplicația.',
      '<b>Ghid de utilizare</b> reia prezentarea de la prima pornire.',
    ],
  },
  'ctrl-obiectiv': {
    title: 'Tabul Obiectiv',
    lines: [
      'Datele obiectivului (inclusiv adresa și localitatea), perioada controlului și construcțiile, fiecare cu dotările ei (DA / NU / NEC = nu este cazul).',
      '<b>Coordonate GPS</b> la fiecare construcție: stați lângă ea și apăsați <b>Completează coordonatele</b>. Poziția se citește o singură dată, doar la cerere; aplicația nu urmărește locația. Dacă localizarea e oprită, vă arată pașii de activare. Precizie bună: ± sub 30 m, în aer liber.',
      'Dotările bifate <b>DA</b> decid ce nereguli de instalații apar în tabul Nereguli.',
      '<b>NU</b> la o instalație înseamnă că lipsește o instalație necesară: e <b>neregulă gravă</b>, marcată cu roșu, și apare prima în tabul Nereguli (G1, G2…). Pentru „nu e cazul” folosiți <b>NEC</b>.',
      '<b>GRF / NSI</b> la fiecare construcție: grad de rezistență la foc (P118/1999) / nivel de stabilitate la incendiu (P118-1/2025), I–V sau „Nu e necesar”. <b>V</b> cu regim de înălțime peste parter (P+1, P+2E, P+M…) = <b>neregulă gravă</b>, cu alertă.',
      '<b>Încheie controlul</b> vă arată ce ați omis înainte de încheiere și pornește termenele.',
    ],
  },
  'ctrl-acte': {
    title: 'Acte și evidențe',
    lines: [
      '<b>✓ Prezentat</b> sau <b>✗ Lipsă</b> pentru fiecare act. Observațiile acceptă mai multe rânduri (Enter).',
      '<b>Restul prezentate</b> arată lista actelor nemarcate și cere bifa „Am verificat…” înainte de marcare; imediat după, aveți <b>Anulează</b>.',
    ],
  },
  'ctrl-nereguli': {
    title: 'Nereguli',
    lines: [
      '<b>Căutare:</b> scrieți litera (d, ag, G1) sau un cuvânt (hidranți, gaz) și lista se restrânge pe loc; ✕ o golește.',
      '<b>✓ Conform</b> sau <b>✗ Constatat</b>. La constatat: construcțiile (una sau mai multe — atingeți meniul și bifați), trecut în PV, amendă (serie, nr., sumă), neregulă veche.',
      'Sus, cu roșu: <b>nereguli grave</b> (G1, G2…) — instalații marcate NU la dotări și construcții cu <b>GRF/NSI V</b> și regim peste parter (P+1, P+2E, P+M…). Apar și dispar singure, după datele din tabul Obiectiv. La constatat, bifa <b>Sigiliu</b> arată în baza cărei nereguli ați aplicat sigiliul.',
      'Rândurile adăugate au bifa <b>Neregulă gravă</b>; bifată, apare și <b>Sigiliu</b>.',
      'Apar doar neregulile pentru instalațiile bifate DA la dotări; <b>Arată toate</b> le afișează și pe celelalte.',
      'Categoriile se strâng din titlul lor; observațiile se ascund individual (săgeata) sau toate deodată.',
      '<b>Restul conform</b> vă arată lista exactă a rândurilor nemarcate și cere bifa „Am verificat…” înainte de marcare; neregulile grave nu intră niciodată în bloc. <b>Adaugă rând</b> pentru nereguli din afara listei.',
    ],
  },
  'ctrl-planuri': {
    title: 'Planuri și SVSU',
    lines: [
      'Pentru localități. <b>✓ Conform</b> sau <b>✗ Neconform</b>; la neconform, ca la nereguli: PV, amendă, neregulă veche.',
      '<b>Căutare</b> după literă sau cuvânt, ca la Nereguli. <b>Restul conforme</b> arată lista și cere bifa „Am verificat…”.',
      'În Text PV și în fișă, rubricile neconforme apar formulate negativ („PAAR neavizat”).',
    ],
  },
  'ctrl-pc': {
    title: 'Protecție civilă',
    lines: [
      'Pentru localități. Sirenele, dotarea și <b>adăpostul</b> (DA / NU / NEC).',
      '„Conform” la „Sirene defecte” înseamnă că nu există sirene defecte.',
      '<b>Căutare</b> după literă sau cuvânt, ca la Nereguli. <b>Restul conforme</b> arată lista și cere bifa „Am verificat…”.',
    ],
  },
};
