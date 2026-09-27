import Foundation

// Anulează / Refă, pe control, în sesiunea curentă (js/state.js → historyStart / checkpoint / historyMove).
// Se păstrează instantanee ale controlului (fără updatedAt). Un pas = o atingere, sau un text tastat până la
// o pauză / până la următoarea atingere. Nu se salvează între sesiuni.

public final class IstoricEditor {
    public static let LIMITA_PASI = 80

    private struct Stare {
        var baza: String
        var anulare: [String] = []
        var refacere: [String] = []
    }
    private var h: [String: Stare] = [:]

    public init() {}

    /// `JSON.stringify(c, (k, v) => (k === 'updatedAt' ? undefined : v))`
    static func instantaneu(_ c: Control) -> String { faraUpdatedAt(.object(c.o)).text() }

    private static func faraUpdatedAt(_ v: JSONValue) -> JSONValue {
        switch v {
        case .object(let o):
            var r = JSObiect()
            for (k, x) in o where k != "updatedAt" { r[k] = faraUpdatedAt(x) }
            return .object(r)
        case .array(let a): return .array(a.map(faraUpdatedAt))
        default: return v
        }
    }

    /// Punctul de plecare: controlul așa cum e la deschidere (înainte de prima modificare)
    public func start(_ c: Control) {
        if h[c.id] == nil { h[c.id] = Stare(baza: Self.instantaneu(c)) }
    }

    /// Închide pasul curent: dacă s-a schimbat ceva de la ultimul pas, starea anterioară intră în „Anulează”.
    @discardableResult
    public func checkpoint(_ c: Control) -> Bool {
        guard var s = h[c.id] else { return false }
        let cur = Self.instantaneu(c)
        if cur == s.baza { return false }
        s.anulare.append(s.baza)
        if s.anulare.count > Self.LIMITA_PASI { s.anulare.removeFirst() }
        s.refacere = []
        s.baza = cur
        h[c.id] = s
        return true
    }

    /// `historyState(id)`: câți pași se pot anula / reface
    public func stare(_ id: String) -> (anulare: Int, refacere: Int) {
        (h[id]?.anulare.count ?? 0, h[id]?.refacere.count ?? 0)
    }

    /// Un pas înapoi (anulare) sau înainte (refacere). Întoarce true dacă s-a schimbat ceva.
    /// Controlul se salvează ca atare (fără „touch”), cu updatedAt nou, ca în web.
    public func muta(_ c: inout Control, inapoi: Bool) -> Bool {
        checkpoint(c)   // textul tastat până acum devine un pas separat
        guard var s = h[c.id] else { return false }
        if inapoi {
            guard let x = s.anulare.popLast() else { return false }
            s.refacere.append(s.baza)
            s.baza = x
        } else {
            guard let x = s.refacere.popLast() else { return false }
            s.anulare.append(s.baza)
            s.baza = x
        }
        h[c.id] = s
        restaureaza(&c, s.baza)
        c.updatedAt = isoMs()
        return true
    }

    /// `restore(c, json)`: cheile care lipsesc din instantaneu se șterg, celelalte se înlocuiesc pe loc,
    /// cele noi se adaugă la sfârșit (Object.assign)
    private func restaureaza(_ c: inout Control, _ json: String) {
        guard let data = (try? JSONValue.citeste(json))?.obiect else { return }
        var o = c.o
        for k in o.chei where data[k] == nil { o[k] = nil }
        for (k, v) in data { o[k] = v }
        c.o = o
    }
}
