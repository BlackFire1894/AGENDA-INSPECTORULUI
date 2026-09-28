import Foundation

// Fișa controlului (js/fisa.js → fisaMarkup, fisaDocument, fisaFileName): rezumatul complet, același HTML ca în web,
// caracter cu caracter (verificat pe demo.json și pe controale aleatoare trecute prin codul web).

private let STATUS_FISA = ["ok": "Conform", "nok": "Neconform", "nec": "NEC (nu este cazul)"]

/// `money(v)` din fisa.js: suma scrisă „2.500 lei”, sau „” dacă nu e un număr
private func moneyFisa(_ v: String) -> String { parseSuma(v).map(lei) ?? "" }

/// Observațiile: fără spații la capete, rândurile noi ca <br>
private func obsFisa(_ t: String) -> String {
    let x = t.trimJS
    return x.isEmpty ? "" : escHTML(x).replacingOccurrences(of: "\n", with: "<br>")
}

public func fisaMarkup(_ c: Control, _ controls: [Control], acum: Date = Ceas.acum()) -> String {
    let today = todayISO(acum)
    let st = controlStats(c, today)
    let multe = c.constructii.count > 1
    let perioada = isIncheiat(c)
        ? (c.dataIncheiere == c.dataInceput ? fmtDate(c.dataInceput) : "\(fmtDate(c.dataInceput)) – \(fmtDate(c.dataIncheiere))")
        : "din \(fmtDate(c.dataInceput)) (în desfășurare)"
    let active = sectiuniActive(c)
    let vechi = c.nereguli.filter { active.contains(secOf($0)) && vecheInfo(controls, c, $0).veche }.count

    var h: [String] = []
    let adresa = [c.adresa, c.localitate].filter { !$0.isEmpty }.joined(separator: ", ")
    h.append("""
    <header class="f-head">
        <div class="f-kicker">Fișa controlului</div>
        <h1>\(escHTML(c.denumire.isEmpty ? "Obiectiv fără denumire" : c.denumire))</h1>
        <div class="f-meta">
          <span><b>Tip:</b> \(c.tip == "LOCALITATE" ? "Localitate" : "OPEC / Instituție")</span>
          <span><b>Perioada:</b> \(escHTML(perioada))</span>
          \(c.administrator.isEmpty ? "" : "<span><b>Administrator:</b> \(escHTML(c.administrator))</span>")
          \(c.persoanaParticipanta.isEmpty ? "" : "<span><b>Persoană participantă:</b> \(escHTML(c.persoanaParticipanta))</span>")
          \(c.telefon.isEmpty ? "" : "<span><b>Telefon:</b> \(escHTML(c.telefon))</span>")
          \(c.email.isEmpty ? "" : "<span><b>Email:</b> \(escHTML(c.email))</span>")
          \(c.adresa.isEmpty && c.localitate.isEmpty ? "" : "<span><b>Adresă:</b> \(escHTML(adresa))</span>")
        </div>
        <div class="f-sum">
          <div><b>\(st.constatate)</b><span>nereguli / neconformități</span></div>
          <div><b>\(st.netrecute)</b><span>\(st.netrecute == 1 ? "netrecută" : "netrecute") în PV</span></div>
          <div><b>\(st.fines.count)</b><span>\(st.fines.count == 1 ? "amendă" : "amenzi")</span></div>
          <div><b>\(vechi)</b><span>\(vechi == 1 ? "neregulă veche" : "nereguli vechi")</span></div>
          <div><b>\(st.acteNok)</b><span>\(st.acteNok == 1 ? "act lipsă" : "acte lipsă")</span></div>
        </div>
      </header>
    """)

    // „De întrebat până la finalizarea controlului” și observațiile generale (v1.25)
    let intreb = c.deIntrebat.filter { !$0.text.trimJS.isEmpty }
    if !intreb.isEmpty {
        let li = intreb.map { x in
            "<li class=\"\(x.gata ? "" : "f-nok")\">\(x.gata ? "✓" : "☐") \(obsFisa(x.text))\(x.gata ? "" : " <b>(nerezolvat)</b>")</li>"
        }.joined()
        h.append("<section><h2>De întrebat până la finalizarea controlului</h2><ul class=\"f-intreb\">\n      \(li)\n    </ul></section>")
    }
    if !c.observatiiGenerale.trimJS.isEmpty {
        h.append("<section><h2>Observații generale</h2><p>\(obsFisa(c.observatiiGenerale))</p></section>")
    }

    // Construcții
    h.append("<section><h2>Construcții (\(c.constructii.count))</h2>")
    for (i, k) in c.constructii.enumerated() {
        var by: [String: [String]] = ["DA": [], "NU": [], "NEC": []]
        let vis = dotariVizibile(c, k)
        for d in vis where !d.centrala {
            let v = k.dotare(d.key)?.v ?? ""
            if by[v] != nil { by[v]!.append(d.label) }
        }
        // o centrală: tipurile ei (ca până acum); mai multe: fiecare, cu numărul ei
        let cen = k.dotare("centrala")
        let cts = cen?.ct ?? []
        let centrala = cen?.nuAre == true ? "nu are"
            : cts.count > 1 ? cts.enumerated().map { j, x in "CT \(j + 1)\(x.tipuri.isEmpty ? "" : ": \(x.tipuri.joined(separator: ", "))")" }.joined(separator: "; ")
            : (cts.first?.tipuri ?? cen?.tipuri ?? []).joined(separator: ", ")
        let ruta = { (s: String) in s.isEmpty ? "—" : s }
        let gps = k.gps.map { "<a href=\"\(escHTML(googleMapsUrl($0)))\">\(escHTML(fmtCoord($0)))</a> (\($0.faraPrecizie ? "introduse manual" : "± \(rotunjesteJS($0.acc)) m"))" } ?? "necompletate"
        let numere = ["asi", "aviz"].filter { d in k.dotare(d)?.v == "DA" && !(k.dotare(d)?.nr.trimJS.isEmpty ?? true) }
            .map { "<p class=\"f-dot\"><b>\($0 == "asi" ? "Nr. autorizație (ASI)" : "Nr. aviz"):</b> \(escHTML(k.dotare($0)?.nr ?? ""))</p>" }.joined()
        let obsDotari = vis.filter { !(k.dotare($0.key)?.obs.trimJS.isEmpty ?? true) }
            .map { "<p class=\"f-dot f-small\"><b>\(escHTML($0.label)):</b> \(obsFisa(k.dotare($0.key)?.obs ?? ""))</p>" }.joined()
        h.append("""
        <div class="f-constr">
              <h3>\(i + 1). \(escHTML(k.denumire.isEmpty ? "Construcția \(i + 1)" : k.denumire))</h3>
              <table class="f-kv"><tr>
                <td><b>Suprafață desf.</b><br>\(k.suprafata.isEmpty ? "—" : "\(escHTML(k.suprafata)) m²")</td>
                <td><b>Regim înălțime</b><br>\(ruta(escHTML(k.regimInaltime)))</td>
                <td><b>GRF / NSI</b><br>\(ruta(escHTML(grfText(k.grf))))\(grfVPesteParter(k) ? "<br><b>neregulă gravă</b>" : "")</td>
                <td><b>Nr. angajați</b><br>\(ruta(escHTML(k.nrAngajati)))</td>
                <td><b>Anul construirii</b><br>\(ruta(escHTML(k.anConstruire)))</td>
                <td><b>Structură</b><br>\(ruta(escHTML(k.structura)))</td>
                <td><b>Pereți</b><br>\(ruta(escHTML(k.materialPereti)))</td>
              </tr></table>
              <p class="f-dot"><b>Coordonate GPS:</b> \(gps)</p>
              \(numere)
              <p class="f-dot"><b>DA:</b> \(ruta(escHTML(by["DA"]!.joined(separator: ", "))))\(centrala.isEmpty ? "" : " · <b>Centrală termică:</b> \(escHTML(centrala))")</p>
              <p class="f-dot"><b>NU:</b> \(ruta(escHTML(by["NU"]!.joined(separator: ", ")))) · <b>NEC:</b> \(ruta(escHTML(by["NEC"]!.joined(separator: ", "))))</p>
              \(obsDotari)
            </div>
        """)
    }
    h.append("</section>")
    // OPEC / Instituție: adăposturile stau la datele obiectivului (la Localitate, în Protecție civilă)
    if !isLocalitate(c) { h.append("<section><h2>Adăposturi de protecție civilă</h2>\(adaposturiFisa(c))</section>") }

    // Acte
    let acte = acteOf(c).enumerated().map { i, a -> String in
        let v = c.act(a.key)
        let sit = v.status == "ok" ? "Prezentat" : v.status == "nok" ? "Lipsă" : v.status == "nec" ? "NEC (nu este cazul)" : "—"
        return "<tr class=\"\(v.status == "nok" ? "f-nok" : "")\">\n      <td>\(i + 1)</td><td>\(escHTML(a.label))</td><td>\(sit)</td><td>\(obsFisa(v.obs))</td></tr>"
    }.joined()
    h.append("""
    <section><h2>Acte de autoritate și evidențe</h2><table class="f-table">
        <thead><tr><th>#</th><th>Act / evidență</th><th>Situație</th><th>Observații</th></tr></thead><tbody>
        \(acte)
      </tbody></table></section>
    """)

    // Secțiuni de constatări
    for sec in active {
        let rows = c.nereguli.filter { secOf($0) == sec }
        // nereguli grave (NU la dotări) apar mereu, chiar neverificate, ca să nu se piardă
        let gravNeverif = { (n: Neregula) in n.status.isEmpty && (sablon(n.key)?.grav ?? false) && isApplicable(c, n) }
        let verif = rows.filter { !$0.status.isEmpty || gravNeverif($0) }
        let neverif = rows.filter { $0.status.isEmpty && isApplicable(c, $0) }.count - rows.filter(gravNeverif).count
        h.append("<section><h2>\(escHTML(K.sectiune(sec).label))</h2>")
        if verif.isEmpty {
            h.append("<p class=\"f-small\">Nicio rubrică verificată.</p>")
        } else {
            h.append("<table class=\"f-table\"><thead><tr><th>Nr.</th><th>\(sec == "ner" ? "Neregulă" : "Rubrică")</th>\(sec == "ner" && multe ? "<th>Construcția</th>" : "")<th>Situație</th><th>PV</th><th>Observații / sancțiune</th></tr></thead><tbody>")
            for n in verif {
                let vi = vecheInfo(controls, c, n)
                var det: [String] = []
                let o = obsFisa(n.obs)
                if !o.isEmpty { det.append(o) }
                if isVerificare(n) && n.status != "nec" {
                    let vs = verifUnitati(c, n).map { u -> String in
                        let s = verifStare(c, n, u)
                        let t = s.stare == "lipsa" ? "fără dată"
                            : "\(fmtDate(s.data)) (\(s.luni) luni)\(s.stare == "expirata" ? " — <b>expirată (era valabilă până la \(fmtDate(s.expira ?? "")))</b>" : "")"
                        return "\(multe || u.ct != nil ? "\(escHTML(u.denumire)): " : "")\(t)"
                    }
                    if !vs.isEmpty { det.append("<b>Ultima verificare:</b> \(vs.joined(separator: "; "))") }
                }
                if n.custom && n.grav { det.append("<b>Neregulă gravă</b>") }
                if n.status == "nok" && isGrav(n) && n.sigiliu { det.append("<b>Sigiliu aplicat</b>") }
                if vi.veche { det.append("<b>Neregulă veche</b>\(vi.auto.map { " (și la controlul din \(fmtDate($0.dataInceput)))" } ?? "")") }
                if n.status == "nok" && n.amenda.aplicata {
                    let fs = fineStatus(c, n, today)
                    let bani = moneyFisa(n.amenda.suma)
                    det.append("<b>Amendă</b>\(bani.isEmpty ? "" : ", \(bani)") — \(escHTML(fs.label))")
                }
                if sec == "ner" && n.key == "a" && !n.custom, let d = asiDeadline(c, today) {
                    det.append("<b>ASI 90 zile:</b> \(escHTML(d.msg))")
                }
                let cat = n.custom ? "" : "<div class=\"f-cat\">\(escHTML(K.categorie(neregulaCat(n)) ?? ""))</div>"
                let constr = sec == "ner" && multe ? "<td>\(escHTML({ let x = constructiiNume(c, n); return x.isEmpty ? "—" : x }()))</td>" : ""
                let sit = n.status == "nok" ? (sec == "ner" ? "Constatat" : "Neconform") : STATUS_FISA[n.status] ?? "<b>Neverificată — gravă</b>"
                h.append("""
                <tr class="\(n.status == "nok" || gravNeverif(n) ? "f-nok" : "")">
                          <td>\(escHTML(neregulaLetter(c, n)))</td>
                          <td>\(escHTML(constatareLabel(n)))\(cat)</td>
                          \(constr)
                          <td>\(sit)</td>
                          <td>\(n.status == "nok" ? (n.inPV ? "Trecut" : "<b>Netrecut</b>") : "")</td>
                          <td>\(det.joined(separator: "<br>"))</td>
                        </tr>
                """)
            }
            h.append("</tbody></table>")
        }
        if neverif != 0 { h.append("<p class=\"f-small\">\(neverif) \(neverif == 1 ? "rubrică neverificată" : "rubrici neverificate") (nu apar în tabel).</p>") }
        if sec == "pc" { h.append(adaposturiFisa(c)) }
        h.append("</section>")
    }

    let p = Ceas.calendar.dateComponents([.hour, .minute], from: acum)
    h.append("<footer class=\"f-foot\">Generat la \(escHTML(fmtDateLong(today))), \(String(format: "%02d:%02d", p.hour ?? 0, p.minute ?? 0)) · Agenda inspectorului</footer>")
    return h.joined(separator: "\n")
}

/// Adăposturile de protecție civilă: DA / NU / NEC, apoi fiecare adăpost cu locația, starea și observațiile
private func adaposturiFisa(_ c: Control) -> String {
    let a = c.adapostPC
    let st = adaposturiStats(c)
    let o = obsFisa(a.obs)
    var h = "<p><b>Adăposturi de protecție civilă:</b> \(escHTML(a.v.isEmpty ? "—" : a.v))\(a.v == "NEC" ? " (nu este cazul)" : "")\(st.map { " — \(escHTML(adaposturiText($0)))" } ?? "")\(o.isEmpty ? "" : " — \(o)")</p>"
    let l = st != nil ? adaposturi(c) : []
    if !l.isEmpty {
        h += "<table class=\"f-table\"><thead><tr><th>Nr.</th><th>Locația</th><th>Stare</th><th>Observații</th></tr></thead><tbody>\n      "
            + l.enumerated().map { i, n in
                let loc = n.locatie.trimJS
                let stare = n.status == "ok" ? "Conform" : n.status == "nok" ? "<b>Neconform</b>" : "<b>Neverificat</b>"
                return "<tr><td>A\(i + 1)</td><td>\(escHTML(loc.isEmpty ? "—" : loc))</td><td>\(stare)</td><td>\(obsFisa(n.obs))</td></tr>"
            }.joined() + "</tbody></table>"
    }
    return h
}

/// Documentul întreg (partajare / tipărire), cu stilurile Fișei
/// `anexa`: fotografiile constatărilor (`anexaFotografii`, adăugire nativă), după fișa din web
public func fisaDocument(_ c: Control, _ controls: [Control], css: String, anexa: String = "") -> String {
    """
    <!doctype html><html lang="ro"><head><meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Fișa controlului – \(escHTML(c.denumire))</title>
    <style>@page { size: A4; margin: 14mm; } body { margin: 0; padding: 16px; } \(css)\(anexa.isEmpty ? "" : "\n" + CSS_FOTOGRAFII)</style></head>
    <body><div class="fisa-doc">\(fisaMarkup(c, controls))\(anexa)</div></body></html>
    """
}

/// „Fisa-control-Scoala-Gimnaziala-nr-3-2026-09-03.html”
public func fisaFileName(_ c: Control) -> String {
    let nume = c.denumire.isEmpty ? "control" : c.denumire
    var s = String(String.UnicodeScalarView(nume.decomposedStringWithCanonicalMapping.unicodeScalars.filter { !(0x300...0x36F).contains($0.value) }))
    s = s.inlocuiesteRegex("[^A-Za-z0-9_]+", "-")
    while s.hasPrefix("-") { s.removeFirst() }
    while s.hasSuffix("-") { s.removeLast() }
    let slug = String(s.prefix(40))   // după curățare, doar ASCII: caractere = unități UTF-16
    return "Fisa-control-\(slug)-\(isISO(c.dataInceput) ? c.dataInceput : todayISO()).html"
}
