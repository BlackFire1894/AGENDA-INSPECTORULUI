import Foundation

// Portarea din tests/nativ/referinta.mjs: cifrele pentru widgeturi (21 de zile), termenele următoare,
// notificările programate și cifra de pe iconiță. Rezultatul pentru setul demonstrativ: vectori/demo.json → nativ.

public let ZILE_WIDGET = 21          // câte zile în avans are widgetul cifrele gata calculate
let ZILE_NOTIFICARI = 75             // cât de departe se caută termene pentru notificări
let MAX_NOTIFICARI = 60              // iOS păstrează cel mult 64 de notificări programate

private func nume(_ c: Control) -> String { c.denumire.isEmpty ? "Obiectiv fără denumire" : c.denumire }

/// Cifrele Panoului într-o zi dată
public struct CifreZi: Codable, Equatable, Sendable {
    public struct Amenzi: Codable, Equatable, Sendable {
        public var rosu = 0, galben = 0, albastru = 0
    }
    public var data: String
    public var amenzi = Amenzi()
    public var asi = 0, asiDepasite = 0, deIncarcat = 0, incarcareUrgent = 0, neincheiate = 0, netrecute = 0, deConfirmat = 0
    public var amenziActive = 0
    /// amenzi la ANAF sau cu termenul expirat, ASI depășite, încărcare cu ultima zi azi / depășită
    public var urgente = 0

    public var json: JSONValue {
        let n = { (x: Int) in JSONValue.number(Double(x)) }
        return .object(JSObiect([
            ("data", .string(data)),
            ("amenzi", .object(JSObiect([("rosu", n(amenzi.rosu)), ("galben", n(amenzi.galben)), ("albastru", n(amenzi.albastru))]))),
            ("asi", n(asi)), ("asiDepasite", n(asiDepasite)), ("deIncarcat", n(deIncarcat)), ("incarcareUrgent", n(incarcareUrgent)),
            ("neincheiate", n(neincheiate)), ("netrecute", n(netrecute)), ("deConfirmat", n(deConfirmat)),
            ("amenziActive", n(amenziActive)), ("urgente", n(urgente)),
        ]))
    }
}

public func cifreZi(_ controls: [Control], _ activitati: [Activitate], _ d: String) -> CifreZi {
    var z = CifreZi(data: d)
    for c in controls {
        if !isIncheiat(c) { z.neincheiate += 1 }
        for n in activeNereguli(c) where n.status == "nok" {
            if !n.inPV { z.netrecute += 1 }
            if !n.amenda.aplicata { continue }
            switch fineStatus(c, n, d).level {
            case "red": z.amenzi.rosu += 1
            case "yellow": z.amenzi.galben += 1
            case "blue": z.amenzi.albastru += 1
            default: break
            }
        }
        if let a = asiDeadline(c, d), a.resolved != true, a.pending != true {
            z.asi += 1
            if (a.daysLeft ?? 0) <= 0 { z.asiDepasite += 1 }
        }
        if let inc = incarcareStatus(c, d), !inc.gata {
            z.deIncarcat += 1
            if inc.level == "red" { z.incarcareUrgent += 1 }
        }
    }
    z.deConfirmat = deConfirmat(activitati, d).count
    z.amenziActive = z.amenzi.rosu + z.amenzi.galben + z.amenzi.albastru
    z.urgente = z.amenzi.rosu + z.amenzi.galben + z.asiDepasite + z.incarcareUrgent
    return z
}

/// Un termen apropiat (widgetul mare): data, nivelul, ce e de făcut
public struct TermenUrmator: Codable, Equatable, Sendable {
    public var data: String, nivel: String, titlu: String, text: String
    public var json: JSONValue { ["data": .string(data), "nivel": .string(nivel), "titlu": .string(titlu), "text": .string(text)] }
}

func termeneUrmatoare(_ controls: [Control], _ azi: String) -> [TermenUrmator] {
    var out: [TermenUrmator] = []
    for c in controls {
        for n in activeNereguli(c) where n.status == "nok" && n.amenda.aplicata && !n.amenda.achitata {
            let st = fineStatus(c, n, azi)
            guard let anaf = st.anafPana, !anaf.isEmpty else { continue }
            let data = st.level == "blue" ? (st.plataPana ?? "") : anaf
            out.append(TermenUrmator(data: data, nivel: st.level, titlu: st.level == "blue" ? "Plata amenzii" : "Trimitere la ANAF",
                                     text: "\(nume(c)) · \(neregulaLetter(c, n))"))
        }
        if let a = asiDeadline(c, azi), a.resolved != true, a.pending != true {
            out.append(TermenUrmator(data: (a.faza == "pierdere" ? a.termenPierdere : a.deadline) ?? "", nivel: "red",
                                     titlu: a.faza == "pierdere" ? "ASI: pierderea valabilității" : "ASI 90 de zile", text: nume(c)))
        }
        if let inc = incarcareStatus(c, azi), !inc.gata {
            out.append(TermenUrmator(data: inc.termen ?? "", nivel: inc.level ?? "", titlu: "Încărcare în aplicație", text: nume(c)))
        }
    }
    return Array(out.filter { isISO($0.data) }.sortatStabil { compara($0.data, $1.data) }.prefix(8))
}

/// O notificare locală programată
public struct Notificare: Codable, Equatable, Sendable {
    public var id: String, data: String, ora: String, titlu: String, text: String
    public var json: JSONValue {
        ["id": .string(id), "data": .string(data), "ora": .string(ora), "titlu": .string(titlu), "text": .string(text)]
    }
}

/// Starea aplicației de care au nevoie notificările (din `meta` în web)
public struct MetaNotificari: Sendable {
    public var lastBackup: String?
    public var sarbatoriVerificate: [Int]
    public init(lastBackup: String? = nil, sarbatoriVerificate: [Int] = []) {
        self.lastBackup = lastBackup
        self.sarbatoriVerificate = sarbatoriVerificate
    }
}

func notificari(_ controls: [Control], _ activitati: [Activitate], _ meta: MetaNotificari, _ azi: String) -> [Notificare] {
    var ev: [Notificare] = []
    func add(_ id: String, _ data: String, _ ora: String, _ titlu: String, _ text: String) {
        if data >= azi { ev.append(Notificare(id: "agenda-\(id)-\(data)", data: data, ora: ora, titlu: titlu, text: text)) }
    }
    let zileN = (0..<ZILE_NOTIFICARI).map { addDays(azi, $0) }
    for c in controls {
        for n in activeNereguli(c) where n.status == "nok" && n.amenda.aplicata && !n.amenda.achitata {
            let cine = "\(nume(c)) · \(neregulaLetter(c, n)). \(constatareLabel(n))"
            var prev = fineStatus(c, n, addDays(azi, -1)).level
            for d in zileN {
                let st = fineStatus(c, n, d)
                let anaf = st.anafPana ?? ""
                if st.level != prev && !anaf.isEmpty {
                    let titlu = st.level == "yellow" ? "Amendă: termenul de plată a expirat" : st.level == "red" ? "Amendă: de trimis la ANAF" : "Amendă"
                    add("amenda-\(c.id)-\(n.key)", d, "08:00", titlu, "\(cine). \(st.msg)")
                }
                if !anaf.isEmpty && d == addDays(anaf, -1) {
                    add("anaf1-\(c.id)-\(n.key)", d, "08:00", "Amendă: mâine e ultima zi pentru ANAF", "\(cine). Termen: \(fmtDate(anaf))")
                }
                if !anaf.isEmpty && d == anaf {
                    add("anaf0-\(c.id)-\(n.key)", d, "08:00", "Amendă: azi e ultima zi pentru ANAF", "\(cine). \(st.msg)")
                }
                prev = st.level
            }
        }
        if let a = asiDeadline(c, azi), a.resolved != true, a.pending != true {
            let t = (a.faza == "pierdere" ? a.termenPierdere : a.deadline) ?? ""
            let ce = a.faza == "pierdere" ? "constatarea pierderii valabilității ASI" : "prezentarea documentației ASI (90 de zile)"
            if isISO(t) {
                add("asi1-\(c.id)", addDays(t, -1), "08:00", "ASI: mâine e ultima zi", "\(nume(c)): \(ce), până la \(fmtDateLong(t))")
                add("asi0-\(c.id)", t, "08:00", "ASI: azi e ultima zi", "\(nume(c)): \(ce)")
            }
        }
        if let inc = incarcareStatus(c, azi), !inc.gata, let termen = inc.termen {
            add("inc1-\(c.id)", addDays(termen, -1), "08:00", "Încărcare: mâine e ultima zi",
                "\(nume(c)): încărcare în aplicație și document, până la \(fmtDateLong(termen))")
            add("inc0-\(c.id)", termen, "08:00", "Încărcare: azi e ultima zi", "\(nume(c)): încărcare în aplicație și document")
        }
    }
    // activitățile planificate: în dimineața zilei; cele trecute neconfirmate: a doua zi
    for x in activitati where x.stare == "planificat" {
        add("act-\(x.id)", x.data, "07:30", "Activitate planificată azi", "\(titluActivitate(x))\(x.ora.isEmpty ? "" : ", ora \(x.ora)")")
        add("actconf-\(x.id)", addDays(sfarsitActivitate(x), 1), "09:00", "Activitate de confirmat",
            "\(titluActivitate(x)): marcați-o efectuată, reprogramați-o sau anulați-o")
    }
    // backupul: la 7 zile de la ultimul (sau azi, dacă nu există)
    if !controls.isEmpty {
        let ultim = meta.lastBackup.flatMap { $0.isEmpty ? nil : String($0.prefix(10)) }
        let candB = ultim.map { addDays($0, 7) > azi ? addDays($0, 7) : azi } ?? azi
        add("backup", candB, "17:00", "Faceți un backup",
            ultim.map { "Ultimul backup: \(fmtDate($0)). Datele există doar pe acest dispozitiv." }
                ?? "Nu ați făcut încă niciun backup. Datele există doar pe acest dispozitiv.")
    }
    // sărbătorile legale: ca în Panou — în decembrie pentru anul următor, în ianuarie pentru anul curent
    let y = Int(azi.prefix(4)) ?? 0
    let m = Int(azi.dropFirst(5).prefix(2)) ?? 0
    let verificate = meta.sarbatoriVerificate
    let an: Int? = m == 12 ? y + 1 : m == 1 ? y : nil
    func sarb(_ a: Int, _ d: String, _ ora: String) {
        add("sarbatori-\(a)", d, ora, "Sărbătorile legale \(a): verificați lista",
            "Verificați în Panou lista sărbătorilor legale pentru \(a): termenele țin cont de ele.")
    }
    if let an, !verificate.contains(an) { sarb(an, azi, "18:00") }
    else if an == nil && !verificate.contains(y + 1) { sarb(y + 1, "\(y)-12-01", "09:00") }
    return Array(ev.sortatStabil { compara($0.data + $0.ora, $1.data + $1.ora) }.prefix(MAX_NOTIFICARI))
}

/// Tot ce primesc widgeturile, notificările și iconița
public struct StareNativa: Codable, Equatable, Sendable {
    public var v = 1
    public var generat: String
    public var azi: String
    public var zile: [CifreZi]
    public var urmatoare: [TermenUrmator]
    public var notificari: [Notificare]
    public var insigna: Int

    public var json: JSONValue {
        .object(JSObiect([
            ("v", .number(Double(v))), ("generat", .string(generat)), ("azi", .string(azi)),
            ("zile", .array(zile.map(\.json))), ("urmatoare", .array(urmatoare.map(\.json))),
            ("notificari", .array(notificari.map(\.json))), ("insigna", .number(Double(insigna))),
        ]))
    }
}

public func stareNativa(_ controls: [Control], _ activitati: [Activitate], _ meta: MetaNotificari, _ azi: String, _ acum: Date = Ceas.acum()) -> StareNativa {
    let zile = (0..<ZILE_WIDGET).map { cifreZi(controls, activitati, addDays(azi, $0)) }
    return StareNativa(generat: isoMs(acum), azi: azi, zile: zile, urmatoare: termeneUrmatoare(controls, azi),
                       notificari: notificari(controls, activitati, meta, azi), insigna: zile[0].urgente)
}
