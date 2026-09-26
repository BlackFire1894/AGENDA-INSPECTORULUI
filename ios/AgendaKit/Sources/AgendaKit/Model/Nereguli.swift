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
public func constructiiNume(_ c: Control, _ n: Neregula) -> String {
    constructiiOf(c, n).map { numeConstructie(c, $0) }.joined(separator: ", ")
}

/// Construcțiile care declanșează o neregulă gravă (NU la dotare sau GRF/NSI V peste parter); nil = nu e gravă
public func constructiiDeclansate(_ c: Control, _ t: RandSablon) -> [Constructie]? {
    if let r = t.reqNU, !r.isEmpty { return constructiiCuNU(c, r) }
    if t.reqGrfV { return c.constructii.filter(grfVPesteParter) }
    return nil
}

/// Construcțiile care au NU la o dotare (instalație necesară, lipsă)
public func constructiiCuNU(_ c: Control, _ key: String) -> [Constructie] {
    c.constructii.filter { $0.dotare(key)?.v == "NU" }
}

/// Construcțiile relevante pentru un rând: cele cu DA la instalația cerută, altfel toate.
public func constructiiEligibile(_ c: Control, _ n: Neregula) -> [Constructie] {
    let list = c.constructii
    guard !n.custom, let t = sablon(n.key), let req = t.req, !t.grav else { return list }
    let cu = list.filter { k in
        req.contains { r in r == "centrala" ? !(k.dotare("centrala")?.tipuri.isEmpty ?? true) : k.dotare(r)?.v == "DA" }
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
    c.constructii.contains { k in
        guard let v = k.dotare(key) else { return false }
        return key == "centrala" ? !v.tipuri.isEmpty : v.v == "DA"
    }
}

/// Neregulile de instalații apar doar dacă instalația există; un rând completat rămâne mereu vizibil.
public func isApplicable(_ c: Control, _ n: Neregula) -> Bool {
    if n.adapost { return c.adapostPC.v == "DA" }
    if n.custom || !n.status.isEmpty { return true }
    let t = sablon(n.key)
    if let t, !inCatalog(c, t) { return false }
    if let t, t.doarLaNU { return !constructiiCuNU(c, t.autoNU ?? "").isEmpty }
    if let t, let decl = constructiiDeclansate(c, t) { return !decl.isEmpty }
    guard let req = t?.req else { return true }
    return req.contains { hasDotare(c, $0) }
}

/// Rânduri ascunse doar pentru că instalația nu e bifată DA („Arată toate” le poate afișa).
public func ascunsaDeDotari(_ c: Control, _ n: Neregula) -> Bool {
    if n.custom || isApplicable(c, n) { return false }
    guard let t = sablon(n.key) else { return false }
    return !t.grav && inCatalog(c, t) && !t.doarLaNU
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

/// Starea verificării unei construcții, față de data începerii controlului.
public func verifStare(_ c: Control, _ n: Neregula, _ k: Constructie) -> StareVerificare {
    let t = sablon(n.key)
    let v = n.verificare(k.id)
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

public func verifExpirate(_ c: Control, _ n: Neregula) -> [Constructie] {
    isVerificare(n) ? constructiiEligibile(c, n).filter { verifStare(c, n, $0).stare == "expirata" } : []
}

/// Textul pentru PV / fișă: datele ultimei verificări la construcțiile alese
public func verifText(_ c: Control, _ n: Neregula) -> String {
    guard isVerificare(n) else { return "" }
    let multe = c.constructii.count > 1
    return constructiiOf(c, n).map { k in
        let s = verifStare(c, n, k)
        let cum = s.stare == "lipsa" ? "fără verificare prezentată"
            : "ultima verificare \(fmtDate(s.data))\(s.stare == "expirata" ? ", expirată (era valabilă până la \(fmtDate(s.expira ?? "")))" : "")"
        return multe ? "\(k.denumire.isEmpty ? "construcție" : k.denumire): \(cum)" : cum
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
/// Precizia: sub 30 m bună, până la 100 m acceptabilă, peste 100 m slabă
public func gpsQuality(_ acc: Double) -> String { acc <= 30 ? "buna" : acc <= 100 ? "medie" : "slaba" }
