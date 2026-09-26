import XCTest
@testable import AgendaKit

/// vectori/normalizare.json: controale din versiuni vechi → cum le completează aplicația;
/// plus: fișierele JSON se citesc și se rescriu identic (octet cu octet), ca JSON.stringify.
final class NormalizareTests: TestVectori {
    func testDateleVechi() throws {
        XCTAssertEqual(try Docs.json("vectori/normalizare.json").lista!.count, 2)
        for x in try Docs.json("vectori/normalizare.json").lista!.compactMap(\.obiect) {
            let intrare = x.obj("intrare")
            var r = normalizeControl(intrare).o
            let web = x.obj("rezultat")
            // construcțiile create acum primesc identificatori noi (aleatori în web): se compară restul
            if intrare.arr("constructii").isEmpty {
                var l = r.arr("constructii")
                for (i, k) in web.arr("constructii").enumerated() where i < l.count {
                    var o = l[i].obiect!
                    o["id"] = k.obiect?["id"]
                    l[i] = .object(o)
                }
                r["constructii"] = .array(l)
            }
            XCTAssertJSON(.object(r), .object(web), intrare.str("id"))
            XCTAssertEqual(r.chei.count, web.chei.count)
        }
    }

    func testFisiereleSeRescriuIdentic() throws {
        for f in ["vectori/demo.json", "vectori/termene.json", "vectori/date.json", "vectori/sume.json", "vectori/normalizare.json",
                  "date/catalog.json", "date/sarbatori.json", "date/ghid.json"] {
            let text = try String(contentsOf: Docs.nativ.appendingPathComponent(f), encoding: .utf8)
            let v = try JSONValue.citeste(text)
            XCTAssertEqual(v.text(indentare: 1) + "\n", text, f)
        }
    }

    func testNumereleCaInJS() {
        XCTAssertEqual(numarJS(2500), "2500")
        XCTAssertEqual(numarJS(1500.5), "1500.5")
        XCTAssertEqual(numarJS(0.1), "0.1")
        XCTAssertEqual(numarJS(1e-7), "1e-7")
        XCTAssertEqual(numarJS(0.000001), "0.000001")
        XCTAssertEqual(numarJS(1e21), "1e+21")
        XCTAssertEqual(numarJS(123456789012), "123456789012")
        XCTAssertEqual(numarJS(-12.25), "-12.25")
        XCTAssertEqual(numarJS(45.123456), "45.123456")
    }
}
