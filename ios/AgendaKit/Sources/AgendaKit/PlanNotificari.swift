import Foundation

// Notificările programate (decizia utilizatorului, 26.09.2026): termenele din specificație (tests/nativ/referinta.mjs
// → notificari, verificate pe vectori), plus rezumatul zilei, alegerea pe categorii și cifra de pe iconiță.

public enum CategorieNotificare: String, Codable, CaseIterable, Sendable {
    case amenzi, asi, incarcare, activitati, confirmare, backup, sarbatori, rezumat

    /// eticheta din Setări
    public var eticheta: String {
        switch self {
        case .amenzi: return "Amenzi"
        case .asi: return "Termene ASI"
        case .incarcare: return "Încărcarea în aplicație"
        case .activitati: return "Activități planificate"
        case .confirmare: return "Activități de confirmat"
        case .backup: return "Backup"
        case .sarbatori: return "Sărbătorile legale"
        case .rezumat: return "Rezumatul zilei"
        }
    }

    /// când vin, pe scurt (Setări)
    public var detalii: String {
        switch self {
        case .amenzi: return "La schimbarea stadiului; ziua dinainte și ultima zi pentru ANAF (08:00)"
        case .asi: return "Ziua dinainte și ultima zi (08:00)"
        case .incarcare: return "Ziua dinainte și ultima zi (08:00)"
        case .activitati: return "În dimineața zilei (07:30)"
        case .confirmare: return "A doua zi după activitate (09:00)"
        case .backup: return "La 7 zile după ultimul backup (17:00)"
        case .sarbatori: return "Verificarea listei pentru anul următor, ca în Panou"
        case .rezumat: return "În zilele lucrătoare, ce mai aveți de făcut"
        }
    }

    /// categoria unei notificări din referință, după identificator
    static func dupaId(_ id: String) -> CategorieNotificare? {
        let reguli: [(String, CategorieNotificare)] = [
            ("agenda-amenda-", .amenzi), ("agenda-anaf1-", .amenzi), ("agenda-anaf0-", .amenzi),
            ("agenda-asi1-", .asi), ("agenda-asi0-", .asi), ("agenda-inc1-", .incarcare), ("agenda-inc0-", .incarcare),
            ("agenda-actconf-", .confirmare), ("agenda-act-", .activitati), ("agenda-backup-", .backup), ("agenda-sarbatori-", .sarbatori),
        ]
        return reguli.first { id.hasPrefix($0.0) }?.1
    }
}

/// Preferințele de notificare ale acestui dispozitiv (nu intră în backup, ca preferințele din web)
public struct SetariNotificari: Codable, Equatable, Sendable {
    public var oprite: Set<CategorieNotificare> = []
    /// ora rezumatului zilei, „HH:MM”
    public var oraRezumat = "07:45"

    public init() {}
    public func activa(_ c: CategorieNotificare) -> Bool { !oprite.contains(c) }
}

/// O notificare de programat
public struct NotificarePlanificata: Equatable, Sendable {
    public var id: String
    public var data: String
    public var ora: String
    public var titlu: String
    public var text: String
    public var categorie: CategorieNotificare?
    /// cifra de pe iconiță în ziua respectivă (urgentele), dacă e cunoscută
    public var insigna: Int?
    /// activitatea la care se referă (butonul „Efectuată”)
    public var activitate: String?
    /// doar actualizează cifra de pe iconiță, fără mesaj
    public var doarInsigna: Bool { titlu.isEmpty && text.isEmpty }
}

public let MAX_PROGRAMATE = 60          // iOS păstrează 64; 4 locuri rămân pentru notificările amânate
let ZILE_REZUMAT = 14

private func plural2(_ n: Int, _ unu: String, _ multe: String) -> String { plural(n, unu, multe) }

/// Rezumatul zilei (titlu, text) din cifrele zilei; nil dacă nu e nimic de făcut
public func rezumatZi(_ z: CifreZi) -> (titlu: String, text: String)? {
    var p: [String] = []
    if z.amenziActive > 0 {
        let urg = z.amenzi.rosu + z.amenzi.galben
        p.append(plural2(z.amenziActive, "amendă activă", "amenzi active") + (urg > 0 ? " (\(urg) \(urg == 1 ? "urgentă" : "urgente"))" : ""))
    }
    if z.asi > 0 { p.append(plural2(z.asi, "termen ASI", "termene ASI") + (z.asiDepasite > 0 ? " (\(z.asiDepasite) \(z.asiDepasite == 1 ? "depășit" : "depășite"))" : "")) }
    if z.deIncarcat > 0 { p.append(plural2(z.deIncarcat, "control de încărcat", "controale de încărcat")) }
    if z.neincheiate > 0 { p.append(plural2(z.neincheiate, "control neîncheiat", "controale neîncheiate")) }
    if z.netrecute > 0 { p.append(plural2(z.netrecute, "constatare netrecută în PV", "constatări netrecute în PV")) }
    if z.deConfirmat > 0 { p.append(plural2(z.deConfirmat, "activitate de confirmat", "activități de confirmat")) }
    if p.isEmpty { return nil }
    let titlu = z.urgente > 0 ? "Ce mai aveți de făcut · \(z.urgente) \(z.urgente == 1 ? "urgentă" : "urgente")" : "Ce mai aveți de făcut"
    return (titlu, p.joined(separator: " · "))
}

/// Toate notificările de programat, în ordinea timpului, cel mult `MAX_PROGRAMATE`.
/// `acum`: momentul programării (notificările de azi trecute de oră nu se mai programează).
public func planNotificari(_ stare: StareNativa, _ setari: SetariNotificari, acum: Date = Ceas.acum()) -> [NotificarePlanificata] {
    let azi = stare.azi
    let p = Ceas.calendar.dateComponents([.hour, .minute], from: acum)
    let oraAcum = String(format: "%02d:%02d", p.hour ?? 0, p.minute ?? 0)
    let insigne = Dictionary(stare.zile.map { ($0.data, $0.urgente) }, uniquingKeysWith: { a, _ in a })
    let viitor = { (data: String, ora: String) in data > azi || (data == azi && ora > oraAcum) }

    var out: [NotificarePlanificata] = []
    for n in stare.notificari {
        let cat = CategorieNotificare.dupaId(n.id)
        guard let cat, setari.activa(cat), viitor(n.data, n.ora) else { continue }
        var act: String?
        if cat == .activitati || cat == .confirmare {
            // „agenda-act-<id>-<data>” / „agenda-actconf-<id>-<data>”
            let fara = n.id.dropFirst(cat == .activitati ? "agenda-act-".count : "agenda-actconf-".count)
            act = String(fara.dropLast(11))
        }
        out.append(NotificarePlanificata(id: n.id, data: n.data, ora: n.ora, titlu: n.titlu, text: n.text, categorie: cat,
                                         insigna: insigne[n.data], activitate: act))
    }
    if setari.activa(.rezumat) {
        for z in stare.zile.prefix(ZILE_REZUMAT) where zinelucratoare(z.data).isEmpty && viitor(z.data, setari.oraRezumat) {
            guard let r = rezumatZi(z) else { continue }
            out.append(NotificarePlanificata(id: "agenda-rezumat-\(z.data)", data: z.data, ora: setari.oraRezumat, titlu: r.titlu, text: r.text,
                                             categorie: .rezumat, insigna: z.urgente, activitate: nil))
        }
    }
    // cifra de pe iconiță se schimbă și în zilele fără nicio notificare: o actualizare fără mesaj, la 00:00
    let zileCuNotificari = Set(out.map(\.data))
    for (i, z) in stare.zile.enumerated() where i > 0 && z.urgente != stare.zile[i - 1].urgente && !zileCuNotificari.contains(z.data) {
        out.append(NotificarePlanificata(id: "agenda-insigna-\(z.data)", data: z.data, ora: "00:00", titlu: "", text: "",
                                         categorie: nil, insigna: z.urgente, activitate: nil))
    }
    return Array(out.sortatStabil { compara($0.data + $0.ora, $1.data + $1.ora) }.prefix(MAX_PROGRAMATE))
}
