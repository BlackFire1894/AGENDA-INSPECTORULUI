import Foundation

// Portarea js/dates.js: date calendaristice ca șiruri „AAAA-LL-ZZ”, termene, zile nelucrătoare.
// Aritmetica e pe calendarul gregorian, fără oră (imună la ora de vară), ca în web.

private func pad2(_ n: Int) -> String { n < 10 ? "0\(n)" : "\(n)" }

// Numărul zilei de la 1970-01-01 (algoritmul „days from civil”); ziua și luna pot depăși limitele, ca Date.UTC.
func zileDinCivil(_ an: Int, _ luna: Int, _ zi: Int) -> Int {
    // luna normalizată în 1…12, cu anul ajustat (Date.UTC(an, luna - 1, zi))
    let l0 = luna - 1
    let y0 = an + Int((Double(l0) / 12).rounded(.down))
    let m = ((l0 % 12) + 12) % 12 + 1
    let y = m <= 2 ? y0 - 1 : y0
    let era = (y >= 0 ? y : y - 399) / 400
    let yoe = y - era * 400
    let mp = (m + 9) % 12
    let doy = (153 * mp + 2) / 5 + zi - 1
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
    return era * 146097 + doe - 719468
}

func civilDinZile(_ z: Int) -> (an: Int, luna: Int, zi: Int) {
    let z = z + 719468
    let era = (z >= 0 ? z : z - 146096) / 146097
    let doe = z - era * 146097
    let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
    let y = yoe + era * 400
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
    let mp = (5 * doy + 2) / 153
    let d = doy - (153 * mp + 2) / 5 + 1
    let m = mp < 10 ? mp + 3 : mp - 9
    return (m <= 2 ? y + 1 : y, m, d)
}

private func parti(_ iso: String) -> (Int, Int, Int) {
    let p = iso.split(separator: "-", omittingEmptySubsequences: false).map { Int($0) ?? 0 }
    return (p.count > 0 ? p[0] : 0, p.count > 1 ? p[1] : 0, p.count > 2 ? p[2] : 0)
}

private func isoDin(_ an: Int, _ luna: Int, _ zi: Int) -> String { "\(an)-\(pad2(luna))-\(pad2(zi))" }

/// Ziua săptămânii ca `Date.getDay()`: 0 = duminică … 6 = sâmbătă.
func ziSaptamana(_ iso: String) -> Int {
    let (y, m, d) = parti(iso)
    let z = zileDinCivil(y, m, d)
    return ((z % 7) + 7 + 4) % 7   // 1970-01-01 a fost joi
}

public func toISO(_ d: Date) -> String {
    let p = Ceas.calendar.dateComponents([.year, .month, .day], from: d)
    return isoDin(p.year!, p.month!, p.day!)
}

public func todayISO(_ now: Date = Ceas.acum()) -> String { toISO(now) }

public func isISO(_ s: String) -> Bool {
    let u = Array(s.utf8)
    guard u.count == 10, u[4] == 0x2D, u[7] == 0x2D else { return false }
    for (i, c) in u.enumerated() where i != 4 && i != 7 {
        if c < 0x30 || c > 0x39 { return false }
    }
    return true
}

public func diffDays(_ de: String, _ pana: String) -> Int {
    let (a, b, c) = parti(de), (x, y, z) = parti(pana)
    return zileDinCivil(x, y, z) - zileDinCivil(a, b, c)
}

public func addDays(_ iso: String, _ n: Int) -> String {
    let (y, m, d) = parti(iso)
    let r = civilDinZile(zileDinCivil(y, m, d + n))
    return isoDin(r.an, r.luna, r.zi)
}

func zileInLuna(_ an: Int, _ luna: Int) -> Int {
    zileDinCivil(an, luna + 1, 1) - zileDinCivil(an, luna, 1)
}

/// + n luni; ziua se limitează la ultima zi a lunii (31.01 + 1 lună = 28/29.02)
public func addMonths(_ iso: String, _ n: Int) -> String {
    let (y, m, d) = parti(iso)
    let t = civilDinZile(zileDinCivil(y, m + n, 1))
    return isoDin(t.an, t.luna, min(d, zileInLuna(t.an, t.luna)))
}

public func fmtDate(_ iso: String) -> String {
    guard isISO(iso) else { return "—" }
    let p = iso.split(separator: "-")
    return "\(p[2]).\(p[1]).\(p[0])"
}

public func fmtDateLong(_ iso: String) -> String {
    guard isISO(iso) else { return "—" }
    let (y, m, d) = parti(iso)
    return "\(K.zileSaptamana[ziSaptamana(iso)]), \(d) \(K.luni[m - 1]) \(y)"
}

public func ucfirst(_ s: String) -> String {
    guard let c = s.first else { return s }
    return String(c).uppercased() + s.dropFirst()
}

public func fmtDateMedium(_ iso: String) -> String {
    guard isISO(iso) else { return "—" }
    let (y, m, d) = parti(iso)
    return "\(d) \(K.luniScurt[m - 1]) \(y)"
}

/// În română: „20 de zile”, „100 de zile”, „120 de zile”, dar „101 zile”, „115 zile”.
public func plural(_ n: Int, _ unu: String, _ multe: String) -> String {
    let a = abs(n)
    if a == 1 { return "\(n) \(unu)" }
    let r = a % 100
    let de = a != 0 && (r == 0 || r >= 20) ? "de " : ""
    return "\(n) \(de)\(multe)"
}
public func zile(_ n: Int) -> String { plural(n, "zi", "zile") }

// ───────── Căutarea după dată ─────────

public enum CerereData: Equatable, Sendable {
    case zi(String)
    case luna(an: Int, luna: Int)
    case an(Int)
}

private func grupuri(_ s: String, _ tipar: String) -> [String]? {
    guard let re = try? NSRegularExpression(pattern: tipar),
          let m = re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) else { return nil }
    return (1..<m.numberOfRanges).map { i in
        Range(m.range(at: i), in: s).map { String(s[$0]) } ?? ""
    }
}

/// Interpretează textul introdus ca dată (zi, lună sau an); nil dacă nu e o dată.
public func parseDateQuery(_ q: String, _ now: Date = Ceas.acum()) -> CerereData? {
    let s = q.trimmingCharacters(in: .whitespacesAndNewlines)
    func mkDay(_ y0: Int, _ mo: Int, _ d: Int) -> CerereData? {
        if mo < 1 || mo > 12 || d < 1 || d > 31 { return nil }
        let y = (0...99).contains(y0) ? y0 + 1900 : y0   // new Date(99, …) = 1999, ca în JS
        if d > zileInLuna(y, mo) { return nil }
        return .zi(isoDin(y, mo, d))
    }
    if let m = grupuri(s, "^([0-9]{4})-([0-9]{1,2})-([0-9]{1,2})$") {
        return mkDay(Int(m[0])!, Int(m[1])!, Int(m[2])!)
    }
    if let m = grupuri(s, "^([0-9]{1,2})[./-]([0-9]{1,2})[./-]([0-9]{2}|[0-9]{4})$") {
        var y = Int(m[2])!
        if y < 100 { y += 2000 }
        return mkDay(y, Int(m[1])!, Int(m[0])!)
    }
    if let m = grupuri(s, "^([0-9]{1,2})[./-]([0-9]{1,2})$") {
        let anCurent = Ceas.calendar.component(.year, from: now)
        return mkDay(anCurent, Int(m[1])!, Int(m[0])!)
    }
    if let m = grupuri(s, "^([0-9]{1,2})[./-]([0-9]{4})$") {
        let mo = Int(m[0])!
        if mo >= 1 && mo <= 12 { return .luna(an: Int(m[1])!, luna: mo) }
    }
    if let m = grupuri(s, "^(20[0-9]{2})$") { return .an(Int(m[0])!) }
    return nil
}

/// Intervalul [start, end] acoperit de o căutare după dată.
public func queryRange(_ dq: CerereData) -> (String, String) {
    switch dq {
    case .zi(let iso): return (iso, iso)
    case .luna(let an, let luna):
        let start = "\(an)-\(pad2(luna))-01"
        let end = addDays(luna == 12 ? "\(an + 1)-01-01" : "\(an)-\(pad2(luna + 1))-01", -1)
        return (start, end)
    case .an(let an): return ("\(an)-01-01", "\(an)-12-31")
    }
}

public func rangesOverlap(_ a1: String, _ a2: String, _ b1: String, _ b2: String) -> Bool {
    a1 <= b2 && b1 <= a2
}

// ───────── Zile nelucrătoare (România) ─────────

/// Paștele ortodox: algoritmul Meeus (calendar iulian) + 13 zile (valabil 1900–2099).
public func pasteOrtodox(_ an: Int) -> String {
    let a = an % 4, b = an % 7, c = an % 19
    let d = (19 * c + 15) % 30
    let e = (2 * a + 4 * b - d + 34) % 7
    let luna = (d + e + 114) / 31
    let zi = ((d + e + 114) % 31) + 1
    return addDays(isoDin(an, luna, zi), 13)
}

/// Sărbătorile legale ale anului, în ordinea din Codul muncii (art. 139); două în aceeași zi: „A / B”.
public struct Sarbatori: Sendable {
    public let lista: [(data: String, nume: String)]
    private let dupaData: [String: String]
    init(_ l: [(String, String)]) {
        var lista: [(data: String, nume: String)] = []
        var dupa: [String: String] = [:]
        for (d, nume) in l {
            if let v = dupa[d] {
                dupa[d] = "\(v) / \(nume)"
                if let i = lista.firstIndex(where: { $0.data == d }) { lista[i].nume = dupa[d]! }
            } else {
                dupa[d] = nume
                lista.append((d, nume))
            }
        }
        self.lista = lista
        dupaData = dupa
    }
    public func get(_ d: String) -> String? { dupaData[d] }
}

private let cacheSarbatori = CacheSarbatori()
private final class CacheSarbatori: @unchecked Sendable {
    private var ani: [Int: Sarbatori] = [:]
    private let lacat = NSLock()
    func get(_ an: Int, _ fa: () -> Sarbatori) -> Sarbatori {
        lacat.lock(); defer { lacat.unlock() }
        if let s = ani[an] { return s }
        let s = fa()
        ani[an] = s
        return s
    }
}

public func sarbatoriLegale(_ an: Int) -> Sarbatori {
    cacheSarbatori.get(an) {
        let p = pasteOrtodox(an)
        return Sarbatori([
            ("\(an)-01-01", "Anul Nou"), ("\(an)-01-02", "Anul Nou"),
            ("\(an)-01-06", "Boboteaza"), ("\(an)-01-07", "Sfântul Ioan Botezătorul"),
            ("\(an)-01-24", "Ziua Unirii"),
            (addDays(p, -2), "Vinerea Mare"), (p, "Paștele"), (addDays(p, 1), "a doua zi de Paște"),
            ("\(an)-05-01", "Ziua Muncii"), ("\(an)-06-01", "Ziua Copilului"),
            (addDays(p, 49), "Rusaliile"), (addDays(p, 50), "a doua zi de Rusalii"),
            ("\(an)-08-15", "Adormirea Maicii Domnului"), ("\(an)-11-30", "Sfântul Andrei"),
            ("\(an)-12-01", "Ziua Națională"), ("\(an)-12-25", "Crăciunul"), ("\(an)-12-26", "a doua zi de Crăciun"),
        ])
    }
}

/// Motivul pentru care ziua e nelucrătoare („sâmbătă”, „sărbătoare legală – Crăciunul”), altfel "".
public func zinelucratoare(_ iso: String) -> String {
    guard isISO(iso) else { return "" }
    if let s = sarbatoriLegale(Int(iso.prefix(4))!).get(iso) { return "sărbătoare legală – \(s)" }
    switch ziSaptamana(iso) {
    case 6: return "sâmbătă"
    case 0: return "duminică"
    default: return ""
    }
}

/// + n zile lucrătoare (fără weekend și sărbători legale); ziua de pornire nu se numără.
public func addWorkingDays(_ iso: String, _ n: Int) -> String {
    var d = iso
    var k = 0
    while k < n {
        d = addDays(d, 1)
        if zinelucratoare(d).isEmpty { k += 1 }
    }
    return d
}

/// Zilele lucrătoare din intervalul (de la, până la].
public func workingDaysBetween(_ de: String, _ pana: String) -> Int {
    var n = 0
    var d = addDays(de, 1)
    while d <= pana {
        if zinelucratoare(d).isEmpty { n += 1 }
        d = addDays(d, 1)
    }
    return n
}

/// Prima zi lucrătoare după o zi (recomandare; termenele afișate nu se mută).
public func nextWorkingDay(_ iso: String) -> String {
    var d = addDays(iso, 1)
    while !zinelucratoare(d).isEmpty { d = addDays(d, 1) }
    return d
}
