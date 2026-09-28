import Foundation

// Portarea din js/views.js: conținutul ecranelor de listă (rândul controlului, obiectivele, istoricul, filtrele,
// pagina obiectivului), ca modele fără interfață. Textele și ordinea lor sunt cele din web; testele le compară cu
// HTML-ul generat de codul web (verificarea încrucișată).

/// O pastilă: `pill(nivel, text, iconiță)` (tip = nivelul: red, warn, neutral, done, open, green, accent, veche)
/// sau `finePill(nivel, text)` (tip = „fs-<nivel>”, iconița amenzii)
public struct PastilaUI: Equatable, Sendable, Hashable {
    public let tip: String
    public let text: String
    public let iconita: String?
    public init(_ tip: String, _ text: String, _ iconita: String? = nil) { self.tip = tip; self.text = text; self.iconita = iconita }
    static func amenda(_ nivel: String, _ text: String) -> PastilaUI { PastilaUI("fs-\(nivel)", text, "fine") }
}

/// aceleași denumiri ca pastilele din Panou (fineStatus)
public let LEVEL_LABEL = ["blue": "În curs", "yellow": "Termen 15 zile expirat", "red": "Trimite la ANAF / Taxe și impozite", "green": "Achitată"]

/// `money(v)`: suma scrisă de inspector, în lei („2.500 lei”), sau "" dacă nu e o sumă
public func money(_ v: String) -> String { parseSuma(v).map(lei) ?? "" }

public func rangeText(_ c: Control) -> String {
    if !isIncheiat(c) { return "din \(fmtDate(c.dataInceput)) · în desfășurare" }
    if c.dataIncheiere == c.dataInceput { return fmtDate(c.dataInceput) }
    return "\(fmtDate(c.dataInceput)) – \(fmtDate(c.dataIncheiere))"
}

func statusPill(_ c: Control) -> PastilaUI {
    isIncheiat(c) ? PastilaUI("done", "Încheiat", "check") : PastilaUI("open", "În desfășurare", "clock")
}

/// Nereguli grave (șablon G sau rânduri adăugate marcate grave) care nu sunt conforme
public func graveCount(_ c: Control) -> Int {
    c.nereguli.filter { isGrav($0) && $0.status != "ok" && isApplicable(c, $0) }.count
}

/// `tipBadge(tip)`
public func textTip(_ tip: String) -> String { tip == "LOCALITATE" ? "Localitate" : "OPEC / Instituție" }

/// Adăposturile PC pe bară (roșu dacă e vreunul neconform)
func adpPill(_ a: StatAdaposturi, _ pre: String = "") -> PastilaUI {
    PastilaUI(a.neconforme > 0 ? "red" : a.total > 0 && a.neverificate == 0 ? "green" : "neutral", "\(pre)\(adaposturiText(a))", "shield")
}

// ───────── filtrele din Istoric și Obiective ─────────

public struct Filtru: Sendable {
    public let key: String, label: String, iconita: String, nivel: String
    /// în Obiective se verifică doar ultimul control (starea actuală); celelalte, la oricare control
    public let ultim: Bool
    let test: @Sendable (Control, StatControl) -> Bool
}

public let FILTRE: [Filtru] = [
    Filtru(key: "am-blue", label: "Amendă în curs", iconita: "fine", nivel: "blue", ultim: false) { _, st in st.fines.contains { $0.st.level == "blue" } },
    Filtru(key: "am-yellow", label: "Termen 15 zile expirat", iconita: "fine", nivel: "yellow", ultim: false) { _, st in st.fines.contains { $0.st.level == "yellow" } },
    Filtru(key: "am-red", label: "Trimite la ANAF / Taxe și impozite", iconita: "fine", nivel: "red", ultim: false) { _, st in st.fines.contains { $0.st.level == "red" } },
    Filtru(key: "am-green", label: "Amendă achitată", iconita: "fine", nivel: "green", ultim: false) { _, st in st.fines.contains { $0.st.level == "green" } },
    Filtru(key: "asi", label: "ASI în curs", iconita: "hourglass", nivel: "red", ultim: false) { _, st in st.asi.map { $0.resolved != true && $0.pending != true } ?? false },
    Filtru(key: "inc", label: "De încărcat", iconita: "upload", nivel: "warn", ultim: false) { _, st in st.incarcare.map { !$0.gata } ?? false },
    Filtru(key: "pv", label: "Netrecute în PV", iconita: "pv", nivel: "warn", ultim: false) { _, st in st.netrecute > 0 },
    Filtru(key: "grave", label: "Nereguli grave", iconita: "alert", nivel: "red", ultim: true) { c, _ in graveCount(c) > 0 },
    Filtru(key: "sigiliu", label: "Sigiliu aplicat", iconita: "lock", nivel: "red", ultim: true) { c, _ in sigiliiControl(c) != nil },
    Filtru(key: "adapost", label: "Adăposturi PC", iconita: "shield", nivel: "pc", ultim: true) { c, _ in adaposturiStats(c) != nil },
]
func filtru(_ k: String) -> Filtru? { FILTRE.first { $0.key == k } }

public func controlPotrivit(_ c: Control, _ keys: [String], _ t: String) -> Bool {
    let st = controlStats(c, t)
    return keys.allSatisfy { filtru($0)?.test(c, st) ?? true }
}

public func obiectivPotrivit(_ o: Obiectiv, _ keys: [String], _ t: String) -> Bool {
    keys.allSatisfy { k in
        guard let f = filtru(k) else { return true }
        return (f.ultim ? [o.last] : o.controls).contains { f.test($0, controlStats($0, t)) }
    }
}

public struct ButonFiltru: Equatable, Sendable {
    public let key: String, label: String, iconita: String, nivel: String
    public let activ: Bool
    /// câte rezultate ar fi cu filtrul adăugat (sau, activ, câte sunt acum)
    public let numar: Int
    public var dezactivat: Bool { numar == 0 && !activ }
}

/// Rândul de filtre; `active` în ordinea în care au fost alese
public func butoaneFiltre(_ active: [String], _ numara: ([String]) -> Int) -> [ButonFiltru] {
    let a = active.filter { filtru($0) != nil }
    return FILTRE.map { f in
        let on = a.contains(f.key)
        return ButonFiltru(key: f.key, label: f.label, iconita: on ? "check" : f.iconita, nivel: f.nivel, activ: on, numar: numara(on ? a : a + [f.key]))
    }
}

func textNumar(_ n: Int, _ unu: String, _ multe: String, _ flt: [String]) -> String {
    "\(n) \(n == 1 ? unu : multe)\(flt.isEmpty ? "" : " · filtre: \(flt.compactMap { filtru($0)?.label }.joined(separator: " + "))")"
}

// ───────── rândul controlului (Istoric, Calendar, pagina obiectivului) ─────────

public struct ModelRandControl: Equatable, Sendable {
    public let id: String
    public let zi: Int, lunaScurt: String, an: String
    public let deschis: Bool
    public let titlu: String?
    public let tip: String?
    public let perioada: String
    public let administrator: String?
    public let pastile: [PastilaUI]
}

public func modelRandControl(_ c: Control, _ controls: [Control], _ azi: String, arataNumele: Bool = true) -> ModelRandControl {
    let st = controlStats(c, azi)
    let p = c.dataInceput.split(separator: "-", omittingEmptySubsequences: false).map(String.init)
    var chips = [statusPill(c)]
    if st.constatate > 0 { chips.append(PastilaUI("neutral", "\(st.constatate) \(st.constatate == 1 ? "neregulă" : "nereguli")")) }
    if st.netrecute > 0 { chips.append(PastilaUI("warn", "\(st.netrecute) \(st.netrecute == 1 ? "netrecută" : "netrecute") în PV", "pv")) }
    let grave = graveCount(c)
    if grave > 0 { chips.insert(PastilaUI("red", "\(grave) \(grave == 1 ? "neregulă gravă" : "nereguli grave")", "alert"), at: 0) }
    if let sig = sigiliiControl(c) { chips.insert(PastilaUI("red", sigiliiText(sig), "lock"), at: grave > 0 ? 1 : 0) }
    let vechi = activeNereguli(c).filter { vecheInfo(controls, c, $0).veche }.count
    if vechi > 0 { chips.append(PastilaUI("veche", "\(vechi) \(vechi == 1 ? "neregulă veche" : "nereguli vechi")", "history")) }
    if let adp = adaposturiStats(c) { chips.append(adpPill(adp)) }
    var peNivel: [String: Int] = [:]
    for f in st.fines { peNivel[f.st.level, default: 0] += 1 }
    for lv in ["red", "yellow", "blue", "green"] {
        if let k = peNivel[lv], k > 0 {
            chips.append(.amenda(lv, "\(k) \(k == 1 ? "amendă" : "amenzi") · \(lv == "green" && k > 1 ? "Achitate" : LEVEL_LABEL[lv]!)"))
        }
    }
    if let a = st.asi, a.resolved != true {
        let z = a.daysLeft ?? 0
        let cand = z > 0 ? (z == 1 ? "mai este 1 zi" : "mai sunt \(zile(z))") : z == 0 ? (a.faza != nil ? "ultima zi azi" : "expiră azi") : "depășit cu \(zile(-z))"
        chips.append(PastilaUI("red", a.pending == true ? "ASI 90 de zile: neînceput" : a.faza == "pierdere" ? "ASI, constatarea pierderii valabilității: \(cand)" : "ASI: \(cand)", "hourglass"))
    }
    if let inc = st.incarcare {
        if inc.gata {
            chips.append(PastilaUI("green", "Încărcat în aplicație · document încărcat", "upload"))
        } else {
            let lv = inc.level ?? "warn"
            for k in inc.lipsa { chips.append(PastilaUI(lv, ucfirst(K.lipsaIncarcareText(k)), "upload")) }
            let d = inc.daysLeft ?? 0
            chips.append(PastilaUI(lv, d < 0 ? "Încărcare: termen depășit cu \(zile(-d))" : d == 0 ? "Încărcare: ultima zi azi"
                                   : "Încărcare: \(d == 1 ? "1 zi lucrătoare" : "\(d) zile lucrătoare")", "hourglass"))
        }
    }
    let luna = Int(p.count > 1 ? p[1] : "") ?? 1
    return ModelRandControl(
        id: c.id, zi: Int(p.count > 2 ? p[2] : "") ?? 0, lunaScurt: K.luniScurt[max(0, min(11, luna - 1))], an: p.first ?? "",
        deschis: !isIncheiat(c), titlu: arataNumele ? (c.denumire.isEmpty ? "Obiectiv fără denumire" : c.denumire) : nil,
        tip: arataNumele ? textTip(c.tip) : nil, perioada: rangeText(c),
        administrator: arataNumele && !c.administrator.isEmpty ? c.administrator : nil, pastile: chips)
}

// ───────── căutarea ─────────

/// `hintText(value)`: explicația de sub bara de căutare
public func hintText(_ value: String) -> String {
    let dq = parseDateQuery(value)
    if value.isEmpty { return "Scrieți numele obiectivului sau o dată: 12.09.2026, 09.2026 sau 2026." }
    guard let dq else { return "Caut după nume: „\(value)”" }
    switch dq {
    case .zi(let iso): return "Controale care includ ziua de \(fmtDateLong(iso))"
    case .luna(let an, let luna): return "Controale din \(K.luni[luna - 1]) \(an)"
    case .an(let an): return "Controale din anul \(an)"
    }
}

/// O stare goală (`empty(ic, titlu, text)`)
public struct Gol: Equatable, Sendable {
    public let iconita: String, titlu: String, text: String
    /// butonul „Control nou” (listele fără date)
    public let controlNou: Bool
    public init(iconita: String, titlu: String, text: String, controlNou: Bool) {
        self.iconita = iconita; self.titlu = titlu; self.text = text; self.controlNou = controlNou
    }
}

// ───────── Obiective ─────────

public struct ModelCardObiectiv: Equatable, Sendable {
    public let id: String
    public let initiale: String
    public let localitateTip: Bool
    public let titlu: String
    public let tip: String
    public let localitate: String?
    public let administrator: String?
    public let telefon: String?
    public let pastile: [PastilaUI]
}

public struct ModelListaObiective: Equatable, Sendable {
    public let filtre: [ButonFiltru]?
    public let arataStergeFiltrele: Bool
    public let numar: String?
    public let carduri: [ModelCardObiectiv]
    public let gol: Gol?
}

/// `objListHTML()`: obiectivele după căutare (`q`), tip ("ALL" / "OPEC" / "LOCALITATE") și filtre
public func modelListaObiective(_ controls: [Control], q: String, tip: String, filtre flt0: [String], azi t: String) -> ModelListaObiective {
    let dq = parseDateQuery(q)
    let baza = objectives(controls)
        .filter { tip == "ALL" || $0.tip == tip }
        .map { o in (o: o, hits: o.controls.filter { matchControl($0, q) }) }
        .filter { !$0.hits.isEmpty || (dq == nil && fold($0.o.denumire).contains(fold(q))) }
    let flt = flt0.filter { filtru($0) != nil }
    let list = baza.filter { obiectivPotrivit($0.o, flt, t) }
    if controls.isEmpty {
        return ModelListaObiective(filtre: nil, arataStergeFiltrele: false, numar: nil, carduri: [],
                                   gol: Gol(iconita: "building", titlu: "Niciun obiectiv încă", text: "Obiectivele apar aici după primul control.", controlNou: true))
    }
    let butoane = butoaneFiltre(flt0) { keys in baza.filter { obiectivPotrivit($0.o, keys, t) }.count }
    if list.isEmpty {
        return ModelListaObiective(filtre: butoane, arataStergeFiltrele: !flt.isEmpty, numar: nil, carduri: [],
                                   gol: Gol(iconita: "search", titlu: "Niciun rezultat", text: flt.isEmpty ? "Încercați alt nume sau altă dată." : "Niciun obiectiv nu îndeplinește toate filtrele alese.", controlNou: false))
    }
    let carduri = list.map { x -> ModelCardObiectiv in
        let o = x.o
        let open = o.controls.filter { !isIncheiat($0) }.count
        let deInc = o.controls.filter { incarcareStatus($0, t).map { !$0.gata } ?? false }.count
        let sts = o.controls.map { controlStats($0, t) }
        let peNivel = { (lv: String) in sts.reduce(0) { $0 + $1.fines.filter { $0.st.level == lv }.count } }
        let achitate = flt0.contains("am-green") ? peNivel("green") : 0
        let asi = sts.filter { filtru("asi")!.test(o.last, $0) }.count
        let netrec = sts.reduce(0) { $0 + $1.netrecute }
        let graveUlt = graveCount(o.last)
        let dateHit = dq != nil ? x.hits.first : nil
        let initiale = String((o.denumire.isEmpty ? "?" : o.denumire).trimJS.cuvinte.prefix(2).compactMap { $0.first.map(String.init) }.joined().uppercased())
        var ch: [PastilaUI] = [
            PastilaUI("neutral", "\(o.controls.count) \(o.controls.count == 1 ? "control" : "controale")", "history"),
            PastilaUI("neutral", "ultimul: \(fmtDate(o.last.dataInceput))", "calendar"),
        ]
        if let h = dateHit { ch.append(PastilaUI("accent", "găsit: \(rangeText(h))", "search")) }
        if let a = adaposturiStats(o.last) { ch.append(adpPill(a, "La ultimul control: ")) }
        if graveUlt > 0 { ch.append(PastilaUI("red", "La ultimul control: \(graveUlt) \(graveUlt == 1 ? "neregulă gravă" : "nereguli grave")", "alert")) }
        if let s = sigiliiControl(o.last) {
            let t = sigiliiText(s)
            ch.append(PastilaUI("red", "La ultimul control: \(t.hasPrefix("S") ? "s" + t.dropFirst() : t)", "lock"))
        }
        if open > 0 { ch.append(PastilaUI("open", "\(open) în desfășurare", "clock")) }
        if deInc > 0 { ch.append(PastilaUI("warn", "\(deInc) \(deInc == 1 ? "control neîncărcat" : "controale neîncărcate")", "upload")) }
        if asi > 0 { ch.append(PastilaUI("red", asi == 1 ? "ASI în curs" : "ASI în curs la \(asi) controale", "hourglass")) }
        if netrec > 0 { ch.append(PastilaUI("warn", "\(netrec) \(netrec == 1 ? "netrecută" : "netrecute") în PV", "pv")) }
        for lv in ["red", "yellow", "blue"] {
            let k = peNivel(lv)
            if k > 0 { ch.append(.amenda(lv, "\(k) \(k == 1 ? "amendă" : "amenzi") · \(LEVEL_LABEL[lv]!)")) }
        }
        if achitate > 0 { ch.append(.amenda("green", "\(achitate) \(achitate == 1 ? "amendă achitată" : "amenzi achitate")")) }
        return ModelCardObiectiv(
            id: o.id, initiale: initiale, localitateTip: o.tip == "LOCALITATE", titlu: o.denumire.isEmpty ? "Obiectiv fără denumire" : o.denumire,
            tip: textTip(o.tip), localitate: o.localitate.isEmpty ? nil : o.localitate,
            administrator: o.administrator.isEmpty ? nil : o.administrator, telefon: o.telefon.isEmpty ? nil : o.telefon, pastile: ch)
    }
    return ModelListaObiective(filtre: butoane, arataStergeFiltrele: !flt.isEmpty, numar: textNumar(list.count, "obiectiv", "obiective", flt),
                               carduri: carduri, gol: nil)
}

// ───────── Istoric ─────────

public struct GrupLuna: Equatable, Sendable {
    /// „octombrie 2026” (afișat cu majusculă, ca în web)
    public let titlu: String
    public let randuri: [ModelRandControl]
}

public struct ModelIstoric: Equatable, Sendable {
    public let filtre: [ButonFiltru]?
    public let arataStergeFiltrele: Bool
    public let numar: String?
    public let grupe: [GrupLuna]
    public let gol: Gol?
}

/// `histListHTML()`: `stare` = "ALL" | "OPEN" | "DONE"
public func modelIstoric(_ controls: [Control], q: String, stare: String, filtre flt0: [String], azi t: String) -> ModelIstoric {
    if controls.isEmpty {
        return ModelIstoric(filtre: nil, arataStergeFiltrele: false, numar: nil, grupe: [],
                            gol: Gol(iconita: "history", titlu: "Niciun control încă", text: "Istoricul se completează automat pe măsură ce lucrezi.", controlNou: true))
    }
    let baza = controls.filter { stare == "ALL" || (stare == "OPEN" ? !isIncheiat($0) : isIncheiat($0)) }.filter { matchControl($0, q) }
    let flt = flt0.filter { filtru($0) != nil }
    let list = baza.filter { controlPotrivit($0, flt, t) }.sortatStabil(byStartDesc)
    let butoane = butoaneFiltre(flt0) { keys in baza.filter { controlPotrivit($0, keys, t) }.count }
    if list.isEmpty {
        return ModelIstoric(filtre: butoane, arataStergeFiltrele: !flt.isEmpty, numar: nil, grupe: [],
                            gol: Gol(iconita: "search", titlu: "Niciun rezultat", text: flt.isEmpty ? "Încercați alt nume, altă dată sau alt filtru." : "Niciun control nu îndeplinește toate filtrele alese.", controlNou: false))
    }
    var ordine: [String] = []
    var grupe: [String: [Control]] = [:]
    for c in list {
        let k = String(c.dataInceput.prefix(7))
        if grupe[k] == nil { ordine.append(k); grupe[k] = [] }
        grupe[k]!.append(c)
    }
    return ModelIstoric(
        filtre: butoane, arataStergeFiltrele: !flt.isEmpty, numar: textNumar(list.count, "control", "controale", flt),
        grupe: ordine.map { k in
            let p = k.split(separator: "-").map(String.init)
            let luna = Int(p.count > 1 ? p[1] : "") ?? 1
            return GrupLuna(titlu: "\(K.luni[max(0, min(11, luna - 1))]) \(p.first ?? "")", randuri: grupe[k]!.map { modelRandControl($0, controls, t) })
        },
        gol: nil)
}

// ───────── pagina obiectivului ─────────

public struct GpsConstructie: Equatable, Sendable {
    public let nume: String
    public let coordonate: String?
    public let google: String?
    public let apple: String?
}

public struct ModelObiectiv: Equatable, Sendable {
    public let id: String
    public let tip: String
    public let titlu: String
    public let administrator: String, telefon: String?, email: String?, adresa: String
    public let constructii: Int
    public let gps: [GpsConstructie]
    public let statistici: [(Int, String)]
    public let istoric: [ModelRandControl]

    public static func == (a: ModelObiectiv, b: ModelObiectiv) -> Bool {
        a.id == b.id && a.titlu == b.titlu && a.istoric == b.istoric && a.statistici.map(\.0) == b.statistici.map(\.0) && a.statistici.map(\.1) == b.statistici.map(\.1)
    }
}

/// `viewObjective(oid)`; nil = obiectiv inexistent
public func modelObiectiv(_ controls: [Control], _ oid: String, azi t: String) -> ModelObiectiv? {
    guard let o = objectives(controls).first(where: { $0.id == oid }) else { return nil }
    let fines = allFines(o.controls, t)
    let totalNer = o.controls.reduce(0) { $0 + controlStats($1, t).constatate }
    let nActive = fines.filter { $0.st.level != "green" }.count
    let titlu = o.denumire.isEmpty ? "Obiectiv fără denumire" : o.denumire
    let adresa = [o.adresa, o.localitate].filter { !$0.isEmpty }.joined(separator: ", ")
    return ModelObiectiv(
        id: o.id, tip: textTip(o.tip), titlu: titlu,
        administrator: o.administrator.isEmpty ? "—" : o.administrator, telefon: o.telefon.isEmpty ? nil : o.telefon,
        email: o.email.isEmpty ? nil : o.email, adresa: adresa.isEmpty ? "—" : adresa,
        constructii: o.last.constructii.count,
        gps: o.last.constructii.enumerated().map { i, k in
            let nume = k.denumire.isEmpty ? "Construcția \(i + 1)" : k.denumire
            return GpsConstructie(nume: nume, coordonate: k.gps.map { fmtCoord($0) }, google: k.gps.map(googleMapsUrl),
                                  apple: k.gps.map { appleMapsUrl($0, "\(o.denumire) – \(nume)") })
        },
        statistici: [
            (o.controls.count, o.controls.count == 1 ? "control" : "controale"),
            (totalNer, totalNer == 1 ? "neregulă constatată" : "nereguli constatate"),
            (fines.count, fines.count == 1 ? "amendă aplicată" : "amenzi aplicate"),
            (nActive, nActive == 1 ? "amendă activă" : "amenzi active"),
        ],
        istoric: o.controls.map { modelRandControl($0, controls, t, arataNumele: false) })
}
