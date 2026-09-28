import Foundation

// Calendarul (js/views.js → calendarData, viewCalendar): grila lunii (de luni până duminică), controalele,
// termenele, activitățile, zilele libere; ziua selectată, cu controalele, termenele și activitățile ei.

public struct TermenCalendar: Sendable {
    /// „plata” | „anaf” | „asi” | „asi2” | „inc”
    public let kind: String
    /// „blue” | „red” | „warn”
    public let level: String
    public let c: Control
    public let n: Neregula?
    public let text: String
    /// ținta atingerii: tabul și elementul din control
    public let tab: String, focus: String
}

public struct ZiCalendar: Sendable {
    public var controls: [Control] = []
    public var deadlines: [TermenCalendar] = []
}

/// Controalele (pe fiecare zi a perioadei; neîncheiate: până azi) și termenele din intervalul [from, to]
public func calendarData(_ controls: [Control], _ from: String, _ to: String, azi t: String) -> [String: ZiCalendar] {
    var map: [String: ZiCalendar] = [:]
    for c in controls {
        var (s, e) = controlRange(c)
        if !isIncheiat(c) && t > s { e = t }   // controlul neîncheiat apare până azi
        if !(e < from || s > to) {
            var d = s < from ? from : s
            let end = e > to ? to : e
            var guardN = 0
            while d <= end && guardN < 62 { map[d, default: ZiCalendar()].controls.append(c); d = addDays(d, 1); guardN += 1 }
        }
        for n in activeNereguli(c) where n.status == "nok" && n.amenda.aplicata {
            let st = fineStatus(c, n, t)
            guard st.level != "green", let pp = st.plataPana, !pp.isEmpty else { continue }
            let tab = tabOfNeregula(n)
            if pp >= from && pp <= to {
                map[pp, default: ZiCalendar()].deadlines.append(TermenCalendar(kind: "plata", level: "blue", c: c, n: n, text: "Termen plată amendă (15 zile)", tab: tab, focus: n.key))
            }
            if let ap = st.anafPana, ap >= from && ap <= to {
                map[ap, default: ZiCalendar()].deadlines.append(TermenCalendar(kind: "anaf", level: "red", c: c, n: n, text: "Termen trimitere la ANAF / Taxe și impozite", tab: tab, focus: n.key))
            }
        }
        let a = asiDeadline(c, t)
        if let a, let dl = a.deadline, !dl.isEmpty, !(a.resolved ?? false), dl >= from && dl <= to {
            map[dl, default: ZiCalendar()].deadlines.append(TermenCalendar(kind: "asi", level: "red", c: c, n: nil, text: "Termen ASI – 90 de zile", tab: "nereguli", focus: "a"))
        }
        if let tp = a?.termenPierdere, !tp.isEmpty, tp >= from && tp <= to {
            map[tp, default: ZiCalendar()].deadlines.append(TermenCalendar(kind: "asi2", level: "red", c: c, n: nil, text: "Termen ASI – constatarea pierderii valabilității", tab: "nereguli", focus: "a"))
        }
        if let inc = incarcareStatus(c, t), !inc.gata, let tm = inc.termen, tm >= from && tm <= to {
            map[tm, default: ZiCalendar()].deadlines.append(TermenCalendar(kind: "inc", level: "warn", c: c, n: nil, text: "Termen încărcare în aplicație și document", tab: "obiectiv", focus: "sec-incarcare"))
        }
    }
    return map
}

// ───────── modelul ecranului ─────────

public struct EticheteZi: Equatable, Sendable {
    /// „liber” | „open” | „done” | „act”
    public let tip: String
    public let text: String
    /// zi liberă: sărbătoare; activitate: tipul (culoarea)
    public var sarbatoare = false
    public var tipActivitate = ""
    /// „efectuat” | „planificat” | „anulat” (zilele libere și activitățile)
    public var stare = ""
}

public struct CelulaCalendar: Equatable, Sendable, Identifiable {
    public var id: String { d }
    public let d: String, numar: Int
    public let inLuna: Bool, libera: Bool, azi: Bool, selectata: Bool
    /// primele 3 etichete
    public let etichete: [EticheteZi]
    public let maiMulte: Int
    /// nivelurile primelor 4 termene (punctele colorate)
    public let termene: [String]
}

public struct TermenZi: Sendable, Identifiable {
    public var id: String { "\(kind)|\(c.id)|\(focus)" }
    public let kind: String, level: String, titlu: String, sub: String
    public let c: Control
    public let tab: String, focus: String
}

public struct ModelZiSelectata: Sendable {
    public let d: String
    public let eticheta: String, titlu: String
    /// „Sărbătoare legală: …” / „Zi liberă (sâmbătă)” + starea
    public let libera: (text: String, sarbatoare: Bool, stare: PastilaUI)?
    public let controale: [Control]
    public let termene: [TermenZi]
    public let activitati: [Activitate]
}

public struct ModelCalendar: Sendable {
    public let an: Int, luna: Int
    public let supratitlu: String, titlu: String, lunaScurt: String
    /// „2026-10”, pentru Planul lunar
    public let pre: String
    public let celule: [CelulaCalendar]
    public let zi: ModelZiSelectata
}

public let ZILE_SCURT = ["Lu", "Ma", "Mi", "Jo", "Vi", "Sâ", "Du"]

public let LEGENDA_CALENDAR: [(String, String)] = [
    ("sw-open", "control în desfășurare"), ("sw-done", "control încheiat"), ("dot-blue", "termen plată amendă"),
    ("dot-red", "termen ANAF / Taxe și impozite sau ASI"), ("dot-warn", "termen încărcare"), ("sw-act", "activitate (culoarea tipului)"),
]
/// ultima intrare din legendă, după dispozitiv (`dsp` din web)
public func legendaLiber(telefon: Bool) -> String {
    telefon ? "zi liberă (fundal gri): weekend / sărbătoare legală" : "zi liberă „Liber”: weekend / sărbătoare legală (✓ = efectuată)"
}

private let PILL_STARE_ZI = ["planificat": ("open", "clock"), "efectuat": ("green", "check"), "anulat": ("neutral", "")]

private func pad2(_ n: Int) -> String { n < 10 ? "0\(n)" : "\(n)" }

/// `luna` 0–11 (ca în web); `selectat` = ziua selectată
public func modelCalendar(_ controls: [Control], _ activitati: [Activitate], an y: Int, luna m: Int, selectat sel: String, azi t: String) -> ModelCalendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    let first = cal.date(from: DateComponents(year: y, month: m + 1, day: 1))!
    let offset = (cal.component(.weekday, from: first) - 1 + 6) % 7
    let daysInMonth = zileInLuna(y, m + 1)
    let weeks = (offset + daysInMonth + 6) / 7
    let firstISO = "\(y)-\(pad2(m + 1))-01"
    let gridStart = addDays(firstISO, -offset)
    let gridEnd = addDays(gridStart, weeks * 7 - 1)
    let data = calendarData(controls, gridStart, gridEnd, azi: t)
    let lastISO = "\(y)-\(pad2(m + 1))-\(pad2(daysInMonth))"
    let monthCount = controls.filter { c in
        var (s, e) = controlRange(c)
        if !isIncheiat(c) && t > s { e = t }
        return s <= lastISO && e >= firstISO
    }.count
    let pre = "\(y)-\(pad2(m + 1))"
    let actLuna = activitati.filter { $0.stare != "anulat" && $0.data.prefix(7) <= pre && sfarsitActivitate($0).prefix(7) >= pre }.count

    var celule: [CelulaCalendar] = []
    for i in 0..<(weeks * 7) {
        let d = addDays(gridStart, i)
        let ev = data[d] ?? ZiCalendar()
        let acts = activitatiInZi(activitati, d).filter { $0.stare != "anulat" }
        let lib = ziLibera(d, t)
        var toate: [EticheteZi] = []
        if let lib { toate.append(EticheteZi(tip: "liber", text: "\(lib.stare == "efectuat" ? "✓ " : "")\(lib.eticheta)", sarbatoare: !lib.sarbatoare.isEmpty, stare: lib.stare)) }
        toate += ev.controls.map { EticheteZi(tip: isIncheiat($0) ? "done" : "open", text: $0.denumire.isEmpty ? "Fără denumire" : $0.denumire) }
        toate += acts.map { EticheteZi(tip: "act", text: "\($0.stare == "efectuat" ? "✓ " : "")\(titluActivitate($0))", tipActivitate: $0.tip, stare: $0.stare) }
        celule.append(CelulaCalendar(
            d: d, numar: Int(d.suffix(2)) ?? 0, inLuna: Int(d.dropFirst(5).prefix(2)) == m + 1, libera: lib != nil,
            azi: d == t, selectata: d == sel, etichete: Array(toate.prefix(3)), maiMulte: max(0, toate.count - 3),
            termene: ev.deadlines.prefix(4).map(\.level)))
    }

    let selData = calendarData(controls, sel, sel, azi: t)[sel] ?? ZiCalendar()
    var libera: (String, Bool, PastilaUI)?
    if let z = ziLibera(sel, t) {
        let (niv, ic) = PILL_STARE_ZI[z.stare] ?? ("neutral", "")
        libera = (eticheteLibera(z), !z.sarbatoare.isEmpty, PastilaUI(niv, K.stareActivitate(z.stare) ?? z.stare, ic))
    }
    let zi = ModelZiSelectata(
        d: sel, eticheta: sel == t ? "Astăzi" : "Ziua selectată", titlu: ucfirst(fmtDateLong(sel)), libera: libera,
        controale: selData.controls,
        termene: selData.deadlines.map { x in
            TermenZi(kind: x.kind, level: x.level, titlu: x.text,
                     sub: x.c.denumire + (x.n.map { " · \(neregulaLetter(x.c, $0)). \(constatareLabel($0))" } ?? ""),
                     c: x.c, tab: x.tab, focus: x.focus)
        },
        activitati: activitatiInZi(activitati, sel))
    return ModelCalendar(
        an: y, luna: m,
        supratitlu: "\(monthCount) \(monthCount == 1 ? "control" : "controale") și \(actLuna) \(actLuna == 1 ? "activitate" : "activități") în această lună",
        titlu: "\(ucfirst(K.luni[m])) \(y)", lunaScurt: ucfirst(K.luniScurt[m]), pre: pre, celule: celule, zi: zi)
}

/// Luna următoare / anterioară (`new Date(an, luna ± 1, 1)`)
public func lunaDeplasata(_ an: Int, _ luna: Int, _ d: Int) -> (an: Int, luna: Int) {
    let t = an * 12 + luna + d
    return (Int((Double(t) / 12).rounded(.down)), ((t % 12) + 12) % 12)
}

// ───────── activitățile: salvarea din fereastră (js/app.js → openActivitate) ─────────

/// Verifică și pregătește activitatea din fereastră; întoarce mesajul de eroare sau activitatea normalizată
public func salveazaActivitate(_ ciorna: Activitate) -> (eroare: String?, activitate: Activitate?) {
    var a = ciorna
    a.descriere = a.descriere.trimJS
    let err = !isISO(a.data) ? "Alegeți data activității."
        : !a.dataSfarsit.isEmpty && a.dataSfarsit < a.data ? "„Până la” nu poate fi înaintea datei de început."
        : a.tip == "alta" && a.descriere.isEmpty ? "Scrieți descrierea activității." : ""
    if !err.isEmpty { return (err, nil) }
    var x = a
    x.updatedAt = isoMs()
    return (nil, normalizeActivitate(x.o))
}
