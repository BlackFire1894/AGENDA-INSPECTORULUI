import Foundation

// Utilitare de text cu semantica din JS (trim, căutare fără diacritice, sume în stil românesc, sortare stabilă).

extension String {
    /// `s.trim()`
    public var trimJS: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    /// lungimea în unități UTF-16 (`s.length` din JS)
    var lungimeJS: Int { utf16.count }
    /// `s.replace(/tipar/g, cu)`
    func inlocuiesteRegex(_ tipar: String, _ cu: String) -> String {
        guard let re = try? NSRegularExpression(pattern: tipar) else { return self }
        return re.stringByReplacingMatches(in: self, range: NSRange(startIndex..., in: self), withTemplate: NSRegularExpression.escapedTemplate(for: cu))
    }
    /// `/tipar/.test(s)`
    func potrivesteRegex(_ tipar: String, ignoraMajuscule: Bool = false) -> Bool {
        guard let re = try? NSRegularExpression(pattern: tipar, options: ignoraMajuscule ? [.caseInsensitive] : []) else { return false }
        return re.firstMatch(in: self, range: NSRange(startIndex..., in: self)) != nil
    }
    /// `s.split(/\s+/)` pe un text deja curățat de spații la capete
    var cuvinte: [String] { split(whereSeparator: { $0.isWhitespace }).map(String.init) }
    /// prima literă mică (`l[0].toLowerCase() + l.slice(1)`)
    var primaMica: String {
        guard let c = first else { return self }
        return String(c).lowercased() + dropFirst()
    }
}

/// `fold()` din js/model.js: litere mici, fără diacritice (ș, ț, ă, â, î → s, t, a, a, i).
public func fold(_ s: String) -> String {
    let d = s.lowercased().decomposedStringWithCanonicalMapping
    var out = String.UnicodeScalarView()
    for u in d.unicodeScalars where !(0x300...0x36F).contains(u.value) {
        switch u {
        case "ş", "ș": out.append("s")
        case "ţ", "ț": out.append("t")
        default: out.append(u)
        }
    }
    return String(out)
}

/// `Number(text)` din JS (NaN dacă textul nu e un număr).
public func numarDinTextJS(_ text: String) -> Double {
    let s = text.trimJS
    if s.isEmpty { return 0 }
    switch s {
    case "Infinity", "+Infinity": return .infinity
    case "-Infinity": return -.infinity
    default: break
    }
    let mic = s.lowercased()
    for (prefix, baza) in [("0x", 16), ("0o", 8), ("0b", 2)] where mic.hasPrefix(prefix) {
        guard let n = UInt64(mic.dropFirst(2), radix: baza) else { return .nan }
        return Double(n)
    }
    guard s.potrivesteRegex("^[+-]?([0-9]+\\.?[0-9]*|\\.[0-9]+)([eE][+-]?[0-9]+)?$"), let n = Double(s) else { return .nan }
    return n
}

/// Suma scrisă de inspector, în lei: „2500”, „2.500”, „2 500”, „1.500,50”, „1500,5” (punct = mii, virgulă = zecimale).
/// Întoarce numărul sau nil dacă textul nu e o sumă.
public func parseSuma(_ v: String?) -> Double? {
    var x = (v ?? "").inlocuiesteRegex("(?i)lei", "").filter { !$0.isWhitespace }
    if x.isEmpty { return nil }
    if x.contains(",") {
        x = x.replacingOccurrences(of: ".", with: "")
        if let r = x.range(of: ",") { x.replaceSubrange(r, with: ".") }
    } else if x.potrivesteRegex("^[0-9]{1,3}(\\.[0-9]{3})+$") {
        x = x.replacingOccurrences(of: ".", with: "")
    }
    let n = numarDinTextJS(x)
    return n.isFinite ? n : nil
}

/// `n.toLocaleString('ro-RO', { maximumFractionDigits: 2 })`: „2.500”, „1.500,5”.
public func numarRo(_ n: Double, zecimale: Int = 2) -> String {
    guard n.isFinite else { return n.isNaN ? "NaN" : (n < 0 ? "-∞" : "∞") }
    // cifrele cele mai scurte ale numărului (ca ICU), apoi rotunjire „jumătate în sus” la `zecimale`
    var d = Decimal(string: "\(abs(n))") ?? Decimal(abs(n))
    var r = Decimal()
    NSDecimalRound(&r, &d, zecimale, .plain)
    let text = NSDecimalNumber(decimal: r).stringValue   // „1500.5”, „2500”
    var intreg = text
    var frac = ""
    if let p = text.firstIndex(of: ".") {
        intreg = String(text[..<p])
        frac = String(text[text.index(after: p)...])
    }
    while frac.hasSuffix("0") { frac.removeLast() }
    var grupat = ""
    for (i, c) in intreg.reversed().enumerated() {
        if i > 0 && i % 3 == 0 { grupat.append(".") }
        grupat.append(c)
    }
    grupat = String(grupat.reversed())
    let semn = n < 0 && (grupat != "0" || !frac.isEmpty) ? "-" : ""
    return semn + grupat + (frac.isEmpty ? "" : "," + frac)
}

/// `lei(n)` din js/activitati.js
public func lei(_ n: Double) -> String { "\(numarRo(n)) lei" }

/// `a.localeCompare(b)` pentru textele din aplicație (date ISO, identificatori): ordinea caracterelor.
func compara(_ a: String, _ b: String) -> Int { a < b ? -1 : a > b ? 1 : 0 }

extension Array {
    /// Sortare stabilă, ca `Array.prototype.sort` din JS (elementele egale își păstrează ordinea).
    func sortatStabil(_ cmp: (Element, Element) -> Int) -> [Element] {
        enumerated().sorted { x, y in
            let r = cmp(x.element, y.element)
            return r != 0 ? r < 0 : x.offset < y.offset
        }.map(\.element)
    }
}
