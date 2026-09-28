import XCTest
@testable import AgendaKit

/// vectori/date.json și date/sarbatori.json
final class DateTests: TestVectori {
    var v: JSObiect!
    override func setUp() {
        super.setUp()
        v = try! Docs.json("vectori/date.json").obiect!
    }

    func testFormatareaDatelor() {
        XCTAssertEqual(v.arr("fmt").count, 34)
        XCTAssertEqual(v.arr("plural").count, 9)
        XCTAssertEqual(v.arr("nelucratoare").count, 809)
        XCTAssertEqual(v.arr("addWorkingDays").count, 52)
        XCTAssertEqual(v.arr("workingDaysBetween").count, 17)
        XCTAssertEqual(v.arr("nextWorkingDay").count, 22)
        XCTAssertEqual(v.arr("parseDateQuery").count, 9)
        for x in v.arr("fmt").compactMap(\.obiect) {
            let iso = x.str("iso")
            XCTAssertEqual(fmtDate(iso), x.str("fmtDate"))
            XCTAssertEqual(fmtDateLong(iso), x.str("fmtDateLong"))
            XCTAssertEqual(fmtDateMedium(iso), x.str("fmtDateMedium"))
        }
    }

    func testPluralul() {
        for x in v.arr("plural").compactMap(\.obiect) {
            XCTAssertEqual(zile(x.int("n")!), x.str("zile"))
        }
    }

    func testZileleNelucratoare2024_2030() {
        var asteptat: [String: String] = [:]
        for x in v.arr("nelucratoare").compactMap(\.obiect) { asteptat[x.str("d")] = x.str("motiv") }
        var d = "2024-01-01"
        var numarate = 0
        while d <= "2030-12-31" {
            let m = zinelucratoare(d)
            XCTAssertEqual(m, asteptat[d] ?? "", d)
            if !m.isEmpty { numarate += 1 }
            d = addDays(d, 1)
        }
        XCTAssertEqual(numarate, asteptat.count)
    }

    func testZileLucratoare() {
        for x in v.arr("addWorkingDays").compactMap(\.obiect) {
            XCTAssertEqual(addWorkingDays(x.str("d"), x.int("n")!), x.str("rezultat"), x.str("d"))
        }
        for x in v.arr("workingDaysBetween").compactMap(\.obiect) {
            XCTAssertEqual(workingDaysBetween(x.str("de"), x.str("pana")), x.int("rezultat")!, x.str("de"))
        }
        for x in v.arr("nextWorkingDay").compactMap(\.obiect) {
            XCTAssertEqual(nextWorkingDay(x.str("d")), x.str("rezultat"), x.str("d"))
        }
    }

    func testCautareaDupaData() {
        for x in v.arr("parseDateQuery").compactMap(\.obiect) {
            let r: JSONValue
            switch parseDateQuery(x.str("q"), Mediu.ACUM) {
            case .none: r = .null
            case .zi(let iso): r = ["kind": "day", "iso": .string(iso)]
            case .luna(let an, let luna): r = ["kind": "month", "year": n(an), "month": n(luna)]
            case .an(let an): r = ["kind": "year", "year": n(an)]
            }
            XCTAssertJSON(r, x["rezultat"].sau, x.str("q"))
        }
    }

    func testSarbatorileSiPastele2024_2040() throws {
        let s = try Docs.json("date/sarbatori.json").obiect!
        for (an, data) in s.obj("pasteOrtodox") {
            XCTAssertEqual(pasteOrtodox(Int(an)!), data.sir, an)
        }
        for (an, lista) in s.obj("sarbatori") {
            var o = JSObiect()
            for x in sarbatoriLegale(Int(an)!).lista.sorted(by: { $0.data < $1.data }) { o[x.data] = .string(x.nume) }
            XCTAssertJSON(.object(o), lista, an)
        }
    }

    func testAritmetica() {
        XCTAssertEqual(addDays("2026-12-31", 1), "2027-01-01")
        XCTAssertEqual(addDays("2024-03-01", -1), "2024-02-29")
        XCTAssertEqual(addMonths("2026-01-31", 1), "2026-02-28")
        XCTAssertEqual(addMonths("2024-01-31", 1), "2024-02-29")
        XCTAssertEqual(addMonths("2026-11-15", 3), "2027-02-15")
        XCTAssertEqual(diffDays("2026-03-28", "2026-03-30"), 2)   // peste ora de vară
        XCTAssertEqual(todayISO(Mediu.ACUM), "2026-10-15")
        XCTAssertEqual(isoMs(Mediu.ACUM), "2026-10-15T06:00:00.000Z")
    }
}
