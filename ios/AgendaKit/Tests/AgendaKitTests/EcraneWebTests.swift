import XCTest
@testable import AgendaKit

/// Ecranele: conținutul calculat în Swift (texte, pastile, filtre, în ordine) = ce afișează codul web (js/views.js)
/// pentru aceleași date. HTML-ul web vine din verificarea încrucișată (ios/Diferential/genereaza.mjs).
final class EcraneWebTests: TestVectori {
    var d: JSObiect!
    var controls: [Control] = []
    var activitati: [Activitate] = []

    override func setUpWithError() throws {
        try super.setUpWithError()
        if DiferentialTests.date == nil {
            guard let data = FileManager.default.contents(atPath: DiferentialTests.fisier) else { throw XCTSkip("Lipsește \(DiferentialTests.fisier)") }
            DiferentialTests.date = try JSONValue.citeste(data).obiect
        }
        d = DiferentialTests.date
        guard d["ecrane"] != nil else { throw XCTSkip("Fișierul verificării încrucișate e vechi (rulați ios/teste.sh)") }
        controls = d.arr("controls").compactMap(\.obiect).map(Control.init)
        activitati = d.arr("activitati").compactMap(\.obiect).map(Activitate.init)
    }

    // ───────── HTML web → șir de comparat ─────────

    private func inlocuieste(_ s: String, _ tipar: String, _ f: ([String]) -> String) -> String {
        let re = try! NSRegularExpression(pattern: tipar)
        var out = ""
        var ultim = s.startIndex
        for m in re.matches(in: s, range: NSRange(s.startIndex..., in: s)) {
            let r = Range(m.range, in: s)!
            out += s[ultim..<r.lowerBound]
            let g = (0..<m.numberOfRanges).map { i in Range(m.range(at: i), in: s).map { String(s[$0]) } ?? "" }
            out += f(g)
            ultim = r.upperBound
        }
        return out + s[ultim...]
    }

    func dinHTML(_ html: String) -> String {
        var s = html.inlocuiesteRegex("<svg[\\s\\S]*?</svg>", "")
        s = inlocuieste(s, "<span class=\"pill ([^\"]+)\">([\\s\\S]*?)</span>") { g in
            let clase = g[1].split(separator: " ").map(String.init)
            let tip = clase.first { $0.hasPrefix("fs-") } ?? clase.first { $0.hasPrefix("pill-") }.map { String($0.dropFirst(5)) } ?? "?"
            return " ⟦\(tip)|\(g[2].trimJS)⟧ "
        }
        s = inlocuieste(s, "<button class=\"flt-btn flt-\\w+ ?(on)?\" data-act=\"flt-toggle\" data-list=\"\\w+\" data-val=\"([^\"]+)\" aria-pressed=\"\\w+\" ?(disabled)?>[\\s\\S]*?<span>([^<]*)</span><b>(\\d+)</b></button>") { g in
            " ⟦flt|\(g[2])|\(g[1].isEmpty ? 0 : 1)|\(g[4])|\(g[5])|\(g[3].isEmpty ? 0 : 1)⟧ "
        }
        s = s.inlocuiesteRegex("<[^>]+>", " ")
        for (e, c) in [("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&#39;", "'")] { s = s.replacingOccurrences(of: e, with: c) }
        return fara(s.cuvinte.joined(separator: " "))
    }

    /// „aplicației .” (eticheta <b> închisă înainte de punct) = „aplicației.”
    private func fara(_ s: String) -> String {
        let re = try! NSRegularExpression(pattern: "\\s+([.,;:])")
        return re.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "$1")
    }

    // ───────── modelele Swift → același șir ─────────

    private func sir(_ parti: [String?]) -> String { fara(parti.compactMap { $0 }.joined(separator: " ").cuvinte.joined(separator: " ")) }
    private func p(_ x: PastilaUI) -> String { "⟦\(x.tip)|\(x.text)⟧" }
    private func f(_ b: ButonFiltru) -> String { "⟦flt|\(b.key)|\(b.activ ? 1 : 0)|\(b.label)|\(b.numar)|\(b.dezactivat ? 1 : 0)⟧" }
    private func gol(_ g: Gol) -> String { sir([g.titlu, g.text, g.controlNou ? "Control nou" : nil]) }
    private func filtre(_ b: [ButonFiltru]?, _ sterge: Bool) -> String { sir((b ?? []).map(f) + [sterge ? "Șterge filtrele" : nil]) }

    func rand(_ r: ModelRandControl) -> String {
        sir(["\(r.zi)", r.lunaScurt, r.an, r.titlu, r.tip, r.perioada, r.administrator.map { "· \($0)" }] + r.pastile.map(p))
    }

    private func textMarkdown(_ s: String) -> String { s.replacingOccurrences(of: "**", with: "") }

    func panou(_ m: ModelPanou) -> String {
        guard let casete = m.casete else {
            return sir([BUN_VENIT_TITLU, textMarkdown(bunVenitText("această tabletă")), "Control nou", "Încarcă date demonstrative", "Ghidul aplicației"])
        }
        var parti: [String?] = []
        if let s = m.sarbatori { parti += [s.titlu, s.text, s.rezumat] + s.lista.map { "\($0.data) — \($0.nume)" } + [s.buton] }
        if !m.deConfirmat.isEmpty {
            parti += ["Activități de confirmat (\(m.deConfirmat.count))", TEXT_DE_CONFIRMAT]
            for a in m.deConfirmat {
                let x = modelActivitate(a, controls, confirmare: true)
                parti += [x.tipText, x.titlu, x.cand, p(x.stare)] + x.butoane
            }
        }
        for k in casete {
            parti += ["\(k.numar)", k.eticheta] + k.legenda.map { "\($0.1) \($0.2)" } + k.subsol
        }
        for s in m.sectiuni {
            parti.append(s.titlu)
            if s.sectiune == .amenzi { parti += LEGENDA_AMENZI.map(\.1) }
            if s.elemente.isEmpty { parti.append(s.gol) }
            parti += s.elemente.flatMap(element)
            if !s.achitate.isEmpty { parti.append("Achitate (\(s.achitate.count))"); parti += s.achitate.flatMap(element) }
        }
        return sir(parti)
    }

    private func element(_ e: ElementPanou) -> [String?] {
        [e.titlu] + e.sub + e.pastileCorp.map(p) + [e.mesaj, e.avertizare, e.veche ? "Neregulă veche" : nil]
            + e.pastileDreapta.map(p) + [e.suma, e.numaratoare.map { "\($0.numar) \($0.text)" }]
    }

    // ───────── testele ─────────

    func testRandulControlului() {
        let e = d.obj("ecrane")
        var n = 0
        for x in e.arr("randuri").compactMap(\.obiect) {
            let c = controls.first { $0.id == x.str("id") }!
            XCTAssertEqual(rand(modelRandControl(c, controls, Mediu.AZI)), dinHTML(x.str("cu")), "rând \(c.id)")
            XCTAssertEqual(rand(modelRandControl(c, controls, Mediu.AZI, arataNumele: false)), dinHTML(x.str("fara")), "rând fără nume \(c.id)")
            n += 1
        }
        XCTAssertGreaterThan(n, 100)
    }

    func testObiectivele() {
        for x in d.obj("ecrane").arr("obiective").compactMap(\.obiect) {
            let m = modelListaObiective(controls, q: x.str("q"), tip: x.str("tip"), filtre: x.strs("flt"), azi: Mediu.AZI)
            var parti: [String?] = [filtre(m.filtre, m.arataStergeFiltrele)]
            if let g = m.gol { parti.append(gol(g)) } else {
                parti.append(m.numar)
                for c in m.carduri {
                    parti += [c.initiale, c.titlu, c.tip, c.localitate, c.administrator, c.telefon.map { "· \($0)" }] + c.pastile.map(p)
                }
            }
            XCTAssertEqual(sir(parti), dinHTML(x.str("html")), "obiective q=„\(x.str("q"))” tip=\(x.str("tip")) filtre=\(x.strs("flt"))")
        }
    }

    func testIstoricul() {
        for x in d.obj("ecrane").arr("istoric").compactMap(\.obiect) {
            let m = modelIstoric(controls, q: x.str("q"), stare: x.str("stare"), filtre: x.strs("flt"), azi: Mediu.AZI)
            var parti: [String?] = [filtre(m.filtre, m.arataStergeFiltrele)]
            if let g = m.gol { parti.append(gol(g)) } else {
                parti.append(m.numar)
                for g in m.grupe { parti += [g.titlu, "\(g.randuri.count)"] + g.randuri.map(rand) }
            }
            XCTAssertEqual(sir(parti), dinHTML(x.str("html")), "istoric q=„\(x.str("q"))” stare=\(x.str("stare")) filtre=\(x.strs("flt"))")
        }
    }

    func testPaginaObiectivului() {
        for x in d.obj("ecrane").arr("pagini").compactMap(\.obiect) {
            let m = modelObiectiv(controls, x.str("id"), azi: Mediu.AZI)!
            var parti: [String?] = [m.tip, m.titlu, "Control nou pe acest obiectiv",
                                    "Administrator", m.administrator, "Telefon", m.telefon ?? "—", "Email", m.email ?? "—", "Adresă", m.adresa,
                                    "Construcții", "\(m.constructii)", "Coordonate GPS pe construcții"]
            for g in m.gps { parti += ["\(g.nume):", g.coordonate.map { "\($0) · Hărți Apple" } ?? "necompletate"] }
            for (n, t) in m.statistici { parti += ["\(n)", t] }
            parti.append("Istoricul controalelor")
            parti += m.istoric.map(rand)
            XCTAssertEqual(sir(parti), dinHTML(x.str("html")), "obiectivul \(x.str("id"))")
        }
    }

    func testPanoul() {
        for x in d.obj("ecrane").arr("panou").compactMap(\.obiect) {
            var html = x.str("html")
            html = html.inlocuiesteRegex("<header class=\"dash-head\">[\\s\\S]*?</header>", "")
            let m = x.obj("meta")
            let meta = Meta(lastBackup: nil, sarbatoriVerificate: m.arr("sarbatoriVerificate").compactMap { $0.numar.map { Int($0) } })
            let cs = x.bool("gol") ? [] : controls
            XCTAssertEqual(panou(modelPanou(cs, activitati, meta, azi: x.str("azi"))), dinHTML(html), "Panoul la \(x.str("azi"))")
        }
    }

    // ───────── calendarul ─────────

    func testCalendarul() throws {
        let l = d.obj("ecrane").arr("calendar").compactMap(\.obiect)
        guard !l.isEmpty else { throw XCTSkip("Fișierul verificării încrucișate e vechi (rulați ios/teste.sh)") }
        for x in l {
            let m = modelCalendar(controls, activitati, an: x.int("an")!, luna: x.int("luna")!, selectat: x.str("sel"), azi: Mediu.AZI)
            let s = Jetoane.Sir()
            s.t(m.supratitlu); s.t("\(K.luni[m.luna]) \(m.an)")
            s.b(); s.t("\(m.an)"); s.t("anul"); s.b()
            s.b(); s.t(K.luniScurt[m.luna]); s.t("luna"); s.b()
            s.b(); s.t("Azi"); s.b(); s.t("Plan lunar")
            for z in ZILE_SCURT { s.t(z) }
            for c in m.celule {
                s.b(false, dis: false, (c.inLuna ? [] : ["out"]) + (c.libera ? ["is-liber"] : []) + (c.azi ? ["is-today"] : []) + (c.selectata ? ["is-sel"] : []))
                s.t("\(c.numar)")
                for e in c.etichete {
                    switch e.tip {
                    case "liber": s.s(["ev-liber"] + (e.sarbatoare ? ["ev-sarb"] : []) + ["st-\(e.stare)"])
                    case "act": s.s(["ev-act", "act-\(e.tipActivitate)", "st-\(e.stare)"])
                    default: s.s(["ev-\(e.tip)"])
                    }
                    s.t(e.text)
                }
                if c.maiMulte > 0 { s.t("+\(c.maiMulte)") }
                for t in c.termene { s.s(["dot-\(t)"]) }
            }
            for (cls, t) in LEGENDA_CALENDAR {
                if cls.hasPrefix("dot-") { s.s([cls]) }
                s.t(t)
            }
            s.t(legendaLiber(telefon: false))
            let z = m.zi
            s.t(z.eticheta); s.t(z.titlu)
            if let lib = z.libera { if lib.sarbatoare { s.s(["ev-sarb"]) }; s.t(lib.text); s.pill(lib.stare) }
            if z.controale.isEmpty { s.t("Niciun control în această zi.") }
            for c in z.controale { s.b(); s.t(rand(modelRandControl(c, controls, Mediu.AZI))) }
            if !z.termene.isEmpty {
                s.t("Termene")
                for t in z.termene { s.b(false, dis: false, ["item-\(t.level)"]); s.t(t.titlu); s.t(t.sub) }
            }
            if z.activitati.isEmpty { s.t("Nicio activitate în această zi.") } else {
                s.t("Activități")
                for a in z.activitati {
                    let x = modelActivitate(a, controls)
                    s.s(["act-\(a.tip)", "st-\(a.stare)"])
                    s.b(); s.t(x.tipText); s.t(x.titlu); s.t(x.cand); s.pill(x.stare)
                    for b in x.butoane { s.b(); s.t(b) }
                }
            }
            s.b(); s.t("Control nou în această zi"); s.b(); s.t("Activitate nouă în această zi")
            XCTAssertEqual(s.text, x.str("tok"), "calendarul \(m.luna + 1)/\(m.an), ziua \(x.str("sel"))")
            if s.text != x.str("tok") { print(Jetoane.diferenta(s.text, x.str("tok"))); return }
        }
    }

    /// Fereastra activității: aceleași verificări și aceeași normalizare ca `openActivitate` din web
    func testSalvareaActivitatii() {
        var a = emptyActivitate("2026-10-20", Mediu.AZI)
        XCTAssertEqual(a.stare, "planificat")
        XCTAssertEqual(emptyActivitate("2026-10-01", Mediu.AZI).stare, "efectuat")
        a.data = ""
        XCTAssertEqual(salveazaActivitate(a).eroare, "Alegeți data activității.")
        a.data = "2026-10-20"; a.dataSfarsit = "2026-10-19"
        XCTAssertEqual(salveazaActivitate(a).eroare, "„Până la” nu poate fi înaintea datei de început.")
        a.dataSfarsit = "2026-10-20"; a.tip = "alta"; a.descriere = "   "
        XCTAssertEqual(salveazaActivitate(a).eroare, "Scrieți descrierea activității.")
        a.descriere = "  Vizită  "
        let r = salveazaActivitate(a)
        XCTAssertNil(r.eroare)
        XCTAssertEqual(r.activitate?.descriere, "Vizită")
        XCTAssertEqual(r.activitate?.dataSfarsit, "")   // aceeași zi: fără „până la”
        XCTAssertEqual(r.activitate.map(titluActivitate), "Vizită")
        a.tip = "sedinta"; a.descriere = ""; a.dataSfarsit = "2026-10-22"; a.ora = "09:30"
        XCTAssertEqual(salveazaActivitate(a).activitate.map(cand), "20.10.2026 – 22.10.2026 (3 zile), ora 09:30")
        XCTAssertEqual(lunaDeplasata(2026, 0, -1).an, 2025); XCTAssertEqual(lunaDeplasata(2026, 0, -1).luna, 11)
        XCTAssertEqual(lunaDeplasata(2026, 11, 1).an, 2027); XCTAssertEqual(lunaDeplasata(2026, 11, 1).luna, 0)
        XCTAssertEqual(raportFileName(raportLunar([], [], 2026, 8, Mediu.AZI)), "Plan-lunar-2026-09.html")
    }

    /// Ghidul: cuprinsul și capitolele găsite, același HTML ca `viewGhid` din web
    func testGhidul() throws {
        let g = try Ghid(data: Docs.date("ghid.json"))
        XCTAssertEqual(g.capitole.count, 18)
        let l = d.obj("ecrane").arr("ghid").compactMap(\.obiect)
        guard !l.isEmpty else { throw XCTSkip("Fișierul verificării încrucișate e vechi (rulați ios/teste.sh)") }
        for x in l {
            XCTAssertEqual(g.cuprinsHTML(x.str("q")), x.str("toc"), "cuprinsul pentru „\(x.str("q"))”")
            XCTAssertEqual(g.listaHTML(x.str("q")), x.str("lista"), "capitolele pentru „\(x.str("q"))”")
        }
    }

    func testTextele() {
        XCTAssertEqual(hintText(""), "Scrieți numele obiectivului sau o dată: 12.09.2026, 09.2026 sau 2026.")
        XCTAssertEqual(hintText("10.2026"), "Controale din octombrie 2026")
        XCTAssertEqual(hintText("12.10.2026"), "Controale care includ ziua de luni, 12 octombrie 2026")
        XCTAssertEqual(hintText("2026"), "Controale din anul 2026")
        XCTAssertEqual(hintText("școala"), "Caut după nume: „școala”")
        let meta = Meta(lastBackup: "2026-10-15T08:30", sarbatoriVerificate: [])
        XCTAssertEqual(backupAgeText(meta, azi: "2026-10-15"), "ultimul: azi, 08:30")
        XCTAssertEqual(backupAgeText(meta, azi: "2026-10-16"), "ultimul: ieri")
        XCTAssertEqual(backupAgeText(meta, azi: "2026-11-15"), "ultimul: acum 31 de zile")
        XCTAssertEqual(backupAgeText(Meta(), azi: "2026-10-15"), "niciun backup încă")
    }
}
