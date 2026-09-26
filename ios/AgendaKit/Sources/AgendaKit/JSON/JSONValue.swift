import Foundation

// Valorile JSON exact ca în aplicația web: obiectele își păstrează ordinea cheilor (ca obiectele JS),
// iar scrierea urmează JSON.stringify. Datele (controale, activități, backup) trec dus-întors fără pierderi,
// inclusiv câmpurile pe care aplicația nativă nu le cunoaște.

public enum JSONValue: Equatable, Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object(JSObiect)

    public var obiect: JSObiect? { if case .object(let o) = self { return o }; return nil }
    public var lista: [JSONValue]? { if case .array(let a) = self { return a }; return nil }
    public var sir: String? { if case .string(let s) = self { return s }; return nil }
    public var numar: Double? { if case .number(let n) = self { return n }; return nil }
    public var esteNull: Bool { if case .null = self { return true }; return false }

    /// Valoarea de adevăr din JS (`if (x)`).
    public var truthy: Bool {
        switch self {
        case .null: return false
        case .bool(let b): return b
        case .number(let n): return n != 0 && !n.isNaN
        case .string(let s): return !s.isEmpty
        case .array, .object: return true
        }
    }

    /// `String(x)` din JS (null → "null"; pentru câmpurile text folosiți `JSObiect.str`).
    public var textJS: String {
        switch self {
        case .null: return "null"
        case .bool(let b): return b ? "true" : "false"
        case .number(let n): return numarJS(n)
        case .string(let s): return s
        case .array(let a): return a.map { $0.esteNull ? "" : $0.textJS }.joined(separator: ",")
        case .object: return "[object Object]"
        }
    }

    /// `Number(x)` din JS, pentru valorile care pot fi scrise ca text („24”).
    public var numarJSValoare: Double {
        switch self {
        case .null: return 0
        case .bool(let b): return b ? 1 : 0
        case .number(let n): return n
        case .string(let s):
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if t.isEmpty { return 0 }
            return Double(t) ?? .nan
        case .array, .object: return .nan
        }
    }
}

/// Obiect JSON cu ordinea cheilor păstrată (ca obiectele JS). Egalitatea nu ține cont de ordine.
public struct JSObiect: Equatable, Sendable, Sequence {
    public private(set) var chei: [String] = []
    private var valori: [String: JSONValue] = [:]

    public init() {}
    public init(_ perechi: [(String, JSONValue)]) {
        for (k, v) in perechi { self[k] = v }
    }

    public subscript(_ cheie: String) -> JSONValue? {
        get { valori[cheie] }
        set {
            if let v = newValue {
                if valori.updateValue(v, forKey: cheie) == nil { chei.append(cheie) }
            } else if valori.removeValue(forKey: cheie) != nil {
                chei.removeAll { $0 == cheie }
            }
        }
    }

    public var count: Int { chei.count }
    public var isEmpty: Bool { chei.isEmpty }
    public func contine(_ cheie: String) -> Bool { valori[cheie] != nil }

    public func makeIterator() -> AnyIterator<(key: String, value: JSONValue)> {
        var i = 0
        return AnyIterator {
            guard i < chei.count else { return nil }
            defer { i += 1 }
            return (chei[i], valori[chei[i]]!)
        }
    }

    /// `{ ...this, ...alt }` din JS: cheile existente își păstrează locul, cele noi se adaugă la sfârșit.
    public func combinat(cu alt: JSObiect) -> JSObiect {
        var r = self
        for (k, v) in alt { r[k] = v }
        return r
    }

    public static func == (a: JSObiect, b: JSObiect) -> Bool { a.valori == b.valori }

    // Citiri tolerante, cu semantica JS
    public func str(_ k: String) -> String {
        guard let v = valori[k] else { return "" }
        switch v {
        case .null: return ""
        default: return v.textJS
        }
    }
    public func bool(_ k: String) -> Bool { valori[k]?.truthy ?? false }
    public func obj(_ k: String) -> JSObiect { valori[k]?.obiect ?? JSObiect() }
    public func arr(_ k: String) -> [JSONValue] { valori[k]?.lista ?? [] }
    public func strs(_ k: String) -> [String] { arr(k).map { $0.esteNull ? "" : $0.textJS } }
    public func int(_ k: String) -> Int? {
        guard let n = valori[k]?.numar, n.isFinite else { return nil }
        return Int(n)
    }
}

extension JSONValue: ExpressibleByStringLiteral, ExpressibleByBooleanLiteral, ExpressibleByIntegerLiteral,
    ExpressibleByFloatLiteral, ExpressibleByNilLiteral, ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral {
    public init(stringLiteral v: String) { self = .string(v) }
    public init(booleanLiteral v: Bool) { self = .bool(v) }
    public init(integerLiteral v: Int) { self = .number(Double(v)) }
    public init(floatLiteral v: Double) { self = .number(v) }
    public init(nilLiteral: ()) { self = .null }
    public init(arrayLiteral elements: JSONValue...) { self = .array(elements) }
    public init(dictionaryLiteral elements: (String, JSONValue)...) { self = .object(JSObiect(elements)) }
}

extension JSONValue {
    public init(_ s: String) { self = .string(s) }
    public init(_ b: Bool) { self = .bool(b) }
    public init(_ n: Int) { self = .number(Double(n)) }
    public init(_ n: Double) { self = .number(n) }
    public init(_ o: JSObiect) { self = .object(o) }
    public init(_ a: [String]) { self = .array(a.map { .string($0) }) }
}

// ───────── Numerele ca în JS (Number.prototype.toString) ─────────

/// `String(n)` din JS: 2500 → "2500", 1500.5 → "1500.5", 1e-7 → "1e-7", 1e21 → "1e+21".
public func numarJS(_ n: Double) -> String {
    if n.isNaN { return "NaN" }
    if n.isInfinite { return n < 0 ? "-Infinity" : "Infinity" }
    if n == 0 { return "0" }
    if n < 0 { return "-" + numarJS(-n) }
    if n == n.rounded(), n < 1e21 {
        if n < 9e18 { return String(Int64(n)) }
    }
    // cifrele cele mai scurte (Swift le dă la fel ca JS), apoi forma JS
    let (cifre, exp) = cifreSiExponent(n)
    let k = cifre.count
    let p = exp + 1   // poziția virgulei: valoarea = 0.cifre × 10^p
    if k <= p && p <= 21 { return cifre + String(repeating: "0", count: p - k) }
    if 0 < p && p <= 21 {
        let i = cifre.index(cifre.startIndex, offsetBy: p)
        return String(cifre[..<i]) + "." + String(cifre[i...])
    }
    if -6 < p && p <= 0 { return "0." + String(repeating: "0", count: -p) + cifre }
    let e = p - 1
    let mant = k == 1 ? cifre : String(cifre.prefix(1)) + "." + String(cifre.dropFirst())
    return mant + "e" + (e < 0 ? "-" : "+") + String(abs(e))
}

/// Cifrele semnificative (fără zerouri la capete) și exponentul zecimal al primei cifre.
private func cifreSiExponent(_ n: Double) -> (String, Int) {
    let d = "\(n)"   // forma cea mai scurtă care se citește înapoi identic
    var mant = d
    var exp = 0
    if let e = d.firstIndex(where: { $0 == "e" || $0 == "E" }) {
        mant = String(d[..<e])
        exp = Int(d[d.index(after: e)...]) ?? 0
    }
    var intreg = mant
    var frac = ""
    if let p = mant.firstIndex(of: ".") {
        intreg = String(mant[..<p])
        frac = String(mant[mant.index(after: p)...])
    }
    var toate = intreg + frac
    var pozitie = intreg.count + exp   // câte cifre sunt înaintea virgulei
    while toate.hasPrefix("0") && toate.count > 1 { toate.removeFirst(); pozitie -= 1 }
    while toate.hasSuffix("0") && toate.count > 1 { toate.removeLast() }
    return (toate, pozitie - 1)
}
