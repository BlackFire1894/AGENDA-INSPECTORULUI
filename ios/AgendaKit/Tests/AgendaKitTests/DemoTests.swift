import XCTest
@testable import AgendaKit

/// vectori/demo.json: setul demonstrativ la 15.10.2026 și tot ce afișează aplicația despre el
/// (fără HTML-ul fișei și al raportului, verificate în etapele 6–7).
final class DemoTests: TestVectori {
    var d: JSObiect!
    var controls: [Control] = []
    var activitati: [Activitate] = []
    let AZI = Mediu.AZI

    override func setUp() {
        super.setUp()
        d = try! Docs.json("vectori/demo.json").obiect!
        controls = d.arr("controls").compactMap(\.obiect).map(Control.init)
        activitati = d.arr("activitati").compactMap(\.obiect).map(Activitate.init)
    }

    func testSetulComplet() {
        XCTAssertEqual(controls.count, 7)
        XCTAssertEqual(activitati.count, 5)
        XCTAssertEqual(d.arr("cautari").count, 8)
        XCTAssertEqual(d.obj("nativ").arr("notificari").count, 22)
        XCTAssertEqual(d.obj("nativ").arr("zile").count, 21)
    }

    func testNormalizareaNuSchimbaDateleNormalizate() {
        for c in controls { XCTAssertJSON(normalizeControl(c.o).json, c.json, c.id) }
        for a in activitati { XCTAssertJSON(normalizeActivitate(a.o).json, a.json, a.id) }
    }

    func testBackupulDusIntors() throws {
        let b = d["backup"]!
        let text = b.text()
        XCTAssertEqual(try JSONValue.citeste(text), b)
        XCTAssertEqual(try JSONValue.citeste(text).text(), text)
    }

    func testPeControl() {
        let perControl = d.arr("perControl").compactMap(\.obiect)
        XCTAssertEqual(perControl.count, controls.count)
        for p in perControl {
            guard let c = controls.first(where: { $0.id == p.str("id") }) else { XCTFail("lipsește \(p.str("id"))"); continue }
            let id = c.id

            let s = controlStats(c, AZI)
            let cs: JSONValue = .object(JSObiect([
                ("acteDone", n(s.acteDone)), ("acteTotal", n(s.acteTotal)), ("acteNok", n(s.acteNok)),
                ("nereguliChecked", n(s.nereguliChecked)), ("nereguliTotal", n(s.nereguliTotal)),
                ("constatate", n(s.constatate)), ("netrecute", n(s.netrecute)),
                ("fines", .array(s.fines.map { f in .object(JSObiect([("key", .string(f.n.key))]).combinat(cu: f.st.json.obiect!)) })),
                ("asi", s.asi?.json ?? .null), ("incarcare", s.incarcare?.json ?? .null),
            ]))
            XCTAssertJSON(cs, p["controlStats"].sau, "\(id) controlStats")

            var ss = JSObiect()
            for sec in sectiuniActive(c) {
                let x = secStats(c, sec, AZI)
                ss[sec] = ["total": n(x.total), "checked": n(x.checked), "hidden": n(x.hidden), "constatate": n(x.constatate),
                           "netrecute": n(x.netrecute), "fines": n(x.fines.count)]
            }
            XCTAssertJSON(.object(ss), p["secStats"].sau, "\(id) secStats")

            XCTAssertJSON(.array(todoList(c).map(\.json)), p["todoList"].sau, "\(id) todoList")

            let pv = pvText(c, controls)
            XCTAssertJSON(["text": .string(pv.text), "count": n(pv.count)], p["pvText"].sau, "\(id) pvText")
            let pvn = pvText(c, controls, doarNetrecute: true, cuActe: false)
            XCTAssertJSON(["text": .string(pvn.text), "count": n(pvn.count)], p["pvTextNetrecute"].sau, "\(id) pvTextNetrecute")

            XCTAssertJSON(sigiliiControl(c)?.json ?? .null, p["sigilii"].sau, "\(id) sigilii")
            XCTAssertJSON(adaposturiStats(c)?.json ?? .null, p["adaposturi"].sau, "\(id) adaposturi")

            let randuri: [JSONValue] = activeNereguli(c).map { r in
                let v = vecheInfo(controls, c, r)
                return .object(JSObiect([
                    ("key", .string(r.key)), ("sec", .string(secOf(r))), ("litera", .string(neregulaLetter(c, r))),
                    ("eticheta", .string(neregulaLabel(r))), ("constatare", .string(constatareLabel(r))),
                    ("categorie", .string(neregulaCat(r))), ("aplicabil", .bool(isApplicable(c, r))), ("status", .string(r.status)),
                    ("grav", .bool(isGrav(r))),
                    ("veche", ["veche": .bool(v.veche), "auto": v.auto.map { .string($0.id) } ?? .null, "manual": .bool(v.manual)]),
                    ("constructii", JSONValue(constructiiOf(c, r).map(\.id))),
                    ("amenda", r.status == "nok" && r.amenda.aplicata ? fineStatus(c, r, AZI).json : .null),
                ]))
            }
            XCTAssertJSON(.array(randuri), p["randuri"].sau, "\(id) randuri")
        }
    }

    func testObiectiveleSiCautarile() {
        let ob: [JSONValue] = objectives(controls).map { o in
            ["id": .string(o.id), "denumire": .string(o.denumire), "tip": .string(o.tip), "controale": ids(o.controls), "ultim": .string(o.last.id)]
        }
        XCTAssertJSON(.array(ob), d["obiective"].sau, "obiective")
        for x in d.arr("cautari").compactMap(\.obiect) {
            let q = x.str("q")
            XCTAssertJSON(ids(controls.filter { matchControl($0, q) }), x["controale"].sau, "căutare „\(q)”")
        }
    }

    func testPanoul() {
        let p = d.obj("panou")
        XCTAssertJSON(cifreZi(controls, activitati, AZI).json, p["cifre"].sau, "cifre")
        let am: [JSONValue] = allFines(controls, AZI).map { f in
            .object(JSObiect([("control", .string(f.c.id)), ("key", .string(f.n.key))]).combinat(cu: f.st.json.obiect!))
        }
        XCTAssertJSON(.array(am), p["amenzi"].sau, "amenzi")
        let asi: [JSONValue] = allAsi(controls, AZI).map { x in
            .object(JSObiect([("control", .string(x.c.id))]).combinat(cu: x.a.json.obiect!))
        }
        XCTAssertJSON(.array(asi), p["asi"].sau, "asi")
        XCTAssertJSON(ids(deConfirmat(activitati, AZI)), p["deConfirmat"].sau, "deConfirmat")
    }

    func testRaportulLunii() {
        let r = raportLunar(controls, activitati, 2026, 9, AZI)
        let zileR: [JSONValue] = r.zile.map { (zi, x) in [.string(zi), ["controale": ids(x.controale), "activitati": ids(x.activitati)]] }
        let j: JSONValue = .object(JSObiect([
            ("an", n(r.an)), ("luna", n(r.luna)), ("titlu", .string(r.titlu)),
            ("controale", ids(r.controale)), ("incheiate", n(r.incheiate)), ("constatate", n(r.constatate)),
            ("amenzi", .array(r.amenzi.map { ["control": .string($0.c.id), "key": .string($0.n.key), "data": .string($0.data), "suma": .number($0.suma)] })),
            ("sumaAmenzi", .number(r.sumaAmenzi)), ("amenziFaraData", n(r.amenziFaraData)),
            ("efectuate", ids(r.efectuate)), ("planificate", ids(r.planificate)), ("anulate", ids(r.anulate)),
            ("peTipuri", .array(r.peTipuri.map { ["key": .string($0.key), "label": .string($0.label), "n": n($0.n), "zile": n($0.zile)] })),
            ("libere", .array(r.libere.map(\.json))), ("zileLuna", n(r.zileLuna)), ("lucratoare", n(r.lucratoare)),
            ("zile", .array(zileR)),
        ]))
        XCTAssertJSON(j, d["raportOctombrie"].sau, "raportOctombrie")
    }

    func testWidgeturileSiNotificarile() {
        let s = stareNativa(controls, activitati, MetaNotificari(), AZI, Mediu.ACUM)
        XCTAssertJSON(s.json, d["nativ"].sau, "nativ")
    }
}
