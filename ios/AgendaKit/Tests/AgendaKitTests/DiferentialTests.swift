import XCTest
@testable import AgendaKit

/// Verificarea încrucișată web ↔ Swift: ios/Diferential/genereaza.mjs trece date aleatoare prin CODUL WEB
/// și scrie rezultatele; aici Swift calculează aceleași lucruri și trebuie să dea exact același rezultat.
/// Fișierul se generează cu `ios/teste.sh` (are nevoie de Node.js); fără el, testul e sărit.
final class DiferentialTests: TestVectori {
    static let fisier = ProcessInfo.processInfo.environment["AGENDA_DIFERENTIAL"]
        ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Caches/AgendaKit-diferential/cazuri.json").path

    nonisolated(unsafe) static var date: JSObiect?
    var d: JSObiect!
    var controls: [Control] = []
    var activitati: [Activitate] = []
    var diferente = 0

    override func setUpWithError() throws {
        try super.setUpWithError()
        if Self.date == nil {
            guard let data = FileManager.default.contents(atPath: Self.fisier) else {
                throw XCTSkip("Lipsește \(Self.fisier) (rulați ios/teste.sh, care îl generează cu Node.js)")
            }
            Self.date = try JSONValue.citeste(data).obiect
        }
        d = Self.date
        XCTAssertEqual(d.str("acum"), isoMs(Mediu.ACUM))
        controls = d.arr("controls").compactMap(\.obiect).map(Control.init)
        activitati = d.arr("activitati").compactMap(\.obiect).map(Activitate.init)
    }

    /// Compară; la primele 40 de diferențe scrie unde e diferența
    private func compara(_ swift: JSONValue, _ web: JSONValue?, _ ce: @autoclosure () -> String, file: StaticString = #filePath, line: UInt = #line) {
        if let dif = diferenta(swift, web ?? .null) {
            diferente += 1
            if diferente <= 40 { XCTFail("\(ce()): \(dif)", file: file, line: line) }
        }
    }

    private func ids(_ l: [Constructie]) -> JSONValue { JSONValue(l.map(\.id)) }
    private func n(_ x: Int) -> JSONValue { .number(Double(x)) }
    private func amendaJSON(_ key: String, _ st: StadiuAmenda) -> JSONValue {
        .object(JSObiect([("key", .string(key))]).combinat(cu: st.json.obiect!))
    }

    func testVolumul() {
        XCTAssertGreaterThan(controls.count, 100)
        XCTAssertEqual(d.arr("perControl").count, controls.count)
    }

    func testNormalizareaEsteIdempotenta() {
        for c in controls { compara(normalizeControl(c.o).json, c.json, "normalizare \(c.id)") }
        for a in activitati { compara(normalizeActivitate(a.o).json, a.json, "activitate \(a.id)") }
    }

    func testNormalizareaDatelorVechi() {
        let v = d.arr("vechi").compactMap(\.obiect)
        XCTAssertEqual(v.count, 40)
        for (i, x) in v.enumerated() { compara(normalizeControl(x.obj("intrare")).json, x["rezultat"], "date vechi #\(i)") }
    }

    func testTermeneleZiCuZi() {
        var cazuri = 0
        for p in d.arr("perControl").compactMap(\.obiect) {
            let c = controls.first { $0.id == p.str("id") }!
            for z in p.arr("zile").compactMap(\.obiect) {
                let azi = z.str("d")
                let am: [JSONValue] = activeNereguli(c).filter { $0.status == "nok" && $0.amenda.aplicata }
                    .map { ["key": .string($0.key), "st": fineStatus(c, $0, azi).json] }
                compara(.array(am), z["amenzi"], "amenzi \(c.id) azi \(azi)")
                compara(asiDeadline(c, azi)?.json ?? .null, z["asi"], "ASI \(c.id) azi \(azi)")
                compara(incarcareStatus(c, azi)?.json ?? .null, z["incarcare"], "încărcare \(c.id) azi \(azi)")
                cazuri += am.count + 2
            }
        }
        XCTAssertGreaterThan(cazuri, 5000)
    }

    func testControlul() {
        for p in d.arr("perControl").compactMap(\.obiect) {
            let c = controls.first { $0.id == p.str("id") }!
            let id = c.id
            let s = controlStats(c)
            compara(.object(JSObiect([
                ("acteDone", n(s.acteDone)), ("acteTotal", n(s.acteTotal)), ("acteNok", n(s.acteNok)),
                ("nereguliChecked", n(s.nereguliChecked)), ("nereguliTotal", n(s.nereguliTotal)),
                ("constatate", n(s.constatate)), ("netrecute", n(s.netrecute)),
                ("fines", .array(s.fines.map { amendaJSON($0.n.key, $0.st) })),
                ("asi", s.asi?.json ?? .null), ("incarcare", s.incarcare?.json ?? .null),
            ])), p["controlStats"], "controlStats \(id)")
            var ss = JSObiect()
            for sec in sectiuniActive(c) {
                let x = secStats(c, sec)
                ss[sec] = ["total": n(x.total), "checked": n(x.checked), "hidden": n(x.hidden), "constatate": n(x.constatate),
                           "netrecute": n(x.netrecute), "fines": .array(x.fines.map { amendaJSON($0.n.key, $0.st) })]
            }
            compara(.object(ss), p["secStats"], "secStats \(id)")
            compara(.array(todoList(c).map(\.json)), p["todoList"], "todoList \(id)")
            compara(.array(todoList(c, includeClose: false).map(\.json)), p["todoFaraInchidere"], "todoList fără încheiere \(id)")
            let pv = pvText(c, controls), pvn = pvText(c, controls, doarNetrecute: true, cuActe: false)
            compara(["text": .string(pv.text), "count": n(pv.count)], p["pvText"], "pvText \(id)")
            compara(["text": .string(pvn.text), "count": n(pvn.count)], p["pvNetrecute"], "pvText netrecute \(id)")
            compara(sigiliiControl(c)?.json ?? .null, p["sigilii"], "sigilii \(id)")
            compara(sigiliiControl(c).map { .string(sigiliiText($0)) } ?? .null, p["sigiliiText"], "sigiliiText \(id)")
            compara(adaposturiStats(c)?.json ?? .null, p["adaposturi"], "adăposturi \(id)")
            compara(adaposturiStats(c).map { .string(adaposturiText($0)) } ?? .null, p["adaposturiText"], "adaposturiText \(id)")
            compara(n(catalogOf(c)), p["catalogOf"], "catalogOf \(id)")
            compara(JSONValue(acteOf(c).map(\.key)), p["acteOf"], "acteOf \(id)")
            let dot: [JSONValue] = c.constructii.map { k in
                .object(JSObiect([("vis", JSONValue(dotariVizibile(c, k).map(\.key))), ("are", .bool(areCentrala(k))),
                                  ("ilum", .string(valDotare(c, k, "ilumHint"))),
                                  ("ct", .array(unitatiCT(c, k).map { [.string($0.id), .string($0.denumire)] }))]))
            }
            compara(.array(dot), p["dotari"], "dotările afișate \(id)")
        }
    }

    /// Controlul nou pe același obiectiv (v1.25: preia tot, constatările devin „neregulă veche”), fără identificatorii noi
    func testControlulUrmator() {
        var n = 0
        for p in d.arr("perControl").compactMap(\.obiect) {
            guard let w = p["urmator"]?.obiect else { continue }
            let c = controls.first { $0.id == p.str("id") }!
            let urm = controlFromPrevious(c, addDays(c.dataInceput, 30))
            compara(canonic(urm), canonic(Control(w)), "controlul următor după \(c.id)")
            n += 1
        }
        XCTAssertGreaterThan(n, 100)
    }

    /// Identificatorii noi (controlul, construcțiile) și momentele creării se înlocuiesc cu nume fixe
    private func canonic(_ c: Control) -> JSONValue {
        var o = c.o
        o["createdAt"] = ""; o["updatedAt"] = ""
        var text = JSONValue.object(o).text()
        text = text.replacingOccurrences(of: "\"\(c.id)\"", with: "\"#C\"")
        for (i, k) in c.constructii.enumerated() where !k.id.isEmpty {
            text = text.replacingOccurrences(of: "\"\(k.id)\"", with: "\"#K\(i)\"").replacingOccurrences(of: "\"\(k.id):", with: "\"#K\(i):")
        }
        return (try? JSONValue.citeste(Data(text.utf8))) ?? .null
    }

    /// Coordonatele scrise de mână (v1.25)
    func testCoordonateleScriseDeMana() {
        let l = d.obj("global").arr("coordonate").compactMap(\.obiect)
        XCTAssertGreaterThan(l.count, 15)
        for x in l {
            let r: JSONValue = parseCoord(x.str("t")).map { ["lat": .number($0.lat), "lon": .number($0.lon)] } ?? .null
            compara(r, x["r"], "coordonatele „\(x.str("t"))”")
        }
    }

    private let INTREBARI = ["d", "AG", "G1", "+1", "A1", "stingatoare", "STINGĂTOARE expirate", "hidranti interiori", "hint", "marcarea hidrantilor",
                             "asigurare", "hol", "foc deschis", "2", "cadru tehnic", "evacuare", "etaj"]

    /// Fișa fiecărui control (HTML identic, caracter cu caracter) și numele fișierului
    func testFisele() {
        var n = 0
        for p in d.arr("perControl").compactMap(\.obiect) {
            guard let w = p["fisa"]?.sir else { continue }
            let c = controls.first { $0.id == p.str("id") }!
            let s = fisaMarkup(c, controls, acum: Mediu.ACUM)
            if s != w {
                XCTFail("fișa \(c.id)\n\(Jetoane.diferenta(s.replacingOccurrences(of: "<", with: " <"), w.replacingOccurrences(of: "<", with: " <")))")
                return
            }
            XCTAssertEqual(fisaFileName(c), p.str("fisier"), "numele fișei \(c.id)")
            n += 1
        }
        XCTAssertGreaterThan(n, 100)
    }

    func testRandurileNeregulilor() {
        var randuri = 0
        for p in d.arr("perControl").compactMap(\.obiect) {
            let c = controls.first { $0.id == p.str("id") }!
            let web = p.arr("randuri")
            XCTAssertEqual(web.count, c.nereguli.count)
            for (i, r) in c.nereguli.enumerated() where i < web.count {
                let v = vecheInfo(controls, c, r)
                let verif: JSONValue = isVerificare(r) ? .array(verifUnitati(c, r).map { u in
                    let s = verifStare(c, r, u)
                    return .object(JSObiect([("id", .string(u.id)), ("denumire", .string(u.denumire)), ("data", .string(s.data)), ("luni", n(s.luni)),
                                             ("expira", s.expira.map { .string($0) } ?? .null), ("stare", .string(s.stare))]))
                }) : .null
                let x: JSONValue = .object(JSObiect([
                    ("key", .string(r.key)), ("litera", .string(neregulaLetter(c, r))), ("eticheta", .string(neregulaLabel(r))),
                    ("constatare", .string(constatareLabel(r))), ("cat", .string(neregulaCat(r))), ("tab", .string(tabOfNeregula(r))),
                    ("aplicabil", .bool(isApplicable(c, r))), ("ascunsa", .bool(ascunsaDeDotari(c, r))), ("grav", .bool(isGrav(r))),
                    ("veche", ["veche": .bool(v.veche), "auto": v.auto.map { .string($0.id) } ?? .null, "manual": .bool(v.manual)]),
                    ("constructii", ids(constructiiOf(c, r))), ("nume", .string(constructiiNume(c, r))), ("eligibile", ids(constructiiEligibile(c, r))),
                    ("serieNr", .string(amendaSerieNr(r.amenda))), ("suma", parseSuma(r.amenda.o["suma"].map { $0.esteNull ? "" : $0.textJS }).map { .number($0) } ?? .null),
                    ("verifText", .string(verifText(c, r))), ("verif", verif), ("expirate", JSONValue(verifExpirate(c, r).map(\.id))),
                    ("centrale", JSONValue(centraleAlese(c, r).map(\.id))), ("perCT", .bool(perCT(c, r))),
                    ("cautari", JSONValue(INTREBARI.filter { matchNeregula(c, r, $0) })),
                ]))
                compara(x, web[i], "rând \(r.key) din \(c.id)")
                randuri += 1
            }
            let acte: [JSONValue] = K.acte.map { a in JSONValue(INTREBARI.filter { matchAct(c, a.key, $0) }) }
            compara(.array(acte), p["acte"], "căutarea în acte \(c.id)")
            let lunaAn = c.dataInceput.prefix(7).split(separator: "-").reversed().joined(separator: ".")
            let q = ["scoala", "șușani", "popescu", c.dataInceput, lunaAn, String(c.dataInceput.prefix(4)), "xyz"].filter { matchControl(c, $0) }
            compara(JSONValue(q), p["cautare"], "căutarea controlului \(c.id)")
        }
        XCTAssertGreaterThan(randuri, 10000)
    }

    func testPanoulWidgeturileNotificarile() {
        let g = d.obj("global")
        for x in g.arr("cifre").compactMap(\.obiect) {
            compara(cifreZi(controls, activitati, x.str("data")).json, .object(x), "cifre \(x.str("data"))")
        }
        for x in g.arr("amenzi").compactMap(\.obiect) {
            let l: [JSONValue] = allFines(controls, x.str("d")).map { f in
                .object(JSObiect([("control", .string(f.c.id)), ("key", .string(f.n.key))]).combinat(cu: f.st.json.obiect!))
            }
            compara(.array(l), x["l"], "allFines \(x.str("d"))")
        }
        for x in g.arr("asi").compactMap(\.obiect) {
            let l: [JSONValue] = allAsi(controls, x.str("d")).map { a in .object(JSObiect([("control", .string(a.c.id))]).combinat(cu: a.a.json.obiect!)) }
            compara(.array(l), x["l"], "allAsi \(x.str("d"))")
        }
        let ob: [JSONValue] = objectives(controls).map { o in ["id": .string(o.id), "controale": JSONValue(o.controls.map(\.id)), "ultim": .string(o.last.id)] }
        compara(.array(ob), g["obiective"], "obiective")
        for x in g.arr("nativ").compactMap(\.obiect) {
            let m = x.obj("meta")
            let meta = MetaNotificari(lastBackup: m["lastBackup"]?.sir, sarbatoriVerificate: m.arr("sarbatoriVerificate").compactMap { $0.numar.map { Int($0) } })
            compara(stareNativa(controls, activitati, meta, x.str("d"), Mediu.ACUM).json, x["stare"], "widgeturi și notificări \(x.str("d"))")
        }
    }

    func testRapoarteleSiActivitatile() {
        let g = d.obj("global")
        for x in g.arr("rapoarte").compactMap(\.obiect) {
            let r = raportLunar(controls, activitati, x.int("an")!, x.int("luna")!, x.str("azi"))
            let zile: [JSONValue] = r.zile.map { (z, y) in [.string(z), ["controale": JSONValue(y.controale.map(\.id)), "activitati": JSONValue(y.activitati.map(\.id))]] }
            let j: JSONValue = .object(JSObiect([
                ("an", n(r.an)), ("luna", n(r.luna)), ("titlu", .string(r.titlu)), ("controale", JSONValue(r.controale.map(\.id))),
                ("incheiate", n(r.incheiate)), ("constatate", n(r.constatate)),
                ("amenzi", .array(r.amenzi.map { ["control": .string($0.c.id), "key": .string($0.n.key), "data": .string($0.data), "suma": .number($0.suma)] })),
                ("sumaAmenzi", .number(r.sumaAmenzi)), ("amenziFaraData", n(r.amenziFaraData)),
                ("efectuate", JSONValue(r.efectuate.map(\.id))), ("planificate", JSONValue(r.planificate.map(\.id))), ("anulate", JSONValue(r.anulate.map(\.id))),
                ("peTipuri", .array(r.peTipuri.map { ["key": .string($0.key), "label": .string($0.label), "n": n($0.n), "zile": n($0.zile)] })),
                ("libere", .array(r.libere.map(\.json))), ("zileLuna", n(r.zileLuna)), ("lucratoare", n(r.lucratoare)), ("zile", .array(zile)),
            ]))
            compara(j, x["r"], "raportul \(x.int("luna")! + 1)/\(x.int("an")!)")
            if let w = x["html"]?.sir {
                let s = raportMarkup(r, controls, acum: Mediu.ACUM)
                XCTAssertEqual(s, w, "HTML-ul raportului \(x.int("luna")! + 1)/\(x.int("an")!)")
            }
        }
        for x in g.arr("activitati").compactMap(\.obiect) {
            let a = activitati.first { $0.id == x.str("id") }!
            compara(["id": .string(a.id), "titlu": .string(titluActivitate(a)), "cand": .string(cand(a)), "zile": n(zileActivitate(a))], .object(x), "activitatea \(a.id)")
        }
        for x in g.arr("peZile").compactMap(\.obiect) {
            let z = x.str("d")
            compara(JSONValue(deConfirmat(activitati, z).map(\.id)), x["deConfirmat"], "de confirmat \(z)")
            compara(JSONValue(activitatiInZi(activitati, z).map(\.id)), x["inZi"], "activități în ziua \(z)")
            compara(ziLibera(z, "2026-10-15")?.json ?? .null, x["libera"], "zi liberă \(z)")
        }
    }
}
