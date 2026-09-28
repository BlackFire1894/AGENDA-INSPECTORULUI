import Foundation

// Portarea din js/model.js: rândurile de nereguli (etichete, litere, categorii, aplicabilitate), construcțiile
// neregulii, sigiliile, verificările instalațiilor, GRF/NSI.

public func sablon(_ key: String) -> RandSablon? { K.rand(key) }

// ───────── GRF/NSI ─────────
public func grfText(_ v: String) -> String { v == "NN" ? "Nu e necesar" : v }

/// „Peste parter” = regimul de înălțime are ceva după P: P+1, P+2E, S+P+1, D+P+M, Parter + 1 etaj…
public func pesteParter(_ regim: String) -> Bool {
    let s = regim.uppercased().replacingOccurrences(of: "PARTER", with: "P").filter { !$0.isWhitespace }
    return s.potrivesteRegex("(^|[^A-Z])P\\+[^+]")
}
public func grfVPesteParter(_ k: Constructie) -> Bool { k.grf == "V" && pesteParter(k.regimInaltime) }

// ───────── Construcțiile neregulii ─────────

/// Construcțiile în care s-a făcut constatarea, în ordinea din tabul Obiectiv. Neales nimic: la neregulile grave,
/// cele cu NU la dotare; altfel, prima construcție (care are instalația).
public func constructiiOf(_ c: Control, _ n: Neregula) -> [Constructie] {
    let list = c.constructii
    // actele lipsă (ao / ap / aq) țin de obiectiv, nu de o construcție
    if !n.custom, sablon(n.key)?.autoActe != nil { return [] }
    let ids = Set(n.constructieIds)
    let alese = list.filter { ids.contains($0.id) }
    if !alese.isEmpty { return alese }
    let t = !n.custom ? sablon(n.key) : nil
    let decl = (t.flatMap { constructiiDeclansate(c, $0) }) ?? []
    if !decl.isEmpty { return decl }
    let elig = constructiiEligibile(c, n)
    return elig.isEmpty ? [] : [elig[0]]
}
public func constructieOf(_ c: Control, _ n: Neregula) -> Constructie? { constructiiOf(c, n).first }

func numeConstructie(_ c: Control, _ k: Constructie) -> String {
    if !k.denumire.isEmpty { return k.denumire }
    let i = c.constructii.firstIndex { $0.id == k.id } ?? -1
    return "Construcția \(i + 1)"
}
/// La rândurile pe centrală termică, centralele alese apar cu numărul lor („Corp A – CT 2”)
public func constructiiNume(_ c: Control, _ n: Neregula) -> String {
    let ct = centraleAlese(c, n)
    return constructiiOf(c, n).map { k in
        let u = ct.filter { $0.k.id == k.id }
        return u.isEmpty ? numeConstructie(c, k) : u.map(\.denumire).joined(separator: ", ")
    }.joined(separator: ", ")
}

/// Construcțiile care declanșează o neregulă gravă (NU la dotare sau GRF/NSI V peste parter); nil = nu e gravă
public func constructiiDeclansate(_ c: Control, _ t: RandSablon) -> [Constructie]? {
    if let r = t.reqNU, !r.isEmpty { return constructiiCuNU(c, r) }
    if t.reqGrfV { return c.constructii.filter(grfVPesteParter) }
    return nil
}

/// Construcțiile care au NU la o dotare (instalație necesară, lipsă)
public func constructiiCuNU(_ c: Control, _ key: String) -> [Constructie] {
    c.constructii.filter { valDotare(c, $0, key) == "NU" }
}

// ───────── Dotările afișate (v1.25) ─────────
// „Iluminat Hint” nu se mai completează când construcția nu are hidranți interiori (NU / NEC); valoarea rămasă
// salvată nu mai contează. Regula nu se aplică la controalele încheiate înainte de v1.25 (lista lor înghețată).

public func ilumHintAscuns(_ c: Control, _ k: Constructie) -> Bool {
    catalogOf(c) >= 12 && ["NU", "NEC"].contains(k.dotare("hidInt")?.o["v"]?.sir ?? "")
}
public func dotareAscunsa(_ c: Control, _ k: Constructie, _ d: DotareSablon) -> Bool {
    if (d.din ?? 0) != 0 && !inCatalog(c, din: d.din) { return true }
    return d.key == "ilumHint" && ilumHintAscuns(c, k)
}
public func dotariVizibile(_ c: Control, _ k: Constructie) -> [DotareSablon] { K.dotari.filter { !dotareAscunsa(c, k, $0) } }

/// Valoarea unei dotări DA / NU / NEC, ținând cont de rândurile ascunse
public func valDotare(_ c: Control, _ k: Constructie, _ key: String) -> String {
    if key == "ilumHint" && ilumHintAscuns(c, k) { return "" }
    return k.dotare(key)?.v ?? ""
}
/// Are construcția centrală termică: cel puțin o centrală declarată (sau, în date vechi, un tip bifat)
public func areCentrala(_ k: Constructie) -> Bool {
    guard let v = k.dotare("centrala") else { return false }
    return !(v.o["ct"]?.lista ?? []).isEmpty || !(v.o["tipuri"]?.lista ?? []).isEmpty
}
/// Centralele construcției
public func centraleOf(_ k: Constructie) -> [Centrala] { k.dotare("centrala")?.ct ?? [] }

/// Construcțiile relevante pentru un rând: cele cu DA la instalația cerută, altfel toate.
public func constructiiEligibile(_ c: Control, _ n: Neregula) -> [Constructie] {
    let list = c.constructii
    guard !n.custom, let t = sablon(n.key), let req = t.req, !t.grav else { return list }
    let cu = list.filter { k in
        req.contains { r in r == "centrala" ? areCentrala(k) : valDotare(c, k, r) == "DA" }
    }
    return cu.isEmpty ? list : cu
}

// ───────── Amenda: seria și numărul ─────────

/// „Seria AB nr. 123456” (gol dacă nu s-a completat nimic)
public func amendaSerieNr(_ a: Amenda) -> String {
    var t = a.serieNr.trimJS
    if t.isEmpty {
        t = [a.o["serie"], a.o["numar"]].map { ($0?.truthy == true ? $0!.textJS : "").trimJS }.filter { !$0.isEmpty }.joined(separator: " ")
    }
    t = t.inlocuiesteRegex("\\s+", " ")
    if t.isEmpty { return "" }
    if let re = try? NSRegularExpression(pattern: "^(?:seria\\s*)?([a-zăâîșț]{1,5})[\\s.,/-]*(?:nr\\.?\\s*)?([0-9][0-9 ]*)$", options: [.caseInsensitive]),
       let m = re.firstMatch(in: t, range: NSRange(t.startIndex..., in: t)),
       let r1 = Range(m.range(at: 1), in: t), let r2 = Range(m.range(at: 2), in: t) {
        return "Seria \(t[r1].uppercased()) nr. \(t[r2].replacingOccurrences(of: " ", with: ""))"
    }
    if t.potrivesteRegex("^[0-9][0-9 ]*$") { return "nr. \(t.replacingOccurrences(of: " ", with: ""))" }
    return t
}

// ───────── Etichete, categorii, litere ─────────

public func neregulaLabel(_ n: Neregula) -> String {
    if n.adapost {
        let l = n.locatie.trimJS
        return "Adăpost de protecție civilă – \(l.isEmpty ? "locație necompletată" : l)"
    }
    if n.custom { return n.label.isEmpty ? "Neregulă suplimentară" : n.label }
    return sablon(n.key)?.label ?? n.label
}

/// Formularea constatării (PV / Panou): la rubricile formulate pozitiv („PAAR avizat”), forma negativă.
public func constatareLabel(_ n: Neregula) -> String {
    if n.adapost && n.status == "nok" {
        let l = n.locatie.trimJS
        return "Adăpost de protecție civilă neconform – \(l.isEmpty ? "locație necompletată" : l)"
    }
    if n.custom { return neregulaLabel(n) }
    if n.status == "nok", let nok = sablon(n.key)?.nokLabel, !nok.isEmpty { return nok }
    return neregulaLabel(n)
}

/// Neregulă gravă: din listă (NU la dotări, GRF/NSI V peste parter) sau rând adăugat bifat „Neregulă gravă”
public func isGrav(_ n: Neregula) -> Bool { n.custom ? n.grav : (sablon(n.key)?.grav ?? false) }

public struct Sigilii: Equatable, Sendable {
    public let criterii: Int, sigilii: Int
    public var json: JSONValue { ["criterii": .number(Double(criterii)), "sigilii": .number(Double(sigilii))] }
}

/// Sigiliul se aplică pe construcție; neregulile grave constatate cu bifa Sigiliu sunt criteriile lui.
public func sigiliiControl(_ c: Control) -> Sigilii? {
    let rows = activeNereguli(c).filter { $0.status == "nok" && isGrav($0) && $0.sigiliu }
    if rows.isEmpty { return nil }
    let ids = Set(rows.flatMap { constructiiOf(c, $0).map(\.id) })
    return Sigilii(criterii: rows.count, sigilii: max(1, ids.count))
}
public func criteriiText(_ n: Int) -> String { "\(n) \(n == 1 ? "criteriu" : "criterii")" }
public func sigiliiText(_ s: Sigilii) -> String {
    s.sigilii == 1 ? "Sigiliu aplicat · \(criteriiText(s.criterii))"
        : "\(s.sigilii) sigilii (\(s.sigilii) construcții) · \(criteriiText(s.criterii))"
}

public func neregulaCat(_ n: Neregula) -> String {
    if n.adapost { return "adapost" }
    if n.custom { return "custom" }
    let c = sablon(n.key)?.cat ?? ""
    return c.isEmpty ? "custom" : c
}
public func secOf(_ n: Neregula) -> String { n.sec.isEmpty ? "ner" : n.sec }
public func tabOfNeregula(_ n: Neregula) -> String { K.sectiune(secOf(n)).tab }

/// Numerotarea afișată: literă (a–z) la Nereguli, număr în grup la Planuri/PC, „+n” la cele adăugate, „An” la adăposturi.
public func neregulaLetter(_ c: Control, _ n: Neregula) -> String {
    if n.adapost {
        let i = adaposturi(c).firstIndex { $0.key == n.key } ?? -1
        return "A\(i + 1)"
    }
    if n.custom {
        let l = c.nereguli.filter { $0.custom && !$0.adapost && secOf($0) == secOf(n) }
        let i = l.firstIndex { $0.key == n.key } ?? -1
        return "+\(i + 1)"
    }
    guard let t = sablon(n.key) else { return n.key }
    if let l = t.letter, !l.isEmpty { return l }
    if t.sec == "ner" { return n.key }
    let grup = K.sablon.filter { $0.cat == t.cat }
    return String((grup.firstIndex { $0.key == t.key } ?? -1) + 1)
}

// ───────── Secțiuni și rânduri active ─────────

/// Secțiunile care se aplică acestui control (Planuri/PC doar la localități)
public func sectiuniActive(_ c: Control) -> [String] {
    K.sectiuni.filter { !$0.onlyLocalitate || isLocalitate(c) }.map(\.key)
}

/// Rândurile care contează (statistici, Panou, amenzi): cele din secțiunile active.
public func activeNereguli(_ c: Control) -> [Neregula] {
    let secs = sectiuniActive(c)
    return c.nereguli.filter { secs.contains(secOf($0)) }
}

/// Are obiectivul dotarea respectivă bifată DA în cel puțin o construcție?
public func hasDotare(_ c: Control, _ key: String) -> Bool {
    c.constructii.contains { k in key == "centrala" ? areCentrala(k) : valDotare(c, k, key) == "DA" }
}

/// Neregulile de instalații apar doar dacă instalația există; un rând completat rămâne mereu vizibil.
public func isApplicable(_ c: Control, _ n: Neregula) -> Bool {
    if n.adapost { return c.adapostPC.v == "DA" }
    if n.custom || !n.status.isEmpty { return true }
    let t = sablon(n.key)
    if let t, !inCatalog(c, t) { return false }
    if let t, t.doarLaNU { return !constructiiCuNU(c, t.autoNU ?? "").isEmpty }
    if let t, t.autoActe != nil { return !acteLipsa(c, t).isEmpty }
    if let t, let decl = constructiiDeclansate(c, t) { return !decl.isEmpty }
    guard let req = t?.req else { return true }
    return req.contains { hasDotare(c, $0) }
}

/// Rânduri ascunse doar pentru că instalația nu e bifată DA („Arată toate” le poate afișa).
public func ascunsaDeDotari(_ c: Control, _ n: Neregula) -> Bool {
    if n.custom || isApplicable(c, n) { return false }
    guard let t = sablon(n.key) else { return false }
    return !t.grav && inCatalog(c, t) && !t.doarLaNU && t.autoActe == nil
}

// ───────── Verificări pe instalații ─────────

public func isVerificare(_ n: Neregula) -> Bool { !n.custom && (sablon(n.key)?.verif ?? 0) != 0 }

public struct StareVerificare: Equatable, Sendable {
    public let data: String
    public let luni: Int
    public let expira: String?
    /// "lipsa" | "expirata" | "valabila"
    public let stare: String
}

// ───────── Rândurile pe centrală termică (v1.25: b3, g, h) ─────────
// Controalele încheiate înainte de v1.25 rămân pe construcție.

public func perCT(_ c: Control, _ n: Neregula) -> Bool { !n.custom && (sablon(n.key)?.perCT ?? false) && catalogOf(c) >= 12 }

/// O unitate de verificare / constatare: o construcție sau o centrală a ei. `id` = cheia din `n.verificari`
/// („<construcție>” sau „<construcție>:<centrală>”).
public struct UnitateVerif: Equatable, Sendable {
    public let id: String
    public let k: Constructie
    public let ct: Centrala?
    /// numărul centralei (1…), 0 la construcție
    public let nr: Int
    public let denumire: String
}

/// Centralele unei construcții, ca unități: „<construcție> – CT 2”
public func unitatiCT(_ c: Control, _ k: Constructie) -> [UnitateVerif] {
    let nume = numeConstructie(c, k)
    return centraleOf(k).enumerated().map { i, x in
        UnitateVerif(id: "\(k.id):\(x.id)", k: k, ct: x, nr: i + 1, denumire: "\(nume) – CT \(i + 1)")
    }
}

/// Centralele alese la o constatare, pe construcțiile ei (alese explicit în `ctIds`); [] = construcțiile întregi
public func centraleAlese(_ c: Control, _ n: Neregula) -> [UnitateVerif] {
    guard perCT(c, n), let l = n.ctIds, !l.isEmpty else { return [] }
    let ids = Set(l)
    return constructiiOf(c, n).flatMap { k in unitatiCT(c, k).filter { ids.contains($0.id) } }
}

/// Unitățile de verificare ale unui rând: construcțiile relevante; la verificarea CT, fiecare centrală
/// (construcția cu „NU ARE” nu are rând; cea fără centrale declarate rămâne pe construcție).
public func verifUnitati(_ c: Control, _ n: Neregula) -> [UnitateVerif] {
    let list = constructiiEligibile(c, n)
    func cons(_ k: Constructie) -> UnitateVerif {
        UnitateVerif(id: k.id, k: k, ct: nil, nr: 0, denumire: k.denumire.isEmpty ? "Construcție" : k.denumire)
    }
    if !perCT(c, n) { return list.map(cons) }
    return list.flatMap { k -> [UnitateVerif] in
        let u = unitatiCT(c, k)
        if !u.isEmpty { return u }
        return k.dotare("centrala")?.nuAre == true ? [] : [cons(k)]
    }
}

/// Starea verificării unei unități (construcție sau centrală), față de data începerii controlului.
/// Prima centrală a unei construcții preia data scrisă pe construcție înainte de v1.25.
public func verifStare(_ c: Control, _ n: Neregula, _ u: UnitateVerif) -> StareVerificare {
    let t = sablon(n.key)
    let m = n.verificari
    let x = m[u.id].flatMap { $0.truthy ? $0 : nil }
        ?? (u.ct != nil && u.nr == 1 ? m[u.k.id].flatMap { $0.truthy ? $0 : nil } : nil)
    let v = Verificare(x?.obiect ?? JSObiect())
    let luniV = v.luni
    let luni: Int
    if let alegeri = t?.verifAlegeri, luniV.isFinite, luniV == luniV.rounded(), alegeri.contains(Int(luniV)) {
        luni = Int(luniV)
    } else {
        luni = t?.verif ?? 0
    }
    if !isISO(v.data) { return StareVerificare(data: "", luni: luni, expira: nil, stare: "lipsa") }
    let expira = addMonths(v.data, luni)
    let ref = isISO(c.dataInceput) ? c.dataInceput : todayISO()
    return StareVerificare(data: v.data, luni: luni, expira: expira, stare: expira < ref ? "expirata" : "valabila")
}

/// Starea verificării pe construcție (unitatea construcției întregi)
public func verifStare(_ c: Control, _ n: Neregula, _ k: Constructie) -> StareVerificare {
    verifStare(c, n, UnitateVerif(id: k.id, k: k, ct: nil, nr: 0, denumire: k.denumire))
}

public func verifExpirate(_ c: Control, _ n: Neregula) -> [UnitateVerif] {
    isVerificare(n) ? verifUnitati(c, n).filter { verifStare(c, n, $0).stare == "expirata" } : []
}

/// Unitățile constatării (PV / fișă): la rândurile pe CT, centralele alese sau toate centralele construcțiilor alese
func unitatiConstatare(_ c: Control, _ n: Neregula) -> [UnitateVerif] {
    if !perCT(c, n) {
        return constructiiOf(c, n).map { UnitateVerif(id: $0.id, k: $0, ct: nil, nr: 0, denumire: $0.denumire.isEmpty ? "construcție" : $0.denumire) }
    }
    let alese = centraleAlese(c, n)
    if !alese.isEmpty { return alese }
    let ks = Set(constructiiOf(c, n).map(\.id))
    return verifUnitati(c, n).filter { ks.contains($0.k.id) }
}

/// Textul pentru PV / fișă: datele ultimei verificări la construcțiile (centralele) alese
public func verifText(_ c: Control, _ n: Neregula) -> String {
    guard isVerificare(n) else { return "" }
    let unit = unitatiConstatare(c, n)
    let multe = c.constructii.count > 1 || unit.contains { $0.ct != nil }
    return unit.map { u in
        let s = verifStare(c, n, u)
        let cum = s.stare == "lipsa" ? "fără verificare prezentată"
            : "ultima verificare \(fmtDate(s.data))\(s.stare == "expirata" ? ", expirată (era valabilă până la \(fmtDate(s.expira ?? "")))" : "")"
        return multe ? "\(u.denumire): \(cum)" : cum
    }.joined(separator: "; ")
}

// ───────── Coordonate GPS ─────────

private func fix6(_ x: Double) -> String { String(format: "%.6f", x) }
public func fmtCoord(_ g: Gps?) -> String { g.map { "\(fix6($0.lat)), \(fix6($0.lon))" } ?? "" }
public func googleMapsUrl(_ g: Gps) -> String { "https://www.google.com/maps/search/?api=1&query=\(fix6(g.lat)),\(fix6(g.lon))" }
public func appleMapsUrl(_ g: Gps, _ label: String = "") -> String {
    var permise = CharacterSet.alphanumerics.intersection(CharacterSet(charactersIn: Unicode.Scalar(0)...Unicode.Scalar(127)))
    permise.insert(charactersIn: "-_.!~*'()")
    let q = (label.isEmpty ? fmtCoord(g) : label).addingPercentEncoding(withAllowedCharacters: permise) ?? ""
    return "https://maps.apple.com/?ll=\(fix6(g.lat)),\(fix6(g.lon))&q=\(q)"
}
/// Precizia: sub 30 m bună, până la 100 m acceptabilă, peste 100 m slabă; coordonatele introduse de mână nu au precizie
public func gpsQuality(_ acc: Double?) -> String {
    guard let acc else { return "manual" }
    return acc <= 30 ? "buna" : acc <= 100 ? "medie" : "slaba"
}
public func gpsQuality(_ g: Gps) -> String { gpsQuality(g.faraPrecizie ? nil : g.acc) }

/// Aceleași coordonate (construcțiile 2… „ca la prima construcție”)
public func gpsEgal(_ a: Gps?, _ b: Gps?) -> Bool {
    guard let a, let b, let la = a.o["lat"], let lb = b.o["lat"], let oa = a.o["lon"], let ob = b.o["lon"] else { return false }
    return la == lb && oa == ob
}

/// Coordonate scrise de mână: „44.426800, 26.102500”, „44,4268 26,1025”, „44°25′36″ N 26°6′9″ E” (Busola de pe iPhone).
/// Întoarce (lat, lon) cu 6 zecimale, sau nil.
public func parseCoord(_ text: String) -> (lat: Double, lon: Double)? {
    let s = text.trimJS
        .inlocuiesteRegex("[’′‘]", "'").inlocuiesteRegex("[”″“]", "\"").replacingOccurrences(of: "º", with: "°")
    if s.isEmpty { return nil }
    var lat = Double.nan, lon = Double.nan
    // `Number(x.replace(',', '.'))`: doar prima virgulă
    func nr(_ x: String?) -> Double {
        let t = x ?? "0"
        return Double(t.range(of: ",").map { t.replacingCharacters(in: $0, with: ".") } ?? t) ?? .nan
    }
    if s.contains("°") {
        guard let re = try? NSRegularExpression(pattern: "(-?\\d+(?:[.,]\\d+)?)\\s*°\\s*(?:(\\d+(?:[.,]\\d+)?)\\s*'\\s*)?(?:(\\d+(?:[.,]\\d+)?)\\s*(?:\"|'')\\s*)?([NSEWV])?", options: [.caseInsensitive]) else { return nil }
        let ns = s as NSString
        let p: [(v: Double, emisfera: String)] = re.matches(in: s, range: NSRange(location: 0, length: ns.length)).map { m in
            func g(_ i: Int) -> String? { m.range(at: i).location == NSNotFound ? nil : ns.substring(with: m.range(at: i)) }
            let gr = nr(g(1)), mi = nr(g(2)), se = nr(g(3))
            let v = abs(gr) + mi / 60 + se / 3600
            let em = (g(4) ?? "").uppercased()
            let neg = gr < 0 || ["S", "W", "V"].contains(em)
            return (neg ? -v : v, em)
        }
        if p.count != 2 { return nil }
        // ordinea: latitudinea (N / S) întâi; „E 26° N 44°” se întoarce
        if ["E", "W", "V"].contains(p[0].emisfera) || ["N", "S"].contains(p[1].emisfera) {
            (lat, lon) = (p[1].v, p[0].v)
        } else {
            (lat, lon) = (p[0].v, p[1].v)
        }
    } else {
        guard let m = s.grupeRegex("^(-?\\d{1,3}[.,]\\d+)(\\s*[,;\\s]\\s*)(-?\\d{1,3}[.,]\\d+)$"), m.count >= 4 else { return nil }
        // cu virgulă zecimală, separatorul trebuie să fie spațiu sau „;” („44,4268,26,1025” e ambiguu)
        if (m[1].contains(",") || m[3].contains(",")) && !m[2].potrivesteRegex("[;\\s]") { return nil }
        (lat, lon) = (nr(m[1]), nr(m[3]))
    }
    if !lat.isFinite || !lon.isFinite || abs(lat) > 90 || abs(lon) > 180 { return nil }
    // Math.round din JS (jumătățile în sus)
    func r6(_ x: Double) -> Double { (x * 1e6 + 0.5).rounded(.down) / 1e6 }
    return (r6(lat), r6(lon))
}
