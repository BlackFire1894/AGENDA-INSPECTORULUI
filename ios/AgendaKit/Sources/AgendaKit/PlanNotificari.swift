import Foundation

// Notificările programate (decizia utilizatorului, 26.09.2026): termenele din specificație (tests/nativ/referinta.mjs
// → notificari, verificate pe vectori), plus rezumatul zilei, alegerea pe categorii și cifra de pe iconiță.

public enum CategorieNotificare: String, Codable, CaseIterable, Sendable {
    case amenzi, asi, incarcare, activitati, confirmare, backup, sarbatori, rezumat, expirare

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
        case .expirare: return "Expirarea instalării"
        }
    }

    /// când vin, pe scurt (Setări)
    public var detalii: String {
        switch self {
        case .amenzi: return "La schimbarea stadiului; termenul ANAF / Taxe și impozite, după regulile alese"
        case .asi: return "După regulile alese"
        case .incarcare: return "După regulile alese, în zilele lucrătoare"
        case .activitati: return "În ziua planificată"
        case .confirmare: return "A doua zi după activitate"
        case .backup: return "La 7 zile după ultimul backup"
        case .sarbatori: return "Verificarea listei pentru anul următor, ca în Panou"
        case .rezumat: return "În zilele lucrătoare, ce mai aveți de făcut"
        case .expirare: return "Cu 2 zile înainte ca aplicația instalată de pe Mac să expire (09:00)"
        }
    }

}

/// Preferințele de notificare ale acestui dispozitiv (nu intră în backup, ca preferințele din web).
/// Câmpurile lipsă (preferințe salvate de o versiune mai veche) primesc valorile implicite.
public struct SetariNotificari: Codable, Equatable, Sendable {
    public var oprite: Set<CategorieNotificare> = []
    /// ora rezumatului zilei, „HH:MM”
    public var oraRezumat = "07:45"
    /// ora notificărilor zilnice, pe categorii (lipsă = `oreImplicite`)
    public var ore: [String: String] = [:]
    /// programul de lucru, pentru „la fiecare N ore”
    public var programStart = "08:00"
    public var programSfarsit = "16:00"
    public var asi = SetariNotificari.implicitASI
    public var incarcare = SetariNotificari.implicitIncarcare
    /// amenzile: termenul ANAF
    public var anaf = SetariNotificari.implicitANAF
    /// amenzile: notificare în ziua în care se schimbă stadiul (termenul de plată expirat, de trimis la ANAF)
    public var schimbareStadiu = true
    /// activitățile cu oră: încă o notificare cu atâtea minute înainte (0 = fără)
    public var minuteInainte = 30

    public init() {}
    public func activa(_ c: CategorieNotificare) -> Bool { !oprite.contains(c) }

    private enum CodingKeys: String, CodingKey {
        case oprite, oraRezumat, ore, programStart, programSfarsit, asi, incarcare, anaf, schimbareStadiu, minuteInainte
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let i = SetariNotificari()
        oprite = (try? c.decodeIfPresent([String].self, forKey: .oprite)).flatMap { $0 }.map { Set($0.compactMap(CategorieNotificare.init(rawValue:))) } ?? i.oprite
        oraRezumat = (try? c.decodeIfPresent(String.self, forKey: .oraRezumat)).flatMap { $0 } ?? i.oraRezumat
        ore = (try? c.decodeIfPresent([String: String].self, forKey: .ore)).flatMap { $0 } ?? i.ore
        programStart = (try? c.decodeIfPresent(String.self, forKey: .programStart)).flatMap { $0 } ?? i.programStart
        programSfarsit = (try? c.decodeIfPresent(String.self, forKey: .programSfarsit)).flatMap { $0 } ?? i.programSfarsit
        asi = (try? c.decodeIfPresent(RegulaTermen.self, forKey: .asi)).flatMap { $0 } ?? i.asi
        incarcare = (try? c.decodeIfPresent(RegulaTermen.self, forKey: .incarcare)).flatMap { $0 } ?? i.incarcare
        anaf = (try? c.decodeIfPresent(RegulaTermen.self, forKey: .anaf)).flatMap { $0 } ?? i.anaf
        schimbareStadiu = (try? c.decodeIfPresent(Bool.self, forKey: .schimbareStadiu)).flatMap { $0 } ?? i.schimbareStadiu
        minuteInainte = (try? c.decodeIfPresent(Int.self, forKey: .minuteInainte)).flatMap { $0 } ?? i.minuteInainte
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(oprite.map(\.rawValue).sorted(), forKey: .oprite)
        try c.encode(oraRezumat, forKey: .oraRezumat)
        try c.encode(ore, forKey: .ore)
        try c.encode(programStart, forKey: .programStart)
        try c.encode(programSfarsit, forKey: .programSfarsit)
        try c.encode(asi, forKey: .asi)
        try c.encode(incarcare, forKey: .incarcare)
        try c.encode(anaf, forKey: .anaf)
        try c.encode(schimbareStadiu, forKey: .schimbareStadiu)
        try c.encode(minuteInainte, forKey: .minuteInainte)
    }
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

/// Avertizarea de expirare a instalării (cont Apple gratuit: 7 zile): la 09:00, cu 2 zile înainte de ziua expirării
/// (sau cu o zi înainte, dacă a trecut); nil dacă nu mai e timp. `dispozitiv`: „iPad-ul” / „telefonul”.
public func notificareExpirare(_ expira: Date, acum: Date, dispozitiv: String) -> NotificarePlanificata? {
    let zi = todayISO(expira)
    let ora = Ceas.calendar.dateComponents([.hour, .minute], from: expira)
    let cand = [addDays(zi, -2), addDays(zi, -1)].first { d in
        guard let t = Ceas.calendar.date(from: DateComponents(year: Int(d.prefix(4)), month: Int(d.dropFirst(5).prefix(2)), day: Int(d.suffix(2)), hour: 9)) else { return false }
        return t > acum && t < expira
    }
    guard let cand else { return nil }
    return NotificarePlanificata(
        id: "agenda-expirare-\(zi)", data: cand, ora: "09:00",
        titlu: "Aplicația expiră pe \(fmtDateLong(zi))",
        text: String(format: "Instalarea de pe Mac e valabilă până la ora %02d:%02d. Conectați %@ la Mac și faceți dublu-clic pe „Reinstalează Agenda” (pe Birou). Datele rămân.", ora.hour ?? 0, ora.minute ?? 0, dispozitiv),
        categorie: .expirare, insigna: nil, activitate: nil)
}

/// Toate notificările de programat, în ordinea timpului, cel mult `MAX_PROGRAMATE`: termenele după regulile alese
/// (`notificariDupaReguli`), sărbătorile legale (ca în referință), rezumatul zilei, actualizările cifrei de pe iconiță.
/// `acum`: momentul programării (notificările de azi trecute de oră nu se mai programează).
/// `expirare`: avertizarea de expirare a instalării; are loc rezervat, nu e împinsă afară de celelalte.
public func planNotificari(_ controls: [Control], _ activitati: [Activitate], _ meta: MetaNotificari, _ stare: StareNativa,
                           _ setari: SetariNotificari, acum: Date = Ceas.acum(), expirare: NotificarePlanificata? = nil) -> [NotificarePlanificata] {
    let azi = stare.azi
    let p = Ceas.calendar.dateComponents([.hour, .minute], from: acum)
    let oraAcum = String(format: "%02d:%02d", p.hour ?? 0, p.minute ?? 0)
    let insigne = Dictionary(stare.zile.map { ($0.data, $0.urgente) }, uniquingKeysWith: { a, _ in a })
    let viitor = { (data: String, ora: String) in data > azi || (data == azi && ora > oraAcum) }

    var out = notificariDupaReguli(controls, activitati, meta, azi, setari).filter { viitor($0.data, $0.ora) }
    if setari.activa(.sarbatori), let n = notificareSarbatori(meta, azi), viitor(n.data, n.ora) {
        out.append(NotificarePlanificata(id: n.id, data: n.data, ora: n.ora, titlu: n.titlu, text: n.text, categorie: .sarbatori,
                                         insigna: nil, activitate: nil))
    }
    for i in out.indices { out[i].insigna = insigne[out[i].data] }
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
    let exp = setari.activa(.expirare) ? expirare : nil
    let restul = Array(out.sortatStabil { compara($0.data + $0.ora, $1.data + $1.ora) }.prefix(MAX_PROGRAMATE - (exp == nil ? 0 : 1)))
    return (restul + [exp].compactMap { $0 }).sortatStabil { compara($0.data + $0.ora, $1.data + $1.ora) }
}
