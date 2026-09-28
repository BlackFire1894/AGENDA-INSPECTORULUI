import XCTest
@testable import AgendaKit

/// Căile către datele comune și vectori (docs/nativ/), relativ la acest fișier.
enum Docs {
    static let nativ = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // AgendaKitTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // AgendaKit
        .deletingLastPathComponent() // ios
        .deletingLastPathComponent() // rădăcina repo
        .appendingPathComponent("docs/nativ")

    static func date(_ nume: String) throws -> Data {
        try Data(contentsOf: nativ.appendingPathComponent("date/\(nume)"))
    }

    static func vector(_ nume: String) throws -> Data {
        try Data(contentsOf: nativ.appendingPathComponent("vectori/\(nume)"))
    }

    static func json(_ cale: String) throws -> JSONValue {
        try JSONValue.citeste(Data(contentsOf: nativ.appendingPathComponent(cale)))
    }
}

/// Mediul din exporta.mjs: joi, 15.10.2026, 09:00 (ora României), catalogul încărcat.
enum Mediu {
    static let ACUM = Date(timeIntervalSince1970: 1_792_044_000)   // 2026-10-15T06:00:00Z
    static let AZI = "2026-10-15"

    nonisolated(unsafe) private static var gata = false
    static func pregateste() {
        Ceas.acum = { ACUM }
        Ceas.fus = TimeZone(identifier: "Europe/Bucharest")!
        var samanta: UInt64 = 42
        Ceas.aleator = {
            samanta = (samanta &* 6364136223846793005 &+ 1442695040888963407)
            return Double(samanta >> 11) / Double(1 << 53)
        }
        if !gata {
            Catalog.incarca(try! Catalog(data: Docs.date("catalog.json")))
            gata = true
        }
    }
}

class TestVectori: XCTestCase {
    override func setUp() {
        super.setUp()
        Mediu.pregateste()
    }
}

/// Prima diferență dintre două valori JSON (cale + cele două valori), sau nil dacă sunt egale.
func diferenta(_ a: JSONValue, _ b: JSONValue, _ cale: String = "$") -> String? {
    switch (a, b) {
    case (.object(let x), .object(let y)):
        for k in x.chei where y[k] == nil { return "\(cale).\(k): în plus în Swift = \(x[k]!.text())" }
        for k in y.chei where x[k] == nil { return "\(cale).\(k): lipsește în Swift (web = \(y[k]!.text()))" }
        for k in y.chei { if let d = diferenta(x[k]!, y[k]!, "\(cale).\(k)") { return d } }
        return nil
    case (.array(let x), .array(let y)):
        for i in 0..<min(x.count, y.count) { if let d = diferenta(x[i], y[i], "\(cale)[\(i)]") { return d } }
        if x.count != y.count { return "\(cale): \(x.count) elemente în Swift, \(y.count) în web" }
        return nil
    default:
        return a == b ? nil : "\(cale): Swift = \(a.text()) · web = \(b.text())"
    }
}

func XCTAssertJSON(_ swift: JSONValue, _ web: JSONValue, _ context: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    if let d = diferenta(swift, web) {
        XCTFail("\(context()) \(d)", file: file, line: line)
    }
}

extension Optional where Wrapped == JSONValue {
    var sau: JSONValue { self ?? .null }
}

func ids(_ l: [Control]) -> JSONValue { JSONValue(l.map(\.id)) }
func ids(_ l: [Activitate]) -> JSONValue { JSONValue(l.map(\.id)) }
func n(_ x: Int) -> JSONValue { .number(Double(x)) }
