import Foundation

// Portarea din js/views.js → viewDashboard: conținutul Panoului, ca model fără interfață.

public enum SectiunePanou: String, Sendable, CaseIterable { case amenzi, asi, incarcare, neincheiate, pv }

/// Un rând din secțiunile Panoului (`.item`)
public struct ElementPanou: Equatable, Sendable, Identifiable {
    public let id: String
    /// culoarea benzii: red, yellow, blue, green, warn, open
    public let nivel: String
    public let titlu: String
    /// rânduri secundare (gri); primul poate fi îngroșat (`subIngrosat`)
    public let sub: [String]
    public var subIngrosat = false
    /// pastilele din corpul rândului (încărcarea: ce lipsește)
    public var pastileCorp: [PastilaUI] = []
    public let mesaj: String?
    /// avertizarea pentru ziua nelucrătoare („⚠ …”)
    public var avertizare: String? = nil
    public var veche = false
    /// dreapta: pastile și/sau numărătoarea
    public var pastileDreapta: [PastilaUI] = []
    public var suma: String? = nil
    public var numaratoare: Numaratoare? = nil
    /// unde duce atingerea: control, tab, element
    public let control: String
    public let tab: String
    public let focus: String?
}

/// `countdown(days)`: cifra mare și textul mic
public struct Numaratoare: Equatable, Sendable {
    public let numar: Int
    public let text: String
    public let depasit: Bool
}

public func numaratoare(_ zile: Int, lucratoare: Bool = false) -> Numaratoare {
    let n = abs(zile)
    let u = "\(n == 1 ? "zi" : "zile")\(lucratoare && zile > 0 ? " lucrătoare" : "")"
    return Numaratoare(numar: n, text: zile < 0 ? "\(u) peste termen" : zile == 0 ? "ultima zi: azi" : "\(u) rămase", depasit: zile <= 0)
}

public struct CasetaPanou: Equatable, Sendable {
    public let sectiune: SectiunePanou
    public let iconita: String
    public let numar: Int
    public let eticheta: String
    /// bara amenzilor (roșu, galben, albastru), doar la amenzi active
    public let bara: [(String, Int)]?
    /// legenda scrisă (amenzi)
    public let legenda: [(String, Int, String)]
    public let subsol: [String]

    public static func == (a: CasetaPanou, b: CasetaPanou) -> Bool {
        a.sectiune == b.sectiune && a.numar == b.numar && a.eticheta == b.eticheta && a.subsol == b.subsol
            && a.legenda.map { "\($0.0)\($0.1)\($0.2)" } == b.legenda.map { "\($0.0)\($0.1)\($0.2)" }
            && (a.bara ?? []).map { "\($0.0)\($0.1)" } == (b.bara ?? []).map { "\($0.0)\($0.1)" }
    }
}

public struct SectiuneModelPanou: Equatable, Sendable {
    public let sectiune: SectiunePanou
    public let titlu: String
    public let iconita: String
    public let elemente: [ElementPanou]
    /// textul când e goală
    public let gol: String
    /// amenzile achitate (lista restrânsă „Achitate (n)”)
    public var achitate: [ElementPanou] = []
}

/// Mementoul sărbătorilor legale (din 1 decembrie, și în ianuarie dacă n-a fost confirmată lista)
public struct MementoSarbatori: Equatable, Sendable {
    public let an: Int
    public let titlu: String
    public let text: String
    public let rezumat: String
    public let lista: [(data: String, nume: String)]
    public let buton: String

    public static func == (a: MementoSarbatori, b: MementoSarbatori) -> Bool { a.an == b.an && a.text == b.text }
}

public struct ModelPanou: Sendable {
    public let data: String
    /// nil = nicio dată: ecranul de bun venit
    public let casete: [CasetaPanou]?
    public let sarbatori: MementoSarbatori?
    public let deConfirmat: [Activitate]
    /// secțiunile, cele cu elemente primele (ordinea fixă: amenzi → ASI → încărcare → neîncheiate → PV)
    public let sectiuni: [SectiuneModelPanou]
}

func anSarbatoriDeVerificat(_ t: String, _ verificate: [Int]) -> Int? {
    let y = Int(t.prefix(4)) ?? 0
    let m = Int(t.dropFirst(5).prefix(2)) ?? 0
    let an: Int? = m == 12 ? y + 1 : m == 1 ? y : nil
    guard let an, !verificate.contains(an) else { return nil }
    return an
}

public func mementoSarbatori(_ t: String, _ verificate: [Int]) -> MementoSarbatori? {
    guard let an = anSarbatoriDeVerificat(t, verificate) else { return nil }
    let l = sarbatoriLegale(an).lista.sorted { $0.data < $1.data }
    return MementoSarbatori(
        an: an, titlu: "Sărbătorile legale pentru \(an): verificați lista",
        text: "Termenele (plată, ANAF / Taxe și impozite, ASI, încărcare) țin cont de zilele nelucrătoare. Aplicația calculează singură sărbătorile legale pentru \(an), după art. 139 din Codul muncii. Verificați dacă legea s-a schimbat față de lista de mai jos; dacă da, cereți actualizarea aplicației.",
        rezumat: "Lista pentru \(an) (\(l.count) zile)", lista: l.map { (fmtDateLong($0.data), $0.nume) }, buton: "Am verificat lista pentru \(an)")
}

private func nume(_ c: Control) -> String { c.denumire.isEmpty ? "Obiectiv fără denumire" : c.denumire }

public func modelPanou(_ cs: [Control], _ activitati: [Activitate], _ meta: Meta, azi t: String) -> ModelPanou {
    let sarb = mementoSarbatori(t, meta.sarbatoriVerificate)
    let conf = deConfirmat(activitati, t)
    if cs.isEmpty {
        return ModelPanou(data: ucfirst(fmtDateLong(t)), casete: nil, sarbatori: sarb, deConfirmat: conf, sectiuni: [])
    }
    let fines = allFines(cs, t)
    let active = fines.filter { $0.st.level != "green" }
    let paid = fines.filter { $0.st.level == "green" }
    var cnt: [String: Int] = ["blue": 0, "yellow": 0, "red": 0, "green": 0]
    for f in fines { cnt[f.st.level, default: 0] += 1 }
    let open = cs.filter { !isIncheiat($0) }.sortatStabil(byStartDesc)
    let asi = allAsi(cs, t)
    let asiActive = asi.filter { $0.a.pending != true }
    let asiPending = asi.count - asiActive.count
    var netrecute: [(Control, Neregula)] = []
    for c in cs { for n in activeNereguli(c) where n.status == "nok" && !n.inPV { netrecute.append((c, n)) } }
    let nearestAsi = asiActive.first?.a.daysLeft
    let deInc = cs.compactMap { c in incarcareStatus(c, t).flatMap { $0.gata ? nil : (c, $0) } }
        .sortatStabil { ($0.1.daysLeft ?? 0) - ($1.1.daysLeft ?? 0) }
    let incRosii = deInc.filter { $0.1.level == "red" }.count

    let g = cnt["green"]!
    var subsolAsi = [nearestAsi.map { $0 >= 0 ? "cel mai apropiat: \($0 == 0 ? "expiră azi" : zile($0))" : "unul depășit cu \(zile(-$0))" } ?? "niciun termen activ"]
    if asiPending > 0 { subsolAsi.append("+ \(asiPending) \(asiPending == 1 ? "neînceput" : "neîncepute") (control neîncheiat)") }
    let casete = [
        CasetaPanou(sectiune: .amenzi, iconita: "fine", numar: active.count, eticheta: "Amenzi active",
                    bara: active.isEmpty ? nil : [("red", cnt["red"]!), ("yellow", cnt["yellow"]!), ("blue", cnt["blue"]!)],
                    legenda: [("red", cnt["red"]!, "de trimis la ANAF / Taxe și impozite"), ("yellow", cnt["yellow"]!, "cu termen de plată expirat"), ("blue", cnt["blue"]!, "în curs")].filter { $0.1 > 0 },
                    subsol: [g > 0 ? "+ \(g) \(g == 1 ? "achitată / executată silit" : "achitate / executate silit") (nu intră în total)" : active.isEmpty ? "nicio amendă activă" : ""].filter { !$0.isEmpty }),
        CasetaPanou(sectiune: .neincheiate, iconita: "clock", numar: open.count, eticheta: "Controale neîncheiate", bara: nil, legenda: [],
                    subsol: [open.isEmpty ? "toate sunt încheiate" : "cel mai vechi: \(fmtDate(open.last!.dataInceput))"]),
        CasetaPanou(sectiune: .asi, iconita: "hourglass", numar: asiActive.count, eticheta: "Termene ASI 90 zile", bara: nil, legenda: [], subsol: subsolAsi),
        CasetaPanou(sectiune: .incarcare, iconita: "upload", numar: deInc.count, eticheta: "De încărcat", bara: nil, legenda: [],
                    subsol: [deInc.isEmpty ? "toate controalele încheiate sunt încărcate" : incRosii > 0 ? "\(incRosii) cu ultima zi azi sau termen depășit" : "în aplicație și document, în 3 zile lucrătoare"]),
        CasetaPanou(sectiune: .pv, iconita: "pv", numar: netrecute.count, eticheta: "Netrecute în PV", bara: nil, legenda: [],
                    subsol: [netrecute.isEmpty ? "toate sunt trecute" : "de completat în procesul-verbal"]),
    ]

    func elementAmenda(_ f: AmendaInControl) -> ElementPanou {
        let c = f.c, n = f.n, st = f.st
        let sub = ["\(neregulaLetter(c, n)). \(constatareLabel(n))\(c.constructii.count > 1 && secOf(n) == "ner" ? " · \(constructiiNume(c, n))" : "")"]
        return ElementPanou(id: "\(c.id)-\(n.key)", nivel: st.level, titlu: nume(c), sub: sub, mesaj: st.msg,
                            avertizare: (st.nelucr ?? "").isEmpty ? nil : "⚠ \(st.nelucr!)", veche: vecheInfo(cs, c, n).veche,
                            pastileDreapta: [.amenda(st.level, st.label)], suma: n.amenda.suma.isEmpty ? nil : money(n.amenda.suma),
                            control: c.id, tab: tabOfNeregula(n), focus: n.key)
    }
    let secAmenzi = SectiuneModelPanou(sectiune: .amenzi, titlu: "Amenzi", iconita: "fine", elemente: active.map(elementAmenda),
                                       gol: "Nicio amendă activă.", achitate: paid.map(elementAmenda))
    let secAsi = SectiuneModelPanou(sectiune: .asi, titlu: "Termene ASI – 90 de zile", iconita: "hourglass", elemente: asi.map { x in
        var e = ElementPanou(id: x.c.id, nivel: "red", titlu: nume(x.c), sub: x.a.faza == "pierdere" ? ["Constatarea pierderii valabilității (5 zile după cele 90)"] : [],
                             mesaj: x.a.msg, avertizare: (x.a.nelucr ?? "").isEmpty ? nil : "⚠ \(x.a.nelucr!)", control: x.c.id, tab: "nereguli", focus: "a")
        e.subIngrosat = true
        if x.a.pending == true { e.pastileDreapta = [PastilaUI("neutral", "neînceput")] } else { e.numaratoare = numaratoare(x.a.daysLeft ?? 0) }
        return e
    }, gol: "Niciun termen ASI activ.")
    let secInc = SectiuneModelPanou(sectiune: .incarcare, titlu: "De încărcat în aplicație", iconita: "upload", elemente: deInc.map { c, x in
        var e = ElementPanou(id: c.id, nivel: x.level == "red" ? "red" : "warn", titlu: nume(c), sub: ["încheiat \(fmtDateLong(c.dataIncheiere))"],
                             mesaj: x.msg, control: c.id, tab: "obiectiv", focus: "sec-incarcare")
        e.pastileCorp = x.lipsa.map { PastilaUI(x.level ?? "warn", ucfirst(K.lipsaIncarcareText($0)), "upload") }
        e.numaratoare = numaratoare(x.daysLeft ?? 0, lucratoare: true)
        return e
    }, gol: "Toate controalele încheiate sunt încărcate în aplicație, cu documentul.")
    let secOpen = SectiuneModelPanou(sectiune: .neincheiate, titlu: "Controale neîncheiate", iconita: "clock", elemente: open.map { c in
        let d = diffDays(c.dataInceput, t)
        var e = ElementPanou(id: c.id, nivel: "open", titlu: nume(c), sub: ["\(d < 0 ? "începe" : "început") \(fmtDateLong(c.dataInceput))"],
                             mesaj: "Lipsește data încheierii", control: c.id, tab: "obiectiv", focus: nil)
        if let s = sigiliiControl(c) { e.pastileDreapta.append(PastilaUI("red", sigiliiText(s), "lock")) }
        e.pastileDreapta.append(PastilaUI("open", d < 0 ? "începe peste \(zile(-d))" : d == 0 ? "început azi" : d == 1 ? "început ieri" : "de \(zile(d))", "clock"))
        return e
    }, gol: "Toate controalele sunt încheiate.")
    let secPv = SectiuneModelPanou(sectiune: .pv, titlu: "Nereguli netrecute în procesul-verbal", iconita: "pv", elemente: netrecute.map { c, n in
        var e = ElementPanou(id: "\(c.id)-\(n.key)", nivel: "warn", titlu: nume(c), sub: ["\(neregulaLetter(c, n)). \(constatareLabel(n))"],
                             mesaj: nil, veche: vecheInfo(cs, c, n).veche, control: c.id, tab: tabOfNeregula(n), focus: n.key)
        e.pastileDreapta = [PastilaUI("warn", "Netrecut")]
        return e
    }, gol: "Toate neregulile constatate sunt trecute în PV.")
    let toate = [secAmenzi, secAsi, secInc, secOpen, secPv]
    return ModelPanou(data: ucfirst(fmtDateLong(t)), casete: casete, sarbatori: sarb, deConfirmat: conf,
                      sectiuni: toate.filter { !$0.elemente.isEmpty } + toate.filter { $0.elemente.isEmpty })
}

/// Vechimea ultimului backup (`backupAgeText`), pentru „Backup rapid”
public func backupAgeText(_ meta: Meta, azi: String) -> String {
    guard let last = meta.lastBackup, last.count >= 10 else { return "niciun backup încă" }
    let d = diffDays(String(last.prefix(10)), azi)
    if d == 0 { return "ultimul: azi, \(last.dropFirst(11).prefix(5))" }
    if d == 1 { return "ultimul: ieri" }
    return "ultimul: acum \(zile(d))"
}

/// `backupIsStale`: există date și ultimul backup e mai vechi de 7 zile (sau nu există)
public func backupIsStale(_ controls: [Control], _ meta: Meta, azi: String) -> Bool {
    guard !controls.isEmpty else { return false }
    guard let last = meta.lastBackup, last.count >= 10 else { return true }
    return diffDays(String(last.prefix(10)), azi) >= 7
}

/// Numerele de pe meniu: Panou = amenzi urgente (roșii și galbene), Istoric = controale neîncheiate
public func cifreMeniu(_ controls: [Control], azi: String) -> (urgente: Int, neincheiate: Int) {
    (allFines(controls, azi).filter { $0.st.level == "red" || $0.st.level == "yellow" }.count, controls.filter { !isIncheiat($0) }.count)
}

// ───────── texte fixe ale Panoului ─────────

/// Legenda secțiunii Amenzi: (culoare, text)
public let LEGENDA_AMENZI: [(String, String)] = [
    ("blue", "în curs (≤ 15 zile)"), ("yellow", "termen de 15 zile expirat"), ("red", "+25 zile: trimite la ANAF / Taxe și impozite"), ("green", "achitată / executată silit"),
]
public let TEXT_DE_CONFIRMAT = "Ziua lor a trecut și sunt încă planificate: marcați-le efectuate, reprogramați-le sau anulați-le. Raportul lunar numără doar activitățile efectuate."

// ───────── o activitate în listă (`actItem`) ─────────

public struct ModelActivitate: Equatable, Sendable, Identifiable {
    public let id: String
    public let tip: String
    public let tipText: String
    public let titlu: String
    public let cand: String
    public let stare: PastilaUI
    /// butoanele: „Efectuată”, „Reprogramează” (doar la confirmare), „Anulată” — doar la cele planificate
    public let butoane: [String]
}

private let PILL_STARE = ["planificat": ("open", "clock"), "efectuat": ("green", "check"), "anulat": ("neutral", "")]

public func modelActivitate(_ a: Activitate, _ controls: [Control], confirmare: Bool = false) -> ModelActivitate {
    let ob = a.objectiveId.isEmpty ? nil : objectives(controls).first { $0.id == a.objectiveId }
    let (nivel, ic) = PILL_STARE[a.stare] ?? ("neutral", "")
    let d = a.descriere.trimJS
    return ModelActivitate(
        id: a.id, tip: a.tip, tipText: tipLabel(a), titlu: d.isEmpty ? tipLabel(a) : d,
        cand: "\(cand(a))\(ob.map { " · \($0.denumire)" } ?? "")",
        stare: PastilaUI(nivel, K.stareActivitate(a.stare) ?? a.stare, ic.isEmpty ? nil : ic),
        butoane: a.stare == "planificat" ? ["Efectuată"] + (confirmare ? ["Reprogramează"] : []) + ["Anulată"] : [])
}

/// Ecranul de bun venit (fără date)
public let BUN_VENIT_TITLU = "Bun venit în Agenda inspectorului"
public func bunVenitText(_ dispozitiv: String) -> String {
    "Toate datele rămân pe \(dispozitiv). Începeți cu un control nou sau încercați aplicația pe date demonstrative. Tot ce face aplicația e explicat în **Ghidul aplicației**."
}
