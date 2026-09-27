import Foundation

// Raportul lunii ca document (js/activitati.js → raportMarkup, raportDocument, raportFileName): același HTML,
// caracter cu caracter (verificat pe demo.json și pe rapoarte aleatoare trecute prin codul web), cu stilurile
// Fișei (docs/nativ/date/stiluri-fisa.css), pentru afișare, tipărire / PDF și partajare.

/// `esc()` din js/ui.js
public func escHTML(_ s: String) -> String {
    var r = ""
    r.reserveCapacity(s.count)
    for ch in s {
        switch ch {
        case "&": r += "&amp;"
        case "<": r += "&lt;"
        case ">": r += "&gt;"
        case "\"": r += "&quot;"
        case "'": r += "&#39;"
        default: r.append(ch)
        }
    }
    return r
}

public func raportMarkup(_ r: RaportLunar, _ controls: [Control], acum: Date = Ceas.acum()) -> String {
    var obNume: [String: String] = [:]
    for o in objectives(controls) where obNume[o.id] == nil { obNume[o.id] = o.denumire }
    let azi = todayISO(acum)
    var h: [String] = []
    let nc = r.controale.count, ne = r.efectuate.count, np = r.planificate.count, nl = r.libere.count
    h.append("""
    <header class="f-head">
        <div class="f-kicker">Plan lunar · raport de activitate</div>
        <h1>\(escHTML(r.titlu))</h1>
        <div class="f-meta"><span><b>Generat:</b> \(escHTML(fmtDateLong(azi)))</span></div>
        <div class="f-sum f-sum-6">
          <div><b>\(nc)</b><span>\(nc == 1 ? "control început" : "controale începute") (\(r.incheiate) \(r.incheiate == 1 ? "încheiat" : "încheiate"))</span></div>
          <div><b>\(r.constatate)</b><span>\(r.constatate == 1 ? "neregulă constatată" : "nereguli constatate")</span></div>
          <div><b>\(r.amenzi.count)</b><span>\(r.amenzi.count == 1 ? "amendă aplicată" : "amenzi aplicate")\(r.amenzi.isEmpty ? "" : " · \(escHTML(lei(r.sumaAmenzi)))")</span></div>
          <div><b>\(ne)</b><span>\(ne == 1 ? "activitate efectuată" : "activități efectuate")</span></div>
          <div><b>\(np)</b><span>\(np == 1 ? "activitate planificată" : "activități planificate") (neconfirmate)</span></div>
          <div><b>\(nl)</b><span>\(nl == 1 ? "zi liberă" : "zile libere") (\(r.lucratoare) lucrătoare)</span></div>
        </div>
      </header>
    """)
    if !r.peTipuri.isEmpty {
        h.append("<section><h2>Activități efectuate, pe tipuri</h2><table class=\"f-table\"><thead><tr><th>Tip</th><th>Activități</th><th>Zile</th></tr></thead><tbody>\n      "
            + r.peTipuri.map { "<tr><td>\(escHTML($0.label))</td><td>\($0.n)</td><td>\($0.zile)</td></tr>" }.joined()
            + "</tbody></table></section>")
    }
    if !r.libere.isEmpty {
        let sarb = r.libere.filter { !$0.sarbatoare.isEmpty }
        let ef = r.libere.filter { $0.stare == "efectuat" }.count
        let lucrate = r.libere.filter { $0.lucrata == true }
        let listaSarb = sarb.isEmpty ? "" : ": \(escHTML(sarb.map { "\($0.sarbatoare) (\(fmtDate($0.d)))" }.joined(separator: ", ")))"
        let pLucrate = lucrate.isEmpty ? ""
            : "<p>Zile libere în care s-a lucrat (control început sau activitate efectuată): \(escHTML(lucrate.map { fmtDate($0.d) }.joined(separator: ", "))).</p>"
        h.append("""
        <section><h2>Zile libere</h2><table class="f-table"><thead><tr><th></th><th>Zile</th></tr></thead><tbody>
              <tr><td>Weekend (fără sărbătorile căzute în weekend)</td><td>\(r.libere.count - sarb.count)</td></tr>
              <tr><td>Sărbători legale\(listaSarb)</td><td>\(sarb.count)</td></tr>
              <tr><td>Efectuate (până azi)</td><td>\(ef)</td></tr>
              <tr><td>Planificate</td><td>\(r.libere.count - ef)</td></tr>
              <tr><td><b>Zile lucrătoare în lună</b></td><td><b>\(r.lucratoare)</b></td></tr></tbody></table>
              \(pLucrate)</section>
        """)
    }
    h.append("<section><h2>Zi cu zi</h2>")
    if r.zile.isEmpty { h.append("<p>Niciun control și nicio activitate în această lună.</p>") }
    for (d, x) in r.zile {
        h.append("<h3>\(escHTML(fmtDateLong(d)))</h3><ul class=\"f-list\">")
        for c in x.controale {
            let st = controlStats(c, azi)
            let stare = isIncheiat(c) ? "încheiat \(escHTML(fmtDate(c.dataIncheiere)))" : "în desfășurare"
            let am = st.fines.isEmpty ? "" : "; \(st.fines.count) \(st.fines.count == 1 ? "amendă" : "amenzi")"
            h.append("<li><b>Control: \(escHTML(c.denumire.isEmpty ? "Obiectiv fără denumire" : c.denumire))</b> — \(stare); \(st.constatate) \(st.constatate == 1 ? "neregulă constatată" : "nereguli constatate")\(am)</li>")
        }
        for a in x.activitati {
            let ob = a.objectiveId.isEmpty ? "" : (obNume[a.objectiveId] ?? "")
            let obs = a.obs.trimJS
            h.append("<li><b>\(escHTML(titluActivitate(a)))</b> — \(escHTML(cand(a)))\(ob.isEmpty ? "" : " · \(escHTML(ob))") · <i>\(escHTML(K.stareActivitate(a.stare) ?? ""))</i>\(obs.isEmpty ? "" : "<br>\(escHTML(obs))")</li>")
        }
        h.append("</ul>")
    }
    h.append("</section>")
    if !r.amenzi.isEmpty || r.amenziFaraData > 0 {
        let tabel = r.amenzi.isEmpty ? "" : "<table class=\"f-table\"><thead><tr><th>Data</th><th>Obiectiv</th><th>Seria și nr.</th><th>Suma</th></tr></thead><tbody>\n      "
            + r.amenzi.sortatStabil { compara($0.data, $1.data) }.map { x in
                let serie = x.n.amenda.serieNr
                return "<tr><td>\(escHTML(fmtDate(x.data)))</td><td>\(escHTML(x.c.denumire))</td><td>\(escHTML(serie.isEmpty ? "—" : serie))</td><td>\(x.suma != 0 && !x.suma.isNaN ? escHTML(lei(x.suma)) : "—")</td></tr>"
            }.joined() + "</tbody></table>"
        let fara = r.amenziFaraData > 0
            ? "<p>+ \(r.amenziFaraData) \(r.amenziFaraData == 1 ? "amendă" : "amenzi") din controale neîncheiate, fără data aplicării (nu sunt numărate mai sus).</p>" : ""
        h.append("<section><h2>Amenzi aplicate în lună</h2>\(tabel)\n      \(fara)</section>")
    }
    if !r.anulate.isEmpty {
        h.append("<section><h2>Activități anulate</h2><ul class=\"f-list\">" + r.anulate.map { "<li>\(escHTML(titluActivitate($0))) — \(escHTML(cand($0)))</li>" }.joined() + "</ul></section>")
    }
    return h.joined()
}

/// Documentul întreg (tipărire / partajare), cu stilurile Fișei și ale Planului lunar
public func raportDocument(_ r: RaportLunar, _ controls: [Control], css: String) -> String {
    """
    <!doctype html><html lang="ro"><head><meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Plan lunar – \(escHTML(r.titlu))</title>
    <style>@page { size: A4; margin: 14mm; } body { margin: 0; padding: 16px; } \(css)</style></head>
    <body><div class="fisa-doc">\(raportMarkup(r, controls))</div></body></html>
    """
}

public func raportFileName(_ r: RaportLunar) -> String {
    "Plan-lunar-\(r.an)-\(r.luna + 1 < 10 ? "0" : "")\(r.luna + 1).html"
}
