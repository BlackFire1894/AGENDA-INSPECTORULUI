import Foundation

// Portarea din js/model.js: obiectivele (gruparea controalelor), căutările, neregula veche.

public struct Obiectiv: Sendable {
    public let id: String
    public let controls: [Control]
    public let last: Control
    public var denumire: String { last.denumire }
    public var tip: String { last.tip }
    public var administrator: String { last.administrator }
    public var telefon: String { last.telefon }
    public var email: String { last.email }
    public var adresa: String { last.adresa }
    public var localitate: String { last.localitate }
}

public func byStartDesc(_ a: Control, _ b: Control) -> Int {
    let r = compara(b.dataInceput, a.dataInceput)
    return r != 0 ? r : compara(b.createdAt, a.createdAt)
}

/// Grupare pe obiective — datele obiectivului se iau din cel mai recent control.
public func objectives(_ controls: [Control]) -> [Obiectiv] {
    var ordine: [String] = []
    var grupe: [String: [Control]] = [:]
    for c in controls {
        if grupe[c.objectiveId] == nil { ordine.append(c.objectiveId); grupe[c.objectiveId] = [] }
        grupe[c.objectiveId]!.append(c)
    }
    let out = ordine.map { id -> Obiectiv in
        let list = grupe[id]!.sortatStabil(byStartDesc)
        return Obiectiv(id: id, controls: list, last: list[0])
    }
    return out.sortatStabil { byStartDesc($0.last, $1.last) }
}

/// Intervalul acoperit de un control (un control neîncheiat: doar ziua începerii)
public func controlRange(_ c: Control) -> (String, String) {
    let s = c.dataInceput
    let e = isISO(c.dataIncheiere) && c.dataIncheiere >= s ? c.dataIncheiere : s
    return (s, e)
}

/// Căutare după nume (fără diacritice) sau după dată (zi, lună, an)
public func matchControl(_ c: Control, _ query: String) -> Bool {
    let q = query.trimJS
    if q.isEmpty { return true }
    if let dq = parseDateQuery(q) {
        let (a, b) = queryRange(dq)
        let (s, e) = controlRange(c)
        return rangesOverlap(s, e, a, b)
    }
    let hay = fold([c.denumire, c.administrator, c.telefon, c.email, c.adresa, c.localitate].joined(separator: " "))
    return fold(q).cuvinte.allSatisfy { hay.contains($0) }
}

// Glosar pentru căutare: abreviere, denumirea completă și expresii care o indică (fără diacritice).
private let GLOSAR: [[String]] = [
    ["iluminat hint", "instalatie de iluminare de securitate pentru marcarea hidrantilor interiori", "marcarea hidrantilor"],
    ["idsai", "instalatie de detectare semnalizare si alarmare la incendiu", "detectare semnalizare"],
    ["hint", "instalatie de stingere a incendiilor cu hidranti interiori", "hidranti interiori"],
    ["hext", "instalatie de stingere a incendiilor cu hidranti exteriori", "hidranti exteriori"],
    ["exit", "instalatie de iluminare de securitate pentru evacuare", "iluminare de securitate pentru evacuare"],
    ["asi", "autorizatie de securitate la incendiu", "autorizatie de securitate"],
    ["aviz", "aviz de securitate la incendiu", "aviz de securitate"],
    ["ctpsi", "cadru tehnic psi", "cadru tehnic"],
    ["resp", "responsabil psi", "responsabil"],
    ["lfd", "lucru cu foc deschis", "foc deschis"],
]
private let GLOSAR_RE: [[NSRegularExpression]] = GLOSAR.map { forme in
    forme.map { try! NSRegularExpression(pattern: "\\b\(NSRegularExpression.escapedPattern(for: $0))\\b") }
}

/// Un text care conține o formă din glosar primește toate formele („hidranti interiori” găsește „Hint” și invers).
public func cuGlosar(_ text: String) -> String {
    let baza = fold(text)
    var rest = " \(baza) "
    var add: [String] = []
    for (i, re) in GLOSAR_RE.enumerated() {
        let gasit = re.contains { $0.firstMatch(in: rest, range: NSRange(rest.startIndex..., in: rest)) != nil }
        if gasit {
            add.append(contentsOf: GLOSAR[i])
            for r in re {
                rest = r.stringByReplacingMatches(in: rest, range: NSRange(rest.startIndex..., in: rest), withTemplate: " ")
            }
        }
    }
    return add.isEmpty ? baza : "\(baza) \(add.joined(separator: " "))"
}

private func potriviri(_ hay: String, _ q: String) -> Bool { q.cuvinte.allSatisfy { hay.contains($0) } }

/// Căutarea în acte: numărul actului sau text (denumire, observații), cu glosar
public func matchAct(_ c: Control, _ key: String, _ query: String) -> Bool {
    let q = fold(query).trimJS
    if q.isEmpty { return true }
    let i = K.acte.firstIndex { $0.key == key } ?? -1
    if q == String(i + 1) { return true }
    if q.lungimeJS < 3 && !q.contains(where: { $0.isWhitespace }) { return false }
    let label = i >= 0 ? K.acte[i].label : ""
    return potriviri(cuGlosar([label, c.act(key).obs].joined(separator: " ")), q)
}

/// Căutarea în nereguli: o literă (d, ag, G1, +2) găsește rândul exact; de la 3 caractere, textul, fără diacritice.
public func matchNeregula(_ c: Control, _ n: Neregula, _ query: String) -> Bool {
    let q = fold(query).trimJS
    if q.isEmpty { return true }
    if q == fold(neregulaLetter(c, n)) { return true }
    if q.lungimeJS < 3 && !q.contains(where: { $0.isWhitespace }) { return false }
    let hay = cuGlosar([neregulaLabel(n), constatareLabel(n), n.custom ? "" : (K.categorie(neregulaCat(n)) ?? ""), n.obs,
                        secOf(n) == "ner" ? constructiiNume(c, n) : ""].joined(separator: " "))
    return potriviri(hay, q)
}

// ───────── Neregulă veche ─────────
// Același rând (aceeași cheie; la rândurile adăugate: același text) constatat și la un control anterior al obiectivului.

func sameRow(_ a: Neregula, _ b: Neregula) -> Bool {
    if a.adapost || b.adapost { return a.adapost && b.adapost && a.key == b.key }
    if a.custom || b.custom {
        let la = fold(a.label).trimJS
        return a.custom && b.custom && !la.isEmpty && la == fold(b.label).trimJS
    }
    return a.key == b.key
}

public func controaleAnterioare(_ controls: [Control], _ c: Control) -> [Control] {
    controls.filter { x in
        x.objectiveId == c.objectiveId && x.id != c.id
            && (x.dataInceput < c.dataInceput || (x.dataInceput == c.dataInceput && x.createdAt < c.createdAt))
    }.sortatStabil(byStartDesc)
}

public func constatareAnterioara(_ controls: [Control], _ c: Control, _ n: Neregula) -> Control? {
    controaleAnterioare(controls, c).first { prev in prev.nereguli.contains { $0.status == "nok" && sameRow($0, n) } }
}

public struct InfoVeche: Sendable {
    public let veche: Bool
    /// controlul anterior la care s-a constatat același rând
    public let auto: Control?
    public let manual: Bool
}

public func vecheInfo(_ controls: [Control], _ c: Control, _ n: Neregula) -> InfoVeche {
    let auto = constatareAnterioara(controls, c, n)
    let manual = n.vecheManual
    return InfoVeche(veche: n.status == "nok" && (auto != nil || manual), auto: auto, manual: manual)
}
