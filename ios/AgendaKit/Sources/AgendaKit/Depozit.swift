import Foundation

/// Datele aplicației în afara controalelor și activităților (`meta` din web)
public struct Meta: Equatable, Sendable {
    /// „AAAA-LL-ZZTHH:MM”, momentul ultimului backup exportat
    public var lastBackup: String?
    /// anii pentru care lista sărbătorilor legale a fost verificată
    public var sarbatoriVerificate: [Int]

    public init(lastBackup: String? = nil, sarbatoriVerificate: [Int] = []) {
        self.lastBackup = lastBackup
        self.sarbatoriVerificate = sarbatoriVerificate
    }

    var json: JSONValue {
        .object(JSObiect([("lastBackup", lastBackup.map { .string($0) } ?? .null),
                          ("sarbatoriVerificate", .array(sarbatoriVerificate.map { .number(Double($0)) }))]))
    }

    init(_ o: JSObiect) {
        lastBackup = o["lastBackup"]?.sir
        sarbatoriVerificate = o.arr("sarbatoriVerificate").compactMap { $0.numar.map { Int($0) } }
    }
}

/// Salvarea pe disc, în containerul aplicației: câte un fișier JSON pe control (același format ca în backup),
/// `activitati.json` și `meta.json`. Scrierile sunt atomice (fișier nou, apoi înlocuire).
/// Un fișier pe control: o atingere rescrie ~40 KB, nu toate controalele.
public final class Depozit: @unchecked Sendable {
    public let folder: URL
    private var folderControale: URL { folder.appendingPathComponent("controale", isDirectory: true) }
    private var fisierActivitati: URL { folder.appendingPathComponent("activitati.json") }
    private var fisierMeta: URL { folder.appendingPathComponent("meta.json") }
    private let fm = FileManager.default

    public init(folder: URL) {
        self.folder = folder
        try? fm.createDirectory(at: folder.appendingPathComponent("controale", isDirectory: true), withIntermediateDirectories: true)
    }

    /// Application Support/Agenda din containerul aplicației
    public static func implicit() -> Depozit {
        let baza = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return Depozit(folder: baza.appendingPathComponent("Agenda", isDirectory: true))
    }

    private func numeFisier(_ id: String) -> String {
        var permise = CharacterSet.alphanumerics.intersection(CharacterSet(charactersIn: Unicode.Scalar(0)...Unicode.Scalar(127)))
        permise.insert(charactersIn: "-_")
        return (id.addingPercentEncoding(withAllowedCharacters: permise) ?? id) + ".json"
    }

    private func scrie(_ v: JSONValue, _ url: URL) throws {
        try v.date().write(to: url, options: .atomic)
    }

    // ───────── citire ─────────

    /// Controalele salvate, normalizate, în ordinea identificatorilor (ca IndexedDB din web).
    public func controale() -> [Control] {
        let fisiere = (try? fm.contentsOfDirectory(at: folderControale, includingPropertiesForKeys: nil)) ?? []
        return fisiere.filter { $0.pathExtension == "json" }
            .compactMap { try? Data(contentsOf: $0) }
            .compactMap { try? JSONValue.citeste($0).obiect }
            .map(normalizeControl)
            .sorted { $0.id < $1.id }
    }

    public func activitati() -> [Activitate] {
        guard let d = try? Data(contentsOf: fisierActivitati), let l = try? JSONValue.citeste(d).lista else { return [] }
        return l.compactMap(\.obiect).map(normalizeActivitate)
    }

    public func meta() -> Meta {
        guard let d = try? Data(contentsOf: fisierMeta), let o = try? JSONValue.citeste(d).obiect else { return Meta() }
        return Meta(o)
    }

    // ───────── scriere ─────────

    public func salveaza(_ c: Control) throws {
        try scrie(c.json, folderControale.appendingPathComponent(numeFisier(c.id)))
    }

    public func sterge(_ id: String) throws {
        let url = folderControale.appendingPathComponent(numeFisier(id))
        if fm.fileExists(atPath: url.path) { try fm.removeItem(at: url) }
    }

    /// Înlocuiește toate controalele (import, ștergerea tuturor datelor)
    public func inlocuiesteTot(_ list: [Control]) throws {
        let pastrate = Set(list.map { numeFisier($0.id) })
        for c in list { try salveaza(c) }
        let fisiere = (try? fm.contentsOfDirectory(at: folderControale, includingPropertiesForKeys: nil)) ?? []
        for f in fisiere where !pastrate.contains(f.lastPathComponent) { try fm.removeItem(at: f) }
    }

    public func salveazaActivitati(_ l: [Activitate]) throws {
        try scrie(.array(l.map(\.json)), fisierActivitati)
    }

    public func salveazaMeta(_ m: Meta) throws {
        try scrie(m.json, fisierMeta)
    }
}
