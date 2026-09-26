import XCTest
@testable import AgendaKit

/// vectori/termene.json (amenzi zi cu zi, ASI 90 + 5 zile, încărcarea) și vectori/sume.json
final class TermeneTests: TestVectori {
    var v: JSObiect!
    override func setUp() {
        super.setUp()
        v = try! Docs.json("vectori/termene.json").obiect!
    }

    /// Ca în exporta.mjs: control OPEC încheiat, cu amendă aplicată la neregula „d”.
    private func controlCuAmenda(_ incheiere: String, _ aplicare: String = "") -> (Control, Int) {
        var c = newControl(tip: "OPEC", denumire: "Test", start: incheiere)
        c.dataIncheiere = incheiere
        var l = c.nereguli
        let i = l.firstIndex { $0.key == "d" }!
        l[i].status = "nok"
        var a = l[i].amenda
        a.aplicata = true; a.data = aplicare; a.suma = "1.000"
        l[i].amenda = a
        c.nereguli = l
        return (c, i)
    }

    func testAmenzile() {
        XCTAssertEqual(v.arr("amenzi").count, 214)
        for x in v.arr("amenzi").compactMap(\.obiect) {
            let c: Control
            let i: Int
            if x.bool("neincheiat") {
                var cc = newControl(tip: "OPEC", start: "2026-10-01")
                var l = cc.nereguli
                i = l.firstIndex { $0.key == "d" }!
                l[i].status = "nok"
                var a = l[i].amenda; a.aplicata = true; l[i].amenda = a
                cc.nereguli = l
                c = cc
            } else {
                var (cc, ii) = controlCuAmenda(x.str("dataIncheiere"), x.str("dataAplicarii"))
                if x.contine("achitata") {
                    var l = cc.nereguli
                    var a = l[ii].amenda; a.achitata = true; a.dataAchitare = x.str("achitata"); l[ii].amenda = a
                    cc.nereguli = l
                }
                c = cc; i = ii
            }
            XCTAssertJSON(fineStatus(c, c.nereguli[i], x.str("azi")).json, x["rezultat"].sau, "amendă \(x.str("dataIncheiere")) azi \(x.str("azi"))")
        }
    }

    func testASI() {
        XCTAssertEqual(v.arr("asi").count, 109)
        for x in v.arr("asi").compactMap(\.obiect) {
            var c = newControl(tip: "OPEC", start: x.bool("neincheiat") ? "2026-10-01" : x.str("dataIncheiere"))
            if !x.bool("neincheiat") { c.dataIncheiere = x.str("dataIncheiere") }
            var l = c.nereguli
            let i = l.firstIndex { $0.key == "a" }!
            l[i].status = "nok"; l[i].asiTermen = true
            for (k, val) in x.obj("cfg") { l[i].o[k] = val }
            c.nereguli = l
            XCTAssertJSON(asiDeadline(c, x.str("azi"))?.json ?? .null, x["rezultat"].sau, "ASI \(x.str("dataIncheiere")) azi \(x.str("azi"))")
        }
    }

    func testIncarcarea() {
        XCTAssertEqual(v.arr("incarcare").count, 150)
        for x in v.arr("incarcare").compactMap(\.obiect) {
            var c = newControl(tip: "OPEC", start: x.str("dataIncheiere"))
            c.dataIncheiere = x.str("dataIncheiere")
            var inc = c.incarcare
            for (k, val) in x.obj("bife") { inc.o[k] = val }
            c.incarcare = inc
            XCTAssertJSON(incarcareStatus(c, x.str("azi"))?.json ?? .null, x["rezultat"].sau, "încărcare \(x.str("dataIncheiere")) azi \(x.str("azi"))")
        }
    }

    func testSumele() throws {
        XCTAssertEqual(try Docs.json("vectori/sume.json").lista!.count, 13)
        for x in try Docs.json("vectori/sume.json").lista!.compactMap(\.obiect) {
            let p = parseSuma(x.str("text"))
            XCTAssertJSON(p.map { .number($0) } ?? .null, x["parseSuma"].sau, "„\(x.str("text"))”")
            XCTAssertJSON(p.map { .string(lei($0)) } ?? .null, x["lei"].sau, "lei „\(x.str("text"))”")
        }
        XCTAssertEqual(lei(1234567.891), "1.234.567,89 lei")
        XCTAssertEqual(lei(0.5), "0,5 lei")
    }
}
