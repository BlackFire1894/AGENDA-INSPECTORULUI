import Foundation

// Portarea din js/app.js (exportBackup, importBackup): același fișier, același nume, aceleași reguli.
// Un backup făcut în aplicația web se importă aici și invers.

public let APP_BACKUP = "agenda-inspectorului"

private func pad2(_ n: Int) -> String { n < 10 ? "0\(n)" : "\(n)" }

/// Momentul ultimului backup, ca în web: „AAAA-LL-ZZTHH:MM” (ora locală)
public func nowStamp(_ d: Date = Ceas.acum()) -> String {
    let p = Ceas.calendar.dateComponents([.hour, .minute], from: d)
    return "\(toISO(d))T\(pad2(p.hour!)):\(pad2(p.minute!))"
}

public struct FisierBackup: Sendable {
    public let nume: String
    public let text: String
}

/// `{ app, schema, exportedAt, controls, activitati }`, scris ca `JSON.stringify(payload, null, 1)`.
/// Adăugire nativă: `fotografii` = { id: JPEG în base64 }, doar dacă există (aplicația web ignoră cheia).
public func exportBackup(_ controls: [Control], _ activitati: [Activitate], fotografii: [String: Data] = [:],
                         acum: Date = Ceas.acum()) -> FisierBackup {
    var payload = JSObiect([
        ("app", .string(APP_BACKUP)), ("schema", .number(Double(SCHEMA_VERSION))), ("exportedAt", .string(isoMs(acum))),
        ("controls", .array(controls.map(\.json))), ("activitati", .array(activitati.map(\.json))),
    ])
    if !fotografii.isEmpty {
        payload["fotografii"] = .object(JSObiect(fotografii.keys.sorted().map { ($0, .string(fotografii[$0]!.base64EncodedString())) }))
    }
    let p = Ceas.calendar.dateComponents([.hour, .minute], from: acum)
    let nume = "agenda-inspectorului-backup-\(todayISO(acum))_\(pad2(p.hour!))-\(pad2(p.minute!)).json"
    return FisierBackup(nume: nume, text: JSONValue.object(payload).text(indentare: 1))
}

public enum EroareImport: Error, Equatable, Sendable {
    /// „Fișierul nu este un backup valid”
    case invalid
    /// „Fișierul nu este un backup al acestei aplicații”
    case strain

    public var mesaj: String {
        switch self {
        case .invalid: return "Fișierul nu este un backup valid"
        case .strain: return "Fișierul nu este un backup al acestei aplicații"
        }
    }
}

/// Conținutul unui backup, citit și normalizat, înainte de alegerea Combină / Înlocuiește tot.
public struct ImportPregatit: Sendable {
    public let controls: [Control]
    /// nil = backup mai vechi de v1.18, fără activități (cele de pe dispozitiv rămân)
    public let activitati: [Activitate]?
    /// `data.exportedAt`, dacă există
    public let exportedAt: String?
    /// fotografiile din backup (adăugire nativă): id → JPEG
    public var fotografii: [String: Data] = [:]

    /// „joi, 15 octombrie 2026” (ziua exportului, în ora locală), sau nil
    public var dataExportului: String? {
        guard let e = exportedAt, !e.isEmpty else { return nil }
        guard let d = dataISO(e) else { return "—" }
        return fmtDateLong(toISO(d))
    }
}

/// `new Date(text)` pentru momentele ISO scrise de aplicație (cu sau fără milisecunde)
func dataISO(_ s: String) -> Date? {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = f.date(from: s) { return d }
    f.formatOptions = [.withInternetDateTime]
    return f.date(from: s)
}

/// Citește fișierul și verifică dacă e un backup al aplicației (ca `importBackup` din web).
public func pregatesteImport(_ date: Data) throws -> ImportPregatit {
    var d = date
    if d.starts(with: [0xEF, 0xBB, 0xBF]) { d = d.dropFirst(3) }   // BOM (TextDecoder îl elimină)
    guard let data = try? JSONValue.citeste(d) else { throw EroareImport.invalid }
    let lista: [JSONValue]?
    if let a = data.lista { lista = a } else { lista = data.obiect?["controls"]?.lista }
    guard let lista else { throw EroareImport.strain }
    for c in lista {
        guard let o = c.obiect, o["id"]?.truthy == true, let di = o["dataInceput"]?.sir, isISO(di) else { throw EroareImport.strain }
    }
    let controls = lista.compactMap(\.obiect).map(normalizeControl)
    var activitati: [Activitate]?
    if let a = data.obiect?["activitati"]?.lista {
        activitati = a.compactMap(\.obiect).filter { o in o["id"]?.truthy == true && isISO(o["data"]?.sir ?? "") }.map(normalizeActivitate)
    }
    let e = data.obiect?["exportedAt"]
    var p = ImportPregatit(controls: controls, activitati: activitati, exportedAt: e?.truthy == true ? e!.textJS : nil)
    for (id, v) in data.obiect?.obj("fotografii") ?? JSObiect() {
        if idFotografieValid(id), let b = v.sir, let d = Data(base64Encoded: b) { p.fotografii[id] = d }
    }
    return p
}

/// „Combină”: adaugă cele noi; la cele existente păstrează versiunea modificată cel mai recent (`updatedAt`).
public func combina(_ existente: [Control], _ noi: [Control]) -> [Control] {
    var ordine = existente.map(\.id)
    var dupaId = Dictionary(existente.map { ($0.id, $0) }, uniquingKeysWith: { _, b in b })
    for c in noi {
        if let cur = dupaId[c.id] {
            if c.updatedAt > cur.updatedAt { dupaId[c.id] = c }
        } else {
            ordine.append(c.id)
            dupaId[c.id] = c
        }
    }
    var vazute = Set<String>()
    return ordine.filter { vazute.insert($0).inserted }.map { dupaId[$0]! }
}

public func combina(_ existente: [Activitate], _ noi: [Activitate]) -> [Activitate] {
    var ordine = existente.map(\.id)
    var dupaId = Dictionary(existente.map { ($0.id, $0) }, uniquingKeysWith: { _, b in b })
    for a in noi {
        if let cur = dupaId[a.id] {
            if a.updatedAt > cur.updatedAt { dupaId[a.id] = a }
        } else {
            ordine.append(a.id)
            dupaId[a.id] = a
        }
    }
    var vazute = Set<String>()
    return ordine.filter { vazute.insert($0).inserted }.map { dupaId[$0]! }
}
