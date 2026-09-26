import Foundation

// Widgeturile „Sarcini” (decizia utilizatorului, 26.09.2026): ce mai e de făcut într-o zi, cu aceleași elemente
// și texte ca secțiunile Panoului din web (js/views.js → viewDashboard): amenzi active, termene ASI, de încărcat,
// controale neîncheiate, netrecute în PV, activități de confirmat.

public enum GrupSarcina: String, Codable, CaseIterable, Sendable {
    case amenzi, asi, incarcare, neincheiate, pv, confirmare

    /// titlurile secțiunilor din Panou
    public var titlu: String {
        switch self {
        case .amenzi: return "Amenzi"
        case .asi: return "Termene ASI – 90 de zile"
        case .incarcare: return "De încărcat în aplicație"
        case .neincheiate: return "Controale neîncheiate"
        case .pv: return "Nereguli netrecute în procesul-verbal"
        case .confirmare: return "Activități de confirmat"
        }
    }

    /// eticheta scurtă (casetele din Panou), pentru widgeturi
    public var titluScurt: String {
        switch self {
        case .amenzi: return "Amenzi active"
        case .asi: return "Termene ASI"
        case .incarcare: return "De încărcat"
        case .neincheiate: return "Controale neîncheiate"
        case .pv: return "Netrecute în PV"
        case .confirmare: return "Activități de confirmat"
        }
    }

    /// iconița secțiunii din Panou
    public var iconita: String {
        switch self {
        case .amenzi: return "fine"
        case .asi: return "hourglass"
        case .incarcare: return "upload"
        case .neincheiate: return "clock"
        case .pv: return "pv"
        case .confirmare: return "calendar"
        }
    }
}

/// Un element de făcut, ca rândul din secțiunea Panoului
public struct Sarcina: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var grup: GrupSarcina
    /// culoarea: "red" | "yellow" | "blue" (stadiile amenzii), "warn", "open"
    public var nivel: String
    /// obiectivul (sau titlul activității)
    public var titlu: String
    /// ce anume: neregula, faza ASI, ce lipsește la încărcare, data începerii…
    public var ce: String
    /// pastila din dreapta: stadiul amenzii sau zilele rămase
    public var eticheta: String
    /// mesajul termenului, cuvânt cu cuvânt ca în web
    public var mesaj: String
    /// data termenului (AAAA-LL-ZZ), dacă există
    public var termen: String?
    public var zile: Int?
    /// intră în cifra „urgente” (iconița, widgetul mic)
    public var urgenta: Bool
    /// unde se deschide aplicația: „control/<id>/<tab>/<element>” sau „panou”
    public var legatura: String
}

/// `countdown()` din js/views.js, ca text: „3 zile rămase”, „ultima zi: azi”, „2 zile peste termen”
public func textRamas(_ zile: Int, lucratoare: Bool = false) -> String {
    let n = abs(zile)
    let u = "\(n == 1 ? "zi" : "zile")\(lucratoare && zile > 0 ? " lucrătoare" : "")"
    return zile < 0 ? "\(n) \(u) peste termen" : zile == 0 ? "ultima zi: azi" : "\(n) \(u) rămase"
}

private func nume(_ c: Control) -> String { c.denumire.isEmpty ? "Obiectiv fără denumire" : c.denumire }

/// Toate sarcinile dintr-o zi, pe grupe, în ordinea din Panou (în fiecare grupă, ordinea din Panou)
public func sarciniZi(_ controls: [Control], _ activitati: [Activitate], _ azi: String) -> [Sarcina] {
    var out: [Sarcina] = []
    // Amenzi active (achitatele nu intră), sortate după urgență, ca în Panou
    for f in allFines(controls, azi) where f.st.level != "green" {
        let c = f.c, n = f.n, st = f.st
        let multe = c.constructii.count > 1 && secOf(n) == "ner"
        out.append(Sarcina(
            id: "amenda-\(c.id)-\(n.key)", grup: .amenzi, nivel: st.level, titlu: nume(c),
            ce: "\(neregulaLetter(c, n)). \(constatareLabel(n))\(multe ? " · \(constructiiNume(c, n))" : "")",
            eticheta: st.label, mesaj: st.msg,
            termen: st.pending == true ? nil : (st.level == "blue" ? st.plataPana : st.anafPana), zile: st.daysLeft,
            urgenta: st.level == "red" || st.level == "yellow",
            legatura: "control/\(c.id)/\(tabOfNeregula(n))/\(n.key)"))
    }
    // Termene ASI (cele neîncepute, la controalele neîncheiate, rămân la final)
    for x in allAsi(controls, azi) {
        let c = x.c, a = x.a
        let pierdere = a.faza == "pierdere"
        out.append(Sarcina(
            id: "asi-\(c.id)", grup: .asi, nivel: "red", titlu: nume(c),
            ce: pierdere ? "Constatarea pierderii valabilității (5 zile după cele 90)" : "Termen ASI – 90 de zile",
            eticheta: a.pending == true ? "neînceput" : textRamas(a.daysLeft ?? 0), mesaj: a.msg,
            termen: pierdere ? a.termenPierdere : a.deadline, zile: a.daysLeft,
            urgenta: a.pending != true && (a.daysLeft ?? 1) <= 0,
            legatura: "control/\(c.id)/nereguli/a"))
    }
    // De încărcat: cele cu termenul depășit sau azi, primele
    let deInc = controls.compactMap { c in incarcareStatus(c, azi).flatMap { $0.gata ? nil : (c, $0) } }
        .sortatStabil { ($0.1.daysLeft ?? 0) - ($1.1.daysLeft ?? 0) }
    for (c, s) in deInc {
        out.append(Sarcina(
            id: "incarcare-\(c.id)", grup: .incarcare, nivel: s.level == "red" ? "red" : "warn", titlu: nume(c),
            ce: s.lipsa.map { ucfirst(K.lipsaIncarcareText($0)) }.joined(separator: ", "),
            eticheta: textRamas(s.daysLeft ?? 0, lucratoare: true), mesaj: s.msg ?? "",
            termen: s.termen, zile: s.daysLeft, urgenta: s.level == "red",
            legatura: "control/\(c.id)/obiectiv/sec-incarcare"))
    }
    // Controale neîncheiate: cele mai noi primele (ca în Panou)
    for c in controls.filter({ !isIncheiat($0) }).sortatStabil(byStartDesc) {
        let d = diffDays(c.dataInceput, azi)
        out.append(Sarcina(
            id: "neincheiat-\(c.id)", grup: .neincheiate, nivel: "open", titlu: nume(c),
            ce: "\(d < 0 ? "începe" : "început") \(fmtDateLong(c.dataInceput))",
            eticheta: d < 0 ? "începe peste \(zile(-d))" : d == 0 ? "început azi" : d == 1 ? "început ieri" : "de \(zile(d))",
            mesaj: "Lipsește data încheierii", termen: nil, zile: nil, urgenta: false,
            legatura: "control/\(c.id)/obiectiv"))
    }
    // Netrecute în PV
    for c in controls {
        for n in activeNereguli(c) where n.status == "nok" && !n.inPV {
            out.append(Sarcina(
                id: "pv-\(c.id)-\(n.key)", grup: .pv, nivel: "warn", titlu: nume(c),
                ce: "\(neregulaLetter(c, n)). \(constatareLabel(n))", eticheta: "Netrecut",
                mesaj: vecheInfo(controls, c, n).veche ? "Neregulă veche" : "", termen: nil, zile: nil, urgenta: false,
                legatura: "control/\(c.id)/\(tabOfNeregula(n))/\(n.key)"))
        }
    }
    // Activități de confirmat
    let obiective = Dictionary(objectives(controls).map { ($0.id, $0.denumire) }, uniquingKeysWith: { a, _ in a })
    for a in deConfirmat(activitati, azi) {
        let ob = a.objectiveId.isEmpty ? nil : obiective[a.objectiveId]
        out.append(Sarcina(
            id: "confirmare-\(a.id)", grup: .confirmare, nivel: "open", titlu: titluActivitate(a),
            ce: "\(cand(a))\(ob.map { " · \($0)" } ?? "")", eticheta: "Planificată",
            mesaj: "Marcați-o efectuată, reprogramați-o sau anulați-o", termen: sfarsitActivitate(a), zile: nil, urgenta: false,
            legatura: "panou"))
    }
    return out
}

/// Sarcinile după urgență (widgeturile mici): întâi cele urgente (aceeași regulă ca cifra de pe iconiță),
/// apoi cele cu termen, apoi activitățile de confirmat, netrecutele în PV și controalele neîncheiate;
/// la aceeași treaptă, termenul cel mai apropiat primul.
public func sarciniDupaUrgenta(_ l: [Sarcina]) -> [Sarcina] {
    func treapta(_ s: Sarcina) -> Int {
        if s.urgenta { return 0 }
        if s.termen != nil && s.grup != .confirmare { return 1 }
        switch s.grup {
        case .confirmare: return 2
        case .pv: return 3
        default: return 4
        }
    }
    return l.sortatStabil { a, b in
        let r = treapta(a) - treapta(b)
        if r != 0 { return r }
        return compara(a.termen ?? "9999-99-99", b.termen ?? "9999-99-99")
    }
}

// ───────── Datele pentru widgeturi (scrise în grupul comun) ─────────

public struct ZiWidget: Codable, Equatable, Sendable {
    public var data: String
    public var cifre: CifreZi
    public var sarcini: [Sarcina]
}

public struct DateWidget: Codable, Equatable, Sendable {
    public var v = 2
    public var generat: String
    public var zile: [ZiWidget]
    /// termenele următoare (widgetul mare „Cifre”), calculate la generare; cele trecute apar „depășit”
    public var urmatoare: [TermenUrmator]

    /// ziua de afișat: azi, dacă e în date; altfel ultima zi calculată (aplicația n-a mai fost deschisă)
    public func zi(_ azi: String) -> ZiWidget? {
        zile.first { $0.data == azi } ?? zile.last { $0.data <= azi } ?? zile.first
    }
}

public func dateWidget(_ controls: [Control], _ activitati: [Activitate], _ stare: StareNativa) -> DateWidget {
    DateWidget(generat: stare.generat,
               zile: stare.zile.map { ZiWidget(data: $0.data, cifre: $0, sarcini: sarciniZi(controls, activitati, $0.data)) },
               urmatoare: stare.urmatoare)
}

extension GrupComun {
    private static var fisierWidget: URL? { folderDate?.appendingPathComponent("widget.json") }

    public static func scrieWidget(_ d: DateWidget) throws {
        guard let url = fisierWidget else { throw CocoaError(.fileNoSuchFile) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(d).write(to: url, options: .atomic)
    }

    public static func citesteWidget() -> DateWidget? {
        guard let url = fisierWidget, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(DateWidget.self, from: data)
    }
}
