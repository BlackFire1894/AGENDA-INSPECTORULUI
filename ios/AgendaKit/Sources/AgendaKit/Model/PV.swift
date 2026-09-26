import Foundation

// Portarea din js/model.js: Text PV, „Ce mai aveți de făcut”, ce s-a schimbat între două stări (Anulează / Refă).

public struct TextPV: Equatable, Sendable {
    public let text: String
    public let count: Int
}

private func peUnRand(_ s: String) -> String { s.inlocuiesteRegex("\\s*\\n\\s*", "; ") }

/// Textul pentru procesul-verbal: constatările (pe secțiuni) și actele lipsă.
public func pvText(_ c: Control, _ controls: [Control] = [], doarNetrecute: Bool = false, cuActe: Bool = true) -> TextPV {
    var lines: [String] = []
    let perioada = isISO(c.dataIncheiere) && c.dataIncheiere != c.dataInceput
        ? "\(fmtDate(c.dataInceput)) – \(fmtDate(c.dataIncheiere))" : fmtDate(c.dataInceput)
    lines.append("Nereguli constatate – \(c.denumire.isEmpty ? "obiectiv fără denumire" : c.denumire) (control \(perioada))")
    var nr = 0
    let multe = c.constructii.count > 1
    for sec in sectiuniActive(c) {
        let rows = c.nereguli.filter { secOf($0) == sec && $0.status == "nok" && (!doarNetrecute || !$0.inPV) }
        if rows.isEmpty { continue }
        lines.append(contentsOf: ["", "\(K.sectiune(sec).label):"])
        for n in rows {
            nr += 1
            var t = "\(nr). \(constatareLabel(n))"
            let ks = constructiiOf(c, n)
            if sec == "ner" && multe && !ks.isEmpty { t += " – \(ks.count > 1 ? "construcțiile" : "construcția"): \(constructiiNume(c, n))" }
            let vt = verifText(c, n)
            if !vt.isEmpty { t += ". \(ucfirst(vt))" }
            if !n.obs.trimJS.isEmpty { t += ". \(peUnRand(n.obs.trimJS))" }
            var extra: [String] = []
            if n.custom && n.grav { extra.append("neregulă gravă") }
            if isGrav(n) && n.sigiliu { extra.append("sigiliu aplicat") }
            if vecheInfo(controls, c, n).veche { extra.append("neregulă veche") }
            if n.amenda.aplicata {
                let sn = amendaSerieNr(n.amenda)
                extra.append("sancționat cu amendă\(sn.isEmpty ? "" : " \(sn)")")
            }
            if !extra.isEmpty { t += " (\(extra.joined(separator: "; ")))" }
            lines.append(t)
        }
    }
    if cuActe {
        let lipsa = K.acte.filter { c.act($0.key).status == "nok" }
        if !lipsa.isEmpty {
            lines.append(contentsOf: ["", "Acte de autoritate și evidențe lipsă:"])
            for a in lipsa {
                nr += 1
                let obs = c.act(a.key).obs.trimJS
                lines.append("\(nr). \(a.label)\(obs.isEmpty ? "" : ". \(peUnRand(obs))")")
            }
        }
    }
    if nr == 0 {
        lines.append(contentsOf: ["", doarNetrecute ? "Toate neregulile constatate sunt deja trecute în PV." : "Nu au fost constatate nereguli."])
    }
    return TextPV(text: lines.joined(separator: "\n"), count: nr)
}

// ───────── „Ce mai aveți de făcut” ─────────

/// Un pas rămas: level "grav" | "todo" | "warn"; tab + focus = unde se deschide controlul.
public struct PasDeFacut: Equatable, Sendable {
    public let id: String, level: String, text: String, tab: String, focus: String
    public var json: JSONValue {
        ["id": .string(id), "level": .string(level), "text": .string(text), "tab": .string(tab), "focus": .string(focus)]
    }
}

/// Lista pașilor rămași într-un control, în ordinea firească a lucrului.
public func todoList(_ c: Control, includeClose: Bool = true) -> [PasDeFacut] {
    var out: [PasDeFacut] = []
    let tabOf = { (sec: String) in K.sectiune(sec).tab }
    if c.denumire.trimJS.isEmpty {
        out.append(PasDeFacut(id: "denumire", level: "todo", text: "Completați denumirea obiectivului", tab: "obiectiv", focus: "sec-date"))
    }
    let acteTodo = K.acte.filter { c.act($0.key).status.isEmpty }
    if !acteTodo.isEmpty {
        out.append(PasDeFacut(id: "acte", level: "todo", text: "\(acteTodo.count) \(acteTodo.count == 1 ? "act neverificat" : "acte neverificate")",
                              tab: "acte", focus: "act-\(acteTodo[0].key)"))
    }
    let grave = c.nereguli.filter { !$0.custom && (sablon($0.key)?.grav ?? false) && $0.status.isEmpty && isApplicable(c, $0) }
    if !grave.isEmpty {
        let ce = grave.map { neregulaLabel($0).primaMica }.joined(separator: ", ")
        out.insert(PasDeFacut(id: "grave", level: "grav", text: "\(grave.count == 1 ? "O neregulă gravă" : "\(grave.count) nereguli grave"): \(ce)",
                              tab: "nereguli", focus: grave[0].key), at: 0)
    }
    for sec in sectiuniActive(c) {
        // aceeași cifră ca filtrul „Neverificate” (neregulile grave sunt incluse și, în plus, semnalate primele)
        let rows = c.nereguli.filter { secOf($0) == sec && isApplicable(c, $0) }
        let todo = rows.filter { $0.status.isEmpty }
        let adapost = sec == "pc" && c.adapostPC.v.isEmpty ? 1 : 0
        let k = todo.count + adapost
        if k > 0 {
            let what = sec == "ner" ? (k == 1 ? "neregulă neverificată" : "nereguli neverificate") : (k == 1 ? "rubrică neverificată" : "rubrici neverificate")
            out.append(PasDeFacut(id: "todo-\(sec)", level: "todo", text: "\(K.sectiune(sec).label): \(k) \(what)", tab: tabOf(sec), focus: todo.first?.key ?? "adapostPC"))
        }
    }
    let active = activeNereguli(c)
    if let adp = adaposturiStats(c), adp.total == 0 {
        out.append(PasDeFacut(id: "adp-nr", level: "todo", text: "Adăposturi de protecție civilă: completați câte sunt",
                              tab: isLocalitate(c) ? "pc" : "obiectiv", focus: isLocalitate(c) ? "adapostPC" : "sec-adaposturi"))
    }
    for n in active where n.adapost && isApplicable(c, n) && n.locatie.trimJS.isEmpty {
        out.append(PasDeFacut(id: "loc-\(n.key)", level: "warn", text: "Adăpostul \(neregulaLetter(c, n)) fără locație", tab: tabOf(secOf(n)), focus: n.key))
    }
    for n in active where n.custom && !n.adapost && !n.status.isEmpty && n.label.trimJS.isEmpty {
        out.append(PasDeFacut(id: "label-\(n.key)", level: "warn", text: "Rând suplimentar fără descriere", tab: tabOf(secOf(n)), focus: n.key))
    }
    let netrec = active.filter { $0.status == "nok" && !$0.inPV }
    if !netrec.isEmpty {
        out.append(PasDeFacut(id: "pv", level: "warn", text: "\(netrec.count) \(netrec.count == 1 ? "constatare netrecută" : "constatări netrecute") în PV",
                              tab: tabOf(secOf(netrec[0])), focus: netrec[0].key))
    }
    for n in active where n.status == "nok" && n.amenda.aplicata {
        var lipsa: [String] = []
        if amendaSerieNr(n.amenda).isEmpty { lipsa.append("seria / nr.") }
        if n.amenda.suma.trimJS.isEmpty { lipsa.append("suma") }
        if !lipsa.isEmpty {
            out.append(PasDeFacut(id: "fine-\(n.key)", level: "warn", text: "Amendă fără \(lipsa.joined(separator: " și ")): \(constatareLabel(n))",
                                  tab: tabOf(secOf(n)), focus: n.key))
        }
    }
    let faraGps = c.constructii.filter { $0.gps == nil }
    if !faraGps.isEmpty {
        let nume = faraGps.map { numeConstructie(c, $0) }.joined(separator: ", ")
        out.append(PasDeFacut(id: "gps", level: "warn", text: "Coordonate GPS necompletate: \(nume)", tab: "obiectiv", focus: "gps-\(faraGps[0].id)"))
    }
    // verificări expirate care nu sunt (încă) constatate — inspectorul decide
    for n in c.nereguli where isVerificare(n) && isApplicable(c, n) && n.status != "nok" && n.status != "nec" {
        let exp = verifExpirate(c, n)
        if !exp.isEmpty {
            let ce = neregulaLabel(n).inlocuiesteRegex("^Nu a prezentat / nu are verificare ", "")
            out.append(PasDeFacut(id: "verif-\(n.key)", level: "warn", text: "Verificare expirată (\(n.key), \(ce)): \(exp.map(\.denumire).joined(separator: ", "))",
                                  tab: "nereguli", focus: n.key))
        }
    }
    if includeClose && !isISO(c.dataIncheiere) {
        out.append(PasDeFacut(id: "close", level: "todo", text: "Controlul nu este încheiat", tab: "obiectiv", focus: "sec-perioada"))
    }
    // după încheiere: încărcarea în aplicația ISU și a documentului
    if let inc = incarcareStatus(c), !inc.gata {
        let ce = inc.lipsa.map { K.lipsaIncarcareText($0) }.joined(separator: ", ")
        let d = inc.daysLeft ?? 0
        let cand = d < 0 ? "termen depășit" : d == 0 ? "ultima zi azi" : (d == 1 ? "1 zi lucrătoare" : "\(d) zile lucrătoare")
        out.append(PasDeFacut(id: "incarcare", level: "warn", text: "\(ucfirst(ce)) — \(cand)", tab: "obiectiv", focus: "sec-incarcare"))
    }
    // ASI: după cele 90 de zile, constatarea pierderii valabilității
    if let asi = asiDeadline(c), asi.faza == "pierdere" {
        let d = asi.daysLeft ?? 0
        let cand = d < 0 ? "termen depășit" : d == 0 ? "ultima zi azi" : zile(d)
        out.append(PasDeFacut(id: "asi-pierdere", level: "warn", text: "ASI: constatați pierderea valabilității — \(cand)", tab: "nereguli", focus: "a"))
    }
    return out
}

// ───────── Ce s-a schimbat între două stări ale controlului (Anulează / Refă) ─────────

public struct Schimbare: Equatable, Sendable {
    public let tab: String, focus: String, text: String
}

/// Primul loc schimbat: tabul, elementul de adus în vizor și o descriere scurtă.
public func schimbare(_ a: Control, _ b: Control) -> Schimbare {
    let na = a.nereguli, nb = b.nereguli
    var chei: [String] = []
    for n in na + nb where !chei.contains(n.key) { chei.append(n.key) }
    for key in chei {
        let x = na.first { $0.key == key }, y = nb.first { $0.key == key }
        if x == y { continue }
        let n = y ?? x!
        let sec = secOf(n)
        guard let y else { return Schimbare(tab: K.sectiune(sec).tab, focus: "add-\(sec)", text: "rândul adăugat") }
        return Schimbare(tab: K.sectiune(sec).tab, focus: key, text: "\(neregulaLetter(b, y)). \(constatareLabel(y))")
    }
    for act in K.acte where a.o.obj("acte")[act.key] != b.o.obj("acte")[act.key] {
        return Schimbare(tab: "acte", focus: "act-\(act.key)", text: act.label)
    }
    let ka = a.constructii, kb = b.constructii
    var ids: [String] = []
    for k in ka + kb where !ids.contains(k.id) { ids.append(k.id) }
    for id in ids {
        let x = ka.first { $0.id == id }, y = kb.first { $0.id == id }
        if x == y { continue }
        if let y { return Schimbare(tab: "obiectiv", focus: "constr-\(id)", text: y.denumire.isEmpty ? "construcția" : y.denumire) }
        return Schimbare(tab: "obiectiv", focus: "sec-constructii", text: "construcțiile")
    }
    if a.o["adapostPC"] != b.o["adapostPC"] { return Schimbare(tab: "pc", focus: "adapostPC", text: "Adăpost de protecție civilă") }
    if a.dataInceput != b.dataInceput || a.dataIncheiere != b.dataIncheiere {
        return Schimbare(tab: "obiectiv", focus: "sec-perioada", text: "perioada controlului")
    }
    return Schimbare(tab: "obiectiv", focus: "sec-date", text: "datele obiectivului")
}
