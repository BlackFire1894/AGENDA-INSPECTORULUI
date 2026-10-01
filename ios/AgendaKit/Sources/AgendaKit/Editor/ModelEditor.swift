import Foundation

// Ce afișează editorul (js/editor.js), ca modele: fiecare text, pastilă, câmp și buton, în ordinea din web.
// Interfața SwiftUI doar le desenează; EditorWebTests verifică modelele față de HTML-ul web, pas cu pas.

// ───────── elemente comune ─────────

/// Un câmp de text (`field()`): eticheta, calea, valoarea, indiciul, unitatea
public struct ModelCamp: Equatable, Sendable {
    public enum Tip: Sendable { case text, telefon, email, zecimal, numeric, data }
    public let eticheta: String, cale: String, valoare: String, indiciu: String
    public var unitate: String? = nil
    public var tip: Tip = .text
    public var lat = false
    /// sugestii (datalist): structura, pereții
    public var sugestii: [String] = []

    public init(eticheta: String, cale: String, valoare: String, indiciu: String, unitate: String? = nil, tip: Tip = .text, lat: Bool = false, sugestii: [String] = []) {
        self.eticheta = eticheta; self.cale = cale; self.valoare = valoare; self.indiciu = indiciu
        self.unitate = unitate; self.tip = tip; self.lat = lat; self.sugestii = sugestii
    }
}

/// `toggle(path, on, label, { level, ic, offLabel })`
public struct ModelComutator: Equatable, Sendable {
    public let cale: String, activ: Bool, text: String, nivel: String, iconita: String
}

func comutator(_ cale: String, _ on: Bool, _ label: String, nivel: String = "accent", iconita: String = "check", offLabel: String = "") -> ModelComutator {
    ModelComutator(cale: cale, activ: on, text: on || offLabel.isEmpty ? label : offLabel, nivel: nivel, iconita: iconita)
}

/// Observațiile: butonul „+ Obs.” (goale, închise) sau câmpul
public struct ModelObs: Equatable, Sendable {
    public let cale: String, valoare: String
    public let deschis: Bool
}

/// `segBtns(path, value, opts)`: butoane de ales (a doua atingere golește alegerea, dacă e permis)
public struct ModelSegment: Equatable, Sendable {
    public let cale: String
    public let optiuni: [(key: String, label: String)]
    public let ales: String
    public init(cale: String, optiuni: [(key: String, label: String)], ales: String) { self.cale = cale; self.optiuni = optiuni; self.ales = ales }
    public static func == (a: Self, b: Self) -> Bool {
        a.cale == b.cale && a.ales == b.ales && a.optiuni.map(\.key) == b.optiuni.map(\.key) && a.optiuni.map(\.label) == b.optiuni.map(\.label)
    }
}

/// `okNok(path, status, okLabel, nokLabel, { nec })`
public struct ModelOkNok: Equatable, Sendable {
    public let cale: String, stare: String, ok: String, nok: String, nec: Bool
}

/// `cdBox(days, { lucr })`: numărătoarea unui termen
public struct ModelNumaratoare: Equatable, Sendable {
    public let numar: Int, text: String, depasit: Bool
}

func cdBox(_ days: Int, lucr: Bool = false) -> ModelNumaratoare {
    let n = abs(days)
    let u = "\(n == 1 ? "zi" : "zile")\(lucr && days > 0 ? " lucrătoare" : "")"
    return ModelNumaratoare(numar: n, text: days < 0 ? "\(u) peste termen" : days == 0 ? "ultima zi: azi" : "\(u) rămase", depasit: days <= 0)
}

/// `.deadline`: termen cu iconiță, titlu, mesaj și numărătoare
public struct ModelTermen: Equatable, Sendable {
    /// „dl-red” | „dl-green” | „dl-warn”
    public let nivel: String
    public let iconita: String, titlu: String
    public var mesaj: String? = nil
    public var nelucr: String? = nil
    public var numaratoare: ModelNumaratoare? = nil
}

// ───────── editorul ─────────

public struct ModelEditor: Equatable, Sendable {
    public let antet: ModelAntetEditor
    public let todo: ModelTodo
    public let taburi: [ModelTabEditor]
    public let corp: CorpEditor
    public let anulare: Bool, refacere: Bool
}

public struct ModelAntetEditor: Equatable, Sendable {
    public let tip: String, incheiat: Bool, titlu: String, perioada: String
}

public struct ModelTodo: Equatable, Sendable {
    public let pasi: [PasDeFacut]
    public let deschis: Bool
}

public struct ModelTabEditor: Equatable, Sendable {
    public let key: String, label: String, iconita: String, nr: Int, activ: Bool
    public let text: String, avertizare: Bool
    public let progres: String, gata: Int, total: Int
    public var complet: Bool { gata == total && total > 0 }
}

public enum CorpEditor: Equatable, Sendable {
    case obiectiv(ModelTabObiectiv)
    case acte(ModelTabActe)
    case sectiune(ModelTabSectiune)
}

public func modelEditor(_ c: Control, _ controls: [Control], _ ed: Editor, azi: String) -> ModelEditor {
    let inc = isIncheiat(c)
    let antet = ModelAntetEditor(
        tip: c.tip == "LOCALITATE" ? "Localitate" : "OPEC / Instituție", incheiat: inc,
        titlu: c.denumire.isEmpty ? "Obiectiv fără denumire" : c.denumire,
        perioada: "\(fmtDate(c.dataInceput))\(inc ? " – \(fmtDate(c.dataIncheiere))" : " – în desfășurare")")
    let t = tabsFor(c).first { $0.key == ed.tab }
    let corp: CorpEditor
    if let t, t.key == "acte" { corp = .acte(modelTabActe(c, ed, azi: azi)) }
    else if let t, let sec = t.sec { corp = .sectiune(modelTabSectiune(c, controls, ed, sec, azi: azi)) }
    else { corp = .obiectiv(modelTabObiectiv(c, controls, ed, azi: azi)) }
    let h = ed.istoric.stare(c.id)
    return ModelEditor(antet: antet, todo: ModelTodo(pasi: todoList(c), deschis: ed.ui.todoOpen),
                       taburi: modelTaburi(c, ed.tab, azi: azi), corp: corp, anulare: h.anulare > 0, refacere: h.refacere > 0)
}

/// „1 constatată / 2 constatate”, „1 neconformă / 2 neconforme”
func nokWord(_ sec: String, _ n: Int) -> String {
    sec == "ner" ? (n == 1 ? "constatată" : "constatate") : (n == 1 ? "neconformă" : "neconforme")
}

/// Taburile: starea în cuvinte (portocaliu: acte lipsă / constatări netrecute în PV) și cât e completat
public func modelTaburi(_ c: Control, _ tab: String, azi: String) -> [ModelTabEditor] {
    let st = controlStats(c, azi)
    return tabsFor(c).enumerated().map { i, t in
        let text: String, warn: Bool, ce: String, gata: Int, total: Int
        if t.key == "obiectiv" {
            let n = c.constructii.count
            (text, warn) = ("\(n) \(n == 1 ? "construcție" : "construcții")", false)
            let s = c.constructii.map { dotariSummary(c, $0) }.reduce((0, 0)) { ($0.0 + $1.set, $0.1 + $1.total) }
            (ce, gata, total) = ("Dotări", s.0, s.1)
        } else if t.key == "acte" {
            (text, warn) = ("\(st.acteNok) lipsă", st.acteNok > 0)
            (ce, gata, total) = ("Verificate", st.acteDone, st.acteTotal)
        } else {
            let sec = t.sec ?? "ner"
            let s2 = secStats(c, sec, azi)
            if s2.constatate == 0 { (text, warn) = ("0 \(nokWord(sec, 0))", false) } else {
                text = "\(s2.constatate) \(nokWord(sec, s2.constatate))\(s2.netrecute > 0 ? " · \(s2.netrecute) \(s2.netrecute == 1 ? "netrecută" : "netrecute") în PV" : "")"
                warn = s2.netrecute > 0
            }
            (ce, gata, total) = ("Verificate", s2.checked, s2.total)
        }
        return ModelTabEditor(key: t.key, label: t.label, iconita: t.iconita, nr: i + 1, activ: t.key == tab,
                              text: text, avertizare: warn, progres: ce, gata: gata, total: total)
    }
}

// ───────── TAB 1: OBIECTIV ─────────

public struct ModelTabObiectiv: Equatable, Sendable {
    public let tip: ModelSegment
    public let campuri: [ModelCamp]   // denumire, administrator, persoana participantă, telefon, email, adresă, localitate
    public let telefon: String, email: String
    /// „De întrebat până la finalizarea controlului”
    public let intrebari: ModelIntrebari
    /// „Observații generale”
    public let observatiiGenerale: String
    public let dataInceput: String, dataIncheiere: String, incheiat: Bool
    /// „Data încheierii este înaintea datei de începere.”
    public let eroareIncheiere: Bool
    public let incarcare: ModelIncarcare?
    /// numărul construcțiilor (− / +)
    public let nrConstructii: Int
    /// căutarea și „Filtre” din Construcții (v1.26; nil la o singură construcție)
    public let unelteConstructii: ModelUnelteConstructii?
    /// cu căutarea / filtrele active: etichetele ✕ și „2 din 6 construcții”
    public let constructiiFiltrate: ModelConstructiiFiltrate?
    /// construcțiile afișate (toate sau cele găsite)
    public let constructii: [ModelConstructie]
    /// „Nicio construcție nu se potrivește…”
    public let constructiiGol: String?
    /// nil la Localitate (adăposturile sunt în tabul Protecție civilă)
    public let adaposturi: ModelAdaposturi?
}

/// Construcții (v1.26): căutarea (denumire sau dotare DA) și panoul „Filtre”
public struct ModelUnelteConstructii: Equatable, Sendable {
    public let valoare: String
    public let deschis: Bool
    /// câte filtre sunt active (cifra de pe „Filtre”)
    public let active: Int
    /// „Dotate cu (DA)”, „Fără (NU)”, „Stare” (doar grupele cu alegeri); gol = încă nimic de filtrat
    public let grupe: [ModelGrupFiltre]
}

public struct ModelGrupFiltre: Equatable, Sendable {
    public let titlu: String
    public let optiuni: [ModelOptiuneFiltru]
}

/// O alegere din „Filtre”, cu numărul construcțiilor
public struct ModelOptiuneFiltru: Equatable, Sendable {
    public let val: String, text: String, n: Int, activ: Bool
}

public struct ModelConstructiiFiltrate: Equatable, Sendable {
    public let etichete: [ModelEticheta]
    /// „2 din 6 construcții”
    public let numar: String
}

/// Un filtru activ, ca etichetă cu ✕: acțiunea care îl scoate
public struct ModelEticheta: Equatable, Sendable {
    public let act: String, date: [String: String], text: String
    /// eticheta construcției (cu iconița clădirii)
    public var constructie = false
}

/// „Sprinklere: DA”, „IDSAI: NU”, „Dotări necompletate”, „Instalații lipsă”
func numeFiltruConstr(_ f: String) -> String {
    let p = f.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
    if p[0] == "necomplet" { return "Dotări necompletate" }
    if p[0] == "lipsa" { return "Instalații lipsă" }
    let key = p.count > 1 ? p[1] : ""
    return "\(K.dotari.first { $0.key == key }?.label ?? key): \(p[0] == "da" ? "DA" : "NU")"
}

func modelUnelteConstructii(_ c: Control, _ ed: Editor) -> ModelUnelteConstructii {
    let u = ed.ui
    let o = optiuniFiltreConstructii(c, u.constrFlt.ordine)
    let opt = { (val: String, text: String, n: Int) in ModelOptiuneFiltru(val: val, text: text, n: n, activ: u.constrFlt.are(val)) }
    var grupe: [ModelGrupFiltre] = []
    if !o.da.isEmpty { grupe.append(ModelGrupFiltre(titlu: "Dotate cu (DA)", optiuni: o.da.map { opt("da:\($0.key)", $0.label, $0.n) })) }
    if !o.nu.isEmpty { grupe.append(ModelGrupFiltre(titlu: "Fără (NU)", optiuni: o.nu.map { opt("nu:\($0.key)", $0.label, $0.n) })) }
    var stare: [ModelOptiuneFiltru] = []
    if o.necomplet > 0 || u.constrFlt.are("necomplet") { stare.append(opt("necomplet", "Dotări necompletate", o.necomplet)) }
    if o.lipsa > 0 || u.constrFlt.are("lipsa") { stare.append(opt("lipsa", "Instalații lipsă", o.lipsa)) }
    if !stare.isEmpty { grupe.append(ModelGrupFiltre(titlu: "Stare", optiuni: stare)) }
    return ModelUnelteConstructii(valoare: u.constrQuery, deschis: u.constrFltOpen, active: u.constrFlt.count, grupe: grupe)
}

/// „De întrebat până la finalizarea controlului”: sarcini cu bifă; cele nebifate apar în „Ce mai aveți de făcut”
public struct ModelIntrebari: Equatable, Sendable {
    public struct Rand: Equatable, Sendable { public let id: String, text: String, gata: Bool }
    public let randuri: [Rand]
    /// „2 nerezolvate” (portocaliu) / „Toate rezolvate” (verde) / nimic (listă goală)
    public let pastila: PastilaUI?
}

func modelIntrebari(_ c: Control) -> ModelIntrebari {
    let l = c.deIntrebat
    let rest = l.filter { !$0.gata && !$0.text.trimJS.isEmpty }.count
    let pastila = rest > 0 ? PastilaUI("warn", "\(rest) \(rest == 1 ? "nerezolvată" : "nerezolvate")", nil)
        : l.isEmpty ? nil : PastilaUI("green", "Toate rezolvate", "check")
    return ModelIntrebari(randuri: l.map { .init(id: $0.id, text: $0.text, gata: $0.gata) }, pastila: pastila)
}

public struct ModelIncarcare: Equatable, Sendable {
    public let aplicatie: ModelComutator, aplicatieData: String?
    public let document: ModelComutator, documentData: String?
    public let termen: ModelTermen
}

public struct ModelAdaposturi: Equatable, Sendable {
    public let rand: ModelRandAdapost
    public let randuri: [ModelRandNeregula]
    public let notaNeconforme: Bool
}

public func modelTabObiectiv(_ c: Control, _ controls: [Control], _ ed: Editor, azi: String) -> ModelTabObiectiv {
    let campuri = [
        ModelCamp(eticheta: "Denumire obiectiv", cale: "denumire", valoare: c.denumire, indiciu: "ex: Școala Gimnazială nr. 1", lat: true),
        ModelCamp(eticheta: "Administrator obiectiv", cale: "administrator", valoare: c.administrator, indiciu: "Nume și prenume"),
        ModelCamp(eticheta: "Persoană participantă", cale: "persoanaParticipanta", valoare: c.persoanaParticipanta, indiciu: "Nume și prenume, funcția"),
        ModelCamp(eticheta: "Telefon", cale: "telefon", valoare: c.telefon, indiciu: "07xx xxx xxx", tip: .telefon),
        ModelCamp(eticheta: "Email", cale: "email", valoare: c.email, indiciu: "nume@exemplu.ro", tip: .email),
        ModelCamp(eticheta: "Adresă", cale: "adresa", valoare: c.adresa, indiciu: "Strada, nr., bloc…"),
        ModelCamp(eticheta: "Localitate", cale: "localitate", valoare: c.localitate, indiciu: "ex: Cluj-Napoca"),
    ]
    var adp: ModelAdaposturi?
    if !isLocalitate(c) {
        adp = ModelAdaposturi(rand: modelRandAdapost(c, ed),
                              randuri: adaposturi(c).filter { isApplicable(c, $0) }.map { modelRandNeregula(c, controls, ed, $0, azi: azi) },
                              notaNeconforme: (adaposturiStats(c)?.neconforme ?? 0) > 0)
    }
    // Construcții: toate sau, cu căutarea / filtrele (v1.26), doar cele găsite
    let filtrat = ed.constrFiltrat(c)
    let rez = filtrat ? constructiiFiltrate(c, ed.ui.constrQuery, ed.ui.constrFlt.ordine)
        : c.constructii.enumerated().map { ConstructieGasita(k: $1, i: $0, potriviri: []) }
    let q = ed.ui.constrQuery.trimJS
    return ModelTabObiectiv(
        tip: ModelSegment(cale: "tip", optiuni: K.tipObiectiv, ales: c.tip),
        campuri: campuri, telefon: c.telefon, email: c.email,
        intrebari: modelIntrebari(c), observatiiGenerale: c.observatiiGenerale,
        dataInceput: c.dataInceput, dataIncheiere: c.dataIncheiere, incheiat: isIncheiat(c),
        eroareIncheiere: isIncheiat(c) && c.dataIncheiere < c.dataInceput,
        incarcare: modelIncarcare(c, azi: azi),
        nrConstructii: c.constructii.count,
        unelteConstructii: c.constructii.count > 1 ? modelUnelteConstructii(c, ed) : nil,
        constructiiFiltrate: filtrat ? ModelConstructiiFiltrate(
            etichete: ed.ui.constrFlt.ordine.map { ModelEticheta(act: "constr-flt", date: ["val": $0], text: numeFiltruConstr($0)) },
            numar: "\(rez.count) din \(c.constructii.count) construcții") : nil,
        constructii: rez.map { modelConstructie(c, $0.k, $0.i, ed, potriviri: $0.potriviri) },
        constructiiGol: rez.isEmpty ? "Nicio construcție nu se potrivește\(q.isEmpty ? "" : " cu „\(q)”")\(ed.ui.constrFlt.isEmpty ? "" : " și filtrelor alese")." : nil,
        adaposturi: adp)
}

/// După încheiere: controlul încărcat în aplicația ISU și documentul (PV scanat) — 3 zile lucrătoare
func modelIncarcare(_ c: Control, azi: String) -> ModelIncarcare? {
    guard let s = incarcareStatus(c, azi) else { return nil }
    let inc = c.incarcare
    let termen = s.gata
        ? ModelTermen(nivel: "dl-green", iconita: "check", titlu: "Încărcat în aplicație și document încărcat")
        : ModelTermen(nivel: s.level == "red" ? "dl-red" : "dl-warn", iconita: "hourglass",
                      titlu: "Termen de încărcare: \(fmtDateLong(s.termen ?? ""))", mesaj: s.msg ?? "",
                      numaratoare: cdBox(s.daysLeft ?? 0, lucr: true))
    let cand = { (d: String) -> String? in d.isEmpty ? nil : "bifat pe \(fmtDate(d))" }
    return ModelIncarcare(
        aplicatie: comutator("incarcare.aplicatie", inc.aplicatie, "Încărcat în aplicație", nivel: "green", offLabel: "Neîncărcat în aplicație"),
        aplicatieData: inc.aplicatie ? cand(inc.aplicatieData) : nil,
        document: comutator("incarcare.document", inc.document, "Document încărcat", nivel: "green", offLabel: "Document neîncărcat"),
        documentData: inc.document ? cand(inc.documentData) : nil,
        termen: termen)
}

// ───────── construcțiile ─────────

public struct SumarDotari: Equatable, Sendable { public let da: Int, nec: Int, set: Int, lipsa: Int, total: Int }

/// Dotările completate (rândurile ascunse nu se numără: iluminat Hint fără hidranți interiori, dotări noi la controalele vechi)
public func dotariSummary(_ c: Control, _ k: Constructie) -> SumarDotari {
    var da = 0, nec = 0, set = 0, lipsa = 0
    let vis = dotariVizibile(c, k)
    for d in vis {
        let v = k.dotare(d.key) ?? Dotare()
        if d.centrala { if !v.ct.isEmpty || !v.tipuri.isEmpty || v.nuAre { set += 1 }; continue }
        if !v.v.isEmpty { set += 1 }
        if v.v == "DA" { da += 1 }
        if v.v == "NEC" { nec += 1 }
        if v.v == "NU" && K.lipsaDotari.contains(d.key) { lipsa += 1 }
    }
    return SumarDotari(da: da, nec: nec, set: set, lipsa: lipsa, total: vis.count)
}

public struct ModelConstructie: Equatable, Sendable {
    public let id: String, nr: Int, deschisa: Bool
    public let denumire: ModelCamp
    /// „2 instalații lipsă”
    public let lipsa: String?
    public let grfV: Bool
    public let sumar: String
    /// ▲▼ (la mai multe construcții): se poate muta mai sus / mai jos
    public let ordine: (sus: Bool, jos: Bool)?
    public let corp: ModelCorpConstructie?
    public static func == (a: Self, b: Self) -> Bool {
        a.id == b.id && a.nr == b.nr && a.deschisa == b.deschisa && a.denumire == b.denumire && a.lipsa == b.lipsa && a.grfV == b.grfV
            && a.sumar == b.sumar && a.ordine?.sus == b.ordine?.sus && a.ordine?.jos == b.ordine?.jos && a.corp == b.corp
    }
}

public struct ModelCorpConstructie: Equatable, Sendable {
    public let campuri: [ModelCamp]
    public let grf: ModelGrf
    public let gps: ModelGps
    public let dotari: [ModelDotare]
    public let stergere: Bool
}

public struct ModelGrf: Equatable, Sendable {
    public let cale: String, ales: String, grav: Bool
    /// „Neregulă gravă: GRF/NSI V cu regim de înălțime … (peste parter). Apare în tabul Nereguli.”
    public let nota: String?
    public static let optiuni: [(key: String, label: String)] = [("I", "I"), ("II", "II"), ("III", "III"), ("IV", "IV"), ("V", "V"), ("NN", "Nu e necesar")]
    public static func == (a: Self, b: Self) -> Bool { a.cale == b.cale && a.ales == b.ales && a.grav == b.grav && a.nota == b.nota }
}

public struct ModelGps: Equatable, Sendable {
    public let id: String
    public let cautare: Bool
    /// nil = necompletat
    public let coordonate: String?
    /// „buna” | „medie” | „slaba” | „manual” (introduse de mână)
    public var calitate = "", precizie = "", preluate: String? = nil
    public var slaba = false
    public var google = "", apple = ""
    /// de la a doua construcție: „Aceleași coordonate ca la …”
    public var caPrima: CaPrima? = nil

    public struct CaPrima: Equatable, Sendable {
        public let activ: Bool, disponibil: Bool, text: String
    }
}

public struct ModelDotare: Equatable, Sendable {
    public let key: String, eticheta: String, cale: String
    /// dotarea căutată sau aleasă în filtre (evidențiată; v1.26)
    public var gasit = false
    /// centrala: tipurile alese și „NU ARE”
    public let centrala: Bool
    public var tipuri: [String] = [], nuAre = false
    public var segment: ModelSegment? = nil
    public var grav = false
    /// centrala (v1.25): centralele construcției, fiecare cu tipurile ei
    public var centrale: [ModelCentrala] = []
    public let obs: ModelObs
    /// nr. autorizație / aviz la DA
    public var nr: ModelCamp? = nil
}

/// O centrală termică: „CT 1”, cu tipurile alese
public struct ModelCentrala: Equatable, Sendable {
    public let id: String, nr: Int, tipuri: [String]
}

func modelConstructie(_ c: Control, _ k: Constructie, _ i: Int, _ ed: Editor, potriviri: Set<String> = []) -> ModelConstructie {
    let open = ed.isOpen(c, k, i)
    let p = "constructii.#\(k.id)"
    let s = dotariSummary(c, k)
    let n = c.constructii.count
    var sumar = "\(s.set)/\(s.total) dotări"
    if !k.suprafata.isEmpty { sumar += " · \(k.suprafata) m²" }
    if !k.regimInaltime.isEmpty { sumar += " · \(k.regimInaltime)" }
    if !k.grf.isEmpty { sumar += " · \(k.grf == "NN" ? "GRF/NSI nu e necesar" : "GRF/NSI \(k.grf)")" }
    if k.gps != nil { sumar += " · GPS ✓" }
    var corp: ModelCorpConstructie?
    if open {
        let grav = grfVPesteParter(k)
        corp = ModelCorpConstructie(
            campuri: [
                ModelCamp(eticheta: "Suprafață desfășurată", cale: "\(p).suprafata", valoare: k.suprafata, indiciu: "0", unitate: "m²", tip: .zecimal),
                ModelCamp(eticheta: "Regim de înălțime", cale: "\(p).regimInaltime", valoare: k.regimInaltime, indiciu: "ex: S+P+2E"),
                ModelCamp(eticheta: "Nr. angajați", cale: "\(p).nrAngajati", valoare: k.nrAngajati, indiciu: "0", tip: .numeric),
                ModelCamp(eticheta: "Anul construirii", cale: "\(p).anConstruire", valoare: k.anConstruire, indiciu: "ex: 1978", tip: .numeric),
                ModelCamp(eticheta: "Structura de rezistență", cale: "\(p).structura", valoare: k.structura, indiciu: "Alegeți sau scrieți", sugestii: K.structuri),
                ModelCamp(eticheta: "Material pereți", cale: "\(p).materialPereti", valoare: k.materialPereti, indiciu: "Alegeți sau scrieți", sugestii: K.materialePereti),
            ],
            grf: ModelGrf(cale: "\(p).grf", ales: k.grf, grav: grav,
                          nota: grav ? "Neregulă gravă: GRF/NSI V cu regim de înălțime \(k.regimInaltime) (peste parter). Apare în tabul Nereguli." : nil),
            gps: modelGps(c, k, i, ed),
            dotari: dotariVizibile(c, k).map { d in var m = modelDotare(c, p, k, d, ed); m.gasit = potriviri.contains(d.key); return m },
            stergere: c.constructii.count > 1)
    }
    return ModelConstructie(
        id: k.id, nr: i + 1, deschisa: open,
        denumire: ModelCamp(eticheta: "", cale: "\(p).denumire", valoare: k.denumire, indiciu: "Denumirea construcției \(i + 1)"),
        lipsa: s.lipsa > 0 ? "\(s.lipsa) \(s.lipsa == 1 ? "instalație lipsă" : "instalații lipsă")" : nil,
        grfV: grfVPesteParter(k), sumar: sumar, ordine: n > 1 ? (i > 0, i < n - 1) : nil, corp: corp)
}

/// Coordonate GPS pe construcție: preluate doar la cerere (o atingere), cu precizia afișată și legături spre hărți;
/// sau introduse de mână (v1.25). De la a doua construcție: „Aceleași coordonate ca la …” copiază coordonatele primei.
func modelGps(_ c: Control, _ k: Constructie, _ i: Int, _ ed: Editor) -> ModelGps {
    let busy = ed.ui.gpsBusy == k.id
    var caPrima: ModelGps.CaPrima?
    if i > 0, let prima = c.constructii.first {
        caPrima = .init(activ: gpsEgal(k.gps, prima.gps), disponibil: prima.gps != nil,
                        text: "Aceleași coordonate ca la \(prima.denumire.isEmpty ? "Construcția 1" : prima.denumire)\(prima.gps == nil ? " (necompletate)" : "")")
    }
    guard let g = k.gps else { return ModelGps(id: k.id, cautare: busy, coordonate: nil, caPrima: caPrima) }
    let q = gpsQuality(g)
    var cand: String?
    if let d = dataDinISO(g.la) {
        let cal = Ceas.calendar
        let p = cal.dateComponents([.hour, .minute], from: d)
        cand = "\(fmtDate(toISO(d))), \(String(format: "%02d:%02d", p.hour ?? 0, p.minute ?? 0))"
    }
    let numeHarta = [c.denumire, k.denumire.isEmpty ? "Construcția \(i + 1)" : k.denumire].filter { !$0.isEmpty }.joined(separator: " – ")
    let manual = q == "manual"
    return ModelGps(id: k.id, cautare: busy, coordonate: fmtCoord(g), calitate: q,
                    precizie: manual ? "introduse manual" : "± \(rotunjesteJS(g.acc)) m · precizie \(q == "buna" ? "bună" : q == "medie" ? "medie" : "slabă")",
                    preluate: cand.map { manual ? $0 : "preluate \($0)" }, slaba: q == "slaba", google: googleMapsUrl(g), apple: appleMapsUrl(g, numeHarta),
                    caPrima: caPrima)
}

/// `new Date(iso)` pentru momentele salvate de aplicație („2026-09-01T08:00:00.000Z”)
func dataDinISO(_ s: String) -> Date? {
    guard !s.isEmpty else { return nil }
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = f.date(from: s) { return d }
    f.formatOptions = [.withInternetDateTime]
    return f.date(from: s)
}

func modelObs(_ c: Control, _ ed: Editor, _ cale: String, _ valoare: String, deschis: Bool = false) -> ModelObs {
    let gol = valoare.trimJS.isEmpty
    return ModelObs(cale: cale, valoare: valoare, deschis: deschis || !gol || ed.ui.obsOpen.contains(obsKey(c, cale)))
}

func modelDotare(_ c: Control, _ p: String, _ k: Constructie, _ d: DotareSablon, _ ed: Editor) -> ModelDotare {
    let v = k.dotare(d.key) ?? Dotare()
    let path = "\(p).dotari.\(d.key)"
    if d.centrala {
        // câte centrale (CT 1, CT 2…), fiecare cu tipurile ei; „NU ARE” le șterge
        return ModelDotare(key: d.key, eticheta: d.label, cale: path, centrala: true, tipuri: v.tipuri, nuAre: v.nuAre,
                           centrale: v.ct.enumerated().map { ModelCentrala(id: $1.id, nr: $0 + 1, tipuri: $1.tipuri) },
                           obs: modelObs(c, ed, "\(path).obs", v.obs))
    }
    let grav = v.v == "NU" && K.lipsaDotari.contains(d.key)
    var m = ModelDotare(key: d.key, eticheta: d.label, cale: path, centrala: false,
                        segment: ModelSegment(cale: "\(path).v", optiuni: d.opts.map { ($0, $0) }, ales: v.v),
                        grav: grav, obs: modelObs(c, ed, "\(path).obs", v.obs))
    if let nr = d.nr, !nr.isEmpty, v.v == "DA" {
        m.nr = ModelCamp(eticheta: nr, cale: "\(path).nr", valoare: v.nr, indiciu: "ex: 1234 din 12.05.2019")
    }
    return m
}

// ───────── adăposturi de protecție civilă ─────────

public struct ModelRandAdapost: Equatable, Sendable {
    /// „2” la Localitate (în categoria „Dotare și adăpost”), altfel iconița
    public let litera: String?
    public let segment: ModelSegment
    /// la DA: câte sunt (fiecare devine un rând A1, A2…)
    public let numar: Int?
    public let sumar: String?
    public let obs: ModelObs
}

func modelRandAdapost(_ c: Control, _ ed: Editor) -> ModelRandAdapost {
    let v = c.adapostPC
    let n = adaposturi(c).count
    return ModelRandAdapost(
        litera: isLocalitate(c) ? "2" : nil,
        segment: ModelSegment(cale: "adapostPC.v", optiuni: ["DA", "NU", "NEC"].map { ($0, $0) }, ales: v.v),
        numar: v.v == "DA" ? n : nil,
        sumar: v.v == "DA" && n > 0 ? adaposturiStats(c).map(adaposturiText) : nil,
        obs: modelObs(c, ed, "adapostPC.obs", v.obs))
}

// ───────── TAB 2: ACTE ─────────

public struct ModelTabActe: Equatable, Sendable {
    public let verificate: Int, total: Int, prezentate: Int, lipsa: Int, nec: Int
    public let cautare: ModelCautare
    /// filtrele active (etichete ✕)
    public let etichete: [ModelEticheta]
    public let rest: String?
    public let rezultat: ModelNotaCautare?
    public let grup: ModelGrupActe
}

/// Căutarea și butonul „Filtre” (v1.26): starea, construcția (la nereguli) și afișarea (restrânge / extinde)
public struct ModelCautare: Equatable, Sendable {
    public let sec: String, valoare: String, indiciu: String
    /// panoul „Filtre” deschis
    public let meniuDeschis: Bool
    /// câte filtre sunt active (cifra de pe „Filtre”)
    public let active: Int
    /// „Stare”: Toate / Constatate / Netrecute în PV / Neverificate (la Acte: Toate / Lipsă / Neverificate)
    public let stare: [ModelFiltru]
    /// „Construcția”: Toate (cheia "") + fiecare construcție (cheia = id); gol = fără grup
    public let constructii: [ModelFiltru]
    /// „Afișare”: butoanele (acțiune, date, text, iconiță)
    public let meniu: [ButonMeniu]
}

/// Filtrele active (etichete ✕) ale tabului: starea și, la nereguli, construcția
func eticheteActive(_ c: Control, _ ed: Editor, _ sec: String, _ stare: [ModelFiltru]) -> [ModelEticheta] {
    var l: [ModelEticheta] = []
    if ed.ui.nerFilter != "ALL", let s = stare.first(where: { $0.key == ed.ui.nerFilter }) {
        l.append(ModelEticheta(act: "ner-filter", date: ["val": "ALL"], text: s.text))
    }
    let kId = sec == "acte" ? "" : ed.constrFiltruNer(c)
    if !kId.isEmpty, let i = c.constructii.firstIndex(where: { $0.id == kId }) {
        let k = c.constructii[i]
        l.append(ModelEticheta(act: "ner-constr", date: ["val": ""], text: "\(i + 1). \(k.denumire.isEmpty ? "Construcția \(i + 1)" : k.denumire)", constructie: true))
    }
    return l
}

/// „Construcția” din „Filtre” (nereguli, la mai multe construcții): Toate + fiecare construcție
func filtruConstructii(_ c: Control, _ ed: Editor) -> [ModelFiltru] {
    guard c.constructii.count > 1 else { return [] }
    let kId = ed.constrFiltruNer(c)
    return [ModelFiltru(key: "", text: "Toate", activ: kId.isEmpty)] + c.constructii.enumerated().map { i, k in
        ModelFiltru(key: k.id, text: "\(i + 1). \(k.denumire.isEmpty ? "Construcția \(i + 1)" : k.denumire)", activ: kId == k.id)
    }
}

public struct ButonMeniu: Equatable, Sendable {
    public let act: String, date: [String: String], text: String, iconita: String
}

public struct ModelFiltru: Equatable, Sendable {
    public let key: String, text: String, activ: Bool
}

/// Rezultatul căutării: „3 rânduri găsite pentru „x”” + butoanele
public struct ModelNotaCautare: Equatable, Sendable {
    public let gasite: Int
    public let text: String
    public let cautaInToate: Bool
    /// „+2 ascunse · Arată toate”
    public let ascunse: String?
}

public struct ModelGrupActe: Equatable, Sendable {
    public let restrans: Bool, dezactivat: Bool
    public let numar: String
    public let info: [ModelInfoCategorie]
    public let randuri: [ModelRandAct]
}

/// O pastilă din bara categoriei (cat-stare / cat-count / cat-pv / cat-amenzi / cat-sigiliu)
public struct ModelInfoCategorie: Equatable, Sendable {
    /// „st-rest” | „st-gata” | „count” | „pv-rest” | „pv-gata” | „amenzi” | „sigiliu”
    public let tip: String
    public let text: String
}

public struct ModelRandAct: Equatable, Sendable {
    public let key: String, nr: Int, eticheta: String, stare: String, restrans: Bool
    public let pastile: [PastilaUI]
    /// „+ Obs.” în bara rândului (observații goale)
    public let obsInBara: ModelObs?
    public let okNok: ModelOkNok?
    /// corpul rândului: câmpul de observații
    public let obs: ModelObs?
}

let ACT_OK = "Prezentat", ACT_NOK = "Lipsă"

public func modelTabActe(_ c: Control, _ ed: Editor, azi: String) -> ModelTabActe {
    let st = controlStats(c, azi)
    let acte = acteOf(c)
    let stari = acte.map { c.act($0.key).status }
    let actKey = { (k: String) in "\(c.id)|act:\(k)" }
    let deschiseGata = acte.filter { !c.act($0.key).status.isEmpty && !ed.ui.rowCollapsed.are(actKey($0.key)) }.count
    let vreunaInchisa = acte.contains { ed.ui.rowCollapsed.are(actKey($0.key)) }
    let gol = stari.filter(\.isEmpty).count
    var meniu: [ButonMeniu] = []
    if deschiseGata > 0 { meniu = [ButonMeniu(act: "rows-collapse", date: ["sec": "acte"], text: "Restrânge completate (\(deschiseGata))", iconita: "list")] }
    else if vreunaInchisa { meniu = [ButonMeniu(act: "rows-expand", date: ["sec": "acte"], text: "Deschide rândurile", iconita: "chevD")] }
    let f = ed.ui.nerFilter
    let (nota, grup) = acteRezultate(c, ed)
    let stare = [("ALL", "Toate"), ("NOK", "Lipsă (\(st.acteNok))"), ("TODO", "Neverificate (\(gol))")].map { ModelFiltru(key: $0.0, text: $0.1, activ: f == $0.0) }
    return ModelTabActe(
        verificate: st.acteDone, total: st.acteTotal, prezentate: stari.filter { $0 == "ok" }.count, lipsa: st.acteNok,
        nec: stari.filter { $0 == "nec" }.count,
        cautare: ModelCautare(sec: "acte", valoare: ed.ui.nerQuery, indiciu: "Caută: numărul actului sau text (ex. LFD, instruire)",
                              meniuDeschis: ed.ui.toolsOpen, active: f != "ALL" ? 1 : 0, stare: stare, constructii: [], meniu: meniu),
        etichete: eticheteActive(c, ed, "acte", stare),
        rest: gol > 0 ? "Restul prezentate (\(gol))" : nil,
        rezultat: nota, grup: grup)
}

/// Lista actelor (se redesenează singură la căutare)
func acteRezultate(_ c: Control, _ ed: Editor) -> (ModelNotaCautare?, ModelGrupActe) {
    let f = ed.ui.nerFilter
    let q = ed.ui.nerQuery.trimJS
    let toate = acteOf(c).enumerated().map { (a: $1, i: $0, v: c.act($1.key)) }
    let vis = toate.filter { x in (f == "ALL" || (f == "NOK" ? x.v.status == "nok" : x.v.status.isEmpty)) && matchAct(c, x.a.key, q) }
    let closed = q.isEmpty && ed.ui.catCollapsed.are("acte")
    let gol = toate.filter { $0.v.status.isEmpty }
    let lipsa = toate.filter { $0.v.status == "nok" }
    func nr(_ l: [(a: ActSablon, i: Int, v: Act)]) -> String {
        l.count > 8 ? "\(l.prefix(8).map { "\($0.i + 1)" }.joined(separator: ", ")) +\(l.count - 8)" : l.map { "\($0.i + 1)" }.joined(separator: ", ")
    }
    var nota: ModelNotaCautare?
    if !q.isEmpty {
        nota = ModelNotaCautare(gasite: vis.count,
                                text: vis.isEmpty ? "Niciun act pentru „\(q)”" : "\(vis.count) \(vis.count == 1 ? "act găsit" : "acte găsite") pentru „\(q)”",
                                cautaInToate: f != "ALL", ascunse: nil)
    }
    var info: [ModelInfoCategorie] = []
    if !gol.isEmpty {
        info.append(ModelInfoCategorie(tip: "st-rest", text: closed ? "\(gol.count) \(gol.count == 1 ? "necompletat" : "necompletate"): \(nr(gol))" : "\(gol.count) necompl."))
    } else { info.append(ModelInfoCategorie(tip: "st-gata", text: "Completat")) }
    if !lipsa.isEmpty { info.append(ModelInfoCategorie(tip: "count", text: closed ? "\(lipsa.count) lipsă: \(nr(lipsa))" : "\(lipsa.count) lipsă")) }
    let randuri = closed ? [] : vis.map { modelRandAct(c, ed, $0.a, $0.i) }
    return (nota, ModelGrupActe(restrans: closed, dezactivat: !q.isEmpty, numar: "\(vis.count) \(vis.count == 1 ? "act" : "acte")", info: info, randuri: randuri))
}

func modelRandAct(_ c: Control, _ ed: Editor, _ a: ActSablon, _ i: Int) -> ModelRandAct {
    let v = c.act(a.key)
    let path = "acte.\(a.key)"
    let collapsed = ed.ui.rowCollapsed.are("\(c.id)|act:\(a.key)")
    var pastile: [PastilaUI] = []
    if collapsed {
        switch v.status {
        case "ok": pastile.append(PastilaUI("green", ACT_OK, "check"))
        case "nok": pastile.append(PastilaUI("red", ACT_NOK, "x"))
        case "nec": pastile.append(PastilaUI("neutral", "NEC", nil))
        default: pastile.append(PastilaUI("todo", "Necompletat", nil))
        }
        if !v.obs.trimJS.isEmpty { pastile.append(PastilaUI("neutral", "Are observații", "doc")) }
    }
    let obsGol = v.obs.trimJS.isEmpty && !ed.ui.obsOpen.contains(obsKey(c, "\(path).obs")) && v.status != "nok"
    return ModelRandAct(
        key: a.key, nr: i + 1, eticheta: a.label, stare: v.status, restrans: collapsed, pastile: pastile,
        obsInBara: obsGol && !collapsed ? ModelObs(cale: "\(path).obs", valoare: "", deschis: false) : nil,
        okNok: collapsed ? nil : ModelOkNok(cale: path, stare: v.status, ok: ACT_OK, nok: ACT_NOK, nec: true),
        obs: collapsed || obsGol ? nil : modelObs(c, ed, "\(path).obs", v.obs, deschis: v.status == "nok"))
}

// ───────── TABURI DE CONSTATĂRI: Nereguli, Planuri și SVSU, Protecție civilă ─────────

public struct TexteSectiune: Sendable {
    public let iconita: String, titlu: String, titluAdaugare: String, nokWord: String, gol: String
}

public let SEC_UI: [String: TexteSectiune] = [
    "ner": TexteSectiune(iconita: "alert", titlu: "Nereguli constatate", titluAdaugare: "Nereguli suplimentare", nokWord: "constatate", gol: "Adăugați nereguli care nu se află în lista standard."),
    "plan": TexteSectiune(iconita: "list", titlu: "Planuri și SVSU", titluAdaugare: "Rubrici suplimentare", nokWord: "neconforme", gol: "Adăugați rubrici care nu se află în lista standard."),
    "pc": TexteSectiune(iconita: "shield", titlu: "Protecție civilă", titluAdaugare: "Rubrici suplimentare", nokWord: "neconforme", gol: "Adăugați rubrici care nu se află în lista standard."),
]

public struct ModelTabSectiune: Equatable, Sendable {
    public let sec: String
    public let verificate: Int, total: Int, constatate: Int, inPV: Int, netrecute: Int, amenzi: Int
    public let nokWord: String
    /// „+3 rânduri ascunse (instalații fără DA) · Arată” / „Ascunde …”
    public let ascunse: String?
    /// „Termenele amenzilor și ASI pornesc după ce completați data încheierii (tabul Obiectiv).”
    public let notaTermene: Bool
    public let cautare: ModelCautare
    /// filtrele active (etichete ✕)
    public let etichete: [ModelEticheta]
    public let rest: String?
    public let rezultat: ModelNotaCautare?
    public let grupe: [ModelGrupNereguli]
    /// „Nimic de afișat pentru acest filtru.” / „Nicio potrivire…”
    public let gol: String?
    public let adaugate: ModelAdaugate
}

public struct ModelGrupNereguli: Equatable, Sendable {
    public let cat: String, titlu: String, restrans: Bool, dezactivat: Bool
    public let numar: String
    public let info: [ModelInfoCategorie]
    /// rândurile, cu rândul „Adăposturi de protecție civilă” (DA / NU / NEC) la locul lui
    public let randuri: [RandSectiune]
}

public enum RandSectiune: Equatable, Sendable {
    case neregula(ModelRandNeregula)
    case adapost(ModelRandAdapost)
}

/// „Nereguli suplimentare” / „Rubrici suplimentare”: rândurile adăugate de inspector
public struct ModelAdaugate: Equatable, Sendable {
    public let cat: String, titlu: String
    public let numar: String?
    public let info: [ModelInfoCategorie]
    public let restrans: Bool, dezactivat: Bool
    public let randuri: [ModelRandNeregula]
    public let gol: String?
}

/// Rândurile unei secțiuni, grupate pe categorii, cu filtrul și căutarea aplicate
struct RanduriSectiune {
    let f: String, q: String
    let groups: [(cat: String, rows: [Neregula])]
    let custom: [Neregula]
    let show: (Neregula) -> Bool
    let ascunse: Int
}

func sectionRows(_ c: Control, _ ed: Editor, _ sec: String) -> RanduriSectiune {
    let f = ed.ui.nerFilter
    let q = ed.ui.nerQuery.trimJS
    let showAll = ed.ui.showAllNer
    let rows = c.nereguli.filter { secOf($0) == sec }
    let tmpl = rows.filter { !$0.custom && (isApplicable(c, $0) || (showAll && ascunsaDeDotari(c, $0))) }
    let custom = rows.filter { $0.custom && !$0.adapost }
    let adp = rows.filter { $0.adapost && isApplicable(c, $0) }
    let kId = ed.constrFiltruNer(c)
    let okStare = { (n: Neregula) in f == "ALL" || (f == "NOK" ? n.status == "nok" : f == "PV" ? n.status == "nok" && !n.inPV : n.status.isEmpty) }
    let show = { (n: Neregula) in okStare(n) && inConstructie(c, n, kId) && matchNeregula(c, n, q) }
    var groups: [(cat: String, rows: [Neregula])] = []
    for n in tmpl {
        let cat = neregulaCat(n)
        if let i = groups.firstIndex(where: { $0.cat == cat }) { groups[i].rows.append(n) } else { groups.append((cat, [n])) }
    }
    // adăposturile: la Localitate lângă rubrica „Adăposturi” (Dotare și adăpost); la OPEC, grup propriu în Nereguli
    if !adp.isEmpty {
        if let i = groups.firstIndex(where: { $0.cat == (sec == "pc" ? "pcdotare" : "adapost") }) { groups[i].rows += adp }
        else { groups.append(("adapost", adp)) }
    }
    // rânduri care s-ar potrivi, dar sunt ascunse (instalații nebifate DA la dotări)
    let ascunse = !q.isEmpty && !showAll ? rows.filter { ascunsaDeDotari(c, $0) && matchNeregula(c, $0, q) }.count : 0
    return RanduriSectiune(f: f, q: q, groups: groups, custom: custom, show: show, ascunse: ascunse)
}

/// Literele rândurilor, scurtat la multe: „b2, c1, e +3”
func litere(_ c: Control, _ rows: [Neregula], max: Int = 6) -> String {
    let l = rows.map { neregulaLetter(c, $0) }
    return l.count > max ? "\(l.prefix(max).joined(separator: ", ")) +\(l.count - max)" : l.joined(separator: ", ")
}

/// Bara unei categorii: completat / necompletat (care), constatate, amendate (care) — vizibile și restrânsă
func catInfo(_ c: Control, _ rows: [Neregula], _ sec: String, adapostGol: Bool = false, scurt: Bool = false) -> [ModelInfoCategorie] {
    let gol = rows.filter { $0.status.isEmpty }
    let rest = gol.count + (adapostGol ? 1 : 0)
    let nok = rows.filter { $0.status == "nok" }
    let netrec = nok.filter { !$0.inPV }
    let amend = nok.filter { $0.amenda.aplicata }
    let sigil = nok.filter { isGrav($0) && $0.sigiliu }
    let lit = [litere(c, gol), adapostGol ? "adăpost" : ""].filter { !$0.isEmpty }.joined(separator: ", ")
    let tNec = "\(rest) \(rest == 1 ? "necompletată" : "necompletate")"
    let tNok = "\(nok.count) \(nokWord(sec, nok.count))"
    let tPv = "\(netrec.count) \(netrec.count == 1 ? "netrecută" : "netrecute") în PV"
    let tAm = "\(amend.count) \(amend.count == 1 ? "amendată" : "amendate")"
    let tSig = "\(sigil.count) \(sigil.count == 1 ? "criteriu" : "criterii") de sigilare"
    var l: [ModelInfoCategorie] = []
    l.append(rest > 0 ? ModelInfoCategorie(tip: "st-rest", text: scurt ? tNec : "\(tNec): \(lit)") : ModelInfoCategorie(tip: "st-gata", text: "Completat"))
    if !nok.isEmpty {
        l.append(ModelInfoCategorie(tip: "count", text: tNok))
        l.append(netrec.isEmpty ? ModelInfoCategorie(tip: "pv-gata", text: "toate în PV")
                 : ModelInfoCategorie(tip: "pv-rest", text: scurt ? tPv : "\(tPv): \(litere(c, netrec))"))
    }
    if !amend.isEmpty { l.append(ModelInfoCategorie(tip: "amenzi", text: scurt ? tAm : "\(tAm): \(litere(c, amend))")) }
    if !sigil.isEmpty { l.append(ModelInfoCategorie(tip: "sigiliu", text: scurt ? tSig : "\(tSig): \(litere(c, sigil))")) }
    return l
}

public func modelTabSectiune(_ c: Control, _ controls: [Control], _ ed: Editor, _ sec: String, azi: String) -> ModelTabSectiune {
    let ui = SEC_UI[sec] ?? SEC_UI["ner"]!
    let st = secStats(c, sec, azi)
    let sr = sectionRows(c, ed, sec)
    let showAll = ed.ui.showAllNer
    let anyFineOrAsi = !st.fines.isEmpty || (sec == "ner" && asiDeadline(c, azi) != nil)
    let rest = c.nereguli.filter { secOf($0) == sec && $0.status.isEmpty && !(sablon($0.key)?.grav ?? false)
        && (isApplicable(c, $0) || (showAll && ascunsaDeDotari(c, $0))) }.count
    let allClosed = !sr.groups.isEmpty && sr.groups.allSatisfy { ed.ui.catCollapsed.are($0.cat) }
    var ascunse: String?
    if sec == "ner" && st.hidden > 0 {
        ascunse = showAll ? "Ascunde \(st.hidden == 1 ? "rândul" : "cele \(st.hidden) rânduri") (instalații fără DA)"
            : "+\(st.hidden) \(st.hidden == 1 ? "rând ascuns (instalație fără DA)" : "rânduri ascunse (instalații fără DA)") · Arată"
    }
    var meniu = [ButonMeniu(act: "cats-all", date: ["val": allClosed ? "open" : "close"], text: allClosed ? "Extinde categoriile" : "Restrânge categoriile", iconita: allClosed ? "chevD" : "list")]
    if let b = rowsBtn(c, ed, sec) { meniu.append(b) }
    let nokCap = ui.nokWord.prefix(1).uppercased() + ui.nokWord.dropFirst()
    let f = ed.ui.nerFilter
    let rez = nerRezultate(c, controls, ed, sec, sr, azi: azi)
    // filtrele de stare (v1.26: și „Netrecute în PV”)
    let stare = [("ALL", "Toate"), ("NOK", "\(nokCap) (\(st.constatate))"), ("PV", "Netrecute în PV (\(st.netrecute))"),
                 ("TODO", "Neverificate (\(st.total - st.checked))")].map { ModelFiltru(key: $0.0, text: $0.1, activ: f == $0.0) }
    return ModelTabSectiune(
        sec: sec, verificate: st.checked, total: st.total, constatate: st.constatate, inPV: st.constatate - st.netrecute,
        netrecute: st.netrecute, amenzi: st.fines.count, nokWord: ui.nokWord, ascunse: ascunse,
        notaTermene: !isIncheiat(c) && anyFineOrAsi,
        cautare: ModelCautare(sec: sec, valoare: ed.ui.nerQuery, indiciu: "Caută: literă (d, G1) sau text (ex. hidranți, gaz)", meniuDeschis: ed.ui.toolsOpen,
                              active: (f != "ALL" ? 1 : 0) + (ed.constrFiltruNer(c).isEmpty ? 0 : 1), stare: stare, constructii: filtruConstructii(c, ed), meniu: meniu),
        etichete: eticheteActive(c, ed, sec, stare),
        rest: rest > 0 ? "\(sec == "ner" ? "Restul conform" : "Restul conforme") (\(rest))" : nil,
        rezultat: rez.nota, grupe: rez.grupe, gol: rez.gol, adaugate: rez.adaugate)
}

/// „Restrânge completate (N)” sau, dacă nu mai e nimic de restrâns, „Deschide rândurile”
func rowsBtn(_ c: Control, _ ed: Editor, _ sec: String) -> ButonMeniu? {
    let rows = c.nereguli.filter { secOf($0) == sec && isApplicable(c, $0) }
    let deschiseGata = rows.filter { !$0.status.isEmpty && !ed.ui.rowCollapsed.are(rowKey(c, $0)) }.count
    if deschiseGata > 0 { return ButonMeniu(act: "rows-collapse", date: ["sec": sec], text: "Restrânge completate (\(deschiseGata))", iconita: "list") }
    if rows.contains(where: { ed.ui.rowCollapsed.are(rowKey(c, $0)) }) { return ButonMeniu(act: "rows-expand", date: ["sec": sec], text: "Deschide rândurile", iconita: "chevD") }
    return nil
}

/// Lista de rânduri (se redesenează la căutare)
func nerRezultate(_ c: Control, _ controls: [Control], _ ed: Editor, _ sec: String, _ sr: RanduriSectiune, azi: String)
    -> (nota: ModelNotaCautare?, grupe: [ModelGrupNereguli], gol: String?, adaugate: ModelAdaugate) {
    let ui = SEC_UI[sec] ?? SEC_UI["ner"]!
    let (f, q) = (sr.f, sr.q)
    let adapostHit = q.isEmpty || (q.lungimeJS >= 3 && fold("adapost de protectie civila").contains(fold(q)))
    var found = 0
    var grupe: [ModelGrupNereguli] = []
    for g in sr.groups {
        let vis = g.rows.filter(sr.show)
        let cuAdapost = sec == "pc" && g.cat == "pcdotare" && adapostHit && (f == "ALL" || (f == "TODO" && c.adapostPC.v.isEmpty))
        if vis.isEmpty && !cuAdapost { continue }
        found += vis.count + (cuAdapost ? 1 : 0)
        let closed = q.isEmpty && ed.ui.catCollapsed.are(g.cat)
        let nRows = vis.count + (cuAdapost ? 1 : 0)
        var randuri: [RandSectiune] = []
        if !closed {
            randuri = vis.filter { !$0.adapost }.map { .neregula(modelRandNeregula(c, controls, ed, $0, azi: azi)) }
            if cuAdapost { randuri.append(.adapost(modelRandAdapost(c, ed))) }
            randuri += vis.filter(\.adapost).map { .neregula(modelRandNeregula(c, controls, ed, $0, azi: azi)) }
        }
        grupe.append(ModelGrupNereguli(
            cat: g.cat, titlu: K.categorie(g.cat) ?? "", restrans: closed, dezactivat: !q.isEmpty,
            numar: "\(nRows) \(nRows == 1 ? "rând" : "rânduri")",
            info: catInfo(c, g.rows, sec, adapostGol: sec == "pc" && g.cat == "pcdotare" && c.adapostPC.v.isEmpty, scurt: !closed),
            randuri: randuri))
    }
    let customVis = sr.custom.filter(sr.show)
    found += customVis.count
    let fName = f == "NOK" ? "„\(ui.nokWord)”" : f == "PV" ? "„Netrecute în PV”" : "„Neverificate”"
    var gol: String?
    if grupe.isEmpty {
        gol = !q.isEmpty
            ? "Nicio potrivire\(customVis.isEmpty ? "" : " în listă (vezi rândurile adăugate, mai jos)")\(f != "ALL" ? " în filtrul \(fName)" : "")."
            : "Nimic de afișat pentru acest filtru."
    }
    var nota: ModelNotaCautare?
    if !q.isEmpty {
        let t = found > 0 ? "\(found) \(found == 1 ? "rând găsit" : "rânduri găsite") pentru „\(q)”" : "Niciun rând pentru „\(q)”"
        nota = ModelNotaCautare(gasite: found, text: t + (f != "ALL" ? " · filtrul \(fName)" : ""), cautaInToate: f != "ALL",
                                ascunse: sr.ascunse > 0 ? "+\(sr.ascunse) \(sr.ascunse == 1 ? "ascunsă" : "ascunse") · Arată toate" : nil)
    }
    let ck = "custom-\(sec)"
    let custom = sr.custom
    let closed = q.isEmpty && !custom.isEmpty && ed.ui.catCollapsed.are(ck)
    let adaugate = ModelAdaugate(
        cat: ck, titlu: ui.titluAdaugare,
        numar: custom.isEmpty ? nil : "\(custom.count) \(custom.count == 1 ? "rând" : "rânduri")",
        info: custom.isEmpty ? [] : catInfo(c, custom, sec, scurt: !closed),
        restrans: closed, dezactivat: custom.isEmpty || !q.isEmpty,
        randuri: closed ? [] : customVis.map { modelRandNeregula(c, controls, ed, $0, azi: azi) },
        gol: closed || !customVis.isEmpty ? nil : (!q.isEmpty && !custom.isEmpty ? "Niciun rând adăugat nu se potrivește căutării." : ui.gol))
    return (nota, grupe, gol, adaugate)
}

/// Cheile butoanelor de categorie din corpul tabului curent („Restrânge / Extinde categoriile”)
public func categoriiPeEcran(_ m: ModelEditor) -> [String] {
    switch m.corp {
    case .obiectiv: return []
    case .acte: return ["acte"]
    case .sectiune(let s): return s.grupe.map(\.cat) + [s.adaugate.cat]
    }
}

// ───────── rândul unei nereguli ─────────

public struct ModelRandNeregula: Equatable, Sendable {
    public let key: String, litera: String, sec: String, stare: String
    public let restrans: Bool
    public let veche: Bool, gravAdaugat: Bool
    /// eticheta: text (șablon), câmp (rând adăugat) sau „Adăpost de protecție civilă” + locația
    public let eticheta: String
    public let campEticheta: ModelCamp?
    public let adapost: Bool
    public let pastile: [PastilaUI]
    /// „+ Obs.” în bara rândului (rând fără corp)
    public let obsInBara: ModelObs?
    public let okNok: ModelOkNok?
    public let corp: ModelCorpNeregula?
    public let detaliu: ModelDetaliuNeregula?
}

public struct ModelCorpNeregula: Equatable, Sendable {
    public let verificare: ModelVerificare?
    public let constrNU: String?
    public let constrSelect: ModelConstrSelect?
    public let obs: ModelObs
    public let stergere: Bool
}

public struct ModelVerificare: Equatable, Sendable {
    public let key: String, titlu: String
    public let randuri: [Rand]
    /// fără rânduri: „Nicio centrală termică: „NU ARE” la toate construcțiile (tabul Obiectiv).”
    public let gol: String?
    /// „Verificare expirată: X. Constatați neregula?” + butonul
    public let propunere: (text: String, buton: String)?

    public struct Rand: Equatable, Sendable {
        public let id: String, nume: String, data: String, expirata: Bool
        public let alegeri: [Int]?
        public let luni: Int
        /// „lipsa” | „expirata” | „valabila”
        public let stare: String
        public let text: String
        /// de la al doilea rând: „Aceeași dată ca la …” (activ = aceeași dată și periodicitate)
        public let caPrima: CaPrima?
    }
    public struct CaPrima: Equatable, Sendable { public let activ: Bool, text: String }
    public static func == (a: Self, b: Self) -> Bool {
        a.key == b.key && a.titlu == b.titlu && a.randuri == b.randuri && a.gol == b.gol
            && a.propunere?.text == b.propunere?.text && a.propunere?.buton == b.propunere?.buton
    }
}

public struct ModelConstrSelect: Equatable, Sendable {
    public let key: String, eticheta: String, valoare: String
    public let multe: Bool, deschis: Bool
    public let optiuni: [Optiune]
    public let nota: String?
    public let toate: Bool

    public struct Optiune: Equatable, Sendable {
        public let id: String, text: String, ales: Bool
        /// la rândurile pe centrală termică (v1.25), în construcțiile alese cu mai multe centrale: CT 1, CT 2…
        public var centrale: [OptiuneCT] = []
    }
    public struct OptiuneCT: Equatable, Sendable { public let id: String, text: String, ales: Bool }
}

public struct ModelDetaliuNeregula: Equatable, Sendable {
    public let inPV: ModelComutator, amenda: ModelComutator
    /// nota „Neregulă veche — constatată și la controlul din …” (din istoric) sau comutatorul manual
    public let vecheNota: String?
    public let vecheManual: ModelComutator?
    public let grav: ModelComutator?
    public let sigiliu: ModelComutator?
    public let asi: ModelASI?
    public let amendaBox: ModelAmenda?
    /// fotografiile constatării (adăugire nativă)
    public var fotografii: [Fotografie] = []
}

public struct ModelASI: Equatable, Sendable {
    public let termen: ModelComutator
    public let prezentat: ModelComutator?
    public let pierdere: ModelComutator?
    public let stare: ModelTermen?
    public let dataPierdere: ModelCamp?
    public let dataPrezentare: ModelCamp?
}

public struct ModelAmenda: Equatable, Sendable {
    public let key: String, nivel: String, titlu: String, mesaj: String
    public let data: ModelCamp
    /// „Folosește data încheierii” (buton) sau „Implicit: data încheierii (…)”
    public let dataImplicita: String?
    public let folosesteIncheierea: Bool
    public let suma: ModelCamp
    public let achitata: ModelComutator
    public let dataAchitare: ModelCamp?
    public let plata: Etapa?, anaf: Etapa?
    public let nelucr: String?

    public struct Etapa: Equatable, Sendable {
        /// „cur” | „past” | „”
        public let stare: String
        public let text: String, data: String
        public let nelucr: String?
    }
}

/// Pastilele din bara unei nereguli: aceleași mesaje și avertismente, și când rândul e restrâns
func rowPills(_ c: Control, _ controls: [Control], _ n: Neregula, _ collapsed: Bool, _ vi: InfoVeche, azi: String) -> [PastilaUI] {
    let sec = K.sectiune(secOf(n))
    var p: [PastilaUI] = []
    if collapsed {
        switch n.status {
        case "ok": p.append(PastilaUI("green", sec.ok, "check"))
        case "nok": p.append(PastilaUI("red", n.adapost ? "Neconform" : sec.nok, "x"))
        case "nec": p.append(PastilaUI("neutral", "NEC", nil))
        default: p.append(PastilaUI("todo", "Necompletat", nil))
        }
    }
    if vi.veche { p.append(PastilaUI("veche", "Neregulă veche", "history")) }
    if n.status == "nok" && isGrav(n) && n.sigiliu { p.append(PastilaUI("red", "Sigiliu", "lock")) }
    if n.status == "nok" && n.custom && n.grav { p.append(PastilaUI("red", "Neregulă gravă", "alert")) }
    if n.status == "nok" && n.auto {
        if sablon(n.key)?.autoActe != nil {
            p.append(PastilaUI("neutral", "Din tabul Acte: act lipsă", "doc"))
        } else {
            let dot = sablon(n.key)?.autoNU
            p.append(PastilaUI("neutral", "Din fișa obiectivului: NU la \(K.dotari.first { $0.key == dot }?.label ?? "")", "building"))
        }
    }
    if n.status == "nok" {
        p.append(n.inPV ? PastilaUI("green", "Trecut în PV", "pv") : PastilaUI("warn", "Netrecut în PV", "pv"))
        if n.amenda.aplicata {
            let fs = fineStatus(c, n, azi)
            p.append(PastilaUI("fs-\(fs.level)", "Amendă · \(fs.label)", "fine"))
        }
        if collapsed && c.constructii.count > 1 && secOf(n) == "ner" && !constructiiOf(c, n).isEmpty { p.append(PastilaUI("neutral", constructiiNume(c, n), "building")) }
    }
    let exp = n.status != "nok" && n.status != "nec" ? verifExpirate(c, n) : []
    if !exp.isEmpty { p.append(PastilaUI("warn", "Verificare expirată: \(exp.map(\.denumire).joined(separator: ", "))", "alert")) }
    if !vi.veche && n.status != "nok", let a = vi.auto { p.append(PastilaUI("neutral", "Constatată la controlul din \(fmtDate(a.dataInceput))", "history")) }
    var fara = n
    fara.status = ""
    if !n.custom && !isApplicable(c, fara) {
        let t = sablon(n.key)
        p.append(PastilaUI("neutral", t?.reqNU != nil ? "Nu mai e marcată NU la dotări" : (t?.reqGrfV ?? false) ? "Nu mai e GRF/NSI V peste parter" : "Instalație nebifată DA la dotări", "info"))
    }
    return p
}

public func modelRandNeregula(_ c: Control, _ controls: [Control], _ ed: Editor, _ n: Neregula, azi: String) -> ModelRandNeregula {
    let path = "nereguli.@\(n.key)"
    let letter = neregulaLetter(c, n)
    let sec = K.sectiune(secOf(n))
    let collapsed = ed.ui.rowCollapsed.are(rowKey(c, n))
    let vi = vecheInfo(controls, c, n)
    let t = sablon(n.key)
    var campEticheta: ModelCamp?
    if n.adapost {
        campEticheta = ModelCamp(eticheta: "Adăpost de protecție civilă", cale: "\(path).locatie", valoare: n.locatie, indiciu: "Locația adăpostului (ex.: subsol bloc A2)")
    } else if n.custom {
        campEticheta = ModelCamp(eticheta: "", cale: "\(path).label", valoare: n.label, indiciu: "Descrieți \(secOf(n) == "ner" ? "neregula" : "rubrica")…")
    }
    let verif = isVerificare(n) && n.status != "nec" ? modelVerificare(c, n) : nil
    var constrNU: String?
    var constrSel: ModelConstrSelect?
    if !n.adapost {
        if let t, t.grav { constrNU = textConstrNU(c, t) }
        else if (n.sec == "ner" || n.sec.isEmpty) && n.status != "nec" { constrSel = modelConstrSelect(c, ed, n) }
    }
    let obsGol = n.obs.trimJS.isEmpty && !ed.ui.obsOpen.contains(obsKey(c, "\(path).obs")) && n.status != "nok"
    let faraCorp = verif == nil && constrNU == nil && constrSel == nil && obsGol && !n.custom && n.status != "nok"
    let obsInBara = faraCorp && !collapsed ? ModelObs(cale: "\(path).obs", valoare: "", deschis: false) : nil
    let okNok: ModelOkNok? = collapsed ? nil : n.adapost
        ? ModelOkNok(cale: path, stare: n.status, ok: "Conform", nok: "Neconform", nec: false)
        : ModelOkNok(cale: path, stare: n.status, ok: sec.ok, nok: sec.nok, nec: !(t?.grav ?? false) || n.custom)
    var corp: ModelCorpNeregula?
    var detaliu: ModelDetaliuNeregula?
    if !collapsed && !faraCorp {
        corp = ModelCorpNeregula(verificare: verif, constrNU: constrNU, constrSelect: constrSel,
                                 obs: modelObs(c, ed, "\(path).obs", n.obs, deschis: n.status == "nok"), stergere: n.custom)
        if n.status == "nok" { detaliu = modelDetaliu(c, n, path, vi, azi: azi) }
    }
    let pills = rowPills(c, controls, n, collapsed, vi, azi: azi)
    return ModelRandNeregula(
        key: n.key, litera: letter, sec: secOf(n), stare: n.status, restrans: collapsed,
        veche: vi.veche && n.status != "nec", gravAdaugat: n.custom && n.grav,
        eticheta: n.adapost ? "Adăpost de protecție civilă" : neregulaLabel(n), campEticheta: campEticheta, adapost: n.adapost,
        pastile: pills, obsInBara: obsInBara, okNok: okNok, corp: corp, detaliu: detaliu)
}

/// Neregulile grave: construcțiile care le declanșează (NU la dotare / GRF-NSI V peste parter)
func textConstrNU(_ c: Control, _ t: RandSablon) -> String? {
    let list = constructiiDeclansate(c, t) ?? []
    if list.isEmpty { return nil }
    let cum = t.reqGrfV ? "GRF/NSI V peste parter în" : "NU la dotări în"
    return "\(cum): \(list.map { $0.denumire + (t.reqGrfV && !$0.regimInaltime.isEmpty ? " (\($0.regimInaltime))" : "") }.joined(separator: ", "))"
}

/// Data ultimei verificări, pe fiecare construcție relevantă (la verificarea CT: pe fiecare centrală); expirarea se
/// calculează față de data controlului. De la al doilea rând: „Aceeași dată ca la …” copiază data rândului de referință
/// (CT 2… → CT 1 al construcției lor; restul → primul rând).
func modelVerificare(_ c: Control, _ n: Neregula) -> ModelVerificare {
    let t = sablon(n.key)
    let exp = verifExpirate(c, n)
    let list = verifUnitati(c, n)
    let randuri = list.map { u -> ModelVerificare.Rand in
        let s = verifStare(c, n, u)
        let text = s.stare == "lipsa" ? "fără dată" : s.stare == "expirata" ? "expirată — era valabilă până la \(fmtDate(s.expira ?? ""))" : "valabilă până la \(fmtDate(s.expira ?? ""))"
        var ca: ModelVerificare.CaPrima?
        if let ref = verifReferinta(list, u) {
            let prima = verifStare(c, n, ref)
            if !prima.data.isEmpty { ca = .init(activ: s.data == prima.data && s.luni == prima.luni, text: "Aceeași dată ca la \(ref.denumire)") }
        }
        return .init(id: u.id, nume: u.denumire, data: s.data, expirata: s.stare == "expirata",
                     alegeri: t?.verifAlegeri, luni: s.luni, stare: s.stare, text: text, caPrima: ca)
    }
    return ModelVerificare(
        key: n.key, titlu: "Data ultimei verificări\(t?.verifAlegeri != nil ? "" : " · valabilă \(t?.verif ?? 0) luni")", randuri: randuri,
        gol: randuri.isEmpty ? "Nicio centrală termică: „NU ARE” la toate construcțiile (tabul Obiectiv)." : nil,
        propunere: !exp.isEmpty && n.status != "nok"
            ? ("Verificare expirată: \(exp.map(\.denumire).joined(separator: ", ")). Constatați neregula?", "Constatat pentru \(exp.count == 1 ? "aceasta" : "cele \(exp.count)")")
            : nil)
}

/// „hidranți interiori”, „centrală termică” … — instalația de care ține un rând
func instalatiaText(_ n: Neregula) -> String {
    (sablon(n.key)?.req ?? []).map { r in (K.dotari.first { $0.key == r }?.label ?? r).lowercased() }.joined(separator: " / ")
}

/// Construcțiile în care s-a făcut constatarea: meniu cu selecție multiplă (implicit prima construcție)
func modelConstrSelect(_ c: Control, _ ed: Editor, _ n: Neregula) -> ModelConstrSelect? {
    let sel = constructiiOf(c, n)
    if sel.isEmpty { return nil }
    let elig = constructiiEligibile(c, n)
    // la rândurile pe centrală termică (v1.25): în construcțiile alese cu mai multe centrale se pot alege centralele
    let peCT = perCT(c, n)
    let multe = elig.count > 1 || sel.count > 1 || (peCT && sel.contains { centraleOf($0).count > 1 })
    let open = multe && ed.ui.constrPick == n.key
    let ids = Set(sel.map(\.id))
    let ctAles = Set(centraleAlese(c, n).map(\.id))
    let eligIds = Set(elig.map(\.id))
    let opts = c.constructii.enumerated().filter { eligIds.contains($1.id) || ids.contains($1.id) }
    func cts(_ k: Constructie) -> [ModelConstrSelect.OptiuneCT] {
        guard peCT, ids.contains(k.id), centraleOf(k).count > 1 else { return [] }
        return unitatiCT(c, k).map { .init(id: $0.id, text: "CT \($0.nr)", ales: ctAles.contains($0.id)) }
    }
    return ModelConstrSelect(
        key: n.key, eticheta: sel.count > 1 ? "Construcțiile (\(sel.count))" : "Construcția", valoare: constructiiNume(c, n),
        multe: multe, deschis: open,
        optiuni: open ? opts.map { i, k in
            .init(id: k.id, text: "\(i + 1). \(k.denumire.isEmpty ? "Construcția \(i + 1)" : k.denumire)", ales: ids.contains(k.id), centrale: cts(k))
        } : [],
        nota: open && opts.count < c.constructii.count ? "Doar construcțiile cu \(instalatiaText(n)) bifat DA în fișă." : nil,
        toate: opts.allSatisfy { ids.contains($0.element.id) })
}

func modelDetaliu(_ c: Control, _ n: Neregula, _ path: String, _ vi: InfoVeche, azi: String) -> ModelDetaliuNeregula {
    let a = n.amenda
    var asi: ModelASI?
    if n.key == "a" && !n.custom && secOf(n) == "ner" {
        let d = asiDeadline(c, azi)
        var stare: ModelTermen?
        if n.asiTermen, let d {
            let resolved = d.resolved ?? false, pending = d.pending ?? false
            let titlu = resolved ? "Rezolvat" : pending ? "Termen neînceput"
                : d.faza == "pierdere" ? "Constatarea pierderii valabilității: până la \(fmtDateLong(d.termenPierdere ?? ""))" : "Termen: \(fmtDateLong(d.deadline ?? ""))"
            stare = ModelTermen(nivel: resolved ? "dl-green" : "dl-red", iconita: resolved ? "check" : "hourglass", titlu: titlu, mesaj: d.msg,
                                nelucr: d.nelucr.flatMap { $0.isEmpty ? nil : $0 },
                                numaratoare: !pending && !resolved ? cdBox(d.daysLeft ?? 0) : nil)
        }
        asi = ModelASI(
            termen: comutator("\(path).asiTermen", n.asiTermen, "Termen de prezentare 90 de zile", nivel: "red", iconita: "hourglass"),
            prezentat: n.asiTermen ? comutator("\(path).asiPrezentat", n.asiPrezentat, "Documentație prezentată", nivel: "green") : nil,
            pierdere: n.asiTermen && !n.asiPrezentat && (d?.faza == "pierdere" || n.asiPierdere)
                ? comutator("\(path).asiPierdere", n.asiPierdere, "Pierderea valabilității constatată", nivel: "green") : nil,
            stare: stare,
            dataPierdere: n.asiTermen && n.asiPierdere && !n.asiPrezentat
                ? ModelCamp(eticheta: "Data constatării pierderii valabilității", cale: "\(path).asiDataPierdere", valoare: n.asiDataPierdere, indiciu: "", tip: .data) : nil,
            dataPrezentare: n.asiTermen && n.asiPrezentat
                ? ModelCamp(eticheta: "Data prezentării", cale: "\(path).asiDataPrezentare", valoare: n.asiDataPrezentare, indiciu: "", tip: .data) : nil)
    }
    var box: ModelAmenda?
    if a.aplicata {
        let fs = fineStatus(c, n, azi)
        let fd = fineDate(c, n)
        var plata: ModelAmenda.Etapa?, anaf: ModelAmenda.Etapa?
        if let pp = fs.plataPana, !pp.isEmpty, !a.achitata {
            plata = .init(stare: fs.level == "blue" ? "cur" : "past", text: "Plată până la", data: fmtDate(pp),
                          nelucr: fs.plataNelucr.flatMap { $0.isEmpty ? nil : "(\($0) → \(fmtDate(nextWorkingDay(pp))))" })
            let ap = fs.anafPana ?? ""
            anaf = .init(stare: fs.level == "red" ? "cur" : "", text: "ANAF / Taxe și impozite până la", data: fmtDate(ap),
                         nelucr: fs.anafNelucr.flatMap { $0.isEmpty ? nil : "(\($0) → \(fmtDate(nextWorkingDay(ap))))" })
        }
        box = ModelAmenda(
            key: n.key, nivel: fs.level, titlu: fs.label, mesaj: fs.msg,
            data: ModelCamp(eticheta: "Data aplicării", cale: "\(path).amenda.data", valoare: a.data, indiciu: "", tip: .data),
            dataImplicita: a.data.isEmpty ? "Implicit: data încheierii\(fd.isEmpty ? " — necompletată" : " (\(fmtDate(fd)))")" : nil,
            folosesteIncheierea: !a.data.isEmpty,
            suma: ModelCamp(eticheta: "Sumă", cale: "\(path).amenda.suma", valoare: a.suma, indiciu: "0", unitate: "lei", tip: .zecimal),
            achitata: comutator("\(path).amenda.achitata", a.achitata, "Achitat / Executat silit", nivel: "green"),
            dataAchitare: a.achitata ? ModelCamp(eticheta: "Data achitării / executării", cale: "\(path).amenda.dataAchitare", valoare: a.dataAchitare, indiciu: "", tip: .data) : nil,
            plata: plata, anaf: anaf,
            nelucr: !a.achitata ? fs.nelucr.flatMap { $0.isEmpty ? nil : $0 } : nil)
    }
    return ModelDetaliuNeregula(
        inPV: comutator("\(path).inPV", n.inPV, "Trecut în procesul-verbal", nivel: "green", iconita: "pv", offLabel: "Netrecut în procesul-verbal"),
        amenda: comutator("\(path).amenda.aplicata", a.aplicata, "Sancționat cu amendă", nivel: "blue", iconita: "fine"),
        vecheNota: vi.auto.map { "Neregulă veche — constatată și la controlul din \(fmtDate($0.dataInceput)) (din istoric)" },
        vecheManual: vi.auto == nil ? comutator("\(path).vecheManual", n.vecheManual, "Neregulă veche", nivel: "veche", iconita: "history") : nil,
        grav: n.custom && !n.adapost ? comutator("\(path).grav", n.grav, "Neregulă gravă", nivel: "red", iconita: "alert") : nil,
        sigiliu: isGrav(n) ? comutator("\(path).sigiliu", n.sigiliu, "Sigiliu", nivel: "red", iconita: "lock") : nil,
        asi: asi, amendaBox: box, fotografii: n.fotografii)
}
