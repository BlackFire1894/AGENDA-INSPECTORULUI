import Foundation

// Regulile notificărilor, alese de utilizator (decizia din 27.09.2026). Implicit:
//   ASI: la fiecare 30 de zile; zilnic în ultimele 5 zile; la fiecare 3 ore (în program) în ultimele 2 zile;
//   încărcarea: zilnic; penultima zi la fiecare 3 ore; ultima zi la fiecare 2 ore (zile lucrătoare, ca termenul);
//   activitățile: în ziua planificată la 08:00, plus cu 30 de minute înainte de oră;
//   termenele depășite: o amintire pe zi (zilele lucrătoare), până la rezolvare; programul: 08:00–16:00.
// Preferințe ale dispozitivului (nu intră în backup, ca în web preferințele de afișare).

/// Cât de des vine notificarea într-o treaptă
public enum Frecventa: Codable, Equatable, Hashable, Sendable {
    /// o dată la N zile (1 = zilnic), la ora categoriei
    case zile(Int)
    /// la fiecare N ore, în programul de lucru (de la începutul programului)
    case ore(Int)
}

/// „În ultimele N zile până la termen: …” (ziua termenului e ultima zi; nil = toată perioada)
public struct Treapta: Codable, Equatable, Hashable, Sendable {
    public var ultimele: Int?
    public var frecventa: Frecventa
    public init(_ ultimele: Int?, _ frecventa: Frecventa) { self.ultimele = ultimele; self.frecventa = frecventa }
}

/// Regula unui termen (ASI, încărcare, ANAF): treptele și amintirea după termen
public struct RegulaTermen: Codable, Equatable, Sendable {
    public var trepte: [Treapta]
    /// după termen: o amintire pe zi, în zilele lucrătoare, până la rezolvare
    public var depasite: Bool
    public init(_ trepte: [Treapta], depasite: Bool) { self.trepte = trepte; self.depasite = depasite }

    /// treapta zilei cu `r` zile rămase (0 = ultima zi): cea mai strânsă care o cuprinde
    public func treapta(_ r: Int) -> Treapta? {
        trepte.filter { t in t.ultimele.map { r < $0 } ?? true }.min { ($0.ultimele ?? .max) < ($1.ultimele ?? .max) }
    }
}

extension SetariNotificari {
    public static let implicitASI = RegulaTermen([Treapta(nil, .zile(30)), Treapta(5, .zile(1)), Treapta(2, .ore(3))], depasite: true)
    public static let implicitIncarcare = RegulaTermen([Treapta(nil, .zile(1)), Treapta(2, .ore(3)), Treapta(1, .ore(2))], depasite: true)
    /// ANAF: ziua dinainte și ultima zi (ca până acum)
    public static let implicitANAF = RegulaTermen([Treapta(2, .zile(1))], depasite: true)
    public static let oreImplicite: [CategorieNotificare: String] = [
        .amenzi: "08:00", .asi: "08:00", .incarcare: "08:00", .activitati: "08:00", .confirmare: "09:00", .backup: "17:00",
    ]

    /// ora la care vin notificările zilnice ale categoriei
    public func ora(_ c: CategorieNotificare) -> String { ore[c.rawValue] ?? Self.oreImplicite[c] ?? "08:00" }
    public mutating func seteazaOra(_ c: CategorieNotificare, _ o: String) { ore[c.rawValue] = o }

    /// orele unei zile pentru „la fiecare N ore”: de la începutul programului, cât timp nu trece de sfârșit
    public func oreProgram(_ n: Int) -> [String] {
        let a = minute(programStart), b = minute(programSfarsit)
        guard n > 0, a <= b else { return [programStart] }
        return stride(from: a, through: b, by: n * 60).map { String(format: "%02d:%02d", $0 / 60, $0 % 60) }
    }

    public func regula(_ c: CategorieNotificare) -> RegulaTermen? {
        switch c {
        case .asi: return asi
        case .incarcare: return incarcare
        case .amenzi: return anaf
        default: return nil
        }
    }
}

func minute(_ hhmm: String) -> Int {
    let p = hhmm.split(separator: ":").compactMap { Int($0) }
    return (p.first ?? 0) * 60 + (p.count > 1 ? p[1] : 0)
}

private func nume(_ c: Control) -> String { c.denumire.isEmpty ? "Obiectiv fără denumire" : c.denumire }

// ───────── textele din Setări ─────────

/// „la fiecare 30 de zile · zilnic în ultimele 5 zile · la fiecare 3 ore în ultimele 2 zile (08:00–16:00)”
public func descriereRegula(_ r: RegulaTermen, _ s: SetariNotificari, lucratoare: Bool = false) -> String {
    let z = lucratoare ? { (n: Int) in plural(n, "zi lucrătoare", "zile lucrătoare") } : { zile($0) }
    var p: [String] = r.trepte.sorted { ($0.ultimele ?? .max) > ($1.ultimele ?? .max) }.map { t in
        let cand: String
        switch t.ultimele {
        case nil: cand = ""
        case 1?: cand = " în ultima zi"
        case let n?: cand = " în ultimele \(z(n))"
        }
        switch t.frecventa {
        case .zile(1): return "zilnic\(cand)"
        case .zile(let k): return "la fiecare \(zile(k))\(cand)"
        case .ore(let h): return "la fiecare \(plural(h, "oră", "ore"))\(cand) (\(s.programStart)–\(s.programSfarsit))"
        }
    }
    if r.depasite { p.append("zilnic după termen, până la rezolvare") }
    return p.joined(separator: " · ")
}

/// Explicația din Setări, după regulile alese
public func detaliiCategorie(_ c: CategorieNotificare, _ s: SetariNotificari) -> String {
    let o = s.ora(c)
    switch c {
    case .asi: return "Ora \(o): " + descriereRegula(s.asi, s)
    case .incarcare: return "Ora \(o), în zilele lucrătoare: " + descriereRegula(s.incarcare, s, lucratoare: true)
    case .amenzi:
        return "Ora \(o): " + ([s.schimbareStadiu ? "la schimbarea stadiului" : nil].compactMap { $0 } + ["ANAF: " + descriereRegula(s.anaf, s)]).joined(separator: " · ")
    case .activitati:
        return "În ziua planificată, la \(o)" + (s.minuteInainte > 0 ? " · cu \(plural(s.minuteInainte, "minut", "minute")) înainte de oră" : "")
    case .confirmare: return "A doua zi după activitate, la \(o)"
    case .backup: return "La 7 zile după ultimul backup, la \(o)"
    default: return c.detalii
    }
}

// ───────── notificările termenelor, după reguli ─────────

/// Toate notificările categoriilor cu reguli (amenzi, ASI, încărcare, activități, confirmări, backup), de azi încolo,
/// pe cel mult `orizont` zile. Ordinea: a timpului. Textele urmează referința (tests/nativ/referinta.mjs) acolo unde
/// regula e aceeași.
public func notificariDupaReguli(_ controls: [Control], _ activitati: [Activitate], _ meta: MetaNotificari, _ azi: String,
                                 _ s: SetariNotificari, orizont: Int = 120) -> [NotificarePlanificata] {
    var ev: [NotificarePlanificata] = []
    let capat = addDays(azi, orizont)
    func add(_ id: String, _ d: String, _ ora: String, _ cat: CategorieNotificare, _ titlu: String, _ text: String, _ act: String? = nil) {
        guard d >= azi, d <= capat, s.activa(cat) else { return }
        ev.append(NotificarePlanificata(id: "agenda-\(id)-\(d)-\(ora.replacingOccurrences(of: ":", with: ""))", data: d, ora: ora,
                                        titlu: titlu, text: text, categorie: cat, insigna: nil, activitate: act))
    }
    /// orele unei zile după treapta ei (nil: nicio notificare în ziua aceasta)
    func ore(_ r: RegulaTermen, _ rest: Int, _ cat: CategorieNotificare) -> [String]? {
        guard let t = r.treapta(rest) else { return nil }
        switch t.frecventa {
        case .zile(let k): return k > 0 && rest % k == 0 ? [s.ora(cat)] : nil
        case .ore(let h): return s.oreProgram(h)
        }
    }
    /// zilele lucrătoare din [de, pana]
    func lucratoare(_ de: String, _ pana: String) -> [String] {
        var l: [String] = [], d = de
        while d <= pana { if zinelucratoare(d).isEmpty { l.append(d) }; d = addDays(d, 1) }
        return l
    }
    let peste14 = addDays(azi, 14)   // amintirile de după termen: cele din următoarele 2 săptămâni (se reînnoiesc la deschidere)

    for c in controls {
        // amenzile: schimbarea stadiului (ca în referință), apoi termenul ANAF după reguli
        for n in activeNereguli(c) where n.status == "nok" && n.amenda.aplicata && !n.amenda.achitata {
            let cine = "\(nume(c)) · \(neregulaLetter(c, n)). \(constatareLabel(n))"
            let st0 = fineStatus(c, n, azi)
            guard let anaf = st0.anafPana else { continue }
            if s.schimbareStadiu {
                var prev = fineStatus(c, n, addDays(azi, -1)).level
                var d = azi
                while d <= min(anaf, capat) {
                    let st = fineStatus(c, n, d)
                    if st.level != prev {
                        let titlu = st.level == "yellow" ? "Amendă: termenul de plată a expirat" : st.level == "red" ? "Amendă: de trimis la ANAF" : "Amendă"
                        add("amenda-\(c.id)-\(n.key)", d, s.ora(.amenzi), .amenzi, titlu, "\(cine). \(st.msg)")
                    }
                    prev = st.level
                    d = addDays(d, 1)
                }
            }
            var d = max(azi, addDays(fineDate(c, n), 1))
            while d <= min(anaf, capat) {
                let r = diffDays(d, anaf)
                for o in ore(s.anaf, r, .amenzi) ?? [] {
                    let titlu = r == 0 ? "Amendă: azi e ultima zi pentru ANAF" : r == 1 ? "Amendă: mâine e ultima zi pentru ANAF"
                        : "Amendă: mai sunt \(zile(r)) pentru ANAF"
                    add("anaf-\(c.id)-\(n.key)", d, o, .amenzi, titlu, r == 0 ? "\(cine). \(fineStatus(c, n, d).msg)" : "\(cine). Termen: \(fmtDate(anaf))")
                }
                d = addDays(d, 1)
            }
            if s.anaf.depasite {
                for d in lucratoare(max(azi, addDays(anaf, 1)), peste14) {
                    add("anaf-dep-\(c.id)-\(n.key)", d, s.ora(.amenzi), .amenzi, "Amendă: termenul ANAF a trecut", "\(cine). \(fineStatus(c, n, d).msg)")
                }
            }
        }

        // ASI: 90 de zile de la încheiere, apoi 5 zile pentru constatarea pierderii valabilității (zile calendaristice)
        if let a = asiDeadline(c, azi), a.resolved != true, a.pending != true, let dl = a.deadline {
            let faze: [(String, String, String)] = [   // (început exclusiv, termen, ce)
                (c.dataIncheiere, dl, "prezentarea documentației ASI (90 de zile)"),
                (dl, addDays(dl, K.TERMEN_PIERDERE_ASI), "constatarea pierderii valabilității ASI"),
            ]
            for (inceput, t, ce) in faze {
                var d = max(azi, addDays(inceput, 1))
                while d <= min(t, capat) {
                    let r = diffDays(d, t)
                    for o in ore(s.asi, r, .asi) ?? [] {
                        let titlu = r == 0 ? "ASI: azi e ultima zi" : r == 1 ? "ASI: mâine e ultima zi" : "ASI: mai sunt \(zile(r))"
                        add("asi-\(c.id)", d, o, .asi, titlu, r == 0 ? "\(nume(c)): \(ce)" : "\(nume(c)): \(ce), până la \(fmtDateLong(t))")
                    }
                    d = addDays(d, 1)
                }
            }
            if s.asi.depasite {
                for d in lucratoare(max(azi, addDays(faze[1].1, 1)), peste14) {
                    add("asi-dep-\(c.id)", d, s.ora(.asi), .asi, "ASI: termen depășit", "\(nume(c)): \(asiDeadline(c, d)?.msg ?? "")")
                }
            }
        }

        // încărcarea: 3 zile lucrătoare de la încheiere; zilele rămase se numără în zile lucrătoare, ca în aplicație
        if let inc = incarcareStatus(c, azi), !inc.gata, let t = inc.termen {
            for d in lucratoare(max(azi, addDays(c.dataIncheiere, 1)), min(t, capat)) {
                let r = workingDaysBetween(d, t)
                for o in ore(s.incarcare, r, .incarcare) ?? [] {
                    let titlu = r == 0 ? "Încărcare: azi e ultima zi" : r == 1 ? "Încărcare: mai este 1 zi lucrătoare" : "Încărcare: mai sunt \(r) zile lucrătoare"
                    add("inc-\(c.id)", d, o, .incarcare, titlu,
                        r == 0 ? "\(nume(c)): încărcare în aplicație și document" : "\(nume(c)): încărcare în aplicație și document, până la \(fmtDateLong(t))")
                }
            }
            if s.incarcare.depasite {
                for d in lucratoare(max(azi, addDays(t, 1)), peste14) {
                    add("inc-dep-\(c.id)", d, s.ora(.incarcare), .incarcare, "Încărcare: termen depășit", "\(nume(c)): \(incarcareStatus(c, d)?.msg ?? "")")
                }
            }
        }
    }

    // activitățile planificate: în ziua lor; cu X minute înainte de oră; cele trecute neconfirmate: a doua zi
    for x in activitati where x.stare == "planificat" {
        add("act-\(x.id)", x.data, s.ora(.activitati), .activitati, "Activitate planificată azi",
            "\(titluActivitate(x))\(x.ora.isEmpty ? "" : ", ora \(x.ora)")", x.id)
        if s.minuteInainte > 0, !x.ora.isEmpty, minute(x.ora) >= s.minuteInainte {
            let m = minute(x.ora) - s.minuteInainte
            add("actmin-\(x.id)", x.data, String(format: "%02d:%02d", m / 60, m % 60), .activitati,
                "Activitate peste \(plural(s.minuteInainte, "minut", "minute"))", "\(titluActivitate(x)), ora \(x.ora)", x.id)
        }
        add("actconf-\(x.id)", addDays(sfarsitActivitate(x), 1), s.ora(.confirmare), .confirmare, "Activitate de confirmat",
            "\(titluActivitate(x)): marcați-o efectuată, reprogramați-o sau anulați-o", x.id)
    }
    // backupul: la 7 zile de la ultimul (sau azi, dacă nu există)
    if !controls.isEmpty {
        let ultim = meta.lastBackup.flatMap { $0.isEmpty ? nil : String($0.prefix(10)) }
        let cand = ultim.map { addDays($0, 7) > azi ? addDays($0, 7) : azi } ?? azi
        add("backup", cand, s.ora(.backup), .backup, "Faceți un backup",
            ultim.map { "Ultimul backup: \(fmtDate($0)). Datele există doar pe acest dispozitiv." }
                ?? "Nu ați făcut încă niciun backup. Datele există doar pe acest dispozitiv.")
    }
    return ev.sortatStabil { compara($0.data + $0.ora, $1.data + $1.ora) }
}
