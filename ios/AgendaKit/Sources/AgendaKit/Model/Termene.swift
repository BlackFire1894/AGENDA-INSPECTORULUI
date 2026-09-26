import Foundation

// Portarea din js/model.js: termenele (amenzi, ASI, încărcare) și statisticile controlului.
// Textele sunt cuvânt cu cuvânt cele din web; vectorii din docs/nativ/vectori/termene.json le verifică.

/// Data de la care curg termenele amenzii: data aplicării, implicit data încheierii.
public func fineDate(_ c: Control, _ n: Neregula) -> String {
    if isISO(n.amenda.data) { return n.amenda.data }
    return isISO(c.dataIncheiere) ? c.dataIncheiere : ""
}

/// Termen într-o zi nelucrătoare: avertizare + recomandarea primei zile lucrătoare (numărătoarea nu se schimbă)
public func nelucrNota(_ ce: String, _ iso: String, _ motiv: String) -> String {
    "\(ce) (\(fmtDate(iso))) cade \(motiv) — următoarea zi lucrătoare: \(fmtDateLong(nextWorkingDay(iso))); verificați prelungirea"
}
func maiSunt(_ n: Int) -> String { n == 1 ? "Mai este 1 zi" : "Mai sunt \(zile(n))" }

/// Stadiul amenzii. level: "green" (achitată) | "blue" (în curs) | "yellow" (15 zile expirat) | "red" (trimite la ANAF)
public struct StadiuAmenda: Equatable, Sendable {
    public var level: String
    public var label: String
    public var msg: String
    public var pending: Bool? = nil
    public var elapsed: Int? = nil
    public var plataPana: String? = nil
    public var anafPana: String? = nil
    public var plataNelucr: String? = nil
    public var anafNelucr: String? = nil
    public var daysLeft: Int? = nil
    public var nelucr: String? = nil

    /// câmpurile prezente, ca obiectul din web (fără cele `undefined`)
    public var json: JSONValue {
        var o = JSObiect([("level", .string(level)), ("label", .string(label))])
        if let v = elapsed { o["elapsed"] = .number(Double(v)) }
        if let v = plataPana { o["plataPana"] = .string(v) }
        if let v = anafPana { o["anafPana"] = .string(v) }
        if let v = plataNelucr { o["plataNelucr"] = .string(v) }
        if let v = anafNelucr { o["anafNelucr"] = .string(v) }
        if let v = daysLeft { o["daysLeft"] = .number(Double(v)) }
        if let v = nelucr { o["nelucr"] = .string(v) }
        o["msg"] = .string(msg)
        if let v = pending { o["pending"] = .bool(v) }
        return .object(o)
    }
}

public func fineStatus(_ c: Control, _ n: Neregula, _ today: String = todayISO()) -> StadiuAmenda {
    let a = n.amenda
    if a.achitata {
        return StadiuAmenda(level: "green", label: "Achitată", msg: a.dataAchitare.isEmpty ? "Dovadă de plată primită" : "Dovadă primită · \(fmtDate(a.dataAchitare))")
    }
    let d = fineDate(c, n)
    if d.isEmpty {
        return StadiuAmenda(level: "blue", label: "În curs", msg: "Termenele pornesc de la data încheierii controlului", pending: true)
    }
    let elapsed = diffDays(d, today)
    let plataPana = addDays(d, K.TERMEN_PLATA)
    let anafPana = addDays(d, K.TERMEN_ANAF)
    // Termenul NU se mută automat; doar se semnalează ziua nelucrătoare.
    let plataNelucr = zinelucratoare(plataPana)
    let anafNelucr = zinelucratoare(anafPana)
    let leftAnaf = K.TERMEN_ANAF - elapsed
    if elapsed <= K.TERMEN_PLATA {
        let left = K.TERMEN_PLATA - elapsed
        let msg: String
        if elapsed < 0 { msg = "Data aplicării amenzii e în viitor (\(fmtDate(d))); plata până la \(fmtDate(plataPana))" }
        else if left == 0 { msg = "Astăzi este ultima zi de plată" }
        else { msg = "\(maiSunt(left)) din termenul de plată (\(fmtDate(plataPana)))" }
        return StadiuAmenda(level: "blue", label: "În curs", msg: msg, elapsed: elapsed, plataPana: plataPana, anafPana: anafPana,
                            plataNelucr: plataNelucr, anafNelucr: anafNelucr, daysLeft: left,
                            nelucr: plataNelucr.isEmpty ? "" : nelucrNota("Termenul de plată", plataPana, plataNelucr))
    }
    if elapsed < K.PRAG_ROSU {
        let over = elapsed - K.TERMEN_PLATA
        return StadiuAmenda(level: "yellow", label: "Termen 15 zile expirat", msg: "Termenul de plată a expirat de \(zile(over)) (\(fmtDate(plataPana)))",
                            elapsed: elapsed, plataPana: plataPana, anafPana: anafPana, plataNelucr: plataNelucr, anafNelucr: anafNelucr,
                            daysLeft: leftAnaf, nelucr: anafNelucr.isEmpty ? "" : nelucrNota("Termenul ANAF", anafPana, anafNelucr))
    }
    let msg: String
    if leftAnaf > 0 { msg = "Mai aveți \(zile(leftAnaf)) până să o trimiteți la ANAF; consultați calculatorul de termene" }
    else if leftAnaf == 0 { msg = "Astăzi este ultima zi pentru trimiterea la ANAF; consultați calculatorul de termene" }
    else { msg = "Termenul de trimitere la ANAF (\(fmtDate(anafPana))) a fost depășit cu \(zile(-leftAnaf))" }
    return StadiuAmenda(level: "red", label: "Trimite la ANAF", msg: msg, elapsed: elapsed, plataPana: plataPana, anafPana: anafPana,
                        plataNelucr: plataNelucr, anafNelucr: anafNelucr, daysLeft: leftAnaf,
                        nelucr: !anafNelucr.isEmpty && leftAnaf >= 0 ? nelucrNota("Termenul ANAF", anafPana, anafNelucr) : "")
}

/// Termenul ASI (neregula „a”): 90 de zile de la încheiere, apoi 5 zile pentru constatarea pierderii valabilității.
public struct TermenASI: Equatable, Sendable {
    public var msg: String
    public var resolved: Bool? = nil
    public var pierdere: Bool? = nil
    public var pending: Bool? = nil
    public var deadline: String? = nil
    public var faza: String? = nil
    public var termenPierdere: String? = nil
    public var daysLeft: Int? = nil
    public var nelucr: String? = nil

    public var json: JSONValue {
        var o = JSObiect()
        if let v = resolved { o["resolved"] = .bool(v) }
        if let v = pierdere { o["pierdere"] = .bool(v) }
        if let v = pending { o["pending"] = .bool(v) }
        if let v = deadline { o["deadline"] = .string(v) }
        if let v = faza { o["faza"] = .string(v) }
        if let v = termenPierdere { o["termenPierdere"] = .string(v) }
        if let v = daysLeft { o["daysLeft"] = .number(Double(v)) }
        o["msg"] = .string(msg)
        if let v = nelucr { o["nelucr"] = .string(v) }
        return .object(o)
    }
}

public func asiDeadline(_ c: Control, _ today: String = todayISO()) -> TermenASI? {
    guard let n = c.nereguli.first(where: { $0.key == "a" && !$0.custom }), n.status == "nok", n.asiTermen else { return nil }
    if n.asiPrezentat {
        return TermenASI(msg: "Documentație prezentată\(isISO(n.asiDataPrezentare) ? " · " + fmtDate(n.asiDataPrezentare) : "")", resolved: true)
    }
    if !isISO(c.dataIncheiere) {
        return TermenASI(msg: "Termenul de 90 de zile începe după încheierea controlului", pending: true)
    }
    let deadline = addDays(c.dataIncheiere, K.TERMEN_ASI)
    let left = diffDays(today, deadline)
    if left >= 0 {
        let msg = left > 0 ? "\(maiSunt(left)) până la \(fmtDate(deadline))" : "Termenul expiră astăzi (\(fmtDate(deadline)))"
        let nl = zinelucratoare(deadline)
        return TermenASI(msg: msg, deadline: deadline, daysLeft: left, nelucr: nl.isEmpty ? "" : nelucrNota("Termenul", deadline, nl))
    }
    // Etapa a doua: după cele 90 de zile, 5 zile calendaristice pentru constatarea pierderii valabilității
    if n.asiPierdere {
        return TermenASI(msg: "Pierderea valabilității constatată\(isISO(n.asiDataPierdere) ? " · " + fmtDate(n.asiDataPierdere) : "")", resolved: true, pierdere: true)
    }
    let termenPierdere = addDays(deadline, K.TERMEN_PIERDERE_ASI)
    let left2 = diffDays(today, termenPierdere)
    let msg: String
    if left2 > 0 { msg = "Termenul de 90 de zile a expirat (\(fmtDate(deadline))). \(maiSunt(left2)) pentru constatarea pierderii valabilității (până la \(fmtDate(termenPierdere)))" }
    else if left2 == 0 { msg = "Astăzi este ultima zi pentru constatarea pierderii valabilității (\(fmtDate(termenPierdere)))" }
    else { msg = "Termenul pentru constatarea pierderii valabilității (\(fmtDate(termenPierdere))) a fost depășit cu \(zile(-left2))" }
    let nl = zinelucratoare(termenPierdere)
    return TermenASI(msg: msg, deadline: deadline, faza: "pierdere", termenPierdere: termenPierdere, daysLeft: left2,
                     nelucr: !nl.isEmpty && left2 >= 0 ? nelucrNota("Termenul", termenPierdere, nl) : "")
}

/// Încărcarea după încheiere (aplicația ISU + documentul): 3 zile lucrătoare de la încheiere; ultima zi și depășirea = roșu.
public struct StareIncarcare: Equatable, Sendable {
    public var gata: Bool
    /// "aplicatie", "document"
    public var lipsa: [String]
    public var termen: String? = nil
    public var daysLeft: Int? = nil
    /// "warn" | "red"
    public var level: String? = nil
    public var msg: String? = nil

    public var json: JSONValue {
        var o = JSObiect([("gata", .bool(gata)), ("lipsa", JSONValue(lipsa))])
        if let v = termen { o["termen"] = .string(v) }
        if let v = daysLeft { o["daysLeft"] = .number(Double(v)) }
        if let v = level { o["level"] = .string(v) }
        if let v = msg { o["msg"] = .string(v) }
        return .object(o)
    }
}

public func incarcareStatus(_ c: Control, _ today: String = todayISO()) -> StareIncarcare? {
    guard isIncheiat(c) else { return nil }
    let inc = c.incarcare
    let lipsa = [inc.aplicatie ? nil : "aplicatie", inc.document ? nil : "document"].compactMap { $0 }
    if lipsa.isEmpty { return StareIncarcare(gata: true, lipsa: lipsa) }
    let termen = addWorkingDays(c.dataIncheiere, K.TERMEN_INCARCARE)
    let msg: String, level: String, daysLeft: Int
    if today > termen {
        daysLeft = -diffDays(termen, today)
        level = "red"
        msg = "Termenul de încărcare (\(fmtDate(termen))) a fost depășit cu \(zile(-daysLeft))"
    } else {
        daysLeft = workingDaysBetween(today, termen)
        level = daysLeft == 0 ? "red" : "warn"
        msg = daysLeft == 0 ? "Astăzi este ultima zi pentru încărcare (\(fmtDate(termen)))"
            : "\(daysLeft == 1 ? "Mai este 1 zi lucrătoare" : "Mai sunt \(daysLeft) zile lucrătoare") pentru încărcare (până la \(fmtDate(termen)))"
    }
    return StareIncarcare(gata: false, lipsa: lipsa, termen: termen, daysLeft: daysLeft, level: level, msg: msg)
}

// ───────── Statistici ─────────

public struct AmendaCuStadiu: Sendable {
    public let n: Neregula
    public let st: StadiuAmenda
}

public struct StatSectiune: Sendable {
    public let total: Int, checked: Int, hidden: Int, constatate: Int, netrecute: Int
    public let fines: [AmendaCuStadiu]
}

/// Statistici pentru o secțiune (tab)
public func secStats(_ c: Control, _ sec: String, _ today: String = todayISO()) -> StatSectiune {
    let rows = c.nereguli.filter { secOf($0) == sec }
    let visible = rows.filter { isApplicable(c, $0) }
    let nok = rows.filter { $0.status == "nok" }
    var total = visible.count
    var checked = visible.filter { !$0.status.isEmpty }.count
    if sec == "pc" {
        total += 1
        if !c.adapostPC.v.isEmpty { checked += 1 }
    }
    return StatSectiune(total: total, checked: checked, hidden: rows.filter { ascunsaDeDotari(c, $0) }.count,
                        constatate: nok.count, netrecute: nok.filter { !$0.inPV }.count,
                        fines: nok.filter { $0.amenda.aplicata }.map { AmendaCuStadiu(n: $0, st: fineStatus(c, $0, today)) })
}

public struct StatControl: Sendable {
    public let acteDone: Int, acteTotal: Int, acteNok: Int
    public let nereguliChecked: Int, nereguliTotal: Int
    public let constatate: Int, netrecute: Int
    public let fines: [AmendaCuStadiu]
    public let asi: TermenASI?
    public let incarcare: StareIncarcare?
}

/// Statistici pentru un control
public func controlStats(_ c: Control, _ today: String = todayISO()) -> StatControl {
    let rows = activeNereguli(c)
    let nok = rows.filter { $0.status == "nok" }
    return StatControl(
        acteDone: K.acte.filter { !c.act($0.key).status.isEmpty }.count, acteTotal: K.acte.count,
        acteNok: K.acte.filter { c.act($0.key).status == "nok" }.count,
        nereguliChecked: rows.filter { !$0.status.isEmpty }.count, nereguliTotal: rows.filter { isApplicable(c, $0) }.count,
        constatate: nok.count, netrecute: nok.filter { !$0.inPV }.count,
        fines: nok.filter { $0.amenda.aplicata }.map { AmendaCuStadiu(n: $0, st: fineStatus(c, $0, today)) },
        asi: asiDeadline(c, today), incarcare: incarcareStatus(c, today))
}

public struct AmendaInControl: Sendable {
    public let c: Control, n: Neregula, st: StadiuAmenda
}

/// Toate amenzile, cu stadiu, sortate după urgență
public func allFines(_ controls: [Control], _ today: String = todayISO()) -> [AmendaInControl] {
    let ordine = ["red": 0, "yellow": 1, "blue": 2, "green": 3]
    var out: [AmendaInControl] = []
    for c in controls {
        for n in activeNereguli(c) where n.status == "nok" && n.amenda.aplicata {
            out.append(AmendaInControl(c: c, n: n, st: fineStatus(c, n, today)))
        }
    }
    return out.sortatStabil { x, y in
        let r = (ordine[x.st.level] ?? 0) - (ordine[y.st.level] ?? 0)
        return r != 0 ? r : (x.st.daysLeft ?? 999) - (y.st.daysLeft ?? 999)
    }
}

public struct ASIInControl: Sendable {
    public let c: Control, a: TermenASI
}

public func allAsi(_ controls: [Control], _ today: String = todayISO()) -> [ASIInControl] {
    var out: [ASIInControl] = []
    for c in controls {
        if let a = asiDeadline(c, today), a.resolved != true { out.append(ASIInControl(c: c, a: a)) }
    }
    return out.sortatStabil { ($0.a.daysLeft ?? 9999) - ($1.a.daysLeft ?? 9999) }
}
