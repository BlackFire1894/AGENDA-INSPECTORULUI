import XCTest
@testable import AgendaKit

/// Editorul: aceiași pași ca în aplicația web (ios/Diferential/editor.mjs apasă butoanele editorului web, scrie în
/// câmpuri, caută, anulează…) dau același control, același ecran (jeton cu jeton), aceleași mesaje și confirmări.
final class EditorWebTests: TestVectori {
    static let fisier = ProcessInfo.processInfo.environment["AGENDA_EDITOR"]
        ?? (NSHomeDirectory() + "/Library/Caches/AgendaKit-diferential/editor.json")
    nonisolated(unsafe) static var date: JSObiect?

    override func tearDown() {
        Ceas.uidFortat = nil
        super.tearDown()
    }

    func testPasiiDinWeb() throws {
        if DiferentialTests.date == nil {
            guard let data = FileManager.default.contents(atPath: DiferentialTests.fisier) else { throw XCTSkip("Lipsește \(DiferentialTests.fisier)") }
            DiferentialTests.date = try JSONValue.citeste(data).obiect
        }
        if Self.date == nil {
            guard let data = FileManager.default.contents(atPath: Self.fisier) else { throw XCTSkip("Lipsește \(Self.fisier) (rulați ios/teste.sh)") }
            Self.date = try JSONValue.citeste(data).obiect
        }
        let toate = DiferentialTests.date!.arr("controls").compactMap(\.obiect).map(Control.init)
        var pasi = 0, erori = 0
        for s in Self.date!.arr("secvente").compactMap(\.obiect) {
            erori += reia(s, toate, &pasi)
            if erori > 12 { XCTFail("Prea multe diferențe; opresc"); break }
        }
        print("Editor: \(pasi) pași reluați")
        XCTAssertGreaterThan(pasi, 200)
    }

    func testControlNou() throws {
        if DiferentialTests.date == nil {
            guard let data = FileManager.default.contents(atPath: DiferentialTests.fisier) else { throw XCTSkip("Lipsește \(DiferentialTests.fisier)") }
            DiferentialTests.date = try JSONValue.citeste(data).obiect
        }
        if Self.date == nil {
            guard let data = FileManager.default.contents(atPath: Self.fisier) else { throw XCTSkip("Lipsește \(Self.fisier) (rulați ios/teste.sh)") }
            Self.date = try JSONValue.citeste(data).obiect
        }
        let controls = DiferentialTests.date!.arr("controls").compactMap(\.obiect).map(Control.init)
        let cazuri = Self.date!.arr("controlNou").compactMap(\.obiect)
        XCTAssertGreaterThan(cazuri.count, 5)
        for x in cazuri {
            let m = modelControlNou(controls, x.str("q"))
            let s = Jetoane.Sir()
            s.t(m.eticheta)
            for o in m.obiective { s.b(false, o.exact ? ["exact"] : []); s.t(o.initiala); s.t(o.titlu); s.t(o.detalii); s.t("Control nou") }
            s.t(m.niciunul)
            XCTAssertEqual(s.text, x.str("html"), "„\(x.str("q"))”")
            XCTAssertEqual(m.buton, x.str("buton"), "„\(x.str("q"))”")
        }
    }

    /// Reia o secvență; întoarce numărul de pași cu diferențe (la prima diferență din secvență se oprește)
    private func reia(_ s: JSObiect, _ toate: [Control], _ nr: inout Int) -> Int {
        var controls = toate
        let id = s.str("id")
        guard let i = controls.firstIndex(where: { $0.id == id }) else { XCTFail("lipsește controlul \(id)"); return 1 }
        var c = controls[i]
        let ed = Editor()
        var ultimaActiune: ActiuneMesaj?
        for (k, p) in s.arr("pasi").compactMap(\.obiect).enumerated() {
            let pas = p.obj("pas")
            let unde = "secvența \(id), pasul \(k) \(JSONValue.object(pas).text())"
            var r = RezultatPas()
            var cereri: [CerereEditor] = []
            if let u = p["uid"]?.sir { Ceas.uidFortat = { u } } else { Ceas.uidFortat = nil }
            switch pas.str("t") {
            case "start":
                ed.deschide(c, tab: pas.str("tab"))
            case "click":
                var d: [String: String] = [:]
                for (k, v) in pas.obj("d") { d[k] = v.sir ?? v.textJS }
                let act = pas.str("act")
                let cat = categoriiPeEcran(modelEditor(c, controls, ed, azi: Mediu.AZI))
                r = ed.click(act, d, &c, catEcran: cat)
                if let q = r.cerere {
                    cereri.append(q)
                    let mesaje = r.mesaje
                    r = ed.click(act, d, &c, raspuns: pas.bool("raspuns"), catEcran: cat)
                    r.mesaje = mesaje + r.mesaje
                }
                if act == "gps-get", r.cereGps != nil {
                    let g = pas.obj("gps")
                    let r2 = ed.gpsPreluat(d["id"] ?? "", lat: g["lat"]!.numar!, lon: g["lon"]!.numar!, acc: g["acc"]!.numar!, &c)
                    r.mesaje += r2.mesaje
                }
            case "nav":
                ed.mergi(pas.str("hash"), c)
            case "input":
                let b = pas.str("bind"), v = pas.str("valoare")
                r = ed.input(b, v, &c)
                if pas.bool("change") {
                    if pas.bool("rerender") { r = ed.schimbaData(b, v, &c) }
                    if let g = pas["grav"]?.sir { r = ed.schimbaRegim(b, gravInainte: g == "1", &c) }
                }
                if pas.bool("focusout") { ed.iesireObs(b, v, c) }
            case "verif":
                r = ed.schimbaVerificare(pas.str("verif"), pas.str("valoare"), &c)
            case "cautare":
                ed.cauta(pas.str("q"))
            case "pauza":
                ed.pauza(c)
            case "mesaj":
                guard let a = ultimaActiune else { XCTFail("\(unde): nicio acțiune în mesaj"); return 1 }
                r = ed.actiuneMesaj(a, &c)
            default:
                XCTFail("pas necunoscut \(JSONValue.object(pas).text())"); return 1
            }
            controls[i] = c
            nr += 1

            // controlul
            if let w = p["c"] {
                let sw = IstoricEditor.instantaneu(c)
                if sw != w.text() {
                    let dif = diferenta(JSONValue.citesteSigur(sw), w) ?? "aceleași valori, altă ordine a cheilor"
                    XCTFail("\(unde): controlul diferă — \(dif)")
                    return 1
                }
            }
            // ruta, istoricul
            if ed.tab != p.str("tab") || ed.focus != p.str("focus") {
                XCTFail("\(unde): ruta \(ed.tab)/\(ed.focus) ≠ web \(p.str("tab"))/\(p.str("focus"))"); return 1
            }
            let h = ed.istoric.stare(c.id)
            let ist = p.arr("ist").compactMap(\.numar).map(Int.init)
            if [h.anulare, h.refacere] != ist { XCTFail("\(unde): istoric \([h.anulare, h.refacere]) ≠ web \(ist)"); return 1 }
            // mesajele
            let mw = p.arr("mesaje").compactMap(\.obiect).map { "\($0.str("nivel"))|\($0.str("text"))|\($0.str("actiune"))" }
            let ms = r.mesaje.map { "\($0.nivel)|\($0.text)|\($0.actiune?.eticheta ?? "")" }
            if mw != ms { XCTFail("\(unde): mesaje\n swift: \(ms)\n web:   \(mw)"); return 1 }
            if let a = r.mesaje.last(where: { $0.actiune != nil })?.actiune { ultimaActiune = a } else if !r.mesaje.isEmpty || !mw.isEmpty { ultimaActiune = nil }
            // ferestrele
            let fw = p.arr("modale").compactMap(\.sir)
            let fs = cereri.map(Jetoane.cerere)
            if fw != fs { XCTFail("\(unde): ferestre\n swift: \(fs)\n web:   \(fw)"); return 1 }
            // ecranul
            let js = Jetoane.editor(modelEditor(c, controls, ed, azi: Mediu.AZI))
            let jw = p.str("tok")
            if js != jw {
                XCTFail("\(unde): ecranul diferă\n\(Jetoane.diferenta(js, jw))")
                return 1
            }
        }
        return 0
    }
}

extension JSONValue {
    static func citesteSigur(_ s: String) -> JSONValue { (try? JSONValue.citeste(s)) ?? .null }
}

// ───────── modelul Swift → șirul de jetoane (aceeași regulă ca `jetoane()` din editor.mjs) ─────────

enum Jetoane {
    final class Sir {
        var p: [String] = []
        func t(_ s: String?) { if let s, !s.isEmpty { p.append(s) } }
        func b(_ on: Bool = false, dis: Bool = false, _ st: [String] = []) {
            p.append("⟦b\(on ? "+" : "")\(dis ? "!" : "")\(st.map { ".\($0)" }.joined())⟧")
        }
        func s(_ st: [String]) { if !st.isEmpty { p.append("⟦\(st.map { ".\($0)" }.joined())⟧") } }
        func s(_ x: String?) { if let x, !x.isEmpty { s([x]) } }
        func pill(_ x: PastilaUI) { p.append("⟦\(x.tip)|\(x.text.trimJS)⟧") }
        func inp(_ v: String, _ ph: String = "") { p.append("⟦in|\(v)|\(ph)⟧") }
        func ta(_ v: String, _ ph: String) { p.append("⟦ta|\(v)|\(ph)⟧") }
        func g(_ cat: String, _ closed: Bool) { p.append("⟦g:cat-\(cat)\(closed ? ".closed" : "")⟧") }
        var text: String {
            let s = p.joined(separator: " ").cuvinte.joined(separator: " ")
            let re = try! NSRegularExpression(pattern: "\\s+([.,;:])")
            return re.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "$1")
        }
    }

    static func diferenta(_ a: String, _ b: String) -> String {
        let x = a.cuvinte, y = b.cuvinte
        var i = 0
        while i < min(x.count, y.count) && x[i] == y[i] { i += 1 }
        let ctx = { (l: [String]) in l[max(0, i - 12)..<min(l.count, i + 25)].joined(separator: " ") }
        return " swift: …\(ctx(x))…\n web:   …\(ctx(y))…"
    }

    static func cerere(_ q: CerereEditor) -> String {
        let s = Sir()
        switch q {
        case .confirmare(let c):
            s.t(c.titlu); s.t(c.text); s.b(); s.t("Renunță"); s.b(); s.t(c.ok)
        case .restConform(let m):
            s.t(m.titlu); s.t(m.lead)
            for r in m.randuri { s.t(r.litera); s.t(r.text) }
            s.t(m.grave)
            s.inp(""); s.t(m.bifa)
            s.b(); s.t("Renunță"); s.b(dis: true); s.t(m.buton)
        case .inainteDeIncheiere(let l):
            s.t("Înainte de încheiere"); s.b()
            s.t("Au rămas \(l.count == 1 ? "un lucru necompletat" : "\(l.count) lucruri necompletate"). Atingeți unul ca să mergeți direct la el, sau încheiați oricum.")
            for x in l { s.b(false, ["t-\(x.level)"]); s.t(x.text) }
            s.b(); s.t("Revin să completez"); s.b(); s.t("Încheie oricum")
        }
        return s.text
    }

    static func editor(_ m: ModelEditor) -> String {
        let s = Sir()
        // antetul
        let a = m.antet
        s.b(); s.t(a.tip); s.pill(a.incheiat ? PastilaUI("done", "Încheiat") : PastilaUI("open", "În desfășurare")); s.t(a.titlu); s.t(a.perioada); s.t("Salvat")
        for x in ["Text PV", "Fișa PDF", "Istoric", "Backup"] { s.b(); s.t(x) }
        s.b()
        // ce mai aveți de făcut
        let td = m.todo
        if td.pasi.isEmpty { s.t("Totul e completat. Puteți genera Text PV sau Fișa PDF.") } else {
            if td.deschis { s.s(["open"]) }
            s.t("Ce mai aveți de făcut"); s.t("\(td.pasi.count)")
            if !td.deschis { s.b(false, ["t-\(td.pasi[0].level)"]); s.t(td.pasi[0].text) }
            if td.pasi.count > 1 || td.deschis { s.b(); s.t(td.deschis ? "Ascunde lista" : "Toate (\(td.pasi.count))") }
            if td.deschis { for x in td.pasi { s.b(false, ["t-\(x.level)"]); s.t(x.text) } }
        }
        // taburile
        for t in m.taburi {
            s.b(t.activ); s.t("\(t.nr)"); s.t(t.label)
            if t.avertizare { s.s(["warn"]) }
            s.t(t.text)
            if t.complet { s.s(["done"]) }
            s.t(t.progres); s.t("\(t.gata)/\(t.total)")
            if t.complet { s.s(["done"]) }
        }
        switch m.corp {
        case .obiectiv(let o): obiectiv(o, s)
        case .acte(let x): acte(x, s)
        case .sectiune(let x): sectiune(x, s)
        }
        s.b(dis: !m.anulare); s.t("Anulează"); s.b(); s.t("Sus"); s.b(dis: !m.refacere); s.t("Refă")
        return s.text
    }

    static func camp(_ c: ModelCamp, _ s: Sir) {
        s.t(c.eticheta); s.inp(c.valoare, c.indiciu); s.t(c.unitate)
    }
    static func segment(_ g: ModelSegment, _ s: Sir) {
        for o in g.optiuni { s.b(g.ales == o.key); s.t(o.label) }
    }
    static func comutator(_ c: ModelComutator, _ s: Sir) {
        s.b(c.activ, dis: false, c.activ ? ["t-\(c.nivel)"] : []); s.t(c.text)
    }
    static func obs(_ o: ModelObs, _ s: Sir) {
        if o.deschis { s.ta(o.valoare, "Observații") } else { s.b(); s.t("Obs.") }
    }
    static func numaratoare(_ n: ModelNumaratoare?, _ s: Sir) {
        guard let n else { return }
        if n.depasit { s.s(["over"]) }
        s.t("\(n.numar)"); s.t(n.text)
    }
    static func termen(_ t: ModelTermen, _ s: Sir) {
        s.s([t.nivel]); s.t(t.titlu); s.t(t.mesaj)
        if let x = t.nelucr { s.t("⚠ \(x)") }
        numaratoare(t.numaratoare, s)
    }
    static func okNok(_ o: ModelOkNok?, _ s: Sir) {
        guard let o else { return }
        s.b(o.stare == "ok"); s.t(o.ok); s.b(o.stare == "nok"); s.t(o.nok)
        if o.nec { s.b(o.stare == "nec"); s.t("NEC nu e cazul") }
    }

    // ───────── Obiectiv ─────────
    static func obiectiv(_ o: ModelTabObiectiv, _ s: Sir) {
        s.t("Date obiectiv"); s.t("Tip obiectiv"); segment(o.tip, s)
        for c in o.campuri {
            camp(c, s)
            if c.cale == "telefon" && !o.telefon.isEmpty { s.b() }
            if c.cale == "email" && !o.email.isEmpty { s.b() }
        }
        s.t("Perioada controlului"); s.t("Data începerii controlului"); s.inp(o.dataInceput); s.b(); s.t("Azi")
        s.t("Data încheierii controlului")
        if o.incheiat {
            s.inp(o.dataIncheiere); s.b(); s.t("Azi"); s.b(); s.t("Redeschide")
            if o.eroareIncheiere { s.t("Data încheierii este înaintea datei de începere.") }
        } else {
            s.t("Control în desfășurare"); s.b(); s.t("Încheie controlul"); s.t("Se completează implicit cu data începerii; o puteți modifica după.")
        }
        if let i = o.incarcare {
            s.t("Încărcare după încheiere")
            comutator(i.aplicatie, s); s.t(i.aplicatieData)
            comutator(i.document, s); s.t(i.documentData)
            termen(i.termen, s)
        }
        s.t("Construcții"); s.b(); s.t("−"); s.t("\(o.constructii.count)"); s.t(o.constructii.count == 1 ? "construcție" : "construcții"); s.b(); s.t("+")
        for k in o.constructii { constructie(k, s) }
        if let a = o.adaposturi {
            s.t("Adăposturi de protecție civilă")
            randAdapost(a.rand, s)
            for n in a.randuri { randNeregula(n, s) }
            if a.notaNeconforme { s.t("Adăposturile neconforme sunt nereguli: apar și în tabul Nereguli (PV, amendă), la „Adăposturi de protecție civilă”.") }
        }
    }

    static func constructie(_ k: ModelConstructie, _ s: Sir) {
        if k.deschisa { s.s(["open"]) }
        s.t("\(k.nr)"); s.inp(k.denumire.valoare, k.denumire.indiciu)
        if let l = k.lipsa { s.pill(PastilaUI("red", l)) }
        if k.grfV { s.pill(PastilaUI("red", "GRF/NSI V peste parter")) }
        s.t(k.sumar); s.b()
        guard let c = k.corp else { return }
        for x in c.campuri { camp(x, s) }
        if c.grf.grav { s.s(["is-grav"]) }
        s.t("GRF / NSI"); s.t("grad de rezistență la foc / nivel de stabilitate la incendiu")
        for o in ModelGrf.optiuni { s.b(c.grf.ales == o.key); s.t(o.label) }
        if let n = c.grf.nota { s.t(n); s.b(); s.t("Vezi") }
        gps(c.gps, s)
        s.t("Dotări și instalații"); s.t("NEC = nu este cazul")
        for d in c.dotari {
            if d.centrala {
                s.t(d.eticheta)
                for t in K.centralaTipuri { s.b(d.tipuri.contains(t)); s.t(t) }
                s.b(d.nuAre); s.t("NU ARE")
                obs(d.obs, s)
                continue
            }
            if d.grav { s.s(["is-grav"]) }
            s.t(d.eticheta)
            if d.grav { s.t("Neregulă gravă") }
            if let g = d.segment { segment(g, s) }
            obs(d.obs, s)
            if let n = d.nr { camp(n, s) }
        }
        if c.stergere { s.b(); s.t("Șterge construcția") }
    }

    static func gps(_ g: ModelGps, _ s: Sir) {
        s.t("Coordonate GPS")
        guard let coord = g.coordonate else {
            s.s(["is-empty"]); s.t("Necompletat"); s.b(dis: g.cautare); s.t(g.cautare ? "Se caută semnalul…" : "Completează coordonatele")
            s.t("Doar la cerere: poziția se citește o singură dată, când apăsați, lângă această construcție. Nu se urmărește locația.")
            return
        }
        s.t(coord); s.s(["q-\(g.calitate)"]); s.t(g.precizie)
        if let p = g.preluate { s.t("· \(p)") }
        if g.slaba { s.t("Precizie slabă: ieșiți în aer liber sau lângă o fereastră și apăsați „Actualizează”.") }
        s.b(); s.t("Google Maps"); s.b(); s.t("Hărți Apple"); s.b(); s.t("Copiază"); s.b(dis: g.cautare); s.t(g.cautare ? "Se caută…" : "Actualizează"); s.b()
    }

    static func randAdapost(_ a: ModelRandAdapost, _ s: Sir) {
        s.t(a.litera); s.t("Adăposturi de protecție civilă"); s.t("NEC = nu este cazul")
        if let n = a.numar {
            s.t("Câte adăposturi?"); s.b(dis: n == 0); s.t("−")
            if n == 0 { s.s(["is-empty"]) }
            s.t("\(n)"); s.t(n == 1 ? "adăpost" : "adăposturi"); s.b(); s.t("+")
            s.t(a.sumar ?? "Apăsați + pentru fiecare adăpost; apoi completați locația și starea lui.")
        }
        obs(a.obs, s)
        segment(a.segment, s)
    }

    // ───────── Acte ─────────
    static func cautare(_ c: ModelCautare, _ s: Sir) {
        s.inp(c.valoare, c.indiciu); s.b()
        if !c.meniu.isEmpty { s.b(c.meniuDeschis) }
        if c.meniuDeschis { for b in c.meniu { s.b(); s.t(b.text) } }
    }
    static func filtre(_ f: [ModelFiltru], _ rest: String?, _ s: Sir) {
        for x in f { s.b(x.activ); s.t(x.text) }
        if let r = rest { s.b(); s.t(r) }
    }
    static func nota(_ n: ModelNotaCautare?, _ s: Sir) {
        guard let n else { return }
        if n.gasite == 0 { s.s(["none"]) }
        s.t(n.text)
        if n.cautaInToate { s.b(); s.t("Caută în toate") }
        if let a = n.ascunse { s.b(); s.t(a) }
    }
    static func info(_ l: [ModelInfoCategorie], _ s: Sir) {
        for x in l {
            if ["st-rest", "st-gata", "pv-rest", "pv-gata"].contains(x.tip) { s.s([x.tip]) }
            s.t(x.text)
        }
    }

    static func acte(_ a: ModelTabActe, _ s: Sir) {
        s.t("\(a.verificate)"); s.t("/\(a.total) verificate"); s.s(["t-green"]); s.t("\(a.prezentate)"); s.t("prezentate")
        if a.lipsa > 0 { s.s(["t-red"]); s.t("\(a.lipsa)"); s.t("lipsă") }
        if a.nec > 0 { s.t("\(a.nec)"); s.t("NEC") }
        cautare(a.cautare, s)
        filtre(a.filtru, a.rest, s)
        nota(a.rezultat, s)
        let g = a.grup
        s.g("acte", g.restrans); s.b(dis: g.dezactivat); s.t("Acte de autoritate și evidențe"); s.t(g.numar); info(g.info, s)
        if !g.restrans {
            if g.randuri.isEmpty { s.t("Nimic de afișat pentru acest filtru.") }
            for r in g.randuri {
                s.s((r.stare.isEmpty ? [] : ["is-\(r.stare)"]) + (r.restrans ? ["is-collapsed"] : []))
                s.t("\(r.nr)"); s.t(r.eticheta)
                for x in r.pastile { s.pill(x) }
                if r.obsInBara != nil { s.b(); s.t("Obs.") }
                okNok(r.okNok, s)
                s.b()
                if let o = r.obs { obs(o, s) }
            }
        }
    }

    // ───────── Nereguli / Planuri / PC ─────────
    static func sectiune(_ x: ModelTabSectiune, _ s: Sir) {
        s.t("\(x.verificate)"); s.t("/\(x.total) verificate")
        if x.constatate > 0 { s.s(["t-red"]) }
        s.t("\(x.constatate)"); s.t(x.nokWord)
        if x.constatate > 0 { s.s([x.netrecute > 0 ? "t-warn" : "t-green"]); s.t("\(x.inPV)"); s.t("/\(x.constatate) în PV") }
        if x.amenzi > 0 { s.t("\(x.amenzi)"); s.t(x.amenzi == 1 ? "amendă" : "amenzi") }
        if let a = x.ascunse { s.b(); s.t(a) }
        if x.notaTermene { s.t("Termenele amenzilor\(x.sec == "ner" ? " și ASI" : "") pornesc după ce completați data încheierii (tabul Obiectiv).") }
        cautare(x.cautare, s)
        filtre(x.filtru, x.rest, s)
        nota(x.rezultat, s)
        for g in x.grupe {
            s.g(g.cat, g.restrans); s.b(dis: g.dezactivat); s.t(g.titlu); s.t(g.numar); info(g.info, s)
            for r in g.randuri {
                switch r {
                case .neregula(let n): randNeregula(n, s)
                case .adapost(let a): randAdapost(a, s)
                }
            }
        }
        s.t(x.gol)
        let a = x.adaugate
        s.b(dis: a.dezactivat); s.t(a.titlu); s.t(a.numar); info(a.info, s)
        s.b(); s.t("Adaugă rând")
        if !a.restrans {
            s.g("custom", false)
            for n in a.randuri { randNeregula(n, s) }
            s.t(a.gol)
        }
    }

    static func randNeregula(_ n: ModelRandNeregula, _ s: Sir) {
        var st: [String] = []
        if !n.stare.isEmpty { st.append("is-\(n.stare)") }
        if n.veche { st.append("is-veche") }
        if n.gravAdaugat { st.append("is-grav-custom") }
        if n.restrans { st.append("is-collapsed") }
        s.s(st)
        s.t(n.litera)
        if n.adapost { s.t("Adăpost de protecție civilă") }
        if let c = n.campEticheta { s.inp(c.valoare, c.indiciu) } else { s.t(n.eticheta) }
        for p in n.pastile { s.pill(p) }
        if n.obsInBara != nil { s.b(); s.t("Obs.") }
        okNok(n.okNok, s)
        s.b()
        guard let c = n.corp else { return }
        if let v = c.verificare {
            s.t(v.titlu)
            for r in v.randuri {
                if r.expirata { s.s(["is-exp"]) }
                s.t(r.nume); s.inp(r.data)
                for l in r.alegeri ?? [] { s.b(r.luni == l); s.t("\(l) luni") }
                s.t(r.text)
            }
            if let p = v.propunere { s.t(p.text); s.b(); s.t(p.buton) }
        }
        s.t(c.constrNU)
        if let x = c.constrSelect {
            if x.deschis { s.s(["open"]) }
            s.b(dis: !x.multe); s.t(x.eticheta); s.t(x.valoare)
            if x.deschis {
                for o in x.optiuni { s.b(o.ales); s.t(o.text) }
                s.t(x.nota)
                s.b(dis: x.toate); s.t("Toate construcțiile"); s.b(); s.t("Gata")
            }
        }
        obs(c.obs, s)
        if c.stergere { s.b() }
        guard let d = n.detaliu else { return }
        comutator(d.inPV, s); comutator(d.amenda, s)
        if let v = d.vecheNota { s.t(v) }
        if let v = d.vecheManual { comutator(v, s) }
        if let g = d.grav { comutator(g, s) }
        if let g = d.sigiliu { comutator(g, s) }
        if let a = d.asi {
            comutator(a.termen, s)
            if let x = a.prezentat { comutator(x, s) }
            if let x = a.pierdere { comutator(x, s) }
            if let t = a.stare { termen(t, s) }
            if let x = a.dataPierdere { camp(x, s) }
            if let x = a.dataPrezentare { camp(x, s) }
        }
        if let f = d.amendaBox {
            s.s(["fb-\(f.nivel)"]); s.t(f.titlu); s.t(f.mesaj)
            camp(f.serie, s)
            camp(f.data, s)
            if f.folosesteIncheierea { s.b(); s.t("Folosește data încheierii") } else { s.t(f.dataImplicita) }
            camp(f.suma, s)
            s.t("Plată"); comutator(f.achitata, s)
            if let x = f.dataAchitare { camp(x, s) }
            for e in [f.plata, f.anaf].compactMap({ $0 }) {
                s.s(e.stare); s.t(e.text); s.t(e.data); s.t(e.nelucr)
            }
            s.t(f.nelucr)
        }
    }
}
