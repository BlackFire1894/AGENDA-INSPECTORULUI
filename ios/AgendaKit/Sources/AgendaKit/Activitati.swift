import Foundation

// Portarea din js/activitati.js: activitățile planului lunar, zilele libere, raportul lunii (datele; HTML-ul în etapa 6).

/// Activitate nouă: implicit efectuată dacă ziua a trecut, altfel planificată
public func emptyActivitate(_ data: String = todayISO(), _ today: String = todayISO()) -> Activitate {
    let acum = isoMs()
    return Activitate(JSObiect([
        ("id", .string(uid())), ("tip", "instruire"), ("data", .string(data)), ("dataSfarsit", ""), ("ora", ""), ("descriere", ""),
        ("stare", .string(data < today ? "efectuat" : "planificat")), ("obs", ""), ("objectiveId", ""),
        ("createdAt", .string(acum)), ("updatedAt", .string(acum)),
    ]))
}

public func normalizeActivitate(_ a: JSObiect) -> Activitate {
    let data = a["data"]?.truthy == true ? a.str("data") : todayISO()
    var out = Activitate(emptyActivitate(data).o.combinat(cu: a))
    if K.tipActivitate(out.tip) == nil { out.tip = "alta" }
    if K.stareActivitate(out.stare) == nil { out.stare = "planificat" }
    if !isISO(out.dataSfarsit) || out.dataSfarsit <= out.data { out.dataSfarsit = "" }
    return out
}

public func sfarsitActivitate(_ a: Activitate) -> String { a.dataSfarsit.isEmpty ? a.data : a.dataSfarsit }

public func zileActivitate(_ a: Activitate) -> Int {
    var n = 1
    var d = a.data
    while d < sfarsitActivitate(a) { d = addDays(d, 1); n += 1 }
    return n
}

public func tipLabel(_ a: Activitate) -> String { K.tipActivitate(a.tip) ?? "Altă activitate" }

/// Titlul afișat: „Ședință: analiza lunară”; la „Altă activitate”, doar descrierea
public func titluActivitate(_ a: Activitate) -> String {
    let d = a.descriere.trimJS
    if a.tip == "alta" { return d.isEmpty ? "Altă activitate" : d }
    return d.isEmpty ? tipLabel(a) : "\(tipLabel(a)): \(d)"
}

public func cand(_ a: Activitate) -> String {
    let per = a.dataSfarsit.isEmpty ? fmtDate(a.data) : "\(fmtDate(a.data)) – \(fmtDate(a.dataSfarsit)) (\(zileActivitate(a)) zile)"
    return a.ora.isEmpty ? per : "\(per), ora \(a.ora)"
}

/// Activitățile dintr-o zi (cele pe mai multe zile apar în fiecare zi)
public func activitatiInZi(_ list: [Activitate], _ d: String) -> [Activitate] {
    list.filter { $0.data <= d && sfarsitActivitate($0) >= d }.sortatStabil { x, y in
        let r = compara(x.ora.isEmpty ? "99" : x.ora, y.ora.isEmpty ? "99" : y.ora)
        return r != 0 ? r : compara(x.createdAt, y.createdAt)
    }
}

/// Planificate a căror (ultimă) zi a trecut: de confirmat (efectuată / reprogramată / anulată)
public func deConfirmat(_ list: [Activitate], _ today: String = todayISO()) -> [Activitate] {
    list.filter { $0.stare == "planificat" && sfarsitActivitate($0) < today }.sortatStabil { compara($0.data, $1.data) }
}

// ───────── Zilele libere (weekend + sărbători legale), calculate la afișare ─────────

private let SARB_SCURT: [String: String] = [
    "Sfântul Ioan Botezătorul": "Sf. Ioan", "a doua zi de Paște": "Paște (ziua 2)", "a doua zi de Rusalii": "Rusalii (ziua 2)",
    "Adormirea Maicii Domnului": "Sf. Maria", "Sfântul Andrei": "Sf. Andrei", "a doua zi de Crăciun": "Crăciun (ziua 2)",
]
private func scurt(_ nume: String) -> String {
    nume.components(separatedBy: " / ").map { SARB_SCURT[$0] ?? $0 }.joined(separator: " / ")
}

public struct ZiLibera: Equatable, Sendable {
    public let d: String, motiv: String, sarbatoare: String, eticheta: String
    /// "efectuat" (până azi inclusiv) | "planificat"
    public let stare: String
    public var lucrata: Bool? = nil

    public var json: JSONValue {
        var o = JSObiect([("d", .string(d)), ("motiv", .string(motiv)), ("sarbatoare", .string(sarbatoare)),
                          ("eticheta", .string(eticheta)), ("stare", .string(stare))])
        if let l = lucrata { o["lucrata"] = .bool(l) }
        return .object(o)
    }
}

public func ziLibera(_ d: String, _ today: String = todayISO()) -> ZiLibera? {
    let motiv = zinelucratoare(d)
    if motiv.isEmpty { return nil }
    let sarbatoare = sarbatoriLegale(Int(d.prefix(4)) ?? 0).get(d) ?? ""
    return ZiLibera(d: d, motiv: motiv, sarbatoare: sarbatoare, eticheta: sarbatoare.isEmpty ? "Liber" : ucfirst(scurt(sarbatoare)),
                    stare: d <= today ? "efectuat" : "planificat")
}

public func eticheteLibera(_ z: ZiLibera) -> String {
    z.sarbatoare.isEmpty ? "Zi liberă (\(z.motiv))" : "Sărbătoare legală: \(ucfirst(z.sarbatoare))"
}

// ───────── Raportul lunii ─────────

public struct AmendaInLuna: Sendable {
    public let c: Control, n: Neregula
    public let data: String
    public let suma: Double
}

public struct TipInRaport: Equatable, Sendable {
    public let key: String, label: String
    public let n: Int, zile: Int
}

public struct ZiInRaport: Sendable {
    public var controale: [Control] = []
    public var activitati: [Activitate] = []
}

public struct RaportLunar: Sendable {
    public let an: Int, luna: Int, titlu: String
    public let controale: [Control]
    public let incheiate: Int, constatate: Int
    public let amenzi: [AmendaInLuna]
    public let sumaAmenzi: Double
    public let amenziFaraData: Int
    public let efectuate: [Activitate], planificate: [Activitate], anulate: [Activitate]
    public let peTipuri: [TipInRaport]
    public let libere: [ZiLibera]
    public let zileLuna: Int, lucratoare: Int
    public let zile: [(String, ZiInRaport)]
}

private func pad2(_ n: Int) -> String { n < 10 ? "0\(n)" : "\(n)" }

/// Raportul lunii (`luna` 0–11, ca în web): controalele începute în lună, amenzile aplicate în lună,
/// activitățile pe tipuri și stări, zilele libere, lista zi cu zi.
public func raportLunar(_ controls: [Control], _ activitati: [Activitate], _ an: Int, _ luna: Int, _ today: String = todayISO()) -> RaportLunar {
    let pre = "\(an)-\(pad2(luna + 1))"
    let inLuna = { (d: String) in isISO(d) && d.prefix(7) == pre }
    let ctl = controls.filter { inLuna($0.dataInceput) }.sortatStabil { -byStartDesc($0, $1) }
    let constatate = ctl.reduce(0) { $0 + controlStats($1, today).constatate }
    var amenzi: [AmendaInLuna] = []
    var faraData = 0
    for c in controls {
        for n in activeNereguli(c) where n.status == "nok" && n.amenda.aplicata {
            let d = fineDate(c, n)
            if inLuna(d) { amenzi.append(AmendaInLuna(c: c, n: n, data: d, suma: parseSuma(n.amenda.suma) ?? 0)) }
            else if d.isEmpty && inLuna(c.dataInceput) { faraData += 1 }
        }
    }
    let act = activitati.filter { $0.data.prefix(7) <= pre && sfarsitActivitate($0).prefix(7) >= pre }
    let peTipuri = K.tipuriActivitate.map { t -> TipInRaport in
        let ef = act.filter { $0.tip == t.key && $0.stare == "efectuat" }
        return TipInRaport(key: t.key, label: t.label, n: ef.count, zile: ef.reduce(0) { $0 + zileInLunaActivitate($1, pre) })
    }.filter { $0.n > 0 }
    var zileOrd: [String] = []
    var zileMap: [String: ZiInRaport] = [:]
    func zi(_ d: String, _ f: (inout ZiInRaport) -> Void) {
        if zileMap[d] == nil { zileOrd.append(d); zileMap[d] = ZiInRaport() }
        f(&zileMap[d]!)
    }
    for c in ctl { zi(c.dataInceput) { $0.controale.append(c) } }
    for a in act { zi(a.data.prefix(7) == pre ? a.data : "\(pre)-01") { $0.activitati.append(a) } }
    var libere: [ZiLibera] = []
    let zileLuna = zileInLuna(an, luna + 1)
    for k in 1...zileLuna {
        guard var z = ziLibera("\(pre)-\(pad2(k))", today) else { continue }
        // lucrată = în ziua liberă a început un control sau s-a efectuat o activitate (alta decât concediul)
        z.lucrata = ctl.contains { $0.dataInceput == z.d }
            || act.contains { $0.stare == "efectuat" && $0.tip != "concediu" && $0.data <= z.d && sfarsitActivitate($0) >= z.d }
        libere.append(z)
    }
    let numeLuna = K.luni[luna]
    return RaportLunar(
        an: an, luna: luna, titlu: "\(ucfirst(numeLuna)) \(an)",
        controale: ctl, incheiate: ctl.filter(isIncheiat).count, constatate: constatate,
        amenzi: amenzi, sumaAmenzi: amenzi.reduce(0) { $0 + $1.suma }, amenziFaraData: faraData,
        efectuate: act.filter { $0.stare == "efectuat" }, planificate: act.filter { $0.stare == "planificat" },
        anulate: act.filter { $0.stare == "anulat" }, peTipuri: peTipuri,
        libere: libere, zileLuna: zileLuna, lucratoare: zileLuna - libere.count,
        zile: zileOrd.sorted().map { ($0, zileMap[$0]!) })
}

private func zileInLunaActivitate(_ a: Activitate, _ pre: String) -> Int {
    var n = 0
    var d = a.data
    while d <= sfarsitActivitate(a) {
        if d.prefix(7) == pre { n += 1 }
        d = addDays(d, 1)
    }
    return n
}
