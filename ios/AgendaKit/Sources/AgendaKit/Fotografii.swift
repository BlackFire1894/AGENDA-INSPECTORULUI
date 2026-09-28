import Foundation

// Fotografiile constatărilor (adăugire nativă, decizia utilizatorului din 27.09.2026): pe rândurile constatate,
// ascunse implicit în editor, incluse în backup și în Fișa controlului.
// Controlul păstrează doar datele lor (`nereguli[].fotografii = [{ id, data }]`); imaginile (JPEG) sunt fișiere
// separate, ca salvarea controlului să rămână mică. Aplicația web păstrează câmpul (normalizeControl îl copiază),
// dar nu afișează fotografiile.

public struct Fotografie: Equatable, Hashable, Sendable {
    public let id: String
    /// momentul adăugării (`isoMs`)
    public let data: String
    public init(id: String, data: String) { self.id = id; self.data = data }
    public init?(_ o: JSObiect) {
        guard let id = o["id"]?.sir, !id.isEmpty else { return nil }
        self.id = id
        data = o.str("data")
    }
    public var json: JSONValue { .object(JSObiect([("id", .string(id)), ("data", .string(data))])) }
}

extension Neregula {
    public var fotografii: [Fotografie] {
        get { o.arr("fotografii").compactMap(\.obiect).compactMap(Fotografie.init) }
        set { o["fotografii"] = newValue.isEmpty ? nil : .array(newValue.map(\.json)) }
    }
}

extension Control {
    /// toate fotografiile controlului (pe toate rândurile, și cele retrase din listă)
    public var toateFotografiile: [Fotografie] { nereguli.flatMap(\.fotografii) }
}

/// Identificatorii fotografiilor folosite de controale (restul fișierelor pot fi șterse)
public func fotografiiFolosite(_ controls: [Control]) -> Set<String> { Set(controls.flatMap { $0.toateFotografiile.map(\.id) }) }

/// Identificator nou („f” + `uid()`), sigur ca nume de fișier
public func idFotografie() -> String { "f" + uid() }

/// Doar litere, cifre, „-”, „_” (numele fișierului; un backup străin nu poate scrie în afara folderului)
public func idFotografieValid(_ id: String) -> Bool {
    !id.isEmpty && id.count <= 64 && id.unicodeScalars.allSatisfy { CharacterSet.alphanumerics.contains($0) && $0.isASCII || $0 == "-" || $0 == "_" }
}

/// Fișa: fotografiile, la final, pe nereguli (litera și denumirea), cu imaginile date ca `data:` URI
/// (`imagine(id)`; nil = fișierul lipsește și fotografia se sare). Gol dacă nu există fotografii.
public func anexaFotografii(_ c: Control, _ controls: [Control], imagine: (String) -> String?) -> String {
    let randuri = activeNereguli(c).filter { $0.status == "nok" && !$0.fotografii.isEmpty }
    var blocuri: [String] = []
    for n in randuri {
        let fig = n.fotografii.compactMap { f -> String? in
            guard let src = imagine(f.id) else { return nil }
            let cand = dataISO(f.data).map { fmtDate(toISO($0)) } ?? ""
            return "<figure class=\"f-foto\"><img src=\"\(src)\" alt=\"\">\(cand.isEmpty ? "" : "<figcaption>\(cand)</figcaption>")</figure>"
        }
        if fig.isEmpty { continue }
        blocuri.append("<div class=\"f-foto-ner\"><h3>\(escHTML("\(neregulaLetter(c, n)). \(constatareLabel(n))"))</h3><div class=\"f-foto-grila\">\(fig.joined())</div></div>")
    }
    if blocuri.isEmpty { return "" }
    return "<section class=\"f-fotografii\"><h2>Fotografii</h2>\(blocuri.joined())</section>"
}

/// Stilurile anexei (în afara stiluri-fisa.css, care vine din web)
public let CSS_FOTOGRAFII = """
.f-fotografii { break-before: page; }
.f-foto-ner { break-inside: avoid; margin-bottom: 8pt; }
.f-foto-grila { display: grid; grid-template-columns: 1fr 1fr; gap: 6pt; }
.f-foto { margin: 0; break-inside: avoid; }
.f-foto img { width: 100%; max-height: 90mm; object-fit: contain; border: 0.75pt solid #d0d5e0; border-radius: 3pt; background: #f4f5f8; }
.f-foto figcaption { font-size: 8.5pt; color: #5b6478; margin-top: 2pt; }
"""
