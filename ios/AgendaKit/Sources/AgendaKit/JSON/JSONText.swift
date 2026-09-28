import Foundation

// Citirea și scrierea textului JSON, cu ordinea cheilor păstrată (ca JSON.parse / JSON.stringify din JS).

public struct EroareJSON: Error, CustomStringConvertible {
    public let mesaj: String
    public let pozitie: Int
    public var description: String { "JSON invalid la poziția \(pozitie): \(mesaj)" }
}

extension JSONValue {
    /// `JSON.parse`
    public static func citeste(_ data: Data) throws -> JSONValue {
        var p = CititorJSON(octeti: [UInt8](data))
        p.spatii()
        let v = try p.valoare()
        p.spatii()
        guard p.i == p.octeti.count else { throw EroareJSON(mesaj: "text în plus după valoare", pozitie: p.i) }
        return v
    }

    public static func citeste(_ text: String) throws -> JSONValue {
        try citeste(Data(text.utf8))
    }

    /// `JSON.stringify(valoare, null, indentare)`; fără indentare = compact.
    public func text(indentare: Int = 0) -> String {
        var out = ""
        scrie(&out, indentare: indentare, nivel: 0)
        return out
    }

    public func date(indentare: Int = 0) -> Data { Data(text(indentare: indentare).utf8) }

    private func scrie(_ out: inout String, indentare: Int, nivel: Int) {
        switch self {
        case .null: out += "null"
        case .bool(let b): out += b ? "true" : "false"
        case .number(let n): out += n.isFinite ? numarJS(n) : "null"
        case .string(let s): scrieSir(&out, s)
        case .array(let a):
            if a.isEmpty { out += "[]"; return }
            out += "["
            for (i, v) in a.enumerated() {
                if i > 0 { out += "," }
                linieNoua(&out, indentare, nivel + 1)
                v.scrie(&out, indentare: indentare, nivel: nivel + 1)
            }
            linieNoua(&out, indentare, nivel)
            out += "]"
        case .object(let o):
            if o.isEmpty { out += "{}"; return }
            out += "{"
            var primul = true
            for (k, v) in o {
                if !primul { out += "," }
                primul = false
                linieNoua(&out, indentare, nivel + 1)
                scrieSir(&out, k)
                out += indentare > 0 ? ": " : ":"
                v.scrie(&out, indentare: indentare, nivel: nivel + 1)
            }
            linieNoua(&out, indentare, nivel)
            out += "}"
        }
    }

    private func linieNoua(_ out: inout String, _ indentare: Int, _ nivel: Int) {
        guard indentare > 0 else { return }
        out += "\n" + String(repeating: " ", count: indentare * nivel)
    }

    private func scrieSir(_ out: inout String, _ s: String) {
        out += "\""
        for u in s.unicodeScalars {
            switch u {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\u{08}": out += "\\b"
            case "\u{0C}": out += "\\f"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            default:
                if u.value < 0x20 {
                    out += String(format: "\\u%04x", u.value)
                } else {
                    out.unicodeScalars.append(u)
                }
            }
        }
        out += "\""
    }
}

private struct CititorJSON {
    let octeti: [UInt8]
    var i = 0

    mutating func spatii() {
        while i < octeti.count, [0x20, 0x09, 0x0A, 0x0D].contains(octeti[i]) { i += 1 }
    }

    func eroare(_ m: String) -> EroareJSON { EroareJSON(mesaj: m, pozitie: i) }

    mutating func valoare() throws -> JSONValue {
        guard i < octeti.count else { throw eroare("sfârșit neașteptat") }
        switch octeti[i] {
        case UInt8(ascii: "{"): return try obiect()
        case UInt8(ascii: "["): return try lista()
        case UInt8(ascii: "\""): return .string(try sir())
        case UInt8(ascii: "t"): try cuvant("true"); return .bool(true)
        case UInt8(ascii: "f"): try cuvant("false"); return .bool(false)
        case UInt8(ascii: "n"): try cuvant("null"); return .null
        default: return .number(try numar())
        }
    }

    mutating func cuvant(_ w: String) throws {
        let b = Array(w.utf8)
        guard i + b.count <= octeti.count, Array(octeti[i..<i + b.count]) == b else { throw eroare("se aștepta \(w)") }
        i += b.count
    }

    mutating func obiect() throws -> JSONValue {
        i += 1
        var o = JSObiect()
        spatii()
        if i < octeti.count, octeti[i] == UInt8(ascii: "}") { i += 1; return .object(o) }
        while true {
            spatii()
            guard i < octeti.count, octeti[i] == UInt8(ascii: "\"") else { throw eroare("se aștepta o cheie") }
            let k = try sir()
            spatii()
            guard i < octeti.count, octeti[i] == UInt8(ascii: ":") else { throw eroare("se aștepta :") }
            i += 1
            spatii()
            o[k] = try valoare()
            spatii()
            guard i < octeti.count else { throw eroare("obiect neterminat") }
            if octeti[i] == UInt8(ascii: ",") { i += 1; continue }
            if octeti[i] == UInt8(ascii: "}") { i += 1; return .object(o) }
            throw eroare("se aștepta , sau }")
        }
    }

    mutating func lista() throws -> JSONValue {
        i += 1
        var a: [JSONValue] = []
        spatii()
        if i < octeti.count, octeti[i] == UInt8(ascii: "]") { i += 1; return .array(a) }
        while true {
            spatii()
            a.append(try valoare())
            spatii()
            guard i < octeti.count else { throw eroare("listă neterminată") }
            if octeti[i] == UInt8(ascii: ",") { i += 1; continue }
            if octeti[i] == UInt8(ascii: "]") { i += 1; return .array(a) }
            throw eroare("se aștepta , sau ]")
        }
    }

    mutating func hex4() throws -> UInt32 {
        guard i + 4 <= octeti.count, let v = UInt32(String(decoding: octeti[i..<i + 4], as: UTF8.self), radix: 16) else {
            throw eroare("\\u invalid")
        }
        i += 4
        return v
    }

    mutating func sir() throws -> String {
        i += 1
        var buf: [UInt8] = []
        while true {
            guard i < octeti.count else { throw eroare("text neterminat") }
            let c = octeti[i]
            if c == UInt8(ascii: "\"") { i += 1; break }
            if c == UInt8(ascii: "\\") {
                i += 1
                guard i < octeti.count else { throw eroare("escape neterminat") }
                let e = octeti[i]
                i += 1
                switch e {
                case UInt8(ascii: "\""): buf.append(0x22)
                case UInt8(ascii: "\\"): buf.append(0x5C)
                case UInt8(ascii: "/"): buf.append(0x2F)
                case UInt8(ascii: "b"): buf.append(0x08)
                case UInt8(ascii: "f"): buf.append(0x0C)
                case UInt8(ascii: "n"): buf.append(0x0A)
                case UInt8(ascii: "r"): buf.append(0x0D)
                case UInt8(ascii: "t"): buf.append(0x09)
                case UInt8(ascii: "u"):
                    var cod = try hex4()
                    if (0xD800...0xDBFF).contains(cod), i + 6 <= octeti.count,
                       octeti[i] == UInt8(ascii: "\\"), octeti[i + 1] == UInt8(ascii: "u") {
                        let salvat = i
                        i += 2
                        let jos = try hex4()
                        if (0xDC00...0xDFFF).contains(jos) {
                            cod = 0x10000 + ((cod - 0xD800) << 10) + (jos - 0xDC00)
                        } else {
                            i = salvat
                        }
                    }
                    let scalar = Unicode.Scalar(cod) ?? "\u{FFFD}"
                    buf.append(contentsOf: Array(String(Character(scalar)).utf8))
                default: throw eroare("escape necunoscut")
                }
                continue
            }
            buf.append(c)
            i += 1
        }
        return String(decoding: buf, as: UTF8.self)
    }

    mutating func numar() throws -> Double {
        let start = i
        while i < octeti.count, let c = Optional(octeti[i]),
              (c >= 0x30 && c <= 0x39) || c == UInt8(ascii: "-") || c == UInt8(ascii: "+")
                || c == UInt8(ascii: ".") || c == UInt8(ascii: "e") || c == UInt8(ascii: "E") {
            i += 1
        }
        guard i > start, let n = Double(String(decoding: octeti[start..<i], as: UTF8.self)) else {
            throw eroare("valoare invalidă")
        }
        return n
    }
}
